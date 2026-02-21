"""通知相关 CRUD，独立模块便于维护与测试。"""
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models import Notification
from app.utils.time_utils import get_utc_time


def create_notification(
    db: Session,
    user_id: str,
    type: str,
    title: str,
    content: str,
    related_id: str = None,
    related_type: str = None,
    title_en: str = None,
    content_en: str = None,
    auto_commit: bool = True,
):
    try:
        if related_type is None and related_id is not None:
            if type in [
                "task_application",
                "task_approved",
                "task_completed",
                "task_confirmed",
                "task_cancelled",
                "task_reward_paid",
                "application_accepted",
            ]:
                related_type = "task_id"
            elif type in [
                "application_message",
                "negotiation_offer",
                "application_rejected",
                "application_withdrawn",
                "negotiation_rejected",
            ]:
                related_type = "application_id"

        notification = Notification(
            user_id=user_id,
            type=type,
            title=title,
            content=content,
            related_id=related_id,
            related_type=related_type,
            title_en=title_en,
            content_en=content_en,
        )
        db.add(notification)
        if auto_commit:
            db.commit()
            db.refresh(notification)
            try:
                from app.redis_cache import invalidate_notification_cache
                invalidate_notification_cache(user_id)
            except Exception:
                pass
        return notification
    except IntegrityError:
        if auto_commit:
            db.rollback()
        existing_notification = (
            db.query(Notification)
            .filter(
                Notification.user_id == user_id,
                Notification.type == type,
                Notification.related_id == related_id,
            )
            .first()
        )

        if existing_notification:
            existing_notification.content = content
            existing_notification.title = title
            if title_en is not None:
                existing_notification.title_en = title_en
            if content_en is not None:
                existing_notification.content_en = content_en
            existing_notification.created_at = get_utc_time()
            existing_notification.is_read = 0
            db.commit()
            db.refresh(existing_notification)
            return existing_notification
        else:
            raise


def get_user_notifications(db: Session, user_id: str, limit: int = 20):
    return (
        db.query(Notification)
        .filter(Notification.user_id == user_id)
        .order_by(Notification.created_at.desc())
        .limit(limit)
        .all()
    )


def get_unread_notifications(db: Session, user_id: str):
    return (
        db.query(Notification)
        .filter(Notification.user_id == user_id, Notification.is_read == 0)
        .order_by(Notification.created_at.desc())
        .all()
    )


def get_unread_notification_count(db: Session, user_id: str):
    return (
        db.query(Notification)
        .filter(Notification.user_id == user_id, Notification.is_read == 0)
        .count()
    )


def get_notifications_with_recent_read(
    db: Session, user_id: str, recent_read_limit: int = 10
):
    """获取所有未读通知和最近N条已读通知"""
    unread_notifications = (
        db.query(Notification)
        .filter(Notification.user_id == user_id, Notification.is_read == 0)
        .order_by(Notification.created_at.desc())
        .all()
    )

    recent_read_notifications = (
        db.query(Notification)
        .filter(Notification.user_id == user_id, Notification.is_read == 1)
        .order_by(Notification.created_at.desc())
        .limit(recent_read_limit)
        .all()
    )

    all_notifications = unread_notifications + recent_read_notifications
    all_notifications.sort(
        key=lambda x: x.created_at.timestamp() if x.created_at else 0,
        reverse=True,
    )

    return all_notifications


def mark_notification_read(db: Session, notification_id: int, user_id: str):
    notification = (
        db.query(Notification)
        .filter(
            Notification.id == notification_id,
            Notification.user_id == user_id,
        )
        .first()
    )
    if notification:
        notification.is_read = 1
        db.commit()
        db.refresh(notification)
        try:
            from app.redis_cache import invalidate_notification_cache
            invalidate_notification_cache(user_id)
        except Exception:
            pass
    return notification


def mark_all_notifications_read(db: Session, user_id: str):
    db.query(Notification).filter(
        Notification.user_id == user_id, Notification.is_read == 0
    ).update({Notification.is_read: 1})
    db.commit()
    try:
        from app.redis_cache import invalidate_notification_cache
        invalidate_notification_cache(user_id)
    except Exception:
        pass
