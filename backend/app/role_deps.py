"""
基于角色的认证依赖
为不同角色提供专门的认证和权限检查
"""

from typing import Optional, Union
from fastapi import Depends, HTTPException, status, Request
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.deps import get_sync_db
from app import models
from app.role_management import UserRole, RoleManager, RoleBasedAccessControl
from app.security import verify_token
from app.csrf import sync_csrf_cookie_bearer, sync_cookie_bearer_readonly

# 用户认证依赖
def get_current_user_secure_sync(
    request: Request,
    db: Session = Depends(get_sync_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(sync_cookie_bearer_readonly),
) -> models.User:
    """获取当前用户（同步版本，只读操作）"""
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="未提供认证信息"
        )
    
    try:
        payload = verify_token(credentials.credentials)
        user_id = payload.get("sub")
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="无效的token"
            )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token验证失败"
        )
    
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户不存在"
        )
    
    if user.is_banned:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="用户已被封禁"
        )
    
    if user.is_suspended:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="用户已被暂停"
        )
    
    return user

# 客服认证依赖
def get_current_customer_service_secure_sync(
    request: Request,
    db: Session = Depends(get_sync_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(sync_csrf_cookie_bearer),
) -> models.CustomerService:
    """获取当前客服（同步版本，CSRF保护）"""
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="未提供认证信息"
        )
    
    try:
        payload = verify_token(credentials.credentials)
        cs_id = payload.get("sub")
        if cs_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="无效的token"
            )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token验证失败"
        )
    
    cs = db.query(models.CustomerService).filter(models.CustomerService.id == cs_id).first()
    if cs is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="客服不存在"
        )
    
    if not cs.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="客服账号已被禁用"
        )
    
    return cs

# 管理员认证依赖
def get_current_admin_secure_sync(
    request: Request,
    db: Session = Depends(get_sync_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(sync_csrf_cookie_bearer),
) -> models.AdminUser:
    """获取当前管理员（同步版本，CSRF保护）"""
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="未提供认证信息"
        )
    
    try:
        payload = verify_token(credentials.credentials)
        admin_id = payload.get("sub")
        if admin_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="无效的token"
            )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token验证失败"
        )
    
    admin = db.query(models.AdminUser).filter(models.AdminUser.id == admin_id).first()
    if admin is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="管理员不存在"
        )
    
    if not admin.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="管理员账号已被禁用"
        )
    
    return admin

# 超级管理员认证依赖
def get_current_super_admin_secure_sync(
    request: Request,
    db: Session = Depends(get_sync_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(sync_csrf_cookie_bearer),
) -> models.AdminUser:
    """获取当前超级管理员（同步版本，CSRF保护）"""
    admin = get_current_admin_secure_sync(request, db, credentials)
    
    if not admin.is_super_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="需要超级管理员权限"
        )
    
    return admin

# 角色验证装饰器
def require_role(required_role: UserRole):
    """要求特定角色的装饰器"""
    def decorator(func):
        def wrapper(*args, **kwargs):
            # 从参数中获取当前用户
            current_user = None
            for arg in args:
                if isinstance(arg, (models.User, models.CustomerService, models.AdminUser)):
                    current_user = arg
                    break
            
            if not current_user:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="未提供用户信息"
                )
            
            user_role = RoleManager.get_user_role(current_user)
            if user_role != required_role:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"需要 {required_role.value} 角色权限"
                )
            
            return func(*args, **kwargs)
        return wrapper
    return decorator

def require_permission(resource: str, action: str):
    """要求特定权限的装饰器"""
    def decorator(func):
        def wrapper(*args, **kwargs):
            # 从参数中获取当前用户
            current_user = None
            for arg in args:
                if isinstance(arg, (models.User, models.CustomerService, models.AdminUser)):
                    current_user = arg
                    break
            
            if not current_user:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="未提供用户信息"
                )
            
            if not RoleManager.has_permission(current_user, resource, action):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"权限不足：需要 {resource}.{action} 权限"
                )
            
            return func(*args, **kwargs)
        return wrapper
    return decorator

# 多角色认证依赖
def get_current_user_or_cs_or_admin(
    request: Request,
    db: Session = Depends(get_sync_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(sync_cookie_bearer_readonly),
) -> Union[models.User, models.CustomerService, models.AdminUser]:
    """获取当前用户、客服或管理员（多角色支持）"""
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="未提供认证信息"
        )
    
    try:
        payload = verify_token(credentials.credentials)
        user_id = payload.get("sub")
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="无效的token"
            )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token验证失败"
        )
    
    # 按优先级查找：管理员 > 客服 > 用户
    admin = db.query(models.AdminUser).filter(models.AdminUser.id == user_id).first()
    if admin and admin.is_active:
        return admin
    
    cs = db.query(models.CustomerService).filter(models.CustomerService.id == user_id).first()
    if cs:  # 客服模型中没有is_active字段，直接检查存在性
        return cs
    
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user and not user.is_banned and not user.is_suspended:
        return user
    
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="用户不存在或已被禁用"
    )

# 角色特定的权限检查
def check_user_permission(user: models.User, resource: str, action: str) -> bool:
    """检查用户权限"""
    return RoleBasedAccessControl.check_user_access(user, resource, action)

def check_cs_permission(cs: models.CustomerService, resource: str, action: str) -> bool:
    """检查客服权限"""
    return RoleBasedAccessControl.check_customer_service_access(cs, resource, action)

def check_admin_permission(admin: models.AdminUser, resource: str, action: str) -> bool:
    """检查管理员权限"""
    return RoleBasedAccessControl.check_admin_access(admin, resource, action)
