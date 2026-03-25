"""
跳蚤市场租赁API路由
实现租赁申请、审批、归还等生命周期管理
"""

import json
import logging
from decimal import Decimal
from typing import Optional
from datetime import timedelta

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    Request,
    status,
    Body,
)
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, and_, func

from app import models, schemas
from app.deps import get_async_db_dependency
from app.async_routers import get_current_user_optional
from app.id_generator import format_flea_market_id, parse_flea_market_id
from app.utils.time_utils import get_utc_time, format_iso_utc
from app.flea_market_extensions import invalidate_item_cache

logger = logging.getLogger(__name__)

# 创建租赁路由器
rental_router = APIRouter(prefix="/api/flea-market", tags=["跳蚤市场-租赁"])


# 认证依赖（复用 flea_market_routes 的模式）
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


# ==================== 辅助函数 ====================

async def _expire_approved_rental_requests(db: AsyncSession, item_id_int: int):
    """懒惰过期检查：将已过支付截止时间的 approved 租赁申请标记为 expired"""
    expired_stmt = (
        update(models.FleaMarketRentalRequest)
        .where(
            models.FleaMarketRentalRequest.item_id == item_id_int,
            models.FleaMarketRentalRequest.status == 'approved',
            models.FleaMarketRentalRequest.payment_expires_at < get_utc_time()
        )
        .values(status='expired')
    )
    await db.execute(expired_stmt)


async def _send_rental_notification(
    db: AsyncSession,
    user_id: str,
    notification_type: str,
    title: str,
    content: str,
    related_id: str,
    push_data: dict = None,
    push_template_vars: dict = None,
):
    """发送租赁相关通知（站内 + 推送）"""
    try:
        from app import async_crud
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=user_id,
            notification_type=notification_type,
            title=title,
            content=content,
            related_id=related_id,
        )

        try:
            from app.push_notification_service import send_push_notification_async_safe
            send_push_notification_async_safe(
                async_db=db,
                user_id=user_id,
                title=None,
                body=None,
                notification_type=notification_type,
                data=push_data or {},
                template_vars=push_template_vars or {},
            )
        except Exception as e:
            logger.warning(f"发送租赁推送通知失败: {e}")

    except Exception as e:
        logger.error(f"发送租赁通知失败: {e}")


def _compute_rental_end_date(start_date, duration: int, unit: str):
    """根据租期和单位计算结束日期"""
    if unit == "week":
        return start_date + timedelta(days=7 * duration)
    elif unit == "month":
        return start_date + timedelta(days=30 * duration)
    else:  # day
        return start_date + timedelta(days=duration)


