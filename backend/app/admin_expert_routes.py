"""
管理员达人团队管理API路由
实现管理员管理达人团队的相关接口
"""

import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import and_, select, func, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.deps import get_async_db_dependency
from app.separate_auth_deps import get_current_admin
from app import models
from app.models_expert import (
    Expert,
    ExpertMember,
    ExpertApplication,
    ExpertProfileUpdateRequest,
    FeaturedExpertV2,
    generate_expert_id,
)
from app.schemas_expert import (
    ExpertApplicationOut,
    ExpertApplicationReview,
    ExpertProfileUpdateOut,
    ExpertProfileUpdateReview,
    ExpertOut,
    ExpertCreateByAdmin,
)
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

admin_expert_router = APIRouter(prefix="/api/admin/experts", tags=["admin-experts"])


# ==================== 内部辅助 ====================

async def _create_expert_team_with_owner(
    db: AsyncSession,
    *,
    name: str,
    owner_user_id: str,
    name_en: Optional[str] = None,
    name_zh: Optional[str] = None,
    bio: Optional[str] = None,
    bio_en: Optional[str] = None,
    bio_zh: Optional[str] = None,
    avatar: Optional[str] = None,
    is_official: bool = False,
    official_badge: Optional[str] = None,
    allow_applications: bool = False,
) -> Expert:
    """在事务中创建一个达人团队 + owner 成员 + 论坛板块。

    调用方负责 `db.commit()` 或 `db.rollback()`。
    raises HTTPException(404) 如果 owner_user_id 不存在。
    """
    # 校验 owner 用户存在
    user_result = await db.execute(
        select(models.User).where(models.User.id == owner_user_id)
    )
    owner = user_result.scalar_one_or_none()
    if not owner:
        raise HTTPException(status_code=404, detail=f"用户 {owner_user_id} 不存在")

    now = get_utc_time()

    # 生成唯一 expert_id
    expert_id = generate_expert_id()
    for _ in range(10):
        existing = await db.execute(select(Expert).where(Expert.id == expert_id))
        if existing.scalar_one_or_none() is None:
            break
        expert_id = generate_expert_id()
    else:
        raise HTTPException(status_code=500, detail="Failed to generate unique expert ID")

    expert = Expert(
        id=expert_id,
        name=name,
        name_en=name_en,
        name_zh=name_zh,
        bio=bio,
        bio_en=bio_en,
        bio_zh=bio_zh,
        avatar=avatar,
        status="active",
        allow_applications=allow_applications,
        is_official=is_official,
        official_badge=official_badge,
        member_count=1,
        created_at=now,
        updated_at=now,
    )
    db.add(expert)

    member = ExpertMember(
        expert_id=expert_id,
        user_id=owner_user_id,
        role="owner",
        status="active",
        joined_at=now,
        updated_at=now,
    )
    db.add(member)

    # 创建达人板块
    from app.models import ForumCategory
    board = ForumCategory(
        name=f"expert_{expert_id}",
        name_zh=name,
        name_en=name_en or name,
        type="expert",
        expert_id=expert_id,
        is_visible=True,
        is_admin_only=False,
    )
    db.add(board)
    await db.flush()
    expert.forum_category_id = board.id

    return expert


# ==================== 达人申请管理 ====================

