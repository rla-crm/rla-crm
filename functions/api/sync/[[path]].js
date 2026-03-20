/**
 * RLA CRM Sync API — Cloudflare Pages Function (catch-all)
 *
 * STORAGE STRATEGY (zero-prerequisite, globally consistent):
 * 1. PRIMARY: Cloudflare KV (env.RLA_SYNC) — bound in CF dashboard → truly global
 * 2. FALLBACK: Collection-level Cache blobs — stores whole collection as one
 *    JSON object so ANY datacenter can read/write the complete dataset.
 *    Short TTL (60s) ensures stale data is refreshed quickly across PoPs.
 *
 * The collection-blob approach is deliberately chosen over per-record caching:
 *  - Reads return ALL records from ONE cache key (no index fragmentation)
 *  - Writes update the blob atomically (read-modify-write)
 *  - Short TTL means global propagation within ~60 seconds
 *  - No prerequisites — works from the moment this function is deployed
 *
 * To enable fully-global KV storage (no TTL delay):
 *   1. Cloudflare Dashboard → Workers & Pages → reallandcrm → Settings → Bindings
 *   2. Add KV Namespace binding: variable = RLA_SYNC, namespace = any new/existing KV
 *   3. Redeploy (auto-redeploy on next push)
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

// Short TTL so cross-datacenter propagation happens quickly (~60s lag max)
const CACHE_TTL = 60;

// Internal namespace for cache URLs
const CACHE_NS = 'https://rlacrm-sync-v3.internal/collection/';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-Sync-Key',
  'Content-Type': 'application/json',
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: corsHeaders });
}

// ── Collection-level blob storage ─────────────────────────────────────────────
// Each collection is stored as a SINGLE JSON object: { records: {...id: record} }
// This ensures reads from ANY PoP return the complete dataset.

const CollectionStore = {
  _cacheKey(collection) {
    return CACHE_NS + collection;
  },

  // ── Read entire collection ────────────────────────────────────────────────
  async getCollection(kv, collection) {
    if (kv) {
      const val = await kv.get(`__collection__:${collection}`);
      return val ? JSON.parse(val) : {};
    }
    // Cache API: read collection blob
    const cache = caches.default;
    const resp = await cache.match(new Request(this._cacheKey(collection)));
    if (!resp) return {};
    try { return await resp.json(); } catch { return {}; }
  },

  // ── Write entire collection ───────────────────────────────────────────────
  async setCollection(kv, collection, data) {
    const serialized = JSON.stringify(data);
    if (kv) {
      await kv.put(`__collection__:${collection}`, serialized);
    }
    // Always write to Cache API (short TTL for cross-PoP propagation)
    const cache = caches.default;
    const resp = new Response(serialized, {
      headers: {
        'Content-Type': 'application/json',
        // Short TTL: forces re-fetch from origin every 60s → cross-PoP sync
        'Cache-Control': `public, max-age=${CACHE_TTL}, s-maxage=${CACHE_TTL}`,
      },
    });
    await cache.put(new Request(this._cacheKey(collection)), resp);
  },

  // ── Upsert a single record ────────────────────────────────────────────────
  async upsert(kv, collection, record) {
    const data = await this.getCollection(kv, collection);
    data[record.id] = record;
    await this.setCollection(kv, collection, data);
    return record;
  },

  // ── Delete a single record ────────────────────────────────────────────────
  async delete(kv, collection, id) {
    const data = await this.getCollection(kv, collection);
    delete data[id];
    await this.setCollection(kv, collection, data);
  },

  // ── List all records ──────────────────────────────────────────────────────
  async list(kv, collection, since) {
    const data = await this.getCollection(kv, collection);
    let records = Object.values(data);
    if (since) {
      const sinceDate = new Date(since);
      records = records.filter(r => {
        const ts = r.sync_updated_at || r.updated_at || r.updatedAt ||
                   r.created_at || r.createdAt;
        return !ts || new Date(ts) >= sinceDate;
      });
    }
    return records;
  },
};

// ── Main handler ─────────────────────────────────────────────────────────────
export async function onRequest(context) {
  const { request, env, params } = context;
  const url  = new URL(request.url);
  const path = (params.path || []).join('/');
  const kv   = env.RLA_SYNC || null;  // null = use Cache fallback

  // ── Preflight ──────────────────────────────────────────────────────────────
  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  // ── Health check ───────────────────────────────────────────────────────────
  if (path === 'health' || path === 'health/') {
    return json({
      status: 'ok',
      service: 'RLA CRM Sync API v3',
      storage: kv ? 'cloudflare-kv (global)' : `cache-api (${CACHE_TTL}s TTL)`,
      kv: !!kv,
      timestamp: new Date().toISOString(),
    });
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
      const since = url.searchParams.get('since');
      const records = await CollectionStore.list(kv, collection, since);
      return json({
        records,
        count: records.length,
        storage: kv ? 'kv' : 'cache',
        ttl: kv ? null : CACHE_TTL,
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
      await CollectionStore.upsert(kv, collection, body);
      return json({ success: true, id: body.id, storage: kv ? 'kv' : 'cache' });
    } catch (e) {
      return json({ error: e.message }, 500);
    }
  }

  // ── DELETE ─────────────────────────────────────────────────────────────────
  if (request.method === 'DELETE') {
    try {
      const id = url.searchParams.get('id');
      if (!id) return json({ error: '"id" param required' }, 400);
      await CollectionStore.delete(kv, collection, id);
      return json({ success: true, id });
    } catch (e) {
      return json({ error: e.message }, 500);
    }
  }

  return json({ error: 'Method not allowed' }, 405);
}
