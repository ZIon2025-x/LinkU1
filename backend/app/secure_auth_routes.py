"""
安全认证路由
使用短有效期JWT + 可撤销机制 + 会话管理
"""

import json
import logging
import os
import time
from typing import Any, Dict
from datetime import datetime
from app.utils.time_utils import get_utc_time, format_iso_utc

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy.orm import Session

from app import crud, models, schemas
from app.deps import get_sync_db
from app.secure_auth import (
    SecureAuthManager,
    get_client_ip,
    get_device_fingerprint,
    validate_session
)
from app.cookie_manager import CookieManager
from app.security import get_password_hash, verify_password, log_security_event, generate_strong_password
from app.rate_limiting import rate_limit, rate_limiter
from app.captcha import captcha_verifier
from app.verification_code_manager import (
    generate_verification_code,
    store_verification_code,
    verify_and_delete_code
)
from app.phone_verification_code_manager import (
    generate_verification_code as generate_phone_code,
    store_verification_code as store_phone_code,
    verify_and_delete_code as verify_phone_code
)
from app.email_utils import send_email
from fastapi import BackgroundTasks

logger = logging.getLogger(__name__)

# 创建安全认证路由器
secure_auth_router = APIRouter(prefix="/api/secure-auth", tags=["安全认证"])

@secure_auth_router.get("/captcha-site-key", response_model=Dict[str, Any])
def get_captcha_site_key():
    """获取 CAPTCHA site key（前端使用）"""
    site_key = captcha_verifier.get_site_key()
    logger.info(f"CAPTCHA 配置查询: enabled={captcha_verifier.is_enabled()}, type={'recaptcha' if captcha_verifier.use_recaptcha else 'hcaptcha' if captcha_verifier.use_hcaptcha else None}, site_key前10字符={site_key[:10] if site_key else 'N/A'}")
    return {
        "site_key": site_key,
        "enabled": captcha_verifier.is_enabled(),
        "type": "recaptcha" if captcha_verifier.use_recaptcha else "hcaptcha" if captcha_verifier.use_hcaptcha else None
    }

@secure_auth_router.post("/login", response_model=Dict[str, Any])
@rate_limit("login")
def secure_login(
    user_credentials: schemas.UserLogin,
    request: Request,
    response: Response,
    db: Session = Depends(get_sync_db),
):
    """安全登录 - 创建会话并设置安全Cookie"""
    try:
        # 调试信息
        logger.info(f"安全登录请求: email={user_credentials.email}, password_length={len(user_credentials.password)}")
        
        # 查找用户 - 根据输入类型判断是ID还是邮箱
        username = user_credentials.email.strip()
        user = None
        
        # 判断输入类型：8位纯数字为ID，否则为邮箱
        if username.isdigit() and len(username) == 8:
            # ID登录：使用ID查找用户
            logger.info(f"ID登录：查找用户 id={username}")
            user = crud.get_user_by_id(db, username)
            if user:
                logger.info(f"通过ID找到用户: id={user.id}, name={user.name}")
            else:
                logger.warning(f"通过ID未找到用户: {username}")
        else:
            # 邮箱登录：使用邮箱查找用户（转小写以匹配数据库存储格式）
            username_lower = username.lower()
            logger.info(f"邮箱登录：查找用户 email={username_lower}")
            user = crud.get_user_by_email(db, username_lower)
            if user:
                logger.info(f"通过邮箱找到用户: id={user.id}, name={user.name}, email={user.email}")
            else:
                logger.warning(f"通过邮箱未找到用户: {username_lower}")
        
        # 验证用户和密码
        if not user:
            logger.warning(f"用户不存在: {username}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="用户不存在"
            )
        
        if not verify_password(user_credentials.password, user.hashed_password):
            logger.warning(f"密码验证失败: {username}")
            client_ip = get_client_ip(request)
            log_security_event(
                "LOGIN_FAILED", username, client_ip, "密码错误"
            )
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="密码错误"
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

        # 获取设备信息
        device_fingerprint = get_device_fingerprint(request)
        client_ip = get_client_ip(request)
        user_agent = request.headers.get("user-agent", "")
        
        # 生成并存储刷新令牌到Redis
        from app.secure_auth import create_user_refresh_token
        refresh_token = create_user_refresh_token(user.id, client_ip, device_fingerprint)
        
        # 创建新会话
        session = SecureAuthManager.create_session(
            user_id=user.id,
            device_fingerprint=device_fingerprint,
            ip_address=client_ip,
            user_agent=user_agent,
            refresh_token=refresh_token
        )
        
        # 设置安全Cookie（传递User-Agent用于移动端检测）
        CookieManager.set_session_cookies(
            response=response,
            session_id=session.session_id,
            refresh_token=refresh_token,
            user_id=user.id,
            user_agent=user_agent
        )
        
        # 生成并设置CSRF token
        from app.csrf import CSRFProtection
        csrf_token = CSRFProtection.generate_csrf_token()
        CookieManager.set_csrf_cookie(response, csrf_token, user_agent)
        
        # 记录成功登录
        log_security_event("LOGIN_SUCCESS", user.id, client_ip, "用户安全登录成功")
        
        # 检测是否为移动端
        is_mobile = any(keyword in user_agent.lower() for keyword in [
            'mobile', 'iphone', 'ipad', 'android', 'blackberry', 
            'windows phone', 'opera mini', 'iemobile'
        ])
        
        # 为移动端添加特殊的响应头
        if is_mobile:
            # 设置会话ID到响应头（用于移动端）
            response.headers["X-Session-ID"] = session.session_id
            response.headers["X-User-ID"] = user.id
            response.headers["X-Auth-Status"] = "authenticated"
            response.headers["X-Mobile-Auth"] = "true"

        return {
            "message": "登录成功",
            "user": {
                "id": user.id,
                "name": user.name,
                "email": user.email,
                "user_level": user.user_level,
                "is_verified": user.is_verified,
            },
            "session_id": session.session_id,  # 会话ID用于认证
            "expires_in": 300,  # 5分钟
            "mobile_auth": is_mobile,  # 标识是否为移动端
            "auth_headers": {
                "X-Session-ID": session.session_id,
                "X-User-ID": user.id,
                "X-Auth-Status": "authenticated"
            } if is_mobile else None
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"安全登录失败: {e}")
        # 提供更详细的错误信息用于调试
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"登录失败: {str(e)}"
        )

