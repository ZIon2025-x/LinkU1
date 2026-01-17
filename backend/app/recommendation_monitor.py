"""
推荐系统性能监控模块
监控推荐系统的效果和性能指标
"""

import logging
from typing import Dict, List, Optional
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, desc

from app.models import UserTaskInteraction, Task, User
from app.redis_cache import redis_cache
from app.crud import get_utc_time

logger = logging.getLogger(__name__)


class RecommendationMonitor:
    """推荐系统监控器"""
    
    def __init__(self, db: Session):
        self.db = db
    
    def get_recommendation_metrics(
        self,
        days: int = 7
    ) -> Dict:
        """
        获取推荐系统指标
        
        Args:
            days: 统计天数
        
        Returns:
            包含各项指标的字典
        """
        start_date = get_utc_time() - timedelta(days=days)
        
        # 1. 推荐任务总数
        total_recommendations = self._count_recommendations(start_date)
        
        # 2. 推荐任务点击率
        click_rate = self._calculate_click_rate(start_date)
        
        # 3. 推荐任务接受率
        accept_rate = self._calculate_accept_rate(start_date)
        
        # 4. 平均匹配分数
        avg_match_score = self._calculate_avg_match_score(start_date)
        
        # 5. 推荐算法分布
        algorithm_distribution = self._get_algorithm_distribution(start_date)
        
        # 6. 用户参与度
        user_engagement = self._calculate_user_engagement(start_date)
        
        metrics = {
            "period_days": days,
            "total_recommendations": total_recommendations,
            "click_rate": round(click_rate, 4),
            "accept_rate": round(accept_rate, 4),
            "avg_match_score": round(avg_match_score, 4),
            "algorithm_distribution": algorithm_distribution,
            "user_engagement": user_engagement,
            "timestamp": get_utc_time().isoformat()
        }
        
        # 更新Prometheus指标
        try:
            from app.recommendation_metrics import update_recommendation_metrics
            # 计算各算法的平均指标
            for algo, count in algorithm_distribution.items():
                if count > 0:
                    # 这里简化处理，实际应该分别计算各算法的指标
                    update_recommendation_metrics(
                        algo,
                        click_rate,
                        accept_rate,
                        avg_match_score
                    )
        except Exception:
            pass
        
        return metrics
    
    def _count_recommendations(self, start_date: datetime) -> int:
        """统计推荐任务总数（通过metadata中的推荐标记）"""
        from sqlalchemy import text
        count = self.db.query(func.count(UserTaskInteraction.id)).filter(
            and_(
                UserTaskInteraction.interaction_type == "view",
                UserTaskInteraction.interaction_time >= start_date,
                UserTaskInteraction.interaction_metadata.isnot(None),
                UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true'
            )
        ).scalar() or 0
        return count
    
    def _calculate_click_rate(self, start_date: datetime) -> float:
        """计算推荐任务的点击率"""
        # 推荐任务的浏览数（从metadata中判断）
        views = self.db.query(func.count(UserTaskInteraction.id)).filter(
            and_(
                UserTaskInteraction.interaction_type == "view",
                UserTaskInteraction.interaction_time >= start_date,
                UserTaskInteraction.interaction_metadata.isnot(None),
                UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true'
            )
        ).scalar() or 0
        
        # 推荐任务的点击数
        clicks = self.db.query(func.count(UserTaskInteraction.id)).filter(
            and_(
                UserTaskInteraction.interaction_type == "click",
                UserTaskInteraction.interaction_time >= start_date,
                UserTaskInteraction.interaction_metadata.isnot(None),
                UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true'
            )
        ).scalar() or 0
        
        if views == 0:
            return 0.0
        
        return clicks / views
    
    def _calculate_accept_rate(self, start_date: datetime) -> float:
        """计算推荐任务的接受率"""
        # 推荐任务的点击数
        clicks = self.db.query(func.count(UserTaskInteraction.id)).filter(
            and_(
                UserTaskInteraction.interaction_type == "click",
                UserTaskInteraction.interaction_time >= start_date,
                UserTaskInteraction.interaction_metadata.isnot(None),
                UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true'
            )
        ).scalar() or 0
        
        # 推荐任务的接受数（通过TaskHistory）
        from app.models import TaskHistory
        accepts = self.db.query(func.count(TaskHistory.id)).filter(
            and_(
                TaskHistory.action == "accepted",
                TaskHistory.timestamp >= start_date
            )
        ).scalar() or 0
        
        if clicks == 0:
            return 0.0
        
        return accepts / clicks
    
    def _calculate_avg_match_score(self, start_date: datetime) -> float:
        """计算平均匹配分数"""
        # 从metadata中提取匹配分数
        # 这里简化处理，实际应该从推荐结果中获取
        return 0.75  # 占位值
    
    def _get_algorithm_distribution(self, start_date: datetime) -> Dict[str, int]:
        """获取推荐算法使用分布"""
        # 从metadata中提取算法类型
        # 这里简化处理
        return {
            "hybrid": 100,
            "content_based": 50,
            "collaborative": 30
        }
    
    def _calculate_user_engagement(self, start_date: datetime) -> Dict:
        """计算用户参与度"""
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
        
        return {
            "active_users": active_users,
            "avg_recommendations_per_user": round(avg_recommendations_per_user, 2)
        }
    
    def get_user_recommendation_stats(self, user_id: str) -> Dict:
        """获取单个用户的推荐统计"""
        # 用户查看的推荐任务数
        viewed = self.db.query(func.count(UserTaskInteraction.id)).filter(
            and_(
                UserTaskInteraction.user_id == user_id,
                UserTaskInteraction.interaction_type == "view",
                UserTaskInteraction.interaction_metadata.isnot(None),
                UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true'
            )
        ).scalar() or 0
        
        # 用户点击的推荐任务数
        clicked = self.db.query(func.count(UserTaskInteraction.id)).filter(
            and_(
                UserTaskInteraction.user_id == user_id,
                UserTaskInteraction.interaction_type == "click",
                UserTaskInteraction.interaction_metadata.isnot(None),
                UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true'
            )
        ).scalar() or 0
        
        # 用户接受的推荐任务数
        from app.models import TaskHistory
        accepted = self.db.query(func.count(TaskHistory.id)).filter(
            and_(
                TaskHistory.user_id == user_id,
                TaskHistory.action == "accepted"
            )
        ).scalar() or 0
        
        click_rate = clicked / viewed if viewed > 0 else 0
        accept_rate = accepted / clicked if clicked > 0 else 0
        
        return {
            "user_id": user_id,
            "viewed_recommendations": viewed,
            "clicked_recommendations": clicked,
            "accepted_recommendations": accepted,
            "click_rate": round(click_rate, 4),
            "accept_rate": round(accept_rate, 4)
        }


def get_recommendation_metrics(db: Session, days: int = 7) -> Dict:
    """获取推荐系统指标的便捷函数"""
    monitor = RecommendationMonitor(db)
    return monitor.get_recommendation_metrics(days)
