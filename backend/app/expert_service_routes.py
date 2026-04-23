"""达人团队服务管理路由"""
import logging
from typing import Any, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app import models, schemas
from app.deps import get_async_db_dependency
from app.async_routers import (
    get_current_user_secure_async_csrf,
    get_current_user_optional,
)
from app.models_expert import Expert, ExpertMember
from app.expert_routes import _get_expert_or_404, _get_member_or_403
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

expert_service_router = APIRouter(
    prefix="/api/experts/{expert_id}/services",
    tags=["expert-services"],
)


async def _validate_bundle_service_ids(
    db: AsyncSession,
    expert_id: str,
    bundle_service_ids: Optional[List[Any]],
    exclude_service_id: Optional[int] = None,
) -> None:
    """运行时校验 bundle 套餐引用的服务都存在,且同属当前团队、不是 deleted/bundle 自身。

    bundle_service_ids 接受双格式:
      - [A, B, C]                                legacy "each once"
      - [{"service_id": A, "count": N}, ...]     explicit count per service
    """
    if not bundle_service_ids:
        return
    # 归一化为纯 service_id 列表 (忽略 count,count 由 schema validator 校验)
    raw_ids: List[int] = []
    for item in bundle_service_ids:
        if isinstance(item, int):
            raw_ids.append(item)
        elif isinstance(item, dict):
            sid = item.get("service_id")
            if isinstance(sid, int):
                raw_ids.append(sid)
            else:
                raise HTTPException(status_code=422, detail={
                    "error_code": "expert_bundle_invalid",
                    "message": "bundle_service_ids 的 service_id 必须是 int",
                })
        else:
            raise HTTPException(status_code=422, detail={
                "error_code": "expert_bundle_invalid",
                "message": "bundle_service_ids 项必须是 int 或 {service_id, count}",
            })
    # 去重
    ids = list(set(raw_ids))
    rows = await db.execute(
        select(models.TaskExpertService.id, models.TaskExpertService.status, models.TaskExpertService.package_type)
        .where(
            and_(
                models.TaskExpertService.id.in_(ids),
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == expert_id,
            )
        )
    )
    found = {row.id: (row.status, row.package_type) for row in rows.all()}
    missing = [i for i in ids if i not in found]
    if missing:
        raise HTTPException(status_code=422, detail={
            "error_code": "bundle_service_not_found",
            "message": f"引用的服务不存在或不属于本团队: {missing}",
        })
    bad_status = [i for i, (s, _) in found.items() if s == "deleted"]
    if bad_status:
        raise HTTPException(status_code=422, detail={
            "error_code": "bundle_service_deleted",
            "message": f"引用的服务已被删除: {bad_status}",
        })
    bad_type = [i for i, (_, pt) in found.items() if pt == "bundle"]
    if bad_type:
        raise HTTPException(status_code=422, detail={
            "error_code": "bundle_nested",
            "message": f"bundle 套餐不能嵌套引用其他 bundle: {bad_type}",
        })
    if exclude_service_id and exclude_service_id in ids:
        raise HTTPException(status_code=422, detail={
            "error_code": "bundle_self_reference",
            "message": "bundle 不能引用自身",
        })


async def _validate_linked_service_id(
    db: AsyncSession,
    expert_id: str,
    linked_service_id: Optional[int],
    exclude_service_id: Optional[int] = None,
) -> None:
    """multi 套餐的 linked_service_id 必须:
    - 存在且同属当前团队 (owner_type='expert' + owner_id=expert_id)
    - 状态非 deleted
    - package_type IS NULL (不能关联其他套餐)
    - 不能是自身
    """
    if linked_service_id is None:
        return
    if exclude_service_id is not None and linked_service_id == exclude_service_id:
        raise HTTPException(status_code=422, detail={
            "error_code": "linked_service_self",
            "message": "multi 套餐不能关联自身",
        })
    row = (await db.execute(
        select(models.TaskExpertService.id, models.TaskExpertService.status, models.TaskExpertService.package_type)
        .where(
            and_(
                models.TaskExpertService.id == linked_service_id,
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == expert_id,
            )
        )
    )).first()
    if row is None:
        raise HTTPException(status_code=422, detail={
            "error_code": "linked_service_not_found",
            "message": f"关联的服务不存在或不属于本团队: {linked_service_id}",
        })
    if row.status == "deleted":
        raise HTTPException(status_code=422, detail={
            "error_code": "linked_service_deleted",
            "message": "关联的服务已删除",
        })
    if row.package_type is not None:
        raise HTTPException(status_code=422, detail={
            "error_code": "linked_service_is_package",
            "message": "只能关联非套餐的单次服务",
        })


