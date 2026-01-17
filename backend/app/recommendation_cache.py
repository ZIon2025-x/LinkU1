"""
推荐系统缓存优化模块
提供更高效的缓存策略和序列化

注意：只缓存任务ID和元数据，避免序列化SQLAlchemy对象
"""

import json
import logging
import hashlib
from typing import List, Dict, Optional, Any
from datetime import datetime

from app.redis_cache import redis_cache

logger = logging.getLogger(__name__)


def _extract_cacheable_data(recommendations: List[Dict]) -> List[Dict]:
    """
    提取可缓存的数据（只保留ID和元数据，不包含SQLAlchemy对象）
    
    Args:
        recommendations: 推荐结果列表（可能包含Task对象）
    
    Returns:
        可安全序列化的数据列表
    """
    cacheable = []
    for rec in recommendations:
        task = rec.get("task")
        if task:
            # 提取任务的关键信息，避免序列化整个ORM对象
            cacheable.append({
                "task_id": task.id if hasattr(task, 'id') else task.get("task_id"),
                "score": rec.get("score", 0),
                "reason": rec.get("reason", ""),
                # 缓存一些常用字段，减少后续查询
                "title": getattr(task, 'title', None) or task.get("title"),
                "task_type": getattr(task, 'task_type', None) or task.get("task_type"),
                "location": getattr(task, 'location', None) or task.get("location"),
            })
        else:
            # 如果没有task对象，可能已经是处理过的数据
            cacheable.append(rec)
    return cacheable


def serialize_recommendations(recommendations: List[Dict]) -> str:
    """
    序列化推荐结果（使用JSON，只序列化ID和元数据）
    
    Args:
        recommendations: 推荐结果列表
    
    Returns:
        序列化后的JSON字符串
    """
    try:
        # 提取可缓存数据（不包含SQLAlchemy对象）
        cacheable_data = _extract_cacheable_data(recommendations)
        return json.dumps(cacheable_data, ensure_ascii=False, default=str)
    except Exception as e:
        logger.warning(f"序列化推荐结果失败: {e}")
        return "[]"


def deserialize_recommendations(data) -> List[Dict]:
    """
    反序列化推荐结果
    
    注意：返回的数据只包含任务ID和元数据，需要调用方根据ID查询完整任务信息
    
    Args:
        data: 序列化后的数据
    
    Returns:
        推荐结果列表（不包含完整Task对象）
    """
    # 如果已经是列表，直接返回
    if isinstance(data, list):
        return data
    
    # 如果是字典，可能是单个结果，包装成列表
    if isinstance(data, dict):
        return [data]
    
    # 如果是 bytes，解码后解析
    if isinstance(data, bytes):
        try:
            return json.loads(data.decode('utf-8'))
        except Exception as e:
            logger.error(f"反序列化推荐结果失败: {e}")
            return []
    
    # 如果是字符串，尝试 JSON 解析
    if isinstance(data, str):
        try:
            result = json.loads(data)
            if isinstance(result, list):
                return result
            return [result] if result else []
        except Exception as e:
            logger.error(f"反序列化推荐结果失败: {e}")
            return []
    
    logger.warning(f"未知的数据类型: {type(data)}")
    return []


def get_cache_key(
    user_id: str,
    algorithm: str,
    limit: int,
    task_type: Optional[str] = None,
    location: Optional[str] = None,
    keyword: Optional[str] = None
) -> str:
    """
    生成缓存键（优化版本，使用哈希缩短键长度）
    
    Args:
        user_id: 用户ID
        algorithm: 推荐算法
        limit: 推荐数量
        task_type: 任务类型
        location: 地点
        keyword: 关键词
    
    Returns:
        缓存键
    """
    # 构建键的组成部分
    parts = [
        "rec",
        user_id,
        algorithm,
        str(limit),
        task_type or "all",
        location or "all",
        keyword or "all"
    ]
    
    # 如果键太长，使用哈希缩短
    key = ":".join(parts)
    if len(key) > 200:  # Redis键长度限制
        # 对筛选条件部分进行哈希
        filter_part = ":".join(parts[4:])
        filter_hash = hashlib.md5(filter_part.encode()).hexdigest()[:8]
        key = ":".join(parts[:4] + [filter_hash])
    
    return key


