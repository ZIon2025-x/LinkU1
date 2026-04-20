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

    # 先 flush 确保 experts 行先于 forum_categories 落库
    # （async SA + asyncpg 不保证列级 FK 的 insert 顺序，否则会触发 FK 违反）
    await db.flush()

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


# ==================== 服务列表(跨团队) — Phase B ====================

@admin_expert_router.get("/services")
async def get_all_expert_services_admin(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    expert_id: Optional[str] = Query(None, description="按团队 ID 筛选"),
    status_filter: Optional[str] = Query(
        None, description="按状态筛选: active / deleted / inactive"
    ),
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """跨团队列出所有团队服务(管理员视角),用于内容审核。"""
    base = select(models.TaskExpertService).where(
        models.TaskExpertService.owner_type == "expert"
    )
    if expert_id:
        base = base.where(models.TaskExpertService.owner_id == expert_id)
    if status_filter:
        base = base.where(models.TaskExpertService.status == status_filter)

    count_q = select(func.count()).select_from(base.subquery())
    total = (await db.execute(count_q)).scalar() or 0

    offset = (page - 1) * limit
    list_q = base.order_by(
        models.TaskExpertService.created_at.desc()
    ).offset(offset).limit(limit)
    services = (await db.execute(list_q)).scalars().all()

    # 一次性把涉及到的 expert 名字捞出来,避免 N+1
    expert_ids = list({s.owner_id for s in services if s.owner_id})
    name_map: dict = {}
    if expert_ids:
        rows = await db.execute(
            select(Expert.id, Expert.name).where(Expert.id.in_(expert_ids))
        )
        name_map = {r.id: r.name for r in rows.all()}

    items = []
    for s in services:
        desc = (str(s.description)[:200] if s.description else "")
        items.append({
            "id": s.id,
            "expert_id": s.owner_id,
            "expert_name": name_map.get(s.owner_id) or s.owner_id or "",
            "service_name": s.service_name or "",
            "service_name_en": s.service_name_en,
            "service_name_zh": s.service_name_zh,
            "description": desc,
            "description_en": (s.description_en or "")[:200] if s.description_en else None,
            "description_zh": (s.description_zh or "")[:200] if s.description_zh else None,
            "images": s.images,
            "base_price": float(s.base_price) if s.base_price is not None else 0,
            "currency": s.currency or "GBP",
            "status": s.status or "active",
            "package_type": s.package_type,
            "view_count": s.view_count or 0,
            "application_count": s.application_count or 0,
            "has_time_slots": getattr(s, "has_time_slots", False) or False,
            "created_at": s.created_at.isoformat() if s.created_at else None,
        })
    return {"items": items, "total": total, "page": page, "limit": limit}


# ==================== 服务下架/恢复 — Phase B ====================

@admin_expert_router.post("/services/{service_id}/review")
async def review_expert_service(
    service_id: int,
    review_data: dict,
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员审核团队服务。

    新模型下,达人创建服务无需审核(默认 active),此端点用于内容审核场景:
      - approve → active   (恢复一个被下架的服务)
      - reject  → deleted  (软删除/下架,与团队侧的删除一致)
    """
    action = review_data.get("action")
    if action not in ("approve", "reject"):
        raise HTTPException(status_code=400, detail="action 必须是 approve 或 reject")

    result = await db.execute(
        select(models.TaskExpertService).where(
            and_(
                models.TaskExpertService.id == service_id,
                models.TaskExpertService.owner_type == "expert",
            )
        )
    )
    service = result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")

    new_status = "active" if action == "approve" else "deleted"
    if service.status != new_status:
        service.status = new_status
        await db.commit()

    return {
        "message": f"服务已{'恢复' if action == 'approve' else '下架'}",
        "status": service.status,
    }


# ==================== 单个服务 编辑 + 删除 — Phase B ====================

@admin_expert_router.put("/services/{service_id}")
async def update_expert_service_admin(
    service_id: int,
    body: dict,
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员编辑团队服务字段。

    只动安全可改字段;价格走 Decimal 转换。
    与团队侧 expert_service_routes.update_service 不同,本端点是管理员越权编辑路径,
    不做 owner 校验,仅限 owner_type='expert' (团队服务)。
    """
    result = await db.execute(
        select(models.TaskExpertService).where(
            and_(
                models.TaskExpertService.id == service_id,
                models.TaskExpertService.owner_type == "expert",
            )
        )
    )
    service = result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")

    allowed = {
        "service_name", "service_name_en", "service_name_zh",
        "description", "description_en", "description_zh",
        "base_price", "currency", "status", "display_order",
        "category", "pricing_type", "location_type", "location",
        "skills", "images",
    }
    for key, value in (body or {}).items():
        if key not in allowed or not hasattr(service, key):
            continue
        if key == "base_price" and value is not None:
            from decimal import Decimal
            setattr(service, key, Decimal(str(value)))
        else:
            setattr(service, key, value)

    service.updated_at = get_utc_time()
    await db.commit()
    logger.info(
        f"管理员 {current_admin.id} 编辑团队服务 {service_id} (owner={service.owner_id})"
    )
    return {"message": "服务更新成功", "service_id": service_id}


@admin_expert_router.delete("/services/{service_id}")
async def delete_expert_service_admin(
    service_id: int,
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员软删除团队服务 (status='deleted'),与 review reject 行为一致。

    不做硬删: 历史 ServiceApplication 仍需保留;如需恢复,用 review approve。
    """
    result = await db.execute(
        select(models.TaskExpertService).where(
            and_(
                models.TaskExpertService.id == service_id,
                models.TaskExpertService.owner_type == "expert",
            )
        )
    )
    service = result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")
    if service.status != "deleted":
        service.status = "deleted"
        service.updated_at = get_utc_time()
        await db.commit()
    logger.info(
        f"管理员 {current_admin.id} 软删除团队服务 {service_id} (owner={service.owner_id})"
    )
    return {"message": "服务已删除", "service_id": service_id}


# ==================== 活动列表(跨团队) — Phase B ====================

@admin_expert_router.get("/activities")
async def get_all_expert_activities_admin(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    expert_id: Optional[str] = Query(None, description="按团队 ID 筛选"),
    status_filter: Optional[str] = Query(None, description="按状态筛选"),
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """跨团队列出所有团队活动(管理员视角)。"""
    base = select(models.Activity).where(
        and_(
            models.Activity.activity_type == "standard",
            models.Activity.owner_type == "expert",
        )
    )
    if expert_id:
        base = base.where(models.Activity.owner_id == expert_id)
    if status_filter:
        base = base.where(models.Activity.status == status_filter)

    count_q = select(func.count()).select_from(base.subquery())
    total = (await db.execute(count_q)).scalar() or 0

    offset = (page - 1) * limit
    list_q = base.order_by(models.Activity.created_at.desc()).offset(offset).limit(limit)
    activities = (await db.execute(list_q)).scalars().all()

    expert_ids = list({a.owner_id for a in activities if a.owner_id})
    name_map: dict = {}
    if expert_ids:
        rows = await db.execute(
            select(Expert.id, Expert.name).where(Expert.id.in_(expert_ids))
        )
        name_map = {r.id: r.name for r in rows.all()}

    items = []
    for a in activities:
        desc = (str(a.description)[:200] if a.description else "")
        items.append({
            "id": a.id,
            "expert_id": a.owner_id,
            "expert_name": name_map.get(a.owner_id) or a.owner_id or "",
            "title": a.title or "",
            "description": desc,
            "expert_service_id": a.expert_service_id,
            "location": a.location or "",
            "task_type": a.task_type or "",
            "status": a.status or "open",
            "max_participants": a.max_participants or 1,
            "currency": a.currency or "GBP",
            "discounted_price_per_participant": (
                float(a.discounted_price_per_participant)
                if a.discounted_price_per_participant is not None
                else None
            ),
            "deadline": a.deadline.isoformat() if a.deadline else None,
            "created_at": a.created_at.isoformat() if a.created_at else None,
        })
    return {"items": items, "total": total, "page": page, "limit": limit}


# ==================== 活动下架/恢复 — Phase B ====================

@admin_expert_router.post("/activities/{activity_id}/review")
async def review_expert_activity(
    activity_id: int,
    review_data: dict,
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员审核团队活动:approve → open, reject → cancelled"""
    action = review_data.get("action")
    if action not in ("approve", "reject"):
        raise HTTPException(status_code=400, detail="action 必须是 approve 或 reject")

    result = await db.execute(
        select(models.Activity).where(
            and_(
                models.Activity.id == activity_id,
                models.Activity.owner_type == "expert",
            )
        )
    )
    activity = result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="活动不存在")

    activity.status = "open" if action == "approve" else "cancelled"
    await db.commit()
    return {
        "message": f"活动已{'恢复' if action == 'approve' else '下架'}",
        "status": activity.status,
    }


# ==================== 单个活动 编辑 + 删除 — Phase B ====================

@admin_expert_router.put("/activities/{activity_id}")
async def update_expert_activity_admin(
    activity_id: int,
    body: dict,
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员编辑团队活动安全字段 (不动定价/上限/截止时间,避免影响订单)。"""
    result = await db.execute(
        select(models.Activity).where(
            and_(
                models.Activity.id == activity_id,
                models.Activity.owner_type == "expert",
            )
        )
    )
    activity = result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="活动不存在")

    allowed = {
        "title", "description", "status", "location",
        "task_type", "is_public", "visibility",
    }
    for key, value in (body or {}).items():
        if key not in allowed or not hasattr(activity, key):
            continue
        setattr(activity, key, value)
    activity.updated_at = get_utc_time()
    await db.commit()
    logger.info(
        f"管理员 {current_admin.id} 编辑团队活动 {activity_id} (owner={activity.owner_id})"
    )
    return {"message": "活动更新成功", "activity_id": activity_id}


@admin_expert_router.delete("/activities/{activity_id}")
async def delete_expert_activity_admin(
    activity_id: int,
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员取消团队活动 (status='cancelled'),与 review reject 行为一致。

    不做硬删 + cascade: 已支付的子任务 PI 仍在跑,误删会丢退款链路。
    需要彻底清理 (含买家退款) 的场景走 multi_participant_routes.delete_expert_activity。
    """
    result = await db.execute(
        select(models.Activity).where(
            and_(
                models.Activity.id == activity_id,
                models.Activity.owner_type == "expert",
            )
        )
    )
    activity = result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="活动不存在")
    if activity.status != "cancelled":
        activity.status = "cancelled"
        activity.updated_at = get_utc_time()
        await db.commit()
    logger.info(
        f"管理员 {current_admin.id} 取消团队活动 {activity_id} (owner={activity.owner_id})"
    )
    return {"message": "活动已取消", "activity_id": activity_id}


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

    # is_featured 在独立的 FeaturedExpertV2 表里, 这里 left-join 取一下
    featured_result = await db.execute(
        select(FeaturedExpertV2.is_featured).where(FeaturedExpertV2.expert_id == expert_id)
    )
    is_featured_row = featured_result.scalar_one_or_none()

    return {
        "id": expert.id,
        "name": expert.name,
        "name_en": expert.name_en,
        "name_zh": expert.name_zh,
        "bio": expert.bio,
        "bio_en": expert.bio_en,
        "bio_zh": expert.bio_zh,
        "avatar": expert.avatar,
        "status": expert.status,
        "rating": float(expert.rating) if expert.rating else 0,
        "completion_rate": float(expert.completion_rate) if expert.completion_rate else 0,
        "total_services": expert.total_services,
        "completed_tasks": expert.completed_tasks,
        "member_count": expert.member_count,
        "is_official": expert.is_official,
        "official_badge": expert.official_badge,
        "allow_applications": expert.allow_applications,
        "stripe_onboarding_complete": expert.stripe_onboarding_complete,
        "forum_category_id": expert.forum_category_id,
        # migration 188: 达人画像字段
        "category": expert.category,
        "location": expert.location,
        "display_order": expert.display_order,
        "is_verified": expert.is_verified,
        "expertise_areas": expert.expertise_areas,
        "expertise_areas_en": expert.expertise_areas_en,
        "featured_skills": expert.featured_skills,
        "featured_skills_en": expert.featured_skills_en,
        "achievements": expert.achievements,
        "achievements_en": expert.achievements_en,
        "response_time": expert.response_time,
        "response_time_en": expert.response_time_en,
        "user_level": expert.user_level,
        "is_featured": bool(is_featured_row) if is_featured_row is not None else False,
        "created_at": expert.created_at.isoformat() if expert.created_at else None,
        "updated_at": expert.updated_at.isoformat() if expert.updated_at else None,
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

    # 允许更新的字段 — migration 188 加了 11 个画像字段
    allowed_fields = [
        'name', 'name_en', 'name_zh', 'bio', 'bio_en', 'bio_zh',
        'avatar', 'status', 'is_official', 'official_badge',
        'allow_applications',
        # migration 188:
        'category', 'location', 'display_order', 'is_verified',
        'expertise_areas', 'expertise_areas_en',
        'featured_skills', 'featured_skills_en',
        'achievements', 'achievements_en',
        'response_time', 'response_time_en', 'user_level',
    ]
    # JSONB 列收到 None 当成 NULL, 收到 [] 当成空数组, 与 admin 表单 parseList 行为对齐
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
