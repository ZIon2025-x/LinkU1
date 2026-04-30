"""
论坛-板块 routes — extracted from forum_routes.py (2026-04-26 split).

All helpers remain in app.forum_routes; this module imports them as needed.
The 4 interleaved helpers (_parse_json_field, _post_to_feed_data,
_task_to_feed_data, _service_to_feed_data) also remain in forum_routes.py
and are imported here for use by the feed endpoint.
"""
from typing import List, Optional
import logging

from fastapi import APIRouter, Depends, HTTPException, Query, status, Request
from sqlalchemy import select, func, or_, and_, desc, asc
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app import models, schemas
from app.deps import get_async_db_dependency
from app.performance_monitor import measure_api_performance
from app.cache import cache_response
from app.push_notification_service import send_push_notification_async_safe
from app.utils.time_utils import get_utc_time

# Helpers from the original forum_routes module (stays as helper hub)
from app.forum_routes import (
    get_current_user_secure_async_csrf,
    get_current_user_optional,
    get_current_admin_async,
    visible_forums,
    assert_forum_visible,
    clear_all_forum_visibility_cache,
    log_admin_operation,
    create_latest_post_info,
    _batch_get_category_post_counts_and_latest_posts,
    _post_to_feed_data,
    _task_to_feed_data,
    _service_to_feed_data,
)

logger = logging.getLogger(__name__)

router = APIRouter()


# ==================== 板块 API ====================