async def _create_rental_task_and_payment(
    db: AsyncSession,
    request_obj: Request,
    item: models.FleaMarketItem,
    rental_request: models.FleaMarketRentalRequest,
    rental_price: Decimal,
    renter: models.User,
):
    """创建租赁任务和支付意图的共享逻辑（approve 和 accept counter-offer 复用）"""
    duration = rental_request.rental_duration
    unit = item.rental_unit or "day"
    deposit = item.deposit or Decimal("0")
    total_rent = rental_price * duration
    total_amount = total_rent + deposit

    # 解析 images
    images = []
    if item.images:
        try:
            images = json.loads(item.images)
        except Exception:
            images = []

    description = item.description
    if item.category:
        description = f"{description}\n\nCategory: {item.category}"

    seller = await db.get(models.User, item.seller_id)
    taker_stripe_account_id = seller.stripe_account_id if seller else None

    is_free = float(total_amount) == 0

    new_task = models.Task(
        title=f"[租赁] {item.title}",
        description=description,
        reward=float(total_amount),
        base_reward=item.rental_price,
        agreed_reward=total_amount,
        currency=item.currency or "GBP",
        location=item.location or "Online",
        task_type="Second-hand & Rental",
        poster_id=rental_request.renter_id,
        taker_id=item.seller_id,
        status="in_progress" if is_free else "pending_payment",
        is_paid=1 if is_free else 0,
        payment_expires_at=None if is_free else (get_utc_time() + timedelta(hours=24)),
        is_flexible=1,
        deadline=None,
        images=json.dumps(images) if images else None,
        task_source="flea_market_rental",
    )
    db.add(new_task)
    await db.flush()

    # 更新租赁申请
    rental_request.status = "approved"
    rental_request.payment_expires_at = new_task.payment_expires_at
    rental_request.task_id = new_task.id

    payment_intent = None
    customer_id = None
    ephemeral_key_secret = None

    if not is_free:
        import stripe
        task_amount_pence = int(float(total_amount) * 100)
        from app.utils.fee_calculator import calculate_application_fee_pence
        application_fee_pence = calculate_application_fee_pence(
            task_amount_pence, task_source="flea_market_rental", task_type=None
        )

        try:
            from app.secure_auth import get_wechat_pay_payment_method_options
            payment_method_options = get_wechat_pay_payment_method_options(request_obj)
            create_pi_kw = {
                "amount": task_amount_pence,
                "currency": (item.currency or "GBP").lower(),
                "payment_method_types": ["card", "wechat_pay", "alipay"],
                "description": f"跳蚤市场租赁 #{new_task.id}: {item.title[:50]}",
                "metadata": {
                    "task_id": str(new_task.id),
                    "task_title": item.title[:200] if item.title else "",
                    "poster_id": str(rental_request.renter_id),
                    "poster_name": renter.name if renter else f"User {rental_request.renter_id}",
                    "taker_id": str(item.seller_id),
                    "taker_name": seller.name if seller else f"User {item.seller_id}",
                    "taker_stripe_account_id": taker_stripe_account_id,
                    "application_fee": str(application_fee_pence),
                    "task_amount": str(task_amount_pence),
                    "task_amount_display": f"{total_amount:.2f}",
                    "platform": "Link²Ur",
                    "payment_type": "flea_market_rental",
                    "flea_market_item_id": str(item.id),
                    "rental_request_id": str(rental_request.id),
                    "deposit_amount": str(int(float(deposit) * 100)),
                    "rent_amount": str(int(float(total_rent) * 100)),
                },
            }
            if payment_method_options:
                create_pi_kw["payment_method_options"] = payment_method_options
            payment_intent = stripe.PaymentIntent.create(**create_pi_kw)

            new_task.payment_intent_id = payment_intent.id
        except Exception as e:
            await db.rollback()
            logger.error(f"创建租赁 PaymentIntent 失败: {e}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="创建支付失败，请稍后重试"
            )

    await db.commit()

    # 创建 Stripe Customer + Ephemeral Key（用于前端支付 Sheet）
    if not is_free and payment_intent:
        try:
            from app.utils.stripe_utils import get_or_create_stripe_customer
            customer_id = get_or_create_stripe_customer(renter)
            if customer_id and renter and (not renter.stripe_customer_id or renter.stripe_customer_id != customer_id):
                await db.execute(
                    update(models.User)
                    .where(models.User.id == renter.id)
                    .values(stripe_customer_id=customer_id)
                )

            import stripe
            ephemeral_key = stripe.EphemeralKey.create(
                customer=customer_id,
                stripe_version="2025-01-27.acacia",
            )
            ephemeral_key_secret = ephemeral_key.secret
        except Exception as e:
            logger.warning(f"无法创建 Stripe Customer 或 Ephemeral Key: {e}")
            customer_id = None
            ephemeral_key_secret = None

    return {
        "task": new_task,
        "payment_intent": payment_intent,
        "customer_id": customer_id,
        "ephemeral_key_secret": ephemeral_key_secret,
        "total_rent": total_rent,
        "deposit": deposit,
        "total_amount": total_amount,
        "is_free": is_free,
    }


# ==================== 1. 提交租赁申请 ====================

