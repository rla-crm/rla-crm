// RLA CRM — Service Worker v18 (Cache Buster)
// Clears ALL caches including flutter-app-cache
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then(keys => {
      console.log('[SW v18] Clearing caches:', keys);
      return Promise.all(keys.map(key => caches.delete(key)));
    }).then(() => {
      console.log('[SW v18] All caches cleared. Unregistering...');
      return self.registration.unregister();
    })
  );
});
self.addEventListener('fetch', (event) => {
  // Pass all requests through without caching
  event.respondWith(fetch(event.request));
});
