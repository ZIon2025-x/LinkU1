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

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["优惠券和积分系统"])


# ==================== 积分相关 API ====================

@router.get("/points/account", response_model=schemas.PointsAccountOut)
def get_account_info(
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """获取积分账户信息"""
    account = get_or_create_points_account(db, current_user.id)
    
    # 格式化显示
    balance_display = f"{account.balance / 100:.2f}"
    
    return {
        "balance": account.balance,
        "balance_display": balance_display,
        "currency": account.currency,
        "total_earned": account.total_earned,
        "total_spent": account.total_spent,
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
    # TODO: 实现积分兑换优惠券逻辑
    raise HTTPException(status_code=501, detail="功能开发中")


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
            "usage_conditions": coupon.usage_conditions
        })
    
    return {"data": data}


@router.post("/coupons/claim")
def claim_coupon_api(
    request: schemas.CouponClaimRequest,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """领取优惠券"""
    if request.coupon_id:
        coupon_id = request.coupon_id
    elif request.promotion_code:
        # TODO: 通过推广码查找优惠券
        raise HTTPException(status_code=501, detail="推广码功能开发中")
    else:
        raise HTTPException(status_code=400, detail="必须提供coupon_id或promotion_code")
    
    user_coupon = claim_coupon(
        db,
        current_user.id,
        coupon_id,
        idempotency_key=request.idempotency_key
    )
    
    if not user_coupon:
        raise HTTPException(status_code=400, detail="领取失败，请检查优惠券是否可用或已达到领取限制")
    
    return {
        "user_coupon_id": user_coupon.id,
        "coupon_id": user_coupon.coupon_id,
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
def create_task_payment(
    task_id: int,
    payment_request: schemas.TaskPaymentRequest,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """创建任务支付（支持积分和优惠券抵扣平台服务费）"""
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
    from sqlalchemy.orm import with_for_update
    
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
        application_fee_rate_setting = get_system_setting(db, "application_fee_rate")
        application_fee_rate = float(application_fee_rate_setting.setting_value) if application_fee_rate_setting else 0.10
        task_amount_pence = int(task_amount * 100)
        application_fee_pence = int(task_amount_pence * application_fee_rate)
        
        return {
            "payment_id": None,
            "fee_type": "task_amount",
            "total_amount": task_amount_pence,
            "total_amount_display": f"{task_amount_pence / 100:.2f}",
            "points_used": None,
            "points_used_display": None,
            "coupon_discount": None,
            "coupon_discount_display": None,
            "stripe_amount": None,
            "stripe_amount_display": None,
            "currency": "GBP",
            "final_amount": 0,
            "final_amount_display": "0.00",
            "checkout_url": None,
            "client_secret": None,
            "payment_intent_id": None,
            "note": "任务已支付"
        }
    
    # 检查任务状态：只有 pending_payment 状态的任务需要支付
    if task.status != "pending_payment":
        raise HTTPException(
            status_code=400, 
            detail=f"任务状态不正确，无法支付。当前状态：{task.status}，需要状态：pending_payment（等待支付）"
        )
    
    # 计算平台服务费（申请费）- 从任务接受人端扣除
    # 假设平台服务费为任务金额的10%，或从系统设置读取
    application_fee_rate_setting = get_system_setting(db, "application_fee_rate")
    application_fee_rate = float(application_fee_rate_setting.setting_value) if application_fee_rate_setting else 0.10  # 默认10%
    
    # 获取任务金额（使用最终成交价或原始标价）
    task_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0
    
    # 验证任务金额必须大于0
    if task_amount <= 0:
        raise HTTPException(
            status_code=400,
            detail="任务金额必须大于0，无法进行支付"
        )
    
    task_amount_pence = int(task_amount * 100)  # 转换为最小货币单位
    
    # 计算平台服务费（从接受人端扣除，包含Stripe服务费）
    application_fee_pence = int(task_amount_pence * application_fee_rate)
    
    # 验证平台服务费必须大于0
    if application_fee_pence <= 0:
        raise HTTPException(
            status_code=400,
            detail="平台服务费计算错误，无法进行支付"
        )
    
    # 发布者支付任务金额（可优惠券/积分抵扣）
    total_amount = task_amount_pence
    
    # 初始化变量
    points_used = 0
    coupon_discount = 0
    user_coupon_id_used = None
    coupon_usage_log = None
    
    # 处理积分抵扣（使用 SELECT FOR UPDATE 锁定积分账户，防止并发扣款）
    if payment_request.payment_method in ["points", "mixed"] and payment_request.points_amount:
        # 输入验证：积分数量必须是正数
        if payment_request.points_amount <= 0:
            raise HTTPException(
                status_code=400,
                detail="积分数量必须大于0"
            )
        
        # 输入验证：积分数量不能超过合理范围（例如 100万积分 = £10,000）
        MAX_POINTS_AMOUNT = 100_000_000  # 100万积分
        if payment_request.points_amount > MAX_POINTS_AMOUNT:
            raise HTTPException(
                status_code=400,
                detail=f"积分数量超出最大限制：{MAX_POINTS_AMOUNT / 100:.2f}"
            )
        
        # 使用 SELECT FOR UPDATE 锁定积分账户，防止并发时余额计算错误
        points_account_query = select(models.PointsAccount).where(
            models.PointsAccount.user_id == current_user.id
        ).with_for_update()
        points_account_result = db.execute(points_account_query)
        points_account = points_account_result.scalar_one_or_none()
        
        # 如果账户不存在，创建新账户
        if not points_account:
            points_account = models.PointsAccount(
                user_id=current_user.id,
                balance=0,
                currency="GBP",
                total_earned=0,
                total_spent=0
            )
            db.add(points_account)
            db.flush()  # 刷新以获取ID
        
        # 在锁内重新检查余额（防止并发时余额变化）
        if points_account.balance < payment_request.points_amount:
            raise HTTPException(
                status_code=400,
                detail=f"积分不足，当前余额：{points_account.balance / 100:.2f}，需要：{payment_request.points_amount / 100:.2f}"
            )
        
        # 积分可以抵扣任务金额
        points_used = min(payment_request.points_amount, total_amount)
        total_amount -= points_used
    
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
    
    # 计算最终需要支付的金额
    final_amount = max(0, total_amount)
    
    # 如果使用积分全额抵扣，直接完成支付
    if final_amount == 0 and points_used > 0:
        try:
            # 使用幂等性 key 防止重复扣款
            idempotency_key = f"task_payment_points_{task_id}_{current_user.id}"
            
            # 检查是否已存在相同的交易（幂等性检查）
            existing_transaction = db.query(models.PointsTransaction).filter(
                models.PointsTransaction.idempotency_key == idempotency_key
            ).first()
            
            if existing_transaction:
                # 如果交易已存在，检查任务是否已支付
                if task.is_paid:
                    # 返回已支付的信息
                    return {
                        "payment_id": None,
                        "fee_type": "task_amount",
                        "total_amount": task_amount_pence,
                        "total_amount_display": f"{task_amount_pence / 100:.2f}",
                        "points_used": points_used,
                        "points_used_display": f"{points_used / 100:.2f}",
                        "coupon_discount": coupon_discount,
                        "coupon_discount_display": f"{coupon_discount / 100:.2f}" if coupon_discount else None,
                        "stripe_amount": None,
                        "stripe_amount_display": None,
                        "currency": "GBP",
                        "final_amount": 0,
                        "final_amount_display": "0.00",
                        "checkout_url": None,
                        "client_secret": None,
                        "payment_intent_id": None,
                        "note": f"任务金额已支付，任务接受人将获得 {task_amount - (application_fee_pence / 100.0):.2f} 镑（已扣除平台服务费 {application_fee_pence / 100.0:.2f} 镑）"
                    }
                # 如果交易存在但任务未支付，继续处理（可能是部分失败的情况）
            
            # 创建积分交易记录（add_points_transaction 会自动更新账户余额）
            # 注意：spend 类型的 amount 必须为负数
            add_points_transaction(
                db,
                current_user.id,
                type="spend",
                amount=-points_used,  # 消费用负数
                source="task_payment",
                related_id=task_id,
                related_type="task",
                description=f"任务 #{task_id} 任务金额支付",
                idempotency_key=idempotency_key
            )
            
            # 标记任务为已支付（积分支付，没有 payment_intent_id）
            task.is_paid = 1
            task.payment_intent_id = None  # 积分支付没有 Payment Intent
            # escrow_amount = 任务金额 - 平台服务费（任务接受人获得的金额）
            taker_amount = task_amount - (application_fee_pence / 100.0)
            task.escrow_amount = max(0.0, taker_amount)  # 确保不为负数
            # 支付成功后，将任务状态从 pending_payment 更新为 in_progress
            if task.status == "pending_payment":
                task.status = "in_progress"
            
            db.commit()
        except Exception as e:
            db.rollback()
            logger.error(f"积分支付失败: {e}")
            raise HTTPException(
                status_code=500,
                detail=f"积分支付处理失败，请稍后重试"
            )
        
        return {
            "payment_id": None,
            "fee_type": "task_amount",
            "total_amount": task_amount_pence,
            "total_amount_display": f"{task_amount_pence / 100:.2f}",
            "points_used": points_used,
            "points_used_display": f"{points_used / 100:.2f}",
            "coupon_discount": coupon_discount,
            "coupon_discount_display": f"{coupon_discount / 100:.2f}" if coupon_discount else None,
            "stripe_amount": None,
            "stripe_amount_display": None,
            "currency": "GBP",
            "final_amount": 0,
            "final_amount_display": "0.00",
            "checkout_url": None,
            "note": f"任务金额已支付，任务接受人将获得 {task_amount - (application_fee_pence / 100.0):.2f} 镑（已扣除平台服务费 {application_fee_pence / 100.0:.2f} 镑）"
        }
    
    # 如果需要Stripe支付
    if final_amount > 0:
        stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
        
        # 获取任务接受人的 Stripe Connect 账户 ID
        taker = db.query(models.User).filter(models.User.id == task.taker_id).first()
        if not taker or not taker.stripe_account_id:
            raise HTTPException(
                status_code=400,
                detail="任务接受人尚未设置 Stripe Connect 收款账户，无法进行支付"
            )
        
        # 创建 Payment Intent（用于 Stripe Elements 嵌入式支付表单）
        # 使用 Stripe Connect Platform charges 模式（Direct charges）
        # on_behalf_of: 指定资金将转到任务接受人的账户（Direct charges 模式）
        # application_fee_amount: 平台服务费（从任务接受人端扣除）
        # 注意：在 Direct charges 模式下，资金会自动转到 on_behalf_of 指定的账户
        # 任务接受人实际收到的金额 = final_amount - application_fee_amount
        payment_intent = stripe.PaymentIntent.create(
            amount=final_amount,  # 便士（发布者需要支付的金额，可能已扣除积分和优惠券）
            currency="gbp",
            payment_method_types=["card"],
            # Stripe Connect Direct charges: 将资金转到任务接受人的账户
            on_behalf_of=taker.stripe_account_id,
            # 平台服务费（从任务接受人端扣除）
            # 注意：application_fee_amount 是基于任务总金额计算的，不是基于 final_amount
            # 但实际扣除时，Stripe 会从 final_amount 中扣除 application_fee_amount
            application_fee_amount=application_fee_pence,
            metadata={
                "task_id": str(task_id),
                "user_id": str(current_user.id),
                "taker_id": str(task.taker_id),
                "task_amount": str(task_amount_pence),  # 任务金额
                "points_used": str(points_used) if points_used else "",
                "coupon_usage_log_id": str(coupon_usage_log.id) if coupon_usage_log else "",
                "application_fee": str(application_fee_pence)  # 平台服务费（从接受人端扣除）
            },
            description=f"任务 #{task_id} 任务金额支付 - {task.title}",
        )
        
        return {
            "payment_id": None,
            "fee_type": "task_amount",
            "total_amount": task_amount_pence,
            "total_amount_display": f"{task_amount_pence / 100:.2f}",
            "points_used": points_used,
            "points_used_display": f"{points_used / 100:.2f}" if points_used else None,
            "coupon_discount": coupon_discount,
            "coupon_discount_display": f"{coupon_discount / 100:.2f}" if coupon_discount else None,
            "stripe_amount": final_amount,
            "stripe_amount_display": f"{final_amount / 100:.2f}",
            "currency": "GBP",
            "final_amount": final_amount,
            "final_amount_display": f"{final_amount / 100:.2f}",
            "checkout_url": None,  # Payment Intent 不需要 checkout_url
            "client_secret": payment_intent.client_secret,  # 前端需要这个来确认支付
            "payment_intent_id": payment_intent.id,
            "note": f"任务金额已支付，任务接受人将获得 {task_amount - (application_fee_pence / 100.0):.2f} 镑（已扣除平台服务费 {application_fee_pence / 100.0:.2f} 镑）"
        }
    
    raise HTTPException(status_code=400, detail="支付金额计算错误")


@router.get("/tasks/{task_id}/payment-status")
def get_task_payment_status(
    task_id: int,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    查询任务支付状态
    
    返回任务的支付信息，包括：
    - 是否已支付
    - Payment Intent ID（如果使用 Stripe 支付）
    - 支付金额
    - 托管金额
    """
    import stripe
    import os
    
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")
    
    # 权限检查：只有任务发布者或接受者可以查看支付状态
    if task.poster_id != current_user.id and task.taker_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权查看此任务的支付状态")
    
    # 获取任务金额
    task_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0
    
    # 构建响应
    response = {
        "task_id": task_id,
        "is_paid": bool(task.is_paid),
        "payment_intent_id": task.payment_intent_id,
        "task_amount": task_amount,
        "escrow_amount": task.escrow_amount,
        "status": task.status,
        "currency": task.currency or "GBP"
    }
    
    # 如果有 Payment Intent ID，从 Stripe 获取详细信息
    if task.payment_intent_id:
        try:
            stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
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
            
            # 获取关联的 Charge 信息
            if payment_intent.charges and len(payment_intent.charges.data) > 0:
                for charge in payment_intent.charges.data:
                    response["payment_details"]["charges"].append({
                        "charge_id": charge.id,
                        "status": charge.status,
                        "paid": charge.paid,
                        "amount": charge.amount,
                        "amount_display": f"{charge.amount / 100:.2f}",
                        "created": charge.created
                    })
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

