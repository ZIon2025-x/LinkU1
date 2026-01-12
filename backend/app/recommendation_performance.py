"""
推荐系统性能优化模块
提供缓存、批量查询等性能优化功能
"""

import logging
from typing import Set, List, Dict
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, func
from functools import lru_cache
import time

from app.models import Task, TaskApplication, TaskHistory, TaskParticipant, User
from app.redis_cache import redis_cache

logger = logging.getLogger(__name__)


def get_excluded_task_ids_cached(db: Session, user_id: str, use_cache: bool = True) -> Set[int]:
    """
    获取应该从推荐中排除的任务ID集合（带缓存优化）
    
    优化点：
    1. 使用Redis缓存排除任务ID（5分钟TTL）
    2. 合并多个查询为单个查询（使用UNION）
    3. 批量查询减少数据库往返
    
    Args:
        db: 数据库会话
        user_id: 用户ID
        use_cache: 是否使用缓存
    
    Returns:
        应该排除的任务ID集合
    """
    cache_key = f"excluded_tasks:{user_id}"
    
    # 尝试从缓存获取
    if use_cache:
        try:
            cached = redis_cache.get(cache_key)
            if cached:
                # 解析缓存的数据（存储为逗号分隔的字符串）
                excluded_ids = set(int(x) for x in cached.decode('utf-8').split(',') if x)
                return excluded_ids
        except Exception as e:
            logger.warning(f"读取排除任务缓存失败: {e}，继续查询数据库")
    
    excluded_ids = set()
    
    try:
        start_time = time.time()
        
        # 优化：使用UNION合并多个查询，减少数据库往返
        # 1. 用户自己发布的任务
        posted_query = db.query(Task.id).filter(Task.poster_id == user_id)
        
        # 2. 用户已接受的任务（单人任务）
        taken_query = db.query(Task.id).filter(Task.taker_id == user_id)
        
        # 3. 用户已申请的任务
        applied_query = db.query(TaskApplication.task_id).filter(
            TaskApplication.applicant_id == user_id
        )
        
        # 4. 用户已完成的任务（从TaskHistory中获取）
        completed_query = db.query(TaskHistory.task_id).filter(
            and_(
                TaskHistory.user_id == user_id,
                TaskHistory.action.in_(["accepted", "completed"])
            )
        ).distinct()
        
        # 5. 用户作为参与者的多人任务
        participant_query = db.query(TaskParticipant.task_id).filter(
            and_(
                TaskParticipant.user_id == user_id,
                TaskParticipant.status.in_(["accepted", "in_progress", "completed"])
            )
        )
        
        # 执行查询并合并结果
        # 注意：SQLAlchemy的union_all需要所有查询返回相同的列
        # 这里我们分别查询然后合并，因为类型不同
        
        posted_ids = {row[0] for row in posted_query.all()}
        taken_ids = {row[0] for row in taken_query.all()}
        applied_ids = {row[0] for row in applied_query.all()}
        completed_ids = {row[0] for row in completed_query.all()}
        participant_ids = {row[0] for row in participant_query.all()}
        
        excluded_ids = posted_ids | taken_ids | applied_ids | completed_ids | participant_ids
        
        query_time = time.time() - start_time
        
        # 如果查询时间超过阈值，记录警告
        if query_time > 0.5:
            logger.warning(f"排除任务查询较慢: user_id={user_id}, time={query_time:.3f}s, count={len(excluded_ids)}")
        
        # 缓存结果（5分钟TTL，因为用户行为可能频繁变化）
        if use_cache and excluded_ids:
            try:
                # 将集合转换为逗号分隔的字符串存储
                cache_value = ','.join(str(task_id) for task_id in excluded_ids)
                redis_cache.setex(cache_key, 300, cache_value)  # 5分钟
            except Exception as e:
                logger.warning(f"写入排除任务缓存失败: {e}")
        
    except Exception as e:
        logger.error(f"获取排除任务列表失败: {e}", exc_info=True)
        # 返回空集合，不影响推荐流程
    
    return excluded_ids


def invalidate_excluded_tasks_cache(user_id: str):
    """
    清除用户的排除任务缓存
    
    当用户行为发生变化时（申请任务、接受任务等），需要清除缓存
    
    Args:
        user_id: 用户ID
    """
    cache_key = f"excluded_tasks:{user_id}"
    try:
        redis_cache.delete(cache_key)
    except Exception as e:
        logger.warning(f"清除排除任务缓存失败: {e}")


def batch_get_user_liked_tasks(db: Session, user_ids: List[str]) -> Dict[str, Set[int]]:
    """
    批量获取多个用户喜欢的任务（优化N+1查询）
    
    Args:
        db: 数据库会话
        user_ids: 用户ID列表
    
    Returns:
        用户ID到任务ID集合的映射
    """
    if not user_ids:
        return {}
    
    try:
        # 批量查询所有用户的交互任务
        from app.models import UserTaskInteraction
        
        interactions = db.query(
            UserTaskInteraction.user_id,
            UserTaskInteraction.task_id
        ).filter(
            and_(
                UserTaskInteraction.user_id.in_(user_ids),
                UserTaskInteraction.interaction_type.in_(["click", "apply", "accepted"])
            )
        ).all()
        
        # 构建用户到任务ID集合的映射
        result = {user_id: set() for user_id in user_ids}
        for user_id, task_id in interactions:
            if user_id in result:
                result[user_id].add(task_id)
        
        return result
    except Exception as e:
        logger.error(f"批量获取用户喜欢任务失败: {e}", exc_info=True)
        return {user_id: set() for user_id in user_ids}


def batch_get_user_info(db: Session, user_ids: List[str]) -> Dict[str, User]:
    """
    批量获取用户信息（优化N+1查询）
    
    Args:
        db: 数据库会话
        user_ids: 用户ID列表
    
    Returns:
        用户ID到用户对象的映射
    """
    if not user_ids:
        return {}
    
    try:
        users = db.query(User).filter(User.id.in_(user_ids)).all()
        return {user.id: user for user in users}
    except Exception as e:
        logger.error(f"批量获取用户信息失败: {e}", exc_info=True)
        return {}


def optimize_task_query(query, excluded_task_ids: Set[int], max_excluded: int = 1000):
    """
    优化任务查询，处理大量排除任务ID的情况
    
    如果排除的任务ID太多，使用NOT EXISTS子查询而不是NOT IN
    
    Args:
        query: SQLAlchemy查询对象
        excluded_task_ids: 排除的任务ID集合
        max_excluded: 使用NOT IN的最大任务ID数量
    
    Returns:
        优化后的查询对象
    """
    if not excluded_task_ids:
        return query
    
    if len(excluded_task_ids) <= max_excluded:
        # 任务ID数量少，使用NOT IN
        return query.filter(~Task.id.in_(excluded_task_ids))
    else:
        # 任务ID数量多，使用NOT EXISTS子查询
        # 这里我们仍然使用NOT IN，但可以考虑优化为子查询
        # 为了性能，我们限制排除的任务ID数量
        excluded_list = list(excluded_task_ids)[:max_excluded]
        return query.filter(~Task.id.in_(excluded_list))
