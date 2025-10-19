"""
独立认证API路由
为客服和管理员提供独立的登录、登出等认证接口
"""

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status, BackgroundTasks
from sqlalchemy.orm import Session
from typing import Dict, Any
from app.deps import get_sync_db, get_current_customer_service_or_user, get_current_admin_user
from app import models, crud, schemas
from app.security import verify_password, get_password_hash
from app.admin_auth import AdminAuthManager, create_admin_session_cookie, clear_admin_session_cookie
from app.service_auth import ServiceAuthManager, create_service_session_cookie, clear_service_session_cookie
from app.separate_auth_deps import get_current_admin, get_current_service, get_current_user
from app.config import Config
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

router = APIRouter()

# ==================== 管理员认证API ====================

def find_admin_by_username_or_id(db: Session, username_or_id: str):
    """根据用户名或ID查找管理员"""
    admin = None
    
    # 首先尝试按用户名查找
    admin = crud.get_admin_user_by_username(db, username_or_id)
    
    # 如果按用户名没找到，且输入的是ID格式（A+4位数字），则按ID查找
    if not admin and username_or_id.startswith('A') and len(username_or_id) == 5 and username_or_id[1:].isdigit():
        admin = crud.get_admin_user_by_id(db, username_or_id)
        logger.info(f"[ADMIN_AUTH] 按ID查找管理员: {username_or_id}")
    
    return admin

@router.post("/admin/login", response_model=schemas.AdminLoginResponse)
def admin_login(
    login_data: schemas.AdminUserLoginNew,
    request: Request,
    response: Response,
    db: Session = Depends(get_sync_db)
):
    """管理员登录（独立认证系统）"""
    from app.admin_verification import AdminVerificationManager
    
    logger.info(f"[ADMIN_AUTH] 管理员登录尝试: {login_data.username}")
    
    # 查找管理员 - 支持用户名和ID登录
    admin = find_admin_by_username_or_id(db, login_data.username)
    if not admin:
        logger.warning(f"[ADMIN_AUTH] 管理员不存在: {login_data.username}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户名或密码错误"
        )
    
    # 检查管理员状态
    if not bool(admin.is_active):
        logger.warning(f"[ADMIN_AUTH] 管理员已被禁用: {admin.id}")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="管理员账户已被禁用"
        )
    
    # 验证密码
    if not verify_password(login_data.password, str(admin.hashed_password)):
        logger.warning(f"[ADMIN_AUTH] 管理员密码错误: {admin.id}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户名或密码错误"
        )
    
    # 检查是否启用了邮箱验证
    if AdminVerificationManager.is_verification_enabled():
        logger.info(f"[ADMIN_AUTH] 管理员邮箱验证已启用，需要验证码: {admin.id}")
        raise HTTPException(
            status_code=status.HTTP_202_ACCEPTED,
            detail="需要邮箱验证码，请先调用发送验证码接口",
            headers={"X-Requires-Verification": "true"}
        )
    
    # 如果未启用邮箱验证，直接登录
    # 创建管理员会话
    session_info = AdminAuthManager.create_session(str(admin.id), request)
    
    # 设置Cookie
    response = create_admin_session_cookie(response, session_info.session_id)
    
    # 创建并设置refresh token
    from app.admin_auth import create_admin_refresh_token, create_admin_refresh_token_cookie
    refresh_token = create_admin_refresh_token(str(admin.id))
    response = create_admin_refresh_token_cookie(response, refresh_token)
    
    # 生成并设置CSRF token
    from app.csrf import CSRFProtection
    csrf_token = CSRFProtection.generate_csrf_token()
    user_agent = request.headers.get("user-agent", "")
    CSRFProtection.set_csrf_cookie(response, csrf_token, user_agent)
    
    # 更新最后登录时间
    admin.last_login = datetime.utcnow()  # type: ignore
    db.commit()
    
    logger.info(f"[ADMIN_AUTH] 管理员登录成功: {admin.id}")
    
    return {
        "message": "管理员登录成功",
        "admin": {
            "id": str(admin.id),
            "name": str(admin.name),
            "username": str(admin.username),
            "email": str(admin.email),
            "is_super_admin": bool(admin.is_super_admin),
            "last_login": admin.last_login.isoformat() if admin.last_login else None  # type: ignore
        },
        "session_id": session_info.session_id
    }

