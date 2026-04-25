"""
Auth-inline domain routes — extracted from app/routers.py (Task 9).

Includes the 12 auth-adjacent routes that historically lived in routers.py:
  - POST /csp-report
  - POST /password/validate
  - POST /register
  - GET  /verify-email   (and /verify-email/{token})
  - POST /resend-verification
  - POST /admin/login
  - GET  /user/info
  - GET  /confirm/{token}
  - POST /forgot_password
  - POST /reset_password/{token}
  - POST /logout   (relocated from the cs region of routers.py)

Mounts at both /api and /api/users via main.py (same as the original main_router).

Note: 10 sibling /debug/* and /register/{test,debug} endpoints were
permanently removed in this same Task 9 commit and are NOT migrated.
"""
import asyncio
import logging
from typing import Optional
from urllib.parse import quote

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    Form,
    HTTPException,
    Request,
    Response,
)
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from app import crud, models, schemas
from app.database import get_async_db
from app.deps import (
    get_current_user_optional,
    get_current_user_secure_sync_csrf,
    get_db,
)
from app.email_utils import (
    confirm_reset_token,
    generate_reset_token,
    send_reset_email,
)

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/csp-report")
async def csp_report(report: dict):
    """接收 CSP 违规报告"""
    logger.warning(f"CSP violation: {report}")
    # 可以发送到监控系统
    return {"status": "ok"}


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


