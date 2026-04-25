"""
Profile domain routes — extracted from app/routers.py (Task 11).

Includes 9 routes covering user profile read/write + account deletion +
per-user task statistics:
  - PATCH  /profile/timezone
  - GET    /profile/me
  - GET    /profile/{user_id}
  - POST   /profile/send-email-update-code
  - POST   /profile/send-phone-update-code
  - PATCH  /profile/avatar
  - PATCH  /profile
  - DELETE /users/account
  - GET    /users/{user_id}/task-statistics

Mounts at both /api and /api/users via main.py.
"""
import logging
from datetime import datetime, time, timezone
from typing import Optional

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Body,
    Depends,
    HTTPException,
    Request,
    Response,
)
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from sqlalchemy import func
from sqlalchemy.orm import Session

from app import crud, models, schemas
from app.cache import cache_response
from app.deps import (
    check_user_status,
    get_current_user_optional,
    get_current_user_secure_sync_csrf,
    get_db,
)
from app.performance_monitor import measure_api_performance
from app.rate_limiting import rate_limit
# Module-level helpers stay in app/routers.py per the split plan.
from app.routers import (
    _safe_parse_images,
    _trigger_background_translation_prefetch,
)
from app.utils.time_utils import format_iso_utc, get_utc_time

logger = logging.getLogger(__name__)

router = APIRouter()


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
        ).filter(Review.user_id == current_user.id, Review.is_deleted.is_(False)).first()
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

        # 检查用户是否是任务达人。
        # 两条路径都算"达人":
        #   1. 老的个人达人模型 (task_experts 表) —— 迁移 159 之前申请的用户
        #   2. 新的团队模型 (expert_members 表) —— 团队 owner / admin / member
        # 任一存在即返回 True,这样 Flutter profile 页面的"达人管理"入口对
        # 通过 admin_expert_routes 新审批的团队 owner 也可见(spec §0.1)。
        from app.utils.expert_helpers import is_user_expert_sync
        is_expert = is_user_expert_sync(db, current_user.id)

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

    # 计算发布的任务数（所有状态，排除咨询占位任务）
    posted_tasks_count = db.query(Task).filter(
        Task.poster_id == user_id,
        Task.is_consultation_placeholder == False,
    ).count()

    # 计算接取的任务数（所有状态）
    taken_tasks_count = db.query(Task).filter(
        Task.taker_id == user_id,
        Task.is_consultation_placeholder == False,  # noqa: E712
    ).count()

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
        db.query(func.avg(Review.rating))
        .filter(Review.user_id == user_id, Review.is_deleted.is_(False))
        .scalar()
    )
    avg_rating = float(avg_rating_result) if avg_rating_result is not None else 0.0

    # 检查用户是否是任务达人:老的 task_experts 或新的 expert_members 任一即可
    # 详见 get_my_profile 同名注释
    from app.utils.expert_helpers import is_user_expert_sync
    is_expert = is_user_expert_sync(db, user_id)

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
