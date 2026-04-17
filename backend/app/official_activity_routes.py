"""
用户端 - 官方/达人活动报名 / 取消 / 结果
"""
import logging
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

import stripe
from app import models, schemas
from app.deps import get_async_db_dependency
from app.utils import get_utc_time
from app.stripe_config import stripe as _stripe_configured  # noqa: F401 — sets stripe.api_key

logger = logging.getLogger(__name__)

official_activity_router = APIRouter(
    prefix="/api/official-activities",
    tags=["official-activities"],
)


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


@official_activity_router.post("/{activity_id}/apply", response_model=dict)
async def apply_official_activity(
    activity_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """报名活动（抽奖/抢位均用此接口）。

    免费活动：直接创建 application。
    付费活动：创建 Stripe PaymentIntent，返回 client_secret，
              webhook 确认后自动创建 application。
    """
    result = await db.execute(
        select(models.Activity).where(
            models.Activity.id == activity_id,
            models.Activity.activity_type.in_(["lottery", "first_come"]),
            models.Activity.status == "open",
        )
    )
    activity = result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="活动不存在或已结束")

    # ── Clean up refunded records so UniqueConstraint doesn't block re-apply ──
    refunded_result = await db.execute(
        select(models.OfficialActivityApplication).where(
            models.OfficialActivityApplication.activity_id == activity_id,
            models.OfficialActivityApplication.user_id == current_user.id,
            models.OfficialActivityApplication.status == 'refunded',
        )
    )
    for refunded_app in refunded_result.scalars().all():
        await db.delete(refunded_app)
    # Flush deletes before checking for active applications
    await db.flush()

    # ── Check for existing active application ──
    existing = await db.execute(
        select(models.OfficialActivityApplication).where(
            models.OfficialActivityApplication.activity_id == activity_id,
            models.OfficialActivityApplication.user_id == current_user.id,
        )
    )
    existing_app = existing.scalar_one_or_none()

    # Idempotent: if payment_pending exists, return existing PI client_secret
    if existing_app and existing_app.status == 'payment_pending' and existing_app.payment_intent_id:
        try:
            pi = stripe.PaymentIntent.retrieve(existing_app.payment_intent_id)
            if pi.status in ('requires_payment_method', 'requires_confirmation', 'requires_action'):
                return {
                    "success": True,
                    "requires_payment": True,
                    "client_secret": pi.client_secret,
                    "payment_intent_id": pi.id,
                    "amount": pi.amount,
                    "currency": (activity.currency or "GBP").upper(),
                }
        except Exception:
            pass  # PI expired/invalid, clean up and create new
        await db.delete(existing_app)
        await db.commit()
        existing_app = None

    if existing_app:
        raise HTTPException(status_code=400, detail="您已报名此活动")

    price_pence = int(round(float(activity.original_price_per_participant or 0) * 100))
    is_paid = price_pence > 0

    # ── FREE activity: create application immediately ──
    if not is_paid:
        if activity.activity_type == "first_come":
            count_result = await db.execute(
                select(func.count()).select_from(models.OfficialActivityApplication).where(
                    models.OfficialActivityApplication.activity_id == activity_id,
                    models.OfficialActivityApplication.status == "attending",
                )
            )
            if (count_result.scalar() or 0) >= (activity.prize_count or 0):
                raise HTTPException(status_code=400, detail="名额已满")
            app_status = "attending"
        else:
            app_status = "pending"

        application = models.OfficialActivityApplication(
            activity_id=activity_id,
            user_id=current_user.id,
            status=app_status,
        )
        db.add(application)
        await db.commit()

        await _check_by_count_trigger(db, activity, activity_id)

        return {
            "success": True,
            "requires_payment": False,
            "status": app_status,
            "message": "报名成功，等待开奖" if app_status == "pending" else "报名成功！",
        }

    # ── PAID activity: create Stripe PaymentIntent ──
    from app.utils.fee_calculator import calculate_application_fee_pence
    application_fee_pence = calculate_application_fee_pence(
        price_pence, task_source="expert_activity", task_type=activity.task_type,
    )

    # Stripe Customer + EphemeralKey (best-effort, fallback to guest)
    customer_id = None
    ephemeral_key_secret = None
    try:
        from app.utils.stripe_utils import get_or_create_stripe_customer
        import asyncio
        customer_id = await asyncio.get_event_loop().run_in_executor(
            None, lambda: get_or_create_stripe_customer(current_user)
        )
        ek = stripe.EphemeralKey.create(
            customer=customer_id, stripe_version="2025-01-27.acacia",
        )
        ephemeral_key_secret = ek.secret
    except Exception as e:
        logger.warning(f"Stripe Customer/EphemeralKey failed: {e}")
        customer_id = None
        ephemeral_key_secret = None

    create_kw = {
        "amount": price_pence,
        "currency": (activity.currency or "GBP").lower(),
        "payment_method_types": ["card"],
        "metadata": {
            "activity_id": str(activity.id),
            "user_id": str(current_user.id),
            "activity_apply": "true",
            "application_fee": str(application_fee_pence),
            "expert_id": activity.owner_id or "",
            "expert_user_id": activity.expert_id or "",
        },
        "description": f"活动报名 #{activity.id} - {activity.title}",
    }
    if customer_id:
        create_kw["customer"] = customer_id

    payment_intent = stripe.PaymentIntent.create(**create_kw)

    application = models.OfficialActivityApplication(
        activity_id=activity_id,
        user_id=current_user.id,
        status="payment_pending",
        payment_intent_id=payment_intent.id,
        amount_paid=price_pence,
    )
    db.add(application)
    await db.commit()

    return {
        "success": True,
        "requires_payment": True,
        "client_secret": payment_intent.client_secret,
        "payment_intent_id": payment_intent.id,
        "amount": price_pence,
        "currency": (activity.currency or "GBP").upper(),
        "customer_id": customer_id,
        "ephemeral_key_secret": ephemeral_key_secret,
    }


