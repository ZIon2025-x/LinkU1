"""
System / public-info domain routes — extracted from app/routers.py (Task 7).

Includes:
  - GET  /stats
  - GET  /system-settings/public
  - GET  /user-preferences
  - PUT  /user-preferences
  - GET  /timezone/info
  - GET  /job-positions
  - POST /job-applications
  - GET  /banners
  - GET  /app/version-check
  - GET  /faq
  - GET  /legal/{doc_type}

Mounts at both /api and /api/users via main.py (same as the original main_router).
"""
import logging
import os
from typing import Optional

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    UploadFile,
)
from sqlalchemy.orm import Session

from app import crud, models, schemas
from app.cache import cache_response
from app.config import Config
from app.deps import get_current_user_secure_sync_csrf, get_db
from app.email_utils import send_email_with_attachment
from app.performance_monitor import measure_api_performance
from app.rate_limiting import rate_limit
from app.utils.time_utils import format_iso_utc
# `_parse_semver` stays as a module-level helper in app/routers.py per the
# split plan; we re-import it here for /app/version-check.
from app.routers import _parse_semver

logger = logging.getLogger(__name__)

router = APIRouter()


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