@router.post("/admin/logout")
def admin_logout(
    request: Request,
    response: Response,
    current_admin: models.AdminUser = Depends(get_current_admin)
):
    """管理员登出（独立认证系统）"""
    logger.info(f"[ADMIN_AUTH] 管理员登出: {current_admin.id}")
    
    # 获取会话ID
    admin_session_id = request.cookies.get("admin_session_id")
    if admin_session_id:
        # 删除当前会话
        AdminAuthManager.delete_session(admin_session_id)
    
    # 删除管理员所有会话（包括其他设备的会话）
    deleted_sessions = AdminAuthManager.delete_all_sessions(str(current_admin.id))
    
    # 撤销所有refresh token
    from app.admin_auth import revoke_all_admin_refresh_tokens
    deleted_tokens = revoke_all_admin_refresh_tokens(str(current_admin.id))
    
    # 清除Cookie
    response = clear_admin_session_cookie(response)
    
    logger.info(f"[ADMIN_AUTH] 管理员登出完成: {current_admin.id}, 删除会话: {deleted_sessions}, 删除refresh token: {deleted_tokens}")
    
    return {
        "message": "管理员登出成功",
        "deleted_sessions": deleted_sessions,
        "deleted_tokens": deleted_tokens
    }


@router.post("/admin/refresh")
def admin_refresh(
    request: Request,
    response: Response,
    db: Session = Depends(get_sync_db)
):
    """管理员refresh token刷新"""
    from app.admin_auth import verify_admin_refresh_token, revoke_admin_refresh_token, create_admin_refresh_token, create_admin_refresh_token_cookie
    
    logger.info(f"[ADMIN_AUTH] 管理员refresh token刷新请求")
    
    try:
        # 从cookie中获取refresh token
        refresh_token = request.cookies.get("admin_refresh_token")
        if not refresh_token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="未找到refresh token"
            )
        
        # 验证refresh token
        admin_id = verify_admin_refresh_token(refresh_token)
        if not admin_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="无效的refresh token"
            )
        
        # 检查管理员是否存在
        admin = crud.get_admin_user_by_id(db, admin_id)
        if not admin:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="管理员不存在"
            )
        
        # 检查管理员状态
        if not bool(admin.is_active):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="管理员账户已被禁用"
            )
        
        # 撤销旧的refresh token
        revoke_admin_refresh_token(refresh_token)
        
        # 创建新的会话
        session_info = AdminAuthManager.create_session(admin_id, request)
        
        # 设置新的Cookie
        response = create_admin_session_cookie(response, session_info.session_id)
        
        # 创建新的refresh token
        new_refresh_token = create_admin_refresh_token(admin_id)
        response = create_admin_refresh_token_cookie(response, new_refresh_token)
        
        # 生成并设置新的CSRF token
        from app.csrf import CSRFProtection
        csrf_token = CSRFProtection.generate_csrf_token()
        user_agent = request.headers.get("user-agent", "")
        CSRFProtection.set_csrf_cookie(response, csrf_token, user_agent)
        
        logger.info(f"[ADMIN_AUTH] 管理员refresh token刷新成功: {admin_id}")
        
        return {
            "message": "会话刷新成功",
            "admin_id": admin_id,
            "session_id": session_info.session_id,
            "csrf_token": csrf_token
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"管理员refresh token刷新异常：{str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Token刷新服务异常"
        )

@router.post("/admin/send-verification-code")
def send_admin_verification_code(
    login_data: schemas.AdminUserLoginNew,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_sync_db)
):
    """发送管理员验证码"""
    from app.admin_verification import AdminVerificationManager
    from app.email_utils import send_admin_verification_code_email
    
    logger.info(f"[ADMIN_AUTH] 发送验证码请求: {login_data.username}")
    
    # 检查是否启用了邮箱验证
    if not AdminVerificationManager.is_verification_enabled():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="管理员邮箱验证功能未启用"
        )
    
    # 查找管理员 - 支持用户名和ID登录
    admin = find_admin_by_username_or_id(db, login_data.username)
    if not admin:
        logger.warning(f"[ADMIN_AUTH] 管理员不存在: {login_data.username}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户名或密码错误"
        )
    
    # 检查管理员状态
    if not bool(admin.is_active):
        logger.warning(f"[ADMIN_AUTH] 管理员已被禁用: {admin.id}")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="管理员账户已被禁用"
        )
    
    # 验证密码
    if not verify_password(login_data.password, str(admin.hashed_password)):
        logger.warning(f"[ADMIN_AUTH] 管理员密码错误: {admin.id}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户名或密码错误"
        )
    
    # 生成验证码
    verification_code = AdminVerificationManager.create_verification_code(db, str(admin.id))
    
    # 发送验证码邮件
    admin_email = AdminVerificationManager.get_admin_email()
    send_admin_verification_code_email(
        background_tasks, 
        admin_email, 
        verification_code, 
        str(admin.name)
    )
    
    logger.info(f"[ADMIN_AUTH] 验证码已发送到管理员邮箱: {admin_email}")
    
    return {
        "message": f"验证码已发送到管理员邮箱 {admin_email}",
        "admin_id": str(admin.id),
        "expires_in_minutes": Config.ADMIN_VERIFICATION_CODE_EXPIRE_MINUTES
    }