@router.get("/forums/visible", response_model=schemas.ForumCategoryListResponse)
async def get_visible_forums(
    include_all: bool = Query(False, description="管理员查看全部板块"),
    view_as: Optional[str] = Query(None, description="管理员以指定用户视角查看（需管理员权限）"),
    include_latest_post: bool = Query(False, description="是否包含每个板块的最新帖子信息"),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    request: Request = None,  # FastAPI injects; Optional[Request] breaks Pydantic field detection
    db: AsyncSession = Depends(get_async_db_dependency)
):
    """
    获取当前用户可见的板块列表

    参数说明：
    - include_all: 管理员查看全部板块（带 can_manage=true 字段）
    - view_as: 管理员以指定用户ID视角查看可见板块（用于客服/排错场景）

    重要：前端必须使用此接口获取板块列表，禁止硬编码或直接查询所有板块。
    """
    # 管理员特殊处理：以指定用户视角查看
    if view_as:
        # 检查是否为管理员
        try:
            admin_user = await get_current_admin_async(request, db)
            if admin_user:
                target_user_result = await db.execute(
                    select(models.User).where(models.User.id == view_as)
                )
                target_user = target_user_result.scalar_one_or_none()
                if not target_user:
                    raise HTTPException(status_code=404, detail="User not found")

                visible_ids = await visible_forums(target_user, db)
                if not visible_ids:
                    # 返回普通板块（用户可以查看，但不能发帖）
                    forums_result = await db.execute(
                        select(models.ForumCategory)
                        .where(
                            models.ForumCategory.type.in_(['general', 'skill']),
                            models.ForumCategory.is_visible == True
                        )
                        .order_by(models.ForumCategory.sort_order, models.ForumCategory.created_at)
                    )
                    forums = forums_result.scalars().all()

                    # 如果需要包含最新帖子信息
                    if include_latest_post:
                        category_ids = [c.id for c in forums]
                        post_counts, latest_posts = await _batch_get_category_post_counts_and_latest_posts(
                            db, category_ids
                        )
                        category_list = []
                        for category in forums:
                            real_post_count = post_counts.get(category.id, 0)
                            latest_post = latest_posts.get(category.id)
                            latest_post_info = None
                            if latest_post:
                                latest_post_info = await create_latest_post_info(
                                    latest_post, db, request, current_user
                                )
                            category_out = schemas.ForumCategoryOut(
                                id=category.id,
                                name=category.name,
                                name_en=getattr(category, 'name_en', None),
                                name_zh=getattr(category, 'name_zh', None),
                                description=category.description,
                                description_en=getattr(category, 'description_en', None),
                                description_zh=getattr(category, 'description_zh', None),
                                icon=category.icon,
                                sort_order=category.sort_order,
                                is_visible=category.is_visible,
                                is_admin_only=getattr(category, 'is_admin_only', False),
                                type=getattr(category, 'type', 'general'),
                                country=getattr(category, 'country', None),
                                university_code=getattr(category, 'university_code', None),
                                skill_type=getattr(category, 'skill_type', None),
                                post_count=real_post_count,
                                service_count=getattr(category, 'service_count', 0),
                                task_count=getattr(category, 'task_count', 0),
                                latest_post=latest_post_info,
                                created_at=category.created_at,
                                updated_at=category.updated_at
                            )
                            category_list.append(category_out)

                        return {"categories": category_list}

                    return {"categories": [schemas.ForumCategoryOut.model_validate(f) for f in forums]}

                # 返回该用户可见的板块（用户可以查看，但不能发帖）
                school_forums_result = await db.execute(
                    select(models.ForumCategory).where(
                        models.ForumCategory.id.in_(visible_ids),
                        models.ForumCategory.is_visible == True
                    )
                )
                general_forums_result = await db.execute(
                    select(models.ForumCategory).where(
                        models.ForumCategory.type.in_(['general', 'skill']),
                        models.ForumCategory.is_visible == True
                    )
                )
                school_forums = school_forums_result.scalars().all()
                general_forums = general_forums_result.scalars().all()

                # 合并并排序
                all_forums = list(school_forums) + list(general_forums)
                all_forums.sort(key=lambda x: (x.sort_order, x.created_at))

                # 如果需要包含最新帖子信息
                if include_latest_post:
                    category_ids = [c.id for c in all_forums]
                    post_counts, latest_posts = await _batch_get_category_post_counts_and_latest_posts(
                        db, category_ids
                    )
                    category_list = []
                    for category in all_forums:
                        real_post_count = post_counts.get(category.id, 0)
                        latest_post = latest_posts.get(category.id)
                        latest_post_info = None
                        if latest_post:
                            latest_post_info = await create_latest_post_info(
                                latest_post, db, request, current_user
                            )
                        category_out = schemas.ForumCategoryOut(
                            id=category.id,
                            name=category.name,
                            name_en=getattr(category, 'name_en', None),
                            name_zh=getattr(category, 'name_zh', None),
                            description=category.description,
                            description_en=getattr(category, 'description_en', None),
                            description_zh=getattr(category, 'description_zh', None),
                            icon=category.icon,
                            sort_order=category.sort_order,
                            is_visible=category.is_visible,
                            is_admin_only=getattr(category, 'is_admin_only', False),
                            type=getattr(category, 'type', 'general'),
                            country=getattr(category, 'country', None),
                            university_code=getattr(category, 'university_code', None),
                            skill_type=getattr(category, 'skill_type', None),
                            post_count=real_post_count,
                            service_count=getattr(category, 'service_count', 0),
                            task_count=getattr(category, 'task_count', 0),
                            latest_post=latest_post_info,
                            created_at=category.created_at,
                            updated_at=category.updated_at
                        )
                        category_list.append(category_out)

                    return {"categories": category_list}

                return {"categories": [schemas.ForumCategoryOut.model_validate(f) for f in all_forums]}
        except HTTPException:
            # 非管理员使用 view_as 参数应被忽略
            pass

    # 管理员特殊处理：查看全部板块
    if include_all:
        try:
            admin_user = await get_current_admin_async(request, db)
            if admin_user:
                forums_result = await db.execute(
                    select(models.ForumCategory)
                    .where(models.ForumCategory.is_visible == True)
                    .order_by(models.ForumCategory.sort_order, models.ForumCategory.created_at)
                )
                forums = forums_result.scalars().all()

                # 如果需要包含最新帖子信息
                if include_latest_post:
                    category_ids = [c.id for c in forums]
                    post_counts, latest_posts = await _batch_get_category_post_counts_and_latest_posts(
                        db, category_ids
                    )
                    category_list = []
                    for category in forums:
                        real_post_count = post_counts.get(category.id, 0)
                        latest_post = latest_posts.get(category.id)
                        latest_post_info = None
                        if latest_post:
                            latest_post_info = await create_latest_post_info(
                                latest_post, db, request, current_user
                            )
                        category_out = schemas.ForumCategoryOut(
                            id=category.id,
                            name=category.name,
                            name_en=getattr(category, 'name_en', None),
                            name_zh=getattr(category, 'name_zh', None),
                            description=category.description,
                            description_en=getattr(category, 'description_en', None),
                            description_zh=getattr(category, 'description_zh', None),
                            icon=category.icon,
                            sort_order=category.sort_order,
                            is_visible=category.is_visible,
                            is_admin_only=getattr(category, 'is_admin_only', False),
                            type=getattr(category, 'type', 'general'),
                            country=getattr(category, 'country', None),
                            university_code=getattr(category, 'university_code', None),
                            skill_type=getattr(category, 'skill_type', None),
                            post_count=real_post_count,
                            service_count=getattr(category, 'service_count', 0),
                            task_count=getattr(category, 'task_count', 0),
                            latest_post=latest_post_info,
                            created_at=category.created_at,
                            updated_at=category.updated_at
                        )
                        category_dict = category_out.model_dump()
                        category_dict["can_manage"] = True
                        category_list.append(category_dict)

                    return {"categories": category_list}

                # 不需要最新帖子信息，直接返回
                categories = []
                for forum in forums:
                    forum_dict = schemas.ForumCategoryOut.model_validate(forum).model_dump()
                    forum_dict["can_manage"] = True
                    categories.append(forum_dict)
                return {"categories": categories}
        except HTTPException:
            # 非管理员使用 include_all 参数应被忽略
            pass

    # 普通用户：根据身份返回可见板块
    # 注意：is_admin_only 只控制发帖权限，不影响查看权限，所以这里不过滤 is_admin_only
    if not current_user:
        # 未登录：返回普通板块和技能板块（用户可以查看，但不能发帖）
        forums_result = await db.execute(
            select(models.ForumCategory)
            .where(
                models.ForumCategory.type.in_(['general', 'skill']),
                models.ForumCategory.is_visible == True
            )
            .order_by(models.ForumCategory.sort_order, models.ForumCategory.created_at)
        )
        forums = forums_result.scalars().all()

        # 如果需要包含最新帖子信息
        if include_latest_post:
            category_ids = [c.id for c in forums]
            post_counts, latest_posts = await _batch_get_category_post_counts_and_latest_posts(
                db, category_ids
            )
            category_list = []
            for category in forums:
                real_post_count = post_counts.get(category.id, 0)
                latest_post = latest_posts.get(category.id)
                latest_post_info = None
                if latest_post:
                    latest_post_info = await create_latest_post_info(
                        latest_post, db, request, current_user
                    )
                category_out = schemas.ForumCategoryOut(
                    id=category.id,
                    name=category.name,
                    name_en=getattr(category, 'name_en', None),
                    name_zh=getattr(category, 'name_zh', None),
                    description=category.description,
                    description_en=getattr(category, 'description_en', None),
                    description_zh=getattr(category, 'description_zh', None),
                    icon=category.icon,
                    sort_order=category.sort_order,
                    is_visible=category.is_visible,
                    is_admin_only=getattr(category, 'is_admin_only', False),
                    type=getattr(category, 'type', 'general'),
                    country=getattr(category, 'country', None),
                    university_code=getattr(category, 'university_code', None),
                    skill_type=getattr(category, 'skill_type', None),
                    post_count=real_post_count,
                    service_count=getattr(category, 'service_count', 0),
                    task_count=getattr(category, 'task_count', 0),
                    latest_post=latest_post_info,
                    created_at=category.created_at,
                    updated_at=category.updated_at
                )
                category_list.append(category_out)

            return {"categories": category_list}

        return {"categories": [schemas.ForumCategoryOut.model_validate(f) for f in forums]}

    # 检查是否为学生认证用户
    logger.info(f"get_visible_forums: current_user={current_user.id if current_user else None}")
    visible_ids = await visible_forums(current_user, db)
    logger.info(f"get_visible_forums: visible_ids={visible_ids}")

    if not visible_ids:
        # 未学生认证：返回普通板块和技能板块（用户可以查看，但不能发帖）
        forums_result = await db.execute(
            select(models.ForumCategory)
            .where(
                models.ForumCategory.type.in_(['general', 'skill']),
                models.ForumCategory.is_visible == True
            )
            .order_by(models.ForumCategory.sort_order, models.ForumCategory.created_at)
        )
        forums = forums_result.scalars().all()

        # 如果需要包含最新帖子信息
        if include_latest_post:
            category_ids = [c.id for c in forums]
            post_counts, latest_posts = await _batch_get_category_post_counts_and_latest_posts(
                db, category_ids
            )
            category_list = []
            for category in forums:
                real_post_count = post_counts.get(category.id, 0)
                latest_post = latest_posts.get(category.id)
                latest_post_info = None
                if latest_post:
                    latest_post_info = await create_latest_post_info(
                        latest_post, db, request, current_user
                    )
                category_out = schemas.ForumCategoryOut(
                    id=category.id,
                    name=category.name,
                    name_en=getattr(category, 'name_en', None),
                    name_zh=getattr(category, 'name_zh', None),
                    description=category.description,
                    description_en=getattr(category, 'description_en', None),
                    description_zh=getattr(category, 'description_zh', None),
                    icon=category.icon,
                    sort_order=category.sort_order,
                    is_visible=category.is_visible,
                    is_admin_only=getattr(category, 'is_admin_only', False),
                    type=getattr(category, 'type', 'general'),
                    country=getattr(category, 'country', None),
                    university_code=getattr(category, 'university_code', None),
                    skill_type=getattr(category, 'skill_type', None),
                    post_count=real_post_count,
                    service_count=getattr(category, 'service_count', 0),
                    task_count=getattr(category, 'task_count', 0),
                    latest_post=latest_post_info,
                    created_at=category.created_at,
                    updated_at=category.updated_at
                )
                category_list.append(category_out)

            return {"categories": category_list}

        return {"categories": [schemas.ForumCategoryOut.model_validate(f) for f in forums]}

    # 已认证学生：返回普通板块 + 技能板块 + 可见的学校板块（用户可以查看，但不能发帖）
    school_forums_result = await db.execute(
        select(models.ForumCategory).where(
            models.ForumCategory.id.in_(visible_ids),
            models.ForumCategory.is_visible == True
        )
    )
    general_forums_result = await db.execute(
        select(models.ForumCategory).where(
            models.ForumCategory.type.in_(['general', 'skill']),
            models.ForumCategory.is_visible == True
        )
    )
    school_forums = school_forums_result.scalars().all()
    general_forums = general_forums_result.scalars().all()

    # 合并并排序
    all_forums = list(school_forums) + list(general_forums)
    all_forums.sort(key=lambda x: (x.sort_order, x.created_at))

    # 如果需要包含最新帖子信息
    if include_latest_post:
        category_ids = [c.id for c in all_forums]
        post_counts, latest_posts = await _batch_get_category_post_counts_and_latest_posts(
            db, category_ids
        )
        category_list = []
        for category in all_forums:
            real_post_count = post_counts.get(category.id, 0)
            latest_post = latest_posts.get(category.id)
            latest_post_info = None
            if latest_post:
                latest_post_info = await create_latest_post_info(
                    latest_post, db, request, None
                )
            category_out = schemas.ForumCategoryOut(
                id=category.id,
                name=category.name,
                name_en=getattr(category, 'name_en', None),
                name_zh=getattr(category, 'name_zh', None),
                description=category.description,
                description_en=getattr(category, 'description_en', None),
                description_zh=getattr(category, 'description_zh', None),
                icon=category.icon,
                sort_order=category.sort_order,
                is_visible=category.is_visible,
                is_admin_only=getattr(category, 'is_admin_only', False),
                type=getattr(category, 'type', 'general'),
                country=getattr(category, 'country', None),
                university_code=getattr(category, 'university_code', None),
                skill_type=getattr(category, 'skill_type', None),
                post_count=real_post_count,
                service_count=getattr(category, 'service_count', 0),
                task_count=getattr(category, 'task_count', 0),
                latest_post=latest_post_info,
                created_at=category.created_at,
                updated_at=category.updated_at
            )
            category_list.append(category_out)
        return {"categories": category_list}
    return {"categories": [schemas.ForumCategoryOut.model_validate(f) for f in all_forums]}


