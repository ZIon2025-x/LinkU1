"""
任务达人功能API路由 (LEGACY)
============================

[B1 收口标记 - 2026-04-08]

这个文件是 Phase 1 时代的"个人达人"系统遗留 API,Phase 2 之后被新的
"达人团队"系统(`expert_routes.py` + 11 个 expert_*.py)替代。

已经做的迁移:
  - migration 168/169/170 把所有 task_experts 数据迁移到 experts +
    expert_members + _expert_id_migration_map
  - migration 185 (B1) 做 catch-up,处理 168 之后新建的 task_experts
  - admin_official_routes.setup_official_account 现在同时 mirror 到新表
  - 1 人团队语义: 每个 task_experts 行 = 一个 1 人团队 (owner = 自己)

仍保留运行的 endpoint (前端还在用,**不要直接删**):

  POST   /apply                                              -> 用户申请成为达人
                                                                ⚠️ DEPRECATED: 新 client 应走 /api/experts/apply
  GET    /my-application                                     -> 查申请状态
                                                                ⚠️ DEPRECATED: 新 client 走 /api/experts/my-applications
  GET    /                                                   -> 公开达人列表 (按 task_experts)
                                                                ⚠️ 仅服务 legacy 个人达人浏览;团队走 /api/experts/
  GET    /{expert_id}                                        -> 公开达人详情
  GET    /services/{service_id}                              -> 公开服务详情
  GET    /services/{service_id}/applications                 -> 服务申请列表 (公开 + owner)
  POST   /services/{service_id}/applications/{id}/reply      -> 所有者回复申请
  GET    /services/{service_id}/reviews                      -> 服务评价
  GET    /{expert_id}/reviews                                -> 达人评价
  GET    /{expert_id}/services                               -> 达人公开服务列表

未来计划:
  Phase 3 (待定): 当前端 (frontend/admin/Flutter) 全部切换到 /api/experts/*
  之后,这个文件可以全量删除。在那之前,所有 endpoint 的 SQL 仍然走旧
  task_experts 表 + 通过 _expert_id_migration_map 桥接到新模型。

不要在此文件添加新 endpoint。新 endpoint 一律加到 expert_*.py。
"""

import json
import logging
from datetime import datetime, timedelta, timezone, date, time as dt_time
from decimal import Decimal
from typing import List, Optional

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    HTTPException,
    Query,
    Request,
    status,
)
from sqlalchemy import select, update, and_, or_, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.exc import IntegrityError

from app import models, schemas
from app.deps import get_async_db_dependency
from app.separate_auth_deps import get_current_admin
from app.async_routers import get_current_user_optional
from app.utils.time_utils import get_utc_time, format_iso_utc

logger = logging.getLogger(__name__)


def _payment_method_types_for_currency(currency: str) -> list:
    """根据货币动态返回 Stripe 支持的支付方式列表"""
    c = currency.lower()
    methods = ["card"]
    if c in ("gbp", "cny"):
        methods.extend(["wechat_pay", "alipay"])
    return methods


# 创建任务达人路由器
task_expert_router = APIRouter(prefix="/api/task-experts", tags=["task-experts"])


def _get_language_from_request(request: Request) -> str:
    """从 Accept-Language 请求头获取语言偏好
    
    与 forum_routes.get_user_language_preference 逻辑一致，
    简化版本（公开接口无需检查用户设置）。
    """
    accept_language = request.headers.get("Accept-Language", "")
    if accept_language:
        for lang in accept_language.split(','):
            lang = lang.split(';')[0].strip().lower()
            if lang.startswith('zh'):
                return 'zh'
            elif lang.startswith('en'):
                return 'en'
    return 'en'


# 认证依赖
async def get_current_user_secure_async_csrf(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
) -> models.User:
    """CSRF保护的安全用户认证（异步版本）"""
    from app.secure_auth import validate_session
    
    session = validate_session(request)
    if session:
        from app import async_crud
        user = await async_crud.async_user_crud.get_user_by_id(db, session.user_id)
        if user:
            if hasattr(user, "is_suspended") and user.is_suspended:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN, detail="账户已被暂停"
                )
            if hasattr(user, "is_banned") and user.is_banned:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN, detail="账户已被封禁"
                )
            return user
    
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供有效的认证信息"
    )


async def get_current_expert(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
) -> models.TaskExpert:
    """获取当前用户的任务达人身份"""
    expert = await db.execute(
        select(models.TaskExpert).where(models.TaskExpert.id == current_user.id)
    )
    expert = expert.scalar_one_or_none()
    if not expert:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="您还不是任务达人"
        )
    if expert.status != "active":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="任务达人账户未激活"
        )
    return expert


# ==================== 任务达人申请相关接口 ====================

