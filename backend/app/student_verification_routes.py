"""
学生认证路由模块
实现学生邮箱验证相关的API接口
"""

import secrets
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Request, status
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_

from app import models
from app.deps import get_sync_db
from app.deps import get_current_user_secure_sync_csrf
from app.student_verification_utils import (
    calculate_expires_at,
    calculate_renewable_from,
    calculate_days_remaining,
    can_renew
)
from app.student_verification_validators import (
    validate_student_email,
    normalize_email,
    extract_domain
)
from app.redis_cache import get_redis_client
from app.utils.time_utils import format_iso_utc, get_utc_time
from app.rate_limiting import rate_limit

logger = logging.getLogger(__name__)

router = APIRouter()


def match_university_by_email(email: str, db: Session) -> Optional[models.University]:
    """
    根据邮箱匹配大学（使用内存缓存优化版本）
    
    Args:
        email: 学生邮箱
        db: 数据库会话
    
    Returns:
        匹配的大学对象，如果未匹配则返回None
    """
    from app.university_matcher import match_university_by_email as cached_match
    return cached_match(email, db)


def generate_verification_token(email: str) -> tuple[str, datetime]:
    """
    生成验证令牌
    
    使用 secrets.token_urlsafe() 生成URL安全的令牌
    长度48字节，提供足够的熵（约384位）
    
    Returns:
        (token, token_expires_at): 令牌和过期时间
    """
    # 使用 token_urlsafe 生成URL安全的令牌（更简洁，熵值足够）
    token = secrets.token_urlsafe(48)  # 48字节，约64字符URL安全编码
    
    # 统一转小写存储邮箱
    email_lower = email.strip().lower()
    
    # 计算令牌过期时间（15分钟后）
    now = get_utc_time()
    token_expires_at = now + timedelta(minutes=15)
    
    # 存储到Redis，使用业务前缀，15分钟过期
    redis_client = get_redis_client()
    if redis_client:
        try:
            token_key = f"student_verification:token:{token}"
            redis_client.setex(
                token_key,  # 业务前缀，便于管理和监控
                900,  # 15分钟 = 900秒
                email_lower
            )
            # 验证存储是否成功
            stored_value = redis_client.get(token_key)
            if stored_value:
                if isinstance(stored_value, bytes):
                    stored_value = stored_value.decode('utf-8')
                if stored_value.lower() != email_lower:
                    logger.error(f"Redis存储验证失败: 存储的值不匹配 - expected={email_lower}, actual={stored_value}")
                else:
                    logger.info(f"验证令牌已成功存储到Redis: token={token[:20]}..., email={email_lower}")
            else:
                logger.error(f"Redis存储验证失败: token={token[:20]}... 存储后立即读取为空")
        except Exception as e:
            logger.error(f"存储验证令牌到Redis失败: {e}", exc_info=True)
            # Redis存储失败不应该阻止认证流程，但应该记录警告
            # 因为验证时如果Redis中没有token，验证会失败
    else:
        logger.warning("Redis客户端不可用，验证令牌将无法存储到Redis，验证可能会失败")
    
    return token, token_expires_at