@secure_auth_router.post("/refresh", response_model=Dict[str, Any])
def refresh_session(
    request: Request,
    response: Response,
    db: Session = Depends(get_sync_db),
):
    """刷新会话 - 延长会话有效期"""
    try:
        # 获取当前会话
        session = validate_session(request)
        if not session:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="会话无效或已过期"
            )
        
        # 获取用户信息
        user = crud.get_user_by_id(db, session.user_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="用户不存在"
            )
        
        # 检查用户状态
        if user.is_suspended or user.is_banned:
            # 撤销所有会话
            SecureAuthManager.revoke_user_sessions(user.id)
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="账户已被暂停或封禁"
            )
        
        # 更新现有会话的最后活动时间（不创建新会话）
        session.last_activity = get_utc_time()
        SecureAuthManager._store_session(session)
        
        # 生成并存储新的刷新令牌到Redis
        from app.secure_auth import create_user_refresh_token
        refresh_token = create_user_refresh_token(user.id, get_client_ip(request), get_device_fingerprint(request))
        
        # 设置新的安全Cookie（复用现有会话）
        CookieManager.set_session_cookies(
            response=response,
            session_id=session.session_id,
            refresh_token=refresh_token,
            user_id=user.id,
            user_agent=request.headers.get("user-agent", "")
        )
        
        logger.info(f"会话刷新成功 - 用户: {user.id}, 会话: {session.session_id[:8]}...")
        
        return {
            "message": "会话刷新成功",
            "session_id": session.session_id,  # 仅用于调试
            "expires_in": 300,  # 5分钟
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"会话刷新失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="会话刷新失败"
        )

@secure_auth_router.post("/refresh-token", response_model=Dict[str, Any])
def refresh_session_with_token(
    request: Request,
    response: Response,
    db: Session = Depends(get_sync_db),
):
    """使用refresh_token刷新会话 - 当session_id过期时使用"""
    try:
        # 从Cookie中获取refresh_token
        refresh_token = request.cookies.get("refresh_token")
        if not refresh_token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, 
                detail="未找到refresh_token"
            )
        
        # 获取设备信息
        device_fingerprint = get_device_fingerprint(request)
        client_ip = get_client_ip(request)
        
        # 验证refresh_token
        from app.secure_auth import verify_user_refresh_token
        user_id = verify_user_refresh_token(refresh_token, client_ip, device_fingerprint)
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, 
                detail="refresh_token无效或已过期"
            )
        
        # 获取用户信息
        user = crud.get_user_by_id(db, user_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, 
                detail="用户不存在"
            )
        
        # 检查用户状态
        if user.is_suspended or user.is_banned:
            # 撤销所有refresh_token
            from app.secure_auth import revoke_all_user_refresh_tokens
            revoke_all_user_refresh_tokens(user.id)
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, 
                detail="账户已被暂停或封禁"
            )
        
        # 获取设备信息
        device_fingerprint = get_device_fingerprint(request)
        client_ip = get_client_ip(request)
        user_agent = request.headers.get("user-agent", "")
        
        # 验证成功后，撤销旧的refresh_token，生成新的refresh_token
        from app.secure_auth import create_user_refresh_token, revoke_user_refresh_token
        revoke_user_refresh_token(refresh_token)
        
        # 创建新的refresh_token（这会自动删除用户的所有旧refresh token）
        new_refresh_token = create_user_refresh_token(user.id, client_ip, device_fingerprint)
        
        # 创建新会话 - refresh token应该总是创建新会话
        # 先撤销现有会话，然后创建新会话
        existing_session_id = request.cookies.get("session_id")
        if existing_session_id:
            SecureAuthManager.revoke_session(existing_session_id)
            logger.info(f"撤销现有会话: {existing_session_id[:8]}...")
        
        # 创建新会话
        session = SecureAuthManager.create_session(
            user_id=user.id,
            device_fingerprint=device_fingerprint,
            ip_address=client_ip,
            user_agent=user_agent,
            refresh_token=new_refresh_token  # 使用新的refresh_token
        )
        
        # 设置新的安全Cookie
        CookieManager.set_session_cookies(
            response=response,
            session_id=session.session_id,
            refresh_token=new_refresh_token,
            user_id=user.id,
            user_agent=user_agent
        )
        
        # 生成并设置CSRF token
        from app.csrf import CSRFProtection
        csrf_token = CSRFProtection.generate_csrf_token()
        CookieManager.set_csrf_cookie(response, csrf_token, user_agent)
        
        logger.info(f"通过refresh_token刷新会话成功 - 用户: {user.id}, 会话: {session.session_id[:8]}...")
        
        return {
            "message": "会话刷新成功",
            "session_id": session.session_id,  # 仅用于调试
            "expires_in": 300,  # 5分钟
            "refreshed_by": "refresh_token"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"refresh_token刷新失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail="refresh_token刷新失败"
        )

@secure_auth_router.post("/logout")
def secure_logout(
    request: Request,
    response: Response,
):
    """安全登出 - 撤销当前会话"""
    try:
        # 获取当前会话
        session = validate_session(request)
        if session:
            # 撤销会话
            SecureAuthManager.revoke_session(session.session_id)
            logger.info(f"用户登出 - 会话: {session.session_id[:8]}...")
        
        # 清除Cookie
        CookieManager.clear_all_cookies(response)
        
        return {"message": "登出成功"}

    except Exception as e:
        logger.error(f"安全登出失败: {e}")
        # 即使出错也要清除Cookie
        CookieManager.clear_all_cookies(response)
        return {"message": "登出成功"}

@secure_auth_router.post("/logout-all")
def logout_all_sessions(
    request: Request,
    response: Response,
    db: Session = Depends(get_sync_db),
):
    """登出所有会话 - 撤销用户的所有会话"""
    try:
        # 获取当前会话
        session = validate_session(request)
        if not session:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="会话无效"
            )
        
        # 撤销用户的所有会话
        revoked_count = SecureAuthManager.revoke_user_sessions(session.user_id)
        
        # 清除Cookie
        CookieManager.clear_all_cookies(response)
        
        logger.info(f"用户登出所有会话 - 用户: {session.user_id}, 撤销: {revoked_count} 个会话")
        
        return {
            "message": "所有会话已登出",
            "revoked_sessions": revoked_count
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"登出所有会话失败: {e}")
        return {"message": "登出失败"}

