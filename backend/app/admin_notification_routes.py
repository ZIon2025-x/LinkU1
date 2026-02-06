"""
管理员 - 通知管理路由
从 routers.py 迁移
"""
import logging
from typing import Optional, List

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Body
from sqlalchemy.orm import Session
from sqlalchemy import func

from app import crud, models, schemas
from app.deps import get_db
from app.separate_auth_deps import get_current_admin
from app.security import get_client_ip
from app.utils.time_utils import get_utc_time, format_iso_utc

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["管理员-通知管理"])


@router.post("/admin/notifications/send")
def admin_send_notification(
    user_ids: List[str] = Body(None, description="用户ID列表，如果为空则发送给所有用户"),
    title: str = Body(...),
    content: str = Body(...),
    notification_type: str = Body("system"),
    current_admin=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """管理员发送通知"""
    from app.services.notification_service import send_system_notification
    
    if user_ids:
        # 发送给指定用户
        for user_id in user_ids:
            user = crud.get_user_by_id(db, user_id)
            if user:
                send_system_notification(
                    db=db,
                    user_id=user_id,
                    title=title,
                    content=content,
                    notification_type=notification_type,
                )
        sent_count = len(user_ids)
    else:
        # 发送给所有用户
        users = db.query(models.User).filter(models.User.is_active == True).all()
        for user in users:
            send_system_notification(
                db=db,
                user_id=user.id,
                title=title,
                content=content,
                notification_type=notification_type,
            )
        sent_count = len(users)
    
    # 记录审计日志
    ip_address = get_client_ip(request) if request else None
    crud.create_audit_log(
        db=db,
        action_type="send_notification",
        entity_type="notification",
        entity_id="batch",
        admin_id=current_admin.id,
        user_id=None,
        old_value=None,
        new_value={
            "title": title,
            "content": content[:200],
            "notification_type": notification_type,
            "recipient_count": sent_count,
            "target_user_ids": user_ids[:10] if user_ids else "all_users"
        },
        reason=f"管理员 {current_admin.id} ({current_admin.name}) 发送了系统通知",
        ip_address=ip_address,
    )
    
    return {
        "message": f"Notification sent to {sent_count} users",
        "sent_count": sent_count
    }


@router.post("/admin/staff-notification")
def admin_send_staff_notification(
    title: str = Body(...),
    content: str = Body(...),
    notification_type: str = Body("staff"),
    current_admin=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """管理员发送员工通知"""
    from app.services.notification_service import send_system_notification
    
    # 获取所有客服和管理员用户
    staff_users = db.query(models.User).filter(
        (models.User.is_customer_service == True) | 
        (models.User.is_admin == True)
    ).filter(models.User.is_active == True).all()
    
    for user in staff_users:
        send_system_notification(
            db=db,
            user_id=user.id,
            title=title,
            content=content,
            notification_type=notification_type,
        )
    
    # 记录审计日志
    ip_address = get_client_ip(request) if request else None
    crud.create_audit_log(
        db=db,
        action_type="send_staff_notification",
        entity_type="notification",
        entity_id="batch",
        admin_id=current_admin.id,
        user_id=None,
        old_value=None,
        new_value={
            "title": title,
            "content": content[:200],
            "notification_type": notification_type,
            "recipient_count": len(staff_users),
        },
        reason=f"管理员 {current_admin.id} ({current_admin.name}) 发送了员工通知",
        ip_address=ip_address,
    )
    
    return {
        "message": f"Staff notification sent to {len(staff_users)} staff members",
        "sent_count": len(staff_users)
    }


@router.get("/admin/notifications")
def admin_get_notifications(
    page: int = 1,
    size: int = 50,
    notification_type: str = None,
    user_id: str = None,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员获取通知列表"""
    skip = (page - 1) * size
    
    query = db.query(models.Notification)
    
    if notification_type:
        query = query.filter(models.Notification.notification_type == notification_type)
    
    if user_id:
        query = query.filter(models.Notification.user_id == user_id)
    
    total = query.count()
    notifications = query.order_by(models.Notification.created_at.desc()).offset(skip).limit(size).all()
    
    return {
        "notifications": [
            {
                "id": n.id,
                "user_id": n.user_id,
                "title": n.title,
                "content": n.content,
                "notification_type": n.notification_type,
                "is_read": n.is_read,
                "created_at": format_iso_utc(n.created_at) if n.created_at else None,
            }
            for n in notifications
        ],
        "total": total,
        "page": page,
        "size": size,
    }


@router.delete("/admin/notifications/{notification_id}")
def admin_delete_notification(
    notification_id: int,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员删除通知"""
    notification = db.query(models.Notification).filter(
        models.Notification.id == notification_id
    ).first()
    
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    
    db.delete(notification)
    db.commit()
    
    return {"message": "Notification deleted successfully"}


@router.post("/admin/notifications/batch-delete")
def admin_batch_delete_notifications(
    notification_ids: List[int] = Body(...),
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员批量删除通知"""
    deleted_count = db.query(models.Notification).filter(
        models.Notification.id.in_(notification_ids)
    ).delete(synchronize_session=False)
    
    db.commit()
    
    return {
        "message": f"Deleted {deleted_count} notifications",
        "deleted_count": deleted_count
    }


@router.get("/admin/notification-stats")
def admin_get_notification_stats(
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取通知统计信息"""
    # 总通知数
    total_count = db.query(func.count(models.Notification.id)).scalar() or 0
    
    # 未读通知数
    unread_count = db.query(func.count(models.Notification.id)).filter(
        models.Notification.is_read == False
    ).scalar() or 0
    
    # 按类型统计
    type_stats = db.query(
        models.Notification.notification_type,
        func.count(models.Notification.id).label('count')
    ).group_by(models.Notification.notification_type).all()
    
    # 今日发送数
    from datetime import timedelta
    today = get_utc_time().replace(hour=0, minute=0, second=0, microsecond=0)
    today_count = db.query(func.count(models.Notification.id)).filter(
        models.Notification.created_at >= today
    ).scalar() or 0
    
    return {
        "total_count": total_count,
        "unread_count": unread_count,
        "today_count": today_count,
        "by_type": [
            {"type": stat.notification_type or "unknown", "count": stat.count}
            for stat in type_stats
        ]
    }
