"""
Redis缓存模块
提供高性能的缓存服务，显著提升API响应速度
"""
import os
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
            f"user_tasks:{user_id}*",  # 使用通配符匹配所有用户任务缓存
            f"user_profile:{user_id}",
            f"user_notifications:{user_id}",
            f"user_reviews:{user_id}"
        ]
        
        total_deleted = 0
        for pattern in patterns:
            total_deleted += self.delete_pattern(pattern)
        
        # 只在删除键数大于0时记录日志，减少日志噪音
        if total_deleted > 0:
            logger.debug(f"清除用户 {user_id} 的缓存，共删除 {total_deleted} 个键")
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
    """生成缓存键，对长键进行哈希优化"""
    import hashlib
    
    arg_str = ':'.join(str(arg) for arg in args)
    
    # 如果键太长，使用哈希缩短（避免内存浪费）
    if len(arg_str) > 50:
        arg_hash = hashlib.md5(arg_str.encode()).hexdigest()
        return f"{prefix}:{arg_hash}"
    
    return f"{prefix}:{arg_str}"

def cache_user_info(user_id: str, user_data: Any, ttl: int = DEFAULT_TTL['USER_INFO']) -> bool:
    """缓存用户信息"""
    key = get_cache_key(CACHE_PREFIXES['USER'], user_id)
    return redis_cache.set(key, user_data, ttl)

def get_user_info(user_id: str) -> Optional[Any]:
    """获取用户信息缓存"""
    key = get_cache_key(CACHE_PREFIXES['USER'], user_id)
    return redis_cache.get(key)

def cache_user_tasks(cache_key: str, tasks_data: Any, ttl: int = DEFAULT_TTL['USER_TASKS']) -> bool:
    """缓存用户任务"""
    # 如果传入的是完整的缓存键，直接使用；否则生成标准键
    if ':' in cache_key:
        key = cache_key
    else:
        key = get_cache_key(CACHE_PREFIXES['USER_TASKS'], cache_key)
    return redis_cache.set(key, tasks_data, ttl)

def get_user_tasks(cache_key: str) -> Optional[Any]:
    """获取用户任务缓存"""
    # 如果传入的是完整的缓存键，直接使用；否则生成标准键
    if ':' in cache_key:
        key = cache_key
    else:
        key = get_cache_key(CACHE_PREFIXES['USER_TASKS'], cache_key)
    return redis_cache.get(key)

def get_tasks_cache_key(skip: int, limit: int, task_type: Optional[str], 
                        location: Optional[str], status: Optional[str],
                        keyword: Optional[str], sort_by: Optional[str]) -> str:
    """生成任务列表缓存键（使用哈希避免键过长）"""
    import hashlib
    import json
    
    # 构建参数字典
    params = {
        "skip": skip,
        "limit": limit,
        "task_type": task_type or "all",
        "location": location or "all",
        "status": status or "all",
        "keyword": keyword or "",
        "sort_by": sort_by or "latest"
    }
    
    # 对参数进行哈希（避免键过长）
    params_str = json.dumps(params, sort_keys=True)
    params_hash = hashlib.md5(params_str.encode()).hexdigest()[:16]
    
    # 使用版本号和哈希
    version = get_cache_version("tasks")
    return f"tasks:list:v{version}:{params_hash}"

def get_tasks_count_cache_key(task_type: Optional[str], 
                              location: Optional[str], 
                              status: Optional[str],
                              keyword: Optional[str]) -> str:
    """生成任务总数缓存键（与列表缓存键结构统一，只包含参与 count 的过滤条件）"""
    import hashlib
    import json
    
    # 构建参数字典（不包含 skip/limit/sort_by，这些不影响总数）
    params = {
        "task_type": task_type or "all",
        "location": location or "all",
        "status": status or "all",
        "keyword": keyword or ""
    }
    
    # 对参数进行哈希
    params_str = json.dumps(params, sort_keys=True)
    params_hash = hashlib.md5(params_str.encode()).hexdigest()[:16]
    
    # 使用版本号和哈希（与列表缓存键结构统一）
    version = get_cache_version("tasks")
    return f"tasks:count:v{version}:{params_hash}"

def get_cache_version(cache_type: str) -> int:
    """获取缓存版本号（用于缓存失效）"""
    # 简单实现：从环境变量或Redis获取版本号
    # 如果Redis不可用，返回固定版本号
    try:
        version_key = f"cache_version:{cache_type}"
        version = redis_cache.get(version_key)
        if version is None:
            redis_cache.set(version_key, 1, ttl=86400 * 365)  # 1年
            return 1
        return int(version) if isinstance(version, (int, str)) else 1
    except Exception:
        return 1

def cache_tasks_list(params: dict, tasks_data: Any, ttl: int = DEFAULT_TTL['TASKS_LIST']) -> bool:
    """缓存任务列表（使用新的缓存键设计）"""
    key = get_tasks_cache_key(
        skip=params.get('skip', 0),
        limit=params.get('limit', 20),
        task_type=params.get('task_type'),
        location=params.get('location'),
        status=params.get('status'),
        keyword=params.get('keyword'),
        sort_by=params.get('sort_by')
    )
    return redis_cache.set(key, tasks_data, ttl)

def get_tasks_list(params: dict) -> Optional[Any]:
    """获取任务列表缓存（使用新的缓存键设计）"""
    key = get_tasks_cache_key(
        skip=params.get('skip', 0),
        limit=params.get('limit', 20),
        task_type=params.get('task_type'),
        location=params.get('location'),
        status=params.get('status'),
        keyword=params.get('keyword'),
        sort_by=params.get('sort_by')
    )
    return redis_cache.get(key)

def cache_tasks_list_safe(params: dict, fetch_fn, ttl: int = DEFAULT_TTL['TASKS_LIST']) -> Any:
    """安全的任务列表缓存，防止缓存穿透和雪崩"""
    param_str = '_'.join(f"{k}_{v}" for k, v in sorted(params.items()))
    key = get_cache_key(CACHE_PREFIXES['TASKS'], param_str)
    
    # 1. 先查缓存
    cached = redis_cache.get(key)
    if cached is not None:
        return cached
    
    # 2. 查询数据库
    try:
        tasks = fetch_fn()
        
        # 3. 缓存结果
        if tasks:
            # 正常数据，正常TTL
            redis_cache.set(key, tasks, ttl)
        else:
            # 空结果，设置较长TTL防止穿透
            redis_cache.set(key, [], ttl=ttl * 5)
        
        return tasks
    except Exception as e:
        logger.error(f"获取任务列表失败: {e}")
        # 失败时缓存空结果，防止反复查数据库
        redis_cache.set(key, [], ttl=ttl)
        return []

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
