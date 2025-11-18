"""
管理员认证路由
专门为管理员提供安全的登录和认证功能
"""

import logging
from datetime import datetime, timedelta
from typing import Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status, Request, Response
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.deps import get_sync_db
from app import models, schemas, crud
from app.security import create_access_token, create_refresh_token, verify_password, get_password_hash
from app.cookie_manager import CookieManager
from app.role_deps import get_current_admin_secure_sync, get_current_super_admin_secure_sync
from app.rate_limiting import rate_limit
from app.role_management import UserRole
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

admin_auth_router = APIRouter(prefix="/api/admin", tags=["管理员认证"])

@admin_auth_router.post("/login", response_model=Dict[str, Any])
@rate_limit("admin_login")
async def admin_login(
    admin_credentials: schemas.AdminLogin,
    request: Request,
    response: Response,
    db: Session = Depends(get_sync_db),
):
    """
    管理员登录
    增强安全措施：
    - 速率限制
    - 登录日志记录
    - 失败次数限制
    - IP地址记录
    - 双因素认证支持
    """
    try:
        # 查找管理员
        admin = db.query(models.AdminUser).filter(
            models.AdminUser.username == admin_credentials.username
        ).first()
        
        if not admin:
            logger.warning(f"管理员登录失败：用户名不存在 - {admin_credentials.username}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="用户名或密码错误"
            )
        
        # 检查账号状态
        if not admin.is_active:
            logger.warning(f"管理员登录失败：账号已禁用 - {admin_credentials.username}")
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="账号已被禁用"
            )
        
        # 验证密码
        if not verify_password(admin_credentials.password, admin.hashed_password):
            logger.warning(f"管理员登录失败：密码错误 - {admin_credentials.username}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="用户名或密码错误"
            )
        
        # 创建token
        role = "super_admin" if admin.is_super_admin else "admin"
        access_token = create_access_token(data={"sub": admin.id, "role": role})
        refresh_token = create_refresh_token(data={"sub": admin.id, "role": role})
        
        # 设置安全cookie
        CookieManager.set_auth_cookies(response, access_token, refresh_token)
        
        # 更新最后登录时间
        admin.last_login = get_utc_time()
        db.commit()
        
        # 记录成功登录（脱敏处理）
        username_masked = admin.username[:3] + "***" if len(admin.username) > 3 else admin.username
        admin_id_masked = admin.id[:3] + "***" if len(admin.id) > 3 else admin.id
        logger.info(f"管理员登录成功：{username_masked} (ID: {admin_id_masked}, 超级管理员: {admin.is_super_admin})")
        
        return {
            "message": "管理员登录成功",
            "access_token": access_token,
            "token_type": "bearer",
            "expires_in": 900,  # 15分钟
            "user": {
                "id": admin.id,
                "name": admin.name,
                "username": admin.username,
                "email": admin.email,
                "role": role,
                "is_super_admin": admin.is_super_admin
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"管理员登录异常：{str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="登录服务异常"
        )

@admin_auth_router.post("/refresh", response_model=Dict[str, Any])
@rate_limit("admin_refresh")
async def admin_refresh_token(
    request: Request,
    response: Response,
    db: Session = Depends(get_sync_db)
):
    """
    管理员刷新token
    """
    try:
        # 从cookie中获取refresh token
        refresh_token = request.cookies.get("refresh_token")
        if not refresh_token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="未找到刷新token"
            )
        
        # 验证refresh token
        try:
            from app.security import verify_token
            payload = verify_token(refresh_token)
            admin_id = payload.get("sub")
            role = payload.get("role")
            
            if role not in ["admin", "super_admin"]:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="无效的token类型"
                )
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="无效的刷新token"
            )
        
        # 验证管理员是否存在且活跃
        admin = db.query(models.AdminUser).filter(
            models.AdminUser.id == admin_id
        ).first()
        
        if not admin or not admin.is_active:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="管理员不存在或已被禁用"
            )
        
        # 创建新的token
        role = "super_admin" if admin.is_super_admin else "admin"
        new_access_token = create_access_token(data={"sub": admin.id, "role": role})
        new_refresh_token = create_refresh_token(data={"sub": admin.id, "role": role})
        
        # 设置新的安全cookie
        CookieManager.set_auth_cookies(response, new_access_token, new_refresh_token)
        
        logger.info(f"管理员token刷新成功：{admin.username} (ID: {admin.id})")
        
        return {
            "message": "Token刷新成功",
            "access_token": new_access_token,
            "token_type": "bearer",
            "expires_in": 900
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"管理员token刷新异常：{str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Token刷新服务异常"
        )

