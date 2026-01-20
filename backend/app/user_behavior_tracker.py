"""
用户行为追踪模块
记录用户对任务的浏览、点击、申请等行为
"""

import logging
from typing import Optional
from datetime import datetime
from sqlalchemy.orm import Session

from app.models import UserTaskInteraction, get_utc_time
from app.redis_cache import redis_cache

logger = logging.getLogger(__name__)


class UserBehaviorTracker:
    """用户行为追踪器"""
    
    def __init__(self, db: Session):
        self.db = db
    
    def record_interaction(
        self,
        user_id: str,
        task_id: int,
        interaction_type: str,
        duration_seconds: Optional[int] = None,
        device_type: Optional[str] = None,
        metadata: Optional[dict] = None,
        is_recommended: bool = False
    ):
        """
        记录用户交互行为
        
        Args:
            user_id: 用户ID
            task_id: 任务ID
            interaction_type: 交互类型 (view, click, apply, accept, complete, skip)
            duration_seconds: 浏览时长（秒）
            device_type: 设备类型 (mobile, desktop, tablet)
            metadata: 额外信息（设备详细信息、推荐信息等）
            is_recommended: 是否为推荐任务
        """
        try:
            # 优化：先验证任务是否存在，避免外键约束错误
            from app.models import Task
            task = self.db.query(Task).filter(Task.id == task_id).first()
            if not task:
                logger.warning(
                    f"尝试记录交互时任务不存在: user_id={user_id}, task_id={task_id}, "
                    f"interaction_type={interaction_type}，跳过记录"
                )
                return
            # 在metadata中添加推荐标记和默认值
            if metadata is None:
                metadata = {}
            
            # 确保is_recommended在metadata中
            metadata["is_recommended"] = is_recommended
            
            # 设置默认来源
            if "source" not in metadata:
                metadata["source"] = "task_hall"
            
            # 如果没有提供device_type，尝试从metadata中获取
            if not device_type and metadata.get("device_info"):
                device_info = metadata.get("device_info", {})
                # 可以从device_info中推断device_type
                if device_info.get("type"):
                    device_type = device_info.get("type")
            
            # 如果没有device_type，使用默认值
            if not device_type:
                device_type = "unknown"
            
            # 检查今天是否已记录过（避免重复记录view和click）
            if interaction_type in ["view", "click"]:
                today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
                existing = self.db.query(UserTaskInteraction).filter(
                    UserTaskInteraction.user_id == user_id,
                    UserTaskInteraction.task_id == task_id,
                    UserTaskInteraction.interaction_type == interaction_type,
                    UserTaskInteraction.interaction_time >= today_start
                ).first()
                
                if existing:
                    # 更新现有记录
                    if duration_seconds:
                        existing.duration_seconds = duration_seconds
                    if metadata:
                        existing.interaction_metadata = metadata
                    self.db.commit()
                    return
            
            # 创建新记录
            interaction = UserTaskInteraction(
                user_id=user_id,
                task_id=task_id,
                interaction_type=interaction_type,
                duration_seconds=duration_seconds,
                device_type=device_type,
                interaction_metadata=metadata
            )
            
            self.db.add(interaction)
            self.db.commit()
            
            # 清除相关缓存
            self._invalidate_cache(user_id, task_id)
            
            # 如果用户有足够的行为数据，异步更新偏好
            if interaction_type in ["accept", "complete"]:
                try:
                    from app.recommendation_tasks import update_user_preferences_async
                    update_user_preferences_async(user_id)
                except Exception as e:
                    logger.warning(f"异步更新用户偏好失败: {e}")
            
        except Exception as e:
            logger.error(f"记录用户交互失败: {e}", exc_info=True)
            self.db.rollback()
    
    def record_view(
        self,
        user_id: str,
        task_id: int,
        duration_seconds: Optional[int] = None,
        device_type: Optional[str] = None,
        source: Optional[str] = None,
        is_recommended: bool = False
    ):
        """记录浏览行为"""
        metadata = {"source": source} if source else {}
        self.record_interaction(
            user_id=user_id,
            task_id=task_id,
            interaction_type="view",
            duration_seconds=duration_seconds,
            device_type=device_type,
            metadata=metadata,
            is_recommended=is_recommended
        )
    
    def record_click(
        self,
        user_id: str,
        task_id: int,
        device_type: Optional[str] = None,
        source: Optional[str] = None,
        is_recommended: bool = False
    ):
        """记录点击行为"""
        metadata = {"source": source} if source else {}
        self.record_interaction(
            user_id=user_id,
            task_id=task_id,
            interaction_type="click",
            device_type=device_type,
            metadata=metadata,
            is_recommended=is_recommended
        )
    
    def record_apply(
        self,
        user_id: str,
        task_id: int,
        device_type: Optional[str] = None
    ):
        """记录申请行为"""
        self.record_interaction(
            user_id=user_id,
            task_id=task_id,
            interaction_type="apply",
            device_type=device_type
        )
    
    def record_skip(
        self,
        user_id: str,
        task_id: int,
        device_type: Optional[str] = None,
        reason: Optional[str] = None
    ):
        """记录跳过行为"""
        metadata = {"reason": reason} if reason else None
        self.record_interaction(
            user_id=user_id,
            task_id=task_id,
            interaction_type="skip",
            device_type=device_type,
            metadata=metadata
        )
    
    def get_user_interactions(
        self,
        user_id: str,
        interaction_type: Optional[str] = None,
        limit: int = 100
    ) -> list:
        """获取用户交互记录"""
        query = self.db.query(UserTaskInteraction).filter(
            UserTaskInteraction.user_id == user_id
        )
        
        if interaction_type:
            query = query.filter(UserTaskInteraction.interaction_type == interaction_type)
        
        return query.order_by(UserTaskInteraction.interaction_time.desc()).limit(limit).all()
    
    def get_task_interactions(
        self,
        task_id: int,
        interaction_type: Optional[str] = None
    ) -> list:
        """获取任务的交互记录"""
        query = self.db.query(UserTaskInteraction).filter(
            UserTaskInteraction.task_id == task_id
        )
        
        if interaction_type:
            query = query.filter(UserTaskInteraction.interaction_type == interaction_type)
        
        return query.order_by(UserTaskInteraction.interaction_time.desc()).all()
    
    def get_user_task_interaction_count(
        self,
        user_id: str,
        task_id: int,
        interaction_type: Optional[str] = None
    ) -> int:
        """获取用户对任务的交互次数"""
        query = self.db.query(UserTaskInteraction).filter(
            UserTaskInteraction.user_id == user_id,
            UserTaskInteraction.task_id == task_id
        )
        
        if interaction_type:
            query = query.filter(UserTaskInteraction.interaction_type == interaction_type)
        
        return query.count()
    
    def _invalidate_cache(self, user_id: str, task_id: int):
        """清除相关缓存"""
        # 清除用户推荐缓存
        patterns = [
            f"recommendations:{user_id}:*",
            f"user_interactions:{user_id}*"
        ]
        for pattern in patterns:
            try:
                redis_cache.delete_pattern(pattern)
            except Exception as e:
                logger.warning(f"清除缓存失败: {e}")


def record_task_view(
    db: Session,
    user_id: str,
    task_id: int,
    duration_seconds: Optional[int] = None,
    device_type: Optional[str] = None
):
    """记录任务浏览的便捷函数"""
    tracker = UserBehaviorTracker(db)
    tracker.record_view(user_id, task_id, duration_seconds, device_type)


def record_task_click(
    db: Session,
    user_id: str,
    task_id: int,
    device_type: Optional[str] = None
):
    """记录任务点击的便捷函数"""
    tracker = UserBehaviorTracker(db)
    tracker.record_click(user_id, task_id, device_type)
