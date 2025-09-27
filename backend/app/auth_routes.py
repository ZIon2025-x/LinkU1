"""
安全认证路由
实现JWT Token认证、刷新、撤销等功能
"""

import logging
from typing import Any, Dict

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from app import async_crud, crud, models, schemas
from app.deps import get_async_db_dependency, get_current_user_secure_sync, get_sync_db
from app.security import (
    SecurityConfig,
    add_security_headers,
    clear_secure_cookies,
    cookie_bearer,
    create_access_token,
    create_refresh_token,
    get_client_ip,
    get_password_hash,
    log_security_event,
    refresh_access_token,
    revoke_all_user_tokens,
    revoke_token,
    set_secure_cookies,
    verify_password,
)
from app.rate_limiting import rate_limit

logger = logging.getLogger(__name__)

# 创建认证路由器
auth_router = APIRouter(prefix="/api/auth", tags=["认证"])


@auth_router.post("/login", response_model=Dict[str, Any])
@rate_limit("login")
async def login(
    user_credentials: schemas.UserLogin,
    request: Request,
    response: Response,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """用户登录（返回JWT Token对）- 支持ID或邮箱登录"""
    try:
        # 判断输入是ID还是邮箱
        username = user_credentials.email  # 这里email字段实际是用户名（可能是ID或邮箱）
        user = None
        
        # 首先尝试作为ID查找（8位数字）
        if username.isdigit() and len(username) == 8:
            user = await async_crud.async_user_crud.get_user_by_id(db, username)
        
        # 如果ID查找失败，尝试作为邮箱查找
        if not user:
            user = await async_crud.async_user_crud.get_user_by_email(db, username)
        
        # 验证用户和密码
        if not user or not verify_password(
            user_credentials.password, user.hashed_password
        ):
            client_ip = get_client_ip(request)
            log_security_event(
                "LOGIN_FAILED", username, client_ip, "无效的用户名或密码"
            )
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="无效的用户名或密码"
            )

        # 检查用户状态
        if user.is_suspended:
            client_ip = get_client_ip(request)
            log_security_event(
                "SUSPENDED_USER_LOGIN", user.id, client_ip, "被暂停用户尝试登录"
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="账户已被暂停"
            )

        if user.is_banned:
            client_ip = get_client_ip(request)
            log_security_event(
                "BANNED_USER_LOGIN", user.id, client_ip, "被封禁用户尝试登录"
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="账户已被封禁"
            )

        # 创建token对
        access_token = create_access_token({"sub": user.id})
        refresh_token = create_refresh_token({"sub": user.id})

        # 设置安全Cookie
        set_secure_cookies(response, access_token, refresh_token)

        # 生成并设置CSRF token
        from app.csrf import CSRFProtection
        csrf_token = CSRFProtection.generate_csrf_token()
        CSRFProtection.set_csrf_cookie(response, csrf_token)

        # 添加安全响应头
        add_security_headers(response)

        # 记录成功登录
        client_ip = get_client_ip(request)
        log_security_event("LOGIN_SUCCESS", user.id, client_ip, "用户登录成功")

        return {
            "message": "登录成功",
            "user": {
                "id": user.id,
                "name": user.name,
                "email": user.email,
                "user_level": user.user_level,
                "is_verified": user.is_verified,
            },
            "access_token": access_token,  # 仅用于调试，生产环境应移除
            "token_type": "bearer",
            "expires_in": 900,  # 15分钟
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"登录失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="登录失败"
        )


@auth_router.post("/refresh", response_model=Dict[str, Any])
@rate_limit("api_auth")
async def refresh_token(
    request: Request, response: Response, db: Session = Depends(get_sync_db)
):
    """刷新访问令牌（实现Token轮换）"""
    try:
        # 从Cookie获取refresh token
        refresh_token = request.cookies.get("refresh_token")
        if not refresh_token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供refresh token"
            )

        # 刷新token（实现轮换）
        new_access_token, new_refresh_token = refresh_access_token(refresh_token)

        # 设置新的安全Cookie
        set_secure_cookies(response, new_access_token, new_refresh_token)

        # 生成并设置新的CSRF token
        from app.csrf import CSRFProtection
        csrf_token = CSRFProtection.generate_csrf_token()
        CSRFProtection.set_csrf_cookie(response, csrf_token)

        # 添加安全响应头
        add_security_headers(response)

        return {
            "message": "Token刷新成功",
            "access_token": new_access_token,  # 仅用于调试，生产环境应移除
            "token_type": "bearer",
            "expires_in": 900,  # 15分钟
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Token刷新失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Token刷新失败"
        )


