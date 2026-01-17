"""
推荐系统计算优化模块
针对高并发场景，减少重复计算，提高效率
"""

import logging
from typing import Dict, Set, List, Optional, Tuple
from functools import lru_cache
from datetime import datetime, timedelta
from sqlalchemy.orm import Session

from app.models import Task, User, UserPreferences, TaskHistory
from app.crud import get_utc_time
from app.redis_cache import redis_cache

logger = logging.getLogger(__name__)


class RecommendationComputeCache:
    """推荐计算缓存管理器（单次推荐请求内复用）"""
    
    def __init__(self, db: Session, user: User):
        self.db = db
        self.user = user
        self._excluded_task_ids: Optional[Set[int]] = None
        self._user_preferences: Optional[UserPreferences] = None
        self._user_history: Optional[List[TaskHistory]] = None
        self._is_new_user: Optional[bool] = None
        self._user_interactions: Optional[Set[int]] = None
        self._popular_tasks: Optional[List[Dict]] = None
        self._task_info_cache: Dict[int, Dict] = {}  # 任务信息缓存
    
    def get_excluded_task_ids(self) -> Set[int]:
        """获取排除任务ID（只计算一次）"""
        if self._excluded_task_ids is None:
            from app.recommendation_utils import get_excluded_task_ids
            self._excluded_task_ids = get_excluded_task_ids(self.db, self.user.id)
        return self._excluded_task_ids
    
    def get_user_preferences(self) -> Optional[UserPreferences]:
        """获取用户偏好（只查询一次）"""
        if self._user_preferences is None:
            self._user_preferences = self.db.query(UserPreferences).filter(
                UserPreferences.user_id == self.user.id
            ).first()
        return self._user_preferences
    
    def get_user_history(self) -> List[TaskHistory]:
        """获取用户历史（只查询一次）"""
        if self._user_history is None:
            from sqlalchemy import desc
            self._user_history = self.db.query(TaskHistory).filter(
                TaskHistory.user_id == self.user.id
            ).order_by(desc(TaskHistory.timestamp)).limit(50).all()
        return self._user_history
    
    def is_new_user(self) -> bool:
        """判断是否为新用户（只计算一次）"""
        if self._is_new_user is None:
            if not self.user.created_at:
                self._is_new_user = False
            else:
                now = get_utc_time()
                days_since_registration = (now - self.user.created_at).days if hasattr(self.user.created_at, 'days') else 999
                self._is_new_user = days_since_registration <= 7
        return self._is_new_user
    
    def get_user_interactions(self) -> Set[int]:
        """获取用户交互过的任务ID（只计算一次）"""
        if self._user_interactions is None:
            history = self.get_user_history()
            self._user_interactions = {h.task_id for h in history}
        return self._user_interactions
    
    def get_popular_tasks(self, limit: int = 30) -> List[Dict]:
        """获取热门任务（全局缓存，所有用户共享）"""
        cache_key = f"popular_task_ids:{limit}"
        
        task_ids = None
        # 尝试从缓存获取任务ID（只缓存ID，避免序列化SQLAlchemy对象）
        try:
            cached = redis_cache.get(cache_key)
            if cached:
                import json
                if isinstance(cached, bytes):
                    task_ids = json.loads(cached.decode('utf-8'))
                elif isinstance(cached, str):
                    task_ids = json.loads(cached)
                elif isinstance(cached, list):
                    task_ids = cached
        except Exception as e:
            logger.warning(f"读取热门任务缓存失败: {e}")
        
        # 如果有缓存的任务ID，查询任务对象
        if task_ids:
            tasks = self.db.query(Task).filter(
                Task.id.in_(task_ids),
                Task.status == "open"
            ).all()
            # 按缓存顺序排序
            task_dict = {task.id: task for task in tasks}
            return [
                {"task": task_dict[tid], "score": 0.8, "reason": "热门任务"}
                for tid in task_ids if tid in task_dict
            ]
        
        # 缓存未命中，查询数据库
        recent_time = get_utc_time() - timedelta(hours=24)
        tasks = self.db.query(Task).filter(
            Task.status == "open",
            Task.created_at >= recent_time
        ).order_by(Task.created_at.desc()).limit(limit).all()
        
        result = [{"task": task, "score": 0.8, "reason": "热门任务"} for task in tasks]
        
        # 只缓存任务ID（避免序列化SQLAlchemy对象的问题）
        try:
            import json
            task_ids_to_cache = [task.id for task in tasks]
            redis_cache.setex(cache_key, 900, json.dumps(task_ids_to_cache))
        except Exception as e:
            logger.warning(f"缓存热门任务失败: {e}")
        
        return result
    
    def cache_task_info(self, task_id: int, info: Dict):
        """缓存任务信息"""
        self._task_info_cache[task_id] = info
    
    def get_cached_task_info(self, task_id: int) -> Optional[Dict]:
        """获取缓存的任务信息"""
        return self._task_info_cache.get(task_id)


