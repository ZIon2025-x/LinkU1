"""
推荐系统查询优化模块
优化数据库查询，减少查询次数，提高效率
"""

import logging
from typing import List, Dict, Set, Optional
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, or_, desc
from sqlalchemy.orm import selectinload

from app.models import Task, User, UserPreferences, TaskHistory, UserTaskInteraction
from app.crud import get_utc_time

logger = logging.getLogger(__name__)


class RecommendationQueryOptimizer:
    """推荐系统查询优化器"""
    
    def __init__(self, db: Session):
        self.db = db
    
    def batch_get_tasks_with_details(
        self,
        task_ids: List[int],
        preload_relations: bool = True
    ) -> Dict[int, Task]:
        """
        批量获取任务详情（优化N+1查询）
        
        Args:
            task_ids: 任务ID列表
            preload_relations: 是否预加载关联数据
        
        Returns:
            任务ID到任务对象的映射
        """
        if not task_ids:
            return {}
        
        try:
            query = self.db.query(Task).filter(Task.id.in_(task_ids))
            
            # 预加载关联数据，避免N+1查询
            if preload_relations:
                query = query.options(
                    selectinload(Task.poster),
                    selectinload(Task.taker),
                )
            
            tasks = query.all()
            return {task.id: task for task in tasks}
        except Exception as e:
            logger.error(f"批量获取任务详情失败: {e}", exc_info=True)
            return {}
    
    def batch_get_tasks_for_diversity(
        self,
        task_ids: List[int],
        limit: int
    ) -> Dict[int, Task]:
        """
        批量获取任务用于多样性判断（只加载必要字段）
        
        优化：只查询需要的字段（id, task_type, location），减少数据传输
        
        Args:
            task_ids: 任务ID列表
            limit: 限制数量
        
        Returns:
            任务ID到任务对象的映射（只包含必要字段）
        """
        if not task_ids:
            return {}
        
        try:
            # 只查询需要的字段，减少数据传输
            tasks = self.db.query(
                Task.id,
                Task.task_type,
                Task.location
            ).filter(
                Task.id.in_(task_ids[:limit * 2])  # 只查询前2倍数量的任务
            ).all()
            
            # 转换为字典格式（使用简化对象）
            task_dict = {}
            for task_id, task_type, location in tasks:
                # 创建简化对象
                class SimpleTask:
                    def __init__(self, id, task_type, location):
                        self.id = id
                        self.task_type = task_type
                        self.location = location
                
                task_dict[task_id] = SimpleTask(task_id, task_type, location)
            
            return task_dict
        except Exception as e:
            logger.error(f"批量获取任务用于多样性判断失败: {e}", exc_info=True)
            # 降级：使用完整查询
            return self.batch_get_tasks_with_details(task_ids, preload_relations=False)
    
    def optimize_task_query(
        self,
        base_query,
        excluded_task_ids: Set[int],
        limit: int,
        max_excluded: int = 1000
    ):
        """
        优化任务查询，处理大量排除任务ID的情况
        
        Args:
            base_query: 基础查询对象
            excluded_task_ids: 排除的任务ID集合
            max_excluded: 使用NOT IN的最大任务ID数量
        
        Returns:
            优化后的查询对象
        """
        if not excluded_task_ids:
            return base_query.limit(limit)
        
        if len(excluded_task_ids) <= max_excluded:
            # 任务ID数量少，使用NOT IN
            return base_query.filter(~Task.id.in_(excluded_task_ids)).limit(limit)
        else:
            # 任务ID数量多，限制排除列表大小
            excluded_list = list(excluded_task_ids)[:max_excluded]
            return base_query.filter(~Task.id.in_(excluded_list)).limit(limit)
    
    def batch_calculate_scores(
        self,
        tasks: List[Task],
        user_vector: Dict,
        user: User,
        excluded_task_ids: Set[int]
    ) -> List[Dict]:
        """
        批量计算任务匹配分数（优化版本）
        
        Args:
            tasks: 任务列表
            user_vector: 用户偏好向量
            user: 用户对象
            excluded_task_ids: 排除的任务ID集合
        
        Returns:
            带分数的任务列表
        """
        from app.task_recommendation import TaskRecommendationEngine
        engine = TaskRecommendationEngine(self.db)
        
        scored_tasks = []
        now = get_utc_time()
        
        for task in tasks:
            # 跳过已排除的任务
            if task.id in excluded_task_ids:
                continue
            
            # 计算基础匹配分数
            base_score = engine._calculate_content_match_score(user_vector, task, user)
            
            # 新任务加成
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


def optimize_diversity_query(
    db: Session,
    task_ids: List[int],
    limit: int
) -> Dict[int, Dict]:
    """
    优化多样性判断的查询（只查询必要字段）
    
    Args:
        db: 数据库会话
        task_ids: 任务ID列表
        limit: 限制数量
    
    Returns:
        任务ID到任务信息的映射（只包含必要字段）
    """
    if not task_ids:
        return {}
    
    try:
        # 只查询需要的字段（id, task_type, location）
        tasks = db.query(
            Task.id,
            Task.task_type,
            Task.location
        ).filter(
            Task.id.in_(task_ids[:limit * 2])  # 只查询前2倍数量
        ).all()
        
        # 转换为字典
        task_info = {}
        for task_id, task_type, location in tasks:
            task_info[task_id] = {
                "id": task_id,
                "task_type": task_type,
                "location": location
            }
        
        return task_info
    except Exception as e:
        logger.error(f"优化多样性查询失败: {e}", exc_info=True)
        return {}