def cache_recommendations(
    cache_key: str,
    recommendations: List[Dict],
    ttl: int = 1800  # 30分钟
) -> bool:
    """
    缓存推荐结果（优化版本）
    
    Args:
        cache_key: 缓存键
        recommendations: 推荐结果
        ttl: 缓存时间（秒）
    
    Returns:
        是否成功
    """
    try:
        serialized = serialize_recommendations(recommendations)
        redis_cache.setex(cache_key, ttl, serialized)
        return True
    except Exception as e:
        logger.warning(f"缓存推荐结果失败: {e}")
        return False


def get_cached_recommendations(cache_key: str) -> Optional[List[Dict]]:
    """
    获取缓存的推荐结果（优化版本）
    
    Args:
        cache_key: 缓存键
    
    Returns:
        推荐结果列表，如果不存在则返回None
    """
    try:
        cached = redis_cache.get(cache_key)
        if cached:
            return deserialize_recommendations(cached)
    except Exception as e:
        logger.warning(f"获取缓存推荐结果失败: {e}")
    
    return None


def invalidate_user_recommendations(user_id: str):
    """
    清除用户的所有推荐缓存
    
    当用户行为发生变化时调用
    
    Args:
        user_id: 用户ID
    """
    try:
        # 使用 scan 代替 keys 命令，避免阻塞 Redis
        pattern = f"rec:{user_id}:*"
        deleted_count = 0
        
        # 使用 scan_iter 迭代匹配的键
        cursor = 0
        while True:
            cursor, keys = redis_cache.scan(cursor, match=pattern, count=100)
            if keys:
                redis_cache.delete(*keys)
                deleted_count += len(keys)
            if cursor == 0:
                break
        
        if deleted_count > 0:
            logger.info(f"清除用户推荐缓存: user_id={user_id}, count={deleted_count}")
    except AttributeError:
        # 如果 redis_cache 不支持 scan，降级到 keys（开发环境）
        try:
            keys = redis_cache.keys(pattern)
            if keys:
                redis_cache.delete(*keys)
                logger.info(f"清除用户推荐缓存(keys): user_id={user_id}, count={len(keys)}")
        except Exception as e:
            logger.warning(f"清除用户推荐缓存失败: {e}")
    except Exception as e:
        logger.warning(f"清除用户推荐缓存失败: {e}")


def get_cache_stats() -> Dict[str, Any]:
    """
    获取缓存统计信息（使用 scan 避免阻塞）
    
    Returns:
        缓存统计信息
    """
    try:
        # 使用 scan 代替 keys 命令
        pattern = "rec:*"
        total_keys = 0
        sample_keys = []
        
        cursor = 0
        while True:
            cursor, keys = redis_cache.scan(cursor, match=pattern, count=100)
            total_keys += len(keys)
            if len(sample_keys) < 10:
                sample_keys.extend(keys[:10 - len(sample_keys)])
            if cursor == 0:
                break
        
        stats = {
            "total_keys": total_keys,
            "sample_keys": sample_keys
        }
        
        return stats
    except AttributeError:
        # 如果不支持 scan，降级到 keys（开发环境）
        try:
            keys = redis_cache.keys(pattern)
            return {
                "total_keys": len(keys) if keys else 0,
                "sample_keys": (keys[:10] if keys else [])
            }
        except Exception as e:
            logger.warning(f"获取缓存统计失败: {e}")
            return {"error": str(e)}
    except Exception as e:
        logger.warning(f"获取缓存统计失败: {e}")
        return {"error": str(e)}
