"""
客服端员工通知 API（/api/users/staff/notifications*）
供客服系统 service.link2ur.com 调用，使用客服认证，与管理员通知共用 StaffNotification 表。
"""

import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.deps import get_sync_db
from app import models, crud
from app.role_deps import get_current_customer_service_secure_sync
from app.utils.time_utils import format_iso_utc

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/staff", tags=["客服-员工通知"])

STAFF_RECIPIENT_TYPE = "customer_service"


def _notification_to_dict(n):
    """将 StaffNotification ORM 转为可 JSON 序列化的 dict。"""
    return {
        "id": n.id,
        "recipient_id": n.recipient_id,
        "recipient_type": n.recipient_type,
        "sender_id": n.sender_id,
        "title": n.title,
        "content": n.content,
        "notification_type": n.notification_type or "info",
        "is_read": n.is_read,
        "created_at": format_iso_utc(n.created_at) if n.created_at else None,
        "read_at": format_iso_utc(n.read_at) if n.read_at else None,
    }


@router.get("/notifications")
def get_staff_notifications(
    current_cs: models.CustomerService = Depends(get_current_customer_service_secure_sync),
    db: Session = Depends(get_sync_db),
):
    """获取客服员工通知列表（未读 + 最近 5 条已读）"""
    try:
        notifications = crud.get_staff_notifications(
            db, current_cs.id, STAFF_RECIPIENT_TYPE
        )
        unread_count = crud.get_unread_staff_notification_count(
            db, current_cs.id, STAFF_RECIPIENT_TYPE
        )
        return {
            "notifications": [_notification_to_dict(n) for n in notifications],
            "total": len(notifications),
            "unread_count": unread_count,
        }
    except Exception as e:
        logger.error(f"获取客服通知失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取通知失败",
        )


@router.get("/notifications/unread")
def get_unread_staff_notifications(
    current_cs: models.CustomerService = Depends(get_current_customer_service_secure_sync),
    db: Session = Depends(get_sync_db),
):
    """获取客服未读通知"""
    try:
        notifications = crud.get_unread_staff_notifications(
            db, current_cs.id, STAFF_RECIPIENT_TYPE
        )
        unread_count = crud.get_unread_staff_notification_count(
            db, current_cs.id, STAFF_RECIPIENT_TYPE
        )
        return {
            "notifications": [_notification_to_dict(n) for n in notifications],
            "unread_count": unread_count,
        }
    except Exception as e:
        logger.error(f"获取客服未读通知失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取未读通知失败",
        )


@router.post("/notifications/{notification_id}/read")
def mark_staff_notification_read(
    notification_id: int,
    current_cs: models.CustomerService = Depends(get_current_customer_service_secure_sync),
    db: Session = Depends(get_sync_db),
):
    """标记一条客服通知为已读"""
    try:
        updated = crud.mark_staff_notification_read(
            db, notification_id, current_cs.id, STAFF_RECIPIENT_TYPE
        )
        if not updated:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="通知不存在或无权限",
            )
        return {"message": "通知已标记为已读"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"标记客服通知已读失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="标记通知已读失败",
        )


@router.post("/notifications/read-all")
def mark_all_staff_notifications_read(
    current_cs: models.CustomerService = Depends(get_current_customer_service_secure_sync),
    db: Session = Depends(get_sync_db),
):
    """标记所有客服通知为已读"""
    try:
        count = crud.mark_all_staff_notifications_read(
            db, current_cs.id, STAFF_RECIPIENT_TYPE
        )
        return {
            "message": f"已标记 {count} 条通知为已读",
            "count": count,
        }
    except Exception as e:
        logger.error(f"标记所有客服通知已读失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="标记所有通知已读失败",
        )