def check_email_uniqueness(email: str, db: Session, exclude_user_id: str = None) -> bool:
    """
    检查邮箱是否已被使用
    
    重要：邮箱统一转小写存储和比较，确保大小写不敏感
    
    实时过期检查：此函数会在每次调用时实时检查记录是否已过期，实现"立即释放"机制。
    
    规则：
    1. verified状态的记录：实时检查是否已过期
       - 如果已过期：立即删除旧记录并标记为expired，允许新验证（实现立即释放）
       - 如果未过期：阻止新验证
    2. expired状态的记录：已过期，允许重新验证（删除旧记录）
    3. pending状态的记录：使用 token_expires_at 判断（不是 created_at）
       - token_expires_at 未过期：阻止新验证（邮箱被占用）
       - token_expires_at 已过期：允许覆盖（验证令牌已过期，删除旧记录）
    4. revoked状态的记录：撤销后立即释放邮箱，允许重新验证（删除旧记录）
    
    返回:
        True: 邮箱可用
        False: 邮箱已被使用
    """
    # 统一转小写，确保大小写不敏感
    email_lower = email.strip().lower()
    
    query = db.query(models.StudentVerification).filter(
        models.StudentVerification.email == email_lower
    )
    
    # 如果提供了用户ID，排除该用户的记录（用于续期场景）
    if exclude_user_id:
        query = query.filter(models.StudentVerification.user_id != exclude_user_id)
    
    existing = query.first()
    
    if not existing:
        return True  # 邮箱可用
    
    now = get_utc_time()
    
    # 处理verified状态的记录：实时检查是否已过期
    if existing.status == 'verified':
        if existing.expires_at and existing.expires_at <= now:
            # 已过期，立即释放邮箱
            existing.status = 'expired'
            existing.updated_at = now
            db.commit()
            logger.info(f"邮箱 {email_lower} 已过期，立即释放")
            return True
        else:
            # 未过期，邮箱被占用
            return False
    
    # 处理expired状态的记录：已过期，允许重新验证
    if existing.status == 'expired':
        # 删除旧记录，允许重新验证
        db.delete(existing)
        db.commit()
        logger.info(f"删除已过期的认证记录，邮箱 {email_lower} 可重新验证")
        return True
    
    # 处理pending状态的记录：使用 token_expires_at 判断
    if existing.status == 'pending':
        if existing.token_expires_at and existing.token_expires_at > now:
            # 令牌未过期，邮箱被占用
            return False
        else:
            # 令牌已过期，允许覆盖
            db.delete(existing)
            db.commit()
            logger.info(f"删除已过期的pending记录，邮箱 {email_lower} 可重新验证")
            return True
    
    # 处理revoked状态的记录：撤销后立即释放邮箱
    if existing.status == 'revoked':
        # 删除旧记录，允许重新验证
        db.delete(existing)
        db.commit()
        logger.info(f"删除已撤销的认证记录，邮箱 {email_lower} 可重新验证")
        return True
    
    # 其他状态，默认不允许
    return False


@router.get("/status")
@rate_limit("60/minute")  # 60次/分钟/用户
def get_verification_status(
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_sync_db),
):
    """
    查询认证状态
    
    返回当前用户的学生认证状态，包括：
    - 是否已验证
    - 认证信息（大学、邮箱等）
    - 过期时间
    - 是否可以续期
    - 续期开始时间（renewable_from）
    """
    # 查询用户的最新认证记录（优先verified，其次pending）
    verification = db.query(models.StudentVerification).filter(
        models.StudentVerification.user_id == current_user.id
    ).order_by(
        models.StudentVerification.created_at.desc()
    ).first()
    
    if not verification:
        return {
            "code": 200,
            "data": {
                "is_verified": False,
                "status": None,
                "university": None,
                "email": None,
                "verified_at": None,
                "expires_at": None,
                "days_remaining": None,
                "can_renew": False,
                "renewable_from": None,
                "email_locked": False
            }
        }
    
    # 检查token是否过期（pending状态）
    now = get_utc_time()
    email_locked = False
    token_expired = False
    
    if verification.status == 'pending':
        if verification.token_expires_at:
            if verification.token_expires_at > now:
                email_locked = True
            else:
                # Token已过期，清除pending状态，允许重新提交
                token_expired = True
                logger.info(f"用户 {current_user.id} 的pending认证token已过期，清除状态以允许重新提交")
                # 删除过期的pending记录
                db.delete(verification)
                db.commit()
                # 返回空状态，让用户可以重新提交
                return {
                    "code": 200,
                    "data": {
                        "is_verified": False,
                        "status": None,
                        "university": None,
                        "email": None,
                        "verified_at": None,
                        "expires_at": None,
                        "days_remaining": None,
                        "can_renew": False,
                        "renewable_from": None,
                        "email_locked": False,
                        "token_expired": True
                    }
                }
        else:
            # 没有token_expires_at，视为已过期
            token_expired = True
            logger.info(f"用户 {current_user.id} 的pending认证没有token过期时间，清除状态")
            db.delete(verification)
            db.commit()
            return {
                "code": 200,
                "data": {
                    "is_verified": False,
                    "status": None,
                    "university": None,
                    "email": None,
                    "verified_at": None,
                    "expires_at": None,
                    "days_remaining": None,
                    "can_renew": False,
                    "renewable_from": None,
                    "email_locked": False,
                    "token_expired": True
                }
            }
    
    # 计算过期相关信息
    days_remaining = None
    can_renew_flag = False
    renewable_from = None
    
    if verification.expires_at:
        days_remaining = calculate_days_remaining(verification.expires_at, now)
        can_renew_flag = can_renew(verification.expires_at, now)
        renewable_from = calculate_renewable_from(verification.expires_at)
    
    # 获取大学信息
    university_info = None
    if verification.university:
        university_info = {
            "id": verification.university.id,
            "name": verification.university.name,
            "name_cn": verification.university.name_cn
        }
    
    return {
        "code": 200,
        "data": {
            "is_verified": verification.status == 'verified',
            "status": verification.status,
            "university": university_info,
            "email": verification.email,
            "verified_at": format_iso_utc(verification.verified_at) if verification.verified_at else None,
            "expires_at": format_iso_utc(verification.expires_at) if verification.expires_at else None,
            "days_remaining": days_remaining,
            "can_renew": can_renew_flag,
            "renewable_from": format_iso_utc(renewable_from) if renewable_from else None,
            "email_locked": email_locked,
            "token_expired": False
        }
    }