@router.get("/categories", response_model=schemas.ForumCategoryListResponse)
@measure_api_performance("get_categories")
@cache_response(ttl=300, key_prefix="forum_categories")  # 缓存5分钟
async def get_categories(
    request: Request,
    include_latest_post: bool = Query(False, description="是否包含每个板块的最新帖子信息"),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取板块列表（已应用缓存和性能监控）

    可选参数：
    - include_latest_post: 如果为 True，每个板块会包含最新帖子的简要信息（标题、作者、最后回复时间等）
    注意：分类列表只显示对普通用户可见的最新帖子（is_visible == True）
    """
    result = await db.execute(
        select(models.ForumCategory)
        .where(models.ForumCategory.is_visible == True)
        .order_by(models.ForumCategory.sort_order.asc(), models.ForumCategory.id.asc())
    )
    categories = result.scalars().all()

    # 如果需要包含最新帖子信息，需要手动构建响应
    if include_latest_post:
        category_ids = [c.id for c in categories]
        post_counts, latest_posts = await _batch_get_category_post_counts_and_latest_posts(
            db, category_ids
        )
        category_list = []
        for category in categories:
            real_post_count = post_counts.get(category.id, 0)
            latest_post = latest_posts.get(category.id)
            latest_post_info = None
            if latest_post:
                latest_post_info = await create_latest_post_info(
                    latest_post, db, request, None
                )
            category_out = schemas.ForumCategoryOut(
                id=category.id,
                name=category.name,
                name_en=getattr(category, 'name_en', None),
                name_zh=getattr(category, 'name_zh', None),
                description=category.description,
                description_en=getattr(category, 'description_en', None),
                description_zh=getattr(category, 'description_zh', None),
                icon=category.icon,
                sort_order=category.sort_order,
                is_visible=category.is_visible,
                is_admin_only=getattr(category, 'is_admin_only', False),
                post_count=real_post_count,
                service_count=getattr(category, 'service_count', 0),
                task_count=getattr(category, 'task_count', 0),
                last_post_at=category.last_post_at,
                created_at=category.created_at,
                updated_at=category.updated_at,
                latest_post=latest_post_info
            )

            category_list.append(category_out)

        return {"categories": category_list}

    # 标准返回（不包含最新帖子信息）- 需要显式序列化以包含多语言字段
    category_list = []
    for category in categories:
        category_out = schemas.ForumCategoryOut(
            id=category.id,
            name=category.name,
            name_en=getattr(category, 'name_en', None),
            name_zh=getattr(category, 'name_zh', None),
            description=category.description,
            description_en=getattr(category, 'description_en', None),
            description_zh=getattr(category, 'description_zh', None),
            icon=category.icon,
            sort_order=category.sort_order,
            is_visible=category.is_visible,
            is_admin_only=getattr(category, 'is_admin_only', False),
            type=getattr(category, 'type', 'general'),
            country=getattr(category, 'country', None),
            university_code=getattr(category, 'university_code', None),
            skill_type=getattr(category, 'skill_type', None),
            post_count=category.post_count,
            service_count=getattr(category, 'service_count', 0),
            task_count=getattr(category, 'task_count', 0),
            last_post_at=category.last_post_at,
            created_at=category.created_at,
            updated_at=category.updated_at
        )
        category_list.append(category_out)

    return {"categories": category_list}


# ==================== 板块申请相关路由（必须在 /categories/{category_id} 之前） ====================

@router.post("/categories/request", response_model=schemas.ForumCategoryRequestResponse)
async def request_new_category(
    request_data: schemas.ForumCategoryRequestCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """申请新建板块（普通用户）"""
    try:
        # 规范化输入：去除首尾空格
        normalized_name = request_data.name.strip()

        # 检查板块名称是否已存在（包括已存在的板块和已通过的申请）
        existing_category = await db.execute(
            select(models.ForumCategory).where(models.ForumCategory.name == normalized_name)
        )
        if existing_category.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="板块名称已存在，请选择其他名称"
            )

        # 检查是否有已通过的申请使用了相同名称
        approved_request = await db.execute(
            select(models.ForumCategoryRequest).where(
                and_(
                    models.ForumCategoryRequest.name == normalized_name,
                    models.ForumCategoryRequest.status == "approved"
                )
            )
        )
        if approved_request.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="该板块名称已被其他申请使用，请选择其他名称"
            )

        # 检查用户是否已有相同名称的待审核申请
        existing_request = await db.execute(
            select(models.ForumCategoryRequest).where(
                and_(
                    models.ForumCategoryRequest.requester_id == current_user.id,
                    models.ForumCategoryRequest.name == normalized_name,
                    models.ForumCategoryRequest.status == "pending"
                )
            )
        )
        if existing_request.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="您已提交过相同名称的申请，请等待审核"
            )

        # 自动填充双语字段
        from app.utils.bilingual_helper import auto_fill_bilingual_fields

        normalized_description = request_data.description.strip() if request_data.description else None
        _, name_en, name_zh, description_en, description_zh = await auto_fill_bilingual_fields(
            name=normalized_name,
            description=normalized_description,
            name_en=request_data.name_en.strip() if request_data.name_en else None,
            name_zh=request_data.name_zh.strip() if request_data.name_zh else None,
            description_en=request_data.description_en.strip() if request_data.description_en else None,
            description_zh=request_data.description_zh.strip() if request_data.description_zh else None,
        )

        # 创建申请
        new_request = models.ForumCategoryRequest(
            requester_id=current_user.id,
            name=normalized_name,
            name_en=name_en,
            name_zh=name_zh,
            description=normalized_description,
            description_en=description_en,
            description_zh=description_zh,
            icon=request_data.icon.strip() if request_data.icon else None,
            type=request_data.type,
            country=request_data.country,
            university_code=request_data.university_code,
            status="pending"
        )

        db.add(new_request)
        await db.commit()
        await db.refresh(new_request)

        logger.info(f"用户 {current_user.id} 提交了板块申请: {normalized_name}")

        return {
            "message": "申请已提交，等待管理员审核",
            "id": new_request.id,
            "request": {
                "id": new_request.id,
                "name": new_request.name,
                "status": new_request.status,
                "created_at": new_request.created_at
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"提交板块申请失败: {e}")
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="提交申请时发生错误，请稍后重试"
        )


@router.get("/categories/requests", response_model=schemas.ForumCategoryRequestListOut)
async def get_category_requests(
    status: Optional[str] = Query(None, pattern="^(pending|approved|rejected)$"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    search: Optional[str] = Query(None, description="搜索板块名称或申请人"),
    sort_by: Optional[str] = Query("created_at", pattern="^(created_at|reviewed_at|status)$"),
    sort_order: Optional[str] = Query("desc", pattern="^(asc|desc)$"),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取板块申请列表（管理员）"""
    # 总数（与列表相同筛选条件）
    count_query = select(func.count()).select_from(models.ForumCategoryRequest)
    if status:
        count_query = count_query.where(models.ForumCategoryRequest.status == status)
    if search:
        search_term = f"%{search.strip()}%"
        count_query = count_query.where(
            or_(
                models.ForumCategoryRequest.name.ilike(search_term),
                models.ForumCategoryRequest.requester_id.ilike(search_term)
            )
        )
    count_result = await db.execute(count_query)
    total = count_result.scalar() or 0
    # 列表查询（带 options、排序、分页）
    query = select(models.ForumCategoryRequest).options(
        selectinload(models.ForumCategoryRequest.requester),
        selectinload(models.ForumCategoryRequest.admin)
    )
    if status:
        query = query.where(models.ForumCategoryRequest.status == status)
    if search:
        search_term = f"%{search.strip()}%"
        query = query.where(
            or_(
                models.ForumCategoryRequest.name.ilike(search_term),
                models.ForumCategoryRequest.requester_id.ilike(search_term)
            )
        )
    if sort_by == "reviewed_at":
        order_col = models.ForumCategoryRequest.reviewed_at
    elif sort_by == "status":
        order_col = models.ForumCategoryRequest.status
    else:
        order_col = models.ForumCategoryRequest.created_at
    if sort_order == "asc":
        query = query.order_by(asc(order_col))
    else:
        query = query.order_by(desc(order_col))
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)
    result = await db.execute(query)
    requests = result.scalars().all()
    items = []
    for req in requests:
        request_dict = {
            "id": req.id,
            "requester_id": req.requester_id,
            "requester_name": req.requester.name if req.requester else None,
            "requester_avatar": req.requester.avatar if req.requester else None,
            "name": req.name,
            "description": req.description,
            "icon": req.icon,
            "type": req.type,
            "country": req.country,
            "university_code": req.university_code,
            "status": req.status,
            "admin_id": req.admin_id,
            "admin_name": req.admin.name if req.admin else None,
            "reviewed_at": req.reviewed_at,
            "review_comment": req.review_comment,
            "created_at": req.created_at,
            "updated_at": req.updated_at
        }
        items.append(schemas.ForumCategoryRequestOut(**request_dict))
    return schemas.ForumCategoryRequestListOut(items=items, total=total)


