"""
推荐系统降级策略
当推荐系统出现问题时，提供降级方案
"""

import logging
from typing import List, Dict, Optional
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import func, desc

from app.models import Task, User
from app.crud import get_utc_time

logger = logging.getLogger(__name__)


class RecommendationFallback:
    """推荐系统降级策略"""
    
    def __init__(self, db: Session):
        self.db = db
    
    def get_fallback_recommendations(
        self,
        user_id: str,
        limit: int = 20,
        task_type: Optional[str] = None,
        location: Optional[str] = None,
        keyword: Optional[str] = None
    ) -> List[Dict]:
        """
        获取降级推荐（当主推荐系统失败时使用）
        
        策略：
        1. 热门任务（最近24小时最受欢迎）
        2. 新发布的任务
        3. 高价值任务
        4. 即将截止的任务
        """
        try:
            recommendations = []
            
            # 1. 热门任务（40%）
            popular_tasks = self._get_popular_tasks(limit=int(limit * 0.4), task_type=task_type, location=location, keyword=keyword)
            for task in popular_tasks:
                recommendations.append({
                    "task": task,
                    "score": 0.6,
                    "reason": "热门任务"
                })
            
            # 2. 新发布的任务（30%）
            new_tasks = self._get_new_tasks(limit=int(limit * 0.3), task_type=task_type, location=location, keyword=keyword)
            for task in new_tasks:
                if task.id not in [r["task"].id for r in recommendations]:
                    recommendations.append({
                        "task": task,
                        "score": 0.5,
                        "reason": "新发布"
                    })
            
            # 3. 高价值任务（20%）
            high_value_tasks = self._get_high_value_tasks(limit=int(limit * 0.2), task_type=task_type, location=location, keyword=keyword)
            for task in high_value_tasks:
                if task.id not in [r["task"].id for r in recommendations]:
                    recommendations.append({
                        "task": task,
                        "score": 0.55,
                        "reason": "高价值任务"
                    })
            
            # 4. 即将截止的任务（10%）
            urgent_tasks = self._get_urgent_tasks(limit=int(limit * 0.1), task_type=task_type, location=location, keyword=keyword)
            for task in urgent_tasks:
                if task.id not in [r["task"].id for r in recommendations]:
                    recommendations.append({
                        "task": task,
                        "score": 0.45,
                        "reason": "即将截止"
                    })
            
            # 去重并限制数量
            seen_ids = set()
            unique_recommendations = []
            for rec in recommendations:
                if rec["task"].id not in seen_ids and len(unique_recommendations) < limit:
                    seen_ids.add(rec["task"].id)
                    unique_recommendations.append(rec)
            
            return unique_recommendations
            
        except Exception as e:
            logger.error(f"降级推荐失败: {e}", exc_info=True)
            return []
    
    def _get_popular_tasks(
        self,
        limit: int,
        task_type: Optional[str] = None,
        location: Optional[str] = None,
        keyword: Optional[str] = None
    ) -> List[Task]:
        """获取热门任务"""
        from app.models import UserTaskInteraction
        from sqlalchemy import and_, or_
        
        recent_time = datetime.utcnow() - timedelta(hours=24)
        
        # 统计任务交互数
        query = self.db.query(
            Task.id,
            func.count(UserTaskInteraction.id).label('interaction_count')
        ).join(
            UserTaskInteraction,
            Task.id == UserTaskInteraction.task_id
        ).filter(
            and_(
                UserTaskInteraction.interaction_time >= recent_time,
                Task.status == "open"
            )
        )
        
        # 应用筛选
        if task_type and task_type != "all":
            query = query.filter(Task.task_type == task_type)
        if location and location != "all":
            if location.lower() == 'online':
                query = query.filter(Task.location.ilike("%online%"))
            else:
                query = query.filter(or_(
                    Task.location.ilike(f"%, {location}%"),
                    Task.location.ilike(f"{location},%"),
                    Task.location.ilike(f"{location}")
                ))
        if keyword:
            query = query.filter(or_(
                Task.title.ilike(f"%{keyword}%"),
                Task.description.ilike(f"%{keyword}%")
            ))
        
        popular_task_ids = query.group_by(Task.id).order_by(desc('interaction_count')).limit(limit).all()
        
        if not popular_task_ids:
            # 如果没有交互数据，返回最近发布的任务
            return self._get_new_tasks(limit, task_type, location, keyword)
        
        task_ids = [task_id for task_id, _ in popular_task_ids]
        tasks = self.db.query(Task).filter(Task.id.in_(task_ids)).all()
        
        # 按交互数排序
        task_dict = {task.id: task for task in tasks}
        sorted_tasks = []
        for task_id, _ in popular_task_ids:
            if task_id in task_dict:
                sorted_tasks.append(task_dict[task_id])
        
        return sorted_tasks
    
    def _get_new_tasks(
        self,
        limit: int,
        task_type: Optional[str] = None,
        location: Optional[str] = None,
        keyword: Optional[str] = None
    ) -> List[Task]:
        """获取新发布的任务"""
        from sqlalchemy import and_, or_
        
        query = self.db.query(Task).filter(
            Task.status == "open"
        ).order_by(desc(Task.created_at))
        
        # 应用筛选
        if task_type and task_type != "all":
            query = query.filter(Task.task_type == task_type)
        if location and location != "all":
            if location.lower() == 'online':
                query = query.filter(Task.location.ilike("%online%"))
            else:
                query = query.filter(or_(
                    Task.location.ilike(f"%, {location}%"),
                    Task.location.ilike(f"{location},%"),
                    Task.location.ilike(f"{location}")
                ))
        if keyword:
            query = query.filter(or_(
                Task.title.ilike(f"%{keyword}%"),
                Task.description.ilike(f"%{keyword}%")
            ))
        
        return query.limit(limit).all()
    
    def _get_high_value_tasks(
        self,
        limit: int,
        task_type: Optional[str] = None,
        location: Optional[str] = None,
        keyword: Optional[str] = None
    ) -> List[Task]:
        """获取高价值任务"""
        from sqlalchemy import and_, or_
        
        query = self.db.query(Task).filter(
            Task.status == "open",
            Task.reward.isnot(None)
        ).order_by(desc(Task.reward))
        
        # 应用筛选
        if task_type and task_type != "all":
            query = query.filter(Task.task_type == task_type)
        if location and location != "all":
            if location.lower() == 'online':
                query = query.filter(Task.location.ilike("%online%"))
            else:
                query = query.filter(or_(
                    Task.location.ilike(f"%, {location}%"),
                    Task.location.ilike(f"{location},%"),
                    Task.location.ilike(f"{location}")
                ))
        if keyword:
            query = query.filter(or_(
                Task.title.ilike(f"%{keyword}%"),
                Task.description.ilike(f"%{keyword}%")
            ))
        
        return query.limit(limit).all()
    
    def _get_urgent_tasks(
        self,
        limit: int,
        task_type: Optional[str] = None,
        location: Optional[str] = None,
        keyword: Optional[str] = None
    ) -> List[Task]:
        """获取即将截止的任务"""
        from sqlalchemy import and_, or_
        
        now = get_utc_time()
        soon = now + timedelta(days=3)
        
        query = self.db.query(Task).filter(
            Task.status == "open",
            Task.deadline.isnot(None),
            Task.deadline >= now,
            Task.deadline <= soon
        ).order_by(Task.deadline.asc())
        
        # 应用筛选
        if task_type and task_type != "all":
            query = query.filter(Task.task_type == task_type)
        if location and location != "all":
            if location.lower() == 'online':
                query = query.filter(Task.location.ilike("%online%"))
            else:
                query = query.filter(or_(
                    Task.location.ilike(f"%, {location}%"),
                    Task.location.ilike(f"{location},%"),
                    Task.location.ilike(f"{location}")
                ))
        if keyword:
            query = query.filter(or_(
                Task.title.ilike(f"%{keyword}%"),
                Task.description.ilike(f"%{keyword}%")
            ))
        
        return query.limit(limit).all()


def get_fallback_recommendations(
    db: Session,
    user_id: str,
    limit: int = 20,
    task_type: Optional[str] = None,
    location: Optional[str] = None,
    keyword: Optional[str] = None
) -> List[Dict]:
    """获取降级推荐的便捷函数"""
    fallback = RecommendationFallback(db)
    return fallback.get_fallback_recommendations(user_id, limit, task_type, location, keyword)