@router.post("/submit")
@rate_limit("5/minute")  # 5次/分钟/IP
def submit_verification(
    request: Request,
    email: str,
    background_tasks: BackgroundTasks,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_sync_db),
):
    """
    提交认证申请
    
    处理流程：
    1. 验证邮箱格式和.ac.uk后缀
    2. 匹配大学
    3. 检查邮箱唯一性
    4. 生成验证令牌
    5. 创建pending记录
    6. 发送验证邮件
    """
    # 标准化和验证邮箱格式
    email = normalize_email(email)
    
    is_valid, error_message = validate_student_email(email)
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "code": 400,
                "message": error_message,
                "error": "INVALID_EMAIL_FORMAT",
                "details": {
                    "email": email
                }
            }
        )
    
    # 匹配大学
    university = match_university_by_email(email, db)
    if not university:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "code": 400,
                "message": "邮箱后缀不在支持列表中",
                "error": "INVALID_EMAIL_DOMAIN",
                "details": {
                    "email": email,
                    "reason": "该大学不在支持列表中"
                }
            }
        )
    
    # 检查邮箱唯一性
    if not check_email_uniqueness(email, db, exclude_user_id=current_user.id):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": 409,
                "message": "该学生邮箱已被其他用户验证，每个邮箱在同一时间只能被一个用户使用",
                "error": "EMAIL_ALREADY_VERIFIED",
                "details": {
                    "email": email,
                    "reason": "邮箱已被使用",
                    "note": "如果认证已过期，邮箱可以被重新验证"
                }
            }
        )
    
    # 检查用户是否已有活跃的认证（pending或verified）
    existing = db.query(models.StudentVerification).filter(
        models.StudentVerification.user_id == current_user.id,
        models.StudentVerification.status.in_(['pending', 'verified'])
    ).first()
    
    if existing:
        # 如果已有pending记录，更新它
        if existing.status == 'pending':
            # 更新现有记录
            verification = existing
        else:
            # 已有verified记录，不允许重复提交
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": 409,
                    "message": "您已有已验证的认证，如需更换邮箱请使用更换邮箱功能",
                    "error": "ALREADY_VERIFIED"
                }
            )
    else:
        # 创建新的pending记录
        verification = models.StudentVerification(
            user_id=current_user.id,
            university_id=university.id,
            email=email,
            status='pending'
        )
        db.add(verification)
    
    # 生成验证令牌
    token, token_expires_at = generate_verification_token(email)
    verification.verification_token = token
    verification.token_expires_at = token_expires_at
    
    # 计算过期时间（使用当前时间计算，因为还未验证）
    now = get_utc_time()
    verification.expires_at = calculate_expires_at(now)
    
    try:
        db.commit()
        db.refresh(verification)
        logger.info(f"用户 {current_user.id} 提交认证申请: {email} (大学: {university.name})")
    except Exception as e:
        db.rollback()
        logger.error(f"提交认证申请失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "code": 500,
                "message": "提交认证申请失败，请稍后重试",
                "error": "INTERNAL_ERROR"
            }
        )
    
    # 发送验证邮件（异步）
    try:
        from app.config import Config
        from app.email_templates_student_verification import get_student_verification_email
        from app.email_utils import send_email
        
        verification_url = f"{Config.FRONTEND_URL}/student-verification/verify/{token}"
        subject, body = get_student_verification_email('en', verification_url, university.name)
        background_tasks.add_task(send_email, email, subject, body)
        logger.info(f"验证邮件已加入发送队列: {email}")
    except Exception as e:
        logger.error(f"添加邮件发送任务失败: {e}", exc_info=True)
        # 邮件发送失败不影响主流程，只记录日志
    
    return {
        "code": 200,
        "message": "验证邮件已发送",
        "data": {
            "verification_id": verification.id,
            "email": email,
            "university": {
                "id": university.id,
                "name": university.name,
                "name_cn": university.name_cn
            },
            "expires_at": format_iso_utc(verification.expires_at)
        }
    }