@router.get("/categories/requests/my", response_model=List[schemas.ForumCategoryRequestOut])
async def get_my_category_requests(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status: Optional[str] = Query(None, pattern="^(pending|approved|rejected)$"),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取我的板块申请列表（普通用户）"""
    query = select(models.ForumCategoryRequest).options(
        selectinload(models.ForumCategoryRequest.requester),
        selectinload(models.ForumCategoryRequest.admin)
    ).where(models.ForumCategoryRequest.requester_id == current_user.id)

    # 状态筛选
    if status:
        query = query.where(models.ForumCategoryRequest.status == status)

    query = query.order_by(desc(models.ForumCategoryRequest.created_at))

    # 分页
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)

    result = await db.execute(query)
    requests = result.scalars().all()

    # 构建响应
    response = []
    for req in requests:
        request_dict = {
            "id": req.id,
            "requester_id": req.requester_id,
            "requester_name": req.requester.name if req.requester else None,
            "requester_avatar": req.requester.avatar if req.requester else None,
            "name": req.name,
            "description": req.description,
            "icon": req.icon,
            "type": req.type,
            "country": req.country,
            "university_code": req.university_code,
            "status": req.status,
            "admin_id": req.admin_id,
            "admin_name": req.admin.name if req.admin else None,
            "reviewed_at": req.reviewed_at,
            "review_comment": req.review_comment,
            "created_at": req.created_at,
            "updated_at": req.updated_at
        }
        response.append(schemas.ForumCategoryRequestOut(**request_dict))

    return response


@router.put("/categories/requests/{request_id}/review")
async def review_category_request(
    request_id: int,
    action: str = Query(..., pattern="^(approve|reject)$"),
    review_comment: Optional[str] = None,
    request: Request = None,  # FastAPI injects; Optional[Request] breaks Pydantic field detection
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """审核板块申请（管理员）"""
    result = await db.execute(
        select(models.ForumCategoryRequest).where(models.ForumCategoryRequest.id == request_id)
    )
    category_request = result.scalar_one_or_none()

    if not category_request:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="申请不存在"
        )

    if category_request.status != "pending":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="该申请已被审核"
        )

    if action == "approve":
        # 批准申请，创建新板块
        # 如果申请中没有双语字段，自动填充
        if not category_request.name_en or not category_request.name_zh:
            from app.utils.bilingual_helper import auto_fill_bilingual_fields
            _, name_en, name_zh, description_en, description_zh = await auto_fill_bilingual_fields(
                name=category_request.name,
                description=category_request.description,
                name_en=category_request.name_en,
                name_zh=category_request.name_zh,
                description_en=category_request.description_en,
                description_zh=category_request.description_zh,
            )
        else:
            name_en = category_request.name_en
            name_zh = category_request.name_zh
            description_en = category_request.description_en
            description_zh = category_request.description_zh

        new_category = models.ForumCategory(
            name=category_request.name,
            name_en=name_en,
            name_zh=name_zh,
            description=category_request.description,
            description_en=description_en,
            description_zh=description_zh,
            icon=category_request.icon,
            type=category_request.type,
            country=category_request.country,
            university_code=category_request.university_code,
            is_visible=True,
            sort_order=0
        )
        db.add(new_category)

        category_request.status = "approved"
        category_request.admin_id = current_admin.id
        category_request.reviewed_at = get_utc_time()
        category_request.review_comment = review_comment

        await db.commit()
        await db.refresh(new_category)
        await db.refresh(category_request)

        logger.info(f"管理员 {current_admin.id} 批准了板块申请 {request_id}，创建了板块 {new_category.id}")

        # 发送批准通知给申请人
        try:
            from app import async_crud

            title = "板块申请已通过"
            title_en = "Forum Category Application Approved"
            content = f"恭喜！您申请的板块「{category_request.name}」已通过审核，现已创建。"
            content_en = f"Congratulations! Your forum category application '{category_request.name}' has been approved and is now created."

            await async_crud.async_notification_crud.create_notification(
                db=db,
                user_id=category_request.requester_id,
                notification_type="forum_category_approved",
                title=title,
                content=content,
                title_en=title_en,
                content_en=content_en,
                related_id=str(new_category.id),
                related_type="forum_category"
            )

            # 发送推送通知
            try:
                send_push_notification_async_safe(
                    db=db,
                    user_id=category_request.requester_id,
                    notification_type="forum_category_approved",
                    data={"category_id": new_category.id},
                    template_vars={
                        "category_name": category_request.name
                    }
                )
            except Exception as e:
                logger.warning(f"发送板块批准推送通知失败: {e}")

            logger.info(f"板块申请批准通知已发送给申请人: {category_request.requester_id}")
        except Exception as e:
            logger.error(f"发送板块申请批准通知失败: {e}")
            # 通知失败不影响审核流程

        # 清理板块列表缓存
        try:
            from app.cache import invalidate_cache
            invalidate_cache("forum_categories*")
            clear_all_forum_visibility_cache(f"新板块 {new_category.id} 已创建")
        except Exception as e:
            logger.warning(f"清理板块缓存失败: {e}")

        return {
            "message": "申请已批准，新板块已创建",
            "category": schemas.ForumCategoryOut.model_validate(new_category),
            "request": schemas.ForumCategoryRequestOut.model_validate(category_request)
        }
    else:
        # 拒绝申请
        category_request.status = "rejected"
        category_request.admin_id = current_admin.id
        category_request.reviewed_at = get_utc_time()
        category_request.review_comment = review_comment

        await db.commit()
        await db.refresh(category_request)

        logger.info(f"管理员 {current_admin.id} 拒绝了板块申请 {request_id}")

        # 发送拒绝通知给申请人
        try:
            from app import async_crud

            title = "板块申请未通过"
            title_en = "Forum Category Application Rejected"
            content = f"很抱歉，您申请的板块「{category_request.name}」未通过审核。"
            if review_comment:
                content += f"\n审核意见：{review_comment}"
            content_en = f"Sorry, your forum category application '{category_request.name}' has been rejected."
            if review_comment:
                content_en += f"\nReview comment: {review_comment}"

            await async_crud.async_notification_crud.create_notification(
                db=db,
                user_id=category_request.requester_id,
                notification_type="forum_category_rejected",
                title=title,
                content=content,
                title_en=title_en,
                content_en=content_en,
                related_id=None,
                related_type="forum_category_request"
            )

            # 发送推送通知
            try:
                send_push_notification_async_safe(
                    db=db,
                    user_id=category_request.requester_id,
                    notification_type="forum_category_rejected",
                    data={"request_id": request_id},
                    template_vars={
                        "category_name": category_request.name
                    }
                )
            except Exception as e:
                logger.warning(f"发送板块拒绝推送通知失败: {e}")

            logger.info(f"板块申请拒绝通知已发送给申请人: {category_request.requester_id}")
        except Exception as e:
            logger.error(f"发送板块申请拒绝通知失败: {e}")
            # 通知失败不影响审核流程

        return {
            "message": "申请已拒绝",
            "request": schemas.ForumCategoryRequestOut.model_validate(category_request)
        }


# ==================== 板块详情路由（必须在 /categories/requests 之后） ====================

@router.get("/categories/{category_id}", response_model=schemas.ForumCategoryOut)
@measure_api_performance("get_forum_category")
async def get_category(
    category_id: int,
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    request: Request = None,  # FastAPI injects; Optional[Request] breaks Pydantic field detection
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取板块详情"""
    # 检查是否为管理员
    is_admin = False
    try:
        await get_current_admin_async(request, db)
        is_admin = True
    except HTTPException:
        pass

    result = await db.execute(
        select(models.ForumCategory).where(models.ForumCategory.id == category_id)
    )
    category = result.scalar_one_or_none()

    if not category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="板块不存在"
        )

    # 检查板块可见性（学校板块需要权限，管理员可以绕过）
    if not is_admin:
        await assert_forum_visible(current_user, category_id, db, raise_exception=True)

    # 记录浏览量（Redis 累加，定时同步到 DB）
    try:
        from app.redis_cache import get_redis_client
        _rc = get_redis_client()
        if _rc:
            _rk = f"forum:category:view_count:{category_id}"
            _rc.incr(_rk)
            _rc.expire(_rk, 7 * 24 * 3600)
        else:
            category.view_count += 1
            await db.flush()
    except Exception:
        category.view_count += 1
        await db.flush()

    # 显式创建 ForumCategoryOut 对象，确保包含双语字段
    return schemas.ForumCategoryOut(
        id=category.id,
        name=category.name,
        name_en=getattr(category, 'name_en', None),
        name_zh=getattr(category, 'name_zh', None),
        description=category.description,
        description_en=getattr(category, 'description_en', None),
        description_zh=getattr(category, 'description_zh', None),
        icon=category.icon,
        sort_order=category.sort_order,
        is_visible=category.is_visible,
        is_admin_only=getattr(category, 'is_admin_only', False),
        type=getattr(category, 'type', 'general'),
        country=getattr(category, 'country', None),
        university_code=getattr(category, 'university_code', None),
        skill_type=getattr(category, 'skill_type', None),
        post_count=category.post_count,
        service_count=getattr(category, 'service_count', 0),
        task_count=getattr(category, 'task_count', 0),
        last_post_at=category.last_post_at,
        created_at=category.created_at,
        updated_at=category.updated_at
    )


