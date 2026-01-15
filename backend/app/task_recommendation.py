"""
任务推荐系统核心模块
实现基于内容、协同过滤和混合推荐算法
"""

import json
import logging
from typing import List, Dict, Optional, Tuple
from datetime import datetime, timedelta
from decimal import Decimal
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, or_, desc
import math

from app.models import Task, User, UserPreferences, TaskHistory, Review
from app.crud import get_utc_time
from app.redis_cache import redis_cache

logger = logging.getLogger(__name__)


class TaskRecommendationEngine:
    """任务推荐引擎"""
    
    def __init__(self, db: Session):
        self.db = db
    
    def recommend_tasks(
        self, 
        user_id: str, 
        limit: int = 20,
        algorithm: str = "hybrid",
        task_type: Optional[str] = None,
        location: Optional[str] = None,
        keyword: Optional[str] = None
    ) -> List[Dict]:
        """
        为用户推荐任务（支持筛选条件）
        
        Args:
            user_id: 用户ID
            limit: 返回任务数量
            algorithm: 推荐算法 (content_based, collaborative, hybrid)
            task_type: 任务类型筛选
            location: 地点筛选
            keyword: 关键词筛选
        
        Returns:
            推荐任务列表，包含任务对象和推荐分数
        """
        user = self.db.query(User).filter(User.id == user_id).first()
        if not user:
            return []
        
        # 构建缓存键（包含筛选条件）
        filter_key = f"{task_type or 'all'}:{location or 'all'}:{keyword or 'all'}"
        cache_key = f"recommendations:{user_id}:{algorithm}:{limit}:{filter_key}"
        
        # 优化：使用智能缓存策略
        try:
            from app.recommendation_cache_strategy import get_cache_strategy
            cache_strategy = get_cache_strategy()
            cached = cache_strategy.get_recommendations(
                user_id, algorithm, limit, task_type, location, keyword, "personal"
            )
            if cached:
                # 记录缓存命中
                try:
                    from app.recommendation_metrics import record_recommendation_cache_hit
                    record_recommendation_cache_hit(algorithm)
                except Exception:
                    pass
                return cached
        except ImportError:
            # 如果缓存策略模块不可用，使用原始方法
            try:
                from app.recommendation_cache import get_cached_recommendations, get_cache_key
                optimized_cache_key = get_cache_key(user_id, algorithm, limit, task_type, location, keyword)
                cached = get_cached_recommendations(optimized_cache_key)
                if cached:
                    try:
                        from app.recommendation_metrics import record_recommendation_cache_hit
                        record_recommendation_cache_hit(algorithm)
                    except Exception:
                        pass
                    return cached
            except Exception:
                pass
        except ImportError:
            # 如果优化缓存模块不可用，使用原始方法
            try:
                cached = redis_cache.get(cache_key)
                if cached:
                    try:
                        from app.recommendation_metrics import record_recommendation_cache_hit
                        record_recommendation_cache_hit(algorithm)
                    except Exception:
                        pass
                    return json.loads(cached)
            except Exception as e:
                logger.warning(f"读取推荐缓存失败: {e}，继续计算推荐")
        except Exception as e:
            logger.warning(f"读取推荐缓存失败: {e}，继续计算推荐")
        
        # 优化：尝试从用户聚类获取共享推荐（避免重复计算）
        try:
            from app.recommendation_user_clustering import get_user_cluster_recommendations
            cluster_recommendations = get_user_cluster_recommendations(
                self.db, user_id, limit, algorithm, task_type, location, keyword
            )
            if cluster_recommendations:
                # 记录聚类缓存命中
                try:
                    from app.recommendation_metrics import record_recommendation_cache_hit
                    record_recommendation_cache_hit(algorithm)
                except Exception:
                    pass
                logger.info(f"从用户聚类获取推荐: user_id={user_id}, count={len(cluster_recommendations)}")
                # 缓存到用户个人缓存
                try:
                    from app.recommendation_cache import cache_recommendations, get_cache_key
                    optimized_cache_key = get_cache_key(user_id, algorithm, limit, task_type, location, keyword)
                    cache_recommendations(optimized_cache_key, cluster_recommendations, ttl=1800)
                except Exception:
                    pass
                return cluster_recommendations
        except ImportError:
            # 如果聚类模块不可用，继续正常流程
            pass
        except Exception as e:
            logger.warning(f"从用户聚类获取推荐失败: {e}，继续计算推荐")
        
        # 记录缓存未命中
        try:
            from app.recommendation_metrics import record_recommendation_cache_miss
            record_recommendation_cache_miss(algorithm)
        except Exception:
            pass
        
        # 记录推荐请求开始时间
        import time
        start_time = time.time()
        
        try:
            if algorithm == "content_based":
                recommendations = self._content_based_recommend(
                    user, limit, task_type, location, keyword
                )
            elif algorithm == "collaborative":
                recommendations = self._collaborative_filtering_recommend(
                    user, limit, task_type, location, keyword
                )
            elif algorithm == "hybrid":
                recommendations = self._hybrid_recommend(
                    user, limit, task_type, location, keyword
                )
            else:
                recommendations = self._hybrid_recommend(
                    user, limit, task_type, location, keyword
                )
            
            # 记录推荐请求成功
            duration = time.time() - start_time
            try:
                from app.recommendation_metrics import record_recommendation_request, record_recommendations_generated
                record_recommendation_request(algorithm, duration, "success")
                user_type = "new" if self._is_new_user(user) else "existing"
                record_recommendations_generated(algorithm, len(recommendations), user_type)
            except Exception:
                pass
                
        except Exception as e:
            logger.error(f"推荐计算失败: {e}", exc_info=True)
            duration = time.time() - start_time
            try:
                from app.recommendation_metrics import record_recommendation_request
                record_recommendation_request(algorithm, duration, "error")
            except Exception:
                pass
            
            # 降级策略：使用简单推荐
            try:
                from app.recommendation_fallback import get_fallback_recommendations
                recommendations = get_fallback_recommendations(
                    self.db, user_id, limit, task_type, location, keyword
                )
                logger.info(f"使用降级推荐策略，返回{len(recommendations)}个任务")
            except Exception as fallback_error:
                logger.error(f"降级推荐也失败: {fallback_error}", exc_info=True)
                recommendations = []
        
        # 最终过滤：确保排除所有不应推荐的任务
        from app.recommendation_utils import get_excluded_task_ids, filter_recommendations, ensure_minimum_recommendations
        excluded_task_ids = get_excluded_task_ids(self.db, user_id)
        recommendations = filter_recommendations(recommendations, excluded_task_ids)
        
        # 确保推荐结果达到最小数量
        if len(recommendations) < limit:
            recommendations = ensure_minimum_recommendations(
                recommendations,
                limit,
                self.db,
                user_id,
                task_type,
                location,
                keyword
            )
        
        # 缓存结果（使用智能缓存策略）
        try:
            from app.recommendation_cache_strategy import get_cache_strategy
            cache_strategy = get_cache_strategy()
            cache_strategy.cache_recommendations(
                user_id, recommendations, algorithm, limit,
                task_type, location, keyword, "personal"
            )
            
            # 优化：同时缓存到用户聚类（如果用户属于某个聚类）
            try:
                from app.recommendation_user_clustering import UserClusteringManager
                clustering_manager = UserClusteringManager(self.db)
                cluster_id = clustering_manager.get_user_cluster_id(user_id)
                if cluster_id:
                    # 缓存到聚类（供其他相似用户使用）
                    clustering_manager.cache_cluster_recommendations(
                        cluster_id, recommendations, algorithm, limit,
                        task_type, location, keyword, ttl=1800
                    )
                    logger.debug(f"缓存到用户聚类: user_id={user_id}, cluster_id={cluster_id}")
            except ImportError:
                # 如果聚类模块不可用，跳过
                pass
            except Exception as e:
                logger.debug(f"缓存到用户聚类失败: {e}")
        except ImportError:
            # 如果缓存策略模块不可用，使用原始方法
            try:
                from app.recommendation_cache import cache_recommendations, get_cache_key
                optimized_cache_key = get_cache_key(user_id, algorithm, limit, task_type, location, keyword)
                cache_recommendations(optimized_cache_key, recommendations, ttl=1800)
            except ImportError:
                # 如果优化缓存模块不可用，使用原始方法
                try:
                    import json
                    cache_data = json.dumps(recommendations, default=str)
                    redis_cache.setex(cache_key, 1800, cache_data)
                except Exception as e:
                    logger.warning(f"写入推荐缓存失败: {e}，继续返回结果")
        except Exception as e:
            logger.warning(f"写入推荐缓存失败: {e}，继续返回结果")
        
        return recommendations
    
    def _content_based_recommend(
        self, 
        user: User, 
        limit: int,
        task_type: Optional[str] = None,
        location: Optional[str] = None,
        keyword: Optional[str] = None
    ) -> List[Dict]:
        """基于内容的推荐（支持筛选，包含冷启动优化和新任务优先）"""
        # 1. 获取用户偏好
        user_preferences = self._get_user_preferences(user.id)
        
        # 2. 获取用户历史任务
        user_history = self._get_user_task_history(user.id)
        
        # 3. 构建用户偏好向量
        user_vector = self._build_user_preference_vector(user, user_preferences, user_history)
        
        # 冷启动处理：如果用户没有历史数据，使用默认偏好
        if not user_history and not user_preferences:
            user_vector = self._get_default_preference_vector(user)
        
        # 4. 获取应该排除的任务ID（用户已发布、已接受、已申请、已完成的任务）
        from app.recommendation_utils import get_excluded_task_ids
        excluded_task_ids = get_excluded_task_ids(self.db, user.id)
        
        # 5. 获取所有开放任务（应用筛选条件）
        query = self.db.query(Task).filter(
            Task.status == "open",
            Task.poster_id != user.id,  # 排除自己发布的任务
            ~Task.id.in_(excluded_task_ids) if excluded_task_ids else True  # 排除已排除的任务
        )
        
        # 应用筛选条件
        if task_type and task_type.strip() and task_type != "all":
            query = query.filter(Task.task_type == task_type.strip())
        
        if location and location.strip() and location != "all":
            loc = location.strip()
            if loc.lower() == 'online':
                query = query.filter(Task.location.ilike("%online%"))
            else:
                from sqlalchemy import or_
                query = query.filter(or_(
                    Task.location.ilike(f"%, {loc}%"),
                    Task.location.ilike(f"{loc},%"),
                    Task.location.ilike(f"{loc}"),
                    Task.location.ilike(f"% {loc}")
                ))
        
        if keyword and keyword.strip():
            from sqlalchemy import func, or_
            keyword_clean = keyword.strip()
            query = query.filter(or_(
                func.similarity(Task.title, keyword_clean) > 0.2,
                func.similarity(Task.description, keyword_clean) > 0.2,
                Task.title.ilike(f"%{keyword_clean}%"),
                Task.description.ilike(f"%{keyword_clean}%")
            ))
        
        # 优化：限制查询数量，避免加载过多任务到内存
        # 先获取更多任务（limit * 3），然后计算分数后排序
        open_tasks = query.limit(limit * 3).all()
        
        # 为新任务添加额外分数加成
        now = get_utc_time()
        
        # 5. 计算每个任务的匹配分数（包含新任务加成）
        scored_tasks = []
        for task in open_tasks:
            base_score = self._calculate_content_match_score(user_vector, task, user)
            
            # 新任务加成
            if self._is_new_task(task):
                # 新任务额外加0.1分
                time_bonus = 0.1
                # 如果是新用户发布的任务，再加0.15分
                if self._is_new_user_task(task):
                    time_bonus += 0.15
                base_score = min(1.0, base_score + time_bonus)
            
            if base_score > 0:  # 只返回有匹配度的任务
                reason = self._generate_recommendation_reason(user_vector, task, base_score)
                # 如果是新用户发布的任务，在理由中说明
                if self._is_new_user_task(task):
                    reason = "新用户发布，优先推荐；" + reason
                elif self._is_new_task(task):
                    reason = "新发布任务；" + reason
                
                scored_tasks.append({
                    "task": task,
                    "score": base_score,
                    "reason": reason
                })
        
        # 6. 按分数排序
        scored_tasks.sort(key=lambda x: x["score"], reverse=True)
        
        return scored_tasks[:limit]
    
    def _collaborative_filtering_recommend(
        self, 
        user: User, 
        limit: int,
        task_type: Optional[str] = None,
        location: Optional[str] = None,
        keyword: Optional[str] = None
    ) -> List[Dict]:
        """协同过滤推荐（支持筛选）"""
        # 1. 获取用户交互过的任务
        user_interactions = self._get_user_interactions(user.id)
        
        if len(user_interactions) < 3:
            # 数据不足，回退到基于内容的推荐
            return self._content_based_recommend(user, limit, task_type, location, keyword)
        
        # 2. 找到相似用户
        similar_users = self._find_similar_users(user.id, user_interactions, k=10)
        
        if not similar_users:
            return self._content_based_recommend(user, limit)
        
        # 3. 批量获取相似用户喜欢的任务（优化N+1查询）
        recommended_tasks = {}
        try:
            from app.recommendation_performance import batch_get_user_liked_tasks
            similar_user_ids = [user_id for user_id, _ in similar_users]
            user_liked_tasks_map = batch_get_user_liked_tasks(self.db, similar_user_ids)
            
            for similar_user_id, similarity in similar_users:
                liked_tasks = user_liked_tasks_map.get(similar_user_id, set())
                for task_id in liked_tasks:
                    if task_id not in user_interactions:
                        if task_id not in recommended_tasks:
                            recommended_tasks[task_id] = 0.0
                        recommended_tasks[task_id] += similarity
        except ImportError:
            # 如果性能模块不可用，使用原始实现
            for similar_user_id, similarity in similar_users:
                liked_tasks = self._get_user_liked_tasks(similar_user_id)
                for task_id in liked_tasks:
                    if task_id not in user_interactions:
                        if task_id not in recommended_tasks:
                            recommended_tasks[task_id] = 0.0
                        recommended_tasks[task_id] += similarity
        
        # 4. 获取任务对象并应用筛选
        task_ids = list(recommended_tasks.keys())
        if not task_ids:
            return []
        
        query = self.db.query(Task).filter(
            Task.id.in_(task_ids),
            Task.status == "open"
        )
        
        # 应用筛选条件
        if task_type and task_type.strip() and task_type != "all":
            query = query.filter(Task.task_type == task_type.strip())
        
        if location and location.strip() and location != "all":
            loc = location.strip()
            if loc.lower() == 'online':
                query = query.filter(Task.location.ilike("%online%"))
            else:
                from sqlalchemy import or_
                query = query.filter(or_(
                    Task.location.ilike(f"%, {loc}%"),
                    Task.location.ilike(f"{loc},%"),
                    Task.location.ilike(f"{loc}"),
                    Task.location.ilike(f"% {loc}")
                ))
        
        if keyword and keyword.strip():
            from sqlalchemy import func, or_
            keyword_clean = keyword.strip()
            query = query.filter(or_(
                func.similarity(Task.title, keyword_clean) > 0.2,
                func.similarity(Task.description, keyword_clean) > 0.2,
                Task.title.ilike(f"%{keyword_clean}%"),
                Task.description.ilike(f"%{keyword_clean}%")
            ))
        
        # 限制最大任务数量，防止内存溢出（最多加载500个任务）
        MAX_TASKS = 500
        tasks = query.limit(MAX_TASKS).all()
        
        scored_tasks = []
        for task in tasks:
            score = recommended_tasks.get(task.id, 0.0)
            scored_tasks.append({
                "task": task,
                "score": score,
                "reason": f"相似用户也喜欢这类任务"
            })
        
        scored_tasks.sort(key=lambda x: x["score"], reverse=True)
        return scored_tasks[:limit]
    
    def _hybrid_recommend(
        self, 
        user: User, 
        limit: int,
        task_type: Optional[str] = None,
        location: Optional[str] = None,
        keyword: Optional[str] = None
    ) -> List[Dict]:
        """混合推荐算法（支持筛选，包含新用户/新任务优先曝光，优化版）"""
        # 检查用户是否为新用户（注册7天内）- 在所有分支之前定义
        is_new_user = self._is_new_user(user)
        
        # 尝试使用优化版本（减少重复计算）
        try:
            from app.recommendation_compute_optimizer import (
                RecommendationComputeCache, 
                optimize_hybrid_recommendation
            )
            compute_cache = RecommendationComputeCache(self.db, user)
            scores, reasons = optimize_hybrid_recommendation(
                compute_cache, limit, task_type, location, keyword
            )
            # 使用优化版本的结果（已经排除了任务）
            filtered_scores = scores
        except ImportError:
            # 如果优化模块不可用，使用原始实现
            scores = {}
            reasons = {}
            filtered_scores = None
        
        # 如果使用了优化版本，直接处理结果并返回
        if filtered_scores is not None:
            # 排序并获取任务对象
            sorted_task_ids = sorted(filtered_scores.items(), key=lambda x: x[1], reverse=True)
            
            # 多样性优化：避免推荐过于相似的任务
            diversified_task_ids = self._diversify_recommendations(
                sorted_task_ids, 
                limit,
                task_type,
                location
            )
            
            task_ids = [task_id for task_id, _ in diversified_task_ids]
            if not task_ids:
                # 如果没有推荐结果，尝试补充
                from app.recommendation_utils import ensure_minimum_recommendations
                return ensure_minimum_recommendations(
                    [],
                    limit,
                    self.db,
                    user.id,
                    task_type,
                    location,
                    keyword
                )
            
            # 优化：批量获取任务详情（预加载关联数据，避免N+1查询）
            try:
                from app.recommendation_query_optimizer import RecommendationQueryOptimizer
                query_optimizer = RecommendationQueryOptimizer(self.db)
                task_dict = query_optimizer.batch_get_tasks_with_details(task_ids, preload_relations=True)
            except ImportError:
                # 如果优化模块不可用，使用原始方法
                tasks = self.db.query(Task).filter(Task.id.in_(task_ids)).all()
                task_dict = {task.id: task for task in tasks}
            
            result = []
            for task_id, score in diversified_task_ids:
                if task_id in task_dict:
                    result.append({
                        "task": task_dict[task_id],
                        "score": score,
                        "reason": reasons.get(task_id, "为您推荐")
                    })
            
            # 最终过滤：确保排除所有不应推荐的任务
            from app.recommendation_utils import filter_recommendations, get_excluded_task_ids
            excluded_task_ids = get_excluded_task_ids(self.db, user.id)
            result = filter_recommendations(result, excluded_task_ids)
            
            # 确保推荐结果达到最小数量
            if len(result) < limit:
                from app.recommendation_utils import ensure_minimum_recommendations
                result = ensure_minimum_recommendations(
                    result,
                    limit,
                    self.db,
                    user.id,
                    task_type,
                    location,
                    keyword
                )
            
            return result
        
        # 1. 基于内容的推荐（权重：35%，新用户时降低到30%）
        content_weight = 0.3 if is_new_user else 0.35
        content_based = self._content_based_recommend(
            user, limit=50, task_type=task_type, location=location, keyword=keyword
        )
        for item in content_based:
            task_id = item["task"].id
            scores[task_id] = scores.get(task_id, 0) + item["score"] * content_weight
            reasons[task_id] = item["reason"]
        
        # 2. 协同过滤推荐（权重：25%，新用户时降低到20%）
        collaborative_weight = 0.2 if is_new_user else 0.25
        if self._has_enough_data(user.id):
            collaborative = self._collaborative_filtering_recommend(
                user, limit=50, task_type=task_type, location=location, keyword=keyword
            )
            for item in collaborative:
                task_id = item["task"].id
                scores[task_id] = scores.get(task_id, 0) + item["score"] * collaborative_weight
                if task_id not in reasons:
                    reasons[task_id] = item["reason"]
        
        # 3. 新任务优先曝光（权重：15%，新用户时提高到20%）
        new_task_weight = 0.2 if is_new_user else 0.15
        new_tasks = self._new_task_boost_recommend(
            user, limit=30, task_type=task_type, location=location, keyword=keyword
        )
        # 应用筛选条件
        if task_type or location or keyword:
            new_tasks = self._apply_filters_to_recommendations(
                new_tasks, task_type, location, keyword
            )
        for item in new_tasks:
            task_id = item["task"].id
            scores[task_id] = scores.get(task_id, 0) + item["score"] * new_task_weight
            if task_id not in reasons:
                reasons[task_id] = item["reason"]
        
        # 4. 地理位置推荐（权重：12%）
        location_based = self._location_based_recommend(user, limit=30)
        # 应用筛选条件
        if task_type or location or keyword:
            location_based = self._apply_filters_to_recommendations(
                location_based, task_type, location, keyword
            )
        for item in location_based:
            task_id = item["task"].id
            scores[task_id] = scores.get(task_id, 0) + item["score"] * 0.12
            if task_id not in reasons:
                reasons[task_id] = item["reason"]
        
        # 5. 热门任务推荐（权重：8%，仅作为补充策略）
        # 注意：热门任务主要用于解决冷启动问题和增加多样性
        # 对于有足够数据的用户，热门任务权重会自动降低
        if is_new_user:
            # 新用户：热门任务权重稍高（10%），帮助发现兴趣
            popular_weight = 0.10
        else:
            # 老用户：热门任务权重更低（5%），更精准个性化
            popular_weight = 0.05
        
        popular = self._popular_tasks_recommend(limit=30, user=user)
        # 应用筛选条件（即使热门任务也会根据用户筛选条件过滤）
        if task_type or location or keyword:
            popular = self._apply_filters_to_recommendations(
                popular, task_type, location, keyword
            )
        for item in popular:
            task_id = item["task"].id
            scores[task_id] = scores.get(task_id, 0) + item["score"] * popular_weight
            if task_id not in reasons:
                reasons[task_id] = item["reason"]
        
        # 6. 时间匹配推荐（权重：5%）
        time_based = self._time_based_recommend(user, limit=20)
        # 应用筛选条件
        if task_type or location or keyword:
            time_based = self._apply_filters_to_recommendations(
                time_based, task_type, location, keyword
            )
        for item in time_based:
            task_id = item["task"].id
            scores[task_id] = scores.get(task_id, 0) + item["score"] * 0.05
            if task_id not in reasons:
                reasons[task_id] = item["reason"]
        
        # 获取应该排除的任务ID
        from app.recommendation_utils import get_excluded_task_ids, filter_recommendations
        excluded_task_ids = get_excluded_task_ids(self.db, user.id)
        
        # 从分数中排除已排除的任务
        filtered_scores = {
            task_id: score for task_id, score in scores.items()
            if task_id not in excluded_task_ids
        }
        
        # 排序并获取任务对象
        sorted_task_ids = sorted(filtered_scores.items(), key=lambda x: x[1], reverse=True)
        
        # 多样性优化：避免推荐过于相似的任务
        diversified_task_ids = self._diversify_recommendations(
            sorted_task_ids, 
            limit,
            task_type,
            location
        )
        
        task_ids = [task_id for task_id, _ in diversified_task_ids]
        if not task_ids:
            # 如果没有推荐结果，尝试补充
            from app.recommendation_utils import ensure_minimum_recommendations
            return ensure_minimum_recommendations(
                [],
                limit,
                self.db,
                user.id,
                task_type,
                location,
                keyword
            )
        
        # 优化：批量获取任务详情（预加载关联数据，避免N+1查询）
        try:
            from app.recommendation_query_optimizer import RecommendationQueryOptimizer
            query_optimizer = RecommendationQueryOptimizer(self.db)
            task_dict = query_optimizer.batch_get_tasks_with_details(task_ids, preload_relations=True)
        except ImportError:
            # 如果优化模块不可用，使用原始方法
            tasks = self.db.query(Task).filter(Task.id.in_(task_ids)).all()
            task_dict = {task.id: task for task in tasks}
        
        result = []
        for task_id, score in diversified_task_ids:
            if task_id in task_dict:
                result.append({
                    "task": task_dict[task_id],
                    "score": score,
                    "reason": reasons.get(task_id, "为您推荐")
                })
        
        # 最终过滤：确保排除所有不应推荐的任务
        from app.recommendation_utils import filter_recommendations
        excluded_task_ids = get_excluded_task_ids(self.db, user.id)
        result = filter_recommendations(result, excluded_task_ids)
        
        # 确保推荐结果达到最小数量
        if len(result) < limit:
            from app.recommendation_utils import ensure_minimum_recommendations
            result = ensure_minimum_recommendations(
                result,
                limit,
                self.db,
                user.id,
                task_type,
                location,
                keyword
            )
        
        return result
    
    def _diversify_recommendations(
        self,
        sorted_task_ids: List[Tuple[int, float]],
        limit: int,
        task_type: Optional[str] = None,
        location: Optional[str] = None
    ) -> List[Tuple[int, float]]:
        """
        推荐多样性优化：避免推荐过于相似的任务
        
        策略：
        1. 同一类型的任务最多占50%
        2. 同一地点的任务最多占60%
        3. 保持推荐质量的同时增加多样性
        """
        if len(sorted_task_ids) <= limit:
            return sorted_task_ids
        
        # 优化：只查询必要字段用于多样性判断（减少数据传输）
        all_task_ids = [task_id for task_id, _ in sorted_task_ids]
        try:
            from app.recommendation_query_optimizer import optimize_diversity_query
            task_info_dict = optimize_diversity_query(self.db, all_task_ids, limit)
            
            # 创建简化任务对象用于多样性判断
            class SimpleTask:
                def __init__(self, task_id, task_type, location):
                    self.id = task_id
                    self.task_type = task_type
                    self.location = location
            
            task_dict = {}
            for task_id, info in task_info_dict.items():
                task_dict[task_id] = SimpleTask(
                    info["id"],
                    info["task_type"],
                    info["location"]
                )
        except ImportError:
            # 如果优化模块不可用，使用原始方法（只查询必要字段）
            tasks = self.db.query(
                Task.id,
                Task.task_type,
                Task.location
            ).filter(Task.id.in_(all_task_ids)).all()
            
            class SimpleTask:
                def __init__(self, task_id, task_type, location):
                    self.id = task_id
                    self.task_type = task_type
                    self.location = location
            
            task_dict = {}
            for task_id, task_type, location in tasks:
                task_dict[task_id] = SimpleTask(task_id, task_type, location)
        
        selected = []
        type_count = {}
        location_count = {}
        max_type_count = max(1, limit // 2)  # 同一类型最多50%
        max_location_count = max(1, int(limit * 0.6))  # 同一地点最多60%
        
        for task_id, score in sorted_task_ids:
            if len(selected) >= limit:
                break
            
            task = task_dict.get(task_id)
            if not task:
                continue
            
            # 检查类型多样性
            type_key = task.task_type
            if type_count.get(type_key, 0) >= max_type_count:
                continue
            
            # 检查地点多样性（如果用户没有筛选地点）
            if not location or location == "all":
                loc_key = task.location.split(',')[0] if task.location else "unknown"
                if location_count.get(loc_key, 0) >= max_location_count:
                    continue
            
            # 通过多样性检查，添加到结果
            selected.append((task_id, score))
            type_count[type_key] = type_count.get(type_key, 0) + 1
            if not location or location == "all":
                loc_key = task.location.split(',')[0] if task.location else "unknown"
                location_count[loc_key] = location_count.get(loc_key, 0) + 1
        
        # 如果多样性筛选后数量不足，补充高分任务
        if len(selected) < limit:
            for task_id, score in sorted_task_ids:
                if len(selected) >= limit:
                    break
                if task_id not in [tid for tid, _ in selected]:
                    selected.append((task_id, score))
        
        return selected
    
    def _location_based_recommend(self, user: User, limit: int) -> List[Dict]:
        """基于地理位置的推荐"""
        if not user.residence_city:
            return []
        
        # 获取应该排除的任务ID
        from app.recommendation_utils import get_excluded_task_ids
        excluded_task_ids = get_excluded_task_ids(self.db, user.id)
        
        # 查找同城或附近的任务
        query = self.db.query(Task).filter(
            Task.status == "open",
            Task.poster_id != user.id,
            Task.location.ilike(f"%{user.residence_city}%"),
            ~Task.id.in_(excluded_task_ids) if excluded_task_ids else True
        )
        tasks = query.limit(limit).all()
        
        return [{"task": task, "score": 1.0, "reason": "同城任务"} for task in tasks]
    
    def _popular_tasks_recommend(self, limit: int, user: Optional[User] = None) -> List[Dict]:
        """热门任务推荐"""
        # 获取最近24小时最受欢迎的任务（基于接受数、浏览数等）
        recent_time = get_utc_time() - timedelta(hours=24)
        
        query = self.db.query(Task).filter(
            Task.status == "open",
            Task.created_at >= recent_time
        )
        
        # 如果提供了用户，排除该用户不应看到的任务
        if user:
            from app.recommendation_utils import get_excluded_task_ids
            excluded_task_ids = get_excluded_task_ids(self.db, user.id)
            query = query.filter(
                Task.poster_id != user.id,
                ~Task.id.in_(excluded_task_ids) if excluded_task_ids else True
            )
        
        tasks = query.order_by(desc(Task.created_at)).limit(limit).all()
        
        return [{"task": task, "score": 0.8, "reason": "热门任务"} for task in tasks]
    
    def _time_based_recommend(self, user: User, limit: int) -> List[Dict]:
        """基于时间匹配的推荐"""
        # 获取应该排除的任务ID
        from app.recommendation_utils import get_excluded_task_ids
        excluded_task_ids = get_excluded_task_ids(self.db, user.id)
        
        now = get_utc_time()
        query = self.db.query(Task).filter(
            Task.status == "open",
            Task.poster_id != user.id,
            Task.deadline.isnot(None),
            Task.deadline > now,
            ~Task.id.in_(excluded_task_ids) if excluded_task_ids else True
        )
        future_tasks = query.order_by(Task.deadline.asc()).limit(limit).all()
        
        return [{"task": task, "score": 0.7, "reason": "即将截止"} for task in future_tasks]
    
    def _is_new_user(self, user: User) -> bool:
        """判断是否为新用户（注册7天内）"""
        if not user.created_at:
            return False
        
        now = get_utc_time()
        days_since_registration = (now - user.created_at).days if hasattr(user.created_at, 'days') else 999
        
        return days_since_registration <= 7
    
    def _is_new_task(self, task: Task) -> bool:
        """判断是否为新任务（发布24小时内）"""
        if not task.created_at:
            return False
        
        now = get_utc_time()
        hours_since_creation = (now - task.created_at).total_seconds() / 3600 if hasattr(task.created_at, 'total_seconds') else 999
        
        return hours_since_creation <= 24
    
    def _is_new_user_task(self, task: Task) -> bool:
        """判断是否为新用户发布的任务（发布者注册7天内且任务发布24小时内）"""
        if not task.poster_id or not task.created_at:
            return False
        
        # 检查任务是否新发布
        if not self._is_new_task(task):
            return False
        
        # 检查发布者是否为新用户（优化：可以缓存用户信息）
        # 注意：这里每次查询用户信息，如果性能有问题可以考虑缓存
        poster = self.db.query(User).filter(User.id == task.poster_id).first()
        if not poster:
            return False
        
        return self._is_new_user(poster)
    
    def _new_task_boost_recommend(
        self,
        user: User,
        limit: int,
        task_type: Optional[str] = None,
        location: Optional[str] = None,
        keyword: Optional[str] = None
    ) -> List[Dict]:
        """新任务优先推荐（特别优先新用户发布的任务）"""
        from sqlalchemy import and_, or_
        
        now = get_utc_time()
        recent_time = now - timedelta(hours=24)
        
        # 获取应该排除的任务ID
        from app.recommendation_utils import get_excluded_task_ids
        excluded_task_ids = get_excluded_task_ids(self.db, user.id)
        
        # 构建查询
        query = self.db.query(Task).filter(
            Task.status == "open",
            Task.poster_id != user.id,
            Task.created_at >= recent_time,
            ~Task.id.in_(excluded_task_ids) if excluded_task_ids else True
        )
        
        # 应用筛选条件
        if task_type and task_type.strip() and task_type != "all":
            query = query.filter(Task.task_type == task_type.strip())
        
        if location and location.strip() and location != "all":
            loc = location.strip()
            if loc.lower() == 'online':
                query = query.filter(Task.location.ilike("%online%"))
            else:
                query = query.filter(or_(
                    Task.location.ilike(f"%, {loc}%"),
                    Task.location.ilike(f"{loc},%"),
                    Task.location.ilike(f"{loc}"),
                    Task.location.ilike(f"% {loc}")
                ))
        
        if keyword and keyword.strip():
            from sqlalchemy import func
            keyword_clean = keyword.strip()
            query = query.filter(or_(
                func.similarity(Task.title, keyword_clean) > 0.2,
                func.similarity(Task.description, keyword_clean) > 0.2,
                Task.title.ilike(f"%{keyword_clean}%"),
                Task.description.ilike(f"%{keyword_clean}%")
            ))
        
        # 按创建时间排序（最新的在前）
        tasks = query.order_by(desc(Task.created_at)).limit(limit * 2).all()
        
        # 为新用户发布的任务分配更高分数
        result = []
        for task in tasks:
            is_new_user_task = self._is_new_user_task(task)
            
            # 计算时间衰减分数（越新分数越高）
            hours_old = (now - task.created_at).total_seconds() / 3600 if hasattr(task.created_at, 'total_seconds') else 24
            time_score = max(0, 1.0 - (hours_old / 24))  # 24小时内线性衰减
            
            # 新用户发布的任务额外加分
            if is_new_user_task:
                score = min(1.0, time_score + 0.3)  # 额外加0.3分
                reason = "新用户发布，优先推荐"
            else:
                score = time_score
                reason = "新发布任务"
            
            result.append({
                "task": task,
                "score": score,
                "reason": reason
            })
        
        # 按分数排序
        result.sort(key=lambda x: x["score"], reverse=True)
        return result[:limit]
    
    def _get_user_preferences(self, user_id: str) -> Optional[UserPreferences]:
        """获取用户偏好"""
        return self.db.query(UserPreferences).filter(
            UserPreferences.user_id == user_id
        ).first()
    
    def _get_user_task_history(self, user_id: str) -> List[TaskHistory]:
        """获取用户任务历史"""
        return self.db.query(TaskHistory).filter(
            TaskHistory.user_id == user_id
        ).order_by(desc(TaskHistory.timestamp)).limit(50).all()
    
    def _get_user_interactions(self, user_id: str) -> set:
        """获取用户交互过的任务ID集合"""
        history = self._get_user_task_history(user_id)
        return {h.task_id for h in history}
    
    def _build_user_preference_vector(
        self, 
        user: User, 
        preferences: Optional[UserPreferences],
        history: List[TaskHistory]
    ) -> Dict:
        """构建用户偏好向量"""
        vector = {
            "task_types": [],
            "locations": [],
            "price_range": {"min": 0, "max": float('inf')},
            "task_levels": [],
            "keywords": []
        }
        
        # 从用户偏好设置中获取
        if preferences:
            if preferences.task_types:
                vector["task_types"] = json.loads(preferences.task_types)
            if preferences.locations:
                vector["locations"] = json.loads(preferences.locations)
            if preferences.task_levels:
                vector["task_levels"] = json.loads(preferences.task_levels)
            if preferences.keywords:
                vector["keywords"] = json.loads(preferences.keywords)
        
        # 从历史行为中学习偏好
        if history:
            task_ids = [h.task_id for h in history[:20]]  # 最近20个任务
            if task_ids:  # 避免空列表查询
                # 优化：只查询必要字段，减少数据传输
                tasks = self.db.query(
                    Task.id,
                    Task.task_type,
                    Task.location,
                    Task.reward
                ).filter(Task.id.in_(task_ids)).all()
                
                # 转换为完整任务对象（用于后续处理）
                class SimpleTask:
                    def __init__(self, task_id, task_type, location, reward):
                        self.id = task_id
                        self.task_type = task_type
                        self.location = location
                        self.reward = reward
                
                tasks = [SimpleTask(t[0], t[1], t[2], t[3]) for t in tasks]
            else:
                tasks = []
            
            # 统计任务类型
            type_counts = {}
            location_counts = {}
            prices = []
            
            for task in tasks:
                # 任务类型
                type_counts[task.task_type] = type_counts.get(task.task_type, 0) + 1
                # 位置
                if task.location:
                    location_counts[task.location] = location_counts.get(task.location, 0) + 1
                # 价格
                if task.reward:
                    prices.append(float(task.reward))
            
            # 更新偏好向量
            if type_counts:
                vector["task_types"].extend([
                    task_type for task_type, count in sorted(
                        type_counts.items(), key=lambda x: x[1], reverse=True
                    )[:5]
                ])
            
            if location_counts:
                vector["locations"].extend([
                    loc for loc, count in sorted(
                        location_counts.items(), key=lambda x: x[1], reverse=True
                    )[:3]
                ])
            
            if prices:
                vector["price_range"]["min"] = min(prices) * 0.8
                vector["price_range"]["max"] = max(prices) * 1.2
        
        return vector
    
    def _calculate_content_match_score(
        self, 
        user_vector: Dict, 
        task: Task, 
        user: User
    ) -> float:
        """计算内容匹配分数"""
        score = 0.0
        
        # 1. 任务类型匹配（权重：0.3）
        if user_vector["task_types"] and task.task_type in user_vector["task_types"]:
            score += 0.3
        
        # 2. 位置匹配（权重：0.25）
        if user_vector["locations"] and task.location:
            for loc in user_vector["locations"]:
                if loc.lower() in task.location.lower() or task.location.lower() in loc.lower():
                    score += 0.25
                    break
        
        # 3. 价格匹配（权重：0.2）
        if task.reward:
            price = float(task.reward)
            price_range = user_vector["price_range"]
            if price_range["min"] <= price <= price_range["max"]:
                score += 0.2
        
        # 4. 任务等级匹配（权重：0.15）
        if user_vector["task_levels"] and task.task_level in user_vector["task_levels"]:
            score += 0.15
        
        # 5. 关键词匹配（权重：0.1）
        if user_vector["keywords"]:
            task_text = f"{task.title} {task.description}".lower()
            matched_keywords = sum(
                1 for keyword in user_vector["keywords"] 
                if keyword.lower() in task_text
            )
            if matched_keywords > 0:
                score += 0.1 * min(matched_keywords / len(user_vector["keywords"]), 1.0)
        
        return min(score, 1.0)
    
    def _get_default_preference_vector(self, user: User) -> Dict:
        """获取默认用户偏好向量（冷启动）"""
        return {
            "task_types": [],
            "locations": [user.residence_city] if user.residence_city else [],
            "price_range": {"min": 0, "max": float('inf')},
            "task_levels": [user.user_level] if user.user_level else ["normal"],
            "keywords": []
        }
    
    def _find_similar_users(
        self, 
        user_id: str, 
        user_interactions: set, 
        k: int = 10
    ) -> List[Tuple[str, float]]:
        """找到相似用户（优化版）"""
        if not user_interactions or len(user_interactions) < 2:
            return []
        
        # 优化：只查询有交互记录的用户，避免查询所有用户
        from app.models import UserTaskInteraction
        from sqlalchemy import func
        
        # 获取所有有交互记录的用户ID（限制最多100个，防止内存溢出）
        active_user_ids = self.db.query(
            func.distinct(UserTaskInteraction.user_id)
        ).filter(
            UserTaskInteraction.user_id != user_id,
            UserTaskInteraction.task_id.in_(list(user_interactions))
        ).limit(100).all()
        
        if not active_user_ids:
            return []
        
        # 批量获取这些用户的交互记录
        similar_users = []
        for (other_user_id,) in active_user_ids:
            other_interactions = self._get_user_interactions(other_user_id)
            if not other_interactions or len(other_interactions) < 2:
                continue
            
            # 计算Jaccard相似度
            intersection = len(user_interactions & other_interactions)
            union = len(user_interactions | other_interactions)
            
            if union > 0:
                similarity = intersection / union
                # 调整阈值，考虑用户交互数量
                min_similarity = 0.1 if len(user_interactions) >= 5 else 0.05
                if similarity > min_similarity:
                    similar_users.append((other_user_id, similarity))
        
        # 按相似度排序
        similar_users.sort(key=lambda x: x[1], reverse=True)
        return similar_users[:k]
    
    def _get_user_liked_tasks(self, user_id: str) -> set:
        """获取用户喜欢的任务（接受或完成的任务）"""
        # 限制最多1000条历史记录，防止内存溢出
        history = self.db.query(TaskHistory).filter(
            TaskHistory.user_id == user_id,
            TaskHistory.action.in_(["accepted", "completed"])
        ).order_by(desc(TaskHistory.timestamp)).limit(1000).all()
        return {h.task_id for h in history}
    
    def _has_enough_data(self, user_id: str) -> bool:
        """检查用户是否有足够的数据进行协同过滤"""
        interactions = self._get_user_interactions(user_id)
        return len(interactions) >= 3
    
    def _generate_recommendation_reason(
        self, 
        user_vector: Dict, 
        task: Task, 
        score: float,
        language: str = "zh"
    ) -> str:
        """生成推荐理由（智能生成，支持多语言）"""
        reasons = []
        
        # 多语言支持
        if language == "en":
            # 英文理由
            if user_vector["task_types"] and task.task_type in user_vector["task_types"]:
                reasons.append(f"You often accept {task.task_type} tasks")
            
            if user_vector["locations"] and task.location:
                for loc in user_vector["locations"]:
                    if loc.lower() in task.location.lower() or task.location.lower() in loc.lower():
                        if "online" not in task.location.lower():
                            reasons.append(f"Located in {loc} where you often work")
                        else:
                            reasons.append("Can be completed online")
                        break
            
            if task.reward:
                price = float(task.reward)
                price_range = user_vector["price_range"]
                if price_range["min"] <= price <= price_range["max"]:
                    reasons.append("Price within your range")
                elif price > price_range["max"]:
                    reasons.append("High-value task")
            
            if task.deadline:
                now = get_utc_time()
                days_left = (task.deadline - now).days if hasattr(task.deadline, 'days') else 0
                if days_left <= 3:
                    reasons.append("Deadline approaching")
                elif days_left <= 7:
                    reasons.append("Recent task")
            
            if not reasons:
                if score >= 0.7:
                    reasons.append("Recommended based on your preferences")
                else:
                    reasons.append("May be suitable for you")
        else:
            # 中文理由（默认）
            # 根据匹配分数确定推荐强度
            if score >= 0.8:
                intensity = "高度"
            elif score >= 0.6:
                intensity = "中等"
            else:
                intensity = "可能"
            
            # 任务类型匹配
            if user_vector["task_types"] and task.task_type in user_vector["task_types"]:
                reasons.append(f"您常接受{task.task_type}类任务")
            
            # 位置匹配
            if user_vector["locations"] and task.location:
                for loc in user_vector["locations"]:
                    if loc.lower() in task.location.lower() or task.location.lower() in loc.lower():
                        if "online" not in task.location.lower():
                            reasons.append(f"位于您常去的{loc}")
                        else:
                            reasons.append("支持在线完成")
                        break
            
            # 价格匹配
            if task.reward:
                price = float(task.reward)
                price_range = user_vector["price_range"]
                if price_range["min"] <= price <= price_range["max"]:
                    reasons.append("价格在您的接受范围内")
                elif price > price_range["max"]:
                    reasons.append("高价值任务")
            
            # 任务等级匹配
            if user_vector["task_levels"] and task.task_level in user_vector["task_levels"]:
                if task.task_level == "vip":
                    reasons.append("VIP任务")
                elif task.task_level == "super":
                    reasons.append("超级任务")
            
            # 时间匹配
            if task.deadline:
                now = get_utc_time()
                days_left = (task.deadline - now).days if hasattr(task.deadline, 'days') else 0
                if days_left <= 3:
                    reasons.append("即将截止")
                elif days_left <= 7:
                    reasons.append("近期任务")
            
            # 如果没有具体理由，使用通用理由
            if not reasons:
                if score >= 0.7:
                    reasons.append("根据您的偏好推荐")
                else:
                    reasons.append("可能适合您")
        
        return "；".join(reasons[:3]) if language == "zh" else " | ".join(reasons[:3])  # 最多显示3个理由


def get_task_recommendations(
    db: Session,
    user_id: str,
    limit: int = 20,
    algorithm: str = "hybrid",
    task_type: Optional[str] = None,
    location: Optional[str] = None,
    keyword: Optional[str] = None
) -> List[Dict]:
    """
    获取任务推荐的便捷函数（支持筛选）
    
    Args:
        db: 数据库会话
        user_id: 用户ID
        limit: 返回数量
        algorithm: 算法类型
        task_type: 任务类型筛选
        location: 地点筛选
        keyword: 关键词筛选
    
    Returns:
        推荐任务列表
    """
    engine = TaskRecommendationEngine(db)
    return engine.recommend_tasks(
        user_id, limit, algorithm, task_type, location, keyword
    )


def calculate_task_match_score(
    db: Session,
    user_id: str,
    task_id: int
) -> float:
    """
    计算任务对用户的匹配分数
    
    Args:
        db: 数据库会话
        user_id: 用户ID
        task_id: 任务ID
    
    Returns:
        匹配分数 (0-1)
    """
    user = db.query(User).filter(User.id == user_id).first()
    task = db.query(Task).filter(Task.id == task_id).first()
    
    if not user or not task:
        return 0.0
    
    engine = TaskRecommendationEngine(db)
    user_preferences = engine._get_user_preferences(user_id)
    user_history = engine._get_user_task_history(user_id)
    user_vector = engine._build_user_preference_vector(user, user_preferences, user_history)
    
    return engine._calculate_content_match_score(user_vector, task, user)