@task_expert_router.post("/apply", response_model=schemas.TaskExpertApplicationOut)
async def apply_to_be_expert(
    application_data: schemas.TaskExpertApplicationCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """用户申请成为任务达人"""
    # 检查是否已有待审核的申请
    existing = await db.execute(
        select(models.TaskExpertApplication)
        .where(models.TaskExpertApplication.user_id == current_user.id)
        .where(models.TaskExpertApplication.status == "pending")
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="您已提交申请，请等待审核"
        )
    
    # 检查是否已经是任务达人
    expert = await db.execute(
        select(models.TaskExpert).where(models.TaskExpert.id == current_user.id)
    )
    if expert.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="您已经是任务达人"
        )
    
    # B1: 这个 endpoint 是 legacy。新 client 应走 /api/experts/apply。
    # 我们仍创建 TaskExpertApplication (back-compat),但同时 mirror 到新
    # ExpertApplication 表,这样 admin 在新 dashboard 也能审批
    logger.warning(
        f"[DEPRECATED] /api/task-experts/apply called by user {current_user.id}. "
        f"New clients should call /api/experts/apply instead."
    )

    # 创建 legacy 申请
    new_application = models.TaskExpertApplication(
        user_id=current_user.id,
        application_message=application_data.application_message,
        status="pending",
    )
    db.add(new_application)

    # B1: 同时创建新 ExpertApplication (如果还没有 pending)
    try:
        from app.models_expert import ExpertApplication
        existing_new = await db.execute(
            select(ExpertApplication).where(
                and_(
                    ExpertApplication.user_id == current_user.id,
                    ExpertApplication.status == "pending",
                )
            )
        )
        if not existing_new.scalar_one_or_none():
            mirror_app = ExpertApplication(
                user_id=current_user.id,
                expert_name=current_user.name or f"User {current_user.id}",
                bio=None,
                avatar=None,
                application_message=application_data.application_message,
                status="pending",
            )
            db.add(mirror_app)
    except Exception as e:
        logger.warning(f"Failed to mirror to ExpertApplication: {e}")

    await db.commit()
    await db.refresh(new_application)

    # 发送通知给管理员
    from app.task_notifications import send_expert_application_notification
    try:
        await send_expert_application_notification(db, current_user.id)
    except Exception as e:
        logger.error(f"Failed to send notification: {e}")

    return new_application


