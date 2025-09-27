"""
简单的内存缓存模块
用于缓存用户信息等频繁访问的数据
"""
import time
from typing import Any, Dict, Optional
from threading import Lock

class SimpleCache:
    """简单的内存缓存实现"""
    
    def __init__(self, default_ttl: int = 300):  # 默认5分钟过期
        self._cache: Dict[str, Dict[str, Any]] = {}
        self._lock = Lock()
        self.default_ttl = default_ttl
    
    def get(self, key: str) -> Optional[Any]:
        """获取缓存值"""
        with self._lock:
            if key in self._cache:
                item = self._cache[key]
                if time.time() < item['expires_at']:
                    return item['value']
                else:
                    # 过期，删除
                    del self._cache[key]
            return None
    
    def set(self, key: str, value: Any, ttl: Optional[int] = None) -> None:
        """设置缓存值"""
        with self._lock:
            expires_at = time.time() + (ttl or self.default_ttl)
            self._cache[key] = {
                'value': value,
                'expires_at': expires_at
            }
    
    def delete(self, key: str) -> None:
        """删除缓存值"""
        with self._lock:
            if key in self._cache:
                del self._cache[key]
    
    def clear(self) -> None:
        """清空所有缓存"""
        with self._lock:
            self._cache.clear()
    
    def cleanup_expired(self) -> None:
        """清理过期的缓存项"""
        with self._lock:
            current_time = time.time()
            expired_keys = [
                key for key, item in self._cache.items()
                if current_time >= item['expires_at']
            ]
            for key in expired_keys:
                del self._cache[key]

# 全局缓存实例
user_cache = SimpleCache(default_ttl=300)  # 用户信息缓存5分钟
task_cache = SimpleCache(default_ttl=60)   # 任务信息缓存1分钟
