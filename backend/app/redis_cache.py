"""
Redis缓存模块
提供高性能的缓存服务，显著提升API响应速度
"""
import json
import logging
import pickle
from typing import Any, Optional, Union
from datetime import datetime, timedelta

try:
    import redis
    from redis.exceptions import RedisError
    REDIS_AVAILABLE = True
except ImportError:
    REDIS_AVAILABLE = False
    redis = None
    RedisError = Exception

from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

class RedisCache:
    """Redis缓存管理器"""
    
    def __init__(self):
        self.redis_client = None
        self.enabled = False
        
        if REDIS_AVAILABLE and settings.USE_REDIS:
            try:
                # 优先使用REDIS_URL，如果不可用则使用单独的环境变量
                if settings.REDIS_URL and not settings.REDIS_URL.startswith("redis://localhost"):
                    # 使用REDIS_URL连接
                    logger.info(f"[DEBUG] Redis连接 - 使用REDIS_URL: {settings.REDIS_URL[:20]}...")
                    self.redis_client = redis.from_url(
                        settings.REDIS_URL,
                        decode_responses=False,  # 使用二进制模式以支持pickle
                        socket_connect_timeout=int(os.getenv("REDIS_CONNECT_TIMEOUT", "5")),
                        socket_timeout=int(os.getenv("REDIS_SOCKET_TIMEOUT", "5")),
                        retry_on_timeout=True,
                        health_check_interval=int(os.getenv("REDIS_HEALTH_CHECK_INTERVAL", "30"))
                    )
                else:
                    # 使用单独的环境变量连接
                    self.redis_client = redis.Redis(
                        host=settings.REDIS_HOST,
                        port=settings.REDIS_PORT,
                        db=settings.REDIS_DB,
                        password=settings.REDIS_PASSWORD,
                        decode_responses=False,  # 使用二进制模式以支持pickle
                        socket_connect_timeout=int(os.getenv("REDIS_CONNECT_TIMEOUT", "5")),
                        socket_timeout=int(os.getenv("REDIS_SOCKET_TIMEOUT", "5")),
                        retry_on_timeout=True,
                        health_check_interval=int(os.getenv("REDIS_HEALTH_CHECK_INTERVAL", "30"))
                    )
                # 测试连接
                self.redis_client.ping()
                self.enabled = True
                logger.info("Redis缓存已启用")
            except Exception as e:
                logger.warning(f"Redis连接失败，使用内存缓存: {e}")
                self.redis_client = None
                self.enabled = False
                # 在Railway环境中，如果Redis连接失败，记录详细信息
                if settings.RAILWAY_ENVIRONMENT:
                    logger.error(f"Railway Redis连接失败 - REDIS_URL: {settings.REDIS_URL}")
                    logger.error(f"Railway Redis连接失败 - USE_REDIS: {settings.USE_REDIS}")
                    logger.error(f"Railway Redis连接失败 - REDIS_AVAILABLE: {REDIS_AVAILABLE}")
        else:
            logger.info("Redis未配置，使用内存缓存")
    
    def _serialize(self, data: Any) -> bytes:
        """序列化数据"""
        try:
            return pickle.dumps(data)
        except Exception as e:
            logger.error(f"序列化失败: {e}")
            return json.dumps(data, default=str).encode('utf-8')
    
    def _deserialize(self, data: bytes) -> Any:
        """反序列化数据"""
        try:
            return pickle.loads(data)
        except Exception:
            try:
                return json.loads(data.decode('utf-8'))
            except Exception as e:
                logger.error(f"反序列化失败: {e}")
                return None
    
    def get(self, key: str) -> Optional[Any]:
        """获取缓存数据"""
        if not self.enabled:
            return None
        
        try:
            data = self.redis_client.get(key)
            if data:
                return self._deserialize(data)
            return None
        except RedisError as e:
            logger.error(f"Redis获取失败: {e}")
            return None
    
    def set(self, key: str, value: Any, ttl: int = 300) -> bool:
        """设置缓存数据"""
        if not self.enabled:
            return False
        
        try:
            serialized_data = self._serialize(value)
            return self.redis_client.setex(key, ttl, serialized_data)
        except RedisError as e:
            logger.error(f"Redis设置失败: {e}")
            return False
    
    def delete(self, key: str) -> bool:
        """删除缓存数据"""
        if not self.enabled:
            return False
        
        try:
            return bool(self.redis_client.delete(key))
        except RedisError as e:
            logger.error(f"Redis删除失败: {e}")
            return False
    
    def delete_pattern(self, pattern: str) -> int:
        """删除匹配模式的所有键"""
        if not self.enabled:
            return 0
        
        try:
            keys = self.redis_client.keys(pattern)
            if keys:
                return self.redis_client.delete(*keys)
            return 0
        except RedisError as e:
            logger.error(f"Redis批量删除失败: {e}")
            return 0
    
    def exists(self, key: str) -> bool:
        """检查键是否存在"""
        if not self.enabled:
            return False
        
        try:
            return bool(self.redis_client.exists(key))
        except RedisError as e:
            logger.error(f"Redis检查存在失败: {e}")
            return False
    
    def get_ttl(self, key: str) -> int:
        """获取键的剩余生存时间"""
        if not self.enabled:
            return -1
        
        try:
            return self.redis_client.ttl(key)
        except RedisError as e:
            logger.error(f"Redis获取TTL失败: {e}")
            return -1
    
    def clear_user_cache(self, user_id: str):
        """清除用户相关的所有缓存"""
        patterns = [
            f"user:{user_id}",
            f"user_tasks:{user_id}",
            f"user_profile:{user_id}",
            f"user_notifications:{user_id}",
            f"user_reviews:{user_id}"
        ]
        
        total_deleted = 0
        for pattern in patterns:
            total_deleted += self.delete_pattern(pattern)
        
        logger.info(f"清除用户 {user_id} 的缓存，共删除 {total_deleted} 个键")
        return total_deleted

