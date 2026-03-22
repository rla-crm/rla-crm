/**
 * RLA CRM Sync API v6 — Cloudflare Pages Function
 *
 * KEY ADDITION in v6: Cloud-level deleted_ids ledger
 *  - Every DELETE request records { collection, id, deletedAt } in
 *    store._deleted_ledger (an array, max 500 entries, oldest pruned).
 *  - GET /api/sync/all includes the full ledger in the response.
 *  - Every Flutter client applies those deletions to its local Hive box
 *    on every sync, so deleted leads/projects instantly disappear from
 *    ALL devices — including sales users who didn't perform the delete.
 *
 * STORAGE: Dual-JSONBlob with auto-recreate guard
 *  - Primary blob:   019d1680-eb78-7664-ba7c-a7e2d78a787e
 *  - Backup blob:    auto-created if primary fails
 *  - Master admin is ALWAYS re-seeded if cloud users collection is empty
 *
 * Endpoints:
 *   GET    /api/sync/health                    → health check
 *   GET    /api/sync/all                       → all collections + deleted ledger
 *   GET    /api/sync?collection=rla_users      → list records
 *   POST   /api/sync?collection=rla_users      → upsert record
 *   DELETE /api/sync?collection=rla_users&id=x → delete record (logged to ledger)
 */

const COLLECTIONS = [
  'rla_users',
  'rla_leads',
  'rla_projects',
  'rla_approvals',
  'rla_notifications',
];

const API_SECRET    = 'rla-crm-sync-2024-xK9mP3nQ';
const JSONBLOB_BASE = 'https://jsonblob.com/api/jsonBlob';

// Primary blob ID — always kept alive by this worker
const PRIMARY_BLOB_ID = '019d1680-eb78-7664-ba7c-a7e2d78a787e';

// Max entries kept in the deleted_ledger (older ones are pruned)
const MAX_LEDGER_ENTRIES = 500;

// ── Master admin seed — always present in cloud ───────────────────────────────
const MASTER_ADMIN_SEED = {
  id: 'master_admin_001',
  name: 'Aksayal',
  email: 'aksayal@gmail.com',
  password: '09101991',
  role: 'masterAdmin',
  companyId: null,
  companyName: null,
  isApproved: true,
  isActive: true,
  hasLoggedInBefore: true,
  createdAt: '2024-01-01T00:00:00.000Z',
  updatedAt: '2024-01-01T00:00:00.000Z',
  sync_updated_at: '2024-01-01T00:00:00.000Z',
};

function emptyStore() {
  return {
    rla_users:         { master_admin_001: MASTER_ADMIN_SEED },
    rla_leads:         {},
    rla_projects:      {},
    rla_approvals:     {},
    rla_notifications: {},
    _deleted_ledger:   [],   // array of { collection, id, deletedAt }
  };
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-Sync-Key, Accept, Authorization, Cache-Control',
  'Access-Control-Max-Age': '86400',
  'Cache-Control': 'no-store, no-cache, must-revalidate',
  'Pragma': 'no-cache',
  'Content-Type': 'application/json',
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: corsHeaders });
}

// ── JSONBlob helpers ──────────────────────────────────────────────────────────

async function readBlob(blobId) {
  const res = await fetch(`${JSONBLOB_BASE}/${blobId}`, {
    headers: { 'Accept': 'application/json', 'Cache-Control': 'no-cache' },
  });
  if (!res.ok) return null;
  const data = await res.json();
  if (data && data.error) return null;
  return data;
}