@admin_expert_router.get("/applications", response_model=dict)
async def list_expert_applications(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status_filter: Optional[str] = Query(None, description="按状态筛选: pending, approved, rejected"),
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """列出达人申请（分页，可按状态筛选）"""
    try:
        q = select(ExpertApplication)
        if status_filter:
            q = q.where(ExpertApplication.status == status_filter)
        q = q.order_by(ExpertApplication.created_at.desc())

        count_q = select(func.count()).select_from(ExpertApplication)
        if status_filter:
            count_q = count_q.where(ExpertApplication.status == status_filter)

        total_result = await db.execute(count_q)
        total = total_result.scalar_one()

        offset = (page - 1) * page_size
        q = q.offset(offset).limit(page_size)
        result = await db.execute(q)
        applications = result.scalars().all()

        return {
            "total": total,
            "page": page,
            "page_size": page_size,
            "items": [ExpertApplicationOut.model_validate(a) for a in applications],
        }
    except Exception as e:
        logger.error("list_expert_applications error: %s", e)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@admin_expert_router.post("/applications/{application_id}/review")
async def review_expert_application(
    application_id: int,
    body: ExpertApplicationReview,
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """审核达人申请（批准/拒绝）"""
    try:
        result = await db.execute(
            select(ExpertApplication).where(ExpertApplication.id == application_id)
        )
        application = result.scalar_one_or_none()
        if not application:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="申请不存在")

        if application.status != "pending":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="申请已被处理")

        now = get_utc_time()
        application.reviewed_by = current_admin.id
        application.reviewed_at = now
        application.review_comment = body.review_comment

        if body.action == "approve":
            application.status = "approved"

            expert = await _create_expert_team_with_owner(
                db,
                name=application.expert_name,
                owner_user_id=application.user_id,
                bio=application.bio,
                avatar=application.avatar,
            )

            await db.commit()
            return {"status": "approved", "expert_id": expert.id}
        else:
            application.status = "rejected"
            await db.commit()
            return {"status": "rejected"}

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error("review_expert_application error: %s", e)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


# ==================== 管理员直接新建达人团队 ====================

