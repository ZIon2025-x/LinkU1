"""
安全认证路由
使用短有效期JWT + 可撤销机制 + 会话管理
"""

import json
import logging
import os
from typing import Any, Dict
from datetime import datetime

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
from app.security import get_password_hash, verify_password, log_security_event
from app.rate_limiting import rate_limit

logger = logging.getLogger(__name__)

# 创建安全认证路由器
secure_auth_router = APIRouter(prefix="/api/secure-auth", tags=["安全认证"])

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
        
        # 查找用户
        username = user_credentials.email
        user = None
        
        # 首先尝试作为ID查找（8位数字）
        if username.isdigit() and len(username) == 8:
            user = crud.get_user_by_id(db, username)
        
        # 如果ID查找失败，尝试作为邮箱查找
        if not user:
            logger.info(f"尝试通过邮箱查找用户: {username}")
            user = crud.get_user_by_email(db, username)
            if user:
                logger.info(f"通过邮箱找到用户: {user.id}, {user.name}")
            else:
                logger.warning(f"通过邮箱未找到用户: {username}")
        
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
        
        # 创建新会话
        session = SecureAuthManager.create_session(
            user_id=user.id,
            device_fingerprint=device_fingerprint,
            ip_address=client_ip,
            user_agent=user_agent
        )
        
        # 生成刷新令牌
        refresh_token = SecureAuthManager.generate_refresh_token()
        
        # 设置安全Cookie（传递User-Agent用于移动端检测）
        CookieManager.set_session_cookies(
            response=response,
            session_id=session.session_id,
            refresh_token=refresh_token,
            user_id=user.id,
            user_agent=user_agent
        )
        
        # 记录成功登录
        log_security_event("LOGIN_SUCCESS", user.id, client_ip, "用户安全登录成功")
        
        # 检测是否为移动端
        is_mobile = any(keyword in user_agent.lower() for keyword in [
            'mobile', 'iphone', 'ipad', 'android', 'blackberry', 
            'windows phone', 'opera mini', 'iemobile'
        ])
        
        # 为移动端添加特殊的响应头和token
        if is_mobile:
            # 为移动端生成access_token作为备用认证
            from app.security import create_access_token
            access_token = create_access_token({"sub": user.id})
            
            response.headers["X-Session-ID"] = session.session_id
            response.headers["X-User-ID"] = user.id
            response.headers["X-Auth-Status"] = "authenticated"
            response.headers["X-Mobile-Auth"] = "true"
            response.headers["X-Access-Token"] = access_token  # 移动端备用token

        return {
            "message": "登录成功",
            "user": {
                "id": user.id,
                "name": user.name,
                "email": user.email,
                "user_level": user.user_level,
                "is_verified": user.is_verified,
            },
            "session_id": session.session_id,  # 移动端需要这个值
            "access_token": access_token if is_mobile else None,  # 移动端备用token
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
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="登录失败"
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
        
        # 生成新的会话ID（防止会话固定攻击）
        new_session = SecureAuthManager.create_session(
            user_id=user.id,
            device_fingerprint=session.device_fingerprint,
            ip_address=get_client_ip(request),
            user_agent=request.headers.get("user-agent", "")
        )
        
        # 撤销旧会话
        SecureAuthManager.revoke_session(session.session_id)
        
        # 生成新的刷新令牌
        refresh_token = SecureAuthManager.generate_refresh_token()
        
        # 设置新的安全Cookie
        CookieManager.set_session_cookies(
            response=response,
            session_id=new_session.session_id,
            refresh_token=refresh_token,
            user_id=user.id,
            user_agent=request.headers.get("user-agent", "")
        )
        
        logger.info(f"会话刷新成功 - 用户: {user.id}, 新会话: {new_session.session_id[:8]}...")
        
        return {
            "message": "会话刷新成功",
            "session_id": new_session.session_id,  # 仅用于调试
            "expires_in": 300,  # 5分钟
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"会话刷新失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="会话刷新失败"
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
        
        if SecureAuthManager.USE_REDIS and SecureAuthManager.redis_client:
            # 从 Redis 获取用户会话
            user_sessions_key = f"user_sessions:{current_session.user_id}"
            session_ids = SecureAuthManager.redis_client.smembers(user_sessions_key)
            
            for session_id in session_ids:
                session_data = SecureAuthManager.redis_client.get(f"session:{session_id}")
                if session_data:
                    data = json.loads(session_data)
                    if data.get("is_active", False):
                        user_sessions.append({
                            "session_id": session_id[:8] + "...",
                            "device_fingerprint": data["device_fingerprint"],
                            "ip_address": data["ip_address"],
                            "created_at": data["created_at"],
                            "last_activity": data["last_activity"],
                            "is_current": session_id == current_session.session_id
                        })
        else:
            # 从内存获取用户会话
            for session in SecureAuthManager.active_sessions.values():
                if session.user_id == current_session.user_id and session.is_active:
                    user_sessions.append({
                        "session_id": session.session_id[:8] + "...",
                        "device_fingerprint": session.device_fingerprint,
                        "ip_address": session.ip_address,
                        "created_at": session.created_at.isoformat(),
                        "last_activity": session.last_activity.isoformat(),
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
        target_session = SecureAuthManager.active_sessions.get(session_id)
        if not target_session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="会话不存在"
            )
        
        # 检查权限（只能撤销自己的会话）
        if target_session.user_id != current_session.user_id:
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
                "created_at": session.created_at.isoformat(),
                "last_activity": session.last_activity.isoformat(),
            }
        }

    except Exception as e:
        logger.error(f"获取认证状态失败: {e}")
        return {
            "authenticated": False,
            "message": "获取状态失败"
        }

@secure_auth_router.get("/redis-status")
def get_redis_status():
    """获取 Redis 连接状态"""
    try:
        from app.secure_auth import USE_REDIS, redis_client
        from app.config import Config
        
        # 基础信息
        status = {
            "timestamp": datetime.now().isoformat(),
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
            test_data = {"test": "railway_redis_check", "timestamp": datetime.now().isoformat()}
            
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
            "timestamp": datetime.now().isoformat()
        }