@secure_auth_router.get("/sessions")
def get_active_sessions(
    request: Request,
    db: Session = Depends(get_sync_db),
):
    """获取活跃会话列表"""
    try:
        # 获取当前会话
        current_session = validate_session(request)
        if not current_session:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="会话无效"
            )
        
        # 获取用户的所有活跃会话
        user_sessions = []
        
        # 导入模块级变量
        from app.secure_auth import USE_REDIS, redis_client
        
        if USE_REDIS and redis_client:
            # 从 Redis 获取用户会话
            user_sessions_key = f"user_sessions:{current_session.user_id}"
            session_ids = redis_client.smembers(user_sessions_key)
            
            for raw_id in session_ids:
                session_id = raw_id.decode() if isinstance(raw_id, bytes) else raw_id
                session_data = redis_client.get(f"session:{session_id}")
                if session_data:
                    data = json.loads(session_data)
                    if data.get("is_active", False):
                        user_sessions.append({
                            "session_id": session_id[:8] + "...",
                            "device_fingerprint": data.get("device_fingerprint", ""),
                            "ip_address": data.get("ip_address", ""),
                            "created_at": data.get("created_at", ""),
                            "last_activity": data.get("last_activity", data.get("created_at", "")),
                            "is_current": session_id == current_session.session_id
                        })
        else:
            # 从内存获取用户会话
            from app.secure_auth import active_sessions
            for session in active_sessions.values():
                if session.user_id == current_session.user_id and session.is_active:
                    user_sessions.append({
                        "session_id": session.session_id[:8] + "...",
                        "device_fingerprint": session.device_fingerprint,
                        "ip_address": session.ip_address,
                        "created_at": format_iso_utc(session.created_at),
                        "last_activity": format_iso_utc(session.last_activity),
                        "is_current": session.session_id == current_session.session_id
                    })
        
        return {
            "sessions": user_sessions,
            "total": len(user_sessions)
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取会话列表失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="获取会话列表失败"
        )

@secure_auth_router.post("/logout-others")
def logout_other_sessions(
    request: Request,
    response: Response,
):
    """一键登出其它设备：保留当前会话，撤销该用户其它所有会话，并清理对应refresh token。"""
    try:
        # 当前会话
        session = validate_session(request)
        if not session:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="会话无效"
            )

        # 获取当前请求中携带的refresh_token（如有则保留）
        keep_refresh = request.cookies.get("refresh_token", "")

        # 撤销其它会话
        from app.secure_auth import SecureAuthManager
        revoked = SecureAuthManager.revoke_other_sessions(
            user_id=session.user_id,
            keep_session_id=session.session_id,
            keep_refresh_token=keep_refresh,
        )

        return {
            "message": "已登出其它设备",
            "revoked_sessions": revoked
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"一键登出其它设备失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="操作失败"
        )

@secure_auth_router.delete("/sessions/{session_id}")
def revoke_session(
    session_id: str,
    request: Request,
    db: Session = Depends(get_sync_db),
):
    """撤销指定会话"""
    try:
        # 获取当前会话
        current_session = validate_session(request)
        if not current_session:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="会话无效"
            )
        
        # 查找要撤销的会话
        from app.secure_auth import USE_REDIS, redis_client, safe_redis_get, active_sessions
        
        # 获取目标会话
        if USE_REDIS and redis_client:
            session_data = safe_redis_get(f"session:{session_id}")
            if not session_data or not session_data.get("is_active", False):
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND, detail="会话不存在"
                )
            target_user_id = session_data.get("user_id")
        else:
            target_session = active_sessions.get(session_id)
            if not target_session or not target_session.is_active:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND, detail="会话不存在"
                )
            target_user_id = target_session.user_id
        
        # 检查权限（只能撤销自己的会话）
        if target_user_id != current_session.user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="无权撤销此会话"
            )
        
        # 撤销会话
        success = SecureAuthManager.revoke_session(session_id)
        if not success:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail="撤销会话失败"
            )
        
        logger.info(f"撤销会话成功 - 会话: {session_id[:8]}..., 用户: {current_session.user_id}")
        
        return {"message": "会话已撤销"}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"撤销会话失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="撤销会话失败"
        )

@secure_auth_router.get("/status")
def get_auth_status(
    request: Request,
    db: Session = Depends(get_sync_db),
):
    """获取认证状态"""
    try:
        # 获取当前会话
        session = validate_session(request)
        if not session:
            return {
                "authenticated": False,
                "message": "未认证"
            }
        
        # 获取用户信息
        user = crud.get_user_by_id(db, session.user_id)
        if not user:
            return {
                "authenticated": False,
                "message": "用户不存在"
            }
        
        return {
            "authenticated": True,
            "user": {
                "id": user.id,
                "name": user.name,
                "email": user.email,
                "user_level": user.user_level,
                "is_verified": user.is_verified,
            },
            "session": {
                "session_id": session.session_id[:8] + "...",
                "created_at": format_iso_utc(session.created_at),
                "last_activity": format_iso_utc(session.last_activity),
            }
        }

    except Exception as e:
        logger.error(f"获取认证状态失败: {e}")
        return {
            "authenticated": False,
            "message": "获取状态失败"
        }

@secure_auth_router.get("/session-id")
def get_session_id(
    request: Request,
):
    """获取当前会话的 session_id（用于跨域请求）"""
    try:
        # 获取当前会话
        session = validate_session(request)
        if not session:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, 
                detail="会话无效或已过期"
            )
        
        # 返回完整的 session_id（用于 X-Session-ID 头）
        return {
            "session_id": session.session_id,
            "message": "会话ID获取成功"
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取会话ID失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取会话ID失败"
        )