@router.post("/admin/verify-code")
def verify_admin_code(
    verification_data: schemas.AdminVerificationRequest,
    request: Request,
    response: Response,
    db: Session = Depends(get_sync_db)
):
    """验证管理员验证码并完成登录"""
    from app.admin_verification import AdminVerificationManager
    
    logger.info(f"[ADMIN_AUTH] 验证码验证请求: {verification_data.admin_id}")
    
    # 验证验证码
    if not AdminVerificationManager.verify_code(db, verification_data.admin_id, verification_data.code):
        logger.warning(f"[ADMIN_AUTH] 验证码验证失败: {verification_data.admin_id}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="验证码错误或已过期"
        )
    
    # 获取管理员信息
    admin = db.query(models.AdminUser).filter(models.AdminUser.id == verification_data.admin_id).first()
    if not admin:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="管理员不存在"
        )
    
    # 创建管理员会话
    session_info = AdminAuthManager.create_session(str(admin.id), request)
    
    # 设置Cookie
    response = create_admin_session_cookie(response, session_info.session_id)
    
    # 创建并设置refresh token
    from app.admin_auth import create_admin_refresh_token, create_admin_refresh_token_cookie
    refresh_token = create_admin_refresh_token(str(admin.id))
    response = create_admin_refresh_token_cookie(response, refresh_token)
    
    # 生成并设置CSRF token
    from app.csrf import CSRFProtection
    csrf_token = CSRFProtection.generate_csrf_token()
    user_agent = request.headers.get("user-agent", "")
    CSRFProtection.set_csrf_cookie(response, csrf_token, user_agent)
    
    # 更新最后登录时间
    admin.last_login = datetime.utcnow()  # type: ignore
    db.commit()
    
    logger.info(f"[ADMIN_AUTH] 管理员验证码登录成功: {admin.id}")
    
    return {
        "message": "管理员登录成功",
        "admin": {
            "id": str(admin.id),
            "name": str(admin.name),
            "username": str(admin.username),
            "email": str(admin.email),
            "is_super_admin": bool(admin.is_super_admin),
            "last_login": admin.last_login.isoformat() if admin.last_login else None  # type: ignore
        },
        "session_id": session_info.session_id
    }

@router.get("/admin/profile", response_model=schemas.AdminProfileResponse)
def get_admin_profile(
    request: Request,
    response: Response,
    current_admin: models.AdminUser = Depends(get_current_admin)
):
    """获取管理员个人信息"""
    # 添加CORS头
    origin = request.headers.get("origin")
    if origin and origin in ["https://www.link2ur.com", "https://api.link2ur.com"]:
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Access-Control-Allow-Credentials"] = "true"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With, Accept, Origin, Cache-Control, Pragma, X-CSRF-Token, X-Session-ID"
    
    return {
        "id": str(current_admin.id),
        "name": str(current_admin.name),
        "username": str(current_admin.username),
        "email": str(current_admin.email),
        "is_super_admin": bool(current_admin.is_super_admin),
        "is_active": bool(current_admin.is_active),
        "created_at": current_admin.created_at.isoformat() if current_admin.created_at else "",  # type: ignore
        "last_login": current_admin.last_login.isoformat() if current_admin.last_login else ""  # type: ignore
    }