async def _fetch_linked_service_summary(
    db: AsyncSession,
    linked_service_id: Optional[int],
) -> Optional[dict]:
    """拉取被关联服务的简要信息供响应附带（name/image/base_price）"""
    if linked_service_id is None:
        return None
    row = (await db.execute(
        select(
            models.TaskExpertService.id,
            models.TaskExpertService.service_name,
            models.TaskExpertService.service_name_en,
            models.TaskExpertService.service_name_zh,
            models.TaskExpertService.images,
            models.TaskExpertService.base_price,
            models.TaskExpertService.currency,
            models.TaskExpertService.status,
        )
        .where(models.TaskExpertService.id == linked_service_id)
    )).first()
    if row is None:
        return None
    first_image = row.images[0] if isinstance(row.images, list) and row.images else None
    return {
        "id": row.id,
        "service_name": row.service_name,
        "service_name_en": row.service_name_en,
        "service_name_zh": row.service_name_zh,
        "image": first_image,
        "base_price": float(row.base_price) if row.base_price is not None else None,
        "currency": row.currency,
        "status": row.status,
    }


@expert_service_router.get("", response_model=List[dict])
async def list_expert_services(
    expert_id: str,
    request: Request,
    status_filter: Optional[str] = Query(None, alias="status"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
):
    """获取达人团队的服务列表（公开）"""
    await _get_expert_or_404(db, expert_id)

    query = select(models.TaskExpertService).where(
        and_(
            models.TaskExpertService.owner_type == "expert",
            models.TaskExpertService.owner_id == expert_id,
        )
    )
    # 只有团队 Owner/Admin 可以看到非 active 服务
    is_team_manager = False
    if current_user:
        from app.models_expert import ExpertMember
        mgr_check = await db.execute(
            select(ExpertMember).where(
                and_(
                    ExpertMember.expert_id == expert_id,
                    ExpertMember.user_id == current_user.id,
                    ExpertMember.status == "active",
                    ExpertMember.role.in_(["owner", "admin"]),
                )
            )
        )
        is_team_manager = mgr_check.scalar_one_or_none() is not None

    if is_team_manager:
        if status_filter:
            query = query.where(models.TaskExpertService.status == status_filter)
        # manager 无 filter 时看全部
    else:
        query = query.where(models.TaskExpertService.status == "active")

    query = query.order_by(
        models.TaskExpertService.display_order.asc(),
        models.TaskExpertService.created_at.desc(),
    ).offset(offset).limit(limit)

    result = await db.execute(query)
    services = result.scalars().all()

    # Batch resolve display identities (Task 3) — avoid N+1
    from app.services.display_identity import batch_resolve_async
    identities = [
        (s.owner_type or "user", s.owner_id or "")
        for s in services
    ]
    identity_map = await batch_resolve_async(db, identities)

    response = []
    for s in services:
        otype = s.owner_type or "user"
        oid = s.owner_id or ""
        display_name, display_avatar = identity_map.get((otype, oid), ("", None))
        response.append({
            "id": s.id,
            "service_name": s.service_name,
            "service_name_en": s.service_name_en,
            "service_name_zh": s.service_name_zh,
            # Flutter 端用 name/name_zh/name_en 读取，加别名兼容
            "name": s.service_name,
            "name_en": s.service_name_en,
            "name_zh": s.service_name_zh,
            "description": s.description,
            "description_en": s.description_en,
            "description_zh": s.description_zh,
            "base_price": float(s.base_price) if s.base_price else 0,
            # 套餐价: 前端需要区分 base_price (单次) 和 package_price (整套)
            "package_price": float(s.package_price) if s.package_price else None,
            "price": float(s.package_price or s.base_price) if (s.package_price or s.base_price) else 0,
            "currency": s.currency,
            "pricing_type": s.pricing_type,
            "location_type": s.location_type,
            "location": s.location,
            "category": s.category,
            "images": s.images,
            "skills": s.skills,
            "status": s.status,
            "has_time_slots": s.has_time_slots,
            "package_type": s.package_type,
            "total_sessions": s.total_sessions,
            "bundle_service_ids": s.bundle_service_ids,
            "linked_service_id": s.linked_service_id,
            "validity_days": s.validity_days,
            "service_radius_km": s.service_radius_km,
            "view_count": s.view_count or 0,
            "application_count": s.application_count or 0,
            "created_at": s.created_at.isoformat() if s.created_at else None,
            "owner_type": otype,
            "owner_id": s.owner_id,
            "display_name": display_name,
            "display_avatar": display_avatar,
        })
    return response


@expert_service_router.post("", status_code=201)
async def create_expert_service(
    expert_id: str,
    body: schemas.TaskExpertServiceCreate,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """创建达人服务（Owner/Admin，无需审核）"""
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    if not expert.stripe_onboarding_complete:
        raise HTTPException(status_code=409, detail={
            "error_code": "expert_stripe_not_ready",
            "message": "Team must complete Stripe onboarding before publishing services",
        })

    if (body.currency or 'GBP').upper() != 'GBP':
        raise HTTPException(status_code=422, detail={
            "error_code": "expert_currency_unsupported",
            "message": "Team services only support GBP currently",
        })

    # bundle 套餐: 校验引用的服务存在且同属
    if body.package_type == "bundle":
        await _validate_bundle_service_ids(db, expert_id, body.bundle_service_ids)

    # multi 套餐: 校验 linked_service_id（若有）同属 + 是单次服务
    linked_service_row = None
    if body.package_type == "multi" and body.linked_service_id is not None:
        await _validate_linked_service_id(db, expert_id, body.linked_service_id)
        # 拉取完整行，用于继承冗余字段
        linked_service_row = (await db.execute(
            select(models.TaskExpertService).where(
                models.TaskExpertService.id == body.linked_service_id
            )
        )).scalar_one_or_none()

    data = body.model_dump(exclude_unset=True)

    # multi + linked_service_id: 从关联服务继承所有冗余字段（snapshot，不是动态引用）
    # 仅填充 data 中缺失的字段，不覆盖卖家显式提供的值（如套餐名可自定义）
    if linked_service_row is not None:
        inheritable_fields = [
            "description", "description_en", "description_zh",
            "category", "images", "skills",
            "location_type", "location", "latitude", "longitude",
            "service_radius_km",
            "currency", "pricing_type",
            "has_time_slots", "time_slot_duration_minutes",
            "time_slot_start_time", "time_slot_end_time",
            "participants_per_slot", "weekly_time_slot_config",
            "base_price",
        ]
        for field in inheritable_fields:
            if field not in data or data.get(field) is None:
                inherited_value = getattr(linked_service_row, field, None)
                if inherited_value is not None:
                    data[field] = inherited_value

    service = models.TaskExpertService(
        owner_type="expert",
        owner_id=expert_id,
        expert_id=None,
        service_type="expert",
        user_id=None,
        status="active",
        **data,
    )
    # Null out service_radius_km for online services
    if service.location_type == "online":
        service.service_radius_km = None

    db.add(service)
    expert.total_services = (expert.total_services or 0) + 1
    expert.updated_at = get_utc_time()
    await db.commit()
    await db.refresh(service)
    return {"id": service.id, "status": service.status}


# ==================== 团队任务列表 ====================
# NOTE: 必须在 /{service_id} 之前注册,否则 "my-tasks" 会被当作 service_id 解析为 int 导致 422


def _task_to_dict(task, poster, *, joined_at) -> dict:
    return {
        "id": task.id,
        "title": task.title,
        "status": task.status,
        "task_source": task.task_source,
        "poster_id": task.poster_id,
        "poster_name": getattr(poster, "name", None) if poster else None,
        "poster_avatar": getattr(poster, "avatar", None) if poster else None,
        "reward": float(task.reward) if task.reward else None,
        "currency": task.currency,
        "created_at": task.created_at.isoformat() if task.created_at else None,
        "accepted_at": task.accepted_at.isoformat() if task.accepted_at else None,
        "joined_at": joined_at.isoformat() if joined_at else None,
    }


@expert_service_router.get("/my-tasks")
async def get_expert_my_tasks(
    expert_id: str,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """团队成员查看自己参与的任务列表。

    - Owner: 看到该团队所有任务 (taker_expert_id = expert_id)
    - Admin/Member: 只看到自己在 chat_participants 里的任务
    """
    from sqlalchemy import func
    from app.models_expert import ExpertMember, ChatParticipant

    # 权限: 活跃成员
    member_result = await db.execute(
        select(ExpertMember).where(
            and_(
                ExpertMember.expert_id == expert_id,
                ExpertMember.user_id == current_user.id,
                ExpertMember.status == "active",
            )
        )
    )
    member = member_result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=403, detail="不是该团队的活跃成员")

    excluded_statuses = ("deleted", "cancelled")

    if member.role == "owner":
        # Owner 看所有团队任务
        count_q = select(func.count(models.Task.id)).where(
            and_(
                models.Task.taker_expert_id == expert_id,
                models.Task.status.notin_(excluded_statuses),
            )
        )
        total = (await db.execute(count_q)).scalar() or 0

        tasks_q = (
            select(models.Task, models.User)
            .outerjoin(models.User, models.Task.poster_id == models.User.id)
            .where(
                and_(
                    models.Task.taker_expert_id == expert_id,
                    models.Task.status.notin_(excluded_statuses),
                )
            )
            .order_by(func.coalesce(models.Task.accepted_at, models.Task.created_at).desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        rows = (await db.execute(tasks_q)).all()

        items = []
        for task, poster in rows:
            items.append(_task_to_dict(task, poster, joined_at=task.accepted_at or task.created_at))
    else:
        # Admin/Member 只看 chat_participants 里有自己的
        count_q = (
            select(func.count(models.Task.id))
            .join(ChatParticipant, ChatParticipant.task_id == models.Task.id)
            .where(
                and_(
                    ChatParticipant.user_id == current_user.id,
                    models.Task.taker_expert_id == expert_id,
                    models.Task.status.notin_(excluded_statuses),
                )
            )
        )
        total = (await db.execute(count_q)).scalar() or 0

        tasks_q = (
            select(models.Task, models.User, ChatParticipant.joined_at)
            .join(ChatParticipant, ChatParticipant.task_id == models.Task.id)
            .outerjoin(models.User, models.Task.poster_id == models.User.id)
            .where(
                and_(
                    ChatParticipant.user_id == current_user.id,
                    models.Task.taker_expert_id == expert_id,
                    models.Task.status.notin_(excluded_statuses),
                )
            )
            .order_by(ChatParticipant.joined_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        rows = (await db.execute(tasks_q)).all()

        items = []
        for task, poster, joined_at in rows:
            items.append(_task_to_dict(task, poster, joined_at=joined_at))

    return {"items": items, "total": total, "page": page, "page_size": page_size}


@expert_service_router.get("/{service_id}")
async def get_expert_service_detail(
    expert_id: str,
    service_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取服务详情（公开）"""
    result = await db.execute(
        select(models.TaskExpertService).where(
            and_(
                models.TaskExpertService.id == service_id,
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == expert_id,
            )
        )
    )
    service = result.scalar_one_or_none()
    if not service or service.status == "deleted":
        raise HTTPException(status_code=404, detail="服务不存在")

    service.view_count = (service.view_count or 0) + 1
    await db.commit()

    linked_summary = await _fetch_linked_service_summary(db, service.linked_service_id)

    # Resolve display identity (Task 3)
    from app.services.display_identity import resolve_async
    otype = service.owner_type or "user"
    display_name, display_avatar = await resolve_async(db, otype, service.owner_id or "")

    return {
        "id": service.id,
        "service_name": service.service_name,
        "service_name_en": service.service_name_en,
        "service_name_zh": service.service_name_zh,
        "description": service.description,
        "description_en": service.description_en,
        "description_zh": service.description_zh,
        "base_price": float(service.base_price) if service.base_price else 0,
        "currency": service.currency,
        "pricing_type": service.pricing_type,
        "location_type": service.location_type,
        "location": service.location,
        "latitude": float(service.latitude) if service.latitude else None,
        "longitude": float(service.longitude) if service.longitude else None,
        "category": service.category,
        "images": service.images,
        "skills": service.skills,
        "status": service.status,
        "display_order": service.display_order,
        "has_time_slots": service.has_time_slots,
        "time_slot_duration_minutes": service.time_slot_duration_minutes,
        "participants_per_slot": service.participants_per_slot,
        "weekly_time_slot_config": service.weekly_time_slot_config,
        "package_type": service.package_type,
        "total_sessions": service.total_sessions,
        "bundle_service_ids": service.bundle_service_ids,
        "package_price": float(service.package_price) if service.package_price else None,
        "validity_days": service.validity_days,
        "linked_service_id": service.linked_service_id,
        "linked_service_summary": linked_summary,
        "service_radius_km": service.service_radius_km,
        "view_count": service.view_count or 0,
        "application_count": service.application_count or 0,
        "created_at": service.created_at.isoformat() if service.created_at else None,
        "updated_at": service.updated_at.isoformat() if service.updated_at else None,
        "owner_type": otype,
        "owner_id": service.owner_id,
        "display_name": display_name,
        "display_avatar": display_avatar,
    }


@expert_service_router.put("/{service_id}")
async def update_expert_service(
    expert_id: str,
    service_id: int,
    body: schemas.TaskExpertServiceUpdate,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """更新达人服务（Owner/Admin）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    result = await db.execute(
        select(models.TaskExpertService).where(
            and_(
                models.TaskExpertService.id == service_id,
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == expert_id,
            )
        )
    )
    service = result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")

    update_data = body.model_dump(exclude_unset=True)

    # bundle 套餐: 如果新的 package_type 是 bundle 或 bundle_service_ids 被更新,执行校验
    new_package_type = update_data.get("package_type", service.package_type)
    new_bundle_ids = update_data.get("bundle_service_ids", service.bundle_service_ids)
    if new_package_type == "bundle" and ("bundle_service_ids" in update_data or "package_type" in update_data):
        await _validate_bundle_service_ids(
            db, expert_id, new_bundle_ids, exclude_service_id=service_id
        )

    # multi 套餐: linked_service_id 仅 multi 允许；非 multi 时强制 NULL
    if "linked_service_id" in update_data:
        new_linked = update_data["linked_service_id"]
        if new_linked is not None and new_package_type != "multi":
            raise HTTPException(status_code=422, detail={
                "error_code": "linked_service_requires_multi",
                "message": "只有 multi 套餐才能设置 linked_service_id",
            })
        if new_linked is not None:
            await _validate_linked_service_id(
                db, expert_id, new_linked, exclude_service_id=service_id
            )
    # package_type 从 multi 切换为其它类型时，清空历史 linked_service_id 避免脏数据
    if "package_type" in update_data and new_package_type != "multi" and service.linked_service_id is not None:
        service.linked_service_id = None

    for field, value in update_data.items():
        if hasattr(service, field):
            setattr(service, field, value)

    # Null out service_radius_km if location_type changed to online
    if service.location_type == "online":
        service.service_radius_km = None

    # base_price 只允许 bundle 为 NULL;multi/普通单次服务不可清空(会让 webhook/结算崩)
    if service.base_price is None and service.package_type != "bundle":
        raise HTTPException(status_code=422, detail={
            "error_code": "base_price_required_non_bundle",
            "message": "非 bundle 服务必须有 base_price",
        })

    service.updated_at = get_utc_time()
    await db.commit()
    return {"id": service.id, "status": service.status}


@expert_service_router.patch("/{service_id}/status")
async def toggle_expert_service_status(
    expert_id: str,
    service_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """上架/下架团队服务（Owner/Admin）— active ↔ inactive 切换"""
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    result = await db.execute(
        select(models.TaskExpertService).where(
            and_(
                models.TaskExpertService.id == service_id,
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == expert_id,
                models.TaskExpertService.status.in_(["active", "inactive"]),
            )
        )
    )
    service = result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在或已删除")

    if service.status == "active":
        # 下架前检查: 有进行中的活动或申请则拒绝
        from sqlalchemy import func as _func
        active_act_count = (await db.execute(
            select(_func.count(models.Activity.id)).where(
                and_(
                    models.Activity.expert_service_id == service_id,
                    models.Activity.status.in_(["open", "in_progress"]),
                )
            )
        )).scalar() or 0
        if active_act_count > 0:
            raise HTTPException(
                status_code=409,
                detail={
                    "error_code": "service_has_active_activities",
                    "message": f"该服务还有 {active_act_count} 个进行中的活动,请先处理后再下架",
                    "active_activities": active_act_count,
                },
            )
        active_app_count = (await db.execute(
            select(_func.count(models.ServiceApplication.id)).where(
                and_(
                    models.ServiceApplication.service_id == service_id,
                    models.ServiceApplication.status.in_(
                        ["pending", "consulting", "negotiating", "price_agreed", "approved"]
                    ),
                )
            )
        )).scalar() or 0
        if active_app_count > 0:
            raise HTTPException(
                status_code=409,
                detail={
                    "error_code": "service_has_active_applications",
                    "message": f"该服务还有 {active_app_count} 个进行中的申请,请先处理后再下架",
                    "active_applications": active_app_count,
                },
            )
        new_status = "inactive"
        expert.total_services = max((expert.total_services or 1) - 1, 0)
    else:
        new_status = "active"
        expert.total_services = (expert.total_services or 0) + 1

    service.status = new_status
    service.updated_at = get_utc_time()
    expert.updated_at = get_utc_time()
    await db.commit()
    return {
        "id": service.id,
        "status": new_status,
        "message": f"服务已{'上架' if new_status == 'active' else '下架'}",
    }


@expert_service_router.delete("/{service_id}")
async def delete_expert_service(
    expert_id: str,
    service_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """删除达人服务（Owner/Admin）"""
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    result = await db.execute(
        select(models.TaskExpertService).where(
            and_(
                models.TaskExpertService.id == service_id,
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == expert_id,
            )
        )
    )
    service = result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")

    # 软删除: 保留历史 ServiceApplication / Review / Task 关联,
    # 仅把 status 改为 'deleted',下架展示。
    if service.status == "deleted":
        return {"detail": "服务已删除"}

    # A3: Activity.expert_service_id FK 是 RESTRICT — 若有 active 活动引用此服务,
    # 拒绝删除并提示用户先处理。
    from sqlalchemy import func as _func
    active_act_q = select(_func.count(models.Activity.id)).where(
        and_(
            models.Activity.expert_service_id == service_id,
            models.Activity.status.in_(["open", "in_progress"]),
        )
    )
    active_count = (await db.execute(active_act_q)).scalar() or 0
    if active_count > 0:
        raise HTTPException(
            status_code=409,
            detail={
                "error_code": "service_has_active_activities",
                "message": f"该服务还有 {active_count} 个进行中的活动,请先取消或完成后再删除",
                "active_activities": active_count,
            },
        )

    # in-flight ServiceApplication 检查 — 防止 buyer 处于"申请中但服务消失"的状态
    active_app_q = select(_func.count(models.ServiceApplication.id)).where(
        and_(
            models.ServiceApplication.service_id == service_id,
            models.ServiceApplication.status.in_(
                ["pending", "consulting", "negotiating", "price_agreed", "approved"]
            ),
        )
    )
    active_app_count = (await db.execute(active_app_q)).scalar() or 0
    if active_app_count > 0:
        raise HTTPException(
            status_code=409,
            detail={
                "error_code": "service_has_active_applications",
                "message": f"该服务还有 {active_app_count} 个进行中的申请,请先处理后再删除",
                "active_applications": active_app_count,
            },
        )

    was_active = service.status == "active"
    service.status = "deleted"
    service.updated_at = get_utc_time()
    if was_active:
        expert.total_services = max((expert.total_services or 1) - 1, 0)
    expert.updated_at = get_utc_time()
    await db.commit()
    return {"detail": "服务已删除"}


