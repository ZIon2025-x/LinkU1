"""
支付转账服务
处理任务完成后的转账逻辑，支持重试和审计
"""
import logging
import stripe
import os
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any
from decimal import Decimal

from sqlalchemy.orm import Session
from sqlalchemy import select, and_, or_

from app import models
from app.utils.time_utils import get_utc_time
from app.stripe_config import configure_stripe, get_stripe_client

logger = logging.getLogger(__name__)

# 初始化 Stripe 配置（带超时）
configure_stripe()

# 重试延迟配置（指数退避）
RETRY_DELAYS = [
    60,      # 1分钟后重试
    300,     # 5分钟后重试
    900,     # 15分钟后重试
    3600,    # 1小时后重试
    14400,   # 4小时后重试
    86400,   # 24小时后重试（最后一次）
]


def create_transfer_record(
    db: Session,
    task_id: int,
    taker_id: str,
    poster_id: str,
    amount: Decimal,
    currency: str = "GBP",
    metadata: Optional[Dict[str, Any]] = None
) -> models.PaymentTransfer:
    """
    创建转账记录
    
    Returns:
        PaymentTransfer: 创建的转账记录
    """
    transfer_record = models.PaymentTransfer(
        task_id=task_id,
        taker_id=taker_id,
        poster_id=poster_id,
        amount=amount,
        currency=currency,
        status="pending",
        retry_count=0,
        max_retries=len(RETRY_DELAYS),
        extra_metadata=metadata or {}
    )
    db.add(transfer_record)
    
    # 使用安全提交，带错误处理和回滚
    from app.transaction_utils import safe_commit
    if not safe_commit(db, f"创建转账记录 task_id={task_id}"):
        raise Exception("创建转账记录失败")
    
    db.refresh(transfer_record)
    
    logger.info(f"✅ 创建转账记录: task_id={task_id}, amount={amount}, transfer_record_id={transfer_record.id}")
    return transfer_record


