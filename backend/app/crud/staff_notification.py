"""员工提醒（StaffNotification）相关 CRUD，独立模块便于维护与测试。"""
from sqlalchemy.orm import Session

from app import models
from app.utils.time_utils import get_utc_time


def create_staff_notification(db: Session, notification_data: dict):
    """创建员工提醒"""
    notification = models.StaffNotification(**notification_data)
    db.add(notification)
    db.commit()
    db.refresh(notification)
    return notification


def get_staff_notifications(
    db: Session, recipient_id: str, recipient_type: str
):
    """获取员工提醒列表（所有未读 + 5 条最新已读）"""
    unread_notifications = (
        db.query(models.StaffNotification)
        .filter(
            models.StaffNotification.recipient_id == recipient_id,
            models.StaffNotification.recipient_type == recipient_type,
            models.StaffNotification.is_read == 0,
        )
        .order_by(models.StaffNotification.created_at.desc())
        .all()
    )
    read_notifications = (
        db.query(models.StaffNotification)
        .filter(
            models.StaffNotification.recipient_id == recipient_id,
            models.StaffNotification.recipient_type == recipient_type,
            models.StaffNotification.is_read == 1,
        )
        .order_by(models.StaffNotification.created_at.desc())
        .limit(5)
        .all()
    )
    all_notifications = unread_notifications + read_notifications
    all_notifications.sort(
        key=lambda x: x.created_at.timestamp() if x.created_at else 0,
        reverse=True,
    )
    return all_notifications


def get_unread_staff_notifications(
    db: Session, recipient_id: str, recipient_type: str
):
    """获取未读员工提醒"""
    return (
        db.query(models.StaffNotification)
        .filter(
            models.StaffNotification.recipient_id == recipient_id,
            models.StaffNotification.recipient_type == recipient_type,
            models.StaffNotification.is_read == 0,
        )
        .order_by(models.StaffNotification.created_at.desc())
        .all()
    )


def get_unread_staff_notification_count(
    db: Session, recipient_id: str, recipient_type: str
):
    """获取未读员工提醒数量"""
    return (
        db.query(models.StaffNotification)
        .filter(
            models.StaffNotification.recipient_id == recipient_id,
            models.StaffNotification.recipient_type == recipient_type,
            models.StaffNotification.is_read == 0,
        )
        .count()
    )


def mark_staff_notification_read(
    db: Session,
    notification_id: int,
    recipient_id: str,
    recipient_type: str,
):
    """标记员工提醒为已读"""
    notification = (
        db.query(models.StaffNotification)
        .filter(
            models.StaffNotification.id == notification_id,
            models.StaffNotification.recipient_id == recipient_id,
            models.StaffNotification.recipient_type == recipient_type,
        )
        .first()
    )
    if notification:
        notification.is_read = 1
        notification.read_at = get_utc_time()
        db.commit()
        db.refresh(notification)
        return notification
    return None


def mark_all_staff_notifications_read(
    db: Session, recipient_id: str, recipient_type: str
):
    """标记所有员工提醒为已读，返回被标记数量。"""
    notifications = (
        db.query(models.StaffNotification)
        .filter(
            models.StaffNotification.recipient_id == recipient_id,
            models.StaffNotification.recipient_type == recipient_type,
            models.StaffNotification.is_read == 0,
        )
        .all()
    )
    for notification in notifications:
        notification.is_read = 1
        notification.read_at = get_utc_time()
    db.commit()
    return len(notifications)
