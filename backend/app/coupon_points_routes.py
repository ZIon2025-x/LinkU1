"""
优惠券和积分系统 API 路由
"""
import logging
from typing import Optional
from datetime import datetime, date, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.orm import Session
from datetime import timedelta

from app import schemas
from app import crud
from app.utils.time_utils import get_utc_time
from app.deps import get_db, get_current_user_secure_sync_csrf
from app.coupon_points_crud import (
    get_points_account,
    get_or_create_points_account,
    add_points_transaction,
    get_points_transactions,
    get_available_coupons,
    get_user_coupons,
    claim_coupon,
    validate_coupon_usage,
    use_coupon,
    get_check_in_today,
    get_last_check_in,
    check_in,
    validate_invitation_code,
    use_invitation_code,
    get_coupon_by_id,
    get_coupon_by_code,
)
from app import models
from app.rate_limiting import rate_limit

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/coupon-points", tags=["优惠券和积分系统"])


# ==================== 积分相关 API ====================

@router.get("/points/account", response_model=schemas.PointsAccountOut)
def get_account_info(
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """获取积分账户信息"""
    from sqlalchemy import func, and_, or_
    from decimal import Decimal
    
    account = get_or_create_points_account(db, current_user.id)
    
    # 格式化显示
    balance_display = f"{account.balance / 100:.2f}"
    
    # 计算累计获得（仅现金收入：用户作为接受人收到的 Stripe 转账）
    # 从 PaymentTransfer 表统计：taker_id=当前用户
    # 包含 succeeded（API 成功即标记）和 历史遗留的 pending 且 transfer_id 非空（Stripe 已转出）
    task_earnings_decimal = db.query(
        func.sum(models.PaymentTransfer.amount).label('total')
    ).filter(
        models.PaymentTransfer.taker_id == current_user.id,
        or_(
            models.PaymentTransfer.status == 'succeeded',
            and_(
                models.PaymentTransfer.status == 'pending',
                models.PaymentTransfer.transfer_id.isnot(None)
            )
        )
    ).scalar() or Decimal('0.0')
    
    # 将英镑转换为便士（乘以 100）
    total_earned_pence = int(task_earnings_decimal * 100)
    
    # 计算累计消费（所有支出来源）
    # 1. 任务支付：用户作为发布人支付的金额（Stripe支付）
    # PaymentHistory.final_amount 已经是便士单位（BigInteger）
    task_payments = db.query(
        func.sum(models.PaymentHistory.final_amount).label('total')
    ).filter(
        and_(
            models.PaymentHistory.user_id == current_user.id,
            models.PaymentHistory.status == 'succeeded'
        )
    ).scalar() or 0
    
    # 2. 积分消费（从积分交易记录中统计，含 coupon_redeem 与 crud 一致）
    # PointsTransaction.amount 已经是便士单位
    points_spent = db.query(
        func.sum(func.abs(models.PointsTransaction.amount)).label('total')
    ).filter(
        and_(
            models.PointsTransaction.user_id == current_user.id,
            models.PointsTransaction.type.in_(['spend', 'expire', 'coupon_redeem'])
        )
    ).scalar() or 0
    
    # 累计消费 = 任务支付（便士）+ 积分消费（便士）
    # 确保为 int（DB sum 可能返回 Decimal）
    total_spent_pence = int((task_payments or 0) + (points_spent or 0))
    
    return {
        "balance": account.balance,
        "balance_display": balance_display,
        "currency": account.currency,
        "total_earned": total_earned_pence,
        "total_spent": total_spent_pence,
        "usage_restrictions": {
            "allowed": [
                "抵扣申请费（任务发布费）",
                "兑换自营商品",
                "兑换折扣券"
            ],
            "forbidden": [
                "转账",
                "提现",
                "作为用户奖励支付给服务者"
            ]
        }
    }


@router.get("/points/transactions", response_model=schemas.PointsTransactionList)
def get_transactions(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """获取积分交易记录"""
    skip = (page - 1) * limit
    transactions, total = get_points_transactions(db, current_user.id, skip, limit)
    
    # 格式化显示
    data = []
    for t in transactions:
        amount_display = f"{abs(t.amount) / 100:.2f}"
        balance_display = f"{t.balance_after / 100:.2f}"
        data.append({
            "id": t.id,
            "type": t.type,
            "amount": t.amount,
            "amount_display": amount_display,
            "balance_after": t.balance_after,
            "balance_after_display": balance_display,
            "currency": t.currency,
            "source": t.source,
            "description": t.description,
            "batch_id": t.batch_id,
            "created_at": t.created_at
        })
    
    return {
        "total": total,
        "page": page,
        "limit": limit,
        "data": data
    }


@router.post("/points/redeem/coupon")
def redeem_coupon(
    request: schemas.PointsRedeemCouponRequest,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """积分兑换优惠券"""
    # 1. 获取优惠券信息
    coupon = get_coupon_by_id(db, request.coupon_id)
    if not coupon:
        raise HTTPException(status_code=404, detail="优惠券不存在")
    
    # 2. 检查优惠券是否可以用积分兑换
    usage_conditions = coupon.usage_conditions or {}
    points_required = usage_conditions.get("points_required", 0)
    
    if points_required <= 0:
        raise HTTPException(status_code=400, detail="该优惠券不支持积分兑换")
    
    # 3. 检查优惠券是否有效
    now = get_utc_time()
    if coupon.status != "active":
        raise HTTPException(status_code=400, detail="优惠券已失效")
    if coupon.valid_from > now or coupon.valid_until < now:
        raise HTTPException(status_code=400, detail="优惠券不在有效期内")
    
    # 4. 获取用户积分账户
    points_account = get_or_create_points_account(db, current_user.id)
    if points_account.balance < points_required:
        raise HTTPException(
            status_code=400, 
            detail=f"积分不足，需要 {points_required} 积分，当前余额 {points_account.balance} 积分"
        )
    
    # 5. 领取优惠券
    user_coupon, claim_error = claim_coupon(
        db,
        current_user.id,
        coupon.id,
        idempotency_key=request.idempotency_key
    )
    
    if not user_coupon:
        raise HTTPException(status_code=400, detail=claim_error or "领取失败，请检查优惠券是否可用或已达到领取限制")
    
    # 6. 扣除积分（使用幂等键防止重复扣除）
    from app.utils.time_utils import get_utc_time
    import uuid
    redeem_idempotency_key = request.idempotency_key or f"coupon_redeem_{current_user.id}_{request.coupon_id}_{uuid.uuid4()}"
    add_points_transaction(
        db,
        current_user.id,
        type="coupon_redeem",
        amount=-points_required,
        source="coupon_redeem",
        related_id=request.coupon_id,
        related_type="coupon",
        description=f"积分兑换优惠券: {coupon.name}",
        idempotency_key=redeem_idempotency_key
    )
    
    return {
        "success": True,
        "user_coupon_id": user_coupon.id,
        "coupon_id": coupon.id,
        "points_used": points_required,
        "message": f"兑换成功！已使用 {points_required} 积分"
    }


@router.post("/points/redeem/product")
def redeem_product(
    request: schemas.PointsRedeemProductRequest,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """积分兑换自营商品"""
    # TODO: 实现积分兑换自营商品逻辑
    raise HTTPException(status_code=501, detail="功能开发中")


# ==================== 优惠券相关 API ====================

@router.get("/coupons/available", response_model=schemas.CouponList)
def get_available_coupons_list(
    current_user: Optional[models.User] = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """获取可用优惠券列表"""
    coupons = get_available_coupons(db, current_user.id if current_user else None)
    
    data = []
    for coupon in coupons:
        discount_value_display = f"{coupon.discount_value / 100:.2f}"
        min_amount_display = f"{coupon.min_amount / 100:.2f}"
        data.append({
            "id": coupon.id,
            "code": coupon.code,
            "name": coupon.name,
            "type": coupon.type,
            "discount_value": coupon.discount_value,
            "discount_value_display": discount_value_display,
            "min_amount": coupon.min_amount,
            "min_amount_display": min_amount_display,
            "currency": coupon.currency,
            "valid_until": coupon.valid_until,
            "usage_conditions": coupon.usage_conditions,
            "eligibility_type": getattr(coupon, "eligibility_type", None),
            "per_user_per_month_limit": getattr(coupon, "per_user_per_month_limit", None),
            "per_user_limit_window": getattr(coupon, "per_user_limit_window", None),
            "per_user_per_window_limit": getattr(coupon, "per_user_per_window_limit", None),
        })
    
    return {"data": data}


@router.post("/coupons/claim")
def claim_coupon_api(
    request: schemas.CouponClaimRequest,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """领取优惠券（支持优惠券ID或兑换码）"""
    promotion_code_id = None
    
    if request.coupon_id:
        coupon_id = request.coupon_id
    elif request.promotion_code:
        # 通过兑换码查找优惠券
        promo_code = db.query(models.PromotionCode).filter(
            models.PromotionCode.code.ilike(request.promotion_code),
            models.PromotionCode.is_active == True
        ).first()
        
        if not promo_code:
            raise HTTPException(status_code=404, detail="兑换码无效或已失效")
        
        # 检查兑换码有效期
        now = get_utc_time()
        if promo_code.valid_from > now or promo_code.valid_until < now:
            raise HTTPException(status_code=400, detail="兑换码不在有效期内")
        
        # 检查兑换码使用次数
        if promo_code.max_uses:
            used_count = db.query(models.UserCoupon).filter(
                models.UserCoupon.promotion_code_id == promo_code.id
            ).count()
            if used_count >= promo_code.max_uses:
                raise HTTPException(status_code=400, detail="兑换码已达到使用上限")
        
        # 检查用户是否已使用过此兑换码
        if promo_code.per_user_limit:
            user_used_count = db.query(models.UserCoupon).filter(
                models.UserCoupon.user_id == current_user.id,
                models.UserCoupon.promotion_code_id == promo_code.id
            ).count()
            if user_used_count >= promo_code.per_user_limit:
                raise HTTPException(status_code=400, detail="您已使用过此兑换码")
        
        coupon_id = promo_code.coupon_id
        promotion_code_id = promo_code.id
    else:
        raise HTTPException(status_code=400, detail="必须提供coupon_id或promotion_code")
    
    user_coupon, claim_error = claim_coupon(
        db,
        current_user.id,
        coupon_id,
        promotion_code_id=promotion_code_id,
        idempotency_key=request.idempotency_key
    )
    
    if not user_coupon:
        raise HTTPException(status_code=400, detail=claim_error or "领取失败，请检查优惠券是否可用或已达到领取限制")
    
    # 获取优惠券详情用于返回
    coupon = get_coupon_by_id(db, coupon_id)
    
    return {
        "user_coupon_id": user_coupon.id,
        "coupon_id": user_coupon.coupon_id,
        "coupon_name": coupon.name if coupon else None,
        "message": "优惠券领取成功"
    }


@router.get("/coupons/my", response_model=schemas.UserCouponList)
def get_my_coupons(
    status: Optional[str] = Query(None, description="状态筛选：unused, used, expired"),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """获取用户优惠券列表"""
    skip = (page - 1) * limit
    user_coupons, total = get_user_coupons(db, current_user.id, status, skip, limit)
    
    data = []
    for uc in user_coupons:
        coupon = get_coupon_by_id(db, uc.coupon_id)
        if not coupon:
            continue
        
        discount_value_display = f"{coupon.discount_value / 100:.2f}"
        min_amount_display = f"{coupon.min_amount / 100:.2f}"
        
        data.append({
            "id": uc.id,
            "coupon": {
                "id": coupon.id,
                "code": coupon.code,
                "name": coupon.name,
                "type": coupon.type,
                "discount_value": coupon.discount_value,
                "discount_value_display": discount_value_display,
                "min_amount": coupon.min_amount,
                "min_amount_display": min_amount_display
            },
            "status": uc.status,
            "obtained_at": uc.obtained_at,
            "valid_until": coupon.valid_until
        })
    
    return {"data": data}


@router.post("/coupons/validate", response_model=schemas.CouponValidateResponse)
def validate_coupon(
    request: schemas.CouponValidateRequest,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """验证优惠券（支付前）"""
    coupon = get_coupon_by_code(db, request.coupon_code)
    if not coupon:
        raise HTTPException(status_code=404, detail="优惠券不存在")
    
    is_valid, error_msg, discount_amount = validate_coupon_usage(
        db,
        current_user.id,
        coupon.id,
        request.order_amount,
        request.task_location,
        request.task_type,
        request.task_date
    )
    
    if not is_valid:
        raise HTTPException(status_code=400, detail=error_msg)
    
    final_amount = request.order_amount - discount_amount
    discount_amount_display = f"{discount_amount / 100:.2f}"
    final_amount_display = f"{final_amount / 100:.2f}"
    
    return {
        "valid": True,
        "discount_amount": discount_amount,
        "discount_amount_display": discount_amount_display,
        "final_amount": final_amount,
        "final_amount_display": final_amount_display,
        "currency": coupon.currency,
        "coupon_id": coupon.id,
        "usage_conditions": coupon.usage_conditions
    }


@router.post("/coupons/use", response_model=schemas.CouponUseResponse)
def use_coupon_api(
    request: schemas.CouponUseRequest,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """使用优惠券（支付时）"""
    usage_log, error_msg = use_coupon(
        db,
        current_user.id,
        request.user_coupon_id,
        request.task_id,
        request.order_amount,
        request.task_location,
        request.task_type,
        request.task_date,
        request.idempotency_key
    )
    
    if not usage_log:
        raise HTTPException(status_code=400, detail=error_msg or "使用失败")
    
    discount_amount_display = f"{usage_log.discount_amount / 100:.2f}"
    final_amount_display = f"{usage_log.final_amount_incl_tax / 100:.2f}"
    
    return {
        "discount_amount": usage_log.discount_amount,
        "discount_amount_display": discount_amount_display,
        "final_amount": usage_log.final_amount_incl_tax,
        "final_amount_display": final_amount_display,
        "currency": usage_log.currency,
        "usage_log_id": usage_log.id,
        "message": "优惠券使用成功"
    }


# ==================== 任务支付集成 API ====================

@router.post("/tasks/{task_id}/payment", response_model=schemas.TaskPaymentResponse)
@rate_limit("create_payment")
def create_task_payment(
    task_id: int,
    payment_request: schemas.TaskPaymentRequest,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    创建任务支付（支持优惠券抵扣）
    
    安全说明：
    - 此 API 只创建 PaymentIntent，不更新 Stripe 支付状态
    - 所有 Stripe 支付状态更新必须通过 Webhook 处理（/api/stripe/webhook）
    - 前端只能创建支付意图，不能确认支付状态
    - 支付状态更新只能由 Stripe Webhook 触发，确保安全性
    """
    from app import crud
    from app.coupon_points_crud import (
        get_or_create_points_account,
        add_points_transaction,
        validate_coupon_usage,
        use_coupon,
        get_coupon_by_code,
    )
    from app.crud import get_system_setting
    import stripe
    import os
    
    # 使用 SELECT FOR UPDATE 锁定任务，防止并发重复支付
    from sqlalchemy import select
    
    task_query = select(models.Task).where(models.Task.id == task_id).with_for_update()
    task_result = db.execute(task_query)
    task = task_result.scalar_one_or_none()
    
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")
    
    if task.poster_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权访问此任务")
    
    # 幂等性检查：如果任务已支付，直接返回成功
    if task.is_paid:
        # 返回已支付的信息，避免重复扣款
        task_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0
        task_amount_pence = int(task_amount * 100)
        # 计算平台服务费
        # 规则：小于10镑固定收取1镑，大于等于10镑按10%计算
        from app.utils.fee_calculator import calculate_application_fee_pence
        application_fee_pence = calculate_application_fee_pence(task_amount_pence)
        
        # 获取支付历史记录以获取优惠券信息
        payment_history = db.query(models.PaymentHistory).filter(
            models.PaymentHistory.task_id == task_id,
            models.PaymentHistory.user_id == current_user.id
        ).order_by(models.PaymentHistory.created_at.desc()).first()
        
        coupon_discount = payment_history.coupon_discount if payment_history else 0
        coupon_info = None
        if payment_history and payment_history.coupon_usage_log_id:
            coupon_usage_log = db.query(models.CouponUsageLog).filter(
                models.CouponUsageLog.id == payment_history.coupon_usage_log_id
            ).first()
            if coupon_usage_log:
                user_coupon = db.query(models.UserCoupon).filter(
                    models.UserCoupon.id == coupon_usage_log.user_coupon_id
                ).first()
                if user_coupon:
                    coupon = db.query(models.Coupon).filter(models.Coupon.id == user_coupon.coupon_id).first()
                    if coupon:
                        coupon_info = {
                            "name": coupon.name,
                            "type": coupon.type,
                            "description": coupon.description
                        }
        
        # 构建计算过程步骤
        calculation_steps = [
            {
                "label": "任务金额",
                "amount": task_amount_pence,
                "amount_display": f"{task_amount_pence / 100:.2f}",
                "type": "original"
            }
        ]
        if coupon_discount > 0:
            calculation_steps.append({
                "label": f"优惠券折扣" + (f"（{coupon_info['name'] if coupon_info else ''}）" if coupon_info else ""),
                "amount": -coupon_discount,
                "amount_display": f"-{coupon_discount / 100:.2f}",
                "type": "discount"
            })
        calculation_steps.append({
            "label": "最终支付金额",
            "amount": 0,
            "amount_display": "0.00",
            "type": "final"
        })
        
        return {
            "payment_id": None,
            "fee_type": "task_amount",
            "original_amount": task_amount_pence,
            "original_amount_display": f"{task_amount_pence / 100:.2f}",
            "coupon_discount": coupon_discount if coupon_discount > 0 else None,
            "coupon_discount_display": f"{coupon_discount / 100:.2f}" if coupon_discount > 0 else None,
            "coupon_name": coupon_info['name'] if coupon_info else None,
            "coupon_type": coupon_info['type'] if coupon_info else None,
            "coupon_description": coupon_info['description'] if coupon_info else None,
            "final_amount": 0,
            "final_amount_display": "0.00",
            "currency": "GBP",
            "client_secret": None,
            "payment_intent_id": task.payment_intent_id,
            "customer_id": None,
            "ephemeral_key_secret": None,
            "calculation_steps": calculation_steps,
            "note": "任务已支付"
        }
    
    # 检查任务状态：只有 pending_payment 状态的任务需要支付
    # 但如果任务有 payment_intent_id（批准申请时创建的），说明是待确认的批准，也允许支付
    if task.status != "pending_payment":
        # 如果任务有 payment_intent_id，说明是批准申请时创建的 PaymentIntent，允许支付
        if task.payment_intent_id:
            logger.info(f"任务状态为 {task.status}，但有 payment_intent_id={task.payment_intent_id}，允许支付（待确认的批准）")
            # 检查 PaymentIntent 状态
            try:
                payment_intent = stripe.PaymentIntent.retrieve(task.payment_intent_id)
                
                # ⚠️ 安全验证：如果提供了 application_id，验证 PaymentIntent 是否属于此申请者
                if payment_request.application_id is not None:
                    payment_intent_application_id = payment_intent.get("metadata", {}).get("application_id")
                    if payment_intent_application_id:
                        # PaymentIntent 有 application_id metadata，必须匹配
                        if str(payment_intent_application_id) != str(payment_request.application_id):
                            logger.warning(
                                f"⚠️ PaymentIntent 申请者不匹配: "
                                f"PaymentIntent metadata.application_id={payment_intent_application_id}, "
                                f"请求的 application_id={payment_request.application_id}, "
                                f"payment_intent_id={task.payment_intent_id}"
                            )
                            raise HTTPException(
                                status_code=400,
                                detail=f"PaymentIntent 不属于申请者 {payment_request.application_id}。请先批准该申请者。"
                            )
                        logger.info(f"✅ PaymentIntent 申请者验证通过: application_id={payment_request.application_id}")
                    else:
                        # PaymentIntent 没有 application_id metadata（可能是旧数据或非申请批准流程创建的）
                        logger.warning(
                            f"⚠️ PaymentIntent 缺少 application_id metadata: "
                            f"payment_intent_id={task.payment_intent_id}, "
                            f"请求的 application_id={payment_request.application_id}"
                        )
                        # 为了安全，不允许使用没有 application_id 的 PaymentIntent 进行申请者支付
                        raise HTTPException(
                            status_code=400,
                            detail=f"PaymentIntent 缺少申请者信息，无法验证。请先批准该申请者。"
                        )
                if payment_intent.status == "succeeded":
                    # 支付已完成，返回已支付信息
                    task_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0
                    task_amount_pence = int(task_amount * 100)
                    from app.utils.fee_calculator import calculate_application_fee_pence
                    application_fee_pence = calculate_application_fee_pence(task_amount_pence)
                    
                    # 获取支付历史记录以获取优惠券信息
                    payment_history = db.query(models.PaymentHistory).filter(
                        models.PaymentHistory.payment_intent_id == task.payment_intent_id
                    ).first()
                    
                    coupon_discount = payment_history.coupon_discount if payment_history else 0
                    coupon_info = None
                    if payment_history and payment_history.coupon_usage_log_id:
                        coupon_usage_log = db.query(models.CouponUsageLog).filter(
                            models.CouponUsageLog.id == payment_history.coupon_usage_log_id
                        ).first()
                        if coupon_usage_log:
                            user_coupon = db.query(models.UserCoupon).filter(
                                models.UserCoupon.id == coupon_usage_log.user_coupon_id
                            ).first()
                            if user_coupon:
                                coupon = db.query(models.Coupon).filter(models.Coupon.id == user_coupon.coupon_id).first()
                                if coupon:
                                    coupon_info = {
                                        "name": coupon.name,
                                        "type": coupon.type,
                                        "description": coupon.description
                                    }
                    
                    # 构建计算过程步骤
                    calculation_steps = [
                        {
                            "label": "任务金额",
                            "amount": task_amount_pence,
                            "amount_display": f"{task_amount_pence / 100:.2f}",
                            "type": "original"
                        }
                    ]
                    if coupon_discount > 0:
                        calculation_steps.append({
                            "label": f"优惠券折扣" + (f"（{coupon_info['name'] if coupon_info else ''}）" if coupon_info else ""),
                            "amount": -coupon_discount,
                            "amount_display": f"-{coupon_discount / 100:.2f}",
                            "type": "discount"
                        })
                    calculation_steps.append({
                        "label": "最终支付金额",
                        "amount": 0,
                        "amount_display": "0.00",
                        "type": "final"
                    })
                    
                    return {
                        "payment_id": None,
                        "fee_type": "task_amount",
                        "original_amount": task_amount_pence,
                        "original_amount_display": f"{task_amount_pence / 100:.2f}",
                        "coupon_discount": coupon_discount if coupon_discount > 0 else None,
                        "coupon_discount_display": f"{coupon_discount / 100:.2f}" if coupon_discount > 0 else None,
                        "coupon_name": coupon_info['name'] if coupon_info else None,
                        "coupon_type": coupon_info['type'] if coupon_info else None,
                        "coupon_description": coupon_info['description'] if coupon_info else None,
                        "final_amount": 0,
                        "final_amount_display": "0.00",
                        "currency": "GBP",
                        "client_secret": None,
                        "payment_intent_id": task.payment_intent_id,
                        "customer_id": None,
                        "ephemeral_key_secret": None,
                        "calculation_steps": calculation_steps,
                        "note": "任务已支付"
                    }
                elif payment_intent.status in ["requires_payment_method", "requires_confirmation", "requires_action"]:
                    # PaymentIntent 存在但未完成，返回 client_secret 让用户完成支付
                    logger.info(f"PaymentIntent 状态为 {payment_intent.status}，返回 client_secret")
                    task_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0
                    task_amount_pence = int(task_amount * 100)
                    from app.utils.fee_calculator import calculate_application_fee_pence
                    application_fee_pence = calculate_application_fee_pence(task_amount_pence)
                    
                    # 从 PaymentIntent metadata 获取优惠券信息
                    metadata = payment_intent.get("metadata", {})
                    coupon_discount = int(metadata.get("coupon_discount", 0)) if metadata.get("coupon_discount") else 0
                    coupon_info = None
                    if coupon_discount > 0 and metadata.get("coupon_usage_log_id"):
                        try:
                            coupon_usage_log_id = int(metadata.get("coupon_usage_log_id"))
                            coupon_usage_log = db.query(models.CouponUsageLog).filter(
                                models.CouponUsageLog.id == coupon_usage_log_id
                            ).first()
                            if coupon_usage_log:
                                user_coupon = db.query(models.UserCoupon).filter(
                                    models.UserCoupon.id == coupon_usage_log.user_coupon_id
                                ).first()
                                if user_coupon:
                                    coupon = db.query(models.Coupon).filter(models.Coupon.id == user_coupon.coupon_id).first()
                                    if coupon:
                                        coupon_info = {
                                            "name": coupon.name,
                                            "type": coupon.type,
                                            "description": coupon.description
                                        }
                        except Exception as e:
                            logger.warning(f"获取优惠券信息失败: {e}")
                    
                    # 构建计算过程步骤
                    calculation_steps = [
                        {
                            "label": "任务金额",
                            "amount": task_amount_pence,
                            "amount_display": f"{task_amount_pence / 100:.2f}",
                            "type": "original"
                        }
                    ]
                    if coupon_discount > 0:
                        calculation_steps.append({
                            "label": f"优惠券折扣" + (f"（{coupon_info['name'] if coupon_info else ''}）" if coupon_info else ""),
                            "amount": -coupon_discount,
                            "amount_display": f"-{coupon_discount / 100:.2f}",
                            "type": "discount"
                        })
                    calculation_steps.append({
                        "label": "最终支付金额",
                        "amount": payment_intent.amount,
                        "amount_display": f"{payment_intent.amount / 100:.2f}",
                        "type": "final"
                    })
                    
                    return {
                        "payment_id": None,
                        "fee_type": "task_amount",
                        "original_amount": task_amount_pence,
                        "original_amount_display": f"{task_amount_pence / 100:.2f}",
                        "coupon_discount": coupon_discount if coupon_discount > 0 else None,
                        "coupon_discount_display": f"{coupon_discount / 100:.2f}" if coupon_discount > 0 else None,
                        "coupon_name": coupon_info['name'] if coupon_info else None,
                        "coupon_type": coupon_info['type'] if coupon_info else None,
                        "coupon_description": coupon_info['description'] if coupon_info else None,
                        "final_amount": payment_intent.amount,
                        "final_amount_display": f"{payment_intent.amount / 100:.2f}",
                        "currency": "GBP",
                        "client_secret": payment_intent.client_secret,
                        "payment_intent_id": payment_intent.id,
                        "customer_id": None,
                        "ephemeral_key_secret": None,
                        "calculation_steps": calculation_steps,
                        "note": "请完成支付以确认批准申请"
                    }
            except Exception as e:
                logger.error(f"获取 PaymentIntent 失败: {e}")
                # 如果获取失败，继续正常流程（创建新的 PaymentIntent）
        
        # 如果没有 payment_intent_id 或获取失败，且状态不是 pending_payment，则报错
        logger.warning(f"任务状态不正确: task_id={task_id}, status={task.status}, expected=pending_payment")
        raise HTTPException(
            status_code=400, 
            detail=f"任务状态不正确，无法支付。当前状态：{task.status}，需要状态：pending_payment（等待支付）。请先接受申请。"
        )
    
    # 检查任务是否已接受申请（必须有接受人）
    if not task.taker_id:
        logger.warning(f"任务尚未接受申请: task_id={task_id}, taker_id=None")
        raise HTTPException(
            status_code=400,
            detail="任务尚未接受申请，无法进行支付。请先接受申请。"
        )
    
    logger.info(f"任务支付检查通过: task_id={task_id}, status={task.status}, taker_id={task.taker_id}")
    
    # ⚠️ 安全检查：检查支付是否已过期
    if task.payment_expires_at:
        current_time = get_utc_time()
        if task.payment_expires_at < current_time:
            logger.warning(
                f"⚠️ 支付已过期: task_id={task_id}, "
                f"payment_expires_at={task.payment_expires_at}, current_time={current_time}"
            )
            raise HTTPException(
                status_code=400,
                detail="支付已过期，无法继续支付。任务将自动取消。"
            )
    
    # 获取任务金额（使用最终成交价或原始标价）
    task_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0
    
    # 验证任务金额必须大于0
    if task_amount <= 0:
        raise HTTPException(
            status_code=400,
            detail="任务金额必须大于0，无法进行支付"
        )
    
    task_amount_pence = int(task_amount * 100)  # 转换为最小货币单位
    
    # 计算平台服务费（从接受人端扣除）
    # 规则：小于10镑固定收取1镑，大于等于10镑按10%计算
    from app.utils.fee_calculator import calculate_application_fee_pence
    application_fee_pence = calculate_application_fee_pence(task_amount_pence)
    
    # 验证平台服务费必须大于0
    if application_fee_pence <= 0:
        raise HTTPException(
            status_code=400,
            detail="平台服务费计算错误，无法进行支付"
        )
    
    # 发布者支付任务金额（只支持优惠券抵扣，积分不能作为支付手段）
    original_amount = task_amount_pence
    total_amount = task_amount_pence
    
    # 初始化变量
    coupon_discount = 0
    user_coupon_id_used = None
    coupon_usage_log = None
    coupon_info = None  # 用于存储优惠券信息
    
    # 处理优惠券抵扣
    if payment_request.coupon_code or payment_request.user_coupon_id:
        # 如果提供了优惠券代码，先查找用户优惠券
        if payment_request.coupon_code:
            coupon = get_coupon_by_code(db, payment_request.coupon_code.upper())
            if not coupon:
                raise HTTPException(status_code=404, detail="优惠券不存在")
            
            # 查找用户的该优惠券
            user_coupon = db.query(models.UserCoupon).filter(
                and_(
                    models.UserCoupon.user_id == current_user.id,
                    models.UserCoupon.coupon_id == coupon.id,
                    models.UserCoupon.status == "unused"
                )
            ).first()
            
            if not user_coupon:
                raise HTTPException(status_code=400, detail="您没有可用的此优惠券")
            
            user_coupon_id_used = user_coupon.id
        else:
            user_coupon_id_used = payment_request.user_coupon_id
        
        # 验证优惠券使用条件
        user_coupon = db.query(models.UserCoupon).filter(
            and_(
                models.UserCoupon.id == user_coupon_id_used,
                models.UserCoupon.user_id == current_user.id
            )
        ).first()
        
        if not user_coupon:
            raise HTTPException(status_code=404, detail="用户优惠券不存在")
        
        # 验证优惠券（针对任务金额）
        is_valid, error_msg, discount_amount = validate_coupon_usage(
            db,
            current_user.id,
            user_coupon.coupon_id,
            task_amount_pence,  # 优惠券针对任务金额
            task.location,
            task.task_type,
            get_utc_time()
        )
        
        if not is_valid:
            raise HTTPException(status_code=400, detail=error_msg or "优惠券不可用")
        
        # 使用优惠券
        coupon_usage_log, error = use_coupon(
            db,
            current_user.id,
            user_coupon_id_used,
            task_id,
            task_amount_pence,  # 优惠券针对任务金额
            task.location,
            task.task_type,
            get_utc_time(),
            idempotency_key=f"task_payment_{task_id}_{current_user.id}"
        )
        
        if error:
            raise HTTPException(status_code=400, detail=error)
        
        coupon_discount = coupon_usage_log.discount_amount
        total_amount = max(0, total_amount - coupon_discount)
        
        # 获取优惠券信息用于响应
        coupon = db.query(models.Coupon).filter(models.Coupon.id == user_coupon.coupon_id).first()
        if coupon:
            coupon_info = {
                "name": coupon.name,
                "type": coupon.type,
                "description": coupon.description
            }
    
    # 计算最终需要支付的金额
    final_amount = max(0, total_amount)
    
    # 如果使用优惠券全额抵扣，直接完成支付（不需要Stripe支付）
    if final_amount == 0 and coupon_discount > 0:
        try:
            # 标记任务为已支付（优惠券全额抵扣，没有 payment_intent_id）
            task.is_paid = 1
            task.payment_intent_id = None
            # escrow_amount = 任务金额 - 平台服务费（任务接受人获得的金额）
            taker_amount = task_amount - (application_fee_pence / 100.0)
            task.escrow_amount = max(0.0, taker_amount)
            # 支付成功后，将任务状态从 pending_payment 更新为 in_progress
            if task.status == "pending_payment":
                task.status = "in_progress"
            
            # 创建支付历史记录
            payment_history = models.PaymentHistory(
                task_id=task_id,
                user_id=current_user.id,
                payment_intent_id=None,
                payment_method="stripe",  # 虽然没用到Stripe，但记录为stripe类型
                total_amount=task_amount_pence,
                points_used=0,
                coupon_discount=coupon_discount,
                stripe_amount=0,
                final_amount=0,
                currency="GBP",
                status="succeeded",
                application_fee=application_fee_pence,
                escrow_amount=taker_amount,
                coupon_usage_log_id=coupon_usage_log.id if coupon_usage_log else None,
                extra_metadata={
                    "coupon_only": True,
                    "task_title": task.title
                }
            )
            db.add(payment_history)
            db.commit()
            
            # 构建计算过程步骤
            calculation_steps = [
                {
                    "label": "任务金额",
                    "amount": original_amount,
                    "amount_display": f"{original_amount / 100:.2f}",
                    "type": "original"
                }
            ]
            if coupon_discount > 0:
                calculation_steps.append({
                    "label": f"优惠券折扣" + (f"（{coupon_info['name'] if coupon_info else ''}）" if coupon_info else ""),
                    "amount": -coupon_discount,
                    "amount_display": f"-{coupon_discount / 100:.2f}",
                    "type": "discount"
                })
            calculation_steps.append({
                "label": "最终支付金额",
                "amount": final_amount,
                "amount_display": f"{final_amount / 100:.2f}",
                "type": "final"
            })
            
            return {
                "payment_id": None,
                "fee_type": "task_amount",
                "original_amount": original_amount,
                "original_amount_display": f"{original_amount / 100:.2f}",
                "coupon_discount": coupon_discount,
                "coupon_discount_display": f"{coupon_discount / 100:.2f}",
                "coupon_name": coupon_info['name'] if coupon_info else None,
                "coupon_type": coupon_info['type'] if coupon_info else None,
                "coupon_description": coupon_info['description'] if coupon_info else None,
                "final_amount": final_amount,
                "final_amount_display": "0.00",
                "currency": "GBP",
                "client_secret": None,
                "payment_intent_id": None,
                "customer_id": None,
                "ephemeral_key_secret": None,
                "calculation_steps": calculation_steps,
                "note": f"任务金额已支付（使用优惠券全额抵扣），任务接受人将获得 {task_amount - (application_fee_pence / 100.0):.2f} 镑（已扣除平台服务费 {application_fee_pence / 100.0:.2f} 镑）"
            }
        except Exception as e:
            db.rollback()
            logger.error(f"优惠券支付失败: {e}")
            raise HTTPException(
                status_code=500,
                detail=f"支付处理失败，请稍后重试"
            )
    
    # 如果需要Stripe支付（优惠券抵扣后仍有余额）
    if final_amount > 0:
        stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
        
        # ⚠️ 重要：检查是否已有未完成的 PaymentIntent，避免重复创建
        # 若请求了 preferred_payment_method（仅用该方式），不复用已有 PI，必须新建仅含该方式的 PI
        # 这样 PaymentSheet 只显示该方式，不再弹支付方式选择窗
        if task.payment_intent_id and not payment_request.preferred_payment_method:
            try:
                existing_payment_intent = stripe.PaymentIntent.retrieve(task.payment_intent_id)
                
                # ⚠️ 安全验证：如果提供了 application_id，验证 PaymentIntent 是否属于此申请者
                if payment_request.application_id is not None:
                    payment_intent_application_id = existing_payment_intent.get("metadata", {}).get("application_id")
                    if payment_intent_application_id and str(payment_intent_application_id) != str(payment_request.application_id):
                        logger.warning(
                            f"⚠️ PaymentIntent 申请者不匹配（复用检查）: "
                            f"PaymentIntent metadata.application_id={payment_intent_application_id}, "
                            f"请求的 application_id={payment_request.application_id}, "
                            f"payment_intent_id={task.payment_intent_id}"
                        )
                        # 如果 PaymentIntent 不属于当前申请者，清除它并创建新的
                        logger.info(f"清除不匹配的 PaymentIntent，将创建新的 PaymentIntent")
                        task.payment_intent_id = None
                        db.commit()
                    elif payment_intent_application_id:
                        logger.info(f"✅ PaymentIntent 申请者验证通过（复用）: application_id={payment_request.application_id}")
                
                # 如果 PaymentIntent 状态是未完成状态，复用已有的 PaymentIntent
                if existing_payment_intent.status in ["requires_payment_method", "requires_confirmation", "requires_action"]:
                    logger.info(f"复用已有的 PaymentIntent: {task.payment_intent_id}, 状态: {existing_payment_intent.status}")
                    
                    # 获取任务接受人的 Stripe Connect 账户 ID
                    taker = db.query(models.User).filter(models.User.id == task.taker_id).first()
                    if not taker or not taker.stripe_account_id:
                        raise HTTPException(
                            status_code=400,
                            detail="任务接受人尚未设置 Stripe Connect 收款账户，无法进行支付"
                        )
                    
                    # 创建或获取 Stripe Customer（用于保存支付方式）
                    customer_id = None
                    ephemeral_key_secret = None
                    
                    try:
                        # 使用 Stripe Search API 查找现有 Customer（通过 metadata.user_id）
                        # 注意：Customer.list() 不支持通过 metadata 查询，需要使用 Search API
                        try:
                            search_result = stripe.Customer.search(
                                query=f"metadata['user_id']:'{current_user.id}'",
                                limit=1
                            )
                            if search_result.data:
                                customer_id = search_result.data[0].id
                            else:
                                # 创建新的 Stripe Customer
                                customer = stripe.Customer.create(
                                    metadata={
                                        "user_id": str(current_user.id),
                                        "user_name": current_user.name
                                    }
                                )
                                customer_id = customer.id
                        except Exception as search_error:
                            # 如果 Search API 不可用或失败，直接创建新的 Customer
                            logger.debug(f"Stripe Search API 不可用，直接创建新 Customer: {search_error}")
                            customer = stripe.Customer.create(
                                metadata={
                                    "user_id": str(current_user.id),
                                    "user_name": current_user.name
                                }
                            )
                            customer_id = customer.id
                        
                        # 创建 Ephemeral Key
                        ephemeral_key = stripe.EphemeralKey.create(
                            customer=customer_id,
                            stripe_version="2025-04-30.preview"
                        )
                        ephemeral_key_secret = ephemeral_key.secret
                    except Exception as e:
                        logger.warning(f"无法创建 Stripe Customer 或 Ephemeral Key: {str(e)}")
                        customer_id = None
                        ephemeral_key_secret = None
                    
                    # 从 PaymentIntent metadata 获取优惠券信息
                    metadata = existing_payment_intent.get("metadata", {})
                    coupon_discount = int(metadata.get("coupon_discount", 0)) if metadata.get("coupon_discount") else 0
                    coupon_info = None
                    if coupon_discount > 0 and metadata.get("coupon_usage_log_id"):
                        try:
                            coupon_usage_log_id = int(metadata.get("coupon_usage_log_id"))
                            coupon_usage_log = db.query(models.CouponUsageLog).filter(
                                models.CouponUsageLog.id == coupon_usage_log_id
                            ).first()
                            if coupon_usage_log:
                                user_coupon = db.query(models.UserCoupon).filter(
                                    models.UserCoupon.id == coupon_usage_log.user_coupon_id
                                ).first()
                                if user_coupon:
                                    coupon = db.query(models.Coupon).filter(models.Coupon.id == user_coupon.coupon_id).first()
                                    if coupon:
                                        coupon_info = {
                                            "name": coupon.name,
                                            "type": coupon.type,
                                            "description": coupon.description
                                        }
                        except Exception as e:
                            logger.warning(f"获取优惠券信息失败: {e}")
                    
                    # 构建计算过程步骤
                    calculation_steps = [
                        {
                            "label": "任务金额",
                            "amount": original_amount,
                            "amount_display": f"{original_amount / 100:.2f}",
                            "type": "original"
                        }
                    ]
                    if coupon_discount > 0:
                        calculation_steps.append({
                            "label": f"优惠券折扣" + (f"（{coupon_info['name'] if coupon_info else ''}）" if coupon_info else ""),
                            "amount": -coupon_discount,
                            "amount_display": f"-{coupon_discount / 100:.2f}",
                            "type": "discount"
                        })
                    calculation_steps.append({
                        "label": "最终支付金额",
                        "amount": existing_payment_intent.amount,
                        "amount_display": f"{existing_payment_intent.amount / 100:.2f}",
                        "type": "final"
                    })
                    
                    return {
                        "payment_id": None,
                        "fee_type": "task_amount",
                        "original_amount": original_amount,
                        "original_amount_display": f"{original_amount / 100:.2f}",
                        "coupon_discount": coupon_discount if coupon_discount > 0 else None,
                        "coupon_discount_display": f"{coupon_discount / 100:.2f}" if coupon_discount > 0 else None,
                        "coupon_name": coupon_info['name'] if coupon_info else None,
                        "coupon_type": coupon_info['type'] if coupon_info else None,
                        "coupon_description": coupon_info['description'] if coupon_info else None,
                        "final_amount": existing_payment_intent.amount,
                        "final_amount_display": f"{existing_payment_intent.amount / 100:.2f}",
                        "currency": "GBP",
                        "client_secret": existing_payment_intent.client_secret,
                        "payment_intent_id": existing_payment_intent.id,
                        "customer_id": customer_id,
                        "ephemeral_key_secret": ephemeral_key_secret,
                        "calculation_steps": calculation_steps,
                        "note": "请完成支付，任务接受人将获得 {:.2f} 镑（已扣除平台服务费 {:.2f} 镑）".format(
                            task_amount - (application_fee_pence / 100.0),
                            application_fee_pence / 100.0
                        )
                    }
                elif existing_payment_intent.status == "succeeded":
                    # PaymentIntent 已完成，但任务状态可能未更新，返回已支付信息
                    logger.info(f"PaymentIntent 已完成: {task.payment_intent_id}")
                    # 这里应该返回已支付信息，但为了安全，继续正常流程检查任务状态
                    pass
                else:
                    # PaymentIntent 状态是 canceled 或其他最终状态，需要创建新的
                    logger.info(f"PaymentIntent 状态为 {existing_payment_intent.status}，将创建新的 PaymentIntent")
            except Exception as e:
                logger.warning(f"获取已有 PaymentIntent 失败: {e}，将创建新的 PaymentIntent")
        
        # 获取任务接受人的 Stripe Connect 账户 ID
        taker = db.query(models.User).filter(models.User.id == task.taker_id).first()
        if not taker or not taker.stripe_account_id:
            raise HTTPException(
                status_code=400,
                detail="任务接受人尚未设置 Stripe Connect 收款账户，无法进行支付"
            )
        
        # 创建或获取 Stripe Customer（用于保存支付方式）
        customer_id = None
        ephemeral_key_secret = None
        
        # 检查用户是否已有 Stripe Customer ID（可以存储在 User 模型中，这里先检查数据库）
        # 如果没有，创建一个新的 Customer
        try:
            # 使用 Stripe Search API 查找现有 Customer（通过 metadata.user_id）
            # 注意：Customer.list() 不支持通过 metadata 查询，需要使用 Search API
            try:
                search_result = stripe.Customer.search(
                    query=f"metadata['user_id']:'{current_user.id}'",
                    limit=1
                )
                if search_result.data:
                    customer_id = search_result.data[0].id
                else:
                    # 创建新的 Stripe Customer
                    customer = stripe.Customer.create(
                        metadata={
                            "user_id": str(current_user.id),
                            "user_name": current_user.name
                        }
                    )
                    customer_id = customer.id
            except Exception as search_error:
                # 如果 Search API 不可用或失败，直接创建新的 Customer
                logger.debug(f"Stripe Search API 不可用，直接创建新 Customer: {search_error}")
                customer = stripe.Customer.create(
                    metadata={
                        "user_id": str(current_user.id),
                        "user_name": current_user.name
                    }
                )
                customer_id = customer.id
                # 注意：这里可以将 customer_id 保存到 User 模型，但为了简化，暂时不保存
            
            # 创建 Ephemeral Key（用于客户端访问 Customer 的支付方式）
            # Ephemeral Key 有效期通常为 24 小时
            ephemeral_key = stripe.EphemeralKey.create(
                customer=customer_id,
                stripe_version="2025-04-30.preview"  # 使用最新的 API 版本
            )
            ephemeral_key_secret = ephemeral_key.secret
            
        except Exception as e:
            # 如果创建 Customer 或 Ephemeral Key 失败，记录错误但不阻止支付
            # 用户仍然可以使用一次性支付（不保存卡）
            logger.warning(f"无法创建 Stripe Customer 或 Ephemeral Key: {str(e)}")
            customer_id = None
            ephemeral_key_secret = None
        
        # 创建 Payment Intent（参考 Stripe Payment Intents API sample code）
        # Create a PaymentIntent with the order amount and currency
        # 使用 automatic_payment_methods（与官方 sample code 一致）
        # In the latest version of the API, specifying the `automatic_payment_methods` parameter
        # is optional because Stripe enables its functionality by default.
        # 这会自动启用所有可用的支付方式，包括 card、apple_pay、google_pay、link 等
        # 
        # 尝试包含 WeChat Pay，如果不可用则回退到只使用 card
        # 这样 PaymentSheet 会显示所有可用的支付方式
        # 
        # 交易市场托管模式（Marketplace/Escrow）：
        # - 支付时：资金先到平台账户（不立即转账给任务接受人）
        # - 任务完成后：使用 Transfer.create 将资金转给任务接受人
        # - 平台服务费在转账时扣除（不在这里设置 application_fee_amount）
        # 
        # 注意：官方示例代码使用的是 Checkout Session + Direct Charges 模式（立即转账）
        # 但交易市场需要托管模式，所以不设置 transfer_data.destination
        
        # 创建 Payment Intent（参考 Stripe Payment Intents API sample code）
        # Create a PaymentIntent with the order amount and currency
        # 使用 automatic_payment_methods（Stripe 推荐方式，与官方 sample code 一致）
        # In the latest version of the API, specifying the `automatic_payment_methods` parameter
        # is optional because Stripe enables its functionality by default.
        # 这会自动启用所有可用的支付方式，包括 card、apple_pay、google_pay、link、wechat_pay 等
        # 
        # 注意：不能同时使用 payment_method_types 和 automatic_payment_methods
        # 如果 Stripe Dashboard 中启用了 WeChat Pay，automatic_payment_methods 会自动包含它
        # 
        # 交易市场托管模式（Marketplace/Escrow）：
        # - 支付时：资金先到平台账户（不立即转账给任务接受人）
        # - 任务完成后：使用 Transfer.create 将资金转给任务接受人
        # - 平台服务费在转账时扣除（不在这里设置 application_fee_amount）
        # 
        # 注意：官方示例代码使用的是 Checkout Session + Direct Charges 模式（立即转账）
        # 但交易市场需要托管模式，所以不设置 transfer_data.destination
        pm_types = (
            [payment_request.preferred_payment_method]
            if payment_request.preferred_payment_method
            else ["card", "wechat_pay", "alipay"]
        )
        logger.info(
            f"创建 PaymentIntent: preferred_payment_method={payment_request.preferred_payment_method!r}, "
            f"pm_types={pm_types}"
        )
        # iOS PaymentSheet 必须为 wechat_pay 指定 client: "ios"，否则会报 "None of the payment methods can be used in PaymentSheet"
        # 仅 wechat_pay 支持 payment_method_options.client；alipay 不支持该参数，传了会报 InvalidRequestError
        payment_method_options = {}
        if "wechat_pay" in pm_types:
            payment_method_options["wechat_pay"] = {"client": "ios"}

        create_kw = {
            "amount": final_amount,
            "currency": "gbp",
            "payment_method_types": pm_types,
            "metadata": {
                "task_id": str(task_id),
                "user_id": str(current_user.id),
                "taker_id": str(task.taker_id),
                "taker_stripe_account_id": taker.stripe_account_id,
                "task_amount": str(task_amount_pence),
                "coupon_usage_log_id": str(coupon_usage_log.id) if coupon_usage_log else "",
                "coupon_discount": str(coupon_discount) if coupon_discount > 0 else "",
                "application_fee": str(application_fee_pence),
            },
            "description": f"任务 #{task_id} 任务金额支付 - {task.title}",
        }
        if payment_method_options:
            create_kw["payment_method_options"] = payment_method_options
        payment_intent = stripe.PaymentIntent.create(**create_kw)
        
        # 记录 PaymentIntent 的支付方式类型，用于调试
        payment_method_types = payment_intent.get("payment_method_types", [])
        logger.info(f"PaymentIntent 创建的支付方式类型: {payment_method_types}")
        if "wechat_pay" in payment_method_types:
            logger.info("✅ PaymentIntent 包含 WeChat Pay")
        else:
            logger.warning(f"⚠️ PaymentIntent 不包含 WeChat Pay，当前支付方式: {payment_method_types}")
            logger.warning("请检查 Stripe Dashboard 中是否已启用 WeChat Pay")
        
        # 检查 Payment Method Configuration（诊断 WeChat Pay 不显示的问题）
        try:
            # 获取 Payment Method Configurations
            pm_configs = stripe.PaymentMethodConfiguration.list(limit=1)
            if pm_configs and pm_configs.data:
                pm_config = pm_configs.data[0]
                wechat_config = getattr(pm_config, 'wechat_pay', None)
                if wechat_config:
                    logger.info(f"🔍 WeChat Pay Configuration: available={getattr(wechat_config, 'available', 'N/A')}, display_preference={getattr(wechat_config, 'display_preference', 'N/A')}")
                else:
                    logger.warning("⚠️ 未找到 WeChat Pay 在 Payment Method Configuration 中的配置")
        except Exception as e:
            logger.debug(f"无法获取 Payment Method Configuration: {e}")
        
        # ⚠️ 重要：更新任务的 payment_intent_id，确保下次调用 API 时能复用
        # 这样即使前端清除 clientSecret，后端也能复用已有的 PaymentIntent，避免重复创建
        if not task.payment_intent_id or task.payment_intent_id != payment_intent.id:
            task.payment_intent_id = payment_intent.id
            logger.info(f"更新任务的 payment_intent_id: {payment_intent.id}")
        
        # 创建支付历史记录（待支付状态）
        # 安全：Stripe 支付的状态更新必须通过 Webhook 处理
        # 这里只创建 PaymentIntent 和支付历史记录，不更新任务状态（is_paid, status）
        # 任务状态更新只能由 Stripe Webhook 触发
        payment_history = models.PaymentHistory(
            task_id=task_id,
            user_id=current_user.id,
            payment_intent_id=payment_intent.id,
            payment_method="stripe",
            total_amount=task_amount_pence,
            points_used=0,  # 不再使用积分支付
            coupon_discount=coupon_discount,
            stripe_amount=final_amount,
            final_amount=final_amount,
            currency="GBP",
            status="pending",  # 待支付，webhook 会更新为 succeeded
            application_fee=application_fee_pence,
            coupon_usage_log_id=coupon_usage_log.id if coupon_usage_log else None,
            extra_metadata={
                "task_title": task.title,
                "taker_id": str(task.taker_id)
            }
        )
        db.add(payment_history)
        db.commit()
        
        # 构建计算过程步骤
        calculation_steps = [
            {
                "label": "任务金额",
                "amount": original_amount,
                "amount_display": f"{original_amount / 100:.2f}",
                "type": "original"
            }
        ]
        if coupon_discount > 0:
            calculation_steps.append({
                "label": f"优惠券折扣" + (f"（{coupon_info['name'] if coupon_info else ''}）" if coupon_info else ""),
                "amount": -coupon_discount,
                "amount_display": f"-{coupon_discount / 100:.2f}",
                "type": "discount"
            })
        calculation_steps.append({
            "label": "最终支付金额",
            "amount": final_amount,
            "amount_display": f"{final_amount / 100:.2f}",
            "type": "final"
        })
        
        return {
            "payment_id": None,
            "fee_type": "task_amount",
            "original_amount": original_amount,
            "original_amount_display": f"{original_amount / 100:.2f}",
            "coupon_discount": coupon_discount if coupon_discount > 0 else None,
            "coupon_discount_display": f"{coupon_discount / 100:.2f}" if coupon_discount > 0 else None,
            "coupon_name": coupon_info['name'] if coupon_info else None,
            "coupon_type": coupon_info['type'] if coupon_info else None,
            "coupon_description": coupon_info['description'] if coupon_info else None,
            "final_amount": final_amount,
            "final_amount_display": f"{final_amount / 100:.2f}",
            "currency": "GBP",
            "client_secret": payment_intent.client_secret,
            "payment_intent_id": payment_intent.id,
            "customer_id": customer_id,
            "ephemeral_key_secret": ephemeral_key_secret,
            "calculation_steps": calculation_steps,
            "note": f"请完成支付，任务接受人将获得 {task_amount - (application_fee_pence / 100.0):.2f} 镑（已扣除平台服务费 {application_fee_pence / 100.0:.2f} 镑）"
        }
    
    raise HTTPException(status_code=400, detail="支付金额计算错误")


@router.get("/payment-history")
def get_payment_history(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    task_id: Optional[int] = Query(None),
    status: Optional[str] = Query(None),
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    获取用户的支付历史记录
    
    支持按任务ID和状态筛选
    """
    query = db.query(models.PaymentHistory).filter(
        models.PaymentHistory.user_id == current_user.id
    )
    
    if task_id:
        query = query.filter(models.PaymentHistory.task_id == task_id)
    
    if status:
        query = query.filter(models.PaymentHistory.status == status)
    
    # 按创建时间倒序排列
    query = query.order_by(models.PaymentHistory.created_at.desc())
    
    total = query.count()
    payments = query.offset(skip).limit(limit).all()
    
    return {
        "total": total,
        "skip": skip,
        "limit": limit,
        "payments": [
            {
                "id": p.id,
                "task_id": p.task_id,
                "payment_intent_id": p.payment_intent_id,
                "payment_method": p.payment_method,
                "total_amount": p.total_amount,
                "total_amount_display": f"{p.total_amount / 100:.2f}",
                "points_used": p.points_used,
                "points_used_display": f"{p.points_used / 100:.2f}" if p.points_used else None,
                "coupon_discount": p.coupon_discount,
                "coupon_discount_display": f"{p.coupon_discount / 100:.2f}" if p.coupon_discount else None,
                "stripe_amount": p.stripe_amount,
                "stripe_amount_display": f"{p.stripe_amount / 100:.2f}" if p.stripe_amount else None,
                "final_amount": p.final_amount,
                "final_amount_display": f"{p.final_amount / 100:.2f}",
                "currency": p.currency,
                "status": p.status,
                "application_fee": p.application_fee,
                "application_fee_display": f"{p.application_fee / 100:.2f}" if p.application_fee else None,
                "escrow_amount": float(p.escrow_amount) if p.escrow_amount else None,
                "created_at": p.created_at.isoformat() if p.created_at else None,
                "updated_at": p.updated_at.isoformat() if p.updated_at else None,
                "task": {
                    "id": p.task.id if p.task else None,
                    "title": p.task.title if p.task else None,
                } if p.task else None,
            }
            for p in payments
        ]
    }


@router.get("/tasks/{task_id}/payment-status")
def get_task_payment_status(
    task_id: int,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    查询任务支付状态（只读，不更新任何状态）
    
    安全说明：
    - 此 API 仅用于查询支付状态，不会更新任何数据库字段
    - 所有支付状态更新必须通过 Stripe Webhook 处理
    - 前端只能读取状态，不能修改状态
    
    返回任务的支付信息，包括：
    - 是否已支付
    - Payment Intent ID（如果使用 Stripe 支付）
    - 支付金额
    - 托管金额
    """
    import stripe
    import os
    import logging
    logger = logging.getLogger(__name__)
    
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")
    
    # 权限检查：只有任务发布者或接受者可以查看支付状态
    if task.poster_id != current_user.id and task.taker_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权查看此任务的支付状态")
    
    # 安全：此 API 只读取状态，不更新任何字段
    # 所有状态更新必须通过 webhook 处理
    logger.info(f"🔍 [READ-ONLY] 查询任务支付状态: task_id={task_id}, user_id={current_user.id}, is_paid={task.is_paid}")
    
    # 获取任务金额
    task_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0
    
    # 构建响应（只读）
    response = {
        "task_id": task_id,
        "is_paid": bool(task.is_paid),  # 从数据库读取，不修改
        "payment_intent_id": task.payment_intent_id,  # 从数据库读取，不修改
        "task_amount": task_amount,
        "escrow_amount": task.escrow_amount,  # 从数据库读取，不修改
        "status": task.status,  # 从数据库读取，不修改
        "currency": task.currency or "GBP",
        "payment_expires_at": task.payment_expires_at.isoformat() if task.payment_expires_at else None,
    }
    
    # 如果有 Payment Intent ID，从 Stripe 获取详细信息（只读）
    if task.payment_intent_id:
        try:
            stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
            # 检索 Payment Intent（只读，不修改）
            payment_intent = stripe.PaymentIntent.retrieve(task.payment_intent_id)
            
            response["payment_details"] = {
                "payment_intent_id": payment_intent.id,
                "status": payment_intent.status,  # succeeded, processing, requires_payment_method, etc.
                "amount": payment_intent.amount,  # 便士
                "amount_display": f"{payment_intent.amount / 100:.2f}",
                "currency": payment_intent.currency.upper(),
                "created": payment_intent.created,
                "charges": []
            }
            
            # 尝试获取关联的 Charge 信息（只读）
            # 在新版本的 Stripe API 中，charges 可能不再直接可用
            # 我们可以通过 latest_charge 或单独查询 charges 来获取
            try:
                # 方法1: 尝试使用 latest_charge（如果存在）
                if hasattr(payment_intent, 'latest_charge') and payment_intent.latest_charge:
                    charge_id = payment_intent.latest_charge
                    if isinstance(charge_id, str):
                        # 如果 latest_charge 是字符串 ID，需要单独检索
                        charge = stripe.Charge.retrieve(charge_id)
                        response["payment_details"]["charges"].append({
                            "charge_id": charge.id,
                            "status": charge.status,
                            "paid": charge.paid,
                            "amount": charge.amount,
                            "amount_display": f"{charge.amount / 100:.2f}",
                            "created": charge.created
                        })
                    else:
                        # 如果 latest_charge 已经是展开的对象
                        charge = charge_id
                        response["payment_details"]["charges"].append({
                            "charge_id": charge.id,
                            "status": charge.status,
                            "paid": charge.paid,
                            "amount": charge.amount,
                            "amount_display": f"{charge.amount / 100:.2f}",
                            "created": charge.created
                        })
                # 方法2: 尝试访问 charges 属性（旧版本 API）
                elif hasattr(payment_intent, 'charges'):
                    charges_obj = payment_intent.charges
                    if hasattr(charges_obj, 'data') and charges_obj.data:
                        for charge in charges_obj.data:
                            response["payment_details"]["charges"].append({
                                "charge_id": charge.id,
                                "status": charge.status,
                                "paid": charge.paid,
                                "amount": charge.amount,
                                "amount_display": f"{charge.amount / 100:.2f}",
                                "created": charge.created
                            })
                    elif isinstance(charges_obj, list):
                        for charge in charges_obj:
                            response["payment_details"]["charges"].append({
                                "charge_id": charge.id,
                                "status": charge.status,
                                "paid": charge.paid,
                                "amount": charge.amount,
                                "amount_display": f"{charge.amount / 100:.2f}",
                                "created": charge.created
                            })
            except (AttributeError, stripe.error.StripeError) as charge_error:
                # 如果无法获取 charge 信息，只记录警告，不影响主要功能
                logger.debug(f"Could not retrieve charge details for payment intent {task.payment_intent_id}: {charge_error}")
                
        except stripe.error.StripeError as e:
            logger.warning(f"Failed to retrieve payment intent {task.payment_intent_id}: {e}")
            response["payment_details"] = {
                "error": f"无法从 Stripe 获取支付详情: {str(e)}"
            }
    
    return response


# ==================== 签到相关 API ====================

@router.post("/checkin", response_model=schemas.CheckInResponse)
def check_in_api(
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
    request: Request = None
):
    """每日签到"""
    # 获取设备指纹和IP（如果可用）
    device_fingerprint = None
    ip_address = None
    if request:
        # TODO: 从请求头获取设备指纹
        ip_address = request.client.host if request.client else None
    
    check_in_record, error_msg = check_in(
        db,
        current_user.id,
        device_fingerprint=device_fingerprint,
        ip_address=ip_address
    )
    
    if not check_in_record:
        raise HTTPException(status_code=400, detail=error_msg or "签到失败")
    
    # 格式化奖励信息
    reward = None
    if check_in_record.reward_type == "points" and check_in_record.points_reward:
        reward = {
            "type": "points",
            "points_reward": check_in_record.points_reward,
            "points_reward_display": f"{check_in_record.points_reward / 100:.2f}",
            "description": check_in_record.reward_description or f"连续签到{check_in_record.consecutive_days}天，获得{check_in_record.points_reward / 100:.2f}积分"
        }
    elif check_in_record.reward_type == "coupon" and check_in_record.coupon_id:
        reward = {
            "type": "coupon",
            "coupon_id": check_in_record.coupon_id,
            "description": check_in_record.reward_description or f"连续签到{check_in_record.consecutive_days}天，获得优惠券"
        }
    
    return {
        "success": True,
        "check_in_date": check_in_record.check_in_date,
        "consecutive_days": check_in_record.consecutive_days,
        "reward": reward,
        "message": f"签到成功！连续签到{check_in_record.consecutive_days}天"
    }


@router.get("/checkin/status", response_model=schemas.CheckInStatus)
def get_check_in_status(
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """获取签到状态"""
    from zoneinfo import ZoneInfo
    from app.utils.time_utils import get_utc_time, to_user_timezone, LONDON
    
    # 获取当前UTC时间并转换为伦敦时区
    utc_time = get_utc_time()
    london_time = to_user_timezone(utc_time, LONDON)
    today = london_time.date()
    
    today_check_in = get_check_in_today(db, current_user.id)
    last_check_in = get_last_check_in(db, current_user.id)
    
    consecutive_days = 0
    if last_check_in:
        consecutive_days = last_check_in.consecutive_days
        if last_check_in.check_in_date < today - timedelta(days=1):
            consecutive_days = 0
    
    # TODO: 获取最近7天签到记录
    check_in_history = []
    
    return {
        "today_checked": today_check_in is not None,
        "consecutive_days": consecutive_days,
        "last_check_in_date": last_check_in.check_in_date if last_check_in else None,
        "next_check_in_date": today if not today_check_in else today + timedelta(days=1),
        "check_in_history": check_in_history
    }


@router.get("/checkin/rewards", response_model=schemas.CheckInRewardsResponse)
def get_check_in_rewards(
    db: Session = Depends(get_db)
):
    """获取签到奖励配置（用户端）"""
    rewards = db.query(models.CheckInReward).filter(
        models.CheckInReward.is_active == True
    ).order_by(models.CheckInReward.consecutive_days).all()
    
    reward_list = []
    for r in rewards:
        reward_data = {
            "consecutive_days": r.consecutive_days,
            "reward_type": r.reward_type,
            "description": r.reward_description or f"连续签到{r.consecutive_days}天奖励"
        }
        
        if r.reward_type == "points" and r.points_reward:
            reward_data["points_reward"] = r.points_reward
            reward_data["points_reward_display"] = f"{r.points_reward / 100:.2f}"
            reward_data["coupon_id"] = None
        elif r.reward_type == "coupon" and r.coupon_id:
            reward_data["points_reward"] = None
            reward_data["points_reward_display"] = None
            reward_data["coupon_id"] = r.coupon_id
        
        reward_list.append(reward_data)
    
    return {"rewards": reward_list}


# ==================== 邀请码相关 API ====================

@router.post("/invitation-codes/validate", response_model=schemas.InvitationCodeValidateResponse)
def validate_invitation_code_api(
    request: schemas.InvitationCodeValidateRequest,
    db: Session = Depends(get_db)
):
    """验证邀请码（注册前）"""
    is_valid, error_msg, invitation_code = validate_invitation_code(db, request.code)
    
    if not is_valid:
        raise HTTPException(status_code=400, detail=error_msg or "邀请码无效")
    
    points_reward_display = f"{invitation_code.points_reward / 100:.2f}"
    
    coupon = None
    if invitation_code.coupon_id:
        coupon_obj = get_coupon_by_id(db, invitation_code.coupon_id)
        if coupon_obj:
            coupon = {
                "id": coupon_obj.id,
                "name": coupon_obj.name
            }
    
    return {
        "valid": True,
        "code": invitation_code.code,
        "name": invitation_code.name,
        "reward_type": invitation_code.reward_type,
        "points_reward": invitation_code.points_reward,
        "points_reward_display": points_reward_display,
        "coupon": coupon,
        "message": f"邀请码有效，注册后可获得{points_reward_display}积分" + (f"和优惠券" if coupon else "")
    }