@router.get("/verify/{token}")
@rate_limit("10/minute")  # 10次/分钟/IP
def verify_email(
    request: Request,
    token: str,
    db: Session = Depends(get_sync_db),
):
    """
    验证邮箱
    
    处理流程：
    1. 从Redis获取并验证令牌（使用原子操作GETDEL）
    2. 验证成功后立即从Redis删除令牌（确保一次性使用）
    3. 检查邮箱唯一性
    4. 更新认证状态为verified
    5. 设置过期时间
    """
    # 从Redis获取并删除令牌（原子操作）
    redis_client = get_redis_client()
    email_from_redis = None
    
    if redis_client:
        token_key = f"student_verification:token:{token}"
        
        try:
            # 使用GETDEL原子操作（Redis 6.2+）
            email_from_redis = redis_client.getdel(token_key)
            logger.info(f"从Redis获取验证令牌: token={token[:20]}..., email_from_redis={'found' if email_from_redis else 'not found'}")
        except AttributeError:
            # Redis版本不支持GETDEL，使用Lua脚本实现原子操作
            lua_script = """
            local value = redis.call('GET', KEYS[1])
            if value then
                redis.call('DEL', KEYS[1])
            end
            return value
            """
            email_from_redis = redis_client.eval(lua_script, 1, token_key)
            logger.info(f"从Redis获取验证令牌(Lua脚本): token={token[:20]}..., email_from_redis={'found' if email_from_redis else 'not found'}")
        except Exception as e:
            logger.error(f"从Redis获取验证令牌失败: {e}", exc_info=True)
    else:
        logger.warning(f"Redis客户端不可用，将使用数据库fallback验证: token={token[:20]}...")
    
    # 如果Redis中没有token，尝试从数据库查找（fallback机制）
    email = None
    if email_from_redis:
        # 解析邮箱
        if isinstance(email_from_redis, bytes):
            email_from_redis = email_from_redis.decode('utf-8')
        email = normalize_email(email_from_redis)
    else:
        # Redis中没有token，尝试从数据库查找pending记录
        logger.info(f"Redis中未找到token，尝试从数据库查找: token={token[:20]}...")
        verification_check = db.query(models.StudentVerification).filter(
            models.StudentVerification.verification_token == token,
            models.StudentVerification.status == 'pending'
        ).first()
        
        if verification_check:
            # 检查token是否过期
            now = get_utc_time()
            if verification_check.token_expires_at and verification_check.token_expires_at > now:
                # Token未过期，使用数据库中的邮箱
                email = normalize_email(verification_check.email)
                logger.info(f"从数据库找到未过期的token: token={token[:20]}..., email={email}, expires_at={verification_check.token_expires_at}")
            else:
                logger.warning(f"数据库中的token已过期: token={token[:20]}..., expires_at={verification_check.token_expires_at}, now={now}")
    
    if not email:
        # 记录详细信息以便调试
        logger.warning(f"验证令牌无效或已过期: token={token[:20]}..., redis_client={'available' if redis_client else 'unavailable'}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "code": 400,
                "message": "验证令牌无效或已过期",
                "error": "INVALID_TOKEN"
            }
        )
    
    # 查找对应的认证记录
    verification = db.query(models.StudentVerification).filter(
        models.StudentVerification.verification_token == token,
        models.StudentVerification.status == 'pending'
    ).first()
    
    if not verification:
        # 记录详细信息以便调试
        # 检查是否有该token但状态不是pending的记录
        verification_any_status = db.query(models.StudentVerification).filter(
            models.StudentVerification.verification_token == token
        ).first()
        if verification_any_status:
            logger.warning(f"找到认证记录但状态不是pending: token={token[:20]}..., status={verification_any_status.status}, user_id={verification_any_status.user_id}")
        else:
            logger.warning(f"数据库中未找到对应的认证记录: token={token[:20]}...")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "code": 400,
                "message": "验证令牌无效或已过期",
                "error": "INVALID_TOKEN"
            }
        )
    
    logger.info(f"找到待验证的认证记录: verification_id={verification.id}, user_id={verification.user_id}, email={verification.email}")
    
    # 验证邮箱是否匹配
    if verification.email.lower() != email:
        logger.error(f"邮箱不匹配: Redis中的email={email}, DB中的email={verification.email}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "code": 400,
                "message": "验证令牌无效或已过期",
                "error": "INVALID_TOKEN"
            }
        )
    
    # 再次检查邮箱唯一性（防止并发验证）
    if not check_email_uniqueness(email, db, exclude_user_id=verification.user_id):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": 409,
                "message": "该学生邮箱已被其他用户验证",
                "error": "EMAIL_ALREADY_VERIFIED"
            }
        )
    
    # 更新认证状态
    now = get_utc_time()
    verification.status = 'verified'
    verification.verified_at = now
    verification.expires_at = calculate_expires_at(now)  # 使用验证时间计算过期时间
    
    # 记录历史
    history = models.VerificationHistory(
        verification_id=verification.id,
        user_id=verification.user_id,
        university_id=verification.university_id,
        email=verification.email,
        action='verified',
        previous_status='pending',
        new_status='verified'
    )
    db.add(history)
    
    try:
        db.commit()
        db.refresh(verification)
        logger.info(f"用户 {verification.user_id} 邮箱验证成功: {email} (认证ID: {verification.id}, status={verification.status})")
        
        # 验证状态确实已更新
        if verification.status != 'verified':
            logger.error(f"验证后状态异常: verification_id={verification.id}, expected=verified, actual={verification.status}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail={
                    "code": 500,
                    "message": "验证状态更新失败，请稍后重试",
                    "error": "STATUS_UPDATE_FAILED"
                }
            )
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"邮箱验证失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "code": 500,
                "message": "验证失败，请稍后重试",
                "error": "INTERNAL_ERROR"
            }
        )
    
    return {
        "code": 200,
        "message": "验证成功",
        "data": {
            "verification_id": verification.id,
            "status": "verified",
            "verified_at": format_iso_utc(verification.verified_at),
            "expires_at": format_iso_utc(verification.expires_at)
        }
    }


