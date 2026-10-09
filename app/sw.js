/* BITFIRST service worker - network first for the page, cache for offline */
var CACHE = 'bitfirst-v5';
self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (e) {
  e.waitUntil((async function () {
    var ks = await caches.keys();
    await Promise.all(ks.filter(function (k) { return k !== CACHE; }).map(function (k) { return caches.delete(k); }));
    await self.clients.claim();
  })());
});
self.addEventListener('fetch', function (e) {
  var r = e.request;
  if (r.method !== 'GET') return;
  var u; try { u = new URL(r.url); } catch (x) { return; }
  if (u.origin !== self.location.origin) return;
  if (r.mode === 'navigate') {
    e.respondWith((async function () {
      try {
        var res = await fetch(r);
        var c = await caches.open(CACHE);
        c.put('/', res.clone());
        return res;
      } catch (err) {
        var c2 = await caches.open(CACHE);
        var hit = await c2.match('/');
        return hit || new Response('Offline', { status: 503, headers: { 'Content-Type': 'text/plain' } });
      }
    })());
    return;
  }
  e.respondWith((async function () {
    var c = await caches.open(CACHE);
    var hit = await c.match(r);
    if (hit) return hit;
    try { var res = await fetch(r); if (res && res.ok) c.put(r, res.clone()); return res; }
    catch (err) { return new Response('', { status: 504 }); }
  })());
});