def execute_transfer(
    db: Session,
    transfer_record: models.PaymentTransfer,
    taker_stripe_account_id: str
) -> tuple[bool, Optional[str], Optional[str]]:
    """
    执行 Stripe Transfer 转账
    
    Args:
        db: 数据库会话
        transfer_record: 转账记录
        taker_stripe_account_id: 接受人的 Stripe Connect 账户ID
    
    Returns:
        (success, transfer_id, error_message)
    """
    # 使用配置好的 Stripe 客户端（已设置超时）
    stripe_client = get_stripe_client()
    if not stripe_client or not stripe_client.api_key:
        return False, None, "Stripe API 未配置"
    
    try:
        # 检查任务状态
        task = db.query(models.Task).filter(models.Task.id == transfer_record.task_id).first()
        if not task:
            return False, None, "任务不存在"
        
        if task.is_confirmed == 1 and task.escrow_amount == 0:
            # 任务已确认且托管金额已清空，可能已经转账成功
            logger.warning(f"任务 {transfer_record.task_id} 已确认，但转账记录状态为 {transfer_record.status}")
            # 检查是否有成功的转账记录
            existing_success = db.query(models.PaymentTransfer).filter(
                and_(
                    models.PaymentTransfer.task_id == transfer_record.task_id,
                    models.PaymentTransfer.status == "succeeded"
                )
            ).first()
            if existing_success:
                logger.info(f"任务 {transfer_record.task_id} 已有成功的转账记录，跳过")
                return True, existing_success.transfer_id, None
        
        # 验证 Stripe Connect 账户状态（带超时）
        try:
            account = stripe_client.Account.retrieve(taker_stripe_account_id)
            if not account.details_submitted:
                error_msg = "任务接受人的 Stripe Connect 账户尚未完成设置"
                logger.warning(f"{error_msg}: taker_id={transfer_record.taker_id}")
                return False, None, error_msg
            if not account.charges_enabled:
                error_msg = "任务接受人的 Stripe Connect 账户尚未启用收款"
                logger.warning(f"{error_msg}: taker_id={transfer_record.taker_id}")
                return False, None, error_msg
        except stripe.error.StripeError as e:
            error_msg = f"无法验证 Stripe Connect 账户: {str(e)}"
            logger.error(f"{error_msg}: account_id={taker_stripe_account_id}")
            return False, None, error_msg
        
        # 计算转账金额（便士）
        transfer_amount_pence = int(float(transfer_record.amount) * 100)
        
        if transfer_amount_pence <= 0:
            error_msg = "转账金额必须大于0"
            logger.error(f"{error_msg}: amount={transfer_record.amount}")
            return False, None, error_msg
        
        # 检查主账户可用余额（仅用于日志记录，不影响转账）
        # 注意：Transfer 使用主账户的可用余额（available balance），不是总余额
        # 如果资金还在 pending 状态，需要等待资金可用后才能转账
        try:
            balance = stripe_client.Balance.retrieve()
            available_balance = balance.available[0].amount if balance.available else 0
            pending_balance = balance.pending[0].amount if balance.pending else 0
            logger.info(
                f"💰 主账户余额检查: "
                f"需要转账={transfer_amount_pence} 便士 (£{transfer_record.amount:.2f}), "
                f"可用余额={available_balance} 便士 (£{available_balance/100:.2f}), "
                f"待处理余额={pending_balance} 便士 (£{pending_balance/100:.2f})"
            )
            
            if available_balance < transfer_amount_pence:
                logger.warning(
                    f"⚠️ 主账户可用余额不足: "
                    f"需要={transfer_amount_pence} 便士 (£{transfer_record.amount:.2f}), "
                    f"可用={available_balance} 便士 (£{available_balance/100:.2f})。"
                    f"如果资金还在 pending 状态（待处理余额={pending_balance} 便士），需要等待资金可用后才能转账。"
                )
        except Exception as e:
            logger.warning(f"无法获取主账户余额信息: {e}")
        
        # 详细记录金额信息，便于调试和验证
        logger.info(
            f"💰 转账金额详情: "
            f"task_id={transfer_record.task_id}, "
            f"原始金额={transfer_record.amount} 英镑, "
            f"转账金额={transfer_amount_pence} 便士 (£{transfer_amount_pence/100:.2f}), "
            f"destination={taker_stripe_account_id} (从主账户转到 Connect 子账户)"
        )
        
        # 创建 Transfer（从主账户转到 Connect 子账户）
        # 注意：Transfer 使用主账户的可用余额（available balance），不是总余额
        # 如果资金还在 pending 状态，需要等待资金可用后才能转账
        transfer = stripe_client.Transfer.create(
            amount=transfer_amount_pence,
            currency=transfer_record.currency.lower(),
            destination=taker_stripe_account_id,  # Connect 子账户 ID
            metadata={
                "task_id": str(transfer_record.task_id),
                "taker_id": str(transfer_record.taker_id),
                "poster_id": str(transfer_record.poster_id),
                "transfer_record_id": str(transfer_record.id),
                "transfer_type": "task_reward"
            },
            description=f"任务 #{transfer_record.task_id} 奖励"
        )
        
        logger.info(f"✅ Transfer 创建成功: transfer_id={transfer.id}, amount=£{transfer_record.amount:.2f}")
        
        # 更新转账记录：状态设为 pending，等待 webhook 确认
        transfer_record.transfer_id = transfer.id
        transfer_record.status = "pending"  # 等待 webhook 确认，不立即设为 succeeded
        transfer_record.last_error = None
        # 不更新 succeeded_at 和 next_retry_at，等待 webhook 确认后再更新
        
        # 不更新任务状态，等待 webhook 确认后再更新
        # task.is_confirmed = 1
        # task.paid_to_user_id = transfer_record.taker_id
        # task.escrow_amount = Decimal('0.0')
        
        # 使用安全提交，带错误处理和回滚
        from app.transaction_utils import safe_commit
        if not safe_commit(db, f"更新转账记录 transfer_id={transfer.id}"):
            raise Exception("更新转账记录失败")
        
        logger.info(f"✅ 任务 {transfer_record.task_id} Transfer 已创建，等待 webhook 确认: transfer_id={transfer.id}")
        return True, transfer.id, None
        
    except stripe.error.StripeError as e:
        error_msg = f"Stripe 转账错误: {str(e)}"
        error_type = type(e).__name__
        error_code = getattr(e, 'code', None)
        
        logger.error(f"{error_msg}: task_id={transfer_record.task_id}, error_type={error_type}, error_code={error_code}")
        
        # 对于余额不足错误，提供更详细的说明
        if error_code == 'balance_insufficient':
            try:
                balance = stripe_client.Balance.retrieve()
                available_balance = balance.available[0].amount if balance.available else 0
                pending_balance = balance.pending[0].amount if balance.pending else 0
                logger.error(
                    f"❌ 主账户可用余额不足详情: "
                    f"需要转账 {transfer_amount_pence} 便士 (£{transfer_record.amount:.2f}), "
                    f"主账户可用余额={available_balance} 便士 (£{available_balance/100:.2f}), "
                    f"待处理余额={pending_balance} 便士 (£{pending_balance/100:.2f})。"
                    f"注意：Transfer 使用可用余额（available balance），不是总余额。"
                    f"如果资金还在 pending 状态，需要等待资金可用后才能转账。"
                )
            except Exception as balance_error:
                logger.warning(f"无法获取余额详情: {balance_error}")
        
        # 对于余额不足等可重试的错误，更新转账记录状态为 retrying
        if error_code in ['balance_insufficient', 'account_invalid', 'rate_limit']:
            transfer_record.status = "retrying"
            transfer_record.last_error = error_msg
            transfer_record.retry_count += 1
            if transfer_record.retry_count < transfer_record.max_retries:
                retry_index = min(transfer_record.retry_count - 1, len(RETRY_DELAYS) - 1)
                delay_seconds = RETRY_DELAYS[retry_index]
                transfer_record.next_retry_at = get_utc_time() + timedelta(seconds=delay_seconds)
                logger.info(f"🔄 转账失败但可重试，已设置重试: transfer_record_id={transfer_record.id}, retry_count={transfer_record.retry_count}, next_retry_at={transfer_record.next_retry_at}")
            else:
                transfer_record.status = "failed"
                transfer_record.next_retry_at = None
                logger.error(f"❌ 转账失败且已达到最大重试次数: transfer_record_id={transfer_record.id}")
            # 使用安全提交，带错误处理和回滚
            from app.transaction_utils import safe_commit
            if not safe_commit(db, f"更新转账记录状态 transfer_record_id={transfer_record.id}"):
                logger.error(f"更新转账记录状态失败: transfer_record_id={transfer_record.id}")
        
        return False, None, error_msg
    except Exception as e:
        error_msg = f"转账处理错误: {str(e)}"
        logger.error(f"{error_msg}: task_id={transfer_record.task_id}", exc_info=True)
        return False, None, error_msg