@auth_router.post("/logout")
async def logout(
    request: Request,
    response: Response,
    current_user: models.User = Depends(get_current_user_secure_sync),
):
    """用户登出（撤销所有Token）"""
    try:
        # 撤销用户的所有token
        revoke_all_user_tokens(current_user.id)

        # 清除安全Cookie
        clear_secure_cookies(response)

        # 添加安全响应头
        add_security_headers(response)

        # 记录登出事件
        client_ip = get_client_ip(request)
        log_security_event("LOGOUT_SUCCESS", current_user.id, client_ip, "用户登出")

        return {"message": "登出成功"}

    except Exception as e:
        logger.error(f"登出失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="登出失败"
        )


@auth_router.post("/logout-all-devices")
async def logout_all_devices(
    request: Request,
    response: Response,
    current_user: models.User = Depends(get_current_user_secure_sync),
):
    """登出所有设备（撤销所有Token）"""
    try:
        # 撤销用户的所有token
        revoke_all_user_tokens(current_user.id)

        # 清除安全Cookie
        clear_secure_cookies(response)

        # 添加安全响应头
        add_security_headers(response)

        # 记录安全事件
        client_ip = get_client_ip(request)
        log_security_event(
            "LOGOUT_ALL_DEVICES", current_user.id, client_ip, "用户登出所有设备"
        )

        return {"message": "所有设备已登出"}

    except Exception as e:
        logger.error(f"登出所有设备失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="登出所有设备失败"
        )


@auth_router.get("/me", response_model=schemas.UserOut)
async def get_current_user_info(
    current_user: models.User = Depends(get_current_user_secure_sync),
):
    """获取当前用户信息"""
    return current_user


@auth_router.post("/change-password")
@rate_limit("api_auth")
async def change_password(
    password_data: schemas.PasswordChange,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_sync),
    db: Session = Depends(get_sync_db),
):
    """修改密码"""
    try:
        # 验证当前密码
        if not verify_password(
            password_data.current_password, current_user.hashed_password
        ):
            client_ip = get_client_ip(request)
            log_security_event(
                "PASSWORD_CHANGE_FAILED", current_user.id, client_ip, "当前密码错误"
            )
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail="当前密码错误"
            )

        # 更新密码
        new_hashed_password = get_password_hash(password_data.new_password)
        crud.update_user(db, current_user.id, {"hashed_password": new_hashed_password})

        # 撤销所有token（强制重新登录）
        revoke_all_user_tokens(current_user.id)

        # 记录安全事件
        client_ip = get_client_ip(request)
        log_security_event(
            "PASSWORD_CHANGED", current_user.id, client_ip, "用户修改密码"
        )

        return {"message": "密码修改成功，请重新登录"}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"修改密码失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="修改密码失败"
        )


@auth_router.get("/security-status")
async def get_security_status(
    current_user: models.User = Depends(get_current_user_secure_sync),
):
    """获取安全状态信息"""
    return {
        "user_id": current_user.id,
        "is_verified": current_user.is_verified,
        "is_suspended": current_user.is_suspended,
        "is_banned": current_user.is_banned,
        "user_level": current_user.user_level,
        "last_login": (
            current_user.created_at.isoformat() if current_user.created_at else None
        ),
        "security_features": {
            "http_only_cookies": SecurityConfig.COOKIE_HTTPONLY,
            "secure_cookies": SecurityConfig.COOKIE_SECURE,
            "same_site": SecurityConfig.COOKIE_SAMESITE,
            "token_rotation": True,
            "blacklist_enabled": True,
        },
    }


@auth_router.post("/revoke-token")
async def revoke_current_token(
    request: Request,
    response: Response,
    credentials: HTTPAuthorizationCredentials = Depends(cookie_bearer),
    current_user: models.User = Depends(get_current_user_secure_sync),
):
    """撤销当前Token"""
    try:
        # 撤销当前token
        if credentials and credentials.credentials:
            revoke_token(credentials.credentials)

        # 清除Cookie
        clear_secure_cookies(response)

        # 记录安全事件
        client_ip = get_client_ip(request)
        log_security_event(
            "TOKEN_REVOKED", current_user.id, client_ip, "用户撤销当前token"
        )

        return {"message": "Token已撤销"}

    except Exception as e:
        logger.error(f"撤销token失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="撤销token失败"
        )
