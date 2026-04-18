"""
用户服务申请管理API路由
实现用户对服务申请的管理接口（包括个人服务所有者管理收到的申请）
"""

import logging
from datetime import timedelta
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
from sqlalchemy import select, func, update
from sqlalchemy.ext.asyncio import AsyncSession

from app import models, schemas
from app.deps import get_async_db_dependency
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)


def _payment_method_types_for_currency(currency: str) -> list:
    """根据货币动态返回 Stripe 支持的支付方式列表"""
    c = currency.lower()
    methods = ["card"]
    if c in ("gbp", "cny"):
        methods.extend(["wechat_pay", "alipay"])
    return methods


# 创建用户服务申请路由器
user_service_application_router = APIRouter(prefix="/api/users/me", tags=["user-service-applications"])


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


@user_service_application_router.get("/service-applications", response_model=schemas.PaginatedResponse)
async def get_my_service_applications(
    status_filter: Optional[str] = Query(None, alias="status"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """用户获取自己的申请列表"""
    query = select(models.ServiceApplication).where(
        models.ServiceApplication.applicant_id == current_user.id
    )
    
    if status_filter:
        query = query.where(models.ServiceApplication.status == status_filter)
    
    # 获取总数
    count_query = select(func.count(models.ServiceApplication.id)).where(
        models.ServiceApplication.applicant_id == current_user.id
    )
    if status_filter:
        count_query = count_query.where(models.ServiceApplication.status == status_filter)
    
    total_result = await db.execute(count_query)
    total = total_result.scalar()
    
    # 分页查询
    query = query.order_by(models.ServiceApplication.created_at.desc()).offset(offset).limit(limit)
    
    result = await db.execute(query)
    applications = result.scalars().all()
    
    # 加载关联数据
    items = []
    for app in applications:
        app_dict = schemas.ServiceApplicationOut.model_validate(app).model_dump()
        # 加载服务信息
        service = await db.get(models.TaskExpertService, app.service_id)
        if service:
            app_dict["service_name"] = service.service_name
        # 加载服务所有者信息
        if app.service_owner_id:
            from app import async_crud
            owner = await async_crud.async_user_crud.get_user_by_id(db, app.service_owner_id)
            if owner:
                app_dict["owner_name"] = owner.name
        elif app.expert_id:
            expert = await db.get(models.TaskExpert, app.expert_id)
            if expert:
                app_dict["owner_name"] = expert.expert_name
        items.append(app_dict)
    
    return {
        "total": total,
        "items": items,
        "limit": limit,
        "offset": offset,
        "has_more": (offset + limit) < total,
    }


@user_service_application_router.post("/service-applications/{application_id}/respond-counter-offer")
async def respond_to_counter_offer(
    application_id: int,
    request: schemas.AcceptCounterOfferRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """用户同意/拒绝任务达人的议价（完整校验 + 并发安全）"""
    # 1. 获取申请记录（带锁，防止并发）
    application = await db.execute(
        select(models.ServiceApplication)
        .where(models.ServiceApplication.id == application_id)
        .with_for_update()  # 并发安全：行级锁
    )
    application = application.scalar_one_or_none()
    
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")
    
    # 2. 权限校验：只能处理自己的申请
    if application.applicant_id != current_user.id:
        raise HTTPException(status_code=403, detail="只能处理自己的申请")
    
    # 3. 状态校验：必须是negotiating状态
    if application.status != "negotiating":
        raise HTTPException(status_code=400, detail="当前状态不允许此操作")
    
    # 4. 验证申请中有任务达人的议价价格
    if application.expert_counter_price is None:
        raise HTTPException(status_code=400, detail="任务达人尚未提出议价")
    
    # 提前计算 owner_id，供 accept 和 reject 分支共用
    owner_id = application.service_owner_id or application.expert_id

    if request.accept:
        # 5. 同意议价：更新状态为price_agreed
        application.status = "price_agreed"
        application.final_price = application.expert_counter_price
        application.price_agreed_at = get_utc_time()
        application.updated_at = get_utc_time()

        await db.commit()
        await db.refresh(application)

        # 6. 发送通知给服务所有者
        from app.task_notifications import send_counter_offer_accepted_notification
        try:
            await send_counter_offer_accepted_notification(
                db=db,
                expert_id=owner_id,
                applicant_id=application.applicant_id,
                counter_price=application.expert_counter_price,
                service_id=application.service_id
            )
        except Exception as e:
            logger.error(f"Failed to send notification: {e}")

        # 7. 发送通知给用户（申请者），提醒用户等待服务所有者创建任务并支付
        from app.task_notifications import send_counter_offer_accepted_to_applicant_notification
        try:
            await send_counter_offer_accepted_to_applicant_notification(
                db=db,
                applicant_id=application.applicant_id,
                expert_id=owner_id,
                counter_price=application.expert_counter_price,
                service_id=application.service_id
            )
        except Exception as e:
            logger.error(f"Failed to send notification to applicant: {e}")
        
        return {
            "message": "已同意任务达人的议价",
            "application_id": application_id,
            "status": "price_agreed",
            "final_price": float(application.final_price),
        }
    else:
        # 7. 拒绝议价：恢复为pending状态
        application.status = "pending"
        application.expert_counter_price = None  # 清除议价
        application.updated_at = get_utc_time()
        
        await db.commit()
        await db.refresh(application)
        
        # 8. 发送通知给服务所有者
        from app.task_notifications import send_counter_offer_rejected_notification
        try:
            await send_counter_offer_rejected_notification(
                db=db,
                expert_id=owner_id,
                applicant_id=application.applicant_id,
                service_id=application.service_id
            )
        except Exception as e:
            logger.error(f"Failed to send notification: {e}")
        
        return {
            "message": "已拒绝任务达人的议价",
            "application_id": application_id,
            "status": "pending",
        }


@user_service_application_router.post("/service-applications/{application_id}/cancel")
async def cancel_service_application(
    application_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """用户取消自己的服务申请（完整校验 + 并发安全 + 幂等性）"""
    # 1. 获取申请记录（带锁，防止并发）
    application = await db.execute(
        select(models.ServiceApplication)
        .where(models.ServiceApplication.id == application_id)
        .with_for_update()  # 并发安全：行级锁
    )
    application = application.scalar_one_or_none()
    
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")
    
    # 2. 权限校验：只能取消自己的申请
    if application.applicant_id != current_user.id:
        raise HTTPException(status_code=403, detail="只能取消自己的申请")
    
    # 3. 幂等性检查：如果已经是cancelled状态，直接返回
    if application.status == "cancelled":
        return {
            "message": "申请已取消",
            "application_id": application_id,
            "status": "cancelled",
        }
    
    # 4. 状态校验：只能取消特定状态的申请
    allowed_statuses = ["pending", "negotiating", "price_agreed"]
    if application.status not in allowed_statuses:
        raise HTTPException(
            status_code=400, 
            detail=f"当前状态（{application.status}）不允许取消，只能取消以下状态的申请：{', '.join(allowed_statuses)}"
        )
    
    # 5. 回退时间段参与者数量
    if application.time_slot_id:
        await db.execute(
            update(models.ServiceTimeSlot)
            .where(models.ServiceTimeSlot.id == application.time_slot_id)
            .where(models.ServiceTimeSlot.current_participants > 0)
            .values(current_participants=models.ServiceTimeSlot.current_participants - 1)
        )

    # 6. 更新状态
    application.status = "cancelled"
    application.updated_at = get_utc_time()

    await db.commit()
    await db.refresh(application)

    # 7. 发送通知给服务所有者
    cancel_owner_id = application.service_owner_id or application.expert_id
    from app.task_notifications import send_service_application_cancelled_notification
    try:
        await send_service_application_cancelled_notification(
            db=db,
            expert_id=cancel_owner_id,
            applicant_id=application.applicant_id,
            service_id=application.service_id
        )
    except Exception as e:
        logger.error(f"Failed to send notification: {e}")
    
    return {
        "message": "申请已取消",
        "application_id": application_id,
        "status": "cancelled",
    }


# ==================== 服务所有者管理收到的申请（个人服务；达人服务使用 task_expert_routes） ====================


async def _get_application_as_owner(
    application_id: int,
    current_user: models.User,
    db: AsyncSession,
    lock: bool = True,
) -> models.ServiceApplication:
    """获取申请记录并验证当前用户是服务所有者（仅限个人服务，达人服务走 task_expert_routes）"""
    query = (
        select(models.ServiceApplication)
        .where(models.ServiceApplication.id == application_id)
    )
    if lock:
        query = query.with_for_update()
    result = await db.execute(query)
    application = result.scalar_one_or_none()

    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")

    if not application.service_owner_id or application.service_owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="只能处理自己服务的申请")

    return application


@user_service_application_router.get("/service-applications/received", response_model=schemas.PaginatedResponse)
async def get_received_service_applications(
    status_filter: Optional[str] = Query(None, alias="status"),
    service_id: Optional[int] = Query(None),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """服务所有者获取收到的申请列表（适用于个人服务和达人服务）"""
    base_filter = models.ServiceApplication.service_owner_id == current_user.id

    query = select(models.ServiceApplication).where(base_filter)
    count_query = select(func.count(models.ServiceApplication.id)).where(base_filter)

    if status_filter:
        query = query.where(models.ServiceApplication.status == status_filter)
        count_query = count_query.where(models.ServiceApplication.status == status_filter)
    if service_id:
        query = query.where(models.ServiceApplication.service_id == service_id)
        count_query = count_query.where(models.ServiceApplication.service_id == service_id)

    total = (await db.execute(count_query)).scalar()

    query = query.order_by(models.ServiceApplication.created_at.desc()).offset(offset).limit(limit)
    applications = (await db.execute(query)).scalars().all()

    items = []
    for app in applications:
        app_dict = schemas.ServiceApplicationOut.model_validate(app).model_dump()
        # 加载服务信息
        service = await db.get(models.TaskExpertService, app.service_id)
        if service:
            app_dict["service_name"] = service.service_name
        # 加载申请者信息
        from app import async_crud
        applicant = await async_crud.async_user_crud.get_user_by_id(db, app.applicant_id)
        if applicant:
            app_dict["applicant_name"] = applicant.name
            app_dict["applicant_avatar"] = applicant.avatar
        items.append(app_dict)

    return {
        "total": total,
        "items": items,
        "limit": limit,
        "offset": offset,
        "has_more": (offset + limit) < total,
    }


@user_service_application_router.post("/service-applications/{application_id}/owner-counter-offer")
async def owner_counter_offer(
    application_id: int,
    counter_offer: schemas.CounterOfferRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """服务所有者议价（适用于个人服务）"""
    application = await _get_application_as_owner(application_id, current_user, db)

    if application.status not in ("pending", "negotiating"):
        raise HTTPException(status_code=400, detail="当前状态不允许议价")

    if counter_offer.counter_price <= 0:
        raise HTTPException(status_code=400, detail="议价价格必须大于0")

    application.status = "negotiating"
    application.expert_counter_price = counter_offer.counter_price
    application.updated_at = get_utc_time()

    await db.commit()
    await db.refresh(application)

    # 发送通知给申请用户
    from app.task_notifications import send_counter_offer_notification
    try:
        await send_counter_offer_notification(
            db=db,
            applicant_id=application.applicant_id,
            expert_id=application.service_owner_id,  # 用 service_owner_id 代替
            counter_price=counter_offer.counter_price,
            service_id=application.service_id,
            message=counter_offer.message
        )
    except Exception as e:
        logger.error(f"Failed to send counter-offer notification: {e}")

    return schemas.ServiceApplicationOut.model_validate(application)


@user_service_application_router.post("/service-applications/{application_id}/owner-approve")
async def owner_approve_application(
    application_id: int,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """服务所有者同意申请（创建任务 + 支付流程）"""
    application = await _get_application_as_owner(application_id, current_user, db)

    # 幂等性检查
    if application.status == "approved" and application.task_id:
        task = await db.get(models.Task, application.task_id)
        return {
            "message": "任务已创建",
            "application_id": application_id,
            "task_id": application.task_id,
            "task": task,
        }

    if application.status not in ("pending", "price_agreed"):
        raise HTTPException(status_code=409, detail="当前状态不允许创建任务")

    # 获取服务信息
    service = await db.get(models.TaskExpertService, application.service_id)
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")
    if service.status != "active":
        raise HTTPException(status_code=400, detail="服务未上架，无法创建任务")

    # 确定最终价格
    # 优先级: 议价达成 > 用户出价 > 时间段拼单价 > 服务基础价
    if application.status == "price_agreed" and application.expert_counter_price is not None:
        price = float(application.expert_counter_price)
    elif application.negotiated_price is not None:
        price = float(application.negotiated_price)
    elif application.time_slot_id:
        slot = await db.get(models.ServiceTimeSlot, application.time_slot_id)
        fallback_base = float(service.base_price) if service.base_price is not None else 0.0
        price = float(slot.price_per_participant) if slot and slot.price_per_participant is not None else fallback_base
    else:
        price = float(service.base_price) if service.base_price is not None else 0.0

    # 价格护栏：0 或非正价格会撞 DB 约束 chk_tasks_reward_type_consistency
    # 且 Stripe 无法对 0 金额创建 PaymentIntent。
    # 议价服务需先通过『还价』设定价格；其它情况属数据异常。
    if price is None or price <= 0:
        is_negotiable = (getattr(service, "pricing_type", None) or "fixed") == "negotiable"
        if is_negotiable:
            detail_msg = (
                "该服务为议价服务，申请人未报价且您尚未还价。"
                "请先通过『还价』设定价格，待申请人确认后再批准。"
            )
            detail_msg_en = (
                "This is a negotiable service with no agreed price. "
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

    # 获取位置信息
    location = service.location or "线上"
    if location.lower() in ("online", "线上"):
        location = "线上"

    # 确定截止日期
    if application.is_flexible == 1:
        task_deadline = None
    elif application.deadline:
        task_deadline = application.deadline
    else:
        task_deadline = get_utc_time() + timedelta(days=7)

    # 处理图片
    import json
    images_json = None
    if service.images:
        if isinstance(service.images, list):
            images_json = json.dumps(service.images) if service.images else None
        elif isinstance(service.images, str):
            images_json = service.images
        else:
            try:
                images_json = json.dumps(service.images)
            except Exception:
                images_json = None

    # 获取申请用户
    applicant_user = await db.get(models.User, application.applicant_id)
    if not applicant_user:
        raise HTTPException(status_code=404, detail="申请用户不存在")

    # 获取服务所有者的 Stripe Connect 账户（收款方）
    taker_stripe_account_id = current_user.stripe_account_id
    if not taker_stripe_account_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="您尚未创建 Stripe Connect 收款账户，无法完成支付。请先前往设置创建收款账户。",
            headers={"X-Stripe-Connect-Required": "true"}
        )

    # 按资金划分任务等级（与普通任务一致）
    from app.async_crud import AsyncTaskCRUD
    settings = await AsyncTaskCRUD.get_system_settings_dict(db)
    vip_threshold = float(settings.get("vip_price_threshold", 10.0))
    super_threshold = float(settings.get("super_vip_price_threshold", 50.0))
    user_level = str(current_user.user_level) if current_user.user_level else "normal"
    if user_level == "super":
        task_level = "vip"
    elif price >= super_threshold:
        task_level = "super"
    elif price >= vip_threshold:
        task_level = "vip"
    else:
        task_level = "normal"

    # Check if task already exists (from consultation flow)
    existing_task = None
    if application.task_id:
        existing_task = await db.get(models.Task, application.task_id)

    if existing_task:
        # Update existing consultation task instead of creating new one
        existing_task.title = service.service_name
        existing_task.description = service.description or f"服务: {service.service_name}"
        existing_task.reward = price
        existing_task.base_reward = float(service.base_price)
        existing_task.agreed_reward = price
        existing_task.currency = application.currency or service.currency
        existing_task.status = "pending_payment"
        existing_task.is_paid = 0
        existing_task.payment_expires_at = get_utc_time() + timedelta(minutes=30)
        existing_task.accepted_at = get_utc_time()
        existing_task.task_source = "consultation"
        existing_task.location = service.location or "线上"
        existing_task.task_type = service.category or "其他"
        existing_task.task_level = "expert" if hasattr(service, 'expert_id') and service.expert_id else task_level
        existing_task.is_flexible = application.is_flexible or 0
        existing_task.expert_service_id = service.id
        # Set deadline
        if application.is_flexible == 1:
            existing_task.deadline = None
        elif application.deadline:
            existing_task.deadline = application.deadline
        else:
            existing_task.deadline = get_utc_time() + timedelta(days=7)

        new_task = existing_task
        await db.flush()
    else:
        # 创建任务
        new_task = models.Task(
            title=service.service_name,
            description=service.description,
            deadline=task_deadline,
            is_flexible=application.is_flexible or 0,
            reward=price,
            base_reward=service.base_price,
            agreed_reward=price,
            currency=application.currency or service.currency,
            location=location,
            task_type=service.category or "其他",
            task_level=task_level,
            poster_id=application.applicant_id,
            taker_id=current_user.id,  # 服务所有者是接收方
            expert_service_id=service.id,  # 关联服务，支付过期时能找到对应申请
            status="pending_payment",
            is_paid=0,
            payment_expires_at=get_utc_time() + timedelta(minutes=30),
            images=images_json,
            accepted_at=get_utc_time(),
            task_source="personal_service",
        )

        db.add(new_task)
        await db.flush()

    # 拼单：创建任务-时间段关联（供自动完成定时器使用）
    if application.time_slot_id:
        slot = await db.get(models.ServiceTimeSlot, application.time_slot_id)
        if slot:
            relation = models.TaskTimeSlotRelation(
                task_id=new_task.id,
                time_slot_id=slot.id,
                relation_mode='fixed',
                slot_start_datetime=slot.slot_start_datetime,
                slot_end_datetime=slot.slot_end_datetime,
            )
            db.add(relation)
            await db.flush()

    # 创建支付意图
    import stripe
    task_amount_pence = int(price * 100)
    from app.utils.fee_calculator import calculate_application_fee_pence
    application_fee_pence = calculate_application_fee_pence(
        task_amount_pence, task_source="personal_service", task_type=None
    )

    try:
        from app.secure_auth import get_wechat_pay_payment_method_options
        pm_types = _payment_method_types_for_currency((getattr(new_task, "currency", None) or "GBP").lower())
        payment_method_options = get_wechat_pay_payment_method_options(request) if "wechat_pay" in pm_types else {}
        create_pi_kw = {
            "amount": task_amount_pence,
            "currency": (getattr(new_task, "currency", None) or "GBP").lower(),
            "payment_method_types": pm_types,
            "description": f"个人服务 #{new_task.id}: {service.service_name[:50]}",
            "metadata": {
                "task_id": str(new_task.id),
                "task_title": service.service_name[:200] if service.service_name else "",
                "poster_id": str(application.applicant_id),
                "poster_name": applicant_user.name if applicant_user else f"User {application.applicant_id}",
                "taker_id": str(current_user.id),
                "taker_name": current_user.name or f"User {current_user.id}",
                "taker_stripe_account_id": taker_stripe_account_id,
                "application_fee": str(application_fee_pence),
                "task_amount": str(task_amount_pence),
                "task_amount_display": f"{price:.2f}",
                "platform": "Link²Ur",
                "payment_type": "service_application_approve",
                "service_application_id": str(application_id),
                "service_id": str(service.id)
            },
        }
        if payment_method_options:
            create_pi_kw["payment_method_options"] = payment_method_options
        payment_intent = stripe.PaymentIntent.create(**create_pi_kw)
        new_task.payment_intent_id = payment_intent.id
    except Exception as e:
        await db.rollback()
        logger.error(f"创建 PaymentIntent 失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="创建支付失败，请稍后重试"
        )

    # 更新申请记录
    application.status = "approved"
    application.final_price = price
    application.task_id = new_task.id
    application.approved_at = get_utc_time()
    application.updated_at = get_utc_time()

    await db.commit()
    await db.refresh(new_task)

    # 创建 Stripe Customer + EphemeralKey
    customer_id = None
    ephemeral_key_secret = None
    try:
        from app.utils.stripe_utils import get_or_create_stripe_customer
        customer_id = get_or_create_stripe_customer(applicant_user)
        if customer_id and applicant_user and (not applicant_user.stripe_customer_id or applicant_user.stripe_customer_id != customer_id):
            await db.execute(
                update(models.User)
                .where(models.User.id == applicant_user.id)
                .values(stripe_customer_id=customer_id)
            )
        ephemeral_key = stripe.EphemeralKey.create(
            customer=customer_id,
            stripe_version="2025-01-27.acacia",
        )
        ephemeral_key_secret = ephemeral_key.secret
    except Exception as e:
        logger.warning(f"无法创建 Stripe Customer 或 Ephemeral Key: {e}")

    # 发送通知给申请用户
    from app.task_notifications import send_service_application_approved_notification
    try:
        await send_service_application_approved_notification(
            db=db,
            applicant_id=application.applicant_id,
            expert_id=current_user.id,  # 服务所有者
            task_id=new_task.id,
            service_name=service.service_name
        )
    except Exception as e:
        logger.error(f"Failed to send approval notification: {e}")

    return {
        "message": "申请已同意，请等待申请者完成支付",
        "application_id": application_id,
        "task_id": new_task.id,
        "task_status": "pending_payment",
        "payment_intent_id": payment_intent.id,
        "client_secret": payment_intent.client_secret,
        "amount": payment_intent.amount,
        "amount_display": f"{payment_intent.amount / 100:.2f}",
        "currency": payment_intent.currency.upper(),
        "customer_id": customer_id,
        "ephemeral_key_secret": ephemeral_key_secret,
        "task": new_task,
    }


@user_service_application_router.post("/service-applications/{application_id}/owner-reject")
async def owner_reject_application(
    application_id: int,
    reject_data: schemas.ServiceApplicationRejectRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """服务所有者拒绝申请"""
    application = await _get_application_as_owner(application_id, current_user, db)

    rejectable_statuses = ("pending", "negotiating", "price_agreed")
    if application.status not in rejectable_statuses:
        raise HTTPException(status_code=400, detail=f"当前状态({application.status})不允许拒绝")

    # 保存通知数据
    applicant_id = application.applicant_id
    service_id = application.service_id
    reject_reason = reject_data.reject_reason

    # 回退时间段参与者数量
    if application.time_slot_id:
        await db.execute(
            update(models.ServiceTimeSlot)
            .where(models.ServiceTimeSlot.id == application.time_slot_id)
            .where(models.ServiceTimeSlot.current_participants > 0)
            .values(current_participants=models.ServiceTimeSlot.current_participants - 1)
        )

    application.status = "rejected"
    application.rejected_at = get_utc_time()
    application.updated_at = get_utc_time()

    await db.commit()

    # 后台发送通知
    from app.task_notifications import send_service_application_rejected_notification
    import asyncio

    async def send_notification_background():
        from app.database import AsyncSessionLocal
        async with AsyncSessionLocal() as async_db:
            try:
                await send_service_application_rejected_notification(
                    db=async_db,
                    applicant_id=applicant_id,
                    expert_id=current_user.id,  # 服务所有者
                    service_id=service_id,
                    reject_reason=reject_reason
                )
            except Exception as e:
                logger.error(f"Failed to send rejection notification: {e}")

    asyncio.create_task(send_notification_background())

    return {
        "message": "申请已拒绝",
        "application_id": application_id,
    }

