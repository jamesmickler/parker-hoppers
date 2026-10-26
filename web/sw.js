// Park Hoppers' background helper (service worker): keeps a copy of the app on the phone so
// it opens instantly, shows "just arrived!" notifications even when the app is closed, and
// opens the right park when one is tapped.

// Filled in by .github/workflows/pages.yml on every publish: the version, and every file in
// web/. A new version makes phones save the new files and use them from the next open.
// Left as-is (local preview), nothing is saved and everything comes from the network.
const VERSION = '__BUILD__';
const FILES = [/*FILES*/];
const CACHE = `park-hoppers-${VERSION}`;
const deployed = !VERSION.startsWith('__');

self.addEventListener('install', (event) => {
  self.skipWaiting();
  if (deployed) event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(['./', ...FILES])));
});

self.addEventListener('activate', (event) => event.waitUntil((async () => {
  // Throw away copies of older versions.
  for (const name of await caches.keys()) {
    if (name !== CACHE) await caches.delete(name);
  }
  await self.clients.claim();
})()));

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  // Supabase, map tiles and anything else on other sites always go straight to the network.
  if (!deployed || event.request.method !== 'GET' || url.origin !== self.location.origin) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    // Any page of the app (…/?invite=CODE included) is the same index.html.
    const saved = event.request.mode === 'navigate' ? await cache.match('./') : await cache.match(event.request);
    return saved || fetch(event.request);
  })());
});

self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch {
    data = { body: event.data?.text() };
  }
  event.waitUntil(self.registration.showNotification(data.title || 'Park Hoppers', {
    body: data.body || '',
    icon: 'icons/icon-192.png',
    badge: 'icons/icon-192.png',
    tag: data.tag,
    data: { url: data.url || './' },
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = new URL(event.notification.data?.url || './', self.registration.scope).href;
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of windows) {
      if ('focus' in client) {
        await client.focus();
        if ('navigate' in client) await client.navigate(url);
        return;
      }
    }
    await self.clients.openWindow(url);
  })());
});
