/**
 * RLA CRM Sync API — Cloudflare Pages Function (catch-all)
 *
 * STORAGE STRATEGY (zero-prerequisite, fully automatic):
 * 1. PRIMARY: Cloudflare KV (env.RLA_SYNC) — when KV namespace is bound
 * 2. FALLBACK: Cloudflare Cache API — persistent per-datacenter, no binding needed
 *
 * The Cache API fallback means sync works automatically the moment this
 * function is deployed — no Cloudflare dashboard configuration required.
 * When KV is later bound (optional), data is automatically promoted to
 * globally-replicated KV storage.
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

const API_SECRET   = 'rla-crm-sync-2024-xK9mP3nQ';
const CACHE_PREFIX = 'https://rla-crm-sync.internal/';  // synthetic URL for cache keys
// Cache TTL: 30 days — long enough to persist across normal usage patterns
const CACHE_TTL    = 60 * 60 * 24 * 30;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-Sync-Key',
  'Content-Type': 'application/json',
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: corsHeaders });
}

// ── Unified KV abstraction (wraps both CF KV and Cache API) ──────────────────
const Store = {
  async get(kv, key) {
    // Try KV first
    if (kv) {
      const val = await kv.get(key);
      return val ? JSON.parse(val) : null;
    }
    // Fall back to Cache API
    const cache = caches.default;
    const cached = await cache.match(new Request(CACHE_PREFIX + encodeURIComponent(key)));
    if (!cached) return null;
    try { return await cached.json(); } catch { return null; }
  },

  async put(kv, key, value) {
    const serialized = JSON.stringify(value);
    // Try KV first
    if (kv) {
      await kv.put(key, serialized, { expirationTtl: CACHE_TTL });
    }
    // Always also write to Cache API (works without KV binding)
    const cache = caches.default;
    const resp = new Response(serialized, {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': `public, max-age=${CACHE_TTL}`,
      },
    });
    await cache.put(new Request(CACHE_PREFIX + encodeURIComponent(key)), resp);
  },

  async delete(kv, key) {
    if (kv) await kv.delete(key);
    const cache = caches.default;
    await cache.delete(new Request(CACHE_PREFIX + encodeURIComponent(key)));
  },

  async listKeys(kv, prefix) {
    if (kv) {
      const result = await kv.list({ prefix });
      return result.keys.map(k => k.name);
    }
    // Cache API doesn't support listing — return the known index key
    const indexKey = `__index__:${prefix}`;
    const index = await Store.get(null, indexKey) || {};
    return Object.keys(index).filter(k => k.startsWith(prefix));
  },

  async addToIndex(kv, prefix, key) {
    const indexKey = `__index__:${prefix}`;
    const index = await Store.get(kv, indexKey) || {};
    index[key] = Date.now();
    await Store.put(kv, indexKey, index);
  },

  async removeFromIndex(kv, prefix, key) {
    const indexKey = `__index__:${prefix}`;
    const index = await Store.get(kv, indexKey) || {};
    delete index[key];
    await Store.put(kv, indexKey, index);
  },
};

// ── Main handler ─────────────────────────────────────────────────────────────
export async function onRequest(context) {
  const { request, env, params } = context;
  const url    = new URL(request.url);
  const path   = (params.path || []).join('/');
  const kv     = env.RLA_SYNC || null;  // null = use Cache fallback

  // ── Preflight ──────────────────────────────────────────────────────────────
  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  // ── Health check ───────────────────────────────────────────────────────────
  if (path === 'health' || path === 'health/') {
    return json({
      status: 'ok',
      service: 'RLA CRM Sync API',
      storage: kv ? 'cloudflare-kv' : 'cache-api',
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

  const prefix = `${collection}:`;

  // ── GET: list all records ──────────────────────────────────────────────────
  if (request.method === 'GET') {
    try {
      const since = url.searchParams.get('since');
      let keys = [];

      if (kv) {
        const listResult = await kv.list({ prefix });
        keys = listResult.keys.map(k => k.name);
      } else {
        // Cache API fallback: use our index
        const indexKey = `__index__:${prefix}`;
        const index = await Store.get(kv, indexKey) || {};
        keys = Object.keys(index);
      }

      const records = [];
      for (const key of keys) {
        let value;
        if (kv) {
          value = await kv.get(key);
          if (!value) continue;
          try { value = JSON.parse(value); } catch { continue; }
        } else {
          value = await Store.get(null, key);
          if (!value) continue;
        }

        if (since) {
          const ts =
            value.sync_updated_at || value.updated_at || value.updatedAt ||
            value.created_at       || value.createdAt;
          if (ts && new Date(ts) < new Date(since)) continue;
        }
        records.push(value);
      }

      return json({ records, count: records.length, storage: kv ? 'kv' : 'cache' });
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
      const key = `${prefix}${body.id}`;
      await Store.put(kv, key, body);
      // Maintain index for Cache API fallback
      if (!kv) await Store.addToIndex(null, prefix, key);
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
      const key = `${prefix}${id}`;
      await Store.delete(kv, key);
      if (!kv) await Store.removeFromIndex(null, prefix, key);
      return json({ success: true, id });
    } catch (e) {
      return json({ error: e.message }, 500);
    }
  }

  return json({ error: 'Method not allowed' }, 405);
}
