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
        # ✅ 安全修复：考虑已转账的情况
        task_amount = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
        refund_amount_decimal = Decimal(str(refund_amount))
        
        # ✅ 计算已转账的总金额
        from sqlalchemy import func, and_
        total_transferred = db.query(
            func.sum(models.PaymentTransfer.amount).label('total_transferred')
        ).filter(
            and_(
                models.PaymentTransfer.task_id == task.id,
                models.PaymentTransfer.status == "succeeded"
            )
        ).scalar() or Decimal('0')
        total_transferred = Decimal(str(total_transferred)) if total_transferred else Decimal('0')
        
        # ✅ 计算当前可用的escrow金额
        current_escrow = Decimal(str(task.escrow_amount)) if task.escrow_amount else Decimal('0')
        
        # ✅ 验证退款金额不超过可用金额（考虑已转账）
        if total_transferred > 0:
            # 如果已经转账，可用退款金额 = 任务金额 - 已转账金额
            max_refundable = task_amount - total_transferred
            if refund_amount_decimal > max_refundable:
                logger.error(f"退款金额（£{refund_amount_decimal}）超过可退款金额（£{max_refundable}），已转账：£{total_transferred}")
                return False, None, None, f"退款金额超过可退款金额。可退款金额：£{max_refundable:.2f}，已转账：£{total_transferred:.2f}"
        elif refund_amount_decimal > current_escrow:
            # 如果没有转账，验证不超过当前escrow
            logger.error(f"退款金额（£{refund_amount_decimal}）超过可用escrow（£{current_escrow}）")
            return False, None, None, f"退款金额超过可用金额。可用金额：£{current_escrow:.2f}"
        
        if refund_amount_decimal >= task_amount:
            # 全额退款
            task.is_paid = 0
            task.payment_intent_id = None
            task.escrow_amount = 0.0
            # 新增：更新任务状态为已取消
            task.status = "cancelled"
            task.confirmed_at = get_utc_time()  # 记录确认时间
            task.auto_confirmed = 1  # 标记为自动确认（通过退款）
            logger.info(f"✅ 全额退款，任务状态已更新为 cancelled")
        else:
            # 部分退款：更新托管金额
            # ✅ 计算退款后的剩余金额（最终成交金额）
            remaining_amount = task_amount - refund_amount_decimal
            
            # ✅ 基于剩余金额重新计算平台服务费
            # 例如：原任务£100，退款£50，剩余£50
            # 服务费基于£50重新计算：£50 >= £10，所以是10% = £5
            # 接单人应得：£50 - £5 = £45
            from app.utils.fee_calculator import calculate_application_fee
            application_fee = calculate_application_fee(float(remaining_amount))
            new_escrow_amount = remaining_amount - Decimal(str(application_fee))
            
            # ✅ 如果已经进行了部分转账，需要从剩余金额中扣除已转账部分
            if total_transferred > 0:
                # 已转账的情况下，新的escrow应该是：剩余金额 - 已转账金额 - 服务费
                # 但服务费是基于剩余金额计算的，所以：
                # 新的escrow = 剩余金额 - 服务费 - 已转账金额
                # 但已转账金额已经转出去了，所以新的escrow应该是：剩余金额 - 服务费
                # 不过需要考虑：如果已经转账了部分，那么剩余可转账金额应该是：剩余金额 - 服务费 - 已转账金额
                remaining_after_transfer = remaining_amount - total_transferred
                if remaining_after_transfer > 0:
                    # 重新计算服务费（基于剩余金额）
                    remaining_application_fee = calculate_application_fee(float(remaining_amount))
                    new_escrow_amount = remaining_amount - Decimal(str(remaining_application_fee)) - total_transferred
                else:
                    # 如果剩余金额已经全部转账，escrow为0
                    new_escrow_amount = Decimal('0')
            
            # 更新托管金额（确保不为负数）
            task.escrow_amount = float(max(Decimal('0'), new_escrow_amount))
            logger.info(f"✅ 部分退款：退款金额 £{refund_amount:.2f}，剩余任务金额 £{remaining_amount:.2f}，已转账 £{total_transferred:.2f}，服务费 £{application_fee:.2f}，更新后托管金额 £{task.escrow_amount:.2f}")
            
            # 新增：部分退款后，任务状态更新为 completed
            # 原因：部分退款是发布者申请的，说明剩余部分已同意，应该给接单人
            task.status = "completed"
            task.confirmed_at = get_utc_time()  # 记录确认时间
            task.auto_confirmed = 1  # 标记为自动确认（通过部分退款）
            # 注意：is_confirmed 在转账成功后再更新，确保转账完成
            
            logger.info(f"✅ 部分退款：任务状态已更新为 completed，准备转账剩余金额 £{task.escrow_amount:.2f}")
            
            # 新增：自动触发转账给接单人（如果 escrow_amount > 0）
            if task.taker_id and task.escrow_amount > 0:
                try:
                    from app.payment_transfer_service import create_transfer_record, execute_transfer
                    from app import crud
                    from sqlalchemy import and_, func
                    
                    # ✅ 安全检查：检查是否已有成功的转账记录（防止重复转账）
                    existing_success_transfers = db.query(
                        func.sum(models.PaymentTransfer.amount).label('total_transferred')
                    ).filter(
                        and_(
                            models.PaymentTransfer.task_id == task.id,
                            models.PaymentTransfer.status == "succeeded"
                        )
                    ).scalar() or Decimal('0')
                    total_transferred_check = Decimal(str(existing_success_transfers))
                    
                    # 如果已全额转账，跳过
                    if total_transferred_check >= Decimal(str(task.escrow_amount)):
                        logger.info(f"任务 {task.id} 已全额转账，跳过部分退款后的转账")
                        task.is_confirmed = 1
                        task.paid_to_user_id = task.taker_id
                        task.escrow_amount = 0.0
                    else:
                        # 计算剩余可转账金额
                        remaining_escrow = Decimal(str(task.escrow_amount))
                        remaining_after_transfer = remaining_escrow - total_transferred_check
                        
                        if remaining_after_transfer > 0:
                            taker = crud.get_user_by_id(db, task.taker_id)
                            if taker and taker.stripe_account_id:
                                # ✅ 安全检查：检查是否已有待处理的转账记录
                                existing_pending_transfer = db.query(models.PaymentTransfer).filter(
                                    and_(
                                        models.PaymentTransfer.task_id == task.id,
                                        models.PaymentTransfer.status.in_(["pending", "retrying"])
                                    )
                                ).first()
                                
                                if existing_pending_transfer:
                                    logger.info(f"任务 {task.id} 已有待处理的转账记录，使用现有记录")
                                    transfer_record = existing_pending_transfer
                                else:
                                    # 创建转账记录
                                    transfer_record = create_transfer_record(
                                        db,
                                        task_id=task.id,
                                        taker_id=task.taker_id,
                                        poster_id=task.poster_id,
                                        amount=remaining_after_transfer,  # 只转账剩余部分
                                        currency="GBP",
                                        metadata={
                                            "task_title": task.title,
                                            "transfer_source": "partial_refund_auto",
                                            "refund_request_id": str(refund_request.id),
                                            "remaining_escrow": str(remaining_after_transfer),
                                            "total_transferred": str(total_transferred_check)
                                        }
                                    )
                                
                                # 执行转账
                                success, transfer_id, error_msg = execute_transfer(db, transfer_record, taker.stripe_account_id)
                                
                                if success:
                                    # 转账成功，更新任务状态
                                    new_escrow = remaining_escrow - remaining_after_transfer
                                    if new_escrow <= Decimal('0.01'):  # 允许小的浮点误差
                                        task.escrow_amount = 0.0
                                        task.is_confirmed = 1
                                        task.paid_to_user_id = task.taker_id
                                        logger.info(f"✅ 部分退款后自动转账成功：任务 {task.id}，已全额转账")
                                    else:
                                        task.escrow_amount = float(new_escrow)
                                        logger.info(f"✅ 部分退款后自动转账成功：任务 {task.id}，转账金额 £{remaining_after_transfer:.2f}，剩余 £{new_escrow:.2f}")
                                else:
                                    # 转账失败，不更新 is_confirmed，等待定时任务重试
                                    logger.warning(f"⚠️ 部分退款后自动转账失败：{error_msg}，转账记录已创建，定时任务将自动重试")
                            elif taker and not taker.stripe_account_id:
                                # 接单人未设置 Stripe 账户，创建转账记录等待设置
                                create_transfer_record(
                                    db,
                                    task_id=task.id,
                                    taker_id=task.taker_id,
                                    poster_id=task.poster_id,
                                    amount=remaining_after_transfer,
                                    currency="GBP",
                                    metadata={
                                        "task_title": task.title,
                                        "transfer_source": "partial_refund_auto",
                                        "refund_request_id": str(refund_request.id),
                                        "reason": "taker_stripe_account_not_setup"
                                    }
                                )
                                logger.info(f"✅ 部分退款后已创建转账记录，等待接单人设置 Stripe 账户")
                except Exception as e:
                    logger.error(f"部分退款后自动转账失败：{e}", exc_info=True)
                    # 转账失败不影响退款流程，定时任务会自动重试
        
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