@admin_expert_router.post("", status_code=201)
async def admin_create_expert_team(
    body: ExpertCreateByAdmin,
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员直接创建达人团队（不走用户申请流程）。

    - 必须指定 owner_user_id（一个已存在的真实用户作为团队 owner）
    - 创建时同时创建：Expert 记录、ExpertMember(owner) 记录、ForumCategory 板块
    """
    try:
        expert = await _create_expert_team_with_owner(
            db,
            name=body.name,
            name_en=body.name_en,
            name_zh=body.name_zh,
            bio=body.bio,
            bio_en=body.bio_en,
            bio_zh=body.bio_zh,
            avatar=body.avatar,
            owner_user_id=body.owner_user_id,
            is_official=body.is_official,
            official_badge=body.official_badge,
            allow_applications=body.allow_applications,
        )
        await db.commit()
        logger.info(
            "admin %s created expert team %s with owner %s",
            current_admin.id, expert.id, body.owner_user_id,
        )
        return {"detail": "创建成功", "expert_id": expert.id}
    except HTTPException:
        await db.rollback()
        raise
    except Exception as e:
        await db.rollback()
        logger.error("admin_create_expert_team error: %s", e)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


# ==================== 资料修改申请管理 ====================

@admin_expert_router.get("/profile-update-requests", response_model=dict)
async def list_profile_update_requests(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status_filter: Optional[str] = Query(None, description="按状态筛选: pending, approved, rejected"),
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """列出达人资料修改申请（分页，可按状态筛选）"""
    try:
        q = select(ExpertProfileUpdateRequest)
        if status_filter:
            q = q.where(ExpertProfileUpdateRequest.status == status_filter)
        q = q.order_by(ExpertProfileUpdateRequest.created_at.desc())

        count_q = select(func.count()).select_from(ExpertProfileUpdateRequest)
        if status_filter:
            count_q = count_q.where(ExpertProfileUpdateRequest.status == status_filter)

        total_result = await db.execute(count_q)
        total = total_result.scalar_one()

        offset = (page - 1) * page_size
        q = q.offset(offset).limit(page_size)
        result = await db.execute(q)
        requests = result.scalars().all()

        return {
            "total": total,
            "page": page,
            "page_size": page_size,
            "items": [ExpertProfileUpdateOut.model_validate(r) for r in requests],
        }
    except Exception as e:
        logger.error("list_profile_update_requests error: %s", e)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@admin_expert_router.post("/profile-update-requests/{request_id}/review")
async def review_profile_update_request(
    request_id: int,
    body: ExpertProfileUpdateReview,
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """审核达人资料修改申请（批准时更新达人字段）"""
    try:
        result = await db.execute(
            select(ExpertProfileUpdateRequest).where(ExpertProfileUpdateRequest.id == request_id)
        )
        update_request = result.scalar_one_or_none()
        if not update_request:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="申请不存在")

        if update_request.status != "pending":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="申请已被处理")

        now = get_utc_time()
        update_request.reviewed_by = current_admin.id
        update_request.reviewed_at = now
        update_request.review_comment = body.review_comment

        if body.action == "approve":
            update_request.status = "approved"

            # 更新达人信息
            expert_result = await db.execute(
                select(Expert).where(Expert.id == update_request.expert_id)
            )
            expert = expert_result.scalar_one_or_none()
            if expert:
                if update_request.new_name is not None:
                    expert.name = update_request.new_name
                if update_request.new_bio is not None:
                    expert.bio = update_request.new_bio
                if update_request.new_avatar is not None:
                    expert.avatar = update_request.new_avatar
                expert.updated_at = now

            await db.commit()
            return {"status": "approved"}
        else:
            update_request.status = "rejected"
            await db.commit()
            return {"status": "rejected"}

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error("review_profile_update_request error: %s", e)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


# ==================== 达人团队列表管理 ====================

@admin_expert_router.get("", response_model=dict)
async def list_experts(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status_filter: Optional[str] = Query(None, description="按状态筛选: active, inactive, suspended"),
    keyword: Optional[str] = Query(None, description="按名称关键字搜索"),
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """列出所有达人团队（分页，可按状态/关键字筛选）"""
    try:
        q = select(Expert)
        if status_filter:
            q = q.where(Expert.status == status_filter)
        if keyword:
            q = q.where(
                or_(
                    Expert.name.ilike(f"%{keyword}%"),
                    Expert.name_en.ilike(f"%{keyword}%"),
                    Expert.name_zh.ilike(f"%{keyword}%"),
                )
            )
        q = q.order_by(Expert.created_at.desc())

        count_q = select(func.count()).select_from(Expert)
        if status_filter:
            count_q = count_q.where(Expert.status == status_filter)
        if keyword:
            count_q = count_q.where(
                or_(
                    Expert.name.ilike(f"%{keyword}%"),
                    Expert.name_en.ilike(f"%{keyword}%"),
                    Expert.name_zh.ilike(f"%{keyword}%"),
                )
            )

        total_result = await db.execute(count_q)
        total = total_result.scalar_one()

        offset = (page - 1) * page_size
        q = q.offset(offset).limit(page_size)
        result = await db.execute(q)
        experts = result.scalars().all()

        return {
            "total": total,
            "page": page,
            "page_size": page_size,
            "items": [ExpertOut.model_validate(e) for e in experts],
        }
    except Exception as e:
        logger.error("list_experts error: %s", e)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


# ==================== 达人详情/编辑/注销 ====================

@admin_expert_router.get("/{expert_id}")
async def get_expert_detail_admin(
    expert_id: str,
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员：获取达人详情"""
    result = await db.execute(select(Expert).where(Expert.id == expert_id))
    expert = result.scalar_one_or_none()
    if not expert:
        raise HTTPException(status_code=404, detail="达人不存在")

    # 获取成员列表
    members_result = await db.execute(
        select(ExpertMember).where(
            and_(ExpertMember.expert_id == expert_id, ExpertMember.status == "active")
        )
    )
    members = members_result.scalars().all()

    return {
        "id": expert.id,
        "name": expert.name,
        "name_en": expert.name_en,
        "name_zh": expert.name_zh,
        "bio": expert.bio,
        "bio_en": expert.bio_en,
        "avatar": expert.avatar,
        "status": expert.status,
        "rating": float(expert.rating) if expert.rating else 0,
        "total_services": expert.total_services,
        "completed_tasks": expert.completed_tasks,
        "member_count": expert.member_count,
        "is_official": expert.is_official,
        "official_badge": expert.official_badge,
        "allow_applications": expert.allow_applications,
        "stripe_onboarding_complete": expert.stripe_onboarding_complete,
        "forum_category_id": expert.forum_category_id,
        "created_at": expert.created_at.isoformat() if expert.created_at else None,
        "members": [
            {"user_id": m.user_id, "role": m.role, "joined_at": m.joined_at.isoformat() if m.joined_at else None}
            for m in members
        ],
    }


@admin_expert_router.put("/{expert_id}")
async def update_expert_admin(
    expert_id: str,
    body: dict,
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员：直接编辑达人信息"""
    result = await db.execute(select(Expert).where(Expert.id == expert_id))
    expert = result.scalar_one_or_none()
    if not expert:
        raise HTTPException(status_code=404, detail="达人不存在")

    # 允许更新的字段
    allowed_fields = [
        'name', 'name_en', 'name_zh', 'bio', 'bio_en', 'bio_zh',
        'avatar', 'status', 'is_official', 'official_badge',
        'allow_applications',
    ]
    for field in allowed_fields:
        if field in body:
            setattr(expert, field, body[field])

    expert.updated_at = get_utc_time()
    await db.commit()
    return {"detail": "更新成功", "expert_id": expert_id}


@admin_expert_router.delete("/{expert_id}")
async def delete_expert_admin(
    expert_id: str,
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员：注销达人团队"""
    result = await db.execute(select(Expert).where(Expert.id == expert_id))
    expert = result.scalar_one_or_none()
    if not expert:
        raise HTTPException(status_code=404, detail="达人不存在")

    now = get_utc_time()
    expert.status = "dissolved"
    expert.updated_at = now

    # 下架所有服务
    from app.models import TaskExpertService
    await db.execute(
        TaskExpertService.__table__.update()
        .where(and_(TaskExpertService.owner_type == "expert", TaskExpertService.owner_id == expert_id))
        .values(status="inactive")
    )

    # 所有成员离开
    await db.execute(
        ExpertMember.__table__.update()
        .where(ExpertMember.expert_id == expert_id)
        .values(status="left", updated_at=now)
    )

    # 删除精选
    await db.execute(
        FeaturedExpertV2.__table__.delete()
        .where(FeaturedExpertV2.expert_id == expert_id)
    )

    await db.commit()
    return {"detail": "达人已注销"}


# ==================== 精选达人管理 ====================

@admin_expert_router.post("/{expert_id}/feature")
async def toggle_featured_expert(
    expert_id: str,
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """切换达人团队精选状态（存在则切换 is_featured，不存在则创建）"""
    try:
        # 检查达人是否存在
        expert_result = await db.execute(select(Expert).where(Expert.id == expert_id))
        expert = expert_result.scalar_one_or_none()
        if not expert:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="达人团队不存在")

        now = get_utc_time()
        featured_result = await db.execute(
            select(FeaturedExpertV2).where(FeaturedExpertV2.expert_id == expert_id)
        )
        featured = featured_result.scalar_one_or_none()

        if featured:
            featured.is_featured = not featured.is_featured
            featured.updated_at = now
            new_status = featured.is_featured
        else:
            featured = FeaturedExpertV2(
                expert_id=expert_id,
                is_featured=True,
                created_by=current_admin.id,
                created_at=now,
                updated_at=now,
            )
            db.add(featured)
            new_status = True

        await db.commit()
        return {"expert_id": expert_id, "is_featured": new_status}

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error("toggle_featured_expert error: %s", e)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


# ==================== 达人状态管理 ====================

@admin_expert_router.put("/{expert_id}/status")
async def change_expert_status(
    expert_id: str,
    new_status: str = Query(..., description="新状态: active, inactive, suspended"),
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """修改达人团队状态"""
    allowed_statuses = {"active", "inactive", "suspended"}
    if new_status not in allowed_statuses:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"无效状态，允许值: {', '.join(allowed_statuses)}",
        )

    try:
        expert_result = await db.execute(select(Expert).where(Expert.id == expert_id))
        expert = expert_result.scalar_one_or_none()
        if not expert:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="达人团队不存在")

        expert.status = new_status
        expert.updated_at = get_utc_time()
        await db.commit()
        return {"expert_id": expert_id, "status": new_status}

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error("change_expert_status error: %s", e)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))