def batch_apply_filters(
    recommendations: List[Dict],
    task_type: Optional[str] = None,
    location: Optional[str] = None,
    keyword: Optional[str] = None
) -> List[Dict]:
    """
    批量应用筛选条件（统一处理，避免重复代码）
    
    Args:
        recommendations: 推荐结果列表
        task_type: 任务类型筛选
        location: 地点筛选
        keyword: 关键词筛选
    
    Returns:
        筛选后的推荐结果
    """
    if not recommendations:
        return []
    
    filtered = []
    for item in recommendations:
        task = item.get("task")
        if not task:
            continue
        
        # 任务类型筛选
        if task_type and task_type.strip() and task_type != "all":
            if task.task_type != task_type.strip():
                continue
        
        # 地点筛选
        if location and location.strip() and location != "all":
            loc = location.strip()
            if loc.lower() == 'online':
                if 'online' not in task.location.lower():
                    continue
            else:
                if not any([
                    loc in task.location,
                    task.location.startswith(f"{loc},"),
                    task.location.endswith(f", {loc}"),
                    task.location == loc
                ]):
                    continue
        
        # 关键词筛选
        if keyword and keyword.strip():
            keyword_clean = keyword.strip().lower()
            task_text = f"{task.title} {task.description}".lower()
            if keyword_clean not in task_text:
                continue
        
        filtered.append(item)
    
    return filtered


def batch_calculate_match_scores(
    tasks: List[Task],
    user_vector: Dict,
    user: User,
    compute_cache: RecommendationComputeCache
) -> List[Dict]:
    """
    批量计算匹配分数（减少重复计算）
    
    Args:
        tasks: 任务列表
        user_vector: 用户偏好向量
        user: 用户对象
        compute_cache: 计算缓存
    
    Returns:
        带分数的任务列表
    """
    from app.task_recommendation import TaskRecommendationEngine
    engine = TaskRecommendationEngine(compute_cache.db)
    
    now = get_utc_time()
    scored_tasks = []
    
    for task in tasks:
        # 计算基础匹配分数
        base_score = engine._calculate_content_match_score(user_vector, task, user)
        
        # 新任务加成（只计算一次）
        if engine._is_new_task(task):
            time_bonus = 0.1
            if engine._is_new_user_task(task):
                time_bonus += 0.15
            base_score = min(1.0, base_score + time_bonus)
        
        if base_score > 0:
            reason = engine._generate_recommendation_reason(user_vector, task, base_score)
            if engine._is_new_user_task(task):
                reason = "新用户发布，优先推荐；" + reason
            elif engine._is_new_task(task):
                reason = "新发布任务；" + reason
            
            scored_tasks.append({
                "task": task,
                "score": base_score,
                "reason": reason
            })
    
    return scored_tasks


