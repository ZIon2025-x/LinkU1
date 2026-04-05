import asyncio
import json
import logging
import os
import uuid
from decimal import Decimal
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
from typing import Optional, List
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession

from app import async_crud, crud, models, schemas
from app.database import get_async_db
from app.rate_limiting import rate_limit
from app.deps import get_current_user_secure_sync_csrf
from app.performance_monitor import measure_api_performance
from app.cache import cache_response
from app.push_notification_service import send_push_notification
from app.task_recommendation import get_task_recommendations, calculate_task_match_score
from app.user_behavior_tracker import UserBehaviorTracker, record_task_view, record_task_click
from app.recommendation_monitor import get_recommendation_metrics, RecommendationMonitor
from app.utils.translation_metrics import TranslationTimer

logger = logging.getLogger(__name__)
import os
from datetime import datetime, timedelta, time, timezone
from app.utils.time_utils import get_utc_time, format_iso_utc

import stripe
from pydantic import BaseModel, Field
from sqlalchemy import or_, and_, select, func, update

from app.security import verify_password
from app.security import create_access_token
from app.deps import (
    check_admin_user_status,
    check_user_status,
    get_current_admin_user,
    get_current_customer_service_or_user,
    get_current_user_secure_sync_csrf,
    get_current_user_secure_async_csrf,
    get_current_user_optional,
    get_db,
    get_sync_db,
    get_async_db_dependency,
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
    send_email_with_attachment,
)
from app.models import CustomerService, User
from app.config import Config

# 注意：Stripe API配置在应用启动时通过stripe_config模块统一配置（带超时）

router = APIRouter()


def _payment_method_types_for_currency(currency: str) -> list:
    """根据货币动态返回 Stripe 支持的支付方式列表"""
    c = currency.lower()
    methods = ["card"]
    if c in ("gbp", "cny"):
        methods.extend(["wechat_pay", "alipay"])
    return methods


def _safe_json_loads(s, default=None):
    """安全的 JSON 解析，失败时返回默认值而非抛出异常"""
    if not s:
        return default
    try:
        return json.loads(s)
    except (json.JSONDecodeError, TypeError, ValueError):
        return default


from app.file_utils import _resolve_legacy_private_file_path  # noqa: F401  (re-export)


async def _translate_missing_tasks_async(
    db: Session,
    task_ids: List[int],
    field_type: str,
    target_lang: str,
) -> None:
    """后台补齐缺失翻译（best-effort，不阻塞主请求）。"""
    if not task_ids:
        return

    from app.utils.translation_prefetch import prefetch_task_by_id

    db_gen = None
    worker_db = db
    using_fresh_session = False

    # 优先使用独立会话，避免请求结束后 session 失效。
    try:
        db_gen = get_db()
        worker_db = next(db_gen)
        using_fresh_session = True
    except Exception as e:
        logger.debug("后台翻译获取独立数据库会话失败，回退当前会话: %s", e)

    try:
        for task_id in task_ids:
            try:
                await prefetch_task_by_id(worker_db, task_id, target_languages=[target_lang])
            except Exception as e:
                logger.warning(
                    "后台翻译任务失败: task_id=%s, field=%s, target=%s, error=%s",
                    task_id,
                    field_type,
                    target_lang,
                    e,
                )
    finally:
        if using_fresh_session and db_gen is not None:
            try:
                db_gen.close()
            except Exception:
                try:
                    worker_db.close()
                except Exception:
                    pass


def _trigger_background_translation_prefetch(
    task_ids: List[int],
    target_languages: Optional[List[str]] = None,
    label: str = "后台翻译任务",
) -> None:
    """在线程中预翻译任务（best-effort，不阻塞主流程）。"""
    if not task_ids:
        return

    import threading
    from app.utils.translation_prefetch import prefetch_task_by_id

    targets = target_languages or ["en", "zh-CN"]

    def _worker():
        db_gen = None
        try:
            db_gen = get_db()
            sync_db = next(db_gen)
            try:
                for task_id in task_ids:
                    try:
                        loop = asyncio.new_event_loop()
                        asyncio.set_event_loop(loop)
                        try:
                            loop.run_until_complete(
                                prefetch_task_by_id(sync_db, task_id, target_languages=targets)
                            )
                        finally:
                            loop.close()
                    except Exception as e:
                        logger.warning("%s %s 失败: %s", label, task_id, e)
            finally:
                try:
                    db_gen.close()
                except Exception:
                    try:
                        sync_db.close()
                    except Exception:
                        pass
        except Exception as e:
            logger.error("%s失败: %s", label, e)

    thread = threading.Thread(target=_worker, daemon=True)
    thread.start()


@router.post("/csp-report")
async def csp_report(report: dict):
    """接收 CSP 违规报告"""
    logger.warning(f"CSP violation: {report}")
    # 可以发送到监控系统
    return {"status": "ok"}


def admin_required(current_user=Depends(get_current_admin_user)):
    return current_user


def require_debug_environment() -> None:
    """生产环境下拒绝 debug 路由，返回 404（与 Config.IS_PRODUCTION 对齐，含 Railway 等）"""
    if Config.IS_PRODUCTION:
        raise HTTPException(status_code=404, detail="Not Found")


@router.post("/register/test")
def register_test(user: schemas.UserCreate, _: None = Depends(require_debug_environment)):
    """测试注册数据格式（仅非生产可访问）"""
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
def register_debug(request_data: dict, _: None = Depends(require_debug_environment)):
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
def debug_test_token(token: str, _: None = Depends(require_debug_environment)):
    """调试token解析"""
    from app.email_utils import confirm_token
    from app.config import Config
    from itsdangerous import URLSafeTimedSerializer
    
    result = {
        "token": token[:20] + "...",
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
def debug_simple_test(_: None = Depends(require_debug_environment)):
    """最简单的测试端点"""
    return {"message": "Simple test works", "status": "ok"}

@router.post("/debug/fix-avatar-null")
def fix_avatar_null(db: Session = Depends(get_db), _: None = Depends(require_debug_environment)):
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
def check_user_avatar(user_id: str, db: Session = Depends(get_db), _: None = Depends(require_debug_environment)):
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
def debug_test_reviews(user_id: str, _: None = Depends(require_debug_environment)):
    """测试reviews端点是否工作"""
    return {"message": f"Reviews endpoint works for user {user_id}", "status": "ok"}

@router.get("/debug/session-status")
def debug_session_status(request: Request, db: Session = Depends(get_db), _: None = Depends(require_debug_environment)):
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
def debug_check_pending(email: str, db: Session = Depends(get_db), _: None = Depends(require_debug_environment)):
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
def debug_test_confirm_simple(_: None = Depends(require_debug_environment)):
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


def _request_lang_sync(request: Request, current_user: Optional[models.User]) -> str:
    """展示语言：登录用户用 language_preference，游客用 query lang 或 Accept-Language。与 async_routers._request_lang 一致。"""
    if current_user and (getattr(current_user, "language_preference", None) or "").strip().lower().startswith("zh"):
        return "zh"
    q = (request.query_params.get("lang") or "").strip().lower()
    if q in ("zh", "zh-cn", "zh_cn"):
        return "zh"
    accept = request.headers.get("accept-language") or ""
    for part in accept.split(","):
        part = part.split(";")[0].strip().lower()
        if part.startswith("zh"):
            return "zh"
        if part.startswith("en"):
            return "en"
    return "en"


# NOTE: 此同步版本已被 async_routers.py 中的异步版本取代。
# 保留代码但注释掉路由装饰器，避免 /api/tasks/{task_id} 路由重复注册。
# @router.get("/tasks/{task_id}", response_model=schemas.TaskOut)
def _get_task_detail_legacy(
    task_id: int,
    request: Request,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
):
    """获取任务详情 - 使用服务层缓存（避免装饰器重复创建）"""
    from app.services.task_service import TaskService
    from app.models import TaskApplication, TaskParticipant
    from sqlalchemy import and_
    from app.utils.task_activity_display import (
        ensure_task_title_for_lang_sync,
        ensure_task_description_for_lang_sync,
    )

    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 内容审核检查：被隐藏的任务只有发布者本人可以看到
    if not task.is_visible:
        if not current_user or str(current_user.id) != str(task.poster_id):
            raise HTTPException(status_code=404, detail="Task not found")

    # 权限检查：除了 open 状态的任务，其他状态的任务只有任务相关人才能看到详情
    # 未登录用户（含搜索引擎爬虫）可看到公开摘要，便于 SEO 索引
    _is_summary_only = False
    if task.status != "open":
        if not current_user:
            _is_summary_only = True
        else:
            user_id_str = str(current_user.id)
            is_poster = task.poster_id is not None and (str(task.poster_id) == user_id_str)
            is_taker = task.taker_id is not None and (str(task.taker_id) == user_id_str)
            is_participant = False
            is_applicant = False
            
            if task.is_multi_participant:
                if task.created_by_expert and task.expert_creator_id and str(task.expert_creator_id) == user_id_str:
                    is_participant = True
                else:
                    participant = db.query(TaskParticipant).filter(
                        and_(
                            TaskParticipant.task_id == task_id,
                            TaskParticipant.user_id == user_id_str,
                            TaskParticipant.status.in_(["accepted", "in_progress"])
                        )
                    ).first()
                    is_participant = participant is not None
            
            if not is_poster and not is_taker and not is_participant:
                application = db.query(TaskApplication).filter(
                    and_(
                        TaskApplication.task_id == task_id,
                        TaskApplication.applicant_id == user_id_str
                    )
                ).first()
                is_applicant = application is not None
            
            if not is_poster and not is_taker and not is_participant and not is_applicant:
                # 已完成/已取消的任务对外展示摘要（有利于 SEO），其他敏感状态仍返回 403
                if task.status in ("completed", "cancelled"):
                    _is_summary_only = True
                else:
                    raise HTTPException(status_code=403, detail="无权限查看此任务")
    
    # 未登录用户看摘要：返回公开字段（标题、描述、状态、类型、图片等），隐藏敏感字段
    if _is_summary_only:
        setattr(task, "has_applied", None)
        setattr(task, "user_application_status", None)
        setattr(task, "completion_evidence", None)
        task.taker_id = None
        task.poster_id = None
        return schemas.TaskOut.from_orm(task, full_location_access=True)

    # 判断当前用户是否为任务相关人（发布者/接单者/参与者/申请者），决定是否返回完整地址和坐标
    _full_location_access = False
    if current_user:
        _uid = str(current_user.id)
        if task.status == "open":
            _full_location_access = task.poster_id is not None and str(task.poster_id) == _uid
        else:
            # 非 open 状态：复用上面已判断的变量
            _full_location_access = is_poster or is_taker or is_participant or is_applicant
    
    # view_count + 用户行为记录 移到后台任务，不阻塞响应
    user_id_for_bg = current_user.id if current_user else None
    ua_for_bg = request.headers.get("User-Agent", "") if hasattr(request, 'headers') else ""

    def _bg_view_count_and_track(t_id: int, uid, ua: str):
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()
        if redis_client:
            try:
                redis_client.incr(f"task:view_count:{t_id}")
            except Exception as e:
                logger.warning("Redis 增加任务浏览量失败, 回退到直写: %s", e)
                redis_client = None

        if not redis_client:
            from app.database import SessionLocal
            bg_db = SessionLocal()
            try:
                bg_db.execute(update(models.Task).where(models.Task.id == t_id).values(view_count=models.Task.view_count + 1))
                bg_db.commit()
            except Exception as e:
                logger.warning("增加任务浏览量失败: %s", e)
                bg_db.rollback()
            finally:
                bg_db.close()

        if uid:
            from app.database import SessionLocal
            bg_db = SessionLocal()
            try:
                from app.user_behavior_tracker import UserBehaviorTracker
                tracker = UserBehaviorTracker(bg_db)
                ua_lower = ua.lower()
                if "mobile" in ua_lower or "android" in ua_lower or "iphone" in ua_lower:
                    device_type = "mobile"
                elif "tablet" in ua_lower or "ipad" in ua_lower:
                    device_type = "tablet"
                else:
                    device_type = "desktop"
                tracker.record_view(user_id=uid, task_id=t_id, device_type=device_type)
            except Exception as e:
                logger.warning(f"记录用户浏览行为失败: {e}")
            finally:
                bg_db.close()

    background_tasks.add_task(_bg_view_count_and_track, task_id, user_id_for_bg, ua_for_bg)
    
    # 按展示语言补齐双语（缺则翻译），放到后台任务避免阻塞
    lang = _request_lang_sync(request, current_user)
    needs_ensure = (
        (lang == "zh" and not getattr(task, "title_zh", None))
        or (lang == "en" and not getattr(task, "title_en", None))
        or (lang == "zh" and not getattr(task, "description_zh", None))
        or (lang == "en" and not getattr(task, "description_en", None))
    )
    if needs_ensure:
        def _bg_ensure_translation(t_id: int, target_lang: str):
            from app.database import SessionLocal
            bg_db = SessionLocal()
            try:
                bg_task = crud.get_task(bg_db, t_id)
                if bg_task:
                    ensure_task_title_for_lang_sync(bg_task, target_lang)
                    ensure_task_description_for_lang_sync(bg_task, target_lang)
                    bg_db.commit()
                    TaskService.invalidate_cache(t_id)
            except Exception as e:
                logger.warning(f"后台任务双语补齐失败 task_id=%s: %s", t_id, e)
                bg_db.rollback()
            finally:
                bg_db.close()
        background_tasks.add_task(_bg_ensure_translation, task_id, lang)

    # 直接使用已加载的 task ORM 对象构建响应，不再重复查询
    # 与活动详情一致：在详情响应中带上「当前用户是否已申请」及申请状态，便于客户端直接显示「已申请」状态
    if current_user:
        user_id_str = str(current_user.id)
        application = db.query(TaskApplication).filter(
            and_(
                TaskApplication.task_id == task_id,
                TaskApplication.applicant_id == user_id_str,
            )
        ).first()
        if application:
            setattr(task, "has_applied", True)
            setattr(task, "user_application_status", application.status)
        else:
            setattr(task, "has_applied", False)
            setattr(task, "user_application_status", None)
    else:
        setattr(task, "has_applied", None)
        setattr(task, "user_application_status", None)
    
    # 任务完成证据：当任务已标记完成时，从系统消息中取出证据（图片/文件 + 文字说明）供详情页展示
    completion_evidence = []
    if task.status in ("pending_confirmation", "completed") and task.completed_at:
        # 先按 meta 包含 task_completed_by_taker 查；若无结果则取该任务所有系统消息在 Python 里按 meta JSON 匹配（兼容不同数据库）
        completion_message = db.query(models.Message).filter(
            models.Message.task_id == task_id,
            models.Message.message_type == "system",
            models.Message.meta.contains("task_completed_by_taker"),
        ).order_by(models.Message.created_at.asc()).first()
        if not completion_message:
            all_system = (
                db.query(models.Message)
                .filter(
                    models.Message.task_id == task_id,
                    models.Message.message_type == "system",
                    models.Message.meta.isnot(None),
                )
                .order_by(models.Message.created_at.asc())
                .all()
            )
            for msg in all_system:
                try:
                    if msg.meta and json.loads(msg.meta).get("system_action") == "task_completed_by_taker":
                        completion_message = msg
                        break
                except (json.JSONDecodeError, TypeError):
                    continue
        if completion_message and completion_message.id:
            attachments = db.query(models.MessageAttachment).filter(
                models.MessageAttachment.message_id == completion_message.id
            ).all()
            # 用于生成私密图片 URL 的参与者（发布者、接单者）
            evidence_participants = []
            if getattr(task, "poster_id", None):
                evidence_participants.append(str(task.poster_id))
            if getattr(task, "taker_id", None):
                evidence_participants.append(str(task.taker_id))
            if current_user and str(current_user.id) not in evidence_participants:
                evidence_participants.append(str(current_user.id))
            if not evidence_participants:
                evidence_participants = [str(current_user.id)] if current_user else []
            viewer_id = str(current_user.id) if current_user else (getattr(task, "poster_id") or getattr(task, "taker_id"))
            viewer_id = str(viewer_id) if viewer_id else None
            for att in attachments:
                url = att.url or ""
                # 证据图片：若有 blob_id（即 private-image 的 image_id），统一生成新的 private-image URL，便于详情页展示且不过期
                is_private_image = att.blob_id and (
                    (att.attachment_type == "image") or (url and "/api/private-image/" in str(url))
                )
                if is_private_image and viewer_id and evidence_participants:
                    try:
                        from app.image_system import private_image_system
                        url = private_image_system.generate_image_url(
                            att.blob_id, viewer_id, evidence_participants
                        )
                    except Exception as e:
                        logger.debug(f"生成完成证据 private-image URL 失败 blob_id={att.blob_id}: {e}")
                elif url and not url.startswith("http"):
                    # 若存的是 file_id（私密文件），生成可访问的签名 URL
                    try:
                        from app.file_utils import is_safe_file_id
                        from app.file_system import private_file_system
                        from app.signed_url import signed_url_manager
                        if is_safe_file_id(url):
                            task_dir = private_file_system.base_dir / "tasks" / str(task_id)
                            if task_dir.exists():
                                for f in task_dir.glob(f"{url}.*"):
                                    if f.is_file():
                                        file_path_for_url = f"files/{f.name}"
                                        if viewer_id:
                                            url = signed_url_manager.generate_signed_url(
                                                file_path=file_path_for_url,
                                                user_id=viewer_id,
                                                expiry_minutes=60,
                                                one_time=False,
                                            )
                                        break
                    except Exception as e:
                        logger.debug(f"生成完成证据文件签名 URL 失败 file_id={url}: {e}")
                completion_evidence.append({
                    "type": att.attachment_type or "file",
                    "url": url,
                    "file_id": att.blob_id,
                })
            if completion_message.meta:
                try:
                    meta_data = json.loads(completion_message.meta)
                    if meta_data.get("evidence_text"):
                        completion_evidence.append({
                            "type": "text",
                            "content": meta_data["evidence_text"],
                        })
                except (json.JSONDecodeError, KeyError):
                    pass
    setattr(task, "completion_evidence", completion_evidence if completion_evidence else None)
    
    # 使用 TaskOut.from_orm 确保所有字段（包括 task_source）都被正确序列化
    # full_location_access=True: 地址不再隐藏，所有人可见完整地址
    task_dict = schemas.TaskOut.from_orm(task, full_location_access=True).model_dump()

    # 注入展示勋章
    from app.utils.badge_helpers import enrich_displayed_badges_sync
    _badge_user_ids = []
    if task.poster is not None:
        _badge_user_ids.append(task.poster.id)
    if task.taker is not None:
        _badge_user_ids.append(task.taker.id)
    _badge_cache = enrich_displayed_badges_sync(db, _badge_user_ids)

    # 任务相关方可以看到 poster/taker 信息
    if task.poster is not None:
        task_dict["poster"] = schemas.UserBrief.model_validate(task.poster).model_dump()
        task_dict["poster"]["displayed_badge"] = _badge_cache.get(task.poster.id)
    if task.taker is not None:
        task_dict["taker"] = schemas.UserBrief.model_validate(task.taker).model_dump()
        task_dict["taker"]["displayed_badge"] = _badge_cache.get(task.taker.id)
    return task_dict


@router.get("/recommendations")
def get_recommendations(
    current_user=Depends(get_current_user_secure_sync_csrf),
    limit: int = Query(20, ge=1, le=50),
    algorithm: str = Query("hybrid", pattern="^(content_based|collaborative|hybrid)$"),
    task_type: Optional[str] = Query(None),
    location: Optional[str] = Query(None),
    keyword: Optional[str] = Query(None, max_length=200),
    latitude: Optional[float] = Query(None, ge=-90, le=90),
    longitude: Optional[float] = Query(None, ge=-180, le=180),
    db: Session = Depends(get_db),
):
    """
    获取个性化任务推荐（支持筛选条件和GPS位置）
    
    Args:
        limit: 返回任务数量（1-50）
        algorithm: 推荐算法类型
            - content_based: 基于内容的推荐
            - collaborative: 协同过滤推荐
            - hybrid: 混合推荐（推荐）
        task_type: 任务类型筛选
        location: 地点筛选
        keyword: 关键词筛选
        latitude: 用户当前纬度（用于基于位置的推荐）
        longitude: 用户当前经度（用于基于位置的推荐）
    """
    try:
        # 将GPS位置直接传递给推荐算法（无需存储到数据库）
        recommendations = get_task_recommendations(
            db=db,
            user_id=current_user.id,
            limit=limit,
            algorithm=algorithm,
            task_type=task_type,
            location=location,
            keyword=keyword,
            latitude=latitude,
            longitude=longitude
        )
        
        # 任务双语标题从任务表列读取；缺失时后台触发预取
        task_ids = [item["task"].id for item in recommendations]
        missing_task_ids = []
        for item in recommendations:
            t = item["task"]
            if not getattr(t, "title_en", None) or not getattr(t, "title_zh", None):
                missing_task_ids.append(t.id)
        if missing_task_ids:
            _trigger_background_translation_prefetch(
                missing_task_ids,
                target_languages=["en", "zh"],
                label="后台翻译任务标题",
            )

        result = []
        from app.utils.location_utils import obfuscate_location
        for item in recommendations:
            task = item["task"]
            title_en = getattr(task, "title_en", None)
            title_zh = getattr(task, "title_zh", None)

            # 解析图片字段
            images_list = []
            if task.images:
                try:
                    import json
                    if isinstance(task.images, str):
                        images_list = json.loads(task.images)
                    elif isinstance(task.images, list):
                        images_list = task.images
                except (json.JSONDecodeError, TypeError):
                    images_list = []

            result.append({
                "id": task.id,
                "task_id": task.id,
                "title": task.title,
                "title_en": title_en,
                "title_zh": title_zh,
                "description": task.description,
                "task_type": task.task_type,
                "location": obfuscate_location(task.location),
                "reward": float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else (float(task.reward) if task.reward else 0.0),
                "base_reward": float(task.base_reward) if task.base_reward else None,
                "agreed_reward": float(task.agreed_reward) if task.agreed_reward else None,
                "reward_to_be_quoted": getattr(task, "reward_to_be_quoted", False),
                "deadline": task.deadline.isoformat() if task.deadline else None,
                "task_level": task.task_level,
                "match_score": round(item["score"], 3),
                "recommendation_reason": item["reason"],
                "created_at": task.created_at.isoformat() if task.created_at else None,
                "images": images_list,  # 添加图片字段
            })
        
        return {
            "recommendations": result,
            "total": len(result),
            "algorithm": algorithm
        }
    except Exception as e:
        logger.error(f"获取推荐失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="获取推荐失败")


@router.get("/tasks/{task_id}/match-score")
def get_task_match_score(
    task_id: int,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    获取任务对当前用户的匹配分数
    
    用于在任务详情页显示匹配度
    """
    try:
        task = crud.get_task(db, task_id)
        if not task or not task.is_visible:
            raise HTTPException(status_code=404, detail="Task not found")
        score = calculate_task_match_score(
            db=db,
            user_id=current_user.id,
            task_id=task_id
        )

        return {
            "task_id": task_id,
            "match_score": round(score, 3),
            "match_percentage": round(score * 100, 1)
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"计算匹配分数失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="计算匹配分数失败")


@router.post("/tasks/{task_id}/interaction")
def record_task_interaction(
    task_id: int,
    interaction_type: str = Body(..., pattern="^(view|click|apply|skip)$"),
    duration_seconds: Optional[int] = Body(None),
    device_type: Optional[str] = Body(None),
    is_recommended: Optional[bool] = Body(None),
    metadata: Optional[dict] = Body(None),
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    记录用户对任务的交互行为
    
    Args:
        interaction_type: 交互类型 (view, click, apply, skip)
        duration_seconds: 浏览时长（秒），仅用于view类型
        device_type: 设备类型 (mobile, desktop, tablet)
        is_recommended: 是否为推荐任务
        metadata: 额外元数据（设备信息、推荐信息等）
    """
    try:
        # 优化：先验证任务是否存在，避免记录不存在的任务交互
        task = crud.get_task(db, task_id)
        if not task:
            logger.warning(
                f"尝试记录交互时任务不存在: user_id={current_user.id}, "
                f"task_id={task_id}, interaction_type={interaction_type}"
            )
            raise HTTPException(status_code=404, detail="Task not found")
        
        tracker = UserBehaviorTracker(db)
        is_rec = is_recommended if is_recommended is not None else False
        
        # 合并metadata，确保包含推荐信息
        final_metadata = metadata or {}
        final_metadata["is_recommended"] = is_rec
        
        if interaction_type == "view":
            tracker.record_interaction(
                user_id=current_user.id,
                task_id=task_id,
                interaction_type="view",
                duration_seconds=duration_seconds,
                device_type=device_type,
                metadata=final_metadata,
                is_recommended=is_rec
            )
        elif interaction_type == "click":
            tracker.record_interaction(
                user_id=current_user.id,
                task_id=task_id,
                interaction_type="click",
                device_type=device_type,
                metadata=final_metadata,
                is_recommended=is_rec
            )
        elif interaction_type == "apply":
            tracker.record_interaction(
                user_id=current_user.id,
                task_id=task_id,
                interaction_type="apply",
                device_type=device_type,
                metadata=final_metadata
            )
        elif interaction_type == "skip":
            tracker.record_interaction(
                user_id=current_user.id,
                task_id=task_id,
                interaction_type="skip",
                device_type=device_type,
                metadata=final_metadata
            )
        
        # 记录Prometheus指标
        try:
            from app.recommendation_metrics import record_user_interaction
            record_user_interaction(interaction_type, is_rec)
        except Exception as e:
            logger.debug(f"记录Prometheus推荐指标失败: {e}")
        
        return {"status": "success", "message": "交互记录成功"}
    except Exception as e:
        logger.error(f"记录交互失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="记录交互失败")


# 已迁移到 admin_recommendation_routes.py: /admin/recommendation-metrics

@router.get("/user/recommendation-stats")
def get_user_recommendation_stats(
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """获取当前用户的推荐统计"""
    try:
        monitor = RecommendationMonitor(db)
        stats = monitor.get_user_recommendation_stats(current_user.id)
        return stats
    except Exception as e:
        logger.error(f"获取用户推荐统计失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="获取用户推荐统计失败")


# 已迁移到 admin_recommendation_routes.py: /admin/recommendation-analytics, /admin/top-recommended-tasks, /admin/recommendation-health, /admin/recommendation-optimization

@router.post("/recommendations/{task_id}/feedback")
def submit_recommendation_feedback(
    task_id: int,
    feedback_type: str = Body(..., pattern="^(like|dislike|not_interested|helpful)$"),
    recommendation_id: Optional[str] = Body(None),
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    提交推荐反馈
    
    Args:
        feedback_type: 反馈类型 (like, dislike, not_interested, helpful)
        recommendation_id: 推荐批次ID（可选）
    """
    try:
        from app.recommendation_feedback import RecommendationFeedbackManager
        manager = RecommendationFeedbackManager(db)
        
        # 获取任务的推荐信息（如果有）
        task = crud.get_task(db, task_id)
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        
        manager.record_feedback(
            user_id=current_user.id,
            task_id=task_id,
            feedback_type=feedback_type,
            recommendation_id=recommendation_id
        )
        
        return {"status": "success", "message": "反馈已记录"}
    except Exception as e:
        logger.error(f"记录推荐反馈失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="记录推荐反馈失败")


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

        # 所有用户均可接受任意等级任务（任务等级仅按赏金划分，由数据库配置的阈值决定，不限制接单权限）

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

        result = crud.accept_task(db, task_id, current_user.id)
        if isinstance(result, str):
            error_messages = {
                "task_not_found": "Task not found.",
                "user_not_found": "User not found.",
                "not_designated_taker": "This task is designated for another user.",
                "task_not_open": "Task is not available for acceptance.",
                "task_already_taken": "Task has already been taken by another user.",
                "task_deadline_passed": "Task deadline has passed.",
                "commit_failed": "Failed to save, please try again.",
                "internal_error": "An internal error occurred, please try again.",
            }
            raise HTTPException(
                status_code=400,
                detail=error_messages.get(result, result),
            )
        updated_task = result

        # ⚠️ 清除任务缓存，确保前端立即看到更新后的状态
        try:
            from app.services.task_service import TaskService
            TaskService.invalidate_cache(task_id)
            from app.redis_cache import invalidate_tasks_cache
            invalidate_tasks_cache()
            logger.info(f"✅ 已清除任务 {task_id} 的缓存（接受任务）")
        except Exception as e:
            logger.warning(f"⚠️ 清除任务缓存失败: {e}")

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
                logger.warning(f"Failed to create notification: {e}")
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
    """
    任务发布者同意接受者进行任务
    
    ⚠️ 安全修复：添加支付验证，防止绕过支付
    注意：此端点可能已废弃，新的流程使用 accept_application 端点
    """
    import logging
    logger = logging.getLogger(__name__)
    
    db_task = crud.get_task(db, task_id)
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 检查权限：只有任务发布者可以同意
    if db_task.poster_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only task poster can approve the taker"
        )

    # ⚠️ 安全修复：检查支付状态，防止绕过支付
    if not db_task.is_paid:
        logger.warning(
            f"⚠️ 安全警告：用户 {current_user.id} 尝试批准未支付的任务 {task_id}"
        )
        raise HTTPException(
            status_code=400, 
            detail="任务尚未支付，无法批准。请先完成支付。"
        )

    # 检查任务状态：必须是 pending_payment 或 in_progress 状态
    # 注意：旧的 "taken" 状态已废弃，新流程使用 pending_payment
    if db_task.status not in ["pending_payment", "in_progress", "taken"]:
        raise HTTPException(
            status_code=400, 
            detail=f"任务状态不正确，无法批准。当前状态: {db_task.status}"
        )

    # 更新任务状态为进行中（如果还不是）
    # ⚠️ 安全修复：确保只有已支付的任务才能进入 in_progress 状态
    if db_task.status == "pending_payment":
        # 再次确认支付状态（双重检查）
        if db_task.is_paid != 1:
            logger.error(
                f"🔴 安全错误：任务 {task_id} 状态为 pending_payment 但 is_paid={db_task.is_paid}，"
                f"不允许进入 in_progress 状态"
            )
            raise HTTPException(
                status_code=400,
                detail="任务尚未支付，无法进入进行中状态。请先完成支付。"
            )
        db_task.status = "in_progress"
        db.commit()
        logger.info(f"✅ 任务 {task_id} 状态从 pending_payment 更新为 in_progress（已确认支付）")
    elif db_task.status == "taken":
        # 兼容旧流程：如果状态是 taken，也更新为 in_progress
        # ⚠️ 安全修复：确保已支付
        if db_task.is_paid != 1:
            logger.error(
                f"🔴 安全错误：任务 {task_id} 状态为 taken 但 is_paid={db_task.is_paid}，"
                f"不允许进入 in_progress 状态"
            )
            raise HTTPException(
                status_code=400,
                detail="任务尚未支付，无法进入进行中状态。请先完成支付。"
            )
        db_task.status = "in_progress"
        db.commit()
        logger.info(f"✅ 任务 {task_id} 状态从 taken 更新为 in_progress（旧流程兼容，已确认支付）")
    # 如果已经是 in_progress，不需要更新
    
    db.refresh(db_task)
    
    # ⚠️ 清除任务缓存，确保前端立即看到更新后的状态
    try:
        from app.services.task_service import TaskService
        TaskService.invalidate_cache(task_id)
        from app.redis_cache import invalidate_tasks_cache
        invalidate_tasks_cache()
        logger.info(f"✅ 已清除任务 {task_id} 的缓存（批准任务）")
    except Exception as e:
        logger.warning(f"⚠️ 清除任务缓存失败: {e}")

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
            logger.warning(f"Failed to create notification: {e}")

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
    
    # ⚠️ 清除任务缓存，确保前端立即看到更新后的状态
    try:
        from app.services.task_service import TaskService
        TaskService.invalidate_cache(task_id)
        from app.redis_cache import invalidate_tasks_cache
        invalidate_tasks_cache()
        logger.info(f"✅ 已清除任务 {task_id} 的缓存（拒绝任务接受者）")
    except Exception as e:
        logger.warning(f"⚠️ 清除任务缓存失败: {e}")

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
            
            # 发送推送通知
            try:
                send_push_notification(
                    db=db,
                    user_id=rejected_taker_id,
                    notification_type="task_rejected",
                    data={"task_id": task_id},
                    template_vars={"task_title": db_task.title, "task_id": task_id}
                )
            except Exception as e:
                logger.warning(f"发送任务拒绝推送通知失败: {e}")
                # 推送通知失败不影响主流程
        except Exception as e:
            logger.warning(f"Failed to create notification: {e}")

    return db_task


@router.patch("/tasks/{task_id}/reward", response_model=schemas.TaskOut)
def update_task_reward(
    task_id: int,
    task_update: schemas.TaskUpdate,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """更新任务价格（仅任务发布者可见）"""
    result = crud.update_task_reward(db, task_id, current_user.id, task_update.reward)
    if isinstance(result, str):
        error_messages = {
            "task_not_found": "Task not found.",
            "not_task_poster": "You don't have permission to update this task.",
            "task_not_open": "Task can only be updated while in open status.",
        }
        raise HTTPException(
            status_code=400,
            detail=error_messages.get(result, result),
        )
    return result


class VisibilityUpdate(BaseModel):
    is_public: int = Field(..., ge=0, le=1, description="0=私密, 1=公开")


@router.patch("/tasks/{task_id}/visibility", response_model=schemas.TaskOut)
def update_task_visibility(
    task_id: int,
    visibility_update: VisibilityUpdate = Body(...),
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """更新任务可见性（发布者更新 is_public，接单者更新 taker_public）"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    is_public = visibility_update.is_public

    if task.poster_id == current_user.id:
        task.is_public = is_public
    elif task.taker_id == current_user.id:
        task.taker_public = is_public
    else:
        raise HTTPException(
            status_code=403, detail="Not authorized to update this task"
        )

    db.commit()
    db.refresh(task)
    return task


@router.post("/tasks/{task_id}/review", response_model=schemas.ReviewOut)
@rate_limit("api_write", limit=10, window=60)  # 限制：10次/分钟，防止刷评价
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

    result = crud.create_review(db, current_user.id, task_id, review)
    if isinstance(result, str):
        error_messages = {
            "task_not_completed": "Task is not completed yet.",
            "not_participant": "You are not a participant of this task.",
            "already_reviewed": "You have already reviewed this task.",
        }
        raise HTTPException(
            status_code=400,
            detail=error_messages.get(result, result),
        )
    db_review = result
    
    # 清除评价列表缓存，确保新评价立即显示
    try:
        from app.cache import invalidate_cache
        # 清除该任务的所有评价缓存（使用通配符匹配所有可能的缓存键）
        invalidate_cache(f"task_reviews:get_task_reviews:*")
        logger.info(f"已清除任务 {task_id} 的评价列表缓存")
    except Exception as e:
        logger.warning(f"清除评价缓存失败: {e}")
    
    # P2 优化：异步处理非关键操作（发送通知等）
    if background_tasks:
        def send_review_notification():
            """后台发送评价通知（非关键操作）"""
            try:
                # 获取任务信息
                task = crud.get_task(db, task_id)
                if not task:
                    return
                
                # 确定被评价的用户（不是评价者）
                reviewed_user_id = None
                if task.is_multi_participant:
                    # 多人任务：参与者评价达人，达人评价第一个参与者
                    if task.created_by_expert and task.expert_creator_id:
                        if current_user.id != task.expert_creator_id:
                            reviewed_user_id = task.expert_creator_id
                        elif task.originating_user_id:
                            reviewed_user_id = task.originating_user_id
                    elif task.taker_id and current_user.id != task.taker_id:
                        reviewed_user_id = task.taker_id
                else:
                    # 单人任务：发布者评价接受者，接受者评价发布者
                    reviewed_user_id = task.taker_id if current_user.id == task.poster_id else task.poster_id
                
                # 通知被评价的用户
                if reviewed_user_id and reviewed_user_id != current_user.id:
                    crud.create_notification(
                        db,
                        reviewed_user_id,
                        "review_created",
                        "收到新评价",
                        f"任务 '{task.title}' 收到了新评价",
                        related_id=str(task_id),
                        related_type="task_id",
                        title_en="New Review Received",
                        content_en=f"New review received for task '{task.title}'",
                    )
            except Exception as e:
                logger.warning(f"发送评价通知失败: {e}")
        
        background_tasks.add_task(send_review_notification)
    
    return db_review


@router.get("/tasks/{task_id}/reviews", response_model=list[schemas.ReviewOut])
@measure_api_performance("get_task_reviews")
def get_task_reviews(
    task_id: int,
    db: Session = Depends(get_db),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
):
    # 内容审核检查：隐藏的任务不返回评价
    task = crud.get_task(db, task_id)
    if not task or not task.is_visible:
        raise HTTPException(status_code=404, detail="Task not found")
    current_user_id = current_user.id if current_user else None
    reviews = crud.get_task_reviews(db, task_id, current_user_id=current_user_id)
    return [schemas.ReviewOut.model_validate(r) for r in reviews]


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
    evidence_images: Optional[List[str]] = Body(None, description="证据图片URL列表"),
    evidence_text: Optional[str] = Body(None, description="文字证据说明（可选）"),
    background_tasks: BackgroundTasks = None,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    # 检查用户是否为客服账号
    if False:  # 普通用户不再有客服权限
        raise HTTPException(status_code=403, detail="客服账号不能完成任务")

    # 验证文字证据长度
    if evidence_text and len(evidence_text.strip()) > 500:
        raise HTTPException(
            status_code=400,
            detail="文字证据说明不能超过500字符"
        )

    # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定任务，防止并发完成
    locked_task_query = select(models.Task).where(
        models.Task.id == task_id
    ).with_for_update()
    db_task = db.execute(locked_task_query).scalar_one_or_none()
    
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")

    if db_task.status != "in_progress":
        raise HTTPException(status_code=400, detail="Task is not in progress")

    if db_task.taker_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only the task taker can complete the task"
        )
    
    # ⚠️ 安全修复：检查支付状态，确保只有已支付的任务才能完成
    if not db_task.is_paid:
        logger.warning(
            f"⚠️ 安全警告：用户 {current_user.id} 尝试完成未支付的任务 {task_id}"
        )
        raise HTTPException(
            status_code=400,
            detail="任务尚未支付，无法完成。请联系发布者完成支付。"
        )

    # 更新任务状态为等待确认
    from datetime import timedelta
    now = get_utc_time()
    db_task.status = "pending_confirmation"
    db_task.completed_at = now
    # 设置确认截止时间：completed_at + 5天
    db_task.confirmation_deadline = now + timedelta(days=5)
    # 清除之前的提醒状态
    db_task.confirmation_reminder_sent = 0
    
    try:
        db.commit()
    except Exception as e:
        db.rollback()
        logger.error(f"完成任务状态更新失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="任务状态更新失败，请重试")
    db.refresh(db_task)
    
    # ⚠️ 清除任务缓存，确保前端立即看到更新后的状态
    try:
        from app.services.task_service import TaskService
        TaskService.invalidate_cache(task_id)
        from app.redis_cache import invalidate_tasks_cache
        invalidate_tasks_cache()
        logger.info(f"✅ 已清除任务 {task_id} 的缓存（完成任务）")
    except Exception as e:
        logger.warning(f"⚠️ 清除任务缓存失败: {e}")

    # 发送系统消息到任务聊天框
    try:
        from app.models import Message, MessageAttachment
        from app.utils.notification_templates import get_notification_texts
        import json
        
        taker_name = current_user.name or f"用户{current_user.id}"
        # 根据是否有证据（图片或文字）显示不同的消息内容
        has_evidence = (evidence_images and len(evidence_images) > 0) or (evidence_text and evidence_text.strip())
        if has_evidence:
            # 使用国际化模板
            _, content_zh, _, content_en = get_notification_texts(
                "task_completed",
                taker_name=taker_name,
                task_title=db_task.title,
                has_evidence=True
            )
            # 如果没有对应的模板，使用默认文本
            if not content_zh:
                if evidence_text and evidence_text.strip():
                    content_zh = f"任务已完成。{evidence_text[:50]}{'...' if len(evidence_text) > 50 else ''}"
                else:
                    content_zh = "任务已完成，请查看证据图片。"
            if not content_en:
                if evidence_text and evidence_text.strip():
                    content_en = f"Task completed. {evidence_text[:50]}{'...' if len(evidence_text) > 50 else ''}"
                else:
                    content_en = "Task completed. Please check the evidence images."
        else:
            _, content_zh, _, content_en = get_notification_texts(
                "task_completed",
                taker_name=taker_name,
                task_title=db_task.title,
                has_evidence=False
            )
            # 如果没有对应的模板，使用默认文本
            if not content_zh:
                content_zh = f"接收者 {taker_name} 已确认完成任务，等待发布者确认。"
            if not content_en:
                content_en = f"Recipient {taker_name} has confirmed task completion, waiting for poster confirmation."
        
        # 构建meta信息，包含证据信息
        meta_data = {
            "system_action": "task_completed_by_taker",
            "content_en": content_en
        }
        if evidence_text and evidence_text.strip():
            meta_data["evidence_text"] = evidence_text
        if evidence_images and len(evidence_images) > 0:
            meta_data["evidence_images_count"] = len(evidence_images)
        
        system_message = Message(
            sender_id=None,  # 系统消息，sender_id为None
            receiver_id=None,
            content=content_zh,  # 中文内容（英文存于 meta.content_en 供客户端本地化）
            task_id=task_id,
            message_type="system",
            conversation_type="task",
            meta=json.dumps(meta_data),
            created_at=get_utc_time()
        )
        db.add(system_message)
        db.flush()  # 获取消息ID
        
        # 如果有证据图片，创建附件（满足 ck_message_attachments_url_blob：url 与 blob_id 二选一）
        if evidence_images:
            for image_url in evidence_images:
                # 从URL中提取image_id（如果URL格式为 {base_url}/api/private-image/{image_id}?user=...&token=...）
                image_id = None
                if image_url and '/api/private-image/' in image_url:
                    try:
                        from urllib.parse import urlparse
                        parsed_url = urlparse(image_url)
                        if '/api/private-image/' in parsed_url.path:
                            path_parts = parsed_url.path.split('/api/private-image/')
                            if len(path_parts) > 1:
                                image_id = path_parts[1].split('?')[0]
                                logger.debug(f"Extracted image_id {image_id} from URL {image_url}")
                    except Exception as e:
                        logger.warning(f"Failed to extract image_id from URL {image_url}: {e}")
                # 约束要求 (url IS NOT NULL AND blob_id IS NULL) OR (url IS NULL AND blob_id IS NOT NULL)
                if image_id:
                    attachment = MessageAttachment(
                        message_id=system_message.id,
                        attachment_type="image",
                        url=None,
                        blob_id=image_id,
                        meta=None,
                        created_at=get_utc_time()
                    )
                else:
                    attachment = MessageAttachment(
                        message_id=system_message.id,
                        attachment_type="image",
                        url=image_url,
                        blob_id=None,
                        meta=None,
                        created_at=get_utc_time()
                    )
                db.add(attachment)
        
        db.commit()
    except Exception as e:
        logger.warning(f"Failed to send system message: {e}")
        # 系统消息发送失败不影响任务完成流程

    # 发送任务完成通知和邮件给发布者（始终创建通知，让发布者知道完成情况与证据）
    try:
        from app.task_notifications import send_task_completion_notification
        from fastapi import BackgroundTasks
        
        # 确保 background_tasks 存在，如果为 None 则创建新实例
        if background_tasks is None:
            background_tasks = BackgroundTasks()
        
        # 只要任务有发布者就发送通知（不依赖 poster 对象是否存在）
        if db_task.poster_id:
            send_task_completion_notification(
                db=db,
                background_tasks=background_tasks,
                task=db_task,
                taker=current_user,
                evidence_images=evidence_images,
                evidence_text=evidence_text,
            )
    except Exception as e:
        logger.warning(f"Failed to send task completion notification: {e}")
        # 通知发送失败不影响任务完成流程

    # 检查任务接受者是否满足VIP晋升条件
    try:
        crud.check_and_upgrade_vip_to_super(db, current_user.id)
    except Exception as e:
        logger.warning(f"Failed to check VIP upgrade: {e}")

    return db_task


@router.post("/tasks/{task_id}/dispute", response_model=schemas.TaskDisputeOut)
@rate_limit("create_dispute")
def create_task_dispute(
    task_id: int,
    dispute_data: schemas.TaskDisputeCreate,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """任务发布者提交争议（未正确完成）"""
    task = crud.get_task(db, task_id)
    if not task or task.poster_id != current_user.id:
        raise HTTPException(status_code=404, detail="Task not found or no permission")
    if task.status != "pending_confirmation":
        raise HTTPException(status_code=400, detail="Task is not pending confirmation")
    
    # 检查是否已经提交过争议
    existing_dispute = db.query(models.TaskDispute).filter(
        models.TaskDispute.task_id == task_id,
        models.TaskDispute.poster_id == current_user.id,
        models.TaskDispute.status == "pending"
    ).first()
    
    if existing_dispute:
        raise HTTPException(status_code=400, detail="您已经提交过争议，请等待管理员处理")
    
    # ✅ 验证证据文件（如果提供）
    validated_evidence_files = []
    if dispute_data.evidence_files:
        if len(dispute_data.evidence_files) > 10:
            raise HTTPException(
                status_code=400,
                detail="证据文件数量不能超过10个"
            )
        
        # 验证文件是否属于当前任务
        from app.models import MessageAttachment, Message
        for file_id in dispute_data.evidence_files:
            # 检查文件是否存在于MessageAttachment中，且与当前任务相关
            attachment = db.query(MessageAttachment).filter(
                MessageAttachment.blob_id == file_id
            ).first()
            
            if attachment:
                # 通过附件找到消息，验证是否属于当前任务
                task_message = db.query(Message).filter(
                    Message.id == attachment.message_id,
                    Message.task_id == task_id
                ).first()
                
                if task_message:
                    validated_evidence_files.append(file_id)
                else:
                    logger.warning(f"证据文件 {file_id} 不属于任务 {task_id}，已忽略")
            else:
                logger.warning(f"证据文件 {file_id} 不存在，已忽略")
    
    # 创建争议记录
    import json
    evidence_files_json = json.dumps(validated_evidence_files) if validated_evidence_files else None
    
    dispute = models.TaskDispute(
        task_id=task_id,
        poster_id=current_user.id,
        reason=dispute_data.reason,
        evidence_files=evidence_files_json,
        status="pending",
        created_at=get_utc_time()
    )
    db.add(dispute)
    db.flush()

    # 更新可靠度画像（taker 被投诉）
    try:
        from app.services.reliability_calculator import on_complaint_created
        on_complaint_created(db, task.taker_id)
    except Exception as e:
        logger.warning(f"更新可靠度失败(complaint_created): {e}")

    # 发送系统消息到任务聊天框
    try:
        from app.models import Message
        import json
        
        poster_name = current_user.name or f"用户{current_user.id}"
        content_zh = f"{poster_name} 对任务完成状态有异议。"
        content_en = f"{poster_name} has raised a dispute about the task completion status."
        
        system_message = Message(
            sender_id=None,  # 系统消息，sender_id为None
            receiver_id=None,
            content=content_zh,  # 中文内容（英文存于 meta.content_en 供客户端本地化）
            task_id=task_id,
            message_type="system",
            conversation_type="task",
            meta=json.dumps({"system_action": "task_dispute_created", "dispute_id": dispute.id, "content_en": content_en}),
            created_at=get_utc_time()
        )
        db.add(system_message)
    except Exception as e:
        logger.error(f"Failed to send system message: {e}")
        # 系统消息发送失败不影响争议提交流程
    
    # 通知管理员（后台任务）
    if background_tasks:
        try:
            from app.task_notifications import send_dispute_notification_to_admin
            send_dispute_notification_to_admin(
                db=db,  # 虽然后台任务会创建新会话，但这里保留参数以保持接口一致性
                background_tasks=background_tasks,
                task=task,
                dispute=dispute,
                poster=current_user
            )
        except Exception as e:
            logger.error(f"Failed to send dispute notification to admin: {e}")
    
    db.commit()
    db.refresh(dispute)
    
    return dispute


# ==================== 管理员任务争议管理API ====================
# 已迁移到 admin_dispute_routes.py

# ==================== 退款申请API ====================

@router.post("/tasks/{task_id}/refund-request", response_model=schemas.RefundRequestOut)
@rate_limit("refund_request")
def create_refund_request(
    task_id: int,
    refund_data: schemas.RefundRequestCreate,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """
    任务发布者申请退款（任务未完成）
    只有在任务状态为 pending_confirmation 时才能申请退款
    """
    from sqlalchemy import select
    from decimal import Decimal
    
    # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定任务记录
    task_query = select(models.Task).where(models.Task.id == task_id).with_for_update()
    task_result = db.execute(task_query)
    task = task_result.scalar_one_or_none()
    
    if not task or task.poster_id != current_user.id:
        raise HTTPException(status_code=404, detail="Task not found or no permission")
    
    # 检查任务状态：必须是 pending_confirmation
    if task.status != "pending_confirmation":
        raise HTTPException(
            status_code=400, 
            detail=f"任务状态不正确，无法申请退款。当前状态: {task.status}。只有在任务待确认状态时才能申请退款。"
        )
    
    # 检查任务是否已支付
    if not task.is_paid:
        raise HTTPException(
            status_code=400,
            detail="任务尚未支付，无需退款。"
        )
    
    # 🔒 并发安全：检查是否已经提交过退款申请（pending 或 processing 状态）
    existing_refund = db.query(models.RefundRequest).filter(
        models.RefundRequest.task_id == task_id,
        models.RefundRequest.poster_id == current_user.id,
        models.RefundRequest.status.in_(["pending", "processing"])
    ).first()
    
    if existing_refund:
        raise HTTPException(
            status_code=400, 
            detail=f"您已经提交过退款申请（状态: {existing_refund.status}），请等待管理员处理"
        )
    
    # ✅ 验证退款类型和金额
    if refund_data.refund_type not in ["full", "partial"]:
        raise HTTPException(
            status_code=400,
            detail="退款类型必须是 'full'（全额退款）或 'partial'（部分退款）"
        )
    
    # 验证退款原因类型
    valid_reason_types = ["completion_time_unsatisfactory", "not_completed", "quality_issue", "other"]
    if refund_data.reason_type not in valid_reason_types:
        raise HTTPException(
            status_code=400,
            detail=f"退款原因类型无效，必须是以下之一：{', '.join(valid_reason_types)}"
        )
    
    # ✅ 修复金额精度：使用Decimal进行金额计算
    task_amount = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
    
    if refund_data.refund_type == "partial":
        # 部分退款：必须提供退款金额或退款比例
        if refund_data.refund_amount is None and refund_data.refund_percentage is None:
            raise HTTPException(
                status_code=400,
                detail="部分退款必须提供退款金额（refund_amount）或退款比例（refund_percentage）"
            )
        
        # 计算退款金额
        if refund_data.refund_percentage is not None:
            # 使用退款比例计算
            refund_percentage = Decimal(str(refund_data.refund_percentage))
            if refund_percentage <= 0 or refund_percentage > 100:
                raise HTTPException(
                    status_code=400,
                    detail="退款比例必须在0-100之间"
                )
            calculated_amount = task_amount * refund_percentage / Decimal('100')
            # 安全：当提供了退款比例时，始终以服务端计算的金额为准，忽略前端传入的金额
            if refund_data.refund_amount is not None and refund_data.refund_amount != calculated_amount:
                logger.warning(f"退款金额（£{refund_data.refund_amount}）与退款比例计算出的金额（£{calculated_amount}）不一致，使用服务端计算的金额")
            final_refund_amount = calculated_amount
        else:
            # 只提供了金额
            final_refund_amount = Decimal(str(refund_data.refund_amount))
        
        if final_refund_amount <= 0:
            raise HTTPException(
                status_code=400,
                detail="退款金额必须大于0"
            )
        
        if final_refund_amount >= task_amount:
            raise HTTPException(
                status_code=400,
                detail=f"部分退款金额（£{final_refund_amount:.2f}）不能大于或等于任务金额（£{task_amount:.2f}），请选择全额退款"
            )
        
        # 更新refund_data中的金额
        refund_data.refund_amount = final_refund_amount
    else:
        # 全额退款：refund_amount应该为空或等于任务金额
        if refund_data.refund_amount is not None:
            refund_amount_decimal = Decimal(str(refund_data.refund_amount))
            if refund_amount_decimal != task_amount:
                logger.warning(f"全额退款时提供的金额（£{refund_amount_decimal}）与任务金额（£{task_amount}）不一致，使用任务金额")
        refund_data.refund_amount = task_amount
    
    # ✅ 修复文件ID验证：验证证据文件ID是否属于当前用户或任务
    validated_evidence_files = []
    if refund_data.evidence_files:
        from app.models import MessageAttachment
        from app.file_system import PrivateFileSystem
        from app.file_utils import is_safe_file_id
        
        file_system = PrivateFileSystem()
        for file_id in refund_data.evidence_files:
            # 🔒 安全检查：防止路径遍历攻击
            if not is_safe_file_id(file_id):
                logger.warning(f"文件ID包含非法字符，跳过: {file_id[:50]}")
                continue
            try:
                # 检查文件是否存在于MessageAttachment中，且与当前任务相关
                attachment = db.query(MessageAttachment).filter(
                    MessageAttachment.blob_id == file_id
                ).first()
                
                if attachment:
                    # 通过附件找到消息，验证是否属于当前任务
                    from app.models import Message
                    task_message = db.query(Message).filter(
                        Message.id == attachment.message_id,
                        Message.task_id == task_id
                    ).first()
                    
                    if task_message:
                        # 文件属于当前任务，验证通过
                        validated_evidence_files.append(file_id)
                    else:
                        logger.warning(f"文件 {file_id} 不属于任务 {task_id}，跳过")
                else:
                    # 文件不在MessageAttachment中，可能是新上传的文件
                    # 检查文件是否存在于任务文件夹中（通过文件系统验证）
                    task_dir = file_system.base_dir / "tasks" / str(task_id)
                    file_exists = False
                    if task_dir.exists():
                        for ext_file in task_dir.glob(f"{file_id}.*"):
                            if ext_file.is_file():
                                file_exists = True
                                break
                    
                    if file_exists:
                        validated_evidence_files.append(file_id)
                    else:
                        logger.warning(f"文件 {file_id} 不存在或不属于任务 {task_id}，跳过")
            except Exception as file_error:
                logger.warning(f"验证文件 {file_id} 时发生错误: {file_error}，跳过")
        
        if not validated_evidence_files and refund_data.evidence_files:
            logger.warning(f"所有证据文件验证失败，但继续处理退款申请")
    
    # 处理证据文件（JSON数组）
    evidence_files_json = None
    if validated_evidence_files:
        import json
        evidence_files_json = json.dumps(validated_evidence_files)
    
    # 创建退款申请记录
    # 将退款原因类型和退款类型存储到reason字段（格式：reason_type|refund_type|reason）
    # 或者可以扩展RefundRequest模型添加新字段，这里先使用reason字段存储
    reason_with_metadata = f"{refund_data.reason_type}|{refund_data.refund_type}|{refund_data.reason}"
    
    refund_request = models.RefundRequest(
        task_id=task_id,
        poster_id=current_user.id,
        reason=reason_with_metadata,  # 包含原因类型和退款类型
        evidence_files=evidence_files_json,
        refund_amount=refund_data.refund_amount,
        status="pending",
        created_at=get_utc_time()
    )
    db.add(refund_request)
    db.flush()
    
    # 发送系统消息到任务聊天框
    try:
        from app.models import Message
        import json
        
        poster_name = current_user.name or f"用户{current_user.id}"
        # 退款原因类型的中文显示
        reason_type_names = {
            "completion_time_unsatisfactory": "对完成时间不满意",
            "not_completed": "接单者完全未完成",
            "quality_issue": "质量问题",
            "other": "其他"
        }
        reason_type_display = reason_type_names.get(refund_data.reason_type, refund_data.reason_type)
        refund_type_display = "全额退款" if refund_data.refund_type == "full" else f"部分退款（£{refund_data.refund_amount:.2f}）"
        
        content_zh = f"{poster_name} 申请退款（{reason_type_display}，{refund_type_display}）：{refund_data.reason[:100]}"
        content_en = f"{poster_name} has requested a refund ({refund_data.refund_type}): {refund_data.reason[:100]}"
        
        system_message = Message(
            sender_id=None,  # 系统消息
            receiver_id=None,
            content=content_zh,
            task_id=task_id,
            message_type="system",
            conversation_type="task",
            meta=json.dumps({
                "system_action": "refund_request_created", 
                "refund_request_id": refund_request.id, 
                "content_en": content_en
            }),
            created_at=get_utc_time()
        )
        db.add(system_message)
        db.flush()  # 获取消息ID
        
        # 如果有证据文件，创建附件（使用验证后的文件列表）
        if validated_evidence_files:
            from app.models import MessageAttachment
            from app.file_system import PrivateFileSystem
            
            file_system = PrivateFileSystem()
            for file_id in validated_evidence_files:
                try:
                    # 生成文件访问URL（需要用户ID和任务参与者）
                    participants = [task.poster_id]
                    if task.taker_id:
                        participants.append(task.taker_id)
                    access_token = file_system.generate_access_token(
                        file_id=file_id,
                        user_id=current_user.id,
                        chat_participants=participants
                    )
                    file_url = f"/api/private-file?file={file_id}&token={access_token}"
                    
                    attachment = MessageAttachment(
                        message_id=system_message.id,
                        attachment_type="file",  # 可能是文件，不只是图片
                        url=file_url,
                        blob_id=file_id,  # 存储文件ID
                        meta=json.dumps({"file_id": file_id}),
                        created_at=get_utc_time()
                    )
                    db.add(attachment)
                except Exception as file_error:
                    logger.warning(f"Failed to create attachment for file {file_id}: {file_error}")
                    # 即使文件处理失败，也继续处理其他文件
    except Exception as e:
        logger.error(f"Failed to send system message: {e}")
    
    # 通知接单者（如果有接单者）
    if task.taker_id:
        try:
            # 创建应用内通知
            crud.create_notification(
                db=db,
                user_id=task.taker_id,
                type="refund_request",
                title="退款申请通知",
                content=f"任务「{task.title}」的发布者申请退款。原因：{reason_type_display}。请查看详情并可以提交反驳证据。",
                related_id=str(task_id),
                related_type="task_id",
                auto_commit=False
            )
            
            # 发送推送通知（后台任务）
            if background_tasks:
                from app.push_notification_service import send_push_notification
                def _send_taker_notification():
                    try:
                        from app.database import SessionLocal
                        db_session = SessionLocal()
                        try:
                            send_push_notification(
                                db=db_session,
                                user_id=task.taker_id,
                                title=None,  # 从模板生成
                                body=None,  # 从模板生成
                                notification_type="refund_request",
                                data={
                                    "task_id": task_id,
                                    "refund_request_id": refund_request.id,
                                    "poster_id": current_user.id
                                },
                                template_vars={
                                    "poster_name": poster_name,
                                    "task_title": task.title,
                                    "reason_type": reason_type_display,
                                    "refund_type": refund_type_display,
                                    "task_id": task_id,
                                    "refund_request_id": refund_request.id
                                }
                            )
                        finally:
                            db_session.close()
                    except Exception as e:
                        logger.error(f"Failed to send push notification to taker: {e}")
                
                background_tasks.add_task(_send_taker_notification)
        except Exception as e:
            logger.error(f"Failed to send refund request notification to taker: {e}")
    
    # 通知管理员（后台任务）
    if background_tasks:
        try:
            from app.task_notifications import send_refund_request_notification_to_admin
            send_refund_request_notification_to_admin(
                db=db,
                background_tasks=background_tasks,
                task=task,
                refund_request=refund_request,
                poster=current_user
            )
        except Exception as e:
            logger.error(f"Failed to send refund request notification to admin: {e}")
    
    db.commit()
    db.refresh(refund_request)
    
    return refund_request


@router.get("/tasks/{task_id}/refund-status", response_model=Optional[schemas.RefundRequestOut])
def get_refund_status(
    task_id: int,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """查询任务的退款申请状态（返回最新的退款申请）"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found or no permission")
    # 发布者和接单人都可以查看退款状态
    uid = str(current_user.id)
    if str(task.poster_id) != uid and str(task.taker_id or "") != uid:
        raise HTTPException(status_code=404, detail="Task not found or no permission")

    refund_request = db.query(models.RefundRequest).filter(
        models.RefundRequest.task_id == task_id,
    ).order_by(models.RefundRequest.created_at.desc()).first()
    
    if not refund_request:
        return None
    
    # 获取任务信息（用于计算退款比例）
    task = crud.get_task(db, task_id)
    
    # 处理证据文件（JSON数组转List）
    evidence_files = None
    if refund_request.evidence_files:
        import json
        try:
            evidence_files = json.loads(refund_request.evidence_files)
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            logger.warning(f"解析退款请求证据文件JSON失败 (refund_request_id={refund_request.id}): {e}")
            evidence_files = []
    
    # 解析退款原因字段（格式：reason_type|refund_type|reason）
    reason_type = None
    refund_type = None
    reason_text = refund_request.reason
    refund_percentage = None
    
    if "|" in refund_request.reason:
        parts = refund_request.reason.split("|", 2)
        if len(parts) >= 3:
            reason_type = parts[0]
            refund_type = parts[1]
            reason_text = parts[2]
        elif len(parts) == 2:
            # 兼容旧格式
            reason_text = refund_request.reason
    
    # 计算退款比例（如果有任务金额和退款金额）
    if refund_request.refund_amount and task:
        task_amount = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
        if task_amount > 0:
            refund_percentage = float((refund_request.refund_amount / task_amount) * 100)
    
    # 创建输出对象
    from app.schemas import RefundRequestOut
    return RefundRequestOut(
        id=refund_request.id,
        task_id=refund_request.task_id,
        poster_id=refund_request.poster_id,
        reason_type=reason_type,
        refund_type=refund_type,
        reason=reason_text,
        evidence_files=evidence_files,
        refund_amount=refund_request.refund_amount,
        refund_percentage=refund_percentage,
        status=refund_request.status,
        admin_comment=refund_request.admin_comment,
        reviewed_by=refund_request.reviewed_by,
        reviewed_at=refund_request.reviewed_at,
        refund_intent_id=refund_request.refund_intent_id,
        refund_transfer_id=refund_request.refund_transfer_id,
        processed_at=refund_request.processed_at,
        completed_at=refund_request.completed_at,
        rebuttal_text=refund_request.rebuttal_text,
        rebuttal_evidence_files=_safe_json_loads(refund_request.rebuttal_evidence_files) if refund_request.rebuttal_evidence_files else None,
        rebuttal_submitted_at=refund_request.rebuttal_submitted_at,
        rebuttal_submitted_by=refund_request.rebuttal_submitted_by,
        created_at=refund_request.created_at,
        updated_at=refund_request.updated_at,
    )


@router.get("/tasks/{task_id}/dispute-timeline")
def get_task_dispute_timeline(
    task_id: int,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """
    获取任务的完整争议时间线
    包括：任务完成时间线、退款申请、反驳、管理员裁定等所有相关信息
    """
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # 验证用户权限：必须是任务参与者（发布者或接单者）
    if task.poster_id != current_user.id and (not task.taker_id or task.taker_id != current_user.id):
        raise HTTPException(status_code=403, detail="Only task participants can view dispute timeline")
    
    timeline_items = []
    import json
    from decimal import Decimal
    
    # 1. 任务完成时间线（从系统消息中获取）
    completion_message = db.query(models.Message).filter(
        models.Message.task_id == task_id,
        models.Message.message_type == "system",
        models.Message.meta.contains("task_completed_by_taker")
    ).order_by(models.Message.created_at.asc()).first()
    
    if completion_message:
        # 获取完成证据（附件和文字），需为私密图片/文件生成可访问 URL（与任务详情一致）
        completion_evidence = []
        if completion_message.id:
            evidence_participants = []
            if task.poster_id:
                evidence_participants.append(str(task.poster_id))
            if task.taker_id:
                evidence_participants.append(str(task.taker_id))
            if current_user and str(current_user.id) not in evidence_participants:
                evidence_participants.append(str(current_user.id))
            if not evidence_participants and current_user:
                evidence_participants.append(str(current_user.id))
            viewer_id = str(current_user.id) if current_user else (str(task.poster_id) if task.poster_id else (str(task.taker_id) if task.taker_id else None))

            attachments = db.query(models.MessageAttachment).filter(
                models.MessageAttachment.message_id == completion_message.id
            ).all()
            for att in attachments:
                url = att.url or ""
                is_private_image = att.blob_id and (
                    (att.attachment_type == "image") or (url and "/api/private-image/" in str(url))
                )
                if is_private_image and viewer_id and evidence_participants:
                    try:
                        from app.image_system import private_image_system
                        url = private_image_system.generate_image_url(
                            att.blob_id, viewer_id, evidence_participants
                        )
                    except Exception as e:
                        logger.debug(f"争议时间线完成证据 private-image URL 失败 blob_id={att.blob_id}: {e}")
                elif url and not url.startswith("http"):
                    try:
                        from app.file_utils import is_safe_file_id
                        from app.file_system import private_file_system
                        from app.signed_url import signed_url_manager
                        if is_safe_file_id(url):
                            task_dir = private_file_system.base_dir / "tasks" / str(task_id)
                            if task_dir.exists():
                                for f in task_dir.glob(f"{url}.*"):
                                    if f.is_file():
                                        file_path_for_url = f"files/{f.name}"
                                        if viewer_id:
                                            url = signed_url_manager.generate_signed_url(
                                                file_path=file_path_for_url,
                                                user_id=viewer_id,
                                                expiry_minutes=60,
                                                one_time=False,
                                            )
                                        break
                    except Exception as e:
                        logger.debug(f"争议时间线完成证据文件签名 URL 失败 file_id={url}: {e}")
                completion_evidence.append({
                    "type": att.attachment_type or "file",
                    "url": url,
                    "file_id": att.blob_id
                })
        
        # 从meta字段中提取文字证据
        if completion_message.meta:
            try:
                meta_data = json.loads(completion_message.meta)
                if "evidence_text" in meta_data and meta_data["evidence_text"]:
                    completion_evidence.append({
                        "type": "text",
                        "content": meta_data["evidence_text"]
                    })
            except (json.JSONDecodeError, KeyError):
                pass  # 如果meta解析失败，忽略
        
        timeline_items.append({
            "type": "task_completed",
            "title": "任务标记完成",
            "description": completion_message.content,
            "timestamp": completion_message.created_at.isoformat() if completion_message.created_at else None,
            "actor": "taker",
            "evidence": completion_evidence
        })
    
    # 2. 确认完成时间线（如果有）
    if task.completed_at and task.is_confirmed:
        confirmation_message = db.query(models.Message).filter(
            models.Message.task_id == task_id,
            models.Message.message_type == "system",
            models.Message.meta.contains("task_confirmed_by_poster")
        ).order_by(models.Message.created_at.asc()).first()
        
        confirmation_evidence = []
        if confirmation_message and confirmation_message.id:
            evidence_participants = []
            if task.poster_id:
                evidence_participants.append(str(task.poster_id))
            if task.taker_id:
                evidence_participants.append(str(task.taker_id))
            if current_user and str(current_user.id) not in evidence_participants:
                evidence_participants.append(str(current_user.id))
            if not evidence_participants and current_user:
                evidence_participants.append(str(current_user.id))
            viewer_id = str(current_user.id) if current_user else (str(task.poster_id) if task.poster_id else (str(task.taker_id) if task.taker_id else None))

            attachments = db.query(models.MessageAttachment).filter(
                models.MessageAttachment.message_id == confirmation_message.id
            ).all()
            for att in attachments:
                url = att.url or ""
                is_private_image = att.blob_id and (
                    (att.attachment_type == "image") or (url and "/api/private-image/" in str(url))
                )
                if is_private_image and viewer_id and evidence_participants:
                    try:
                        from app.image_system import private_image_system
                        url = private_image_system.generate_image_url(
                            att.blob_id, viewer_id, evidence_participants
                        )
                    except Exception as e:
                        logger.debug(f"争议时间线确认证据 private-image URL 失败 blob_id={att.blob_id}: {e}")
                elif url and not url.startswith("http"):
                    try:
                        from app.file_utils import is_safe_file_id
                        from app.file_system import private_file_system
                        from app.signed_url import signed_url_manager
                        if is_safe_file_id(url):
                            task_dir = private_file_system.base_dir / "tasks" / str(task_id)
                            if task_dir.exists():
                                for f in task_dir.glob(f"{url}.*"):
                                    if f.is_file():
                                        file_path_for_url = f"files/{f.name}"
                                        if viewer_id:
                                            url = signed_url_manager.generate_signed_url(
                                                file_path=file_path_for_url,
                                                user_id=viewer_id,
                                                expiry_minutes=60,
                                                one_time=False,
                                            )
                                        break
                    except Exception as e:
                        logger.debug(f"争议时间线确认证据文件签名 URL 失败 file_id={url}: {e}")
                confirmation_evidence.append({
                    "type": att.attachment_type or "file",
                    "url": url,
                    "file_id": att.blob_id
                })
        
        timeline_items.append({
            "type": "task_confirmed",
            "title": "发布者确认完成",
            "description": confirmation_message.content if confirmation_message else "发布者已确认任务完成",
            "timestamp": task.completed_at.isoformat() if task.completed_at else None,
            "actor": "poster",
            "evidence": confirmation_evidence
        })
    
    # 3. 退款申请时间线
    refund_requests = db.query(models.RefundRequest).filter(
        models.RefundRequest.task_id == task_id
    ).order_by(models.RefundRequest.created_at.asc()).all()
    
    # Batch-load all evidence attachments to avoid N+1 queries
    all_evidence_file_ids = set()
    for rr in refund_requests:
        for field in (rr.evidence_files, rr.rebuttal_evidence_files):
            if field:
                try:
                    all_evidence_file_ids.update(json.loads(field))
                except Exception:
                    pass
    attachment_map = {}
    if all_evidence_file_ids:
        attachments = db.query(models.MessageAttachment).filter(
            models.MessageAttachment.blob_id.in_(list(all_evidence_file_ids))
        ).all()
        attachment_map = {att.blob_id: att for att in attachments}
    
    for refund_request in refund_requests:
        reason_type = None
        refund_type = None
        reason_text = refund_request.reason
        
        if "|" in refund_request.reason:
            parts = refund_request.reason.split("|", 2)
            if len(parts) >= 3:
                reason_type = parts[0]
                refund_type = parts[1]
                reason_text = parts[2]
        
        refund_evidence = []
        if refund_request.evidence_files:
            try:
                evidence_file_ids = json.loads(refund_request.evidence_files)
                for file_id in evidence_file_ids:
                    att = attachment_map.get(file_id)
                    if att:
                        refund_evidence.append({
                            "type": att.attachment_type,
                            "url": att.url,
                            "file_id": att.blob_id
                        })
            except Exception as e:
                logger.warning(f"解析退款证据附件失败: {e}")
        
        timeline_items.append({
            "type": "refund_request",
            "title": "退款申请",
            "description": reason_text,
            "reason_type": reason_type,
            "refund_type": refund_type,
            "refund_amount": float(refund_request.refund_amount) if refund_request.refund_amount else None,
            "status": refund_request.status,
            "timestamp": refund_request.created_at.isoformat() if refund_request.created_at else None,
            "actor": "poster",
            "evidence": refund_evidence,
            "refund_request_id": refund_request.id
        })
        
        # 4. 反驳时间线（如果有）
        if refund_request.rebuttal_text:
            rebuttal_evidence = []
            if refund_request.rebuttal_evidence_files:
                try:
                    rebuttal_file_ids = json.loads(refund_request.rebuttal_evidence_files)
                    for file_id in rebuttal_file_ids:
                        att = attachment_map.get(file_id)
                        if att:
                            rebuttal_evidence.append({
                                "type": att.attachment_type,
                                "url": att.url,
                                "file_id": att.blob_id
                            })
                except Exception as e:
                    logger.warning(f"解析反驳证据附件失败: {e}")
            
            timeline_items.append({
                "type": "rebuttal",
                "title": "接单者反驳",
                "description": refund_request.rebuttal_text,
                "timestamp": refund_request.rebuttal_submitted_at.isoformat() if refund_request.rebuttal_submitted_at else None,
                "actor": "taker",
                "evidence": rebuttal_evidence,
                "refund_request_id": refund_request.id
            })
        
        # 5. 管理员裁定时间线（如果有）
        if refund_request.reviewed_at:
            reviewer_name = None
            if refund_request.reviewed_by:
                reviewer = crud.get_user_by_id(db, refund_request.reviewed_by)
                if reviewer:
                    reviewer_name = reviewer.name
            
            timeline_items.append({
                "type": "admin_review",
                "title": "管理员裁定",
                "description": refund_request.admin_comment or f"管理员已{refund_request.status}退款申请",
                "status": refund_request.status,
                "timestamp": refund_request.reviewed_at.isoformat() if refund_request.reviewed_at else None,
                "actor": "admin",
                "reviewer_name": reviewer_name,
                "refund_request_id": refund_request.id
            })
    
    # 6. 任务争议时间线（如果有）
    disputes = db.query(models.TaskDispute).filter(
        models.TaskDispute.task_id == task_id
    ).order_by(models.TaskDispute.created_at.asc()).all()
    
    for dispute in disputes:
        timeline_items.append({
            "type": "dispute",
            "title": "任务争议",
            "description": dispute.reason,
            "status": dispute.status,
            "timestamp": dispute.created_at.isoformat() if dispute.created_at else None,
            "actor": "poster",
            "dispute_id": dispute.id
        })
        
        # 如果有管理员处理结果
        if dispute.resolved_at:
            resolver_name = None
            if dispute.resolved_by:
                resolver = crud.get_user_by_id(db, dispute.resolved_by)
                if resolver:
                    resolver_name = resolver.name
            
            timeline_items.append({
                "type": "dispute_resolution",
                "title": "争议处理结果",
                "description": dispute.resolution_note or f"争议已{dispute.status}",
                "status": dispute.status,
                "timestamp": dispute.resolved_at.isoformat() if dispute.resolved_at else None,
                "actor": "admin",
                "resolver_name": resolver_name,
                "dispute_id": dispute.id
            })
    
    # 按时间排序
    timeline_items.sort(key=lambda x: x.get("timestamp") or "")
    
    return {
        "task_id": task_id,
        "task_title": task.title,
        "timeline": timeline_items
    }


@router.get("/tasks/{task_id}/refund-history", response_model=List[schemas.RefundRequestOut])
def get_refund_history(
    task_id: int,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """获取任务的退款申请历史记录（所有退款申请）"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found or no permission")
    # 发布者和接单人都可以查看退款历史
    uid = str(current_user.id)
    if str(task.poster_id) != uid and str(task.taker_id or "") != uid:
        raise HTTPException(status_code=404, detail="Task not found or no permission")

    refund_requests = db.query(models.RefundRequest).filter(
        models.RefundRequest.task_id == task_id,
    ).order_by(models.RefundRequest.created_at.desc()).all()
    
    if not refund_requests:
        return []
    
    # 获取任务信息（用于计算退款比例）
    task = crud.get_task(db, task_id)
    
    result_list = []
    for refund_request in refund_requests:
        # 处理证据文件（JSON数组转List）
        evidence_files = None
        if refund_request.evidence_files:
            import json
            try:
                evidence_files = json.loads(refund_request.evidence_files)
            except (json.JSONDecodeError, TypeError, ValueError) as e:
                logger.warning(f"解析退款请求证据文件JSON失败 (refund_request_id={refund_request.id}): {e}")
                evidence_files = []
        
        # 解析退款原因字段（格式：reason_type|refund_type|reason）
        reason_type = None
        refund_type = None
        reason_text = refund_request.reason
        refund_percentage = None
        
        if "|" in refund_request.reason:
            parts = refund_request.reason.split("|", 2)
            if len(parts) >= 3:
                reason_type = parts[0]
                refund_type = parts[1]
                reason_text = parts[2]
        
        # 计算退款比例（如果有任务金额和退款金额）
        if refund_request.refund_amount and task:
            task_amount = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
            if task_amount > 0:
                refund_percentage = float((refund_request.refund_amount / task_amount) * 100)
        
        # 处理反驳证据文件
        rebuttal_evidence_files = None
        if refund_request.rebuttal_evidence_files:
            try:
                rebuttal_evidence_files = json.loads(refund_request.rebuttal_evidence_files)
            except (json.JSONDecodeError, TypeError, ValueError) as e:
                logger.warning(f"解析反驳证据文件JSON失败 (refund_request_id={refund_request.id}): {e}")
                rebuttal_evidence_files = []
        
        # 创建输出对象
        from app.schemas import RefundRequestOut
        result_list.append(RefundRequestOut(
            id=refund_request.id,
            task_id=refund_request.task_id,
            poster_id=refund_request.poster_id,
            reason_type=reason_type,
            refund_type=refund_type,
            reason=reason_text,
            evidence_files=evidence_files,
            refund_amount=refund_request.refund_amount,
            refund_percentage=refund_percentage,
            status=refund_request.status,
            admin_comment=refund_request.admin_comment,
            reviewed_by=refund_request.reviewed_by,
            reviewed_at=refund_request.reviewed_at,
            refund_intent_id=refund_request.refund_intent_id,
            refund_transfer_id=refund_request.refund_transfer_id,
            processed_at=refund_request.processed_at,
            completed_at=refund_request.completed_at,
            rebuttal_text=refund_request.rebuttal_text,
            rebuttal_evidence_files=rebuttal_evidence_files,
            rebuttal_submitted_at=refund_request.rebuttal_submitted_at,
            rebuttal_submitted_by=refund_request.rebuttal_submitted_by,
            created_at=refund_request.created_at,
            updated_at=refund_request.updated_at,
        ))
    
    return result_list


@router.post("/tasks/{task_id}/refund-request/{refund_id}/cancel", response_model=schemas.RefundRequestOut)
def cancel_refund_request(
    task_id: int,
    refund_id: int,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """撤销退款申请（只能在pending状态时撤销）"""
    from sqlalchemy import select
    from decimal import Decimal
    
    # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定退款申请记录
    refund_query = select(models.RefundRequest).where(
        models.RefundRequest.id == refund_id,
        models.RefundRequest.task_id == task_id,
        models.RefundRequest.poster_id == current_user.id,
        models.RefundRequest.status == "pending"  # 只能撤销pending状态的申请
    ).with_for_update()
    refund_result = db.execute(refund_query)
    refund_request = refund_result.scalar_one_or_none()
    
    if not refund_request:
        # 检查是否存在但状态不是pending
        existing = db.query(models.RefundRequest).filter(
            models.RefundRequest.id == refund_id,
            models.RefundRequest.task_id == task_id,
            models.RefundRequest.poster_id == current_user.id
        ).first()
        if existing:
            raise HTTPException(
                status_code=400, 
                detail=f"退款申请状态不正确，无法撤销。当前状态: {existing.status}。只有待审核（pending）状态的退款申请可以撤销。"
            )
        raise HTTPException(status_code=404, detail="Refund request not found")
    
    # 更新退款申请状态为cancelled
    refund_request.status = "cancelled"
    refund_request.updated_at = get_utc_time()
    
    # 获取任务信息
    task = crud.get_task(db, task_id)
    
    # 发送系统消息到任务聊天框
    try:
        from app.models import Message
        import json
        
        poster_name = current_user.name or f"用户{current_user.id}"
        content_zh = f"{poster_name} 已撤销退款申请"
        content_en = f"{poster_name} has cancelled the refund request"
        
        system_message = Message(
            sender_id=None,  # 系统消息
            receiver_id=None,
            content=content_zh,
            task_id=task_id,
            message_type="system",
            conversation_type="task",
            meta=json.dumps({
                "system_action": "refund_request_cancelled", 
                "refund_request_id": refund_request.id, 
                "content_en": content_en
            }),
            created_at=get_utc_time()
        )
        db.add(system_message)
    except Exception as e:
        logger.error(f"Failed to send system message: {e}")
    
    db.commit()
    db.refresh(refund_request)
    
    # 处理输出格式（解析reason字段等）
    evidence_files = None
    if refund_request.evidence_files:
        import json
        try:
            evidence_files = json.loads(refund_request.evidence_files)
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            logger.warning(f"解析退款请求证据文件JSON失败 (refund_request_id={refund_request.id}): {e}")
            evidence_files = []
    
    # 解析退款原因字段
    reason_type = None
    refund_type = None
    reason_text = refund_request.reason
    refund_percentage = None
    
    if "|" in refund_request.reason:
        parts = refund_request.reason.split("|", 2)
        if len(parts) >= 3:
            reason_type = parts[0]
            refund_type = parts[1]
            reason_text = parts[2]
    
    # 计算退款比例
    if refund_request.refund_amount and task:
        task_amount = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
        if task_amount > 0:
            refund_percentage = float((refund_request.refund_amount / task_amount) * 100)
    
    from app.schemas import RefundRequestOut
    return RefundRequestOut(
        id=refund_request.id,
        task_id=refund_request.task_id,
        poster_id=refund_request.poster_id,
        reason_type=reason_type,
        refund_type=refund_type,
        reason=reason_text,
        evidence_files=evidence_files,
        refund_amount=refund_request.refund_amount,
        refund_percentage=refund_percentage,
        status=refund_request.status,
        admin_comment=refund_request.admin_comment,
        reviewed_by=refund_request.reviewed_by,
        reviewed_at=refund_request.reviewed_at,
        refund_intent_id=refund_request.refund_intent_id,
        refund_transfer_id=refund_request.refund_transfer_id,
        processed_at=refund_request.processed_at,
        completed_at=refund_request.completed_at,
        rebuttal_text=refund_request.rebuttal_text,
        rebuttal_evidence_files=_safe_json_loads(refund_request.rebuttal_evidence_files) if refund_request.rebuttal_evidence_files else None,
        rebuttal_submitted_at=refund_request.rebuttal_submitted_at,
        rebuttal_submitted_by=refund_request.rebuttal_submitted_by,
        created_at=refund_request.created_at,
        updated_at=refund_request.updated_at,
    )


@router.post("/tasks/{task_id}/refund-request/{refund_id}/rebuttal", response_model=schemas.RefundRequestOut)
def submit_refund_rebuttal(
    task_id: int,
    refund_id: int,
    rebuttal_data: schemas.RefundRequestRebuttal,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """
    接单者提交退款申请的反驳
    允许接单者上传完成证据和文字说明来反驳退款申请
    """
    from sqlalchemy import select
    from decimal import Decimal
    import json
    
    # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定退款申请记录
    refund_query = select(models.RefundRequest).where(
        models.RefundRequest.id == refund_id,
        models.RefundRequest.task_id == task_id
    ).with_for_update()
    refund_result = db.execute(refund_query)
    refund_request = refund_result.scalar_one_or_none()
    
    if not refund_request:
        raise HTTPException(status_code=404, detail="Refund request not found")
    
    # 获取任务
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # 验证用户是接单者
    if not task.taker_id or task.taker_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the task taker can submit a rebuttal")
    
    # 验证退款申请状态：只有在pending状态时才能提交反驳
    if refund_request.status != "pending":
        raise HTTPException(
            status_code=400,
            detail=f"只能对pending状态的退款申请提交反驳。当前状态: {refund_request.status}"
        )
    
    # 检查是否已经提交过反驳
    if refund_request.rebuttal_submitted_at is not None:
        raise HTTPException(
            status_code=400,
            detail="您已经提交过反驳，无法重复提交"
        )
    
    # 验证证据文件数量（最多5个）
    validated_evidence_files = []
    if rebuttal_data.evidence_files:
        if len(rebuttal_data.evidence_files) > 5:
            raise HTTPException(
                status_code=400,
                detail="证据文件数量不能超过5个"
            )
        
        from app.models import MessageAttachment
        from app.file_system import PrivateFileSystem
        from app.file_utils import is_safe_file_id
        
        file_system = PrivateFileSystem()
        for file_id in rebuttal_data.evidence_files:
            # 🔒 安全检查：防止路径遍历攻击
            if not is_safe_file_id(file_id):
                logger.warning(f"文件ID包含非法字符，跳过: {file_id[:50]}")
                continue
            try:
                # 检查文件是否存在于MessageAttachment中，且与当前任务相关
                attachment = db.query(MessageAttachment).filter(
                    MessageAttachment.blob_id == file_id
                ).first()
                
                if attachment:
                    # 通过附件找到消息，验证是否属于当前任务
                    from app.models import Message
                    task_message = db.query(Message).filter(
                        Message.id == attachment.message_id,
                        Message.task_id == task_id
                    ).first()
                    
                    if task_message:
                        validated_evidence_files.append(file_id)
                    else:
                        logger.warning(f"文件 {file_id} 不属于任务 {task_id}，跳过")
                else:
                    # 检查文件是否存在于任务文件夹中
                    task_dir = file_system.base_dir / "tasks" / str(task_id)
                    file_exists = False
                    if task_dir.exists():
                        for ext_file in task_dir.glob(f"{file_id}.*"):
                            if ext_file.is_file():
                                file_exists = True
                                break
                    
                    if file_exists:
                        validated_evidence_files.append(file_id)
                    else:
                        logger.warning(f"文件 {file_id} 不存在或不属于任务 {task_id}，跳过")
            except Exception as file_error:
                logger.warning(f"验证文件 {file_id} 时发生错误: {file_error}，跳过")
    
    # 处理证据文件（JSON数组）
    rebuttal_evidence_files_json = None
    if validated_evidence_files:
        rebuttal_evidence_files_json = json.dumps(validated_evidence_files)
    
    # 更新退款申请记录
    refund_request.rebuttal_text = rebuttal_data.rebuttal_text
    refund_request.rebuttal_evidence_files = rebuttal_evidence_files_json
    refund_request.rebuttal_submitted_at = get_utc_time()
    refund_request.rebuttal_submitted_by = current_user.id
    refund_request.updated_at = get_utc_time()
    
    # 发送系统消息到任务聊天框
    try:
        from app.models import Message
        import json
        
        taker_name = current_user.name or f"用户{current_user.id}"
        content_zh = f"{taker_name} 提交了反驳证据：{rebuttal_data.rebuttal_text[:100]}"
        content_en = f"{taker_name} has submitted rebuttal evidence: {rebuttal_data.rebuttal_text[:100]}"
        
        system_message = Message(
            sender_id=None,  # 系统消息
            receiver_id=None,
            content=content_zh,
            task_id=task_id,
            message_type="system",
            conversation_type="task",
            meta=json.dumps({
                "system_action": "refund_rebuttal_submitted",
                "refund_request_id": refund_request.id,
                "content_en": content_en
            }),
            created_at=get_utc_time()
        )
        db.add(system_message)
        db.flush()
        
        # 如果有证据文件，创建附件
        if validated_evidence_files:
            from app.models import MessageAttachment
            from app.file_system import PrivateFileSystem
            
            file_system = PrivateFileSystem()
            for file_id in validated_evidence_files:
                try:
                    # 生成文件访问URL
                    participants = [task.poster_id]
                    if task.taker_id:
                        participants.append(task.taker_id)
                    access_token = file_system.generate_access_token(
                        file_id=file_id,
                        user_id=current_user.id,
                        chat_participants=participants
                    )
                    file_url = f"/api/private-file?file={file_id}&token={access_token}"
                    
                    attachment = MessageAttachment(
                        message_id=system_message.id,
                        attachment_type="file",
                        url=file_url,
                        blob_id=file_id,
                        meta=json.dumps({"file_id": file_id}),
                        created_at=get_utc_time()
                    )
                    db.add(attachment)
                except Exception as file_error:
                    logger.warning(f"Failed to create attachment for file {file_id}: {file_error}")
    except Exception as e:
        logger.error(f"Failed to send system message: {e}")
    
    # 通知发布者和管理员（后台任务）
    try:
        # 通知发布者
        crud.create_notification(
            db=db,
            user_id=task.poster_id,
            type="refund_rebuttal",
            title="收到反驳证据",
            content=f"任务「{task.title}」的接单者提交了反驳证据，请查看详情。",
            related_id=str(task_id),
            related_type="task_id",
            auto_commit=False
        )
        
        # 通知管理员（后台任务）
        if background_tasks:
            try:
                from app.task_notifications import send_refund_rebuttal_notification_to_admin
                send_refund_rebuttal_notification_to_admin(
                    db=db,
                    background_tasks=background_tasks,
                    task=task,
                    refund_request=refund_request,
                    taker=current_user
                )
            except Exception as e:
                logger.error(f"Failed to send rebuttal notification to admin: {e}")
    except Exception as e:
        logger.error(f"Failed to send notifications: {e}")
    
    db.commit()
    db.refresh(refund_request)
    
    # 处理输出格式（解析reason字段等）
    evidence_files = None
    if refund_request.evidence_files:
        try:
            evidence_files = json.loads(refund_request.evidence_files)
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            logger.warning(f"解析退款请求证据文件JSON失败 (refund_request_id={refund_request.id}): {e}")
            evidence_files = []
    
    # 处理反驳证据文件
    rebuttal_evidence_files = None
    if refund_request.rebuttal_evidence_files:
        try:
            rebuttal_evidence_files = json.loads(refund_request.rebuttal_evidence_files)
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            logger.warning(f"解析反驳证据文件JSON失败 (refund_request_id={refund_request.id}): {e}")
            rebuttal_evidence_files = []
    
    # 解析退款原因字段
    reason_type = None
    refund_type = None
    reason_text = refund_request.reason
    refund_percentage = None
    
    if "|" in refund_request.reason:
        parts = refund_request.reason.split("|", 2)
        if len(parts) >= 3:
            reason_type = parts[0]
            refund_type = parts[1]
            reason_text = parts[2]
    
    # 计算退款比例
    if refund_request.refund_amount and task:
        task_amount = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
        if task_amount > 0:
            refund_percentage = float((refund_request.refund_amount / task_amount) * 100)
    
    from app.schemas import RefundRequestOut
    return RefundRequestOut(
        id=refund_request.id,
        task_id=refund_request.task_id,
        poster_id=refund_request.poster_id,
        reason_type=reason_type,
        refund_type=refund_type,
        reason=reason_text,
        evidence_files=evidence_files,
        refund_amount=refund_request.refund_amount,
        refund_percentage=refund_percentage,
        status=refund_request.status,
        admin_comment=refund_request.admin_comment,
        reviewed_by=refund_request.reviewed_by,
        reviewed_at=refund_request.reviewed_at,
        refund_intent_id=refund_request.refund_intent_id,
        refund_transfer_id=refund_request.refund_transfer_id,
        processed_at=refund_request.processed_at,
        completed_at=refund_request.completed_at,
        rebuttal_text=refund_request.rebuttal_text,
        rebuttal_evidence_files=rebuttal_evidence_files,
        rebuttal_submitted_at=refund_request.rebuttal_submitted_at,
        rebuttal_submitted_by=refund_request.rebuttal_submitted_by,
        created_at=refund_request.created_at,
        updated_at=refund_request.updated_at
    )


# ==================== 管理员退款申请管理API ====================
# 已迁移到 admin_refund_routes.py

# ==================== 管理员 VIP 订阅管理 API ====================
# 已迁移到 admin_vip_routes.py


@router.post("/tasks/{task_id}/confirm_completion", response_model=schemas.TaskOut)
def confirm_task_completion(
    task_id: int,
    evidence_files: Optional[List[str]] = Body(None, description="完成证据文件ID列表（可选）"),
    partial_transfer: Optional[schemas.PartialTransferRequest] = Body(None, description="部分转账请求（可选，用于部分完成的任务）"),
    background_tasks: BackgroundTasks = None,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """任务发布者确认任务完成，可上传完成证据文件"""
    # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定任务，防止并发确认
    locked_task_query = select(models.Task).where(
        models.Task.id == task_id
    ).with_for_update()
    task = db.execute(locked_task_query).scalar_one_or_none()
    
    if not task or task.poster_id != current_user.id:
        raise HTTPException(status_code=404, detail="Task not found or no permission")
    
    # ⚠️ 安全修复：更严格的状态检查，防止绕过支付
    # 检查任务状态：只允许 pending_confirmation 状态，或已支付且正常进行中的任务
    if task.status != "pending_confirmation":
        # 只允许 in_progress 状态的任务（已支付且正常进行中）
        # 不允许 pending_payment 状态的任务确认完成（即使 is_paid 被错误设置）
        if task.is_paid == 1 and task.taker_id and task.status == "in_progress":
            logger.warning(
                f"⚠️ 任务 {task_id} 状态为 {task.status}，但已支付且有接受者，允许确认完成"
            )
            # 将状态更新为 pending_confirmation 以便后续处理
            task.status = "pending_confirmation"
            db.flush()  # flush而不是commit，保持在同一事务中
        else:
            # 如果 is_paid 被错误设置，记录安全警告
            if task.is_paid == 1 and task.status == "pending_payment":
                logger.error(
                    f"🔴 安全警告：任务 {task_id} 状态为 pending_payment 但 is_paid=1，"
                    f"可能存在数据不一致或安全漏洞"
                )
            raise HTTPException(
                status_code=400, 
                detail=f"任务状态不正确，无法确认完成。当前状态: {task.status}, is_paid: {task.is_paid}。"
                      f"任务必须处于 pending_confirmation 状态，或已支付且处于 in_progress 状态。"
            )

    # 将任务状态改为已完成
    task.status = "completed"
    task.confirmed_at = get_utc_time()  # 记录确认时间
    task.auto_confirmed = 0  # 手动确认
    # 付费任务：is_confirmed 在钱包入账成功后才设为 1，避免入账失败时任务被跳过
    # 免费任务：直接确认
    if not (task.is_paid == 1 and task.taker_id and task.escrow_amount and task.escrow_amount > 0):
        task.is_confirmed = 1
    # 更新可靠度画像
    try:
        from app.services.reliability_calculator import on_task_completed
        was_on_time = bool(task.deadline and task.completed_at and task.completed_at <= task.deadline)
        on_task_completed(db, task.taker_id, was_on_time)
    except Exception as e:
        logger.warning(f"更新可靠度失败(task_completed): {e}")
    try:
        db.commit()
    except Exception as e:
        db.rollback()
        logger.error(f"确认任务完成提交失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="确认任务完成失败，请重试")
    crud.add_task_history(db, task_id, current_user.id, "confirmed_completion")
    db.refresh(task)
    
    # ⚠️ 清除任务缓存，确保前端立即看到更新后的状态
    try:
        from app.services.task_service import TaskService
        TaskService.invalidate_cache(task_id)
        from app.redis_cache import invalidate_tasks_cache
        invalidate_tasks_cache()
        logger.info(f"✅ 已清除任务 {task_id} 的缓存（确认任务完成）")
    except Exception as e:
        logger.warning(f"⚠️ 清除任务缓存失败: {e}")

    # 发送系统消息到任务聊天框
    try:
        from app.models import Message
        from app.utils.notification_templates import get_notification_texts
        import json
        
        poster_name = current_user.name or f"用户{current_user.id}"
        _, content_zh, _, content_en = get_notification_texts(
            "task_confirmed",
            poster_name=poster_name,
            task_title=task.title
        )
        # 如果没有对应的模板，使用默认文本
        if not content_zh:
            content_zh = f"发布者 {poster_name} 已确认任务完成。"
        if not content_en:
            content_en = f"Poster {poster_name} has confirmed task completion."
        
        system_message = Message(
            sender_id=None,  # 系统消息，sender_id为None
            receiver_id=None,
            content=content_zh,  # 中文内容（英文存于 meta.content_en 供客户端本地化）
            task_id=task_id,
            message_type="system",
            conversation_type="task",
            meta=json.dumps({"system_action": "task_confirmed_by_poster", "content_en": content_en}),
            created_at=get_utc_time()
        )
        db.add(system_message)
        db.flush()  # 获取消息ID
        
        # 如果有完成证据文件，创建附件
        if evidence_files:
            from app.models import MessageAttachment
            for file_id in evidence_files:
                # 生成文件访问URL（使用私有文件系统）
                from app.file_system import PrivateFileSystem
                file_system = PrivateFileSystem()
                try:
                    # 生成访问URL（需要用户ID和任务参与者）
                    participants = [task.poster_id]
                    if task.taker_id:
                        participants.append(task.taker_id)
                    access_token = file_system.generate_access_token(
                        file_id=file_id,
                        user_id=current_user.id,
                        chat_participants=participants
                    )
                    file_url = f"/api/private-file?file={file_id}&token={access_token}"
                    
                    attachment = MessageAttachment(
                        message_id=system_message.id,
                        attachment_type="file",  # 可能是文件，不只是图片
                        url=file_url,
                        blob_id=file_id,  # 存储文件ID
                        meta=json.dumps({"file_id": file_id}),
                        created_at=get_utc_time()
                    )
                    db.add(attachment)
                except Exception as file_error:
                    logger.warning(f"Failed to create attachment for file {file_id}: {file_error}")
                    # 即使文件处理失败，也继续处理其他文件
        
        db.commit()
    except Exception as e:
        db.rollback()
        logger.warning(f"Failed to send system message: {e}")
        # 系统消息发送失败不影响任务确认流程

    # 查询一次 taker，后续通知/奖励/入账复用
    taker = crud.get_user_by_id(db, task.taker_id) if task.taker_id else None

    # 发送任务确认完成通知和邮件给接收者
    if taker:
        try:
            from app.task_notifications import send_task_confirmation_notification
            from fastapi import BackgroundTasks

            # 确保 background_tasks 存在，如果为 None 则创建新实例
            if background_tasks is None:
                background_tasks = BackgroundTasks()

            if taker:
                send_task_confirmation_notification(
                    db=db,
                    background_tasks=background_tasks,
                    task=task,
                    taker=taker
                )
        except Exception as e:
            logger.warning(f"Failed to send task confirmation notification: {e}")
            # 通知发送失败不影响任务确认流程

    # 自动更新相关用户的统计信息（后台执行，不阻塞响应）
    def _bg_update_stats(poster_id, taker_id):
        from app.database import SessionLocal
        bg_db = SessionLocal()
        try:
            crud.update_user_statistics(bg_db, poster_id)
            if taker_id:
                crud.update_user_statistics(bg_db, taker_id)
        except Exception as e:
            logger.warning(f"后台更新用户统计失败: {e}")
        finally:
            bg_db.close()
    if background_tasks is None:
        background_tasks = BackgroundTasks()
    background_tasks.add_task(_bg_update_stats, task.poster_id, task.taker_id)
    
    # 🔒 使用 SAVEPOINT 包装所有奖励发放操作，确保原子性
    # 任务完成时自动发放积分奖励（平台赠送，非任务报酬）
    if task.taker_id:
        rewards_savepoint = db.begin_nested()
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
                
                # 生成幂等键（防止重复发放）- 必须是确定性的以确保幂等性
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
            rewards_savepoint.commit()
        except Exception as e:
            rewards_savepoint.rollback()
            logger.error(f"发放任务完成积分奖励失败，已回滚SAVEPOINT: {e}", exc_info=True)
            # 积分发放失败不影响任务完成流程
    
    # 检查任务是否关联活动，如果活动设置了奖励申请者，则发放奖励（积分和/或现金）
    if task.taker_id and task.parent_activity_id:
        activity_rewards_savepoint = db.begin_nested()
        try:
            from app.coupon_points_crud import add_points_transaction
            from app.models import Activity
            import stripe
            import os
            
            # 查询关联的活动
            activity = db.query(Activity).filter(Activity.id == task.parent_activity_id).first()
            
            if activity and activity.reward_applicants:
                # 活动设置了奖励申请者
                
                # 1. 发放积分奖励（如果有）
                if activity.applicant_points_reward and activity.applicant_points_reward > 0:
                    points_to_give = activity.applicant_points_reward
                    
                    # 生成幂等键（防止重复发放）
                    activity_reward_idempotency_key = f"activity_reward_points_{task.parent_activity_id}_{task_id}_{task.taker_id}"
                    
                    # 检查是否已发放（通过幂等键）
                    from app.models import PointsTransaction
                    existing_activity_reward = db.query(PointsTransaction).filter(
                        PointsTransaction.idempotency_key == activity_reward_idempotency_key
                    ).first()
                    
                    if not existing_activity_reward:
                        # 发放活动奖励积分给申请者
                        add_points_transaction(
                            db,
                            task.taker_id,
                            type="earn",
                            amount=points_to_give,
                            source="activity_applicant_reward",
                            related_id=task.parent_activity_id,
                            related_type="activity",
                            description=f"完成活动 #{task.parent_activity_id} 任务获得达人奖励积分",
                            idempotency_key=activity_reward_idempotency_key
                        )
                        
                        # 更新活动的已发放积分总额
                        activity.distributed_points_total = (activity.distributed_points_total or 0) + points_to_give
                        
                        logger.info(f"活动奖励积分已发放: 用户 {task.taker_id}, 活动 {task.parent_activity_id}, 积分 {points_to_give}")
                        
                        # 发送通知给申请者
                        try:
                            crud.create_notification(
                                db=db,
                                user_id=task.taker_id,
                                type="activity_reward_points",
                                title="活动奖励积分已发放",
                                content=f"您完成活动「{activity.title}」的任务，获得 {points_to_give} 积分奖励",
                                related_id=str(task.parent_activity_id),
                                auto_commit=False
                            )
                            
                            # 发送推送通知
                            try:
                                from app.push_notification_service import send_push_notification
                                send_push_notification(
                                    db=db,
                                    user_id=task.taker_id,
                                    notification_type="activity_reward_points",
                                    data={"activity_id": task.parent_activity_id, "task_id": task_id, "points": points_to_give},
                                    template_vars={"activity_title": activity.title, "points": points_to_give}
                                )
                            except Exception as e:
                                logger.warning(f"发送活动奖励积分推送通知失败: {e}")
                        except Exception as e:
                            logger.warning(f"创建活动奖励积分通知失败: {e}")
                
                # 2. 发放现金奖励（如果有）
                if activity.applicant_reward_amount and activity.applicant_reward_amount > 0:
                    cash_amount = float(activity.applicant_reward_amount)
                    
                    # 生成幂等键（防止重复发放）
                    activity_cash_reward_idempotency_key = f"activity_reward_cash_{task.parent_activity_id}_{task_id}_{task.taker_id}"
                    
                    # 检查是否已发放（通过检查 PaymentTransfer 记录）
                    from app.models import PaymentTransfer
                    existing_cash_reward = db.query(PaymentTransfer).filter(
                        PaymentTransfer.idempotency_key == activity_cash_reward_idempotency_key
                    ).first()
                    
                    if not existing_cash_reward and taker:
                        try:
                            from app.wallet_service import credit_wallet
                            from decimal import Decimal

                            wallet_tx = credit_wallet(
                                db,
                                user_id=taker.id,
                                amount=Decimal(str(cash_amount)),
                                source="activity_cash_reward",
                                related_id=str(task_id),
                                related_type="task",
                                description=f"活动 #{task.parent_activity_id} 现金奖励",
                                currency=(task.currency or "GBP").upper(),
                                idempotency_key=activity_cash_reward_idempotency_key,
                            )

                            if wallet_tx:
                                logger.info(f"活动现金奖励已入账钱包: 用户 {task.taker_id}, 活动 {task.parent_activity_id}, 金额 £{cash_amount:.2f}")
                            else:
                                logger.info(f"活动现金奖励已处理过（幂等跳过）: task_id={task_id}")

                            # 发送通知给申请者
                            try:
                                crud.create_notification(
                                    db=db,
                                    user_id=task.taker_id,
                                    type="activity_reward_cash",
                                    title="活动现金奖励已发放",
                                    content=f"您完成活动「{activity.title}」的任务，获得 £{cash_amount:.2f} 现金奖励（已入账钱包）",
                                    related_id=str(task.parent_activity_id),
                                    auto_commit=False
                                )

                                try:
                                    from app.push_notification_service import send_push_notification
                                    send_push_notification(
                                        db=db,
                                        user_id=task.taker_id,
                                        notification_type="activity_reward_cash",
                                        data={"activity_id": task.parent_activity_id, "task_id": task_id, "amount": cash_amount},
                                        template_vars={"activity_title": activity.title, "amount": cash_amount}
                                    )
                                except Exception as e:
                                    logger.warning(f"发送活动现金奖励推送通知失败: {e}")
                            except Exception as e:
                                logger.warning(f"创建活动现金奖励通知失败: {e}")
                        except Exception as e:
                            logger.error(f"发放活动现金奖励失败: {e}", exc_info=True)
                            # 现金奖励发放失败不影响任务完成流程
                    elif not existing_cash_reward and not taker:
                        logger.warning(f"用户 {task.taker_id} 不存在，无法发放现金奖励")
                
                # 提交SAVEPOINT内的所有奖励发放更改
                activity_rewards_savepoint.commit()
                
        except Exception as e:
            activity_rewards_savepoint.rollback()
            logger.error(f"发放活动奖励失败，已回滚SAVEPOINT: {e}", exc_info=True)
            # 奖励发放失败不影响任务完成流程
    
    # 如果任务已支付，将托管金额转给接受人
    # 优先直接 Stripe Transfer（接单者有 Connect 账户时），否则入本地钱包
    if task.is_paid == 1 and task.taker_id and task.escrow_amount > 0:
        payout_savepoint = db.begin_nested()
        try:
            from decimal import Decimal

            net_amount = Decimal(str(task.escrow_amount))
            currency = (task.currency or "GBP").upper()

            # Determine gross amount: agreed_reward > base_reward > reward (fallback to net)
            _raw_gross = task.agreed_reward if task.agreed_reward is not None else (
                task.base_reward if task.base_reward is not None else task.reward
            )
            gross_amount = Decimal(str(_raw_gross)) if _raw_gross is not None else net_amount
            fee_amount = gross_amount - net_amount if gross_amount > net_amount else Decimal("0")

            # Determine source: flea market sale or task earning
            source = "flea_market_sale" if getattr(task, "task_source", "normal") in ("flea_market", "flea_market_rental") else "task_earning"

            idempotency_key = f"earning:task:{task.id}:user:{task.taker_id}"

            # 检查接单者是否有 Stripe Connect 账户（taker 已在函数开头查询）
            taker_stripe_id = getattr(taker, "stripe_account_id", None) if taker else None

            if taker_stripe_id:
                # 有 Stripe Connect 账户 → 尝试直接转账，失败则回退到钱包
                amount_minor = int(net_amount * 100)  # 转为最小货币单位（便士/分）
                try:
                    transfer = stripe.Transfer.create(
                        amount=amount_minor,
                        currency=currency.lower(),
                        destination=taker_stripe_id,
                        description=f"Task #{task.id} payout",
                        metadata={
                            "task_id": str(task.id),
                            "taker_id": str(task.taker_id),
                            "source": source,
                        },
                        idempotency_key=idempotency_key,
                    )
                    logger.info(
                        f"✅ 任务 {task_id} 奖励 £{net_amount:.2f} 已直接转账至用户 {task.taker_id} "
                        f"Stripe 账户 {taker_stripe_id} (transfer={transfer.id})"
                    )
                except stripe.error.StripeError as stripe_err:
                    # Stripe 明确拒绝 → 回退到钱包入账（不会双重支付）
                    logger.warning(
                        f"任务 {task_id} Stripe Transfer 被拒绝，回退到钱包入账: {stripe_err}"
                    )
                    from app.wallet_service import credit_wallet
                    credit_wallet(
                        db=db,
                        user_id=task.taker_id,
                        amount=net_amount,
                        source=source,
                        related_id=str(task.id),
                        related_type="task",
                        description=f"任务 #{task.id} 奖励（Stripe转账失败，入钱包）",
                        fee_amount=fee_amount,
                        gross_amount=gross_amount,
                        idempotency_key=idempotency_key,
                        currency=currency,
                    )
                except Exception as unexpected_err:
                    # 网络超时等不确定异常 → 不回退钱包（Stripe 可能已成功）
                    # 抛出让外层 savepoint rollback，由 auto_transfer 定时任务后续处理
                    logger.error(
                        f"任务 {task_id} Stripe Transfer 异常（可能已成功），不回退钱包: {unexpected_err}"
                    )
                    raise
            else:
                # 无 Stripe Connect 账户 → 入本地钱包（用户后续可绑定 Stripe 后提现）
                from app.wallet_service import credit_wallet
                credit_wallet(
                    db=db,
                    user_id=task.taker_id,
                    amount=net_amount,
                    source=source,
                    related_id=str(task.id),
                    related_type="task",
                    description=f"任务 #{task.id} 奖励",
                    fee_amount=fee_amount,
                    gross_amount=gross_amount,
                    idempotency_key=idempotency_key,
                    currency=currency,
                )
                logger.info(
                    f"✅ 任务 {task_id} 奖励 £{net_amount:.2f} 已记入用户 {task.taker_id} 本地钱包"
                    f"（用户无 Stripe Connect 账户）"
                )

            # Clear escrow and mark as paid
            task.escrow_amount = Decimal("0.00")
            task.paid_to_user_id = task.taker_id
            task.is_confirmed = 1

            payout_savepoint.commit()
        except Exception as e:
            payout_savepoint.rollback()
            logger.error(f"任务报酬支付失败 for task {task_id}: {e}", exc_info=True)
            # 支付失败不影响任务完成确认流程

    # 提交所有 savepoint 内的变更（积分奖励、活动奖励、钱包入账）
    try:
        db.commit()
    except Exception as e:
        db.rollback()
        logger.error(f"提交奖励/钱包变更失败 for task {task_id}: {e}", exc_info=True)

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
        cancel_result = crud.cancel_task(db, task_id, current_user.id)
        if isinstance(cancel_result, str):
            error_messages = {
                "task_not_found": "Task not found.",
                "cancel_not_permitted": "You don't have permission to cancel this task.",
                "not_participant": "Only task participants can cancel.",
            }
            raise HTTPException(
                status_code=400,
                detail=error_messages.get(cancel_result, cancel_result),
            )
        cancelled_task = cancel_result
        
        # ⚠️ 清除任务缓存，确保前端立即看到更新后的状态
        try:
            from app.services.task_service import TaskService
            TaskService.invalidate_cache(task_id)
            from app.redis_cache import invalidate_tasks_cache
            invalidate_tasks_cache()
            logger.info(f"✅ 已清除任务 {task_id} 的缓存（取消任务）")
        except Exception as e:
            logger.warning(f"⚠️ 清除任务缓存失败: {e}")
        
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
    if isinstance(result, str):
        error_messages = {
            "task_not_found": "Task not found.",
            "not_task_poster": "Only the task poster can delete this task.",
            "task_not_cancelled": "Only cancelled tasks can be deleted.",
            "delete_failed": "Failed to delete task, please try again.",
        }
        raise HTTPException(
            status_code=400,
            detail=error_messages.get(result, result),
        )

    return result


@router.get("/tasks/{task_id}/history")
@measure_api_performance("get_task_history")
@cache_response(ttl=180, key_prefix="task_history")  # 缓存3分钟
def get_task_history(
    task_id: int,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    # 安全校验：只允许任务参与者查看任务历史
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    if task.poster_id != current_user.id and task.taker_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to view this task's history")
    
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
        
        from app.models import Review
        from sqlalchemy import func as sa_func
        rating_row = db.query(
            sa_func.avg(Review.rating), sa_func.count(Review.id)
        ).filter(Review.user_id == current_user.id).first()
        avg_rating = round(float(rating_row[0]), 1) if rating_row and rating_row[0] else 0.0
        
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
        
        # 计算进行中的任务数
        # 1. 作为发布者或接受者的任务，状态为 in_progress
        from app.models import Task, TaskParticipant
        
        # 普通任务（作为发布者或接受者）
        regular_in_progress_count = db.query(Task).filter(
            (Task.poster_id == current_user.id) | (Task.taker_id == current_user.id),
            Task.status == "in_progress",
            Task.is_multi_participant == False  # 排除多人任务，因为多人任务通过参与者统计
        ).count()
        
        # 2. 多人任务：作为参与者，参与者状态为 in_progress 且任务状态为 in_progress
        multi_participant_in_progress_count = db.query(func.count(TaskParticipant.id)).join(
            Task, TaskParticipant.task_id == Task.id
        ).filter(
            TaskParticipant.user_id == current_user.id,
            TaskParticipant.status == "in_progress",
            Task.status == "in_progress",
            Task.is_multi_participant == True
        ).scalar() or 0
        
        # 3. 多人任务：作为发布者（expert_creator_id），任务状态为 in_progress
        multi_task_creator_in_progress_count = db.query(Task).filter(
            Task.expert_creator_id == current_user.id,
            Task.status == "in_progress",
            Task.is_multi_participant == True
        ).count()
        
        in_progress_tasks_count = regular_in_progress_count + multi_participant_in_progress_count + multi_task_creator_in_progress_count

        # 检查用户是否是任务达人
        from app.models import TaskExpert
        task_expert = db.query(TaskExpert).filter(
            TaskExpert.id == current_user.id,
            TaskExpert.status == "active"
        ).first()
        is_expert = task_expert is not None

        # 检查用户是否通过学生认证
        from app.models import StudentVerification
        student_verification = db.query(StudentVerification).filter(
            StudentVerification.user_id == current_user.id,
            StudentVerification.status == "verified"
        ).order_by(StudentVerification.created_at.desc()).first()
        is_student_verified = student_verification is not None

        from app.utils.badge_helpers import enrich_displayed_badges_sync
        _badge_cache = enrich_displayed_badges_sync(db, [current_user.id])

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
            "task_count": in_progress_tasks_count,  # 修改为进行中的任务数，而不是所有任务数
            "completed_task_count": getattr(current_user, 'completed_task_count', 0),
            "avg_rating": avg_rating,
            "is_expert": is_expert,
            "is_student_verified": is_student_verified,
            "residence_city": residence_city,
            "language_preference": language_preference,
            "name_updated_at": getattr(current_user, 'name_updated_at', None),
            "flea_market_notice_agreed_at": getattr(current_user, 'flea_market_notice_agreed_at', None),  # 跳蚤市场须知同意时间
            "onboarding_completed": getattr(current_user, 'onboarding_completed', False),
            "displayed_badge": _badge_cache.get(current_user.id),
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


@router.get("/my-tasks")
@measure_api_performance("get_my_tasks")
def get_my_tasks(
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
    page: int = Query(1, ge=1, description="页码，从 1 开始"),
    page_size: int = Query(20, ge=1, le=100, description="每页条数"),
    role: str | None = Query(None, description="角色筛选: poster=我发布的, taker=我接取的"),
    status: str | None = Query(None, description="状态筛选: open, in_progress, completed, cancelled 等"),
):
    """获取当前用户的任务（支持按 role/status 筛选与分页）。返回 { tasks, total, page, page_size }。"""
    offset = (page - 1) * page_size
    tasks, total = crud.get_user_tasks(
        db, current_user.id,
        limit=page_size, offset=offset,
        role=role, status=status,
    )

    # 任务双语字段已由 ORM 从任务表列加载；缺失时后台触发预取
    task_ids = [task.id for task in tasks]
    missing_task_ids = [
        t.id for t in tasks
        if not getattr(t, "title_en", None) or not getattr(t, "title_zh", None)
        or not getattr(t, "description_en", None) or not getattr(t, "description_zh", None)
    ]
    if missing_task_ids:
        _trigger_background_translation_prefetch(
            missing_task_ids,
            target_languages=["en", "zh"],
            label="后台翻译任务",
        )

    # 批量加载展示勋章
    from app.utils.badge_helpers import enrich_displayed_badges_sync
    _badge_user_ids = set()
    for t in tasks:
        if t.poster is not None:
            _badge_user_ids.add(t.poster.id)
        if t.taker is not None:
            _badge_user_ids.add(t.taker.id)
    _badge_cache = enrich_displayed_badges_sync(db, list(_badge_user_ids))

    # 序列化任务，并附带相关用户简要信息（当前用户是任务相关方）
    task_list = []
    for t in tasks:
        task_dict = schemas.TaskOut.model_validate(t).model_dump()
        if t.poster is not None:
            task_dict["poster"] = schemas.UserBrief.model_validate(t.poster).model_dump()
            task_dict["poster"]["displayed_badge"] = _badge_cache.get(t.poster.id)
        if t.taker is not None:
            task_dict["taker"] = schemas.UserBrief.model_validate(t.taker).model_dump()
            task_dict["taker"]["displayed_badge"] = _badge_cache.get(t.taker.id)
        task_list.append(task_dict)

    return {
        "tasks": task_list,
        "total": total,
        "page": page,
        "page_size": page_size,
    }


def _safe_parse_images(images_value):
    """安全解析图片字段（Text/JSON列存储兼容）"""
    if not images_value:
        return []
    if isinstance(images_value, list):
        return images_value
    if isinstance(images_value, str):
        try:
            parsed = json.loads(images_value)
            return parsed if isinstance(parsed, list) else []
        except (json.JSONDecodeError, ValueError):
            return []
    return []


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

    # Increment profile views (don't count self-views)
    try:
        is_self_view = current_user and current_user.id == user.id
        if not is_self_view:
            user.profile_views = (user.profile_views or 0) + 1
            db.commit()
            db.refresh(user)
    except Exception:
        db.rollback()

    # 计算注册天数
    from app.utils.time_utils import get_utc_time

    days_since_joined = (get_utc_time() - user.created_at).days

    # 获取用户的任务统计（真实数据：计算所有任务，不限制状态和公开性）
    from app.models import Task
    
    # 计算发布的任务数（所有状态）
    posted_tasks_count = db.query(Task).filter(Task.poster_id == user_id).count()
    
    # 计算接取的任务数（所有状态）
    taken_tasks_count = db.query(Task).filter(Task.taker_id == user_id).count()
    
    # 计算完成的任务数（接取的任务中已完成的数量）
    completed_tasks_count = db.query(Task).filter(
        Task.taker_id == user_id,
        Task.status == "completed"
    ).count()
    
    # 计算总任务数 = 发布任务数 + 接受任务数
    total_tasks = posted_tasks_count + taken_tasks_count

    # 计算完成率 = 完成的任务数 / 接受过的任务数（包括中途被取消的任务）
    completion_rate = 0.0
    if taken_tasks_count > 0:
        completion_rate = (completed_tasks_count / taken_tasks_count) * 100
    
    # 只显示已完成且公开的任务，按时间取最近 3 条
    # 发布者看 is_public，接单者看 taker_public
    recent_tasks_source = (
        db.query(Task)
        .filter(
            Task.status == "completed",
            Task.is_visible == True,
            (
                ((Task.poster_id == user_id) & (Task.is_public == 1))
                | ((Task.taker_id == user_id) & (Task.taker_public == 1))
            ),
        )
        .order_by(Task.created_at.desc())
        .limit(3)
        .all()
    )
    missing_task_ids = [
        t.id for t in recent_tasks_source
        if not getattr(t, "title_en", None) or not getattr(t, "title_zh", None)
    ]
    if missing_task_ids:
        _trigger_background_translation_prefetch(
            missing_task_ids,
            target_languages=["en", "zh"],
            label="后台翻译任务标题",
        )

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

    # 检查用户是否是任务达人（在task_experts表中且status为active）
    from app.models import TaskExpert
    task_expert = db.query(TaskExpert).filter(
        TaskExpert.id == user_id,
        TaskExpert.status == "active"
    ).first()
    is_expert = task_expert is not None

    # 检查用户是否通过学生认证（在student_verifications表中有verified状态的记录）
    from app.models import StudentVerification
    student_verification = db.query(StudentVerification).filter(
        StudentVerification.user_id == user_id,
        StudentVerification.status == "verified"
    ).order_by(StudentVerification.created_at.desc()).first()
    is_student_verified = student_verification is not None

    # 关注相关统计
    from app.models import UserFollow
    followers_count = db.query(UserFollow).filter(UserFollow.following_id == user_id).count()
    following_count = db.query(UserFollow).filter(UserFollow.follower_id == user_id).count()

    # 当前登录用户是否已关注该用户
    is_following = False
    if current_user:
        is_following = db.query(UserFollow).filter(
            UserFollow.follower_id == current_user.id,
            UserFollow.following_id == user_id,
        ).first() is not None

    # 安全：只返回公开信息，不返回敏感信息（email, phone）
    from app.utils.badge_helpers import enrich_displayed_badges_sync
    _badge_cache = enrich_displayed_badges_sync(db, [user.id])

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
        "is_expert": is_expert,
        "is_student_verified": is_student_verified,
        "profile_views": user.profile_views or 0,
        "bio": user.bio,
        "residence_city": user.residence_city,
        "followers_count": followers_count,
        "following_count": following_count,
        "is_following": is_following,
        "displayed_badge": _badge_cache.get(user.id),
    }

    # 获取用户近期论坛帖子（已发布的，最多5条）
    from app.models import ForumPost
    recent_forum_posts = (
        db.query(ForumPost)
        .filter(
            ForumPost.author_id == user_id,
            ForumPost.is_deleted == False,
            ForumPost.is_visible == True,
        )
        .order_by(ForumPost.created_at.desc())
        .limit(5)
        .all()
    )

    # 获取用户已售闲置物品（最多5条）
    from app.models import FleaMarketItem
    sold_flea_items = (
        db.query(FleaMarketItem)
        .filter(
            FleaMarketItem.seller_id == user_id,
            FleaMarketItem.status == "sold",
            FleaMarketItem.is_visible == True,
        )
        .order_by(FleaMarketItem.updated_at.desc())
        .limit(5)
        .all()
    )

    return {
        "user": user_data,
        "stats": {
            "total_tasks": total_tasks,
            "posted_tasks": posted_tasks_count,  # 真实数据：所有发布的任务
            "taken_tasks": taken_tasks_count,  # 真实数据：所有接取的任务
            "completed_tasks": completed_tasks_count,  # 真实数据：所有完成的任务
            "completion_rate": round(completion_rate, 1),
            "total_reviews": len(reviews),
        },
        "recent_tasks": [
            {
                "id": t.id,
                "title": t.title,
                "title_en": getattr(t, "title_en", None),
                "title_zh": getattr(t, "title_zh", None),
                "status": t.status,
                "created_at": t.created_at,
                "reward": float(t.agreed_reward) if t.agreed_reward is not None else float(t.base_reward) if t.base_reward is not None else 0.0,
                "task_type": t.task_type,
            }
            for t in recent_tasks_source
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
        "recent_forum_posts": [
            {
                "id": p.id,
                "title": p.title,
                "title_en": p.title_en,
                "title_zh": p.title_zh,
                "content_preview": (p.content[:100] + "...") if p.content and len(p.content) > 100 else p.content,
                "images": p.images if isinstance(p.images, list) else [],
                "like_count": p.like_count or 0,
                "reply_count": p.reply_count or 0,
                "view_count": p.view_count or 0,
                "created_at": p.created_at,
            }
            for p in recent_forum_posts
        ],
        "sold_flea_items": [
            {
                "id": item.id,
                "title": item.title,
                "price": float(item.price) if item.price is not None else 0.0,
                "images": _safe_parse_images(item.images),
                "status": item.status,
                "view_count": item.view_count or 0,
                "created_at": item.created_at,
            }
            for item in sold_flea_items
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
        
        # 检查新邮箱是否为临时邮箱
        from app.email_utils import is_temp_email, notify_user_to_update_email
        if is_temp_email(new_email):
            raise HTTPException(
                status_code=400,
                detail="不能使用临时邮箱地址。请使用您的真实邮箱地址。"
            )
        
        # 根据用户语言偏好获取邮件模板
        from app.email_templates import get_user_language, get_email_update_verification_code_email
        
        language = get_user_language(current_user)
        subject, body = get_email_update_verification_code_email(language, new_email, verification_code)
        
        # 异步发送邮件（传递数据库会话和用户ID以便创建通知）
        from app.database import SessionLocal
        temp_db = SessionLocal()
        try:
            background_tasks.add_task(send_email, new_email, subject, body, temp_db, current_user.id)
        finally:
            # 注意：这里不能关闭数据库，因为后台任务可能还需要使用
            # 后台任务会在完成后自动处理数据库会话
            pass
        
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
        
        # 标准化手机号（去掉英国号码前导0等）
        new_phone = StringValidator.normalize_phone(request_data.new_phone.strip())
        
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
        # 保存旧头像 URL
        old_avatar = current_user.avatar

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
            logger.warning(f"头像更新后清除用户缓存失败 (user_id={current_user.id}): {e}")

        # 删除旧头像文件（失败不影响更新）
        if old_avatar and old_avatar != data.avatar and "/static/" not in old_avatar:
            try:
                from app.image_cleanup import delete_user_avatar
                delete_user_avatar(str(current_user.id), old_avatar)
            except Exception as e:
                logger.warning(f"删除旧头像失败 (user_id={current_user.id}): {e}")

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
    bio: Optional[str] = None


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
                
                # 更新名字和修改时间（只保存日期部分，存为当日 00:00 UTC 以匹配 DateTime(timezone=True)）
                update_data["name"] = new_name
                update_data["name_updated_at"] = datetime.combine(get_utc_time().date(), time.min, tzinfo=timezone.utc)
        
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

        # 处理 bio 更新（检测联系方式并自动替换）
        if data.bio is not None:
            from app.content_filter.contact_detector import ContactDetector
            bio_text = data.bio.strip()
            if bio_text:
                detector = ContactDetector()
                result = detector.detect(bio_text)
                if result.has_contact:
                    bio_text = result.masked_text
            update_data["bio"] = bio_text if bio_text else None

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
            
            # 标准化手机号（去掉英国号码前导0等）
            if new_phone:
                new_phone = StringValidator.normalize_phone(new_phone)
            
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
            logger.warning(f"个人资料更新后清除用户缓存失败 (user_id={current_user.id}): {e}")
        
        return {"message": "个人资料更新成功", **update_data}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"个人资料更新失败: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"个人资料更新失败: {str(e)}")


# 已迁移到 admin_user_management_routes.py: /admin/user/{user_id}/set_level, /admin/user/{user_id}/set_status
# 已迁移到 admin_task_management_routes.py: /admin/task/{task_id}/set_level


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
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0, le=100000),
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
    debug: bool = False,
    current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    unread_messages = crud.get_unread_messages(db, current_user.id)
    result = {"unread_count": len(unread_messages)}
    
    if debug:
        from app.models import Task, TaskParticipant
        
        # 调试模式：返回每条未读消息的详细信息
        debug_details = []
        for msg in unread_messages:
            debug_details.append({
                "message_id": msg.id,
                "task_id": msg.task_id,
                "sender_id": msg.sender_id,
                "content": (msg.content[:80] + '...') if msg.content and len(msg.content) > 80 else msg.content,
                "message_type": msg.message_type,
                "conversation_type": msg.conversation_type,
                "created_at": msg.created_at.isoformat() if msg.created_at else None,
            })
        
        # 按 task_id 分组统计，并查询任务详情
        task_unread_map = {}
        for msg in unread_messages:
            tid = msg.task_id
            if tid not in task_unread_map:
                task_unread_map[tid] = {"task_id": tid, "count": 0, "latest_message": None}
            task_unread_map[tid]["count"] += 1
            if task_unread_map[tid]["latest_message"] is None:
                task_unread_map[tid]["latest_message"] = {
                    "message_id": msg.id,
                    "sender_id": msg.sender_id,
                    "content": (msg.content[:50] + '...') if msg.content and len(msg.content) > 50 else msg.content,
                    "created_at": msg.created_at.isoformat() if msg.created_at else None,
                }
        
        # 查询每个有未读消息的任务的详细信息
        for tid in task_unread_map:
            task = db.query(Task).filter(Task.id == tid).first()
            if task:
                task_info = {
                    "title": task.title[:50] if task.title else None,
                    "status": task.status,
                    "poster_id": task.poster_id,
                    "taker_id": task.taker_id,
                    "is_multi_participant": getattr(task, 'is_multi_participant', False),
                    "user_is_poster": str(task.poster_id) == str(current_user.id),
                    "user_is_taker": str(task.taker_id) == str(current_user.id) if task.taker_id else False,
                }
                # 查询用户在该任务中的参与者身份
                participant = db.query(TaskParticipant).filter(
                    TaskParticipant.task_id == tid,
                    TaskParticipant.user_id == current_user.id
                ).first()
                if participant:
                    task_info["participant_status"] = participant.status
                    task_info["participant_role"] = getattr(participant, 'role', None)
                else:
                    task_info["participant_status"] = None
                    task_info["participant_role"] = None
                task_unread_map[tid]["task_info"] = task_info
            else:
                task_unread_map[tid]["task_info"] = {"error": "任务不存在(已删除?)"}
        
        result["debug"] = {
            "user_id": current_user.id,
            "total_unread": len(unread_messages),
            "by_task": list(task_unread_map.values()),
            "messages": debug_details
        }
    
    return result


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
    from sqlalchemy import func as sa_func
    
    rows = (
        db.query(Message.sender_id, sa_func.count(Message.id))
        .filter(
            Message.receiver_id == current_user.id,
            Message.is_read == 0,
            Message.sender_id.isnot(None),
        )
        .group_by(Message.sender_id)
        .all()
    )
    contact_counts = {str(sender_id): cnt for sender_id, cnt in rows}
    
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


# 已迁移到 admin_customer_service_routes.py: /admin/messages


# 通知相关API（已迁移为 async 以提升并发）
@router.get("/notifications", response_model=None)
@cache_response(ttl=30, key_prefix="notifications")
async def get_notifications_api(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
    page: int = Query(1, ge=1, description="页码"),
    page_size: int = Query(20, ge=1, le=100, description="每页数量"),
    limit: Optional[int] = Query(None, ge=1, le=100, description="兼容旧版：直接限制条数"),
):
    """
    获取系统通知列表（排除排行榜互动类型）。
    Page 1: 全部未读 + 前 page_size 条已读
    Page 2+: 继续加载已读
    兼容旧版 limit 参数。
    """
    from app.utils.notification_utils import enrich_notifications_with_task_id_async

    leaderboard_interaction_types = ["leaderboard_vote", "leaderboard_like"]

    if limit is not None:
        notifications = await async_crud.async_notification_crud.get_user_notifications(
            db, current_user.id, skip=0, limit=limit, unread_only=False
        )
        enriched = await enrich_notifications_with_task_id_async(notifications, db)
        return [n for n in enriched if n.type not in leaderboard_interaction_types]

    all_notifications = await async_crud.async_notification_crud.get_user_notifications(
        db, current_user.id, skip=0, limit=1000, unread_only=False
    )
    enriched = await enrich_notifications_with_task_id_async(all_notifications, db)
    filtered = [n for n in enriched if n.type not in leaderboard_interaction_types]

    unread = [n for n in filtered if n.is_read == 0]
    read = [n for n in filtered if n.is_read != 0]

    if page == 1:
        read_page = read[:page_size]
        result = unread + read_page
    else:
        offset = (page - 1) * page_size
        result = read[offset:offset + page_size]

    has_more = len(read) > page * page_size

    return {
        "notifications": result,
        "total": len(filtered),
        "page": page,
        "page_size": page_size,
        "has_more": has_more,
    }


@router.get("/notifications/unread", response_model=list[schemas.NotificationOut])
async def get_unread_notifications_api(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """获取未读通知，支持分页（Flutter 传 page、page_size）"""
    from app.utils.notification_utils import enrich_notifications_with_task_id_async

    notifications = await async_crud.async_notification_crud.get_user_notifications(
        db, current_user.id, skip=(page - 1) * page_size, limit=page_size, unread_only=True
    )
    return await enrich_notifications_with_task_id_async(notifications, db)


@router.get("/notifications/with-recent-read", response_model=list[schemas.NotificationOut])
async def get_notifications_with_recent_read_api(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
    recent_read_limit: int = Query(10, ge=1, le=100),
):
    """获取所有未读通知和最近N条已读通知"""
    from app.utils.notification_utils import enrich_notifications_with_task_id_async

    notifications = await async_crud.async_notification_crud.get_notifications_with_recent_read(
        db, current_user.id, recent_read_limit
    )
    return await enrich_notifications_with_task_id_async(notifications, db)


@router.get("/notifications/unread/count")
@cache_response(ttl=30, key_prefix="notifications")
async def get_unread_notification_count_api(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    system_count = await async_crud.async_notification_crud.get_unread_notification_count(
        db, current_user.id
    )
    leaderboard_interaction_types = ["leaderboard_vote", "leaderboard_like"]
    lb_unread_result = await db.execute(
        select(func.count()).select_from(models.Notification).where(
            models.Notification.user_id == current_user.id,
            models.Notification.is_read == 0,
            models.Notification.type.in_(leaderboard_interaction_types),
        )
    )
    lb_unread = lb_unread_result.scalar() or 0

    forum_unread_result = await db.execute(
        select(func.count()).select_from(models.ForumNotification).where(
            models.ForumNotification.to_user_id == current_user.id,
            models.ForumNotification.is_read == False,
        )
    )
    forum_unread = forum_unread_result.scalar() or 0

    return {
        "unread_count": system_count - lb_unread,
        "forum_count": forum_unread + lb_unread,
    }


@router.get("/notifications/interaction")
async def get_interaction_notifications_api(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """
    获取互动消息（统一接口）
    合并论坛通知 + 排行榜互动通知，按时间倒序排列，支持分页。
    Page 1: 全部未读 + 前 page_size 条已读
    Page 2+: 继续加载已读
    """
    from sqlalchemy.orm import selectinload
    from app.forum_routes import visible_forums

    # === 1. 查论坛通知 ===
    forum_query = (
        select(models.ForumNotification)
        .where(models.ForumNotification.to_user_id == current_user.id)
        .order_by(models.ForumNotification.created_at.desc())
        .options(selectinload(models.ForumNotification.from_user))
    )
    forum_result = await db.execute(forum_query)
    all_forum = forum_result.scalars().all()

    # 过滤学校板块
    visible_category_ids = []
    general_result = await db.execute(
        select(models.ForumCategory.id).where(
            models.ForumCategory.type == 'general',
            models.ForumCategory.is_visible == True
        )
    )
    visible_category_ids.extend([r[0] for r in general_result.all()])
    school_ids = await visible_forums(current_user, db)
    visible_category_ids.extend(school_ids)

    # 批量查 post/reply 的 category_id
    post_notifs = [n for n in all_forum if n.target_type == "post"]
    reply_notifs = [n for n in all_forum if n.target_type == "reply"]

    post_category_map = {}
    if post_notifs:
        res = await db.execute(
            select(models.ForumPost.id, models.ForumPost.category_id)
            .where(models.ForumPost.id.in_([n.target_id for n in post_notifs]))
        )
        post_category_map = {r[0]: r[1] for r in res.all()}

    reply_post_map = {}
    reply_category_map = {}
    if reply_notifs:
        res = await db.execute(
            select(models.ForumReply.id, models.ForumReply.post_id)
            .where(models.ForumReply.id.in_([n.target_id for n in reply_notifs]))
        )
        reply_post_map = {r[0]: r[1] for r in res.all()}
        if reply_post_map:
            res2 = await db.execute(
                select(models.ForumPost.id, models.ForumPost.category_id)
                .where(models.ForumPost.id.in_(list(reply_post_map.values())))
            )
            pid_to_cat = {r[0]: r[1] for r in res2.all()}
            reply_category_map = {
                rid: pid_to_cat.get(pid)
                for rid, pid in reply_post_map.items()
                if pid in pid_to_cat
            }

    # 转换论坛通知为统一格式
    forum_converted = []
    _type_labels = {
        "reply_post": ("回复了你的帖子", "replied to your post"),
        "reply_reply": ("回复了你的评论", "replied to your comment"),
        "like_post": ("点赞了你的帖子", "liked your post"),
        "feature_post": ("精选了你的帖子", "featured your post"),
        "pin_post": ("置顶了你的帖子", "pinned your post"),
    }

    for n in all_forum:
        if n.target_type == "post":
            cat_id = post_category_map.get(n.target_id)
        else:
            cat_id = reply_category_map.get(n.target_id)
        if not cat_id or cat_id not in visible_category_ids:
            continue

        if n.target_type == "reply":
            post_id = reply_post_map.get(n.target_id)
        else:
            post_id = n.target_id

        from_name = n.from_user.name if n.from_user else "某人"
        from_name_en = n.from_user.name if n.from_user else "Someone"
        label_zh, label_en = _type_labels.get(
            n.notification_type, ("与你互动", "interacted with you")
        )

        forum_converted.append({
            "id": n.id,
            "user_id": current_user.id,
            "type": f"forum_{n.notification_type}",
            "title": f"{from_name}{label_zh}",
            "content": f"{from_name}{label_zh}",
            "title_en": f"{from_name_en} {label_en}",
            "content_en": f"{from_name_en} {label_en}",
            "related_id": post_id,
            "related_type": "forum_post_id",
            "is_read": 1 if n.is_read else 0,
            "created_at": n.created_at,
            "task_id": None,
            "variables": None,
        })

    # === 2. 查排行榜互动通知 ===
    leaderboard_types = ["leaderboard_vote", "leaderboard_like"]
    lb_result = await db.execute(
        select(models.Notification)
        .where(
            models.Notification.user_id == current_user.id,
            models.Notification.type.in_(leaderboard_types),
        )
        .order_by(models.Notification.created_at.desc())
    )
    lb_notifications = lb_result.scalars().all()

    lb_converted = []
    for n in lb_notifications:
        lb_converted.append({
            "id": n.id,
            "user_id": n.user_id,
            "type": n.type,
            "title": n.title,
            "content": n.content,
            "title_en": n.title_en,
            "content_en": n.content_en,
            "related_id": n.related_id,
            "related_type": n.related_type,
            "is_read": n.is_read,
            "created_at": n.created_at,
            "task_id": None,
            "variables": None,
        })

    # === 3. 合并 + 未读优先分页 ===
    from datetime import datetime as dt
    all_items = forum_converted + lb_converted
    unread_items = [x for x in all_items if x["is_read"] in (False, 0)]
    read_items = [x for x in all_items if x["is_read"] not in (False, 0)]

    unread_items.sort(key=lambda x: x["created_at"] or dt.min, reverse=True)
    read_items.sort(key=lambda x: x["created_at"] or dt.min, reverse=True)

    if page == 1:
        read_page = read_items[:page_size]
        result_items = unread_items + read_page
    else:
        offset = (page - 1) * page_size
        read_page = read_items[offset:offset + page_size]
        result_items = read_page

    has_more = len(read_items) > page * page_size

    return {
        "notifications": result_items,
        "total": len(all_items),
        "page": page,
        "page_size": page_size,
        "has_more": has_more,
    }


@router.post(
    "/notifications/{notification_id}/read", response_model=schemas.NotificationOut
)
async def mark_notification_read_api(
    notification_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    from app.utils.notification_utils import enrich_notification_dict_with_task_id_async

    notification = await async_crud.async_notification_crud.mark_notification_as_read(
        db, notification_id, current_user.id
    )
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    notification_dict = schemas.NotificationOut.model_validate(notification).model_dump()
    enriched_dict = await enrich_notification_dict_with_task_id_async(
        notification, notification_dict, db
    )
    return schemas.NotificationOut(**enriched_dict)


@router.post("/users/device-token")
def register_device_token(
    request: Request,
    device_token_data: schemas.DeviceTokenRegister,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """注册或更新设备推送令牌"""
    import logging
    from sqlalchemy.exc import IntegrityError
    logger = logging.getLogger(__name__)
    
    device_token = device_token_data.device_token
    platform = device_token_data.platform
    device_id = device_token_data.device_id  # 可能为 None 或空字符串
    app_version = device_token_data.app_version  # 可能为 None 或空字符串
    device_language = device_token_data.device_language  # 设备系统语言（zh 或 en）
    
    # 验证和规范化设备语言
    # 只有中文使用中文推送，其他所有语言都使用英文推送
    if device_language:
        device_language = device_language.strip().lower()
        if device_language.startswith('zh'):
            device_language = 'zh'  # 中文
        else:
            device_language = 'en'  # 其他所有语言都使用英文
    else:
        device_language = 'en'  # 默认英文
    
    logger.debug(f"[DEVICE_TOKEN] 用户 {current_user.id} 尝试注册设备令牌: platform={platform}, app_version={app_version}, device_id={device_id or '未提供'}, device_language={device_language}")
    
    if not device_token:
        raise HTTPException(status_code=400, detail="device_token is required")
    
    # 查找是否已存在该设备令牌（当前用户的）
    existing_token = db.query(models.DeviceToken).filter(
        models.DeviceToken.user_id == current_user.id,
        models.DeviceToken.device_token == device_token
    ).first()
    
    # ---- 节流：如果令牌已存在且信息无变化，10 分钟内跳过写库 ----
    from datetime import timedelta
    THROTTLE_MINUTES = 10
    if existing_token and existing_token.is_active:
        now = get_utc_time()
        recently_updated = (
            existing_token.last_used_at
            and (now - existing_token.last_used_at) < timedelta(minutes=THROTTLE_MINUTES)
        )
        info_unchanged = (
            existing_token.platform == platform
            and existing_token.device_language == device_language
            and (not (device_id and device_id.strip()) or existing_token.device_id == device_id)
            and (not (app_version and app_version.strip()) or existing_token.app_version == app_version)
        )
        if recently_updated and info_unchanged:
            logger.debug(f"[DEVICE_TOKEN] 用户 {current_user.id} 的设备令牌无变化且在 {THROTTLE_MINUTES} 分钟内已更新，跳过写库: token_id={existing_token.id}")
            return {"message": "Device token up-to-date", "token_id": existing_token.id}
    
    # 在注册/更新令牌前，禁用同一 device_id 的所有其他旧令牌（包括其他用户的）
    if device_id and device_id.strip():
        deactivated_own = db.query(models.DeviceToken).filter(
            models.DeviceToken.user_id == current_user.id,
            models.DeviceToken.device_id == device_id,
            models.DeviceToken.device_token != device_token,
            models.DeviceToken.is_active == True
        ).update({"is_active": False, "updated_at": get_utc_time()})
        if deactivated_own > 0:
            logger.info(f"[DEVICE_TOKEN] 已禁用同一 device_id 的 {deactivated_own} 个当前用户旧令牌: user_id={current_user.id}, device_id={device_id}")
        
        deactivated_others = db.query(models.DeviceToken).filter(
            models.DeviceToken.user_id != current_user.id,
            models.DeviceToken.device_id == device_id,
            models.DeviceToken.is_active == True
        ).update({"is_active": False, "updated_at": get_utc_time()})
        if deactivated_others > 0:
            logger.info(f"[DEVICE_TOKEN] 已禁用同一 device_id 上其他用户的 {deactivated_others} 个令牌（账号切换）: device_id={device_id}")
    
    deactivated_same_token = db.query(models.DeviceToken).filter(
        models.DeviceToken.user_id != current_user.id,
        models.DeviceToken.device_token == device_token,
        models.DeviceToken.is_active == True
    ).update({"is_active": False, "updated_at": get_utc_time()})
    if deactivated_same_token > 0:
        logger.info(f"[DEVICE_TOKEN] 已禁用其他用户持有的相同 device_token 的 {deactivated_same_token} 个记录")
    
    if existing_token:
        existing_token.is_active = True
        existing_token.platform = platform
        existing_token.device_language = device_language
        
        if device_id and device_id.strip():
            old_device_id = existing_token.device_id
            existing_token.device_id = device_id
            if old_device_id != device_id:
                logger.debug(f"[DEVICE_TOKEN] device_id 已更新: {old_device_id or '未设置'} -> {device_id}")
        
        if app_version and app_version.strip():
            existing_token.app_version = app_version
        
        existing_token.updated_at = get_utc_time()
        existing_token.last_used_at = get_utc_time()
        db.commit()
        logger.info(f"[DEVICE_TOKEN] 用户 {current_user.id} 的设备令牌已更新: token_id={existing_token.id}, device_id={existing_token.device_id or '未设置'}, device_language={existing_token.device_language}")
        return {"message": "Device token updated", "token_id": existing_token.id}
    else:
        # 创建新令牌
        # 使用 try-except 处理并发插入时的唯一约束冲突
        try:
            new_token = models.DeviceToken(
                user_id=current_user.id,
                device_token=device_token,
                platform=platform,
                device_id=device_id,
                app_version=app_version,
                device_language=device_language,  # 设置设备语言
                is_active=True,
                last_used_at=get_utc_time()
            )
            db.add(new_token)
            db.commit()
            db.refresh(new_token)
            logger.info(f"[DEVICE_TOKEN] 用户 {current_user.id} 的设备令牌已注册: token_id={new_token.id}, device_token={device_token[:20]}..., device_id={new_token.device_id or '未设置'}")
            return {"message": "Device token registered", "token_id": new_token.id}
        except IntegrityError as e:
            # 处理并发插入时的唯一约束冲突
            # 回滚当前事务
            db.rollback()
            
            # 重新查询已存在的令牌（可能由另一个并发请求插入）
            existing_token = db.query(models.DeviceToken).filter(
                models.DeviceToken.user_id == current_user.id,
                models.DeviceToken.device_token == device_token
            ).first()
            
            if existing_token:
                # 禁用同一 device_id 的其他旧令牌（并发处理时也需要）
                if device_id and device_id.strip():
                    deactivated_count = db.query(models.DeviceToken).filter(
                        models.DeviceToken.user_id == current_user.id,
                        models.DeviceToken.device_id == device_id,
                        models.DeviceToken.device_token != device_token,
                        models.DeviceToken.is_active == True
                    ).update({"is_active": False, "updated_at": get_utc_time()})
                    if deactivated_count > 0:
                        logger.info(f"[DEVICE_TOKEN] 已禁用同一 device_id 的 {deactivated_count} 个旧令牌（并发处理）: user_id={current_user.id}, device_id={device_id}")
                
                # 更新现有令牌
                existing_token.is_active = True
                existing_token.platform = platform
                existing_token.device_language = device_language
                
                # 更新 device_id
                if device_id and device_id.strip():
                    existing_token.device_id = device_id
                
                # 更新 app_version
                if app_version and app_version.strip():
                    existing_token.app_version = app_version
                
                existing_token.updated_at = get_utc_time()
                existing_token.last_used_at = get_utc_time()
                db.commit()
                logger.info(f"[DEVICE_TOKEN] 用户 {current_user.id} 的设备令牌已更新（处理并发冲突）: token_id={existing_token.id}, device_id={existing_token.device_id or '未设置'}, device_language={existing_token.device_language}")
                return {"message": "Device token updated", "token_id": existing_token.id}
            else:
                # 如果仍然找不到，记录错误并重新抛出异常
                logger.error(f"[DEVICE_TOKEN] 唯一约束冲突但未找到现有令牌: user_id={current_user.id}, device_token={device_token[:20]}...")
                raise HTTPException(status_code=500, detail="Failed to register device token due to concurrent conflict")


@router.delete("/users/device-token")
def unregister_device_token(
    device_token_data: schemas.DeviceTokenUnregister,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """注销设备推送令牌 - 标记为不活跃而非删除
    
    登出或切换账号时调用此接口，将设备令牌标记为不活跃，
    而不是完全删除，这样可以：
    1. 保留历史记录用于调试
    2. 重新登录时可以快速重新激活
    3. 避免删除后重新注册时的竞态条件
    """
    logger = logging.getLogger(__name__)
    device_token = device_token_data.device_token
    
    # 查找令牌并标记为不活跃（而不是删除）
    updated = db.query(models.DeviceToken).filter(
        models.DeviceToken.user_id == current_user.id,
        models.DeviceToken.device_token == device_token
    ).update({"is_active": False, "updated_at": get_utc_time()})
    
    db.commit()
    
    if updated > 0:
        logger.info(f"[DEVICE_TOKEN] 用户 {current_user.id} 的设备令牌已标记为不活跃（登出）: token={device_token[:20]}...")
        return {"message": "Device token deactivated"}
    else:
        # 令牌不存在时也返回成功（幂等操作，避免客户端重试问题）
        logger.info(f"[DEVICE_TOKEN] 用户 {current_user.id} 的设备令牌未找到或已不活跃: token={device_token[:20]}...")
        return {"message": "Device token not found or already deactivated"}


@router.delete("/users/account")
def delete_user_account(
    request: Request,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """删除用户账户及其所有相关数据"""
    import logging
    logger = logging.getLogger(__name__)
    
    user_id = current_user.id
    
    try:
        # 检查用户是否有进行中的任务
        from app.models import Task
        active_tasks = db.query(Task).filter(
            (Task.poster_id == user_id) | (Task.taker_id == user_id),
            Task.status.in_(['open', 'assigned', 'in_progress', 'pending_payment'])
        ).count()
        
        if active_tasks > 0:
            raise HTTPException(
                status_code=400,
                detail="无法删除账户：您有进行中的任务。请先完成或取消所有任务后再删除账户。"
            )
        
        # 删除用户相关的所有数据
        # 1. 删除设备令牌
        from app.models import DeviceToken
        db.query(DeviceToken).filter(DeviceToken.user_id == user_id).delete()
        
        # 2. 删除通知
        from app.models import Notification
        db.query(Notification).filter(
            (Notification.user_id == user_id) | (Notification.related_id == user_id)
        ).delete()
        
        # 3. 删除消息（保留消息历史，但移除用户关联）
        from app.models import Message
        # 将消息的发送者ID设为NULL（如果数据库允许）
        # 或者删除用户相关的消息
        db.query(Message).filter(
            (Message.sender_id == user_id) | (Message.receiver_id == user_id)
        ).delete()
        
        # 4. 删除任务申请（申请者字段为 applicant_id）
        from app.models import TaskApplication
        db.query(TaskApplication).filter(TaskApplication.applicant_id == user_id).delete()
        
        # 5. 删除评价（保留评价，但移除用户关联）
        from app.models import Review
        db.query(Review).filter(
            (Review.reviewer_id == user_id) | (Review.reviewee_id == user_id)
        ).delete()
        
        # 6. 删除收藏（如果存在Favorite模型）
        try:
            from app.models import Favorite
            db.query(Favorite).filter(Favorite.user_id == user_id).delete()
        except Exception:
            pass  # 如果模型不存在，跳过
        
        # 7. 删除用户偏好设置
        from app.models import UserProfilePreference
        db.query(UserProfilePreference).filter(UserProfilePreference.user_id == user_id).delete()
        
        # 8. 删除Stripe Connect账户关联（不删除Stripe账户本身）
        user = db.query(models.User).filter(models.User.id == user_id).first()
        if user:
            user.stripe_account_id = None
        
        # 9. 删除用户会话（通过secure_auth系统）
        from app.secure_auth import SecureAuthManager
        try:
            SecureAuthManager().revoke_all_user_sessions(user_id)
        except Exception as e:
            logger.warning(f"删除用户会话时出错: {e}")
        
        # 10. 最后删除用户本身
        db.delete(user)
        db.commit()
        
        logger.info(f"用户账户已删除: {user_id}")
        
        # 清除响应中的认证信息
        response = JSONResponse(content={"message": "账户已成功删除"})
        response.delete_cookie("session_id", path="/")
        response.delete_cookie("csrf_token", path="/")
        
        return response
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"删除用户账户失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"删除账户时发生错误: {str(e)}"
        )


@router.post("/notifications/read-all")
async def mark_all_notifications_read_api(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
    type: Optional[str] = Query(None, description="system, interaction, or all (default: all)"),
):
    """
    标记通知为已读。
    type=system: 只标记系统通知（排除 leaderboard_vote/like）
    type=interaction: 标记论坛通知 + 排行榜互动通知
    type=all 或 None: 标记全部
    """
    effective_type = type or "all"
    leaderboard_interaction_types = ["leaderboard_vote", "leaderboard_like"]

    if effective_type in ("system", "all"):
        if effective_type == "system":
            await db.execute(
                update(models.Notification)
                .where(
                    models.Notification.user_id == current_user.id,
                    models.Notification.is_read == 0,
                    models.Notification.type.notin_(leaderboard_interaction_types),
                )
                .values(is_read=1)
            )
        else:
            await async_crud.async_notification_crud.mark_all_notifications_read(
                db, current_user.id
            )

    if effective_type in ("interaction", "all"):
        await db.execute(
            update(models.ForumNotification)
            .where(
                models.ForumNotification.to_user_id == current_user.id,
                models.ForumNotification.is_read == False,
            )
            .values(is_read=True)
        )
        if effective_type == "interaction":
            await db.execute(
                update(models.Notification)
                .where(
                    models.Notification.user_id == current_user.id,
                    models.Notification.is_read == 0,
                    models.Notification.type.in_(leaderboard_interaction_types),
                )
                .values(is_read=1)
            )

    await db.commit()
    return {"message": "Notifications marked as read"}


@router.post("/notifications/send-announcement")
def send_announcement_api(
    announcement: schemas.AnnouncementCreate,
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """发送平台公告给所有用户"""
    from app.models import User

    # 获取所有用户（分批处理，防止内存溢出）
    # 使用 yield_per 分批加载，每批最多 1000 个用户
    users_query = db.query(User)
    total_users = users_query.count()
    
    # 如果用户数量过多，分批处理
    batch_size = 1000
    if total_users > batch_size:
        logger.warning(f"用户数量过多 ({total_users})，将分批处理，每批 {batch_size} 个")
    
    # 分批处理用户
    offset = 0
    processed_count = 0
    while offset < total_users:
        users = users_query.offset(offset).limit(batch_size).all()
        if not users:
            break
            
        # 为每个用户创建公告通知
        for user in users:
            try:
                crud.create_notification(
                    db,
                    user.id,
                    "announcement",
                    announcement.title,
                    announcement.content,
                    None,
                )
                processed_count += 1
            except Exception as e:
                logger.error(f"创建通知失败，用户ID: {user.id}, 错误: {e}")
        
        # 更新偏移量
        offset += batch_size
        # 每批处理后提交一次，避免事务过大
        db.commit()
    
    return {"message": f"Announcement sent to {processed_count} users"}


@router.post("/tasks/{task_id}/pay")
def create_payment(
    task_id: int, current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    task = crud.get_task(db, task_id)
    if not task or task.poster_id != current_user.id:
        raise HTTPException(status_code=404, detail="Task not found or no permission.")
    if task.is_paid:
        return {"message": "Task already paid."}
    # 计算任务金额和平台服务费（用于 metadata 交叉校验）
    from app.utils.fee_calculator import calculate_application_fee_pence
    task_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0
    task_amount_pence = round(task_amount * 100)
    task_source = getattr(task, "task_source", None)
    task_type = getattr(task, "task_type", None)
    application_fee_pence = calculate_application_fee_pence(task_amount_pence, task_source, task_type)
    # 创建Stripe支付会话
    session = stripe.checkout.Session.create(
        payment_method_types=_payment_method_types_for_currency((task.currency or "GBP").lower()),
        line_items=[
            {
                "price_data": {
                    "currency": (task.currency or "GBP").lower(),
                    "product_data": {"name": task.title},
                    "unit_amount": task_amount_pence,
                },
                "quantity": 1,
            }
        ],
        mode="payment",
        success_url=f"{Config.BASE_URL}/api/users/tasks/{task_id}/pay/success",
        cancel_url=f"{Config.BASE_URL}/api/users/tasks/{task_id}/pay/cancel",
        metadata={
            "task_id": task_id,
            "application_fee": application_fee_pence,
            "task_source": task_source or "",
            "task_type": task_type or "",
        },
    )
    return {"checkout_url": session.url}


@router.post("/stripe/webhook")
async def stripe_webhook(request: Request, db: Session = Depends(get_db)):
    import logging
    import json
    logger = logging.getLogger(__name__)
    
    # 记录请求开始时间
    import time
    start_time = time.time()
    
    # 确保 crud 模块已导入（避免 UnboundLocalError）
    from app import crud
    # 确保 SQLAlchemy 函数已导入（避免 UnboundLocalError）
    from sqlalchemy import and_, func, select
    
    # 获取请求信息
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")
    endpoint_secret = os.getenv("STRIPE_WEBHOOK_SECRET")
    content_type = request.headers.get("content-type", "unknown")
    user_agent = request.headers.get("user-agent", "unknown")
    client_ip = request.client.host if request.client else "unknown"
    
    # 记录webhook接收（关键信息保留INFO，详细信息降级为DEBUG）
    logger.info("=" * 80)
    logger.info(f"🔔 [WEBHOOK] 收到 Stripe Webhook 请求")
    logger.debug(f"  - 时间: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime())}")
    logger.debug(f"  - 客户端IP: {client_ip}")
    logger.debug(f"  - User-Agent: {user_agent}")
    logger.debug(f"  - Content-Type: {content_type}")
    logger.debug(f"  - Payload 大小: {len(payload)} bytes")
    logger.debug(f"  - Signature 前缀: {sig_header[:30] if sig_header else 'None'}...")
    logger.debug(f"  - Secret 配置: {'✅ 已配置' if endpoint_secret else '❌ 未配置'}")
    
    # 严格验证 Webhook 签名（安全要求）
    # 只有通过 Stripe 签名验证的请求才能处理
    if not endpoint_secret:
        logger.error(f"❌ [WEBHOOK] 安全错误：STRIPE_WEBHOOK_SECRET 未配置")
        return JSONResponse(status_code=500, content={"error": "Webhook secret not configured"})
    
    if not sig_header:
        logger.error(f"❌ [WEBHOOK] 安全错误：缺少 Stripe 签名头")
        return JSONResponse(status_code=400, content={"error": "Missing stripe-signature header"})
    
    try:
        # 严格验证 Webhook 签名
        event = stripe.Webhook.construct_event(payload, sig_header, endpoint_secret)
        logger.debug(f"✅ [WEBHOOK] 事件验证成功（签名已验证）")
    except ValueError as e:
        logger.error(f"❌ [WEBHOOK] Invalid payload: {e}")
        logger.error(f"  - Payload 内容 (前500字符): {payload[:500].decode('utf-8', errors='ignore')}")
        return JSONResponse(status_code=400, content={"error": "Invalid payload"})
    except stripe.error.SignatureVerificationError as e:
        logger.error(f"❌ [WEBHOOK] 安全错误：签名验证失败: {e}")
        logger.error(f"  - 提供的 Signature: {sig_header[:50]}...")
        logger.error(f"  - 使用的 Secret: ***{endpoint_secret[-4:]}")
        logger.error(f"  - 这可能是恶意请求或配置错误，已拒绝处理")
        return JSONResponse(status_code=400, content={"error": "Invalid signature"})
    except Exception as e:
        logger.error(f"❌ [WEBHOOK] 处理错误: {type(e).__name__}: {e}")
        import traceback
        logger.error(f"  - 错误堆栈: {traceback.format_exc()}")
        return JSONResponse(status_code=400, content={"error": str(e)})
    
    event_type = event["type"]
    event_id = event.get("id")
    event_data = event["data"]["object"]
    livemode = event.get("livemode", False)
    created = event.get("created")
    
    # 记录事件关键信息（详细信息降级为DEBUG）
    logger.info(f"📦 [WEBHOOK] 事件: {event_type} (ID: {event_id})")
    logger.debug(f"  - Livemode: {livemode}")
    logger.debug(f"  - 创建时间: {created} ({time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(created)) if created else 'N/A'})")
    
    # Idempotency 检查：防止重复处理同一个 webhook 事件
    import json
    from app.utils.time_utils import get_utc_time
    
    if event_id:
        existing_event = db.query(models.WebhookEvent).filter(
            models.WebhookEvent.event_id == event_id
        ).first()
        
        if existing_event:
            if existing_event.processed:
                logger.warning(f"⚠️ [WEBHOOK] 事件已处理过，跳过: event_id={event_id}, processed_at={existing_event.processed_at}")
                return {"status": "already_processed", "event_id": event_id}
            else:
                logger.info(f"🔄 [WEBHOOK] 事件之前处理失败，重新处理: event_id={event_id}, error={existing_event.processing_error}")
        else:
            # 创建新的事件记录
            webhook_event = models.WebhookEvent(
                event_id=event_id,
                event_type=event_type,
                livemode=livemode,
                processed=False,
                event_data=json.loads(json.dumps(event))  # 保存完整事件数据
            )
            db.add(webhook_event)
            try:
                db.commit()
                logger.debug(f"✅ [WEBHOOK] 已创建事件记录: event_id={event_id}")
            except Exception as e:
                db.rollback()
                logger.error(f"❌ [WEBHOOK] 创建事件记录失败: {e}")
                # 如果是因为重复事件ID导致的错误，可能是并发请求，检查是否已存在
                existing_event = db.query(models.WebhookEvent).filter(
                    models.WebhookEvent.event_id == event_id
                ).first()
                if existing_event and existing_event.processed:
                    logger.warning(f"⚠️ [WEBHOOK] 并发请求，事件已处理: event_id={event_id}")
                    return {"status": "already_processed", "event_id": event_id}
                raise
    else:
        logger.error(f"❌ [WEBHOOK] 事件缺少 event_id，拒绝处理以保证幂等性: event_type={event_type}")
        return JSONResponse(status_code=400, content={"error": "Missing event_id, cannot guarantee idempotency"})
    
    # 标记事件开始处理
    processing_started = False
    try:
        if event_id:
            webhook_event = db.query(models.WebhookEvent).filter(
                models.WebhookEvent.event_id == event_id
            ).first()
            if webhook_event:
                webhook_event.processed = False  # 重置处理状态
                webhook_event.processing_error = None
                db.commit()
                processing_started = True
    except Exception as e:
        logger.error(f"❌ [WEBHOOK] 更新事件处理状态失败: {e}")
        db.rollback()
    
    # 如果是 payment_intent 相关事件，记录关键信息（详细信息降级为DEBUG）
    if "payment_intent" in event_type:
        payment_intent_id = event_data.get("id")
        payment_status = event_data.get("status")
        amount = event_data.get("amount")
        currency = event_data.get("currency", "unknown")
        metadata = event_data.get("metadata", {})
        logger.info(f"💳 [WEBHOOK] Payment Intent: {payment_intent_id}, 状态: {payment_status}, 金额: {amount / 100 if amount else 0:.2f} {currency.upper()}")
        logger.debug(f"  - Metadata: {json.dumps(metadata, ensure_ascii=False)}")
        logger.debug(f"  - Task ID: {metadata.get('task_id', 'N/A')}, Application ID: {metadata.get('application_id', 'N/A')}, Pending Approval: {metadata.get('pending_approval', 'N/A')}")
    
    # 处理 Payment Intent 事件（用于 Stripe Elements）
    if event_type == "payment_intent.succeeded":
        payment_intent = event_data
        payment_intent_id = payment_intent.get("id")
        task_id = int(payment_intent.get("metadata", {}).get("task_id", 0))
        
        logger.info(f"Payment intent succeeded: {payment_intent_id}, task_id: {task_id}, amount: {payment_intent.get('amount')}")
        
        if task_id:
            # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定任务，防止并发webhook更新
            locked_task_query = select(models.Task).where(
                models.Task.id == task_id
            ).with_for_update()
            task = db.execute(locked_task_query).scalar_one_or_none()
            if task and not task.is_paid:  # 幂等性检查
                task.is_paid = 1
                task.payment_intent_id = payment_intent_id  # 保存 Payment Intent ID 用于关联
                # 获取任务金额（使用最终成交价或原始标价）
                task_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0
                
                # 🔒 安全修复：始终使用后端计算的服务费，不信任metadata中的金额
                # metadata仅作为交叉校验参考；按任务来源/类型取费率
                from app.utils.fee_calculator import calculate_application_fee_pence
                task_amount_pence = round(task_amount * 100)
                task_source = getattr(task, "task_source", None)
                task_type = getattr(task, "task_type", None)
                application_fee_pence = calculate_application_fee_pence(task_amount_pence, task_source, task_type)

                # 交叉校验metadata中的费用（仅记录差异，不使用metadata值）
                metadata = payment_intent.get("metadata", {})
                metadata_fee = int(metadata.get("application_fee", 0))
                if metadata_fee > 0 and metadata_fee != application_fee_pence:
                    logger.warning(f"⚠️ 服务费不一致: metadata={metadata_fee}, calculated={application_fee_pence}, task_id={task_id}")
                
                # escrow_amount = 任务金额 - 平台服务费（任务接受人获得的金额）
                application_fee = application_fee_pence / 100.0
                taker_amount = task_amount - application_fee
                task.escrow_amount = max(0.0, taker_amount)  # 确保不为负数

                # ==================== 钱包混合支付：确认钱包扣款 ====================
                metadata = payment_intent.get("metadata", {})
                _wallet_tx_id = metadata.get("wallet_tx_id")
                if _wallet_tx_id:
                    try:
                        from app.wallet_service import complete_debit
                        complete_debit(db, int(_wallet_tx_id))
                        logger.info(f"✅ [WEBHOOK] 钱包扣款已确认: wallet_tx_id={_wallet_tx_id}, task_id={task_id}")
                    except Exception as wallet_err:
                        logger.error(f"❌ [WEBHOOK] 确认钱包扣款失败: wallet_tx_id={_wallet_tx_id}, error={wallet_err}")
                        # 钱包确认失败不阻塞主流程（交易已经 pending，可后续修复）

                # 检查是否是待确认的批准（pending_approval）
                is_pending_approval = metadata.get("pending_approval") == "true"
                
                # ⚠️ 优化：如果是跳蚤市场购买，支付成功后更新商品状态为 sold
                payment_type = metadata.get("payment_type")
                if payment_type == "flea_market_direct_purchase" or payment_type == "flea_market_purchase_request":
                    flea_market_item_id = metadata.get("flea_market_item_id")
                    if flea_market_item_id:
                        try:
                            from app.models import FleaMarketItem
                            from app.id_generator import parse_flea_market_id
                            db_item_id = parse_flea_market_id(flea_market_item_id)
                            
                            # 更新商品状态为 sold（支付成功后）
                            # ⚠️ 优化：支持 active 或 reserved 状态（reserved 是已关联任务但未支付的状态）
                            # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定商品记录，防止并发支付重复标记 sold
                            flea_item = db.query(FleaMarketItem).filter(
                                and_(
                                    FleaMarketItem.id == db_item_id,
                                    FleaMarketItem.sold_task_id == task_id,
                                    FleaMarketItem.status.in_(["active", "reserved"])
                                )
                            ).with_for_update().first()

                            if flea_item:
                                flea_item.status = "sold"
                                # 确保 sold_task_id 已设置（双重保险）
                                if flea_item.sold_task_id != task_id:
                                    flea_item.sold_task_id = task_id
                                db.flush()
                                logger.info(f"✅ [WEBHOOK] 跳蚤市场商品 {flea_market_item_id} 支付成功，状态已更新为 sold (task_id: {task_id})")
                                
                                # 清除商品缓存（invalidate_item_cache 会自动清除列表缓存和详情缓存）
                                from app.flea_market_extensions import invalidate_item_cache
                                invalidate_item_cache(flea_item.id)
                                logger.info(f"✅ [WEBHOOK] 已清除跳蚤市场商品缓存（包括列表和详情）")
                                
                                # ✅ 支付成功后，发送"商品已售出"通知给卖家
                                # 注意：下单时仅发送"商品已被下单"通知，此处才是真正的"已售出"
                                try:
                                    buyer_name = metadata.get("poster_name", "买家")
                                    item_title = flea_item.title or metadata.get("task_title", "商品")
                                    
                                    crud.create_notification(
                                        db=db,
                                        user_id=flea_item.seller_id,
                                        type="flea_market_sold",
                                        title="商品已售出",
                                        content=f"「{item_title}」已售出！买家已完成付款，可以开始交易了",
                                        related_id=str(task_id),
                                        auto_commit=False,
                                    )
                                    
                                    # 发送推送通知给卖家
                                    try:
                                        from app.id_generator import format_flea_market_id
                                        send_push_notification(
                                            db=db,
                                            user_id=flea_item.seller_id,
                                            title=None,  # 从模板生成（根据用户语言偏好）
                                            body=None,   # 从模板生成
                                            notification_type="flea_market_sold",
                                            data={
                                                "item_id": format_flea_market_id(flea_item.id),
                                                "task_id": task_id
                                            },
                                            template_vars={
                                                "item_title": item_title
                                            }
                                        )
                                    except Exception as push_err:
                                        logger.warning(f"⚠️ [WEBHOOK] 发送商品售出推送通知失败: {push_err}")
                                    
                                    # 同时通知买家：支付成功
                                    buyer_id = metadata.get("poster_id")
                                    if buyer_id:
                                        crud.create_notification(
                                            db=db,
                                            user_id=buyer_id,
                                            type="flea_market_payment_success",
                                            title="支付成功",
                                            content=f"您已成功购买「{item_title}」，可以联系卖家进行交易",
                                            related_id=str(task_id),
                                            auto_commit=False,
                                        )
                                    
                                    logger.info(f"✅ [WEBHOOK] 跳蚤市场商品售出通知已创建 (seller_id: {flea_item.seller_id}, task_id: {task_id})")
                                except Exception as notify_err:
                                    logger.warning(f"⚠️ [WEBHOOK] 创建商品售出通知失败: {notify_err}")
                            else:
                                logger.warning(f"⚠️ [WEBHOOK] 跳蚤市场商品 {flea_market_item_id} 未找到或状态不匹配 (db_id: {db_item_id}, task_id: {task_id})")
                        except Exception as e:
                            logger.error(f"❌ [WEBHOOK] 更新跳蚤市场商品状态失败: {e}", exc_info=True)

                # ⚠️ 跳蚤市场租赁：支付成功后创建 FleaMarketRental 记录
                if payment_type == "flea_market_rental":
                    rental_request_id = metadata.get("rental_request_id")
                    flea_market_item_id_str = metadata.get("flea_market_item_id")
                    if rental_request_id and flea_market_item_id_str:
                        try:
                            from app.models import FleaMarketRentalRequest, FleaMarketRental, FleaMarketItem
                            from datetime import timedelta as _td
                            from app.utils.time_utils import get_utc_time as _get_utc

                            rr = db.query(FleaMarketRentalRequest).filter(
                                FleaMarketRentalRequest.id == int(rental_request_id)
                            ).with_for_update().first()

                            if rr and rr.status == "approved":
                                flea_item = db.query(FleaMarketItem).filter(
                                    FleaMarketItem.id == int(flea_market_item_id_str)
                                ).first()

                                now = _get_utc()
                                unit = flea_item.rental_unit if flea_item else "day"
                                duration = rr.rental_duration
                                if unit == "week":
                                    end_date = now + _td(days=7 * duration)
                                elif unit == "month":
                                    end_date = now + _td(days=30 * duration)
                                else:
                                    end_date = now + _td(days=duration)

                                deposit_pence = int(metadata.get("deposit_amount", "0"))
                                rent_pence = int(metadata.get("rent_amount", "0"))
                                total_pence = deposit_pence + rent_pence

                                new_rental = FleaMarketRental(
                                    item_id=rr.item_id,
                                    renter_id=rr.renter_id,
                                    request_id=rr.id,
                                    rental_duration=duration,
                                    rental_unit=unit,
                                    total_rent=rent_pence / 100.0,
                                    deposit_amount=deposit_pence / 100.0,
                                    total_paid=total_pence / 100.0,
                                    currency=flea_item.currency if flea_item else "GBP",
                                    start_date=now,
                                    end_date=end_date,
                                    status="active",
                                    deposit_status="held",
                                    task_id=task_id,
                                )
                                db.add(new_rental)
                                # 更新租赁申请状态为已完成
                                rr.status = "completed"
                                db.flush()

                                logger.info(f"✅ [WEBHOOK] 跳蚤市场租赁记录已创建: rental_id={new_rental.id}, request_id={rental_request_id}")

                                # 通知物主和租客
                                try:
                                    item_title = flea_item.title if flea_item else "商品"
                                    renter_id = rr.renter_id
                                    seller_id = flea_item.seller_id if flea_item else None

                                    if seller_id:
                                        crud.create_notification(
                                            db=db,
                                            user_id=seller_id,
                                            type="flea_market_rental_payment_success",
                                            title="租赁支付成功",
                                            content=f"「{item_title}」的租赁支付已完成，租赁已生效。",
                                            related_id=str(new_rental.id),
                                            auto_commit=False,
                                        )

                                    crud.create_notification(
                                        db=db,
                                        user_id=renter_id,
                                        type="flea_market_rental_payment_success",
                                        title="租赁支付成功",
                                        content=f"您已成功租赁「{item_title}」，租赁已生效。",
                                        related_id=str(new_rental.id),
                                        auto_commit=False,
                                    )
                                except Exception as notify_err:
                                    logger.warning(f"⚠️ [WEBHOOK] 创建租赁通知失败: {notify_err}")
                            else:
                                logger.warning(f"⚠️ [WEBHOOK] 租赁申请 {rental_request_id} 不存在或状态不匹配")
                        except Exception as e:
                            logger.error(f"❌ [WEBHOOK] 创建跳蚤市场租赁记录失败: {e}", exc_info=True)

                application_id_str = metadata.get("application_id")
                
                logger.debug(f"🔍 Webhook检查: is_pending_approval={is_pending_approval}, application_id={application_id_str}")
                
                if is_pending_approval and application_id_str:
                    # 这是批准申请时的支付，需要确认批准
                    application_id = int(application_id_str)
                    logger.debug(f"🔍 查找申请: application_id={application_id}, task_id={task_id}")
                    
                    # 🔒 安全修复：使用 SELECT FOR UPDATE 防止并发 webhook 重复批准申请
                    # 支持 pending 和 chatting 状态的申请（chatting 来自聊天后支付流程）
                    application = db.execute(
                        select(models.TaskApplication).where(
                            and_(
                                models.TaskApplication.id == application_id,
                                models.TaskApplication.task_id == task_id,
                                models.TaskApplication.status.in_(["pending", "chatting"])
                            )
                        ).with_for_update()
                    ).scalar_one_or_none()
                    
                    logger.debug(f"🔍 找到申请: {application is not None}")
                    
                    if application:
                        logger.info(f"✅ [WEBHOOK] 开始批准申请 {application_id}, applicant_id={application.applicant_id}")
                        # 批准申请
                        application.status = "approved"
                        task.taker_id = application.applicant_id
                        # ⚠️ 新流程：支付成功后，任务状态直接设置为 in_progress（不再使用 pending_payment）
                        task.status = "in_progress"
                        logger.info(f"✅ [WEBHOOK] 申请已批准，任务状态设置为 in_progress, taker_id={task.taker_id}")
                        
                        # 如果申请包含议价，更新 agreed_reward
                        if application.negotiated_price is not None:
                            task.agreed_reward = application.negotiated_price
                            logger.info(f"✅ [WEBHOOK] 更新任务成交价: {application.negotiated_price}")
                        
                        # 自动拒绝所有其他待处理/聊天中的申请
                        other_applications = db.execute(
                            select(models.TaskApplication).where(
                                and_(
                                    models.TaskApplication.task_id == task_id,
                                    models.TaskApplication.id != application_id,
                                    models.TaskApplication.status.in_(["chatting", "pending"])
                                )
                            )
                        ).scalars().all()

                        for other_app in other_applications:
                            was_chatting = other_app.status == "chatting"
                            other_app.status = "rejected"
                            logger.info(f"✅ [WEBHOOK] 自动拒绝其他申请: application_id={other_app.id}, was_chatting={was_chatting}")
                            # 如果申请者之前在聊天中，发送系统消息通知
                            if was_chatting:
                                content_zh = "发布者已选择了其他申请者完成此任务。"
                                content_en = "The poster has selected another applicant for this task."
                                reject_msg = models.Message(
                                    task_id=task_id,
                                    application_id=other_app.id,
                                    sender_id=None,
                                    content=content_zh,
                                    message_type="system",
                                    conversation_type="task",
                                    meta=json.dumps({"system_action": "application_rejected", "content_en": content_en}),
                                    created_at=get_utc_time(),
                                )
                                db.add(reject_msg)
                        
                        # 写入操作日志
                        from app.utils.time_utils import get_utc_time
                        log_entry = models.NegotiationResponseLog(
                            task_id=task_id,
                            application_id=application_id,
                            user_id=task.poster_id,
                            action="accept",
                            negotiated_price=application.negotiated_price,
                            responded_at=get_utc_time()
                        )
                        db.add(log_entry)
                        logger.debug(f"✅ [WEBHOOK] 已添加操作日志")
                        
                        # 发送通知给申请者（支付成功后，任务已进入 in_progress 状态）
                        try:
                            from app import crud
                            from app.task_notifications import send_task_approval_notification
                            
                            # 获取申请者信息
                            applicant = db.query(models.User).filter(models.User.id == application.applicant_id).first()
                            if applicant:
                                # 使用 send_task_approval_notification 发送通知
                                # 注意：此时任务状态已经是 in_progress，所以不会显示支付提醒（这是正确的）
                                # background_tasks 可以为 None，因为通知会立即发送
                                send_task_approval_notification(
                                    db=db,
                                    background_tasks=None,  # webhook 中不需要后台任务
                                    task=task,
                                    applicant=applicant
                                )
                                logger.debug(f"✅ [WEBHOOK] 已发送接受申请通知给申请者 {application.applicant_id}")
                            else:
                                # 如果无法获取申请者信息，使用简单通知
                                crud.create_notification(
                                    db,
                                    application.applicant_id,
                                    "application_accepted",
                                    "您的申请已被接受",
                                    f"您的任务申请已被接受：{task.title}",
                                    task.id,
                                    auto_commit=False,
                                )
                                logger.debug(f"✅ [WEBHOOK] 已发送简单接受申请通知给申请者 {application.applicant_id}")
                        except Exception as e:
                            logger.error(f"❌ [WEBHOOK] 发送接受申请通知失败: {e}")
                        
                        logger.info(f"✅ [WEBHOOK] 支付成功，申请 {application_id} 已批准")
                        
                        # 增强支付审计信息：记录申请批准相关的支付信息
                        try:
                            # 创建或更新 PaymentHistory（如果不存在）
                            payment_history = db.query(models.PaymentHistory).filter(
                                models.PaymentHistory.payment_intent_id == payment_intent_id
                            ).first()
                            
                            if payment_history:
                                # 更新现有记录（状态机保护）
                                try:
                                    payment_history.transition_status("succeeded")
                                except ValueError as e:
                                    logger.warning(f"⚠️ [WEBHOOK] 状态转换被拒绝: {e}")
                                payment_history.escrow_amount = task.escrow_amount
                                # 增强 metadata（用新 dict 赋值，确保 SQLAlchemy 检测 JSONB 变更）
                                payment_history.extra_metadata = {
                                    **(payment_history.extra_metadata or {}),
                                    "application_id": str(application_id),
                                    "taker_id": str(application.applicant_id),
                                    "taker_name": application.applicant.name if hasattr(application, 'applicant') and application.applicant else None,
                                    "pending_approval": "true",
                                    "approved_via_webhook": True,
                                    "webhook_event_id": event_id,
                                    "approved_at": get_utc_time().isoformat()
                                }
                                logger.debug(f"✅ [WEBHOOK] 已更新支付历史记录: payment_history_id={payment_history.id}")
                            else:
                                # 创建新的支付历史记录（用于审计）
                                from decimal import Decimal
                                payment_history = models.PaymentHistory(
                                    order_no=models.PaymentHistory.generate_order_no(),
                                    task_id=task_id,
                                    user_id=task.poster_id,
                                    payment_intent_id=payment_intent_id,
                                    payment_method="stripe",
                                    total_amount=int(task_amount * 100),
                                    stripe_amount=int(task_amount * 100),
                                    final_amount=int(task_amount * 100),
                                    currency=task.currency or "GBP",
                                    status="succeeded",
                                    application_fee=application_fee_pence,
                                    escrow_amount=Decimal(str(task.escrow_amount)),
                                    extra_metadata={
                                        "application_id": str(application_id),
                                        "taker_id": str(application.applicant_id),
                                        "pending_approval": "true",
                                        "approved_via_webhook": True,
                                        "webhook_event_id": event_id,
                                        "approved_at": get_utc_time().isoformat()
                                    }
                                )
                                db.add(payment_history)
                                logger.debug(f"✅ [WEBHOOK] 已创建支付历史记录: order_no={payment_history.order_no}")
                        except Exception as e:
                            logger.error(f"❌ [WEBHOOK] 创建/更新支付历史记录失败: {e}", exc_info=True)
                            # 支付历史记录失败不影响主流程
                    else:
                        # Application not in expected status — check if it was withdrawn (race condition)
                        withdrawn_application = db.execute(
                            select(models.TaskApplication).where(
                                and_(
                                    models.TaskApplication.id == application_id,
                                    models.TaskApplication.task_id == task_id,
                                    models.TaskApplication.status == "withdrawn"
                                )
                            )
                        ).scalar_one_or_none()

                        if withdrawn_application:
                            logger.warning(
                                f"⚠️ [WEBHOOK] 申请人已撤回申请，支付成功但需退款: "
                                f"application_id={application_id_str}, task_id={task_id}, "
                                f"payment_intent_id={payment_intent_id}"
                            )
                            # Revert task paid status since we will refund
                            task.is_paid = 0
                            task.payment_intent_id = None
                            task.escrow_amount = None
                            # 退还钱包扣款（如果有）
                            if _wallet_tx_id:
                                try:
                                    from app.wallet_service import reverse_debit
                                    _wd = metadata.get("wallet_deduction")
                                    if _wd:
                                        from decimal import Decimal
                                        _wcur = metadata.get("wallet_currency", "GBP")
                                        reverse_debit(db, int(_wallet_tx_id), metadata.get("user_id", ""), Decimal(_wd) / Decimal("100"), currency=_wcur)
                                        logger.info(f"✅ [WEBHOOK] 申请撤回退款，钱包扣款已退还: wallet_tx_id={_wallet_tx_id}")
                                except Exception as w_err:
                                    logger.error(f"❌ [WEBHOOK] 退还钱包扣款失败（撤回）: {w_err}")
                            try:
                                stripe.Refund.create(payment_intent=payment_intent_id)
                                logger.info(
                                    f"✅ [WEBHOOK] 已发起退款: payment_intent_id={payment_intent_id}, "
                                    f"task_id={task_id}, application_id={application_id_str}"
                                )
                                # Notify the poster that payment was refunded
                                try:
                                    crud.create_notification(
                                        db=db,
                                        user_id=task.poster_id,
                                        type="payment_refunded",
                                        title="支付已退款",
                                        content=f"申请人在支付处理期间撤回了申请，您的付款已自动退款：{task.title}",
                                        related_id=str(task_id),
                                        auto_commit=False,
                                    )
                                except Exception as notify_err:
                                    logger.warning(f"⚠️ [WEBHOOK] 创建退款通知失败: {notify_err}")
                            except Exception as refund_err:
                                logger.error(
                                    f"❌ [WEBHOOK] 退款失败，需人工处理: payment_intent_id={payment_intent_id}, "
                                    f"task_id={task_id}, error={refund_err}",
                                    exc_info=True
                                )
                        else:
                            logger.warning(
                                f"⚠️ [WEBHOOK] 未找到匹配的申请: application_id={application_id_str}, "
                                f"task_id={task_id}, status not in [pending, chatting, withdrawn]. "
                                f"Attempting refund for payment_intent_id={payment_intent_id}"
                            )
                            # Application not found at all or in unexpected status — refund to be safe
                            task.is_paid = 0
                            task.payment_intent_id = None
                            task.escrow_amount = None
                            # 退还钱包扣款（如果有）
                            if _wallet_tx_id:
                                try:
                                    from app.wallet_service import reverse_debit
                                    _wd = metadata.get("wallet_deduction")
                                    if _wd:
                                        from decimal import Decimal
                                        _wcur = metadata.get("wallet_currency", "GBP")
                                        reverse_debit(db, int(_wallet_tx_id), metadata.get("user_id", ""), Decimal(_wd) / Decimal("100"), currency=_wcur)
                                        logger.info(f"✅ [WEBHOOK] 申请未找到退款，钱包扣款已退还: wallet_tx_id={_wallet_tx_id}")
                                except Exception as w_err:
                                    logger.error(f"❌ [WEBHOOK] 退还钱包扣款失败（未找到）: {w_err}")
                            try:
                                stripe.Refund.create(payment_intent=payment_intent_id)
                                logger.info(
                                    f"✅ [WEBHOOK] 已发起退款（申请未找到）: payment_intent_id={payment_intent_id}"
                                )
                            except Exception as refund_err:
                                logger.error(
                                    f"❌ [WEBHOOK] 退款失败，需人工处理: payment_intent_id={payment_intent_id}, "
                                    f"error={refund_err}",
                                    exc_info=True
                                )
                else:
                    logger.info(f"ℹ️ 不是待确认的批准支付: is_pending_approval={is_pending_approval}, application_id={application_id_str}")
                    # 即使不是 pending_approval，也要记录支付历史
                    try:
                        payment_history = db.query(models.PaymentHistory).filter(
                            models.PaymentHistory.payment_intent_id == payment_intent_id
                        ).first()
                        
                        if not payment_history:
                            # 创建新的支付历史记录
                            from decimal import Decimal
                            payment_history = models.PaymentHistory(
                                order_no=models.PaymentHistory.generate_order_no(),
                                task_id=task_id,
                                user_id=task.poster_id,
                                payment_intent_id=payment_intent_id,
                                payment_method="stripe",
                                total_amount=int(task_amount * 100),
                                stripe_amount=int(task_amount * 100),
                                final_amount=int(task_amount * 100),
                                currency=task.currency or "GBP",
                                status="succeeded",
                                application_fee=application_fee_pence,
                                escrow_amount=Decimal(str(task.escrow_amount)),
                                extra_metadata={
                                    "approved_via_webhook": True,
                                    "webhook_event_id": event_id,
                                    "approved_at": get_utc_time().isoformat()
                                }
                            )
                            db.add(payment_history)
                            logger.debug(f"✅ [WEBHOOK] 已创建支付历史记录（非 pending_approval）: order_no={payment_history.order_no}")
                        else:
                            # 更新现有记录（状态机保护）
                            try:
                                payment_history.transition_status("succeeded")
                            except ValueError as e:
                                logger.warning(f"⚠️ [WEBHOOK] 状态转换被拒绝: {e}")
                            payment_history.escrow_amount = task.escrow_amount
                            # 用新 dict 赋值，确保 SQLAlchemy 检测 JSONB 变更
                            payment_history.extra_metadata = {
                                **(payment_history.extra_metadata or {}),
                                "approved_via_webhook": True,
                                "webhook_event_id": event_id,
                                "approved_at": get_utc_time().isoformat()
                            }
                            logger.debug(f"✅ [WEBHOOK] 已更新支付历史记录（非 pending_approval）: order_no={payment_history.order_no}")
                    except Exception as e:
                        logger.error(f"❌ [WEBHOOK] 创建/更新支付历史记录失败（非 pending_approval）: {e}", exc_info=True)
                        # 支付历史记录失败不影响主流程
                
                # 支付成功后，将任务状态从 pending_payment 更新为 in_progress
                logger.info(f"🔍 检查任务状态: 当前状态={task.status}, is_paid={task.is_paid}")
                if task.status == "pending_payment":
                    logger.info(f"✅ 任务状态从 pending_payment 更新为 in_progress")
                    task.status = "in_progress"
                else:
                    logger.info(f"⚠️ 任务状态不是 pending_payment，当前状态: {task.status}，跳过状态更新")

            elif task and task.is_paid == 1:
                # ====== 补差价支付（top_up）：任务已付款，此次为追加支付 ======
                metadata = payment_intent.get("metadata", {})
                if metadata.get("payment_type") == "top_up" and metadata.get("pending_approval") == "true":
                    top_up_pence = payment_intent.get("amount", 0)
                    logger.info(f"✅ [WEBHOOK] 补差价支付成功: task_id={task_id}, top_up={top_up_pence}p")

                    # 更新 escrow：累加补差价金额（扣除补差价部分的服务费）
                    from app.utils.fee_calculator import calculate_application_fee_pence
                    task_source = getattr(task, "task_source", None)
                    task_type_val = getattr(task, "task_type", None)
                    top_up_fee = calculate_application_fee_pence(top_up_pence, task_source, task_type_val)
                    top_up_net = (top_up_pence - top_up_fee) / 100.0
                    task.escrow_amount = float(task.escrow_amount or 0) + max(0.0, top_up_net)

                    # 更新 agreed_reward 为新总价
                    if metadata.get("negotiated_price"):
                        try:
                            from decimal import Decimal
                            task.agreed_reward = Decimal(metadata["negotiated_price"])
                        except Exception:
                            pass

                    # 保存最新的 payment_intent_id
                    task.payment_intent_id = payment_intent_id

                    # 批准申请（复用与上面相同的逻辑）
                    application_id_str = metadata.get("application_id")
                    if application_id_str:
                        application_id = int(application_id_str)
                        application = db.execute(
                            select(models.TaskApplication).where(
                                and_(
                                    models.TaskApplication.id == application_id,
                                    models.TaskApplication.task_id == task_id,
                                    models.TaskApplication.status.in_(["pending", "chatting"])
                                )
                            ).with_for_update()
                        ).scalar_one_or_none()

                        if application:
                            application.status = "approved"
                            task.taker_id = application.applicant_id
                            task.status = "in_progress"
                            logger.info(f"✅ [WEBHOOK] 补差价后批准申请 {application_id}")

                            # 自动拒绝其他申请
                            other_apps = db.execute(
                                select(models.TaskApplication).where(
                                    and_(
                                        models.TaskApplication.task_id == task_id,
                                        models.TaskApplication.id != application_id,
                                        models.TaskApplication.status.in_(["chatting", "pending"])
                                    )
                                )
                            ).scalars().all()
                            for other_app in other_apps:
                                was_chatting = other_app.status == "chatting"
                                other_app.status = "rejected"
                                if was_chatting:
                                    reject_msg = models.Message(
                                        task_id=task_id, application_id=other_app.id,
                                        sender_id=None, receiver_id=None,
                                        content="发布者已选择了其他申请者完成此任务。",
                                        message_type="system", conversation_type="task",
                                        meta=json.dumps({"system_action": "auto_rejected",
                                                         "content_en": "The poster has selected another applicant for this task."}),
                                        created_at=get_utc_time(),
                                    )
                                    db.add(reject_msg)

                            # 通知申请人
                            try:
                                crud.create_notification(
                                    db, application.applicant_id,
                                    "application_accepted", "申请已通过",
                                    f"您的任务申请已被接受：{task.title}",
                                    related_id=str(task_id), auto_commit=False,
                                )
                            except Exception as e:
                                logger.warning(f"⚠️ [WEBHOOK] 通知失败: {e}")
                        else:
                            logger.warning(f"⚠️ [WEBHOOK] 补差价支付成功但未找到申请 {application_id_str}")
                else:
                    logger.info(f"ℹ️ [WEBHOOK] 已付款任务收到支付，非 top_up 类型，跳过")
                
                # 支付历史记录已在上面更新（如果存在待确认的批准支付）
                
                # 提交数据库更改
                try:
                    # 在提交前记录更新前的状态（DEBUG级别）
                    logger.debug(f"📝 [WEBHOOK] 提交前任务状态: is_paid={task.is_paid}, status={task.status}, payment_intent_id={task.payment_intent_id}, escrow_amount={task.escrow_amount}, taker_id={task.taker_id}")
                    
                    db.commit()
                    logger.debug(f"✅ [WEBHOOK] 数据库提交成功")
                    
                    # 刷新任务对象以获取最新状态
                    db.refresh(task)
                    
                    # ⚠️ 优化：清除任务缓存，确保前端立即看到更新后的状态
                    try:
                        from app.services.task_service import TaskService
                        TaskService.invalidate_cache(task_id)
                        logger.debug(f"✅ [WEBHOOK] 已清除任务 {task_id} 的缓存")
                    except Exception as e:
                        logger.warning(f"⚠️ [WEBHOOK] 清除任务缓存失败: {e}")
                    
                    # 清除任务列表缓存（因为任务状态已改变）
                    try:
                        from app.redis_cache import invalidate_tasks_cache
                        invalidate_tasks_cache()
                        logger.debug(f"✅ [WEBHOOK] 已清除任务列表缓存")
                    except Exception as e:
                        logger.warning(f"⚠️ [WEBHOOK] 清除任务列表缓存失败: {e}")
                    
                    # 验证更新是否成功（关键信息保留INFO）
                    logger.info(f"✅ [WEBHOOK] 任务 {task_id} 支付完成: status={task.status}, is_paid={task.is_paid}, taker_id={task.taker_id}")
                    logger.debug(f"  - Payment Intent ID: {task.payment_intent_id}, Escrow 金额: {task.escrow_amount}")
                    
                    # 如果 is_paid 没有正确更新，记录警告
                    if task.is_paid != 1:
                        logger.error(f"❌ [WEBHOOK] 警告：任务 {task_id} 的 is_paid 字段未正确更新！当前值: {task.is_paid}")
                except Exception as e:
                    logger.error(f"❌ [WEBHOOK] 数据库提交失败: {e}")
                    import traceback
                    logger.error(f"  - 错误堆栈: {traceback.format_exc()}")
                    db.rollback()
                    raise
            else:
                logger.warning(f"⚠️ [WEBHOOK] 任务 {task_id} 已支付或不存在")
                if task:
                    logger.warning(f"  - 任务已支付状态: {task.is_paid}")
                    logger.warning(f"  - 任务当前状态: {task.status}")
        else:
            logger.warning(f"⚠️ [WEBHOOK] Payment Intent 成功但 metadata 中没有 task_id")
            logger.warning(f"  - Metadata: {json.dumps(payment_intent.get('metadata', {}), ensure_ascii=False)}")
            logger.warning(f"  - Payment Intent ID: {payment_intent_id}")
    
    elif event_type == "payment_intent.payment_failed":
        payment_intent = event_data
        payment_intent_id = payment_intent.get("id")
        task_id = int(payment_intent.get("metadata", {}).get("task_id", 0))
        application_id_str = payment_intent.get("metadata", {}).get("application_id")
        error_message = payment_intent.get('last_payment_error', {}).get('message', 'Unknown error')
        
        logger.warning(f"❌ [WEBHOOK] Payment Intent 支付失败:")
        logger.warning(f"  - Payment Intent ID: {payment_intent_id}")
        logger.warning(f"  - Task ID: {task_id}")
        logger.warning(f"  - Application ID: {application_id_str}")
        logger.warning(f"  - 错误信息: {error_message}")
        logger.warning(f"  - 完整错误: {json.dumps(payment_intent.get('last_payment_error', {}), ensure_ascii=False)}")
        
        # 更新支付历史记录状态为失败
        if payment_intent_id:
            try:
                payment_history = db.query(models.PaymentHistory).filter(
                    models.PaymentHistory.payment_intent_id == payment_intent_id
                ).first()
                if payment_history:
                    try:
                        payment_history.transition_status("failed")
                    except ValueError as e:
                        logger.warning(f"⚠️ [WEBHOOK] 状态转换被拒绝: {e}")
                    # 用新 dict 赋值，确保 SQLAlchemy 检测 JSONB 变更
                    payment_history.extra_metadata = {
                        **(payment_history.extra_metadata or {}),
                        "payment_failed": True,
                        "error_message": error_message,
                        "webhook_event_id": event_id,
                        "failed_at": get_utc_time().isoformat()
                    }
                    db.commit()
                    logger.info(f"✅ [WEBHOOK] 已更新支付历史记录状态为失败: order_no={payment_history.order_no}")
            except Exception as e:
                logger.error(f"❌ [WEBHOOK] 更新支付历史记录失败: {e}", exc_info=True)

        # ==================== 钱包混合支付：退还钱包扣款 ====================
        _failed_metadata = payment_intent.get("metadata", {})
        _failed_wallet_tx_id = _failed_metadata.get("wallet_tx_id")
        _failed_wallet_deduction = _failed_metadata.get("wallet_deduction")
        if _failed_wallet_tx_id and _failed_wallet_deduction:
            try:
                from app.wallet_service import reverse_debit
                from decimal import Decimal
                _user_id = _failed_metadata.get("user_id", "")
                _deduction_pounds = Decimal(_failed_wallet_deduction) / Decimal("100")
                _wcur = _failed_metadata.get("wallet_currency", "GBP")
                reverse_debit(db, int(_failed_wallet_tx_id), _user_id, _deduction_pounds, currency=_wcur)
                db.commit()
                logger.info(
                    f"✅ [WEBHOOK] 支付失败，钱包扣款已退还: "
                    f"wallet_tx_id={_failed_wallet_tx_id}, amount={_failed_wallet_deduction}p, task_id={task_id}"
                )
            except Exception as wallet_err:
                logger.error(f"❌ [WEBHOOK] 退还钱包扣款失败: wallet_tx_id={_failed_wallet_tx_id}, error={wallet_err}")
                db.rollback()

        # 支付失败时，清除 payment_intent_id（申请状态保持为 pending，可以重新尝试）
        if task_id and application_id_str:
            application_id = int(application_id_str)
            task = crud.get_task(db, task_id)
            
            if task and task.status == "pending_payment" and task.taker_id:
                # 查找已批准的申请
                application = db.execute(
                    select(models.TaskApplication).where(
                        and_(
                            models.TaskApplication.id == application_id,
                            models.TaskApplication.task_id == task_id,
                            models.TaskApplication.status == "approved"
                        )
                    )
                ).scalar_one_or_none()
                
                if application:
                    logger.info(f"🔄 [WEBHOOK] 撤销申请批准: application_id={application_id}")
                    application.status = "pending"
                    task.taker_id = None
                    task.status = "open"
                    task.is_paid = 0
                    task.payment_intent_id = None
                    
                    # 发送通知
                    try:
                        from app import crud
                        crud.create_notification(
                            db,
                            application.applicant_id,
                            "payment_failed",
                            "支付失败",
                            f"任务支付失败，申请已撤销：{task.title}",
                            task.id,
                            auto_commit=False,
                        )
                        crud.create_notification(
                            db,
                            task.poster_id,
                            "payment_failed",
                            "支付失败",
                            f"任务支付失败：{task.title}",
                            task.id,
                            auto_commit=False,
                        )
                        logger.info(f"✅ [WEBHOOK] 已发送支付失败通知")
                    except Exception as e:
                        logger.error(f"❌ [WEBHOOK] 发送支付失败通知失败: {e}")
                    
                    try:
                        db.commit()
                        logger.info(f"✅ [WEBHOOK] 已撤销申请批准并恢复任务状态")
                        logger.info(f"  - 申请状态: pending")
                        logger.info(f"  - 任务状态: {task.status}")
                        logger.info(f"  - Taker ID: {task.taker_id}")
                        
                        # ⚠️ 优化：清除任务缓存，确保前端立即看到更新后的状态
                        try:
                            from app.services.task_service import TaskService
                            TaskService.invalidate_cache(task_id)
                            logger.info(f"✅ [WEBHOOK] 已清除任务 {task_id} 的缓存（支付失败）")
                        except Exception as e:
                            logger.warning(f"⚠️ [WEBHOOK] 清除任务缓存失败: {e}")
                        
                        # 清除任务列表缓存
                        try:
                            from app.redis_cache import invalidate_tasks_cache
                            invalidate_tasks_cache()
                            logger.info(f"✅ [WEBHOOK] 已清除任务列表缓存（支付失败）")
                        except Exception as e:
                            logger.warning(f"⚠️ [WEBHOOK] 清除任务列表缓存失败: {e}")
                    except Exception as e:
                        logger.error(f"❌ [WEBHOOK] 数据库提交失败: {e}")
                        db.rollback()
                else:
                    logger.warning(f"⚠️ [WEBHOOK] 未找到已批准的申请: application_id={application_id}")
            elif task:
                task.payment_intent_id = None
                try:
                    db.commit()
                    logger.info(f"✅ [WEBHOOK] 已清除任务 {task_id} 的 payment_intent_id")
                    
                    # ⚠️ 优化：清除任务缓存
                    try:
                        from app.services.task_service import TaskService
                        TaskService.invalidate_cache(task_id)
                        from app.redis_cache import invalidate_tasks_cache
                        invalidate_tasks_cache()
                        logger.info(f"✅ [WEBHOOK] 已清除任务缓存（支付失败-无申请）")
                    except Exception as e:
                        logger.warning(f"⚠️ [WEBHOOK] 清除任务缓存失败: {e}")
                except Exception as e:
                    logger.error(f"❌ [WEBHOOK] 数据库提交失败: {e}")
                    db.rollback()
    
    # 处理退款事件
    elif event_type == "charge.refunded":
        charge = event_data
        task_id = int(charge.get("metadata", {}).get("task_id", 0))
        refund_request_id = charge.get("metadata", {}).get("refund_request_id")
        
        if task_id:
            task = crud.get_task(db, task_id)
            if task:
                # ✅ 安全修复：验证任务仍然已支付
                if not task.is_paid:
                    logger.warning(f"任务 {task_id} 已不再支付，跳过webhook退款处理")
                    return {"status": "skipped", "reason": "task_not_paid"}
                
                # ✅ 安全修复：验证退款申请状态（如果有关联的退款申请）
                if refund_request_id:
                    try:
                        refund_request_check = db.query(models.RefundRequest).filter(
                            models.RefundRequest.id == int(refund_request_id)
                        ).first()
                        if refund_request_check and refund_request_check.status != "processing":
                            logger.warning(f"退款申请 {refund_request_id} 状态为 {refund_request_check.status}，不是processing，跳过webhook处理")
                            return {"status": "skipped", "reason": "refund_request_not_processing"}
                    except Exception as e:
                        logger.warning(f"检查退款申请状态时发生错误: {e}")
                
                # ✅ 修复金额精度：使用Decimal计算退款金额
                from decimal import Decimal
                refund_amount = Decimal(str(charge.get("amount_refunded", 0))) / Decimal('100')
                refund_amount_float = float(refund_amount)  # 用于显示和日志
                
                # 如果有关联的退款申请，更新退款申请状态
                if refund_request_id:
                    try:
                        refund_request = db.query(models.RefundRequest).filter(
                            models.RefundRequest.id == int(refund_request_id)
                        ).first()
                        
                        if refund_request and refund_request.status == "processing":
                            # 更新退款申请状态为已完成
                            refund_request.status = "completed"
                            refund_request.completed_at = get_utc_time()
                            
                            # 发送系统消息通知用户
                            try:
                                from app.models import Message
                                import json
                                
                                content_zh = f"您的退款申请已处理完成，退款金额：£{refund_amount_float:.2f}。退款将在5-10个工作日内退回您的原支付方式。"
                                content_en = f"Your refund request has been processed. Refund amount: £{refund_amount_float:.2f}. The refund will be returned to your original payment method within 5-10 business days."
                                
                                system_message = Message(
                                    sender_id=None,
                                    receiver_id=None,
                                    content=content_zh,
                                    task_id=task.id,
                                    message_type="system",
                                    conversation_type="task",
                                    meta=json.dumps({
                                        "system_action": "refund_completed",
                                        "refund_request_id": refund_request.id,
                                        "refund_amount": float(refund_amount),
                                        "content_en": content_en
                                    }),
                                    created_at=get_utc_time()
                                )
                                db.add(system_message)
                                
                                # 发送通知给发布者
                                crud.create_notification(
                                    db=db,
                                    user_id=refund_request.poster_id,
                                    type="refund_completed",
                                    title="退款已完成",
                                    content=f"您的任务「{task.title}」的退款申请已处理完成，退款金额：£{refund_amount_float:.2f}",
                                    related_id=str(task.id),
                                    auto_commit=False
                                )
                            except Exception as e:
                                logger.error(f"Failed to send refund completion notification: {e}")
                    except Exception as e:
                        logger.error(f"Failed to update refund request status: {e}")
                
                # ✅ 修复金额精度：使用Decimal进行金额比较
                # ✅ 支持部分退款：更新任务状态和托管金额
                task_amount = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
                
                if refund_amount >= task_amount:
                    # 全额退款
                    task.is_paid = 0
                    task.payment_intent_id = None
                    task.escrow_amount = 0.0
                    logger.info(f"✅ 全额退款，已更新任务支付状态")
                else:
                    # 部分退款：更新托管金额
                    # ✅ 计算退款后的剩余金额（最终成交金额）
                    remaining_amount = task_amount - refund_amount
                    
                    # ✅ 计算已转账的总金额
                    from sqlalchemy import func, and_
                    total_transferred = db.query(
                        func.sum(models.PaymentTransfer.amount).label('total_transferred')
                    ).filter(
                        and_(
                            models.PaymentTransfer.task_id == task.id,
                            models.PaymentTransfer.status == "succeeded"
                        )
                    ).scalar() or Decimal('0')
                    total_transferred = Decimal(str(total_transferred)) if total_transferred else Decimal('0')
                    
                    # ✅ 基于剩余金额重新计算平台服务费（按任务来源/类型取费率）
                    from app.utils.fee_calculator import calculate_application_fee
                    _ts = getattr(task, "task_source", None)
                    _tt = getattr(task, "task_type", None)
                    application_fee = calculate_application_fee(float(remaining_amount), _ts, _tt)
                    new_escrow_amount = remaining_amount - Decimal(str(application_fee))
                    
                    # ✅ 如果已经进行了部分转账，需要从剩余金额中扣除已转账部分
                    if total_transferred > 0:
                        remaining_after_transfer = remaining_amount - total_transferred
                        if remaining_after_transfer > 0:
                            remaining_application_fee = calculate_application_fee(float(remaining_amount), _ts, _tt)
                            new_escrow_amount = remaining_amount - Decimal(str(remaining_application_fee)) - total_transferred
                        else:
                            # 如果剩余金额已经全部转账，escrow为0
                            new_escrow_amount = Decimal('0')
                    
                    # 更新托管金额（确保不为负数）
                    task.escrow_amount = float(max(Decimal('0'), new_escrow_amount))
                    logger.info(f"✅ 部分退款：退款金额 £{refund_amount_float:.2f}，剩余任务金额 £{remaining_amount:.2f}，已转账 £{total_transferred:.2f}，服务费 £{application_fee:.2f}，更新后托管金额 £{task.escrow_amount:.2f}")
                
                db.commit()
                logger.info(f"Task {task_id} refunded: £{refund_amount_float:.2f}")
    
    # 处理争议事件
    elif event_type == "charge.dispute.created":
        dispute = event_data
        charge_id = dispute.get("charge")
        task_id = int(dispute.get("metadata", {}).get("task_id", 0))
        reason = dispute.get("reason", "unknown")
        amount = (dispute.get("amount") or 0) / 100.0
        logger.warning(f"Stripe 争议 charge.dispute.created: charge={charge_id}, task_id={task_id}, reason={reason}, amount={amount}")
        try:
            # 通知 poster、taker、管理员，并冻结任务状态
            if task_id:
                task = crud.get_task(db, task_id)
                if task:
                    # ✅ Stripe争议冻结：冻结任务状态，防止资金继续流出
                    if not hasattr(task, 'stripe_dispute_frozen') or task.stripe_dispute_frozen != 1:
                        task.stripe_dispute_frozen = 1
                        logger.warning(f"⚠️ 任务 {task_id} 因Stripe争议已冻结，防止资金继续流出")
                        
                        # 发送系统消息
                        try:
                            from app.models import Message
                            import json
                            
                            content_zh = f"⚠️ 此任务的支付发生Stripe争议，任务状态已冻结。原因: {reason}，金额: £{amount:.2f}。在争议解决前，所有资金操作将被暂停。"
                            content_en = f"⚠️ A Stripe dispute has been raised for this task's payment. Task status is now frozen. Reason: {reason}, amount: £{amount:.2f}. All fund operations are suspended until the dispute is resolved."
                            system_message = Message(
                                sender_id=None,
                                receiver_id=None,
                                content=content_zh,
                                task_id=task.id,
                                message_type="system",
                                conversation_type="task",
                                meta=json.dumps({
                                    "system_action": "stripe_dispute_frozen",
                                    "charge_id": charge_id,
                                    "reason": reason,
                                    "amount": amount,
                                    "content_en": content_en
                                }),
                                created_at=get_utc_time()
                            )
                            db.add(system_message)
                        except Exception as e:
                            logger.error(f"Failed to send system message for dispute freeze: {e}")
                    
                    # 通知发布者
                    crud.create_notification(
                        db, str(task.poster_id),
                        "stripe_dispute", "Stripe 支付争议",
                        f"您的任务「{task.title}」（ID: {task_id}）的支付发生 Stripe 争议，任务状态已冻结。原因: {reason}，金额: £{amount:.2f}",
                        related_id=str(task_id), auto_commit=False
                    )
                    # 通知接受者（如有）
                    if task.taker_id:
                        crud.create_notification(
                            db, str(task.taker_id),
                            "stripe_dispute", "Stripe 支付争议",
                            f"您参与的任务「{task.title}」（ID: {task_id}）的支付发生 Stripe 争议，任务状态已冻结。原因: {reason}，金额: £{amount:.2f}",
                            related_id=str(task_id), auto_commit=False
                        )
            admins = db.query(models.AdminUser.id).filter(models.AdminUser.is_active == True).all()
            admin_content = f"Stripe 争议: charge={charge_id}, task_id={task_id or 'N/A'}, reason={reason}, amount=£{amount:.2f}"
            related = str(task_id) if task_id else (charge_id or "")
            for (admin_id,) in admins:
                crud.create_notification(
                    db, admin_id, "stripe_dispute", "Stripe 支付争议", admin_content,
                    related_id=related, auto_commit=False
                )
        except Exception as e:
            logger.error(f"charge.dispute.created 通知处理失败: {e}", exc_info=True)
    
    elif event_type == "charge.dispute.updated":
        dispute = event_data
        charge_id = dispute.get("charge")
        task_id = int(dispute.get("metadata", {}).get("task_id", 0))
        status = dispute.get("status")
        logger.info(f"Dispute updated for charge {charge_id}, task {task_id}: status={status}")
    
    elif event_type == "charge.dispute.closed":
        dispute = event_data
        charge_id = dispute.get("charge")
        task_id = int(dispute.get("metadata", {}).get("task_id", 0))
        status = dispute.get("status")
        logger.info(f"Dispute closed for charge {charge_id}, task {task_id}: status={status}")
        
        # ✅ Stripe争议解冻：争议关闭后解冻任务状态
        if task_id:
            task = crud.get_task(db, task_id)
            if task and hasattr(task, 'stripe_dispute_frozen') and task.stripe_dispute_frozen == 1:
                task.stripe_dispute_frozen = 0
                logger.info(f"✅ 任务 {task_id} 的Stripe争议已关闭，已解冻任务状态")
                
                # 发送系统消息
                try:
                    from app.models import Message
                    import json
                    
                    content_zh = f"✅ Stripe争议已关闭（状态: {status}），任务状态已解冻，资金操作已恢复正常。"
                    content_en = f"✅ Stripe dispute has been closed (status: {status}). Task status is now unfrozen and fund operations have resumed."
                    system_message = Message(
                        sender_id=None,
                        receiver_id=None,
                        content=content_zh,
                        task_id=task.id,
                        message_type="system",
                        conversation_type="task",
                        meta=json.dumps({
                            "system_action": "stripe_dispute_unfrozen",
                            "charge_id": charge_id,
                            "status": status,
                            "content_en": content_en
                        }),
                        created_at=get_utc_time()
                    )
                    db.add(system_message)
                    db.commit()
                except Exception as e:
                    logger.error(f"Failed to send system message for dispute unfreeze: {e}")
                    db.rollback()
    
    elif event_type == "charge.dispute.funds_withdrawn":
        dispute = event_data
        charge_id = dispute.get("charge")
        task_id = int(dispute.get("metadata", {}).get("task_id", 0))
        logger.warning(f"Dispute funds withdrawn for charge {charge_id}, task {task_id}")
    
    elif event_type == "charge.dispute.funds_reinstated":
        dispute = event_data
        charge_id = dispute.get("charge")
        task_id = int(dispute.get("metadata", {}).get("task_id", 0))
        logger.info(f"Dispute funds reinstated for charge {charge_id}, task {task_id}")
    
    # 处理其他 charge 事件
    elif event_type == "charge.succeeded":
        charge = event_data
        task_id = int(charge.get("metadata", {}).get("task_id", 0))
        if task_id:
            logger.info(f"Charge succeeded for task {task_id}: charge_id={charge.get('id')}")
    
    elif event_type == "charge.failed":
        charge = event_data
        task_id = int(charge.get("metadata", {}).get("task_id", 0))
        logger.warning(f"Charge failed for task {task_id}: {charge.get('failure_message', 'Unknown error')}")
    
    elif event_type == "charge.captured":
        charge = event_data
        task_id = int(charge.get("metadata", {}).get("task_id", 0))
        logger.info(f"Charge captured for task {task_id}: charge_id={charge.get('id')}")
    
    elif event_type == "charge.refund.updated":
        refund = event_data
        charge_id = refund.get("charge")
        task_id = int(refund.get("metadata", {}).get("task_id", 0))
        status = refund.get("status")
        logger.info(f"Refund updated for charge {charge_id}, task {task_id}: status={status}")
    
    # 处理 Payment Intent 其他事件
    elif event_type == "payment_intent.created":
        payment_intent = event_data
        task_id = int(payment_intent.get("metadata", {}).get("task_id", 0))
        logger.info(f"Payment intent created for task {task_id}: payment_intent_id={payment_intent.get('id')}")
    
    elif event_type == "payment_intent.canceled":
        payment_intent = event_data
        payment_intent_id = payment_intent.get("id")
        task_id = int(payment_intent.get("metadata", {}).get("task_id", 0))
        logger.warning(f"⚠️ [WEBHOOK] Payment intent canceled: payment_intent_id={payment_intent_id}, task_id={task_id}")

        # ==================== 钱包混合支付：退还钱包扣款 ====================
        _canceled_metadata = payment_intent.get("metadata", {})
        _canceled_wallet_tx_id = _canceled_metadata.get("wallet_tx_id")
        _canceled_wallet_deduction = _canceled_metadata.get("wallet_deduction")
        if _canceled_wallet_tx_id and _canceled_wallet_deduction:
            try:
                from app.wallet_service import reverse_debit
                from decimal import Decimal
                _user_id = _canceled_metadata.get("user_id", "")
                _deduction_pounds = Decimal(_canceled_wallet_deduction) / Decimal("100")
                _wcur = _canceled_metadata.get("wallet_currency", "GBP")
                reverse_debit(db, int(_canceled_wallet_tx_id), _user_id, _deduction_pounds, currency=_wcur)
                db.commit()
                logger.info(
                    f"✅ [WEBHOOK] 支付取消，钱包扣款已退还: "
                    f"wallet_tx_id={_canceled_wallet_tx_id}, amount={_canceled_wallet_deduction}p, task_id={task_id}"
                )
            except Exception as wallet_err:
                logger.error(f"❌ [WEBHOOK] 退还钱包扣款失败: wallet_tx_id={_canceled_wallet_tx_id}, error={wallet_err}")
                db.rollback()

        # ⚠️ 处理 PaymentIntent 取消事件
        # 新流程：任务保持 open 状态，支付取消时只需清除 payment_intent_id
        # 这样用户可以继续批准其他申请者或重新批准同一个申请者
        if task_id:
            task = crud.get_task(db, task_id)
            # 检查任务状态：open 或 pending_payment（兼容旧流程）
            if task and task.payment_intent_id == payment_intent_id and task.status in ["open", "pending_payment"]:
                logger.info(
                    f"ℹ️ [WEBHOOK] 任务 {task_id} 的 PaymentIntent 已取消，"
                    f"任务状态: {task.status}，清除 payment_intent_id，允许用户重新创建支付"
                )
                # 清除 payment_intent_id，允许用户重新创建支付
                task.payment_intent_id = None
                db.commit()
                logger.info(f"✅ [WEBHOOK] 已清除任务 {task_id} 的 payment_intent_id，允许重新创建支付")
            else:
                logger.info(
                    f"ℹ️ [WEBHOOK] 任务 {task_id} 状态不匹配或 payment_intent_id 不匹配，"
                    f"当前状态: {task.status if task else 'N/A'}, payment_intent_id: {task.payment_intent_id if task else 'N/A'}"
                )
    
    elif event_type == "payment_intent.requires_action":
        payment_intent = event_data
        task_id = int(payment_intent.get("metadata", {}).get("task_id", 0))
        logger.info(f"Payment intent requires action for task {task_id}: payment_intent_id={payment_intent.get('id')}")
    
    elif event_type == "payment_intent.processing":
        payment_intent = event_data
        task_id = int(payment_intent.get("metadata", {}).get("task_id", 0))
        logger.info(f"Payment intent processing for task {task_id}: payment_intent_id={payment_intent.get('id')}")
    
    # 处理 Invoice 事件（用于订阅）
    elif event_type == "invoice.paid":
        invoice = event_data
        subscription_id = invoice.get("subscription")
        logger.info(f"Invoice paid: invoice_id={invoice.get('id')}, subscription_id={subscription_id}")
    
    elif event_type == "invoice.payment_failed":
        invoice = event_data
        subscription_id = invoice.get("subscription")
        logger.warning(f"Invoice payment failed: invoice_id={invoice.get('id')}, subscription_id={subscription_id}")
    
    elif event_type == "invoice.finalized":
        invoice = event_data
        logger.info(f"Invoice finalized: invoice_id={invoice.get('id')}")
    
    # 保留对 Checkout Session 的兼容性（包括 iOS 微信支付二维码）
    elif event_type == "checkout.session.completed":
        session = event_data
        metadata = session.get("metadata", {})
        task_id = int(metadata.get("task_id", 0))
        payment_type = metadata.get("payment_type", "")
        
        logger.info(f"[WEBHOOK] Checkout Session 完成: session_id={session.get('id')}, task_id={task_id}, payment_type={payment_type}")
        
        if task_id:
            locked_task_query = select(models.Task).where(
                models.Task.id == task_id
            ).with_for_update()
            task = db.execute(locked_task_query).scalar_one_or_none()
            if task and not task.is_paid:
                task.is_paid = 1
                # 存储 PaymentIntent ID（用于后续退款），Checkout Session 内部创建了 PaymentIntent
                session_pi = session.get("payment_intent")
                if session_pi and not task.payment_intent_id:
                    task.payment_intent_id = session_pi
                # 获取任务金额（使用最终成交价或原始标价）
                task_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0

                # 🔒 安全修复：始终使用后端计算的服务费，不信任metadata中的金额；按任务来源/类型取费率
                from app.utils.fee_calculator import calculate_application_fee_pence
                task_amount_pence = round(task_amount * 100)
                task_source = getattr(task, "task_source", None)
                task_type = getattr(task, "task_type", None)
                application_fee_pence = calculate_application_fee_pence(task_amount_pence, task_source, task_type)
                
                metadata_fee = int(metadata.get("application_fee", 0))
                if metadata_fee > 0 and metadata_fee != application_fee_pence:
                    logger.warning(f"⚠️ Checkout session 服务费不一致: metadata={metadata_fee}, calculated={application_fee_pence}, task_id={task_id}")
                
                # escrow_amount = 任务金额 - 平台服务费（任务接受人获得的金额）
                application_fee = application_fee_pence / 100.0
                taker_amount = task_amount - application_fee
                task.escrow_amount = max(0.0, taker_amount)  # 确保不为负数
                
                # 支付成功后，将任务状态从 pending_payment 更新为 in_progress
                if task.status == "pending_payment":
                    task.status = "in_progress"
                
                # 更新支付历史记录状态
                try:
                    checkout_session_id = session.get("id")
                    if checkout_session_id:
                        payment_history = db.query(models.PaymentHistory).filter(
                            models.PaymentHistory.task_id == task_id,
                            models.PaymentHistory.status == "pending"
                        ).order_by(models.PaymentHistory.created_at.desc()).first()
                        
                        if payment_history:
                            try:
                                payment_history.transition_status("succeeded")
                            except ValueError as e:
                                logger.warning(f"⚠️ [WEBHOOK] 状态转换被拒绝: {e}")
                            payment_history.payment_intent_id = session.get("payment_intent") or checkout_session_id
                            logger.info(f"[WEBHOOK] 更新支付历史记录状态为 succeeded: order_no={payment_history.order_no}")
                except Exception as e:
                    logger.warning(f"[WEBHOOK] 更新支付历史记录失败: {e}")
                
                # 跳蚤市场：Checkout Session 完成时更新商品状态为 sold（微信支付等）
                flea_market_item_id = metadata.get("flea_market_item_id")
                if flea_market_item_id:
                    try:
                        from app.models import FleaMarketItem
                        from app.id_generator import parse_flea_market_id
                        db_item_id = parse_flea_market_id(flea_market_item_id)
                        # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定商品记录
                        flea_item = db.query(FleaMarketItem).filter(
                            and_(
                                FleaMarketItem.id == db_item_id,
                                FleaMarketItem.sold_task_id == task_id,
                                FleaMarketItem.status.in_(["active", "reserved"])
                            )
                        ).with_for_update().first()
                        if flea_item:
                            flea_item.status = "sold"
                            if flea_item.sold_task_id != task_id:
                                flea_item.sold_task_id = task_id
                            db.flush()
                            logger.info(f"✅ [WEBHOOK] 微信支付跳蚤市场商品 {flea_market_item_id} 状态已更新为 sold (task_id: {task_id})")
                            from app.flea_market_extensions import invalidate_item_cache
                            invalidate_item_cache(flea_item.id)
                            # 发送商品已售出通知
                            try:
                                item_title = flea_item.title or metadata.get("task_title", "商品")
                                crud.create_notification(
                                    db=db,
                                    user_id=flea_item.seller_id,
                                    type="flea_market_sold",
                                    title="商品已售出",
                                    content=f"「{item_title}」已售出！买家已完成付款，可以开始交易了",
                                    related_id=str(task_id),
                                    auto_commit=False,
                                )
                                buyer_id = metadata.get("user_id")
                                if buyer_id:
                                    crud.create_notification(
                                        db=db,
                                        user_id=str(buyer_id),
                                        type="flea_market_payment_success",
                                        title="支付成功",
                                        content=f"您已成功购买「{item_title}」，可以联系卖家进行交易",
                                        related_id=str(task_id),
                                        auto_commit=False,
                                    )
                            except Exception as notify_err:
                                logger.warning(f"⚠️ [WEBHOOK] 创建跳蚤市场售出通知失败: {notify_err}")
                        else:
                            logger.warning(f"⚠️ [WEBHOOK] 微信支付跳蚤市场商品 {flea_market_item_id} 未找到 (task_id: {task_id})")
                    except Exception as e:
                        logger.error(f"❌ [WEBHOOK] 微信支付更新跳蚤市场商品状态失败: {e}", exc_info=True)
                
                db.commit()
                
                # 记录微信支付完成（用于调试）
                if payment_type == "wechat_checkout":
                    logger.info(f"✅ [WEBHOOK] 微信支付完成 (iOS WebView): task_id={task_id}, escrow_amount={task.escrow_amount}")
                else:
                    logger.info(f"Task {task_id} payment completed via Stripe Checkout Session, status updated to in_progress, escrow_amount: {task.escrow_amount}")
    
    # 处理 Transfer 事件（转账给任务接受人）
    elif event_type == "transfer.paid":
        transfer = event_data
        transfer_id = transfer.get("id")
        transfer_record_id_str = transfer.get("metadata", {}).get("transfer_record_id")
        task_id = int(transfer.get("metadata", {}).get("task_id", 0))
        
        logger.info(f"✅ [WEBHOOK] Transfer 支付成功:")
        logger.info(f"  - Transfer ID: {transfer_id}")
        logger.info(f"  - Transfer Record ID: {transfer_record_id_str}")
        logger.info(f"  - Task ID: {task_id}")
        logger.info(f"  - Amount: {transfer.get('amount')} {transfer.get('currency')}")
        
        if transfer_record_id_str:
            transfer_record_id = int(transfer_record_id_str)
            transfer_record = db.query(models.PaymentTransfer).filter(
                models.PaymentTransfer.id == transfer_record_id
            ).first()
            
            if transfer_record:
                # 防止重复处理：检查是否已经成功
                if transfer_record.status == "succeeded":
                    logger.warning(f"⚠️ [WEBHOOK] Transfer 记录已成功，跳过重复处理: transfer_record_id={transfer_record_id}")
                else:
                    # 更新转账记录状态
                    from decimal import Decimal
                    transfer_record.status = "succeeded"
                    transfer_record.succeeded_at = get_utc_time()
                    transfer_record.last_error = None
                    transfer_record.next_retry_at = None
                    
                    # 更新任务状态
                    task = crud.get_task(db, transfer_record.task_id)
                    if task:
                        task.is_confirmed = 1
                        task.paid_to_user_id = transfer_record.taker_id
                        task.escrow_amount = Decimal('0.0')  # 转账后清空托管金额
                        logger.info(f"✅ [WEBHOOK] 任务 {task.id} 转账完成，金额已转给接受人 {transfer_record.taker_id}")
                        
                        # 发送通知给任务接收人：任务金已发放
                        try:
                            # 格式化金额（从 Decimal 转换为字符串，保留两位小数）
                            amount_display = f"£{float(transfer_record.amount):.2f}"
                            task_title = task.title or f"任务 #{task.id}"
                            
                            # 创建通知内容：任务金已发放（金额 - 任务标题）
                            notification_content = f"任务金已发放：{amount_display} - {task_title}"
                            
                            # 创建通知
                            crud.create_notification(
                                db=db,
                                user_id=transfer_record.taker_id,
                                type="task_reward_paid",  # 任务奖励已支付
                                title="任务金已发放",
                                content=notification_content,
                                related_id=str(task.id),  # 关联任务ID，方便前端跳转
                                auto_commit=False  # 不自动提交，等待下面的 db.commit()
                            )
                            
                            # 发送推送通知
                            try:
                                send_push_notification(
                                    db=db,
                                    user_id=transfer_record.taker_id,
                                    notification_type="task_reward_paid",
                                    data={"task_id": task.id, "amount": str(transfer_record.amount)},
                                    template_vars={"task_title": task.title, "task_id": task.id}
                                )
                            except Exception as e:
                                logger.warning(f"发送任务金发放推送通知失败: {e}")
                                # 推送通知失败不影响主流程
                            
                            logger.info(f"✅ [WEBHOOK] 已发送任务金发放通知给用户 {transfer_record.taker_id}")
                        except Exception as e:
                            # 通知发送失败不影响转账流程
                            logger.error(f"❌ [WEBHOOK] 发送任务金发放通知失败: {e}", exc_info=True)
                    
                    db.commit()
                    logger.info(f"✅ [WEBHOOK] Transfer 记录已更新为成功: transfer_record_id={transfer_record_id}")
            else:
                logger.warning(f"⚠️ [WEBHOOK] 未找到转账记录: transfer_record_id={transfer_record_id_str}")
        # 🔒 Fix W1: 处理钱包提现 Transfer（metadata 含 wallet_tx_id）
        elif transfer.get("metadata", {}).get("wallet_tx_id"):
            _w_tx_id = transfer["metadata"]["wallet_tx_id"]
            _w_user_id = transfer["metadata"].get("user_id", "")
            logger.info(
                f"✅ [WEBHOOK] 钱包提现 Transfer 成功: "
                f"transfer_id={transfer_id}, wallet_tx_id={_w_tx_id}, user={_w_user_id}"
            )
            try:
                from app.wallet_service import complete_withdrawal as _cw
                from app.wallet_models import WalletTransaction as _WT
                # 幂等：仅 pending 状态才更新
                _existing = db.query(_WT).filter(_WT.id == int(_w_tx_id)).first()
                if _existing and _existing.status == "pending":
                    _cw(db, int(_w_tx_id), transfer_id)
                    db.commit()
                    logger.info(f"✅ [WEBHOOK] 钱包提现已确认: wallet_tx_id={_w_tx_id}")
                elif _existing:
                    logger.info(f"ℹ️ [WEBHOOK] 钱包提现 tx 已是 {_existing.status}，跳过: wallet_tx_id={_w_tx_id}")
                else:
                    logger.error(f"❌ [WEBHOOK] 钱包提现 tx 不存在: wallet_tx_id={_w_tx_id}")
            except Exception as _w_err:
                logger.error(f"❌ [WEBHOOK] 确认钱包提现失败: wallet_tx_id={_w_tx_id}, error={_w_err}")
                db.rollback()
        else:
            logger.warning(f"⚠️ [WEBHOOK] Transfer metadata 中没有 transfer_record_id 或 wallet_tx_id")

    elif event_type == "transfer.failed":
        transfer = event_data
        transfer_id = transfer.get("id")
        transfer_record_id_str = transfer.get("metadata", {}).get("transfer_record_id")
        task_id = int(transfer.get("metadata", {}).get("task_id", 0))
        failure_code = transfer.get("failure_code", "unknown")
        failure_message = transfer.get("failure_message", "Unknown error")

        logger.warning(f"❌ [WEBHOOK] Transfer 支付失败:")
        logger.warning(f"  - Transfer ID: {transfer_id}")
        logger.warning(f"  - Transfer Record ID: {transfer_record_id_str}")
        logger.warning(f"  - Task ID: {task_id}")
        logger.warning(f"  - 失败代码: {failure_code}")
        logger.warning(f"  - 失败信息: {failure_message}")

        if transfer_record_id_str:
            transfer_record_id = int(transfer_record_id_str)
            transfer_record = db.query(models.PaymentTransfer).filter(
                models.PaymentTransfer.id == transfer_record_id
            ).first()

            if transfer_record:
                # 更新转账记录状态为失败
                transfer_record.status = "failed"
                transfer_record.last_error = f"{failure_code}: {failure_message}"
                transfer_record.next_retry_at = None

                # 不更新任务状态，保持原状

                db.commit()
                logger.info(f"✅ [WEBHOOK] Transfer 记录已更新为失败: transfer_record_id={transfer_record_id}")
            else:
                logger.warning(f"⚠️ [WEBHOOK] 未找到转账记录: transfer_record_id={transfer_record_id_str}")
        # 🔒 Fix W1: 处理钱包提现 Transfer 失败
        elif transfer.get("metadata", {}).get("wallet_tx_id"):
            _wf_tx_id = transfer["metadata"]["wallet_tx_id"]
            _wf_user_id = transfer["metadata"].get("user_id", "")
            logger.warning(
                f"❌ [WEBHOOK] 钱包提现 Transfer 失败: "
                f"transfer_id={transfer_id}, wallet_tx_id={_wf_tx_id}, user={_wf_user_id}, "
                f"failure={failure_code}: {failure_message}"
            )
            try:
                from app.wallet_service import fail_withdrawal as _fw
                from app.wallet_models import WalletTransaction as _WT2
                from decimal import Decimal as _Dec
                _fail_tx = db.query(_WT2).filter(_WT2.id == int(_wf_tx_id)).first()
                if _fail_tx and _fail_tx.status == "pending":
                    _refund_amount = abs(_fail_tx.amount)
                    # 用 DB 记录的 user_id，不信任 metadata（防御性）
                    _fw(db, int(_wf_tx_id), _fail_tx.user_id, _refund_amount, currency=_fail_tx.currency)
                    db.commit()
                    logger.info(f"✅ [WEBHOOK] 钱包提现失败，余额已退还: wallet_tx_id={_wf_tx_id}, amount={_refund_amount}")
                elif _fail_tx:
                    logger.info(f"ℹ️ [WEBHOOK] 钱包提现 tx 已是 {_fail_tx.status}，跳过: wallet_tx_id={_wf_tx_id}")
                else:
                    logger.error(f"❌ [WEBHOOK] 钱包提现 tx 不存在: wallet_tx_id={_wf_tx_id}")
            except Exception as _wf_err:
                logger.error(f"❌ [WEBHOOK] 退还钱包提现余额失败: wallet_tx_id={_wf_tx_id}, error={_wf_err}")
                db.rollback()
        else:
            logger.warning(f"⚠️ [WEBHOOK] Transfer metadata 中没有 transfer_record_id 或 wallet_tx_id")
    
    else:
        logger.info(f"ℹ️ [WEBHOOK] 未处理的事件类型: {event_type}")
        logger.info(f"  - 事件ID: {event_id}")
        # 只记录关键字段，避免日志过长
        event_summary = {}
        if isinstance(event_data, dict):
            for key in ['id', 'object', 'status', 'amount', 'currency']:
                if key in event_data:
                    event_summary[key] = event_data[key]
        logger.info(f"  - 事件数据摘要: {json.dumps(event_summary, ensure_ascii=False)}")
    
    # 标记事件处理完成
    if event_id:
        try:
            webhook_event = db.query(models.WebhookEvent).filter(
                models.WebhookEvent.event_id == event_id
            ).first()
            if webhook_event:
                webhook_event.processed = True
                webhook_event.processed_at = get_utc_time()
                webhook_event.processing_error = None
                db.commit()
                logger.debug(f"✅ [WEBHOOK] 事件处理完成，已标记: event_id={event_id}")
        except Exception as e:
            logger.error(f"❌ [WEBHOOK] 更新事件处理状态失败: {e}", exc_info=True)
            db.rollback()
    
    # 记录处理耗时和总结
    processing_time = time.time() - start_time
    logger.debug(f"⏱️ [WEBHOOK] 处理耗时: {processing_time:.3f} 秒")
    logger.info(f"✅ [WEBHOOK] Webhook 处理完成: {event_type}")
    logger.debug("=" * 80)
    
    return {"status": "success"}


@router.post("/tasks/{task_id}/confirm_complete")
def confirm_task_complete(
    task_id: int, current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    """
    [已弃用] 确认任务完成并通过 Stripe Transfer 直接转账给接受人的 Connect 账户。

    前端已切换到 POST /tasks/{task_id}/confirm_completion（钱包入账模式）。
    此端点仅供管理后台或特殊场景使用（如接受人要求直接 Stripe 到账）。
    自动结算由 auto_transfer_expired_tasks 定时任务处理。

    要求：
    1. 任务必须已支付
    2. 任务状态必须为 completed
    3. 任务接受人必须有 Stripe Connect 账户且已完成 onboarding
    """
    import logging

    logger = logging.getLogger(__name__)

    task = crud.get_task(db, task_id)
    if not task or task.poster_id != current_user.id:
        raise HTTPException(status_code=404, detail="Task not found or no permission.")
    if not task.is_paid or task.status != "completed" or task.is_confirmed:
        raise HTTPException(
            status_code=400, detail="Task not eligible for confirmation."
        )
    
    if not task.taker_id:
        raise HTTPException(
            status_code=400, detail="Task has no taker."
        )
    
    # 获取任务接受人信息
    taker = crud.get_user_by_id(db, task.taker_id)
    if not taker:
        raise HTTPException(
            status_code=404, detail="Task taker not found."
        )
    
    # 检查 escrow_amount 是否大于0
    if task.escrow_amount <= 0:
        raise HTTPException(
            status_code=400,
            detail="任务托管金额为0，无需转账。"
        )

    # 优先直接 Stripe Transfer（接单者有 Connect 账户时），否则入本地钱包
    try:
        # 确保 escrow_amount 正确（任务金额 - 平台服务费）
        if task.escrow_amount <= 0:
            task_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0
            from app.utils.fee_calculator import calculate_application_fee
            task_source = getattr(task, "task_source", None)
            task_type = getattr(task, "task_type", None)
            application_fee = calculate_application_fee(task_amount, task_source, task_type)
            task.escrow_amount = max(0.0, task_amount - application_fee)
            logger.info(f"重新计算 escrow_amount: 任务金额={task_amount}, 服务费={application_fee}, escrow={task.escrow_amount}")

        escrow_amount = Decimal(str(task.escrow_amount))
        currency = (task.currency or "GBP").upper()
        payout_idempotency_key = f"earning:task:{task_id}:user:{taker.id}"

        if taker.stripe_account_id:
            # 有 Stripe Connect 账户 → 尝试直接转账，失败则回退到钱包
            amount_minor = int(escrow_amount * 100)
            try:
                stripe_transfer = stripe.Transfer.create(
                    amount=amount_minor,
                    currency=currency.lower(),
                    destination=taker.stripe_account_id,
                    description=f"Task #{task_id} payout",
                    metadata={"task_id": str(task_id), "taker_id": str(taker.id)},
                    idempotency_key=payout_idempotency_key,
                )
                logger.info(f"✅ 直接 Stripe Transfer: task={task_id}, transfer={stripe_transfer.id}, amount=£{escrow_amount:.2f}")
                payout_method = "stripe_transfer"
            except stripe.error.StripeError as stripe_err:
                # Stripe 明确拒绝 → 回退到钱包
                logger.warning(f"任务 {task_id} Stripe Transfer 被拒绝，回退到钱包入账: {stripe_err}")
                from app.wallet_service import credit_wallet
                credit_wallet(
                    db,
                    user_id=taker.id,
                    amount=escrow_amount,
                    source="task_earning",
                    related_id=str(task_id),
                    related_type="task",
                    description=f"任务 #{task_id} 收入（Stripe失败回退）",
                    currency=currency,
                    idempotency_key=payout_idempotency_key,
                )
                payout_method = "wallet_fallback"
        else:
            # 无 Stripe Connect 账户 → 入本地钱包
            from app.wallet_service import credit_wallet
            credit_wallet(
                db,
                user_id=taker.id,
                amount=escrow_amount,
                source="task_earning",
                related_id=str(task_id),
                related_type="task",
                description=f"任务 #{task_id} 收入 - {task.title}",
                currency=currency,
                idempotency_key=payout_idempotency_key,
            )
            logger.info(f"✅ 钱包入账: task={task_id}, amount=£{escrow_amount:.2f}（用户无 Stripe Connect）")
            payout_method = "wallet"

        # 更新任务状态
        task.is_confirmed = 1
        task.paid_to_user_id = task.taker_id
        transfer_amount = task.escrow_amount  # 先保存转账金额
        task.escrow_amount = 0.0  # 入账后清空托管金额

        db.commit()

        return {
            "message": f"Payment sent via {payout_method}.",
            "amount": transfer_amount,
            "currency": currency
        }

    except Exception as e:
        logger.error(f"Error confirming task {task_id}: {e}")
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="确认任务完成时发生错误，请重试。"
        )


# 已迁移到 admin_task_management_routes.py: /admin/tasks, /admin/tasks/{task_id}, /admin/tasks/batch-update, /admin/tasks/batch-delete


# 管理员处理客服请求相关API
@router.get("/admin/customer-service-requests")
@cache_response(ttl=60, key_prefix="admin_cs_requests")
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

    requester_ids = {r.requester_id for r in requests if r.requester_id}
    cs_map = {}
    if requester_ids:
        cs_list = db.query(CustomerService).filter(CustomerService.id.in_(requester_ids)).all()
        cs_map = {cs.id: cs for cs in cs_list}

    result = []
    for request in requests:
        cs = cs_map.get(request.requester_id)
        request_dict = {
            "id": request.id,
            "requester_id": request.requester_id,
            "requester_name": cs.name if cs else "未知客服",
            "type": request.type,
            "title": request.title,
            "description": request.description,
            "priority": request.priority,
            "status": request.status,
            "admin_response": request.admin_response,
            "admin_id": request.admin_id,
            "created_at": format_iso_utc(request.created_at) if request.created_at else None,
            "updated_at": format_iso_utc(request.updated_at) if request.updated_at else None,
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
        "request": {
            "id": request.id,
            "requester_id": request.requester_id,
            "type": request.type,
            "title": request.title,
            "description": request.description,
            "priority": request.priority,
            "status": request.status,
            "admin_response": request.admin_response,
            "admin_id": request.admin_id,
            "created_at": format_iso_utc(request.created_at) if request.created_at else None,
            "updated_at": format_iso_utc(request.updated_at) if request.updated_at else None,
        },
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

    return {
        "message": "Request updated successfully",
        "request": {
            "id": request.id,
            "requester_id": request.requester_id,
            "type": request.type,
            "title": request.title,
            "description": request.description,
            "priority": request.priority,
            "status": request.status,
            "admin_response": request.admin_response,
            "admin_id": request.admin_id,
            "created_at": format_iso_utc(request.created_at) if request.created_at else None,
            "updated_at": format_iso_utc(request.updated_at) if request.updated_at else None,
        },
    }


@router.get("/admin/customer-service-chat")
def admin_get_customer_service_chat_messages(
    current_user=Depends(get_current_admin), db: Session = Depends(get_db)
):
    """管理员获取与客服的聊天记录"""
    from app.models import AdminChatMessage, CustomerService

    messages = (
        db.query(AdminChatMessage).order_by(AdminChatMessage.created_at.asc()).all()
    )

    cs_sender_ids = {m.sender_id for m in messages if m.sender_type == "customer_service" and m.sender_id}
    cs_map = {}
    if cs_sender_ids:
        cs_list = db.query(CustomerService).filter(CustomerService.id.in_(cs_sender_ids)).all()
        cs_map = {cs.id: cs for cs in cs_list}

    result = []
    for message in messages:
        sender_name = None
        if message.sender_type == "customer_service" and message.sender_id:
            cs = cs_map.get(message.sender_id)
            sender_name = cs.name if cs else "未知客服"
        elif message.sender_type == "admin" and message.sender_id:
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

    return {
        "message": "Message sent successfully",
        "chat_message": {
            "id": chat_message.id,
            "sender_id": chat_message.sender_id,
            "sender_type": chat_message.sender_type,
            "content": chat_message.content,
            "created_at": format_iso_utc(chat_message.created_at) if chat_message.created_at else None,
        },
    }


# 已迁移到 admin_payment_routes.py: /admin/payments


@router.get("/contacts")
@measure_api_performance("get_contacts")
@cache_response(ttl=180, key_prefix="user_contacts")  # 缓存3分钟
def get_contacts(current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)):
    try:
        from app.models import Message, User
        
        logger.debug(f"开始获取联系人，用户ID: {current_user.id}")

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
        
        logger.debug(f"找到 {len(contact_ids)} 个联系人ID: {list(contact_ids)}")

        if not contact_ids:
            logger.debug("没有找到联系人，返回空列表")
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
                logger.debug(f"添加联系人: {contact_info['name']} (ID: {contact_info['id']})")
        
        # 按最新消息时间排序
        contacts_with_last_message.sort(
            key=lambda x: x["last_message_time"] or "1970-01-01T00:00:00", 
            reverse=True
        )

        logger.debug(f"成功获取 {len(contacts_with_last_message)} 个联系人")
        return contacts_with_last_message
        
    except Exception as e:
        logger.warning(f"contacts API发生错误: {e}", exc_info=True)
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
            Task.is_visible == True,
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


# 已迁移到 admin_task_management_routes.py: /admin/cancel-requests, /admin/cancel-requests/{request_id}/review


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
            # 限制查询数量，防止内存溢出（最多查询1000个客服）
            all_services = db.query(CustomerService).limit(1000).all()
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
                from app.websocket_manager import get_ws_manager
                
                ws_manager = get_ws_manager()
                notification_message = {
                    "type": "user_connected",
                    "user_info": {
                        "id": current_user.id,
                        "name": current_user.name or f"用户{current_user.id}",
                    },
                    "chat_id": chat_data["chat_id"],
                    "timestamp": format_iso_utc(get_utc_time()),
                }
                # 使用 WebSocketManager 发送消息
                asyncio.create_task(
                    ws_manager.send_to_user(service.id, notification_message)
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


@router.get("/user/customer-service/availability")
def check_customer_service_availability(
    current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    """检查人工客服是否有在线的"""
    from app.models import CustomerService
    from sqlalchemy import cast, Integer
    online_count = db.query(func.count(CustomerService.id)).filter(
        cast(CustomerService.is_online, Integer) == 1
    ).scalar() or 0
    return {"available": online_count > 0, "online_count": online_count}


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
        
        # 清理僵尸对话：自动结束那些创建时间超过10分钟且只有系统消息的对话
        try:
            from app.models import CustomerServiceChat, CustomerServiceMessage
            from app.utils.time_utils import get_utc_time
            from datetime import timedelta
            from sqlalchemy import func
            
            now = get_utc_time()
            threshold_time = now - timedelta(minutes=10)  # 10分钟阈值
            
            # 查找所有进行中的对话
            active_chats = (
                db.query(CustomerServiceChat)
                .filter(
                    CustomerServiceChat.service_id == current_user.id,
                    CustomerServiceChat.is_ended == 0,
                    CustomerServiceChat.created_at < threshold_time
                )
                .all()
            )
            
            cleaned_count = 0
            for chat in active_chats:
                # 检查是否有非系统消息
                has_real_message = (
                    db.query(CustomerServiceMessage)
                    .filter(
                        CustomerServiceMessage.chat_id == chat.chat_id,
                        CustomerServiceMessage.sender_type != 'system'
                    )
                    .first()
                ) is not None
                
                # 如果只有系统消息，自动结束对话
                if not has_real_message:
                    chat.is_ended = 1
                    chat.ended_at = now
                    chat.ended_reason = "auto_cleanup"
                    chat.ended_by = "system"
                    chat.ended_type = "auto"
                    cleaned_count += 1
                    logger.info(f"[CUSTOMER_SERVICE] 自动清理僵尸对话: {chat.chat_id}")
            
            if cleaned_count > 0:
                db.commit()
                logger.info(f"[CUSTOMER_SERVICE] 客服上线时清理了 {cleaned_count} 个僵尸对话")
        except Exception as cleanup_error:
            logger.warning(f"[CUSTOMER_SERVICE] 清理僵尸对话时出错: {cleanup_error}")
            # 不影响上线操作，继续执行
        
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
            from app.websocket_manager import get_ws_manager
            ws_manager = get_ws_manager()
            
            # 构建消息响应
            message_response = {
                "type": "cs_message",
                "from": current_user.id,
                "receiver_id": chat["user_id"],
                "content": message["content"],
                "created_at": str(message["created_at"]),
                "sender_type": "customer_service",
                "original_sender_id": current_user.id,
                "chat_id": chat_id,
                "message_id": message["id"],
            }
            
            # 使用 WebSocketManager 发送消息
            success = await ws_manager.send_to_user(chat["user_id"], message_response)
            if success:
                logger.info(f"Customer service message sent to user {chat['user_id']} via WebSocket")
            else:
                logger.debug(f"User {chat['user_id']} not connected via WebSocket")
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
    background_tasks: BackgroundTasks = BackgroundTasks(),
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

    # 通过WebSocket实时推送给客服（使用后台任务异步发送）
    async def send_websocket_message():
        try:
            from app.websocket_manager import get_ws_manager
            ws_manager = get_ws_manager()

            message_response = {
                "id": message["id"],
                "type": "cs_message",
                "from": current_user.id,
                "receiver_id": chat["service_id"],
                "content": message["content"],
                "created_at": str(message["created_at"]),
                "sender_type": "user",
                "original_sender_id": current_user.id,
                "chat_id": chat_id,
                "message_id": message["id"],
            }

            success = await ws_manager.send_to_user(chat["service_id"], message_response)
            if success:
                logger.info(f"User message sent to CS {chat['service_id']} via WebSocket")
            else:
                logger.debug(f"CS {chat['service_id']} not connected via WebSocket")
        except Exception as e:
            logger.error(f"Failed to push user message to CS via WebSocket: {e}")

    background_tasks.add_task(send_websocket_message)

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
        # 使用流式读取文件内容，避免大文件一次性读入内存
        from app.file_stream_utils import read_file_with_size_check
        
        # 优化：先尝试从Content-Type检测文件类型（最快，不需要读取文件）
        # 这对于iOS上传特别有用，因为iOS会设置正确的Content-Type
        content_type = (file.content_type or "").lower()
        is_image_from_type = any(ext in content_type for ext in ['jpeg', 'jpg', 'png', 'gif', 'webp'])
        is_document_from_type = any(ext in content_type for ext in ['pdf', 'msword', 'word', 'plain'])
        
        # 从filename检测（如果filename存在）
        from app.file_utils import get_file_extension_from_filename
        file_ext = get_file_extension_from_filename(file.filename)
        is_image = file_ext in ALLOWED_EXTENSIONS or is_image_from_type
        is_document = file_ext in {".pdf", ".doc", ".docx", ".txt"} or is_document_from_type
        
        # 如果还是无法确定，先读取少量内容用于magic bytes检测
        # 注意：FastAPI的UploadFile不支持seek，所以我们需要在流式读取时处理
        # 这里先不读取，等流式读取时再检测
        
        if not (is_image or is_document):
            raise HTTPException(
                status_code=400,
                detail=f"不支持的文件类型。允许的类型: 图片({', '.join(ALLOWED_EXTENSIONS)}), 文档(pdf, doc, docx, txt)"
            )
        
        # 确定最大文件大小
        max_size = MAX_FILE_SIZE if is_image else MAX_FILE_SIZE_LARGE
        
        # 流式读取文件内容
        content, file_size = await read_file_with_size_check(file, max_size)
        
        # 最终验证：使用完整内容再次检测（确保准确性）
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
        # 优化：先尝试从Content-Type检测文件类型（最快，不需要读取文件）
        # 这对于iOS上传特别有用，因为iOS会设置正确的Content-Type
        content_type = (file.content_type or "").lower()
        is_image_from_type = any(ext in content_type for ext in ['jpeg', 'jpg', 'png', 'gif', 'webp'])
        is_document_from_type = any(ext in content_type for ext in ['pdf', 'msword', 'word', 'plain'])
        
        # 从filename检测（如果filename存在）
        file_ext = None
        if file.filename:
            file_ext = Path(file.filename).suffix.lower()
        else:
            # 如果没有filename，尝试从Content-Type推断
            if is_image_from_type:
                file_ext = ".jpg"  # 默认使用jpg
            elif is_document_from_type:
                file_ext = ".pdf"  # 默认使用pdf
        
        # 检查是否为危险文件类型
        if file_ext and file_ext in DANGEROUS_EXTENSIONS:
            raise HTTPException(status_code=400, detail=f"不允许上传 {file_ext} 类型的文件")
        
        # 判断文件类型（图片或文档）
        is_image = (file_ext and file_ext in ALLOWED_EXTENSIONS) or is_image_from_type
        is_document = (file_ext and file_ext in {".pdf", ".doc", ".docx", ".txt"}) or is_document_from_type
        
        if not (is_image or is_document):
            raise HTTPException(
                status_code=400,
                detail=f"不支持的文件类型。允许的类型: 图片({', '.join(ALLOWED_EXTENSIONS)}), 文档(pdf, doc, docx, txt)"
            )
        
        # 使用流式读取文件内容，避免大文件一次性读入内存
        from app.file_stream_utils import read_file_with_size_check
        
        # 确定最大文件大小
        max_size = MAX_FILE_SIZE if is_image else MAX_FILE_SIZE_LARGE
        
        # 流式读取文件内容
        content, file_size = await read_file_with_size_check(file, max_size)
        
        # 最终验证：使用完整内容再次检测（确保准确性）
        from app.file_utils import get_file_extension_from_upload
        file_ext = get_file_extension_from_upload(file, content=content)
        
        # 如果无法检测到扩展名
        if not file_ext:
            raise HTTPException(
                status_code=400,
                detail="无法检测文件类型，请确保上传的是有效的文件（图片或文档）"
            )
        
        # 再次检查是否为危险文件类型（使用最终检测结果）
        if file_ext in DANGEROUS_EXTENSIONS:
            raise HTTPException(status_code=400, detail=f"不允许上传 {file_ext} 类型的文件")
        
        # 流式读取文件内容
        content, file_size = await read_file_with_size_check(file, max_size)
        
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

    # 批量加载任务和用户，避免 N+1 查询
    task_ids = list({r.task_id for r in requests})
    requester_ids = list({r.requester_id for r in requests})
    task_map = {t.id: t for t in db.query(Task).filter(Task.id.in_(task_ids)).all()} if task_ids else {}
    user_map = {u.id: u for u in db.query(User).filter(User.id.in_(requester_ids)).all()} if requester_ids else {}

    result = []
    for req in requests:
        task = task_map.get(req.task_id)
        requester = user_map.get(req.requester_id)

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
            "created_at": format_iso_utc(req.created_at) if req.created_at else None,
            "reviewed_at": format_iso_utc(req.reviewed_at) if req.reviewed_at else None,
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
            
            # ⚠️ 清除任务缓存，确保前端立即看到更新后的状态
            try:
                from app.services.task_service import TaskService
                TaskService.invalidate_cache(cancel_request.task_id)
                from app.redis_cache import invalidate_tasks_cache
                invalidate_tasks_cache()
                logger.info(f"✅ 已清除任务 {cancel_request.task_id} 的缓存（客服审核取消）")
            except Exception as e:
                logger.warning(f"⚠️ 清除任务缓存失败: {e}")

            # 通知请求者
            crud.create_notification(
                db,
                cancel_request.requester_id,
                "cancel_request_approved",
                "取消请求已通过",
                f'您的任务 "{task.title}" 取消请求已通过审核',
                task.id,
            )
            
            # 发送推送通知给请求者
            try:
                send_push_notification(
                    db=db,
                    user_id=cancel_request.requester_id,
                    notification_type="cancel_request_approved",
                    data={"task_id": task.id},
                    template_vars={"task_title": task.title, "task_id": task.id}
                )
            except Exception as e:
                logger.warning(f"发送取消请求通过推送通知失败: {e}")
                # 推送通知失败不影响主流程

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
                
                # 发送推送通知给另一方
                try:
                    send_push_notification(
                        db=db,
                        user_id=other_user_id,
                        notification_type="task_cancelled",
                        data={"task_id": task.id},
                        template_vars={"task_title": task.title, "task_id": task.id}
                    )
                except Exception as e:
                    logger.warning(f"发送任务取消推送通知失败: {e}")
                    # 推送通知失败不影响主流程

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
            
            # 发送推送通知给请求者
            try:
                send_push_notification(
                    db=db,
                    user_id=cancel_request.requester_id,
                    notification_type="cancel_request_rejected",
                    data={"task_id": task.id},
                    template_vars={"task_title": task.title, "task_id": task.id}
                )
            except Exception as e:
                logger.warning(f"发送取消请求拒绝推送通知失败: {e}")
                # 推送通知失败不影响主流程

    return {
        "message": f"Cancel request {review.status}",
        "request": {
            "id": updated_request.id,
            "task_id": updated_request.task_id,
            "requester_id": updated_request.requester_id,
            "reason": updated_request.reason,
            "status": updated_request.status,
            "admin_id": updated_request.admin_id,
            "service_id": updated_request.service_id,
            "admin_comment": updated_request.admin_comment,
            "created_at": format_iso_utc(updated_request.created_at) if updated_request.created_at else None,
            "reviewed_at": format_iso_utc(updated_request.reviewed_at) if updated_request.reviewed_at else None,
        },
    }


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
    """获取公开的平台统计数据（用户总数、成功匹配并完成的任务数）"""
    try:
        total_users = db.query(models.User).count()
        completed_tasks = db.query(models.Task).filter(models.Task.status == "completed").count()
        return {
            "total_users": total_users,
            "completed_tasks": completed_tasks,
        }
    except Exception as e:
        logger.error(f"Error in get_public_stats: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


# 已迁移到 admin_user_management_routes.py: /admin/dashboard/stats, /admin/users, /admin/users/{user_id}, /admin/admin-users, /admin/admin-user
# 已迁移到 admin_notification_routes.py: /admin/staff-notification, /staff/notifications, /admin/notifications/send
# 已迁移到 admin_customer_service_routes.py: /admin/customer-service, /admin/customer-service/{cs_id}/notify
# 已迁移到 admin_task_management_routes.py: /admin/tasks/{task_id}
# 已迁移到 admin_system_routes.py: /admin/system-settings


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


@router.post("/users/vip/activate")
@rate_limit("vip_activate")
def activate_vip(
    http_request: Request,
    activation_request: schemas.VIPActivationRequest,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """激活VIP会员（通过IAP购买）- 生产级实现"""
    from app.iap_verification_service import iap_verification_service
    from datetime import datetime, timezone

    request = activation_request
    try:
        # 1. 验证产品ID
        if not iap_verification_service.validate_product_id(request.product_id):
            raise HTTPException(status_code=400, detail="无效的产品ID")
        
        # 2. 验证交易JWS
        try:
            transaction_info = iap_verification_service.verify_transaction_jws(request.transaction_jws)
        except ValueError as e:
            logger.error(f"JWS验证失败: {str(e)}")
            raise HTTPException(status_code=400, detail=f"交易验证失败: {str(e)}")
        
        # 3. 验证交易ID是否匹配
        if transaction_info["transaction_id"] != request.transaction_id:
            raise HTTPException(status_code=400, detail="交易ID不匹配")
        
        # 4. 验证产品ID是否匹配
        if transaction_info["product_id"] != request.product_id:
            raise HTTPException(status_code=400, detail="产品ID不匹配")
        
        # 5. 检查是否已经处理过这个交易（防止重复激活）
        existing_subscription = crud.get_vip_subscription_by_transaction_id(db, request.transaction_id)
        if existing_subscription:
            logger.warning(f"交易 {request.transaction_id} 已被处理过，用户: {existing_subscription.user_id}")
            # 如果交易已存在，检查是否是同一用户
            if existing_subscription.user_id != current_user.id:
                raise HTTPException(status_code=400, detail="该交易已被其他用户使用")
            # 如果是同一用户，返回现有订阅信息
            return {
                "message": "VIP已激活（重复请求）",
                "user_level": current_user.user_level,
                "product_id": request.product_id,
                "subscription_id": existing_subscription.id
            }
        
        # 6. 从Apple服务器获取交易信息（可选，用于额外验证）
        server_transaction_info = None
        try:
            server_transaction_info = iap_verification_service.get_transaction_info(
                request.transaction_id,
                transaction_info["environment"]
            )
            if server_transaction_info:
                logger.info(f"从Apple服务器获取交易信息成功: {request.transaction_id}")
        except Exception as e:
            logger.warning(f"从Apple服务器获取交易信息失败（继续处理）: {str(e)}")
        
        # 7. 转换时间戳
        purchase_date = iap_verification_service.convert_timestamp_to_datetime(
            transaction_info["purchase_date"]
        )
        expires_date = None
        if transaction_info["expires_date"]:
            expires_date = iap_verification_service.convert_timestamp_to_datetime(
                transaction_info["expires_date"]
            )
        
        # 8. 创建VIP订阅记录
        subscription = crud.create_vip_subscription(
            db=db,
            user_id=current_user.id,
            product_id=request.product_id,
            transaction_id=request.transaction_id,
            original_transaction_id=transaction_info.get("original_transaction_id"),
            transaction_jws=request.transaction_jws,
            purchase_date=purchase_date,
            expires_date=expires_date,
            is_trial_period=transaction_info["is_trial_period"],
            is_in_intro_offer_period=transaction_info["is_in_intro_offer_period"],
            environment=transaction_info["environment"],
            status="active"
        )
        
        # 8.1 若为同一条订阅线升级（如月订→年订），将旧订阅标记为 replaced，与 Apple 状态一致
        otid = transaction_info.get("original_transaction_id")
        if otid:
            crud.mark_replaced_by_upgrade(
                db, current_user.id, otid, request.transaction_id
            )
        
        # 9. 更新用户VIP状态
        # 根据产品ID确定VIP类型
        user_level = "vip"
        if request.product_id == "com.link2ur.vip.yearly":
            # 年度订阅可以设置为super VIP（根据业务需求）
            user_level = "vip"  # 或 "super"
        
        crud.update_user_vip_status(db, current_user.id, user_level)
        try:
            from app.vip_subscription_service import vip_subscription_service
            vip_subscription_service.invalidate_vip_cache(current_user.id)
        except Exception as e:
            logger.debug("VIP cache invalidate: %s", e)

        # 10. 记录日志
        logger.info(
            f"用户 {current_user.id} 通过IAP激活VIP成功: "
            f"产品ID={request.product_id}, "
            f"交易ID={request.transaction_id}, "
            f"订阅ID={subscription.id}, "
            f"环境={transaction_info['environment']}"
        )
        
        # 11. 发送通知（可选）
        try:
            from app.push_notification_service import send_push_notification
            send_push_notification(
                db=db,
                user_id=current_user.id,
                notification_type="vip_activated",
                data={"type": "vip_activated", "subscription_id": subscription.id}
            )
        except Exception as e:
            logger.warning(f"发送VIP激活通知失败: {str(e)}")
        
        return {
            "message": "VIP激活成功",
            "user_level": user_level,
            "product_id": request.product_id,
            "subscription_id": subscription.id,
            "expires_date": expires_date.isoformat() if expires_date else None
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"激活VIP失败: {str(e)}", exc_info=True)
        db.rollback()
        raise HTTPException(status_code=500, detail=f"激活VIP失败: {str(e)}")


@router.get("/users/vip/status")
def get_vip_status(
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """获取当前用户的VIP订阅状态（带缓存）"""
    from app.vip_subscription_service import vip_subscription_service

    subscription_status = vip_subscription_service.check_subscription_status_cached(
        db, current_user.id
    )
    return {
        "user_level": current_user.user_level,
        "is_vip": current_user.user_level in ["vip", "super"],
        "subscription": subscription_status
    }


@router.get("/users/vip/history")
def get_vip_history(
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0, le=100000)
):
    """获取当前用户的VIP订阅历史"""
    rows = crud.get_vip_subscription_history(db, current_user.id, limit=limit, offset=offset)
    total = crud.count_vip_subscriptions_by_user(db, current_user.id)
    items = []
    for s in rows:
        items.append({
            "id": s.id,
            "product_id": s.product_id,
            "transaction_id": s.transaction_id,
            "purchase_date": s.purchase_date.isoformat() if s.purchase_date else None,
            "expires_date": s.expires_date.isoformat() if s.expires_date else None,
            "status": s.status,
            "environment": s.environment,
            "is_trial_period": s.is_trial_period,
            "is_in_intro_offer_period": s.is_in_intro_offer_period,
            "auto_renew_status": s.auto_renew_status,
        })
    return {"items": items, "total": total}


@router.post("/webhooks/apple-iap")
async def apple_iap_webhook(
    request: Request,
    db: Session = Depends(get_db)
):
    """
    Apple IAP Webhook端点
    处理 App Store Server Notifications V2（signedPayload 验证）及 V1 兼容。
    """
    from app.vip_subscription_service import vip_subscription_service
    from app.apple_webhook_verifier import verify_and_decode_notification

    try:
        body = await request.json()
    except Exception as e:
        logger.warning("Apple IAP Webhook 无效 JSON: %s", e)
        return JSONResponse(status_code=400, content={"status": "error", "message": "Invalid JSON"})

    reject_v1 = os.getenv("APPLE_IAP_WEBHOOK_REJECT_V1", "true").lower() == "true"

    try:
        if "signedPayload" in body:
            signed_payload = body["signedPayload"]
            decoded = verify_and_decode_notification(signed_payload)
            if not decoded:
                logger.warning("Apple IAP Webhook V2 签名验证失败或未配置")
                return JSONResponse(
                    status_code=401,
                    content={"status": "error", "message": "Verification failed"},
                )
            notification_type = decoded.get("notificationType") or ""
            data = decoded.get("data") or {}
            logger.info("Apple IAP Webhook V2 已验证: %s", notification_type)

            if notification_type == "SUBSCRIBED":
                logger.info("V2 新订阅通知（激活由 /users/vip/activate 处理）")
            elif notification_type == "DID_RENEW":
                jws = data.get("signedTransactionInfo")
                if jws:
                    _handle_v2_renewal(db, vip_subscription_service, jws)
                else:
                    logger.warning("V2 DID_RENEW 缺少 signedTransactionInfo")
            elif notification_type == "DID_FAIL_TO_RENEW":
                logger.warning("V2 订阅续费失败")
            elif notification_type == "CANCEL":
                jws = data.get("signedTransactionInfo")
                if jws:
                    _handle_v2_cancel(db, vip_subscription_service, jws)
            elif notification_type == "DID_CHANGE_RENEWAL_STATUS":
                logger.info("V2 续订状态变更")
            elif notification_type == "EXPIRED":
                jws = data.get("signedTransactionInfo")
                if jws:
                    _handle_v2_expired(db, vip_subscription_service, jws)
            elif notification_type == "REFUND":
                jws = data.get("signedTransactionInfo")
                if jws:
                    _handle_v2_refund(db, vip_subscription_service, jws)
            elif notification_type == "REVOKE":
                jws = data.get("signedTransactionInfo")
                if jws:
                    _handle_v2_revoke(db, vip_subscription_service, jws)
            elif notification_type == "GRACE_PERIOD_EXPIRED":
                logger.warning("V2 宽限期已过期")
            elif notification_type == "OFFER_REDEEMED":
                logger.info("V2 优惠兑换")
            elif notification_type == "DID_CHANGE_RENEWAL_PREF":
                logger.info("V2 续订偏好变更")
            elif notification_type == "RENEWAL_EXTENDED":
                logger.info("V2 续订已延长")
            elif notification_type == "TEST":
                logger.info("V2 测试通知")
            else:
                logger.info("V2 未处理类型: %s", notification_type)
            return {"status": "success"}

        notification_type = body.get("notification_type")
        if notification_type is not None:
            if reject_v1:
                logger.warning("拒绝未验证的 V1 Webhook（APPLE_IAP_WEBHOOK_REJECT_V1=true）")
                return JSONResponse(
                    status_code=400,
                    content={"status": "error", "message": "V1 notifications rejected"},
                )
            unified_receipt = body.get("unified_receipt", {})
            latest_receipt_info = unified_receipt.get("latest_receipt_info", [])
            logger.info("Apple IAP Webhook V1（未验证）: %s", notification_type)

            if notification_type == "INITIAL_BUY":
                logger.info("V1 初始购买")
            elif notification_type == "DID_RENEW" and latest_receipt_info:
                lt = latest_receipt_info[-1]
                orig = lt.get("original_transaction_id")
                tid = lt.get("transaction_id")
                logger.info("V1 续费: %s -> %s（无 JWS，仅记录）", orig, tid)
            elif notification_type == "DID_FAIL_TO_RENEW":
                logger.warning("V1 续费失败")
            elif notification_type == "CANCEL" and latest_receipt_info:
                lt = latest_receipt_info[-1]
                tid = lt.get("transaction_id")
                reason = lt.get("cancellation_reason")
                if tid:
                    vip_subscription_service.cancel_subscription(db, tid, reason)
            elif notification_type == "REFUND" and latest_receipt_info:
                lt = latest_receipt_info[-1]
                tid = lt.get("transaction_id")
                if tid:
                    vip_subscription_service.process_refund(db, tid, "Apple退款")

            return {"status": "success"}

        logger.warning("Apple IAP Webhook 无法识别格式（无 signedPayload 且无 notification_type）")
        return JSONResponse(status_code=400, content={"status": "error", "message": "Unknown payload"})
    except Exception as e:
        logger.error("处理Apple IAP Webhook失败: %s", e, exc_info=True)
        return JSONResponse(
            status_code=500,
            content={"status": "error", "message": str(e)},
        )


def _decode_jws_transaction(jws: str):
    """解析 JWS 获取 transactionId、originalTransactionId。"""
    from app.iap_verification_service import iap_verification_service
    try:
        info = iap_verification_service.verify_transaction_jws(jws)
        return info
    except Exception:
        return None


def _handle_v2_renewal(db, vip_subscription_service, jws: str):
    info = _decode_jws_transaction(jws)
    if not info:
        logger.warning("V2 DID_RENEW 解析 JWS 失败")
        return
    otid = info.get("original_transaction_id") or info.get("transaction_id")
    tid = info.get("transaction_id")
    vip_subscription_service.process_subscription_renewal(db, otid, tid, jws)


def _handle_v2_cancel(db, vip_subscription_service, jws: str):
    info = _decode_jws_transaction(jws)
    if not info:
        return
    tid = info.get("transaction_id")
    if tid:
        vip_subscription_service.cancel_subscription(db, tid, "Apple 取消")


def _handle_v2_expired(db, vip_subscription_service, jws: str):
    info = _decode_jws_transaction(jws)
    if not info:
        return
    tid = info.get("transaction_id")
    sub = crud.get_vip_subscription_by_transaction_id(db, tid)
    if sub and sub.status == "active":
        crud.update_vip_subscription_status(db, sub.id, "expired")
        active = crud.get_active_vip_subscription(db, sub.user_id)
        if not active:
            crud.update_user_vip_status(db, sub.user_id, "normal")
        vip_subscription_service.invalidate_vip_cache(sub.user_id)


def _handle_v2_refund(db, vip_subscription_service, jws: str):
    info = _decode_jws_transaction(jws)
    if not info:
        return
    tid = info.get("transaction_id")
    vip_subscription_service.process_refund(db, tid, "Apple退款")


def _handle_v2_revoke(db, vip_subscription_service, jws: str):
    info = _decode_jws_transaction(jws)
    if not info:
        return
    tid = info.get("transaction_id")
    vip_subscription_service.process_refund(db, tid, "Apple撤销")


# 用户任务偏好相关API
@router.get("/user-preferences")
def get_user_preferences(
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """获取用户任务偏好"""
    from app.models import UserProfilePreference

    preferences = db.query(UserProfilePreference).filter(UserProfilePreference.user_id == current_user.id).first()

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
        "task_types": preferences.task_types or [],
        "locations": preferences.locations or [],
        "task_levels": preferences.task_levels or [],
        "keywords": preferences.keywords or [],
        "min_deadline_days": preferences.min_deadline_days
    }


@router.put("/user-preferences")
def update_user_preferences(
    preferences_data: dict,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """更新用户任务偏好"""
    from app.models import UserProfilePreference

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
    preferences = db.query(UserProfilePreference).filter(UserProfilePreference.user_id == current_user.id).first()

    if not preferences:
        preferences = UserProfilePreference(user_id=current_user.id)
        db.add(preferences)

    # 更新偏好数据 (JSON columns, store as native lists)
    preferences.task_types = task_types if task_types else None
    preferences.locations = locations if locations else None
    preferences.task_levels = task_levels if task_levels else None
    preferences.keywords = keywords if keywords else None
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
            related_id=chat["id"],
        )

        # 通过WebSocket通知用户对话已结束
        try:
            from app.websocket_manager import get_ws_manager
            ws_manager = get_ws_manager()
            
            timeout_message = {
                "type": "chat_timeout",
                "chat_id": chat_id,
                "content": "由于长时间没有收到你的信息，本次对话已结束"
            }
            
            success = await ws_manager.send_to_user(chat["user_id"], timeout_message)
            if success:
                logger.info(f"已通过WebSocket发送超时消息给用户 {chat['user_id']}")
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
        # 使用流式读取文件内容，避免大文件一次性读入内存
        from app.file_stream_utils import read_file_with_size_check
        
        # 图片最大大小：5MB
        MAX_IMAGE_SIZE = 5 * 1024 * 1024
        
        # 流式读取文件内容
        content, file_size = await read_file_with_size_check(image, MAX_IMAGE_SIZE)
        
        # 使用新的私密图片系统上传
        from app.image_system import private_image_system
        result = private_image_system.upload_image(content, image.filename, current_user.id, db, task_id=task_id, chat_id=chat_id, content_type=image.content_type)
        
        # 生成图片访问 URL（确保总是返回 URL，否则 iOS 无法解析并继续发送消息）
        if result.get("success") and result.get("image_id"):
            participants = []
            try:
                # 如果有 task_id，获取任务参与者
                if task_id:
                    task = crud.get_task(db, task_id)
                    if task:
                        if task.poster_id:
                            participants.append(str(task.poster_id))
                        if task.taker_id:
                            participants.append(str(task.taker_id))
                        # 多人任务：加入 TaskParticipant 及 expert_creator_id，确保接收方能加载私密图片
                        if getattr(task, "is_multi_participant", False):
                            if getattr(task, "expert_creator_id", None):
                                expert_id = str(task.expert_creator_id)
                                if expert_id not in participants:
                                    participants.append(expert_id)
                            for p in db.query(models.TaskParticipant).filter(
                                models.TaskParticipant.task_id == task_id,
                                models.TaskParticipant.status.in_(["accepted", "in_progress"]),
                            ).all():
                                if p.user_id:
                                    user_id_str = str(p.user_id)
                                    if user_id_str not in participants:
                                        participants.append(user_id_str)
                
                # 添加当前用户（如果不在列表中）
                current_user_id_str = str(current_user.id)
                if current_user_id_str not in participants:
                    participants.append(current_user_id_str)
                
                # 如果没有参与者（不应该发生），至少包含当前用户
                if not participants:
                    participants = [current_user_id_str]
                
                # 生成图片访问 URL
                image_url = private_image_system.generate_image_url(
                    result["image_id"],
                    current_user_id_str,
                    participants
                )
                result["url"] = image_url
                logger.debug("upload/image: 已写入 result[url], image_id=%s", result.get("image_id"))
            except Exception as e:
                logger.warning("upload/image: 构建 participants 或 generate_image_url 失败: %s，使用仅当前用户生成 url", e)
                participants = [str(current_user.id)]
                image_url = private_image_system.generate_image_url(
                    result["image_id"],
                    str(current_user.id),
                    participants
                )
                result["url"] = image_url
        
        if result.get("image_id") and "url" not in result:
            logger.error("upload/image: image_id 存在但 result 中无 url，iOS 将无法解析。result keys=%s", list(result.keys()))
        return JSONResponse(content=result)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"图片上传失败: {e}")
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")


@router.post("/upload/public-image", deprecated=True)
@rate_limit("upload_file")
async def upload_public_image(
    request: Request,
    image: UploadFile = File(...),
    category: str = Query("public", description="图片类型：expert_avatar、service_image、public、leaderboard_item、leaderboard_cover、flea_market、forum_post（论坛帖子图片）"),
    resource_id: str = Query(None, description="资源ID：expert_avatar时传expert_id，service_image时传expert_id，public时传task_id（任务ID，发布新任务时可省略）"),
    db: Session = Depends(get_db),
):
    """
    ⚠️ 已废弃 — 请使用 /api/v2/upload/image（upload_routes.py）。
    V2 额外支持批量上传、temp 清理、论坛文件上传。Flutter 端已全部迁移至 V2。
    本接口保留仅为兼容旧版 iOS/Web 调用，后续将移除。

    ---
    上传公开图片文件（所有人可访问）
    用于头像等需要公开访问的图片
    支持管理员和普通用户上传

    参数:
    - category: 图片类型
      - expert_avatar: 任务达人头像
      - service_image: 服务图片
      - public: 其他公开图片（默认）
      - leaderboard_item: 竞品图片
      - leaderboard_cover: 榜单封面
      - flea_market: 跳蚤市场商品图片
    - resource_id: 资源ID，用于创建子文件夹
      - expert_avatar: 任务达人ID（expert_id）
      - service_image: 任务达人ID（expert_id），不是service_id
      - public: 任务ID（task_id），用于任务相关的图片
      - flea_market: 商品ID（item_id）
    
    优化功能：
    - 自动压缩图片（节省存储空间）
    - 自动旋转（根据 EXIF）
    - 移除隐私元数据
    - 限制最大尺寸
    """
    try:
        # 导入图片上传服务
        from app.services import ImageCategory, get_image_upload_service
        
        # 尝试获取管理员或用户ID
        user_id = None
        user_type = None
        
        # 首先尝试管理员认证
        from app.admin_auth import validate_admin_session
        admin_session = validate_admin_session(request)
        if admin_session:
            user_id = admin_session.admin_id
            user_type = "管理员"
        else:
            # 尝试普通用户认证
            from app.secure_auth import validate_session
            user_session = validate_session(request)
            if user_session:
                user_id = user_session.user_id
                user_type = "用户"
            else:
                raise HTTPException(status_code=401, detail="认证失败，请先登录")
        
        if not user_id:
            raise HTTPException(status_code=401, detail="认证失败，请先登录")
        
        # 类别映射
        category_map = {
            "expert_avatar": ImageCategory.EXPERT_AVATAR,
            "service_image": ImageCategory.SERVICE_IMAGE,
            "public": ImageCategory.TASK,
            "leaderboard_item": ImageCategory.LEADERBOARD_ITEM,
            "leaderboard_cover": ImageCategory.LEADERBOARD_COVER,
            "flea_market": ImageCategory.FLEA_MARKET,
            "forum_post": ImageCategory.FORUM_POST,
        }
        
        if category not in category_map:
            raise HTTPException(
                status_code=400,
                detail=f"无效的图片类型。允许的类型: {', '.join(category_map.keys())}"
            )
        
        image_category = category_map[category]
        
        # 确定是否使用临时目录
        is_temp = False
        actual_resource_id = resource_id
        
        if not resource_id:
            if category in ("expert_avatar", "service_image"):
                # 管理员上传时必须传 resource_id（达人 user_id），否则会存到 expert_avatars/{管理员id}/，孤儿清理会误删
                if admin_session:
                    raise HTTPException(
                        status_code=400,
                        detail="管理员上传达人头像或服务图片时请在 URL 中提供 resource_id（达人 user_id）",
                    )
                # 普通用户：头像/服务图使用当前用户 id
                actual_resource_id = user_id
            else:
                # 其他类别使用临时目录
                is_temp = True
        elif resource_id.startswith("temp_"):
            is_temp = True
            actual_resource_id = None  # 服务会自动使用 user_id 构建临时目录
        
        # 使用流式读取文件内容，避免大文件一次性读入内存
        from app.file_stream_utils import read_file_with_size_check
        
        # 公开图片最大大小：5MB
        MAX_PUBLIC_IMAGE_SIZE = 5 * 1024 * 1024
        
        # 流式读取文件内容
        content, file_size = await read_file_with_size_check(image, MAX_PUBLIC_IMAGE_SIZE)
        
        # 使用图片上传服务
        service = get_image_upload_service()
        result = service.upload(
            content=content,
            category=image_category,
            resource_id=actual_resource_id,
            user_id=user_id,
            filename=image.filename,
            is_temp=is_temp
        )
        
        if not result.success:
            raise HTTPException(status_code=400, detail=result.error)
        
        logger.info(
            f"{user_type} {user_id} 上传公开图片 [{category}]: "
            f"size={result.original_size}->{result.size}, "
            f"resource_id={actual_resource_id or 'temp'}"
        )
        
        # 返回响应（保持与原 API 兼容的格式）
        response_data = {
            "success": True,
            "url": result.url,
            "filename": result.filename,
            "size": result.size,
            "category": category,
            "resource_id": resource_id or f"temp_{user_id}",
            "message": "图片上传成功"
        }
        
        # 添加压缩信息
        if result.original_size != result.size:
            response_data["original_size"] = result.original_size
            response_data["compression_saved"] = result.original_size - result.size
        
        return JSONResponse(content=response_data)
        
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
            if task.poster_id:
                participants.append(str(task.poster_id))
            if task.taker_id:
                participants.append(str(task.taker_id))
            
            # 多人任务：加入 TaskParticipant 及 expert_creator_id，确保所有参与者都能加载私密图片
            if getattr(task, "is_multi_participant", False):
                if getattr(task, "expert_creator_id", None):
                    expert_id = str(task.expert_creator_id)
                    if expert_id not in participants:
                        participants.append(expert_id)
                for p in db.query(models.TaskParticipant).filter(
                    models.TaskParticipant.task_id == message.task_id,
                    models.TaskParticipant.status.in_(["accepted", "in_progress"]),
                ).all():
                    if p.user_id:
                        user_id_str = str(p.user_id)
                        if user_id_str not in participants:
                            participants.append(user_id_str)
            
            # 检查用户是否有权限访问此图片（必须是任务的参与者）
            current_user_id_str = str(current_user.id)
            if current_user_id_str not in participants:
                raise HTTPException(status_code=403, detail="无权访问此图片")
        else:
            # 普通聊天：使用发送者和接收者
            if message.sender_id:
                participants.append(str(message.sender_id))
            if message.receiver_id:
                participants.append(str(message.receiver_id))
            
            # 检查用户是否有权限访问此图片
            current_user_id_str = str(current_user.id)
            if current_user_id_str not in participants:
                raise HTTPException(status_code=403, detail="无权访问此图片")
        
        # 如果没有参与者（不应该发生），至少包含当前用户
        if not participants:
            participants = [str(current_user.id)]
        
        # 生成访问URL
        image_url = private_image_system.generate_image_url(
            image_id,
            str(current_user.id),
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
        # 使用流式读取文件内容，避免大文件一次性读入内存
        from app.file_stream_utils import read_file_with_size_check
        
        # 文件最大大小：10MB（支持文档等大文件）
        MAX_FILE_SIZE_UPLOAD = 10 * 1024 * 1024
        
        # 流式读取文件内容
        content, file_size = await read_file_with_size_check(file, MAX_FILE_SIZE_UPLOAD)
        
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
            db_gen = get_db()
            db = next(db_gen)
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
                try:
                    db_gen.close()
                except Exception:
                    db.close()
        except Exception as e:
            logger.debug(f"从新文件系统查找文件失败，尝试旧路径: {e}")
        
        # 回退到旧路径（向后兼容）
        if RAILWAY_ENVIRONMENT and not USE_CLOUD_STORAGE:
            base_private_dir = Path("/data/uploads/private")
        else:
            base_private_dir = Path("uploads/private")
        
        file_path = _resolve_legacy_private_file_path(base_private_dir, file_path_str)
        
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


# 已迁移到 admin_system_routes.py: /admin/job-positions, /admin/job-positions/{position_id}


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


ALLOWED_RESUME_EXTENSIONS = {".pdf", ".doc", ".docx"}
ALLOWED_RESUME_CONTENT_TYPES = {
    "application/pdf",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
}
MAX_RESUME_SIZE = 10 * 1024 * 1024  # 10 MB


@router.post("/job-applications")
@rate_limit("general")
def submit_job_application(
    background_tasks: BackgroundTasks,
    name: str = Form(..., min_length=1, max_length=100),
    email: str = Form(..., max_length=200),
    phone: str = Form(default="", max_length=30),
    position: str = Form(..., min_length=1, max_length=200),
    experience: str = Form(..., min_length=1, max_length=100),
    introduction: str = Form(..., min_length=1, max_length=5000),
    resume: UploadFile = File(...),
):
    """公开接口 — 提交岗位申请，简历作为附件发送到招聘邮箱"""
    hiring_email = Config.HIRING_EMAIL
    if not hiring_email:
        raise HTTPException(status_code=503, detail="招聘邮箱尚未配置，暂时无法投递")

    import re
    if not re.match(r'^[^@\s]+@[^@\s]+\.[^@\s]+$', email):
        raise HTTPException(status_code=400, detail="邮箱格式无效")

    ext = os.path.splitext(resume.filename or "")[1].lower()
    if ext not in ALLOWED_RESUME_EXTENSIONS:
        raise HTTPException(status_code=400, detail="仅支持 PDF、DOC、DOCX 格式的简历")

    content_type = resume.content_type or "application/octet-stream"
    if content_type not in ALLOWED_RESUME_CONTENT_TYPES and ext not in ALLOWED_RESUME_EXTENSIONS:
        raise HTTPException(status_code=400, detail="文件类型不合法")

    file_data = resume.file.read()
    if len(file_data) > MAX_RESUME_SIZE:
        raise HTTPException(status_code=400, detail="简历文件不能超过 10 MB")

    experience_labels = {
        "freshGraduate": "应届毕业生",
        "lessThan1Year": "1年以下",
        "oneToThreeYears": "1-3年",
        "threeToFiveYears": "3-5年",
        "moreThanFiveYears": "5年以上",
    }
    experience_display = experience_labels.get(experience, experience)

    subject = f"[Link2Ur 岗位投递] {position} - {name}"
    body = f"""
    <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #3b82f6; border-bottom: 2px solid #3b82f6; padding-bottom: 10px;">
            新简历投递通知
        </h2>
        <table style="width: 100%; border-collapse: collapse; margin: 16px 0;">
            <tr><td style="padding: 8px 12px; font-weight: bold; width: 100px; color: #555;">姓名</td>
                <td style="padding: 8px 12px;">{name}</td></tr>
            <tr style="background: #f9fafb;">
                <td style="padding: 8px 12px; font-weight: bold; color: #555;">邮箱</td>
                <td style="padding: 8px 12px;"><a href="mailto:{email}">{email}</a></td></tr>
            <tr><td style="padding: 8px 12px; font-weight: bold; color: #555;">手机</td>
                <td style="padding: 8px 12px;">{phone or '未提供'}</td></tr>
            <tr style="background: #f9fafb;">
                <td style="padding: 8px 12px; font-weight: bold; color: #555;">申请岗位</td>
                <td style="padding: 8px 12px;">{position}</td></tr>
            <tr><td style="padding: 8px 12px; font-weight: bold; color: #555;">工作经验</td>
                <td style="padding: 8px 12px;">{experience_display}</td></tr>
        </table>
        <div style="margin-top: 16px;">
            <h3 style="color: #555;">自我介绍</h3>
            <p style="white-space: pre-wrap; background: #f9fafb; padding: 12px; border-radius: 8px;">{introduction}</p>
        </div>
        <p style="color: #999; font-size: 12px; margin-top: 24px;">
            简历文件已附在邮件附件中，请查收。
        </p>
    </div>
    """

    safe_filename = f"{name}_{position}{ext}"

    background_tasks.add_task(
        send_email_with_attachment,
        to_email=hiring_email,
        subject=subject,
        body=body,
        attachment_data=file_data,
        attachment_filename=safe_filename,
        attachment_content_type=content_type,
    )

    logger.info(f"岗位投递已提交: {name} -> {position}, email={email}")
    return {"message": "投递成功，我们会尽快与您联系！"}


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
        ).with_for_update().first()

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
        
        # 保存旧头像URL，用于后续删除（仅在新头像有效时才删除旧头像）
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
        # 注意：只有当头像实际被更新（expert.avatar 不再等于旧值）时才删除旧文件
        if old_avatar_url and 'avatar' in expert_data and expert.avatar != old_avatar_url:
            from app.image_cleanup import delete_expert_avatar
            try:
                delete_expert_avatar(expert_id, old_avatar_url)
            except Exception as e:
                logger.warning(f"删除旧头像失败: {e}")
        
        logger.info(f"更新任务达人成功: {expert_id}")

        # 同步更新到新 experts 表（Phase 2a 兼容）
        try:
            from app.models_expert import Expert
            from sqlalchemy import text as sa_text
            map_result = db.execute(
                sa_text("SELECT new_id FROM _expert_id_migration_map WHERE old_id = :old_id"),
                {"old_id": expert.user_id}
            ).first()
            if map_result:
                new_expert_id = map_result[0]
                new_expert = db.query(Expert).filter(Expert.id == new_expert_id).first()
                if new_expert:
                    if 'name' in expert_data:
                        new_expert.name = expert.name
                    if 'bio' in expert_data:
                        new_expert.bio = expert.bio
                    if 'bio_en' in expert_data:
                        new_expert.bio_en = expert.bio_en
                    if 'avatar' in expert_data and expert.avatar:
                        new_expert.avatar = expert.avatar
                    if 'is_official' in expert_data:
                        new_expert.is_official = bool(expert_data.get('is_official'))
                    if hasattr(expert, 'category') and 'category' in expert_data:
                        pass  # experts 表没有 category 字段，category 在 featured_experts_v2
                    new_expert.updated_at = get_utc_time()
                    db.commit()
                    logger.info(f"同步更新新 experts 表: {new_expert_id}")
        except Exception as sync_err:
            logger.warning(f"同步更新新 experts 表失败（不影响主流程）: {sync_err}")

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
# 注：GET /api/admin/task-expert-services 与 GET /api/admin/task-expert-activities 已迁移至 admin_task_expert_routes.py

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
                    "service_name_en": s.service_name_en,
                    "service_name_zh": s.service_name_zh,
                    "description": s.description,
                    "description_en": s.description_en,
                    "description_zh": s.description_zh,
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
        
        # 检查是否有进行中的服务申请
        pending_applications = db.query(models.ServiceApplication).filter(
            models.ServiceApplication.service_id == service_id,
            models.ServiceApplication.status.in_(["pending", "negotiating", "price_agreed"])
        ).count()

        if tasks_using_service > 0 or activities_using_service > 0 or pending_applications > 0:
            error_msg = "无法删除服务，因为"
            reasons = []
            if tasks_using_service > 0:
                reasons.append(f"有 {tasks_using_service} 个任务正在使用此服务")
            if activities_using_service > 0:
                reasons.append(f"有 {activities_using_service} 个活动正在使用此服务")
            if pending_applications > 0:
                reasons.append(f"有 {pending_applications} 个待处理的服务申请")
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
        
        # 🔒 安全修复：使用 SELECT FOR UPDATE 锁定活动记录，防止并发删除导致重复积分退款
        activity = db.query(models.Activity).filter(
            models.Activity.id == activity_id,
            models.Activity.expert_id == expert_id
        ).with_for_update().first()
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
        
        # ⚠️ 优化：返还未使用的预扣积分（如果有）
        refund_points = 0
        if activity.reserved_points_total and activity.reserved_points_total > 0:
            # 计算应返还的积分 = 预扣积分 - 已发放积分
            distributed = activity.distributed_points_total or 0
            refund_points = activity.reserved_points_total - distributed
            
            if refund_points > 0:
                from app.coupon_points_crud import add_points_transaction
                try:
                    add_points_transaction(
                        db=db,
                        user_id=activity.expert_id,
                        type="refund",
                        amount=refund_points,  # 正数表示返还
                        source="activity_points_refund",
                        related_id=activity_id,
                        related_type="activity",
                        description=f"管理员删除活动，返还未使用的预扣积分（预扣 {activity.reserved_points_total}，已发放 {distributed}，返还 {refund_points}）",
                        idempotency_key=f"activity_admin_refund_{activity_id}_{refund_points}"
                    )
                    logger.info(f"管理员删除活动 {activity_id}，返还积分 {refund_points} 给用户 {activity.expert_id}")
                except Exception as e:
                    logger.error(f"管理员删除活动 {activity_id}，返还积分失败: {e}")
                    # 不抛出异常，继续删除活动
        
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


# 公开 API - 获取任务达人列表（已迁移到 task_expert_routes.py）
# @router.get("/task-experts")
# @measure_api_performance("get_task_experts")
# @cache_response(ttl=600, key_prefix="public_task_experts")
def _deprecated_get_public_task_experts(
    category: Optional[str] = None,
    location: Optional[str] = Query(None, description="城市筛选"),
    keyword: Optional[str] = Query(None, max_length=200, description="关键词搜索（搜索名称、简介、技能）"),
    limit: Optional[int] = Query(None, ge=1, le=100, description="返回数量限制"),
    db: Session = Depends(get_db),
):
    """获取任务达人列表（公开）"""
    try:
        query = db.query(models.FeaturedTaskExpert).filter(
            models.FeaturedTaskExpert.is_active == 1
        )
        
        # 关键词搜索（支持中英文：同时匹配中文字段和英文字段）
        if keyword:
            keyword_pattern = f"%{keyword}%"
            query = query.filter(
                or_(
                    models.FeaturedTaskExpert.name.ilike(keyword_pattern),
                    models.FeaturedTaskExpert.bio.ilike(keyword_pattern),
                    models.FeaturedTaskExpert.bio_en.ilike(keyword_pattern),
                    models.FeaturedTaskExpert.expertise_areas.ilike(keyword_pattern),
                    models.FeaturedTaskExpert.expertise_areas_en.ilike(keyword_pattern),
                    models.FeaturedTaskExpert.featured_skills.ilike(keyword_pattern),
                    models.FeaturedTaskExpert.featured_skills_en.ilike(keyword_pattern),
                    models.FeaturedTaskExpert.achievements.ilike(keyword_pattern),
                    models.FeaturedTaskExpert.achievements_en.ilike(keyword_pattern),
                    models.FeaturedTaskExpert.category.ilike(keyword_pattern),
                )
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
        
        # 限制返回数量
        if limit:
            query = query.limit(limit)
        
        experts = query.all()
        
        # 批量计算完成率为0的专家（只读，不写回数据库）
        from app.models import Task
        zero_rate_ids = [e.id for e in experts if e.completion_rate == 0.0]
        completion_rate_map = {}
        if zero_rate_ids:
            from sqlalchemy import case
            stats = db.query(
                Task.taker_id,
                func.count(Task.id).label('total'),
                func.count(case((Task.status == 'completed', 1))).label('completed')
            ).filter(
                Task.taker_id.in_(zero_rate_ids)
            ).group_by(Task.taker_id).all()

            for taker_id, total, completed in stats:
                if total > 0:
                    completion_rate_map[taker_id] = (completed / total) * 100.0

        result_experts = []
        for expert in experts:
            completion_rate = completion_rate_map.get(expert.id, expert.completion_rate)
            
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
    翻译文本（优化版：支持缓存、去重、文本预处理）
    
    参数:
    - text: 要翻译的文本
    - target_language: 目标语言代码 (如 'en', 'zh', 'zh-cn')
    - source_language: 源语言代码 (可选, 如果不提供则自动检测)
    
    返回:
    - translated_text: 翻译后的文本
    - source_language: 检测到的源语言
    """
    import hashlib
    import asyncio
    import time
    from app.redis_cache import redis_cache
    
    try:
        # 获取请求体
        body = await request.json()
        
        text = body.get('text', '').strip()
        target_language = body.get('target_language', 'en')
        source_language = body.get('source_language')
        
        if not text:
            raise HTTPException(status_code=400, detail="缺少text参数")
        if not target_language:
            raise HTTPException(status_code=400, detail="缺少target_language参数")
        
        # 转换语言代码格式 (zh -> zh-CN, en -> en)
        lang_map = {
            'zh': 'zh-CN',
            'zh-cn': 'zh-CN',
            'zh-tw': 'zh-TW',
            'en': 'en'
        }
        target_lang = lang_map.get(target_language.lower(), target_language)
        source_lang = lang_map.get(source_language.lower(), source_language) if source_language else 'auto'
        
        # 如果源语言和目标语言相同，直接返回原文
        if source_lang != 'auto' and source_lang == target_lang:
            return {
                "translated_text": text,
                "source_language": source_lang,
                "target_language": target_lang,
                "original_text": text,
                "cached": False
            }
        
        # 长文本优化：如果文本超过5000字符，分段翻译（提高翻译质量和速度）
        MAX_TEXT_LENGTH = 5000
        if len(text) > MAX_TEXT_LENGTH:
            # 使用翻译管理器（支持多个服务自动降级）
            from app.translation_manager import get_translation_manager
            
            # 按段落分段（优先保留换行符和段落格式）
            import re
            # 先按双换行符（段落分隔）分段
            paragraphs = re.split(r'(\n\s*\n)', text)
            
            # 重新组合段落，保持段落分隔符
            segments = []
            segment_separators = []  # 记录每个分段之间的分隔符
            current_segment = ""
            
            for i in range(0, len(paragraphs), 2):
                paragraph = paragraphs[i] + (paragraphs[i+1] if i+1 < len(paragraphs) else "")
                if len(current_segment) + len(paragraph) > MAX_TEXT_LENGTH and current_segment:
                    segments.append(current_segment)
                    # 记录分段之间的分隔符（段落分隔符或空字符串）
                    segment_separators.append(paragraphs[i-1] if i > 0 and i-1 < len(paragraphs) else "")
                    current_segment = paragraph
                else:
                    current_segment += paragraph
            
            if current_segment:
                segments.append(current_segment)
                segment_separators.append("")  # 最后一段没有后续分隔符
            
            # 如果分段后仍然有超长段，按单换行符或句子分段
            final_segments = []
            final_separators = []
            for seg_idx, seg in enumerate(segments):
                if len(seg) > MAX_TEXT_LENGTH:
                    # 按单换行符分段
                    lines = re.split(r'(\n)', seg)
                    current_chunk = ""
                    for i in range(0, len(lines), 2):
                        line = lines[i] + (lines[i+1] if i+1 < len(lines) else "")
                        if len(current_chunk) + len(line) > MAX_TEXT_LENGTH and current_chunk:
                            final_segments.append(current_chunk)
                            final_separators.append(lines[i-1] if i > 0 and i-1 < len(lines) else "")
                            current_chunk = line
                        else:
                            current_chunk += line
                    if current_chunk:
                        final_segments.append(current_chunk)
                        final_separators.append("")
                else:
                    final_segments.append(seg)
                    final_separators.append(segment_separators[seg_idx] if seg_idx < len(segment_separators) else "")
            
            # 检查分段后的缓存
            segment_cache_key = f"translation_segments:{hashlib.md5(f'{text}|{source_lang}|{target_lang}'.encode('utf-8')).hexdigest()}"
            segment_separators_key = f"translation_separators:{hashlib.md5(f'{text}|{source_lang}|{target_lang}'.encode('utf-8')).hexdigest()}"
            if redis_cache and redis_cache.enabled:
                cached_segments = redis_cache.get(segment_cache_key)
                cached_separators = redis_cache.get(segment_separators_key)
                if cached_segments and isinstance(cached_segments, list) and len(cached_segments) == len(final_segments):
                    logger.debug(f"长文本分段翻译缓存命中: {len(final_segments)}段")
                    # 合并时保留分隔符
                    if cached_separators and isinstance(cached_separators, list) and len(cached_separators) == len(final_separators):
                        translated_text = ""
                        for i, seg in enumerate(cached_segments):
                            translated_text += seg
                            if i < len(cached_separators):
                                translated_text += cached_separators[i]
                    else:
                        # 兼容旧缓存格式（没有分隔符信息）
                        translated_text = "".join(cached_segments)
                    return {
                        "translated_text": translated_text,
                        "source_language": source_lang if source_lang != 'auto' else 'auto',
                        "target_language": target_lang,
                        "original_text": text,
                        "cached": True
                    }
            
            # 使用异步批量翻译（并发处理多个分段）
            from app.translation_manager import get_translation_manager
            from app.utils.translation_async import translate_batch_async
            translation_manager = get_translation_manager()
            
            translated_segments_list = await translate_batch_async(
                translation_manager,
                texts=final_segments,
                target_lang=target_lang,
                source_lang=source_lang,
                max_retries=2,
                max_concurrent=3  # 限制并发数，避免触发限流
            )
            
            # 处理翻译结果（失败的使用原文），并保留分段分隔符
            translated_segments = []
            for i, translated_seg in enumerate(translated_segments_list):
                if translated_seg:
                    translated_segments.append(translated_seg)
                else:
                    logger.warning(f"分段 {i} 翻译失败，使用原文")
                    translated_segments.append(final_segments[i])
            
            # 合并翻译结果，保留原始的分段分隔符
            translated_text = ""
            for i, seg in enumerate(translated_segments):
                translated_text += seg
                # 添加分段之间的分隔符（保留换行符和段落格式）
                if i < len(final_separators):
                    translated_text += final_separators[i]
            
            # 缓存分段翻译结果和分隔符
            if redis_cache and redis_cache.enabled:
                try:
                    redis_cache.set(segment_cache_key, translated_segments, ttl=7 * 24 * 60 * 60)
                    redis_cache.set(segment_separators_key, final_separators, ttl=7 * 24 * 60 * 60)
                except Exception as e:
                    logger.warning(f"保存分段翻译缓存失败: {e}")
            
            return {
                "translated_text": translated_text,
                "source_language": source_lang if source_lang != 'auto' else 'auto',
                "target_language": target_lang,
                "original_text": text,
                "cached": False
            }
        
        # 生成缓存键（使用文本内容、源语言、目标语言）
        cache_key_data = f"{text}|{source_lang}|{target_lang}"
        cache_key_hash = hashlib.md5(cache_key_data.encode('utf-8')).hexdigest()
        cache_key = f"translation:{cache_key_hash}"
        
        # 1. 先检查Redis缓存
        if redis_cache and redis_cache.enabled:
            cached_result = redis_cache.get(cache_key)
            if cached_result:
                logger.debug(f"翻译缓存命中: {text[:30]}...")
                return {
                    "translated_text": cached_result.get("translated_text"),
                    "source_language": cached_result.get("source_language", source_lang),
                    "target_language": target_lang,
                    "original_text": text,
                    "cached": True
                }
        
        # 2. 检查是否有正在进行的翻译请求（防止重复翻译）
        lock_key = f"translation_lock:{cache_key_hash}"
        if redis_cache and redis_cache.enabled:
            # 尝试获取锁（5秒过期，防止死锁）
            lock_acquired = False
            try:
                # 使用SET NX EX实现分布式锁
                lock_value = str(time.time())
                lock_acquired = redis_cache.redis_client.set(
                    lock_key, 
                    lock_value.encode('utf-8'),
                    ex=5,  # 5秒过期
                    nx=True  # 只在不存在时设置
                )
                
                if not lock_acquired:
                    # 有其他请求正在翻译，等待并重试缓存
                    await asyncio.sleep(0.5)  # 等待500ms
                    cached_result = redis_cache.get(cache_key)
                    if cached_result:
                        logger.debug(f"翻译缓存命中（等待后）: {text[:30]}...")
                        return {
                            "translated_text": cached_result.get("translated_text"),
                            "source_language": cached_result.get("source_language", source_lang),
                            "target_language": target_lang,
                            "original_text": text,
                            "cached": True
                        }
            except Exception as e:
                logger.warning(f"获取翻译锁失败: {e}")
        
        try:
            # 3. 执行翻译（使用翻译管理器，支持多个服务自动降级）
            from app.translation_manager import get_translation_manager
            
            logger.debug(f"开始翻译: text={text[:50]}..., target={target_lang}, source={source_lang}")
            
            translation_manager = get_translation_manager()
            # 使用带换行保护的翻译（自动分段处理含换行的文本）
            from app.utils.bilingual_helper import _translate_with_encoding_protection
            translated_text = await _translate_with_encoding_protection(
                translation_manager,
                text=text,
                target_lang=target_lang,
                source_lang=source_lang,
                max_retries=3
            )
            
            if translated_text is None:
                raise Exception("所有翻译服务都失败，无法翻译文本")
            
            logger.debug(f"翻译完成: {translated_text[:50]}...")
            
            # 检测源语言（如果未提供）
            detected_source = source_lang if source_lang != 'auto' else 'auto'
            
            result = {
                "translated_text": translated_text,
                "source_language": detected_source,
                "target_language": target_lang,
                "original_text": text,
                "cached": False
            }
            
            # 4. 保存到Redis缓存（7天过期）
            if redis_cache and redis_cache.enabled:
                try:
                    cache_data = {
                        "translated_text": translated_text,
                        "source_language": detected_source,
                        "target_language": target_lang
                    }
                    redis_cache.set(cache_key, cache_data, ttl=7 * 24 * 60 * 60)  # 7天
                except Exception as e:
                    logger.warning(f"保存翻译缓存失败: {e}")
            
            return result
            
        finally:
            # 释放锁
            if lock_acquired and redis_cache and redis_cache.enabled:
                try:
                    redis_cache.redis_client.delete(lock_key)
                except Exception as e:
                    logger.warning(f"释放翻译锁失败: {e}")
                    
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
    批量翻译文本（优化版：支持缓存、去重、复用translator实例）
    
    参数:
    - texts: 要翻译的文本列表
    - target_language: 目标语言代码
    - source_language: 源语言代码 (可选)
    
    返回:
    - translations: 翻译结果列表
    """
    import hashlib
    from app.redis_cache import redis_cache
    
    try:
        # 获取请求体
        body = await request.json()
        
        texts = body.get('texts', [])
        target_language = body.get('target_language', 'en')
        source_language = body.get('source_language')
        
        if not texts:
            raise HTTPException(status_code=400, detail="缺少texts参数")
        if not target_language:
            raise HTTPException(status_code=400, detail="缺少target_language参数")
        
        # 限制单次批量翻译的最大文本数量，防止内存溢出
        MAX_BATCH_SIZE = 500
        if len(texts) > MAX_BATCH_SIZE:
            logger.warning(f"批量翻译文本数量过多 ({len(texts)})，限制为 {MAX_BATCH_SIZE} 个")
            texts = texts[:MAX_BATCH_SIZE]
        
        # 预处理：去除空白、去重
        processed_texts = []
        text_to_index = {}  # 用于去重，保留第一个出现的索引
        for i, text in enumerate(texts):
            cleaned_text = text.strip() if isinstance(text, str) else str(text).strip()
            if cleaned_text and cleaned_text not in text_to_index:
                text_to_index[cleaned_text] = len(processed_texts)
                processed_texts.append(cleaned_text)
        
        if not processed_texts:
            return {
                "translations": [{"original_text": t, "translated_text": t, "source_language": "auto"} for t in texts],
                "target_language": target_language
            }
        
        # 转换语言代码格式
        lang_map = {
            'zh': 'zh-CN',
            'zh-cn': 'zh-CN',
            'zh-tw': 'zh-TW',
            'en': 'en'
        }
        target_lang = lang_map.get(target_language.lower(), target_language)
        source_lang = lang_map.get(source_language.lower(), source_language) if source_language else 'auto'
        
        # 如果源语言和目标语言相同，直接返回原文
        if source_lang != 'auto' and source_lang == target_lang:
            return {
                "translations": [{"original_text": t, "translated_text": t, "source_language": source_lang} for t in texts],
                "target_language": target_lang
            }
        
        # 使用翻译管理器（支持多个服务自动降级）
        from app.translation_manager import get_translation_manager
        translation_manager = get_translation_manager()
        
        # 批量处理：先检查缓存，再翻译未缓存的文本
        translations_map = {}  # 存储翻译结果
        texts_to_translate = []  # 需要翻译的文本列表
        text_indices = []  # 对应的索引
        
        for i, text in enumerate(processed_texts):
            # 生成缓存键
            cache_key_data = f"{text}|{source_lang}|{target_lang}"
            cache_key_hash = hashlib.md5(cache_key_data.encode('utf-8')).hexdigest()
            cache_key = f"translation:{cache_key_hash}"
            
            # 检查缓存
            cached_result = None
            if redis_cache and redis_cache.enabled:
                cached_result = redis_cache.get(cache_key)
            
            if cached_result:
                translations_map[text] = cached_result.get("translated_text")
            else:
                texts_to_translate.append(text)
                text_indices.append(i)
        
        # 批量翻译未缓存的文本（分批处理，每批最多50个，避免API限制）
        if texts_to_translate:
            logger.debug(f"批量翻译: {len(texts_to_translate)}个文本需要翻译")
            
            batch_size = 50  # 每批最多50个文本
            for batch_start in range(0, len(texts_to_translate), batch_size):
                batch_texts = texts_to_translate[batch_start:batch_start + batch_size]
                
                for text in batch_texts:
                    try:
                        # 生成缓存键
                        cache_key_data = f"{text}|{source_lang}|{target_lang}"
                        cache_key_hash = hashlib.md5(cache_key_data.encode('utf-8')).hexdigest()
                        cache_key = f"translation:{cache_key_hash}"
                        
                        # 使用翻译管理器执行翻译（自动降级）
                        translated_text = translation_manager.translate(
                            text=text,
                            target_lang=target_lang,
                            source_lang=source_lang,
                            max_retries=2  # 批量翻译时减少重试次数
                        )
                        
                        if translated_text:
                            translations_map[text] = translated_text
                            
                            # 保存到缓存
                            if redis_cache and redis_cache.enabled:
                                try:
                                    cache_data = {
                                        "translated_text": translated_text,
                                        "source_language": source_lang if source_lang != 'auto' else 'auto',
                                        "target_language": target_lang
                                    }
                                    redis_cache.set(cache_key, cache_data, ttl=7 * 24 * 60 * 60)  # 7天
                                except Exception as e:
                                    logger.warning(f"保存翻译缓存失败: {e}")
                        else:
                            # 翻译失败时返回原文
                            logger.error(f"翻译文本失败: {text[:50]}...")
                            translations_map[text] = text
                        
                        # 批量处理时添加小延迟，避免API限流
                        if len(batch_texts) > 10:
                            await asyncio.sleep(0.1)
                            
                    except Exception as e:
                        logger.error(f"翻译文本失败: {text[:50]}... - {e}")
                        translations_map[text] = text  # 翻译失败时返回原文
        
        # 构建返回结果（保持原始顺序和重复）
        result_translations = []
        for original_text in texts:
            cleaned_text = original_text.strip() if isinstance(original_text, str) else str(original_text).strip()
            if cleaned_text in translations_map:
                translated = translations_map[cleaned_text]
            else:
                # 如果不在map中（可能是空文本），返回原文
                translated = original_text
            
            result_translations.append({
                "original_text": original_text,
                "translated_text": translated,
                "source_language": source_lang if source_lang != 'auto' else 'auto',
            })
        
        logger.debug(f"批量翻译完成: 总数={len(texts)}, 缓存命中={len(processed_texts) - len(texts_to_translate)}, 新翻译={len(texts_to_translate)}")
        
        return {
            "translations": result_translations,
            "target_language": target_lang
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"批量翻译失败: {e}")
        raise HTTPException(status_code=500, detail=f"批量翻译失败: {str(e)}")


# 任务翻译API - 从任务表 zh/en 列读取（任务翻译表已停用）
@router.get("/translate/task/{task_id}")
def get_task_translation(
    task_id: int,
    field_type: str = Query(..., description="字段类型：title 或 description"),
    target_language: str = Query(..., description="目标语言代码"),
    db: Session = Depends(get_db),
):
    """
    获取任务翻译（从任务表 title_zh/title_en、description_zh/description_en 读取）
    """
    try:
        from app import crud

        if field_type not in ['title', 'description']:
            raise HTTPException(status_code=400, detail="field_type必须是'title'或'description'")

        task = crud.get_task(db, task_id)
        if not task:
            raise HTTPException(status_code=404, detail="任务不存在")

        # 映射到任务表列：en -> *_en, zh-CN/zh -> *_zh
        is_zh = target_language and (target_language == 'zh-CN' or target_language.lower() == 'zh')
        col = (field_type + '_zh') if is_zh else (field_type + '_en')
        translated_text = getattr(task, col, None)

        if translated_text:
            return {
                "translated_text": translated_text,
                "exists": True,
                "source_language": "auto",
                "target_language": target_language or (is_zh and "zh-CN" or "en"),
            }
        return {"translated_text": None, "exists": False}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取任务翻译失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取任务翻译失败: {str(e)}")


@router.post("/translate/task/{task_id}")
async def translate_and_save_task(
    task_id: int,
    request: Request,
    db: Session = Depends(get_db),
):
    """
    翻译任务内容并保存到数据库（供所有用户共享使用）
    
    参数:
    - task_id: 任务ID
    - field_type: 字段类型（title 或 description）
    - target_language: 目标语言代码
    - source_language: 源语言代码（可选）
    
    返回:
    - translated_text: 翻译后的文本
    - saved: 是否保存到数据库
    """
    import hashlib
    import asyncio
    import time
    from app import crud
    from app.redis_cache import redis_cache
    
    try:
        # 获取请求体
        body = await request.json()
        
        field_type = body.get('field_type')
        target_language = body.get('target_language', 'en')
        source_language = body.get('source_language')
        
        if not field_type:
            raise HTTPException(status_code=400, detail="缺少field_type参数")
        if field_type not in ['title', 'description']:
            raise HTTPException(status_code=400, detail="field_type必须是'title'或'description'")
        if not target_language:
            raise HTTPException(status_code=400, detail="缺少target_language参数")
        
        # 检查任务是否存在
        task = crud.get_task(db, task_id)
        if not task:
            raise HTTPException(status_code=404, detail="任务不存在")
        
        # 获取原始文本
        if field_type == 'title':
            original_text = task.title
        else:
            original_text = task.description
        
        if not original_text:
            raise HTTPException(status_code=400, detail=f"任务的{field_type}为空")
        
        # 转换语言代码格式
        lang_map = {
            'zh': 'zh-CN',
            'zh-cn': 'zh-CN',
            'zh-tw': 'zh-TW',
            'en': 'en'
        }
        target_lang = lang_map.get(target_language.lower(), target_language)
        source_lang = lang_map.get(source_language.lower(), source_language) if source_language else 'auto'
        
        # 如果源语言和目标语言相同，直接返回原文
        if source_lang != 'auto' and source_lang == target_lang:
            return {
                "translated_text": original_text,
                "saved": False,
                "source_language": source_lang,
                "target_language": target_lang
            }
        
        # 1. 先检查任务翻译专用缓存（优先级最高）
        from app.utils.task_translation_cache import (
            get_cached_task_translation,
            cache_task_translation
        )
        
        cached_translation = get_cached_task_translation(task_id, field_type, target_lang)
        if cached_translation:
            logger.debug(f"任务翻译缓存命中: task_id={task_id}, field={field_type}, lang={target_lang}")
            return {
                "translated_text": cached_translation.get("translated_text"),
                "saved": True,
                "source_language": cached_translation.get("source_language", source_lang),
                "target_language": cached_translation.get("target_language", target_lang),
                "from_cache": True
            }
        
        # 2. 检查任务表列是否已有翻译（任务翻译表已停用）
        is_zh = target_lang in ('zh-CN', 'zh')
        col = (field_type + '_zh') if is_zh else (field_type + '_en')
        existing_text = getattr(task, col, None)
        if existing_text:
            logger.debug(f"任务翻译列命中: task_id={task_id}, field={field_type}, lang={target_lang}")
            cache_task_translation(task_id, field_type, target_lang, existing_text, "auto")
            return {
                "translated_text": existing_text,
                "saved": True,
                "source_language": "auto",
                "target_language": target_lang,
                "from_cache": False,
            }

        # 3. 检查通用翻译缓存（基于文本内容）
        cache_key_data = f"{original_text}|{source_lang}|{target_lang}"
        cache_key_hash = hashlib.md5(cache_key_data.encode('utf-8')).hexdigest()
        cache_key = f"translation:{cache_key_hash}"
        
        cached_result = None
        if redis_cache and redis_cache.enabled:
            cached_result = redis_cache.get(cache_key)
        
        if cached_result:
            translated_text = cached_result.get("translated_text")
            setattr(task, col, translated_text)
            db.commit()
            # 缓存到任务翻译专用缓存
            cache_task_translation(
                task_id, field_type, target_lang,
                translated_text,
                cached_result.get("source_language", source_lang)
            )
            logger.debug(f"任务翻译保存到数据库: task_id={task_id}, field={field_type}")
            return {
                "translated_text": translated_text,
                "saved": True,
                "source_language": cached_result.get("source_language", source_lang),
                "target_language": target_lang,
                "from_cache": True
            }
        
        # 3. 执行翻译（使用翻译管理器，支持多个服务自动降级）
        from app.translation_manager import get_translation_manager
        
        logger.debug(f"开始翻译任务内容: task_id={task_id}, field={field_type}, target={target_lang}")
        
        translation_manager = get_translation_manager()
        with TranslationTimer('task_translation', source_lang, target_lang, cached=False):
            # 使用异步翻译（在线程池中执行，不阻塞事件循环）
            from app.utils.translation_async import translate_async
            translated_text = await translate_async(
                translation_manager,
                text=original_text,
                target_lang=target_lang,
                source_lang=source_lang,
                max_retries=3
            )
        
        if translated_text is None:
            raise Exception("所有翻译服务都失败，无法翻译文本")
        
        logger.debug(f"翻译完成: {translated_text[:50]}...")
        
        detected_source = source_lang if source_lang != 'auto' else 'auto'
        setattr(task, col, translated_text)
        db.commit()
        logger.debug(f"任务翻译已写入任务表列: task_id={task_id}, field={field_type}")
        
        # 5. 保存到缓存（任务翻译专用缓存 + 通用翻译缓存）
        # 5.1 任务翻译专用缓存
        cache_task_translation(
            task_id, field_type, target_lang,
            translated_text, detected_source
        )
        
        # 5.2 通用翻译缓存（基于文本内容）
        if redis_cache and redis_cache.enabled:
            try:
                cache_data = {
                    "translated_text": translated_text,
                    "source_language": detected_source,
                    "target_language": target_lang
                }
                redis_cache.set(cache_key, cache_data, ttl=7 * 24 * 60 * 60)  # 7天
            except Exception as e:
                logger.warning(f"保存通用翻译缓存失败: {e}")
        
        return {
            "translated_text": translated_text,
            "saved": True,
            "source_language": detected_source,
            "target_language": target_lang,
            "from_cache": False
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"翻译并保存任务失败: {e}")
        raise HTTPException(status_code=500, detail=f"翻译并保存任务失败: {str(e)}")


# 批量获取任务翻译API
@router.post("/translate/tasks/batch")
async def get_task_translations_batch(
    request: Request,
    db: Session = Depends(get_db),
):
    """
    批量获取任务翻译（用于优化任务列表加载）
    
    参数:
    - task_ids: 任务ID列表
    - field_type: 字段类型（title 或 description）
    - target_language: 目标语言代码
    
    返回:
    - translations: 翻译结果字典 {task_id: translated_text}
    """
    try:
        from app import crud
        
        body = await request.json()
        task_ids = body.get('task_ids', [])
        field_type = body.get('field_type')
        target_language = body.get('target_language', 'en')
        
        if not task_ids:
            return {"translations": {}}
        
        if not field_type:
            raise HTTPException(status_code=400, detail="缺少field_type参数")
        if field_type not in ['title', 'description']:
            raise HTTPException(status_code=400, detail="field_type必须是'title'或'description'")
        if not target_language:
            raise HTTPException(status_code=400, detail="缺少target_language参数")
        
        # 转换语言代码格式
        lang_map = {
            'zh': 'zh-CN',
            'zh-cn': 'zh-CN',
            'zh-tw': 'zh-TW',
            'en': 'en'
        }
        target_lang = lang_map.get(target_language.lower(), target_language)
        
        # 1. 先检查批量查询缓存
        from app.utils.task_translation_cache import (
            get_cached_batch_translations,
            cache_batch_translations
        )
        
        cached_batch = get_cached_batch_translations(task_ids, field_type, target_lang)
        if cached_batch:
            logger.debug(f"批量翻译查询缓存命中: {len(cached_batch)} 条")
            return {
                "translations": cached_batch,
                "target_language": target_lang,
                "from_cache": True
            }
        
        # 2. 从任务表列批量读取（任务翻译表已停用）
        MAX_BATCH_SIZE = 1000
        if len(task_ids) > MAX_BATCH_SIZE:
            logger.warning(f"批量查询任务翻译数量过大: {len(task_ids)}，限制为{MAX_BATCH_SIZE}")
            task_ids = task_ids[:MAX_BATCH_SIZE]

        from app.models import Task
        is_zh = target_lang in ('zh-CN', 'zh')
        col = (field_type + '_zh') if is_zh else (field_type + '_en')
        tasks_batch = db.query(Task).filter(Task.id.in_(task_ids), Task.is_visible == True).all()
        task_map = {t.id: t for t in tasks_batch}

        result = {}
        missing_task_ids = []
        for task_id in task_ids:
            task = task_map.get(task_id)
            text = getattr(task, col, None) if task else None
            if text:
                result[task_id] = {
                    "translated_text": text,
                    "source_language": "auto",
                    "target_language": target_lang,
                }
            else:
                missing_task_ids.append(task_id)
        
        # 4. 如果有缺少翻译的任务，尝试异步翻译（不阻塞，后台处理）
        if missing_task_ids:
            logger.debug(f"发现 {len(missing_task_ids)} 个任务缺少翻译，将在后台处理")
            # 在后台异步翻译缺少的任务（不等待结果）
            try:
                asyncio.create_task(
                    _translate_missing_tasks_async(
                        db, missing_task_ids, field_type, target_lang
                    )
                )
            except Exception as e:
                logger.warning(f"启动后台翻译任务失败: {e}")
        
        # 5. 缓存批量查询结果（只缓存已有的翻译）
        if result:
            cache_batch_translations(task_ids, field_type, target_lang, result)
        
        logger.debug(f"批量获取任务翻译: 请求{len(task_ids)}个，返回{len(result)}个，缺少{len(missing_task_ids)}个")
        
        return {
            "translations": result,
            "target_language": target_lang,
            "from_cache": False,
            "missing_count": len(missing_task_ids),  # 返回缺少翻译的数量
            "partial": len(missing_task_ids) > 0  # 是否部分成功
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"批量获取任务翻译失败: {e}")
        raise HTTPException(status_code=500, detail=f"批量获取任务翻译失败: {str(e)}")


# 翻译性能指标API
@router.get("/translate/metrics")
def get_translation_metrics():
    """
    获取翻译性能指标
    
    返回:
    - metrics: 性能指标摘要
    - cache_stats: 缓存统计信息
    """
    try:
        from app.utils.translation_metrics import get_metrics_summary
        from app.utils.cache_eviction import get_cache_stats
        
        metrics = get_metrics_summary()
        cache_stats = get_cache_stats()
        
        return {
            "metrics": metrics,
            "cache_stats": cache_stats,
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"获取翻译性能指标失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取翻译性能指标失败: {str(e)}")


# 翻译服务状态API
@router.get("/translate/services/status")
def get_translation_services_status():
    """
    获取翻译服务状态
    
    返回:
    - available_services: 可用服务列表
    - failed_services: 失败服务列表
    - stats: 服务统计信息
    """
    try:
        from app.translation_manager import get_translation_manager
        
        manager = get_translation_manager()
        available = manager.get_available_services()
        all_services = manager.get_all_services()
        stats = manager.get_service_stats()
        failed = [s.value for s in manager.failed_services]
        
        # 构建统计信息
        stats_result = {}
        for service_name in all_services:
            # 找到对应的服务枚举
            service_enum = None
            for s, _ in manager.services:
                if s.value == service_name:
                    service_enum = s
                    break
            
            if service_enum:
                stats_result[service_name] = {
                    "success": stats.get(service_enum, {}).get('success', 0),
                    "failure": stats.get(service_enum, {}).get('failure', 0),
                    "is_available": service_name in available
                }
        
        return {
            "available_services": available,
            "failed_services": failed,
            "all_services": all_services,
            "stats": stats_result
        }
    except Exception as e:
        logger.error(f"获取翻译服务状态失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取翻译服务状态失败: {str(e)}")


# 重置翻译服务状态API
@router.post("/translate/services/reset")
def reset_translation_services(
    service_name: Optional[str] = Query(None, description="要重置的服务名称，如果为空则重置所有")
):
    """
    重置翻译服务失败记录
    
    参数:
    - service_name: 要重置的服务名称（可选），如果为空则重置所有
    
    返回:
    - success: 是否成功
    - message: 消息
    """
    try:
        from app.translation_manager import get_translation_manager, TranslationService
        
        manager = get_translation_manager()
        
        if service_name:
            # 重置指定服务
            try:
                service = TranslationService(service_name.lower())
                manager.reset_failed_service(service)
                return {
                    "success": True,
                    "message": f"翻译服务 {service_name} 的失败记录已重置"
                }
            except ValueError:
                raise HTTPException(status_code=400, detail=f"无效的服务名称: {service_name}")
        else:
            # 重置所有服务
            manager.reset_failed_services()
            return {
                "success": True,
                "message": "所有翻译服务失败记录已重置"
            }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"重置翻译服务状态失败: {e}")
        raise HTTPException(status_code=500, detail=f"重置翻译服务状态失败: {str(e)}")


# 获取失败服务信息API
@router.get("/translate/services/failed")
def get_failed_services_info():
    """
    获取失败服务的详细信息
    
    返回:
    - failed_services: 失败服务信息
    """
    try:
        from app.translation_manager import get_translation_manager
        
        manager = get_translation_manager()
        failed_info = manager.get_failed_services_info()
        
        return {
            "failed_services": failed_info,
            "count": len(failed_info)
        }
    except Exception as e:
        logger.error(f"获取失败服务信息失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取失败服务信息失败: {str(e)}")


# 翻译告警API
@router.get("/translate/alerts")
def get_translation_alerts(
    service_name: Optional[str] = Query(None, description="服务名称过滤"),
    severity: Optional[str] = Query(None, description="严重程度过滤（info/warning/error/critical）"),
    limit: int = Query(50, ge=1, le=200, description="返回数量限制")
):
    """
    获取翻译服务告警信息
    
    返回:
    - alerts: 告警列表
    - stats: 告警统计
    """
    try:
        from app.utils.translation_alert import get_recent_alerts, get_alert_stats
        
        alerts = get_recent_alerts(
            service_name=service_name,
            severity=severity,
            limit=limit
        )
        stats = get_alert_stats()
        
        return {
            "alerts": alerts,
            "stats": stats,
            "count": len(alerts)
        }
    except Exception as e:
        logger.error(f"获取翻译告警失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取翻译告警失败: {str(e)}")


# 预翻译API
@router.post("/translate/prefetch")
async def prefetch_translations(
    request: Request,
    db: Session = Depends(get_db),
):
    """
    预翻译热门任务或指定任务
    
    参数:
    - task_ids: 任务ID列表（可选，如果提供则翻译指定任务，否则翻译热门任务）
    - target_languages: 目标语言列表（可选，默认使用常用语言）
    - limit: 预翻译的任务数量（仅当task_ids为空时有效）
    
    返回:
    - prefetched_count: 预翻译的数量
    """
    try:
        from app.utils.translation_prefetch import (
            prefetch_popular_tasks,
            prefetch_task_by_id
        )
        
        body = await request.json()
        task_ids = body.get('task_ids', [])
        target_languages = body.get('target_languages')
        limit = body.get('limit', 50)
        
        if task_ids:
            # 翻译指定任务
            total_count = 0
            for task_id in task_ids[:100]:  # 限制最多100个任务
                count = await prefetch_task_by_id(
                    db, task_id, target_languages
                )
                total_count += count
            
            return {
                "prefetched_count": total_count,
                "task_count": len(task_ids)
            }
        else:
            # 翻译热门任务
            count = await prefetch_popular_tasks(
                db, limit=limit, target_languages=target_languages
            )
            
            return {
                "prefetched_count": count,
                "limit": limit
            }
    except Exception as e:
        logger.error(f"预翻译失败: {e}")
        raise HTTPException(status_code=500, detail=f"预翻译失败: {str(e)}")


# 智能缓存预热API
@router.post("/translate/warmup")
async def warmup_translations(
    request: Request,
    db: Session = Depends(get_db),
):
    """
    智能缓存预热（根据用户偏好和任务类型）
    
    参数:
    - task_ids: 任务ID列表（可选）
    - user_language: 用户语言偏好（可选）
    - task_type: 任务类型（可选）
    - limit: 预热的任务数量（默认50）
    
    返回:
    - stats: 预热统计信息
    """
    try:
        from app.utils.translation_cache_warmup import (
            warmup_hot_tasks,
            warmup_by_user_preference,
            warmup_task_translations
        )
        
        body = await request.json()
        task_ids = body.get('task_ids', [])
        user_language = body.get('user_language')
        task_type = body.get('task_type')
        limit = body.get('limit', 50)
        
        if task_ids:
            # 预热指定任务
            stats = warmup_task_translations(
                db,
                task_ids=task_ids,
                languages=[user_language] if user_language else None
            )
        elif user_language:
            # 根据用户偏好预热
            stats = warmup_by_user_preference(
                db,
                user_language=user_language,
                limit=limit
            )
        else:
            # 预热热门任务
            stats = warmup_hot_tasks(
                db,
                limit=limit,
                user_language=user_language,
                task_type=task_type
            )
        
        return {
            "stats": stats,
            "success": True
        }
    except Exception as e:
        logger.error(f"缓存预热失败: {e}")
        raise HTTPException(status_code=500, detail=f"缓存预热失败: {str(e)}")


# 已迁移到 admin_system_routes.py: /admin/cleanup/completed-tasks, /admin/cleanup/all-old-tasks, /admin/cleanup/duplicate-device-tokens, /admin/cleanup/old-inactive-device-tokens


# ==================== Banner 广告 API ====================

@router.get("/banners")
@cache_response(ttl=300, key_prefix="banners")  # 缓存5分钟
def get_banners(
    db: Session = Depends(get_db),
):
    """获取滚动广告列表（用于 iOS app）"""
    try:
        # 查询所有启用的 banner，按 order 字段升序排序
        banners = db.query(models.Banner).filter(
            models.Banner.is_active == True
        ).order_by(models.Banner.order.asc()).all()
        
        # 转换为返回格式
        banner_list = []
        for banner in banners:
            banner_list.append({
                "id": banner.id,
                "image_url": banner.image_url,
                "title": banner.title,
                "subtitle": banner.subtitle,
                "link_url": banner.link_url,
                "link_type": banner.link_type,
                "order": banner.order
            })
        
        return {
            "banners": banner_list
        }
    except Exception as e:
        logger.error(f"获取 banner 列表失败: {e}")
        raise HTTPException(status_code=500, detail="获取广告列表失败")


# ==================== App 版本检查 API ====================

def _parse_semver(version_str: str) -> tuple:
    """将版本字符串解析为 (major, minor, patch) 元组用于比较"""
    try:
        parts = version_str.strip().split(".")
        return tuple(int(p) for p in parts[:3])
    except (ValueError, AttributeError):
        return (0, 0, 0)


@router.get("/app/version-check")
def check_app_version(platform: str, current_version: str):
    """
    公开接口：检查 App 版本。
    - platform: ios / android
    - current_version: 当前 App 版本号，如 1.1.1
    返回最新版本、最低版本、是否强制更新、更新链接。
    """
    latest = Config.APP_LATEST_VERSION
    min_ver = Config.APP_MIN_VERSION
    release_notes = Config.APP_RELEASE_NOTES

    # 根据平台返回对应商店链接
    if platform.lower() == "ios":
        update_url = Config.IOS_STORE_URL
    else:
        update_url = Config.ANDROID_STORE_URL

    # 语义化版本比较
    current_parsed = _parse_semver(current_version)
    min_parsed = _parse_semver(min_ver)
    force_update = current_parsed < min_parsed

    return {
        "latest_version": latest,
        "min_version": min_ver,
        "force_update": force_update,
        "update_url": update_url,
        "release_notes": release_notes,
    }


# ==================== FAQ 库 API ====================

@router.get("/faq", response_model=schemas.FaqListResponse)
@cache_response(ttl=600, key_prefix="faq")  # 缓存 10 分钟
def get_faq(
    lang: Optional[str] = Query("en", description="语言：zh 或 en"),
    db: Session = Depends(get_db),
):
    """获取 FAQ 列表（按分类与语言返回，用于 Web / iOS）"""
    try:
        lang = (lang or "en").lower()
        if lang not in ("zh", "en"):
            lang = "en"
        sections = (
            db.query(models.FaqSection)
            .order_by(models.FaqSection.sort_order.asc())
            .all()
        )
        section_list = []
        for sec in sections:
            items = (
                db.query(models.FaqItem)
                .filter(models.FaqItem.section_id == sec.id)
                .order_by(models.FaqItem.sort_order.asc())
                .all()
            )
            item_list = [
                {
                    "id": it.id,
                    "question": getattr(it, "question_zh" if lang == "zh" else "question_en"),
                    "answer": getattr(it, "answer_zh" if lang == "zh" else "answer_en"),
                    "sort_order": it.sort_order,
                }
                for it in items
            ]
            section_list.append({
                "id": sec.id,
                "key": sec.key,
                "title": getattr(sec, "title_zh" if lang == "zh" else "title_en"),
                "items": item_list,
                "sort_order": sec.sort_order,
            })
        return {"sections": section_list}
    except Exception as e:
        logger.error(f"获取 FAQ 列表失败: {e}")
        raise HTTPException(status_code=500, detail="获取FAQ失败")


# ==================== 法律文档库 API ====================

@router.get("/legal/{doc_type}", response_model=schemas.LegalDocumentOut)
@cache_response(ttl=600, key_prefix="legal")
def get_legal_document(
    doc_type: str,
    lang: Optional[str] = Query("en", description="语言：zh 或 en"),
    db: Session = Depends(get_db),
):
    """获取法律文档（隐私政策/用户协议/Cookie 政策/社区准则），按 type+lang 返回 content_json。用于 Web / iOS。"""
    try:
        doc_type = (doc_type or "").lower()
        if doc_type not in ("privacy", "terms", "cookie", "community_guidelines"):
            raise HTTPException(status_code=400, detail="doc_type 须为 privacy、terms、cookie 或 community_guidelines")
        lang = (lang or "en").lower()
        if lang not in ("zh", "en"):
            lang = "en"
        row = (
            db.query(models.LegalDocument)
            .filter(models.LegalDocument.type == doc_type, models.LegalDocument.lang == lang)
            .first()
        )
        if not row:
            raise HTTPException(status_code=404, detail="未找到该法律文档")
        return {
            "type": row.type,
            "lang": row.lang,
            "content_json": row.content_json or {},
            "version": row.version,
            "effective_at": row.effective_at,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取法律文档失败: {e}")
        raise HTTPException(status_code=500, detail="获取法律文档失败")