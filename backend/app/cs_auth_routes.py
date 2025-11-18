"""
客服认证路由
专门为客服提供安全的登录和认证功能
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
from app.role_deps import get_current_customer_service_secure_sync
from app.rate_limiting import rate_limit
from app.role_management import UserRole

logger = logging.getLogger(__name__)

cs_auth_router = APIRouter(prefix="/api/customer-service", tags=["客服认证"])

@cs_auth_router.post("/login", response_model=Dict[str, Any])
@rate_limit("cs_login")
async def cs_login(
    cs_credentials: schemas.CustomerServiceLogin,
    request: Request,
    response: Response,
    db: Session = Depends(get_sync_db),
):
    """
    客服登录
    增强安全措施：
    - 速率限制
    - 登录日志记录
    - 失败次数限制
    - IP地址记录
    """
    try:
        # 判断输入是ID还是邮箱
        username = cs_credentials.cs_id  # 这里cs_id字段实际是用户名（可能是ID或邮箱）
        cs = None
        
        # 首先尝试作为ID查找（CS + 4位数字格式）
        if username.startswith('CS') and len(username) == 6 and username[2:].isdigit():
            cs = db.query(models.CustomerService).filter(
                models.CustomerService.id == username
            ).first()
        
        # 如果ID查找失败，尝试作为邮箱查找
        if not cs:
            cs = db.query(models.CustomerService).filter(
                models.CustomerService.email == username
            ).first()
        
        if not cs:
            logger.warning(f"客服登录失败：用户名不存在 - {username}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="用户名或密码错误"
            )
        
        # 检查账号状态（客服模型中没有is_active字段，暂时跳过）
        # if not cs.is_active:
        #     logger.warning(f"客服登录失败：账号已禁用 - {username}")
        #     raise HTTPException(
        #         status_code=status.HTTP_403_FORBIDDEN,
        #         detail="账号已被禁用"
        #     )
        
        # 验证密码
        if not verify_password(cs_credentials.password, cs.hashed_password):
            logger.warning(f"客服登录失败：密码错误 - {cs_credentials.email}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="邮箱或密码错误"
            )
        
        # 使用新的客服会话认证系统
        from app.service_auth import ServiceAuthManager, create_service_session_cookie
        
        # 创建客服会话
        session_info = ServiceAuthManager.create_session(str(cs.id), request)
        logger.info(f"[SERVICE_AUTH] 客服会话创建成功: {cs.id}")
        
        # 设置客服会话Cookie
        user_agent = request.headers.get("user-agent", "")
        response = create_service_session_cookie(response, session_info.session_id, user_agent, str(cs.id), request)
        
        # 生成并设置CSRF token
        from app.csrf import CSRFProtection
        csrf_token = CSRFProtection.generate_csrf_token()
        user_agent = request.headers.get("user-agent", "")
        CSRFProtection.set_csrf_cookie(response, csrf_token, user_agent)
        
        # 添加安全响应头
        from app.security import add_security_headers
        add_security_headers(response)
        
        # 更新最后登录时间（客服模型中没有last_login字段，暂时跳过）
        # cs.last_login = get_utc_time()
        # db.commit()
        
        # 记录成功登录
        logger.info(f"客服登录成功：{cs.email} (ID: {cs.id})")
        
        return {
            "message": "客服登录成功",
            "user": {
                "id": cs.id,
                "name": cs.name,
                "email": cs.email,
                "role": "customer_service",
                "user_type": "customer_service"
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"客服登录异常：{str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="登录服务异常"
        )

@cs_auth_router.post("/refresh", response_model=Dict[str, Any])
@rate_limit("cs_refresh")
async def cs_refresh_token(
    request: Request,
    response: Response,
    db: Session = Depends(get_sync_db)
):
    """
    客服刷新token
    """
    try:
        # 从cookie中获取refresh token
        refresh_token = request.cookies.get("service_refresh_token")
        if not refresh_token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="未找到refresh token"
            )
        
        # 从cookie中获取service_id
        service_id = request.cookies.get("service_id")
        if not service_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="未找到service_id"
            )
        
        # 检查客服是否存在
        cs = db.query(models.CustomerService).filter(
            models.CustomerService.id == service_id
        ).first()
        
        if not cs:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="客服不存在"
            )
        
        # 验证refresh token
        from app.service_auth import verify_service_refresh_token
        from app.secure_auth import get_client_ip, get_device_fingerprint
        verified_service_id = verify_service_refresh_token(refresh_token, get_client_ip(request), get_device_fingerprint(request))
        if not verified_service_id or verified_service_id != service_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="无效的refresh token"
            )
        
        # 获取现有会话ID（不创建新会话）
        existing_session_id = request.cookies.get("service_session_id")
        if not existing_session_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="未找到现有会话"
            )
        
        # 验证现有会话
        from app.service_auth import ServiceAuthManager
        existing_session = ServiceAuthManager.get_session(existing_session_id)
        if not existing_session or existing_session.service_id != service_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="现有会话无效"
            )
        
        # 撤销旧的refresh token
        from app.service_auth import revoke_service_refresh_token
        revoke_service_refresh_token(refresh_token)
        
        # 生成新的refresh token（复用现有会话）
        from app.service_auth import create_service_session_cookie
        user_agent = request.headers.get("user-agent", "")
        response = create_service_session_cookie(response, existing_session_id, user_agent, str(cs.id), request)
        
        # 生成并设置新的CSRF token
        from app.csrf import CSRFProtection
        csrf_token = CSRFProtection.generate_csrf_token()
        user_agent = request.headers.get("user-agent", "")
        CSRFProtection.set_csrf_cookie(response, csrf_token, user_agent)
        
        # 添加安全响应头
        from app.security import add_security_headers
        add_security_headers(response)
        
        logger.info(f"客服refresh token刷新成功 - 客服: {cs.id}")
        
        return {
            "message": "会话刷新成功",
            "service_id": cs.id,
            "session_id": existing_session_id,
            "csrf_token": csrf_token
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"客服token刷新异常：{str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Token刷新服务异常"
        )

@cs_auth_router.post("/logout")
@rate_limit("cs_logout")
async def cs_logout(
    request: Request,
    response: Response,
    current_cs: models.CustomerService = Depends(get_current_customer_service_secure_sync)
):
    """
    客服登出
    """
    try:
        # 获取refresh token并清理Redis
        service_refresh_token = request.cookies.get("service_refresh_token")
        if service_refresh_token:
            try:
                from app.service_auth import USE_REDIS, redis_client
                if USE_REDIS and redis_client:
                    # 从Redis删除refresh token
                    refresh_key = f"service_refresh_token:{service_refresh_token}"
                    redis_client.delete(refresh_key)
                    logger.info(f"[CS_AUTH] 客服refresh token已删除: {service_refresh_token[:8]}...")
            except Exception as e:
                logger.error(f"[CS_AUTH] 清理refresh token失败: {e}")
        
        # 清除cookie
        from app.cookie_manager import CookieManager
        CookieManager.clear_all_cookies(response)
        
        # 设置客服离线状态
        current_cs.is_online = 0  # type: ignore
        from app.deps import get_sync_db
        db = next(get_sync_db())
        db.commit()
        
        logger.info(f"客服登出成功：{current_cs.email} (ID: {current_cs.id})")
        
        return {"message": "登出成功"}
        
    except Exception as e:
        logger.error(f"客服登出异常：{str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="登出服务异常"
        )

@cs_auth_router.get("/profile")
async def get_cs_profile(
    current_cs: models.CustomerService = Depends(get_current_customer_service_secure_sync)
):
    """
    获取客服个人信息
    """
    return {
        "id": current_cs.id,
        "name": current_cs.name,
        "email": current_cs.email,
        "is_active": current_cs.is_active,
        "created_at": current_cs.created_at,
        "last_login": current_cs.last_login,
        "role": "customer_service"
    }

@cs_auth_router.put("/change-password")
@rate_limit("cs_change_password")
async def cs_change_password(
    password_data: schemas.PasswordChange,
    current_cs: models.CustomerService = Depends(get_current_customer_service_secure_sync),
    db: Session = Depends(get_sync_db)
):
    """
    客服修改密码
    """
    try:
        # 验证当前密码
        if not verify_password(password_data.current_password, current_cs.hashed_password):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="当前密码错误"
            )
        
        # 更新密码
        current_cs.hashed_password = get_password_hash(password_data.new_password)
        db.commit()
        
        logger.info(f"客服修改密码成功：{current_cs.email} (ID: {current_cs.id})")
        
        return {"message": "密码修改成功"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"客服修改密码异常：{str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="密码修改服务异常"
        )

@cs_auth_router.get("/permissions")
async def get_cs_permissions(
    current_cs: models.CustomerService = Depends(get_current_customer_service_secure_sync)
):
    """
    获取客服权限列表
    """
    from app.role_management import RolePermissions, UserRole
    from app.utils.time_utils import get_utc_time
    
    permissions = RolePermissions.get_permissions(UserRole.CUSTOMER_SERVICE)
    
    return {
        "role": "customer_service",
        "permissions": permissions
    }