@router.post("/admin/change-password")
def admin_change_password(
    password_data: schemas.AdminChangePassword,
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_sync_db)
):
    """管理员修改密码"""
    # 验证旧密码
    if not verify_password(password_data.old_password, str(current_admin.hashed_password)):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="旧密码错误"
        )
    
    # 更新密码
    current_admin.hashed_password = get_password_hash(password_data.new_password)  # type: ignore
    db.commit()
    
    logger.info(f"[ADMIN_AUTH] 管理员修改密码成功: {current_admin.id}")
    return {"message": "密码修改成功"}

# ==================== 客服认证API ====================

@router.get("/service/redis-test")
def service_redis_test():
    """测试客服Redis连接状态"""
    from app.service_auth import USE_REDIS, redis_client, safe_redis_get, safe_redis_set
    
    try:
        # 测试Redis连接
        if not USE_REDIS or not redis_client:
            return {
                "status": "error",
                "message": "Redis未启用或连接失败",
                "use_redis": USE_REDIS,
                "redis_client": redis_client is not None
            }
        
        # 测试ping
        try:
            redis_client.ping()
            ping_status = "success"
        except Exception as e:
            ping_status = f"failed: {e}"
        
        # 查找现有的客服会话
        pattern = "service_session:CS8888:*"
        existing_keys = redis_client.keys(pattern)
        
        # 测试存储和获取
        test_key = "service_test_key"
        test_data = {"test": "service_redis_test", "timestamp": datetime.utcnow().isoformat()}
        
        # 存储测试数据
        set_result = safe_redis_set(test_key, test_data, 60)
        
        # 获取测试数据
        get_result = safe_redis_get(test_key)
        
        # 测试现有会话数据获取
        existing_session_data = None
        if existing_keys:
            existing_session_data = safe_redis_get(existing_keys[0])
        
        # 清理测试数据
        if redis_client:
            redis_client.delete(test_key)
        
        return {
            "status": "success",
            "use_redis": USE_REDIS,
            "redis_client": redis_client is not None,
            "ping_status": ping_status,
            "set_result": set_result,
            "get_result": get_result,
            "data_match": get_result == test_data if get_result else False,
            "existing_keys": existing_keys,
            "existing_session_data": existing_session_data
        }
        
    except Exception as e:
        return {
            "status": "error",
            "message": f"测试失败: {str(e)}",
            "use_redis": USE_REDIS,
            "redis_client": redis_client is not None
        }

@router.post("/service/login", response_model=schemas.ServiceLoginResponse)
def service_login(
    login_data: schemas.CustomerServiceLogin,
    request: Request,
    response: Response,
    db: Session = Depends(get_sync_db)
):
    """客服登录（独立认证系统）"""
    logger.info(f"[SERVICE_AUTH] 客服登录尝试: {login_data.cs_id}")
    
    # 支持ID或邮箱登录
    username = login_data.cs_id  # 这里cs_id字段实际是用户名（可能是ID或邮箱）
    service = None
    
    # 首先尝试作为ID查找（CS + 4位数字格式）
    if username.startswith('CS') and len(username) == 6 and username[2:].isdigit():
        service = crud.get_customer_service_by_id(db, username)
        if service and verify_password(login_data.password, str(service.hashed_password)):
            pass  # 验证成功
        else:
            service = None
    
    # 如果ID查找失败，尝试作为邮箱查找
    if not service:
        service = crud.get_customer_service_by_email(db, username)
        if service and verify_password(login_data.password, str(service.hashed_password)):
            pass  # 验证成功
        else:
            service = None
    
    if not service:
        logger.warning(f"[SERVICE_AUTH] 客服不存在或密码错误: {username}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户名或密码错误"
        )
    
    # 创建客服会话
    try:
        session_info = ServiceAuthManager.create_session(str(service.id), request)
        logger.info(f"[SERVICE_AUTH] 客服会话创建成功: {service.id}")
    except Exception as e:
        logger.error(f"[SERVICE_AUTH] 客服会话创建失败: {service.id}, 错误: {str(e)}")
        logger.error(f"[SERVICE_AUTH] 错误详情: {type(e).__name__}: {str(e)}")
        import traceback
        logger.error(f"[SERVICE_AUTH] 堆栈跟踪: {traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"会话创建失败: {str(e)}"
        )
    
    # 设置Cookie
    try:
        user_agent = request.headers.get("user-agent", "")
        response = create_service_session_cookie(response, session_info.session_id, user_agent, str(service.id))
        
        # 生成并设置CSRF token
        try:
            from app.csrf import CSRFProtection
            csrf_token = CSRFProtection.generate_csrf_token()
            logger.info(f"[SERVICE_AUTH] 生成CSRF token: {csrf_token[:8]}...")
            CSRFProtection.set_csrf_cookie(response, csrf_token, user_agent)
            logger.info(f"[SERVICE_AUTH] CSRF cookie设置完成")
        except Exception as csrf_error:
            logger.error(f"[SERVICE_AUTH] CSRF token设置失败: {csrf_error}")
            # 不抛出异常，继续执行
        
        logger.info(f"[SERVICE_AUTH] 客服Cookie设置成功: {service.id}")
    except Exception as e:
        logger.error(f"[SERVICE_AUTH] 客服Cookie设置失败: {service.id}, 错误: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Cookie设置失败，请稍后重试"
        )
    
    # 设置客服在线状态
    service.is_online = 1  # type: ignore
    db.commit()
    
    logger.info(f"[SERVICE_AUTH] 客服登录成功: {service.id}")
    
    return {
        "message": "客服登录成功",
        "service": {
            "id": str(service.id),
            "name": str(service.name),
            "email": str(service.email),
            "avg_rating": float(service.avg_rating) if service.avg_rating else 0.0,  # type: ignore
            "total_ratings": int(service.total_ratings) if service.total_ratings else 0,  # type: ignore
            "is_online": bool(service.is_online),
            "created_at": service.created_at.isoformat() if service.created_at else None  # type: ignore
        },
        "session_id": session_info.session_id
    }

