"""达人服务申请/咨询/协商路由"""
import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import select, and_, func
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

consultation_router = APIRouter(tags=["expert-consultations"])


# ==================== 用户侧：申请/咨询服务 ====================

@consultation_router.post("/api/services/{service_id}/apply")
async def apply_for_service(
    service_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """用户申请服务"""
    # 查找服务
    service_result = await db.execute(
        select(models.TaskExpertService).where(models.TaskExpertService.id == service_id)
    )
    service = service_result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")
    if service.status != "active":
        raise HTTPException(status_code=400, detail="服务未上架")

    # 检查是否已有 pending 申请
    existing = await db.execute(
        select(models.ServiceApplication).where(
            and_(
                models.ServiceApplication.service_id == service_id,
                models.ServiceApplication.applicant_id == current_user.id,
                models.ServiceApplication.status.in_(["pending", "consulting", "negotiating", "price_agreed"]),
            )
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="你已有进行中的申请")

    application = models.ServiceApplication(
        service_id=service_id,
        applicant_id=current_user.id,
        expert_id=None,  # 旧字段，不再使用
        new_expert_id=service.owner_id if service.owner_type == "expert" else None,
        service_owner_id=service.owner_id if service.owner_type == "user" else None,
        application_message=body.get("message"),
        time_slot_id=body.get("time_slot_id"),
        status="pending",
        currency=service.currency or "GBP",
    )
    db.add(application)

    # 更新服务申请计数
    service.application_count = (service.application_count or 0) + 1
    await db.commit()
    await db.refresh(application)

    return {
        "id": application.id,
        "service_id": service_id,
        "status": application.status,
    }


@consultation_router.post("/api/services/{service_id}/consult")
async def create_consultation(
    service_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """用户发起服务咨询"""
    service_result = await db.execute(
        select(models.TaskExpertService).where(models.TaskExpertService.id == service_id)
    )
    service = service_result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")

    application = models.ServiceApplication(
        service_id=service_id,
        applicant_id=current_user.id,
        new_expert_id=service.owner_id if service.owner_type == "expert" else None,
        service_owner_id=service.owner_id if service.owner_type == "user" else None,
        application_message=body.get("message"),
        status="consulting",
        currency=service.currency or "GBP",
    )
    db.add(application)
    await db.commit()
    await db.refresh(application)

    return {"id": application.id, "status": "consulting"}


# ==================== 用户侧：协商/报价 ====================

@consultation_router.post("/api/applications/{application_id}/negotiate")
async def negotiate_price(
    application_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """用户提出议价"""
    app_result = await db.execute(
        select(models.ServiceApplication).where(models.ServiceApplication.id == application_id)
    )
    application = app_result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")
    if application.applicant_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权操作")

    application.negotiated_price = body.get("price")
    application.status = "negotiating"
    application.updated_at = get_utc_time()
    await db.commit()
    return {"status": "negotiating"}


@consultation_router.post("/api/applications/{application_id}/quote")
async def quote_price(
    application_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """达人报价（Owner/Admin）"""
    app_result = await db.execute(
        select(models.ServiceApplication).where(models.ServiceApplication.id == application_id)
    )
    application = app_result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")

    # 检查是否为服务的达人团队成员
    if application.new_expert_id:
        await _get_member_or_403(db, application.new_expert_id, current_user.id, required_roles=["owner", "admin"])
    elif application.service_owner_id == current_user.id:
        pass  # 个人服务 owner
    else:
        raise HTTPException(status_code=403, detail="无权操作")

    application.expert_counter_price = body.get("price")
    application.status = "negotiating"
    application.updated_at = get_utc_time()
    await db.commit()
    return {"status": "negotiating"}


@consultation_router.post("/api/applications/{application_id}/negotiate-response")
async def respond_to_negotiation(
    application_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """回应协商（接受/拒绝/还价）"""
    app_result = await db.execute(
        select(models.ServiceApplication).where(models.ServiceApplication.id == application_id)
    )
    application = app_result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")

    action = body.get("action")  # accept, reject, counter
    if action == "accept":
        application.final_price = application.expert_counter_price or application.negotiated_price
        application.status = "price_agreed"
        application.price_agreed_at = get_utc_time()
    elif action == "reject":
        application.status = "rejected"
        application.rejected_at = get_utc_time()
    elif action == "counter":
        if application.applicant_id == current_user.id:
            application.negotiated_price = body.get("price")
        else:
            application.expert_counter_price = body.get("price")
        application.status = "negotiating"

    application.updated_at = get_utc_time()
    await db.commit()
    return {"status": application.status}


@consultation_router.post("/api/applications/{application_id}/formal-apply")
async def formal_apply(
    application_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """正式申请（咨询转申请）"""
    app_result = await db.execute(
        select(models.ServiceApplication).where(models.ServiceApplication.id == application_id)
    )
    application = app_result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")
    if application.applicant_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权操作")

    application.final_price = body.get("price", application.negotiated_price)
    application.deadline = body.get("deadline")
    application.is_flexible = body.get("is_flexible", 0)
    application.status = "pending"
    application.updated_at = get_utc_time()
    await db.commit()
    return {"status": "pending"}


@consultation_router.post("/api/applications/{application_id}/close")
async def close_consultation(
    application_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """关闭咨询"""
    app_result = await db.execute(
        select(models.ServiceApplication).where(models.ServiceApplication.id == application_id)
    )
    application = app_result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")

    application.status = "cancelled"
    application.updated_at = get_utc_time()
    await db.commit()
    return {"status": "cancelled"}


# ==================== 达人侧：处理申请 ====================

@consultation_router.post("/api/applications/{application_id}/approve")
async def approve_application(
    application_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """达人批准申请（Owner/Admin）"""
    app_result = await db.execute(
        select(models.ServiceApplication).where(models.ServiceApplication.id == application_id)
    )
    application = app_result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")

    # 权限检查
    if application.new_expert_id:
        await _get_member_or_403(db, application.new_expert_id, current_user.id, required_roles=["owner", "admin"])
    elif application.service_owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权操作")

    application.status = "approved"
    application.approved_at = get_utc_time()
    application.updated_at = get_utc_time()
    await db.commit()
    return {"status": "approved"}


@consultation_router.post("/api/applications/{application_id}/reject")
async def reject_application(
    application_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """达人拒绝申请（Owner/Admin）"""
    app_result = await db.execute(
        select(models.ServiceApplication).where(models.ServiceApplication.id == application_id)
    )
    application = app_result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")

    if application.new_expert_id:
        await _get_member_or_403(db, application.new_expert_id, current_user.id, required_roles=["owner", "admin"])
    elif application.service_owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权操作")

    application.status = "rejected"
    application.rejected_at = get_utc_time()
    application.updated_at = get_utc_time()
    await db.commit()
    return {"status": "rejected"}


@consultation_router.post("/api/applications/{application_id}/counter-offer")
async def counter_offer(
    application_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """达人还价（Owner/Admin）"""
    app_result = await db.execute(
        select(models.ServiceApplication).where(models.ServiceApplication.id == application_id)
    )
    application = app_result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")

    if application.new_expert_id:
        await _get_member_or_403(db, application.new_expert_id, current_user.id, required_roles=["owner", "admin"])
    elif application.service_owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权操作")

    application.expert_counter_price = body.get("price")
    application.status = "negotiating"
    application.updated_at = get_utc_time()
    await db.commit()
    return {"status": "negotiating", "counter_price": float(application.expert_counter_price) if application.expert_counter_price else None}


# ==================== 查询类 ====================

@consultation_router.get("/api/applications/{application_id}/status")
async def get_application_status(
    application_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """获取申请状态"""
    app_result = await db.execute(
        select(models.ServiceApplication).where(models.ServiceApplication.id == application_id)
    )
    application = app_result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")

    return {
        "id": application.id,
        "service_id": application.service_id,
        "status": application.status,
        "negotiated_price": float(application.negotiated_price) if application.negotiated_price else None,
        "expert_counter_price": float(application.expert_counter_price) if application.expert_counter_price else None,
        "final_price": float(application.final_price) if application.final_price else None,
        "created_at": application.created_at.isoformat() if application.created_at else None,
    }


@consultation_router.get("/api/experts/{expert_id}/applications")
async def list_expert_applications(
    expert_id: str,
    request: Request,
    status_filter: Optional[str] = Query(None, alias="status"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """获取达人团队收到的服务申请列表（Owner/Admin）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    query = (
        select(
            models.ServiceApplication,
            models.User.name.label("applicant_name"),
            models.TaskExpertService.service_name.label("service_name"),
            models.TaskExpertService.service_name_en.label("service_name_en"),
            models.TaskExpertService.service_name_zh.label("service_name_zh"),
        )
        .join(
            models.User,
            models.User.id == models.ServiceApplication.applicant_id,
        )
        .join(
            models.TaskExpertService,
            models.TaskExpertService.id == models.ServiceApplication.service_id,
        )
        .where(models.ServiceApplication.new_expert_id == expert_id)
    )
    if status_filter:
        query = query.where(models.ServiceApplication.status == status_filter)
    query = query.order_by(models.ServiceApplication.created_at.desc()).offset(offset).limit(limit)

    result = await db.execute(query)
    rows = result.all()
    return [
        {
            "id": row.ServiceApplication.id,
            "service_id": row.ServiceApplication.service_id,
            "service_name": row.service_name,
            "service_name_en": row.service_name_en,
            "service_name_zh": row.service_name_zh,
            "applicant_id": row.ServiceApplication.applicant_id,
            "applicant_name": row.applicant_name,
            "status": row.ServiceApplication.status,
            "application_message": row.ServiceApplication.application_message,
            "negotiated_price": float(row.ServiceApplication.negotiated_price) if row.ServiceApplication.negotiated_price else None,
            "expert_counter_price": float(row.ServiceApplication.expert_counter_price) if row.ServiceApplication.expert_counter_price else None,
            "final_price": float(row.ServiceApplication.final_price) if row.ServiceApplication.final_price else None,
            "currency": row.ServiceApplication.currency or "GBP",
            "task_id": row.ServiceApplication.task_id,
            "created_at": row.ServiceApplication.created_at.isoformat() if row.ServiceApplication.created_at else None,
        }
        for row in rows
    ]


@consultation_router.get("/api/my/service-applications")
async def list_my_service_applications(
    request: Request,
    status_filter: Optional[str] = Query(None, alias="status"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """获取我发出的服务申请列表"""
    query = select(models.ServiceApplication).where(
        models.ServiceApplication.applicant_id == current_user.id
    )
    if status_filter:
        query = query.where(models.ServiceApplication.status == status_filter)
    query = query.order_by(models.ServiceApplication.created_at.desc()).offset(offset).limit(limit)

    result = await db.execute(query)
    apps = result.scalars().all()
    return [
        {
            "id": a.id,
            "service_id": a.service_id,
            "status": a.status,
            "application_message": a.application_message,
            "negotiated_price": float(a.negotiated_price) if a.negotiated_price else None,
            "final_price": float(a.final_price) if a.final_price else None,
            "created_at": a.created_at.isoformat() if a.created_at else None,
        }
        for a in apps
    ]
