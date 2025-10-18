"""
独立认证依赖
为客服和管理员提供独立的认证依赖
"""

from typing import Optional, Union
from fastapi import Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
from app.deps import get_sync_db, get_async_db_dependency
from app import models, crud
from app.admin_auth import validate_admin_session, AdminSessionInfo
from app.service_auth import validate_service_session, ServiceSessionInfo
from app.secure_auth import validate_session, SessionInfo
import logging

logger = logging.getLogger(__name__)

# ==================== 管理员认证依赖 ====================

def get_current_admin(request: Request, db: Session = Depends(get_sync_db)) -> models.AdminUser:
    """获取当前管理员（独立认证）"""
    logger.info(f"[ADMIN_AUTH] get_current_admin - URL: {request.url}")
    
    # 验证管理员会话
    admin_session = validate_admin_session(request)
    if not admin_session:
        logger.info("[ADMIN_AUTH] 管理员会话验证失败")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="管理员认证失败，请重新登录"
        )
    
    # 获取管理员信息
    admin = crud.get_admin_user_by_id(db, admin_session.admin_id)
    if not admin:
        logger.warning(f"[ADMIN_AUTH] 管理员不存在: {admin_session.admin_id}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="管理员不存在"
        )
    
    # 检查管理员状态
    if not admin.is_active:
        logger.warning(f"[ADMIN_AUTH] 管理员已被禁用: {admin.id}")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="管理员账户已被禁用"
        )
    
    logger.info(f"[ADMIN_AUTH] 管理员认证成功: {admin.id}")
    return admin

def get_current_admin_optional(request: Request, db: Session = Depends(get_sync_db)) -> Optional[models.AdminUser]:
    """获取当前管理员（可选，不抛出异常）"""
    try:
        return get_current_admin(request, db)
    except HTTPException:
        return None

# ==================== 客服认证依赖 ====================

def get_current_service(request: Request, db: Session = Depends(get_sync_db)) -> models.CustomerService:
    """获取当前客服（独立认证）"""
    logger.info(f"[SERVICE_AUTH] get_current_service - URL: {request.url}")
    
    # 验证客服会话
    service_session = validate_service_session(request)
    if not service_session:
        logger.info("[SERVICE_AUTH] 客服会话验证失败")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="客服认证失败，请重新登录"
        )
    
    # 获取客服信息
    service = crud.get_customer_service_by_id(db, service_session.service_id)
    if not service:
        logger.warning(f"[SERVICE_AUTH] 客服不存在: {service_session.service_id}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="客服不存在"
        )
    
    logger.info(f"[SERVICE_AUTH] 客服认证成功: {service.id}")
    return service

def get_current_service_optional(request: Request, db: Session = Depends(get_sync_db)) -> Optional[models.CustomerService]:
    """获取当前客服（可选，不抛出异常）"""
    try:
        return get_current_service(request, db)
    except HTTPException:
        return None

# ==================== 用户认证依赖 ====================

def get_current_user(request: Request, db: Session = Depends(get_sync_db)) -> models.User:
    """获取当前用户（独立认证）"""
    logger.info(f"[USER_AUTH] get_current_user - URL: {request.url}")
    
    # 验证用户会话
    user_session = validate_session(request)
    if not user_session:
        logger.info("[USER_AUTH] 用户会话验证失败")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户认证失败，请重新登录"
        )
    
    # 获取用户信息
    user = crud.get_user_by_id(db, user_session.user_id)
    if not user:
        logger.warning(f"[USER_AUTH] 用户不存在: {user_session.user_id}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户不存在"
        )
    
    # 检查用户状态
    if user.is_banned:
        logger.warning(f"[USER_AUTH] 用户已被封禁: {user.id}")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="账户已被封禁"
        )
    
    if user.is_suspended:
        logger.warning(f"[USER_AUTH] 用户已被暂停: {user.id}")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="账户已被暂停"
        )
    
    logger.info(f"[USER_AUTH] 用户认证成功: {user.id}")
    return user

def get_current_user_optional(request: Request, db: Session = Depends(get_sync_db)) -> Optional[models.User]:
    """获取当前用户（可选，不抛出异常）"""
    try:
        return get_current_user(request, db)
    except HTTPException:
        return None

# ==================== 多角色认证依赖 ====================

def get_current_user_or_service(request: Request, db: Session = Depends(get_sync_db)) -> Union[models.User, models.CustomerService]:
    """获取当前用户或客服"""
    # 先尝试用户认证
    try:
        return get_current_user(request, db)
    except HTTPException:
        pass
    
    # 再尝试客服认证
    try:
        return get_current_service(request, db)
    except HTTPException:
        pass
    
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="认证失败，请重新登录"
    )

def get_current_any_role(request: Request, db: Session = Depends(get_sync_db)) -> Union[models.User, models.CustomerService, models.AdminUser]:
    """获取当前任何角色（用户、客服或管理员）"""
    # 按优先级尝试：管理员 > 客服 > 用户
    try:
        return get_current_admin(request, db)
    except HTTPException:
        pass
    
    try:
        return get_current_service(request, db)
    except HTTPException:
        pass
    
    try:
        return get_current_user(request, db)
    except HTTPException:
        pass
    
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="认证失败，请重新登录"
    )

# ==================== 权限检查 ====================

def require_admin_role(current_user: models.AdminUser = Depends(get_current_admin)) -> models.AdminUser:
    """要求管理员角色"""
    return current_user

def require_service_role(current_service: models.CustomerService = Depends(get_current_service)) -> models.CustomerService:
    """要求客服角色"""
    return current_service

def require_user_role(current_user: models.User = Depends(get_current_user)) -> models.User:
    """要求用户角色"""
    return current_user

def require_super_admin(current_admin: models.AdminUser = Depends(get_current_admin)) -> models.AdminUser:
    """要求超级管理员权限"""
    if not current_admin.is_super_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="需要超级管理员权限"
        )
    return current_admin