@secure_auth_router.get("/redis-status")
def get_redis_status():
    """获取 Redis 连接状态"""
    try:
        from app.secure_auth import USE_REDIS, redis_client
        from app.config import Config
        
        # 基础信息
        status = {
            "timestamp": format_iso_utc(get_utc_time()),
            "railway_environment": os.getenv("RAILWAY_ENVIRONMENT", "false"),
            "redis_url_set": bool(Config.REDIS_URL),
            "redis_url_preview": Config.REDIS_URL[:20] + "..." if Config.REDIS_URL else None,
            "use_redis_config": Config.USE_REDIS,
            "secure_auth_use_redis": USE_REDIS,
            "redis_client_available": bool(redis_client)
        }
        
        if not USE_REDIS or not redis_client:
            status.update({
                "redis_enabled": False,
                "message": "Redis 未启用或连接失败",
                "details": {
                    "config_use_redis": Config.USE_REDIS,
                    "secure_auth_use_redis": USE_REDIS,
                    "redis_client_exists": bool(redis_client)
                }
            })
            return status
        
        # 测试 Redis 连接
        try:
            redis_client.ping()
            status["ping_success"] = True
        except Exception as ping_error:
            status.update({
                "redis_enabled": False,
                "message": f"Redis ping 失败: {str(ping_error)}",
                "ping_success": False
            })
            return status
        
        # 获取 Redis 信息
        try:
            info = redis_client.info()
            status.update({
                "redis_enabled": True,
                "redis_version": info.get("redis_version", "unknown"),
                "connected_clients": info.get("connected_clients", 0),
                "used_memory": info.get("used_memory_human", "unknown"),
                "uptime_in_seconds": info.get("uptime_in_seconds", 0),
                "message": "Redis 连接正常"
            })
        except Exception as info_error:
            status.update({
                "redis_enabled": True,
                "message": f"Redis 连接正常，但获取信息失败: {str(info_error)}"
            })
        
        # 测试会话存储
        try:
            test_session_id = "test_railway_redis"
            test_data = {"test": "railway_redis_check", "timestamp": format_iso_utc(get_utc_time())}
            
            # 存储测试数据
            redis_client.setex(f"session:{test_session_id}", 60, json.dumps(test_data))
            
            # 获取测试数据
            retrieved = redis_client.get(f"session:{test_session_id}")
            if retrieved:
                parsed = json.loads(retrieved)
                if parsed.get("test") == "railway_redis_check":
                    status["session_storage_test"] = "✅ 成功"
                else:
                    status["session_storage_test"] = "❌ 数据不匹配"
                # 清理测试数据
                redis_client.delete(f"session:{test_session_id}")
            else:
                status["session_storage_test"] = "❌ 获取失败"
                
        except Exception as session_error:
            status["session_storage_test"] = f"❌ 测试失败: {str(session_error)}"
        
        return status
        
    except Exception as e:
        logger.error(f"Redis 状态检查失败: {e}")
        return {
            "redis_enabled": False,
            "message": f"Redis 连接失败: {str(e)}",
            "error_details": str(e),
            "timestamp": format_iso_utc(get_utc_time())
        }

@secure_auth_router.post("/cleanup-refresh-tokens")
def cleanup_old_refresh_tokens_endpoint(
    request: Request,
):
    """清理旧的refresh token（手动触发）"""
    try:
        # 验证会话
        current_session = validate_session(request)
        if not current_session:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="会话无效"
            )
        from app.secure_auth import USE_REDIS, redis_client
        
        if not USE_REDIS or not redis_client:
            return {
                "success": False,
                "message": "Redis不可用"
            }
        
        # 获取所有refresh token
        pattern = "user_refresh_token:*"
        all_keys = redis_client.keys(pattern)
        
        if not all_keys:
            return {
                "success": True,
                "message": "没有需要清理的refresh token",
                "deleted": 0
            }
        
        # 按用户分组
        user_tokens = {}
        for key in all_keys:
            key_str = key.decode() if isinstance(key, bytes) else key
            # 格式: user_refresh_token:USER_ID:TOKEN
            parts = key_str.split(':')
            if len(parts) >= 3:
                user_id = parts[1]
                if user_id not in user_tokens:
                    user_tokens[user_id] = []
                user_tokens[user_id].append(key_str)
        
        # 对于每个用户，如果有多个token，只保留最新的一个
        total_deleted = 0
        for user_id, token_keys in user_tokens.items():
            if len(token_keys) > 1:
                # 获取所有token的创建时间
                token_times = []
                for token_key in token_keys:
                    try:
                        data = redis_client.get(token_key)
                        if data:
                            data_str = data.decode() if isinstance(data, bytes) else data
                            token_data = json.loads(data_str)
                            created_at = token_data.get('created_at', '')
                            token_times.append((token_key, created_at))
                    except Exception as e:
                        logger.warning(f"获取token数据失败 {token_key}: {e}")
                        token_times.append((token_key, ''))
                
                # 按创建时间排序，保留最新的一个
                if token_times:
                    token_times.sort(key=lambda x: x[1], reverse=True)
                    # 删除旧的token
                    old_tokens = [k for k, _ in token_times[1:]]
                    if old_tokens:
                        redis_client.delete(*old_tokens)
                        total_deleted += len(old_tokens)
                        logger.info(f"用户 {user_id}: 保留了1个最新token，删除了{len(old_tokens)}个旧token")
        
        return {
            "success": True,
            "message": f"清理完成，共删除 {total_deleted} 个旧refresh token",
            "deleted": total_deleted
        }
        
    except Exception as e:
        logger.error(f"清理refresh token失败: {e}")
        return {
            "success": False,
            "message": f"清理失败: {str(e)}"
        }

