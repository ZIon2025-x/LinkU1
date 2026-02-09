"""
API响应缓存装饰器
使用Redis实现API响应缓存，提升性能
"""
import hashlib
import json
import logging
from functools import wraps
from typing import Any, Callable, Optional
from app.redis_cache import get_redis_client

logger = logging.getLogger(__name__)


def _convert_to_serializable(obj: Any) -> Any:
    """
    将对象转换为可序列化的格式
    处理 Pydantic 模型、字典、列表等
    """
    # 如果是 Pydantic 模型，转换为字典
    if hasattr(obj, 'model_dump'):
        return obj.model_dump()
    elif hasattr(obj, 'dict'):
        return obj.dict()
    
    # 如果是字典，递归处理值
    if isinstance(obj, dict):
        return {k: _convert_to_serializable(v) for k, v in obj.items()}
    
    # 如果是列表或元组，递归处理元素
    if isinstance(obj, (list, tuple)):
        return [_convert_to_serializable(item) for item in obj]
    
    # 其他类型直接返回
    return obj


def cache_response(ttl: int = 300, key_prefix: str = "cache"):
    """
    API响应缓存装饰器
    
    Args:
        ttl: 缓存过期时间（秒），默认5分钟
        key_prefix: 缓存键前缀
    
    Usage:
        @cache_response(ttl=600, key_prefix="tasks")
        async def get_tasks():
            ...
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            redis_client = get_redis_client()
            if not redis_client:
                # Redis不可用时，直接执行函数
                return await func(*args, **kwargs)
            
            try:
                # 生成缓存键（基于函数名和参数）
                # 排除request对象（不可序列化）
                cache_params = {
                    k: v for k, v in kwargs.items() 
                    if k != 'request' and k != 'db' and not k.startswith('_')
                }
                # 将参数转换为可序列化的格式
                params_str = json.dumps(cache_params, sort_keys=True, default=str)
                cache_key = f"{key_prefix}:{func.__name__}:{hashlib.md5(params_str.encode()).hexdigest()}"
                
                # 尝试从缓存获取
                cached = redis_client.get(cache_key)
                if cached:
                    try:
                        cached_data = json.loads(cached)
                        # 检查缓存数据格式是否正确（应该是字典，不是字符串）
                        if isinstance(cached_data, str):
                            # 旧格式的缓存（字符串），清除它
                            logger.warning(f"检测到旧格式缓存（字符串），已清除: {cache_key}")
                            redis_client.delete(cache_key)
                        else:
                            logger.debug(f"缓存命中: {cache_key}")
                            return cached_data
                    except json.JSONDecodeError:
                        logger.warning(f"缓存数据格式错误，已清除: {cache_key}")
                        redis_client.delete(cache_key)
                
                # 执行函数
                result = await func(*args, **kwargs)
                
                # 存储到缓存（只缓存可序列化的结果）
                try:
                    # 将 Pydantic 模型转换为字典
                    serializable_result = _convert_to_serializable(result)
                    result_str = json.dumps(serializable_result, default=str)
                    redis_client.setex(cache_key, ttl, result_str)
                    logger.debug(f"缓存已设置: {cache_key}, TTL: {ttl}秒")
                except (TypeError, ValueError) as e:
                    logger.warning(f"无法缓存结果（不可序列化）: {cache_key}, 错误: {e}")
                
                return result
            except Exception as e:
                logger.error(f"缓存操作失败: {e}", exc_info=True)
                # 缓存失败不影响主功能，直接执行函数
                return await func(*args, **kwargs)
        
        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            redis_client = get_redis_client()
            if not redis_client:
                # Redis不可用时，直接执行函数
                return func(*args, **kwargs)
            
            try:
                # 生成缓存键
                cache_params = {
                    k: v for k, v in kwargs.items() 
                    if k != 'request' and k != 'db' and not k.startswith('_')
                }
                params_str = json.dumps(cache_params, sort_keys=True, default=str)
                cache_key = f"{key_prefix}:{func.__name__}:{hashlib.md5(params_str.encode()).hexdigest()}"
                
                # 尝试从缓存获取
                cached = redis_client.get(cache_key)
                if cached:
                    try:
                        cached_data = json.loads(cached)
                        # 检查缓存数据格式是否正确（应该是字典，不是字符串）
                        if isinstance(cached_data, str):
                            # 旧格式的缓存（字符串），清除它
                            logger.warning(f"检测到旧格式缓存（字符串），已清除: {cache_key}")
                            redis_client.delete(cache_key)
                        else:
                            logger.debug(f"缓存命中: {cache_key}")
                            return cached_data
                    except json.JSONDecodeError:
                        logger.warning(f"缓存数据格式错误，已清除: {cache_key}")
                        redis_client.delete(cache_key)
                
                # 执行函数
                result = func(*args, **kwargs)
                
                # 存储到缓存
                try:
                    # 将 Pydantic 模型转换为字典
                    serializable_result = _convert_to_serializable(result)
                    result_str = json.dumps(serializable_result, default=str)
                    redis_client.setex(cache_key, ttl, result_str)
                    logger.debug(f"缓存已设置: {cache_key}, TTL: {ttl}秒")
                except (TypeError, ValueError) as e:
                    logger.warning(f"无法缓存结果（不可序列化）: {cache_key}, 错误: {e}")
                
                return result
            except Exception as e:
                logger.error(f"缓存操作失败: {e}", exc_info=True)
                # 缓存失败不影响主功能，直接执行函数
                return func(*args, **kwargs)
        
        # 根据函数类型返回对应的包装器
        import asyncio
        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        else:
            return sync_wrapper
    
    return decorator


def invalidate_cache(pattern: str):
    """
    使缓存失效
    
    Args:
        pattern: 缓存键模式（支持通配符）
    
    Usage:
        invalidate_cache("cache:get_tasks:*")
    """
    redis_client = get_redis_client()
    if not redis_client:
        return
    
    try:
        from app.redis_utils import delete_by_pattern
        deleted = delete_by_pattern(redis_client, pattern)
        if deleted > 0:
            logger.info(f"已清除缓存: {deleted} 个键匹配模式 {pattern}")
    except Exception as e:
        logger.error(f"清除缓存失败: {e}", exc_info=True)


def clear_all_cache(key_prefix: str = "cache"):
    """
    清除所有指定前缀的缓存
    
    Args:
        key_prefix: 缓存键前缀
    """
    invalidate_cache(f"{key_prefix}:*")