@router.post("/service/refresh", response_model=Dict[str, Any])
def service_refresh(
    request: Request,
    response: Response,
    current_service: models.CustomerService = Depends(get_current_service)
):
    """客服会话刷新 - 延长会话有效期"""
    logger.info(f"[SERVICE_AUTH] 客服会话刷新: {current_service.id}")
    
    try:
        # 获取当前会话ID
        service_session_id = request.cookies.get("service_session_id")
        if not service_session_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="未找到客服会话"
            )
        
        # 验证会话并更新活动时间
        session_info = ServiceAuthManager.get_session(service_session_id, update_activity=True)
        if not session_info or not session_info.is_active:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="客服会话无效或已过期"
            )
        
        # 生成新的CSRF token
        from app.csrf import CSRFProtection
        csrf_token = CSRFProtection.generate_csrf_token()
        user_agent = request.headers.get("user-agent", "")
        CSRFProtection.set_csrf_cookie(response, csrf_token, user_agent)
        
        logger.info(f"[SERVICE_AUTH] 客服会话刷新成功: {current_service.id}")
        
        return {
            "message": "会话刷新成功",
            "service": {
                "id": str(current_service.id),
                "name": str(current_service.name),
                "email": str(current_service.email),
                "avg_rating": float(current_service.avg_rating) if current_service.avg_rating else 0.0,  # type: ignore
                "total_ratings": int(current_service.total_ratings) if current_service.total_ratings else 0,  # type: ignore
                "is_online": bool(current_service.is_online),
                "created_at": current_service.created_at.isoformat() if current_service.created_at else None  # type: ignore
            },
            "session_id": session_info.session_id
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[SERVICE_AUTH] 客服会话刷新失败: {current_service.id}, 错误: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="会话刷新失败，请稍后重试"
        )

@router.post("/service/refresh-token", response_model=Dict[str, Any])
def service_refresh_token(
    request: Request,
    response: Response,
    db: Session = Depends(get_sync_db)
):
    """客服refresh token刷新 - 生成新的会话"""
    logger.info(f"[SERVICE_AUTH] 客服refresh token刷新请求")
    
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
        service = crud.get_customer_service_by_id(db, service_id)
        if not service:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="客服不存在"
            )
        
        # 验证refresh token
        from app.service_auth import verify_service_refresh_token
        verified_service_id = verify_service_refresh_token(refresh_token)
        if not verified_service_id or verified_service_id != service_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="无效的refresh token"
            )
        
        # 生成新的会话
        from app.service_auth import ServiceAuthManager, create_service_session_cookie
        new_session = ServiceAuthManager.create_session(service_id, request)
        
        # 撤销旧的refresh token
        from app.service_auth import revoke_service_refresh_token
        revoke_service_refresh_token(refresh_token)
        
        # 生成新的会话和refresh token
        user_agent = request.headers.get("user-agent", "")
        response = create_service_session_cookie(response, new_session.session_id, user_agent, str(service.id))
        
        # 生成新的CSRF token
        from app.csrf import CSRFProtection
        csrf_token = CSRFProtection.generate_csrf_token()
        CSRFProtection.set_csrf_cookie(response, csrf_token, user_agent)
        
        logger.info(f"[SERVICE_AUTH] 客服refresh token刷新成功: {service.id}")
        
        return {
            "message": "Token刷新成功",
            "service": {
                "id": str(service.id),
                "name": str(service.name),
                "email": str(service.email),
                "avg_rating": float(service.avg_rating) if service.avg_rating else 0.0,  # type: ignore
                "total_ratings": int(service.total_ratings) if service.total_ratings else 0,  # type: ignore
                "is_online": bool(service.is_online),
                "created_at": service.created_at.isoformat() if service.created_at else None  # type: ignore
            },
            "access_token": new_access_token,
            "refresh_token": new_refresh_token
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[SERVICE_AUTH] 客服refresh token刷新失败: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Token刷新失败，请稍后重试"
        )