@secure_auth_router.post("/send-verification-code", response_model=Dict[str, Any])
@rate_limit("send_code")
def send_email_verification_code(
    request_data: schemas.EmailVerificationCodeRequest,
    background_tasks: BackgroundTasks,
    request: Request,
):
    """发送邮箱验证码"""
    try:
        # CAPTCHA 验证（强制要求，防止恶意刷验证码）
        captcha_enabled = captcha_verifier.is_enabled()
        logger.info(f"发送邮箱验证码请求: email={request_data.email}, CAPTCHA启用={captcha_enabled}, 收到token={bool(request_data.captcha_token)}")
        
        if captcha_enabled:
            if not request_data.captcha_token:
                logger.warning(f"发送验证码请求缺少 CAPTCHA token: email={request_data.email}, IP={get_client_ip(request)}")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="必须完成人机验证才能发送验证码"
                )
            
            client_ip = get_client_ip(request)
            captcha_result = captcha_verifier.verify(request_data.captcha_token, client_ip)
            if not captcha_result.get("success"):
                logger.warning(f"CAPTCHA 验证失败: email={request_data.email}, IP={client_ip}, error={captcha_result.get('error')}")
                # 记录安全事件
                log_security_event(
                    "CAPTCHA_FAILED", request_data.email, client_ip, f"CAPTCHA验证失败: {captcha_result.get('error')}"
                )
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="人机验证失败，请重新完成验证后再试"
                )
            logger.info(f"CAPTCHA 验证成功: email={request_data.email}")
        else:
            logger.info(f"CAPTCHA 未启用，跳过验证: email={request_data.email}")
        
        # 针对特定邮箱的速率限制（更严格）
        # 创建临时请求对象用于邮箱级别的速率限制
        from types import SimpleNamespace
        email_rate_request = SimpleNamespace()
        email_rate_request.headers = request.headers
        email_rate_request.client = request.client
        email_rate_request.cookies = request.cookies
        
        # 使用邮箱作为标识符进行速率限制
        email_rate_key = f"rate_limit:send_code_per_email:email:{request_data.email.strip().lower()}"
        try:
            # 手动检查速率限制
            if rate_limiter.redis_client:
                current_time = int(time.time())
                window = 600  # 10分钟
                limit = 3
                window_start = current_time - window
                
                # 移除过期的请求
                rate_limiter.redis_client.zremrangebyscore(email_rate_key, 0, window_start)
                
                # 获取当前窗口内的请求数
                current_requests = rate_limiter.redis_client.zcard(email_rate_key)
                
                if current_requests >= limit:
                    logger.warning(f"邮箱验证码发送频率限制: email={request_data.email}, 已发送 {current_requests} 次")
                    raise HTTPException(
                        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                        detail=f"该邮箱验证码发送过于频繁，请10分钟后再试"
                    )
                
                # 添加当前请求
                rate_limiter.redis_client.zadd(email_rate_key, {str(current_time): current_time})
                rate_limiter.redis_client.expire(email_rate_key, window)
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"邮箱速率限制检查失败: {e}")
            # 失败时继续，不阻止请求
        
        email = request_data.email.strip().lower()
        
        # 验证邮箱格式
        import re
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_pattern, email):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="邮箱格式不正确"
            )
        
        # 生成6位数字验证码
        verification_code = generate_verification_code(6)
        
        # 存储验证码到Redis，有效期10分钟
        if not store_verification_code(email, verification_code):
            logger.error(f"存储验证码失败: email={email}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="发送验证码失败，请稍后重试"
            )
        
        # 根据用户语言偏好获取邮件模板（尝试从数据库获取用户信息）
        from app import crud
        from app.email_templates import get_user_language, get_login_verification_code_email
        from app.database import SessionLocal
        
        user = None
        try:
            # 创建临时数据库会话
            temp_db = SessionLocal()
            try:
                user = crud.get_user_by_email(temp_db, email)
            finally:
                temp_db.close()
        except:
            pass
        
        language = get_user_language(user) if user else 'en'  # 默认英文
        subject, body = get_login_verification_code_email(language, verification_code)
        
        # 异步发送邮件
        background_tasks.add_task(send_email, email, subject, body)
        
        logger.info(f"验证码已发送: email={email}")
        
        return {
            "message": "验证码已发送到您的邮箱",
            "email": email,
            "expires_in": 600  # 10分钟
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"发送验证码失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="发送验证码失败"
        )