@router.post("/categories", response_model=schemas.ForumCategoryOut)
async def create_category(
    category: schemas.ForumCategoryCreate,
    request: Request,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """创建板块（管理员）"""
    # 检查名称是否已存在
    existing = await db.execute(
        select(models.ForumCategory).where(models.ForumCategory.name == category.name)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="板块名称已存在"
        )

    # 验证学校板块字段
    category_type = category.type or 'general'
    if category_type == 'university':
        if not category.university_code:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="university类型板块必须提供university_code"
            )
        # 验证大学编码是否存在
        university = await db.execute(
            select(models.University).where(models.University.code == category.university_code)
        )
        if not university.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"大学编码 '{category.university_code}' 不存在"
            )
        # university类型板块不应有country字段
        if category.country:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="university类型板块不应设置country字段"
            )
    elif category_type == 'root':
        if not category.country:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="root类型板块必须提供country字段"
            )
        # root类型板块不应有university_code字段
        if category.university_code:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="root类型板块不应设置university_code字段"
            )
    else:  # general
        # general类型板块不应有country和university_code字段
        if category.country or category.university_code:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="general类型板块不应设置country或university_code字段"
            )

    # 自动填充双语字段
    from app.utils.bilingual_helper import auto_fill_bilingual_fields

    normalized_description = category.description.strip() if category.description else None
    _, name_en, name_zh, description_en, description_zh = await auto_fill_bilingual_fields(
        name=category.name,
        description=normalized_description,
        name_en=category.name_en.strip() if category.name_en else None,
        name_zh=category.name_zh.strip() if category.name_zh else None,
        description_en=category.description_en.strip() if category.description_en else None,
        description_zh=category.description_zh.strip() if category.description_zh else None,
    )

    # 创建板块对象，包含双语字段
    category_dict = category.model_dump()
    category_dict['name_en'] = name_en
    category_dict['name_zh'] = name_zh
    category_dict['description_en'] = description_en
    category_dict['description_zh'] = description_zh

    db_category = models.ForumCategory(**category_dict)
    db.add(db_category)
    await db.flush()

    # 如果创建的是学校板块或 is_admin_only 板块，清理所有用户的可见板块缓存
    if (db_category.type in ('root', 'university') or db_category.is_admin_only):
        clear_all_forum_visibility_cache(f"新板块 {db_category.id} 已创建")

    # 记录管理员操作日志
    await log_admin_operation(
        operator_id=current_admin.id,
        operation_type="create_category",
        target_type="category",
        target_id=db_category.id,
        action="create",
        request=request,
        db=db
    )

    await db.commit()
    await db.refresh(db_category)

    # 清理板块列表缓存
    try:
        from app.cache import invalidate_cache
        invalidate_cache("forum_categories*")
    except Exception as e:
        logger.warning(f"清理板块缓存失败: {e}")

    return db_category


