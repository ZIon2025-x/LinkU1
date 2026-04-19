"""公开服务路由 — Phase B1 收口

历史:
  原 task_expert_routes.py 下有 5 个 buyer 端会调用的端点:
    GET  /api/task-experts/services/{service_id}
    GET  /api/task-experts/services/{service_id}/applications
    POST /api/task-experts/services/{service_id}/applications/{application_id}/reply
    GET  /api/task-experts/services/{service_id}/reviews
    GET  /api/task-experts/{expert_id}/reviews
  其中 reply 端点 ownership check 用 `service.expert_id == user_id`，那是 legacy
  TaskExpert 模型的字段（user_id 语义），新 Expert 团队 (8字符 ID) 完全不会命中。
  并且 Flutter 实际调的是 `/api/experts/{id}/reviews`，这个 URL 在 legacy 文件里
  并不存在，等于一直 404。

修复:
  本文件提供同样的语义，但路由迁到 `/api/services/...` 和 `/api/experts/{id}/reviews`，
  ownership 通过 ExpertMember (新团队成员关系) 解析，对新旧团队都正确工作。
  Flutter `api_endpoints.dart` 切到本文件的新 URL。
"""

import json as _json
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import and_, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app import models, schemas
from app.async_routers import (
    get_current_user_optional,
    get_current_user_secure_async_csrf,
)
from app.deps import get_async_db_dependency
from app.models_expert import ExpertMember
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

service_public_router = APIRouter(tags=["service-public"])


# ==================== ownership helper ====================

async def _is_service_owner(
    db: AsyncSession,
    service: models.TaskExpertService,
    user_id: Optional[str],
) -> bool:
    """判断 user_id 是否能"代表"该服务行使所有者权限。

    覆盖三种 service 形态:
      1. 个人服务 (owner_type='user' 或 service_type='personal'):
         service.owner_id 或 service.user_id == user_id
      2. 新达人团队服务 (owner_type='expert', owner_id=experts.id 8 字符):
         user 是该团队的 active owner/admin (ExpertMember)
      3. legacy 单人达人服务 (service.expert_id == user_id, 旧 user_id 语义):
         向后兼容,如果 service.expert_id == user_id 也算所有者
    """
    if not user_id:
        return False

    # case 1: 个人服务
    if service.owner_type == "user" and service.owner_id == user_id:
        return True
    if service.service_type == "personal" and service.user_id == user_id:
        return True

    # case 2: 新达人团队
    if service.owner_type == "expert" and service.owner_id:
        result = await db.execute(
            select(ExpertMember).where(
                and_(
                    ExpertMember.expert_id == service.owner_id,
                    ExpertMember.user_id == user_id,
                    ExpertMember.status == "active",
                    ExpertMember.role.in_(["owner", "admin"]),
                )
            )
        )
        if result.scalar_one_or_none() is not None:
            return True

    # case 3: legacy 兼容
    if service.service_type == "expert" and service.expert_id == user_id:
        return True

    return False


# ==================== GET /api/services/{service_id} ====================