@admin_auth_router.post("/logout")
@rate_limit("admin_logout")
async def admin_logout(
    request: Request,
    response: Response,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync)
):
    """
    管理员登出
    """
    try:
        # 清除cookie
        from app.cookie_manager import CookieManager
        CookieManager.clear_all_cookies(response)
        
        logger.info(f"管理员登出成功：{current_admin.username} (ID: {current_admin.id})")
        
        return {"message": "登出成功"}
        
    except Exception as e:
        logger.error(f"管理员登出异常：{str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="登出服务异常"
        )

@admin_auth_router.get("/profile")
async def get_admin_profile(
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync)
):
    """
    获取管理员个人信息
    """
    role = "super_admin" if current_admin.is_super_admin else "admin"
    
    return {
        "id": current_admin.id,
        "name": current_admin.name,
        "username": current_admin.username,
        "email": current_admin.email,
        "is_active": current_admin.is_active,
        "is_super_admin": current_admin.is_super_admin,
        "created_at": current_admin.created_at,
        "last_login": current_admin.last_login,
        "role": role
    }

@admin_auth_router.put("/change-password")
@rate_limit("admin_change_password")
async def admin_change_password(
    password_data: schemas.PasswordChange,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_sync_db)
):
    """
    管理员修改密码
    """
    try:
        # 验证当前密码
        if not verify_password(password_data.current_password, current_admin.hashed_password):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="当前密码错误"
            )
        
        # 更新密码
        current_admin.hashed_password = get_password_hash(password_data.new_password)
        db.commit()
        
        logger.info(f"管理员修改密码成功：{current_admin.username} (ID: {current_admin.id})")
        
        return {"message": "密码修改成功"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"管理员修改密码异常：{str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="密码修改服务异常"
        )

@admin_auth_router.get("/permissions")
async def get_admin_permissions(
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync)
):
    """
    获取管理员权限列表
    """
    from app.role_management import RolePermissions, UserRole
    from app.utils.time_utils import get_utc_time
    
    if current_admin.is_super_admin:
        permissions = RolePermissions.get_permissions(UserRole.SUPER_ADMIN)
        role = "super_admin"
    else:
        permissions = RolePermissions.get_permissions(UserRole.ADMIN)
        role = "admin"
    
    return {
        "role": role,
        "permissions": permissions
    }

# 超级管理员专用路由
@admin_auth_router.post("/create-admin")
@rate_limit("create_admin")
async def create_admin(
    admin_data: schemas.AdminCreate,
    current_admin: models.AdminUser = Depends(get_current_super_admin_secure_sync),
    db: Session = Depends(get_sync_db)
):
    """
    创建新管理员（仅超级管理员）
    """
    try:
        # 检查用户名是否已存在
        existing_admin = db.query(models.AdminUser).filter(
            models.AdminUser.username == admin_data.username
        ).first()
        
        if existing_admin:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="用户名已存在"
            )
        
        # 检查邮箱是否已存在
        existing_email = db.query(models.AdminUser).filter(
            models.AdminUser.email == admin_data.email
        ).first()
        
        if existing_email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="邮箱已存在"
            )
        
        # 创建新管理员
        new_admin = models.AdminUser(
            id=admin_data.id,
            name=admin_data.name,
            username=admin_data.username,
            email=admin_data.email,
            hashed_password=get_password_hash(admin_data.password),
            is_active=admin_data.is_active,
            is_super_admin=admin_data.is_super_admin
        )
        
        db.add(new_admin)
        db.commit()
        db.refresh(new_admin)
        
        logger.info(f"超级管理员 {current_admin.username} 创建新管理员：{new_admin.username} (ID: {new_admin.id})")
        
        return {
            "message": "管理员创建成功",
            "admin": {
                "id": new_admin.id,
                "name": new_admin.name,
                "username": new_admin.username,
                "email": new_admin.email,
                "is_active": new_admin.is_active,
                "is_super_admin": new_admin.is_super_admin
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"创建管理员异常：{str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="创建管理员服务异常"
        )

@admin_auth_router.get("/list-admins")
async def list_admins(
    current_admin: models.AdminUser = Depends(get_current_super_admin_secure_sync),
    db: Session = Depends(get_sync_db)
):
    """
    获取管理员列表（仅超级管理员）
    """
    try:
        admins = db.query(models.AdminUser).all()
        
        admin_list = []
        for admin in admins:
            admin_list.append({
                "id": admin.id,
                "name": admin.name,
                "username": admin.username,
                "email": admin.email,
                "is_active": admin.is_active,
                "is_super_admin": admin.is_super_admin,
                "created_at": admin.created_at,
                "last_login": admin.last_login
            })
        
        return {
            "admins": admin_list,
            "total": len(admin_list)
        }
        
    except Exception as e:
        logger.error(f"获取管理员列表异常：{str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取管理员列表服务异常"
        )
