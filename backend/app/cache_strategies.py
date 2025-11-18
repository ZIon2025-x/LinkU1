"""
智能缓存策略
根据数据特性和访问模式优化缓存策略
"""

from typing import Any, Optional, Dict, List
from datetime import datetime, timedelta
import json
import hashlib
from functools import wraps

from app.redis_cache import redis_cache
from app.config import Config
import logging

logger = logging.getLogger(__name__)


class CacheStrategy:
    """缓存策略基类"""
    
    @staticmethod
    def generate_cache_key(prefix: str, *args, **kwargs) -> str:
        """生成缓存键"""
        # 将参数序列化为字符串
        key_parts = [str(arg) for arg in args]
        key_parts.extend([f"{k}={v}" for k, v in sorted(kwargs.items())])
        
        # 生成哈希值避免键过长
        key_string = ":".join(key_parts)
        if len(key_string) > 200:  # Redis键长度限制
            key_hash = hashlib.md5(key_string.encode()).hexdigest()
            return f"{prefix}:{key_hash}"
        
        return f"{prefix}:{key_string}"


class UserCacheStrategy(CacheStrategy):
    """用户数据缓存策略"""
    
    # 用户信息缓存时间（分钟）
    USER_INFO_TTL = 30
    USER_STATS_TTL = 10
    USER_TASKS_TTL = 5
    
    @staticmethod
    def cache_user_info(user_id: str, user_data: Any) -> bool:
        """缓存用户基本信息
        
        注意：此方法已被弃用，请使用 redis_cache.cache_user_info
        保留此方法仅用于向后兼容。
        """
        # 使用统一的缓存函数，确保格式转换
        from app.redis_cache import cache_user_info
        return cache_user_info(user_id, user_data, UserCacheStrategy.USER_INFO_TTL * 60)
    
    @staticmethod
    def get_user_info(user_id: str) -> Optional[Any]:
        """获取用户基本信息"""
        key = CacheStrategy.generate_cache_key("user", user_id)
        return redis_cache.get(key)
    
    @staticmethod
    def cache_user_stats(user_id: str, stats: Dict[str, Any]) -> bool:
        """缓存用户统计信息"""
        key = CacheStrategy.generate_cache_key("user_stats", user_id)
        return redis_cache.set(key, stats, UserCacheStrategy.USER_STATS_TTL * 60)
    
    @staticmethod
    def get_user_stats(user_id: str) -> Optional[Dict[str, Any]]:
        """获取用户统计信息"""
        key = CacheStrategy.generate_cache_key("user_stats", user_id)
        return redis_cache.get(key)
    
    @staticmethod
    def invalidate_user_cache(user_id: str) -> None:
        """使用户相关缓存失效"""
        patterns = [
            f"user:{user_id}",
            f"user_stats:{user_id}",
            f"user_tasks:{user_id}:*",
            f"user_dashboard:{user_id}"
        ]
        
        for pattern in patterns:
            redis_cache.delete_pattern(pattern)


class TaskCacheStrategy(CacheStrategy):
    """任务数据缓存策略"""
    
    # 任务缓存时间（分钟）
    TASK_LIST_TTL = 5
    TASK_DETAIL_TTL = 15
    TASK_STATS_TTL = 10
    
    @staticmethod
    def cache_task_list(params: Dict[str, Any], tasks: List[Any]) -> bool:
        """缓存任务列表"""
        key = CacheStrategy.generate_cache_key("tasks", **params)
        return redis_cache.set(key, tasks, TaskCacheStrategy.TASK_LIST_TTL * 60)
    
    @staticmethod
    def get_task_list(params: Dict[str, Any]) -> Optional[List[Any]]:
        """获取任务列表缓存"""
        key = CacheStrategy.generate_cache_key("tasks", **params)
        return redis_cache.get(key)
    
    @staticmethod
    def cache_task_detail(task_id: int, task: Any) -> bool:
        """缓存任务详情"""
        key = CacheStrategy.generate_cache_key("task_detail", task_id)
        return redis_cache.set(key, task, TaskCacheStrategy.TASK_DETAIL_TTL * 60)
    
    @staticmethod
    def get_task_detail(task_id: int) -> Optional[Any]:
        """获取任务详情缓存"""
        key = CacheStrategy.generate_cache_key("task_detail", task_id)
        return redis_cache.get(key)
    
    @staticmethod
    def invalidate_task_cache(task_id: Optional[int] = None) -> None:
        """使任务相关缓存失效"""
        if task_id:
            # 失效特定任务的缓存
            patterns = [
                f"task_detail:{task_id}",
                f"task_stats:{task_id}"
            ]
        else:
            # 失效所有任务列表缓存
            patterns = [
                "tasks:*",
                "task_stats:*"
            ]
        
        for pattern in patterns:
            redis_cache.delete_pattern(pattern)


