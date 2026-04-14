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


# ==================== Helpers ====================

async def _notify_team_admins_new_application(
    db: AsyncSession,
    expert_id: str,
    applicant_name: str,
    service_name: str,
    application_id: int,
    notification_type: str = "service_application_received",
    title_zh: str = "新服务申请",
    title_en: str = "New Service Application",
) -> None:
    """通知团队所有 active owner+admin 收到新的服务申请/咨询。Best-effort,失败不阻塞主流程。"""
    try:
        from app.async_crud import AsyncNotificationCRUD
        managers_result = await db.execute(
            select(ExpertMember.user_id).where(
                and_(
                    ExpertMember.expert_id == expert_id,
                    ExpertMember.status == "active",
                    ExpertMember.role.in_(["owner", "admin"]),
                )
            )
        )
        manager_ids = [r[0] for r in managers_result.all()]
        if not manager_ids:
            return
        content_zh = f"用户「{applicant_name}」对服务「{service_name}」发起了新申请,请前往达人后台处理"
        content_en = f"「{applicant_name}」submitted a new request for service「{service_name}」"
        for mid in manager_ids:
            await AsyncNotificationCRUD.create_notification(
                db=db,
                user_id=mid,
                notification_type=notification_type,
                title=title_zh,
                content=content_zh,
                title_en=title_en,
                content_en=content_en,
                related_id=str(application_id),
                related_type="service_application",
            )
    except Exception as e:
        logger.warning(f"通知团队成员新申请失败: {e}")


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

    # 时间段容量校验: 若指定了 time_slot_id, 检查该 slot 是否还有名额
    # 并发安全: 用 SELECT FOR UPDATE 锁定 slot 行,然后 count + insert,
    # 这样并发请求会串行化,避免超额。
    time_slot_id = body.get("time_slot_id")
    if time_slot_id:
        slot_result = await db.execute(
            select(models.ServiceTimeSlot)
            .where(
                and_(
                    models.ServiceTimeSlot.id == time_slot_id,
                    models.ServiceTimeSlot.service_id == service_id,
                    models.ServiceTimeSlot.is_manually_deleted == False,
                )
            )
            .with_for_update()  # 🔒 锁住 slot 行,后续 count+insert 串行化
        )
        slot = slot_result.scalar_one_or_none()
        if not slot:
            raise HTTPException(status_code=404, detail="时间段不存在或已删除")

        max_cap = slot.max_participants or 1
        active_count_result = await db.execute(
            select(func.count(models.ServiceApplication.id)).where(
                and_(
                    models.ServiceApplication.time_slot_id == time_slot_id,
                    models.ServiceApplication.status.in_(
                        ["pending", "negotiating", "price_agreed", "approved"]
                    ),
                )
            )
        )
        active_count = active_count_result.scalar() or 0
        if active_count >= max_cap:
            raise HTTPException(
                status_code=409,
                detail={
                    "error_code": "time_slot_full",
                    "message": "该时间段已满,请选择其他时间段",
                    "max_participants": max_cap,
                    "current": active_count,
                },
            )

    application = models.ServiceApplication(
        service_id=service_id,
        applicant_id=current_user.id,
        expert_id=None,  # 旧字段，不再使用
        new_expert_id=service.owner_id if service.owner_type == "expert" else None,
        service_owner_id=service.owner_id if service.owner_type == "user" else None,
        application_message=body.get("message"),
        time_slot_id=time_slot_id,
        status="pending",
        currency=service.currency or "GBP",
    )
    db.add(application)

    # 更新服务申请计数 — 用 atomic UPDATE 避免 read-modify-write 竞态
    from sqlalchemy import update
    await db.execute(
        update(models.TaskExpertService)
        .where(models.TaskExpertService.id == service_id)
        .values(application_count=models.TaskExpertService.application_count + 1)
    )
    await db.commit()
    await db.refresh(application)

    # 通知团队 owner+admin 有新申请(团队服务才发,个人服务跳过)
    if service.owner_type == "expert":
        await _notify_team_admins_new_application(
            db,
            expert_id=service.owner_id,
            applicant_name=current_user.name or "用户",
            service_name=service.service_name or "服务",
            application_id=application.id,
            notification_type="service_application_received",
            title_zh="新服务申请",
            title_en="New Service Application",
        )

    return {
        "id": application.id,
        "service_id": service_id,
        "status": application.status,
    }


