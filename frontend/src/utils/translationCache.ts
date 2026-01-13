/**
 * 翻译缓存工具
 * 使用 sessionStorage 持久化缓存，避免组件卸载失效
 * 使用稳定的哈希算法生成缓存键
 */
// 缓存版本号（用于失效策略）
const CACHE_VERSION = 'v1';

// 缓存键前缀
const CACHE_PREFIX = `translation_cache_${CACHE_VERSION}`;

// 最大缓存条目数（防止 sessionStorage 过大）
const MAX_CACHE_SIZE = 500;

// 缓存过期时间（7天）
const CACHE_EXPIRY_MS = 7 * 24 * 60 * 60 * 1000;

interface CacheEntry {
  translated: string;
  timestamp: number;
  sourceLang: string;
  targetLang: string;
}

/**
 * 生成稳定的缓存键（使用简单的字符串哈希）
 * ⚠️ 注意：浏览器环境没有 Node.js 的 crypto，使用简单的哈希算法
 * 对于翻译缓存，简单哈希足够（不需要加密强度）
 */
function generateCacheKey(text: string, targetLang: string, sourceLang?: string): string {
  const keyString = `${text}::${sourceLang || 'auto'}::${targetLang}`;
  
  // 使用简单的字符串哈希（类似 Java 的 String.hashCode）
  let hash = 0;
  for (let i = 0; i < keyString.length; i++) {
    const char = keyString.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32bit integer
  }
  
  // 使用 base36 编码缩短键长度
  return `${CACHE_PREFIX}_${Math.abs(hash).toString(36)}`;
}

/**
 * 从 sessionStorage 加载缓存
 */
function loadCacheFromStorage(): Map<string, CacheEntry> {
  const cache = new Map<string, CacheEntry>();
  
  if (typeof window === 'undefined' || !window.sessionStorage) {
    return cache;
  }
  
  try {
    const stored = sessionStorage.getItem(CACHE_PREFIX);
    if (!stored) return cache;
    
    const data = JSON.parse(stored);
    const now = Date.now();
    
    // 过滤过期条目
    for (const [key, entry] of Object.entries(data)) {
      const cacheEntry = entry as CacheEntry;
      if (now - cacheEntry.timestamp < CACHE_EXPIRY_MS) {
        cache.set(key, cacheEntry);
      }
    }
    
    // 如果缓存过大，清理最旧的条目
    if (cache.size > MAX_CACHE_SIZE) {
      const entries = Array.from(cache.entries())
        .sort((a, b) => a[1].timestamp - b[1].timestamp);
      
      cache.clear();
      // 只保留最新的 MAX_CACHE_SIZE 个条目
      entries.slice(-MAX_CACHE_SIZE).forEach(([key, entry]) => {
        cache.set(key, entry);
      });
    }
  } catch (error) {
      }
  
  return cache;
}

/**
 * 保存缓存到 sessionStorage
 */
function saveCacheToStorage(cache: Map<string, CacheEntry>): void {
  if (typeof window === 'undefined' || !window.sessionStorage) {
    return;
  }
  
  try {
    const data: Record<string, CacheEntry> = {};
    cache.forEach((entry, key) => {
      data[key] = entry;
    });
    
    sessionStorage.setItem(CACHE_PREFIX, JSON.stringify(data));
  } catch (error) {
    // sessionStorage 可能已满，清理最旧的条目
    if (error instanceof DOMException && error.code === 22) {
            const entries = Array.from(cache.entries())
        .sort((a, b) => a[1].timestamp - b[1].timestamp);
      
      cache.clear();
      // 只保留最新的 MAX_CACHE_SIZE / 2 个条目
      entries.slice(-Math.floor(MAX_CACHE_SIZE / 2)).forEach(([key, entry]) => {
        cache.set(key, entry);
      });
      
      // 重试保存
      try {
        const data: Record<string, CacheEntry> = {};
        cache.forEach((entry, key) => {
          data[key] = entry;
        });
        sessionStorage.setItem(CACHE_PREFIX, JSON.stringify(data));
      } catch (retryError) {
              }
    } else {
          }
  }
}

// 模块级缓存（单例）
let translationCache: Map<string, CacheEntry> | null = null;

/**
 * 获取翻译缓存实例（单例模式）
 */
function getCache(): Map<string, CacheEntry> {
  if (!translationCache) {
    translationCache = loadCacheFromStorage();
  }
  return translationCache;
}

/**
 * 获取翻译缓存（优化版：更新访问时间，实现LRU）
 */
export function getTranslationCache(
  text: string,
  targetLang: string,
  sourceLang?: string
): string | null {
  const cache = getCache();
  const key = generateCacheKey(text, targetLang, sourceLang);
  const entry = cache.get(key);
  
  if (entry) {
    const now = Date.now();
    if (now - entry.timestamp < CACHE_EXPIRY_MS) {
      // 更新访问时间（LRU策略：最近使用的条目保留）
      entry.timestamp = now;
      cache.set(key, entry);
      return entry.translated;
    } else {
      // 过期，删除
      cache.delete(key);
    }
  }
  
  return null;
}

/**
 * 设置翻译缓存（优化版：LRU淘汰策略）
 */
export function setTranslationCache(
  text: string,
  translated: string,
  targetLang: string,
  sourceLang?: string
): void {
  const cache = getCache();
  const key = generateCacheKey(text, targetLang, sourceLang);
  
  // 如果缓存已满，删除最旧的条目（LRU策略）
  if (cache.size >= MAX_CACHE_SIZE && !cache.has(key)) {
    // 找到最旧的条目
    let oldestKey: string | null = null;
    let oldestTime = Date.now();
    
    for (const [k, entry] of cache.entries()) {
      if (entry.timestamp < oldestTime) {
        oldestTime = entry.timestamp;
        oldestKey = k;
      }
    }
    
    if (oldestKey) {
      cache.delete(oldestKey);
    }
  }
  
  // 更新或添加缓存条目（更新访问时间）
  cache.set(key, {
    translated,
    timestamp: Date.now(),
    sourceLang: sourceLang || 'auto',
    targetLang
  });
  
  // 异步保存到 sessionStorage（避免阻塞）
  // 优化：减少保存频率，每20个条目保存一次
  if (cache.size % 20 === 0) {
    saveCacheToStorage(cache);
  }
}

/**
 * 清除所有翻译缓存
 */
export function clearTranslationCache(): void {
  const cache = getCache();
  cache.clear();
  
  if (typeof window !== 'undefined' && window.sessionStorage) {
    try {
      sessionStorage.removeItem(CACHE_PREFIX);
    } catch (error) {
          }
  }
}

/**
 * 在页面卸载时保存缓存
 */
if (typeof window !== 'undefined') {
  window.addEventListener('beforeunload', () => {
    if (translationCache) {
      saveCacheToStorage(translationCache);
    }
  });
}

