import json
import logging
import os
import uuid
from pathlib import Path
from urllib.parse import quote

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Body,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    Request,
    Response,
    UploadFile,
    status,
)
from fastapi.responses import JSONResponse, RedirectResponse
from fastapi.security import OAuth2PasswordRequestForm, HTTPAuthorizationCredentials
from typing import Optional
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession

from app import crud, models, schemas
from app.database import get_async_db
from app.rate_limiting import rate_limit
from app.deps import get_current_user_secure_sync_csrf
from app.performance_monitor import measure_api_performance
from app.cache import cache_response

logger = logging.getLogger(__name__)
import os
from datetime import datetime, timedelta, timezone
from app.utils.time_utils import get_utc_time, format_iso_utc

import stripe
from pydantic import BaseModel
from sqlalchemy import or_

from app.security import verify_password
from app.security import create_access_token
from app.deps import (
    check_admin_user_status,
    check_user_status,
    get_current_admin_user,
    get_current_customer_service_or_user,
    get_current_user_secure_sync_csrf,
    get_current_user_optional,
    get_db,
    get_sync_db,
)
from app.separate_auth_deps import (
    get_current_admin,
    get_current_service,
    get_current_admin_or_service,
    get_current_user,
    get_current_admin_optional,
    get_current_service_optional,
    get_current_user_optional as get_current_user_optional_new,
)
from app.security import sync_cookie_bearer
from app.email_utils import (
    confirm_reset_token,
    confirm_token,
    generate_confirmation_token,
    generate_reset_token,
    send_confirmation_email,
    send_reset_email,
    send_task_update_email,
)
from app.models import CustomerService, User

stripe.api_key = os.getenv("STRIPE_SECRET_KEY", "sk_test_placeholder_replace_with_real_key")

router = APIRouter()


@router.post("/csp-report")
async def csp_report(report: dict):
    """接收 CSP 违规报告"""
    logger.warning(f"CSP violation: {report}")
    # 可以发送到监控系统
    return {"status": "ok"}


def admin_required(current_user=Depends(get_current_admin_user)):
    return current_user


@router.post("/register/test")
def register_test(user: schemas.UserCreate):
    """测试注册数据格式"""
    return {
        "message": "数据格式正确",
        "data": user.dict(),
        "validation": "passed"
    }

@router.post("/password/validate")
def validate_password_strength(
    password_data: schemas.PasswordValidationRequest,
    current_user: Optional[models.User] = Depends(get_current_user_optional)
):
    """验证密码强度"""
    from app.password_validator import password_validator
    
    # 获取用户信息用于验证
    username = str(current_user.name) if current_user else password_data.username
    email = str(current_user.email) if current_user else password_data.email
    
    validation_result = password_validator.validate_password(
        password_data.password,
        username=username,
        email=email
    )
    
    return {
        "is_valid": validation_result.is_valid,
        "score": validation_result.score,
        "strength": validation_result.strength,
        "bars": validation_result.bars,  # 密码强度横线数：1=弱，2=中，3=强
        "errors": validation_result.errors,
        "suggestions": validation_result.suggestions,
        "missing_requirements": getattr(validation_result, 'missing_requirements', []),  # 缺少的要求（带例子）
        "requirements": password_validator.get_password_requirements()
    }

@router.post("/register/debug")
def register_debug(request_data: dict):
    """调试注册数据 - 接受原始JSON"""
    return {
        "message": "收到原始数据",
        "data": request_data,
        "keys": list(request_data.keys()),
        "types": {k: type(v).__name__ for k, v in request_data.items()}
    }

@router.post("/register")
async def register(
    user: schemas.UserCreate,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_async_db),
):
    """用户注册 - 根据配置决定是否需要邮箱验证"""
    from app.validators import UserValidator, validate_input
    from app.email_verification import EmailVerificationManager, send_verification_email_with_token
    from app.config import Config
    from app.security import get_password_hash
    from app.password_validator import password_validator
    from datetime import datetime
    from app.async_crud import async_user_crud
    
    # 使用验证器验证输入数据
    try:
        validated_data = validate_input(user.dict(), UserValidator)
        # 确保邀请码字段被保留（即使验证器可能没有包含它）
        if hasattr(user, 'invitation_code') and user.invitation_code:
            validated_data['invitation_code'] = user.invitation_code
    except HTTPException as e:
        raise e
    
    # 注册接口需要邮箱（手机号登录通过验证码登录接口，不需要注册接口）
    if not validated_data.get('email'):
        raise HTTPException(
            status_code=400,
            detail="注册需要提供邮箱地址"
        )
    
    # 调试信息
    # 注册请求处理中（已移除敏感信息日志）
    
    # 检查邮箱是否已被注册（正式用户）
    db_user = await async_user_crud.get_user_by_email(db, validated_data['email'])
    if db_user:
        raise HTTPException(
            status_code=400, 
            detail="该邮箱已被注册，请使用其他邮箱或直接登录"
        )
    
    # 检查用户名是否已被注册（正式用户）
    db_name = await async_user_crud.get_user_by_name(db, validated_data['name'])
    if db_name:
        raise HTTPException(
            status_code=400, 
            detail="该用户名已被使用，请选择其他用户名"
        )

    # 检查用户名是否包含客服相关关键词，防止用户注册客服账号
    customer_service_keywords = ["客服", "customer", "service", "support", "help"]
    name_lower = validated_data['name'].lower()
    if any(keyword.lower() in name_lower for keyword in customer_service_keywords):
        raise HTTPException(
            status_code=400, 
            detail="用户名不能包含客服相关关键词"
        )
    
    # 检查用户是否同意条款（防止绕过前端验证）
    agreed_to_terms = validated_data.get('agreed_to_terms', False)
    if not agreed_to_terms:
        raise HTTPException(
            status_code=400,
            detail="您必须同意用户协议和隐私政策才能注册"
        )
    
    # 验证密码强度
    password_validation = password_validator.validate_password(
        validated_data['password'], 
        username=validated_data['name'],
        email=validated_data['email']
    )
    
    if not password_validation.is_valid:
        error_message = "密码不符合安全要求：\n" + "\n".join(password_validation.errors)
        if password_validation.suggestions:
            error_message += "\n\n建议：\n" + "\n".join(password_validation.suggestions)
        raise HTTPException(
            status_code=400,
            detail=error_message
        )

    # 处理邀请码或用户ID（如果提供）
    invitation_code_id = None
    inviter_id = None
    invitation_code_text = None
    if validated_data.get('invitation_code'):
        from app.coupon_points_crud import process_invitation_input
        from app.database import SessionLocal
        
        # 使用同步数据库处理邀请码或用户ID
        sync_db = SessionLocal()
        try:
            inviter_id, invitation_code_id, invitation_code_text, error_msg = process_invitation_input(
                sync_db, validated_data['invitation_code']
            )
            if inviter_id:
                print(f"邀请人ID验证成功: {inviter_id}")
            elif invitation_code_id:
                print(f"邀请码验证成功: {invitation_code_text}, ID: {invitation_code_id}")
            elif error_msg:
                print(f"邀请码/用户ID验证失败: {error_msg}")
                # 邀请码/用户ID无效不影响注册，只记录警告
        finally:
            sync_db.close()
    
    # 检查是否跳过邮件验证（开发环境）
    if Config.SKIP_EMAIL_VERIFICATION:
        print("开发环境：跳过邮件验证，直接创建用户")
        
        # 使用异步CRUD创建用户
        user_data = schemas.UserCreate(**validated_data)
        new_user = await async_user_crud.create_user(db, user_data)
        
        # 更新用户状态为已验证和激活，并设置邀请信息
        from sqlalchemy import update
        await db.execute(
            update(User)
            .where(User.id == new_user.id)
            .values(
                is_verified=1,
                is_active=1,
                user_level="normal",
                inviter_id=inviter_id,
                invitation_code_id=invitation_code_id,
                invitation_code_text=invitation_code_text
            )
        )
        await db.commit()
        await db.refresh(new_user)
        
        # 处理邀请码奖励（开发环境：用户创建成功后立即发放）
        if invitation_code_id:
            from app.coupon_points_crud import use_invitation_code
            from app.database import SessionLocal
            sync_db = SessionLocal()
            try:
                success, error_msg = use_invitation_code(sync_db, new_user.id, invitation_code_id)
                if success:
                    print(f"邀请码奖励发放成功: 用户 {new_user.id}, 邀请码ID {invitation_code_id}")
                else:
                    print(f"邀请码奖励发放失败: {error_msg}")
            finally:
                sync_db.close()
        
        # 开发环境：用户注册成功，无需邮箱验证
        
        return {
            "message": "注册成功！（开发环境：已跳过邮箱验证）",
            "email": validated_data['email'],
            "verification_required": False,
            "user_id": new_user.id
        }
    else:
        # 生产环境：需要邮箱验证
        print("生产环境：需要邮箱验证")
        
        # 生成验证令牌
        verification_token = EmailVerificationManager.generate_verification_token(validated_data['email'])
        
        # 创建待验证用户（这里需要同步操作，因为EmailVerificationManager使用同步数据库）
        user_data = schemas.UserCreate(**validated_data)
        
        # 临时使用同步数据库操作创建待验证用户
        from app.database import SessionLocal
        sync_db = SessionLocal()
        try:
            pending_user = EmailVerificationManager.create_pending_user(sync_db, user_data, verification_token)
        finally:
            sync_db.close()
        
        # 发送验证邮件（新用户注册，默认使用英文，因为还没有用户记录）
        send_verification_email_with_token(background_tasks, validated_data['email'], verification_token, language='en')
        
        return {
            "message": "注册成功！请检查您的邮箱并点击验证链接完成注册。",
            "email": validated_data['email'],
            "verification_required": True
        }


@router.get("/verify-email")
@router.get("/verify-email/{token}")
def verify_email(
    request: Request,
    response: Response,
    token: Optional[str] = None,
    db: Session = Depends(get_db),
):
    """验证用户邮箱 - 支持路径参数和查询参数，验证成功后自动登录并重定向到前端页面"""
    from app.email_verification import EmailVerificationManager
    from app.config import Config
    from fastapi.responses import RedirectResponse
    
    # 从路径参数或查询参数获取token
    if not token:
        token = request.query_params.get('token')
    
    frontend_url = Config.FRONTEND_URL
    
    if not token:
        # 如果没有token，重定向到错误页面
        return RedirectResponse(
            url=f"{frontend_url}/verify-email?error={quote('缺少验证令牌')}",
            status_code=302
        )
    
    # 验证用户 - 这是关键步骤，如果成功则必须重定向到成功页面
    user = None
    try:
        user = EmailVerificationManager.verify_user(db, token)
    except Exception as verify_error:
        logger.error(f"验证用户时发生异常: {verify_error}")
        import traceback
        logger.error(f"详细错误: {traceback.format_exc()}")
        # 验证过程出错，重定向到错误页面
        error_msg = str(verify_error) if len(str(verify_error)) < 100 else "验证失败"
        return RedirectResponse(
            url=f"{frontend_url}/verify-email?error={quote(error_msg)}",
            status_code=302
        )
    
    if not user:
        # 验证失败，token无效或已使用，重定向到首页
        logger.warning(f"验证失败，令牌无效或已过期，重定向到首页: {token}")
        return RedirectResponse(
            url=frontend_url,
            status_code=302
        )
    
    # 用户验证成功，记录日志
    logger.info(f"用户验证成功: ID: {user.id}")
    
    # 处理邀请码奖励（如果注册时提供了邀请码）
    # 注意：由于PendingUser没有invitation_code_id字段，我们需要通过其他方式获取
    # 临时方案：在注册时验证邀请码，将邀请码文本存储到User的某个字段
    # 更好的方案：在PendingUser中添加invitation_code_id字段，或使用Redis临时存储
    # 当前实现：在注册API中已经验证了邀请码，但验证成功后无法获取
    # 解决方案：在注册时，如果邀请码有效，将邀请码文本存储到User的某个字段（如invitation_code_text）
    # 或者：在注册API中，将邀请码ID存储到Redis，key为email，在验证成功后从Redis获取
    
    # 尝试从Redis获取邀请码ID（如果注册时存储了）
    try:
        from app.redis_cache import redis_client
        if redis_client:
            invitation_code_key = f"registration_invitation_code:{user.email}"
            invitation_code_id_str = redis_client.get(invitation_code_key)
            if invitation_code_id_str:
                invitation_code_id = int(invitation_code_id_str.decode())
                from app.coupon_points_crud import use_invitation_code
                success, error_msg = use_invitation_code(db, user.id, invitation_code_id)
                if success:
                    logger.info(f"邀请码奖励发放成功: 用户 {user.id}, 邀请码ID {invitation_code_id}")
                    # 删除Redis中的临时数据
                    redis_client.delete(invitation_code_key)
                else:
                    logger.warning(f"邀请码奖励发放失败: {error_msg}")
    except Exception as e:
        logger.error(f"处理邀请码奖励时出错: {e}", exc_info=True)
    
    # 验证成功，尝试自动登录用户（可选，失败不影响验证成功）
    try:
        from app.secure_auth import SecureAuthManager, get_client_ip, get_device_fingerprint
        from app.cookie_manager import CookieManager
        
        # 获取设备信息
        device_fingerprint = get_device_fingerprint(request)
        client_ip = get_client_ip(request)
        user_agent = request.headers.get("user-agent", "")
        
        # 生成刷新令牌
        from app.secure_auth import create_user_refresh_token
        refresh_token = create_user_refresh_token(user.id, client_ip, device_fingerprint)
        
        # 创建会话
        session = SecureAuthManager.create_session(
            user_id=user.id,
            device_fingerprint=device_fingerprint,
            ip_address=client_ip,
            user_agent=user_agent,
            refresh_token=refresh_token
        )
        
        # 设置安全Cookie
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
        
        # 检测是否为移动端
        is_mobile = any(keyword in user_agent.lower() for keyword in [
            'mobile', 'iphone', 'ipad', 'android', 'blackberry', 
            'windows phone', 'opera mini', 'iemobile'
        ])
        
        # 为移动端添加特殊的响应头
        if is_mobile:
            response.headers["X-Session-ID"] = session.session_id
            response.headers["X-User-ID"] = str(user.id)
            response.headers["X-Auth-Status"] = "authenticated"
            response.headers["X-Mobile-Auth"] = "true"
        
        logger.info(f"邮箱验证成功后自动登录成功: ID: {user.id}")
        
    except Exception as auth_error:
        logger.warning(f"自动登录失败（不影响验证成功）: {auth_error}")
        import traceback
        logger.debug(f"自动登录详细错误: {traceback.format_exc()}")
        # 即使自动登录失败，验证仍然成功，继续重定向到成功页面
    
    # 验证成功，必须重定向到前端成功页面
    # 无论自动登录是否成功，只要用户验证成功，就显示成功页面
    try:
        success_url = f"{frontend_url}/verify-email?success=true"
        logger.info(f"重定向到验证成功页面: {success_url}")
        
        redirect_response = RedirectResponse(
            url=success_url,
            status_code=302
        )
        
        # 将已设置的Cookie复制到重定向响应（Set-Cookie头）
        # FastAPI的response对象会自动处理Cookie，但需要手动复制
        if 'set-cookie' in response.headers:
            cookies = response.headers.getlist('set-cookie')
            for cookie in cookies:
                redirect_response.headers.append('set-cookie', cookie)
        
        # 复制其他自定义响应头
        for header_name in ['x-session-id', 'x-user-id', 'x-auth-status', 'x-mobile-auth']:
            if header_name in response.headers:
                redirect_response.headers[header_name] = response.headers[header_name]
        
        return redirect_response
        
    except Exception as redirect_error:
        logger.error(f"创建重定向响应时发生错误: {redirect_error}")
        import traceback
        logger.error(f"详细错误: {traceback.format_exc()}")
        # 即使重定向创建失败，也要尝试返回一个基本的重定向响应
        return RedirectResponse(
            url=f"{frontend_url}/verify-email?success=true",
            status_code=302
        )


