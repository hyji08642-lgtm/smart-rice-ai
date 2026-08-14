// Smart Rice AI — PWA 서비스 워커
// v4: fetch를 항상 네트워크에서 가져와(cache:'no-store') 이전 main.dart.js 캐시 문제 해결.
const CACHE_NAME = 'smart-rice-ai-v4';

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(keys.map((k) => caches.delete(k))),
      )
      .then(() => {
        self.clients.matchAll({ type: 'window' }).then((clients) => {
          clients.forEach((client) => client.navigate(client.url));
        });
        return self.clients.claim();
      }),
  );
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  // API 요청(백엔드)은 항상 네트워크로.
  if (url.pathname.includes('/api/')) return;
  if (event.request.method !== 'GET') return;
  // 네트워크 우선 + 브라우저 HTTP 캐시 무시: 성공 시 캐시 갱신, 실패(오프라인) 시 캐시 대체.
  event.respondWith(
    fetch(event.request, { cache: 'no-store' })
      .then((response) => {
        if (response && response.status === 200) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        }
        return response;
      })
      .catch(() => caches.match(event.request)),
  );
});