@secure_auth_router.post("/send-phone-verification-code", response_model=Dict[str, Any])
@rate_limit("send_code")
def send_phone_verification_code(
    request_data: schemas.PhoneVerificationCodeRequest,
    background_tasks: BackgroundTasks,
    request: Request,
):
    """发送手机验证码"""
    try:
        # CAPTCHA 验证（强制要求，防止恶意刷验证码）
        captcha_enabled = captcha_verifier.is_enabled()
        logger.info(f"发送手机验证码请求: phone={request_data.phone}, CAPTCHA启用={captcha_enabled}, 收到token={bool(request_data.captcha_token)}")
        
        if captcha_enabled:
            if not request_data.captcha_token:
                logger.warning(f"发送验证码请求缺少 CAPTCHA token: phone={request_data.phone}, IP={get_client_ip(request)}")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="必须完成人机验证才能发送验证码"
                )
            
            client_ip = get_client_ip(request)
            captcha_result = captcha_verifier.verify(request_data.captcha_token, client_ip)
            if not captcha_result.get("success"):
                logger.warning(f"CAPTCHA 验证失败: phone={request_data.phone}, IP={client_ip}, error={captcha_result.get('error')}")
                # 记录安全事件
                log_security_event(
                    "CAPTCHA_FAILED", request_data.phone, client_ip, f"CAPTCHA验证失败: {captcha_result.get('error')}"
                )
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="人机验证失败，请重新完成验证后再试"
                )
            logger.info(f"CAPTCHA 验证成功: phone={request_data.phone}")
        else:
            logger.info(f"CAPTCHA 未启用，跳过验证: phone={request_data.phone}")
        
        import re
        from app.validators import StringValidator
        
        phone = request_data.phone.strip()
        
        # 针对特定手机号的速率限制（更严格）
        phone_rate_key = f"rate_limit:send_code_per_phone:phone:{phone}"
        try:
                # 手动检查速率限制
            if rate_limiter.redis_client:
                current_time = int(time.time())
                window = 600  # 10分钟
                limit = 3
                window_start = current_time - window
                
                # 移除过期的请求
                rate_limiter.redis_client.zremrangebyscore(phone_rate_key, 0, window_start)
                
                # 获取当前窗口内的请求数
                current_requests = rate_limiter.redis_client.zcard(phone_rate_key)
                
                if current_requests >= limit:
                    logger.warning(f"手机验证码发送频率限制: phone={phone}, 已发送 {current_requests} 次")
                    raise HTTPException(
                        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                        detail=f"该手机号验证码发送过于频繁，请10分钟后再试"
                    )
                
                # 添加当前请求
                rate_limiter.redis_client.zadd(phone_rate_key, {str(current_time): current_time})
                rate_limiter.redis_client.expire(phone_rate_key, window)
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"手机号速率限制检查失败: {e}")
            # 失败时继续，不阻止请求
        
        # 验证手机号格式（前端已发送完整号码，如 +447700123456）
        # 验证格式：必须以 + 开头，后面是10-15位数字
        import re
        if not phone.startswith('+'):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="手机号格式不正确，必须以国家代码开头（如 +44）"
            )
        if not re.match(r'^\+\d{10,15}$', phone):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="手机号格式不正确，请检查国家代码和手机号"
            )
        
        phone_digits = phone  # 直接使用前端发送的完整号码
        
        # 发送短信（使用 Twilio）
        try:
            from app.twilio_sms import twilio_sms
            
            # 如果使用 Twilio Verify API，不需要生成和存储验证码
            if twilio_sms.use_verify_api and twilio_sms.verify_client:
                # Verify API 会自动生成验证码，直接发送
                sms_sent = twilio_sms.send_verification_code(phone_digits, language='zh')
                verification_code = None  # Verify API 不需要我们存储验证码
            else:
                # Messages API 需要自己生成验证码
                # 生成6位数字验证码
                verification_code = generate_phone_code(6)
                
                # 存储验证码到Redis，有效期10分钟
                if not store_phone_code(phone_digits, verification_code):
                    logger.error(f"存储手机验证码失败: phone={phone_digits}")
                    raise HTTPException(
                        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                        detail="发送验证码失败，请稍后重试"
                    )
                
                # 获取用户语言偏好（默认为中文）
                language = 'zh'  # 可以从请求中获取，暂时默认为中文
                
                # 尝试发送短信
                sms_sent = twilio_sms.send_verification_code(phone_digits, verification_code, language)
            
                if not sms_sent:
                    # 如果 Twilio 发送失败，在开发环境中记录日志
                    if os.getenv("ENVIRONMENT", "production") == "development":
                        if verification_code:
                            logger.warning(f"[开发环境] Twilio 未配置或发送失败，手机验证码: {phone_digits} -> {verification_code}")
                        else:
                            logger.warning(f"[开发环境] Twilio Verify API 发送失败: {phone_digits}")
                    else:
                        logger.error(f"Twilio 短信发送失败: phone={phone_digits}")
                        raise HTTPException(
                            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                            detail="发送验证码失败，请稍后重试"
                        )
                else:
                    logger.info(f"手机验证码已通过 Twilio 发送: phone={phone_digits}")
        except ValueError as e:
            # 检测特定的 Twilio 错误
            if str(e) == "CHINA_VETTING_REQUIRED":
                logger.error(f"Twilio 需要审核才能向中国手机号发送短信: phone={phone_digits}")
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail="向中国手机号发送短信需要 Twilio 审核，请联系管理员或使用邮箱验证码登录"
                )
            elif str(e) == "PHONE_BLOCKED":
                logger.error(f"Twilio 检测到可疑活动，手机号被临时封禁: phone={phone_digits}")
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="该手机号因可疑活动被临时封禁，请稍后再试或使用邮箱验证码登录。如有疑问，请联系客服。"
                )
            raise
        except ImportError:
            # 如果 Twilio 未安装，在开发环境中记录日志
            logger.warning("Twilio 模块未安装，无法发送短信")
            if os.getenv("ENVIRONMENT", "production") == "development":
                # 生成验证码用于开发环境测试
                verification_code = generate_phone_code(6)
                if not store_phone_code(phone_digits, verification_code):
                    logger.error(f"存储手机验证码失败: phone={phone_digits}")
                logger.warning(f"[开发环境] 手机验证码: {phone_digits} -> {verification_code}")
            else:
                logger.error("Twilio 模块未安装，无法发送短信")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="短信服务未配置，请联系管理员"
                )
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"发送短信时发生异常: {e}")
            # 在开发环境中，即使发送失败也继续（记录验证码）
            if os.getenv("ENVIRONMENT", "production") == "development":
                # 如果使用 Verify API，无法获取验证码，只能提示
                if twilio_sms.use_verify_api:
                    logger.warning(f"[开发环境] Twilio Verify API 异常，无法获取验证码: {phone_digits}")
                else:
                    # Messages API 模式下，记录生成的验证码
                    if 'verification_code' not in locals():
                        verification_code = generate_phone_code(6)
                        store_phone_code(phone_digits, verification_code)
                    logger.warning(f"[开发环境] 手机验证码: {phone_digits} -> {verification_code}")
            else:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="发送验证码失败，请稍后重试"
                )
        
        return {
            "message": "验证码已发送到您的手机",
            "phone": phone_digits,
            "expires_in": 600  # 10分钟
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"发送手机验证码失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="发送验证码失败"
        )