@router.post("/renew")
@rate_limit("5/minute")  # 5次/分钟/IP
def renew_verification(
    request: Request,
    email: str,
    background_tasks: BackgroundTasks,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_sync_db),
):
    """申请续期"""
    # 检查用户是否有已验证的认证
    current_verification = db.query(models.StudentVerification).filter(
        models.StudentVerification.user_id == current_user.id,
        models.StudentVerification.status == 'verified'
    ).first()
    
    if not current_verification:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": 400, "message": "您还没有已验证的认证，无法续期", "error": "NO_VERIFIED_VERIFICATION"}
        )
    
    # 标准化和验证邮箱格式
    email = normalize_email(email)
    
    is_valid, error_message = validate_student_email(email)
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "code": 400,
                "message": error_message,
                "error": "INVALID_EMAIL_FORMAT",
                "details": {
                    "email": email
                }
            }
        )
    
    # 验证邮箱是否匹配
    if email != current_verification.email.lower():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "code": 400,
                "message": "邮箱不匹配，请使用您之前验证的邮箱",
                "error": "EMAIL_MISMATCH",
                "details": {
                    "provided_email": email,
                    "verified_email": current_verification.email
                }
            }
        )
    
    # 检查是否可以续期
    if not can_renew(current_verification.expires_at):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "code": 400,
                "message": "距离过期时间超过30天，暂时无法续期",
                "error": "CANNOT_RENEW_YET",
                "details": {"renewable_from": format_iso_utc(calculate_renewable_from(current_verification.expires_at))}
            }
        )
    
    # 检查邮箱唯一性
    if not check_email_uniqueness(email, db, exclude_user_id=current_user.id):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": 409, "message": "该学生邮箱已被其他用户验证，无法用于续期", "error": "EMAIL_ALREADY_VERIFIED"}
        )
    
    # 匹配大学
    university = match_university_by_email(email, db)
    if not university:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "code": 400,
                "message": "邮箱后缀不在支持列表中",
                "error": "INVALID_EMAIL_DOMAIN",
                "details": {
                    "email": email,
                    "reason": "该大学不在支持列表中"
                }
            }
        )
    
    # 生成验证令牌并创建新记录
    token, token_expires_at = generate_verification_token(email)
    now = get_utc_time()
    verification = models.StudentVerification(
        user_id=current_user.id,
        university_id=university.id,
        email=email,
        status='pending',
        verification_token=token,
        token_expires_at=token_expires_at,
        expires_at=calculate_expires_at(now)
    )
    db.add(verification)
    
    # 记录历史
    history = models.VerificationHistory(
        verification_id=current_verification.id,
        user_id=current_user.id,
        university_id=university.id,
        email=email,
        action='renewed',
        previous_status='verified',
        new_status='pending'
    )
    db.add(history)
    
    try:
        db.commit()
        db.refresh(verification)
        logger.info(f"用户 {current_user.id} 申请续期: {email} (认证ID: {verification.id})")
    except Exception as e:
        db.rollback()
        logger.error(f"申请续期失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "code": 500,
                "message": "申请续期失败，请稍后重试",
                "error": "INTERNAL_ERROR"
            }
        )
    
    # 发送验证邮件
    try:
        from app.config import Config
        from app.email_templates_student_verification import get_student_verification_email
        from app.email_utils import send_email
        verification_url = f"{Config.FRONTEND_URL}/student-verification/verify/{token}"
        subject, body = get_student_verification_email('en', verification_url, university.name)
        background_tasks.add_task(send_email, email, subject, body)
        logger.info(f"续期验证邮件已加入发送队列: {email}")
    except Exception as e:
        logger.error(f"添加续期邮件发送任务失败: {e}", exc_info=True)
        # 邮件发送失败不影响主流程，只记录日志
    
    return {
        "code": 200,
        "message": "续期验证邮件已发送",
        "data": {
            "verification_id": verification.id,
            "new_expires_at": format_iso_utc(verification.expires_at)
        }
    }