@router.post("/resend-verification")
def resend_verification_email(
    email: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    """重新发送验证邮件"""
    from app.email_verification import EmailVerificationManager
    
    # 检查邮箱格式
    from app.validators import StringValidator
    try:
        validated_email = StringValidator.validate_email(email)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    
    # 重新发送验证邮件
    success = EmailVerificationManager.resend_verification_email(db, validated_email, background_tasks)
    
    if not success:
        raise HTTPException(
            status_code=400, 
            detail="未找到待验证的用户，请先注册。"
        )
    
    return {
        "message": "验证邮件已重新发送，请检查您的邮箱。"
    }


# 旧的JWT登录路由已删除，请使用 /api/secure-auth/login
# 旧的客服登录路由已删除，请使用 /api/customer-service/login (在 cs_auth_routes.py 中)


@router.post("/admin/login")
def admin_login(
    request: Request,
    response: Response,
    login_data: schemas.AdminUserLogin, 
    db: Session = Depends(get_db)
):
    """后台管理员登录端点，使用Cookie会话认证"""
    admin = crud.authenticate_admin_user(db, login_data.username, login_data.password)
    if not admin:
        raise HTTPException(status_code=400, detail="Incorrect username or password")

    # 更新最后登录时间
    crud.update_admin_last_login(db, admin.id)

    # 使用新的管理员会话认证系统
    from app.admin_auth import create_admin_session, create_admin_session_cookie
    
    # 创建管理员会话
    session_id = create_admin_session(admin.id, request)
    if not session_id:
        raise HTTPException(status_code=500, detail="Failed to create admin session")
    
    # 设置管理员会话Cookie
    response = create_admin_session_cookie(response, session_id)

    return {
        "message": "管理员登录成功",
        "admin": {
            "id": admin.id,
            "name": admin.name,
            "username": admin.username,
            "email": admin.email,
            "is_super_admin": admin.is_super_admin,
            "user_type": "admin",
        },
    }


@router.get("/user/info")
def get_user_info(
    current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    """获取当前用户信息"""
    return {
        "id": current_user.id,  # 数据库已经存储格式化ID
        "name": current_user.name,
        "email": current_user.email,
        "avatar": getattr(current_user, 'avatar', ''),
        "user_type": "normal_user",
    }


# 调试端点已移除 - 安全考虑

@router.get("/debug/test-token/{token}")
def debug_test_token(token: str):
    """调试token解析"""
    from app.email_utils import confirm_token
    from app.config import Config
    from itsdangerous import URLSafeTimedSerializer
    
    result = {
        "token": token[:20] + "...",
        "current_secret_key": Config.SECRET_KEY[:20] + "...",
        "secret_key_length": len(Config.SECRET_KEY),
        "is_default_secret": Config.SECRET_KEY == "change-this-secret-key-in-production"
    }
    
    # 测试当前配置
    try:
        email = confirm_token(token)
        result["current_config_result"] = email
    except Exception as e:
        result["current_config_error"] = str(e)
    
    # 测试手动解析
    try:
        serializer = URLSafeTimedSerializer(Config.SECRET_KEY)
        email = serializer.loads(token, salt="email-confirm", max_age=3600*24)
        result["manual_parse_result"] = email
    except Exception as e:
        result["manual_parse_error"] = str(e)
    
    return result

@router.get("/debug/simple-test")
def debug_simple_test():
    """最简单的测试端点"""
    return {"message": "Simple test works", "status": "ok"}

@router.post("/debug/fix-avatar-null")
def fix_avatar_null(db: Session = Depends(get_db)):
    """修复数据库中avatar字段为NULL的用户"""
    try:
        # 查找所有avatar为NULL的用户
        users_with_null_avatar = db.query(models.User).filter(models.User.avatar.is_(None)).all()
        
        # 为这些用户设置默认头像
        for user in users_with_null_avatar:
            user.avatar = "/static/avatar1.png"
        
        db.commit()
        
        return {
            "message": f"已修复 {len(users_with_null_avatar)} 个用户的头像字段",
            "fixed_count": len(users_with_null_avatar)
        }
    except Exception as e:
        logger.error(f"修复头像字段失败: {e}")
        return {"error": str(e)}

@router.get("/debug/check-user-avatar/{user_id}")
def check_user_avatar(user_id: str, db: Session = Depends(get_db)):
    """检查指定用户的头像数据"""
    try:
        # 直接从数据库查询
        user = db.query(models.User).filter(models.User.id == user_id).first()
        if user:
            return {
                "user_id": user_id,
                "avatar_from_db": user.avatar,
                "user_found": True
            }
        else:
            return {
                "user_id": user_id,
                "user_found": False
            }
    except Exception as e:
        logger.error(f"检查用户头像失败: {e}")
        return {"error": str(e)}

@router.get("/debug/test-reviews/{user_id}")
def debug_test_reviews(user_id: str):
    """测试reviews端点是否工作"""
    return {"message": f"Reviews endpoint works for user {user_id}", "status": "ok"}

@router.get("/debug/session-status")
def debug_session_status(request: Request, db: Session = Depends(get_db)):
    """调试会话状态"""
    from app.secure_auth import validate_session, SecureAuthManager
    
    result = {
        "url": str(request.url),
        "cookies": dict(request.cookies),
        "headers": dict(request.headers),
        "session_validation": None,
        "user_agent": request.headers.get("user-agent", ""),
    }
    
    # 获取session_id
    session_id = (
        request.cookies.get("session_id") or
        request.headers.get("X-Session-ID")
    )
    
    if session_id:
        result["session_id"] = session_id[:8] + "..."
        # 直接检查会话是否存在
        session = SecureAuthManager.get_session(session_id, update_activity=False)
        if session:
            result["session_validation"] = {
                "success": True,
                "user_id": session.user_id,
                "session_id": session.session_id[:8] + "...",
                "is_active": session.is_active,
                "last_activity": format_iso_utc(session.last_activity) if session.last_activity else None
            }
        else:
            result["session_validation"] = {"success": False, "reason": "Session not found in storage"}
    else:
        result["session_validation"] = {"success": False, "reason": "No session_id provided"}
    
    return result

@router.get("/debug/check-pending/{email}")
def debug_check_pending(email: str, db: Session = Depends(get_db)):
    """检查PendingUser表中的用户"""
    from app.models import PendingUser
    from datetime import datetime
    
    result = {
        "email": email,
        "current_time": format_iso_utc(get_utc_time())
    }
    
    try:
        # 查找PendingUser
        pending_user = db.query(PendingUser).filter(PendingUser.email == email).first()
        if pending_user:
            result["pending_user_found"] = True
            result["pending_user_data"] = {
                "id": pending_user.id,
                "name": pending_user.name,
                "email": pending_user.email,
                "created_at": format_iso_utc(pending_user.created_at),
                "expires_at": format_iso_utc(pending_user.expires_at),
                "is_expired": pending_user.expires_at < get_utc_time()
            }
        else:
            result["pending_user_found"] = False
            
        # 查找User表
        from app import crud
        user = crud.get_user_by_email(db, email)
        if user:
            result["user_found"] = True
            result["user_data"] = {
                "id": user.id,
                "name": user.name,
                "email": user.email,
                "is_verified": user.is_verified
            }
        else:
            result["user_found"] = False
            
    except Exception as e:
        result["error"] = str(e)
        import traceback
        result["traceback"] = traceback.format_exc()
    
    return result

@router.get("/debug/test-confirm-simple")
def debug_test_confirm_simple():
    """简单的确认测试端点"""
    return {
        "message": "confirm endpoint is working",
        "status": "ok"
    }

@router.get("/confirm/{token}")
def confirm_email(token: str, db: Session = Depends(get_db)):
    """邮箱验证端点（兼容旧链接，重定向到新端点）"""
    # 重定向到新的verify-email端点，会自动重定向到前端页面
    from fastapi.responses import RedirectResponse
    from app.config import Config
    
    return RedirectResponse(
        url=f"{Config.BASE_URL}/api/users/verify-email/{token}",
        status_code=302
    )


@router.post("/forgot_password")
def forgot_password(
    email: str = Form(...),
    background_tasks: BackgroundTasks = None,
    db: Session = Depends(get_db),
):
    """忘记密码 - 发送重置链接到邮箱"""
    # 验证邮箱格式和长度
    from app.validators import StringValidator
    try:
        validated_email = StringValidator.validate_email(email)
    except ValueError as e:
        raise HTTPException(
            status_code=400,
            detail=str(e)
        )
    
    user = crud.get_user_by_email(db, validated_email)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # 生成token
    token = generate_reset_token(validated_email)
    
    # 将token存储到Redis，设置2小时过期（7200秒），key格式：password_reset_token:{token}
    from app.redis_cache import get_redis_client
    redis_client = get_redis_client()
    
    if redis_client:
        try:
            # 存储token到Redis，值为邮箱，过期时间2小时
            redis_client.setex(
                f"password_reset_token:{token}",
                7200,  # 2小时 = 7200秒
                validated_email
            )
        except Exception as e:
            logger.error(f"存储重置密码token到Redis失败: {e}")
            # Redis失败时，不发送邮件，避免用户收到无法使用的链接
            raise HTTPException(
                status_code=503,
                detail="Service temporarily unavailable. Please try again later."
            )
    else:
        logger.error("Redis不可用，无法存储重置密码token")
        # Redis不可用时，不发送邮件
        raise HTTPException(
            status_code=503,
            detail="Service temporarily unavailable. Please try again later."
        )
    
    # 尝试获取用户语言偏好
    from app.email_templates import get_user_language
    language = get_user_language(user) if user else 'en'
    
    send_reset_email(background_tasks, validated_email, token, language)
    return {"message": "Password reset email sent."}


@router.post("/reset_password/{token}")
def reset_password(
    token: str, new_password: str = Form(...), db: Session = Depends(get_db)
):
    """重置密码 - 使用一次性token"""
    # 首先验证token格式和过期时间
    email = confirm_reset_token(token)
    if not email:
        raise HTTPException(status_code=400, detail="Invalid or expired token")
    
    # 从Redis获取并删除token（原子操作，确保一次性使用）
    from app.redis_cache import get_redis_client
    redis_client = get_redis_client()
    
    if not redis_client:
        raise HTTPException(status_code=503, detail="Service temporarily unavailable. Please try again later.")
    
    token_key = f"password_reset_token:{token}"
    
    # 使用GETDEL原子操作（Redis 6.2+），如果Redis版本不支持则使用Lua脚本
    try:
        # 尝试使用GETDEL（原子操作：获取并删除）
        stored_email = redis_client.getdel(token_key)
    except AttributeError:
        # Redis版本不支持GETDEL，使用Lua脚本实现原子操作
        lua_script = """
        local value = redis.call('GET', KEYS[1])
        if value then
            redis.call('DEL', KEYS[1])
        end
        return value
        """
        stored_email = redis_client.eval(lua_script, 1, token_key)
    except Exception as e:
        logger.error(f"从Redis获取token失败: {e}")
        raise HTTPException(status_code=500, detail="Token verification failed")
    
    # 检查token是否存在（如果不存在说明已被使用或过期）
    if not stored_email:
        raise HTTPException(status_code=400, detail="Invalid, expired, or already used token")
    
    # 验证存储的邮箱与token中的邮箱是否匹配
    stored_email_str = stored_email.decode('utf-8') if isinstance(stored_email, bytes) else stored_email
    if stored_email_str != email:
        raise HTTPException(status_code=400, detail="Token email mismatch")
    
    # 查找用户
    user = crud.get_user_by_email(db, email)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # 验证密码强度（与注册时相同）
    from app.password_validator import PasswordValidator
    password_validator = PasswordValidator()
    password_validation = password_validator.validate_password(
        new_password,
        username=user.name,
        email=user.email
    )
    
    if not password_validation.is_valid:
        error_message = "密码不符合安全要求：\n" + "\n".join(password_validation.errors)
        if password_validation.suggestions:
            error_message += "\n\n建议：\n" + "\n".join(password_validation.suggestions)
        raise HTTPException(
            status_code=400,
            detail=error_message
        )
    
    # token有效且未被使用，重置密码
    from app.security import get_password_hash
    user.hashed_password = get_password_hash(new_password)
    db.commit()
    
    # token已在Redis中删除（通过GETDEL或Lua脚本），确保一次性使用
    return {"message": "Password reset successful."}


# 同步发布任务路由已禁用，使用异步版本
# @router.post("/tasks", response_model=schemas.TaskOut)
# @rate_limit("create_task")
# def create_task(
#     task: schemas.TaskCreate,
#     current_user=Depends(get_current_user_secure_sync_csrf),
#     db: Session = Depends(get_db),
# ):
#     # 检查用户是否为客服账号
#     if False:  # 普通用户不再有客服权限
#         raise HTTPException(status_code=403, detail="客服账号不能发布任务")
#
#     try:
#         db_task = crud.create_task(db, current_user.id, task)
#         # 手动序列化Task对象，避免关系字段问题
#         return {
#             "id": db_task.id,
#             "title": db_task.title,
#             "description": db_task.description,
#             "deadline": db_task.deadline,
#             "reward": db_task.reward,
#             "location": db_task.location,
#             "task_type": db_task.task_type,
#             "poster_id": db_task.poster_id,
#             "taker_id": db_task.taker_id,
#             "status": db_task.status,
#             "task_level": db_task.task_level,
#             "created_at": db_task.created_at,
#             "is_public": db_task.is_public
#         }
#     except Exception as e:
#         print(f"Error creating task: {e}")
#         raise HTTPException(status_code=500, detail=f"创建任务失败: {str(e)}")


@router.patch("/profile/timezone")
def update_timezone(
    timezone: str = Body(...),
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """更新用户时区"""
    from app.models import User

    user = db.query(User).filter(User.id == current_user.id).first()
    if user:
        user.timezone = timezone
        db.commit()
        return {"message": "Timezone updated successfully"}
    raise HTTPException(status_code=404, detail="User not found")


# 同步任务列表路由已禁用，使用异步版本
# @router.get("/tasks")
# def list_tasks(
#     page: int = 1,
#     page_size: int = 20,
#     task_type: str = None,
#     location: str = None,
#     keyword: str = None,
#     sort_by: str = "latest",
#     db: Session = Depends(get_db),
# ):
#     skip = (page - 1) * page_size
#     tasks = crud.list_tasks(db, skip, page_size, task_type, location, keyword, sort_by)
#     total = crud.count_tasks(db, task_type, location, keyword)
#
#     return {"tasks": tasks, "total": total, "page": page, "page_size": page_size}


@router.get("/tasks/{task_id}", response_model=schemas.TaskOut)
def get_task_detail(task_id: int, db: Session = Depends(get_db)):
    """获取任务详情 - 使用服务层缓存（避免装饰器重复创建）"""
    from app.services.task_service import TaskService
    return TaskService.get_task_cached(task_id=task_id, db=db)


@router.post("/tasks/{task_id}/accept", response_model=schemas.TaskOut)
def accept_task(
    task_id: int,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    # 接收任务处理中（已移除DEBUG日志以提升性能）
    
    # 如果current_user为None，说明认证失败
    if not current_user:
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    try:

        # 检查用户是否为客服账号
        if False:  # 普通用户不再有客服权限
            raise HTTPException(status_code=403, detail="客服账号不能接受任务")

        db_task = crud.get_task(db, task_id)
        if not db_task:
            raise HTTPException(status_code=404, detail="Task not found")


        if db_task.status != "open":
            raise HTTPException(
                status_code=400, detail="Task is not available for acceptance"
            )

        if db_task.poster_id == current_user.id:
            raise HTTPException(
                status_code=400, detail="You cannot accept your own task"
            )

        # 检查用户等级是否满足任务等级要求
        user_level = current_user.user_level
        task_level = db_task.task_level

        # 权限检查：用户等级必须大于等于任务等级
        # expert 等级是达人任务，通常已有指定接收者，不参与等级检查
        level_hierarchy = {"normal": 1, "vip": 2, "super": 3, "expert": 0}
        user_level_value = level_hierarchy.get(user_level, 1)
        task_level_value = level_hierarchy.get(task_level, 1)

        # expert 任务跳过等级检查（因为已有指定接收者）
        if task_level == "expert":
            pass  # expert 任务不检查用户等级
        elif user_level_value < task_level_value:
            if task_level == "vip":
                raise HTTPException(
                    status_code=403,
                    detail="此任务需要VIP用户才能接受，请升级您的账户等级",
                )
            elif task_level == "super":
                raise HTTPException(
                    status_code=403,
                    detail="此任务需要超级VIP用户才能接受，请升级您的账户等级",
                )
            else:
                raise HTTPException(
                    status_code=403, detail="您的账户等级不足以接受此任务"
                )

        # 检查任务是否已过期
        from datetime import datetime, timezone
        from app.utils.time_utils import get_utc_time, LONDON, to_user_timezone

        current_time = get_utc_time()

        # 如果deadline是naive datetime，假设它是UTC时间（数据库迁移后应该都是带时区的）
        if db_task.deadline.tzinfo is None:
            # 旧数据兼容：假设是UTC时间
            deadline_utc = db_task.deadline.replace(tzinfo=timezone.utc)
        else:
            deadline_utc = db_task.deadline.astimezone(timezone.utc)

        if deadline_utc < current_time:
            raise HTTPException(status_code=400, detail="Task deadline has passed")

        updated_task = crud.accept_task(db, task_id, current_user.id)
        if not updated_task:
            raise HTTPException(status_code=400, detail="Failed to accept task")


        # 发送通知给任务发布者
        if background_tasks:
            try:
                crud.create_notification(
                    db,
                    db_task.poster_id,
                    "task_accepted",
                    "任务已被接受",
                    f"用户 {current_user.name} 接受了您的任务 '{db_task.title}'",
                    current_user.id,
                )
            except Exception as e:
                print(f"Failed to create notification: {e}")
                # 不要因为通知失败而影响任务接受

        return updated_task
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.post("/tasks/{task_id}/approve", response_model=schemas.TaskOut)
def approve_task_taker(
    task_id: int,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """任务发布者同意接受者进行任务"""
    db_task = crud.get_task(db, task_id)
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 检查权限：只有任务发布者可以同意
    if db_task.poster_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only task poster can approve the taker"
        )

    # 检查任务状态：必须是taken状态
    if db_task.status != "taken":
        raise HTTPException(status_code=400, detail="Task is not in taken status")

    # 更新任务状态为进行中
    db_task.status = "in_progress"
    db.commit()
    db.refresh(db_task)

    # 创建通知给任务接受者
    if background_tasks and db_task.taker_id:
        try:
            crud.create_notification(
                db,
                db_task.taker_id,
                "task_approved",
                "任务已批准",
                f"您的任务申请 '{db_task.title}' 已被发布者批准，可以开始工作了",
                current_user.id,
            )
        except Exception as e:
            print(f"Failed to create notification: {e}")

    return db_task


@router.post("/tasks/{task_id}/reject", response_model=schemas.TaskOut)
def reject_task_taker(
    task_id: int,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """任务发布者拒绝接受者，任务重新变为open状态"""
    db_task = crud.get_task(db, task_id)
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 检查权限：只有任务发布者可以拒绝
    if db_task.poster_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only task poster can reject the taker"
        )

    # 检查任务状态：必须是taken状态
    if db_task.status != "taken":
        raise HTTPException(status_code=400, detail="Task is not in taken status")

    # 记录被拒绝的接受者ID
    rejected_taker_id = db_task.taker_id

    # 重置任务状态为open，清除接受者
    db_task.status = "open"
    db_task.taker_id = None
    db.commit()
    db.refresh(db_task)

    # 创建通知给被拒绝的接受者
    if background_tasks and rejected_taker_id:
        try:
            crud.create_notification(
                db,
                rejected_taker_id,
                "task_rejected",
                "任务申请被拒绝",
                f"您的任务申请 '{db_task.title}' 已被发布者拒绝，任务已重新开放",
                current_user.id,
            )
        except Exception as e:
            print(f"Failed to create notification: {e}")

    return db_task


@router.patch("/tasks/{task_id}/reward", response_model=schemas.TaskOut)
def update_task_reward(
    task_id: int,
    task_update: schemas.TaskUpdate,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """更新任务价格（仅任务发布者可见）"""
    task = crud.update_task_reward(db, task_id, current_user.id, task_update.reward)
    if not task:
        raise HTTPException(
            status_code=400,
            detail="Task not found or you don't have permission to update it",
        )
    return task


@router.patch("/tasks/{task_id}/visibility", response_model=schemas.TaskOut)
def update_task_visibility(
    task_id: int,
    visibility_update: dict = Body(...),
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """更新任务可见性（仅任务发布者可见）"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    if task.poster_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Not authorized to update this task"
        )

    is_public = visibility_update.get("is_public")
    if is_public not in [0, 1]:
        raise HTTPException(status_code=400, detail="is_public must be 0 or 1")

    task.is_public = is_public
    db.commit()
    db.refresh(task)
    return task


@router.post("/tasks/{task_id}/review", response_model=schemas.ReviewOut)
def create_review(
    task_id: int,
    review: schemas.ReviewCreate = Body(...),
    background_tasks: BackgroundTasks = None,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    # 检查用户是否为客服账号
    if False:  # 普通用户不再有客服权限
        raise HTTPException(status_code=403, detail="客服账号不能创建评价")

    db_review = crud.create_review(db, current_user.id, task_id, review)
    if not db_review:
        raise HTTPException(
            status_code=400,
            detail="Cannot create review. Task may not be completed, you may not be a participant, or you may have already reviewed this task.",
        )
    
    # P2 优化：异步处理非关键操作（发送通知等）
    if background_tasks:
        def send_review_notification():
            """后台发送评价通知（非关键操作）"""
            try:
                # 获取任务信息
                task = crud.get_task(db, task_id)
                if task and task.poster_id != current_user.id:
                    # 通知任务发布者
                    crud.create_notification(
                        db,
                        task.poster_id,
                        "review_created",
                        "收到新评价",
                        f"任务 '{task.title}' 收到了新评价",
                        current_user.id,
                    )
            except Exception as e:
                logger.warning(f"发送评价通知失败: {e}")
        
        background_tasks.add_task(send_review_notification)
    
    return db_review


@router.get("/tasks/{task_id}/reviews", response_model=list[schemas.ReviewOut])
@measure_api_performance("get_task_reviews")
@cache_response(ttl=180, key_prefix="task_reviews")  # 缓存3分钟
def get_task_reviews(task_id: int, db: Session = Depends(get_db)):
    return crud.get_task_reviews(db, task_id)


@router.get("/users/{user_id}/received-reviews", response_model=list[schemas.ReviewOut])
@measure_api_performance("get_user_received_reviews")
@cache_response(ttl=300, key_prefix="user_reviews")  # 缓存5分钟
def get_user_received_reviews(user_id: str, db: Session = Depends(get_db)):
    """获取用户收到的所有评价（包括匿名评价），用于个人主页显示"""
    return crud.get_user_received_reviews(db, user_id)


@router.get("/{user_id}/reviews")
@measure_api_performance("get_user_reviews")
@cache_response(ttl=300, key_prefix="user_reviews_alt")  # 缓存5分钟
def get_user_reviews(user_id: str, db: Session = Depends(get_db)):
    """获取用户收到的评价（用于个人主页显示）"""
    try:
        reviews = crud.get_user_reviews_with_reviewer_info(db, user_id)
        return reviews
    except Exception as e:
        import traceback
        logger.error(f"获取用户评价失败: {e}")
        logger.error(traceback.format_exc())
        return []


@router.post("/tasks/{task_id}/complete", response_model=schemas.TaskOut)
def complete_task(
    task_id: int,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    # 检查用户是否为客服账号
    if False:  # 普通用户不再有客服权限
        raise HTTPException(status_code=403, detail="客服账号不能完成任务")

    db_task = crud.get_task(db, task_id)
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")

    if db_task.status != "in_progress":
        raise HTTPException(status_code=400, detail="Task is not in progress")

    if db_task.taker_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only the task taker can complete the task"
        )

    # 更新任务状态为等待确认
    db_task.status = "pending_confirmation"
    db_task.completed_at = get_utc_time()
    db.commit()
    db.refresh(db_task)

    # 发送系统消息到任务聊天框
    try:
        from app.models import Message
        import json
        
        taker_name = current_user.name or f"用户{current_user.id}"
        system_message = Message(
            sender_id=None,  # 系统消息，sender_id为None
            receiver_id=None,
            content=f"接收者 {taker_name} 已确认完成任务，等待发布者确认。",
            task_id=task_id,
            message_type="system",
            conversation_type="task",
            meta=json.dumps({"system_action": "task_completed_by_taker"}),
            created_at=get_utc_time()
        )
        db.add(system_message)
        db.commit()
    except Exception as e:
        print(f"Failed to send system message: {e}")
        # 系统消息发送失败不影响任务完成流程

    # 发送任务完成通知和邮件给发布者
    if background_tasks:
        try:
            from app.task_notifications import send_task_completion_notification
            
            # 获取发布者信息
            poster = crud.get_user_by_id(db, db_task.poster_id)
            if poster:
                send_task_completion_notification(
                    db=db,
                    background_tasks=background_tasks,
                    task=db_task,
                    taker=current_user
                )
        except Exception as e:
            print(f"Failed to send task completion notification: {e}")

    # 检查任务接受者是否满足VIP晋升条件
    try:
        crud.check_and_upgrade_vip_to_super(db, current_user.id)
    except Exception as e:
        print(f"Failed to check VIP upgrade: {e}")

    return db_task


@router.post("/tasks/{task_id}/confirm_completion", response_model=schemas.TaskOut)
def confirm_task_completion(
    task_id: int,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """任务发布者确认任务完成"""
    task = crud.get_task(db, task_id)
    if not task or task.poster_id != current_user.id:
        raise HTTPException(status_code=404, detail="Task not found or no permission")
    if task.status != "pending_confirmation":
        raise HTTPException(status_code=400, detail="Task is not pending confirmation")

    # 将任务状态改为已完成
    task.status = "completed"
    db.commit()
    crud.add_task_history(db, task_id, current_user.id, "confirmed_completion")
    db.refresh(task)

    # 发送系统消息到任务聊天框
    try:
        from app.models import Message
        import json
        
        poster_name = current_user.name or f"用户{current_user.id}"
        system_message = Message(
            sender_id=None,  # 系统消息，sender_id为None
            receiver_id=None,
            content=f"发布者 {poster_name} 已确认任务完成。",
            task_id=task_id,
            message_type="system",
            conversation_type="task",
            meta=json.dumps({"system_action": "task_confirmed_by_poster"}),
            created_at=get_utc_time()
        )
        db.add(system_message)
        db.commit()
    except Exception as e:
        print(f"Failed to send system message: {e}")
        # 系统消息发送失败不影响任务确认流程

    # 发送任务确认完成通知和邮件给接收者
    if task.taker_id and background_tasks:
        try:
            from app.task_notifications import send_task_confirmation_notification
            
            # 获取接收者信息
            taker = crud.get_user_by_id(db, task.taker_id)
            if taker:
                send_task_confirmation_notification(
                    db=db,
                    background_tasks=background_tasks,
                    task=task,
                    taker=taker
                )
        except Exception as e:
            print(f"Failed to send task confirmation notification: {e}")

    # 自动更新相关用户的统计信息
    crud.update_user_statistics(db, task.poster_id)
    if task.taker_id:
        crud.update_user_statistics(db, task.taker_id)
    
    # 任务完成时自动发放积分奖励（平台赠送，非任务报酬）
    if task.taker_id:
        try:
            from app.coupon_points_crud import (
                get_or_create_points_account,
                add_points_transaction
            )
            from app.crud import get_system_setting
            from datetime import datetime, timezone as tz, timedelta
            import uuid
            
            # 获取任务完成奖励积分（优先使用任务级别的积分，否则使用系统设置，默认0）
            points_amount = 0
            if hasattr(task, 'points_reward') and task.points_reward is not None:
                # 使用任务级别的积分设置
                points_amount = int(task.points_reward)
            else:
                # 使用系统设置（默认0）
                task_bonus_setting = get_system_setting(db, "points_task_complete_bonus")
                points_amount = int(task_bonus_setting.setting_value) if task_bonus_setting else 0  # 默认0积分
            
            if points_amount > 0:
                # 生成批次ID（季度格式：2025Q1-COMP）
                now = get_utc_time()
                quarter = (now.month - 1) // 3 + 1
                batch_id = f"{now.year}Q{quarter}-COMP"
                
                # 计算过期时间（如果启用积分过期）
                expire_days_setting = get_system_setting(db, "points_expire_days")
                expire_days = int(expire_days_setting.setting_value) if expire_days_setting else 0
                expires_at = None
                if expire_days > 0:
                    expires_at = now + timedelta(days=expire_days)
                
                # 生成幂等键（防止重复发放）
                idempotency_key = f"task_complete_{task_id}_{task.taker_id}"
                
                # 检查是否已发放（通过幂等键）
                from app.models import PointsTransaction
                existing = db.query(PointsTransaction).filter(
                    PointsTransaction.idempotency_key == idempotency_key
                ).first()
                
                if not existing:
                    # 发放积分奖励
                    add_points_transaction(
                        db,
                        task.taker_id,
                        type="earn",
                        amount=points_amount,
                        source="task_complete_bonus",
                        related_id=task_id,
                        related_type="task",
                        description=f"完成任务 #{task_id} 获得平台赠送积分（非任务报酬）",
                        batch_id=batch_id,
                        expires_at=expires_at,
                        idempotency_key=idempotency_key
                    )
                    
                    logger.info(f"任务完成积分奖励已发放: 用户 {task.taker_id}, 任务 {task_id}, 积分 {points_amount}")
        except Exception as e:
            logger.error(f"发放任务完成积分奖励失败: {e}", exc_info=True)
            # 积分发放失败不影响任务完成流程

    return task


@router.post("/tasks/{task_id}/cancel")
def cancel_task(
    task_id: int,
    cancel_data: schemas.TaskCancelRequest = Body(default=schemas.TaskCancelRequest()),
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """取消任务 - 如果任务已被接受，需要客服审核"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 检查权限：只有任务发布者或接受者可以取消任务
    if task.poster_id != current_user.id and task.taker_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only task poster or taker can cancel the task"
        )

    # 如果任务状态是 'open'，直接取消
    if task.status == "open":
        cancelled_task = crud.cancel_task(db, task_id, current_user.id)
        if not cancelled_task:
            raise HTTPException(status_code=400, detail="Task cannot be cancelled")
        return cancelled_task

    # 如果任务已被接受或正在进行中，创建取消请求等待客服审核
    elif task.status in ["taken", "in_progress"]:
        # 检查是否已有待审核的取消请求
        existing_request = crud.get_task_cancel_requests(db, "pending")
        existing_request = next(
            (req for req in existing_request if req.task_id == task_id), None
        )

        if existing_request:
            raise HTTPException(
                status_code=400,
                detail="A cancel request is already pending for this task",
            )

        # 创建取消请求
        cancel_request = crud.create_task_cancel_request(
            db, task_id, current_user.id, cancel_data.reason
        )

        # 注意：不发送通知到 notifications 表，因为客服不在 users 表中
        # 客服可以通过客服面板的取消请求列表查看待审核的请求
        # 如果需要通知功能，应该使用 staff_notifications 表通知所有在线客服

        return {
            "message": "Cancel request submitted for admin review",
            "request_id": cancel_request.id,
        }

    else:
        raise HTTPException(
            status_code=400, detail="Task cannot be cancelled in current status"
        )


@router.delete("/tasks/{task_id}/delete")
def delete_cancelled_task(
    task_id: int, current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    """删除已取消的任务"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 只有任务发布者可以删除任务
    if task.poster_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only task poster can delete the task"
        )

    # 只有已取消的任务可以删除
    if task.status != "cancelled":
        raise HTTPException(
            status_code=400, detail="Only cancelled tasks can be deleted"
        )

    # 使用新的安全删除函数
    result = crud.delete_user_task(db, task_id, current_user.id)
    if not result:
        raise HTTPException(status_code=500, detail="Failed to delete task")

    return result


@router.get("/tasks/{task_id}/history")
@measure_api_performance("get_task_history")
@cache_response(ttl=180, key_prefix="task_history")  # 缓存3分钟
def get_task_history(task_id: int, db: Session = Depends(get_db)):
    history = crud.get_task_history(db, task_id)
    return [
        {
            "id": h.id,
            "user_id": h.user_id,
            "action": h.action,
            "timestamp": h.timestamp,
            "remark": h.remark,
        }
        for h in history
    ]


@router.get("/profile/me")
@measure_api_performance("get_my_profile")
def get_my_profile(
    request: Request, 
    current_user=Depends(get_current_user_secure_sync_csrf), 
    db: Session = Depends(get_db)
):

    # 安全地创建用户对象，避免SQLAlchemy内部属性
    try:
        # 普通用户 - 尝试从缓存获取，如果缓存未命中则从数据库查询
        from app import crud
        fresh_user = crud.get_user_by_id(db, current_user.id)
        if fresh_user:
            current_user = fresh_user
        
        # 计算平均评分
        from app.models import Review
        user_reviews = db.query(Review).filter(Review.user_id == current_user.id).all()
        avg_rating = 0.0
        if user_reviews:
            total_rating = sum(r.rating for r in user_reviews)
            avg_rating = round(total_rating / len(user_reviews), 1)
        
        # 获取并清理字符串字段（去除首尾空格）
        residence_city = getattr(current_user, 'residence_city', None)
        if residence_city and isinstance(residence_city, str):
            residence_city = residence_city.strip()
            if not residence_city:  # 如果清理后为空字符串，设为 None
                residence_city = None
        
        language_preference = getattr(current_user, 'language_preference', 'en')
        if language_preference and isinstance(language_preference, str):
            language_preference = language_preference.strip()
            if not language_preference:  # 如果清理后为空字符串，设为默认值
                language_preference = 'en'
        
        formatted_user = {
            "id": current_user.id,
            "name": getattr(current_user, 'name', ''),
            "email": getattr(current_user, 'email', ''),
            "phone": getattr(current_user, 'phone', ''),
            "is_verified": getattr(current_user, 'is_verified', False),
            "user_level": getattr(current_user, 'user_level', 1),
            "avatar": getattr(current_user, 'avatar', ''),
            "created_at": getattr(current_user, 'created_at', None),
            "user_type": "normal_user",
            "task_count": getattr(current_user, 'task_count', 0),
            "completed_task_count": getattr(current_user, 'completed_task_count', 0),
            "avg_rating": avg_rating,
            "residence_city": residence_city,
            "language_preference": language_preference,
            "name_updated_at": getattr(current_user, 'name_updated_at', None),
            "flea_market_notice_agreed_at": getattr(current_user, 'flea_market_notice_agreed_at', None)  # 跳蚤市场须知同意时间
        }
        
        # ⚠️ 处理datetime对象，使其可JSON序列化（用于ETag生成和响应）
        # 注意：SQLAlchemy的DateTime可能返回timezone-aware或naive的datetime对象
        from datetime import datetime as dt, date
        import json
        
        def serialize_value(value):
            """递归序列化值，处理datetime和date对象"""
            if value is None:
                return None
            # 处理datetime对象（包括timezone-aware和naive）
            if isinstance(value, dt):
                return format_iso_utc(value)
            # 处理date对象（但不是datetime）
            if isinstance(value, date) and not isinstance(value, dt):
                return value.isoformat()
            # 处理其他可能不可序列化的类型
            try:
                # 快速测试：尝试序列化单个值
                json.dumps(value)
                return value
            except (TypeError, ValueError):
                # 如果无法序列化，转换为字符串（兜底方案）
                return str(value)
        
        serializable_user = {}
        for key, value in formatted_user.items():
            serializable_user[key] = serialize_value(value)
        
        # ⚠️ 生成ETag（用于HTTP协商缓存）- 必须使用已序列化的数据
        import hashlib
        user_json = json.dumps(serializable_user, sort_keys=True)
        etag = hashlib.md5(user_json.encode()).hexdigest()
        
        # 检查If-None-Match
        if_none_match = request.headers.get("If-None-Match")
        if if_none_match == etag:
            # ⚠️ 统一：304必须直接return Response对象，不return None
            return Response(
                status_code=304, 
                headers={
                    "ETag": etag,
                    "Cache-Control": "private, max-age=300",
                    "Vary": "Cookie"
                }
            )
        
        # ⚠️ 使用JSONResponse返回，设置响应头
        # 注意：serializable_user已经处理了datetime对象，可以直接使用
        
        return JSONResponse(
            content=serializable_user,
            headers={
                "ETag": etag,
                "Cache-Control": "private, max-age=300",  # 5分钟，配合Vary避免CDN误缓存
                "Vary": "Cookie"  # 避免中间层误缓存
            }
        )
    except Exception as e:
        logger.error(f"Error in get_my_profile for user {current_user.id if hasattr(current_user, 'id') else 'unknown'}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.get("/my-tasks", response_model=list[schemas.TaskOut])
@measure_api_performance("get_my_tasks")
def get_my_tasks(
    current_user=Depends(check_user_status), 
    db: Session = Depends(get_db),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0)
):
    """获取当前用户的任务（发布的和接受的）"""
    tasks = crud.get_user_tasks(db, current_user.id, limit=limit, offset=offset)
    return tasks


@router.get("/profile/{user_id}")
@measure_api_performance("get_user_profile")
@cache_response(ttl=300, key_prefix="user_profile")  # 缓存5分钟
def user_profile(
    user_id: str, current_user: Optional[models.User] = Depends(get_current_user_optional), db: Session = Depends(get_db)
):
    # 尝试直接查找
    user = crud.get_user_by_id(db, user_id)

    # 如果没找到且是7位数字，尝试转换为8位格式
    if not user and user_id.isdigit() and len(user_id) <= 7:
        # 补齐前导零到8位
        formatted_id = user_id.zfill(8)
        user = crud.get_user_by_id(db, formatted_id)

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # 计算注册天数
    from app.utils.time_utils import get_utc_time

    days_since_joined = (get_utc_time() - user.created_at).days

    # 获取用户的任务统计（限制数量以提高性能）
    tasks = crud.get_user_tasks(db, user_id, limit=100)  # 限制为最近100个任务
    # 所有用户看到的任务列表都是一样的，只显示已完成且公开的任务，避免信息泄露
    posted_tasks = [
        t
        for t in tasks
        if t.poster_id == user_id and t.is_public == 1 and t.status == "completed"
    ]
    taken_tasks = [
        t
        for t in tasks
        if t.taker_id == user_id and t.is_public == 1 and t.status == "completed"
    ]

    # 计算用户接受的任务中完成的数量
    completed_taken_tasks = [t for t in taken_tasks if t.status == "completed"]

    # 计算总任务数 = 发布任务数 + 接受任务数
    total_tasks = len(posted_tasks) + len(taken_tasks)

    # 计算完成率 = 完成的任务数 / 接受过的任务数（包括中途被取消的任务）
    completion_rate = 0.0
    if len(taken_tasks) > 0:
        completion_rate = (len(completed_taken_tasks) / len(taken_tasks)) * 100

    # 获取用户收到的评价
    reviews = crud.get_reviews_received_by_user(
        db, user_id, limit=10
    )  # 获取最近10条评价

    # 实时计算平均评分
    from sqlalchemy import func

    from app.models import Review, User

    avg_rating_result = (
        db.query(func.avg(Review.rating)).filter(Review.user_id == user_id).scalar()
    )
    avg_rating = float(avg_rating_result) if avg_rating_result is not None else 0.0

    # 安全：只返回公开信息，不返回敏感信息（email, phone）
    # 所有用户看到的用户页面内容都是一样的，包括自己查看自己的页面，避免信息泄露
    user_data = {
        "id": user.id,  # 数据库已经存储格式化ID
        "name": user.name,
        "created_at": user.created_at,
        "is_verified": user.is_verified,
        "user_level": user.user_level,
        "avatar": user.avatar,
        "avg_rating": avg_rating,
        "days_since_joined": days_since_joined,
        "task_count": user.task_count,
        "completed_task_count": user.completed_task_count,
    }
    
    return {
        "user": user_data,
        "stats": {
            "total_tasks": total_tasks,
            "posted_tasks": len(posted_tasks),
            "taken_tasks": len(taken_tasks),
            "completed_tasks": len(completed_taken_tasks),
            "completion_rate": round(completion_rate, 1),
            "total_reviews": len(reviews),
        },
        "recent_tasks": [
            {
                "id": t.id,
                "title": t.title,
                "status": t.status,
                "created_at": t.created_at,
                "reward": float(t.agreed_reward) if t.agreed_reward is not None else float(t.base_reward) if t.base_reward is not None else 0.0,
                "task_type": t.task_type,
            }
            for t in (posted_tasks + taken_tasks)[
                :5
            ]  # 最近5个任务（基于过滤后的任务列表）
        ],
        "reviews": [
            {
                "id": r.id,
                "rating": r.rating,
                "comment": r.comment,
                "created_at": r.created_at,
                "task_id": r.task_id,
                "is_anonymous": bool(r.is_anonymous),
                "reviewer_name": "匿名用户" if r.is_anonymous else user.name,
                "reviewer_avatar": "" if r.is_anonymous else (user.avatar or ""),
            }
            for r, user in reviews
        ],
    }


@router.post("/profile/send-email-update-code")
@rate_limit("send_code")
def send_email_update_code(
    request_data: schemas.UpdateEmailRequest,
    background_tasks: BackgroundTasks,
    current_user=Depends(get_current_user_secure_sync_csrf),
):
    """发送邮箱修改验证码到新邮箱"""
    try:
        from app.update_verification_code_manager import generate_verification_code, store_email_update_code
        from app.validators import StringValidator
        from app.email_utils import send_email
        
        new_email = request_data.new_email.strip().lower()
        
        # 验证邮箱格式
        try:
            validated_email = StringValidator.validate_email(new_email)
            new_email = validated_email.lower()
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))
        
        # 检查邮箱是否已被其他用户使用
        from app.database import SessionLocal
        db = SessionLocal()
        try:
            existing_user = db.query(models.User).filter(
                models.User.email == new_email,
                models.User.id != current_user.id
            ).first()
            if existing_user:
                raise HTTPException(status_code=400, detail="该邮箱已被其他用户使用")
        finally:
            db.close()
        
        # 生成6位数字验证码
        verification_code = generate_verification_code(6)
        
        # 存储验证码到Redis，有效期5分钟
        if not store_email_update_code(current_user.id, new_email, verification_code):
            logger.error(f"存储邮箱修改验证码失败: user_id={current_user.id}, new_email={new_email}")
            raise HTTPException(
                status_code=500,
                detail="发送验证码失败，请稍后重试"
            )
        
        # 根据用户语言偏好获取邮件模板
        from app.email_templates import get_user_language, get_email_update_verification_code_email
        
        language = get_user_language(current_user)
        subject, body = get_email_update_verification_code_email(language, new_email, verification_code)
        
        # 异步发送邮件
        background_tasks.add_task(send_email, new_email, subject, body)
        
        logger.info(f"邮箱修改验证码已发送: user_id={current_user.id}, new_email={new_email}")
        
        return {
            "message": "验证码已发送到新邮箱",
            "email": new_email,
            "expires_in": 300  # 5分钟
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"发送邮箱修改验证码失败: {e}")
        raise HTTPException(
            status_code=500,
            detail="发送验证码失败"
        )


@router.post("/profile/send-phone-update-code")
@rate_limit("send_code")
def send_phone_update_code(
    request_data: schemas.UpdatePhoneRequest,
    background_tasks: BackgroundTasks,
    current_user=Depends(get_current_user_secure_sync_csrf),
):
    """发送手机号修改验证码到新手机号"""
    try:
        from app.update_verification_code_manager import generate_verification_code, store_phone_update_code
        from app.validators import StringValidator
        import os
        
        new_phone = request_data.new_phone.strip()
        
        # 验证手机号格式
        try:
            validated_phone = StringValidator.validate_phone(new_phone)
            new_phone = validated_phone
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))
        
        # 检查手机号是否已被其他用户使用
        from app.database import SessionLocal
        db = SessionLocal()
        try:
            existing_user = db.query(models.User).filter(
                models.User.phone == new_phone,
                models.User.id != current_user.id
            ).first()
            if existing_user:
                raise HTTPException(status_code=400, detail="该手机号已被其他用户使用")
        finally:
            db.close()
        
        # 生成6位数字验证码
        verification_code = generate_verification_code(6)
        
        # 存储验证码到Redis，有效期5分钟
        if not store_phone_update_code(current_user.id, new_phone, verification_code):
            logger.error(f"存储手机号修改验证码失败: user_id={current_user.id}, new_phone={new_phone}")
            raise HTTPException(
                status_code=500,
                detail="发送验证码失败，请稍后重试"
            )
        
        # 发送短信（使用 Twilio）
        try:
            from app.twilio_sms import twilio_sms
            # 获取用户语言偏好
            language = current_user.language_preference if hasattr(current_user, 'language_preference') and current_user.language_preference else 'zh'
            
            # 尝试发送短信
            sms_sent = twilio_sms.send_update_verification_code(new_phone, verification_code, language)
            
            if not sms_sent:
                # 如果 Twilio 发送失败，在开发环境中记录日志
                if os.getenv("ENVIRONMENT", "production") == "development":
                    logger.warning(f"[开发环境] Twilio 未配置或发送失败，手机号修改验证码: {new_phone} -> {verification_code}")
                else:
                    logger.error(f"Twilio 短信发送失败: user_id={current_user.id}, phone={new_phone}")
                    raise HTTPException(
                        status_code=500,
                        detail="发送验证码失败，请稍后重试"
                    )
            else:
                logger.info(f"手机号修改验证码已通过 Twilio 发送: user_id={current_user.id}, phone={new_phone}")
        except ImportError:
            # 如果 Twilio 未安装，在开发环境中记录日志
            logger.warning("Twilio 模块未安装，无法发送短信")
            if os.getenv("ENVIRONMENT", "production") == "development":
                logger.warning(f"[开发环境] 手机号修改验证码: {new_phone} -> {verification_code}")
            else:
                logger.error("Twilio 模块未安装，无法发送短信")
                raise HTTPException(
                    status_code=500,
                    detail="短信服务未配置，请联系管理员"
                )
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"发送短信时发生异常: {e}")
            # 在开发环境中，即使发送失败也继续（记录验证码）
            if os.getenv("ENVIRONMENT", "production") == "development":
                logger.warning(f"[开发环境] 手机号修改验证码: {new_phone} -> {verification_code}")
            else:
                raise HTTPException(
                    status_code=500,
                    detail="发送验证码失败，请稍后重试"
                )
        
        return {
            "message": "验证码已发送到新手机号",
            "phone": new_phone,
            "expires_in": 300  # 5分钟
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"发送手机号修改验证码失败: {e}")
        raise HTTPException(
            status_code=500,
            detail="发送验证码失败"
        )


class AvatarUpdate(BaseModel):
    avatar: str


@router.patch("/profile/avatar")
def update_avatar(
    data: AvatarUpdate,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    
    try:
        # 直接更新数据库，简单直接
        db.query(models.User).filter(models.User.id == current_user.id).update({
            "avatar": data.avatar
        })
        db.commit()
        
        # 清除用户缓存
        try:
            from app.redis_cache import invalidate_user_cache
            invalidate_user_cache(current_user.id)
        except Exception as e:
            pass  # 静默处理缓存清除失败
        
        return {"avatar": data.avatar}
        
    except Exception as e:
        logger.error(f"头像更新失败: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail="头像更新失败")


class ProfileUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    email_verification_code: Optional[str] = None  # 修改邮箱时需要验证码
    phone: Optional[str] = None
    phone_verification_code: Optional[str] = None  # 修改手机号时需要验证码
    residence_city: Optional[str] = None
    language_preference: Optional[str] = None


@router.patch("/profile")
def update_profile(
    request: Request,
    data: ProfileUpdate,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """更新用户个人资料（名字、常住城市、语言偏好等）"""
    # 更新个人资料处理中（已移除DEBUG日志以提升性能）
    try:
        from datetime import datetime, timedelta
        from app.validators import StringValidator
        import re
        
        update_data = {}
        
        # 处理名字更新
        if data.name is not None:
            new_name = data.name.strip()
            
            # 验证名字长度
            if len(new_name) < 3:
                raise HTTPException(status_code=400, detail="用户名至少需要3个字符")
            if len(new_name) > 50:
                raise HTTPException(status_code=400, detail="用户名不能超过50个字符")
            
            # 验证名字格式（支持中文、英文字母、数字、下划线和连字符）
            # 使用Unicode字符类，允许中文、日文、韩文等
            # 排除空格、换行、制表符等空白字符
            if re.search(r'[\s\n\r\t]', new_name):
                raise HTTPException(status_code=400, detail="用户名不能包含空格或换行符")
            
            # 验证名字不能以数字开头
            if new_name[0].isdigit():
                raise HTTPException(status_code=400, detail="用户名不能以数字开头")
            
            # 检查是否与当前名字相同
            if new_name == current_user.name:
                # 如果名字没变，不需要更新
                pass
            else:
                # 检查名字唯一性
                existing_user = db.query(models.User).filter(
                    models.User.name == new_name,
                    models.User.id != current_user.id
                ).first()
                if existing_user:
                    raise HTTPException(status_code=400, detail="该用户名已被使用，请选择其他用户名")
                
                # 检查是否在一个月内修改过名字
                if current_user.name_updated_at:
                    # 处理日期比较（兼容 date 和 datetime 类型）
                    last_update = current_user.name_updated_at
                    if isinstance(last_update, datetime):
                        # 如果是 datetime 类型，只取日期部分
                        last_update_date = last_update.date()
                    else:
                        # 如果是 date 类型，直接使用
                        last_update_date = last_update
                    
                    # 获取当前日期（UTC）
                    current_date = get_utc_time().date()
                    
                    # 计算日期差
                    days_diff = (current_date - last_update_date).days
                    
                    if days_diff < 30:
                        days_left = 30 - days_diff
                        raise HTTPException(
                            status_code=400, 
                            detail=f"用户名一个月内只能修改一次，请在 {days_left} 天后再试"
                        )
                
                # 更新名字和修改时间（只保存日期部分，兼容 date 类型）
                update_data["name"] = new_name
                # 使用当前日期（不包含时间），兼容 date 类型数据库字段
                update_data["name_updated_at"] = get_utc_time().date()
        
        if data.residence_city is not None:
            # 验证城市选项（可选：可以在后端验证城市是否在允许列表中）
            # 允许空字符串或null，表示清除城市
            if data.residence_city == "":
                update_data["residence_city"] = None
            else:
                update_data["residence_city"] = data.residence_city
        
        if data.language_preference is not None:
            # 验证语言偏好只能是 'zh' 或 'en'
            if data.language_preference not in ['zh', 'en']:
                raise HTTPException(status_code=400, detail="语言偏好只能是 'zh' 或 'en'")
            update_data["language_preference"] = data.language_preference
        
        # 处理邮箱更新
        if data.email is not None:
            new_email = data.email.strip() if data.email else None
            
            # 如果邮箱为空，允许设置为None（用于手机号登录用户绑定邮箱）
            if new_email == "":
                new_email = None
            
            # 如果提供了新邮箱且与当前邮箱不同，需要验证码验证
            if new_email and new_email != current_user.email:
                # 验证格式
                try:
                    validated_email = StringValidator.validate_email(new_email)
                    new_email = validated_email.lower()
                except ValueError as e:
                    raise HTTPException(status_code=400, detail=str(e))
                
                # 检查邮箱是否已被其他用户使用
                existing_user = db.query(models.User).filter(
                    models.User.email == new_email,
                    models.User.id != current_user.id
                ).first()
                if existing_user:
                    raise HTTPException(status_code=400, detail="该邮箱已被其他用户使用")
                
                # 验证验证码
                if not data.email_verification_code:
                    raise HTTPException(status_code=400, detail="修改邮箱需要验证码，请先发送验证码到新邮箱")
                
                from app.update_verification_code_manager import verify_email_update_code
                if not verify_email_update_code(current_user.id, new_email, data.email_verification_code):
                    raise HTTPException(status_code=400, detail="验证码错误或已过期，请重新发送")
                
                update_data["email"] = new_email
            elif new_email == current_user.email:
                # 邮箱没变化，不需要更新
                pass
            elif new_email is None and current_user.email:
                # 清空邮箱（解绑），不需要验证码
                update_data["email"] = None
        
        # 处理手机号更新
        if data.phone is not None:
            new_phone = data.phone.strip() if data.phone else None
            
            # 如果手机号为空，允许设置为None（用于邮箱登录用户绑定手机号）
            if new_phone == "":
                new_phone = None
            
            # 如果提供了新手机号且与当前手机号不同，需要验证码验证
            if new_phone and new_phone != current_user.phone:
                # 验证格式
                try:
                    validated_phone = StringValidator.validate_phone(new_phone)
                    new_phone = validated_phone
                except ValueError as e:
                    raise HTTPException(status_code=400, detail=str(e))
                
                # 检查手机号是否已被其他用户使用
                existing_user = db.query(models.User).filter(
                    models.User.phone == new_phone,
                    models.User.id != current_user.id
                ).first()
                if existing_user:
                    raise HTTPException(status_code=400, detail="该手机号已被其他用户使用")
                
                # 验证验证码
                if not data.phone_verification_code:
                    raise HTTPException(status_code=400, detail="修改手机号需要验证码，请先发送验证码到新手机号")
                
                from app.update_verification_code_manager import verify_phone_update_code
                if not verify_phone_update_code(current_user.id, new_phone, data.phone_verification_code):
                    raise HTTPException(status_code=400, detail="验证码错误或已过期，请重新发送")
                
                update_data["phone"] = new_phone
            elif new_phone == current_user.phone:
                # 手机号没变化，不需要更新
                pass
            elif new_phone is None and current_user.phone:
                # 清空手机号（解绑），不需要验证码
                update_data["phone"] = None
        
        # 如果没有要更新的字段，直接返回成功（允许只更新任务偏好而不更新个人资料）
        if not update_data:
            return {"message": "没有需要更新的个人资料字段"}
        
        
        # 更新数据库
        db.query(models.User).filter(models.User.id == current_user.id).update(update_data)
        db.commit()
        
        # 清除用户缓存
        try:
            from app.redis_cache import invalidate_user_cache
            invalidate_user_cache(current_user.id)
        except Exception as e:
            pass  # 静默处理缓存清除失败
        
        return {"message": "个人资料更新成功", **update_data}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"个人资料更新失败: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"个人资料更新失败: {str(e)}")


@router.post("/admin/user/{user_id}/set_level")
def admin_set_user_level(
    user_id: str,
    level: str = Body(...),
    current_user=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    from app.security import get_client_ip
    
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
    from app.security import get_client_ip
    
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
    
    return {"message": f"User {user_id} status updated."}


@router.post("/admin/task/{task_id}/set_level")
def admin_set_task_level(
    task_id: int,
    level: str = Body(...),
    current_user=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    from app.security import get_client_ip
    
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found.")
    
    old_level = task.task_level
    task.task_level = level
    db.commit()
    
    # 记录审计日志
    if old_level != level:
        ip_address = get_client_ip(request) if request else None
        crud.create_audit_log(
            db=db,
            action_type="update_task_level",
            entity_type="task",
            entity_id=str(task_id),
            admin_id=current_user.id,
            user_id=task.poster_id,
            old_value={"task_level": old_level},
            new_value={"task_level": level},
            reason=f"管理员 {current_user.id} ({current_user.name}) 修改了任务等级",
            ip_address=ip_address,
        )
    
    return {"message": f"Task {task_id} level set to {level}."}


@router.post("/messages/send", response_model=schemas.MessageOut)
@rate_limit("send_message")
def send_message_api(
    # ⚠️ DEPRECATED: 此接口已废弃，不再使用
    # 联系人聊天功能已移除，请使用任务聊天接口：
    # POST /api/messages/task/{task_id}/send
    # 此接口已完全禁用，不再创建无任务ID的消息
    msg: schemas.MessageCreate,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    # 完全禁用此接口，返回错误
    raise HTTPException(
        status_code=410,  # 410 Gone - 资源已永久移除
        detail="此接口已废弃。联系人聊天功能已移除，请使用任务聊天接口：POST /api/messages/task/{task_id}/send"
    )


@router.get("/messages/history/{user_id}", response_model=list[schemas.MessageOut])
def get_chat_history_api(
    # ⚠️ DEPRECATED: 此接口已废弃，不再使用
    # 联系人聊天功能已移除，请使用任务聊天接口：
    # GET /api/messages/task/{task_id}
    # 此接口保留仅用于向后兼容，可能会在未来的版本中移除
    user_id: str,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
    limit: int = 20,  # 增加默认加载数量
    offset: int = 0,
    session_id: int = None,
):
    # 如果提供了session_id，直接使用它
    if session_id is not None:
        return crud.get_chat_history(
            db, current_user.id, user_id, limit, offset, session_id=session_id
        )

    # 普通用户之间的消息
    return crud.get_chat_history(db, current_user.id, user_id, limit, offset)


@router.get("/messages/unread", response_model=list[schemas.MessageOut])
def get_unread_messages_api(
    current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    try:
        messages = crud.get_unread_messages(db, current_user.id)
        # 过滤并修复消息：确保 sender_id 和 receiver_id 都不为 None
        valid_messages = []
        for msg in messages:
            # 跳过 sender_id 为 None 的消息（系统消息）
            if msg.sender_id is None:
                continue
            # 对于任务消息，receiver_id 可能为 None，设置为当前用户ID
            # 因为这是未读消息，肯定是发送给当前用户的
            if msg.receiver_id is None:
                setattr(msg, 'receiver_id', current_user.id)
            valid_messages.append(msg)
        return valid_messages
    except Exception as e:
        from fastapi import HTTPException
        raise HTTPException(status_code=500, detail=f"获取未读消息失败: {str(e)}")


@router.get("/messages/unread/count")
def get_unread_count_api(
    current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    return {"unread_count": len(crud.get_unread_messages(db, current_user.id))}


@router.get("/messages/unread/by-contact")
def get_unread_count_by_contact_api(
    current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    """
    ⚠️ DEPRECATED: 此接口已废弃，不再使用
    联系人聊天功能已移除，请使用任务聊天接口：
    GET /api/messages/tasks (获取任务列表，包含未读消息数)
    此接口保留仅用于向后兼容，可能会在未来的版本中移除
    
    获取每个联系人的未读消息数量（已废弃）
    """
    from app.models import Message
    
    # 查询所有未读消息，按发送者分组
    unread_messages = (
        db.query(Message)
        .filter(Message.receiver_id == current_user.id, Message.is_read == 0)
        .all()
    )
    
    # 按发送者ID分组计数
    contact_counts = {}
    for msg in unread_messages:
        sender_id = msg.sender_id
        if sender_id:
            contact_counts[sender_id] = contact_counts.get(sender_id, 0) + 1
    
    return {"contact_unread_counts": contact_counts}


@router.post("/messages/{msg_id}/read", response_model=schemas.MessageOut)
def mark_message_read_api(
    msg_id: int, current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    return crud.mark_message_read(db, msg_id, current_user.id)


@router.post("/messages/mark-chat-read/{contact_id}")
def mark_chat_messages_read_api(
    contact_id: str, current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    """
    ⚠️ DEPRECATED: 此接口已废弃，不再使用
    联系人聊天功能已移除，请使用任务聊天接口：
    POST /api/messages/task/{task_id}/read
    此接口保留仅用于向后兼容，可能会在未来的版本中移除
    
    标记与指定联系人的所有消息为已读（已废弃）
    """
    try:
        from app.models import Message
        
        
        # 获取与指定联系人的所有未读消息
        unread_messages = (
            db.query(Message)
            .filter(
                Message.receiver_id == current_user.id,
                Message.sender_id == contact_id,
                Message.is_read == 0
            )
            .all()
        )
        
        
        # 标记所有未读消息为已读
        for msg in unread_messages:
            msg.is_read = 1
        
        db.commit()
        
        return {
            "message": f"已标记与用户 {contact_id} 的 {len(unread_messages)} 条消息为已读",
            "marked_count": len(unread_messages)
        }
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"标记消息为已读失败: {str(e)}")


@router.get("/admin/messages", response_model=list[schemas.MessageOut])
def get_admin_messages_api(
    current_user=Depends(get_current_admin), db: Session = Depends(get_db)
):
    return crud.get_admin_messages(db, current_user.id)


# 通知相关API
@router.get("/notifications", response_model=list[schemas.NotificationOut])
def get_notifications_api(
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
    limit: int = 20,
):
    return crud.get_user_notifications(db, current_user.id, limit)


@router.get("/notifications/unread", response_model=list[schemas.NotificationOut])
def get_unread_notifications_api(
    current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    return crud.get_unread_notifications(db, current_user.id)


@router.get("/notifications/with-recent-read", response_model=list[schemas.NotificationOut])
def get_notifications_with_recent_read_api(
    current_user=Depends(check_user_status), 
    db: Session = Depends(get_db),
    recent_read_limit: int = 10
):
    """获取所有未读通知和最近N条已读通知"""
    return crud.get_notifications_with_recent_read(db, current_user.id, recent_read_limit)


@router.get("/notifications/unread/count")
def get_unread_notification_count_api(
    current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    return {"unread_count": crud.get_unread_notification_count(db, current_user.id)}


@router.post(
    "/notifications/{notification_id}/read", response_model=schemas.NotificationOut
)
def mark_notification_read_api(
    notification_id: int,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    return crud.mark_notification_read(db, notification_id, current_user.id)


@router.post("/notifications/read-all")
def mark_all_notifications_read_api(
    current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    crud.mark_all_notifications_read(db, current_user.id)
    return {"message": "All notifications marked as read"}


@router.post("/notifications/send-announcement")
def send_announcement_api(
    announcement: dict = Body(...),
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """发送平台公告给所有用户"""
    from app.models import User

    # 获取所有用户
    users = db.query(User).all()

    # 为每个用户创建公告通知
    for user in users:
        crud.create_notification(
            db,
            user.id,
            "announcement",
            announcement.get("title", "平台公告"),
            announcement.get("content", ""),
            None,
        )

    return {"message": f"Announcement sent to {len(users)} users"}


@router.post("/tasks/{task_id}/pay")
def create_payment(
    task_id: int, current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    task = crud.get_task(db, task_id)
    if not task or task.poster_id != current_user.id:
        raise HTTPException(status_code=404, detail="Task not found or no permission.")
    if task.is_paid:
        return {"message": "Task already paid."}
    # 创建Stripe支付会话
    session = stripe.checkout.Session.create(
        payment_method_types=["card"],
        line_items=[
            {
                "price_data": {
                    "currency": "gbp",
                    "product_data": {"name": task.title},
                    "unit_amount": int((float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0) * 100),
                },
                "quantity": 1,
            }
        ],
        mode="payment",
        success_url=f"http://localhost:8000/api/users/tasks/{task_id}/pay/success",
        cancel_url=f"http://localhost:8000/api/users/tasks/{task_id}/pay/cancel",
        metadata={"task_id": task_id},
    )
    return {"checkout_url": session.url}


@router.post("/stripe/webhook")
async def stripe_webhook(request: Request, db: Session = Depends(get_db)):
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")
    endpoint_secret = os.getenv("STRIPE_WEBHOOK_SECRET", "whsec_...yourkey...")
    try:
        event = stripe.Webhook.construct_event(payload, sig_header, endpoint_secret)
    except Exception as e:
        return {"error": str(e)}
    if event["type"] == "checkout.session.completed":
        session = event["data"]["object"]
        task_id = int(session["metadata"]["task_id"])
        task = crud.get_task(db, task_id)
        if task:
            task.is_paid = 1
            # 使用最终成交价（如果有议价）或原始标价
            task.escrow_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0
            db.commit()
    return {"status": "success"}


@router.post("/tasks/{task_id}/confirm_complete")
def confirm_task_complete(
    task_id: int, current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    task = crud.get_task(db, task_id)
    if not task or task.poster_id != current_user.id:
        raise HTTPException(status_code=404, detail="Task not found or no permission.")
    if not task.is_paid or task.status != "completed" or task.is_confirmed:
        raise HTTPException(
            status_code=400, detail="Task not eligible for confirmation."
        )
    task.is_confirmed = 1
    task.paid_to_user_id = task.taker_id
    task.escrow_amount = 0.0
    db.commit()
    return {"message": "Payment released to taker."}


# 删除重复的admin/users端点，使用后面的get_users_for_admin


@router.get("/admin/tasks")
def admin_get_tasks(
    skip: int = 0,
    limit: int = 50,
    status: str = None,
    task_type: str = None,
    location: str = None,
    keyword: str = None,
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员获取任务列表（支持分页和筛选）"""
    from sqlalchemy import or_

    from app.models import Task

    # 构建查询
    query = db.query(Task)

    # 添加状态筛选
    if status and status.strip():
        query = query.filter(Task.status == status)

    # 添加任务类型筛选
    if task_type and task_type.strip():
        query = query.filter(Task.task_type == task_type)

    # 添加城市筛选
    if location and location.strip():
        query = query.filter(Task.location == location)

    # 添加关键词搜索（使用 pg_trgm 优化）
    if keyword and keyword.strip():
        from sqlalchemy import func
        keyword_clean = keyword.strip()
        query = query.filter(
            or_(
                func.similarity(Task.title, keyword_clean) > 0.2,
                func.similarity(Task.description, keyword_clean) > 0.2,
                func.similarity(Task.task_type, keyword_clean) > 0.2,
                func.similarity(Task.location, keyword_clean) > 0.2,
                Task.title.ilike(f"%{keyword_clean}%"),
                Task.description.ilike(f"%{keyword_clean}%")
            )
        )

    # 获取总数
    total = query.count()

    # 执行查询并排序
    tasks = query.order_by(Task.created_at.desc()).offset(skip).limit(limit).all()

    return {"tasks": tasks, "total": total, "skip": skip, "limit": limit}


@router.get("/admin/tasks/{task_id}")
def admin_get_task_detail(
    task_id: int, current_user=Depends(get_current_admin), db: Session = Depends(get_db)
):
    """管理员获取任务详情"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 获取任务历史
    history = crud.get_task_history(db, task_id)

    return {"task": task, "history": history}


@router.put("/admin/tasks/{task_id}")
def admin_update_task(
    task_id: int,
    task_update: schemas.AdminTaskUpdate,
    current_user=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """管理员更新任务信息"""
    from app.security import get_client_ip
    
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 更新任务（返回变更信息）
    updated_task, old_values, new_values = crud.update_task_by_admin(
        db, task_id, task_update.dict(exclude_unset=True)
    )

    # 记录操作历史（管理员操作时user_id设为None，因为管理员不在users表中）
    crud.add_task_history(
        db, task_id, None, "admin_update", f"管理员 {current_user.id} ({current_user.name}) 更新了任务信息"
    )
    
    # 记录审计日志（如果有变更）
    if old_values and new_values:
        ip_address = get_client_ip(request) if request else None
        crud.create_audit_log(
            db=db,
            action_type="update_task",
            entity_type="task",
            entity_id=str(task_id),
            admin_id=current_user.id,
            user_id=task.poster_id,  # 任务发布者
            old_value=old_values,
            new_value=new_values,
            reason=f"管理员 {current_user.id} ({current_user.name}) 更新了任务信息",
            ip_address=ip_address,
        )

    return {"message": "任务更新成功", "task": updated_task}


@router.delete("/admin/tasks/{task_id}")
def admin_delete_task(
    task_id: int, 
    current_user=Depends(get_current_admin), 
    request: Request = None,
    db: Session = Depends(get_db)
):
    """管理员删除任务"""
    from app.security import get_client_ip
    
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 记录任务信息（用于审计日志）
    task_data = {
        'id': task.id,
        'title': task.title,
        'status': task.status,
        'poster_id': task.poster_id,
        'taker_id': task.taker_id,
        'reward': float(task.reward) if task.reward else None,
        'task_type': task.task_type,
        'location': task.location,
    }

    # 记录删除历史（管理员操作时user_id设为None）
    crud.add_task_history(
        db, task_id, None, "admin_delete", f"管理员 {current_user.id} ({current_user.name}) 删除了任务"
    )

    # 删除任务
    success = crud.delete_task_by_admin(db, task_id)

    if success:
        # 记录审计日志
        ip_address = get_client_ip(request) if request else None
        crud.create_audit_log(
            db=db,
            action_type="delete_task",
            entity_type="task",
            entity_id=str(task_id),
            admin_id=current_user.id,
            user_id=task.poster_id,
            old_value=task_data,
            new_value=None,  # 删除后值为None
            reason=f"管理员 {current_user.id} ({current_user.name}) 删除了任务",
            ip_address=ip_address,
        )
        return {"message": f"任务 {task_id} 已删除"}
    else:
        raise HTTPException(status_code=500, detail="删除任务失败")


@router.post("/admin/tasks/batch-update")
def admin_batch_update_tasks(
    task_ids: list[int],
    task_update: schemas.AdminTaskUpdate,
    current_user=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """管理员批量更新任务"""
    from app.security import get_client_ip
    
    updated_tasks = []
    failed_tasks = []
    ip_address = get_client_ip(request) if request else None

    for task_id in task_ids:
        try:
            task = crud.get_task(db, task_id)
            if task:
                updated_task, old_values, new_values = crud.update_task_by_admin(
                    db, task_id, task_update.dict(exclude_unset=True)
                )
                crud.add_task_history(
                    db,
                    task_id,
                    None,
                    "admin_batch_update",
                    f"管理员 {current_user.id} ({current_user.name}) 批量更新了任务信息",
                )
                # 记录审计日志（如果有变更）
                if old_values and new_values:
                    crud.create_audit_log(
                        db=db,
                        action_type="batch_update_task",
                        entity_type="task",
                        entity_id=str(task_id),
                        admin_id=current_user.id,
                        user_id=task.poster_id,
                        old_value=old_values,
                        new_value=new_values,
                        reason=f"管理员 {current_user.id} ({current_user.name}) 批量更新了任务信息",
                        ip_address=ip_address,
                    )
                updated_tasks.append(updated_task)
            else:
                failed_tasks.append({"task_id": task_id, "error": "任务不存在"})
        except Exception as e:
            failed_tasks.append({"task_id": task_id, "error": str(e)})

    return {
        "message": f"批量更新完成，成功: {len(updated_tasks)}, 失败: {len(failed_tasks)}",
        "updated_tasks": updated_tasks,
        "failed_tasks": failed_tasks,
    }


@router.post("/admin/tasks/batch-delete")
def admin_batch_delete_tasks(
    task_ids: list[int],
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员批量删除任务"""
    deleted_tasks = []
    failed_tasks = []

    for task_id in task_ids:
        try:
            task = crud.get_task(db, task_id)
            if task:
                crud.add_task_history(
                    db,
                    task_id,
                    None,
                    "admin_batch_delete",
                    f"管理员 {current_user.id} ({current_user.name}) 批量删除了任务",
                )
                success = crud.delete_task_by_admin(db, task_id)
                if success:
                    deleted_tasks.append(task_id)
                else:
                    failed_tasks.append({"task_id": task_id, "error": "删除失败"})
            else:
                failed_tasks.append({"task_id": task_id, "error": "任务不存在"})
        except Exception as e:
            failed_tasks.append({"task_id": task_id, "error": str(e)})

    return {
        "message": f"批量删除完成，成功: {len(deleted_tasks)}, 失败: {len(failed_tasks)}",
        "deleted_tasks": deleted_tasks,
        "failed_tasks": failed_tasks,
    }


# 管理员处理客服请求相关API
@router.get("/admin/customer-service-requests")
def admin_get_customer_service_requests(
    status: str = None,
    priority: str = None,
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员获取客服请求列表"""
    from app.models import AdminRequest, CustomerService

    query = db.query(AdminRequest)

    # 添加状态筛选
    if status and status.strip():
        query = query.filter(AdminRequest.status == status)

    # 添加优先级筛选
    if priority and priority.strip():
        query = query.filter(AdminRequest.priority == priority)

    requests = query.order_by(AdminRequest.created_at.desc()).all()

    # 为每个请求添加客服信息
    result = []
    for request in requests:
        customer_service = (
            db.query(CustomerService)
            .filter(CustomerService.id == request.requester_id)
            .first()
        )
        request_dict = {
            "id": request.id,
            "requester_id": request.requester_id,
            "requester_name": customer_service.name if customer_service else "未知客服",
            "type": request.type,
            "title": request.title,
            "description": request.description,
            "priority": request.priority,
            "status": request.status,
            "admin_response": request.admin_response,
            "admin_id": request.admin_id,
            "created_at": request.created_at,
            "updated_at": request.updated_at,
        }
        result.append(request_dict)

    return {"requests": result, "total": len(result)}


@router.get("/admin/customer-service-requests/{request_id}")
def admin_get_customer_service_request_detail(
    request_id: int, current_user=Depends(get_current_admin), db: Session = Depends(get_db)
):
    """管理员获取客服请求详情"""
    from app.models import AdminRequest, CustomerService

    request = db.query(AdminRequest).filter(AdminRequest.id == request_id).first()
    if not request:
        raise HTTPException(status_code=404, detail="Request not found")

    customer_service = (
        db.query(CustomerService)
        .filter(CustomerService.id == request.requester_id)
        .first()
    )

    return {
        "request": request,
        "customer_service": {
            "id": customer_service.id if customer_service else None,
            "name": customer_service.name if customer_service else "未知客服",
        },
    }


@router.put("/admin/customer-service-requests/{request_id}")
def admin_update_customer_service_request(
    request_id: int,
    request_update: dict,
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员更新客服请求状态和回复"""
    from datetime import datetime

    from app.models import AdminRequest

    request = db.query(AdminRequest).filter(AdminRequest.id == request_id).first()
    if not request:
        raise HTTPException(status_code=404, detail="Request not found")

    # 更新请求信息
    if "status" in request_update:
        request.status = request_update["status"]
    if "admin_response" in request_update:
        request.admin_response = request_update["admin_response"]
    if "priority" in request_update:
        request.priority = request_update["priority"]

    request.admin_id = current_user.id
    request.updated_at = get_utc_time()

    db.commit()
    db.refresh(request)

    return {"message": "Request updated successfully", "request": request}


@router.get("/admin/customer-service-chat")
def admin_get_customer_service_chat_messages(
    current_user=Depends(get_current_admin), db: Session = Depends(get_db)
):
    """管理员获取与客服的聊天记录"""
    from app.models import AdminChatMessage, CustomerService

    messages = (
        db.query(AdminChatMessage).order_by(AdminChatMessage.created_at.asc()).all()
    )

    # 为每个消息添加发送者信息
    result = []
    for message in messages:
        sender_name = None
        if message.sender_type == "customer_service" and message.sender_id:
            customer_service = (
                db.query(CustomerService)
                .filter(CustomerService.id == message.sender_id)
                .first()
            )
            sender_name = customer_service.name if customer_service else "未知客服"
        elif message.sender_type == "admin" and message.sender_id:
            # 这里可以添加管理员信息查询
            sender_name = "管理员"

        message_dict = {
            "id": message.id,
            "sender_id": message.sender_id,
            "sender_type": message.sender_type,
            "sender_name": sender_name,
            "content": message.content,
            "created_at": format_iso_utc(message.created_at) if message.created_at else None,
        }
        result.append(message_dict)

    return {"messages": result, "total": len(result)}


@router.post("/admin/customer-service-chat")
def admin_send_customer_service_chat_message(
    message_data: dict,
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员发送消息给客服"""
    from app.models import AdminChatMessage

    chat_message = AdminChatMessage(
        sender_id=current_user.id, sender_type="admin", content=message_data["content"]
    )

    db.add(chat_message)
    db.commit()
    db.refresh(chat_message)

    return {"message": "Message sent successfully", "chat_message": chat_message}


@router.get("/admin/payments")
def admin_get_payments(
    current_user=Depends(get_current_admin), db: Session = Depends(get_db)
):
    from app.models import Task

    return db.query(Task).filter(Task.is_paid == 1).all()


@router.get("/contacts")
@measure_api_performance("get_contacts")
@cache_response(ttl=180, key_prefix="user_contacts")  # 缓存3分钟
def get_contacts(current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)):
    try:
        from app.models import Message, User
        
        print(f"DEBUG: 开始获取联系人，用户ID: {current_user.id}")

        # 简化版本：直接获取所有与当前用户有消息往来的用户
        # 获取发送的消息
        sent_contacts = db.query(Message.receiver_id).filter(
            Message.sender_id == current_user.id
        ).distinct().all()
        
        # 获取接收的消息
        received_contacts = db.query(Message.sender_id).filter(
            Message.receiver_id == current_user.id
        ).distinct().all()

        # 合并并去重
        contact_ids = set()
        for result in sent_contacts:
            if result[0]:
                contact_ids.add(result[0])
        for result in received_contacts:
            if result[0]:
                contact_ids.add(result[0])

        # 排除自己
        contact_ids.discard(current_user.id)
        
        print(f"DEBUG: 找到 {len(contact_ids)} 个联系人ID: {list(contact_ids)}")

        if not contact_ids:
            print("DEBUG: 没有找到联系人，返回空列表")
            return []

        # 使用一次查询获取所有用户信息和最新消息时间
        from sqlalchemy import func, case
        
        # 构建联系人ID列表用于IN查询
        contact_id_list = list(contact_ids)
        
        # 一次性查询所有用户信息
        users_query = db.query(User).filter(User.id.in_(contact_id_list)).all()
        users_dict = {user.id: user for user in users_query}
        
        # 一次性查询所有最新消息时间
        latest_messages = db.query(
            case(
                (Message.sender_id == current_user.id, Message.receiver_id),
                else_=Message.sender_id
            ).label('contact_id'),
            func.max(Message.created_at).label('last_message_time')
        ).filter(
            ((Message.sender_id == current_user.id) & (Message.receiver_id.in_(contact_id_list))) |
            ((Message.receiver_id == current_user.id) & (Message.sender_id.in_(contact_id_list)))
        ).group_by(
            case(
                (Message.sender_id == current_user.id, Message.receiver_id),
                else_=Message.sender_id
            )
        ).all()
        
        # 确保时间格式正确，添加时区信息
        latest_messages_dict = {}
        for msg in latest_messages:
            if msg.last_message_time:
                # 确保时间是UTC格式，添加Z后缀
                if msg.last_message_time.tzinfo is None:
                    # 假设是UTC时间，添加时区信息
                    utc_time = msg.last_message_time.replace(tzinfo=timezone.utc)
                else:
                    utc_time = msg.last_message_time.astimezone(timezone.utc)
                latest_messages_dict[msg.contact_id] = format_iso_utc(utc_time)
            else:
                latest_messages_dict[msg.contact_id] = None
        
        # 构建联系人信息
        contacts_with_last_message = []
        for contact_id in contact_id_list:
            user = users_dict.get(contact_id)
            if user:
                contact_info = {
                    "id": user.id,
                    "name": getattr(user, 'name', None) or f"用户{user.id}",
                    "avatar": getattr(user, 'avatar', None) or "/static/avatar1.png",
                    "email": getattr(user, 'email', None),
                    "user_level": 1,  # 默认等级
                    "task_count": 0,
                    "avg_rating": 0.0,
                    "last_message_time": latest_messages_dict.get(contact_id),
                    "is_verified": False
                }
                contacts_with_last_message.append(contact_info)
                print(f"DEBUG: 添加联系人: {contact_info['name']} (ID: {contact_info['id']})")
        
        # 按最新消息时间排序
        contacts_with_last_message.sort(
            key=lambda x: x["last_message_time"] or "1970-01-01T00:00:00", 
            reverse=True
        )

        print(f"DEBUG: 成功获取 {len(contacts_with_last_message)} 个联系人")
        return contacts_with_last_message
        
    except Exception as e:
        print(f"DEBUG: contacts API发生错误: {e}")
        import traceback
        traceback.print_exc()
        return []


@router.get("/users/shared-tasks/{other_user_id}")
def get_shared_tasks(
    other_user_id: str,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """获取当前用户与指定用户之间的共同任务"""
    from app.models import Task

    # 查找当前用户和对方用户都参与的任务
    # 任务状态为 'taken' 或 'pending_confirmation' 或 'completed'
    shared_tasks = (
        db.query(Task)
        .filter(
            Task.status.in_(["taken", "pending_confirmation", "completed"]),
            ((Task.poster_id == current_user.id) & (Task.taker_id == other_user_id))
            | ((Task.poster_id == other_user_id) & (Task.taker_id == current_user.id)),
        )
        .order_by(Task.created_at.desc())
        .all()
    )

    return [
        {
            "id": task.id,
            "title": task.title,
            "status": task.status,
            "created_at": task.created_at,
            "reward": float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0,
            "task_type": task.task_type,
            "is_poster": task.poster_id == current_user.id,
        }
        for task in shared_tasks
    ]


@router.get("/admin/cancel-requests", response_model=list[schemas.TaskCancelRequestOut])
def admin_get_cancel_requests(
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
    status: str = None,
):
    """管理员获取任务取消请求列表"""
    requests = crud.get_task_cancel_requests(db, status)
    return requests


@router.post("/admin/cancel-requests/{request_id}/review")
def admin_review_cancel_request(
    request_id: int,
    review: schemas.TaskCancelRequestReview,
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员审核任务取消请求"""
    cancel_request = crud.get_task_cancel_request_by_id(db, request_id)
    if not cancel_request:
        raise HTTPException(status_code=404, detail="Cancel request not found")

    if cancel_request.status != "pending":
        raise HTTPException(status_code=400, detail="Request has already been reviewed")

    # 更新请求状态（管理员审核）
    updated_request = crud.update_task_cancel_request(
        db, request_id, review.status, current_user.id, review.admin_comment, reviewer_type='admin'
    )

    # 如果审核通过，实际取消任务
    if review.status == "approved":
        task = crud.get_task(db, cancel_request.task_id)
        if task:
            # 实际取消任务
            crud.cancel_task(
                db,
                cancel_request.task_id,
                cancel_request.requester_id,
                is_admin_review=True,
            )

            # 通知请求者
            crud.create_notification(
                db,
                cancel_request.requester_id,
                "cancel_request_approved",
                "取消请求已通过",
                f'您的任务 "{task.title}" 取消请求已通过审核',
                task.id,
            )

            # 通知另一方（发布者或接受者）
            other_user_id = (
                task.poster_id
                if cancel_request.requester_id == task.taker_id
                else task.taker_id
            )
            if other_user_id:
                crud.create_notification(
                    db,
                    other_user_id,
                    "task_cancelled",
                    "任务已取消",
                    f'任务 "{task.title}" 已被取消',
                    task.id,
                )

    elif review.status == "rejected":
        # 通知请求者
        task = crud.get_task(db, cancel_request.task_id)
        if task:
            crud.create_notification(
                db,
                cancel_request.requester_id,
                "cancel_request_rejected",
                "取消请求被拒绝",
                f'您的任务 "{task.title}" 取消请求被拒绝，原因：{review.admin_comment or "无"}',
                task.id,
            )

    return {"message": f"Cancel request {review.status}", "request": updated_request}


@router.post("/user/customer-service/assign")
def assign_customer_service(
    current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    """用户分配客服（使用排队系统）"""
    try:
        from app.models import CustomerService, CustomerServiceChat, CustomerServiceQueue
        from app.utils.time_utils import get_utc_time, format_iso_utc
        
        # 1. 检查用户是否已有未结束的对话
        existing_chat = (
            db.query(CustomerServiceChat)
            .filter(
                CustomerServiceChat.user_id == current_user.id,
                CustomerServiceChat.is_ended == 0
            )
            .first()
        )
        
        if existing_chat:
            # 返回现有对话
            service = db.query(CustomerService).filter(
                CustomerService.id == existing_chat.service_id
            ).first()
            
            if service:
                return {
                    "service": {
                        "id": service.id,
                        "name": service.name,
                        "avatar": "/static/service.png",
                        "avg_rating": service.avg_rating,
                        "total_ratings": service.total_ratings,
                    },
                    "chat": {
                        "chat_id": existing_chat.chat_id,
                        "user_id": existing_chat.user_id,
                        "service_id": existing_chat.service_id,
                        "is_ended": existing_chat.is_ended,
                        "created_at": format_iso_utc(existing_chat.created_at) if existing_chat.created_at else None,
                        "total_messages": existing_chat.total_messages or 0,
                    },
                }
        
        # 2. 检查是否有在线客服
        # 使用类型转换确保正确匹配，兼容数据库中可能存在的不同类型
        from sqlalchemy import cast, Integer
        services = (
            db.query(CustomerService)
            .filter(cast(CustomerService.is_online, Integer) == 1)
            .all()
        )
        
        # 如果数据库查询没有结果，使用备用方法：在Python层面检查
        if not services:
            all_services = db.query(CustomerService).all()
            logger.info(f"[CUSTOMER_SERVICE] 数据库查询无结果，使用Python层面检查，总客服数量={len(all_services)}")
            # 在Python层面检查在线客服（兼容不同的数据类型）
            services = []
            for s in all_services:
                if s.is_online:
                    # 转换为整数进行比较
                    is_online_value = int(s.is_online) if s.is_online else 0
                    if is_online_value == 1:
                        services.append(s)
                        logger.info(f"[CUSTOMER_SERVICE] 发现在线客服（Python层面）: {s.id}, is_online={s.is_online}")
        
        if not services:
            # 没有可用客服时，将用户加入排队队列
            queue_info = crud.add_user_to_customer_service_queue(db, current_user.id)
            return {
                "error": "no_available_service",
                "message": "暂无在线客服，已加入排队队列",
                "queue_status": queue_info,
                "system_message": {
                    "content": "目前没有可用的客服，您已加入排队队列。系统将尽快为您分配客服，请稍候。"
                },
            }
        
        # 3. 尝试立即分配（如果有可用客服且负载未满）
        import random
        from sqlalchemy import func
        
        # 计算每个客服的当前负载
        service_loads = []
        for service in services:
            active_chats = (
                db.query(func.count(CustomerServiceChat.chat_id))
                .filter(
                    CustomerServiceChat.service_id == service.id,
                    CustomerServiceChat.is_ended == 0
                )
                .scalar() or 0
            )
            max_concurrent = getattr(service, 'max_concurrent_chats', 5) or 5
            if active_chats < max_concurrent:
                service_loads.append((service, active_chats))
        
        if service_loads:
            # 选择负载最低的客服
            service_loads.sort(key=lambda x: x[1])
            service = service_loads[0][0]
            
            # 创建对话
            chat_data = crud.create_customer_service_chat(db, current_user.id, service.id)
            
            # 向客服发送用户连接通知
            try:
                import asyncio
                import json
                from app.main import active_connections
                
                if service.id in active_connections:
                    notification_message = {
                        "type": "user_connected",
                        "user_info": {
                            "id": current_user.id,
                            "name": current_user.name or f"用户{current_user.id}",
                        },
                        "chat_id": chat_data["chat_id"],
                        "timestamp": format_iso_utc(get_utc_time()),
                    }
                    asyncio.create_task(
                        active_connections[service.id].send_text(
                            json.dumps(notification_message)
                        )
                    )
            except Exception as e:
                logger.error(f"发送客服通知失败: {e}")
            
            return {
                "service": {
                    "id": service.id,
                    "name": service.name,
                    "avatar": "/static/service.png",
                    "avg_rating": service.avg_rating,
                    "total_ratings": service.total_ratings,
                },
                "chat": {
                    "chat_id": chat_data["chat_id"],
                    "user_id": chat_data["user_id"],
                    "service_id": chat_data["service_id"],
                    "is_ended": chat_data["is_ended"],
                    "created_at": chat_data["created_at"],
                    "total_messages": chat_data["total_messages"],
                },
            }
        else:
            # 所有客服都满载，加入排队队列
            queue_info = crud.add_user_to_customer_service_queue(db, current_user.id)
            return {
                "error": "all_services_busy",
                "message": "所有客服都在忙碌中，已加入排队队列",
                "queue_status": queue_info,
                "system_message": {
                    "content": "所有客服都在忙碌中，您已加入排队队列。系统将尽快为您分配客服，请稍候。"
                },
            }
            
    except Exception as e:
        logger.error(f"客服会话分配错误: {e}", exc_info=True)
        db.rollback()
        raise HTTPException(status_code=500, detail=f"客服会话分配失败: {str(e)}")


@router.get("/user/customer-service/queue-status")
def get_customer_service_queue_status(
    current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    """获取用户在客服排队队列中的状态"""
    queue_status = crud.get_user_queue_status(db, current_user.id)
    return queue_status


# 客服在线状态管理
@router.post("/customer-service/online")
def set_customer_service_online(
    current_user=Depends(get_current_service), db: Session = Depends(get_sync_db)
):
    """设置客服为在线状态"""
    logger.info(f"[CUSTOMER_SERVICE] 设置客服在线状态: {current_user.id}")
    logger.info(f"[CUSTOMER_SERVICE] 当前在线状态: {current_user.is_online}")
    
    try:
        current_user.is_online = 1
        db.commit()
        logger.info(f"[CUSTOMER_SERVICE] 客服在线状态设置成功: {current_user.id}")
        
        # 验证更新是否成功
        db.refresh(current_user)
        logger.info(f"[CUSTOMER_SERVICE] 验证更新后状态: {current_user.is_online}")
        
        return {"message": "客服已设置为在线状态", "is_online": current_user.is_online}
    except Exception as e:
        logger.error(f"[CUSTOMER_SERVICE] 设置在线状态失败: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"设置在线状态失败: {str(e)}")


@router.post("/customer-service/offline")
def set_customer_service_offline(
    current_user=Depends(get_current_service), db: Session = Depends(get_sync_db)
):
    """设置客服为离线状态"""
    logger.info(f"[CUSTOMER_SERVICE] 设置客服离线状态: {current_user.id}")
    logger.info(f"[CUSTOMER_SERVICE] 当前在线状态: {current_user.is_online}")
    
    try:
        current_user.is_online = 0
        db.commit()
        logger.info(f"[CUSTOMER_SERVICE] 客服离线状态设置成功: {current_user.id}")
        
        # 验证更新是否成功
        db.refresh(current_user)
        logger.info(f"[CUSTOMER_SERVICE] 验证更新后状态: {current_user.is_online}")
        
        return {"message": "客服已设置为离线状态", "is_online": current_user.is_online}
    except Exception as e:
        logger.error(f"[CUSTOMER_SERVICE] 设置离线状态失败: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"设置离线状态失败: {str(e)}")


@router.post("/logout")
def logout(response: Response):
    """用户登出端点"""
    # 清除HttpOnly Cookie
    from app.security import clear_secure_cookies
    clear_secure_cookies(response)
    return {"message": "登出成功"}

# 旧的客服登出路由已删除，请使用 /api/customer-service/logout (在 cs_auth_routes.py 中)

@router.get("/customer-service/status")
def get_customer_service_status(
    current_user=Depends(get_current_service), db: Session = Depends(get_sync_db)
):
    """获取客服在线状态和名字"""
    # 使用新的客服对话系统获取评分数据
    from sqlalchemy import func

    from app.models import CustomerServiceChat

    ratings_result = (
        db.query(
            func.avg(CustomerServiceChat.user_rating).label("avg_rating"),
            func.count(CustomerServiceChat.user_rating).label("total_ratings"),
        )
        .filter(
            CustomerServiceChat.service_id == current_user.id,
            CustomerServiceChat.user_rating.isnot(None),
        )
        .first()
    )

    # 获取实时评分数据
    real_time_avg_rating = (
        float(ratings_result.avg_rating)
        if ratings_result and ratings_result.avg_rating is not None
        else 0.0
    )
    real_time_total_ratings = (
        int(ratings_result.total_ratings)
        if ratings_result and ratings_result.total_ratings is not None
        else 0
    )

    # 更新数据库中的评分数据
    current_user.avg_rating = real_time_avg_rating
    current_user.total_ratings = real_time_total_ratings
    db.commit()

    return {
        "is_online": current_user.is_online == 1,
        "service": {
            "id": current_user.id,  # 数据库已经存储格式化ID
            "name": current_user.name,
            "avg_rating": real_time_avg_rating,
            "total_ratings": real_time_total_ratings,
        },
    }


@router.get("/customer-service/check-availability")
def check_customer_service_availability(db: Session = Depends(get_sync_db)):
    """检查是否有在线客服可用"""
    from app.models import CustomerService

    # 查询在线客服数量
    try:
        # 使用类型转换确保正确匹配，兼容数据库中可能存在的不同类型
        from sqlalchemy import cast, Integer
        online_services = (
            db.query(CustomerService)
            .filter(cast(CustomerService.is_online, Integer) == 1)
            .count()
        )
        
        # 添加调试日志
        logger.info(f"[CUSTOMER_SERVICE] 查询在线客服: 标准查询结果={online_services}")
        
        # 如果查询结果为0，使用备用方法：在Python层面检查
        if online_services == 0:
            all_services = db.query(CustomerService).all()
            logger.info(f"[CUSTOMER_SERVICE] 调试信息: 总客服数量={len(all_services)}")
            # 在Python层面检查在线客服（兼容不同的数据类型）
            python_online_count = 0
            for s in all_services:
                logger.info(f"[CUSTOMER_SERVICE] 客服 {s.id}: is_online={s.is_online} (type: {type(s.is_online).__name__})")
                # 检查is_online是否为真值（兼容1, '1', True等）
                if s.is_online:
                    # 转换为整数进行比较
                    is_online_value = int(s.is_online) if s.is_online else 0
                    if is_online_value == 1:
                        python_online_count += 1
                        logger.info(f"[CUSTOMER_SERVICE] 发现在线客服（Python层面）: {s.id}, is_online={s.is_online}")
            
            # 如果Python层面发现有在线客服，使用该结果
            if python_online_count > 0:
                logger.warning(f"[CUSTOMER_SERVICE] 数据库查询返回0，但Python层面发现{python_online_count}个在线客服，使用Python层面结果")
                online_services = python_online_count
    except Exception as e:
        logger.error(f"[CUSTOMER_SERVICE] 查询客服可用性失败: {e}", exc_info=True)
        online_services = 0

    return {
        "available": online_services > 0,
        "online_count": online_services,
        "message": (
            f"当前有 {online_services} 个客服在线"
            if online_services > 0
            else "当前无客服在线"
        ),
    }


# 客服管理相关接口
@router.get("/customer-service/chats")
def get_customer_service_chats(
    current_user=Depends(get_current_service), db: Session = Depends(get_sync_db)
):
    """获取分配给当前客服的用户对话列表"""
    chats = crud.get_service_customer_service_chats(db, current_user.id)

    # 获取用户信息和未读消息数量
    user_chats = []
    for chat in chats:
        user = db.query(User).filter(User.id == chat["user_id"]).first()
        if user:
            # 计算未读消息数量
            unread_count = crud.get_unread_customer_service_messages_count(
                db, chat["chat_id"], current_user.id
            )

            user_chats.append(
                {
                    "chat_id": chat["chat_id"],
                    "user_id": user.id,
                    "user_name": user.name,
                    "user_avatar": user.avatar or "/static/avatar1.png",
                    "created_at": chat["created_at"],  # 已经在 crud 中格式化了
                    "last_message_at": chat["last_message_at"],  # 已经在 crud 中格式化了
                    "is_ended": chat["is_ended"],
                    "total_messages": chat["total_messages"],
                    "unread_count": unread_count,
                    "user_rating": chat["user_rating"],
                    "user_comment": chat["user_comment"],
                }
            )

    return user_chats


@router.get("/customer-service/chats/{chat_id}/messages")
def get_customer_service_messages(
    chat_id: str,
    current_user=Depends(get_current_service),
    db: Session = Depends(get_db),
):
    """获取客服对话消息（仅限分配给该客服的对话）"""
    # 验证chat_id是否属于当前客服
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat or chat["service_id"] != current_user.id:
        raise HTTPException(status_code=404, detail="Chat not found or not authorized")

    # 获取对话消息
    messages = crud.get_customer_service_messages(db, chat_id)

    return messages


@router.post("/user/customer-service/chats/{chat_id}/messages/{message_id}/mark-read")
def mark_customer_service_message_read(
    chat_id: str,
    message_id: int,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """标记单条消息为已读"""
    # 验证chat_id是否属于当前用户
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat or chat["user_id"] != current_user.id:
        raise HTTPException(status_code=404, detail="Chat not found or not authorized")
    
    # 标记消息为已读
    success = crud.mark_customer_service_message_read(db, message_id)
    if not success:
        raise HTTPException(status_code=400, detail="Failed to mark message as read")
    
    return {"message": "Message marked as read", "message_id": message_id}


@router.post("/customer-service/chats/{chat_id}/mark-read")
def mark_customer_service_messages_read(
    chat_id: str,
    current_user=Depends(get_current_service),
    db: Session = Depends(get_db),
):
    """标记客服对话消息为已读"""
    # 验证chat_id是否属于当前客服
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat or chat["service_id"] != current_user.id:
        raise HTTPException(status_code=404, detail="Chat not found or not authorized")

    # 标记消息为已读
    marked_count = crud.mark_customer_service_messages_read(
        db, chat_id, current_user.id
    )

    return {"message": "Messages marked as read", "marked_count": marked_count}


@router.post("/customer-service/chats/{chat_id}/messages")
@rate_limit("send_message")
def send_customer_service_message(
    chat_id: str,
    message_data: dict = Body(...),
    current_user=Depends(get_current_service),
    request: Request = None,
    background_tasks: BackgroundTasks = BackgroundTasks(),
    db: Session = Depends(get_db),
):
    """客服发送消息给用户"""
    # 验证chat_id是否属于当前客服且未结束
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat or chat["service_id"] != current_user.id:
        raise HTTPException(status_code=404, detail="Chat not found or not authorized")

    if chat["is_ended"] == 1:
        raise HTTPException(status_code=400, detail="Chat has ended")

    # 保存消息
    message = crud.save_customer_service_message(
        db,
        chat_id,
        current_user.id,
        "customer_service",
        message_data.get("content", ""),
    )

    # 通过WebSocket实时推送给用户（使用后台任务异步发送）
    async def send_websocket_message():
        try:
            from app.main import active_connections
            user_ws = active_connections.get(chat["user_id"])
            if user_ws:
                # 构建消息响应
                message_response = {
                    "from": current_user.id,
                    "receiver_id": chat["user_id"],
                    "content": message["content"],
                    "created_at": str(message["created_at"]),
                    "sender_type": "customer_service",
                    "original_sender_id": current_user.id,
                    "chat_id": chat_id,
                    "message_id": message["id"],
                }
                try:
                    await user_ws.send_text(json.dumps(message_response))
                    logger.info(f"Customer service message sent to user {chat['user_id']} via WebSocket")
                except Exception as ws_error:
                    logger.error(f"Failed to send WebSocket message to user {chat['user_id']}: {ws_error}")
                    # 如果连接失败，从活跃连接中移除
                    active_connections.pop(chat["user_id"], None)
        except Exception as e:
            # WebSocket推送失败不应该影响消息发送
            logger.error(f"Failed to push message via WebSocket: {e}")
    
    background_tasks.add_task(send_websocket_message)

    # 注意：不再在每次发送消息时创建通知
    # 通知只在用户快被自动超时结束的时候才创建（在send_timeout_warnings中实现）

    return message


# 结束对话和评分相关接口
@router.post("/user/customer-service/chats/{chat_id}/end")
@rate_limit("end_chat")
def end_customer_service_chat_user(
    chat_id: str, current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    """用户结束客服对话"""
    # 验证chat_id是否存在且用户有权限
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat:
        raise HTTPException(status_code=404, detail="Chat not found")

    # 检查权限：只有对话的用户可以结束对话
    if chat["user_id"] != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to end this chat")

    # 检查对话状态
    if chat["is_ended"] == 1:
        raise HTTPException(status_code=400, detail="Chat already ended")

    # 结束对话，记录结束原因
    success = crud.end_customer_service_chat(
        db, 
        chat_id,
        reason="user_ended",
        ended_by=current_user.id,
        ended_type="manual"
    )
    if not success:
        raise HTTPException(status_code=500, detail="Failed to end chat")

    return {"message": "Chat ended successfully"}

@router.post("/customer-service/chats/{chat_id}/end")
@rate_limit("end_chat")
def end_customer_service_chat(
    chat_id: str, current_user=Depends(get_current_customer_service_or_user), db: Session = Depends(get_db)
):
    """结束客服对话"""
    # 验证chat_id是否存在且用户有权限
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat:
        raise HTTPException(status_code=404, detail="Chat not found")

    # 检查权限：只有对话的用户或客服可以结束对话
    if chat["user_id"] != current_user.id and chat["service_id"] != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to end this chat")

    # 检查对话状态
    if chat["is_ended"] == 1:
        raise HTTPException(status_code=400, detail="Chat already ended")

    # 判断结束者类型
    if chat["service_id"] == current_user.id:
        # 客服结束
        ended_by = f"service_{current_user.id}"
        reason = "service_ended"
    else:
        # 用户结束
        ended_by = current_user.id
        reason = "user_ended"

    # 结束对话，记录结束原因
    success = crud.end_customer_service_chat(
        db, 
        chat_id,
        reason=reason,
        ended_by=ended_by,
        ended_type="manual"
    )
    if not success:
        raise HTTPException(status_code=500, detail="Failed to end chat")

    return {"message": "Chat ended successfully"}


@router.post("/user/customer-service/chats/{chat_id}/rate")
@rate_limit("rate_service")
def rate_customer_service(
    chat_id: str,
    rating_data: schemas.CustomerServiceRating,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """用户对客服评分"""
    # 验证chat_id是否存在且用户有权限
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat:
        raise HTTPException(status_code=404, detail="Chat not found")

    # 检查权限：只有对话的用户可以评分
    if chat["user_id"] != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to rate this chat")

    # 检查对话状态
    if chat["is_ended"] != 1:
        raise HTTPException(status_code=400, detail="Can only rate ended chats")

    # 检查是否已经评分
    if chat["user_rating"] is not None:
        raise HTTPException(status_code=400, detail="Chat already rated")

    # 保存评分
    success = crud.rate_customer_service_chat(
        db, chat_id, rating_data.rating, rating_data.comment
    )
    if not success:
        raise HTTPException(status_code=500, detail="Failed to save rating")

    # 更新客服的平均评分
    service = (
        db.query(CustomerService)
        .filter(CustomerService.id == chat["service_id"])
        .first()
    )
    if service:
        # 计算该客服的所有评分
        from sqlalchemy import func

        from app.models import CustomerServiceChat

        ratings_result = (
            db.query(
                func.avg(CustomerServiceChat.user_rating).label("avg_rating"),
                func.count(CustomerServiceChat.user_rating).label("total_ratings"),
            )
            .filter(
                CustomerServiceChat.service_id == chat["service_id"],
                CustomerServiceChat.user_rating.isnot(None),
            )
            .first()
        )

        if ratings_result and ratings_result.avg_rating is not None:
            # 更新客服的平均评分和总评分数量
            service.avg_rating = float(ratings_result.avg_rating)
            service.total_ratings = int(ratings_result.total_ratings)
            db.commit()

    return {"message": "Rating submitted successfully"}


@router.get("/user/customer-service/chats")
def get_my_customer_service_chats(
    current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    """获取用户的客服对话历史"""
    chats = crud.get_user_customer_service_chats(db, current_user.id)
    return chats


@router.get("/user/customer-service/chats/{chat_id}/messages")
def get_customer_service_chat_messages(
    chat_id: str, current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    """获取客服对话消息（用户端）"""
    # 验证chat_id是否属于当前用户
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat or chat["user_id"] != current_user.id:
        raise HTTPException(status_code=404, detail="Chat not found or not authorized")

    # 获取对话消息
    messages = crud.get_customer_service_messages(db, chat_id)

    return messages


@router.post("/user/customer-service/chats/{chat_id}/messages")
@rate_limit("send_message")
def send_customer_service_chat_message(
    chat_id: str,
    message_data: dict = Body(...),
    current_user=Depends(get_current_user_secure_sync_csrf),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """用户发送消息到客服对话"""
    # 验证chat_id是否属于当前用户且未结束
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat or chat["user_id"] != current_user.id:
        raise HTTPException(status_code=404, detail="Chat not found or not authorized")

    if chat["is_ended"] == 1:
        raise HTTPException(status_code=400, detail="Chat has ended")

    # 保存消息
    message = crud.save_customer_service_message(
        db, chat_id, current_user.id, "user", message_data.get("content", "")
    )

    # 注意：不创建通知给客服，因为客服ID不在users表中
    # 客服可以通过WebSocket实时接收消息通知
    # crud.create_notification(
    #     db,
    #     chat['service_id'],
    #     "message",
    #     "新消息",
    #     f"用户 {current_user.name} 给您发来一条消息",
    #     current_user.id
    # )

    return message


# 客服对话文件上传接口
@router.post("/user/customer-service/chats/{chat_id}/files")
@rate_limit("upload_file")
async def upload_customer_service_chat_file(
    chat_id: str,
    file: UploadFile = File(...),
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    用户上传文件到客服对话
    支持图片和文档文件
    - 图片：jpg, jpeg, png, gif, webp（最大5MB）
    - 文档：pdf, doc, docx, txt（最大10MB）
    """
    # 验证chat_id是否属于当前用户且未结束
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat or chat["user_id"] != current_user.id:
        raise HTTPException(status_code=404, detail="Chat not found or not authorized")
    
    if chat["is_ended"] == 1:
        raise HTTPException(status_code=400, detail="Chat has ended")
    
    try:
        # 读取文件内容（流式读取，避免大文件占内存）
        content = await file.read()
        file_size = len(content)
        
        # 验证文件类型和大小
        # 使用智能扩展名检测（支持从 filename、Content-Type 或 magic bytes 检测）
        from app.file_utils import get_file_extension_from_upload
        file_ext = get_file_extension_from_upload(file, content=content)
        
        # 如果无法检测到扩展名
        if not file_ext:
            raise HTTPException(
                status_code=400,
                detail="无法检测文件类型，请确保上传的是有效的文件（图片或文档）"
            )
        
        # 检查是否为危险文件类型
        if file_ext in DANGEROUS_EXTENSIONS:
            raise HTTPException(status_code=400, detail=f"不允许上传 {file_ext} 类型的文件")
        
        # 判断文件类型（图片或文档）
        is_image = file_ext in ALLOWED_EXTENSIONS
        is_document = file_ext in {".pdf", ".doc", ".docx", ".txt"}
        
        if not (is_image or is_document):
            raise HTTPException(
                status_code=400,
                detail=f"不支持的文件类型。允许的类型: 图片({', '.join(ALLOWED_EXTENSIONS)}), 文档(pdf, doc, docx, txt)"
            )
        
        # 验证文件大小
        max_size = MAX_FILE_SIZE if is_image else MAX_FILE_SIZE_LARGE
        if file_size > max_size:
            size_mb = max_size / (1024 * 1024)
            raise HTTPException(
                status_code=413,
                detail=f"文件大小不能超过 {size_mb}MB"
            )
        
        # 使用私密文件系统上传
        from app.file_system import private_file_system
        result = private_file_system.upload_file(
            content, 
            file.filename, 
            current_user.id, 
            db, 
            task_id=None, 
            chat_id=chat_id,
            content_type=file.content_type
        )
        
        # 生成签名URL
        from app.signed_url import signed_url_manager
        file_path_for_url = f"files/{result['filename']}"
        file_url = signed_url_manager.generate_signed_url(
            file_path=file_path_for_url,
            user_id=current_user.id,
            expiry_minutes=15,  # 15分钟过期
            one_time=False  # 可以多次使用
        )
        
        return {
            "success": True,
            "url": file_url,
            "file_id": result["file_id"],
            "filename": result["filename"],
            "size": result["size"],
            "original_name": result["original_filename"],
            "file_type": "image" if is_image else "document",
            "chat_id": chat_id
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"客服对话文件上传失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")


@router.post("/customer-service/chats/{chat_id}/files")
@rate_limit("upload_file")
async def upload_customer_service_file(
    chat_id: str,
    file: UploadFile = File(...),
    current_user=Depends(get_current_service),
    db: Session = Depends(get_db),
):
    """
    客服上传文件到对话
    支持图片和文档文件
    - 图片：jpg, jpeg, png, gif, webp（最大5MB）
    - 文档：pdf, doc, docx, txt（最大10MB）
    """
    # 验证chat_id是否属于当前客服且未结束
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat or chat["service_id"] != current_user.id:
        raise HTTPException(status_code=404, detail="Chat not found or not authorized")
    
    if chat["is_ended"] == 1:
        raise HTTPException(status_code=400, detail="Chat has ended")
    
    try:
        # 验证文件类型和大小
        if not file.filename:
            raise HTTPException(status_code=400, detail="文件名不能为空")
        
        # 获取文件扩展名
        file_ext = Path(file.filename).suffix.lower()
        
        # 检查是否为危险文件类型
        if file_ext in DANGEROUS_EXTENSIONS:
            raise HTTPException(status_code=400, detail=f"不允许上传 {file_ext} 类型的文件")
        
        # 判断文件类型（图片或文档）
        is_image = file_ext in ALLOWED_EXTENSIONS
        is_document = file_ext in {".pdf", ".doc", ".docx", ".txt"}
        
        if not (is_image or is_document):
            raise HTTPException(
                status_code=400,
                detail=f"不支持的文件类型。允许的类型: 图片({', '.join(ALLOWED_EXTENSIONS)}), 文档(pdf, doc, docx, txt)"
            )
        
        # 读取文件内容（流式读取，避免大文件占内存）
        content = await file.read()
        file_size = len(content)
        
        # 验证文件大小
        max_size = MAX_FILE_SIZE if is_image else MAX_FILE_SIZE_LARGE
        if file_size > max_size:
            size_mb = max_size / (1024 * 1024)
            raise HTTPException(
                status_code=413,
                detail=f"文件大小不能超过 {size_mb}MB"
            )
        
        # 使用私密文件系统上传
        from app.file_system import private_file_system
        result = private_file_system.upload_file(
            content, 
            file.filename, 
            current_user.id, 
            db, 
            task_id=None, 
            chat_id=chat_id,
            content_type=file.content_type
        )
        
        # 生成签名URL
        from app.signed_url import signed_url_manager
        file_path_for_url = f"files/{result['filename']}"
        file_url = signed_url_manager.generate_signed_url(
            file_path=file_path_for_url,
            user_id=chat["user_id"],  # 使用用户ID生成URL，因为客服ID不在users表中
            expiry_minutes=15,  # 15分钟过期
            one_time=False  # 可以多次使用
        )
        
        return {
            "success": True,
            "url": file_url,
            "file_id": result["file_id"],
            "filename": result["filename"],
            "size": result["size"],
            "original_name": result["original_filename"],
            "file_type": "image" if is_image else "document",
            "chat_id": chat_id
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"客服文件上传失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")


@router.get("/customer-service/{service_id}/rating")
@measure_api_performance("get_customer_service_rating")
@cache_response(ttl=300, key_prefix="cs_rating")  # 缓存5分钟
def get_customer_service_rating(service_id: str, db: Session = Depends(get_db)):
    """获取客服的平均评分信息"""
    service = db.query(CustomerService).filter(CustomerService.id == service_id).first()
    if not service:
        raise HTTPException(status_code=404, detail="Customer service not found")

    return {
        "service_id": service.id,
        "service_name": service.name,
        "avg_rating": service.avg_rating,
        "total_ratings": service.total_ratings,
    }


@router.get("/customer-service/all-ratings")
@measure_api_performance("get_all_customer_service_ratings")
@cache_response(ttl=300, key_prefix="cs_all_ratings")  # 缓存5分钟
def get_all_customer_service_ratings(db: Session = Depends(get_db)):
    """获取所有客服的平均评分信息"""
    services = db.query(CustomerService).all()

    return [
        {
            "service_id": service.id,
            "service_name": service.name,
            "avg_rating": service.avg_rating,
            "total_ratings": service.total_ratings,
            "is_online": service.is_online == 1,
        }
        for service in services
    ]


@router.get("/customer-service/cancel-requests")
def cs_get_cancel_requests(
    current_user=Depends(get_current_service),
    db: Session = Depends(get_db),
    status: str = None,
):
    """
    客服获取任务取消请求列表
    
    权限说明：客服只能审核任务取消请求，这是客服的唯一管理权限。
    其他管理操作需要通过 /customer-service/admin-requests 向管理员请求。
    """
    from app.models import TaskCancelRequest, Task, User
    
    requests = crud.get_task_cancel_requests(db, status)
    
    # 为每个请求添加任务信息和用户身份
    result = []
    for req in requests:
        task = crud.get_task(db, req.task_id)
        requester = crud.get_user_by_id(db, req.requester_id)
        
        # 判断请求者是发布者还是接收者
        is_poster = task and task.poster_id == req.requester_id
        is_taker = task and task.taker_id == req.requester_id
        
        result.append({
            "id": req.id,
            "task_id": req.task_id,
            "requester_id": req.requester_id,
            "requester_name": requester.name if requester else "未知用户",
            "reason": req.reason,
            "status": req.status,
            "admin_id": req.admin_id,  # 管理员ID（格式：A0001）
            "service_id": req.service_id,  # 客服ID（格式：CS8888）
            "admin_comment": req.admin_comment,
            "created_at": req.created_at,
            "reviewed_at": req.reviewed_at,
            "task": {
                "id": task.id if task else None,
                "title": task.title if task else "任务已删除",
                "status": task.status if task else "deleted",
                "poster_id": task.poster_id if task else None,
                "taker_id": task.taker_id if task else None,
            },
            "user_role": "发布者" if is_poster else ("接收者" if is_taker else "未知")
        })
    
    return result


@router.post("/customer-service/cancel-requests/{request_id}/review")
def cs_review_cancel_request(
    request_id: int,
    review: schemas.TaskCancelRequestReview,
    current_user=Depends(get_current_service),
    db: Session = Depends(get_db),
):
    """
    客服审核任务取消请求
    
    权限说明：
    - 这是客服的唯一管理权限，可以审核通过或拒绝任务取消请求
    - 客服不能直接操作任务（删除、修改等）
    - 客服不能操作用户账户（封禁、暂停等）
    - 其他管理操作需要通过 /customer-service/admin-requests 向管理员请求
    """
    cancel_request = crud.get_task_cancel_request_by_id(db, request_id)
    if not cancel_request:
        raise HTTPException(status_code=404, detail="Cancel request not found")

    if cancel_request.status != "pending":
        raise HTTPException(status_code=400, detail="Request has already been reviewed")

    # 更新请求状态（客服审核）
    updated_request = crud.update_task_cancel_request(
        db, request_id, review.status, current_user.id, review.admin_comment, reviewer_type='service'
    )

    if review.status == "approved":
        task = crud.get_task(db, cancel_request.task_id)
        if task:
            # 实际取消任务
            crud.cancel_task(
                db,
                cancel_request.task_id,
                cancel_request.requester_id,
                is_admin_review=True,
            )

            # 通知请求者
            crud.create_notification(
                db,
                cancel_request.requester_id,
                "cancel_request_approved",
                "取消请求已通过",
                f'您的任务 "{task.title}" 取消请求已通过审核',
                task.id,
            )

            # 通知另一方（发布者或接受者）
            other_user_id = (
                task.poster_id
                if cancel_request.requester_id == task.taker_id
                else task.taker_id
            )
            if other_user_id:
                crud.create_notification(
                    db,
                    other_user_id,
                    "task_cancelled",
                    "任务已取消",
                    f'任务 "{task.title}" 已被取消',
                    task.id,
                )

    elif review.status == "rejected":
        # 通知请求者
        task = crud.get_task(db, cancel_request.task_id)
        if task:
            crud.create_notification(
                db,
                cancel_request.requester_id,
                "cancel_request_rejected",
                "取消请求被拒绝",
                f'您的任务 "{task.title}" 取消请求被拒绝，原因：{review.admin_comment or "无"}',
                task.id,
            )

    return {"message": f"Cancel request {review.status}", "request": updated_request}


# 管理请求相关API
@router.get(
    "/customer-service/admin-requests", response_model=list[schemas.AdminRequestOut]
)
def get_admin_requests(
    current_user=Depends(get_current_service), db: Session = Depends(get_sync_db)
):
    """获取客服提交的管理请求列表"""
    from app.models import AdminRequest

    requests = (
        db.query(AdminRequest)
        .filter(AdminRequest.requester_id == current_user.id)
        .order_by(AdminRequest.created_at.desc())
        .all()
    )
    return requests


@router.post("/customer-service/admin-requests", response_model=schemas.AdminRequestOut)
def create_admin_request(
    request_data: schemas.AdminRequestCreate,
    current_user=Depends(get_current_service),
    db: Session = Depends(get_sync_db),
):
    """
    客服提交管理请求
    
    权限说明：
    - 客服只有审核取消任务请求的权限
    - 对于其他管理操作（如删除任务、封禁用户等），客服必须通过此接口向管理员请求
    - 管理员会在后台处理这些请求
    """
    from app.models import AdminRequest

    admin_request = AdminRequest(
        requester_id=current_user.id,
        type=request_data.type,
        title=request_data.title,
        description=request_data.description,
        priority=request_data.priority,
    )
    db.add(admin_request)
    db.commit()
    db.refresh(admin_request)
    return admin_request


@router.get(
    "/customer-service/admin-chat", response_model=list[schemas.AdminChatMessageOut]
)
def get_admin_chat_messages(
    current_user=Depends(get_current_service), db: Session = Depends(get_sync_db)
):
    """获取与后台工作人员的聊天记录"""
    from app.models import AdminChatMessage

    messages = (
        db.query(AdminChatMessage).order_by(AdminChatMessage.created_at.asc()).all()
    )
    return messages


@router.post("/customer-service/admin-chat", response_model=schemas.AdminChatMessageOut)
def send_admin_chat_message(
    message_data: schemas.AdminChatMessageCreate,
    current_user=Depends(get_current_service),
    db: Session = Depends(get_sync_db),
):
    """客服发送消息给后台工作人员"""
    from app.models import AdminChatMessage

    chat_message = AdminChatMessage(
        sender_id=current_user.id,
        sender_type="customer_service",
        content=message_data.content,
    )
    db.add(chat_message)
    db.commit()
    db.refresh(chat_message)
    return chat_message


# 清理过期会话的后台任务（不自动结束超时对话）


# 管理后台相关API接口
from app.deps import check_admin, check_admin_user_status, check_super_admin


@router.get("/stats")
@measure_api_performance("get_public_stats")
@cache_response(ttl=300, key_prefix="public_stats")  # 缓存5分钟
def get_public_stats(
    db: Session = Depends(get_db)
):
    """获取公开的平台统计数据（仅用户总数）"""
    try:
        # 只返回用户总数，不返回其他敏感信息
        total_users = db.query(models.User).count()
        return {
            "total_users": total_users
        }
    except Exception as e:
        logger.error(f"Error in get_public_stats: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


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
        from app.security import get_client_ip
        client_ip = get_client_ip(request)
        logger.info(f"管理员访问仪表板: {current_admin.username[:3]}*** (IP: {client_ip})")
    try:
        stats = crud.get_dashboard_stats(db)
        return stats
    except Exception as e:
        logger.error(f"Error in get_dashboard_stats: {e}")
        # 生产环境不暴露内部错误信息
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
    from app.security import get_client_ip
    
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


# 员工提醒相关API
@router.post("/admin/staff-notification")
def send_staff_notification(
    notification: schemas.StaffNotificationCreate,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """超级管理员发送员工提醒"""
    # 只有超级管理员才能发送提醒
    if not current_admin.is_super_admin:
        raise HTTPException(
            status_code=403, detail="Only super admin can send staff notifications"
        )

    # 验证接收者是否存在
    if notification.recipient_type == "customer_service":
        recipient = (
            db.query(models.CustomerService)
            .filter(models.CustomerService.id == notification.recipient_id)
            .first()
        )
    elif notification.recipient_type == "admin":
        recipient = (
            db.query(models.AdminUser)
            .filter(models.AdminUser.id == notification.recipient_id)
            .first()
        )
    else:
        raise HTTPException(status_code=400, detail="Invalid recipient type")

    if not recipient:
        raise HTTPException(status_code=404, detail="Recipient not found")

    # 创建提醒
    notification_data = {
        "recipient_id": notification.recipient_id,
        "recipient_type": notification.recipient_type,
        "sender_id": current_admin.id,
        "title": notification.title,
        "content": notification.content,
        "notification_type": notification.notification_type,
    }

    staff_notification = crud.create_staff_notification(db, notification_data)

    return {
        "message": "Staff notification sent successfully",
        "notification": {
            "id": staff_notification.id,
            "recipient_id": staff_notification.recipient_id,
            "recipient_type": staff_notification.recipient_type,
            "title": staff_notification.title,
            "content": staff_notification.content,
            "notification_type": staff_notification.notification_type,
            "created_at": staff_notification.created_at,
        },
    }


@router.get("/staff/notifications")
def get_staff_notifications(
    current_user=Depends(get_current_admin_or_service),
    db: Session = Depends(get_db),
):
    """获取员工提醒列表（所有提醒，已读+未读，限制5条最新）"""
    # 确定用户类型（current_user 可能是 AdminUser 或 CustomerService）
    if isinstance(current_user, models.AdminUser):
        recipient_type = "admin"
        recipient_id = current_user.id
    elif isinstance(current_user, models.CustomerService):
        recipient_type = "customer_service"
        recipient_id = current_user.id
    else:
        # 不应该到达这里，但为了安全起见
        raise HTTPException(status_code=403, detail="无效的用户类型")

    # 获取所有未读提醒 + 5条最新已读提醒
    notifications = crud.get_staff_notifications(db, recipient_id, recipient_type)
    # 获取未读数量
    unread_count = crud.get_unread_staff_notification_count(
        db, recipient_id, recipient_type
    )

    return {
        "notifications": notifications,
        "total": len(notifications),
        "unread_count": unread_count,
    }


@router.get("/staff/notifications/unread")
def get_unread_staff_notifications(
    current_user=Depends(get_current_admin_or_service),
    db: Session = Depends(get_db),
):
    """获取未读员工提醒"""
    # 确定用户类型（current_user 可能是 AdminUser 或 CustomerService）
    if isinstance(current_user, models.AdminUser):
        recipient_type = "admin"
        recipient_id = current_user.id
    elif isinstance(current_user, models.CustomerService):
        recipient_type = "customer_service"
        recipient_id = current_user.id
    else:
        # 不应该到达这里，但为了安全起见
        raise HTTPException(status_code=403, detail="无效的用户类型")

    notifications = crud.get_unread_staff_notifications(
        db, recipient_id, recipient_type
    )
    count = crud.get_unread_staff_notification_count(db, recipient_id, recipient_type)

    return {"notifications": notifications, "unread_count": count}


@router.post("/staff/notifications/{notification_id}/read")
def mark_staff_notification_read(
    notification_id: int,
    current_user=Depends(get_current_admin_or_service),
    db: Session = Depends(get_db),
):
    """标记员工提醒为已读"""
    # 确定用户类型（current_user 可能是 AdminUser 或 CustomerService）
    if isinstance(current_user, models.AdminUser):
        recipient_type = "admin"
        recipient_id = current_user.id
    elif isinstance(current_user, models.CustomerService):
        recipient_type = "customer_service"
        recipient_id = current_user.id
    else:
        # 不应该到达这里，但为了安全起见
        raise HTTPException(status_code=403, detail="无效的用户类型")

    notification = crud.mark_staff_notification_read(
        db, notification_id, recipient_id, recipient_type
    )
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")

    return {"message": "Notification marked as read"}


@router.post("/staff/notifications/read-all")
def mark_all_staff_notifications_read(
    current_user=Depends(get_current_admin_or_service),
    db: Session = Depends(get_db),
):
    """标记所有员工提醒为已读"""
    # 确定用户类型（current_user 可能是 AdminUser 或 CustomerService）
    if isinstance(current_user, models.AdminUser):
        recipient_type = "admin"
        recipient_id = current_user.id
    elif isinstance(current_user, models.CustomerService):
        recipient_type = "customer_service"
        recipient_id = current_user.id
    else:
        # 不应该到达这里，但为了安全起见
        raise HTTPException(status_code=403, detail="无效的用户类型")

    count = crud.mark_all_staff_notifications_read(db, recipient_id, recipient_type)

    return {"message": f"Marked {count} notifications as read"}


@router.post("/admin/customer-service")
def create_customer_service_by_admin(
    cs_data: schemas.AdminCustomerServiceCreate,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """超级管理员创建客服账号"""
    # 检查邮箱是否已存在（在用户表和客服表中）
    existing_user = crud.get_user_by_email(db, cs_data.email)
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already exists")

    existing_cs_email = crud.get_customer_service_by_email(db, cs_data.email)
    if existing_cs_email:
        raise HTTPException(status_code=400, detail="Email already exists")

    # 生成唯一的客服ID
    import random

    from app.id_generator import format_customer_service_id

    while True:
        # 生成4位随机数字
        random_id = random.randint(1000, 9999)
        cs_id = format_customer_service_id(random_id)

        # 检查ID是否已存在
        existing_cs_id = crud.get_customer_service_by_id(db, cs_id)
        if not existing_cs_id:
            break

    # 添加ID到数据中
    cs_data_dict = cs_data.dict()
    cs_data_dict["id"] = cs_id

    # 检查姓名是否已存在（在客服表中）
    from app.models import CustomerService

    existing_cs_name = (
        db.query(CustomerService).filter(CustomerService.name == cs_data.name).first()
    )
    if existing_cs_name:
        raise HTTPException(status_code=400, detail="Name already exists")

    result = crud.create_customer_service_with_login(db, cs_data_dict)
    return {"message": "Customer service created successfully", "data": result}


@router.delete("/admin/customer-service/{cs_id}")
def delete_customer_service_by_admin(
    cs_id: int,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """超级管理员删除客服账号"""
    success = crud.delete_customer_service_by_admin(db, cs_id)
    if not success:
        raise HTTPException(status_code=404, detail="Customer service not found")

    return {"message": "Customer service deleted successfully"}


@router.get("/admin/customer-service")
def get_customer_services_for_admin(
    page: int = 1,
    size: int = 20,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """超级管理员获取客服列表"""
    skip = (page - 1) * size
    result = crud.get_customer_services_for_admin(db, skip=skip, limit=size)

    return {
        "customer_services": result["customer_services"],
        "total": result["total"],
        "page": page,
        "size": size,
    }


@router.post("/admin/notifications/send")
def send_admin_notification(
    notification: schemas.AdminNotificationCreate,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """超级管理员发送通知"""
    notifications = crud.send_admin_notification(
        db,
        notification.user_ids,
        notification.title,
        notification.content,
        notification.type,
    )

    return {
        "message": f"Notification sent to {len(notifications)} users",
        "count": len(notifications),
    }


@router.patch("/admin/tasks/{task_id}")
def update_task_by_admin(
    task_id: int,
    task_update: schemas.AdminTaskUpdate,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """超级管理员更新任务信息"""
    update_data = task_update.dict(exclude_unset=True)
    task = crud.update_task_by_admin(db, task_id, update_data)

    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    return {"message": "Task updated successfully", "task": task}

# 注意：删除任务的路由已在2821行定义（admin_delete_task），这里不再重复定义


@router.post("/admin/customer-service/{cs_id}/notify")
def notify_customer_service(
    cs_id: int,
    message: str = Body(...),
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """超级管理员给指定客服发送提醒"""
    # 获取客服信息
    cs = db.query(CustomerService).filter(CustomerService.id == cs_id).first()
    if not cs:
        raise HTTPException(status_code=404, detail="Customer service not found")

    # 找到对应的用户账号
    from app.models import User

    user = db.query(User).filter(User.name == cs.name).first()

    if not user:
        raise HTTPException(status_code=404, detail="Customer service user not found")

    # 发送通知
    notification = crud.create_notification(
        db, user.id, "admin_notification", "管理员提醒", message
    )

    return {
        "message": "Notification sent to customer service",
        "notification": notification,
    }


# 系统设置相关API
@router.get("/admin/system-settings")
def get_system_settings(
    current_admin=Depends(get_current_admin), db: Session = Depends(get_db)
):
    """获取系统设置"""
    settings_dict = crud.get_system_settings_dict(db)

    # 返回默认设置（如果数据库中没有设置）
    default_settings = {
        "vip_enabled": True,
        "super_vip_enabled": True,
        "vip_task_threshold": 5,
        "super_vip_task_threshold": 20,
        "vip_price_threshold": 10.0,
        "super_vip_price_threshold": 50.0,
        "vip_button_visible": True,
        "vip_auto_upgrade_enabled": False,
        "vip_benefits_description": "优先任务推荐、专属客服服务、任务发布数量翻倍",
        "super_vip_benefits_description": "所有VIP功能、无限任务发布、专属高级客服、任务优先展示、专属会员标识",
        # VIP晋升超级VIP的条件
        "vip_to_super_task_count_threshold": 50,
        "vip_to_super_rating_threshold": 4.5,
        "vip_to_super_completion_rate_threshold": 0.8,
        "vip_to_super_enabled": True,
    }

    # 合并数据库设置和默认设置
    for key, value in default_settings.items():
        if key not in settings_dict:
            settings_dict[key] = value

    return settings_dict


@router.put("/admin/system-settings")
def update_system_settings(
    settings_data: schemas.SystemSettingsBulkUpdate,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """更新系统设置"""
    try:
        updated_settings = crud.bulk_update_system_settings(db, settings_data)
        
        # 清除相关缓存
        from app.cache import invalidate_cache
        invalidate_cache("cache:public_settings:*")
        invalidate_cache("cache:system_settings:*")
        
        return {
            "message": "系统设置更新成功",
            "updated_count": len(updated_settings),
            "settings": crud.get_system_settings_dict(db),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"更新系统设置失败: {str(e)}")


@router.get("/system-settings/public")
def get_public_system_settings(db: Session = Depends(get_db)):
    """获取公开的系统设置（前端使用，已应用缓存）"""
    from app.cache import cache_response
    
    @cache_response(ttl=600, key_prefix="public_settings")  # 缓存10分钟
    def _get_cached_settings():
        settings_dict = crud.get_system_settings_dict(db)

        # 默认设置（如果数据库中没有设置）
        default_settings = {
            "vip_enabled": True,
            "super_vip_enabled": True,
            "vip_task_threshold": 5,
            "super_vip_task_threshold": 20,
            "vip_price_threshold": 10.0,
            "super_vip_price_threshold": 50.0,
            "vip_button_visible": True,
            "vip_auto_upgrade_enabled": False,
            "vip_benefits_description": "优先任务推荐、专属客服服务、任务发布数量翻倍",
            "super_vip_benefits_description": "所有VIP功能、无限任务发布、专属高级客服、任务优先展示、专属会员标识",
            # VIP晋升超级VIP的条件
            "vip_to_super_task_count_threshold": 50,
            "vip_to_super_rating_threshold": 4.5,
            "vip_to_super_completion_rate_threshold": 0.8,
            "vip_to_super_enabled": True,
        }

        # 合并数据库设置和默认设置
        for key, value in default_settings.items():
            if key not in settings_dict:
                settings_dict[key] = value

        # 返回前端需要的所有公开设置
        public_settings = {
            # VIP功能开关
            "vip_enabled": settings_dict.get("vip_enabled", True),
            "super_vip_enabled": settings_dict.get("super_vip_enabled", True),
            "vip_button_visible": settings_dict.get("vip_button_visible", True),
            
            # 价格阈值设置
            "vip_price_threshold": float(settings_dict.get("vip_price_threshold", 10.0)),
            "super_vip_price_threshold": float(settings_dict.get("super_vip_price_threshold", 50.0)),
            
            # 任务数量阈值
            "vip_task_threshold": int(settings_dict.get("vip_task_threshold", 5)),
            "super_vip_task_threshold": int(settings_dict.get("super_vip_task_threshold", 20)),
            
            # VIP晋升设置
            "vip_auto_upgrade_enabled": settings_dict.get("vip_auto_upgrade_enabled", False),
            "vip_to_super_task_count_threshold": int(settings_dict.get("vip_to_super_task_count_threshold", 50)),
            "vip_to_super_rating_threshold": float(settings_dict.get("vip_to_super_rating_threshold", 4.5)),
            "vip_to_super_completion_rate_threshold": float(settings_dict.get("vip_to_super_completion_rate_threshold", 0.8)),
            "vip_to_super_enabled": settings_dict.get("vip_to_super_enabled", True),
            
            # 描述信息
            "vip_benefits_description": settings_dict.get(
                "vip_benefits_description", "优先任务推荐、专属客服服务、任务发布数量翻倍"
            ),
            "super_vip_benefits_description": settings_dict.get(
                "super_vip_benefits_description",
                "所有VIP功能、无限任务发布、专属高级客服、任务优先展示、专属会员标识",
            ),
        }

        return public_settings
    
    return _get_cached_settings()


@router.get("/users/{user_id}/task-statistics")
def get_user_task_statistics(
    user_id: str, current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    """获取用户的任务统计信息"""
    # 只能查看自己的统计信息
    if current_user.id != user_id:
        raise HTTPException(status_code=403, detail="只能查看自己的统计信息")

    statistics = crud.get_user_task_statistics(db, user_id)

    # 获取晋升条件设置
    settings = crud.get_system_settings_dict(db)
    upgrade_conditions = {
        "task_count_threshold": settings.get("vip_to_super_task_count_threshold", 50),
        "rating_threshold": settings.get("vip_to_super_rating_threshold", 4.5),
        "completion_rate_threshold": settings.get(
            "vip_to_super_completion_rate_threshold", 0.8
        ),
        "upgrade_enabled": settings.get("vip_to_super_enabled", True),
    }

    return {
        "statistics": statistics,
        "upgrade_conditions": upgrade_conditions,
        "current_level": current_user.user_level,
    }


# 用户任务偏好相关API
@router.get("/user-preferences")
def get_user_preferences(
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """获取用户任务偏好"""
    from app.models import UserPreferences
    import json
    
    preferences = db.query(UserPreferences).filter(UserPreferences.user_id == current_user.id).first()
    
    if not preferences:
        # 返回默认偏好
        return {
            "task_types": [],
            "locations": [],
            "task_levels": [],
            "keywords": [],
            "min_deadline_days": 1
        }
    
    return {
        "task_types": json.loads(preferences.task_types) if preferences.task_types else [],
        "locations": json.loads(preferences.locations) if preferences.locations else [],
        "task_levels": json.loads(preferences.task_levels) if preferences.task_levels else [],
        "keywords": json.loads(preferences.keywords) if preferences.keywords else [],
        "min_deadline_days": preferences.min_deadline_days
    }


@router.put("/user-preferences")
def update_user_preferences(
    preferences_data: dict,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """更新用户任务偏好"""
    from app.models import UserPreferences
    import json
    
    # 验证数据
    task_types = preferences_data.get("task_types", [])
    locations = preferences_data.get("locations", [])
    task_levels = preferences_data.get("task_levels", [])
    keywords = preferences_data.get("keywords", [])
    min_deadline_days = preferences_data.get("min_deadline_days", 1)
    
    # 验证关键词数量限制
    if len(keywords) > 20:
        raise HTTPException(status_code=400, detail="关键词数量不能超过20个")
    
    # 验证最少截止时间
    if not isinstance(min_deadline_days, int) or min_deadline_days < 1 or min_deadline_days > 30:
        raise HTTPException(status_code=400, detail="最少截止时间必须在1-30天之间")
    
    # 查找或创建偏好记录
    preferences = db.query(UserPreferences).filter(UserPreferences.user_id == current_user.id).first()
    
    if not preferences:
        preferences = UserPreferences(user_id=current_user.id)
        db.add(preferences)
    
    # 更新偏好数据
    preferences.task_types = json.dumps(task_types) if task_types else None
    preferences.locations = json.dumps(locations) if locations else None
    preferences.task_levels = json.dumps(task_levels) if task_levels else None
    preferences.keywords = json.dumps(keywords) if keywords else None
    preferences.min_deadline_days = min_deadline_days
    
    try:
        db.commit()
        db.refresh(preferences)
        return {"message": "偏好设置保存成功"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"保存偏好设置失败: {str(e)}")


@router.post("/customer-service/cleanup-old-chats/{service_id}")
def cleanup_old_customer_service_chats(
    service_id: str,
    current_user: models.CustomerService = Depends(get_current_service),
    db: Session = Depends(get_db),
):
    """清理客服的旧已结束对话"""
    if current_user.id != service_id:
        raise HTTPException(status_code=403, detail="无权限清理其他客服的对话")

    try:
        deleted_count = crud.cleanup_old_ended_chats(db, service_id)
        return {
            "message": f"成功清理 {deleted_count} 个旧对话",
            "deleted_count": deleted_count,
        }
    except Exception as e:
        logger.error(f"清理旧对话失败: {e}")
        raise HTTPException(status_code=500, detail=f"清理失败: {str(e)}")


@router.post("/customer-service/chats/{chat_id}/timeout-end")
async def timeout_end_customer_service_chat(
    chat_id: str,
    current_user: models.CustomerService = Depends(get_current_service),
    db: Session = Depends(get_db),
):
    """超时结束客服对话"""
    try:
        logger.info(f"客服 {current_user.id} 尝试超时结束对话 {chat_id}")
        
        # 获取对话信息
        chat = crud.get_customer_service_chat(db, chat_id)
        if not chat:
            logger.warning(f"对话 {chat_id} 不存在")
            raise HTTPException(status_code=404, detail="对话不存在")

        # 检查权限
        if chat["service_id"] != current_user.id:
            logger.warning(f"客服 {current_user.id} 无权限操作对话 {chat_id}，对话属于客服 {chat['service_id']}")
            raise HTTPException(status_code=403, detail="无权限操作此对话")

        # 检查对话是否已结束
        if chat["is_ended"] == 1:
            logger.info(f"对话 {chat_id} 已经结束")
            raise HTTPException(status_code=400, detail="对话已结束")

        # 先发送系统消息给用户 - 由于长时间没有收到你的信息，本次对话已结束
        logger.info(f"为用户 {chat['user_id']} 发送系统消息")
        try:
            crud.save_customer_service_message(
                db=db,
                chat_id=chat_id,
                sender_id="system",  # 系统消息
                sender_type="system",
                content="由于长时间没有收到你的信息，本次对话已结束"
            )
            logger.info(f"已发送系统消息到对话 {chat_id}")
        except Exception as e:
            logger.error(f"发送系统消息失败: {e}")
            # 不影响流程继续

        # 结束对话（在发送消息后再结束）
        logger.info(f"正在结束对话 {chat_id}")
        success = crud.end_customer_service_chat(db, chat_id)
        if not success:
            logger.error(f"结束对话 {chat_id} 失败")
            raise HTTPException(status_code=500, detail="结束对话失败")

        # 发送超时通知给用户
        logger.info(f"为用户 {chat['user_id']} 创建超时通知")
        crud.create_notification(
            db=db,
            user_id=chat["user_id"],
            type="chat_timeout",
            title="对话超时结束",
            content="您的客服对话因超时（2分钟无活动）已自动结束。如需继续咨询，请重新联系客服。",
            related_id=chat_id,
        )

        # 通过WebSocket通知用户对话已结束
        try:
            from app.main import active_connections
            if chat["user_id"] in active_connections:
                logger.info(f"通过WebSocket通知用户 {chat['user_id']} 对话已结束")
                timeout_message = {
                    "type": "chat_timeout",
                    "chat_id": chat_id,
                    "content": "由于长时间没有收到你的信息，本次对话已结束"
                }
                try:
                    await active_connections[chat["user_id"]].send_text(
                        json.dumps(timeout_message)
                    )
                    logger.info(f"已通过WebSocket发送超时消息给用户 {chat['user_id']}")
                except Exception as ws_error:
                    logger.error(f"WebSocket发送失败: {ws_error}")
            else:
                logger.info(f"用户 {chat['user_id']} 不在线，无法通过WebSocket发送")
        except Exception as e:
            logger.error(f"WebSocket通知失败: {e}")

        logger.info(f"对话 {chat_id} 超时结束成功")
        return {"message": "对话已超时结束", "chat_id": chat_id, "user_notified": True}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"超时结束对话失败: {e}")
        raise HTTPException(status_code=500, detail=f"操作失败: {str(e)}")


@router.get("/timezone/info")
def get_timezone_info():
    """获取当前服务器时区信息 - 使用新的时间处理系统"""
    from app.utils.time_utils import get_utc_time, to_user_timezone, LONDON, format_iso_utc
    from datetime import timezone as tz
    
    utc_time = get_utc_time()
    london_time = to_user_timezone(utc_time, LONDON)
    
    # 检查是否夏令时
    is_dst = london_time.dst().total_seconds() > 0
    tz_name = london_time.tzname()
    offset_hours = london_time.utcoffset().total_seconds() / 3600
    
    return {
        "server_timezone": "Europe/London",
        "server_time": format_iso_utc(london_time.astimezone(tz.utc)),
        "utc_time": format_iso_utc(utc_time),
        "timezone_offset": london_time.strftime("%z"),
        "is_dst": is_dst,
        "timezone_name": tz_name,
        "offset_hours": offset_hours,
        "dst_info": {
            "is_dst": is_dst,
            "tz_name": tz_name,
            "offset_hours": offset_hours,
            "description": f"英国{'夏令时' if is_dst else '冬令时'} ({tz_name}, UTC{offset_hours:+.0f})"
        }
    }


@router.get("/customer-service/chats/{chat_id}/timeout-status")
def get_chat_timeout_status(
    chat_id: str,
    current_user: models.CustomerService = Depends(get_current_service),
    db: Session = Depends(get_db),
):
    """获取对话超时状态"""
    try:
        logger.info(f"客服 {current_user.id} 检查对话 {chat_id} 的超时状态")
        
        # 获取对话信息
        chat = crud.get_customer_service_chat(db, chat_id)
        if not chat:
            logger.warning(f"对话 {chat_id} 不存在")
            raise HTTPException(status_code=404, detail="对话不存在")

        # 检查权限
        if chat["service_id"] != current_user.id:
            logger.warning(f"客服 {current_user.id} 无权限查看对话 {chat_id}")
            raise HTTPException(status_code=403, detail="无权限查看此对话")

        # 检查对话是否已结束
        if chat["is_ended"] == 1:
            logger.info(f"对话 {chat_id} 已结束")
            return {"is_ended": True, "is_timeout": False, "timeout_available": False}

        # 计算最后消息时间到现在的时间差
        from datetime import datetime, timedelta, timezone

        last_message_time = chat["last_message_at"]

        # 统一处理时间格式 - 使用UTC时间
        from app.utils.time_utils import get_utc_time, LONDON, to_user_timezone, parse_iso_utc

        current_time = get_utc_time()

        if isinstance(last_message_time, str):
            # 处理字符串格式的时间，统一使用 parse_iso_utc 确保返回 aware datetime
            last_message_time = parse_iso_utc(last_message_time.replace("Z", "+00:00") if last_message_time.endswith("Z") else last_message_time)
        elif hasattr(last_message_time, "replace"):
            # 如果是datetime对象但没有时区信息，假设是UTC
            if last_message_time.tzinfo is None:
                last_message_time = last_message_time.replace(tzinfo=timezone.utc)
                logger.info(f"为datetime对象添加UTC时区: {last_message_time}")
        else:
            # 如果是其他类型，使用当前UTC时间
            logger.warning(
                f"Unexpected time type: {type(last_message_time)}, value: {last_message_time}"
            )
            last_message_time = current_time

        # 计算时间差（都是UTC时间）
        time_diff = current_time - last_message_time

        # 调试信息
        logger.info(
            f"Current time: {current_time}, Last message time: {last_message_time}, Diff: {time_diff.total_seconds()} seconds"
        )
        logger.info(
            f"Current time type: {type(current_time)}, Last message time type: {type(last_message_time)}"
        )
        logger.info(
            f"Current time tzinfo: {current_time.tzinfo}, Last message time tzinfo: {last_message_time.tzinfo}"
        )

        # 2分钟 = 120秒
        is_timeout = time_diff.total_seconds() > 120
        
        result = {
            "is_ended": False,
            "is_timeout": is_timeout,
            "timeout_available": is_timeout,
            "last_message_time": chat["last_message_at"],
            "time_since_last_message": int(time_diff.total_seconds()),
        }
        
        logger.info(f"对话 {chat_id} 超时状态: {result}")
        return result

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取对话超时状态失败: {e}")
        raise HTTPException(status_code=500, detail=f"操作失败: {str(e)}")


# 文件上传配置 - 支持Railway部署
import os
from app.config import Config

# 检测部署环境
RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
USE_CLOUD_STORAGE = os.getenv("USE_CLOUD_STORAGE", "false").lower() == "true"

# 图片上传相关配置 - 使用私有存储
if RAILWAY_ENVIRONMENT and not USE_CLOUD_STORAGE:
    # Railway环境：使用私有目录
    PRIVATE_IMAGE_DIR = Path("/data/uploads/private/images")
    PRIVATE_FILE_DIR = Path("/data/uploads/private/files")
else:
    # 本地开发环境：使用私有目录
    PRIVATE_IMAGE_DIR = Path("uploads/private/images")
    PRIVATE_FILE_DIR = Path("uploads/private/files")

# 确保私有目录存在
PRIVATE_IMAGE_DIR.mkdir(parents=True, exist_ok=True)
PRIVATE_FILE_DIR.mkdir(parents=True, exist_ok=True)

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp"}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5MB

# 危险文件扩展名（不允许上传）
DANGEROUS_EXTENSIONS = {".exe", ".bat", ".cmd", ".com", ".pif", ".scr", ".vbs", ".js", ".jar", ".sh", ".ps1"}
MAX_FILE_SIZE_LARGE = 10 * 1024 * 1024  # 10MB


@router.post("/upload/image")
@rate_limit("upload_file")
async def upload_image(
    image: UploadFile = File(...),
    task_id: Optional[int] = Query(None, description="任务ID（任务聊天时提供）"),
    chat_id: Optional[str] = Query(None, description="聊天ID（客服聊天时提供）"),
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    上传私密图片文件
    支持按任务ID或聊天ID分类存储
    - task_id: 任务聊天时提供，图片会存储在 tasks/{task_id}/ 文件夹
    - chat_id: 客服聊天时提供，图片会存储在 chats/{chat_id}/ 文件夹
    """
    try:
        # 读取文件内容
        content = await image.read()
        
        # 使用新的私密图片系统上传
        from app.image_system import private_image_system
        result = private_image_system.upload_image(content, image.filename, current_user.id, db, task_id=task_id, chat_id=chat_id, content_type=image.content_type)
        
        return JSONResponse(content=result)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"图片上传失败: {e}")
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")


@router.post("/upload/public-image")
async def upload_public_image(
    request: Request,
    image: UploadFile = File(...),
    category: str = Query("public", description="图片类型：expert_avatar（任务达人头像）、service_image（服务图片）、public（任务相关图片）、leaderboard_item（竞品图片）、leaderboard_cover（榜单封面）"),
    resource_id: str = Query(None, description="资源ID：expert_avatar时传expert_id，service_image时传expert_id，public时传task_id（任务ID，发布新任务时可省略）"),
    db: Session = Depends(get_db),
):
    """
    上传公开图片文件（所有人可访问）
    用于头像等需要公开访问的图片
    支持管理员和普通用户上传
    
    参数:
    - category: 图片类型
      - expert_avatar: 任务达人头像
      - service_image: 服务图片
      - public: 其他公开图片（默认）
    - resource_id: 资源ID，用于创建子文件夹
      - expert_avatar: 任务达人ID（expert_id）
      - service_image: 任务达人ID（expert_id），不是service_id
      - public: 任务ID（task_id），用于任务相关的图片
    """
    try:
        # 尝试获取管理员或用户ID
        user_id = None
        user_type = None
        
        # 首先尝试管理员认证
        from app.admin_auth import validate_admin_session
        admin_session = validate_admin_session(request)
        if admin_session:
            user_id = admin_session.admin_id
            user_type = "管理员"
            logger.info(f"管理员 {user_id} 上传公开图片")
        else:
            # 尝试普通用户认证
            from app.secure_auth import validate_session
            user_session = validate_session(request)
            if user_session:
                user_id = user_session.user_id
                user_type = "用户"
                logger.info(f"用户 {user_id} 上传公开图片")
            else:
                raise HTTPException(status_code=401, detail="认证失败，请先登录")
        
        if not user_id:
            raise HTTPException(status_code=401, detail="认证失败，请先登录")
        
        # 验证 category 参数
        valid_categories = ["expert_avatar", "service_image", "public", "leaderboard_item", "leaderboard_cover"]
        if category not in valid_categories:
            raise HTTPException(
                status_code=400,
                detail=f"无效的图片类型。允许的类型: {', '.join(valid_categories)}"
            )
        
        # 根据 category 确定 resource_id（如果未提供）
        if not resource_id:
            if category == "expert_avatar":
                # 任务达人头像：使用当前用户ID（任务达人ID等于用户ID）
                resource_id = user_id
            elif category == "service_image":
                # 服务图片：使用当前用户ID（任务达人ID等于用户ID）
                # 因为服务图片属于任务达人，应该按任务达人ID分类
                resource_id = user_id
            elif category == "leaderboard_item":
                # 竞品图片：如果没有提供item_id，使用临时标识
                # 注意：上传时item可能还未创建，所以使用临时标识
                resource_id = f"temp_{user_id}"
            elif category == "leaderboard_cover":
                # 榜单封面：如果没有提供resource_id，使用临时标识
                resource_id = f"temp_{user_id}"
            else:  # public
                # 用户上传的图片都是任务相关的，需要提供task_id
                # 如果没有提供task_id，使用临时标识（用于发布新任务时）
                resource_id = f"temp_{user_id}"
        
        # 读取文件内容
        content = await image.read()
        
        # 验证文件类型
        # 首先尝试从filename获取扩展名
        if image.filename:
            file_extension = Path(image.filename).suffix.lower()
        else:
            file_extension = ''
        
        # 如果从filename无法获取扩展名（如filename为"blob"），尝试从Content-Type或文件内容检测
        if not file_extension:
            # 首先尝试从Content-Type获取
            content_type = image.content_type or ''
            if 'jpeg' in content_type or 'jpg' in content_type:
                file_extension = '.jpg'
            elif 'png' in content_type:
                file_extension = '.png'
            elif 'gif' in content_type:
                file_extension = '.gif'
            elif 'webp' in content_type:
                file_extension = '.webp'
            
            # 如果Content-Type无法确定，通过文件内容的magic bytes检测
            if not file_extension and len(content) >= 4:
                # JPEG: FF D8 FF
                if content[:3] == b'\xff\xd8\xff':
                    file_extension = '.jpg'
                # PNG: 89 50 4E 47
                elif content[:4] == b'\x89PNG':
                    file_extension = '.png'
                # GIF: 47 49 46 38
                elif content[:4] == b'GIF8':
                    file_extension = '.gif'
                # WEBP: RIFF...WEBP
                elif len(content) >= 12 and content[:4] == b'RIFF' and content[8:12] == b'WEBP':
                    file_extension = '.webp'
            
            if not file_extension:
                logger.error(f"无法检测文件类型: filename={image.filename}, content_type={image.content_type}, content_size={len(content)}, magic_bytes={content[:12].hex() if len(content) >= 12 else content.hex()}")
                raise HTTPException(
                    status_code=400,
                    detail="无法检测文件类型，请确保上传的是有效的图片文件（JPG、PNG、GIF、WEBP）"
                )
        
        if file_extension not in ALLOWED_EXTENSIONS:
            logger.warning(f"不支持的文件类型: {file_extension}, filename={image.filename}, content_type={image.content_type}")
            raise HTTPException(
                status_code=400,
                detail=f"不支持的文件类型: {file_extension}。允许的类型: {', '.join(ALLOWED_EXTENSIONS)}"
            )
        
        # 验证文件大小
        if len(content) > MAX_FILE_SIZE:
            raise HTTPException(
                status_code=400,
                detail=f"文件过大。最大允许大小: {MAX_FILE_SIZE // (1024*1024)}MB"
            )
        
        # 检测部署环境
        if RAILWAY_ENVIRONMENT:
            base_public_dir = Path("/data/uploads/public/images")
        else:
            base_public_dir = Path("uploads/public/images")
        
        # 根据 category 确定子目录和文件命名前缀
        if category == "expert_avatar":
            sub_dir = "expert_avatars"
            filename_prefix = "expert_avatar_"
            # 创建按任务达人ID的子文件夹
            resource_subdir = resource_id
        elif category == "service_image":
            sub_dir = "service_images"
            filename_prefix = "service_image_"
            # 创建按任务达人ID的子文件夹（不是service_id）
            resource_subdir = resource_id
        elif category == "leaderboard_item":
            sub_dir = "leaderboard_items"
            filename_prefix = "leaderboard_item_"
            # 创建按竞品ID的子文件夹
            resource_subdir = str(resource_id) if resource_id else f"temp_{user_id}"
        elif category == "leaderboard_cover":
            sub_dir = "leaderboard_covers"
            filename_prefix = "leaderboard_cover_"
            # 创建按用户ID的临时子文件夹（申请时使用temp_，审核批准后移动到leaderboard_id文件夹）
            if resource_id and resource_id.startswith("temp_"):
                # 如果resource_id是temp_开头，直接使用（前端已传入temp_{user_id}）
                resource_subdir = resource_id
            elif resource_id and not resource_id.startswith("temp_"):
                # 如果resource_id不是temp_开头，说明是正式榜单ID，直接使用
                resource_subdir = str(resource_id)
            else:
                # 如果没有提供resource_id，使用临时文件夹
                resource_subdir = f"temp_{user_id}"
        else:  # public
            sub_dir = "public"
            filename_prefix = "public_"
            # 创建按任务ID的子文件夹（用户上传的图片都是任务相关的）
            resource_subdir = str(resource_id)
        
        # 构建完整的保存目录：/data/uploads/public/images/{sub_dir}/{resource_id}/
        if sub_dir:
            public_image_dir = base_public_dir / sub_dir / resource_subdir
        else:
            public_image_dir = base_public_dir / resource_subdir
        
        # 确保目录存在
        public_image_dir.mkdir(parents=True, exist_ok=True)
        
        # 生成唯一文件名（使用前缀+UUID，便于后续清理）
        unique_filename = f"{filename_prefix}{uuid.uuid4()}{file_extension}"
        file_path = public_image_dir / unique_filename
        
        # 保存文件
        with open(file_path, "wb") as buffer:
            buffer.write(content)
        
        # 生成公开URL（通过静态文件服务访问）
        # 注意：图片在后端服务器上，通过Vercel的rewrite规则代理到后端
        from app.config import Config
        # 使用前端域名，Vercel会将/uploads/请求代理到后端API服务器
        base_url = Config.FRONTEND_URL.rstrip('/')
        
        # 构建URL路径（包含子目录和资源ID）
        if sub_dir:
            image_url = f"{base_url}/uploads/images/{sub_dir}/{resource_subdir}/{unique_filename}"
        else:
            image_url = f"{base_url}/uploads/images/{resource_subdir}/{unique_filename}"
        
        logger.info(f"{user_type} {user_id} 上传公开图片 [{category}] 资源ID: {resource_id}, 文件名: {unique_filename}")
        
        return JSONResponse(content={
            "success": True,
            "url": image_url,
            "filename": unique_filename,
            "size": len(content),
            "category": category,
            "resource_id": resource_id,
            "message": "图片上传成功"
        })
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"公开图片上传失败: {e}")
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")


@router.post("/refresh-image-url")
async def refresh_image_url(
    request: dict, 
    current_user: models.User = Depends(get_current_user_secure_sync_csrf)
):
    """
    刷新过期的图片URL
    """
    try:
        original_url = request.get("original_url")
        if not original_url:
            raise HTTPException(status_code=400, detail="缺少original_url参数")
        
        # 从URL中提取文件名
        from urllib.parse import urlparse, parse_qs
        parsed_url = urlparse(original_url)
        query_params = parse_qs(parsed_url.query)
        
        if 'file' not in query_params:
            raise HTTPException(status_code=400, detail="无法从URL中提取文件名")
        
        filename = query_params['file'][0]
        
        # 生成新的签名URL（无过期时间）
        from app.signed_url import signed_url_manager
        new_url = signed_url_manager.generate_signed_url(
            file_path=f"images/{filename}",
            user_id=current_user.id,
            expiry_minutes=None,  # 无过期时间
            one_time=False
        )
        
        logger.info(f"用户 {current_user.id} 刷新图片URL: {filename}")
        
        return JSONResponse(content={
            "success": True,
            "url": new_url,
            "filename": filename
        })
        
    except Exception as e:
        logger.error(f"刷新图片URL失败: {e}")
        raise HTTPException(status_code=500, detail=f"刷新失败: {str(e)}")


@router.get("/private-image/{image_id}")
async def get_private_image(
    image_id: str,
    user: str = Query(..., description="用户ID"),
    token: str = Query(..., description="访问令牌"),
    db: Session = Depends(get_db)
):
    """
    获取私密图片（需要验证访问权限）
    """
    try:
        from app.image_system import private_image_system
        return private_image_system.get_image(image_id, user, token, db)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取私密图片失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取图片失败: {str(e)}")


@router.post("/messages/generate-image-url")
def generate_image_url(
    request_data: dict,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    为聊天参与者生成图片访问URL
    """
    try:
        from app.image_system import private_image_system
        from urllib.parse import urlparse, parse_qs
        import re
        
        # 从请求数据中获取image_id
        raw_image_id = request_data.get('image_id')
        if not raw_image_id:
            raise HTTPException(status_code=400, detail="缺少image_id参数")
        
        logger.info(f"尝试生成图片URL，原始image_id: {raw_image_id}")
        
        # 处理不同格式的image_id
        image_id = raw_image_id
        
        # 如果是base64数据（旧格式），直接返回错误
        if raw_image_id.startswith('data:image/'):
            logger.error(f"检测到旧的base64格式图片数据，不支持")
            raise HTTPException(status_code=400, detail="此图片使用旧格式存储，请重新发送图片")
        
        # 如果是完整的URL，尝试提取图片ID
        if raw_image_id.startswith('http'):
            try:
                parsed_url = urlparse(raw_image_id)
                if '/api/private-file' in parsed_url.path:
                    # 从private-file URL中提取file参数
                    query_params = parse_qs(parsed_url.query)
                    if 'file' in query_params:
                        file_path = query_params['file'][0]
                        # 提取文件名（去掉images/前缀）
                        if file_path.startswith('images/'):
                            image_id = file_path[7:]  # 去掉'images/'前缀
                            # 去掉文件扩展名
                            image_id = image_id.rsplit('.', 1)[0]
                        else:
                            image_id = file_path.rsplit('.', 1)[0]
                        logger.info(f"从URL提取image_id: {image_id}")
                elif '/private-image/' in parsed_url.path:
                    # 从private-image URL中提取image_id
                    image_id = parsed_url.path.split('/private-image/')[-1]
                    logger.info(f"从private-image URL提取image_id: {image_id}")
            except Exception as e:
                logger.warning(f"URL解析失败: {e}")
                # 如果URL解析失败，尝试从URL中提取可能的ID
                uuid_match = re.search(r'([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})', raw_image_id)
                if uuid_match:
                    image_id = uuid_match.group(1)
                    logger.info(f"从URL中提取UUID: {image_id}")
        
        # 如果是新格式的image_id（user_timestamp_random），直接使用
        elif '_' in raw_image_id and len(raw_image_id.split('_')) >= 3:
            image_id = raw_image_id
            logger.info(f"使用新格式image_id: {image_id}")
        
        # 如果是旧格式的UUID，也直接使用
        else:
            image_id = raw_image_id
            logger.info(f"使用原始image_id: {image_id}")
        
        logger.info(f"最终image_id: {image_id}")
        
        # 查找包含此图片的消息
        message = None
        
        # 首先尝试通过image_id字段查找（如果字段存在）
        try:
            if hasattr(models.Message, 'image_id'):
                message = db.query(models.Message).filter(models.Message.image_id == image_id).first()
                if message:
                    logger.info(f"通过image_id找到消息: {message.id}")
        except Exception as e:
            logger.warning(f"image_id字段查询失败: {e}")
        
        # 如果通过image_id找不到，尝试通过content查找
        if not message:
            message = db.query(models.Message).filter(models.Message.content.like(f'%[图片] {image_id}%')).first()
            if message:
                logger.info(f"通过content找到消息: {message.id}")
        
        # 如果还是找不到，尝试查找原始image_id
        if not message and raw_image_id != image_id:
            logger.info(f"尝试通过原始image_id查找")
            if hasattr(models.Message, 'image_id'):
                message = db.query(models.Message).filter(models.Message.image_id == raw_image_id).first()
            if not message:
                message = db.query(models.Message).filter(models.Message.content.like(f'%[图片] {raw_image_id}%')).first()
            if message:
                logger.info(f"通过原始image_id找到消息: {message.id}")
                image_id = raw_image_id  # 使用原始ID
        
        if not message:
            logger.error(f"未找到包含image_id {image_id}的消息")
            raise HTTPException(status_code=404, detail="图片不存在")
        
        # 获取聊天参与者
        participants = []
        
        # 如果是任务聊天，从任务中获取参与者
        if hasattr(message, 'conversation_type') and message.conversation_type == 'task' and message.task_id:
            from app import crud
            task = crud.get_task(db, message.task_id)
            if not task:
                raise HTTPException(status_code=404, detail="任务不存在")
            
            # 任务参与者：发布者和接受者
            participants = [task.poster_id]
            if task.taker_id:
                participants.append(task.taker_id)
            
            # 检查用户是否有权限访问此图片（必须是任务的参与者）
            if current_user.id not in participants:
                raise HTTPException(status_code=403, detail="无权访问此图片")
        else:
            # 普通聊天：使用发送者和接收者
            participants = [message.sender_id]
            if message.receiver_id:
                participants.append(message.receiver_id)
            
            # 检查用户是否有权限访问此图片
            if current_user.id not in participants:
                raise HTTPException(status_code=403, detail="无权访问此图片")
        
        # 生成访问URL
        image_url = private_image_system.generate_image_url(
            image_id,
            current_user.id,
            participants
        )

        return JSONResponse(content={
            "success": True,
            "image_url": image_url,
            "image_id": image_id
        })

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"生成图片URL失败: {e}")
        import traceback
        logger.error(f"详细错误: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"生成URL失败: {str(e)}")


# 废弃的公开图片API已删除 - 现在使用私密图片系统


@router.post("/upload/file")
@rate_limit("upload_file")
async def upload_file(
    file: UploadFile = File(...),
    task_id: Optional[int] = Query(None, description="任务ID（任务聊天时提供）"),
    chat_id: Optional[str] = Query(None, description="聊天ID（客服聊天时提供）"),
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    上传文件
    支持按任务ID或聊天ID分类存储
    - task_id: 任务聊天时提供，文件会存储在 tasks/{task_id}/ 文件夹
    - chat_id: 客服聊天时提供，文件会存储在 chats/{chat_id}/ 文件夹
    """
    try:
        # 读取文件内容
        content = await file.read()
        
        # 使用新的私密文件系统上传
        from app.file_system import private_file_system
        result = private_file_system.upload_file(content, file.filename, current_user.id, db, task_id=task_id, chat_id=chat_id, content_type=file.content_type)
        
        # 生成签名URL（使用新的文件ID）
        from app.signed_url import signed_url_manager
        # 构建文件路径（用于签名URL，保持向后兼容）
        file_path_for_url = f"files/{result['filename']}"
        file_url = signed_url_manager.generate_signed_url(
            file_path=file_path_for_url,
            user_id=current_user.id,
            expiry_minutes=15,  # 15分钟过期
            one_time=False  # 可以多次使用
        )
        
        return JSONResponse(
            content={
                "success": True,
                "url": file_url,
                "file_id": result["file_id"],
                "filename": result["filename"],
                "size": result["size"],
                "original_name": result["original_filename"],
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"文件上传失败: {e}")
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")


@router.get("/private-file")
async def get_private_file(
    file: str = Query(..., description="文件路径"),
    user: str = Query(..., description="用户ID"),
    exp: int = Query(..., description="过期时间戳"),
    sig: str = Query(..., description="签名"),
    ts: int = Query(None, description="时间戳"),
    ip: str = Query(None, description="IP地址限制"),
    ot: str = Query("0", description="是否一次性使用")
):
    """
    获取私有文件 - 需要签名URL
    """
    try:
        from app.signed_url import signed_url_manager
        from fastapi import Request
        from fastapi.responses import FileResponse
        
        # 解析参数
        params = {
            "file": file,
            "user": user,
            "exp": str(exp),
            "sig": sig,
            "ip": ip,
            "ot": ot
        }
        
        # 如果有时间戳参数，添加到参数中
        if ts is not None:
            params["ts"] = str(ts)
        
        parsed_params = signed_url_manager.parse_signed_url_params(params)
        if not parsed_params:
            raise HTTPException(status_code=400, detail="无效的签名URL参数")
        
        # 验证签名
        request_ip = None  # 可以从Request对象获取
        if not signed_url_manager.verify_signed_url(
            file_path=parsed_params["file_path"],
            user_id=parsed_params["user_id"],
            expiry=parsed_params["expiry"],
            signature=parsed_params["signature"],
            timestamp=parsed_params.get("timestamp", exp - 900),  # 如果没有时间戳，使用过期时间减去15分钟
            ip_address=parsed_params.get("ip_address"),
            one_time=parsed_params["one_time"]
        ):
            raise HTTPException(status_code=403, detail="签名验证失败")
        
        # 构建文件路径
        # 支持新旧两种路径格式：
        # 旧格式：files/{filename} (向后兼容)
        # 新格式：files/{filename} (但实际文件可能在新结构 private_files/tasks/{task_id}/ 或 private_files/chats/{chat_id}/)
        file_path_str = parsed_params["file_path"]
        
        # 从文件路径中提取文件名（去掉 "files/" 前缀）
        if file_path_str.startswith("files/"):
            filename = file_path_str[6:]  # 去掉 "files/" 前缀
        else:
            filename = file_path_str
        
        # 提取文件ID（去掉扩展名）
        file_id = Path(filename).stem
        
        # 尝试在新文件系统中查找（通过数据库查询优化）
        file_path = None
        try:
            # 使用文件系统查找文件（会从数据库查询优化路径）
            from app.file_system import private_file_system
            db = next(get_db())
            try:
                file_response = private_file_system.get_file(file_id, parsed_params["user_id"], db)
                # 如果找到了，直接返回
                return file_response
            except HTTPException as e:
                if e.status_code == 404:
                    # 文件不在新系统中，尝试旧路径
                    pass
                else:
                    raise
            finally:
                db.close()
        except Exception as e:
            logger.debug(f"从新文件系统查找文件失败，尝试旧路径: {e}")
        
        # 回退到旧路径（向后兼容）
        if RAILWAY_ENVIRONMENT and not USE_CLOUD_STORAGE:
            base_private_dir = Path("/data/uploads/private")
        else:
            base_private_dir = Path("uploads/private")
        
        file_path = base_private_dir / file_path_str
        
        if not file_path.exists():
            raise HTTPException(status_code=404, detail="文件不存在")
        
        # 检查是否是文件而不是目录
        if not file_path.is_file():
            raise HTTPException(status_code=404, detail="文件不存在")
        
        # 返回文件
        return FileResponse(
            path=file_path,
            filename=file_path.name,
            media_type='application/octet-stream'
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取私有文件失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取文件失败: {str(e)}")


# 旧的图片存储优化API已删除 - 现在使用私密图片系统
# 旧的图片存储优化API已删除 - 现在使用私密图片系统


# 岗位管理API
@router.get("/admin/job-positions")
def get_job_positions(
    page: int = Query(1, ge=1, description="页码"),
    size: int = Query(20, ge=1, le=100, description="每页数量"),
    is_active: Optional[bool] = Query(None, description="是否启用"),
    department: Optional[str] = Query(None, description="部门筛选"),
    type: Optional[str] = Query(None, description="工作类型筛选"),
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取岗位列表"""
    try:
        skip = (page - 1) * size
        positions, total = crud.get_job_positions(
            db=db,
            skip=skip,
            limit=size,
            is_active=is_active,
            department=department,
            type=type
        )
        
        # 处理JSON字段
        import json
        processed_positions = []
        for position in positions:
            position_dict = {
                "id": position.id,
                "title": position.title,
                "title_en": position.title_en,
                "department": position.department,
                "department_en": position.department_en,
                "type": position.type,
                "type_en": position.type_en,
                "location": position.location,
                "location_en": position.location_en,
                "experience": position.experience,
                "experience_en": position.experience_en,
                "salary": position.salary,
                "salary_en": position.salary_en,
                "description": position.description,
                "description_en": position.description_en,
                "requirements": json.loads(position.requirements) if position.requirements else [],
                "requirements_en": json.loads(position.requirements_en) if position.requirements_en else [],
                "tags": json.loads(position.tags) if position.tags else [],
                "tags_en": json.loads(position.tags_en) if position.tags_en else [],
                "is_active": bool(position.is_active),
                "created_at": format_iso_utc(position.created_at) if position.created_at else None,
                "updated_at": format_iso_utc(position.updated_at) if position.updated_at else None,
                "created_by": position.created_by
            }
            processed_positions.append(position_dict)
        
        return {
            "positions": processed_positions,
            "total": total,
            "page": page,
            "size": size
        }
    except Exception as e:
        logger.error(f"获取岗位列表失败: {e}")
        raise HTTPException(status_code=500, detail="获取岗位列表失败")


@router.get("/admin/job-positions/{position_id}")
def get_job_position(
    position_id: int,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取单个岗位详情"""
    try:
        position = crud.get_job_position(db=db, position_id=position_id)
        if not position:
            raise HTTPException(status_code=404, detail="岗位不存在")
        
        import json
        position_dict = {
            "id": position.id,
            "title": position.title,
            "title_en": position.title_en,
            "department": position.department,
            "department_en": position.department_en,
            "type": position.type,
            "type_en": position.type_en,
            "location": position.location,
            "location_en": position.location_en,
            "experience": position.experience,
            "experience_en": position.experience_en,
            "salary": position.salary,
            "salary_en": position.salary_en,
            "description": position.description,
            "description_en": position.description_en,
            "requirements": json.loads(position.requirements) if position.requirements else [],
            "requirements_en": json.loads(position.requirements_en) if position.requirements_en else [],
            "tags": json.loads(position.tags) if position.tags else [],
            "tags_en": json.loads(position.tags_en) if position.tags_en else [],
            "is_active": bool(position.is_active),
            "created_at": format_iso_utc(position.created_at) if position.created_at else None,
            "updated_at": format_iso_utc(position.updated_at) if position.updated_at else None,
            "created_by": position.created_by
        }
        
        return position_dict
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取岗位详情失败: {e}")
        raise HTTPException(status_code=500, detail="获取岗位详情失败")


@router.post("/admin/job-positions")
def create_job_position(
    position: schemas.JobPositionCreate,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """创建新岗位"""
    try:
        db_position = crud.create_job_position(
            db=db,
            position=position,
            created_by=current_admin.id
        )
        
        import json
        position_dict = {
            "id": db_position.id,
            "title": db_position.title,
            "title_en": db_position.title_en,
            "department": db_position.department,
            "department_en": db_position.department_en,
            "type": db_position.type,
            "type_en": db_position.type_en,
            "location": db_position.location,
            "location_en": db_position.location_en,
            "experience": db_position.experience,
            "experience_en": db_position.experience_en,
            "salary": db_position.salary,
            "salary_en": db_position.salary_en,
            "description": db_position.description,
            "description_en": db_position.description_en,
            "requirements": json.loads(db_position.requirements) if db_position.requirements else [],
            "requirements_en": json.loads(db_position.requirements_en) if db_position.requirements_en else [],
            "tags": json.loads(db_position.tags) if db_position.tags else [],
            "tags_en": json.loads(db_position.tags_en) if db_position.tags_en else [],
            "is_active": bool(db_position.is_active),
            "created_at": format_iso_utc(db_position.created_at) if db_position.created_at else None,
            "updated_at": format_iso_utc(db_position.updated_at) if db_position.updated_at else None,
            "created_by": db_position.created_by
        }
        
        return position_dict
    except Exception as e:
        logger.error(f"创建岗位失败: {e}")
        raise HTTPException(status_code=500, detail="创建岗位失败")


@router.put("/admin/job-positions/{position_id}")
def update_job_position(
    position_id: int,
    position: schemas.JobPositionUpdate,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """更新岗位"""
    try:
        db_position = crud.update_job_position(
            db=db,
            position_id=position_id,
            position=position
        )
        
        if not db_position:
            raise HTTPException(status_code=404, detail="岗位不存在")
        
        import json
        position_dict = {
            "id": db_position.id,
            "title": db_position.title,
            "title_en": db_position.title_en,
            "department": db_position.department,
            "department_en": db_position.department_en,
            "type": db_position.type,
            "type_en": db_position.type_en,
            "location": db_position.location,
            "location_en": db_position.location_en,
            "experience": db_position.experience,
            "experience_en": db_position.experience_en,
            "salary": db_position.salary,
            "salary_en": db_position.salary_en,
            "description": db_position.description,
            "description_en": db_position.description_en,
            "requirements": json.loads(db_position.requirements) if db_position.requirements else [],
            "requirements_en": json.loads(db_position.requirements_en) if db_position.requirements_en else [],
            "tags": json.loads(db_position.tags) if db_position.tags else [],
            "tags_en": json.loads(db_position.tags_en) if db_position.tags_en else [],
            "is_active": bool(db_position.is_active),
            "created_at": format_iso_utc(db_position.created_at) if db_position.created_at else None,
            "updated_at": format_iso_utc(db_position.updated_at) if db_position.updated_at else None,
            "created_by": db_position.created_by
        }
        
        return position_dict
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"更新岗位失败: {e}")
        raise HTTPException(status_code=500, detail="更新岗位失败")


@router.delete("/admin/job-positions/{position_id}")
def delete_job_position(
    position_id: int,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """删除岗位"""
    try:
        success = crud.delete_job_position(db=db, position_id=position_id)
        if not success:
            raise HTTPException(status_code=404, detail="岗位不存在")
        
        return {"message": "岗位删除成功"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"删除岗位失败: {e}")
        raise HTTPException(status_code=500, detail="删除岗位失败")


@router.patch("/admin/job-positions/{position_id}/toggle-status")
def toggle_job_position_status(
    position_id: int,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """切换岗位启用状态"""
    try:
        db_position = crud.toggle_job_position_status(db=db, position_id=position_id)
        if not db_position:
            raise HTTPException(status_code=404, detail="岗位不存在")
        
        return {
            "message": "状态切换成功",
            "is_active": bool(db_position.is_active)
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"切换岗位状态失败: {e}")
        raise HTTPException(status_code=500, detail="切换岗位状态失败")


# 公开API - 获取启用的岗位列表（用于join页面）
@router.get("/job-positions")
@cache_response(ttl=600, key_prefix="public_job_positions")  # 缓存10分钟
def get_public_job_positions(
    page: int = Query(1, ge=1, description="页码"),
    size: int = Query(20, ge=1, le=100, description="每页数量"),
    department: Optional[str] = Query(None, description="部门筛选"),
    type: Optional[str] = Query(None, description="工作类型筛选"),
    db: Session = Depends(get_db),
):
    """获取公开的岗位列表（仅显示启用的岗位）"""
    try:
        skip = (page - 1) * size
        positions, total = crud.get_job_positions(
            db=db,
            skip=skip,
            limit=size,
            is_active=True,  # 只获取启用的岗位
            department=department,
            type=type
        )
        
        # 处理JSON字段
        import json
        processed_positions = []
        for position in positions:
            position_dict = {
                "id": position.id,
                "title": position.title,
                "title_en": position.title_en,
                "department": position.department,
                "department_en": position.department_en,
                "type": position.type,
                "type_en": position.type_en,
                "location": position.location,
                "location_en": position.location_en,
                "experience": position.experience,
                "experience_en": position.experience_en,
                "salary": position.salary,
                "salary_en": position.salary_en,
                "description": position.description,
                "description_en": position.description_en,
                "requirements": json.loads(position.requirements) if position.requirements else [],
                "requirements_en": json.loads(position.requirements_en) if position.requirements_en else [],
                "tags": json.loads(position.tags) if position.tags else [],
                "tags_en": json.loads(position.tags_en) if position.tags_en else [],
                "is_active": bool(position.is_active),
                "created_at": format_iso_utc(position.created_at) if position.created_at else None,
                "updated_at": format_iso_utc(position.updated_at) if position.updated_at else None
            }
            processed_positions.append(position_dict)
        
        return {
            "positions": processed_positions,
            "total": total,
            "page": page,
            "size": size
        }
    except Exception as e:
        logger.error(f"获取公开岗位列表失败: {e}")
        raise HTTPException(status_code=500, detail="获取岗位列表失败")


# ==================== 任务达人管理 API ====================

@router.get("/admin/task-experts")
def get_task_experts(
    page: int = 1,
    size: int = 20,
    category: Optional[str] = None,
    is_active: Optional[int] = None,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取任务达人列表（管理员）"""
    try:
        query = db.query(models.FeaturedTaskExpert)
        
        # 筛选
        if category:
            query = query.filter(models.FeaturedTaskExpert.category == category)
        if is_active is not None:
            query = query.filter(models.FeaturedTaskExpert.is_active == is_active)
        
        # 排序
        query = query.order_by(
            models.FeaturedTaskExpert.display_order,
            models.FeaturedTaskExpert.created_at.desc()
        )
        
        total = query.count()
        skip = (page - 1) * size
        experts = query.offset(skip).limit(size).all()
        
        return {
            "task_experts": [
                {
                    "id": expert.id,
                    "user_id": expert.user_id,
                    "name": expert.name,
                    "avatar": expert.avatar,
                    "user_level": expert.user_level,
                    "bio": expert.bio,
                    "bio_en": expert.bio_en,
                    "avg_rating": expert.avg_rating,
                    "completed_tasks": expert.completed_tasks,
                    "total_tasks": expert.total_tasks,
                    "completion_rate": expert.completion_rate,
                    "expertise_areas": json.loads(expert.expertise_areas) if expert.expertise_areas else [],
                    "expertise_areas_en": json.loads(expert.expertise_areas_en) if expert.expertise_areas_en else [],
                    "featured_skills": json.loads(expert.featured_skills) if expert.featured_skills else [],
                    "featured_skills_en": json.loads(expert.featured_skills_en) if expert.featured_skills_en else [],
                    "achievements": json.loads(expert.achievements) if expert.achievements else [],
                    "achievements_en": json.loads(expert.achievements_en) if expert.achievements_en else [],
                    "response_time": expert.response_time,
                    "response_time_en": expert.response_time_en,
                    "success_rate": expert.success_rate,
                    "is_verified": bool(expert.is_verified),
                    "is_active": bool(expert.is_active),
                    "is_featured": bool(expert.is_featured),
                    "display_order": expert.display_order,
                    "category": expert.category,
                    "location": expert.location,  # 添加城市字段
                    "created_at": format_iso_utc(expert.created_at) if expert.created_at else None,
                    "updated_at": format_iso_utc(expert.updated_at) if expert.updated_at else None,
                }
                for expert in experts
            ],
            "total": total,
            "page": page,
            "size": size
        }
    except Exception as e:
        logger.error(f"获取任务达人列表失败: {e}")
        raise HTTPException(status_code=500, detail="获取任务达人列表失败")


@router.get("/admin/task-expert/{expert_id}")
def get_task_expert(
    expert_id: str,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取单个任务达人详情（管理员）"""
    try:
        expert = db.query(models.FeaturedTaskExpert).filter(
            models.FeaturedTaskExpert.id == expert_id
        ).first()
        
        if not expert:
            raise HTTPException(status_code=404, detail="任务达人不存在")
        
        return {
            "id": expert.id,
            "user_id": expert.user_id,
            "name": expert.name,
            "avatar": expert.avatar,
            "user_level": expert.user_level,
            "bio": expert.bio,
            "bio_en": expert.bio_en,
            "avg_rating": expert.avg_rating,
            "completed_tasks": expert.completed_tasks,
            "total_tasks": expert.total_tasks,
            "completion_rate": expert.completion_rate,
            "expertise_areas": json.loads(expert.expertise_areas) if expert.expertise_areas else [],
            "expertise_areas_en": json.loads(expert.expertise_areas_en) if expert.expertise_areas_en else [],
            "featured_skills": json.loads(expert.featured_skills) if expert.featured_skills else [],
            "featured_skills_en": json.loads(expert.featured_skills_en) if expert.featured_skills_en else [],
            "achievements": json.loads(expert.achievements) if expert.achievements else [],
            "achievements_en": json.loads(expert.achievements_en) if expert.achievements_en else [],
            "response_time": expert.response_time,
            "response_time_en": expert.response_time_en,
            "success_rate": expert.success_rate,
            "is_verified": bool(expert.is_verified),
            "is_active": expert.is_active if expert.is_active is not None else 1,
            "is_featured": expert.is_featured if expert.is_featured is not None else 1,
            "display_order": expert.display_order,
            "category": expert.category,
            "location": expert.location,
            "created_at": format_iso_utc(expert.created_at) if expert.created_at else None,
            "updated_at": format_iso_utc(expert.updated_at) if expert.updated_at else None,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取任务达人详情失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取任务达人详情失败: {str(e)}")


@router.post("/admin/task-expert")
def create_task_expert(
    expert_data: dict,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """创建任务达人（管理员）"""
    from sqlalchemy.exc import IntegrityError
    
    # 1. 确保 expert_data 包含 user_id，并且 id 和 user_id 相同
    if 'user_id' not in expert_data:
        raise HTTPException(status_code=400, detail="必须提供 user_id")
    
    user_id = expert_data['user_id']
    
    # 2. 验证 user_id 格式（应该是8位字符串）
    if not isinstance(user_id, str) or len(user_id) != 8:
        raise HTTPException(status_code=400, detail="user_id 必须是8位字符串")
    
    # 3. 验证用户是否存在
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")
    
    # 4. 检查用户是否已经是基础任务达人（TaskExpert）
    existing_task_expert = db.query(models.TaskExpert).filter(
        models.TaskExpert.id == user_id
    ).first()
    if not existing_task_expert:
        raise HTTPException(status_code=400, detail="该用户还不是任务达人，请先批准任务达人申请")
    
    # 5. 检查用户是否已经是特色任务达人（FeaturedTaskExpert）
    existing_featured = db.query(models.FeaturedTaskExpert).filter(
        models.FeaturedTaskExpert.id == user_id
    ).first()
    if existing_featured:
        raise HTTPException(status_code=400, detail="该用户已经是特色任务达人")
    
    # 设置 id 为 user_id
    expert_data['id'] = user_id
    
    # 重要：头像永远不要自动从用户表同步，必须由管理员手动设置
    # 如果 expert_data 中没有提供 avatar，确保使用空字符串而不是用户头像
    if 'avatar' not in expert_data:
        expert_data['avatar'] = ""
    
    try:
        # 将数组字段转换为 JSON
        for field in ['expertise_areas', 'expertise_areas_en', 'featured_skills', 'featured_skills_en', 'achievements', 'achievements_en']:
            if field in expert_data and isinstance(expert_data[field], list):
                expert_data[field] = json.dumps(expert_data[field])
        
        new_expert = models.FeaturedTaskExpert(
            **expert_data,
            created_by=current_admin.id
        )
        db.add(new_expert)
        db.commit()
        db.refresh(new_expert)
        
        logger.info(f"创建任务达人成功: {new_expert.id}")
        
        return {
            "message": "创建任务达人成功",
            "task_expert": {
                "id": new_expert.id,
                "name": new_expert.name,
            }
        }
    except IntegrityError as e:
        db.rollback()
        logger.error(f"创建任务达人失败（完整性错误）: {e}")
        # 检查是否是主键冲突
        if "duplicate key" in str(e).lower() or "unique constraint" in str(e).lower():
            raise HTTPException(status_code=409, detail="该用户已经是特色任务达人（并发冲突）")
        raise HTTPException(status_code=400, detail=f"数据完整性错误: {str(e)}")
    except Exception as e:
        logger.error(f"创建任务达人失败: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"创建任务达人失败: {str(e)}")


@router.put("/admin/task-expert/{expert_id}")
def update_task_expert(
    expert_id: str,  # 改为字符串类型
    expert_data: dict,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """更新任务达人（管理员）"""
    from sqlalchemy.exc import IntegrityError
    
    try:
        expert = db.query(models.FeaturedTaskExpert).filter(
            models.FeaturedTaskExpert.id == expert_id
        ).first()
        
        if not expert:
            raise HTTPException(status_code=404, detail="任务达人不存在")
        
        # 1. 禁止修改 user_id 和 id（主键不能修改）
        if 'user_id' in expert_data and expert_data['user_id'] != expert.user_id:
            raise HTTPException(status_code=400, detail="不允许修改 user_id，如需更换用户请删除后重新创建")
        
        if 'id' in expert_data and expert_data['id'] != expert.id:
            raise HTTPException(status_code=400, detail="不允许修改 id（主键），如需更换用户请删除后重新创建")
        
        # 2. 如果提供了 user_id，验证用户是否存在
        if 'user_id' in expert_data:
            user_id = expert_data['user_id']
            if not isinstance(user_id, str) or len(user_id) != 8:
                raise HTTPException(status_code=400, detail="user_id 必须是8位字符串")
            
            user = db.query(models.User).filter(models.User.id == user_id).first()
            if not user:
                raise HTTPException(status_code=404, detail="用户不存在")
        
        # 将数组字段转换为 JSON
        for field in ['expertise_areas', 'expertise_areas_en', 'featured_skills', 'featured_skills_en', 'achievements', 'achievements_en']:
            if field in expert_data and isinstance(expert_data[field], list):
                expert_data[field] = json.dumps(expert_data[field])
        
        # 从 expert_data 中移除 id 和 user_id（不允许更新）
        expert_data.pop('id', None)
        expert_data.pop('user_id', None)
        
        # 保存旧头像URL，用于后续删除
        # 注意：只要 expert_data 中包含 'avatar' 字段（无论值是什么），都应该保存旧头像URL
        # 这样即使传入空字符串清空头像，也能删除旧头像文件
        old_avatar_url = expert.avatar if 'avatar' in expert_data else None
        
        # 记录要更新的字段（用于调试）
        logger.info(f"更新任务达人 {expert_id}，接收到的字段: {list(expert_data.keys())}")
        if 'location' in expert_data:
            logger.info(f"location 字段值: {expert_data['location']}")
        
        # 更新字段（排除主键 id，因为它不应该被更新）
        # 注意：id 和 user_id 的同步已经在上面处理过了，这里只需要更新其他字段
        excluded_fields = {'id', 'user_id'}  # 主键和关联字段不应该通过循环更新
        # 需要特殊处理的字段：如果值为空字符串或None，且原值存在，则跳过更新（避免覆盖原有数据）
        preserve_if_empty_fields = {'avatar'}  # 头像字段：如果新值为空且原值存在，则保留原值
        updated_fields = []
        for key, value in expert_data.items():
            if key not in excluded_fields and hasattr(expert, key):
                # 跳过只读字段或不应该更新的字段
                if key not in ['created_at', 'created_by']:  # 创建时间和创建者不应该被更新
                    old_value = getattr(expert, key, None)
                    # 对于需要保留的字段，如果新值为空且原值存在，则跳过更新
                    if key in preserve_if_empty_fields:
                        if (value is None or value == '') and old_value:
                            logger.info(f"跳过更新字段 {key}：新值为空，保留原值 {old_value}")
                            continue
                    setattr(expert, key, value)
                    updated_fields.append(f"{key}: {old_value} -> {value}")
        
        logger.info(f"更新的字段: {updated_fields}")
        
        # 如果更新了名字，同步更新 TaskExpert 表中的 expert_name
        # 检查 name 是否在 expert_data 中且不在排除字段中（说明会被更新）
        if 'name' in expert_data and 'name' not in excluded_fields:
            # 重要：预加载 services 关系，避免级联删除问题
            from sqlalchemy.orm import joinedload
            task_expert = db.query(models.TaskExpert).options(
                joinedload(models.TaskExpert.services)
            ).filter(
                models.TaskExpert.id == expert.user_id
            ).first()
            if task_expert:
                # 使用更新后的 expert.name（在 commit 前已经通过 setattr 更新）
                task_expert.expert_name = expert.name
                task_expert.updated_at = get_utc_time()
                logger.info(f"同步更新 TaskExpert.expert_name: {task_expert.expert_name} (来自 FeaturedTaskExpert.name: {expert.name})")
            else:
                logger.warning(f"未找到对应的 TaskExpert 记录 (user_id: {expert.user_id})")
        
        # 如果更新了头像，同步更新 TaskExpert 表中的 avatar
        # 检查 avatar 是否在 expert_data 中且不在排除字段中（说明会被更新）
        if 'avatar' in expert_data and 'avatar' not in excluded_fields:
            # 直接检查传入的 avatar 值，只有当传入的是有效的非空 URL 时才同步更新
            # 不能传递空值，只能传递更新有 url 的头像值
            avatar_value = expert_data.get('avatar')
            if avatar_value and avatar_value.strip():  # 确保不是 None、空字符串或只有空白字符
                # 重要：预加载 services 关系，避免级联删除问题
                from sqlalchemy.orm import joinedload
                task_expert = db.query(models.TaskExpert).options(
                    joinedload(models.TaskExpert.services)
                ).filter(
                    models.TaskExpert.id == expert.user_id
                ).first()
                if task_expert:
                    # 使用传入的有效头像 URL（expert.avatar 已经通过 setattr 更新）
                    task_expert.avatar = expert.avatar
                    task_expert.updated_at = get_utc_time()
                    logger.info(f"同步更新 TaskExpert.avatar: {task_expert.avatar} (来自 FeaturedTaskExpert.avatar: {expert.avatar})")
                else:
                    logger.warning(f"未找到对应的 TaskExpert 记录 (user_id: {expert.user_id})")
            else:
                logger.info(f"跳过同步更新头像：传入的 avatar 值为空或无效 (user_id: {expert.user_id})")
        
        expert.updated_at = get_utc_time()
        db.commit()
        db.refresh(expert)
        
        # 验证 location 是否已更新
        logger.info(f"更新后的 location 值: {expert.location}")
        
        # 如果更换了头像，删除旧头像
        if old_avatar_url and 'avatar' in expert_data and old_avatar_url != expert_data['avatar']:
            from app.image_cleanup import delete_expert_avatar
            try:
                delete_expert_avatar(expert_id, old_avatar_url)
            except Exception as e:
                logger.warning(f"删除旧头像失败: {e}")
        
        logger.info(f"更新任务达人成功: {expert_id}")
        
        return {
            "message": "更新任务达人成功",
            "task_expert": {"id": expert.id, "name": expert.name}
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"更新任务达人失败: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"更新任务达人失败: {str(e)}")


@router.delete("/admin/task-expert/{expert_id}")
def delete_task_expert(
    expert_id: str,  # 改为字符串类型
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """删除任务达人（管理员）"""
    try:
        expert = db.query(models.FeaturedTaskExpert).filter(
            models.FeaturedTaskExpert.id == expert_id
        ).first()
        
        if not expert:
            raise HTTPException(status_code=404, detail="任务达人不存在")
        
        db.delete(expert)
        db.commit()
        
        logger.info(f"删除任务达人成功: {expert_id}")
        
        return {"message": "删除任务达人成功"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"删除任务达人失败: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"删除任务达人失败: {str(e)}")


# ==================== 管理员管理任务达人服务和活动 API ====================

@router.get("/admin/task-expert/{expert_id}/services")
def get_expert_services_admin(
    expert_id: str,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取任务达人的服务列表（管理员）"""
    try:
        # 验证任务达人是否存在
        expert = db.query(models.TaskExpert).filter(models.TaskExpert.id == expert_id).first()
        if not expert:
            raise HTTPException(status_code=404, detail="任务达人不存在")
        
        services = db.query(models.TaskExpertService).filter(
            models.TaskExpertService.expert_id == expert_id
        ).order_by(models.TaskExpertService.display_order, models.TaskExpertService.created_at.desc()).all()
        
        return {
            "services": [
                {
                    "id": s.id,
                    "expert_id": s.expert_id,
                    "service_name": s.service_name,
                    "description": s.description,
                    "images": s.images,
                    "base_price": float(s.base_price) if s.base_price else 0,
                    "currency": s.currency,
                    "status": s.status,
                    "display_order": s.display_order,
                    "view_count": s.view_count,
                    "application_count": s.application_count,
                    "has_time_slots": s.has_time_slots,
                    "time_slot_duration_minutes": s.time_slot_duration_minutes,
                    "time_slot_start_time": str(s.time_slot_start_time) if s.time_slot_start_time else None,
                    "time_slot_end_time": str(s.time_slot_end_time) if s.time_slot_end_time else None,
                    "participants_per_slot": s.participants_per_slot,
                    "weekly_time_slot_config": s.weekly_time_slot_config,
                    "created_at": s.created_at.isoformat() if s.created_at else None,
                    "updated_at": s.updated_at.isoformat() if s.updated_at else None,
                }
                for s in services
            ]
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取任务达人服务列表失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取服务列表失败: {str(e)}")


@router.put("/admin/task-expert/{expert_id}/services/{service_id}")
def update_expert_service_admin(
    expert_id: str,
    service_id: int,
    service_data: dict,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """更新任务达人的服务（管理员）"""
    try:
        # 验证任务达人是否存在
        expert = db.query(models.TaskExpert).filter(models.TaskExpert.id == expert_id).first()
        if not expert:
            raise HTTPException(status_code=404, detail="任务达人不存在")
        
        # 验证服务是否存在且属于该任务达人
        service = db.query(models.TaskExpertService).filter(
            models.TaskExpertService.id == service_id,
            models.TaskExpertService.expert_id == expert_id
        ).first()
        if not service:
            raise HTTPException(status_code=404, detail="服务不存在")
        
        # 更新服务字段
        for key, value in service_data.items():
            if hasattr(service, key) and key not in ['id', 'expert_id', 'created_at']:
                if key == 'base_price' and value is not None:
                    from decimal import Decimal
                    setattr(service, key, Decimal(str(value)))
                elif key in ['time_slot_start_time', 'time_slot_end_time'] and value:
                    from datetime import time as dt_time
                    setattr(service, key, dt_time.fromisoformat(value))
                elif key == 'weekly_time_slot_config':
                    # weekly_time_slot_config是JSONB字段，直接设置
                    setattr(service, key, value)
                else:
                    setattr(service, key, value)
        
        service.updated_at = get_utc_time()
        db.commit()
        
        logger.info(f"管理员 {current_admin.id} 更新任务达人 {expert_id} 的服务 {service_id}")
        
        return {"message": "服务更新成功", "service_id": service_id}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"更新服务失败: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"更新服务失败: {str(e)}")


@router.delete("/admin/task-expert/{expert_id}/services/{service_id}")
def delete_expert_service_admin(
    expert_id: str,
    service_id: int,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """删除任务达人的服务（管理员）"""
    try:
        # 验证任务达人是否存在
        expert = db.query(models.TaskExpert).filter(models.TaskExpert.id == expert_id).first()
        if not expert:
            raise HTTPException(status_code=404, detail="任务达人不存在")
        
        # 验证服务是否存在且属于该任务达人
        service = db.query(models.TaskExpertService).filter(
            models.TaskExpertService.id == service_id,
            models.TaskExpertService.expert_id == expert_id
        ).first()
        if not service:
            raise HTTPException(status_code=404, detail="服务不存在")
        
        # 检查是否有任务正在使用这个服务
        tasks_using_service = db.query(models.Task).filter(
            models.Task.expert_service_id == service_id
        ).count()
        
        # 检查是否有活动正在使用这个服务
        activities_using_service = db.query(models.Activity).filter(
            models.Activity.expert_service_id == service_id
        ).count()
        
        if tasks_using_service > 0 or activities_using_service > 0:
            error_msg = "无法删除服务，因为"
            reasons = []
            if tasks_using_service > 0:
                reasons.append(f"有 {tasks_using_service} 个任务正在使用此服务")
            if activities_using_service > 0:
                reasons.append(f"有 {activities_using_service} 个活动正在使用此服务")
            error_msg += "、" .join(reasons) + "。请先处理相关任务和活动后再删除。"
            raise HTTPException(status_code=400, detail=error_msg)
        
        # 检查是否有未过期且仍有参与者的时间段
        from app.utils.time_utils import get_utc_time
        current_utc = get_utc_time()
        
        future_slots_with_participants = db.query(models.ServiceTimeSlot).filter(
            models.ServiceTimeSlot.service_id == service_id,
            models.ServiceTimeSlot.slot_start_datetime >= current_utc,
            models.ServiceTimeSlot.current_participants > 0
        ).count()
        
        if future_slots_with_participants > 0:
            raise HTTPException(
                status_code=400,
                detail=f"无法删除服务，因为有 {future_slots_with_participants} 个未过期的时间段仍有参与者。请等待时间段过期或处理相关参与者后再删除。"
            )
        
        # 查找所有相关的 ServiceTimeSlot IDs
        time_slots = db.query(models.ServiceTimeSlot.id).filter(
            models.ServiceTimeSlot.service_id == service_id
        ).all()
        time_slot_ids = [row[0] for row in time_slots]
        
        if time_slot_ids:
            # 删除所有 TaskTimeSlotRelation 记录
            db.query(models.TaskTimeSlotRelation).filter(
                models.TaskTimeSlotRelation.time_slot_id.in_(time_slot_ids)
            ).delete(synchronize_session=False)
            
            # 删除所有 ActivityTimeSlotRelation 记录
            db.query(models.ActivityTimeSlotRelation).filter(
                models.ActivityTimeSlotRelation.time_slot_id.in_(time_slot_ids)
            ).delete(synchronize_session=False)
        
        # 删除服务图片（如果存在）
        service_images = service.images if hasattr(service, 'images') and service.images else []
        if service_images:
            from app.image_cleanup import delete_service_images
            try:
                import json
                if isinstance(service_images, str):
                    image_urls = json.loads(service_images)
                elif isinstance(service_images, list):
                    image_urls = service_images
                else:
                    image_urls = []
                
                delete_service_images(expert_id, service_id, image_urls)
            except Exception as e:
                logger.warning(f"删除服务图片失败: {e}")
        
        # 更新任务达人的服务数量
        expert.total_services = max(0, expert.total_services - 1)
        
        # 现在安全地删除服务（cascades 到 ServiceTimeSlot）
        db.delete(service)
        db.commit()
        
        logger.info(f"管理员 {current_admin.id} 删除任务达人 {expert_id} 的服务 {service_id}")
        
        return {"message": "服务删除成功"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"删除服务失败: {e}")
        db.rollback()
        # 如果是外键约束错误，提供更友好的错误消息
        if "foreign key constraint" in str(e).lower() or "referenced" in str(e).lower():
            raise HTTPException(
                status_code=400,
                detail="无法删除服务，因为有任务或活动正在使用此服务。请先处理相关任务和活动后再删除。"
            )
        raise HTTPException(status_code=500, detail=f"删除服务失败: {str(e)}")


@router.get("/admin/task-expert/{expert_id}/activities")
def get_expert_activities_admin(
    expert_id: str,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取任务达人的活动列表（管理员）"""
    try:
        # 验证任务达人是否存在
        expert = db.query(models.TaskExpert).filter(models.TaskExpert.id == expert_id).first()
        if not expert:
            raise HTTPException(status_code=404, detail="任务达人不存在")
        
        activities = db.query(models.Activity).filter(
            models.Activity.expert_id == expert_id
        ).order_by(models.Activity.created_at.desc()).all()
        
        return {
            "activities": [
                {
                    "id": a.id,
                    "title": a.title,
                    "description": a.description,
                    "expert_id": a.expert_id,
                    "expert_service_id": a.expert_service_id,
                    "location": a.location,
                    "task_type": a.task_type,
                    "reward_type": a.reward_type,
                    "original_price_per_participant": float(a.original_price_per_participant) if a.original_price_per_participant else None,
                    "discount_percentage": float(a.discount_percentage) if a.discount_percentage else None,
                    "discounted_price_per_participant": float(a.discounted_price_per_participant) if a.discounted_price_per_participant else None,
                    "currency": a.currency,
                    "points_reward": a.points_reward,
                    "max_participants": a.max_participants,
                    "min_participants": a.min_participants,
                    "completion_rule": a.completion_rule,
                    "reward_distribution": a.reward_distribution,
                    "status": a.status,
                    "is_public": a.is_public,
                    "visibility": a.visibility,
                    "deadline": a.deadline.isoformat() if a.deadline else None,
                    "activity_end_date": a.activity_end_date.isoformat() if a.activity_end_date else None,
                    "images": a.images,
                    "has_time_slots": a.has_time_slots,
                    "created_at": a.created_at.isoformat() if a.created_at else None,
                }
                for a in activities
            ]
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取任务达人活动列表失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取活动列表失败: {str(e)}")


@router.put("/admin/task-expert/{expert_id}/activities/{activity_id}")
def update_expert_activity_admin(
    expert_id: str,
    activity_id: int,
    activity_data: dict,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """更新任务达人的活动（管理员）"""
    try:
        # 验证任务达人是否存在
        expert = db.query(models.TaskExpert).filter(models.TaskExpert.id == expert_id).first()
        if not expert:
            raise HTTPException(status_code=404, detail="任务达人不存在")
        
        # 验证活动是否存在且属于该任务达人
        activity = db.query(models.Activity).filter(
            models.Activity.id == activity_id,
            models.Activity.expert_id == expert_id
        ).first()
        if not activity:
            raise HTTPException(status_code=404, detail="活动不存在")
        
        # 更新活动字段
        for key, value in activity_data.items():
            if hasattr(activity, key) and key not in ['id', 'expert_id', 'created_at']:
                if key in ['original_price_per_participant', 'discount_percentage', 'discounted_price_per_participant'] and value is not None:
                    from decimal import Decimal
                    setattr(activity, key, Decimal(str(value)))
                elif key in ['deadline'] and value:
                    from datetime import datetime
                    setattr(activity, key, datetime.fromisoformat(value.replace('Z', '+00:00')))
                elif key in ['activity_end_date'] and value:
                    from datetime import date
                    setattr(activity, key, date.fromisoformat(value))
                else:
                    setattr(activity, key, value)
        
        db.commit()
        
        logger.info(f"管理员 {current_admin.id} 更新任务达人 {expert_id} 的活动 {activity_id}")
        
        return {"message": "活动更新成功", "activity_id": activity_id}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"更新活动失败: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"更新活动失败: {str(e)}")


@router.delete("/admin/task-expert/{expert_id}/activities/{activity_id}")
def delete_expert_activity_admin(
    expert_id: str,
    activity_id: int,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    删除任务达人的活动（管理员）- 级联删除
    
    管理员权限：
    - 可以删除任何状态的活动
    - 级联删除：会自动删除该活动关联的所有任务（无论任务状态如何）
    """
    try:
        # 验证任务达人是否存在
        expert = db.query(models.TaskExpert).filter(models.TaskExpert.id == expert_id).first()
        if not expert:
            raise HTTPException(status_code=404, detail="任务达人不存在")
        
        # 验证活动是否存在且属于该任务达人
        activity = db.query(models.Activity).filter(
            models.Activity.id == activity_id,
            models.Activity.expert_id == expert_id
        ).first()
        if not activity:
            raise HTTPException(status_code=404, detail="活动不存在")
        
        # 级联删除逻辑：先删除所有关联的任务
        # 注意：Task.participants 和 Task.time_slot_relations 配置了 cascade="all, delete-orphan"，会自动删除
        related_tasks = db.query(models.Task).filter(
            models.Task.parent_activity_id == activity_id
        ).all()
        
        deleted_tasks_count = len(related_tasks)
        if related_tasks:
            # 先删除任务的时间段关联，避免 task_id 置空触发 NOT NULL 约束
            task_ids = [t.id for t in related_tasks]
            
            # 清理任务相关的历史/审计/奖励/参与者，防止外键约束阻止删除
            db.query(models.TaskHistory).filter(
                models.TaskHistory.task_id.in_(task_ids)
            ).delete(synchronize_session=False)
            db.query(models.TaskAuditLog).filter(
                models.TaskAuditLog.task_id.in_(task_ids)
            ).delete(synchronize_session=False)
            db.query(models.TaskParticipantReward).filter(
                models.TaskParticipantReward.task_id.in_(task_ids)
            ).delete(synchronize_session=False)
            db.query(models.TaskParticipant).filter(
                models.TaskParticipant.task_id.in_(task_ids)
            ).delete(synchronize_session=False)
            db.query(models.TaskTimeSlotRelation).filter(
                models.TaskTimeSlotRelation.task_id.in_(task_ids)
            ).delete(synchronize_session=False)
            
            # 确保子表删除语句立即执行，避免后续删除任务时触发外键约束
            db.flush()
            
            for task in related_tasks:
                db.delete(task)
            logger.info(f"管理员 {current_admin.id} 删除活动 {activity_id} 时级联删除了 {deleted_tasks_count} 个关联任务（含时间段关联）")
        
        # 删除活动与时间段的关联关系（虽然外键有CASCADE，但显式删除更清晰）
        # 注意：这里只删除关联关系，不会删除时间段本身（ServiceTimeSlot），因为时间段是服务的资源
        db.query(models.ActivityTimeSlotRelation).filter(
            models.ActivityTimeSlotRelation.activity_id == activity_id
        ).delete(synchronize_session=False)
        
        # 删除活动（ActivityTimeSlotRelation 会通过外键 CASCADE 自动删除，但上面已经显式删除）
        db.delete(activity)
        db.commit()
        
        logger.info(f"管理员 {current_admin.id} 删除任务达人 {expert_id} 的活动 {activity_id}")
        
        return {
            "message": "活动及关联任务删除成功",
            "deleted_tasks_count": deleted_tasks_count
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"删除活动失败: {e}")
        db.rollback()
        # 如果是外键约束错误，提供更友好的错误消息
        if "foreign key constraint" in str(e).lower() or "referenced" in str(e).lower():
            raise HTTPException(
                status_code=400,
                detail=f"删除失败（外键约束）：{str(e)}"
            )
        raise HTTPException(status_code=500, detail=f"删除活动失败: {str(e)}")


@router.post("/admin/task-expert/{expert_id}/services/{service_id}/time-slots/batch-create")
def batch_create_service_time_slots_admin(
    expert_id: str,
    service_id: int,
    start_date: str = Query(..., description="开始日期，格式：YYYY-MM-DD"),
    end_date: str = Query(..., description="结束日期，格式：YYYY-MM-DD"),
    price_per_participant: float = Query(..., description="每个参与者的价格"),
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """批量创建服务时间段（管理员）"""
    try:
        # 验证任务达人是否存在
        expert = db.query(models.TaskExpert).filter(models.TaskExpert.id == expert_id).first()
        if not expert:
            raise HTTPException(status_code=404, detail="任务达人不存在")
        
        # 验证服务是否存在且属于该任务达人
        service = db.query(models.TaskExpertService).filter(
            models.TaskExpertService.id == service_id,
            models.TaskExpertService.expert_id == expert_id
        ).first()
        if not service:
            raise HTTPException(status_code=404, detail="服务不存在")
        
        # 验证服务是否启用了时间段
        if not service.has_time_slots:
            raise HTTPException(status_code=400, detail="该服务未启用时间段功能")
        
        # 检查配置：优先使用 weekly_time_slot_config，否则使用旧的 time_slot_start_time/time_slot_end_time
        has_weekly_config = service.weekly_time_slot_config and isinstance(service.weekly_time_slot_config, dict)
        
        if not has_weekly_config:
            # 使用旧的配置方式（向后兼容）
            if not service.time_slot_start_time or not service.time_slot_end_time or not service.time_slot_duration_minutes or not service.participants_per_slot:
                raise HTTPException(status_code=400, detail="服务的时间段配置不完整")
        else:
            # 使用新的按周几配置
            if not service.time_slot_duration_minutes or not service.participants_per_slot:
                raise HTTPException(status_code=400, detail="服务的时间段配置不完整（缺少时间段时长或参与者数量）")
        
        # 解析日期
        from datetime import date, timedelta, time as dt_time, datetime as dt_datetime
        from decimal import Decimal
        from app.utils.time_utils import parse_local_as_utc, LONDON
        
        try:
            start = date.fromisoformat(start_date)
            end = date.fromisoformat(end_date)
            if start > end:
                raise HTTPException(status_code=400, detail="开始日期必须早于或等于结束日期")
        except ValueError:
            raise HTTPException(status_code=400, detail="日期格式错误，应为YYYY-MM-DD")
        
        # 生成时间段（使用UTC时间存储）
        created_slots = []
        current_date = start
        duration_minutes = service.time_slot_duration_minutes
        price_decimal = Decimal(str(price_per_participant))
        
        # 周几名称映射（Python的weekday(): 0=Monday, 6=Sunday）
        weekday_names = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
        
        while current_date <= end:
            # 获取当前日期是周几（0=Monday, 6=Sunday）
            weekday = current_date.weekday()
            weekday_name = weekday_names[weekday]
            
            # 确定该日期的时间段配置
            if has_weekly_config:
                # 使用按周几配置
                day_config = service.weekly_time_slot_config.get(weekday_name, {})
                if not day_config.get('enabled', False):
                    # 该周几未启用，跳过
                    current_date += timedelta(days=1)
                    continue
                
                slot_start_time_str = day_config.get('start_time', '09:00:00')
                slot_end_time_str = day_config.get('end_time', '18:00:00')
                
                # 解析时间字符串
                try:
                    slot_start_time = dt_time.fromisoformat(slot_start_time_str)
                    slot_end_time = dt_time.fromisoformat(slot_end_time_str)
                except ValueError:
                    # 如果格式不对，尝试添加秒数
                    if len(slot_start_time_str) == 5:  # HH:MM
                        slot_start_time_str += ':00'
                    if len(slot_end_time_str) == 5:  # HH:MM
                        slot_end_time_str += ':00'
                    slot_start_time = dt_time.fromisoformat(slot_start_time_str)
                    slot_end_time = dt_time.fromisoformat(slot_end_time_str)
            else:
                # 使用旧的统一配置
                slot_start_time = service.time_slot_start_time
                slot_end_time = service.time_slot_end_time
            
            # 检查该日期是否被手动删除（跳过手动删除的日期）
            start_local = dt_datetime.combine(current_date, dt_time(0, 0, 0))
            end_local = dt_datetime.combine(current_date, dt_time(23, 59, 59))
            start_utc = parse_local_as_utc(start_local, LONDON)
            end_utc = parse_local_as_utc(end_local, LONDON)
            
            # 检查该日期是否有手动删除的时间段
            deleted_check = db.query(models.ServiceTimeSlot).filter(
                models.ServiceTimeSlot.service_id == service_id,
                models.ServiceTimeSlot.slot_start_datetime >= start_utc,
                models.ServiceTimeSlot.slot_start_datetime <= end_utc,
                models.ServiceTimeSlot.is_manually_deleted == True,
            ).first()
            if deleted_check:
                # 该日期已被手动删除，跳过
                current_date += timedelta(days=1)
                continue
            
            # 计算该日期的时间段
            current_time = slot_start_time
            while current_time < slot_end_time:
                # 计算结束时间
                total_minutes = current_time.hour * 60 + current_time.minute + duration_minutes
                end_hour = total_minutes // 60
                end_minute = total_minutes % 60
                if end_hour >= 24:
                    break  # 超出一天，跳过
                
                slot_end = dt_time(end_hour, end_minute)
                if slot_end > slot_end_time:
                    break  # 超出服务允许的结束时间
                
                # 将英国时间的日期+时间组合，然后转换为UTC
                slot_start_local = dt_datetime.combine(current_date, current_time)
                slot_end_local = dt_datetime.combine(current_date, slot_end)
                
                # 转换为UTC时间
                slot_start_utc = parse_local_as_utc(slot_start_local, LONDON)
                slot_end_utc = parse_local_as_utc(slot_end_local, LONDON)
                
                # 检查是否已存在且未被手动删除
                existing = db.query(models.ServiceTimeSlot).filter(
                    models.ServiceTimeSlot.service_id == service_id,
                    models.ServiceTimeSlot.slot_start_datetime == slot_start_utc,
                    models.ServiceTimeSlot.slot_end_datetime == slot_end_utc,
                    models.ServiceTimeSlot.is_manually_deleted == False,
                ).first()
                if not existing:
                    # 创建新时间段（使用UTC时间）
                    new_slot = models.ServiceTimeSlot(
                        service_id=service_id,
                        slot_start_datetime=slot_start_utc,
                        slot_end_datetime=slot_end_utc,
                        price_per_participant=price_decimal,
                        max_participants=service.participants_per_slot,
                        current_participants=0,
                        is_available=True,
                        is_manually_deleted=False,
                    )
                    db.add(new_slot)
                    created_slots.append(new_slot)
                
                # 移动到下一个时间段
                total_minutes = current_time.hour * 60 + current_time.minute + duration_minutes
                next_hour = total_minutes // 60
                next_minute = total_minutes % 60
                if next_hour >= 24:
                    break
                current_time = dt_time(next_hour, next_minute)
            
            # 移动到下一天
            current_date += timedelta(days=1)
        
        db.commit()
        
        logger.info(f"管理员 {current_admin.id} 为任务达人 {expert_id} 的服务 {service_id} 批量创建了 {len(created_slots)} 个时间段")
        
        return {
            "message": f"成功创建 {len(created_slots)} 个时间段",
            "created_count": len(created_slots),
            "service_id": service_id,
            "expert_id": expert_id
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"批量创建时间段失败: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"批量创建时间段失败: {str(e)}")


# 公开 API - 获取任务达人列表（前端使用）
@router.get("/task-experts")
@measure_api_performance("get_task_experts")
@cache_response(ttl=600, key_prefix="public_task_experts")  # 缓存10分钟
def get_public_task_experts(
    category: Optional[str] = None,
    location: Optional[str] = Query(None, description="城市筛选"),
    db: Session = Depends(get_db),
):
    """获取任务达人列表（公开）"""
    try:
        query = db.query(models.FeaturedTaskExpert).filter(
            models.FeaturedTaskExpert.is_active == 1
        )
        
        if category:
            query = query.filter(models.FeaturedTaskExpert.category == category)
        
        if location and location != 'all':
            # 处理location筛选：支持精确匹配，同时处理NULL和空字符串的情况
            # 如果筛选"Online"，也要匹配NULL和空字符串的记录（因为后端返回时会将它们转换为"Online"）
            if location == 'Online':
                query = query.filter(
                    or_(
                        models.FeaturedTaskExpert.location == 'Online',
                        models.FeaturedTaskExpert.location == None,
                        models.FeaturedTaskExpert.location == '',
                        models.FeaturedTaskExpert.location.is_(None)  # 使用is_()检查NULL
                    )
                )
            else:
                # 对于其他城市，进行精确匹配
                # 注意：数据库中的location值应该与筛选器中的值完全匹配
                query = query.filter(models.FeaturedTaskExpert.location == location)
        
        # 排序
        query = query.order_by(
            models.FeaturedTaskExpert.display_order,
            models.FeaturedTaskExpert.created_at.desc()
        )
        
        experts = query.all()
        
        # ⚠️ 如果完成率为0，尝试实时计算（可能是数据未更新）
        from app.models import Task
        result_experts = []
        for expert in experts:
            completion_rate = expert.completion_rate
            # 如果完成率为0，尝试实时计算
            if completion_rate == 0.0:
                taken_tasks = db.query(Task).filter(Task.taker_id == expert.id).count()
                completed_taken_tasks = db.query(Task).filter(
                    Task.taker_id == expert.id,
                    Task.status == "completed"
                ).count()
                if taken_tasks > 0:
                    completion_rate = (completed_taken_tasks / taken_tasks) * 100.0
                    # 更新数据库中的值（异步，不阻塞返回）
                    try:
                        expert.completion_rate = completion_rate
                        db.commit()
                    except Exception as e:
                        logger.warning(f"更新任务达人 {expert.id} 完成率失败: {e}")
                        db.rollback()
            
            result_experts.append({
                "id": expert.id,  # id 现在就是 user_id
                "name": expert.name,
                "avatar": expert.avatar,
                "user_level": expert.user_level,
                "avg_rating": expert.avg_rating,
                "completed_tasks": expert.completed_tasks,
                "total_tasks": expert.total_tasks,
                "completion_rate": round(completion_rate, 1),
                "expertise_areas": json.loads(expert.expertise_areas) if expert.expertise_areas else [],
                "featured_skills": json.loads(expert.featured_skills) if expert.featured_skills else [],
                "achievements": json.loads(expert.achievements) if expert.achievements else [],
                "is_verified": bool(expert.is_verified),
                "bio": expert.bio,
                "response_time": expert.response_time,
                "success_rate": expert.success_rate,
                "location": expert.location if expert.location and expert.location.strip() else "Online",  # 添加城市字段，处理NULL和空字符串
                "category": expert.category if hasattr(expert, 'category') else None,  # 添加类别字段
            })
        
        return {
            "task_experts": result_experts
        }
    except Exception as e:
        logger.error(f"获取任务达人列表失败: {e}")
        raise HTTPException(status_code=500, detail="获取任务达人列表失败")


# 翻译API
@router.post("/translate")
async def translate_text(
    request: Request,
):
    """
    翻译文本
    
    参数:
    - text: 要翻译的文本
    - target_language: 目标语言代码 (如 'en', 'zh', 'zh-cn')
    - source_language: 源语言代码 (可选, 如果不提供则自动检测)
    
    返回:
    - translated_text: 翻译后的文本
    - source_language: 检测到的源语言
    """
    try:
        # 获取请求体
        body = await request.json()
        logger.info(f"翻译请求收到: {body}")
        
        text = body.get('text', '')
        target_language = body.get('target_language', 'en')
        source_language = body.get('source_language')
        
        if not text:
            raise HTTPException(status_code=400, detail="缺少text参数")
        if not target_language:
            raise HTTPException(status_code=400, detail="缺少target_language参数")
        try:
            from deep_translator import GoogleTranslator
        except ImportError:
            logger.error("deep-translator模块未安装，请运行: pip install deep-translator")
            raise HTTPException(
                status_code=503, 
                detail="翻译服务暂时不可用，请稍后重试。管理员请检查deep-translator模块是否已安装。"
            )
        
        # 转换语言代码格式 (zh -> zh-CN, en -> en)
        lang_map = {
            'zh': 'zh-CN',
            'zh-cn': 'zh-CN',
            'zh-tw': 'zh-TW',
            'en': 'en'
        }
        target_lang = lang_map.get(target_language.lower(), target_language)
        source_lang = lang_map.get(source_language.lower(), source_language) if source_language else 'auto'
        
        logger.info(f"开始翻译: text={text[:50]}..., target={target_lang}, source={source_lang}")
        
        # 使用GoogleTranslator进行翻译
        if source_language and source_lang != 'auto':
            translator = GoogleTranslator(source=source_lang, target=target_lang)
        else:
            translator = GoogleTranslator(target=target_lang)
        
        translated_text = translator.translate(text)
        logger.info(f"翻译完成: {translated_text[:50]}...")
        
        # 检测源语言（如果未提供）
        detected_source = source_lang if source_lang != 'auto' else 'auto'
        
        return {
            "translated_text": translated_text,
            "source_language": detected_source,
            "target_language": target_lang,
            "original_text": text
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"翻译失败: {e}")
        raise HTTPException(status_code=500, detail=f"翻译失败: {str(e)}")


@router.post("/translate/batch")
async def translate_batch(
    request: Request,
):
    """
    批量翻译文本
    
    参数:
    - texts: 要翻译的文本列表
    - target_language: 目标语言代码
    - source_language: 源语言代码 (可选)
    
    返回:
    - translations: 翻译结果列表
    """
    try:
        # 获取请求体
        body = await request.json()
        logger.info(f"批量翻译请求收到: texts数量={len(body.get('texts', []))}")
        
        texts = body.get('texts', [])
        target_language = body.get('target_language', 'en')
        source_language = body.get('source_language')
        
        if not texts:
            raise HTTPException(status_code=400, detail="缺少texts参数")
        if not target_language:
            raise HTTPException(status_code=400, detail="缺少target_language参数")
        
        try:
            from deep_translator import GoogleTranslator
            from app.utils.time_utils import get_utc_time
            from zoneinfo import ZoneInfo
        except ImportError:
            logger.error("deep-translator模块未安装，请运行: pip install deep-translator")
            raise HTTPException(
                status_code=503, 
                detail="翻译服务暂时不可用，请稍后重试。管理员请检查deep-translator模块是否已安装。"
            )
        
        # 转换语言代码格式
        lang_map = {
            'zh': 'zh-CN',
            'zh-cn': 'zh-CN',
            'zh-tw': 'zh-TW',
            'en': 'en'
        }
        target_lang = lang_map.get(target_language.lower(), target_language)
        source_lang = lang_map.get(source_language.lower(), source_language) if source_language else 'auto'
        
        translations = []
        
        for text in texts:
            try:
                if source_language and source_lang != 'auto':
                    translator = GoogleTranslator(source=source_lang, target=target_lang)
                else:
                    translator = GoogleTranslator(target=target_lang)
                
                translated_text = translator.translate(text)
                
                translations.append({
                    "original_text": text,
                    "translated_text": translated_text,
                    "source_language": source_lang if source_lang != 'auto' else 'auto',
                })
            except Exception as e:
                logger.error(f"翻译文本失败: {text[:50]}... - {e}")
                translations.append({
                    "original_text": text,
                    "translated_text": text,  # 翻译失败时返回原文
                    "source_language": "unknown",
                    "error": str(e)
                })
        
        return {
            "translations": translations,
            "target_language": target_lang
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"批量翻译失败: {e}")
        raise HTTPException(status_code=500, detail=f"批量翻译失败: {str(e)}")


@router.post("/admin/cleanup/completed-tasks")
def cleanup_completed_tasks_files_api(
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """清理已完成超过3天的任务的图片和文件（管理员接口）"""
    try:
        cleaned_count = crud.cleanup_completed_tasks_files(db)
        return {
            "success": True,
            "message": f"成功清理 {cleaned_count} 个已完成超过3天的任务的文件",
            "cleaned_count": cleaned_count
        }
    except Exception as e:
        logger.error(f"清理已完成任务文件失败: {e}")
        raise HTTPException(status_code=500, detail=f"清理失败: {str(e)}")


@router.post("/admin/cleanup/all-old-tasks")
def cleanup_all_old_tasks_files_api(
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """一键清理所有已完成或已取消任务的图片和文件（管理员接口，不检查时间限制）
    清理内容包括：
    - 公开图片（任务相关图片）
    - 私密图片（任务聊天图片）
    - 私密文件（任务聊天文件）
    """
    try:
        result = crud.cleanup_all_completed_and_cancelled_tasks_files(db)
        return {
            "success": True,
            "message": f"清理完成：已完成任务 {result['completed_count']} 个，已取消任务 {result['cancelled_count']} 个，总计 {result['total_count']} 个任务的所有图片和文件已清理",
            "completed_count": result["completed_count"],
            "cancelled_count": result["cancelled_count"],
            "total_count": result["total_count"]
        }
    except Exception as e:
        logger.error(f"清理任务文件失败: {e}")
        raise HTTPException(status_code=500, detail=f"清理失败: {str(e)}")