@secure_auth_router.post("/login-with-phone-code", response_model=Dict[str, Any])
@rate_limit("login")
def login_with_phone_verification_code(
    login_data: schemas.PhoneVerificationCodeLogin,
    request: Request,
    response: Response,
    db: Session = Depends(get_sync_db),
):
    """使用手机号验证码登录，新用户自动创建"""
    try:
        # CAPTCHA 验证（登录时可选，因为用户已经通过验证码验证）
        # 注意：发送验证码时已经完成了 CAPTCHA 验证，登录时不再强制要求
        if captcha_verifier.is_enabled() and login_data.captcha_token:
            # 如果提供了 CAPTCHA token，则验证（可选）
            client_ip = get_client_ip(request)
            captcha_result = captcha_verifier.verify(login_data.captcha_token, client_ip)
            if not captcha_result.get("success"):
                logger.warning(f"CAPTCHA 验证失败: phone={login_data.phone}, IP={client_ip}, error={captcha_result.get('error')}")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="人机验证失败，请重试"
                )
            logger.info(f"CAPTCHA 验证成功（登录）: phone={login_data.phone}")
        else:
            # 登录时不强制要求 CAPTCHA（用户已通过验证码验证）
            logger.info(f"登录请求: phone={login_data.phone}, CAPTCHA token={'已提供' if login_data.captcha_token else '未提供（允许）'}")
        
        import re
        from app.validators import StringValidator
        
        phone = login_data.phone.strip()
        verification_code = login_data.verification_code.strip()
        
        # 验证手机号格式（前端已发送完整号码，如 +447700123456）
        # 验证格式：必须以 + 开头，后面是10-15位数字
        import re
        if not phone.startswith('+'):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="手机号格式不正确，必须以国家代码开头（如 +44）"
            )
        if not re.match(r'^\+\d{10,15}$', phone):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="手机号格式不正确，请检查国家代码和手机号"
            )
        
        phone_digits = phone  # 直接使用前端发送的完整号码
        
        # 验证验证码（支持 Twilio Verify API 和自定义验证码）
        verification_success = False
        try:
            from app.twilio_sms import twilio_sms
            # 如果使用 Twilio Verify API，使用其验证方法
            if twilio_sms.use_verify_api and twilio_sms.verify_client:
                verification_success = twilio_sms.verify_code(phone_digits, verification_code)
            else:
                # 否则使用自定义验证码（存储在 Redis 中）
                verification_success = verify_phone_code(phone_digits, verification_code)
        except Exception as e:
            logger.error(f"验证码验证过程出错: {e}")
            verification_success = False
        
        if not verification_success:
            logger.warning(f"手机验证码验证失败: phone={phone_digits}")
            client_ip = get_client_ip(request)
            log_security_event(
                "LOGIN_FAILED", phone_digits, client_ip, "手机验证码错误或已过期"
            )
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="验证码错误或已过期"
            )
        
        # 查找用户（使用手机号，不是邮箱）
        logger.info(f"手机号验证码登录：查找用户 phone={phone_digits}")
        user = crud.get_user_by_phone(db, phone_digits)
        if user:
            logger.info(f"通过手机号找到用户: id={user.id}, name={user.name}, phone={user.phone}, email={user.email}")
        else:
            logger.info(f"手机号 {phone_digits} 未找到用户，将创建新用户")
        
        # 如果用户不存在，自动创建新用户
        is_new_user = False
        if not user:
            is_new_user = True
            import random
            # 生成唯一的8位用户ID
            while True:
                user_id = str(random.randint(10000000, 99999999))
                existing_user = crud.get_user_by_id(db, user_id)
                if not existing_user:
                    break
            
            # 生成强密码
            strong_password = generate_strong_password(16)
            hashed_password = get_password_hash(strong_password)
            
            # 生成用户名：user + 用户ID
            username = f"user{user_id}"
            
            # 检查用户名是否已存在（虽然理论上不应该，但为了安全）
            while True:
                existing_name = db.query(models.User).filter(models.User.name == username).first()
                if not existing_name:
                    break
                # 如果用户名已存在，重新生成用户ID和用户名
                while True:
                    user_id = str(random.randint(10000000, 99999999))
                    existing_user = crud.get_user_by_id(db, user_id)
                    if not existing_user:
                        break
                username = f"user{user_id}"
            
            # 创建新用户（手机号登录时，邮箱为空，等待用户后续设置）
            try:
                db_user = models.User(
                    id=user_id,
                    name=username,
                    email=None,  # 手机号登录时，邮箱为空，用户后续可以设置
                    hashed_password=hashed_password,
                    phone=phone_digits,
                    avatar="",
                    agreed_to_terms=1,
                    terms_agreed_at=get_utc_time(),
                    is_verified=1,  # 验证码登录创建的用户已验证
                    is_active=1,    # 激活
                )
                db.add(db_user)
                db.commit()
                db.refresh(db_user)
                
                user = db_user
                logger.info(f"新用户已创建（手机号登录）: id={user_id}, phone={phone_digits}, name={username}, email=None, is_verified=1")
            except Exception as e:
                db.rollback()
                logger.error(f"创建新用户失败: {e}")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail=f"创建用户失败: {str(e)}"
                )
        
        # 检查用户状态
        if user.is_suspended:
            client_ip = get_client_ip(request)
            log_security_event(
                "SUSPENDED_USER_LOGIN", user.id, client_ip, "被暂停用户尝试登录"
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="账户已被暂停"
            )
        
        if user.is_banned:
            client_ip = get_client_ip(request)
            log_security_event(
                "BANNED_USER_LOGIN", user.id, client_ip, "被封禁用户尝试登录"
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="账户已被封禁"
            )
        
        # 获取设备信息
        device_fingerprint = get_device_fingerprint(request)
        client_ip = get_client_ip(request)
        user_agent = request.headers.get("user-agent", "")
        
        # 生成并存储刷新令牌到Redis
        from app.secure_auth import create_user_refresh_token
        refresh_token = create_user_refresh_token(user.id, client_ip, device_fingerprint)
        
        # 创建新会话
        session = SecureAuthManager.create_session(
            user_id=user.id,
            device_fingerprint=device_fingerprint,
            ip_address=client_ip,
            user_agent=user_agent,
            refresh_token=refresh_token
        )
        
        # 设置安全Cookie（传递User-Agent用于移动端检测）
        CookieManager.set_session_cookies(
            response=response,
            session_id=session.session_id,
            refresh_token=refresh_token,
            user_id=user.id,
            user_agent=user_agent
        )
        
        # 生成并设置CSRF token
        from app.csrf import CSRFProtection
        csrf_token = CSRFProtection.generate_csrf_token()
        CookieManager.set_csrf_cookie(response, csrf_token, user_agent)
        
        # 记录成功登录
        log_security_event("LOGIN_SUCCESS", user.id, client_ip, "用户手机验证码登录成功")
        
        # 检测是否为移动端
        is_mobile = any(keyword in user_agent.lower() for keyword in [
            'mobile', 'iphone', 'ipad', 'android', 'blackberry', 
            'windows phone', 'opera mini', 'iemobile'
        ])
        
        # 为移动端添加特殊的响应头
        if is_mobile:
            response.headers["X-Session-ID"] = session.session_id
            response.headers["X-User-ID"] = user.id
            response.headers["X-Auth-Status"] = "authenticated"
            response.headers["X-Mobile-Auth"] = "true"

        return {
            "message": "登录成功",
            "user": {
                "id": user.id,
                "name": user.name,
                "email": user.email,
                "phone": user.phone,
                "user_level": user.user_level,
                "is_verified": user.is_verified,
            },
            "session_id": session.session_id,
            "expires_in": 300,
            "mobile_auth": is_mobile,
            "auth_headers": {
                "X-Session-ID": session.session_id,
                "X-User-ID": user.id,
                "X-Auth-Status": "authenticated"
            } if is_mobile else None,
            "is_new_user": is_new_user
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"手机验证码登录失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"登录失败: {str(e)}"
        )