def retry_failed_transfer(
    db: Session,
    transfer_record: models.PaymentTransfer
) -> tuple[bool, Optional[str]]:
    """
    重试失败的转账
    
    Args:
        db: 数据库会话
        transfer_record: 转账记录
    
    Returns:
        (success, error_message)
    """
    # 检查是否超过最大重试次数
    if transfer_record.retry_count >= transfer_record.max_retries:
        transfer_record.status = "failed"
        transfer_record.next_retry_at = None
        from app.transaction_utils import safe_commit
        if not safe_commit(db, f"标记转账记录为失败 transfer_record_id={transfer_record.id}"):
            logger.error(f"标记转账记录为失败时提交失败: transfer_record_id={transfer_record.id}")
        logger.warning(f"转账记录 {transfer_record.id} 已达到最大重试次数，标记为失败")
        return False, "已达到最大重试次数"
    
    # 检查是否到了重试时间
    if transfer_record.next_retry_at and transfer_record.next_retry_at > get_utc_time():
        logger.debug(f"转账记录 {transfer_record.id} 尚未到重试时间")
        return False, "尚未到重试时间"
    
    # 获取任务接受人的 Stripe Connect 账户ID
    taker = db.query(models.User).filter(models.User.id == transfer_record.taker_id).first()
    if not taker:
        error_msg = "任务接受人不存在"
        transfer_record.status = "failed"
        transfer_record.last_error = error_msg
        from app.transaction_utils import safe_commit
        if not safe_commit(db, f"标记转账记录为失败（接受人不存在） transfer_record_id={transfer_record.id}"):
            logger.error(f"标记转账记录为失败时提交失败: transfer_record_id={transfer_record.id}")
        return False, error_msg
    
    if not taker.stripe_account_id:
        error_msg = "任务接受人尚未创建 Stripe Connect 账户"
        transfer_record.status = "failed"
        transfer_record.last_error = error_msg
        from app.transaction_utils import safe_commit
        if not safe_commit(db, f"标记转账记录为失败（无Stripe账户） transfer_record_id={transfer_record.id}"):
            logger.error(f"标记转账记录为失败时提交失败: transfer_record_id={transfer_record.id}")
        return False, error_msg
    
    # 更新重试次数和状态
    transfer_record.retry_count += 1
    transfer_record.status = "retrying"
    
    # 计算下次重试时间（指数退避）
    retry_index = min(transfer_record.retry_count - 1, len(RETRY_DELAYS) - 1)
    delay_seconds = RETRY_DELAYS[retry_index]
    transfer_record.next_retry_at = get_utc_time() + timedelta(seconds=delay_seconds)
    
    logger.info(f"🔄 重试转账: transfer_record_id={transfer_record.id}, retry_count={transfer_record.retry_count}/{transfer_record.max_retries}, next_retry_at={transfer_record.next_retry_at}")
    
    # 执行转账
    success, transfer_id, error_msg = execute_transfer(db, transfer_record, taker.stripe_account_id)
    
    if success:
        logger.info(f"✅ 转账重试成功: transfer_record_id={transfer_record.id}, transfer_id={transfer_id}")
        return True, None
    else:
        # 更新错误信息
        transfer_record.last_error = error_msg
        transfer_record.status = "retrying"  # 保持 retrying 状态，等待下次重试
        
        # 如果达到最大重试次数，标记为失败
        if transfer_record.retry_count >= transfer_record.max_retries:
            transfer_record.status = "failed"
            transfer_record.next_retry_at = None
            logger.error(f"❌ 转账记录 {transfer_record.id} 重试失败，已达到最大重试次数")
        
        from app.transaction_utils import safe_commit
        if not safe_commit(db, f"更新转账记录重试状态 transfer_record_id={transfer_record.id}"):
            logger.error(f"更新转账记录重试状态失败: transfer_record_id={transfer_record.id}")
        return False, error_msg