def optimize_hybrid_recommendation(
    compute_cache: RecommendationComputeCache,
    limit: int,
    task_type: Optional[str] = None,
    location: Optional[str] = None,
    keyword: Optional[str] = None,
    latitude: Optional[float] = None,
    longitude: Optional[float] = None
) -> Tuple[Dict[int, float], Dict[int, str]]:
    """
    优化的混合推荐（减少重复计算）
    
    Args:
        compute_cache: 计算缓存管理器
        limit: 推荐数量
        task_type: 任务类型筛选
        location: 地点筛选
        keyword: 关键词筛选
        latitude: 用户当前纬度（用于基于位置的推荐）
        longitude: 用户当前经度（用于基于位置的推荐）
    
    返回:
        (scores, reasons) - 任务ID到分数和理由的映射
    """
    from app.task_recommendation import TaskRecommendationEngine
    engine = TaskRecommendationEngine(compute_cache.db)
    # 设置当前请求的GPS位置
    engine._current_latitude = latitude
    engine._current_longitude = longitude
    
    scores = {}
    reasons = {}
    
    # 只计算一次的用户信息
    is_new_user = compute_cache.is_new_user()
    excluded_task_ids = compute_cache.get_excluded_task_ids()
    
    # 1. 基于内容的推荐（权重：30%，新用户时降低到25%）
    # 总权重100%：新用户 25+15+15+15+10+12+8=100 | 老用户 30+25+10+15+10+2+8=100
    content_weight = 0.25 if is_new_user else 0.30
    content_based = engine._content_based_recommend(
        compute_cache.user, limit=50, task_type=task_type, location=location, keyword=keyword
    )
    # 应用筛选条件（统一处理）
    content_based = batch_apply_filters(content_based, task_type, location, keyword)
    for item in content_based:
        task_id = item["task"].id
        if task_id not in excluded_task_ids:
            scores[task_id] = scores.get(task_id, 0) + item["score"] * content_weight
            reasons[task_id] = item["reason"]
    
    # 2. 协同过滤推荐（权重：25%，新用户时降低到15%）
    collaborative_weight = 0.15 if is_new_user else 0.25
    if engine._has_enough_data(compute_cache.user.id):
        collaborative = engine._collaborative_filtering_recommend(
            compute_cache.user, limit=50, task_type=task_type, location=location, keyword=keyword
        )
        collaborative = batch_apply_filters(collaborative, task_type, location, keyword)
        for item in collaborative:
            task_id = item["task"].id
            if task_id not in excluded_task_ids:
                scores[task_id] = scores.get(task_id, 0) + item["score"] * collaborative_weight
                if task_id not in reasons:
                    reasons[task_id] = item["reason"]
    
    # 3. 新任务优先推荐（权重：10%，新用户时提高到15%）
    new_task_weight = 0.15 if is_new_user else 0.10
    new_tasks = engine._new_task_boost_recommend(
        compute_cache.user, limit=30, task_type=task_type, location=location, keyword=keyword
    )
    new_tasks = batch_apply_filters(new_tasks, task_type, location, keyword)
    for item in new_tasks:
        task_id = item["task"].id
        if task_id not in excluded_task_ids:
            scores[task_id] = scores.get(task_id, 0) + item["score"] * new_task_weight
            if task_id not in reasons:
                reasons[task_id] = item["reason"]
    
    # 4. 社交关系推荐（新增功能）⭐
    social_based = engine._social_based_recommend(compute_cache.user, limit=30)
    social_based = batch_apply_filters(social_based, task_type, location, keyword)
    for item in social_based:
        task_id = item["task"].id
        if task_id not in excluded_task_ids:
            scores[task_id] = scores.get(task_id, 0) + item["score"] * 0.15
            if task_id not in reasons:
                reasons[task_id] = item["reason"]
    
    # 5. 地理位置推荐（权重从12%降低到10%）
    location_based = engine._location_based_recommend(compute_cache.user, limit=30)
    location_based = batch_apply_filters(location_based, task_type, location, keyword)
    for item in location_based:
        task_id = item["task"].id
        if task_id not in excluded_task_ids:
            scores[task_id] = scores.get(task_id, 0) + item["score"] * 0.10
            if task_id not in reasons:
                reasons[task_id] = item["reason"]
    
    # 6. 热门任务推荐
    # 注意：热门任务主要用于解决冷启动问题和增加多样性
    # 权重根据用户数据量动态调整
    if is_new_user:
        # 新用户：热门任务权重稍高（12%），帮助发现兴趣
        popular_weight = 0.12
    else:
        # 老用户：热门任务权重更低（2%），更精准个性化
        popular_weight = 0.02
    
    popular = compute_cache.get_popular_tasks(limit=30)
    # 应用用户特定的排除和筛选（在内存中过滤，避免重复查询）
    # 即使热门任务也会根据用户筛选条件过滤，确保相关性
    popular = [item for item in popular 
               if item["task"].id not in excluded_task_ids 
               and item["task"].poster_id != compute_cache.user.id
               and item["task"].status == "open"]  # 确保状态正确
    popular = batch_apply_filters(popular, task_type, location, keyword)
    for item in popular:
        task_id = item["task"].id
        scores[task_id] = scores.get(task_id, 0) + item["score"] * popular_weight
        if task_id not in reasons:
            reasons[task_id] = item["reason"]
    
    # 7. 时间匹配推荐（权重从5%提高到8%，增强功能）
    time_based = engine._time_based_recommend(compute_cache.user, limit=20)
    time_based = batch_apply_filters(time_based, task_type, location, keyword)
    for item in time_based:
        task_id = item["task"].id
        if task_id not in excluded_task_ids:
            scores[task_id] = scores.get(task_id, 0) + item["score"] * 0.08
            if task_id not in reasons:
                reasons[task_id] = item["reason"]
    
    return scores, reasons