@router.post("/service/logout")
def service_logout(
    request: Request,
    response: Response,
    current_service: models.CustomerService = Depends(get_current_service),
    db: Session = Depends(get_sync_db)
):
    """客服登出（独立认证系统）"""
    logger.info(f"[SERVICE_AUTH] 客服登出: {current_service.id}")
    
    # 获取会话ID和refresh token
    service_session_id = request.cookies.get("service_session_id")
    service_refresh_token = request.cookies.get("service_refresh_token")
    
    if service_session_id:
        # 删除会话
        ServiceAuthManager.delete_session(service_session_id)
        logger.info(f"[SERVICE_AUTH] 客服会话已删除: {service_session_id[:8]}...")
    
    # 清理refresh token
    if service_refresh_token:
        try:
            from app.service_auth import USE_REDIS, redis_client
            if USE_REDIS and redis_client:
                # 从Redis删除refresh token
                refresh_key = f"service_refresh_token:{service_refresh_token}"
                redis_client.delete(refresh_key)
                logger.info(f"[SERVICE_AUTH] 客服refresh token已删除: {service_refresh_token[:8]}...")
        except Exception as e:
            logger.error(f"[SERVICE_AUTH] 清理refresh token失败: {e}")
    
    # 设置客服离线状态
    current_service.is_online = 0  # type: ignore
    db.commit()
    
    # 清除Cookie
    response = clear_service_session_cookie(response)
    
    logger.info(f"[SERVICE_AUTH] 客服登出完成: {current_service.id}")
    return {"message": "客服登出成功"}

@router.get("/service/profile", response_model=schemas.ServiceProfileResponse)
def get_service_profile(
    current_service: models.CustomerService = Depends(get_current_service)
):
    """获取客服个人信息"""
    return {
        "id": str(current_service.id),
        "name": str(current_service.name),
        "email": str(current_service.email),
        "avg_rating": float(current_service.avg_rating) if current_service.avg_rating else 0.0,  # type: ignore
        "total_ratings": int(current_service.total_ratings) if current_service.total_ratings else 0,  # type: ignore
        "is_online": bool(current_service.is_online),
        "created_at": current_service.created_at.isoformat() if current_service.created_at else None  # type: ignore
    }

@router.post("/service/change-password")
def service_change_password(
    password_data: schemas.ServiceChangePassword,
    current_service: models.CustomerService = Depends(get_current_service),
    db: Session = Depends(get_sync_db)
):
    """客服修改密码"""
    # 验证旧密码
    if not verify_password(password_data.old_password, str(current_service.hashed_password)):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="旧密码错误"
        )
    
    # 更新密码
    current_service.hashed_password = get_password_hash(password_data.new_password)  # type: ignore
    db.commit()
    
    logger.info(f"[SERVICE_AUTH] 客服修改密码成功: {current_service.id}")
    return {"message": "密码修改成功"}

# ==================== 用户认证API ====================

@router.get("/user/profile", response_model=schemas.UserProfileResponse)
def get_user_profile(
    current_user: models.User = Depends(get_current_user)
):
    """获取用户个人信息"""
    return {
        "id": str(current_user.id),
        "name": str(current_user.name),
        "email": str(current_user.email),
        "phone": str(current_user.phone) if current_user.phone else None,  # type: ignore
        "is_verified": bool(current_user.is_verified),
        "is_suspended": bool(current_user.is_suspended),
        "is_banned": bool(current_user.is_banned),
        "created_at": current_user.created_at.isoformat(),
        "last_login": getattr(current_user, 'last_login', None).isoformat() if getattr(current_user, 'last_login', None) else None  # type: ignore
    }

