/**
 * RLA CRM Sync API — Cloudflare Pages Function (catch-all)
 *
 * Deployed at: https://rlacrm.com/api/sync/*
 *
 * Provides a simple REST API backed by Cloudflare KV for cross-platform
 * data synchronisation (web ↔ Android ↔ iOS).
 *
 * KV Namespace: RLA_SYNC (must be bound in Cloudflare Pages settings)
 *   Pages → Settings → Functions → KV namespace bindings
 *   Variable name: RLA_SYNC  →  select your KV namespace
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

// Shared secret — must match SyncService._syncKey in Flutter
const API_SECRET = 'rla-crm-sync-2024-xK9mP3nQ';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-Sync-Key',
  'Content-Type': 'application/json',
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: corsHeaders });
}

export async function onRequest(context) {
  const { request, env, params } = context;
  const url = new URL(request.url);
  const path = (params.path || []).join('/');

  // ── Preflight ────────────────────────────────────────────────────────────────
  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  // ── Health check ─────────────────────────────────────────────────────────────
  if (path === 'health' || path === 'health/') {
    return json({
      status: 'ok',
      service: 'RLA CRM Sync API',
      kv: !!env.RLA_SYNC,
      timestamp: new Date().toISOString(),
    });
  }

  // ── Auth check for mutating requests ─────────────────────────────────────────
  const syncKey = request.headers.get('X-Sync-Key');
  if (
    (request.method === 'POST' || request.method === 'DELETE') &&
    syncKey !== API_SECRET
  ) {
    return json({ error: 'Unauthorized' }, 401);
  }

  // ── KV availability ───────────────────────────────────────────────────────────
  const kv = env.RLA_SYNC;
  if (!kv) {
    // KV not bound yet — return empty data so app stays offline-first
    return json({ records: [], count: 0, note: 'KV binding RLA_SYNC not configured' });
  }

  const collection = url.searchParams.get('collection');
  if (!collection || !COLLECTIONS.includes(collection)) {
    return json(
      { error: `Invalid collection. Valid values: ${COLLECTIONS.join(', ')}` },
      400,
    );
  }

  // ── GET: list all records (optionally filtered by ?since=ISO) ─────────────────
  if (request.method === 'GET') {
    try {
      const since = url.searchParams.get('since');
      const listResult = await kv.list({ prefix: `${collection}:` });
      const records = [];

      for (const key of listResult.keys) {
        const value = await kv.get(key.name);
        if (value) {
          try {
            const record = JSON.parse(value);
            if (since) {
              const ts =
                record.sync_updated_at ||
                record.updated_at ||
                record.updatedAt ||
                record.created_at ||
                record.createdAt;
              if (ts && new Date(ts) < new Date(since)) continue;
            }
            records.push(record);
          } catch (_) {}
        }
      }
      return json({ records, count: records.length });
    } catch (e) {
      return json({ error: e.message, records: [] }, 500);
    }
  }

  // ── POST: upsert a record ─────────────────────────────────────────────────────
  if (request.method === 'POST') {
    try {
      const body = await request.json();
      if (!body || !body.id) {
        return json({ error: 'Request body must be JSON with an "id" field' }, 400);
      }
      body.sync_updated_at = new Date().toISOString();
      await kv.put(`${collection}:${body.id}`, JSON.stringify(body));
      return json({ success: true, id: body.id });
    } catch (e) {
      return json({ error: e.message }, 500);
    }
  }

  // ── DELETE: remove a record ───────────────────────────────────────────────────
  if (request.method === 'DELETE') {
    try {
      const id = url.searchParams.get('id');
      if (!id) {
        return json({ error: '"id" query parameter is required' }, 400);
      }
      await kv.delete(`${collection}:${id}`);
      return json({ success: true, id });
    } catch (e) {
      return json({ error: e.message }, 500);
    }
  }

  return json({ error: 'Method not allowed' }, 405);
}