def check_transfer_timeout(db: Session, timeout_hours: int = 24) -> Dict[str, Any]:
    """
    检查转账超时（长时间处于 pending 状态）
    
    Args:
        db: 数据库会话
        timeout_hours: 超时时间（小时），默认24小时
    
    Returns:
        超时检查结果统计
    """
    stats = {
        "checked": 0,
        "timeout": 0,
        "updated": 0
    }
    
    try:
        from datetime import timedelta
        timeout_threshold = get_utc_time() - timedelta(hours=timeout_hours)
        
        # 查找长时间处于 pending 状态的转账记录
        timeout_transfers = db.query(models.PaymentTransfer).filter(
            and_(
                models.PaymentTransfer.status == "pending",
                models.PaymentTransfer.created_at < timeout_threshold,
                models.PaymentTransfer.transfer_id.isnot(None)  # 已经有 transfer_id，说明已创建但未收到 webhook
            )
        ).all()
        
        logger.info(f"🕐 检查转账超时: 找到 {len(timeout_transfers)} 条超时记录")
        
        for transfer_record in timeout_transfers:
            stats["checked"] += 1
            
            try:
                # 检查 Stripe Transfer 状态（带超时）
                stripe_client = get_stripe_client()
                if not stripe_client or not stripe_client.api_key:
                    logger.error("Stripe API 未配置，无法检查转账状态")
                    continue
                
                if transfer_record.transfer_id:
                    try:
                        transfer = stripe_client.Transfer.retrieve(transfer_record.transfer_id)
                        
                        # 根据 Stripe Transfer 状态更新本地记录
                        if transfer.reversed:
                            # Transfer 已被撤销
                            transfer_record.status = "failed"
                            transfer_record.last_error = "Transfer was reversed by Stripe"
                            stats["timeout"] += 1
                            logger.warning(f"⚠️ 转账 {transfer_record.id} 已被 Stripe 撤销")
                        elif transfer.amount_reversed > 0:
                            # Transfer 部分撤销
                            transfer_record.status = "failed"
                            transfer_record.last_error = f"Transfer partially reversed: {transfer.amount_reversed}"
                            stats["timeout"] += 1
                            logger.warning(f"⚠️ 转账 {transfer_record.id} 部分撤销")
                        else:
                            # Transfer 状态正常，可能是 webhook 未收到，标记为需要人工检查
                            transfer_record.status = "retrying"
                            transfer_record.last_error = f"Transfer timeout: no webhook received after {timeout_hours} hours"
                            transfer_record.retry_count += 1
                            stats["timeout"] += 1
                            logger.warning(f"⚠️ 转账 {transfer_record.id} 超时，未收到 webhook，标记为需要重试")
                        
                        stats["updated"] += 1
                        from app.transaction_utils import safe_commit
                        if not safe_commit(db, f"更新转账记录超时状态 transfer_record_id={transfer_record.id}"):
                            logger.error(f"更新转账记录超时状态失败: transfer_record_id={transfer_record.id}")
                        
                    except stripe.error.StripeError as e:
                        logger.error(f"❌ 查询 Stripe Transfer 状态失败: transfer_id={transfer_record.transfer_id}, error={e}")
                        # 标记为需要人工检查
                        transfer_record.status = "retrying"
                        transfer_record.last_error = f"Failed to check Stripe Transfer status: {str(e)}"
                        transfer_record.retry_count += 1
                        stats["updated"] += 1
                        from app.transaction_utils import safe_commit
                        if not safe_commit(db, f"更新转账记录错误状态 transfer_record_id={transfer_record.id}"):
                            logger.error(f"更新转账记录错误状态失败: transfer_record_id={transfer_record.id}")
            
            except Exception as e:
                logger.error(f"处理转账超时检查失败: transfer_record_id={transfer_record.id}, error={e}", exc_info=True)
                db.rollback()
        
        logger.info(f"✅ 转账超时检查完成: {stats}")
        return stats
        
    except Exception as e:
        logger.error(f"检查转账超时失败: {e}", exc_info=True)
        return stats


