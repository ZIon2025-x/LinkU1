"""
推荐系统缓存策略优化模块
提供智能缓存策略，提高缓存命中率和效率
"""

import logging
from typing import List, Dict, Optional, Set
from datetime import datetime, timedelta
from functools import lru_cache

from app.redis_cache import redis_cache
from app.recommendation_cache import (
    get_cached_recommendations,
    cache_recommendations,
    get_cache_key,
    invalidate_user_recommendations
)

logger = logging.getLogger(__name__)


class RecommendationCacheStrategy:
    """推荐系统缓存策略管理器"""
    
    # 缓存TTL配置（秒）
    CACHE_TTL = {
        "personal": 1800,      # 个人推荐：30分钟
        "cluster": 1800,        # 聚类推荐：30分钟
        "popular": 900,         # 热门任务：15分钟
        "fallback": 600,        # 降级推荐：10分钟
    }
    
    # 缓存预热配置
    PREWARM_ENABLED = True
    PREWARM_USER_LIMIT = 100  # 预热前100个活跃用户
    
    def __init__(self):
        self._cache_stats = {
            "hits": 0,
            "misses": 0,
            "invalidations": 0
        }
    
    def get_recommendations(
        self,
        user_id: str,
        algorithm: str,
        limit: int,
        task_type: Optional[str] = None,
        location: Optional[str] = None,
        keyword: Optional[str] = None,
        cache_type: str = "personal"
    ) -> Optional[List[Dict]]:
        """
        获取推荐结果（带智能缓存策略）
        
        Args:
            user_id: 用户ID
            algorithm: 推荐算法
            limit: 推荐数量
            task_type: 任务类型筛选
            location: 地点筛选
            keyword: 关键词筛选
            cache_type: 缓存类型（personal, cluster, popular, fallback）
        
        Returns:
            推荐结果列表，如果缓存未命中则返回None
        """
        cache_key = get_cache_key(user_id, algorithm, limit, task_type, location, keyword)
        
        # 尝试从缓存获取
        cached = get_cached_recommendations(cache_key)
        if cached:
            self._cache_stats["hits"] += 1
            logger.debug(f"缓存命中: cache_key={cache_key}, cache_type={cache_type}")
            return cached
        
        self._cache_stats["misses"] += 1
        logger.debug(f"缓存未命中: cache_key={cache_key}, cache_type={cache_type}")
        return None
    
    def cache_recommendations(
        self,
        user_id: str,
        recommendations: List[Dict],
        algorithm: str,
        limit: int,
        task_type: Optional[str] = None,
        location: Optional[str] = None,
        keyword: Optional[str] = None,
        cache_type: str = "personal"
    ) -> bool:
        """
        缓存推荐结果（带智能TTL策略）
        
        Args:
            user_id: 用户ID
            recommendations: 推荐结果
            algorithm: 推荐算法
            limit: 推荐数量
            task_type: 任务类型筛选
            location: 地点筛选
            keyword: 关键词筛选
            cache_type: 缓存类型
        
        Returns:
            是否成功
        """
        cache_key = get_cache_key(user_id, algorithm, limit, task_type, location, keyword)
        
        # 根据缓存类型选择TTL
        ttl = self.CACHE_TTL.get(cache_type, self.CACHE_TTL["personal"])
        
        # 动态调整TTL：如果推荐结果少，缩短TTL
        if len(recommendations) < limit * 0.5:
            ttl = int(ttl * 0.5)  # 减少50%的TTL
        
        success = cache_recommendations(cache_key, recommendations, ttl)
        if success:
            logger.debug(f"缓存成功: cache_key={cache_key}, cache_type={cache_type}, ttl={ttl}")
        
        return success
    
    def invalidate_cache(
        self,
        user_id: Optional[str] = None,
        cluster_id: Optional[str] = None,
        task_id: Optional[int] = None
    ):
        """
        智能缓存失效
        
        Args:
            user_id: 用户ID（清除该用户的所有缓存）
            cluster_id: 聚类ID（清除该聚类的所有缓存）
            task_id: 任务ID（清除包含该任务的推荐缓存）
        """
        try:
            if user_id:
                # 清除用户个人缓存
                invalidate_user_recommendations(user_id)
                self._cache_stats["invalidations"] += 1
                logger.info(f"清除用户缓存: user_id={user_id}")
            
            if cluster_id:
                # 清除聚类缓存
                pattern = f"cluster_recommendations:{cluster_id}:*"
                keys = redis_cache.keys(pattern)
                if keys:
                    redis_cache.delete(*keys)
                    self._cache_stats["invalidations"] += 1
                    logger.info(f"清除聚类缓存: cluster_id={cluster_id}, count={len(keys)}")
            
            if task_id:
                # 清除包含该任务的推荐缓存（需要遍历，但可以优化）
                # 注意：这个操作可能比较慢，应该谨慎使用
                logger.debug(f"任务缓存失效: task_id={task_id}（需要手动处理）")
                
        except Exception as e:
            logger.warning(f"清除缓存失败: {e}")
    
    def get_cache_stats(self) -> Dict:
        """获取缓存统计信息"""
        total = self._cache_stats["hits"] + self._cache_stats["misses"]
        hit_rate = (self._cache_stats["hits"] / total * 100) if total > 0 else 0
        
        return {
            "hits": self._cache_stats["hits"],
            "misses": self._cache_stats["misses"],
            "hit_rate": round(hit_rate, 2),
            "invalidations": self._cache_stats["invalidations"]
        }
    
    def reset_stats(self):
        """重置统计信息"""
        self._cache_stats = {
            "hits": 0,
            "misses": 0,
            "invalidations": 0
        }


# 全局缓存策略实例
_cache_strategy = RecommendationCacheStrategy()


def get_cache_strategy() -> RecommendationCacheStrategy:
    """获取缓存策略实例"""
    return _cache_strategy
