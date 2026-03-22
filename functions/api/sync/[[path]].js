/**
 * RLA CRM Sync API v7 — Cloudflare Pages Function
 *
 * NEW in v7: Real-time sync infrastructure
 *  1. sync_version: monotonically-increasing integer incremented on EVERY write.
 *     Flutter polls GET /api/sync/version every 5s — a tiny 1-field response.
 *     Only fetches the full /all payload when the version has changed.
 *     This makes "is there anything new?" nearly free (single number compare).
 *
 *  2. Persistent deleted_ledger (from v6) — still present, max 500 entries.
 *
 *  3. Per-collection timestamps: each record gets sync_updated_at on upsert.
 *     Clients can use ?since= for incremental pulls in future.
 *
 * STORAGE: JSONBlob with auto-recreate guard (primary blob always kept alive).
 *
 * Endpoints:
 *   GET    /api/sync/health           → health + version + ledger size
 *   GET    /api/sync/version          → { version, updatedAt }  (lightweight poll)
 *   GET    /api/sync/all              → all collections + deleted_ledger + version
 *   GET    /api/sync?collection=x     → list records in collection
 *   POST   /api/sync?collection=x     → upsert record  (bumps version)
 *   DELETE /api/sync?collection=x&id=y → delete record (bumps version + ledger)
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
const PRIMARY_BLOB_ID = '019d1680-eb78-7664-ba7c-a7e2d78a787e';
const MAX_LEDGER_ENTRIES = 500;

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
    _deleted_ledger:   [],
    _sync_version:     1,
    _sync_updated_at:  new Date().toISOString(),
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
    console.warn('[RLA-CRM] Primary blob missing, recreating…');
    store = emptyStore();
    await writeBlob(PRIMARY_BLOB_ID, store);
  }

  // Ensure all collections exist
  for (const col of COLLECTIONS) {
    if (!store[col]) store[col] = {};
  }
  if (!Array.isArray(store._deleted_ledger)) store._deleted_ledger = [];
  if (typeof store._sync_version !== 'number') store._sync_version = 1;
  if (!store._sync_updated_at) store._sync_updated_at = new Date().toISOString();

  // Always ensure master admin
  if (!store.rla_users || Object.keys(store.rla_users).length === 0 ||
      !store.rla_users['master_admin_001']) {
    console.warn('[RLA-CRM] Master admin missing — re-seeding…');
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
  if (!store.rla_users) store.rla_users = {};
  if (!store.rla_users['master_admin_001']) {
    store.rla_users['master_admin_001'] = {
      ...MASTER_ADMIN_SEED,
      sync_updated_at: new Date().toISOString(),
    };
  }
  if (!Array.isArray(store._deleted_ledger)) store._deleted_ledger = [];

  // ── Bump sync version on every write ──────────────────────────────────────
  store._sync_version   = (store._sync_version || 0) + 1;
  store._sync_updated_at = new Date().toISOString();

  const ok = await writeBlob(PRIMARY_BLOB_ID, store);
  if (!ok) {
    console.warn('[RLA-CRM] Primary blob write failed, attempting recreate…');
    const newId = await createBlob(store);
    if (newId) {
      console.warn(`[RLA-CRM] New blob: ${newId} — update PRIMARY_BLOB_ID in worker`);
    }
    throw new Error('Storage write failed — please retry');
  }
  return store._sync_version;
}

// ── Append to deleted ledger ──────────────────────────────────────────────────
function appendToLedger(store, collection, id) {
  if (!Array.isArray(store._deleted_ledger)) store._deleted_ledger = [];
  // Remove any previous entry for this id+collection to avoid duplicates
  store._deleted_ledger = store._deleted_ledger.filter(
    e => !(e.collection === collection && e.id === id)
  );
  store._deleted_ledger.push({ collection, id, deletedAt: new Date().toISOString() });
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

  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  // ── Health ──────────────────────────────────────────────────────────────────
  if (path === 'health' || path === 'health/') {
    let blobStatus = 'ok', userCount = 0, ledgerSize = 0, version = 0;
    try {
      const store = await readStore();
      userCount  = Object.keys(store.rla_users || {}).length;
      ledgerSize = (store._deleted_ledger || []).length;
      version    = store._sync_version || 0;
    } catch (e) {
      blobStatus = 'degraded: ' + e.message;
    }
    return json({
      status: blobStatus === 'ok' ? 'ok' : 'degraded',
      service: 'RLA CRM Sync API v7',
      storage: 'jsonblob (global-persistent)',
      blobId: PRIMARY_BLOB_ID,
      userCount,
      deletedLedgerSize: ledgerSize,
      syncVersion: version,
      timestamp: new Date().toISOString(),
    });
  }

  // ── VERSION POLL (lightweight) ──────────────────────────────────────────────
  // Flutter polls this every 5s. Returns only { version, updatedAt }.
  // If version > lastKnown → trigger full /all fetch. Otherwise skip.
  if (path === 'version' || path === 'version/') {
    try {
      const store = await readStore();
      return json({
        version:   store._sync_version   || 1,
        updatedAt: store._sync_updated_at || new Date().toISOString(),
      });
    } catch (e) {
      return json({ error: e.message }, 500);
    }
  }

  // ── GET ALL ─────────────────────────────────────────────────────────────────
  if (request.method === 'GET' && (path === 'all' || path === 'all/')) {
    try {
      const store = await readStore();
      const result = {};
      for (const col of COLLECTIONS) {
        result[col] = Object.values(store[col] || {});
      }
      return json({
        collections:    result,
        deleted_ledger: store._deleted_ledger || [],
        version:        store._sync_version   || 1,
        storage:        'jsonblob-v7',
      });
    } catch (e) {
      return json({ error: e.message }, 500);
    }
  }

  // ── Auth gate ───────────────────────────────────────────────────────────────
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
      return json({
        records, count: records.length,
        storage: 'jsonblob-v7', collection,
        version: store._sync_version || 1,
      });
    } catch (e) {
      return json({ error: e.message, records: [] }, 500);
    }
  }

  // ── POST: upsert ─────────────────────────────────────────────────────────────
  if (request.method === 'POST') {
    try {
      const body = await request.json();
      if (!body || !body.id) {
        return json({ error: 'Body must have "id" field' }, 400);
      }
      body.sync_updated_at = new Date().toISOString();

      const store = await readStore();
      if (!store[collection]) store[collection] = {};
      store[collection][body.id] = body;

      // If this record was previously in the ledger (deleted then re-added),
      // remove it so other clients won't delete it again.
      if (Array.isArray(store._deleted_ledger)) {
        store._deleted_ledger = store._deleted_ledger.filter(
          e => !(e.collection === collection && e.id === body.id)
        );
      }

      const newVersion = await writeStore(store);
      return json({ success: true, id: body.id, version: newVersion, storage: 'jsonblob-v7' });
    } catch (e) {
      return json({ error: e.message }, 500);
    }
  }

  // ── DELETE ───────────────────────────────────────────────────────────────────
  if (request.method === 'DELETE') {
    try {
      const id = url.searchParams.get('id');
      if (!id) return json({ error: '"id" param required' }, 400);

      if (collection === 'rla_users' && id === 'master_admin_001') {
        return json({ error: 'Master admin cannot be deleted' }, 403);
      }

      const store = await readStore();
      if (store[collection] && store[collection][id]) {
        delete store[collection][id];
      }
      appendToLedger(store, collection, id);
      const newVersion = await writeStore(store);
      return json({ success: true, id, version: newVersion, ledgerSize: store._deleted_ledger.length });
    } catch (e) {
      return json({ error: e.message }, 500);
    }
  }

  return json({ error: 'Method not allowed' }, 405);
}