@router.put("/categories/{category_id}", response_model=schemas.ForumCategoryOut)
async def update_category(
    category_id: int,
    category: schemas.ForumCategoryUpdate,
    request: Request,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """更新板块（管理员）"""
    result = await db.execute(
        select(models.ForumCategory).where(models.ForumCategory.id == category_id)
    )
    db_category = result.scalar_one_or_none()

    if not db_category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="板块不存在"
        )

    # 如果更新名称，检查是否重复
    if category.name and category.name != db_category.name:
        existing = await db.execute(
            select(models.ForumCategory).where(models.ForumCategory.name == category.name)
        )
        if existing.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="板块名称已存在"
            )

    # 确定板块类型（如果更新了type，使用新值；否则使用当前值）
    category_type = category.type if category.type is not None else db_category.type

    # 验证学校板块字段
    if category_type == 'university':
        university_code = category.university_code if category.university_code is not None else db_category.university_code
        if not university_code:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="university类型板块必须提供university_code"
            )
        # 验证大学编码是否存在
        university = await db.execute(
            select(models.University).where(models.University.code == university_code)
        )
        if not university.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"大学编码 '{university_code}' 不存在"
            )
        # university类型板块不应有country字段
        if category.country is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="university类型板块不应设置country字段"
            )
    elif category_type == 'root':
        country = category.country if category.country is not None else db_category.country
        if not country:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="root类型板块必须提供country字段"
            )
        # root类型板块不应有university_code字段
        if category.university_code is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="root类型板块不应设置university_code字段"
            )
    else:  # general
        # general类型板块不应有country和university_code字段
        if category.country is not None or category.university_code is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="general类型板块不应设置country或university_code字段"
            )

    # 记录更新前的类型、is_admin_only 和 is_visible（用于判断是否需要清理缓存）
    old_type = db_category.type
    old_university_code = db_category.university_code
    old_country = db_category.country
    old_is_admin_only = db_category.is_admin_only
    old_is_visible = db_category.is_visible

    # 更新字段
    update_data = category.model_dump(exclude_unset=True)

    # 若客户端提交了双语字段则直接使用；否则若更新了 name/description 则用 auto_fill 填充
    if any(k in update_data for k in ('name_en', 'name_zh', 'description_en', 'description_zh')):
        # 直接使用管理员填写的双语字段，不覆盖
        pass
    elif 'name' in update_data or 'description' in update_data:
        from app.utils.bilingual_helper import auto_fill_bilingual_fields

        updated_name = update_data.get('name', db_category.name)
        updated_description = update_data.get('description', db_category.description)

        _, name_en, name_zh, description_en, description_zh = await auto_fill_bilingual_fields(
            name=updated_name,
            description=updated_description,
            name_en=db_category.name_en,
            name_zh=db_category.name_zh,
            description_en=db_category.description_en,
            description_zh=db_category.description_zh,
        )
        update_data['name_en'] = name_en
        update_data['name_zh'] = name_zh
        update_data['description_en'] = description_en
        update_data['description_zh'] = description_zh

    for field, value in update_data.items():
        setattr(db_category, field, value)

    db_category.updated_at = get_utc_time()
    await db.flush()

    # 如果板块类型、关联信息、is_admin_only 或 is_visible 发生变化，需要清理所有相关用户的缓存
    new_type = db_category.type
    new_university_code = db_category.university_code
    new_country = db_category.country
    new_is_admin_only = db_category.is_admin_only
    new_is_visible = db_category.is_visible

    if (old_type != new_type or
        old_university_code != new_university_code or
        old_country != new_country or
        old_is_admin_only != new_is_admin_only or
        old_is_visible != new_is_visible):
        # 清理所有用户的可见板块缓存（因为板块可见性可能已改变）
        clear_all_forum_visibility_cache(f"板块 {category_id} 信息变更")

    # 记录管理员操作日志
    await log_admin_operation(
        operator_id=current_admin.id,
        operation_type="update_category",
        target_type="category",
        target_id=category_id,
        action="update",
        request=request,
        db=db
    )

    await db.commit()
    await db.refresh(db_category)

    # 清理板块列表缓存
    try:
        from app.cache import invalidate_cache
        invalidate_cache("forum_categories*")
        invalidate_cache(f"forum_category:{category_id}*")
        # 如果可见性相关字段发生变化，清理所有用户的可见板块缓存
        if (old_type != new_type or
            old_university_code != new_university_code or
            old_country != new_country or
            old_is_admin_only != new_is_admin_only or
            old_is_visible != new_is_visible):
            clear_all_forum_visibility_cache(f"板块 {category_id} 信息更新")
    except Exception as e:
        logger.warning(f"清理板块缓存失败: {e}")

    return db_category


