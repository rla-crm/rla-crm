// RLA crm — Service Worker
// v5 — Dual-blob storage, master admin always seeded, 3-attempt login sync

const CACHE_NAME = 'rla-crm-v5';

// Core assets to cache on install (app shell)
const CORE_ASSETS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/favicon.png',
  '/flutter_bootstrap.js',
  '/main.dart.js',
  '/flutter.js',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/icons/Icon-maskable-192.png',
  '/icons/Icon-maskable-512.png',
];

// ── Install: cache app shell ──────────────────────────────────
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('[SW] Caching app shell v4');
      // Use addAll but don't fail if individual assets are missing
      return Promise.allSettled(
        CORE_ASSETS.map(url => cache.add(url).catch(() => {}))
      );
    }).then(() => self.skipWaiting())
  );
});

// ── Activate: clean old caches ────────────────────────────────
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter(name => name !== CACHE_NAME)
          .map(name => {
            console.log('[SW] Deleting old cache:', name);
            return caches.delete(name);
          })
      );
    }).then(() => self.clients.claim())
  );
});

// ── Fetch: network-first with cache fallback ──────────────────
self.addEventListener('fetch', (event) => {
  // Only handle GET requests
  if (event.request.method !== 'GET') return;

  // Skip cross-origin requests (API calls to rlacrm.com must go directly to network)
  if (!event.request.url.startsWith(self.location.origin)) return;

  // Never cache API sync calls — always fetch fresh data
  if (event.request.url.includes('/api/sync')) return;
  if (event.request.url.includes('jsonblob.com')) return;

  event.respondWith(
    fetch(event.request)
      .then((networkResponse) => {
        // Cache a copy of the successful network response
        if (networkResponse && networkResponse.status === 200) {
          const responseClone = networkResponse.clone();
          caches.open(CACHE_NAME).then(cache => {
            cache.put(event.request, responseClone);
          });
        }
        return networkResponse;
      })
      .catch(() => {
        // Network failed → serve from cache
        return caches.match(event.request).then(cached => {
          if (cached) return cached;
          // Last resort: return cached index.html for navigation requests
          if (event.request.mode === 'navigate') {
            return caches.match('/index.html');
          }
        });
      })
  );
});

// ── Background sync / push (future use) ──────────────────────
self.addEventListener('message', (event) => {
  if (event.data === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

// Force all open tabs to reload when new SW takes over
self.addEventListener('controllerchange', () => {
  self.clients.matchAll({ type: 'window' }).then(clients => {
    clients.forEach(client => client.navigate(client.url));
  });
});