@router.post("/change-email")
@rate_limit("5/minute")  # 5次/分钟/IP
def change_email(
    request: Request,
    new_email: str,
    background_tasks: BackgroundTasks,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_sync_db),
):
    """更换邮箱（改绑）"""
    # 检查是否有已验证的认证
    current_verification = db.query(models.StudentVerification).filter(
        models.StudentVerification.user_id == current_user.id,
        models.StudentVerification.status == 'verified'
    ).first()
    
    if not current_verification:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": 400, "message": "当前用户没有已验证的认证，无法更换邮箱", "error": "NO_VERIFIED_VERIFICATION"}
        )
    
    # 标准化和验证新邮箱格式
    new_email = normalize_email(new_email)
    
    is_valid, error_message = validate_student_email(new_email)
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "code": 400,
                "message": error_message,
                "error": "INVALID_EMAIL_FORMAT",
                "details": {
                    "email": new_email
                }
            }
        )
    
    # 匹配大学
    university = match_university_by_email(new_email, db)
    if not university:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": 400, "message": "邮箱后缀不在支持列表中", "error": "INVALID_EMAIL_DOMAIN"}
        )
    
    # 检查新邮箱唯一性
    if not check_email_uniqueness(new_email, db, exclude_user_id=current_user.id):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": 409, "message": "新邮箱已被其他用户验证", "error": "EMAIL_ALREADY_VERIFIED"}
        )
    
    # 撤销旧认证
    old_email = current_verification.email
    now = get_utc_time()
    current_verification.status = 'revoked'
    current_verification.revoked_at = now
    current_verification.revoked_reason = "用户更换邮箱"
    current_verification.revoked_reason_type = "user_request"
    
    # 创建新认证记录
    token, token_expires_at = generate_verification_token(new_email)
    verification = models.StudentVerification(
        user_id=current_user.id,
        university_id=university.id,
        email=new_email,
        status='pending',
        verification_token=token,
        token_expires_at=token_expires_at,
        expires_at=calculate_expires_at(now)
    )
    db.add(verification)
    
    # 记录历史
    history = models.VerificationHistory(
        verification_id=current_verification.id,
        user_id=current_user.id,
        university_id=university.id,
        email=new_email,
        action='email_changed',
        previous_status='verified',
        new_status='pending'
    )
    db.add(history)
    
    try:
        db.commit()
        db.refresh(verification)
        logger.info(f"用户 {current_user.id} 更换邮箱: {old_email} -> {new_email} (认证ID: {verification.id})")
    except Exception as e:
        db.rollback()
        logger.error(f"更换邮箱失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "code": 500,
                "message": "更换邮箱失败，请稍后重试",
                "error": "INTERNAL_ERROR"
            }
        )
    
    # 发送验证邮件
    try:
        from app.config import Config
        from app.email_templates_student_verification import get_student_verification_email
        from app.email_utils import send_email
        verification_url = f"{Config.FRONTEND_URL}/student-verification/verify/{token}"
        subject, body = get_student_verification_email('en', verification_url, university.name)
        background_tasks.add_task(send_email, new_email, subject, body)
        logger.info(f"更换邮箱验证邮件已加入发送队列: {new_email}")
    except Exception as e:
        logger.error(f"添加更换邮箱邮件发送任务失败: {e}", exc_info=True)
        # 邮件发送失败不影响主流程，只记录日志
    
    return {
        "code": 200,
        "message": "验证邮件已发送到新邮箱",
        "data": {
            "old_email": old_email,
            "new_email": new_email,
            "verification_id": verification.id,
            "university": {"id": university.id, "name": university.name, "name_cn": university.name_cn}
        }
    }