@router.delete("/categories/{category_id}")
async def delete_category(
    category_id: int,
    request: Request,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """删除板块（管理员）"""
    result = await db.execute(
        select(models.ForumCategory).where(models.ForumCategory.id == category_id)
    )
    category = result.scalar_one_or_none()

    if not category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="板块不存在"
        )

    # 记录删除前的类型和 is_admin_only（用于判断是否需要清理缓存）
    category_type = category.type
    category_is_admin_only = category.is_admin_only

    # 记录管理员操作日志（在删除前记录）
    await log_admin_operation(
        operator_id=current_admin.id,
        operation_type="delete_category",
        target_type="category",
        target_id=category_id,
        action="delete",
        request=request,
        db=db
    )

    await db.delete(category)
    await db.commit()

    # 如果删除的是学校板块或 is_admin_only 板块，清理所有用户的可见板块缓存
    if category_type in ('root', 'university') or category_is_admin_only:
        clear_all_forum_visibility_cache(f"板块 {category_id} 已删除")

    return {"message": "板块删除成功"}


# ==================== Skill Feed Endpoint ====================

@router.get("/categories/{category_id}/feed", response_model=schemas.SkillFeedResponse)
async def get_skill_feed(
    category_id: int,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    sort_by: str = Query("weight", pattern="^(weight|time)$"),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取技能板块的混合 feed（帖子 + 任务 + 服务）"""
    import datetime as _datetime

    # 1. Validate category exists and is a skill type
    cat_result = await db.execute(
        select(models.ForumCategory).where(
            models.ForumCategory.id == category_id,
            models.ForumCategory.is_visible == True,
        )
    )
    category = cat_result.scalar_one_or_none()
    if not category:
        raise HTTPException(status_code=404, detail="Category not found")
    if category.type != "skill" or not category.skill_type:
        raise HTTPException(status_code=400, detail="Not a skill category")

    skill_type = category.skill_type
    now = get_utc_time()
    twenty_four_hours_ago = now - _datetime.timedelta(hours=24)

    # 2. Query posts for this category
    posts_query = (
        select(models.ForumPost)
        .options(selectinload(models.ForumPost.author))
        .where(
            models.ForumPost.category_id == category_id,
            models.ForumPost.is_deleted == False,
            models.ForumPost.is_visible == True,
        )
    )
    posts_result = await db.execute(posts_query)
    posts = posts_result.scalars().all()

    # 3. Query open tasks matching skill_type
    tasks_query = (
        select(models.Task)
        .options(selectinload(models.Task.poster))
        .where(
            models.Task.task_type == skill_type,
            models.Task.status == "open",
            models.Task.is_visible == True,
        )
    )
    tasks_result = await db.execute(tasks_query)
    tasks = tasks_result.scalars().all()

    # 4. Query active services matching skill_type (by category field)
    services_query = (
        select(models.TaskExpertService)
        .where(
            models.TaskExpertService.category == skill_type,
            models.TaskExpertService.status == "active",
        )
    )
    services_result = await db.execute(services_query)
    services = services_result.scalars().all()

    # 5. Build feed items with sort scores
    feed_items = []

    for post in posts:
        created = post.created_at or now
        if post.is_pinned:
            score = 10000.0
        else:
            score = created.timestamp()
        feed_items.append({
            "item_type": "post",
            "data": _post_to_feed_data(post),
            "sort_score": score,
            "created_at": created,
        })

    for task in tasks:
        created = task.created_at or now
        if created >= twenty_four_hours_ago:
            age_hours = (now - created).total_seconds() / 3600
            score = 5000.0 + (24 - age_hours) * 200
        else:
            score = created.timestamp()
        feed_items.append({
            "item_type": "task",
            "data": _task_to_feed_data(task),
            "sort_score": score,
            "created_at": created,
        })

    for service in services:
        created = service.created_at or now
        if created >= twenty_four_hours_ago:
            age_hours = (now - created).total_seconds() / 3600
            score = 4000.0 + (24 - age_hours) * 160
        else:
            score = created.timestamp()
        feed_items.append({
            "item_type": "service",
            "data": _service_to_feed_data(service),
            "sort_score": score,
            "created_at": created,
        })

    # 6. Sort
    if sort_by == "weight":
        feed_items.sort(key=lambda x: (-x["sort_score"], -x["created_at"].timestamp()))
    else:
        feed_items.sort(key=lambda x: -x["created_at"].timestamp())

    # 7. Paginate
    total = len(feed_items)
    start = (page - 1) * page_size
    end = start + page_size
    page_items = feed_items[start:end]
    has_more = end < total

    return schemas.SkillFeedResponse(
        items=[schemas.FeedItem(**item) for item in page_items],
        total=total,
        page=page,
        page_size=page_size,
        has_more=has_more,
    )


# ==================== 板块统计 API ====================

@router.get("/categories/{category_id}/stats")
async def get_category_stats(
    category_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取板块详细统计信息"""
    # 验证板块存在
    category_result = await db.execute(
        select(models.ForumCategory).where(models.ForumCategory.id == category_id)
    )
    category = category_result.scalar_one_or_none()
    if not category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="板块不存在",
            headers={"X-Error-Code": "CATEGORY_NOT_FOUND"}
        )

    # 统计可见帖子数
    post_count_result = await db.execute(
        select(func.count(models.ForumPost.id))
        .where(
            models.ForumPost.category_id == category_id,
            models.ForumPost.is_deleted == False,
            models.ForumPost.is_visible == True
        )
    )
    post_count = post_count_result.scalar() or 0

    # 统计总回复数（可见帖子下的可见回复）
    reply_count_result = await db.execute(
        select(func.count(models.ForumReply.id))
        .join(models.ForumPost)
        .where(
            models.ForumPost.category_id == category_id,
            models.ForumPost.is_deleted == False,
            models.ForumPost.is_visible == True,
            models.ForumReply.is_deleted == False,
            models.ForumReply.is_visible == True
        )
    )
    reply_count = reply_count_result.scalar() or 0

    # 统计总点赞数（可见帖子下的点赞）
    like_count_result = await db.execute(
        select(func.count(models.ForumLike.id))
        .join(models.ForumPost, and_(
            models.ForumLike.target_type == "post",
            models.ForumLike.target_id == models.ForumPost.id
        ))
        .where(
            models.ForumPost.category_id == category_id,
            models.ForumPost.is_deleted == False,
            models.ForumPost.is_visible == True
        )
    )
    like_count = like_count_result.scalar() or 0

    # 统计参与用户数（在该板块发过帖子或回复的用户）
    post_authors = select(models.ForumPost.author_id).distinct().where(
        models.ForumPost.category_id == category_id,
        models.ForumPost.is_deleted == False
    )
    reply_authors = select(models.ForumReply.author_id).distinct().join(models.ForumPost).where(
        models.ForumPost.category_id == category_id,
        models.ForumReply.is_deleted == False
    )
    users_subquery = post_authors.union(reply_authors).subquery()
    users_count_result = await db.execute(
        select(func.count()).select_from(users_subquery)
    )
    users_count = users_count_result.scalar() or 0

    return {
        "category_id": category_id,
        "category_name": category.name,
        "post_count": post_count,
        "reply_count": reply_count,
        "like_count": like_count,
        "users_count": users_count,
        "last_post_at": category.last_post_at
    }