@rental_router.post("/items/{item_id}/rental-request", response_model=dict)
async def create_rental_request(
    item_id: str,
    request_data: schemas.FleaMarketRentalRequestCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """提交租赁申请"""
    try:
        db_id = parse_flea_market_id(item_id)

        # 查询商品
        result = await db.execute(
            select(models.FleaMarketItem).where(models.FleaMarketItem.id == db_id)
        )
        item = result.scalar_one_or_none()

        if not item or not item.is_visible:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="商品不存在"
            )

        if item.listing_type != "rental":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="该商品不支持租赁"
            )

        if item.status != "active":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="该商品已下架或不可租赁"
            )

        if item.seller_id == current_user.id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="不能租赁自己的商品"
            )

        # 检查是否已有 pending/counter_offer 状态的申请
        existing = await db.execute(
            select(models.FleaMarketRentalRequest)
            .where(
                models.FleaMarketRentalRequest.item_id == db_id,
                models.FleaMarketRentalRequest.renter_id == current_user.id,
                models.FleaMarketRentalRequest.status.in_(["pending", "counter_offer", "approved"]),
            )
        )
        if existing.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="您已有进行中的租赁申请，请等待处理"
            )

        new_request = models.FleaMarketRentalRequest(
            item_id=db_id,
            renter_id=current_user.id,
            rental_duration=request_data.rental_duration,
            desired_time=request_data.desired_time,
            usage_description=request_data.usage_description,
            proposed_rental_price=request_data.proposed_rental_price,
            status="pending",
        )

        db.add(new_request)
        await db.commit()
        await db.refresh(new_request)

        # 发送通知给卖家
        renter_name = current_user.name or f"用户{current_user.id}"
        content_parts = [f"{renter_name} 申请租赁您的物品「{item.title}」"]
        content_parts.append(f"租期: {request_data.rental_duration} {item.rental_unit or 'day'}")
        if request_data.proposed_rental_price:
            content_parts.append(f"期望租金: {'€' if item.currency == 'EUR' else '£'}{float(request_data.proposed_rental_price):.2f}/{item.rental_unit or 'day'}")
        if request_data.usage_description:
            content_parts.append(f"用途: {request_data.usage_description}")

        await _send_rental_notification(
            db=db,
            user_id=item.seller_id,
            notification_type="flea_market_rental_request",
            title="新的租赁申请",
            content="\n".join(content_parts),
            related_id=str(item.id),
            push_data={"item_id": format_flea_market_id(item.id)},
            push_template_vars={
                "renter_name": renter_name,
                "item_title": item.title,
            },
        )

        return {
            "success": True,
            "data": {
                "rental_request_id": new_request.id,
                "status": "pending",
                "created_at": format_iso_utc(new_request.created_at),
            },
            "message": "租赁申请已提交，等待物主处理"
        }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"创建租赁申请失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="创建租赁申请失败"
        )


# ==================== 2. 获取商品的租赁申请列表 ====================

