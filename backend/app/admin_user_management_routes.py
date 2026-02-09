"""
管理员 - 用户管理路由
从 routers.py 迁移
"""
import logging
import os
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Body
from sqlalchemy.orm import Session

from app import crud, models, schemas
from app.audit_logger import log_admin_action
from app.deps import get_db
from app.separate_auth_deps import get_current_admin
from app.security import get_client_ip
from app.performance_monitor import measure_api_performance
from app.utils.time_utils import format_iso_utc, get_utc_time

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["管理员-用户管理"])


@router.get("/admin/dashboard/stats")
@measure_api_performance("get_dashboard_stats")
def get_dashboard_stats(
    current_admin=Depends(get_current_admin), 
    db: Session = Depends(get_db),
    request: Request = None
):
    """获取管理后台统计数据"""
    # 记录管理页面访问
    if request:
        client_ip = get_client_ip(request)
        logger.info(f"管理员访问仪表板: {current_admin.username[:3]}*** (IP: {client_ip})")
    try:
        stats = crud.get_dashboard_stats(db)
        return stats
    except Exception as e:
        logger.error(f"Error in get_dashboard_stats: {e}")
        if os.getenv("ENVIRONMENT", "development") == "production":
            raise HTTPException(status_code=500, detail="Internal server error")
        else:
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.get("/admin/users")
def get_users_for_admin(
    page: int = 1,
    size: int = 20,
    search: str = None,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """超级管理员获取用户列表"""
    skip = (page - 1) * size
    result = crud.get_users_for_admin(db, skip=skip, limit=size, search=search)

    return {
        "users": result["users"],
        "total": result["total"],
        "page": page,
        "size": size,
    }


@router.patch("/admin/users/{user_id}")
def update_user_by_admin(
    user_id: str,
    user_update: schemas.AdminUserUpdate,
    current_admin=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """后台管理员更新用户信息"""
    update_data = user_update.dict(exclude_unset=True)
    user, old_values, new_values = crud.update_user_by_admin(db, user_id, update_data)

    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # 记录审计日志（如果有变更）
    if old_values and new_values:
        ip_address = get_client_ip(request) if request else None
        crud.create_audit_log(
            db=db,
            action_type="update_user",
            entity_type="user",
            entity_id=user_id,
            admin_id=current_admin.id,
            user_id=user_id,
            old_value=old_values,
            new_value=new_values,
            reason=f"管理员 {current_admin.id} ({current_admin.name}) 更新了用户信息",
            ip_address=ip_address,
        )

    return {"message": "User updated successfully", "user": user}


@router.post("/admin/user/{user_id}/set_level")
def admin_set_user_level(
    user_id: str,
    level: str = Body(...),
    current_user=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """管理员设置用户等级"""
    # 安全：验证等级值是否合法
    ALLOWED_USER_LEVELS = {"normal", "vip", "super"}
    if level not in ALLOWED_USER_LEVELS:
        raise HTTPException(
            status_code=400,
            detail=f"无效的用户等级，允许的值: {', '.join(ALLOWED_USER_LEVELS)}"
        )
    
    user = crud.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")
    
    old_level = user.user_level
    user.user_level = level
    db.commit()
    
    # 记录审计日志
    if old_level != level:
        ip_address = get_client_ip(request) if request else None
        crud.create_audit_log(
            db=db,
            action_type="update_user_level",
            entity_type="user",
            entity_id=user_id,
            admin_id=current_user.id,
            user_id=user_id,
            old_value={"user_level": old_level},
            new_value={"user_level": level},
            reason=f"管理员 {current_user.id} ({current_user.name}) 修改了用户等级",
            ip_address=ip_address,
        )
    
    return {"message": f"User {user_id} level set to {level}."}


@router.post("/admin/user/{user_id}/set_status")
def admin_set_user_status(
    user_id: str,
    is_banned: int = Body(None),
    is_suspended: int = Body(None),
    suspend_until: str = Body(None),
    current_user=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """管理员设置用户状态"""
    user = crud.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")
    
    # 记录修改前的值
    old_values = {}
    new_values = {}
    
    if is_banned is not None:
        old_values['is_banned'] = user.is_banned
        new_values['is_banned'] = is_banned
        user.is_banned = is_banned
    
    if is_suspended is not None:
        old_values['is_suspended'] = user.is_suspended
        new_values['is_suspended'] = is_suspended
        user.is_suspended = is_suspended
    
    if suspend_until:
        from app.utils.time_utils import parse_iso_utc
        old_values['suspend_until'] = format_iso_utc(user.suspend_until) if user.suspend_until else None
        new_values['suspend_until'] = suspend_until
        user.suspend_until = parse_iso_utc(suspend_until)
    
    db.commit()
    
    # 记录审计日志
    if old_values:
        ip_address = get_client_ip(request) if request else None
        crud.create_audit_log(
            db=db,
            action_type="update_user_status",
            entity_type="user",
            entity_id=user_id,
            admin_id=current_user.id,
            user_id=user_id,
            old_value=old_values,
            new_value=new_values,
            reason=f"管理员 {current_user.id} ({current_user.name}) 修改了用户状态",
            ip_address=ip_address,
        )
        log_admin_action(
            action="set_user_status",
            admin_id=current_user.id,
            request=request,
            target_type="user",
            target_id=user_id,
            details={"old": old_values, "new": new_values},
        )
    
    return {"message": f"User {user_id} status updated."}


@router.get("/admin/admin-users")
def get_admin_users_for_super_admin(
    page: int = 1,
    size: int = 20,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """超级管理员获取管理员列表"""
    # 只有超级管理员才能查看管理员列表
    if not current_admin.is_super_admin:
        raise HTTPException(
            status_code=403, detail="Only super admin can view admin users"
        )

    skip = (page - 1) * size
    result = crud.get_admin_users_for_admin(db, skip=skip, limit=size)

    return {
        "admin_users": result["admin_users"],
        "total": result["total"],
        "page": page,
        "size": size,
    }


@router.post("/admin/admin-user")
def create_admin_user_by_super_admin(
    admin_data: schemas.AdminUserCreate,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """超级管理员创建管理员账号"""
    # 只有超级管理员才能创建新的管理员用户
    if not current_admin.is_super_admin:
        raise HTTPException(
            status_code=403, detail="Only super admin can create admin users"
        )

    # 检查用户名是否已存在
    existing_admin = crud.get_admin_user_by_username(db, admin_data.username)
    if existing_admin:
        raise HTTPException(status_code=400, detail="Username already exists")

    # 检查邮箱是否已存在
    existing_email = crud.get_admin_user_by_email(db, admin_data.email)
    if existing_email:
        raise HTTPException(status_code=400, detail="Email already exists")

    # 创建管理员用户
    admin_user = crud.create_admin_user(db, admin_data.dict())

    return {
        "message": "Admin user created successfully",
        "admin_user": {
            "id": admin_user.id,
            "name": admin_user.name,
            "username": admin_user.username,
            "email": admin_user.email,
            "is_super_admin": admin_user.is_super_admin,
            "is_active": admin_user.is_active,
            "created_at": admin_user.created_at,
        },
    }


@router.delete("/admin/admin-user/{admin_id}")
def delete_admin_user_by_super_admin(
    admin_id: str,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """超级管理员删除管理员账号"""
    # 只有超级管理员才能删除管理员用户
    if not current_admin.is_super_admin:
        raise HTTPException(
            status_code=403, detail="Only super admin can delete admin users"
        )

    # 不能删除自己
    if admin_id == current_admin.id:
        raise HTTPException(status_code=400, detail="Cannot delete yourself")

    success = crud.delete_admin_user_by_super_admin(db, admin_id)
    if not success:
        raise HTTPException(
            status_code=404, detail="Admin user not found or cannot be deleted"
        )

    return {"message": "Admin user deleted successfully"}