@router.post("/user/logout")
def user_logout(
    request: Request,
    response: Response,
    current_user: models.User = Depends(get_current_user)
):
    """用户登出（使用原有认证系统）"""
    logger.info(f"[USER_AUTH] 用户登出: {current_user.id}")
    
    # 获取会话ID
    session_id = request.cookies.get("session_id")
    if session_id:
        # 删除会话（使用原有系统）
        from app.secure_auth import SecureAuthManager
        SecureAuthManager.revoke_session(session_id)
    
    # 清除Cookie
    response.delete_cookie("session_id")
    response.delete_cookie("user_authenticated")
    
    return {"message": "用户登出成功"}

# ==================== 会话管理API ====================

@router.get("/admin/sessions")
def get_admin_sessions(
    current_admin: models.AdminUser = Depends(get_current_admin)
):
    """获取管理员活跃会话列表"""
    # 这里可以实现获取当前管理员的所有活跃会话
    return {"message": "获取管理员会话列表", "sessions": []}

@router.post("/admin/sessions/clear")
def clear_admin_sessions(
    current_admin: models.AdminUser = Depends(get_current_admin)
):
    """清除管理员所有会话"""
    deleted_count = AdminAuthManager.delete_all_sessions(str(current_admin.id))
    return {"message": f"已清除 {deleted_count} 个会话"}

@router.get("/service/sessions")
def get_service_sessions(
    current_service: models.CustomerService = Depends(get_current_service)
):
    """获取客服活跃会话列表"""
    # 这里可以实现获取当前客服的所有活跃会话
    return {"message": "获取客服会话列表", "sessions": []}

@router.post("/service/sessions/clear")
def clear_service_sessions(
    current_service: models.CustomerService = Depends(get_current_service)
):
    """清除客服所有会话"""
    deleted_count = ServiceAuthManager.delete_all_sessions(str(current_service.id))
    return {"message": f"已清除 {deleted_count} 个会话"}


# ==================== 管理员通知API ====================

@router.get("/admin/notifications")
def get_admin_notifications(
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_sync_db)
):
    """获取管理员通知列表"""
    try:
        # 获取所有未读提醒 + 5条最新已读提醒
        notifications = crud.get_staff_notifications(db, current_admin.id, "admin")
        # 获取未读数量
        unread_count = crud.get_unread_staff_notification_count(
            db, current_admin.id, "admin"
        )

        return {
            "notifications": notifications,
            "total": len(notifications),
            "unread_count": unread_count,
        }
    except Exception as e:
        logger.error(f"获取管理员通知失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取通知失败"
        )


@router.get("/admin/notifications/unread")
def get_unread_admin_notifications(
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_sync_db)
):
    """获取管理员未读通知"""
    try:
        notifications = crud.get_unread_staff_notifications(db, current_admin.id, "admin")
        unread_count = crud.get_unread_staff_notification_count(
            db, current_admin.id, "admin"
        )

        return {
            "notifications": notifications,
            "unread_count": unread_count,
        }
    except Exception as e:
        logger.error(f"获取管理员未读通知失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取未读通知失败"
        )


@router.post("/admin/notifications/{notification_id}/read")
def mark_admin_notification_read(
    notification_id: int,
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_sync_db)
):
    """标记管理员通知为已读"""
    try:
        success = crud.mark_staff_notification_read(
            db, notification_id, current_admin.id, "admin"
        )
        
        if not success:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="通知不存在或无权限"
            )
        
        return {"message": "通知已标记为已读"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"标记管理员通知已读失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="标记通知已读失败"
        )


@router.post("/admin/notifications/read-all")
def mark_all_admin_notifications_read(
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_sync_db)
):
    """标记所有管理员通知为已读"""
    try:
        count = crud.mark_all_staff_notifications_read(
            db, current_admin.id, "admin"
        )
        
        return {
            "message": f"已标记 {count} 条通知为已读",
            "count": count
        }
    except Exception as e:
        logger.error(f"标记所有管理员通知已读失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="标记所有通知已读失败"
        )