@secure_auth_router.post("/login-with-code", response_model=Dict[str, Any])
@rate_limit("login")
def login_with_verification_code(
    login_data: schemas.EmailVerificationCodeLogin,
    request: Request,
    response: Response,
    db: Session = Depends(get_sync_db),
):
    """使用邮箱验证码登录，新用户自动创建"""
    try:
        # CAPTCHA 验证（登录时可选，因为用户已经通过验证码验证）
        # 注意：发送验证码时已经完成了 CAPTCHA 验证，登录时不再强制要求
        if captcha_verifier.is_enabled() and login_data.captcha_token:
            # 如果提供了 CAPTCHA token，则验证（可选）
            client_ip = get_client_ip(request)
            captcha_result = captcha_verifier.verify(login_data.captcha_token, client_ip)
            if not captcha_result.get("success"):
                logger.warning(f"CAPTCHA 验证失败: email={login_data.email}, IP={client_ip}, error={captcha_result.get('error')}")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="人机验证失败，请重试"
                )
            logger.info(f"CAPTCHA 验证成功（登录）: email={login_data.email}")
        else:
            # 登录时不强制要求 CAPTCHA（用户已通过验证码验证）
            logger.info(f"登录请求: email={login_data.email}, CAPTCHA token={'已提供' if login_data.captcha_token else '未提供（允许）'}")
        
        email = login_data.email.strip().lower()
        verification_code = login_data.verification_code.strip()
        
        # 验证验证码
        if not verify_and_delete_code(email, verification_code):
            logger.warning(f"验证码验证失败: email={email}")
            client_ip = get_client_ip(request)
            log_security_event(
                "LOGIN_FAILED", email, client_ip, "验证码错误或已过期"
            )
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="验证码错误或已过期"
            )
        
        # 查找用户（使用邮箱，不是手机号）
        logger.info(f"邮箱验证码登录：查找用户 email={email}")
        user = crud.get_user_by_email(db, email)
        if user:
            logger.info(f"通过邮箱找到用户: id={user.id}, name={user.name}, email={user.email}, phone={user.phone}")
        else:
            logger.info(f"邮箱 {email} 未找到用户，将创建新用户")
        
        # 如果用户不存在，自动创建新用户
        is_new_user = False
        if not user:
            is_new_user = True
            import random
            # 生成唯一的8位用户ID
            while True:
                user_id = str(random.randint(10000000, 99999999))
                existing_user = crud.get_user_by_id(db, user_id)
                if not existing_user:
                    break
            
            # 生成强密码
            strong_password = generate_strong_password(16)
            hashed_password = get_password_hash(strong_password)
            
            # 生成用户名：user + 用户ID
            username = f"user{user_id}"
            
            # 检查用户名是否已存在（虽然理论上不应该，但为了安全）
            # 直接使用数据库查询
            while True:
                existing_name = db.query(models.User).filter(models.User.name == username).first()
                if not existing_name:
                    break
                # 如果用户名已存在，重新生成用户ID和用户名
                while True:
                    user_id = str(random.randint(10000000, 99999999))
                    existing_user = crud.get_user_by_id(db, user_id)
                    if not existing_user:
                        break
                username = f"user{user_id}"
            
            # 创建新用户
            try:
                db_user = models.User(
                    id=user_id,
                    name=username,
                    email=email,
                    hashed_password=hashed_password,
                    phone=None,
                    avatar="",
                    agreed_to_terms=1,
                    terms_agreed_at=get_utc_time(),
                    is_verified=1,  # 验证码登录创建的用户已验证
                    is_active=1,    # 激活
                )
                db.add(db_user)
                db.commit()
                db.refresh(db_user)
                
                user = db_user
                logger.info(f"新用户已创建: id={user_id}, email={email}, name={username}, is_verified=1")
            except Exception as e:
                db.rollback()
                logger.error(f"创建新用户失败: {e}")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail=f"创建用户失败: {str(e)}"
                )
        
        # 检查用户状态
        if user.is_suspended:
            client_ip = get_client_ip(request)
            log_security_event(
                "SUSPENDED_USER_LOGIN", user.id, client_ip, "被暂停用户尝试登录"
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="账户已被暂停"
            )
        
        if user.is_banned:
            client_ip = get_client_ip(request)
            log_security_event(
                "BANNED_USER_LOGIN", user.id, client_ip, "被封禁用户尝试登录"
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="账户已被封禁"
            )
        
        # 获取设备信息
        device_fingerprint = get_device_fingerprint(request)
        client_ip = get_client_ip(request)
        user_agent = request.headers.get("user-agent", "")
        
        # 生成并存储刷新令牌到Redis
        from app.secure_auth import create_user_refresh_token
        refresh_token = create_user_refresh_token(user.id, client_ip, device_fingerprint)
        
        # 创建新会话
        session = SecureAuthManager.create_session(
            user_id=user.id,
            device_fingerprint=device_fingerprint,
            ip_address=client_ip,
            user_agent=user_agent,
            refresh_token=refresh_token
        )
        
        # 设置安全Cookie（传递User-Agent用于移动端检测）
        CookieManager.set_session_cookies(
            response=response,
            session_id=session.session_id,
            refresh_token=refresh_token,
            user_id=user.id,
            user_agent=user_agent
        )
        
        # 生成并设置CSRF token
        from app.csrf import CSRFProtection
        csrf_token = CSRFProtection.generate_csrf_token()
        CookieManager.set_csrf_cookie(response, csrf_token, user_agent)
        
        # 记录成功登录
        log_security_event("LOGIN_SUCCESS", user.id, client_ip, "用户验证码登录成功")
        
        # 检测是否为移动端
        is_mobile = any(keyword in user_agent.lower() for keyword in [
            'mobile', 'iphone', 'ipad', 'android', 'blackberry', 
            'windows phone', 'opera mini', 'iemobile'
        ])
        
        # 为移动端添加特殊的响应头
        if is_mobile:
            response.headers["X-Session-ID"] = session.session_id
            response.headers["X-User-ID"] = user.id
            response.headers["X-Auth-Status"] = "authenticated"
            response.headers["X-Mobile-Auth"] = "true"

        return {
            "message": "登录成功",
            "user": {
                "id": user.id,
                "name": user.name,
                "email": user.email,
                "user_level": user.user_level,
                "is_verified": user.is_verified,
            },
            "session_id": session.session_id,
            "expires_in": 300,
            "mobile_auth": is_mobile,
            "auth_headers": {
                "X-Session-ID": session.session_id,
                "X-User-ID": user.id,
                "X-Auth-Status": "authenticated"
            } if is_mobile else None,
            "is_new_user": is_new_user
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"验证码登录失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"登录失败: {str(e)}"
        )
