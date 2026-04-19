"""达人服务申请/咨询/协商路由"""
import json
import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app import models, schemas
from app.consultation import error_codes
from app.consultation.helpers import (
    check_consultation_idempotency,
    close_consultation_task,
    create_placeholder_task,
    resolve_taker_from_service,
)
from app.consultation.notifications import (
    consultation_submitted,
    task_negotiation_accepted,
    task_negotiation_rejected,
    task_counter_offer,
)
from app.deps import get_async_db_dependency
from app.error_handlers import raise_http_error_with_code
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
        _msg = consultation_submitted(
            applicant_name=applicant_name, service_name=service_name
        )
        content_zh = _msg["content_zh"] + ",请前往达人后台处理"
        content_en = _msg["content_en"]
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
        raise_http_error_with_code("服务不存在", 404, error_codes.SERVICE_NOT_FOUND)
    if service.status != "active":
        raise_http_error_with_code("服务未上架", 400, error_codes.SERVICE_INACTIVE)

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

    # 护栏：议价服务 + 无基础价 + 无时间段 → apply 流程无处落地价格，
    # 到审批时会撞 DB 约束（chk_tasks_reward_type_consistency）且 Stripe 拒 0 金额。
    # 引导用户走 /consult 咨询流程（那边原生支持 reward_to_be_quoted）。
    _is_negotiable = (service.pricing_type or "fixed") == "negotiable"
    _no_base_price = service.base_price is None or float(service.base_price) <= 0
    if _is_negotiable and _no_base_price and not time_slot_id:
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "apply_requires_consultation",
                "message": "此服务为议价服务且未设定基础价格，请使用『咨询』功能先与服务提供者沟通价格后再申请。",
                "message_en": "This service has no fixed price. Please use consultation to discuss price before applying.",
                "suggested_action": "consult",
                "service_id": service_id,
            },
        )

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

    # 拼单：增加时间段参与人数
    if time_slot_id:
        await db.execute(
            update(models.ServiceTimeSlot)
            .where(models.ServiceTimeSlot.id == time_slot_id)
            .values(current_participants=models.ServiceTimeSlot.current_participants + 1)
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
        raise_http_error_with_code("服务不存在", 404, error_codes.SERVICE_NOT_FOUND)

    # 检查是否已有进行中的咨询/申请（幂等）
    existing_app = await check_consultation_idempotency(
        db,
        applicant_id=current_user.id,
        subject_id=service_id,
        subject_type="service",
    )
    if existing_app:
        return {
            "id": existing_app.id,
            "status": existing_app.status,
            "task_id": existing_app.task_id,
            "application_id": existing_app.id,
        }

    # 创建 consulting 占位 task（供聊天页面使用）
    service_name = service.service_name or "服务咨询"
    service_name_en = service.service_name_en or service.service_name or "Service Consultation"

    # 解析服务 owner 的 user_id，设为 taker_id 以便对方在消息列表中看到此咨询
    taker_user_id, _ = await resolve_taker_from_service(db, service)

    consulting_task = await create_placeholder_task(
        db,
        consultation_type="consultation",
        title=service_name,
        applicant_id=current_user.id,
        taker_id=taker_user_id,
        description=f"咨询: {service_name}",
        title_zh=service_name,
        title_en=service_name_en,
        reward=service.base_price or 0,
        base_reward=service.base_price or 0,
        reward_to_be_quoted=True if not service.base_price else False,
        currency=service.currency or "GBP",
        location=service.location or "",
        task_type="expert_service",
        task_level="expert",
        expert_service_id=service.id,
    )

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

    # 通知服务提供者有新咨询
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
    elif service.owner_type == "user" and taker_user_id:
        # 个人服务：通知服务提供者
        try:
            from app import async_crud
            applicant_name = current_user.name or "用户"
            svc_name = service.service_name or "服务"
            await async_crud.async_notification_crud.create_notification(
                db, taker_user_id, "service_consultation_received",
                "新服务咨询",
                f'{applicant_name} 想咨询您的服务「{svc_name}」',
                related_id=str(application.id),
                title_en="New Consultation Request",
                content_en=f'{applicant_name} wants to consult about your service "{svc_name}"',
                related_type="application_id",
            )
        except Exception as e:
            logger.warning(f"Failed to notify personal service owner: {e}")

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
        raise_http_error_with_code("达人团队不存在", 404, error_codes.EXPERT_TEAM_NOT_FOUND)
    if expert.status != "active":
        raise_http_error_with_code("该团队未在运营中", 400, error_codes.EXPERT_TEAM_INACTIVE)

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
        raise_http_error_with_code("不能咨询自己所在的团队", 400, error_codes.CANNOT_CONSULT_SELF)

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
    team_name_en = expert.name_en or expert.name or "Expert Team"

    # 解析团队 owner 的 user_id，设为 taker_id 以便对方在消息列表中看到此咨询
    owner_result = await db.execute(
        select(ExpertMember.user_id).where(
            ExpertMember.expert_id == expert_id,
            ExpertMember.role == "owner",
            ExpertMember.status == "active",
        )
    )
    owner_row = owner_result.first()
    taker_user_id = owner_row[0] if owner_row else None

    consulting_task = await create_placeholder_task(
        db,
        consultation_type="consultation",
        title=f"团队咨询: {team_name}",
        applicant_id=current_user.id,
        taker_id=taker_user_id,
        description=f"团队咨询: {team_name}",
        title_zh=f"团队咨询: {team_name}",
        title_en=f"Team Consultation: {team_name_en}",
        reward=0,
        base_reward=0,
        reward_to_be_quoted=True,
        currency="GBP",
        location="",
        task_type="expert_service",
        task_level="expert",
    )

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
        raise_http_error_with_code("申请不存在", 404, error_codes.CONSULTATION_NOT_FOUND)
    if application.applicant_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权操作")

    try:
        price = float(body.get("price", 0))
    except (TypeError, ValueError):
        raise_http_error_with_code("price 必须为数字", 400, error_codes.PRICE_OUT_OF_RANGE)
    if price <= 0:
        raise_http_error_with_code("price 必须大于 0", 400, error_codes.PRICE_OUT_OF_RANGE)
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
            raise_http_error_with_code("service_not_found", 400, error_codes.SERVICE_NOT_FOUND)
        application.service_id = int(service_id)
    application.negotiated_price = price
    application.expert_counter_price = None  # 新一轮议价,清掉对方前一次的价
    application.status = "negotiating"
    application.updated_at = get_utc_time()

    # 写议价卡片消息（镜像 task_chat_routes 模式）
    task = await db.get(models.Task, application.task_id) if application.task_id else None
    if task:
        receiver_id = task.taker_id if current_user.id == task.poster_id else task.poster_id
        currency = application.currency or "GBP"
        user_name = current_user.name if hasattr(current_user, "name") else "用户"
        _msg = task_counter_offer(user_name=user_name, currency=currency, price=float(price))
        system_message = models.Message(
            sender_id=current_user.id,
            receiver_id=str(receiver_id) if receiver_id else None,
            task_id=application.task_id,
            application_id=None,
            message_type="negotiation",
            conversation_type="task",
            content=_msg["content_zh"],
            meta=json.dumps({
                "content_en": _msg["content_en"],
                "action": "negotiate",
                "price": float(price),
                "currency": currency,
            }),
            created_at=get_utc_time(),
        )
        db.add(system_message)

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
        raise_http_error_with_code("申请不存在", 404, error_codes.CONSULTATION_NOT_FOUND)

    # 检查是否为服务的达人团队成员
    if application.new_expert_id:
        await _get_member_or_403(db, application.new_expert_id, current_user.id, required_roles=["owner", "admin"])
    elif application.service_owner_id == current_user.id:
        pass  # 个人服务 owner
    else:
        raise_http_error_with_code("无权操作", 403, error_codes.NOT_SERVICE_OWNER)

    try:
        price = float(body.get("price", 0))
    except (TypeError, ValueError):
        raise_http_error_with_code("price 必须为数字", 400, error_codes.PRICE_OUT_OF_RANGE)
    if price <= 0:
        raise_http_error_with_code("price 必须大于 0", 400, error_codes.PRICE_OUT_OF_RANGE)
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
            raise_http_error_with_code("service_not_found", 400, error_codes.SERVICE_NOT_FOUND)
        application.service_id = int(service_id)
    application.expert_counter_price = price
    application.negotiated_price = None  # 新一轮报价,清掉对方前一次的价
    application.status = "negotiating"
    application.updated_at = get_utc_time()

    # 写报价卡片消息（镜像 task_chat_routes 模式）
    task = await db.get(models.Task, application.task_id) if application.task_id else None
    if task:
        receiver_id = task.taker_id if current_user.id == task.poster_id else task.poster_id
        currency = application.currency or "GBP"
        user_name = current_user.name if hasattr(current_user, "name") else "达人"
        _msg = task_counter_offer(user_name=user_name, currency=currency, price=float(price))
        system_message = models.Message(
            sender_id=current_user.id,
            receiver_id=str(receiver_id) if receiver_id else None,
            task_id=application.task_id,
            application_id=None,
            message_type="quote",
            conversation_type="task",
            content=_msg["content_zh"],
            meta=json.dumps({
                "content_en": _msg["content_en"],
                "action": "quote",
                "price": float(price),
                "currency": currency,
            }),
            created_at=get_utc_time(),
        )
        db.add(system_message)

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
        raise_http_error_with_code(
            f"当前状态({application.status})不允许回应协商",
            400,
            error_codes.INVALID_STATUS_TRANSITION,
        )

    action = body.get("action")  # accept, reject, counter
    if action not in ("accept", "reject", "counter"):
        raise HTTPException(status_code=400, detail="action 必须为 accept/reject/counter")

    if action == "accept":
        # 只能接受对方的报价,不能自己同意自己提的价
        other_side_price = (
            application.expert_counter_price if is_applicant
            else application.negotiated_price
        )
        if other_side_price is None:
            raise HTTPException(status_code=400, detail="尚未收到对方报价,不能接受")
        application.final_price = other_side_price
        application.status = "price_agreed"
        application.price_agreed_at = get_utc_time()
    elif action == "reject":
        application.status = "rejected"
        application.rejected_at = get_utc_time()
        # 同步关闭咨询占位 Task
        await close_consultation_task(db, application, reason="协商已被拒绝")
    elif action == "counter":
        # 校验价格
        try:
            price = float(body.get("price", 0))
        except (TypeError, ValueError):
            raise_http_error_with_code("price 必须为数字", 400, error_codes.PRICE_OUT_OF_RANGE)
        if price <= 0:
            raise_http_error_with_code("price 必须大于 0", 400, error_codes.PRICE_OUT_OF_RANGE)
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
                raise_http_error_with_code("service_not_found", 400, error_codes.SERVICE_NOT_FOUND)
            application.service_id = int(service_id)
        # 按身份区分写哪个字段(不再依赖匿名 fallback),并清掉对方前一次的价
        if is_applicant:
            application.negotiated_price = price
            application.expert_counter_price = None
        else:
            application.expert_counter_price = price
            application.negotiated_price = None
        application.status = "negotiating"

    application.updated_at = get_utc_time()

    # 写协商结果卡片消息（镜像 task_chat_routes 模式）
    task = await db.get(models.Task, application.task_id) if application.task_id else None
    if task:
        receiver_id = task.taker_id if current_user.id == task.poster_id else task.poster_id
        currency = application.currency or "GBP"
        user_name = current_user.name if hasattr(current_user, "name") else "用户"
        if action == "accept":
            accepted_price = float(application.final_price or application.expert_counter_price or application.negotiated_price or 0)
            _msg = task_negotiation_accepted(user_name=user_name, currency=currency, price=accepted_price)
            message_type = "negotiation_accepted"
            meta_price = accepted_price
        elif action == "reject":
            _msg = task_negotiation_rejected(user_name=user_name)
            message_type = "negotiation_rejected"
            meta_price = float(application.negotiated_price or application.expert_counter_price or 0)
        else:  # counter
            _msg = task_counter_offer(user_name=user_name, currency=currency, price=float(price))
            message_type = "counter_offer"
            meta_price = float(price)
        system_message = models.Message(
            sender_id=current_user.id,
            receiver_id=str(receiver_id) if receiver_id else None,
            task_id=application.task_id,
            application_id=None,
            message_type=message_type,
            conversation_type="task",
            content=_msg["content_zh"],
            meta=json.dumps({
                "content_en": _msg["content_en"],
                "action": action,
                "price": meta_price,
                "currency": currency,
            }),
            created_at=get_utc_time(),
        )
        db.add(system_message)

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
        raise_http_error_with_code("申请不存在", 404, error_codes.CONSULTATION_NOT_FOUND)
    if application.applicant_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权操作")

    application.final_price = body.get("price", application.negotiated_price)
    application.deadline = body.get("deadline")
    application.is_flexible = body.get("is_flexible", 0)
    application.status = "pending"
    application.updated_at = get_utc_time()

    # 写系统卡片:申请已正式提交,等待服务方批准
    if application.task_id:
        system_message = models.Message(
            sender_id=None,
            receiver_id=None,
            task_id=application.task_id,
            application_id=None,
            message_type="system",
            conversation_type="task",
            content="申请已正式提交,等待服务方批准",
            meta=json.dumps({
                "content_en": "Application submitted. Waiting for provider approval.",
                "event": "formal_apply_submitted",
            }),
            created_at=get_utc_time(),
        )
        db.add(system_message)

    await db.commit()
    return {"status": "pending"}


@consultation_router.post("/api/applications/{application_id}/pay-and-finalize")
async def pay_and_finalize(
    application_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """申请方在 price_agreed 状态下确认订单并进入付款(仅限申请方调用)。

    团队咨询 → 复用 _approve_team_service_application;
    个人服务 → 复用 user_service_application_routes.finalize_personal_service_application。
    两条路径返回相同 shape(含 client_secret),供 Flutter 打开 Stripe payment sheet。

    并发安全: SELECT ... FOR UPDATE 锁住 application 行,防止双击造成重复
    Task + PaymentIntent。第二次请求在第一次 commit 完后拿锁,看到 status=approved
    直接走幂等路径。
    """
    # 加行锁防止并发重复创建(applicant 可能快速双击)
    app_result = await db.execute(
        select(models.ServiceApplication)
        .where(models.ServiceApplication.id == application_id)
        .with_for_update()
    )
    application = app_result.scalar_one_or_none()
    if not application:
        raise_http_error_with_code("申请不存在", 404, error_codes.CONSULTATION_NOT_FOUND)

    if application.applicant_id != current_user.id:
        raise HTTPException(status_code=403, detail="只有申请方可以确认付款")

    # 幂等: 第一次 pay-and-finalize 已完成, 第二次拿锁时看到 approved → 不重复创建
    # 但我们需要返回完整的支付信息(client_secret + customer_id + ephemeral_key_secret),
    # 让客户端能重开付款 sheet。所以需要重新 retrieve PI + 新建 ephemeral key。
    if application.status == "approved" and application.task_id:
        import stripe as _stripe
        existing_task = await db.get(models.Task, application.task_id)
        if existing_task and existing_task.payment_intent_id:
            try:
                pi = _stripe.PaymentIntent.retrieve(existing_task.payment_intent_id)
                from app.utils.stripe_utils import get_or_create_stripe_customer
                applicant_user = await db.get(models.User, application.applicant_id)
                customer_id = get_or_create_stripe_customer(applicant_user) if applicant_user else None
                ek = _stripe.EphemeralKey.create(
                    customer=customer_id,
                    stripe_version="2025-01-27.acacia",
                ) if customer_id else None
                return {
                    "message": "订单已创建,请完成付款",
                    "application_id": application.id,
                    "task_id": existing_task.id,
                    "task_status": existing_task.status,
                    "payment_intent_id": pi.id,
                    "client_secret": pi.client_secret,
                    "amount": pi.amount,
                    "amount_display": f"{pi.amount / 100:.2f}",
                    "currency": (pi.currency or "gbp").upper(),
                    "customer_id": customer_id,
                    "ephemeral_key_secret": ek.secret if ek else None,
                }
            except Exception as e:
                logger.error(f"pay_and_finalize 幂等路径重新 retrieve PI 失败: {e}")
                raise HTTPException(
                    status_code=500,
                    detail="订单已创建但重新获取支付信息失败,请稍后前往任务详情页付款",
                )

    if application.status != "price_agreed":
        raise_http_error_with_code(
            f"当前状态({application.status})不允许确认付款",
            400,
            error_codes.INVALID_STATUS_TRANSITION,
        )

    # 解析 body:deadline / is_flexible
    deadline_val = body.get("deadline") if body else None
    parsed_deadline = None
    if deadline_val:
        try:
            from datetime import datetime as _dt
            parsed_deadline = (
                _dt.fromisoformat(deadline_val.replace("Z", "+00:00"))
                if isinstance(deadline_val, str) else deadline_val
            )
        except (ValueError, TypeError):
            raise HTTPException(status_code=400, detail="deadline 格式无效")
    is_flexible_val = body.get("is_flexible") if body else None

    if application.new_expert_id:
        # 团队咨询:写 deadline/flex 后委托给 team helper
        if parsed_deadline is not None:
            application.deadline = parsed_deadline
        if is_flexible_val is not None:
            application.is_flexible = 1 if is_flexible_val else 0
        result = await _approve_team_service_application(
            db=db,
            request=request,
            current_user=current_user,
            application=application,
        )
    else:
        # 个人服务:加载服务提供方,调用 personal helper
        if not application.service_owner_id:
            raise HTTPException(status_code=400, detail="申请缺少服务提供方信息")
        owner_user = await db.get(models.User, application.service_owner_id)
        if not owner_user:
            raise HTTPException(status_code=404, detail="服务提供方不存在")

        from app.user_service_application_routes import finalize_personal_service_application
        result = await finalize_personal_service_application(
            db=db,
            request=request,
            application=application,
            owner_user=owner_user,
            deadline_override=parsed_deadline,
            is_flexible_override=is_flexible_val,
        )

    # 严格校验:applicant pay-and-finalize 必须返回完整支付信息给 Flutter;
    # 两端 helper 都把 Stripe Customer/EphemeralKey 创建包在 broad except,
    # 失败时静默返回 None。对 applicant 路径而言这会导致客户端打开付款 sheet 时报错。
    # 此时 Task + PI 已创建(可走任务详情页重新获取付款信息),给 502 提示用户。
    if isinstance(result, dict) and (
        not result.get("client_secret")
        or not result.get("customer_id")
        or not result.get("ephemeral_key_secret")
    ):
        logger.error(
            "pay-and-finalize 返回缺失支付字段: app=%s client_secret=%s customer=%s ek=%s",
            application_id,
            bool(result.get("client_secret")),
            bool(result.get("customer_id")),
            bool(result.get("ephemeral_key_secret")),
        )
        raise HTTPException(
            status_code=502,
            detail="订单已创建但付款准备失败,请前往任务详情页继续付款",
        )

    return result


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
        raise_http_error_with_code("申请不存在", 404, error_codes.CONSULTATION_NOT_FOUND)

    # 权限检查 — 修复 IDOR
    await _check_application_party(db, application, current_user.id)

    # 幂等: 已 cancelled 直接返回
    if application.status == "cancelled":
        return {"status": "cancelled"}

    # 仅在 consulting/negotiating/pending/price_agreed 状态可关闭
    # approved/rejected 状态不允许关闭(已有最终结果)
    if application.status not in ("consulting", "negotiating", "pending", "price_agreed"):
        raise_http_error_with_code(
            f"当前状态({application.status})不允许关闭",
            400,
            error_codes.INVALID_STATUS_TRANSITION,
        )

    application.status = "cancelled"
    application.updated_at = get_utc_time()
    # 同步关闭咨询占位 Task
    await close_consultation_task(db, application, reason="咨询已关闭", new_status="closed")
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
        raise_http_error_with_code("申请不存在", 404, error_codes.CONSULTATION_NOT_FOUND)

    # 权限检查
    if application.new_expert_id:
        await _get_member_or_403(db, application.new_expert_id, current_user.id, required_roles=["owner", "admin"])
    elif application.service_owner_id != current_user.id:
        raise_http_error_with_code("无权操作", 403, error_codes.NOT_SERVICE_OWNER)

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
        raise_http_error_with_code("当前状态不允许批准", 409, error_codes.INVALID_STATUS_TRANSITION)

    # 2. 加载服务
    service = await db.get(models.TaskExpertService, application.service_id)
    if not service:
        raise_http_error_with_code("服务不存在", 404, error_codes.SERVICE_NOT_FOUND)
    if service.status != "active":
        raise_http_error_with_code("服务未上架，无法创建任务", 400, error_codes.SERVICE_INACTIVE)

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
        price = float(service.base_price) if service.base_price is not None else 0.0

    # 价格护栏（与 user_service_application_routes 同款）：
    # 0 价会违反 chk_tasks_reward_type_consistency 且 Stripe 拒 0 金额。
    # 团队议价服务需先通过『还价』定价；定价服务异常则属数据问题。
    if price is None or price <= 0:
        is_negotiable = (getattr(service, "pricing_type", None) or "fixed") == "negotiable"
        if is_negotiable:
            detail_msg = (
                "该团队服务为议价服务，申请人未报价且未有还价价格。"
                "请先通过『还价』设定价格，待申请人确认后再批准。"
            )
            detail_msg_en = (
                "This team service is negotiable with no agreed price. "
                "Please send a counter-offer first and wait for the applicant to accept."
            )
            error_code = "approval_price_not_set_negotiable"
        else:
            detail_msg = "该申请价格异常（0 或未设定），请通过『还价』重新设定价格。"
            detail_msg_en = "Application price is invalid (0 or unset). Please send a counter-offer."
            error_code = "approval_price_not_set"
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": error_code,
                "message": detail_msg,
                "message_en": detail_msg_en,
                "current_price": price,
                "pricing_type": getattr(service, "pricing_type", None),
            },
        )

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

    # 关闭旧的咨询占位 Task（task_id 即将被新 Task 覆盖）
    await close_consultation_task(db, application, reason="咨询已转为正式订单")

    # 12. 更新 application
    application.status = "approved"
    application.final_price = price
    # 备份咨询占位 id,保留 team 成员访问历史消息的路径(防御性兜底,双层防护)
    if application.task_id and not application.consultation_task_id:
        application.consultation_task_id = application.task_id
    application.task_id = new_task.id
    application.approved_at = get_utc_time()
    application.updated_at = get_utc_time()

    await db.commit()

    # 14. Admin 审批时自动加入任务聊天 (best-effort, savepoint 保证原子性)
    try:
        from app.models_expert import ChatParticipant
        async with db.begin_nested():
            # 始终创建 poster + owner 的 ChatParticipant，保持与 invite 端点的"首次升级"一致
            for uid, role in [
                (application.applicant_id, "client"),
                (taker_id_value, "expert_owner"),
            ]:
                existing = await db.execute(
                    select(ChatParticipant).where(
                        and_(ChatParticipant.task_id == new_task.id, ChatParticipant.user_id == uid)
                    )
                )
                if not existing.scalar_one_or_none():
                    db.add(ChatParticipant(task_id=new_task.id, user_id=uid, role=role))
            # 如果审批人不是 owner，也加入聊天
            if current_user.id != taker_id_value and current_user.id != application.applicant_id:
                existing_admin = await db.execute(
                    select(ChatParticipant).where(
                        and_(ChatParticipant.task_id == new_task.id, ChatParticipant.user_id == current_user.id)
                    )
                )
                if not existing_admin.scalar_one_or_none():
                    db.add(ChatParticipant(
                        task_id=new_task.id,
                        user_id=current_user.id,
                        role="expert_admin",
                    ))
        await db.commit()
    except Exception as e:
        logger.warning(f"审批后自动加入聊天失败: {e}")

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

    # 写系统卡片:订单已创建,请完成付款(owner 批准 / applicant pay-and-finalize 共用)
    try:
        order_msg = models.Message(
            sender_id=None,
            receiver_id=None,
            task_id=new_task.id,
            application_id=None,
            message_type="system",
            conversation_type="task",
            content="订单已创建,请完成付款以开始任务",
            meta=json.dumps({
                "content_en": "Order created. Please complete payment to start the task.",
                "event": "order_created",
            }),
            created_at=get_utc_time(),
        )
        db.add(order_msg)
        await db.commit()
    except Exception as e:
        logger.warning(f"写入订单创建系统卡片失败: {e}")

    # 创建 Stripe Customer + EphemeralKey(供 Flutter payment sheet 使用,与个人服务 helper 对称)
    customer_id = None
    ephemeral_key_secret = None
    try:
        from app.utils.stripe_utils import get_or_create_stripe_customer
        customer_id = get_or_create_stripe_customer(applicant_user)
        if customer_id and applicant_user and (
            not applicant_user.stripe_customer_id
            or applicant_user.stripe_customer_id != customer_id
        ):
            from sqlalchemy import update as _sa_update
            await db.execute(
                _sa_update(models.User)
                .where(models.User.id == applicant_user.id)
                .values(stripe_customer_id=customer_id)
            )
            await db.commit()
        ephemeral_key = stripe.EphemeralKey.create(
            customer=customer_id,
            stripe_version="2025-01-27.acacia",
        )
        ephemeral_key_secret = ephemeral_key.secret
    except stripe.error.StripeError as e:
        logger.error(
            "团队服务:Stripe Customer/EphemeralKey 创建失败 "
            "app=%s applicant=%s stripe_code=%s stripe_type=%s customer_id=%s: %s",
            application.id,
            applicant_user.id if applicant_user else None,
            getattr(e, "code", None),
            type(e).__name__,
            customer_id,
            e,
            exc_info=True,
        )
    except Exception as e:
        logger.exception(
            "团队服务:创建 Stripe Customer/EphemeralKey 时发生非 Stripe 异常 "
            "app=%s applicant=%s customer_id=%s: %s",
            application.id,
            applicant_user.id if applicant_user else None,
            customer_id,
            e,
        )

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
        "customer_id": customer_id,
        "ephemeral_key_secret": ephemeral_key_secret,
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
        raise_http_error_with_code("申请不存在", 404, error_codes.CONSULTATION_NOT_FOUND)

    if application.new_expert_id:
        await _get_member_or_403(db, application.new_expert_id, current_user.id, required_roles=["owner", "admin"])
    elif application.service_owner_id != current_user.id:
        raise_http_error_with_code("无权操作", 403, error_codes.NOT_SERVICE_OWNER)

    application.status = "rejected"
    application.rejected_at = get_utc_time()
    application.updated_at = get_utc_time()
    # 同步关闭咨询占位 Task
    await close_consultation_task(db, application, reason="申请已被拒绝")
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
        raise_http_error_with_code("申请不存在", 404, error_codes.CONSULTATION_NOT_FOUND)

    if application.new_expert_id:
        await _get_member_or_403(db, application.new_expert_id, current_user.id, required_roles=["owner", "admin"])
    elif application.service_owner_id != current_user.id:
        raise_http_error_with_code("无权操作", 403, error_codes.NOT_SERVICE_OWNER)

    price = body.get("price")
    if price is not None:
        try:
            price = float(price)
        except (TypeError, ValueError):
            raise_http_error_with_code("price 必须为数字", 400, error_codes.PRICE_OUT_OF_RANGE)
        if price <= 0:
            raise_http_error_with_code("price 必须大于 0", 400, error_codes.PRICE_OUT_OF_RANGE)

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
            raise_http_error_with_code("service_not_found", 400, error_codes.SERVICE_NOT_FOUND)
        application.service_id = int(service_id)

    if price is not None:
        application.expert_counter_price = price
        application.negotiated_price = None  # 新一轮还价,清掉对方前一次的价
    application.status = "negotiating"
    application.updated_at = get_utc_time()

    # 写还价卡片消息（镜像 task_chat_routes 模式）
    task = await db.get(models.Task, application.task_id) if application.task_id else None
    if task and price is not None:
        receiver_id = task.taker_id if current_user.id == task.poster_id else task.poster_id
        currency = application.currency or "GBP"
        user_name = current_user.name if hasattr(current_user, "name") else "达人"
        _msg = task_counter_offer(user_name=user_name, currency=currency, price=float(price))
        system_message = models.Message(
            sender_id=current_user.id,
            receiver_id=str(receiver_id) if receiver_id else None,
            task_id=application.task_id,
            application_id=None,
            message_type="counter_offer",
            conversation_type="task",
            content=_msg["content_zh"],
            meta=json.dumps({
                "content_en": _msg["content_en"],
                "action": "counter",
                "price": float(price),
                "currency": currency,
            }),
            created_at=get_utc_time(),
        )
        db.add(system_message)

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
        raise_http_error_with_code("申请不存在", 404, error_codes.CONSULTATION_NOT_FOUND)

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
            "consultation_task_id": row.ServiceApplication.consultation_task_id,
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
                "consultation_task_id": a.consultation_task_id,
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
