"""
缓存装饰器模块
使用 orjson 进行高性能序列化，支持版本号命名空间避免通配符删除
"""
import logging
from functools import wraps
from typing import Callable, Any, Optional
import orjson

from app.redis_cache import get_redis_client

logger = logging.getLogger(__name__)

# 缓存版本号（用于失效策略）
CACHE_VERSION = "v3"


def cache_task_detail_sync(ttl: int = 300):
    """同步函数缓存装饰器 - 只缓存 Pydantic model
    
    ⚠️ 注意：装饰器内不能使用 Depends()，需要从 kwargs 中获取参数
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            # 从 kwargs 中获取参数（不能使用 Depends）
            task_id = kwargs.get("task_id")
            db = kwargs.get("db")
            
            if not task_id or not db:
                # 如果参数不在 kwargs 中，尝试从 args 获取
                # 这取决于被装饰函数的签名
                if args:
                    task_id = args[0] if len(args) > 0 else task_id
                # 直接调用原函数，不缓存
                return func(*args, **kwargs)
            
            redis_client = get_redis_client()
            # 使用版本号命名空间，避免通配符删除
            cache_key = f"task:{CACHE_VERSION}:detail:{task_id}"
            
            # 尝试从缓存获取
            if redis_client:
                try:
                    cached = redis_client.get(cache_key)
                    if cached:
                        # P1 优化：防止缓存穿透 - 检查是否是空值标记
                        if cached == b"__NULL__" or cached == "__NULL__":
                            # 空值标记，返回 None（防止穿透）
                            return None
                        
                        # 使用 orjson 反序列化
                        cached_dict = orjson.loads(cached)
                        # 从 dict 重建 Pydantic model
                        from app import schemas
                        return schemas.TaskOut(**cached_dict)
                except Exception as e:
                    logger.warning(f"缓存反序列化失败: {e}")
            
            # P1 优化：防止缓存雪崩 - 使用随机 TTL（±10%）
            import random
            actual_ttl = int(ttl * (1 + random.uniform(-0.1, 0.1)))
            
            # 从数据库查询
            result = func(*args, **kwargs)
            
            # 写入缓存 - 只缓存 Pydantic model 的 dict
            if redis_client:
                try:
                    if result:
                        # 使用 model_dump() 获取 dict，然后用 orjson 序列化
                        if hasattr(result, 'model_dump'):
                            cache_data = result.model_dump()
                        elif hasattr(result, 'dict'):
                            cache_data = result.dict()
                        else:
                            # 检查是否是 SQLAlchemy 模型对象
                            try:
                                from sqlalchemy import inspect as sqlalchemy_inspect
                                from decimal import Decimal
                                from datetime import datetime, date
                                
                                # 尝试使用 SQLAlchemy 的 inspect 获取列值
                                mapper = sqlalchemy_inspect(result.__class__)
                                if mapper and hasattr(mapper, 'columns'):
                                    # 是 SQLAlchemy 模型，转换为字典，并处理特殊类型
                                    cache_data = {}
                                    for col in mapper.columns:
                                        value = getattr(result, col.key)
                                        # 处理 Decimal 类型
                                        if isinstance(value, Decimal):
                                            cache_data[col.key] = float(value)
                                        # 处理 datetime 类型
                                        elif isinstance(value, datetime):
                                            cache_data[col.key] = value.isoformat()
                                        # 处理 date 类型
                                        elif isinstance(value, date) and not isinstance(value, datetime):
                                            cache_data[col.key] = value.isoformat()
                                        else:
                                            cache_data[col.key] = value
                                else:
                                    # 不是 SQLAlchemy 模型，尝试使用 __dict__，并处理特殊类型
                                    cache_data = {}
                                    if hasattr(result, '__dict__'):
                                        from decimal import Decimal
                                        from datetime import datetime, date
                                        for key, value in result.__dict__.items():
                                            if isinstance(value, Decimal):
                                                cache_data[key] = float(value)
                                            elif isinstance(value, datetime):
                                                cache_data[key] = value.isoformat()
                                            elif isinstance(value, date) and not isinstance(value, datetime):
                                                cache_data[key] = value.isoformat()
                                            else:
                                                cache_data[key] = value
                                    else:
                                        cache_data = result
                            except (ImportError, AttributeError, Exception):
                                # 如果 inspect 失败或不可用，尝试使用 __dict__，并处理特殊类型
                                if hasattr(result, '__dict__'):
                                    from decimal import Decimal
                                    from datetime import datetime, date
                                    cache_data = {}
                                    for key, value in result.__dict__.items():
                                        if isinstance(value, Decimal):
                                            cache_data[key] = float(value)
                                        elif isinstance(value, datetime):
                                            cache_data[key] = value.isoformat()
                                        elif isinstance(value, date) and not isinstance(value, datetime):
                                            cache_data[key] = value.isoformat()
                                        else:
                                            cache_data[key] = value
                                else:
                                    cache_data = result
                        
                        redis_client.setex(
                            cache_key,
                            actual_ttl,  # 使用随机 TTL 防止雪崩
                            orjson.dumps(cache_data)
                        )
                    else:
                        # P1 优化：防止缓存穿透 - 缓存空值（较短 TTL）
                        # 空结果也缓存，避免频繁查询数据库
                        redis_client.setex(
                            cache_key,
                            min(60, actual_ttl // 5),  # 空值缓存时间较短
                            "__NULL__"
                        )
                except Exception as e:
                    logger.warning(f"缓存写入失败: {e}")
            
            return result
        return wrapper
    return decorator


def cache_task_detail_async(ttl: int = 300):
    """异步函数缓存装饰器 - 使用 redis.asyncio 处理阻塞 I/O"""
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # 从 kwargs 中获取参数
            task_id = kwargs.get("task_id")
            db = kwargs.get("db")
            
            if not task_id:
                if args:
                    task_id = args[0]
                return await func(*args, **kwargs)
            
            # 使用 redis>=4 的 redis.asyncio 接口（推荐）
            # ⚠️ 注意：aioredis 已并入 redis-py，使用 redis>=4 的 redis.asyncio
            try:
                import redis.asyncio as aioredis
                from app.config import get_settings
                
                settings = get_settings()
                redis_url = settings.REDIS_URL or f"redis://{settings.REDIS_HOST}:{settings.REDIS_PORT}/{settings.REDIS_DB}"
                
                redis_client = aioredis.from_url(
                    redis_url,
                    decode_responses=False
                )
            except Exception as e:
                logger.warning(f"创建异步 Redis 客户端失败: {e}")
                redis_client = None
            
            cache_key = f"task:{CACHE_VERSION}:detail:{task_id}"
            
            if redis_client:
                try:
                    # 异步获取缓存
                    cached = await redis_client.get(cache_key)
                    if cached:
                        cached_dict = orjson.loads(cached)
                        from app import schemas
                        return schemas.TaskOut(**cached_dict)
                except Exception as e:
                    logger.warning(f"缓存反序列化失败: {e}")
                finally:
                    if redis_client:
                        await redis_client.aclose()
            
            # 异步查询
            result = await func(*args, **kwargs)
            
            if redis_client and result:
                try:
                    if hasattr(result, 'model_dump'):
                        cache_data = result.model_dump()
                    elif hasattr(result, 'dict'):
                        cache_data = result.dict()
                    else:
                        # 检查是否是 SQLAlchemy 模型对象
                        try:
                            from sqlalchemy import inspect as sqlalchemy_inspect
                            from decimal import Decimal
                            from datetime import datetime, date
                            
                            # 尝试使用 SQLAlchemy 的 inspect 获取列值
                            mapper = sqlalchemy_inspect(result.__class__)
                            if mapper and hasattr(mapper, 'columns'):
                                # 是 SQLAlchemy 模型，转换为字典，并处理特殊类型
                                cache_data = {}
                                for col in mapper.columns:
                                    value = getattr(result, col.key)
                                    # 处理 Decimal 类型
                                    if isinstance(value, Decimal):
                                        cache_data[col.key] = float(value)
                                    # 处理 datetime 类型
                                    elif isinstance(value, datetime):
                                        cache_data[col.key] = value.isoformat()
                                    # 处理 date 类型
                                    elif isinstance(value, date) and not isinstance(value, datetime):
                                        cache_data[col.key] = value.isoformat()
                                    else:
                                        cache_data[col.key] = value
                            else:
                                # 不是 SQLAlchemy 模型，尝试使用 __dict__，并处理特殊类型
                                cache_data = {}
                                if hasattr(result, '__dict__'):
                                    from decimal import Decimal
                                    from datetime import datetime, date
                                    for key, value in result.__dict__.items():
                                        if isinstance(value, Decimal):
                                            cache_data[key] = float(value)
                                        elif isinstance(value, datetime):
                                            cache_data[key] = value.isoformat()
                                        elif isinstance(value, date) and not isinstance(value, datetime):
                                            cache_data[key] = value.isoformat()
                                        else:
                                            cache_data[key] = value
                                else:
                                    cache_data = result
                        except (ImportError, AttributeError, Exception):
                            # 如果 inspect 失败或不可用，尝试使用 __dict__，并处理特殊类型
                            if hasattr(result, '__dict__'):
                                from decimal import Decimal
                                from datetime import datetime, date
                                cache_data = {}
                                for key, value in result.__dict__.items():
                                    if isinstance(value, Decimal):
                                        cache_data[key] = float(value)
                                    elif isinstance(value, datetime):
                                        cache_data[key] = value.isoformat()
                                    elif isinstance(value, date) and not isinstance(value, datetime):
                                        cache_data[key] = value.isoformat()
                                    else:
                                        cache_data[key] = value
                            else:
                                cache_data = result
                    
                    # 重新创建客户端用于写入
                    redis_client = aioredis.from_url(redis_url, decode_responses=False)
                    # 异步写入缓存
                    await redis_client.setex(
                        cache_key,
                        ttl,
                        orjson.dumps(cache_data)
                    )
                    await redis_client.aclose()
                except Exception as e:
                    logger.warning(f"缓存写入失败: {e}")
            
            return result
        return wrapper
    return decorator


def invalidate_task_cache(task_id: int):
    """使任务缓存失效 - 使用版本号命名空间"""
    redis_client = get_redis_client()
    if redis_client:
        cache_key = f"task:{CACHE_VERSION}:detail:{task_id}"
        redis_client.delete(cache_key)
        logger.info(f"已清除任务 {task_id} 的缓存")


def invalidate_task_list_cache():
    """清除任务列表缓存 - 通过版本号递增"""
    redis_client = get_redis_client()
    if redis_client:
        list_cache_version_key = "task:list:version"
        redis_client.incr(list_cache_version_key)
        logger.info("任务列表缓存版本已递增")


def get_task_list_cache_key(status: str, page: int, size: int) -> str:
    """获取任务列表缓存键 - 统一键工厂"""
    redis_client = get_redis_client()
    if redis_client:
        # 获取当前版本号
        version = int(redis_client.get("task:list:version") or 1)
        # 使用版本号构建键，避免通配符删除
        return f"task:list:v{version}:{status}:{page}:{size}"
    return f"task:list:v1:{status}:{page}:{size}"