@router.post("/register")
async def register(
    user: schemas.UserCreate,
    request: Request,
    response: Response,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_async_db),
):
    """User registration — validates email verification code, creates user, auto-login"""
    from app.validators import UserValidator, validate_input
    from app.security import get_password_hash
    from app.password_validator import password_validator
    from app.async_crud import async_user_crud
    from app.verification_code_manager import verify_and_delete_code

    # --- Input validation ---
    try:
        validated_data = validate_input(user.dict(), UserValidator)
        if hasattr(user, 'invitation_code') and user.invitation_code:
            validated_data['invitation_code'] = user.invitation_code
        phone_verification_code = validated_data.pop('phone_verification_code', None)
        if phone_verification_code:
            validated_data['_phone_verification_code'] = phone_verification_code
    except HTTPException:
        raise

    # --- Basic checks (English error codes) ---
    if not validated_data.get('email'):
        raise HTTPException(status_code=400, detail="email_required")

    agreed_to_terms = validated_data.get('agreed_to_terms', False)
    if not agreed_to_terms:
        raise HTTPException(status_code=400, detail="terms_not_agreed")

    # --- Email verification code ---
    verification_code = user.verification_code
    if not verification_code or not verification_code.strip():
        raise HTTPException(status_code=400, detail="verification_code_invalid")

    email = validated_data['email'].strip().lower()

    # Brute-force protection
    try:
        from app.redis_cache import get_redis_client
        _redis = get_redis_client()
        if _redis:
            attempt_key = f"verify_attempt:register:{email}"
            attempts = _redis.incr(attempt_key)
            if attempts == 1:
                _redis.expire(attempt_key, 900)
            if attempts > 5:
                raise HTTPException(status_code=429, detail="verification_code_invalid")
    except HTTPException:
        raise
    except Exception as e:
        logger.warning(f"Rate limit check failed for registration: {e}")

    if not verify_and_delete_code(email, verification_code.strip()):
        raise HTTPException(status_code=400, detail="verification_code_invalid")

    # --- Phone verification (if phone provided) ---
    phone = validated_data.get('phone')
    phone_verification_code = validated_data.pop('_phone_verification_code', None)
    if phone:
        if not phone_verification_code:
            raise HTTPException(status_code=400, detail="Phone verification code required")

        import re
        if not phone.startswith('+'):
            raise HTTPException(status_code=400, detail="Invalid phone format")
        if not re.match(r'^\+\d{10,15}$', phone):
            raise HTTPException(status_code=400, detail="Invalid phone format")

        phone_verified = False
        try:
            from app.phone_verification_code_manager import verify_and_delete_code as verify_phone
            from app.twilio_sms import twilio_sms
            if twilio_sms.use_verify_api and twilio_sms.verify_client:
                phone_verified = twilio_sms.verify_code(phone, phone_verification_code)
            else:
                phone_verified = verify_phone(phone, phone_verification_code)
        except Exception as e:
            logger.error(f"Phone verification error: {e}")
        if not phone_verified:
            raise HTTPException(status_code=400, detail="verification_code_invalid")

        db_phone_user = await async_user_crud.get_user_by_phone(db, phone)
        if db_phone_user:
            raise HTTPException(status_code=400, detail="email_already_registered")

    # --- Uniqueness checks ---
    db_user = await async_user_crud.get_user_by_email(db, email)
    if db_user:
        raise HTTPException(status_code=400, detail="email_already_registered")

    db_name = await async_user_crud.get_user_by_name(db, validated_data['name'])
    if db_name:
        raise HTTPException(status_code=400, detail="username_already_taken")

    # Reserved keywords check
    customer_service_keywords = ["客服", "customer", "service", "support", "help"]
    name_lower = validated_data['name'].lower()
    if any(kw.lower() in name_lower for kw in customer_service_keywords):
        raise HTTPException(status_code=400, detail="username_contains_reserved_keywords")

    # --- Password strength ---
    password_validation = password_validator.validate_password(
        validated_data['password'],
        username=validated_data['name'],
        email=email
    )
    if not password_validation.is_valid:
        raise HTTPException(status_code=400, detail="password_too_weak")

    # --- Invitation code processing ---
    invitation_code_id = None
    inviter_id = None
    invitation_code_text = None
    if validated_data.get('invitation_code'):
        def _process_invitation_sync():
            from app.database import SessionLocal
            from app.coupon_points_crud import process_invitation_input
            _db = SessionLocal()
            try:
                return process_invitation_input(_db, validated_data['invitation_code'])
            finally:
                _db.close()
        inviter_id, invitation_code_id, invitation_code_text, error_msg = await asyncio.to_thread(
            _process_invitation_sync
        )

    # --- Create user (verified, since email code was valid) ---
    user_data = schemas.UserCreate(**validated_data)
    new_user = await async_user_crud.create_user(db, user_data)

    from sqlalchemy import update
    await db.execute(
        update(models.User)
        .where(models.User.id == new_user.id)
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

    # --- Invitation code reward ---
    if invitation_code_id:
        _user_id_str = new_user.id
        _inv_code_id = invitation_code_id
        def _use_invitation_sync():
            from app.database import SessionLocal
            from app.coupon_points_crud import use_invitation_code
            _db = SessionLocal()
            try:
                return use_invitation_code(_db, _user_id_str, _inv_code_id)
            finally:
                _db.close()
        success, error_msg = await asyncio.to_thread(_use_invitation_sync)
        if success:
            logger.info(f"Invitation reward granted: user {new_user.id}")
        else:
            logger.warning(f"Invitation reward failed: {error_msg}")

    # --- Create session (same as secure_login) ---
    from app.secure_auth import SecureAuthManager, get_client_ip, get_device_fingerprint
    from app.secure_auth import is_mobile_app_request, create_user_refresh_token
    from app.cookie_manager import CookieManager

    device_fingerprint = get_device_fingerprint(request)
    client_ip = get_client_ip(request)
    user_agent = request.headers.get("user-agent", "")
    is_ios_app = is_mobile_app_request(request)

    refresh_token = create_user_refresh_token(
        new_user.id, client_ip, device_fingerprint, is_ios_app=is_ios_app
    )

    session = SecureAuthManager.create_session(
        user_id=new_user.id,
        device_fingerprint=device_fingerprint,
        ip_address=client_ip,
        user_agent=user_agent,
        refresh_token=refresh_token,
        is_ios_app=is_ios_app
    )

    origin = request.headers.get("origin", "")
    CookieManager.set_session_cookies(
        response=response,
        session_id=session.session_id,
        refresh_token=refresh_token,
        user_id=new_user.id,
        user_agent=user_agent,
        origin=origin
    )

    from app.csrf import CSRFProtection
    csrf_token = CSRFProtection.generate_csrf_token()
    CookieManager.set_csrf_cookie(response, csrf_token, user_agent, origin)

    is_mobile = any(kw in user_agent.lower() for kw in [
        'mobile', 'iphone', 'ipad', 'android', 'blackberry',
        'windows phone', 'opera mini', 'iemobile'
    ])

    if is_mobile:
        response.headers["X-Session-ID"] = session.session_id
        response.headers["X-User-ID"] = str(new_user.id)
        response.headers["X-Auth-Status"] = "authenticated"
        response.headers["X-Mobile-Auth"] = "true"

    logger.info(f"User registered and logged in: user_id={new_user.id}, email={email}")

    response_data = {
        "message": "Registration successful",
        "user": {
            "id": new_user.id,
            "name": new_user.name,
            "email": new_user.email,
            "phone": new_user.phone,
            "avatar": new_user.avatar or "",
            "bio": new_user.bio or "",
            "is_verified": 1,
            "user_level": new_user.user_level or "normal",
            "is_expert": 0,
            "is_student_verified": 0,
            "task_count": 0,
            "completed_task_count": 0,
            "avg_rating": 0.0,
            "residence_city": new_user.residence_city,
            "language_preference": new_user.language_preference or "en",
            "is_admin": 0,
            "created_at": new_user.created_at.isoformat() if new_user.created_at else None,
            "profile_views": 0,
            "onboarding_completed": False,
        },
        "session_id": session.session_id,
        "expires_in": 300,
        "mobile_auth": is_mobile,
        "auth_headers": {
            "X-Session-ID": session.session_id,
            "X-User-ID": new_user.id,
            "X-Auth-Status": "authenticated"
        } if is_mobile else None
    }

    if is_mobile:
        response_data["refresh_token"] = refresh_token

    return response_data


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
    # 🔒 使用原子操作 GETDEL 防止并发注册重复使用同一邀请码
    try:
        from app.redis_cache import get_redis_client
        _redis = get_redis_client()
        if _redis:
            invitation_code_key = f"registration_invitation_code:{user.email}"
            # 原子操作：获取并删除，防止竞态条件导致双重使用
            try:
                invitation_code_id_str = _redis.getdel(invitation_code_key)
            except AttributeError:
                # redis-py 版本过低，无 getdel 方法，回退到 Lua 脚本
                lua_script = "local v = redis.call('GET', KEYS[1]); if v then redis.call('DEL', KEYS[1]); end; return v"
                invitation_code_id_str = _redis.eval(lua_script, 1, invitation_code_key)
            except Exception as _redis_err:
                # Redis Server < 6.2 不支持 GETDEL 等情况，回退到 Lua 脚本
                if "unknown command" in str(_redis_err).lower() or "ERR" in str(_redis_err):
                    lua_script = "local v = redis.call('GET', KEYS[1]); if v then redis.call('DEL', KEYS[1]); end; return v"
                    invitation_code_id_str = _redis.eval(lua_script, 1, invitation_code_key)
                else:
                    raise  # 非命令不支持的错误（如连接断开），向上抛出
            if invitation_code_id_str:
                invitation_code_id = int(invitation_code_id_str if isinstance(invitation_code_id_str, (int, str)) else invitation_code_id_str.decode())
                from app.coupon_points_crud import use_invitation_code
                success, error_msg = use_invitation_code(db, user.id, invitation_code_id)
                if success:
                    logger.info(f"邀请码奖励发放成功: 用户 {user.id}, 邀请码ID {invitation_code_id}")
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

        # 检测是否为移动端应用（iOS 原生 / Flutter iOS / Flutter Android）
        from app.secure_auth import is_mobile_app_request
        is_ios_app = is_mobile_app_request(request)

        # 生成刷新令牌（移动端应用使用更长的过期时间）
        from app.secure_auth import create_user_refresh_token
        refresh_token = create_user_refresh_token(user.id, client_ip, device_fingerprint, is_ios_app=is_ios_app)

        # 创建会话（移动端应用会话将长期有效）
        session = SecureAuthManager.create_session(
            user_id=user.id,
            device_fingerprint=device_fingerprint,
            ip_address=client_ip,
            user_agent=user_agent,
            refresh_token=refresh_token,
            is_ios_app=is_ios_app
        )

        # 获取请求来源（用于 localhost 检测）
        origin = request.headers.get("origin", "")

        # 设置安全Cookie
        CookieManager.set_session_cookies(
            response=response,
            session_id=session.session_id,
            refresh_token=refresh_token,
            user_id=user.id,
            user_agent=user_agent,
            origin=origin
        )

        # 生成并设置CSRF token
        from app.csrf import CSRFProtection
        csrf_token = CSRFProtection.generate_csrf_token()
        CookieManager.set_csrf_cookie(response, csrf_token, user_agent, origin)

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

    # 检查是否为临时邮箱
    from app.email_utils import is_temp_email, notify_user_to_update_email
    from app.email_templates import get_user_language
    language = get_user_language(user) if user else 'en'

    if is_temp_email(validated_email):
        # 临时邮箱无法接收邮件，创建通知提醒用户更新邮箱
        notify_user_to_update_email(db, user.id, language)
        logger.info(f"检测到用户使用临时邮箱，已创建邮箱更新提醒通知: user_id={user.id}")
        raise HTTPException(
            status_code=400,
            detail="您当前使用的是临时邮箱，无法接收密码重置邮件。请在个人设置中更新您的真实邮箱地址，或使用手机号登录。"
        )

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


@router.post("/logout")
def logout(response: Response):
    """用户登出端点"""
    # 清除HttpOnly Cookie
    from app.security import clear_secure_cookies
    clear_secure_cookies(response)
    return {"message": "登出成功"}