@service_public_router.get(
    "/api/services/{service_id}",
    response_model=schemas.TaskExpertServiceOut,
)
async def get_service_detail(
    service_id: int,
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取服务详情 (公开 + 可选认证拿 user_application_*)。"""
    result = await db.execute(
        select(models.TaskExpertService).where(
            and_(
                models.TaskExpertService.id == service_id,
                models.TaskExpertService.status == "active",
            )
        )
    )
    service = result.scalar_one_or_none()
    if not service:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="服务不存在或未上架"
        )

    # 浏览次数 — 优先 Redis 计数, 退化到 DB
    try:
        from app.redis_cache import get_redis_client
        rc = get_redis_client()
        if rc:
            rk = f"service:view_count:{service_id}"
            rc.incr(rk)
            rc.expire(rk, 7 * 24 * 3600)
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

    # 用户的服务申请信息 (登录用户)
    user_application_id = None
    user_application_status = None
    user_task_id = None
    user_task_status = None
    user_task_is_paid = None
    user_application_has_negotiation = None

    if current_user:
        app_result = await db.execute(
            select(models.ServiceApplication)
            .where(
                and_(
                    models.ServiceApplication.service_id == service_id,
                    models.ServiceApplication.applicant_id == current_user.id,
                )
            )
            .order_by(models.ServiceApplication.created_at.desc())
            .limit(1)
        )
        application = app_result.scalars().first()
        if application:
            user_application_id = application.id
            user_application_status = application.status
            user_application_has_negotiation = (
                application.negotiated_price is not None
            )
            if application.task_id:
                task = await db.get(models.Task, application.task_id)
                if task:
                    user_task_id = task.id
                    user_task_status = task.status
                    user_task_is_paid = bool(task.is_paid)

    service_out = schemas.TaskExpertServiceOut.from_orm(service)
    service_out.user_application_id = user_application_id
    service_out.user_application_status = user_application_status
    service_out.user_task_id = user_task_id
    service_out.user_task_status = user_task_status
    service_out.user_task_is_paid = user_task_is_paid
    service_out.user_application_has_negotiation = user_application_has_negotiation

    # 关联服务摘要（multi 套餐展示 "适用于 XX" 用）
    if service.linked_service_id is not None:
        linked_row = (await db.execute(
            select(
                models.TaskExpertService.id,
                models.TaskExpertService.service_name,
                models.TaskExpertService.service_name_en,
                models.TaskExpertService.service_name_zh,
                models.TaskExpertService.images,
                models.TaskExpertService.base_price,
                models.TaskExpertService.currency,
                models.TaskExpertService.status,
            ).where(models.TaskExpertService.id == service.linked_service_id)
        )).first()
        if linked_row is not None:
            first_image = (
                linked_row.images[0]
                if isinstance(linked_row.images, list) and linked_row.images
                else None
            )
            service_out.linked_service_summary = {
                "id": linked_row.id,
                "service_name": linked_row.service_name,
                "service_name_en": linked_row.service_name_en,
                "service_name_zh": linked_row.service_name_zh,
                "image": first_image,
                "base_price": float(linked_row.base_price) if linked_row.base_price is not None else None,
                "currency": linked_row.currency,
                "status": linked_row.status,
            }

    # owner 信息: 个人服务显示用户; 团队服务显示团队
    if service.owner_type == "user" and service.owner_id:
        from app import async_crud
        owner = await async_crud.async_user_crud.get_user_by_id(db, service.owner_id)
        if owner:
            service_out.owner_name = owner.name
            service_out.owner_avatar = owner.avatar
            service_out.owner_rating = owner.avg_rating
    elif service.owner_type == "expert" and service.owner_id:
        from app.models_expert import Expert
        expert_obj = await db.get(Expert, service.owner_id)
        if expert_obj:
            service_out.owner_name = expert_obj.name
            service_out.owner_avatar = expert_obj.avatar
            service_out.owner_rating = float(expert_obj.rating) if expert_obj.rating else 0.0

    return service_out


# ==================== GET /api/services/{service_id}/applications ====================

@service_public_router.get("/api/services/{service_id}/applications")
async def get_service_applications(
    service_id: int,
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
):
    """获取服务的申请列表 (公开留言)。

    三种调用者:
      1. 服务所有者 → 完整数据 (含 applicant_id + 私密字段)
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
    is_owner = await _is_service_owner(db, service, user_id)

    query = (
        select(models.ServiceApplication)
        .where(
            and_(
                models.ServiceApplication.service_id == service_id,
                models.ServiceApplication.status.in_(
                    ["pending", "negotiating", "price_agreed", "approved"]
                ),
            )
        )
        .order_by(models.ServiceApplication.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    result = await db.execute(query)
    applications = result.scalars().all()

    applicant_ids = list({app.applicant_id for app in applications})
    applicants_map: dict = {}
    if applicant_ids:
        users_result = await db.execute(
            select(models.User).where(models.User.id.in_(applicant_ids))
        )
        for u in users_result.scalars().all():
            applicants_map[u.id] = u

    items = []
    for app in applications:
        applicant = applicants_map.get(app.applicant_id)
        item: dict = {
            "id": app.id,
            "applicant_name": applicant.name if applicant else "Unknown",
            "applicant_avatar": applicant.avatar if applicant else None,
            "applicant_user_level": getattr(applicant, "user_level", None) if applicant else None,
            "currency": app.currency or "GBP",
            "status": app.status,
            "created_at": app.created_at.isoformat() if app.created_at else None,
            "owner_reply": app.owner_reply,
            "owner_reply_at": app.owner_reply_at.isoformat() if app.owner_reply_at else None,
        }
        if is_owner or (user_id and str(app.applicant_id) == user_id):
            item["application_message"] = app.application_message
            item["negotiated_price"] = (
                float(app.negotiated_price) if app.negotiated_price else None
            )
        if is_owner or (user_id and app.applicant_id == user_id):
            item["applicant_id"] = app.applicant_id
        items.append(item)

    return items


# ==================== POST /api/services/{service_id}/applications/{id}/reply ====================

@service_public_router.post(
    "/api/services/{service_id}/applications/{application_id}/reply"
)
async def reply_to_service_application(
    service_id: int,
    application_id: int,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """服务所有者对申请的公开回复 (每个申请只能回复一次)。

    与 legacy task_expert_routes.reply_to_service_application 的关键差异:
      - ownership check 通过 _is_service_owner 走 ExpertMember,
        新 Expert 团队的 owner/admin 都能回复 (legacy 只让 service.expert_id==user_id 通过)
    """
    body = await request.json()
    message = (body.get("message") or "").strip()
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
    if not await _is_service_owner(db, service, user_id):
        raise HTTPException(status_code=403, detail="只有服务所有者可以回复")

    app_result = await db.execute(
        select(models.ServiceApplication).where(
            and_(
                models.ServiceApplication.id == application_id,
                models.ServiceApplication.service_id == service_id,
            )
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

    # 通知申请人 (best-effort)
    try:
        notification_content = _json.dumps({
            "service_id": service_id,
            "service_name": service.service_name,
            "reply_message": message[:200],
            "owner_name": current_user.name or None,
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
        "owner_reply_at": application.owner_reply_at.isoformat()
            if application.owner_reply_at else None,
    }


# ==================== GET /api/services/{service_id}/reviews ====================

@service_public_router.get("/api/services/{service_id}/reviews")
async def get_service_reviews(
    service_id: int,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取服务获得的评价 (公开,不含评价人私人信息)。"""
    service = await db.get(models.TaskExpertService, service_id)
    if not service:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="服务不存在"
        )

    base_where = and_(
        models.Task.created_by_expert == True,  # noqa: E712
        models.Task.expert_service_id == service_id,
        models.Task.status == "completed",
        models.Review.is_anonymous == 0,
        models.Review.is_deleted.is_(False),
    )

    count_query = (
        select(func.count(models.Review.id))
        .select_from(models.Review)
        .join(models.Task, models.Review.task_id == models.Task.id)
        .where(base_where)
    )
    total = (await db.execute(count_query)).scalar() or 0

    list_query = (
        select(models.Review)
        .join(models.Task, models.Review.task_id == models.Task.id)
        .where(base_where)
        .order_by(models.Review.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    reviews = (await db.execute(list_query)).scalars().all()

    return {
        "total": total,
        "items": [
            schemas.ReviewPublicOut(
                id=r.id,
                task_id=r.task_id,
                rating=r.rating,
                comment=r.comment,
                created_at=r.created_at,
                reply_content=r.reply_content,
                reply_at=r.reply_at,
            )
            for r in reviews
        ],
        "limit": limit,
        "offset": offset,
        "has_more": (offset + limit) < total,
    }


# ==================== GET /api/experts/{expert_id}/reviews ====================
#
# Flutter `taskExpertReviews(id)` 长期指向这个 URL, 但 expert_routes.py 没有
# 这个 handler, 等于一直 404。这次补上。

@service_public_router.get("/api/experts/{expert_id}/reviews")
async def get_expert_reviews(
    expert_id: str,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取达人团队收到的评价 (公开,不含评价人私人信息)。

    新模型: 通过 Review.expert_id 直接查 (Phase 2/3 已 backfill,
    见 migration 183_backfill_review_expert_id_and_rating.sql)。
    Legacy 兼容: 同时按 task.expert_creator_id == expert_id 兜底,
    覆盖历史 task 但 review.expert_id 还没 backfill 的边缘情况。
    """
    base_where = and_(
        models.Task.status == "completed",
        models.Review.is_anonymous == 0,
        models.Review.is_deleted.is_(False),
        (
            (models.Review.expert_id == expert_id)
            | (
                (models.Task.expert_creator_id == expert_id)
                & (models.Task.created_by_expert == True)  # noqa: E712
            )
        ),
    )

    count_query = (
        select(func.count(models.Review.id))
        .select_from(models.Review)
        .join(models.Task, models.Review.task_id == models.Task.id)
        .where(base_where)
    )
    total = (await db.execute(count_query)).scalar() or 0

    list_query = (
        select(models.Review)
        .join(models.Task, models.Review.task_id == models.Task.id)
        .where(base_where)
        .order_by(models.Review.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    reviews = (await db.execute(list_query)).scalars().all()

    return {
        "total": total,
        "items": [
            schemas.ReviewPublicOut(
                id=r.id,
                task_id=r.task_id,
                rating=r.rating,
                comment=r.comment,
                created_at=r.created_at,
                reply_content=r.reply_content,
                reply_at=r.reply_at,
            )
            for r in reviews
        ],
        "limit": limit,
        "offset": offset,
        "has_more": (offset + limit) < total,
    }