# 全局Redis缓存实例
redis_cache = RedisCache()

# 缓存键前缀
CACHE_PREFIXES = {
    'USER': 'user',
    'USER_TASKS': 'user_tasks',
    'USER_PROFILE': 'user_profile',
    'USER_NOTIFICATIONS': 'user_notifications',
    'USER_REVIEWS': 'user_reviews',
    'TASKS': 'tasks',
    'TASK_DETAIL': 'task_detail',
    'NOTIFICATIONS': 'notifications',
    'SYSTEM_SETTINGS': 'system_settings'
}

# 默认TTL配置（秒）
DEFAULT_TTL = {
    'USER_INFO': 300,        # 用户信息5分钟
    'USER_TASKS': 120,       # 用户任务2分钟
    'USER_PROFILE': 300,     # 用户资料5分钟
    'TASKS_LIST': 60,        # 任务列表1分钟
    'TASK_DETAIL': 300,      # 任务详情5分钟
    'NOTIFICATIONS': 30,     # 通知30秒
    'SYSTEM_SETTINGS': 600,  # 系统设置10分钟
    'DEFAULT': 60            # 默认1分钟
}

def get_cache_key(prefix: str, *args) -> str:
    """生成缓存键"""
    return f"{prefix}:{':'.join(str(arg) for arg in args)}"

def cache_user_info(user_id: str, user_data: Any, ttl: int = DEFAULT_TTL['USER_INFO']) -> bool:
    """缓存用户信息"""
    key = get_cache_key(CACHE_PREFIXES['USER'], user_id)
    return redis_cache.set(key, user_data, ttl)

def get_user_info(user_id: str) -> Optional[Any]:
    """获取用户信息缓存"""
    key = get_cache_key(CACHE_PREFIXES['USER'], user_id)
    return redis_cache.get(key)

def cache_user_tasks(user_id: str, tasks_data: Any, ttl: int = DEFAULT_TTL['USER_TASKS']) -> bool:
    """缓存用户任务"""
    key = get_cache_key(CACHE_PREFIXES['USER_TASKS'], user_id)
    return redis_cache.set(key, tasks_data, ttl)

def get_user_tasks(user_id: str) -> Optional[Any]:
    """获取用户任务缓存"""
    key = get_cache_key(CACHE_PREFIXES['USER_TASKS'], user_id)
    return redis_cache.get(key)

def cache_tasks_list(params: dict, tasks_data: Any, ttl: int = DEFAULT_TTL['TASKS_LIST']) -> bool:
    """缓存任务列表"""
    # 生成基于参数的唯一键
    param_str = '_'.join(f"{k}_{v}" for k, v in sorted(params.items()))
    key = get_cache_key(CACHE_PREFIXES['TASKS'], param_str)
    return redis_cache.set(key, tasks_data, ttl)

def get_tasks_list(params: dict) -> Optional[Any]:
    """获取任务列表缓存"""
    param_str = '_'.join(f"{k}_{v}" for k, v in sorted(params.items()))
    key = get_cache_key(CACHE_PREFIXES['TASKS'], param_str)
    return redis_cache.get(key)

def invalidate_user_cache(user_id: str):
    """使用户相关缓存失效"""
    redis_cache.clear_user_cache(user_id)

def invalidate_tasks_cache():
    """使任务相关缓存失效"""
    redis_cache.delete_pattern(f"{CACHE_PREFIXES['TASKS']}:*")
    redis_cache.delete_pattern(f"{CACHE_PREFIXES['TASK_DETAIL']}:*")

def get_redis_client():
    """获取Redis客户端实例"""
    return redis_cache.redis_client if redis_cache.enabled else None
