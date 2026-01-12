"""
推荐系统缓存优化模块
提供更高效的缓存策略和序列化
"""

import json
import logging
import pickle
import hashlib
from typing import List, Dict, Optional, Any
from datetime import datetime

from app.redis_cache import redis_cache

logger = logging.getLogger(__name__)


def serialize_recommendations(recommendations: List[Dict]) -> bytes:
    """
    序列化推荐结果（优化版本）
    
    使用pickle而不是JSON，因为：
    1. 更快
    2. 支持更多Python类型
    3. 文件更小
    
    Args:
        recommendations: 推荐结果列表
    
    Returns:
        序列化后的字节数据
    """
    try:
        # 使用pickle序列化（更快，但需要Python环境）
        return pickle.dumps(recommendations, protocol=pickle.HIGHEST_PROTOCOL)
    except Exception as e:
        logger.warning(f"Pickle序列化失败，使用JSON: {e}")
        # 降级到JSON
        return json.dumps(recommendations, default=str).encode('utf-8')


def deserialize_recommendations(data: bytes) -> List[Dict]:
    """
    反序列化推荐结果
    
    Args:
        data: 序列化后的字节数据
    
    Returns:
        推荐结果列表
    """
    try:
        # 尝试pickle反序列化
        return pickle.loads(data)
    except (pickle.UnpicklingError, TypeError):
        try:
            # 降级到JSON
            return json.loads(data.decode('utf-8'))
        except Exception as e:
            logger.error(f"反序列化推荐结果失败: {e}")
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
        # 使用模式匹配删除所有相关缓存
        pattern = f"rec:{user_id}:*"
        # 注意：Redis的keys命令在生产环境可能有问题，应该使用scan
        # 这里简化处理，实际应该使用scan_iter
        keys = redis_cache.keys(pattern)
        if keys:
            redis_cache.delete(*keys)
            logger.info(f"清除用户推荐缓存: user_id={user_id}, count={len(keys)}")
    except Exception as e:
        logger.warning(f"清除用户推荐缓存失败: {e}")


def get_cache_stats() -> Dict[str, Any]:
    """
    获取缓存统计信息
    
    Returns:
        缓存统计信息
    """
    try:
        # 获取所有推荐相关的缓存键
        pattern = "rec:*"
        keys = redis_cache.keys(pattern)
        
        # 统计信息
        stats = {
            "total_keys": len(keys),
            "sample_keys": keys[:10] if keys else []
        }
        
        return stats
    except Exception as e:
        logger.warning(f"获取缓存统计失败: {e}")
        return {"error": str(e)}
