// Smart Rice AI — PWA 서비스 워커
// 기본 셸을 캐시해 설치형 앱으로 동작하게 한다.
// 업데이트가 항상 반영되도록 네트워크 우선(stale-while-revalidate) 전략을 쓴다.
const CACHE_NAME = 'smart-rice-ai-v2';

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) =>
      cache.addAll(['./', './index.html', './manifest.json', './favicon.png']),
    ),
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))),
      ),
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  // API 요청(백엔드)은 항상 네트워크로.
  if (url.pathname.includes('/api/')) return;
  if (event.request.method !== 'GET') return;
  // 네트워크 우선: 실패하면 캐시(오프라인 대체). 성공 시 캐시 갱신.
  event.respondWith(
    fetch(event.request)
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