@task_expert_router.get("/my-application", response_model=schemas.TaskExpertApplicationOut)
async def get_my_application(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取用户的最新申请状态"""
    application = await db.execute(
        select(models.TaskExpertApplication)
        .where(models.TaskExpertApplication.user_id == current_user.id)
        .order_by(models.TaskExpertApplication.created_at.desc())
        .limit(1)
    )
    application = application.scalar_one_or_none()
    if not application:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="未找到申请记录"
        )
    return application


# ==================== 任务达人管理接口 ====================

@task_expert_router.get("")
async def get_experts_list(
    request: Request,
    category: Optional[str] = Query(None, description="分类筛选"),
    location: Optional[str] = Query(None, description="城市位置筛选"),
    keyword: Optional[str] = Query(None, description="关键词搜索（名称/简介/技能）"),
    sort: Optional[str] = Query(None, description="排序方式: random=随机排序"),
    status_filter: Optional[str] = Query("active", alias="status"),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取任务达人列表（公开接口，登录后返回 is_following）

    优先从 FeaturedTaskExpert 表获取精选任务达人，如果没有则从 TaskExpert 表获取。
    根据 Accept-Language 请求头自动返回对应语言的双语字段。
    支持 category 和 location 筛选。location 支持中英文城市名（如 London / 伦敦）。
    sort=random 时随机排序，offset 被忽略（随机排序无法稳定分页）。
    """
    import json
    from app.utils.city_filter_utils import build_city_location_filter
    
    # 获取用户语言偏好（从 Accept-Language 请求头）
    user_lang = _get_language_from_request(request)
    
    # 首先尝试从 FeaturedTaskExpert 表获取（精选任务达人）
    featured_query = select(models.FeaturedTaskExpert).where(
        models.FeaturedTaskExpert.is_active == 1
    )
    
    if category:
        featured_query = featured_query.where(
            models.FeaturedTaskExpert.category == category
        )
    
    if location:
        # 使用 build_city_location_filter 进行大小写不敏感的城市匹配
        location_filter = build_city_location_filter(models.FeaturedTaskExpert.location, location.strip())
        if location_filter is not None:
            featured_query = featured_query.where(location_filter)

    if keyword and keyword.strip():
        from app.utils.search_expander import build_keyword_filter
        keyword_expr = build_keyword_filter(
            columns=[
                models.FeaturedTaskExpert.name,
                models.FeaturedTaskExpert.bio,
                models.FeaturedTaskExpert.bio_en,
                models.FeaturedTaskExpert.expertise_areas,
                models.FeaturedTaskExpert.expertise_areas_en,
                models.FeaturedTaskExpert.featured_skills,
                models.FeaturedTaskExpert.featured_skills_en,
                models.FeaturedTaskExpert.category,
            ],
            keyword=keyword.strip(),
            use_similarity=False,
        )
        if keyword_expr is not None:
            featured_query = featured_query.where(keyword_expr)
    
    if sort == 'random':
        from sqlalchemy.sql.expression import func as sql_func
        featured_query = featured_query.order_by(sql_func.random()).limit(limit)
    else:
        featured_query = featured_query.order_by(
            models.FeaturedTaskExpert.display_order,
            models.FeaturedTaskExpert.created_at.desc()
        ).offset(offset).limit(limit)
    
    featured_result = await db.execute(featured_query)
    featured_experts = featured_result.scalars().all()
    
    # 如果有精选任务达人，返回它们
    if featured_experts:
        items = []
        for expert in featured_experts:
            # 解析 JSON 字段（中文 + 英文版本）
            expertise_areas = json.loads(expert.expertise_areas) if expert.expertise_areas else []
            expertise_areas_en = json.loads(expert.expertise_areas_en) if expert.expertise_areas_en else []
            featured_skills = json.loads(expert.featured_skills) if expert.featured_skills else []
            featured_skills_en = json.loads(expert.featured_skills_en) if expert.featured_skills_en else []
            achievements = json.loads(expert.achievements) if expert.achievements else []
            achievements_en = json.loads(expert.achievements_en) if expert.achievements_en else []
            
            # 根据语言选择显示字段（与论坛双语模式一致）
            display_bio = expert.bio or ""
            if user_lang == 'en' and expert.bio_en:
                display_bio = expert.bio_en
            
            display_specialties = expertise_areas
            if user_lang == 'en' and expertise_areas_en:
                display_specialties = expertise_areas_en
            
            display_featured_skills = featured_skills
            if user_lang == 'en' and featured_skills_en:
                display_featured_skills = featured_skills_en
            
            display_achievements = achievements
            if user_lang == 'en' and achievements_en:
                display_achievements = achievements_en
            
            display_response_time = expert.response_time or ""
            if user_lang == 'en' and expert.response_time_en:
                display_response_time = expert.response_time_en
            
            # 从 FeaturedTaskExpert 转换为前端需要的格式
            # 字段名以 React 前端 TaskExperts.tsx interface TaskExpert 为准
            # 同时增加双语字段（_en/_zh）供 Flutter 使用
            expert_dict = {
                # === 基础字段（与 React 前端 interface 一致） ===
                "id": expert.id,
                "name": expert.name,
                "avatar": expert.avatar,
                "user_level": expert.user_level,
                "avg_rating": expert.avg_rating or 0,
                "completed_tasks": expert.completed_tasks or 0,
                "total_tasks": expert.total_tasks or 0,
                "completion_rate": round(expert.completion_rate or 0, 1),
                "is_verified": bool(expert.is_verified),
                "success_rate": expert.success_rate or 0,
                "location": expert.location if expert.location and expert.location.strip() else "Online",
                "category": expert.category,
                "created_at": format_iso_utc(expert.created_at) if expert.created_at else None,
                "updated_at": format_iso_utc(expert.updated_at) if expert.updated_at else None,
                # === 双语字段：bio ===
                "bio": display_bio,
                "bio_en": expert.bio_en or "",
                "bio_zh": expert.bio or "",
                # === 双语字段：expertise_areas（专业领域） ===
                "expertise_areas": display_specialties,
                "expertise_areas_en": expertise_areas_en,
                "specialties_zh": expertise_areas,  # Flutter 使用
                # === 双语字段：featured_skills（特色技能） ===
                "featured_skills": display_featured_skills,
                "featured_skills_en": featured_skills_en,
                "featured_skills_zh": featured_skills,
                # === 双语字段：achievements（成就） ===
                "achievements": display_achievements,
                "achievements_en": achievements_en,
                "achievements_zh": achievements,
                # === 双语字段：response_time ===
                "response_time": display_response_time,
                "response_time_en": expert.response_time_en or "",
                "response_time_zh": expert.response_time or "",
            }
            items.append(expert_dict)
        return await _attach_is_following(items, request, db)

    # 如果没有精选任务达人，从 TaskExpert 表获取
    query = select(models.TaskExpert).where(
        models.TaskExpert.status == status_filter
    )

    if keyword and keyword.strip():
        from app.utils.search_expander import build_keyword_filter
        keyword_expr = build_keyword_filter(
            columns=[
                models.TaskExpert.expert_name,
                models.TaskExpert.bio,
            ],
            keyword=keyword.strip(),
            use_similarity=False,
        )
        if keyword_expr is not None:
            query = query.where(keyword_expr)
    
    # 分页查询
    if sort == 'random':
        from sqlalchemy.sql.expression import func as sql_func
        query = query.order_by(sql_func.random()).limit(limit)
    else:
        query = query.order_by(
            models.TaskExpert.is_official.desc(),
            models.TaskExpert.created_at.desc()
        ).offset(offset).limit(limit)
    
    result = await db.execute(query)
    experts = result.scalars().all()

    # Batch-load Users and FeaturedTaskExpert to avoid N+1 (was 2N extra queries per page)
    expert_ids = [e.id for e in experts]
    users_by_id: dict = {}
    featured_by_id: dict = {}
    if expert_ids:
        users_result = await db.execute(
            select(models.User).where(models.User.id.in_(expert_ids))
        )
        users_by_id = {u.id: u for u in users_result.scalars().all()}
        featured_result = await db.execute(
            select(models.FeaturedTaskExpert).where(
                models.FeaturedTaskExpert.id.in_(expert_ids)
            )
        )
        featured_by_id = {f.id: f for f in featured_result.scalars().all()}

    # 加载关联的用户信息，构建与 FeaturedTaskExpert 路径相同格式的响应
    items = []
    for expert in experts:
        user = users_by_id.get(expert.id)
        featured_expert = featured_by_id.get(expert.id)
        
        # 确定各字段值
        display_name = user.name if user else (expert.expert_name or "")
        avatar = ""
        if featured_expert and featured_expert.avatar:
            avatar = featured_expert.avatar
        elif user:
            avatar = user.avatar or ""
        
        location_val = "Online"
        if featured_expert and featured_expert.location:
            location_val = featured_expert.location
        elif user and hasattr(user, 'residence_city') and user.residence_city:
            location_val = user.residence_city
        
        # 使用与 FeaturedTaskExpert 路径一致的字段名（React 前端格式）
        expert_dict = {
            "id": expert.id,
            "name": display_name,
            "avatar": avatar,
            "user_level": "normal",
            "avg_rating": float(expert.rating) if expert.rating else 0,
            "completed_tasks": expert.completed_tasks or 0,
            "total_tasks": expert.total_services or 0,
            "completion_rate": 0,
            "is_verified": False,
            "bio": expert.bio or "",
            "success_rate": 0,
            "location": location_val,
            "expertise_areas": [],
            "featured_skills": [],
            "achievements": [],
            "response_time": "",
            "created_at": format_iso_utc(expert.created_at) if expert.created_at else None,
        }
        
        # 如果有 FeaturedTaskExpert 关联，补充双语字段和扩展数据
        if featured_expert:
            bio_zh = featured_expert.bio or ""
            bio_en = featured_expert.bio_en or ""
            expert_dict["bio"] = bio_en if user_lang == 'en' and bio_en else bio_zh
            expert_dict["bio_en"] = bio_en
            expert_dict["bio_zh"] = bio_zh
            expert_dict["user_level"] = featured_expert.user_level or "normal"
            expert_dict["is_verified"] = bool(featured_expert.is_verified)
            expert_dict["success_rate"] = featured_expert.success_rate or 0
            expert_dict["completion_rate"] = round(featured_expert.completion_rate or 0, 1)
            expert_dict["total_tasks"] = featured_expert.total_tasks or expert_dict["total_tasks"]
            
            ea = json.loads(featured_expert.expertise_areas) if featured_expert.expertise_areas else []
            ea_en = json.loads(featured_expert.expertise_areas_en) if featured_expert.expertise_areas_en else []
            expert_dict["expertise_areas"] = ea_en if user_lang == 'en' and ea_en else ea
            expert_dict["expertise_areas_en"] = ea_en
            expert_dict["specialties_zh"] = ea
            
            fs = json.loads(featured_expert.featured_skills) if featured_expert.featured_skills else []
            fs_en = json.loads(featured_expert.featured_skills_en) if featured_expert.featured_skills_en else []
            expert_dict["featured_skills"] = fs_en if user_lang == 'en' and fs_en else fs
            expert_dict["featured_skills_en"] = fs_en
            expert_dict["featured_skills_zh"] = fs
            
            ach = json.loads(featured_expert.achievements) if featured_expert.achievements else []
            ach_en = json.loads(featured_expert.achievements_en) if featured_expert.achievements_en else []
            expert_dict["achievements"] = ach_en if user_lang == 'en' and ach_en else ach
            expert_dict["achievements_en"] = ach_en
            expert_dict["achievements_zh"] = ach
            
            expert_dict["response_time"] = featured_expert.response_time_en if user_lang == 'en' and featured_expert.response_time_en else (featured_expert.response_time or "")
            expert_dict["response_time_en"] = featured_expert.response_time_en or ""
            expert_dict["response_time_zh"] = featured_expert.response_time or ""
        
        items.append(expert_dict)

    return await _attach_is_following(items, request, db)


async def _attach_is_following(items: list, request, db) -> list:
    """批量查询当前用户是否关注了列表中的达人"""
    if not items:
        return items

    # 可选鉴权：尝试从 request 获取当前用户 ID
    current_user_id = None
    try:
        from app.secure_auth import validate_session
        session = validate_session(request)
        if session:
            current_user_id = session.user_id
    except Exception:
        pass

    if not current_user_id:
        for item in items:
            item['is_following'] = False
        return items

    expert_ids = [item['id'] for item in items]
    from sqlalchemy import select as sa_select
    result = await db.execute(
        sa_select(models.UserFollow.following_id).where(
            models.UserFollow.follower_id == current_user_id,
            models.UserFollow.following_id.in_(expert_ids),
        )
    )
    following_ids = set(result.scalars().all())
    for item in items:
        item['is_following'] = item['id'] in following_ids
    return items


@task_expert_router.get("/{expert_id}")
async def get_expert(
    request: Request,
    expert_id: str,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取任务达人信息（优先从 FeaturedTaskExpert 获取，与列表接口保持一致）
    
    响应格式与列表接口一致，包含完整的双语字段（_en/_zh）。
    """
    user_lang = _get_language_from_request(request)
    
    # 优先从 FeaturedTaskExpert 获取数据（与列表接口保持一致）
    featured_expert = await db.execute(
        select(models.FeaturedTaskExpert).where(models.FeaturedTaskExpert.id == expert_id)
    )
    featured_expert = featured_expert.scalar_one_or_none()
    
    # 如果 FeaturedTaskExpert 不存在，从 TaskExpert 获取基础信息
    expert = await db.execute(
        select(models.TaskExpert).where(models.TaskExpert.id == expert_id)
    )
    expert = expert.scalar_one_or_none()
    
    if not expert and not featured_expert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="任务达人不存在"
        )
    
    # 加载用户信息以获取名称和头像
    from app import async_crud
    user = await async_crud.async_user_crud.get_user_by_id(db, expert_id)
    
    # 优先使用 FeaturedTaskExpert 的数据（与列表接口保持一致）
    if featured_expert:
        import json
        # 解析 JSON 字段
        ea = json.loads(featured_expert.expertise_areas) if featured_expert.expertise_areas else []
        ea_en = json.loads(featured_expert.expertise_areas_en) if featured_expert.expertise_areas_en else []
        fs = json.loads(featured_expert.featured_skills) if featured_expert.featured_skills else []
        fs_en = json.loads(featured_expert.featured_skills_en) if featured_expert.featured_skills_en else []
        ach = json.loads(featured_expert.achievements) if featured_expert.achievements else []
        ach_en = json.loads(featured_expert.achievements_en) if featured_expert.achievements_en else []
        
        result_dict = {
            # 基础字段（与 React 前端一致）
            "id": featured_expert.id,
            "name": featured_expert.name,
            "avatar": featured_expert.avatar or "",
            "user_level": featured_expert.user_level,
            "avg_rating": featured_expert.avg_rating or 0.0,
            "completed_tasks": featured_expert.completed_tasks or 0,
            "total_tasks": featured_expert.total_tasks or 0,
            "completion_rate": round(featured_expert.completion_rate or 0.0, 1),
            "is_verified": bool(featured_expert.is_verified),
            "success_rate": featured_expert.success_rate or 0.0,
            "location": featured_expert.location or "Online",
            "category": featured_expert.category,
            "status": expert.status if expert else "active",
            "total_services": expert.total_services if expert else 0,
            "created_at": format_iso_utc(featured_expert.created_at) if featured_expert.created_at else None,
            "updated_at": format_iso_utc(featured_expert.updated_at) if featured_expert.updated_at else None,
            # 双语：bio
            "bio": featured_expert.bio_en if user_lang == 'en' and featured_expert.bio_en else (featured_expert.bio or ""),
            "bio_en": featured_expert.bio_en or "",
            "bio_zh": featured_expert.bio or "",
            # 双语：expertise_areas
            "expertise_areas": ea_en if user_lang == 'en' and ea_en else ea,
            "expertise_areas_en": ea_en,
            "specialties_zh": ea,
            # 双语：featured_skills
            "featured_skills": fs_en if user_lang == 'en' and fs_en else fs,
            "featured_skills_en": fs_en,
            "featured_skills_zh": fs,
            # 双语：achievements
            "achievements": ach_en if user_lang == 'en' and ach_en else ach,
            "achievements_en": ach_en,
            "achievements_zh": ach,
            # 双语：response_time
            "response_time": featured_expert.response_time_en if user_lang == 'en' and featured_expert.response_time_en else (featured_expert.response_time or ""),
            "response_time_en": featured_expert.response_time_en or "",
            "response_time_zh": featured_expert.response_time or "",
        }
        result = await _attach_is_following([result_dict], request, db)
        return result[0]

    # 如果没有 FeaturedTaskExpert，使用 TaskExpert 的基础数据
    if expert:
        result_dict = {
            "id": expert.id,
            "name": expert.expert_name or (user.name if user else ""),
            "avatar": expert.avatar or (user.avatar if user else "") or "",
            "user_level": "normal",
            "avg_rating": float(expert.rating) if expert.rating else 0.0,
            "completed_tasks": expert.completed_tasks or 0,
            "total_tasks": 0,
            "completion_rate": 0.0,
            "is_verified": False,
            "success_rate": 0.0,
            "location": user.residence_city if user and hasattr(user, 'residence_city') and user.residence_city else "Online",
            "status": expert.status,
            "total_services": expert.total_services,
            "bio": expert.bio or "",
            "expertise_areas": [],
            "featured_skills": [],
            "achievements": [],
            "response_time": "",
            "created_at": format_iso_utc(expert.created_at),
            "updated_at": format_iso_utc(expert.updated_at) if expert.updated_at else None,
        }
        result = await _attach_is_following([result_dict], request, db)
        return result[0]

    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND, detail="任务达人不存在"
    )


# ==================== 服务菜单管理接口 ====================


# ==================== 服务时间段管理接口 ====================


# 注意：更具体的路由必须放在通用路由之前
# 否则 FastAPI 可能会将 /by-date 匹配到 /{time_slot_id}


# ===========================================
# 辅助函数：自动添加时间段到活动
# ===========================================


# ===========================================
# 辅助函数：检查并结束活动
# ===========================================

async def check_and_end_activities(db: AsyncSession):
    """
    检查活动是否应该结束（最后一个时间段结束或达到截至日期），并自动结束活动
    
    应该在定时任务中定期调用
    """
    from datetime import datetime as dt_datetime
    from app.utils.time_utils import get_utc_time
    
    # 查询所有开放中的活动
    open_activities = await db.execute(
        select(models.Activity)
        .where(models.Activity.status == "open")
    )
    open_activities = open_activities.scalars().all()
    
    ended_count = 0
    current_time = get_utc_time()
    
    for activity in open_activities:
        should_end = False
        end_reason = ""
        
        # 查询活动的所有时间段关联
        relations = await db.execute(
            select(models.ActivityTimeSlotRelation)
            .where(models.ActivityTimeSlotRelation.activity_id == activity.id)
            .where(models.ActivityTimeSlotRelation.relation_mode == "fixed")
        )
        fixed_relations = relations.scalars().all()
        
        # 查询重复规则关联
        recurring_relation = await db.execute(
            select(models.ActivityTimeSlotRelation)
            .where(models.ActivityTimeSlotRelation.activity_id == activity.id)
            .where(models.ActivityTimeSlotRelation.relation_mode == "recurring")
            .limit(1)
        )
        recurring_relation = recurring_relation.scalar_one_or_none()
        
        # 检查是否达到截至日期
        if recurring_relation and recurring_relation.activity_end_date:
            today = get_utc_time().date()
            if today > recurring_relation.activity_end_date:
                should_end = True
                end_reason = f"已达到活动截至日期 {recurring_relation.activity_end_date}"
        
        # 检查最后一个时间段是否已结束
        if not should_end and fixed_relations:
            # 获取所有关联的时间段
            time_slot_ids = [r.time_slot_id for r in fixed_relations if r.time_slot_id]
            if time_slot_ids:
                time_slots = await db.execute(
                    select(models.ServiceTimeSlot)
                    .where(models.ServiceTimeSlot.id.in_(time_slot_ids))
                    .order_by(models.ServiceTimeSlot.slot_end_datetime.desc())
                )
                time_slots = time_slots.scalars().all()
                
                if time_slots:
                    # 获取最后一个时间段
                    last_slot = time_slots[0]
                    
                    # 检查最后一个时间段是否已结束
                    if last_slot.slot_end_datetime < current_time:
                        # 如果活动有重复规则且auto_add_new_slots为True，不结束活动
                        if recurring_relation and recurring_relation.auto_add_new_slots:
                            # 检查是否还有未到期的匹配时间段（未来30天内）
                            from app.utils.time_utils import parse_local_as_utc, LONDON
                            future_date = date.today() + timedelta(days=30)
                            future_utc = parse_local_as_utc(
                                dt_datetime.combine(future_date, dt_time(23, 59, 59)),
                                LONDON
                            )
                            
                            # 查询服务是否有未来的时间段
                            service = await db.execute(
                                select(models.TaskExpertService)
                                .where(models.TaskExpertService.id == activity.expert_service_id)
                            )
                            service = service.scalar_one_or_none()
                            
                            if service:
                                future_slots = await db.execute(
                                    select(models.ServiceTimeSlot)
                                    .where(models.ServiceTimeSlot.service_id == service.id)
                                    .where(models.ServiceTimeSlot.slot_start_datetime > current_time)
                                    .where(models.ServiceTimeSlot.slot_start_datetime <= future_utc)
                                    .where(models.ServiceTimeSlot.is_manually_deleted == False)
                                    .limit(1)
                                )
                                if not future_slots.scalar_one_or_none():
                                    # 没有未来的时间段，结束活动
                                    should_end = True
                                    end_reason = "最后一个时间段已结束，且没有未来的匹配时间段"
                        else:
                            # 没有重复规则或auto_add_new_slots为False，最后一个时间段结束就结束活动
                            should_end = True
                            end_reason = f"最后一个时间段已结束（{last_slot.slot_end_datetime}）"
        
        # 非时间段服务：检查截止日期
        if not should_end and not activity.has_time_slots and activity.deadline:
            if current_time > activity.deadline:
                should_end = True
                end_reason = f"已达到活动截止日期 {activity.deadline}"
        
        # 如果活动应该结束，更新状态
        if should_end:
            # 更新活动状态为已完成
            await db.execute(
                update(models.Activity)
                .where(models.Activity.id == activity.id)
                .values(status="completed", updated_at=get_utc_time())
            )
            
            # 自动处理关联的任务状态
            # 查询所有关联到此活动的任务（状态为open或taken）
            related_tasks_query = await db.execute(
                select(models.Task)
                .where(models.Task.parent_activity_id == activity.id)
                .where(models.Task.status.in_(["open", "taken"]))
            )
            related_tasks = related_tasks_query.scalars().all()
            
            for task in related_tasks:
                # 将未开始的任务标记为已取消
                old_status = task.status
                await db.execute(
                    update(models.Task)
                    .where(models.Task.id == task.id)
                    .values(status="cancelled", updated_at=get_utc_time())
                )
                
                # 记录审计日志
                task_audit_log = models.TaskAuditLog(
                    task_id=task.id,
                    action_type="task_cancelled",
                    action_description=f"活动已结束，任务自动取消",
                    user_id=None,
                    old_status=old_status,
                    new_status="cancelled",
                )
                db.add(task_audit_log)
            
            # 记录活动审计日志（使用通用的 AuditLog 表，因为 TaskAuditLog 的 task_id 不能为 NULL）
            audit_log = models.AuditLog(
                action_type="activity_completed",
                entity_type="activity",
                entity_id=str(activity.id),
                user_id=None,  # 系统自动操作
                admin_id=None,
                old_value={"status": "open"},
                new_value={"status": "completed"},
                reason=f"活动自动结束: {end_reason}",
            )
            db.add(audit_log)
            
            ended_count += 1
            logger.info(f"活动 {activity.id} 自动结束：{end_reason}")
    
    if ended_count > 0:
        await db.commit()
        logger.info(f"自动结束了 {ended_count} 个活动")
    
    return ended_count


# ===========================================
# API端点：手动触发活动结束检查（管理员或系统调用）
# ===========================================


# 注意：更具体的路由必须放在通用路由之前
# 否则 FastAPI 可能会将 /services/123 匹配到 /{expert_id}/services

# 公开接口：获取服务的时间段列表（无需认证）


@task_expert_router.get("/services/{service_id}", response_model=schemas.TaskExpertServiceOut)
async def get_service_detail(
    service_id: int,
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取服务详情"""
    service = await db.execute(
        select(models.TaskExpertService)
        .where(models.TaskExpertService.id == service_id)
        .where(models.TaskExpertService.status == "active")
    )
    service = service.scalar_one_or_none()
    if not service:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="服务不存在或未上架"
        )
    
    # 增加浏览次数（Redis 累加，定时同步到 DB）
    try:
        from app.redis_cache import get_redis_client
        _rc = get_redis_client()
        if _rc:
            _rk = f"service:view_count:{service_id}"
            _rc.incr(_rk)
            _rc.expire(_rk, 7 * 24 * 3600)
        else:
            await db.execute(
                update(models.TaskExpertService)
                .where(models.TaskExpertService.id == service_id)
                .values(view_count=models.TaskExpertService.view_count + 1)
            )
            await db.commit()
            await db.refresh(service)
    except Exception:
        pass

    
    # 查询用户申请的服务申请信息（如果用户已登录）
    user_application_id = None
    user_application_status = None
    user_task_id = None
    user_task_status = None
    user_task_is_paid = None
    user_application_has_negotiation = None
    
    if current_user:
        # 查询用户的服务申请
        application = await db.execute(
            select(models.ServiceApplication)
            .where(models.ServiceApplication.service_id == service_id)
            .where(models.ServiceApplication.applicant_id == current_user.id)
            .order_by(models.ServiceApplication.created_at.desc())
            .limit(1)
        )
        application = application.scalars().first()
        
        if application:
            user_application_id = application.id
            user_application_status = application.status
            user_application_has_negotiation = application.negotiated_price is not None
            
            # 如果申请已批准且有任务ID，查询任务信息
            if application.task_id:
                task = await db.get(models.Task, application.task_id)
                if task:
                    user_task_id = task.id
                    user_task_status = task.status
                    user_task_is_paid = bool(task.is_paid)
    
    # 使用 from_orm 方法创建输出对象，并添加用户申请信息
    service_out = schemas.TaskExpertServiceOut.from_orm(service)
    # 添加用户申请信息
    service_out.user_application_id = user_application_id
    service_out.user_application_status = user_application_status
    service_out.user_task_id = user_task_id
    service_out.user_task_status = user_task_status
    service_out.user_task_is_paid = user_task_is_paid
    service_out.user_application_has_negotiation = user_application_has_negotiation

    # 加载服务所有者信息（个人服务显示所有者，达人服务显示达人）
    if service.service_type == "personal" and service.user_id:
        from app import async_crud
        owner = await async_crud.async_user_crud.get_user_by_id(db, service.user_id)
        if owner:
            service_out.owner_name = owner.name
            service_out.owner_avatar = owner.avatar
            service_out.owner_rating = owner.avg_rating

    return service_out


@task_expert_router.get("/services/{service_id}/applications")
async def get_service_applications(
    service_id: int,
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
):
    """获取服务的申请列表（公开留言）

    三种调用者：
    1. 服务所有者 → 完整数据（含 applicant_id）
    2. 已登录非所有者 → 公开列表 + 自己的完整申请
    3. 未登录 → 公开列表
    """
    service_result = await db.execute(
        select(models.TaskExpertService).where(
            models.TaskExpertService.id == service_id
        )
    )
    service = service_result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")

    user_id = str(current_user.id) if current_user else None
    is_owner = False
    if user_id:
        if service.service_type == "personal" and service.user_id == user_id:
            is_owner = True
        elif service.service_type == "expert" and service.expert_id == user_id:
            is_owner = True

    query = (
        select(models.ServiceApplication)
        .where(models.ServiceApplication.service_id == service_id)
        .where(models.ServiceApplication.status.in_(
            ["pending", "negotiating", "price_agreed", "approved"]
        ))
        .order_by(models.ServiceApplication.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    result = await db.execute(query)
    applications = result.scalars().all()

    applicant_ids = list({app.applicant_id for app in applications})
    applicants_map = {}
    if applicant_ids:
        applicants_result = await db.execute(
            select(models.User).where(models.User.id.in_(applicant_ids))
        )
        for u in applicants_result.scalars().all():
            applicants_map[u.id] = u

    items = []
    for app in applications:
        applicant = applicants_map.get(app.applicant_id)
        item = {
            "id": app.id,
            "applicant_name": applicant.name if applicant else "Unknown",
            "applicant_avatar": applicant.avatar if applicant else None,
            "applicant_user_level": applicant.user_level if applicant and hasattr(applicant, "user_level") else None,
            "currency": app.currency or "GBP",
            "status": app.status,
            "created_at": app.created_at.isoformat() if app.created_at else None,
            "owner_reply": app.owner_reply,
            "owner_reply_at": app.owner_reply_at.isoformat() if app.owner_reply_at else None,
        }
        # Only include private fields for owner or the applicant themselves
        if is_owner or (current_user and str(app.applicant_id) == current_user.id):
            item["application_message"] = app.application_message
            item["negotiated_price"] = float(app.negotiated_price) if app.negotiated_price else None
        if is_owner:
            item["applicant_id"] = app.applicant_id
        elif user_id and app.applicant_id == user_id:
            item["applicant_id"] = app.applicant_id

        items.append(item)

    return items


@task_expert_router.post("/services/{service_id}/applications/{application_id}/reply")
async def reply_to_service_application(
    service_id: int,
    application_id: int,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """服务所有者对申请的公开回复（每个申请只能回复一次）"""
    body = await request.json()
    message = body.get("message", "").strip()
    if not message:
        raise HTTPException(status_code=400, detail="回复内容不能为空")
    if len(message) > 500:
        raise HTTPException(status_code=400, detail="回复内容不能超过500字")

    service_result = await db.execute(
        select(models.TaskExpertService).where(
            models.TaskExpertService.id == service_id
        )
    )
    service = service_result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")

    user_id = str(current_user.id)
    is_owner = (
        (service.service_type == "personal" and service.user_id == user_id) or
        (service.service_type == "expert" and service.expert_id == user_id)
    )
    if not is_owner:
        raise HTTPException(status_code=403, detail="只有服务所有者可以回复")

    app_result = await db.execute(
        select(models.ServiceApplication).where(
            models.ServiceApplication.id == application_id,
            models.ServiceApplication.service_id == service_id,
        )
    )
    application = app_result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")

    if application.owner_reply is not None:
        raise HTTPException(status_code=409, detail="已回复过该申请")

    application.owner_reply = message
    application.owner_reply_at = get_utc_time()
    await db.commit()

    try:
        import json as json_lib
        notification_content = json_lib.dumps({
            "service_id": service_id,
            "service_name": service.service_name,
            "reply_message": message[:200],
            "owner_name": current_user.name if current_user.name else None,
        })
        notification = models.Notification(
            user_id=str(application.applicant_id),
            type="service_owner_reply",
            title="服务所有者回复了你的申请",
            title_en="The service owner replied to your application",
            content=notification_content,
            related_id=service_id,
            related_type="service_id",
        )
        db.add(notification)
        await db.commit()
    except Exception as e:
        logger.warning(f"Failed to create notification for service reply: {e}")

    return {
        "id": application.id,
        "owner_reply": application.owner_reply,
        "owner_reply_at": application.owner_reply_at.isoformat() if application.owner_reply_at else None,
    }


# 获取任务达人的公开服务列表（放在 /services/{service_id} 之后，避免路由冲突）
@task_expert_router.get("/{expert_id}/reviews")
async def get_expert_reviews(
    expert_id: str,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取任务达人作为达人身份获得的评价（不包含评价人私人信息）
    
    只返回与达人创建的服务/活动相关的任务评价
    """
    from sqlalchemy import and_, func
    
    # 查询条件：任务是由该达人创建的（created_by_expert=True 且 expert_creator_id=expert_id）
    # 并且任务已完成，有评价
    base_query = (
        select(models.Review)
        .join(models.Task, models.Review.task_id == models.Task.id)
        .where(
            and_(
                models.Task.created_by_expert == True,
                models.Task.expert_creator_id == expert_id,
                models.Task.status == "completed",
                models.Review.is_anonymous == 0  # 只返回非匿名评价
            )
        )
    )
    
    # 获取总数
    count_query = (
        select(func.count(models.Review.id))
        .join(models.Task, models.Review.task_id == models.Task.id)
        .where(
            and_(
                models.Task.created_by_expert == True,
                models.Task.expert_creator_id == expert_id,
                models.Task.status == "completed",
                models.Review.is_anonymous == 0
            )
        )
    )
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0
    
    # 获取分页数据
    reviews_query = (
        base_query
        .order_by(models.Review.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    
    result = await db.execute(reviews_query)
    reviews = result.scalars().all()
    
    # 转换为公开评价格式（不包含user_id等私人信息）
    return {
        "total": total,
        "items": [
            schemas.ReviewPublicOut(
                id=review.id,
                task_id=review.task_id,
                rating=review.rating,
                comment=review.comment,
                created_at=review.created_at
            )
            for review in reviews
        ],
        "limit": limit,
        "offset": offset,
        "has_more": (offset + limit) < total
    }


@task_expert_router.get("/services/{service_id}/reviews")
async def get_service_reviews(
    service_id: int,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取服务获得的评价（不包含评价人私人信息）
    
    只返回与该服务相关的任务评价
    """
    from sqlalchemy import func
    
    try:
        # 可选：验证服务是否存在（如果服务不存在，返回空列表也是合理的）
        # 但为了更好的错误提示，可以添加验证
        service = await db.get(models.TaskExpertService, service_id)
        if not service:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="服务不存在"
            )
        # 查询条件：任务关联了该服务（expert_service_id=service_id）
        # 并且是达人创建的任务（created_by_expert=True）
        # 并且任务已完成，有评价
        base_query = (
            select(models.Review)
            .join(models.Task, models.Review.task_id == models.Task.id)
            .where(
                and_(
                    models.Task.created_by_expert == True,  # 确保是达人创建的任务
                    models.Task.expert_service_id == service_id,
                    models.Task.status == "completed",
                    models.Review.is_anonymous == 0  # 只返回非匿名评价
                )
            )
        )
        
        # 获取总数（使用与 base_query 相同的查询条件）
        count_query = (
            select(func.count(models.Review.id))
            .select_from(models.Review)
            .join(models.Task, models.Review.task_id == models.Task.id)
            .where(
                and_(
                    models.Task.created_by_expert == True,  # 确保是达人创建的任务
                    models.Task.expert_service_id == service_id,
                    models.Task.status == "completed",
                    models.Review.is_anonymous == 0
                )
            )
        )
        total_result = await db.execute(count_query)
        total = total_result.scalar() or 0
        
        # 获取分页数据
        reviews_query = (
            base_query
            .order_by(models.Review.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        
        result = await db.execute(reviews_query)
        reviews = result.scalars().all()
        
        # 转换为公开评价格式（不包含user_id等私人信息）
        return {
            "total": total,
            "items": [
                schemas.ReviewPublicOut(
                    id=review.id,
                    task_id=review.task_id,
                    rating=review.rating,
                    comment=review.comment,
                    created_at=review.created_at
                )
                for review in reviews
            ],
            "limit": limit,
            "offset": offset,
            "has_more": (offset + limit) < total
        }
    except Exception as e:
        logger.error(f"获取服务评价失败 (service_id={service_id}): {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取服务评价失败: {str(e)}"
        )


@task_expert_router.get("/{expert_id}/services")
async def get_expert_services(
    expert_id: str,
    status_filter: Optional[str] = Query("active", alias="status"),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取任务达人的公开服务列表"""
    try:
        expert = await db.execute(
            select(models.TaskExpert).where(models.TaskExpert.id == expert_id)
        )
        expert = expert.scalar_one_or_none()
        if not expert:
            logger.warning(f"任务达人不存在: {expert_id}")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="任务达人不存在"
            )
        
        query = select(models.TaskExpertService).where(
            models.TaskExpertService.expert_id == expert_id,
            models.TaskExpertService.status == status_filter
        ).order_by(
            models.TaskExpertService.display_order,
            models.TaskExpertService.created_at.desc()
        )
        
        result = await db.execute(query)
        services = result.scalars().all()
        
        return {
            "expert_id": expert_id,
            "expert_name": expert.expert_name or (expert.user.name if hasattr(expert, "user") and expert.user else None),
            "services": [schemas.TaskExpertServiceOut.from_orm(s) for s in services],
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取任务达人服务列表失败: {expert_id}, 错误: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取服务列表失败"
        )


# ==================== 服务申请相关接口 ====================


# ==================== 咨询与议价相关接口 ====================


# ==================== 任务达人仪表盘和时刻表 ====================


# ==================== 任务达人关门日期管理 ====================


