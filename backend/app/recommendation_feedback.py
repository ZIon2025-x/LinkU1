"""
推荐反馈模块
收集用户对推荐任务的反馈，用于优化推荐算法
"""

import logging
from typing import Optional
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy import func, and_, desc

from app.models import Base, RecommendationFeedback, get_utc_time
from app.redis_cache import redis_cache

logger = logging.getLogger(__name__)


class RecommendationFeedbackManager:
    """推荐反馈管理器"""
    
    def __init__(self, db: Session):
        self.db = db
    
    def record_feedback(
        self,
        user_id: str,
        task_id: int,
        feedback_type: str,
        recommendation_id: Optional[str] = None,
        algorithm: Optional[str] = None,
        match_score: Optional[float] = None,
        metadata: Optional[dict] = None
    ):
        """
        记录推荐反馈
        
        Args:
            user_id: 用户ID
            task_id: 任务ID
            feedback_type: 反馈类型 (like, dislike, not_interested, helpful)
            recommendation_id: 推荐批次ID
            algorithm: 使用的推荐算法
            match_score: 推荐时的匹配分数
            metadata: 额外信息
        """
        try:
            # 检查今天是否已记录过（避免重复）
            today_start = get_utc_time().replace(hour=0, minute=0, second=0, microsecond=0)
            existing = self.db.query(RecommendationFeedback).filter(
                RecommendationFeedback.user_id == user_id,
                RecommendationFeedback.task_id == task_id,
                RecommendationFeedback.feedback_type == feedback_type,
                RecommendationFeedback.feedback_time >= today_start
            ).first()
            
            if existing:
                # 更新现有记录
                if metadata:
                    existing.feedback_metadata = metadata
                self.db.commit()
                return
            
            # 创建新记录
            feedback = RecommendationFeedback(
                user_id=user_id,
                task_id=task_id,
                recommendation_id=recommendation_id,
                feedback_type=feedback_type,
                algorithm=algorithm,
                match_score=match_score,
                feedback_metadata=metadata
            )
            
            self.db.add(feedback)
            self.db.commit()
            
            # 清除相关缓存，触发偏好更新
            self._invalidate_cache(user_id)
            
            # 异步更新用户偏好
            try:
                from app.recommendation_tasks import update_user_preferences_async
                update_user_preferences_async(user_id)
            except Exception as e:
                logger.warning(f"异步更新用户偏好失败: {e}")
            
        except Exception as e:
            logger.error(f"记录推荐反馈失败: {e}", exc_info=True)
            self.db.rollback()
    
    def get_user_feedback_stats(self, user_id: str) -> dict:
        """获取用户的反馈统计"""
        stats = self.db.query(
            RecommendationFeedback.feedback_type,
            func.count(RecommendationFeedback.id).label('count')
        ).filter(
            RecommendationFeedback.user_id == user_id
        ).group_by(
            RecommendationFeedback.feedback_type
        ).all()
        
        result = {
            "like": 0,
            "dislike": 0,
            "not_interested": 0,
            "helpful": 0,
            "total": 0
        }
        
        for stat in stats:
            result[stat.feedback_type] = stat.count
            result["total"] += stat.count
        
        return result
    
    def _invalidate_cache(self, user_id: str):
        """清除相关缓存"""
        patterns = [
            f"recommendations:{user_id}:*",
        ]
        for pattern in patterns:
            try:
                redis_cache.delete_pattern(pattern)
            except Exception as e:
                logger.warning(f"清除缓存失败: {e}")


def record_recommendation_feedback(
    db: Session,
    user_id: str,
    task_id: int,
    feedback_type: str,
    recommendation_id: Optional[str] = None,
    algorithm: Optional[str] = None,
    match_score: Optional[float] = None
):
    """记录推荐反馈的便捷函数"""
    manager = RecommendationFeedbackManager(db)
    manager.record_feedback(
        user_id=user_id,
        task_id=task_id,
        feedback_type=feedback_type,
        recommendation_id=recommendation_id,
        algorithm=algorithm,
        match_score=match_score
    )
