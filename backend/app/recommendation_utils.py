"""
推荐系统工具函数
提供通用的过滤和排除逻辑
"""

from typing import Set, List
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_

from app.models import Task, TaskApplication, TaskHistory, TaskParticipant, User


def get_excluded_task_ids(db: Session, user_id: str, use_cache: bool = True) -> Set[int]:
    """
    获取应该从推荐中排除的任务ID集合（带缓存优化）
    
    排除规则：
    1. 用户自己发布的任务
    2. 用户已接受的任务（taker_id）
    3. 用户已申请的任务（TaskApplication）
    4. 用户已完成的任务（TaskHistory）
    5. 用户作为参与者的多人任务（TaskParticipant）
    6. 已关闭/取消的任务（status != "open"）
    
    Args:
        db: 数据库会话
        user_id: 用户ID
        use_cache: 是否使用缓存（默认True）
    
    Returns:
        应该排除的任务ID集合
    """
    # 尝试使用性能优化版本
    try:
        from app.recommendation_performance import get_excluded_task_ids_cached
        return get_excluded_task_ids_cached(db, user_id, use_cache)
    except ImportError:
        # 如果性能模块不可用，使用原始实现
        pass
    
    excluded_ids = set()
    
    try:
        # 1. 用户自己发布的任务
        posted_tasks = db.query(Task.id).filter(
            Task.poster_id == user_id
        ).all()
        excluded_ids.update([task.id for task in posted_tasks])
        
        # 2. 用户已接受的任务（单人任务）
        taken_tasks = db.query(Task.id).filter(
            Task.taker_id == user_id
        ).all()
        excluded_ids.update([task.id for task in taken_tasks])
        
        # 3. 用户已申请的任务（无论状态如何，都不再推荐）
        applications = db.query(TaskApplication.task_id).filter(
            TaskApplication.applicant_id == user_id
        ).all()
        excluded_ids.update([app.task_id for app in applications])
        
        # 4. 用户已完成的任务（从TaskHistory中获取）
        completed_tasks = db.query(TaskHistory.task_id).filter(
            and_(
                TaskHistory.user_id == user_id,
                TaskHistory.action.in_(["accepted", "completed"])
            )
        ).distinct().all()
        excluded_ids.update([h.task_id for h in completed_tasks])
        
        # 5. 用户作为参与者的多人任务
        participant_tasks = db.query(TaskParticipant.task_id).filter(
            and_(
                TaskParticipant.user_id == user_id,
                TaskParticipant.status.in_(["accepted", "in_progress", "completed"])
            )
        ).all()
        excluded_ids.update([p.task_id for p in participant_tasks])
        
        # 6. 已关闭/取消的任务（这些任务不应该被推荐）
        # 注意：这个在查询时已经通过 Task.status == "open" 过滤了
        
    except Exception as e:
        # 如果查询失败，记录错误但不影响推荐
        import logging
        logger = logging.getLogger(__name__)
        logger.warning(f"获取排除任务列表失败: {e}")
    
    return excluded_ids


def filter_recommendations(
    recommendations: List[dict],
    excluded_task_ids: Set[int]
) -> List[dict]:
    """
    过滤推荐结果，排除不应该推荐的任务
    
    Args:
        recommendations: 推荐结果列表
        excluded_task_ids: 应该排除的任务ID集合
    
    Returns:
        过滤后的推荐结果
    """
    if not excluded_task_ids:
        return recommendations
    
    filtered = []
    for rec in recommendations:
        task = rec.get("task")
        if task and task.id not in excluded_task_ids:
            filtered.append(rec)
    
    return filtered


def ensure_minimum_recommendations(
    recommendations: List[dict],
    min_count: int,
    db: Session,
    user_id: str,
    task_type: str = None,
    location: str = None,
    keyword: str = None
) -> List[dict]:
    """
    确保推荐结果达到最小数量
    
    如果推荐结果不足，从热门任务中补充
    
    Args:
        recommendations: 当前推荐结果
        min_count: 最小推荐数量
        db: 数据库会话
        user_id: 用户ID
        task_type: 任务类型筛选
        location: 地点筛选
        keyword: 关键词筛选
    
    Returns:
        补充后的推荐结果
    """
    if len(recommendations) >= min_count:
        return recommendations
    
    # 获取已推荐的任务ID
    recommended_ids = {rec["task"].id for rec in recommendations if rec.get("task")}
    
    # 获取排除的任务ID
    excluded_ids = get_excluded_task_ids(db, user_id)
    excluded_ids.update(recommended_ids)
    
    # 从热门任务中补充
    from app.recommendation_fallback import RecommendationFallback
    fallback = RecommendationFallback(db)
    
    # 获取补充推荐
    supplement = fallback.get_fallback_recommendations(
        user_id=user_id,
        limit=min_count - len(recommendations),
        task_type=task_type,
        location=location,
        keyword=keyword
    )
    
    # 过滤掉已排除的任务
    supplement = filter_recommendations(supplement, excluded_ids)
    
    # 合并推荐结果
    recommendations.extend(supplement)
    
    return recommendations[:min_count]