class MessageCacheStrategy(CacheStrategy):
    """消息数据缓存策略"""
    
    # 消息缓存时间（分钟）
    MESSAGE_LIST_TTL = 2
    CONVERSATION_TTL = 5
    
    @staticmethod
    def cache_conversation(user1_id: str, user2_id: str, messages: List[Any]) -> bool:
        """缓存对话消息"""
        # 确保键的一致性（按字母顺序排序用户ID）
        users = sorted([user1_id, user2_id])
        key = CacheStrategy.generate_cache_key("conversation", *users)
        return redis_cache.set(key, messages, MessageCacheStrategy.CONVERSATION_TTL * 60)
    
    @staticmethod
    def get_conversation(user1_id: str, user2_id: str) -> Optional[List[Any]]:
        """获取对话消息缓存"""
        users = sorted([user1_id, user2_id])
        key = CacheStrategy.generate_cache_key("conversation", *users)
        return redis_cache.get(key)
    
    @staticmethod
    def invalidate_conversation_cache(user1_id: str, user2_id: str) -> None:
        """使对话缓存失效"""
        users = sorted([user1_id, user2_id])
        key = CacheStrategy.generate_cache_key("conversation", *users)
        redis_cache.delete(key)


class CacheDecorator:
    """缓存装饰器"""
    
    @staticmethod
    def cache_result(strategy: CacheStrategy, ttl: int = 300):
        """缓存函数结果的装饰器"""
        def decorator(func):
            @wraps(func)
            def wrapper(*args, **kwargs):
                # 生成缓存键
                cache_key = strategy.generate_cache_key(
                    func.__name__, 
                    *args, 
                    **{k: v for k, v in kwargs.items() if k != 'db'}
                )
                
                # 尝试从缓存获取
                cached_result = redis_cache.get(cache_key)
                if cached_result is not None:
                    logger.debug(f"Cache hit for {func.__name__}")
                    return cached_result
                
                # 缓存未命中，执行函数
                result = func(*args, **kwargs)
                
                # 缓存结果
                redis_cache.set(cache_key, result, ttl)
                logger.debug(f"Cache miss for {func.__name__}, cached result")
                
                return result
            
            return wrapper
        return decorator
    
    @staticmethod
    def cache_invalidate(strategy: CacheStrategy, pattern: str):
        """缓存失效装饰器"""
        def decorator(func):
            @wraps(func)
            def wrapper(*args, **kwargs):
                result = func(*args, **kwargs)
                
                # 使相关缓存失效
                redis_cache.delete_pattern(pattern)
                logger.debug(f"Invalidated cache pattern: {pattern}")
                
                return result
            
            return wrapper
        return decorator


class SmartCacheManager:
    """智能缓存管理器"""
    
    def __init__(self):
        self.user_strategy = UserCacheStrategy()
        self.task_strategy = TaskCacheStrategy()
        self.message_strategy = MessageCacheStrategy()
    
    def get_cache_hit_rate(self) -> Dict[str, float]:
        """获取缓存命中率统计"""
        if not redis_cache.enabled:
            return {"error": "Redis not available"}
        
        try:
            # 获取Redis信息
            info = redis_cache.redis_client.info()
            
            hits = info.get('keyspace_hits', 0)
            misses = info.get('keyspace_misses', 0)
            total = hits + misses
            
            hit_rate = (hits / total * 100) if total > 0 else 0
            
            return {
                "hit_rate": round(hit_rate, 2),
                "hits": hits,
                "misses": misses,
                "total_requests": total
            }
        except Exception as e:
            logger.error(f"Error getting cache hit rate: {e}")
            return {"error": str(e)}
    
    def warm_up_cache(self, db) -> None:
        """预热缓存"""
        logger.info("Starting cache warm-up...")
        
        try:
            # 预热热门任务列表
            from app.query_optimizer import query_optimizer
            popular_tasks = query_optimizer.get_tasks_with_relations(
                db, limit=20, sort_by='latest'
            )
            self.task_strategy.cache_task_list(
                {'limit': 20, 'sort_by': 'latest'}, 
                popular_tasks
            )
            
            # 预热系统设置
            from app.models import SystemSettings
            settings = db.query(SystemSettings).all()
            for setting in settings:
                redis_cache.set(
                    f"system_setting:{setting.setting_key}",
                    setting.setting_value,
                    3600  # 1小时
                )
            
            logger.info("Cache warm-up completed")
            
        except Exception as e:
            logger.error(f"Cache warm-up failed: {e}")
    
    def cleanup_expired_cache(self) -> None:
        """清理过期缓存"""
        if not redis_cache.enabled:
            return
        
        try:
            # Redis会自动清理过期的键，这里可以添加额外的清理逻辑
            logger.info("Cache cleanup completed")
        except Exception as e:
            logger.error(f"Cache cleanup failed: {e}")


# 创建全局缓存管理器
cache_manager = SmartCacheManager()
