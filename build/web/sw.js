// RLA crm — Service Worker v15 (Firebase Firestore)
// Clears all old caches and lets Flutter's own service worker take over.

const CACHE_VERSION = 'rla-crm-v15';

self.addEventListener('install', (event) => {
  // Skip waiting so this SW activates immediately
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  // Delete ALL old caches (v1–v14)
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((k) => k !== CACHE_VERSION)
          .map((k) => {
            console.log('[SW v15] Deleting old cache:', k);
            return caches.delete(k);
          })
      )
    ).then(() => self.clients.claim())
  );
});

// Pass every request straight to the network — let Flutter's service worker handle caching
self.addEventListener('fetch', (event) => {
  // Do nothing — fall through to Flutter's flutter_service_worker.js
});

// Handle SKIP_WAITING message from index.html
self.addEventListener('message', (event) => {
  if (event.data === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});
