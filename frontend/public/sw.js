// Service Worker for Link²Ur PWA
const CACHE_NAME = 'link2ur-v1';
const RUNTIME_CACHE = 'link2ur-runtime-v1';

// 需要预缓存的静态资源
const urlsToCache = [
  '/',
  '/static/favicon.png',
  '/static/favicon.ico',
  '/static/logo.png',
  '/static/background.jpg',
  '/manifest.json',
];

// 判断是否为静态资源
function isStaticResource(url) {
  const staticExtensions = ['.js', '.css', '.png', '.jpg', '.jpeg', '.webp', '.avif', '.svg', '.woff2', '.woff', '.ttf', '.ico'];
  const urlPath = new URL(url).pathname;
  return staticExtensions.some(ext => urlPath.endsWith(ext)) || 
         urlPath === '/' || 
         urlPath.startsWith('/static/');
}

// 判断是否为API请求
function isApiRequest(url) {
  return url.includes('/api/') || 
         url.includes('/graphql') ||
         url.includes('/ws/');
}

// 安装Service Worker
self.addEventListener('install', (event) => {
  console.log('[Service Worker] Installing...');
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[Service Worker] Caching app shell');
        return cache.addAll(urlsToCache);
      })
      .catch((error) => {
        console.error('[Service Worker] Cache failed:', error);
      })
  );
  // 立即激活新版本
  self.skipWaiting();
});

// 激活Service Worker
self.addEventListener('activate', (event) => {
  console.log('[Service Worker] Activating...');
  const cacheWhitelist = [CACHE_NAME, RUNTIME_CACHE];
  
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (!cacheWhitelist.includes(cacheName)) {
            console.log('[Service Worker] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  // 立即接管所有页面
  return self.clients.claim();
});

// 拦截网络请求
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // 跳过非GET请求
  if (request.method !== 'GET') {
    return;
  }

  // 跳过API请求，直接走网络
  if (isApiRequest(url.href)) {
    event.respondWith(
      fetch(request).catch(() => {
        // 网络失败时返回离线提示
        return new Response(
          JSON.stringify({ error: '网络连接失败，请检查您的网络设置' }),
          {
            headers: { 'Content-Type': 'application/json' },
            status: 503
          }
        );
      })
    );
    return;
  }

  // 处理导航请求（页面访问）
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then((response) => {
          // 网络成功，缓存并返回
          const responseToCache = response.clone();
          caches.open(RUNTIME_CACHE).then((cache) => {
            cache.put(request, responseToCache);
          });
          return response;
        })
        .catch(() => {
          // 网络失败，尝试从缓存获取
          return caches.match('/').then((cachedResponse) => {
            if (cachedResponse) {
              return cachedResponse;
            }
            // 如果缓存也没有，返回离线页面
            return new Response(
              '<!DOCTYPE html><html><head><title>离线</title></head><body><h1>您当前处于离线状态</h1><p>请检查您的网络连接</p></body></html>',
              {
                headers: { 'Content-Type': 'text/html' },
                status: 200
              }
            );
          });
        })
    );
    return;
  }

  // 处理静态资源：使用缓存优先策略
  if (isStaticResource(url.href)) {
    event.respondWith(
      caches.match(request)
        .then((cachedResponse) => {
          // 缓存命中，直接返回
          if (cachedResponse) {
            return cachedResponse;
          }
          
          // 缓存未命中，请求网络
          return fetch(request)
            .then((response) => {
              // 只缓存有效的同源响应
              if (response && response.status === 200 && response.type === 'basic') {
                const responseToCache = response.clone();
                caches.open(RUNTIME_CACHE).then((cache) => {
                  cache.put(request, responseToCache);
                });
              }
              return response;
            })
            .catch(() => {
              // 网络失败，返回占位符或空响应
              if (request.destination === 'image') {
                // 图片加载失败时返回透明1x1像素
                return new Response(
                  'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
                  {
                    headers: { 'Content-Type': 'image/gif' }
                  }
                );
              }
              return new Response('', { status: 404 });
            });
        })
    );
    return;
  }

  // 其他请求：网络优先策略
  event.respondWith(
    fetch(request)
      .then((response) => {
        // 网络成功，缓存并返回
        if (response && response.status === 200) {
          const responseToCache = response.clone();
          caches.open(RUNTIME_CACHE).then((cache) => {
            cache.put(request, responseToCache);
          });
        }
        return response;
      })
      .catch(() => {
        // 网络失败，尝试从缓存获取
        return caches.match(request);
      })
  );
});

// 处理消息（用于更新通知等）
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