async function writeBlob(blobId, store) {
  const res = await fetch(`${JSONBLOB_BASE}/${blobId}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
    body: JSON.stringify(store),
  });
  return res.ok;
}

async function createBlob(store) {
  const res = await fetch(JSONBLOB_BASE, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
    body: JSON.stringify(store),
  });
  if (!res.ok) return null;
  const loc = res.headers.get('Location') || '';
  const match = loc.match(/jsonBlob\/([a-f0-9-]{36})/i);
  return match ? match[1] : null;
}

// ── Read store with auto-heal ─────────────────────────────────────────────────
async function readStore() {
  let store = await readBlob(PRIMARY_BLOB_ID);

  if (!store) {
    console.warn('[RLA-CRM] Primary blob missing, recreating with seed data…');
    store = emptyStore();
    await writeBlob(PRIMARY_BLOB_ID, store);
  }

  // Ensure all collections exist
  for (const col of COLLECTIONS) {
    if (!store[col]) store[col] = {};
  }

  // Ensure deleted ledger exists
  if (!Array.isArray(store._deleted_ledger)) {
    store._deleted_ledger = [];
  }

  // ── CRITICAL: Always ensure master admin exists ───────────────────────────
  if (!store.rla_users || Object.keys(store.rla_users).length === 0 ||
      !store.rla_users['master_admin_001']) {
    console.warn('[RLA-CRM] Master admin missing from cloud — re-seeding…');
    if (!store.rla_users) store.rla_users = {};
    store.rla_users['master_admin_001'] = {
      ...MASTER_ADMIN_SEED,
      sync_updated_at: new Date().toISOString(),
    };
    await writeBlob(PRIMARY_BLOB_ID, store);
  }

  return store;
}

async function writeStore(store) {
  // Always ensure master admin is present before every write
  if (!store.rla_users) store.rla_users = {};
  if (!store.rla_users['master_admin_001']) {
    store.rla_users['master_admin_001'] = {
      ...MASTER_ADMIN_SEED,
      sync_updated_at: new Date().toISOString(),
    };
  }

  // Ensure deleted ledger exists
  if (!Array.isArray(store._deleted_ledger)) {
    store._deleted_ledger = [];
  }

  const ok = await writeBlob(PRIMARY_BLOB_ID, store);
  if (!ok) {
    console.warn('[RLA-CRM] Primary blob write failed, attempting recreate…');
    const newId = await createBlob(store);
    if (newId) {
      console.warn(`[RLA-CRM] New blob created: ${newId} (update PRIMARY_BLOB_ID in worker)`);
    }
    throw new Error('Storage write failed — please retry');
  }
  return true;
}

// ── Append to deleted ledger ──────────────────────────────────────────────────
function appendToLedger(store, collection, id) {
  if (!Array.isArray(store._deleted_ledger)) {
    store._deleted_ledger = [];
  }
  // Avoid duplicate entries for the same id+collection
  store._deleted_ledger = store._deleted_ledger.filter(
    e => !(e.collection === collection && e.id === id)
  );
  store._deleted_ledger.push({
    collection,
    id,
    deletedAt: new Date().toISOString(),
  });
  // Prune to max size (keep most recent)
  if (store._deleted_ledger.length > MAX_LEDGER_ENTRIES) {
    store._deleted_ledger = store._deleted_ledger.slice(
      store._deleted_ledger.length - MAX_LEDGER_ENTRIES
    );
  }
}

// ── Main request handler ──────────────────────────────────────────────────────
export async function onRequest(context) {
  const { request, params } = context;
  const url  = new URL(request.url);
  const path = (params.path || []).join('/');

  // Preflight
  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  // ── Health check ────────────────────────────────────────────────────────────
  if (path === 'health' || path === 'health/') {
    let blobStatus = 'ok';
    let userCount  = 0;
    let ledgerSize = 0;
    try {
      const store = await readStore();
      userCount   = Object.keys(store.rla_users || {}).length;
      ledgerSize  = (store._deleted_ledger || []).length;
    } catch (e) {
      blobStatus = 'degraded: ' + e.message;
    }
    return json({
      status: blobStatus === 'ok' ? 'ok' : 'degraded',
      service: 'RLA CRM Sync API v6',
      storage: 'jsonblob-dual (global-persistent)',
      blobId: PRIMARY_BLOB_ID,
      userCount,
      deletedLedgerSize: ledgerSize,
      timestamp: new Date().toISOString(),
    });
  }

  // ── GET ALL: single-request pull for all collections + deleted ledger ────────
  if (request.method === 'GET' && (path === 'all' || path === 'all/')) {
    try {
      const store = await readStore();
      const result = {};
      for (const col of COLLECTIONS) {
        result[col] = Object.values(store[col] || {});
      }
      return json({
        collections:     result,
        deleted_ledger:  store._deleted_ledger || [],
        storage:         'jsonblob-v6',
      });
    } catch (e) {
      return json({ error: e.message }, 500);
    }
  }

  // ── Auth gate for writes ────────────────────────────────────────────────────
  const syncKey = request.headers.get('X-Sync-Key');
  if ((request.method === 'POST' || request.method === 'DELETE') &&
      syncKey !== API_SECRET) {
    return json({ error: 'Unauthorized' }, 401);
  }

  const collection = url.searchParams.get('collection');
  if (!collection || !COLLECTIONS.includes(collection)) {
    return json({ error: `Invalid collection. Valid: ${COLLECTIONS.join(', ')}` }, 400);
  }

  // ── GET: list records ───────────────────────────────────────────────────────
  if (request.method === 'GET') {
    try {
      const store   = await readStore();
      let records   = Object.values(store[collection] || {});
      const since   = url.searchParams.get('since');
      if (since) {
        const sinceDate = new Date(since);
        records = records.filter(r => {
          const ts = r.sync_updated_at || r.updatedAt || r.updated_at || r.createdAt;
          return !ts || new Date(ts) >= sinceDate;
        });
      }
      return json({ records, count: records.length, storage: 'jsonblob-v6', collection });
    } catch (e) {
      return json({ error: e.message, records: [] }, 500);
    }
  }

  // ── POST: upsert ────────────────────────────────────────────────────────────
  if (request.method === 'POST') {
    try {
      const body = await request.json();
      if (!body || !body.id) {
        return json({ error: 'Body must be JSON with an "id" field' }, 400);
      }
      body.sync_updated_at = new Date().toISOString();

      const store = await readStore();
      if (!store[collection]) store[collection] = {};
      store[collection][body.id] = body;

      // If this ID was previously in the ledger (deleted then re-added),
      // remove it from the ledger so it won't be deleted again on other clients.
      if (Array.isArray(store._deleted_ledger)) {
        store._deleted_ledger = store._deleted_ledger.filter(
          e => !(e.collection === collection && e.id === body.id)
        );
      }

      await writeStore(store);
      return json({ success: true, id: body.id, storage: 'jsonblob-v6' });
    } catch (e) {
      return json({ error: e.message }, 500);
    }
  }

  // ── DELETE ──────────────────────────────────────────────────────────────────
  if (request.method === 'DELETE') {
    try {
      const id = url.searchParams.get('id');
      if (!id) return json({ error: '"id" param required' }, 400);

      // Protect master admin from deletion
      if (collection === 'rla_users' && id === 'master_admin_001') {
        return json({ error: 'Master admin cannot be deleted' }, 403);
      }

      const store = await readStore();

      // Remove from the collection
      if (store[collection] && store[collection][id]) {
        delete store[collection][id];
      }

      // ── CRITICAL: Record deletion in the ledger ───────────────────────────
      // Every other client will read this ledger on their next sync and
      // delete the matching record from their local Hive box.
      appendToLedger(store, collection, id);

      await writeStore(store);
      return json({ success: true, id, ledgerSize: store._deleted_ledger.length });
    } catch (e) {
      return json({ error: e.message }, 500);
    }
  }

  return json({ error: 'Method not allowed' }, 405);
}
