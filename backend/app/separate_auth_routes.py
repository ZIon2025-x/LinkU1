"""
独立认证API路由
为客服和管理员提供独立的登录、登出等认证接口
"""

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy.orm import Session
from typing import Dict, Any
from app.deps import get_sync_db, get_current_customer_service_or_user, get_current_admin_user
from app import models, crud, schemas
from app.security import verify_password, get_password_hash
from app.admin_auth import AdminAuthManager, create_admin_session_cookie, clear_admin_session_cookie
from app.service_auth import ServiceAuthManager, create_service_session_cookie, clear_service_session_cookie
from app.separate_auth_deps import get_current_admin, get_current_service, get_current_user
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

router = APIRouter()

# ==================== 管理员认证API ====================

@router.post("/admin/login", response_model=schemas.AdminLoginResponse)
def admin_login(
    login_data: schemas.AdminUserLoginNew,
    request: Request,
    response: Response,
    db: Session = Depends(get_sync_db)
):
    """管理员登录（独立认证系统）"""
    logger.info(f"[ADMIN_AUTH] 管理员登录尝试: {login_data.username}")
    
    # 查找管理员
    admin = crud.get_admin_user_by_username(db, login_data.username)
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
    
    # 创建管理员会话
    session_info = AdminAuthManager.create_session(str(admin.id), request)
    
    # 设置Cookie
    response = create_admin_session_cookie(response, session_info.session_id)
    
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
        # 删除会话
        AdminAuthManager.delete_session(admin_session_id)
    
    # 清除Cookie
    response = clear_admin_session_cookie(response)
    
    return {"message": "管理员登出成功"}

@router.get("/admin/profile", response_model=schemas.AdminProfileResponse)
def get_admin_profile(
    current_admin: models.AdminUser = Depends(get_current_admin)
):
    """获取管理员个人信息"""
    return {
        "id": str(current_admin.id),
        "name": str(current_admin.name),
        "username": str(current_admin.username),
        "email": str(current_admin.email),
        "is_super_admin": bool(current_admin.is_super_admin),
        "is_active": bool(current_admin.is_active),
        "created_at": current_admin.created_at.isoformat() if current_admin.created_at else None,  # type: ignore
        "last_login": current_admin.last_login.isoformat() if current_admin.last_login else None  # type: ignore
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
        response = create_service_session_cookie(response, session_info.session_id, user_agent)
        
        # 生成并设置CSRF token
        from app.csrf import CSRFProtection
        csrf_token = CSRFProtection.generate_csrf_token()
        CSRFProtection.set_csrf_cookie(response, csrf_token, user_agent)
        
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

@router.post("/service/logout")
def service_logout(
    request: Request,
    response: Response,
    current_service: models.CustomerService = Depends(get_current_service)
):
    """客服登出（独立认证系统）"""
    logger.info(f"[SERVICE_AUTH] 客服登出: {current_service.id}")
    
    # 获取会话ID
    service_session_id = request.cookies.get("service_session_id")
    if service_session_id:
        # 删除会话
        ServiceAuthManager.delete_session(service_session_id)
    
    # 设置客服离线状态
    current_service.is_online = 0  # type: ignore
    db.commit()
    
    # 清除Cookie
    response = clear_service_session_cookie(response)
    
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
        SecureAuthManager.delete_session(session_id)
    
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
