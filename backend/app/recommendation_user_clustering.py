"""
推荐系统用户聚类模块
将相似用户分组，共享推荐结果，减少重复计算
"""

import logging
import hashlib
import json
from typing import List, Dict, Set, Optional, Tuple
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import func, and_

from app.models import User, UserTaskInteraction, TaskHistory, UserPreferences
from app.crud import get_utc_time
from app.redis_cache import redis_cache

logger = logging.getLogger(__name__)


class UserClusteringManager:
    """用户聚类管理器"""
    
    def __init__(self, db: Session):
        self.db = db
    
    def get_user_cluster_id(
        self, 
        user_id: str,
        min_similarity: float = 0.7
    ) -> Optional[str]:
        """
        获取用户所属的聚类ID
        
        聚类策略：
        1. 基于用户交互行为相似度（Jaccard相似度）
        2. 基于用户偏好相似度（任务类型、位置、价格范围）
        3. 基于用户基本信息（城市、等级）
        
        Args:
            user_id: 用户ID
            min_similarity: 最小相似度阈值（默认0.7）
        
        Returns:
            聚类ID，如果没有找到相似用户则返回None
        """
        # 尝试从缓存获取
        cache_key = f"user_cluster:{user_id}"
        try:
            cached = redis_cache.get(cache_key)
            if cached:
                # redis_cache.get() 已经反序列化，可能是 str 或 bytes
                if isinstance(cached, bytes):
                    cluster_id = cached.decode('utf-8')
                else:
                    cluster_id = str(cached)
                if cluster_id != "none":
                    return cluster_id
        except Exception as e:
            logger.warning(f"读取用户聚类缓存失败: {e}")
        
        # 获取用户特征
        user_features = self._get_user_features(user_id)
        if not user_features:
            return None
        
        # 查找相似用户
        similar_users = self._find_similar_users_by_features(
            user_id, user_features, min_similarity
        )
        
        if not similar_users:
            # 没有找到相似用户，缓存"none"
            try:
                redis_cache.setex(cache_key, 3600, "none")  # 1小时
            except Exception:
                pass
            return None
        
        # 生成聚类ID（基于相似用户组的特征哈希）
        cluster_id = self._generate_cluster_id(user_features, similar_users)
        
        # 缓存聚类ID
        try:
            redis_cache.setex(cache_key, 3600, cluster_id)  # 1小时
        except Exception:
            pass
        
        return cluster_id
    
    def _get_user_features(self, user_id: str) -> Optional[Dict]:
        """
        获取用户特征向量
        
        Returns:
            用户特征字典，包含：
            - interaction_tasks: 交互过的任务ID集合
            - task_types: 偏好的任务类型
            - locations: 偏好的位置
            - price_range: 价格范围
            - city: 居住城市
            - user_level: 用户等级
        """
        try:
            # 1. 获取用户交互过的任务
            interactions = self.db.query(UserTaskInteraction.task_id).filter(
                UserTaskInteraction.user_id == user_id,
                UserTaskInteraction.interaction_type.in_(["click", "apply", "accepted"])
            ).distinct().all()
            interaction_tasks = {row[0] for row in interactions}
            
            # 2. 获取用户偏好
            preferences = self.db.query(UserPreferences).filter(
                UserPreferences.user_id == user_id
            ).first()
            
            task_types = []
            locations = []
            price_range = {"min": 0, "max": float('inf')}
            
            if preferences:
                try:
                    if preferences.task_types:
                        task_types = json.loads(preferences.task_types)
                    if preferences.locations:
                        locations = json.loads(preferences.locations)
                except (json.JSONDecodeError, TypeError):
                    pass
            
            # 3. 从历史行为中学习偏好
            if len(interaction_tasks) < 3:
                # 如果交互数据不足，从TaskHistory获取
                history = self.db.query(TaskHistory).filter(
                    TaskHistory.user_id == user_id
                ).limit(20).all()
                
                task_ids = [h.task_id for h in history]
                if task_ids:
                    from app.models import Task
                    tasks = self.db.query(Task).filter(Task.id.in_(task_ids)).all()
                    
                    type_counts = {}
                    location_counts = {}
                    prices = []
                    
                    for task in tasks:
                        type_counts[task.task_type] = type_counts.get(task.task_type, 0) + 1
                        if task.location:
                            location_counts[task.location] = location_counts.get(task.location, 0) + 1
                        if task.reward:
                            prices.append(float(task.reward))
                    
                    if type_counts:
                        task_types.extend([
                            t for t, _ in sorted(type_counts.items(), key=lambda x: x[1], reverse=True)[:5]
                        ])
                    if location_counts:
                        locations.extend([
                            l for l, _ in sorted(location_counts.items(), key=lambda x: x[1], reverse=True)[:3]
                        ])
                    if prices:
                        price_range["min"] = min(prices) * 0.8
                        price_range["max"] = max(prices) * 1.2
            
            # 4. 获取用户基本信息
            user = self.db.query(User).filter(User.id == user_id).first()
            if not user:
                return None
            
            return {
                "interaction_tasks": interaction_tasks,
                "task_types": sorted(set(task_types)),  # 排序并去重
                "locations": sorted(set(locations)),  # 排序并去重
                "price_range": price_range,
                "city": user.residence_city or "",
                "user_level": user.user_level or "normal"
            }
        except Exception as e:
            logger.error(f"获取用户特征失败: {e}", exc_info=True)
            return None
    
    def _find_similar_users_by_features(
        self,
        user_id: str,
        user_features: Dict,
        min_similarity: float = 0.7
    ) -> List[str]:
        """
        根据特征找到相似用户
        
        Args:
            user_id: 用户ID
            user_features: 用户特征
            min_similarity: 最小相似度阈值
        
        Returns:
            相似用户ID列表
        """
        if not user_features or len(user_features.get("interaction_tasks", set())) < 2:
            return []
        
        try:
            # 查找有相似交互行为的用户
            interaction_tasks = user_features["interaction_tasks"]
            if len(interaction_tasks) < 2:
                return []
            
            # 优化：限制交互任务数量，避免查询过大
            interaction_tasks_list = list(interaction_tasks)
            if len(interaction_tasks_list) > 100:
                # 只使用最近的100个交互任务
                interaction_tasks_list = interaction_tasks_list[:100]
            
            # 获取与当前用户有共同交互任务的用户
            common_users = self.db.query(
                UserTaskInteraction.user_id,
                func.count(UserTaskInteraction.task_id).label('common_count')
            ).filter(
                and_(
                    UserTaskInteraction.user_id != user_id,
                    UserTaskInteraction.task_id.in_(interaction_tasks_list),
                    UserTaskInteraction.interaction_type.in_(["click", "apply", "accepted"])
                )
            ).group_by(UserTaskInteraction.user_id).having(
                func.count(UserTaskInteraction.task_id) >= 2  # 至少2个共同任务
            ).limit(20).all()  # 限制候选用户数量，提高效率
            
            similar_users = []
            for other_user_id, common_count in common_users:
                # 计算相似度
                similarity = self._calculate_user_similarity(
                    user_id, other_user_id, user_features, common_count, len(interaction_tasks)
                )
                
                if similarity >= min_similarity:
                    similar_users.append((other_user_id, similarity))
            
            # 按相似度排序，返回最相似的5个用户
            similar_users.sort(key=lambda x: x[1], reverse=True)
            return [user_id for user_id, _ in similar_users[:5]]
            
        except Exception as e:
            logger.error(f"查找相似用户失败: {e}", exc_info=True)
            return []
    
    def _calculate_user_similarity(
        self,
        user_id: str,
        other_user_id: str,
        user_features: Dict,
        common_count: int,
        user_interaction_count: int
    ) -> float:
        """
        计算用户相似度
        
        相似度 = 交互行为相似度 * 0.6 + 偏好相似度 * 0.4
        """
        try:
            # 1. 交互行为相似度（Jaccard相似度）
            other_interactions = self.db.query(UserTaskInteraction.task_id).filter(
                and_(
                    UserTaskInteraction.user_id == other_user_id,
                    UserTaskInteraction.interaction_type.in_(["click", "apply", "accepted"])
                )
            ).distinct().all()
            other_interaction_tasks = {row[0] for row in other_interactions}
            
            intersection = common_count
            union = len(user_features["interaction_tasks"] | other_interaction_tasks)
            interaction_similarity = intersection / union if union > 0 else 0.0
            
            # 2. 偏好相似度
            other_preferences = self.db.query(UserPreferences).filter(
                UserPreferences.user_id == other_user_id
            ).first()
            
            preference_similarity = 0.0
            
            # 任务类型相似度
            if user_features["task_types"]:
                other_task_types = []
                if other_preferences and other_preferences.task_types:
                    try:
                        other_task_types = json.loads(other_preferences.task_types)
                    except (json.JSONDecodeError, TypeError):
                        pass
                
                if other_task_types:
                    common_types = set(user_features["task_types"]) & set(other_task_types)
                    all_types = set(user_features["task_types"]) | set(other_task_types)
                    if all_types:
                        preference_similarity += len(common_types) / len(all_types) * 0.5
            
            # 位置相似度
            if user_features["locations"]:
                other_locations = []
                if other_preferences and other_preferences.locations:
                    try:
                        other_locations = json.loads(other_preferences.locations)
                    except (json.JSONDecodeError, TypeError):
                        pass
                
                if other_locations:
                    common_locations = set(user_features["locations"]) & set(other_locations)
                    all_locations = set(user_features["locations"]) | set(other_locations)
                    if all_locations:
                        preference_similarity += len(common_locations) / len(all_locations) * 0.3
            
            # 城市相似度
            other_user = self.db.query(User).filter(User.id == other_user_id).first()
            if other_user and user_features["city"]:
                if user_features["city"] == (other_user.residence_city or ""):
                    preference_similarity += 0.2
            
            # 综合相似度
            total_similarity = interaction_similarity * 0.6 + preference_similarity * 0.4
            
            return total_similarity
            
        except Exception as e:
            logger.warning(f"计算用户相似度失败: {e}")
            return 0.0
    
    def _generate_cluster_id(
        self,
        user_features: Dict,
        similar_users: List[str]
    ) -> str:
        """
        生成聚类ID（基于特征哈希）
        
        相同特征的用户会得到相同的聚类ID
        """
        # 构建特征字符串
        feature_str = json.dumps({
            "task_types": sorted(user_features.get("task_types", [])),
            "locations": sorted(user_features.get("locations", [])),
            "city": user_features.get("city", ""),
            "user_level": user_features.get("user_level", "normal")
        }, sort_keys=True)
        
        # 生成哈希
        cluster_hash = hashlib.md5(feature_str.encode()).hexdigest()[:12]
        return f"cluster_{cluster_hash}"
    
    def get_cluster_recommendations(
        self,
        cluster_id: str,
        algorithm: str,
        limit: int,
        task_type: Optional[str] = None,
        location: Optional[str] = None,
        keyword: Optional[str] = None
    ) -> Optional[List[Dict]]:
        """
        获取聚类共享的推荐结果
        
        Args:
            cluster_id: 聚类ID
            algorithm: 推荐算法
            limit: 推荐数量
            task_type: 任务类型筛选
            location: 地点筛选
            keyword: 关键词筛选
        
        Returns:
            推荐结果列表，如果不存在则返回None
        """
        # 构建缓存键
        filter_key = f"{task_type or 'all'}:{location or 'all'}:{keyword or 'all'}"
        cache_key = f"cluster_recommendations:{cluster_id}:{algorithm}:{limit}:{filter_key}"
        
        try:
            from app.recommendation_cache import get_cached_recommendations
            return get_cached_recommendations(cache_key)
        except Exception as e:
            logger.warning(f"获取聚类推荐缓存失败: {e}")
            return None
    
    def cache_cluster_recommendations(
        self,
        cluster_id: str,
        recommendations: List[Dict],
        algorithm: str,
        limit: int,
        task_type: Optional[str] = None,
        location: Optional[str] = None,
        keyword: Optional[str] = None,
        ttl: int = 1800  # 30分钟
    ):
        """
        缓存聚类共享的推荐结果
        
        Args:
            cluster_id: 聚类ID
            recommendations: 推荐结果
            algorithm: 推荐算法
            limit: 推荐数量
            task_type: 任务类型筛选
            location: 地点筛选
            keyword: 关键词筛选
            ttl: 缓存时间（秒）
        """
        filter_key = f"{task_type or 'all'}:{location or 'all'}:{keyword or 'all'}"
        cache_key = f"cluster_recommendations:{cluster_id}:{algorithm}:{limit}:{filter_key}"
        
        try:
            from app.recommendation_cache import cache_recommendations
            cache_recommendations(cache_key, recommendations, ttl)
        except Exception as e:
            logger.warning(f"缓存聚类推荐失败: {e}")
    
    def invalidate_cluster_cache(self, cluster_id: str):
        """
        清除聚类缓存
        
        当聚类中用户行为发生变化时调用
        """
        try:
            pattern = f"cluster_recommendations:{cluster_id}:*"
            deleted_count = 0
            
            # 使用 scan 代替 keys 命令，避免阻塞 Redis
            cursor = 0
            while True:
                cursor, keys = redis_cache.scan(cursor, match=pattern, count=100)
                if keys:
                    redis_cache.delete(*keys)
                    deleted_count += len(keys)
                if cursor == 0:
                    break
            
            if deleted_count > 0:
                logger.info(f"清除聚类缓存: cluster_id={cluster_id}, count={deleted_count}")
        except AttributeError:
            # 降级：使用 redis_utils 的 SCAN 实现
            try:
                from app.redis_utils import delete_by_pattern
                deleted = delete_by_pattern(redis_cache, pattern)
                if deleted > 0:
                    logger.info(f"清除聚类缓存(scan): cluster_id={cluster_id}, count={deleted}")
            except Exception as e:
                logger.warning(f"清除聚类缓存失败: {e}")
        except Exception as e:
            logger.warning(f"清除聚类缓存失败: {e}")