@router.get("/user/{user_id}/status")
@rate_limit("60/minute")  # 60次/分钟/IP
def get_user_verification_status(
    request: Request,
    user_id: str,
    db: Session = Depends(get_sync_db),
):
    """
    查询指定用户的学生认证状态（公开信息）
    
    返回指定用户的学生认证状态，只包含公开信息：
    - 是否已验证
    - 大学信息（不包含邮箱等敏感信息）
    """
    # 查询用户的最新认证记录（只查询verified状态）
    verification = db.query(models.StudentVerification).filter(
        models.StudentVerification.user_id == user_id,
        models.StudentVerification.status == 'verified'
    ).order_by(
        models.StudentVerification.created_at.desc()
    ).first()
    
    if not verification:
        return {
            "code": 200,
            "data": {
                "is_verified": False,
                "university": None
            }
        }
    
    # 获取大学信息（公开信息）
    university_info = None
    if verification.university:
        university_info = {
            "id": verification.university.id,
            "name": verification.university.name,
            "name_cn": verification.university.name_cn
        }
    
    return {
        "code": 200,
        "data": {
            "is_verified": True,
            "university": university_info
        }
    }


@router.get("/universities")
@rate_limit("60/minute")  # 60次/分钟/IP
def get_universities(
    request: Request,
    search: Optional[str] = None,
    page: int = 1,
    page_size: int = 20,
    db: Session = Depends(get_sync_db),
):
    """获取支持的大学列表"""
    query = db.query(models.University).filter(models.University.is_active == True)
    
    if search:
        search_term = f"%{search.lower()}%"
        query = query.filter(
            or_(
                models.University.name.ilike(search_term),
                models.University.name_cn.ilike(search_term),
                models.University.email_domain.ilike(search_term)
            )
        )
    
    total = query.count()
    offset = (page - 1) * page_size
    universities = query.order_by(models.University.name).offset(offset).limit(page_size).all()
    
    return {
        "code": 200,
        "data": {
            "total": total,
            "page": page,
            "page_size": page_size,
            "items": [
                {"id": u.id, "name": u.name, "name_cn": u.name_cn, "email_domain": u.email_domain}
                for u in universities
            ]
        }
    }

