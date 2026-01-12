"""
推荐系统数据清理模块
定期清理无效、过期和低质量的数据
"""

import logging
from typing import List, Dict
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, or_

from app.models import UserTaskInteraction, RecommendationFeedback, Task, User
from app.crud import get_utc_time

logger = logging.getLogger(__name__)


class RecommendationDataCleanup:
    """推荐系统数据清理器"""
    
    def __init__(self, db: Session):
        self.db = db
    
    def cleanup_invalid_interactions(self, days_old: int = 180) -> int:
        """
        清理无效的交互记录
        
        规则：
        1. 删除关联任务已不存在的交互记录
        2. 删除关联用户已不存在的交互记录
        3. 删除超过指定天数的旧记录（可选）
        
        Args:
            days_old: 保留最近多少天的数据（默认180天）
        
        Returns:
            清理的记录数
        """
        try:
            cleaned_count = 0
            
            # 1. 删除关联任务已不存在的交互记录
            task_ids = self.db.query(Task.id).subquery()
            orphan_interactions = self.db.query(UserTaskInteraction).filter(
                ~UserTaskInteraction.task_id.in_(task_ids)
            ).all()
            
            for interaction in orphan_interactions:
                self.db.delete(interaction)
                cleaned_count += 1
            
            logger.info(f"删除 {len(orphan_interactions)} 条关联任务不存在的交互记录")
            
            # 2. 删除关联用户已不存在的交互记录
            user_ids = self.db.query(User.id).subquery()
            orphan_user_interactions = self.db.query(UserTaskInteraction).filter(
                ~UserTaskInteraction.user_id.in_(user_ids)
            ).all()
            
            for interaction in orphan_user_interactions:
                self.db.delete(interaction)
                cleaned_count += 1
            
            logger.info(f"删除 {len(orphan_user_interactions)} 条关联用户不存在的交互记录")
            
            # 3. 删除超过指定天数的旧记录
            if days_old > 0:
                cutoff_date = get_utc_time() - timedelta(days=days_old)
                old_interactions = self.db.query(UserTaskInteraction).filter(
                    UserTaskInteraction.interaction_time < cutoff_date
                ).all()
                
                for interaction in old_interactions:
                    self.db.delete(interaction)
                    cleaned_count += 1
                
                logger.info(f"删除 {len(old_interactions)} 条超过 {days_old} 天的旧交互记录")
            
            self.db.commit()
            logger.info(f"总共清理了 {cleaned_count} 条无效交互记录")
            
            return cleaned_count
            
        except Exception as e:
            logger.error(f"清理无效交互记录失败: {e}", exc_info=True)
            self.db.rollback()
            return 0
    
    def cleanup_duplicate_interactions(self) -> int:
        """
        清理重复的交互记录
        
        规则：
        1. 同一用户、同一任务、同一天、同一类型的交互只保留一条
        2. 保留最新的记录
        
        Returns:
            清理的记录数
        """
        try:
            cleaned_count = 0
            cutoff_date = get_utc_time() - timedelta(days=1)
            
            # 查找重复记录（同一天、同一用户、同一任务、同一类型）
            duplicates = self.db.query(
                UserTaskInteraction.user_id,
                UserTaskInteraction.task_id,
                UserTaskInteraction.interaction_type,
                func.date(UserTaskInteraction.interaction_time).label('interaction_date'),
                func.count(UserTaskInteraction.id).label('count')
            ).filter(
                UserTaskInteraction.interaction_time >= cutoff_date
            ).group_by(
                UserTaskInteraction.user_id,
                UserTaskInteraction.task_id,
                UserTaskInteraction.interaction_type,
                func.date(UserTaskInteraction.interaction_time)
            ).having(
                func.count(UserTaskInteraction.id) > 1
            ).all()
            
            for user_id, task_id, interaction_type, interaction_date, count in duplicates:
                # 获取该组的所有记录
                records = self.db.query(UserTaskInteraction).filter(
                    UserTaskInteraction.user_id == user_id,
                    UserTaskInteraction.task_id == task_id,
                    UserTaskInteraction.interaction_type == interaction_type,
                    func.date(UserTaskInteraction.interaction_time) == interaction_date
                ).order_by(UserTaskInteraction.interaction_time.desc()).all()
                
                # 保留最新的，删除其他的
                for record in records[1:]:
                    self.db.delete(record)
                    cleaned_count += 1
            
            self.db.commit()
            logger.info(f"清理了 {cleaned_count} 条重复交互记录")
            
            return cleaned_count
            
        except Exception as e:
            logger.error(f"清理重复交互记录失败: {e}", exc_info=True)
            self.db.rollback()
            return 0
    
    def cleanup_invalid_feedback(self) -> int:
        """
        清理无效的推荐反馈记录
        
        规则：
        1. 删除关联任务已不存在的反馈记录
        2. 删除关联用户已不存在的反馈记录
        
        Returns:
            清理的记录数
        """
        try:
            cleaned_count = 0
            
            # 删除关联任务已不存在的反馈记录
            task_ids = self.db.query(Task.id).subquery()
            orphan_feedbacks = self.db.query(RecommendationFeedback).filter(
                ~RecommendationFeedback.task_id.in_(task_ids)
            ).all()
            
            for feedback in orphan_feedbacks:
                self.db.delete(feedback)
                cleaned_count += 1
            
            logger.info(f"删除 {len(orphan_feedbacks)} 条关联任务不存在的反馈记录")
            
            # 删除关联用户已不存在的反馈记录
            user_ids = self.db.query(User.id).subquery()
            orphan_user_feedbacks = self.db.query(RecommendationFeedback).filter(
                ~RecommendationFeedback.user_id.in_(user_ids)
            ).all()
            
            for feedback in orphan_user_feedbacks:
                self.db.delete(feedback)
                cleaned_count += 1
            
            logger.info(f"删除 {len(orphan_user_feedbacks)} 条关联用户不存在的反馈记录")
            
            self.db.commit()
            logger.info(f"总共清理了 {cleaned_count} 条无效反馈记录")
            
            return cleaned_count
            
        except Exception as e:
            logger.error(f"清理无效反馈记录失败: {e}", exc_info=True)
            self.db.rollback()
            return 0
    
    def cleanup_low_quality_interactions(self, min_duration: int = 1) -> int:
        """
        清理低质量的交互记录
        
        规则：
        1. 删除浏览时长过短的view记录（可能是误触）
        2. 删除异常长的浏览时长（可能是数据错误）
        
        Args:
            min_duration: 最小有效浏览时长（秒），默认1秒
        
        Returns:
            清理的记录数
        """
        try:
            cleaned_count = 0
            
            # 删除浏览时长过短的view记录（可能是误触或页面快速关闭）
            short_views = self.db.query(UserTaskInteraction).filter(
                and_(
                    UserTaskInteraction.interaction_type == "view",
                    or_(
                        UserTaskInteraction.duration_seconds < min_duration,
                        UserTaskInteraction.duration_seconds.is_(None)
                    )
                )
            ).all()
            
            for interaction in short_views:
                # 检查是否有其他交互（如果有其他交互，保留view记录）
                has_other_interaction = self.db.query(UserTaskInteraction).filter(
                    and_(
                        UserTaskInteraction.user_id == interaction.user_id,
                        UserTaskInteraction.task_id == interaction.task_id,
                        UserTaskInteraction.interaction_type != "view"
                    )
                ).first()
                
                if not has_other_interaction:
                    self.db.delete(interaction)
                    cleaned_count += 1
            
            logger.info(f"清理了 {cleaned_count} 条低质量交互记录")
            
            # 删除异常长的浏览时长（可能是数据错误，超过1小时）
            max_duration = 3600  # 1小时
            long_views = self.db.query(UserTaskInteraction).filter(
                and_(
                    UserTaskInteraction.interaction_type == "view",
                    UserTaskInteraction.duration_seconds > max_duration
                )
            ).all()
            
            for interaction in long_views:
                # 将异常长的时长设为null或合理值
                interaction.duration_seconds = None
                cleaned_count += 1
            
            self.db.commit()
            logger.info(f"总共清理了 {cleaned_count} 条低质量交互记录")
            
            return cleaned_count
            
        except Exception as e:
            logger.error(f"清理低质量交互记录失败: {e}", exc_info=True)
            self.db.rollback()
            return 0


def cleanup_recommendation_data(db: Session) -> Dict[str, int]:
    """
    执行完整的推荐数据清理
    
    Returns:
        清理统计信息
    """
    cleanup = RecommendationDataCleanup(db)
    
    stats = {
        "invalid_interactions": cleanup.cleanup_invalid_interactions(days_old=180),
        "duplicate_interactions": cleanup.cleanup_duplicate_interactions(),
        "invalid_feedback": cleanup.cleanup_invalid_feedback(),
        "low_quality_interactions": cleanup.cleanup_low_quality_interactions(min_duration=1)
    }
    
    total = sum(stats.values())
    stats["total"] = total
    
    logger.info(f"推荐数据清理完成，共清理 {total} 条记录")
    
    return stats