def get_user_cluster_recommendations(
    db: Session,
    user_id: str,
    limit: int,
    algorithm: str = "hybrid",
    task_type: Optional[str] = None,
    location: Optional[str] = None,
    keyword: Optional[str] = None
) -> Optional[List[Dict]]:
    """
    尝试从用户聚类获取共享推荐结果
    
    Args:
        db: 数据库会话
        user_id: 用户ID
        limit: 推荐数量
        algorithm: 推荐算法
        task_type: 任务类型筛选
        location: 地点筛选
        keyword: 关键词筛选
    
    Returns:
        推荐结果列表，如果无法从聚类获取则返回None
    """
    try:
        clustering_manager = UserClusteringManager(db)
        
        # 获取用户所属的聚类
        cluster_id = clustering_manager.get_user_cluster_id(user_id)
        if not cluster_id:
            return None
        
        # 尝试从聚类缓存获取推荐
        cluster_recommendations = clustering_manager.get_cluster_recommendations(
            cluster_id, algorithm, limit, task_type, location, keyword
        )
        
        if cluster_recommendations:
            # 需要根据用户个人差异调整推荐结果
            # 主要是排除用户已发布/接受/申请的任务
            from app.recommendation_utils import get_excluded_task_ids, filter_recommendations
            excluded_task_ids = get_excluded_task_ids(db, user_id)
            filtered_recommendations = filter_recommendations(
                cluster_recommendations, excluded_task_ids
            )
            
            # 如果过滤后仍有足够的结果，返回
            if len(filtered_recommendations) >= limit * 0.7:  # 至少70%的结果
                logger.info(f"从聚类获取推荐: user_id={user_id}, cluster_id={cluster_id}, count={len(filtered_recommendations)}")
                return filtered_recommendations[:limit]
        
        return None
        
    except Exception as e:
        logger.warning(f"获取聚类推荐失败: {e}")
        return None