@consultation_router.post("/api/services/{service_id}/consult")
async def create_consultation(
    service_id: int,
    request: Request,
    body: Optional[dict] = None,
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

    # 检查是否已有进行中的咨询/申请
    existing = await db.execute(
        select(models.ServiceApplication).where(
            and_(
                models.ServiceApplication.service_id == service_id,
                models.ServiceApplication.applicant_id == current_user.id,
                models.ServiceApplication.status.in_(["consulting", "negotiating", "price_agreed", "pending"]),
            )
        )
    )
    existing_app = existing.scalar_one_or_none()
    if existing_app:
        # 已有进行中的咨询/申请，直接返回（幂等）
        return {
            "id": existing_app.id,
            "status": existing_app.status,
            "task_id": existing_app.task_id,
            "application_id": existing_app.id,
        }

    # 创建 consulting 占位 task（供聊天页面使用）
    service_name = service.service_name or "服务咨询"
    consulting_task = models.Task(
        title=service_name,
        description=f"咨询: {service_name}",
        reward=service.base_price or 0,
        base_reward=service.base_price or 0,
        reward_to_be_quoted=True if not service.base_price else False,
        currency=service.currency or "GBP",
        location=service.location or "",
        task_type="expert_service",
        poster_id=current_user.id,
        status="consulting",
        task_level="expert",
    )
    db.add(consulting_task)
    await db.flush()  # 获取 task.id

    application = models.ServiceApplication(
        service_id=service_id,
        applicant_id=current_user.id,
        new_expert_id=service.owner_id if service.owner_type == "expert" else None,
        service_owner_id=service.owner_id if service.owner_type == "user" else None,
        application_message=(body or {}).get("message"),
        status="consulting",
        currency=service.currency or "GBP",
        task_id=consulting_task.id,
    )
    db.add(application)
    await db.commit()
    await db.refresh(application)

    # 通知团队 owner+admin 有新咨询
    if service.owner_type == "expert":
        await _notify_team_admins_new_application(
            db,
            expert_id=service.owner_id,
            applicant_name=current_user.name or "用户",
            service_name=service.service_name or "服务",
            application_id=application.id,
            notification_type="service_consultation_received",
            title_zh="新服务咨询",
            title_en="New Consultation Request",
        )

    return {
        "id": application.id,
        "status": "consulting",
        "task_id": consulting_task.id,
        "application_id": application.id,
    }


@consultation_router.post("/api/experts/{expert_id}/consult")
async def create_team_consultation(
    expert_id: str,
    request: Request,
    body: Optional[dict] = None,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """用户对达人团队发起咨询（不绑定具体服务）"""
    # 校验团队存在且 active
    result = await db.execute(select(Expert).where(Expert.id == expert_id))
    expert = result.scalar_one_or_none()
    if not expert:
        raise HTTPException(status_code=404, detail="达人团队不存在")
    if expert.status != "active":
        raise HTTPException(status_code=400, detail="该团队未在运营中")

    # 不能咨询自己的团队
    member_check = await db.execute(
        select(ExpertMember.id).where(
            and_(
                ExpertMember.expert_id == expert_id,
                ExpertMember.user_id == current_user.id,
                ExpertMember.status == "active",
            )
        ).limit(1)
    )
    if member_check.scalar_one_or_none() is not None:
        raise HTTPException(status_code=400, detail="不能咨询自己所在的团队")

    # 幂等：已有进行中的团队咨询直接返回
    existing = await db.execute(
        select(models.ServiceApplication).where(
            and_(
                models.ServiceApplication.new_expert_id == expert_id,
                models.ServiceApplication.applicant_id == current_user.id,
                models.ServiceApplication.service_id.is_(None),
                models.ServiceApplication.status.in_(["consulting", "negotiating", "price_agreed"]),
            )
        )
    )
    existing_app = existing.scalar_one_or_none()
    if existing_app:
        return {
            "task_id": existing_app.task_id,
            "application_id": existing_app.id,
            "status": existing_app.status,
        }

    # 创建占位 task
    team_name = expert.name or "达人团队"
    consulting_task = models.Task(
        title=f"团队咨询: {team_name}",
        description=f"团队咨询: {team_name}",
        reward=0,
        base_reward=0,
        reward_to_be_quoted=True,
        currency="GBP",
        location="",
        task_type="expert_service",
        poster_id=current_user.id,
        status="consulting",
        task_level="expert",
    )
    db.add(consulting_task)
    await db.flush()

    # 创建 application（service_id=NULL 表示团队咨询）
    application = models.ServiceApplication(
        service_id=None,
        applicant_id=current_user.id,
        new_expert_id=expert_id,
        application_message=(body or {}).get("message"),
        status="consulting",
        currency="GBP",
        task_id=consulting_task.id,
    )
    db.add(application)
    await db.commit()
    await db.refresh(application)

    # 通知团队 owner+admin
    await _notify_team_admins_new_application(
        db,
        expert_id=expert_id,
        applicant_name=current_user.name or "用户",
        service_name=team_name,
        application_id=application.id,
        notification_type="team_consultation_received",
        title_zh="新团队咨询",
        title_en="New Team Consultation",
    )

    return {
        "task_id": consulting_task.id,
        "application_id": application.id,
        "status": "consulting",
    }


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

    try:
        price = float(body.get("price", 0))
    except (TypeError, ValueError):
        raise HTTPException(status_code=400, detail="price 必须为数字")
    if price <= 0:
        raise HTTPException(status_code=400, detail="price 必须大于 0")
    # 团队咨询：议价时必须绑定服务
    service_id = body.get("service_id")
    if application.service_id is None:
        if not service_id:
            raise HTTPException(status_code=400, detail="团队咨询议价必须选择一个服务")
        # 校验服务属于该团队
        svc_result = await db.execute(
            select(models.TaskExpertService).where(
                and_(
                    models.TaskExpertService.id == int(service_id),
                    models.TaskExpertService.owner_type == "expert",
                    models.TaskExpertService.owner_id == application.new_expert_id,
                    models.TaskExpertService.status == "active",
                )
            )
        )
        if not svc_result.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="service_not_found")
        application.service_id = int(service_id)
    application.negotiated_price = price
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

    try:
        price = float(body.get("price", 0))
    except (TypeError, ValueError):
        raise HTTPException(status_code=400, detail="price 必须为数字")
    if price <= 0:
        raise HTTPException(status_code=400, detail="price 必须大于 0")
    # 团队咨询：报价时必须绑定服务
    service_id = body.get("service_id")
    if application.service_id is None:
        if not service_id:
            raise HTTPException(status_code=400, detail="团队咨询报价必须选择一个服务")
        svc_result = await db.execute(
            select(models.TaskExpertService).where(
                and_(
                    models.TaskExpertService.id == int(service_id),
                    models.TaskExpertService.owner_type == "expert",
                    models.TaskExpertService.owner_id == application.new_expert_id,
                    models.TaskExpertService.status == "active",
                )
            )
        )
        if not svc_result.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="service_not_found")
        application.service_id = int(service_id)
    application.expert_counter_price = price
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
    """回应协商(接受/拒绝/还价)。仅申请人或服务提供方可调用。"""
    app_result = await db.execute(
        select(models.ServiceApplication).where(models.ServiceApplication.id == application_id)
    )
    application = app_result.scalar_one_or_none()
    # not-found 也 mask 成 403, 防止匿名用户枚举 application_id 是否存在
    if not application:
        raise HTTPException(status_code=403, detail="无权操作该申请")

    # 权限检查 — 修复 IDOR
    # 解析当前用户身份: 是 applicant 还是 provider
    is_applicant = application.applicant_id == current_user.id
    is_provider = False
    if not is_applicant:
        if application.new_expert_id:
            try:
                await _get_member_or_403(
                    db,
                    application.new_expert_id,
                    current_user.id,
                    required_roles=["owner", "admin"],
                )
                is_provider = True
            except HTTPException:
                pass
        elif application.service_owner_id == current_user.id:
            is_provider = True
    if not is_applicant and not is_provider:
        raise HTTPException(status_code=403, detail="无权操作该申请")

    # 状态校验: 仅 negotiating 状态可回应
    if application.status not in ("negotiating", "pending"):
        raise HTTPException(
            status_code=400,
            detail=f"当前状态({application.status})不允许回应协商",
        )

    action = body.get("action")  # accept, reject, counter
    if action not in ("accept", "reject", "counter"):
        raise HTTPException(status_code=400, detail="action 必须为 accept/reject/counter")

    if action == "accept":
        application.final_price = application.expert_counter_price or application.negotiated_price
        application.status = "price_agreed"
        application.price_agreed_at = get_utc_time()
    elif action == "reject":
        application.status = "rejected"
        application.rejected_at = get_utc_time()
    elif action == "counter":
        # 校验价格
        try:
            price = float(body.get("price", 0))
        except (TypeError, ValueError):
            raise HTTPException(status_code=400, detail="price 必须为数字")
        if price <= 0:
            raise HTTPException(status_code=400, detail="price 必须大于 0")
        # 团队咨询还价时可更换服务
        service_id = body.get("service_id")
        if application.service_id is None and not service_id:
            raise HTTPException(status_code=400, detail="团队咨询还价必须选择一个服务")
        if service_id:
            svc_result = await db.execute(
                select(models.TaskExpertService).where(
                    and_(
                        models.TaskExpertService.id == int(service_id),
                        models.TaskExpertService.owner_type == "expert",
                        models.TaskExpertService.owner_id == application.new_expert_id,
                        models.TaskExpertService.status == "active",
                    )
                )
            )
            if not svc_result.scalar_one_or_none():
                raise HTTPException(status_code=400, detail="service_not_found")
            application.service_id = int(service_id)
        # 按身份区分写哪个字段(不再依赖匿名 fallback)
        if is_applicant:
            application.negotiated_price = price
        else:
            application.expert_counter_price = price
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