def process_pending_transfers(db: Session) -> Dict[str, Any]:
    """
    处理待处理的转账（定时任务调用）
    
    Returns:
        处理结果统计
    """
    stats = {
        "processed": 0,
        "succeeded": 0,
        "failed": 0,
        "retrying": 0,
        "skipped": 0
    }
    
    try:
        # 查找需要处理的转账记录
        # 1. 状态为 pending 的记录（首次尝试）
        # 2. 状态为 retrying 且到了重试时间的记录
        now = get_utc_time()
        
        pending_transfers = db.query(models.PaymentTransfer).filter(
            and_(
                models.PaymentTransfer.status.in_(["pending", "retrying"]),
                or_(
                    models.PaymentTransfer.status == "pending",
                    and_(
                        models.PaymentTransfer.status == "retrying",
                        models.PaymentTransfer.next_retry_at <= now
                    )
                )
            )
        ).limit(100).all()  # 每次最多处理100条
        
        logger.info(f"🔄 找到 {len(pending_transfers)} 条待处理的转账记录")
        
        for transfer_record in pending_transfers:
            stats["processed"] += 1
            
            try:
                # 获取任务接受人的 Stripe Connect 账户ID
                taker = db.query(models.User).filter(models.User.id == transfer_record.taker_id).first()
                if not taker or not taker.stripe_account_id:
                    transfer_record.status = "failed"
                    transfer_record.last_error = "任务接受人没有 Stripe Connect 账户"
                    from app.transaction_utils import safe_commit
                    if not safe_commit(db, f"标记转账记录为失败（无Stripe账户） transfer_record_id={transfer_record.id}"):
                        logger.error(f"标记转账记录为失败时提交失败: transfer_record_id={transfer_record.id}")
                    stats["failed"] += 1
                    continue
                
                # 执行转账
                if transfer_record.status == "pending":
                    # 首次尝试
                    success, transfer_id, error_msg = execute_transfer(db, transfer_record, taker.stripe_account_id)
                else:
                    # 重试
                    success, error_msg = retry_failed_transfer(db, transfer_record)
                    transfer_id = transfer_record.transfer_id if success else None
                
                if success:
                    stats["succeeded"] += 1
                else:
                    if transfer_record.status == "retrying":
                        stats["retrying"] += 1
                    else:
                        stats["failed"] += 1
                    
                    logger.warning(f"转账处理失败: transfer_record_id={transfer_record.id}, error={error_msg}")
            
            except Exception as e:
                logger.error(f"处理转账记录失败: transfer_record_id={transfer_record.id}, error={e}", exc_info=True)
                stats["failed"] += 1
                try:
                    transfer_record.status = "retrying"
                    transfer_record.last_error = str(e)
                    transfer_record.retry_count += 1
                    if transfer_record.retry_count < transfer_record.max_retries:
                        retry_index = min(transfer_record.retry_count - 1, len(RETRY_DELAYS) - 1)
                        delay_seconds = RETRY_DELAYS[retry_index]
                        transfer_record.next_retry_at = get_utc_time() + timedelta(seconds=delay_seconds)
                    else:
                        transfer_record.status = "failed"
                        transfer_record.next_retry_at = None
                    from app.transaction_utils import safe_commit
                    if not safe_commit(db, f"更新转账记录异常状态 transfer_record_id={transfer_record.id}"):
                        logger.error(f"更新转账记录异常状态失败: transfer_record_id={transfer_record.id}")
        
        logger.info(f"✅ 转账处理完成: {stats}")
        return stats
        
    except Exception as e:
        logger.error(f"处理待处理转账失败: {e}", exc_info=True)
        return stats

