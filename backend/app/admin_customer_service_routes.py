"""
管理员 - 客服管理路由
从 routers.py 迁移
"""
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session
from sqlalchemy import func

from app import crud, models, schemas
from app.deps import get_db
from app.separate_auth_deps import get_current_admin
from app.security import get_client_ip

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["管理员-客服管理"])


@router.get("/admin/customer-service-users")
def admin_get_customer_service_users(
    page: int = 1,
    size: int = 20,
    status: str = None,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取客服用户列表"""
    skip = (page - 1) * size
    
    query = db.query(models.User).filter(models.User.is_customer_service == True)
    
    if status == "active":
        query = query.filter(models.User.is_active == True)
    elif status == "inactive":
        query = query.filter(models.User.is_active == False)
    
    total = query.count()
    users = query.order_by(models.User.created_at.desc()).offset(skip).limit(size).all()
    
    return {
        "users": [
            {
                "id": u.id,
                "name": u.name,
                "email": u.email,
                "phone": u.phone,
                "is_active": u.is_active,
                "created_at": u.created_at,
                "last_login": u.last_login,
            }
            for u in users
        ],
        "total": total,
        "page": page,
        "size": size,
    }


@router.post("/admin/customer-service-user")
def admin_add_customer_service_user(
    user_id: str,
    current_admin=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """将用户设置为客服"""
    user = crud.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if user.is_customer_service:
        raise HTTPException(status_code=400, detail="User is already a customer service")
    
    old_value = user.is_customer_service
    user.is_customer_service = True
    db.commit()
    
    # 记录审计日志
    ip_address = get_client_ip(request) if request else None
    crud.create_audit_log(
        db=db,
        action_type="add_customer_service",
        entity_type="user",
        entity_id=user_id,
        admin_id=current_admin.id,
        user_id=user_id,
        old_value={"is_customer_service": old_value},
        new_value={"is_customer_service": True},
        reason=f"管理员 {current_admin.id} ({current_admin.name}) 将用户设置为客服",
        ip_address=ip_address,
    )
    
    return {"message": "User set as customer service successfully"}


@router.delete("/admin/customer-service-user/{user_id}")
def admin_remove_customer_service_user(
    user_id: str,
    current_admin=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """取消用户的客服权限"""
    user = crud.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if not user.is_customer_service:
        raise HTTPException(status_code=400, detail="User is not a customer service")
    
    old_value = user.is_customer_service
    user.is_customer_service = False
    db.commit()
    
    # 记录审计日志
    ip_address = get_client_ip(request) if request else None
    crud.create_audit_log(
        db=db,
        action_type="remove_customer_service",
        entity_type="user",
        entity_id=user_id,
        admin_id=current_admin.id,
        user_id=user_id,
        old_value={"is_customer_service": old_value},
        new_value={"is_customer_service": False},
        reason=f"管理员 {current_admin.id} ({current_admin.name}) 取消了用户的客服权限",
        ip_address=ip_address,
    )
    
    return {"message": "Customer service role removed successfully"}


@router.get("/admin/customer-service-stats")
def admin_get_customer_service_stats(
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取客服统计信息"""
    # 客服总数
    total_cs = db.query(func.count(models.User.id)).filter(
        models.User.is_customer_service == True
    ).scalar() or 0
    
    # 活跃客服数
    active_cs = db.query(func.count(models.User.id)).filter(
        models.User.is_customer_service == True,
        models.User.is_active == True
    ).scalar() or 0
    
    # 今日处理的消息数（如果有消息统计表）
    # 这里简化处理，实际可能需要查询消息表
    
    return {
        "total_customer_service": total_cs,
        "active_customer_service": active_cs,
    }


@router.get("/admin/messages")
def admin_get_messages(
    page: int = 1,
    size: int = 50,
    user_id: str = None,
    message_type: str = None,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员获取消息列表"""
    skip = (page - 1) * size
    
    query = db.query(models.Message)
    
    if user_id:
        query = query.filter(
            (models.Message.sender_id == user_id) | 
            (models.Message.receiver_id == user_id)
        )
    
    if message_type:
        query = query.filter(models.Message.message_type == message_type)
    
    total = query.count()
    messages = query.order_by(models.Message.created_at.desc()).offset(skip).limit(size).all()
    
    return {
        "messages": messages,
        "total": total,
        "page": page,
        "size": size,
    }


@router.delete("/admin/messages/{message_id}")
def admin_delete_message(
    message_id: int,
    current_admin=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """管理员删除消息"""
    message = db.query(models.Message).filter(models.Message.id == message_id).first()
    
    if not message:
        raise HTTPException(status_code=404, detail="Message not found")
    
    # 记录审计日志
    message_data = {
        "id": message.id,
        "sender_id": message.sender_id,
        "receiver_id": message.receiver_id,
        "content_preview": message.content[:100] if message.content else None,
    }
    
    ip_address = get_client_ip(request) if request else None
    crud.create_audit_log(
        db=db,
        action_type="delete_message",
        entity_type="message",
        entity_id=str(message_id),
        admin_id=current_admin.id,
        user_id=message.sender_id,
        old_value=message_data,
        new_value=None,
        reason=f"管理员 {current_admin.id} ({current_admin.name}) 删除了消息",
        ip_address=ip_address,
    )
    
    db.delete(message)
    db.commit()
    
    return {"message": "Message deleted successfully"}
