// Smart Rice AI — PWA 서비스 워커
// 업데이트가 항상 반영되도록 네트워크 우선(stale-while-revalidate) 전략을 쓴다.
// v3: 새 버전 감지 시 모든 탭/창을 자동 새로고침해 변경사항이 즉시 보이게 한다.
const CACHE_NAME = 'smart-rice-ai-v3';

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
        // 활성화된 모든 클라이언트(탭/창/PWA 앱)를 강제로 새로고침한다.
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
  // 네트워크 우선: 성공 시 캐시 갱신, 실패(오프라인) 시 캐시 대체.
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
