"""
推荐系统分析模块
提供推荐效果的深度分析
"""

import logging
from typing import Dict, List, Optional
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, desc, text

from app.models import UserTaskInteraction, Task, User, TaskHistory
from app.redis_cache import redis_cache

logger = logging.getLogger(__name__)


class RecommendationAnalytics:
    """推荐系统分析器"""
    
    def __init__(self, db: Session):
        self.db = db
    
    def get_recommendation_performance(
        self,
        days: int = 7,
        algorithm: Optional[str] = None
    ) -> Dict:
        """
        获取推荐系统性能分析
        
        Args:
            days: 统计天数
            algorithm: 算法类型（可选）
        
        Returns:
            性能分析报告
        """
        start_date = datetime.utcnow() - timedelta(days=days)
        
        # 1. 推荐任务统计
        recommended_stats = self._get_recommended_task_stats(start_date)
        
        # 2. 用户参与度分析
        engagement = self._analyze_user_engagement(start_date)
        
        # 3. 推荐质量分析
        quality = self._analyze_recommendation_quality(start_date)
        
        # 4. 算法对比（如果指定了算法）
        algorithm_comparison = None
        if algorithm:
            algorithm_comparison = self._compare_algorithms(start_date, algorithm)
        
        return {
            "period_days": days,
            "recommended_stats": recommended_stats,
            "user_engagement": engagement,
            "quality_metrics": quality,
            "algorithm_comparison": algorithm_comparison,
            "timestamp": datetime.utcnow().isoformat()
        }
    
    def _get_recommended_task_stats(self, start_date: datetime) -> Dict:
        """获取推荐任务统计"""
        # 推荐任务总数
        total_recommended = self.db.query(func.count(func.distinct(UserTaskInteraction.task_id))).filter(
            and_(
                UserTaskInteraction.interaction_time >= start_date,
                UserTaskInteraction.interaction_metadata.isnot(None),
                UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true'
            )
        ).scalar() or 0
        
        # 推荐任务浏览数
        views = self.db.query(func.count(UserTaskInteraction.id)).filter(
            and_(
                UserTaskInteraction.interaction_type == "view",
                UserTaskInteraction.interaction_time >= start_date,
                UserTaskInteraction.interaction_metadata.isnot(None),
                UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true'
            )
        ).scalar() or 0
        
        # 推荐任务点击数
        clicks = self.db.query(func.count(UserTaskInteraction.id)).filter(
            and_(
                UserTaskInteraction.interaction_type == "click",
                UserTaskInteraction.interaction_time >= start_date,
                UserTaskInteraction.interaction_metadata.isnot(None),
                UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true'
            )
        ).scalar() or 0
        
        # 推荐任务接受数
        from app.models import TaskHistory
        accepts = self.db.query(func.count(TaskHistory.id)).filter(
            and_(
                TaskHistory.action == "accepted",
                TaskHistory.timestamp >= start_date
            )
        ).join(
            UserTaskInteraction,
            and_(
                TaskHistory.task_id == UserTaskInteraction.task_id,
                TaskHistory.user_id == UserTaskInteraction.user_id,
                UserTaskInteraction.interaction_metadata.isnot(None),
                UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true'
            )
        ).scalar() or 0
        
        return {
            "total_recommended_tasks": total_recommended,
            "total_views": views,
            "total_clicks": clicks,
            "total_accepts": accepts,
            "click_rate": round(clicks / views, 4) if views > 0 else 0.0,
            "accept_rate": round(accepts / clicks, 4) if clicks > 0 else 0.0,
            "conversion_rate": round(accepts / views, 4) if views > 0 else 0.0
        }
    
    def _analyze_user_engagement(self, start_date: datetime) -> Dict:
        """分析用户参与度"""
        # 活跃用户数（有推荐交互的用户）
        active_users = self.db.query(
            func.count(func.distinct(UserTaskInteraction.user_id))
        ).filter(
            and_(
                UserTaskInteraction.interaction_time >= start_date,
                UserTaskInteraction.interaction_metadata.isnot(None),
                UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true'
            )
        ).scalar() or 0
        
        # 平均每个用户的推荐任务数
        total_interactions = self.db.query(func.count(UserTaskInteraction.id)).filter(
            and_(
                UserTaskInteraction.interaction_time >= start_date,
                UserTaskInteraction.interaction_metadata.isnot(None),
                UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true'
            )
        ).scalar() or 0
        
        avg_recommendations_per_user = total_interactions / active_users if active_users > 0 else 0
        
        # 高参与度用户（交互超过5次的用户）
        high_engagement_users = self.db.query(
            func.count(func.distinct(UserTaskInteraction.user_id))
        ).filter(
            and_(
                UserTaskInteraction.interaction_time >= start_date,
                UserTaskInteraction.interaction_metadata.isnot(None),
                UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true'
            )
        ).group_by(
            UserTaskInteraction.user_id
        ).having(
            func.count(UserTaskInteraction.id) > 5
        ).count()
        
        return {
            "active_users": active_users,
            "avg_recommendations_per_user": round(avg_recommendations_per_user, 2),
            "high_engagement_users": high_engagement_users,
            "engagement_rate": round(high_engagement_users / active_users, 4) if active_users > 0 else 0.0
        }
    
    def _analyze_recommendation_quality(self, start_date: datetime) -> Dict:
        """分析推荐质量"""
        # 获取推荐任务的匹配分数分布
        # 这里简化处理，实际应该从推荐结果中获取匹配分数
        
        # 推荐任务的平均浏览时长
        avg_duration = self.db.query(
            func.avg(UserTaskInteraction.duration_seconds)
        ).filter(
            and_(
                UserTaskInteraction.interaction_type == "view",
                UserTaskInteraction.interaction_time >= start_date,
                UserTaskInteraction.interaction_metadata.isnot(None),
                UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true',
                UserTaskInteraction.duration_seconds.isnot(None)
            )
        ).scalar() or 0
        
        # 推荐任务的跳过率
        skips = self.db.query(func.count(UserTaskInteraction.id)).filter(
            and_(
                UserTaskInteraction.interaction_type == "skip",
                UserTaskInteraction.interaction_time >= start_date,
                UserTaskInteraction.interaction_metadata.isnot(None),
                UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true'
            )
        ).scalar() or 0
        
        views = self.db.query(func.count(UserTaskInteraction.id)).filter(
            and_(
                UserTaskInteraction.interaction_type == "view",
                UserTaskInteraction.interaction_time >= start_date,
                UserTaskInteraction.interaction_metadata.isnot(None),
                UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true'
            )
        ).scalar() or 0
        
        skip_rate = skips / views if views > 0 else 0.0
        
        return {
            "avg_view_duration_seconds": round(avg_duration, 2) if avg_duration else 0,
            "skip_rate": round(skip_rate, 4),
            "quality_score": round((1 - skip_rate) * 100, 2)  # 质量分数（基于跳过率）
        }
    
    def _compare_algorithms(self, start_date: datetime, algorithm: str) -> Dict:
        """对比算法效果"""
        # 这里可以对比不同算法的效果
        # 简化实现，实际应该从metadata中提取算法信息
        return {
            "algorithm": algorithm,
            "note": "算法对比功能待完善"
        }
    
    def get_top_recommended_tasks(self, days: int = 7, limit: int = 10) -> List[Dict]:
        """获取最受欢迎的推荐任务"""
        start_date = datetime.utcnow() - timedelta(days=days)
        
        # 统计推荐任务的交互次数
        top_tasks = self.db.query(
            UserTaskInteraction.task_id,
            func.count(UserTaskInteraction.id).label('interaction_count')
        ).filter(
            and_(
                UserTaskInteraction.interaction_time >= start_date,
                UserTaskInteraction.interaction_metadata.isnot(None),
                UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true'
            )
        ).group_by(
            UserTaskInteraction.task_id
        ).order_by(
            desc('interaction_count')
        ).limit(limit).all()
        
        # 获取任务详情
        task_ids = [task.task_id for task in top_tasks]
        tasks = self.db.query(Task).filter(Task.id.in_(task_ids)).all()
        task_dict = {task.id: task for task in tasks}
        
        result = []
        for task_stat in top_tasks:
            task = task_dict.get(task_stat.task_id)
            if task:
                result.append({
                    "task_id": task.id,
                    "title": task.title,
                    "task_type": task.task_type,
                    "location": task.location,
                    "reward": float(task.reward) if task.reward else 0.0,
                    "interaction_count": task_stat.interaction_count
                })
        
        return result


def get_recommendation_analytics(
    db: Session,
    days: int = 7,
    algorithm: Optional[str] = None
) -> Dict:
    """获取推荐分析报告的便捷函数"""
    analytics = RecommendationAnalytics(db)
    return analytics.get_recommendation_performance(days, algorithm)