async def _check_application_party(
    db: AsyncSession,
    application: "models.ServiceApplication",
    current_user_id: str,
    *,
    allow_applicant: bool = True,
    allow_provider: bool = True,
) -> None:
    """权限检查 helper: 确认 current_user 是 application 的相关方。

    - allow_applicant: 申请人本人可访问
    - allow_provider: 服务提供方(团队 owner/admin 或个人服务 owner)可访问
    """
    if allow_applicant and application.applicant_id == current_user_id:
        return
    if allow_provider:
        if application.new_expert_id:
            try:
                await _get_member_or_403(
                    db,
                    application.new_expert_id,
                    current_user_id,
                    required_roles=["owner", "admin"],
                )
                return
            except HTTPException:
                pass
        elif application.service_owner_id == current_user_id:
            return
    raise HTTPException(status_code=403, detail="无权访问该申请")


@consultation_router.post("/api/applications/{application_id}/close")
async def close_consultation(
    application_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """关闭咨询(申请人或服务提供方均可)"""
    app_result = await db.execute(
        select(models.ServiceApplication).where(models.ServiceApplication.id == application_id)
    )
    application = app_result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")

    # 权限检查 — 修复 IDOR
    await _check_application_party(db, application, current_user.id)

    # 幂等: 已 cancelled 直接返回
    if application.status == "cancelled":
        return {"status": "cancelled"}

    # 仅在 consulting/negotiating/pending/price_agreed 状态可关闭
    # approved/rejected 状态不允许关闭(已有最终结果)
    if application.status not in ("consulting", "negotiating", "pending", "price_agreed"):
        raise HTTPException(status_code=400, detail=f"当前状态({application.status})不允许关闭")

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
    """达人批准申请（Owner/Admin）。

    对于团队服务申请 (`new_expert_id` 非空):
      - 调用 resolve_task_taker_from_service 解析 (taker_id, taker_expert_id)
      - 创建 Task (status='pending_payment')
      - 创建 Stripe PaymentIntent (客户后续支付时使用 client_secret)
      - 关联 application.task_id
      - 通知申请人

    对于历史个人服务路径 (`service_owner_id` 等于 current_user)：
      - 仅更新 status='approved'。Task 创建走 user_service_application_routes
        的 owner-approve 端点，不在此处重复。

    spec §4.2 (修复 plan v3 在 LEGACY 路径上 wire helper 后留下的空洞)。
    """
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

    # 幂等性：已经 approved 且关联了 task → 返回现状，不重复创建
    if application.status == "approved" and application.task_id:
        existing = await db.get(models.Task, application.task_id)
        return {
            "message": "任务已创建",
            "application_id": application_id,
            "task_id": application.task_id,
            "task_status": getattr(existing, "status", None) if existing else None,
            "task": existing,
        }

    # 团队服务路径：创建 Task + PaymentIntent
    if application.new_expert_id:
        return await _approve_team_service_application(
            db=db,
            request=request,
            current_user=current_user,
            application=application,
        )

    # 历史个人服务路径：仅更新状态（Task 创建在 user_service_application_routes）
    application.status = "approved"
    application.approved_at = get_utc_time()
    application.updated_at = get_utc_time()
    await db.commit()
    return {"status": "approved"}


async def _approve_team_service_application(
    *,
    db: AsyncSession,
    request: Request,
    current_user: "models.User",
    application: "models.ServiceApplication",
) -> dict:
    """Create Task + PaymentIntent for a team service application approval.

    Splits the heavy lifting out of approve_application so the request handler
    stays readable. All preconditions (auth, idempotency) have already been
    checked by the caller.

    spec §4.2 — team service Task creation site (filling the gap left by the
    plan v3 reverts).
    """
    from datetime import timedelta
    from app.services.expert_task_resolver import resolve_task_taker_from_service

    # 1. 状态校验：仅允许从 pending / price_agreed 进入 approved
    if application.status not in ("pending", "price_agreed"):
        raise HTTPException(status_code=409, detail="当前状态不允许批准")

    # 2. 加载服务
    service = await db.get(models.TaskExpertService, application.service_id)
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")
    if service.status != "active":
        raise HTTPException(status_code=400, detail="服务未上架，无法创建任务")

    # 3. 解析团队 taker（同时校验 Stripe Connect + GBP 货币）
    taker_id_value, taker_expert_id_value = await resolve_task_taker_from_service(db, service)

    # 4. 加载 expert 以拿到 stripe_account_id（resolver 已校验过 onboarding）
    expert = await db.get(Expert, taker_expert_id_value)
    if not expert or not expert.stripe_account_id:
        raise HTTPException(status_code=500, detail={
            "error_code": "team_no_stripe_account",
            "message": "Team has no Stripe Connect account configured",
        })

    # 5. 决定最终价格（与 user_service_application_routes 保持一致的回退逻辑）
    if application.status == "price_agreed" and application.expert_counter_price is not None:
        price = float(application.expert_counter_price)
    elif application.final_price is not None:
        price = float(application.final_price)
    elif application.negotiated_price is not None:
        price = float(application.negotiated_price)
    else:
        price = float(service.base_price)

    # 6. 决定截止日期
    if application.is_flexible == 1:
        task_deadline = None
    elif application.deadline:
        task_deadline = application.deadline
    else:
        task_deadline = get_utc_time() + timedelta(days=7)

    # 7. 加载申请人（用于通知 + PaymentIntent metadata）
    applicant_user = await db.get(models.User, application.applicant_id)
    if not applicant_user:
        raise HTTPException(status_code=404, detail="申请用户不存在")

    # 8. 处理图片
    import json as _json
    images_json = None
    if service.images:
        if isinstance(service.images, list):
            images_json = _json.dumps(service.images) if service.images else None
        elif isinstance(service.images, str):
            images_json = service.images

    # 9. 位置归一化
    location = service.location or "线上"
    if isinstance(location, str) and location.lower() in ("online", "线上"):
        location = "线上"

    # 10. 创建 Task —— 关键:taker_expert_id 必须填团队 id
    new_task = models.Task(
        title=service.service_name,
        description=service.description or f"团队服务: {service.service_name}",
        deadline=task_deadline,
        is_flexible=application.is_flexible or 0,
        reward=price,
        base_reward=service.base_price,
        agreed_reward=price,
        currency=application.currency or service.currency or "GBP",
        location=location,
        task_type=service.category or "其他",
        task_level="expert",
        poster_id=application.applicant_id,
        taker_id=taker_id_value,                  # 团队 owner 的 user_id
        taker_expert_id=taker_expert_id_value,    # 🎯 团队 id —— 核心修复
        expert_service_id=service.id,
        status="pending_payment",
        is_paid=0,
        payment_expires_at=get_utc_time() + timedelta(minutes=30),
        images=images_json,
        accepted_at=get_utc_time(),
        task_source="expert_service",
    )
    db.add(new_task)
    await db.flush()  # allocate new_task.id

    # 11. 创建 PaymentIntent（destination 走平台账户，后续 payment_transfer_service
    #     会按 task.taker_expert_id 把钱转到团队的 Stripe Connect 账户）
    import stripe
    from app.utils.fee_calculator import calculate_application_fee_pence
    task_amount_pence = int(round(price * 100))
    application_fee_pence = calculate_application_fee_pence(
        task_amount_pence, task_source="expert_service", task_type=None
    )

    try:
        currency_lower = (getattr(new_task, "currency", None) or "GBP").lower()
        try:
            from app.routers import _payment_method_types_for_currency
            pm_types = _payment_method_types_for_currency(currency_lower)
        except Exception:
            pm_types = ["card"]
        try:
            from app.secure_auth import get_wechat_pay_payment_method_options
            payment_method_options = (
                get_wechat_pay_payment_method_options(request) if "wechat_pay" in pm_types else {}
            )
        except Exception:
            payment_method_options = {}

        create_pi_kw = {
            "amount": task_amount_pence,
            "currency": currency_lower,
            "payment_method_types": pm_types,
            "description": f"团队服务 #{new_task.id}: {service.service_name[:50]}",
            "metadata": {
                "task_id": str(new_task.id),
                "task_title": (service.service_name or "")[:200],
                "poster_id": str(application.applicant_id),
                "poster_name": getattr(applicant_user, "name", "") or f"User {application.applicant_id}",
                "taker_id": str(taker_id_value),
                "taker_expert_id": str(taker_expert_id_value),
                "team_name": getattr(expert, "name", "") or "",
                "team_stripe_account_id": expert.stripe_account_id,
                "application_fee": str(application_fee_pence),
                "task_amount": str(task_amount_pence),
                "task_amount_display": f"{price:.2f}",
                "platform": "Link\u00b2Ur",
                "payment_type": "team_service_application_approve",
                "service_application_id": str(application.id),
                "service_id": str(service.id),
            },
        }
        if payment_method_options:
            create_pi_kw["payment_method_options"] = payment_method_options

        payment_intent = stripe.PaymentIntent.create(**create_pi_kw)
        new_task.payment_intent_id = payment_intent.id
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"创建团队服务 PaymentIntent 失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="创建支付失败，请稍后重试",
        )

    # 12. 更新 application
    application.status = "approved"
    application.final_price = price
    application.task_id = new_task.id
    application.approved_at = get_utc_time()
    application.updated_at = get_utc_time()

    await db.commit()

    # 13. 通知申请人（best-effort，失败不阻塞主流程）
    try:
        from app.task_notifications import send_service_application_approved_notification
        await send_service_application_approved_notification(
            db=db,
            applicant_id=application.applicant_id,
            expert_id=taker_id_value,  # 团队 owner 的 user_id（兼容现有签名）
            task_id=new_task.id,
            service_name=service.service_name,
        )
    except Exception as e:
        logger.warning(f"团队服务批准通知发送失败: {e}")

    return {
        "message": "申请已同意，请等待申请者完成支付",
        "application_id": application.id,
        "task_id": new_task.id,
        "task_status": "pending_payment",
        "payment_intent_id": payment_intent.id,
        "client_secret": payment_intent.client_secret,
        "amount": payment_intent.amount,
        "amount_display": f"{payment_intent.amount / 100:.2f}",
        "currency": (payment_intent.currency or "gbp").upper(),
        "taker_expert_id": taker_expert_id_value,
        "task": new_task,
    }


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

    price = body.get("price")
    if price is not None:
        try:
            price = float(price)
        except (TypeError, ValueError):
            raise HTTPException(status_code=400, detail="price 必须为数字")
        if price <= 0:
            raise HTTPException(status_code=400, detail="price 必须大于 0")

    # 团队咨询：还价时必须绑定服务
    service_id = body.get("service_id")
    if application.service_id is None:
        if not service_id:
            raise HTTPException(status_code=400, detail="团队咨询还价必须选择一个服务")
        svc_result = await db.execute(
            select(models.TaskExpertService).where(
                and_(
                    models.TaskExpertService.id == int(service_id),
                    models.TaskExpertService.owner_type == "expert",
                    models.TaskExpertService.owner_id == application.new_expert_id,
                    models.TaskExpertService.status == "active",
                )
            )
        )
        if not svc_result.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="service_not_found")
        application.service_id = int(service_id)

    if price is not None:
        application.expert_counter_price = price
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
    """获取申请状态(申请人或服务提供方)"""
    app_result = await db.execute(
        select(models.ServiceApplication).where(models.ServiceApplication.id == application_id)
    )
    application = app_result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")

    # 权限检查: 申请人、团队 owner/admin、或团队 member 可查看
    is_applicant = application.applicant_id == current_user.id
    is_owner_admin = False
    is_team_member = False
    if not is_applicant and application.new_expert_id:
        try:
            await _get_member_or_403(
                db, application.new_expert_id, current_user.id,
                required_roles=["owner", "admin"],
            )
            is_owner_admin = True
        except HTTPException:
            # 检查是否为普通 member
            from app.models_expert import ExpertMember
            mem_result = await db.execute(
                select(ExpertMember.id).where(
                    and_(
                        ExpertMember.expert_id == application.new_expert_id,
                        ExpertMember.user_id == current_user.id,
                        ExpertMember.status == "active",
                    )
                ).limit(1)
            )
            is_team_member = mem_result.scalar_one_or_none() is not None
    elif not is_applicant and application.service_owner_id == current_user.id:
        is_owner_admin = True

    if not is_applicant and not is_owner_admin and not is_team_member:
        raise HTTPException(status_code=403, detail="无权查看该申请")

    return {
        "id": application.id,
        "service_id": application.service_id,
        "applicant_id": application.applicant_id,
        "new_expert_id": application.new_expert_id,
        "status": application.status,
        "negotiated_price": float(application.negotiated_price) if application.negotiated_price else None,
        "expert_counter_price": float(application.expert_counter_price) if application.expert_counter_price else None,
        "final_price": float(application.final_price) if application.final_price else None,
        "can_quote": is_owner_admin and not is_applicant,
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
        .outerjoin(
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
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """获取我发出的服务申请列表（含服务/所有者信息）"""
    base_filter = [models.ServiceApplication.applicant_id == current_user.id]
    if status_filter:
        base_filter.append(models.ServiceApplication.status == status_filter)

    # 总数
    total_result = await db.execute(
        select(func.count(models.ServiceApplication.id)).where(and_(*base_filter))
    )
    total = total_result.scalar() or 0

    offset = (page - 1) * page_size
    query = (
        select(models.ServiceApplication)
        .where(and_(*base_filter))
        .order_by(models.ServiceApplication.created_at.desc())
        .offset(offset)
        .limit(page_size)
    )
    result = await db.execute(query)
    apps = result.scalars().all()

    # 批量取关联 service 和 owner 信息，避免 N+1
    service_ids = list({a.service_id for a in apps if a.service_id})
    services_map: dict = {}
    if service_ids:
        svc_result = await db.execute(
            select(models.TaskExpertService).where(
                models.TaskExpertService.id.in_(service_ids)
            )
        )
        for s in svc_result.scalars().all():
            services_map[s.id] = s

    owner_ids = list({a.service_owner_id for a in apps if a.service_owner_id})
    # 也把 service.user_id 一并取，避免 owner 字段为空
    owner_ids += [
        s.user_id for s in services_map.values() if s.user_id and s.user_id not in owner_ids
    ]
    owners_map: dict = {}
    if owner_ids:
        owner_result = await db.execute(
            select(models.User).where(models.User.id.in_(owner_ids))
        )
        for u in owner_result.scalars().all():
            owners_map[u.id] = u

    items = []
    for a in apps:
        svc = services_map.get(a.service_id)
        owner_id = a.service_owner_id or (svc.user_id if svc else None)
        owner = owners_map.get(owner_id) if owner_id else None
        items.append(
            {
                "id": a.id,
                "service_id": a.service_id,
                "service_name": svc.service_name if svc else None,
                "service_owner_id": owner_id,
                "service_owner_name": owner.name if owner else None,
                "status": a.status,
                "application_message": a.application_message,
                "negotiated_price": float(a.negotiated_price) if a.negotiated_price else None,
                "expert_counter_price": float(a.expert_counter_price) if a.expert_counter_price else None,
                "final_price": float(a.final_price) if a.final_price else None,
                "currency": a.currency or (svc.currency if svc else "GBP"),
                "task_id": a.task_id,
                "owner_reply": a.owner_reply,
                "owner_reply_at": a.owner_reply_at.isoformat() if a.owner_reply_at else None,
                "created_at": a.created_at.isoformat() if a.created_at else None,
            }
        )

    return {
        "items": items,
        "total": total,
        "page": page,
        "page_size": page_size,
    }