@rental_router.get("/items/{item_id}/rental-requests", response_model=dict)
async def get_rental_requests_for_item(
    item_id: str,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取商品的租赁申请列表（仅卖家可查看）"""
    try:
        db_id = parse_flea_market_id(item_id)

        result = await db.execute(
            select(models.FleaMarketItem).where(models.FleaMarketItem.id == db_id)
        )
        item = result.scalar_one_or_none()

        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="商品不存在"
            )

        if item.seller_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权限查看此商品的租赁申请"
            )

        # 懒惰过期检查
        await _expire_approved_rental_requests(db, db_id)

        # 查询租赁申请
        query = (
            select(models.FleaMarketRentalRequest)
            .where(models.FleaMarketRentalRequest.item_id == db_id)
            .order_by(models.FleaMarketRentalRequest.created_at.desc())
        )

        # 总数
        count_result = await db.execute(
            select(func.count()).select_from(query.subquery())
        )
        total = count_result.scalar() or 0

        # 分页
        skip = (page - 1) * page_size
        query = query.offset(skip).limit(page_size)
        result = await db.execute(query)
        requests = result.scalars().all()

        # 批量获取租客信息
        renter_ids = list({r.renter_id for r in requests})
        renter_info = {}
        if renter_ids:
            renter_result = await db.execute(
                select(models.User.id, models.User.name, models.User.avatar)
                .where(models.User.id.in_(renter_ids))
            )
            for row in renter_result.all():
                renter_info[row[0]] = {"name": row[1], "avatar": row[2]}

        items = []
        for r in requests:
            info = renter_info.get(r.renter_id, {})
            items.append(schemas.FleaMarketRentalRequestResponse(
                id=r.id,
                item_id=format_flea_market_id(r.item_id),
                renter_id=r.renter_id,
                renter_name=info.get("name"),
                renter_avatar=info.get("avatar"),
                rental_duration=r.rental_duration,
                desired_time=r.desired_time,
                usage_description=r.usage_description,
                proposed_rental_price=float(r.proposed_rental_price) if r.proposed_rental_price else None,
                counter_rental_price=float(r.counter_rental_price) if r.counter_rental_price else None,
                status=r.status,
                created_at=format_iso_utc(r.created_at),
                updated_at=format_iso_utc(r.updated_at),
            ))

        return {
            "success": True,
            "data": {
                "items": [item.model_dump() for item in items],
                "page": page,
                "pageSize": page_size,
                "total": total,
                "hasMore": (page * page_size) < total,
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取租赁申请列表失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取租赁申请列表失败"
        )


# ==================== 3. 物主批准租赁申请 ====================

@rental_router.post("/rental-requests/{request_id}/approve", response_model=dict)
async def approve_rental_request(
    request_id: int,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """物主批准租赁申请"""
    try:
        # 查询租赁申请（FOR UPDATE）
        req_result = await db.execute(
            select(models.FleaMarketRentalRequest)
            .where(models.FleaMarketRentalRequest.id == request_id)
            .with_for_update()
        )
        rental_request = req_result.scalar_one_or_none()

        if not rental_request:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="租赁申请不存在"
            )

        if rental_request.status != "pending":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="该申请已被处理"
            )

        # 查询商品
        item_result = await db.execute(
            select(models.FleaMarketItem)
            .where(models.FleaMarketItem.id == rental_request.item_id)
            .with_for_update()
        )
        item = item_result.scalar_one_or_none()

        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="商品不存在"
            )

        if item.seller_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权限操作此申请"
            )

        # 审批使用商品标价（租客建议价仅供参考，接受建议价需走还价流程）
        rental_price = item.rental_price

        # 获取租客信息
        renter = await db.get(models.User, rental_request.renter_id)
        if not renter:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="租客不存在"
            )

        result = await _create_rental_task_and_payment(
            db=db,
            request_obj=request,
            item=item,
            rental_request=rental_request,
            rental_price=rental_price,
            renter=renter,
        )

        # 通知租客
        renter_name = renter.name or f"用户{renter.id}"
        await _send_rental_notification(
            db=db,
            user_id=rental_request.renter_id,
            notification_type="flea_market_rental_approved",
            title="租赁申请已通过",
            content=f"您的租赁申请已被通过！\n物品: {item.title}\n"
                    f"总租金: {'€' if item.currency == 'EUR' else '£'}{float(result['total_rent']):.2f}\n"
                    f"押金: {'€' if item.currency == 'EUR' else '£'}{float(result['deposit']):.2f}\n"
                    f"总计: {'€' if item.currency == 'EUR' else '£'}{float(result['total_amount']):.2f}\n"
                    f"请在24小时内完成支付。",
            related_id=str(item.id),
            push_data={"item_id": format_flea_market_id(item.id)},
            push_template_vars={"item_title": item.title},
        )

        if result["is_free"]:
            return {
                "success": True,
                "data": {
                    "task_id": str(result["task"].id),
                    "status": "approved",
                    "is_free": True,
                },
                "message": "租赁申请已通过（免费租赁）"
            }

        pi = result["payment_intent"]
        return {
            "success": True,
            "data": {
                "task_id": str(result["task"].id),
                "status": "approved",
                "client_secret": pi.client_secret if pi else None,
                "amount": pi.amount if pi else None,
                "deposit_amount": int(float(result["deposit"]) * 100),
                "rent_amount": int(float(result["total_rent"]) * 100),
                "currency": pi.currency.upper() if pi else "GBP",
                "customer_id": result["customer_id"],
                "ephemeral_key_secret": result["ephemeral_key_secret"],
                "payment_expires_at": result["task"].payment_expires_at.isoformat() if result["task"].payment_expires_at else None,
            },
            "message": "租赁申请已通过，请租客完成支付"
        }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"批准租赁申请失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="批准租赁申请失败"
        )


# ==================== 4. 物主拒绝租赁申请 ====================

@rental_router.post("/rental-requests/{request_id}/reject", response_model=dict)
async def reject_rental_request(
    request_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """物主拒绝租赁申请"""
    try:
        req_result = await db.execute(
            select(models.FleaMarketRentalRequest)
            .where(models.FleaMarketRentalRequest.id == request_id)
        )
        rental_request = req_result.scalar_one_or_none()

        if not rental_request:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="租赁申请不存在"
            )

        if rental_request.status != "pending":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="该申请已被处理"
            )

        # 权限：物主
        item_result = await db.execute(
            select(models.FleaMarketItem).where(models.FleaMarketItem.id == rental_request.item_id)
        )
        item = item_result.scalar_one_or_none()

        if not item or item.seller_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权限操作此申请"
            )

        await db.execute(
            update(models.FleaMarketRentalRequest)
            .where(models.FleaMarketRentalRequest.id == request_id)
            .values(status="rejected")
        )
        await db.commit()

        # 通知租客
        await _send_rental_notification(
            db=db,
            user_id=rental_request.renter_id,
            notification_type="flea_market_rental_rejected",
            title="租赁申请被拒绝",
            content=f"您对物品「{item.title}」的租赁申请已被物主拒绝。",
            related_id=str(item.id),
            push_data={"item_id": format_flea_market_id(item.id)},
            push_template_vars={"item_title": item.title},
        )

        return {
            "success": True,
            "data": {"status": "rejected"},
            "message": "租赁申请已拒绝"
        }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"拒绝租赁申请失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="拒绝租赁申请失败"
        )


# ==================== 5. 物主还价 ====================

@rental_router.post("/rental-requests/{request_id}/counter-offer", response_model=dict)
async def counter_offer_rental_request(
    request_id: int,
    counter_rental_price: Decimal = Body(..., embed=True),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """物主对租赁申请还价"""
    try:
        req_result = await db.execute(
            select(models.FleaMarketRentalRequest)
            .where(models.FleaMarketRentalRequest.id == request_id)
        )
        rental_request = req_result.scalar_one_or_none()

        if not rental_request:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="租赁申请不存在"
            )

        if rental_request.status != "pending":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="该申请状态不允许还价"
            )

        item_result = await db.execute(
            select(models.FleaMarketItem).where(models.FleaMarketItem.id == rental_request.item_id)
        )
        item = item_result.scalar_one_or_none()

        if not item or item.seller_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权限操作此申请"
            )

        await db.execute(
            update(models.FleaMarketRentalRequest)
            .where(models.FleaMarketRentalRequest.id == request_id)
            .values(
                status="counter_offer",
                counter_rental_price=counter_rental_price,
            )
        )
        await db.commit()

        # 通知租客
        await _send_rental_notification(
            db=db,
            user_id=rental_request.renter_id,
            notification_type="flea_market_rental_counter_offer",
            title="租赁还价",
            content=f"物主对您租赁「{item.title}」的申请进行了还价。\n还价租金: {'€' if item.currency == 'EUR' else '£'}{float(counter_rental_price):.2f}/{item.rental_unit or 'day'}",
            related_id=str(item.id),
            push_data={"item_id": format_flea_market_id(item.id)},
            push_template_vars={"item_title": item.title},
        )

        return {
            "success": True,
            "data": {
                "status": "counter_offer",
                "counter_rental_price": float(counter_rental_price),
            },
            "message": "还价已发送，等待租客回应"
        }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"租赁还价失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="租赁还价失败"
        )


# ==================== 6. 租客回应还价 ====================

@rental_router.post("/rental-requests/{request_id}/respond-counter-offer", response_model=dict)
async def respond_rental_counter_offer(
    request_id: int,
    accept: bool = Body(..., embed=True),
    request: Request = None,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """租客回应物主的还价"""
    try:
        req_result = await db.execute(
            select(models.FleaMarketRentalRequest)
            .where(models.FleaMarketRentalRequest.id == request_id)
            .with_for_update()
        )
        rental_request = req_result.scalar_one_or_none()

        if not rental_request:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="租赁申请不存在"
            )

        if rental_request.renter_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权限操作此申请"
            )

        if rental_request.status != "counter_offer":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="该申请状态不允许此操作"
            )

        if not accept:
            # 拒绝还价
            await db.execute(
                update(models.FleaMarketRentalRequest)
                .where(models.FleaMarketRentalRequest.id == request_id)
                .values(status="rejected")
            )
            await db.commit()
            return {
                "success": True,
                "data": {"status": "rejected"},
                "message": "已拒绝还价"
            }

        # 接受还价 → 走批准流程
        item_result = await db.execute(
            select(models.FleaMarketItem)
            .where(models.FleaMarketItem.id == rental_request.item_id)
            .with_for_update()
        )
        item = item_result.scalar_one_or_none()

        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="商品不存在"
            )

        rental_price = rental_request.counter_rental_price or item.rental_price

        result = await _create_rental_task_and_payment(
            db=db,
            request_obj=request,
            item=item,
            rental_request=rental_request,
            rental_price=rental_price,
            renter=current_user,
        )

        # 通知物主
        await _send_rental_notification(
            db=db,
            user_id=item.seller_id,
            notification_type="flea_market_rental_counter_accepted",
            title="租客接受了您的还价",
            content=f"租客接受了您对「{item.title}」的租赁还价，等待支付。",
            related_id=str(item.id),
            push_data={"item_id": format_flea_market_id(item.id)},
            push_template_vars={"item_title": item.title},
        )

        if result["is_free"]:
            return {
                "success": True,
                "data": {
                    "task_id": str(result["task"].id),
                    "status": "approved",
                    "is_free": True,
                },
                "message": "还价已接受（免费租赁）"
            }

        pi = result["payment_intent"]
        return {
            "success": True,
            "data": {
                "task_id": str(result["task"].id),
                "status": "approved",
                "client_secret": pi.client_secret if pi else None,
                "amount": pi.amount if pi else None,
                "deposit_amount": int(float(result["deposit"]) * 100),
                "rent_amount": int(float(result["total_rent"]) * 100),
                "currency": pi.currency.upper() if pi else "GBP",
                "customer_id": result["customer_id"],
                "ephemeral_key_secret": result["ephemeral_key_secret"],
                "payment_expires_at": result["task"].payment_expires_at.isoformat() if result["task"].payment_expires_at else None,
            },
            "message": "还价已接受，请完成支付"
        }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"回应租赁还价失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="回应租赁还价失败"
        )


# ==================== 7.5 租客确认已归还 ====================

@rental_router.post("/rentals/{rental_id}/renter-confirm-return", response_model=dict)
async def renter_confirm_return(
    rental_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """租客确认已归还物品，状态变为 pending_return，等待物主确认"""
    try:
        rental_result = await db.execute(
            select(models.FleaMarketRental)
            .where(models.FleaMarketRental.id == rental_id)
            .with_for_update()
        )
        rental = rental_result.scalar_one_or_none()

        if not rental:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="租赁记录不存在"
            )

        # 权限：租客
        if rental.renter_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权限操作此租赁"
            )

        if rental.status not in ("active", "overdue"):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="该租赁状态不支持确认归还"
            )

        now = get_utc_time()

        await db.execute(
            update(models.FleaMarketRental)
            .where(models.FleaMarketRental.id == rental_id)
            .values(status="pending_return")
        )
        await db.commit()

        # 获取物品信息用于通知
        item_result = await db.execute(
            select(models.FleaMarketItem).where(models.FleaMarketItem.id == rental.item_id)
        )
        item = item_result.scalar_one_or_none()

        # 通知物主：租客已确认归还
        if item:
            await _send_rental_notification(
                db=db,
                user_id=item.seller_id,
                notification_type="flea_market_rental_pending_return",
                title="租客已确认归还",
                content=f"租客已确认归还物品「{item.title}」，请检查物品后确认归还。",
                related_id=str(rental.id),
                push_data={"rental_id": str(rental.id), "item_id": format_flea_market_id(item.id)},
                push_template_vars={"item_title": item.title},
            )

        return {
            "success": True,
            "data": {
                "status": "pending_return",
            },
            "message": "已确认归还，等待出租人确认"
        }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"租客确认归还失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="确认归还失败"
        )


# ==================== 8. 物主确认归还 ====================

@rental_router.post("/rentals/{rental_id}/confirm-return", response_model=dict)
async def confirm_rental_return(
    rental_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """物主确认物品归还并退还押金"""
    try:
        rental_result = await db.execute(
            select(models.FleaMarketRental)
            .where(models.FleaMarketRental.id == rental_id)
            .with_for_update()
        )
        rental = rental_result.scalar_one_or_none()

        if not rental:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="租赁记录不存在"
            )

        if rental.status != "pending_return":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="该租赁状态不支持确认归还，需要租客先确认归还"
            )

        # 权限：物主
        item_result = await db.execute(
            select(models.FleaMarketItem).where(models.FleaMarketItem.id == rental.item_id)
        )
        item = item_result.scalar_one_or_none()

        if not item or item.seller_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权限操作此租赁"
            )

        now = get_utc_time()

        # 退还押金（Stripe Partial Refund）
        stripe_refund_id = None
        deposit_pence = int(float(rental.deposit_amount) * 100)
        if deposit_pence > 0 and rental.task_id:
            try:
                task = await db.get(models.Task, rental.task_id)
                if task and task.payment_intent_id:
                    import stripe
                    refund = stripe.Refund.create(
                        payment_intent=task.payment_intent_id,
                        amount=deposit_pence,
                    )
                    stripe_refund_id = refund.id
                    logger.info(f"租赁 {rental_id} 押金退款成功: {stripe_refund_id}, amount={deposit_pence}")
            except Exception as e:
                logger.error(f"租赁 {rental_id} 押金退款失败: {e}", exc_info=True)
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="押金退款失败，请稍后重试"
                )

        # 租金入账到物主钱包
        wallet_credited = False
        rent_amount = float(rental.total_rent)
        if rent_amount > 0:
            try:
                def _credit_rent(sync_session):
                    from app.wallet_service import credit_wallet
                    credit_wallet(
                        db=sync_session,
                        user_id=current_user.id,
                        amount=Decimal(str(rental.total_rent)),
                        source="flea_market_rental",
                        related_id=str(rental.id),
                        related_type="rental",
                        description=f"租赁 #{rental.id} 租金收入 — {item.title}",
                        currency=rental.currency or item.currency or "GBP",
                        idempotency_key=f"earning:rental:{rental.id}:owner:{current_user.id}",
                    )

                await db.run_sync(_credit_rent)
                wallet_credited = True
                logger.info(f"租赁 {rental_id} 租金 {rent_amount} 已入账物主钱包")
            except Exception as e:
                logger.error(f"租赁 {rental_id} 租金入账失败: {e}", exc_info=True)
                # 租金入账失败不阻塞归还流程，记录错误继续

        # 更新租赁记录
        update_values = {
            "status": "returned",
            "returned_at": now,
            "deposit_status": "refunded" if stripe_refund_id else "held",
        }
        if stripe_refund_id:
            update_values["stripe_refund_id"] = stripe_refund_id

        await db.execute(
            update(models.FleaMarketRental)
            .where(models.FleaMarketRental.id == rental_id)
            .values(**update_values)
        )
        await db.commit()

        # 通知租客
        rent_msg = f"\n租金 {'€' if (rental.currency or item.currency) == 'EUR' else '£'}{rent_amount:.2f} 已入账出租人钱包。" if wallet_credited else ""
        await _send_rental_notification(
            db=db,
            user_id=rental.renter_id,
            notification_type="flea_market_rental_returned",
            title="物品归还确认",
            content=f"物主已确认物品「{item.title}」归还。"
                    + (f"\n押金 {'€' if (rental.currency or item.currency) == 'EUR' else '£'}{float(rental.deposit_amount):.2f} 已退还。" if stripe_refund_id else "")
                    + rent_msg,
            related_id=str(rental.id),
            push_data={"rental_id": str(rental.id), "item_id": format_flea_market_id(item.id)},
            push_template_vars={"item_title": item.title},
        )

        return {
            "success": True,
            "data": {
                "status": "returned",
                "deposit_status": "refunded" if stripe_refund_id else "held",
                "stripe_refund_id": stripe_refund_id,
                "wallet_credited": wallet_credited,
                "rent_credited": rent_amount if wallet_credited else 0,
            },
            "message": "归还确认成功" + ("，押金已退还" if stripe_refund_id else "") + ("，租金已入账" if wallet_credited else "")
        }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"确认归还失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="确认归还失败"
        )


# ==================== 9. 租赁详情 ====================

@rental_router.get("/rentals/{rental_id}", response_model=dict)
async def get_rental_detail(
    rental_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取租赁详情"""
    try:
        rental_result = await db.execute(
            select(models.FleaMarketRental)
            .where(models.FleaMarketRental.id == rental_id)
        )
        rental = rental_result.scalar_one_or_none()

        if not rental:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="租赁记录不存在"
            )

        # 权限：租客或物主
        item_result = await db.execute(
            select(models.FleaMarketItem).where(models.FleaMarketItem.id == rental.item_id)
        )
        item = item_result.scalar_one_or_none()

        if rental.renter_id != current_user.id and (not item or item.seller_id != current_user.id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权限查看此租赁"
            )

        # 获取租客信息
        renter_result = await db.execute(
            select(models.User.name, models.User.avatar)
            .where(models.User.id == rental.renter_id)
        )
        renter_row = renter_result.one_or_none()

        rental_data = schemas.FleaMarketRentalResponse(
            id=rental.id,
            item_id=format_flea_market_id(rental.item_id),
            renter_id=rental.renter_id,
            renter_name=renter_row[0] if renter_row else None,
            renter_avatar=renter_row[1] if renter_row else None,
            rental_duration=rental.rental_duration,
            rental_unit=rental.rental_unit,
            total_rent=float(rental.total_rent),
            deposit_amount=float(rental.deposit_amount),
            total_paid=float(rental.total_paid),
            currency=rental.currency,
            start_date=format_iso_utc(rental.start_date),
            end_date=format_iso_utc(rental.end_date),
            status=rental.status,
            deposit_status=rental.deposit_status,
            returned_at=format_iso_utc(rental.returned_at) if rental.returned_at else None,
            created_at=format_iso_utc(rental.created_at),
        )

        # 附带商品信息
        item_info = None
        if item:
            images = []
            if item.images:
                try:
                    images = json.loads(item.images)
                except Exception:
                    images = []
            item_info = {
                "id": format_flea_market_id(item.id),
                "title": item.title,
                "images": images,
                "seller_id": item.seller_id,
            }

        return {
            "success": True,
            "data": {
                "rental": rental_data.model_dump(),
                "item": item_info,
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取租赁详情失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取租赁详情失败"
        )


# ==================== 10. 我的租赁列表 ====================

@rental_router.get("/my-rentals", response_model=dict)
async def get_my_rentals(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取当前用户的租赁列表（作为租客）"""
    try:
        query = (
            select(models.FleaMarketRental)
            .where(models.FleaMarketRental.renter_id == current_user.id)
            .order_by(models.FleaMarketRental.created_at.desc())
        )

        count_result = await db.execute(
            select(func.count()).select_from(query.subquery())
        )
        total = count_result.scalar() or 0

        skip = (page - 1) * page_size
        query = query.offset(skip).limit(page_size)
        result = await db.execute(query)
        rentals = result.scalars().all()

        # 批量获取商品信息
        item_ids = list({r.item_id for r in rentals})
        item_info_map = {}
        if item_ids:
            items_result = await db.execute(
                select(models.FleaMarketItem.id, models.FleaMarketItem.title, models.FleaMarketItem.images, models.FleaMarketItem.seller_id)
                .where(models.FleaMarketItem.id.in_(item_ids))
            )
            for row in items_result.all():
                images = []
                if row[2]:
                    try:
                        images = json.loads(row[2])
                    except Exception:
                        images = []
                item_info_map[row[0]] = {
                    "id": format_flea_market_id(row[0]),
                    "title": row[1],
                    "images": images,
                    "seller_id": row[3],
                }

        items = []
        for r in rentals:
            items.append({
                "rental": schemas.FleaMarketRentalResponse(
                    id=r.id,
                    item_id=format_flea_market_id(r.item_id),
                    renter_id=r.renter_id,
                    rental_duration=r.rental_duration,
                    rental_unit=r.rental_unit,
                    total_rent=float(r.total_rent),
                    deposit_amount=float(r.deposit_amount),
                    total_paid=float(r.total_paid),
                    currency=r.currency,
                    start_date=format_iso_utc(r.start_date),
                    end_date=format_iso_utc(r.end_date),
                    status=r.status,
                    deposit_status=r.deposit_status,
                    returned_at=format_iso_utc(r.returned_at) if r.returned_at else None,
                    created_at=format_iso_utc(r.created_at),
                ).model_dump(),
                "item": item_info_map.get(r.item_id),
            })

        return {
            "success": True,
            "data": {
                "items": items,
                "page": page,
                "pageSize": page_size,
                "total": total,
                "hasMore": (page * page_size) < total,
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取我的租赁列表失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取我的租赁列表失败"
        )
