"""
缓存淘汰策略工具
实现LRU（最近最少使用）淘汰和缓存大小限制
"""
import logging
import time
from typing import Optional, Dict, List
from collections import OrderedDict
from app.redis_cache import redis_cache

logger = logging.getLogger(__name__)

# 缓存大小限制（键数量）
MAX_CACHE_KEYS = {
    'task_translation': 10000,  # 任务翻译缓存最多10000条
    'batch_query': 1000,  # 批量查询缓存最多1000条
    'general_translation': 50000,  # 通用翻译缓存最多50000条
}

# LRU跟踪（内存中，定期同步到Redis）
_lru_trackers = {
    'task_translation': OrderedDict(),
    'batch_query': OrderedDict(),
    'general_translation': OrderedDict(),
}


def track_cache_access(cache_type: str, cache_key: str):
    """跟踪缓存访问（用于LRU淘汰）"""
    if cache_type not in _lru_trackers:
        return
    
    tracker = _lru_trackers[cache_type]
    
    # 如果键已存在，移动到末尾（最近使用）
    if cache_key in tracker:
        tracker.move_to_end(cache_key)
    else:
        # 添加新键到末尾
        tracker[cache_key] = time.time()
        
        # 检查是否超过限制
        max_keys = MAX_CACHE_KEYS.get(cache_type, 10000)
        if len(tracker) > max_keys:
            # 删除最旧的键（LRU淘汰）
            oldest_key, _ = tracker.popitem(last=False)
            try:
                if redis_cache and redis_cache.enabled:
                    redis_cache.delete(oldest_key)
                logger.debug(f"LRU淘汰缓存: {cache_type}:{oldest_key}")
            except Exception as e:
                logger.warning(f"LRU淘汰缓存失败: {e}")


def evict_old_cache(cache_type: str, max_age_seconds: int = 7 * 24 * 60 * 60):
    """淘汰过期缓存（基于时间）"""
    if cache_type not in _lru_trackers:
        return
    
    tracker = _lru_trackers[cache_type]
    current_time = time.time()
    evicted_count = 0
    
    # 从最旧的开始检查
    keys_to_remove = []
    for cache_key, last_access in list(tracker.items()):
        if current_time - last_access > max_age_seconds:
            keys_to_remove.append(cache_key)
    
    # 删除过期键
    for cache_key in keys_to_remove:
        try:
            if redis_cache and redis_cache.enabled:
                redis_cache.delete(cache_key)
            del tracker[cache_key]
            evicted_count += 1
        except Exception as e:
            logger.warning(f"淘汰过期缓存失败: {e}")
    
    if evicted_count > 0:
        logger.info(f"淘汰过期缓存: {cache_type}, 数量: {evicted_count}")
    
    return evicted_count


def get_cache_stats() -> Dict:
    """获取缓存统计信息"""
    stats = {}
    
    for cache_type, tracker in _lru_trackers.items():
        max_keys = MAX_CACHE_KEYS.get(cache_type, 10000)
        stats[cache_type] = {
            'current_keys': len(tracker),
            'max_keys': max_keys,
            'usage_percent': round((len(tracker) / max_keys) * 100, 2) if max_keys > 0 else 0
        }
    
    return stats


def clear_cache_type(cache_type: str) -> int:
    """清除指定类型的缓存"""
    if cache_type not in _lru_trackers:
        return 0
    
    tracker = _lru_trackers[cache_type]
    cleared_count = 0
    
    for cache_key in list(tracker.keys()):
        try:
            if redis_cache and redis_cache.enabled:
                redis_cache.delete(cache_key)
            del tracker[cache_key]
            cleared_count += 1
        except Exception as e:
            logger.warning(f"清除缓存失败: {e}")
    
    logger.info(f"清除缓存类型: {cache_type}, 数量: {cleared_count}")
    return cleared_count
