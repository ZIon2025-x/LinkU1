"""
退款处理服务
处理退款申请的实际退款逻辑，包括 Stripe 退款和转账撤销
"""

import logging
import os
import hashlib
import stripe
from typing import Tuple, Optional
from sqlalchemy.orm import Session
from app import models, crud
from app.utils.time_utils import get_utc_time
from decimal import Decimal

logger = logging.getLogger(__name__)


def process_refund(
    db: Session,
    refund_request: models.RefundRequest,
    task: models.Task,
    refund_amount: float
) -> Tuple[bool, Optional[str], Optional[str], Optional[str]]:
    """
    处理退款
    
    Args:
        db: 数据库会话
        refund_request: 退款申请记录
        task: 任务记录
        refund_amount: 退款金额（英镑）
    
    Returns:
        (success, refund_intent_id, refund_transfer_id, error_message)
        - success: 是否成功
        - refund_intent_id: Stripe Refund ID（如果有）
        - refund_transfer_id: 反向转账ID（如果有）
        - error_message: 错误信息（如果失败）
    """
    try:
        # 初始化 Stripe
        stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
        if not stripe.api_key:
            return False, None, None, "Stripe API 未配置"
        
        refund_intent_id = None
        refund_transfer_id = None
        
        # 1. 处理 Stripe 支付退款
        if task.payment_intent_id:
            try:
                # 获取 PaymentIntent
                payment_intent = stripe.PaymentIntent.retrieve(task.payment_intent_id)
                
                # 检查是否已经退款
                if payment_intent.status == "canceled":
                    logger.warning(f"PaymentIntent {task.payment_intent_id} 已取消，无需退款")
                else:
                    # ✅ 修复金额精度：使用Decimal计算，然后转换为便士
                    refund_amount_decimal = Decimal(str(refund_amount))
                    refund_amount_pence = int(refund_amount_decimal * 100)
                    
                    # 获取 Charge ID（PaymentIntent 可能有多个 Charge，取第一个成功的）
                    charges = stripe.Charge.list(payment_intent=task.payment_intent_id, limit=1)
                    if charges.data:
                        charge_id = charges.data[0].id
                        
                        # ✅ 修复Stripe Idempotency：生成idempotency_key防止重复退款
                        idempotency_key = hashlib.sha256(
                            f"refund_{task.id}_{refund_request.id}_{refund_amount_pence}".encode()
                        ).hexdigest()
                        
                        # 创建退款（使用idempotency_key）
                        refund = stripe.Refund.create(
                            charge=charge_id,
                            amount=refund_amount_pence,
                            reason="requested_by_customer",
                            idempotency_key=idempotency_key,
                            metadata={
                                "task_id": str(task.id),
                                "refund_request_id": str(refund_request.id),
                                "poster_id": str(task.poster_id),
                                "taker_id": str(task.taker_id) if task.taker_id else "",
                            }
                        )
                        
                        refund_intent_id = refund.id
                        logger.info(f"✅ Stripe 退款创建成功: refund_id={refund.id}, amount=£{refund_amount:.2f}")
                    else:
                        logger.warning(f"PaymentIntent {task.payment_intent_id} 没有找到 Charge")
            except stripe.error.StripeError as e:
                logger.error(f"Stripe 退款失败: {e}")
                return False, None, None, f"Stripe 退款失败: {str(e)}"
        
        # 2. 处理已转账的情况（需要撤销转账或创建反向转账）
        if task.is_confirmed == 1 and task.escrow_amount == 0:
            # 任务已完成且已转账，需要创建反向转账
            if task.taker_id:
                taker = crud.get_user_by_id(db, task.taker_id)
                if taker and taker.stripe_account_id:
                    try:
                        # 验证 Stripe Connect 账户状态
                        account = stripe.Account.retrieve(taker.stripe_account_id)
                        if not account.details_submitted:
                            logger.warning(f"任务接受人 {task.taker_id} 的 Stripe Connect 账户未完成设置，无法创建反向转账")
                        elif not account.charges_enabled:
                            logger.warning(f"任务接受人 {task.taker_id} 的 Stripe Connect 账户未启用收款，无法创建反向转账")
                        else:
                            # 创建反向转账（从接受人账户转回平台账户）
                            # 注意：Stripe 不支持直接从 Connect 账户转账回平台账户
                            # 需要使用 Reversal 或创建新的 Transfer（但方向相反）
                            # 这里我们记录需要手动处理，或者使用 Stripe 的 Reversal API
                            
                            # ✅ 修复金额精度：使用Decimal计算，然后转换为便士
                            refund_amount_decimal = Decimal(str(refund_amount))
                            refund_amount_pence = int(refund_amount_decimal * 100)
                            
                            # 查找原始转账记录
                            from sqlalchemy import and_
                            original_transfer = db.query(models.PaymentTransfer).filter(
                                and_(
                                    models.PaymentTransfer.task_id == task.id,
                                    models.PaymentTransfer.status == "succeeded"
                                )
                            ).first()
                            
                            if original_transfer and original_transfer.transfer_id:
                                # 尝试创建 Reversal（如果 Stripe 支持）
                                try:
                                    # 注意：Stripe Transfer Reversal 需要特定条件
                                    # 如果不可用，需要记录为需要手动处理
                                    reversal = stripe.Transfer.create_reversal(
                                        original_transfer.transfer_id,
                                        amount=refund_amount_pence,
                                        metadata={
                                            "task_id": str(task.id),
                                            "refund_request_id": str(refund_request.id),
                                            "original_transfer_id": original_transfer.transfer_id,
                                        }
                                    )
                                    refund_transfer_id = reversal.id
                                    logger.info(f"✅ 创建反向转账成功: reversal_id={reversal.id}, amount=£{refund_amount:.2f}")
                                except stripe.error.StripeError as e:
                                    # Reversal 可能不可用（例如转账已结算），记录为需要手动处理
                                    logger.warning(f"无法创建反向转账: {e}。需要手动处理。")
                                    refund_transfer_id = None
                            else:
                                logger.warning(f"未找到原始转账记录，无法创建反向转账")
                    except Exception as e:
                        logger.error(f"处理反向转账时发生错误: {e}", exc_info=True)
                        # 反向转账失败不影响退款流程，但需要记录
                        refund_transfer_id = None
        
        # 3. 更新任务状态和托管金额
        # ✅ 修复金额精度：使用Decimal进行金额比较
        # ✅ 支持部分退款：更新托管金额
        task_amount = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
        refund_amount_decimal = Decimal(str(refund_amount))
        
        if refund_amount_decimal >= task_amount:
            # 全额退款
            task.is_paid = 0
            task.payment_intent_id = None
            task.escrow_amount = 0.0
            logger.info(f"✅ 全额退款，已更新任务支付状态")
        else:
            # 部分退款：更新托管金额
            # 计算退款后的剩余金额
            remaining_amount = task_amount - refund_amount_decimal
            from app.utils.fee_calculator import calculate_application_fee
            application_fee = calculate_application_fee(float(remaining_amount))
            new_escrow_amount = remaining_amount - Decimal(str(application_fee))
            
            # 更新托管金额（任务金额 - 退款金额 - 平台服务费）
            task.escrow_amount = float(max(Decimal('0'), new_escrow_amount))
            logger.info(f"✅ 部分退款：退款金额 £{refund_amount:.2f}，剩余任务金额 £{remaining_amount:.2f}，更新后托管金额 £{task.escrow_amount:.2f}")
        
        # 4. 退还优惠券（如果需要）
        # 注意：积分支付已禁用，不需要退还积分
        try:
            # 查找 PaymentHistory 记录
            payment_history = db.query(models.PaymentHistory).filter(
                models.PaymentHistory.task_id == task.id,
                models.PaymentHistory.status == "succeeded"
            ).order_by(models.PaymentHistory.created_at.desc()).first()
            
            if payment_history and payment_history.coupon_usage_log_id:
                # 查找优惠券使用记录
                from app.coupon_points_crud import get_coupon_usage_log, restore_coupon
                coupon_usage_log = get_coupon_usage_log(db, payment_history.coupon_usage_log_id)
                
                if coupon_usage_log and coupon_usage_log.coupon_id:
                    # 恢复优惠券状态（标记为未使用）
                    success = restore_coupon(db, coupon_usage_log.coupon_id, coupon_usage_log.user_id)
                    if success:
                        logger.info(f"✅ 已恢复优惠券（ID: {coupon_usage_log.coupon_id}）")
                    else:
                        logger.warning(f"恢复优惠券失败（ID: {coupon_usage_log.coupon_id}），可能需要手动处理")
        except Exception as e:
            logger.warning(f"处理优惠券退还时发生错误: {e}，不影响退款流程")
        
        return True, refund_intent_id, refund_transfer_id, None
        
    except Exception as e:
        logger.error(f"处理退款时发生错误: {e}", exc_info=True)
        return False, None, None, f"处理退款时发生错误: {str(e)}"
