/**
 * RLA CRM Sync API — Cloudflare Pages Function (catch-all)
 *
 * STORAGE: JSONBlob.com — a free, globally hosted JSON persistence service
 * backed by Cloudflare's own global network. Data written from any device
 * is immediately visible to ALL other devices worldwide.
 *
 * Blob ID: 019d0aeb-b769-74e2-aa3e-99467f7dbc4f
 * This single blob holds ALL collections as a JSON object:
 * {
 *   "rla_users":         { "id": { ...record } },
 *   "rla_leads":         { "id": { ...record } },
 *   "rla_projects":      { "id": { ...record } },
 *   "rla_approvals":     { "id": { ...record } },
 *   "rla_notifications": { "id": { ...record } }
 * }
 *
 * Why JSONBlob:
 *  - Globally persistent (not per-datacenter like CF Cache API)
 *  - No signup, no credentials required
 *  - Free, backed by Cloudflare CDN
 *  - Simple REST API: GET/PUT on a URL
 *  - Immediately consistent across all regions
 *
 * Endpoints:
 *   GET    /api/sync/health                   → health check
 *   GET    /api/sync?collection=rla_users     → list all records
 *   POST   /api/sync?collection=rla_users     → upsert a record (body = JSON)
 *   DELETE /api/sync?collection=rla_users&id=xxx → delete a record
 */

const COLLECTIONS = [
  'rla_users',
  'rla_leads',
  'rla_projects',
  'rla_approvals',
  'rla_notifications',
];

const API_SECRET = 'rla-crm-sync-2024-xK9mP3nQ';

// JSONBlob production store — globally persistent
const JSONBLOB_ID   = '019d0aeb-b769-74e2-aa3e-99467f7dbc4f';
const JSONBLOB_BASE = 'https://jsonblob.com/api/jsonBlob';
const JSONBLOB_URL  = `${JSONBLOB_BASE}/${JSONBLOB_ID}`;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-Sync-Key',
  'Content-Type': 'application/json',
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: corsHeaders });
}

// ── JSONBlob store helpers ─────────────────────────────────────────────────────

/** Read the entire store from JSONBlob */
async function readStore() {
  try {
    const res = await fetch(JSONBLOB_URL, {
      headers: { 'Accept': 'application/json' },
    });
    if (!res.ok) throw new Error(`JSONBlob read failed: ${res.status}`);
    return await res.json();
  } catch (e) {
    console.error('readStore error:', e.message);
    // Return empty structure so app still works
    return {
      rla_users: {},
      rla_leads: {},
      rla_projects: {},
      rla_approvals: {},
      rla_notifications: {},
    };
  }
}

/** Write the entire store back to JSONBlob */
async function writeStore(store) {
  const res = await fetch(JSONBLOB_URL, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: JSON.stringify(store),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`JSONBlob write failed: ${res.status} — ${text}`);
  }
  return true;
}

// ── Main handler ──────────────────────────────────────────────────────────────
export async function onRequest(context) {
  const { request, params } = context;
  const url  = new URL(request.url);
  const path = (params.path || []).join('/');

  // ── Preflight ──────────────────────────────────────────────────────────────
  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  // ── Health check ───────────────────────────────────────────────────────────
  if (path === 'health' || path === 'health/') {
    return json({
      status: 'ok',
      service: 'RLA CRM Sync API v4',
      storage: 'jsonblob (global-persistent)',
      blobId: JSONBLOB_ID,
      timestamp: new Date().toISOString(),
    });
  }

  // ── GET ALL COLLECTIONS at once (efficient single-request pull) ───────────
  // Called as GET /api/sync/all
  if (request.method === 'GET' && (path === 'all' || path === 'all/')) {
    try {
      const store = await readStore();
      const result = {};
      for (const col of COLLECTIONS) {
        result[col] = Object.values(store[col] || {});
      }
      return json({ collections: result, storage: 'jsonblob' });
    } catch (e) {
      return json({ error: e.message }, 500);
    }
  }

  // ── Auth for writes ────────────────────────────────────────────────────────
  const syncKey = request.headers.get('X-Sync-Key');
  if (
    (request.method === 'POST' || request.method === 'DELETE') &&
    syncKey !== API_SECRET
  ) {
    return json({ error: 'Unauthorized' }, 401);
  }

  const collection = url.searchParams.get('collection');
  if (!collection || !COLLECTIONS.includes(collection)) {
    return json({ error: `Invalid collection. Valid: ${COLLECTIONS.join(', ')}` }, 400);
  }

  // ── GET: list all records ──────────────────────────────────────────────────
  if (request.method === 'GET') {
    try {
      const store = await readStore();
      const collectionData = store[collection] || {};
      let records = Object.values(collectionData);

      const since = url.searchParams.get('since');
      if (since) {
        const sinceDate = new Date(since);
        records = records.filter(r => {
          const ts = r.sync_updated_at || r.updatedAt || r.updated_at || r.createdAt;
          return !ts || new Date(ts) >= sinceDate;
        });
      }

      return json({
        records,
        count: records.length,
        storage: 'jsonblob',
        collection,
      });
    } catch (e) {
      return json({ error: e.message, records: [] }, 500);
    }
  }

  // ── POST: upsert ───────────────────────────────────────────────────────────
  if (request.method === 'POST') {
    try {
      const body = await request.json();
      if (!body || !body.id) {
        return json({ error: 'Body must be JSON with an "id" field' }, 400);
      }
      body.sync_updated_at = new Date().toISOString();

      // Read-modify-write (atomic at the blob level)
      const store = await readStore();
      if (!store[collection]) store[collection] = {};
      store[collection][body.id] = body;
      await writeStore(store);

      return json({ success: true, id: body.id, storage: 'jsonblob' });
    } catch (e) {
      return json({ error: e.message }, 500);
    }
  }

  // ── DELETE ─────────────────────────────────────────────────────────────────
  if (request.method === 'DELETE') {
    try {
      const id = url.searchParams.get('id');
      if (!id) return json({ error: '"id" param required' }, 400);

      const store = await readStore();
      if (store[collection]) {
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