async def _check_by_count_trigger(db: AsyncSession, activity, activity_id: int):
    """Check and trigger by_count auto-draw if threshold reached."""
    if not (
        activity.activity_type == "lottery"
        and activity.draw_mode == "auto"
        and activity.draw_trigger in ("by_count", "both")
        and not activity.is_drawn
        and activity.draw_participant_count
    ):
        return

    count_result = await db.execute(
        select(func.count()).select_from(models.OfficialActivityApplication).where(
            models.OfficialActivityApplication.activity_id == activity_id,
            models.OfficialActivityApplication.status == "pending",
        )
    )
    if (count_result.scalar() or 0) < activity.draw_participant_count:
        return

    locked_result = await db.execute(
        select(models.Activity).where(models.Activity.id == activity_id).with_for_update()
    )
    locked_activity = locked_result.scalar_one_or_none()
    if locked_activity and not locked_activity.is_drawn:
        from app.draw_logic import perform_draw_async
        try:
            await perform_draw_async(db, locked_activity)
        except Exception:
            logger.error(f"by_count auto-draw failed for activity {activity_id}", exc_info=True)


@official_activity_router.delete("/{activity_id}/apply", response_model=dict)
async def cancel_official_activity_application(
    activity_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """取消报名（截止前可取消）"""
    result = await db.execute(
        select(models.OfficialActivityApplication).where(
            models.OfficialActivityApplication.activity_id == activity_id,
            models.OfficialActivityApplication.user_id == current_user.id,
        )
    )
    application = result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="未找到报名记录")
    if application.status in ("won", "lost"):
        raise HTTPException(status_code=400, detail="已开奖，无法取消")

    await db.delete(application)
    await db.commit()
    return {"success": True}


@official_activity_router.get("/{activity_id}/result", response_model=schemas.OfficialActivityResultOut)
async def get_official_activity_result(
    activity_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """查看开奖结果（含我的状态）"""
    act_result = await db.execute(
        select(models.Activity).where(models.Activity.id == activity_id)
    )
    activity = act_result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="活动不存在")

    my_app_result = await db.execute(
        select(models.OfficialActivityApplication).where(
            models.OfficialActivityApplication.activity_id == activity_id,
            models.OfficialActivityApplication.user_id == current_user.id,
        )
    )
    my_app = my_app_result.scalar_one_or_none()

    my_voucher = None
    if my_app and my_app.status == "won" and my_app.prize_index is not None:
        codes = activity.voucher_codes or []
        if my_app.prize_index < len(codes):
            my_voucher = codes[my_app.prize_index]

    winners = []
    if activity.winners:
        winners = [
            schemas.ActivityWinner(
                user_id=w["user_id"],
                name=w["name"],
                prize_index=w.get("prize_index"),
            )
            for w in activity.winners
        ]

    return schemas.OfficialActivityResultOut(
        is_drawn=activity.is_drawn,
        drawn_at=activity.drawn_at,
        winners=winners,
        my_status=my_app.status if my_app else None,
        my_voucher_code=my_voucher,
    )
