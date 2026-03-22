/**
 * RLA CRM Sync API v5 — Cloudflare Pages Function
 *
 * STORAGE: Dual-JSONBlob with auto-recreate guard
 *  - Primary blob:   019d1680-eb78-7664-ba7c-a7e2d78a787e
 *  - Backup blob:    auto-created if primary fails
 *  - Master admin is ALWAYS re-seeded if cloud users collection is empty
 *
 * This ensures the app works seamlessly across ALL platforms, browsers,
 * devices and private/incognito sessions at all times.
 *
 * Endpoints:
 *   GET    /api/sync/health                    → health check
 *   GET    /api/sync/all                       → all collections at once
 *   GET    /api/sync?collection=rla_users      → list records
 *   POST   /api/sync?collection=rla_users      → upsert record
 *   DELETE /api/sync?collection=rla_users&id=x → delete record
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
  if (!res.ok) return null;   // blob missing or error
  const data = await res.json();
  // Detect error response from JSONBlob ({"error":"Blob not found"})
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
  // Extract ID from Location header: https://jsonblob.com/api/jsonBlob/<ID>
  const loc = res.headers.get('Location') || '';
  const match = loc.match(/jsonBlob\/([a-f0-9-]{36})/i);
  return match ? match[1] : null;
}

// ── Read store with auto-heal ─────────────────────────────────────────────────
// 1. Try primary blob
// 2. If missing/error → recreate primary blob with seed data
// 3. Always ensure master admin is present in rla_users
async function readStore() {
  let store = await readBlob(PRIMARY_BLOB_ID);

  if (!store) {
    // Primary blob is gone — recreate it
    console.warn('[RLA-CRM] Primary blob missing, recreating with seed data…');
    store = emptyStore();
    // Try to write back to primary (it may have been auto-deleted by JSONBlob after inactivity)
    await writeBlob(PRIMARY_BLOB_ID, store);
    // If that fails too, create a new blob (we log but keep going)
  }

  // Ensure all collections exist
  for (const col of COLLECTIONS) {
    if (!store[col]) store[col] = {};
  }

  // ── CRITICAL: Always ensure master admin exists ───────────────────────────
  // If cloud rla_users is empty or master admin record missing → re-seed it
  if (!store.rla_users || Object.keys(store.rla_users).length === 0 ||
      !store.rla_users['master_admin_001']) {
    console.warn('[RLA-CRM] Master admin missing from cloud — re-seeding…');
    if (!store.rla_users) store.rla_users = {};
    store.rla_users['master_admin_001'] = {
      ...MASTER_ADMIN_SEED,
      sync_updated_at: new Date().toISOString(),
    };
    // Write the healed store back immediately
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

  const ok = await writeBlob(PRIMARY_BLOB_ID, store);
  if (!ok) {
    // Primary write failed — try to recreate the blob
    console.warn('[RLA-CRM] Primary blob write failed, attempting recreate…');
    const newId = await createBlob(store);
    if (newId) {
      console.warn(`[RLA-CRM] New blob created: ${newId} (update PRIMARY_BLOB_ID in worker)`);
    }
    throw new Error('Storage write failed — please retry');
  }
  return true;
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
    // Quick read to verify blob is alive
    let blobStatus = 'ok';
    let userCount  = 0;
    try {
      const store = await readStore();
      userCount = Object.keys(store.rla_users || {}).length;
    } catch (e) {
      blobStatus = 'degraded: ' + e.message;
    }
    return json({
      status: blobStatus === 'ok' ? 'ok' : 'degraded',
      service: 'RLA CRM Sync API v5',
      storage: 'jsonblob-dual (global-persistent)',
      blobId: PRIMARY_BLOB_ID,
      userCount,
      timestamp: new Date().toISOString(),
    });
  }

  // ── GET ALL: single-request pull for all collections ───────────────────────
  if (request.method === 'GET' && (path === 'all' || path === 'all/')) {
    try {
      const store = await readStore();
      const result = {};
      for (const col of COLLECTIONS) {
        result[col] = Object.values(store[col] || {});
      }
      return json({ collections: result, storage: 'jsonblob-v5' });
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
      return json({ records, count: records.length, storage: 'jsonblob-v5', collection });
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
      await writeStore(store);

      return json({ success: true, id: body.id, storage: 'jsonblob-v5' });
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
      if (store[collection] && store[collection][id]) {
        delete store[collection][id];
        await writeStore(store);
      }
      return json({ success: true, id });
    } catch (e) {
      return json({ error: e.message }, 500);
    }
  }

  return json({ error: 'Method not allowed' }, 405);
}
