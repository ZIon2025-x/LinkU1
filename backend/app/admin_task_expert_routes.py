"""管理员: 跨团队的服务/活动列表 + 内容审核(下架).

历史: 这个文件原本管理 legacy `task_experts` 模型,2026-04-08 重写为
使用新 `experts` 表 (owner_type='expert' + owner_id) 但保持相同的 URL,
以保证 `admin/src/api.ts` 中的旧调用站点不受影响。

Endpoints (URL 保持稳定 — admin frontend 调用):
  GET    /api/admin/task-expert-services                    跨团队服务列表
  GET    /api/admin/task-expert-activities                  跨团队活动列表
  POST   /api/admin/task-expert-services/{id}/review        服务下架/恢复
  POST   /api/admin/task-expert-activities/{id}/review      活动下架/恢复
  POST   /api/admin/task-expert-applications/{id}/create-featured-expert
                                                            从已批准的 ExpertApplication
                                                            创建 FeaturedExpertV2
"""

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import and_, select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.exc import IntegrityError

from app import models
from app.deps import get_async_db_dependency
from app.models_expert import Expert, ExpertApplication, FeaturedExpertV2


# 复用 admin_expert_routes 的 admin 依赖,避免维护两份认证。
async def get_current_admin_async(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
) -> models.AdminUser:
    from app.admin_auth import validate_admin_session

    admin_session = validate_admin_session(request)
    if not admin_session:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="管理员认证失败,请重新登录",
        )
    admin_result = await db.execute(
        select(models.AdminUser).where(models.AdminUser.id == admin_session.admin_id)
    )
    admin = admin_result.scalar_one_or_none()
    if not admin:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="管理员不存在")
    if not admin.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="管理员账户已被禁用")
    return admin


logger = logging.getLogger(__name__)

admin_task_expert_router = APIRouter(prefix="/api/admin", tags=["admin-task-experts"])


# ==================== 服务列表(跨团队) ====================

@admin_task_expert_router.get("/task-expert-services")
async def get_all_expert_services_admin(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    expert_id: Optional[str] = Query(None, description="按团队 ID 筛选"),
    status_filter: Optional[str] = Query(
        None, description="按状态筛选: active / deleted / inactive"
    ),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
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


# ==================== 活动列表(跨团队) ====================

@admin_task_expert_router.get("/task-expert-activities")
async def get_all_expert_activities_admin(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    expert_id: Optional[str] = Query(None, description="按团队 ID 筛选"),
    status_filter: Optional[str] = Query(None, description="按状态筛选"),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
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


# ==================== 服务下架/恢复 ====================

@admin_task_expert_router.post("/task-expert-services/{service_id}/review")
async def review_expert_service(
    service_id: int,
    review_data: dict,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
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


# ==================== 活动下架/恢复 ====================

@admin_task_expert_router.post("/task-expert-activities/{activity_id}/review")
async def review_expert_activity(
    activity_id: int,
    review_data: dict,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
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


# ==================== 从已批准的申请创建 FeaturedExpertV2 ====================

@admin_task_expert_router.post("/task-expert-applications/{application_id}/create-featured-expert")
async def create_featured_expert_from_application(
    application_id: int,
    expert_id: Optional[str] = Query(
        None, description="可选: 显式指定团队 ID(申请人在多团队时必填)"
    ),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """根据已批准的 ExpertApplication 把对应 Expert 团队设为 Featured。

    流程:
      1) 查 ExpertApplication 必须是 approved
      2) 解析对应 Expert 团队:
         - 若传 ?expert_id=... 直接用
         - 否则按 application.user_id + role='owner' 查 ExpertMember,
           恰好 1 个时使用,多个时 422 提示要传 expert_id
      3) 写 FeaturedExpertV2
    """
    from app.models_expert import ExpertMember

    app_result = await db.execute(
        select(ExpertApplication).where(ExpertApplication.id == application_id)
    )
    application = app_result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")
    if application.status != "approved":
        raise HTTPException(status_code=400, detail="只能为已批准的申请创建特色团队")

    resolved_expert_id = expert_id
    if not resolved_expert_id:
        owner_rows = await db.execute(
            select(ExpertMember.expert_id).where(
                and_(
                    ExpertMember.user_id == application.user_id,
                    ExpertMember.role == "owner",
                    ExpertMember.status == "active",
                )
            )
        )
        owned_team_ids = [r[0] for r in owner_rows.all()]
        if not owned_team_ids:
            raise HTTPException(
                status_code=400,
                detail="未找到该申请人对应的 Expert 团队 (可能 review 流程异常,请联系开发)",
            )
        if len(owned_team_ids) > 1:
            raise HTTPException(
                status_code=422,
                detail={
                    "error_code": "ambiguous_expert_team",
                    "message": "申请人为多个团队的 owner,请通过 ?expert_id= 显式指定",
                    "candidates": owned_team_ids,
                },
            )
        resolved_expert_id = owned_team_ids[0]

    expert = (
        await db.execute(select(Expert).where(Expert.id == resolved_expert_id))
    ).scalar_one_or_none()
    if not expert:
        raise HTTPException(status_code=404, detail="对应的 Expert 团队不存在")

    # 检查是否已是 featured
    existing = await db.execute(
        select(FeaturedExpertV2).where(FeaturedExpertV2.expert_id == resolved_expert_id)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="该团队已是特色团队")

    try:
        new_featured = FeaturedExpertV2(
            expert_id=resolved_expert_id,
            is_featured=True,
            display_order=0,
            created_by=current_admin.id,
        )
        db.add(new_featured)
        await db.commit()
        await db.refresh(new_featured)
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=409, detail="该团队已是特色团队 (并发冲突)")

    logger.info(
        f"管理员 {current_admin.id} 通过申请 {application_id} 把团队 {resolved_expert_id} 设为特色"
    )

    return {
        "message": "特色团队创建成功",
        "expert_id": resolved_expert_id,
        "featured_id": new_featured.id,
    }
