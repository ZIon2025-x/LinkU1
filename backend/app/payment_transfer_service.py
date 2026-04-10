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

# 接受人 Stripe Connect 未完成时的重试间隔（秒），避免每 5 分钟打一次日志
TAKER_CONNECT_INCOMPLETE_RETRY_SECONDS = 86400  # 24 小时

CONNECT_NOT_COMPLETE_MSG = "任务接受人的 Stripe Connect 账户尚未完成设置"
CONNECT_NOT_ENABLED_MSG = "任务接受人的 Stripe Connect 账户尚未启用收款"


def _is_connect_not_ready_error(msg) -> bool:
    if msg is None:
        return False
    s = str(msg)
    return CONNECT_NOT_COMPLETE_MSG in s or CONNECT_NOT_ENABLED_MSG in s


def create_transfer_record(
    db: Session,
    task_id: int,
    taker_id: str,
    poster_id: str,
    amount: Decimal,
    currency: str = "GBP",
    taker_expert_id: Optional[str] = None,
    idempotency_key: Optional[str] = None,
    metadata: Optional[Dict[str, Any]] = None,
    commit: bool = True
) -> models.PaymentTransfer:
    """
    创建转账记录（带幂等性检查）

    Args:
        taker_expert_id: 达人团队接单时传入 experts.id (spec §3.2 v2)
        idempotency_key: Stripe 转账幂等键，默认 f"task_{task_id}_transfer"
        commit: 是否立即提交。设为 False 可在 SAVEPOINT 内使用 flush 代替 commit，
                避免破坏外层事务隔离。调用方需自行提交。

    Returns:
        PaymentTransfer: 创建的转账记录（可能返回已有记录）
    """
    # 🔒 幂等性检查：避免重复创建转账记录
    existing = db.query(models.PaymentTransfer).filter(
        and_(
            models.PaymentTransfer.task_id == task_id,
            models.PaymentTransfer.taker_id == taker_id,
            models.PaymentTransfer.status.in_(["pending", "retrying", "succeeded"])
        )
    ).first()
    if existing:
        logger.info(f"转账记录已存在: task_id={task_id}, taker_id={taker_id}, status={existing.status}, transfer_id={existing.id}")
        return existing

    transfer_record = models.PaymentTransfer(
        task_id=task_id,
        taker_id=taker_id,
        poster_id=poster_id,
        amount=amount,
        currency=currency,
        status="pending",
        retry_count=0,
        max_retries=len(RETRY_DELAYS),
        taker_expert_id=taker_expert_id,
        idempotency_key=idempotency_key or f"task_{task_id}_transfer",
        extra_metadata=metadata or {}
    )
    db.add(transfer_record)
    
    if commit:
        # 使用安全提交，带错误处理和回滚
        from app.transaction_utils import safe_commit
        if not safe_commit(db, f"创建转账记录 task_id={task_id}"):
            raise Exception("创建转账记录失败")
    else:
        # 仅 flush 到 DB（获取 id），不提交事务，保持 SAVEPOINT 隔离
        db.flush()
    
    db.refresh(transfer_record)
    
    logger.info(f"✅ 创建转账记录: task_id={task_id}, amount={amount}, transfer_record_id={transfer_record.id}")
    return transfer_record


def execute_transfer(
    db: Session,
    transfer_record: models.PaymentTransfer,
    taker_stripe_account_id: str,
    commit: bool = True
) -> tuple[bool, Optional[str], Optional[str]]:
    """
    执行 Stripe Transfer 转账
    
    Args:
        db: 数据库会话
        transfer_record: 转账记录
        taker_stripe_account_id: 接受人的 Stripe Connect 账户ID
        commit: 是否立即提交。设为 False 可在 SAVEPOINT 内使用 flush 代替 commit，
                避免破坏外层事务隔离。调用方需自行提交。
    
    Returns:
        (success, transfer_id, error_message)
    """
    # 使用配置好的 Stripe 客户端（已设置超时）
    stripe_client = get_stripe_client()
    if not stripe_client or not stripe_client.api_key:
        return False, None, "Stripe API 未配置"
    
    try:
        # ── Package branch: resolve destination from expert team ──────────────────
        if transfer_record.package_id is not None:
            from app.models_expert import UserServicePackage, Expert
            pkg = db.query(UserServicePackage).filter(
                UserServicePackage.id == transfer_record.package_id
            ).first()
            if not pkg:
                logger.error(
                    f"PaymentTransfer {transfer_record.id} references non-existent "
                    f"package {transfer_record.package_id}"
                )
                transfer_record.status = "failed"
                transfer_record.last_error = "package_not_found"
                if commit:
                    from app.transaction_utils import safe_commit
                    safe_commit(db, f"package not found transfer={transfer_record.id}")
                return False, None, "package_not_found"

            expert = db.query(Expert).filter(Expert.id == pkg.expert_id).first()
            if not expert or not expert.stripe_account_id:
                transfer_record.status = "failed"
                transfer_record.last_error = "expert_stripe_account_missing"
                if commit:
                    from app.transaction_utils import safe_commit
                    safe_commit(db, f"missing stripe account transfer={transfer_record.id}")
                return False, None, "expert_stripe_account_missing"

            taker_stripe_account_id = expert.stripe_account_id
            # Note: skip the 90-day Stripe Transfer window check for packages
            # (packages have their own expires_at limit, typically much shorter)

        else:
            # ── Task branch: existing task-based destination resolution ───────────
            # 检查任务状态
            task = db.query(models.Task).filter(models.Task.id == transfer_record.task_id).first()
            if not task:
                return False, None, "任务不存在"

            # ✅ Stripe争议冻结检查：如果任务因Stripe争议被冻结，阻止转账
            if task.stripe_dispute_frozen == 1:
                error_msg = "任务因Stripe争议已冻结，无法执行转账。请等待争议解决后再试。"
                logger.warning(f"任务 {transfer_record.task_id} 因Stripe争议已冻结，阻止转账")
                return False, None, error_msg

        # Task-specific checks: only run for task transfers (package branch already returned or
        # set taker_stripe_account_id and has no task object).
        if transfer_record.package_id is None:
            task = db.query(models.Task).filter(models.Task.id == transfer_record.task_id).first()
            # Note: task was already loaded and checked above in the else branch; re-query is a
            # no-op on SQLAlchemy identity map, but kept here for clarity of the code path.

            # Team-aware destination override: 若为团队任务，直接使用 experts.stripe_account_id
            # spec §3.2 (v2 — payout site team-awareness)
            if transfer_record.taker_expert_id:
                from app.models_expert import Expert
                expert = db.query(Expert).filter(Expert.id == transfer_record.taker_expert_id).first()
                if not expert or not expert.stripe_account_id or not expert.stripe_onboarding_complete:
                    error_msg = "Team Stripe Connect not ready"
                    logger.error(
                        f"任务 {transfer_record.task_id} 团队 Stripe 状态异常 "
                        f"(expert_id={transfer_record.taker_expert_id})，取消转账"
                    )
                    return False, None, error_msg
                taker_stripe_account_id = expert.stripe_account_id

                # 90-day Stripe Transfer window check (spec §3.4a) — only for team tasks
                # Stripe enforces a strict 90-day window for stripe.Transfer.create after the original Charge.
                # 安全边界: 留 1 天 buffer 防止 transfer 在 89~90 天之间因时差/重试漂移到失败
                if task.payment_completed_at:
                    from datetime import datetime, timedelta
                    age = datetime.utcnow() - task.payment_completed_at.replace(tzinfo=None)
                    STRIPE_TRANSFER_WINDOW_DAYS = 89  # 89 天为安全阈值,Stripe 实际允许 90
                    if age > timedelta(days=STRIPE_TRANSFER_WINDOW_DAYS):
                        transfer_record.status = "failed"
                        transfer_record.last_error = (
                            f"stripe_transfer_window_expired "
                            f"({age.days}d > {STRIPE_TRANSFER_WINDOW_DAYS}d safety threshold, Stripe limit: 90d)"
                        )
                        if commit:
                            from app.transaction_utils import safe_commit
                            safe_commit(db, f"transfer 时效过期 task={transfer_record.task_id}")
                        return False, None, transfer_record.last_error

                # GBP-only enforcement for team tasks (spec §1.4)
                currency_upper = (transfer_record.currency or 'GBP').upper()
                if currency_upper != 'GBP':
                    transfer_record.status = "failed"
                    transfer_record.last_error = f"currency_unsupported ({currency_upper}; team tasks require GBP)"
                    if commit:
                        from app.transaction_utils import safe_commit
                        safe_commit(db, f"team task 币种不支持 task={transfer_record.task_id}")
                    return False, None, transfer_record.last_error

        if transfer_record.package_id is None and task.is_confirmed == 1 and task.escrow_amount == 0:
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
                error_msg = CONNECT_NOT_COMPLETE_MSG
                logger.warning(f"{error_msg}: taker_id={transfer_record.taker_id}")
                return False, None, error_msg
            if not account.charges_enabled:
                error_msg = CONNECT_NOT_ENABLED_MSG
                logger.warning(f"{error_msg}: taker_id={transfer_record.taker_id}")
                return False, None, error_msg
        except stripe.error.StripeError as e:
            error_msg = f"无法验证 Stripe Connect 账户: {str(e)}"
            logger.error(f"{error_msg}: account_id={taker_stripe_account_id}")
            return False, None, error_msg
        
        # 计算转账金额（便士）
        # 修复 P1#7：使用 Decimal 运算避免浮点精度丢失
        # 例如 float(10.15) * 100 = 1014.9999... → int() 截断为 1014（少1便士）
        transfer_amount_pence = int(Decimal(str(transfer_record.amount)) * 100)
        
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
        _stripe_create_kwargs = dict(
            amount=transfer_amount_pence,
            currency=transfer_record.currency.lower(),
            destination=taker_stripe_account_id,  # Connect 子账户 ID
            metadata={
                "task_id": str(transfer_record.task_id) if transfer_record.task_id else "",
                "package_id": str(transfer_record.package_id) if transfer_record.package_id else "",
                "taker_id": str(transfer_record.taker_id) if transfer_record.taker_id else "",
                "taker_expert_id": str(transfer_record.taker_expert_id) if transfer_record.taker_expert_id else "",
                "poster_id": str(transfer_record.poster_id) if transfer_record.poster_id else "",
                "transfer_record_id": str(transfer_record.id),
                "transfer_type": "package_release" if transfer_record.package_id else "task_reward",
            },
            description=(
                f"Package #{transfer_record.package_id} release"
                if transfer_record.package_id
                else f"任务 #{transfer_record.task_id} 奖励"
            )
        )
        if transfer_record.idempotency_key:
            _stripe_create_kwargs["idempotency_key"] = transfer_record.idempotency_key
        transfer = stripe_client.Transfer.create(**_stripe_create_kwargs)
        
        logger.info(f"✅ Transfer 创建成功: transfer_id={transfer.id}, amount=£{transfer_record.amount:.2f}")
        
        # Connect Transfer 在 API 成功时即完成，Stripe 不一定发送 transfer.paid webhook，
        # 故直接设为 succeeded，不依赖 webhook 配置
        transfer_record.transfer_id = transfer.id
        transfer_record.status = "succeeded"
        transfer_record.succeeded_at = get_utc_time()
        transfer_record.last_error = None
        transfer_record.next_retry_at = None

        # Package post-processing: stamp released_at / released_amount_pence and
        # transition exhausted/expired → released.
        # partially_refunded is terminal — leave as-is.
        if transfer_record.package_id is not None:
            from app.models_expert import UserServicePackage
            pkg = db.query(UserServicePackage).filter(
                UserServicePackage.id == transfer_record.package_id
            ).first()
            if pkg:
                pkg.released_at = get_utc_time()
                pkg.released_amount_pence = int(Decimal(str(transfer_record.amount)) * 100)
                if pkg.status in ("exhausted", "expired"):
                    pkg.status = "released"
                logger.info(
                    f"Package {transfer_record.package_id} post-process: "
                    f"released_at set, status={pkg.status}"
                )

        if commit:
            # 使用安全提交，带错误处理和回滚
            from app.transaction_utils import safe_commit
            if not safe_commit(db, f"更新转账记录 transfer_id={transfer.id}"):
                raise Exception("更新转账记录失败")
        else:
            # 仅 flush，保持 SAVEPOINT 隔离
            db.flush()

        logger.info(f"✅ 任务 {transfer_record.task_id} Transfer 已创建并标记为成功: transfer_id={transfer.id}")
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
            if commit:
                # 使用安全提交，带错误处理和回滚
                from app.transaction_utils import safe_commit
                if not safe_commit(db, f"更新转账记录状态 transfer_record_id={transfer_record.id}"):
                    logger.error(f"更新转账记录状态失败: transfer_record_id={transfer_record.id}")
            else:
                # 仅 flush，保持 SAVEPOINT 隔离
                db.flush()
        
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
    
    # 团队任务：直接进入 Stripe 重试路径，不做 taker.stripe_account_id 检查/钱包回退
    # spec §3.2 v2 — 团队任务资金只能流向团队 Stripe
    if transfer_record.taker_expert_id:
        from app.models_expert import Expert
        expert = db.query(Expert).filter(Expert.id == transfer_record.taker_expert_id).first()
        if not expert or not expert.stripe_account_id or not expert.stripe_onboarding_complete:
            error_msg = "Team Stripe Connect not ready (manual intervention required)"
            transfer_record.last_error = error_msg
            transfer_record.status = "retrying"
            # 保持 retrying 状态，等后台修复
            from app.transaction_utils import safe_commit
            safe_commit(db, f"团队 Stripe 未就绪 transfer_record_id={transfer_record.id}")
            logger.error(f"{error_msg}: transfer_record_id={transfer_record.id}")
            return False, error_msg
        transfer_record.status = "retrying"
        logger.info(
            f"🔄 团队任务重试转账: transfer_record_id={transfer_record.id}, "
            f"retry_count={transfer_record.retry_count}/{transfer_record.max_retries}"
        )
        success, transfer_id, error_msg = execute_transfer(db, transfer_record, expert.stripe_account_id)
        if success:
            logger.info(f"✅ 团队转账重试成功: transfer_record_id={transfer_record.id}, transfer_id={transfer_id}")
            return True, None
        transfer_record.last_error = error_msg
        transfer_record.status = "retrying"
        # I1: Unconditionally increment retry_count to ensure progress to failed state.
        # (The whitelist-based increment inside execute_transfer targets individual taker
        # semantics and does not fire for generic Stripe/unknown errors — without this
        # bump the team branch would tight-loop forever.)
        transfer_record.retry_count = (transfer_record.retry_count or 0) + 1
        # I2: Respect RETRY_DELAYS schedule so the scheduler waits before re-picking this row.
        if transfer_record.status == "retrying":
            delay_idx = min(transfer_record.retry_count - 1, len(RETRY_DELAYS) - 1)
            delay_seconds = RETRY_DELAYS[delay_idx] if delay_idx >= 0 else RETRY_DELAYS[0]
            from datetime import datetime, timedelta
            transfer_record.next_retry_at = datetime.utcnow() + timedelta(seconds=delay_seconds)
        if transfer_record.retry_count >= transfer_record.max_retries:
            transfer_record.status = "failed"
            transfer_record.next_retry_at = None
            logger.error(
                f"❌ 团队任务 transfer_record {transfer_record.id} 重试失败，已达到最大重试次数 — 不回退钱包"
            )
        from app.transaction_utils import safe_commit
        safe_commit(db, f"更新团队转账重试状态 transfer_record_id={transfer_record.id}")
        return False, error_msg

    # 获取任务接受人的 Stripe Connect 账户ID（个人任务路径）
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
        # 无 Stripe Connect 账户，改为钱包入账
        logger.info(f"接单人无 Stripe Connect，转为钱包入账: transfer_record_id={transfer_record.id}")
        try:
            from app.wallet_service import credit_wallet
            from decimal import Decimal
            wallet_tx = credit_wallet(
                db,
                user_id=taker.id,
                amount=Decimal(str(transfer_record.amount)),
                source="task_earning",
                related_id=str(transfer_record.task_id),
                related_type="task",
                description=f"任务 #{transfer_record.task_id} 收入（转账重试转钱包）",
                currency=transfer_record.currency or "GBP",
            )
            transfer_record.status = "succeeded"
            transfer_record.last_error = None
            transfer_record.succeeded_at = get_utc_time()
            from app.transaction_utils import safe_commit
            if not safe_commit(db, f"转账记录转钱包入账 transfer_record_id={transfer_record.id}"):
                logger.error(f"转账记录转钱包入账提交失败: transfer_record_id={transfer_record.id}")
                return False, "数据库提交失败"
            logger.info(f"✅ 转账记录转钱包入账成功: transfer_record_id={transfer_record.id}")
            return True, None
        except Exception as e:
            logger.error(f"转账记录转钱包入账失败: {e}")
            return False, str(e)

    # 有 Stripe Connect 账户，走原有 Stripe Transfer 重试
    # 修复 P1#8：不在此处预增 retry_count，避免与 execute_transfer 中的增量重复。
    transfer_record.status = "retrying"

    logger.info(f"🔄 重试转账: transfer_record_id={transfer_record.id}, retry_count={transfer_record.retry_count}/{transfer_record.max_retries}")

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

        # 批量加载所有 taker，避免循环内 N+1 查询
        _taker_ids = list({t.taker_id for t in pending_transfers if t.taker_id})
        _takers_map = {}
        if _taker_ids:
            _takers = db.query(models.User).filter(models.User.id.in_(_taker_ids)).all()
            _takers_map = {u.id: u for u in _takers}

        for transfer_record in pending_transfers:
            stats["processed"] += 1

            try:
                # ── Package branch ────────────────────────────────────────────────────
                # Package transfers have no individual taker; destination is resolved
                # from UserServicePackage.expert_id → Expert.stripe_account_id.
                if transfer_record.package_id is not None:
                    from app.models_expert import UserServicePackage, Expert
                    pkg = db.query(UserServicePackage).filter(
                        UserServicePackage.id == transfer_record.package_id
                    ).first()
                    if not pkg:
                        logger.error(
                            f"PaymentTransfer {transfer_record.id} references non-existent "
                            f"package {transfer_record.package_id}"
                        )
                        transfer_record.status = "failed"
                        transfer_record.last_error = "package_not_found"
                        from app.transaction_utils import safe_commit
                        safe_commit(db, f"package not found transfer={transfer_record.id}")
                        stats["failed"] += 1
                        continue

                    expert = db.query(Expert).filter(Expert.id == pkg.expert_id).first()
                    if not expert or not expert.stripe_account_id:
                        transfer_record.status = "failed"
                        transfer_record.last_error = "expert_stripe_account_missing"
                        from app.transaction_utils import safe_commit
                        safe_commit(db, f"missing stripe account transfer={transfer_record.id}")
                        stats["failed"] += 1
                        logger.error(
                            f"PaymentTransfer {transfer_record.id} package={transfer_record.package_id}: "
                            f"expert stripe account missing"
                        )
                        continue

                    taker_stripe_id = expert.stripe_account_id
                    transfer_amount = Decimal(str(transfer_record.amount))
                    transfer_currency = (transfer_record.currency or "GBP").upper()
                    amount_minor = int(transfer_amount * 100)
                    payout_idempotency_key = transfer_record.idempotency_key

                    try:
                        stripe_xfer = stripe.Transfer.create(
                            amount=amount_minor,
                            currency=transfer_currency.lower(),
                            destination=taker_stripe_id,
                            description=f"Package #{transfer_record.package_id} release",
                            metadata={
                                "package_id": str(transfer_record.package_id),
                                "taker_expert_id": str(transfer_record.taker_expert_id) if transfer_record.taker_expert_id else "",
                                "poster_id": str(transfer_record.poster_id) if transfer_record.poster_id else "",
                                "transfer_record_id": str(transfer_record.id),
                                "transfer_type": "package_release",
                            },
                            idempotency_key=payout_idempotency_key,
                        )
                        transfer_record.transfer_id = stripe_xfer.id
                        logger.info(
                            f"✅ Package Stripe Transfer: transfer_record_id={transfer_record.id}, "
                            f"stripe_transfer={stripe_xfer.id}, package={transfer_record.package_id}"
                        )
                    except stripe.error.StripeError as stripe_err:
                        error_msg = str(stripe_err)
                        error_code = getattr(stripe_err, "code", None)
                        if error_code in ("balance_insufficient", "account_invalid", "rate_limit"):
                            transfer_record.status = "retrying"
                            transfer_record.last_error = error_msg
                            transfer_record.retry_count = (transfer_record.retry_count or 0) + 1
                            delay_idx = min(transfer_record.retry_count - 1, len(RETRY_DELAYS) - 1)
                            transfer_record.next_retry_at = now + timedelta(seconds=RETRY_DELAYS[delay_idx])
                            if transfer_record.retry_count >= transfer_record.max_retries:
                                transfer_record.status = "failed"
                                transfer_record.next_retry_at = None
                            from app.transaction_utils import safe_commit
                            safe_commit(db, f"package transfer stripe error transfer={transfer_record.id}")
                            stats["retrying"] += 1
                        else:
                            transfer_record.status = "failed"
                            transfer_record.last_error = error_msg
                            from app.transaction_utils import safe_commit
                            safe_commit(db, f"package transfer stripe fatal transfer={transfer_record.id}")
                            stats["failed"] += 1
                        logger.error(
                            f"Package Stripe Transfer failed: transfer_record_id={transfer_record.id}, "
                            f"package={transfer_record.package_id}, error={error_msg}"
                        )
                        continue

                    # Stripe Transfer succeeded — mark record and update package
                    transfer_record.status = "succeeded"
                    transfer_record.succeeded_at = get_utc_time()
                    transfer_record.last_error = None
                    transfer_record.next_retry_at = None

                    # Post-processing: stamp released_at / released_amount_pence on package
                    # and transition exhausted/expired → released.
                    # partially_refunded is terminal — leave as-is.
                    pkg.released_at = get_utc_time()
                    pkg.released_amount_pence = int(Decimal(str(transfer_record.amount)) * 100)
                    if pkg.status in ("exhausted", "expired"):
                        pkg.status = "released"

                    from app.transaction_utils import safe_commit
                    safe_commit(db, f"package transfer succeeded transfer={transfer_record.id}")
                    stats["succeeded"] += 1
                    logger.info(
                        f"✅ Package transfer complete: transfer_record_id={transfer_record.id}, "
                        f"package={transfer_record.package_id}, pkg.status={pkg.status}"
                    )
                    continue
                # ── End package branch ────────────────────────────────────────────────

                # 获取任务接受人信息（已批量加载）
                taker = _takers_map.get(transfer_record.taker_id)
                if not taker:
                    transfer_record.status = "failed"
                    transfer_record.last_error = "任务接受人不存在"
                    from app.transaction_utils import safe_commit
                    if not safe_commit(db, f"标记转账记录为失败（接受人不存在） transfer_record_id={transfer_record.id}"):
                        logger.error(f"标记转账记录为失败时提交失败: transfer_record_id={transfer_record.id}")
                    stats["failed"] += 1
                    continue

                # 优先直接 Stripe Transfer（接单者有 Connect 账户时），否则入本地钱包
                taker_stripe_id = getattr(taker, "stripe_account_id", None)
                transfer_amount = Decimal(str(transfer_record.amount))
                transfer_currency = (transfer_record.currency or "GBP").upper()
                payout_idempotency_key = f"earning:task:{transfer_record.task_id}:user:{taker.id}"

                if taker_stripe_id:
                    # 有 Stripe Connect → 直接转账
                    amount_minor = int(transfer_amount * 100)
                    try:
                        stripe_xfer = stripe.Transfer.create(
                            amount=amount_minor,
                            currency=transfer_currency.lower(),
                            destination=taker_stripe_id,
                            description=f"Task #{transfer_record.task_id} payout",
                            metadata={
                                "task_id": str(transfer_record.task_id),
                                "taker_id": str(taker.id),
                                "transfer_record_id": str(transfer_record.id),
                                "transfer_type": "task_reward",
                            },
                            idempotency_key=payout_idempotency_key,
                        )
                        transfer_record.transfer_id = stripe_xfer.id
                        logger.info(
                            f"✅ 待处理转账直接 Stripe Transfer: transfer_record_id={transfer_record.id}, "
                            f"stripe_transfer={stripe_xfer.id}, taker={taker.id}"
                        )
                    except stripe.error.StripeError as stripe_err:
                        error_msg = str(stripe_err)
                        if _is_connect_not_ready_error(error_msg):
                            # Connect 账户未就绪 → 延迟重试
                            transfer_record.status = "retrying"
                            transfer_record.last_error = error_msg
                            transfer_record.next_retry_at = now + timedelta(seconds=TAKER_CONNECT_INCOMPLETE_RETRY_SECONDS)
                            from app.transaction_utils import safe_commit
                            safe_commit(db, f"延期重试（接受人Connect未完成） transfer_record_id={transfer_record.id}")
                            stats["retrying"] += 1
                            logger.info(
                                f"接受人 Stripe Connect 未就绪，已延至 24 小时后重试: "
                                f"transfer_record_id={transfer_record.id}, taker_id={transfer_record.taker_id}"
                            )
                        else:
                            # Stripe 转账失败 → 回退到钱包入账
                            logger.warning(
                                f"Stripe Transfer 失败，回退到钱包入账: transfer_record_id={transfer_record.id}, "
                                f"error={error_msg}"
                            )
                            from app.wallet_service import credit_wallet
                            credit_wallet(
                                db,
                                user_id=taker.id,
                                amount=transfer_amount,
                                source="task_earning",
                                related_id=str(transfer_record.task_id),
                                related_type="task",
                                description=f"任务 #{transfer_record.task_id} 收入（Stripe转账失败，入钱包）",
                                currency=transfer_currency,
                                idempotency_key=payout_idempotency_key,
                            )
                        # 如果是 retrying，跳过后续的 succeeded 处理
                        if transfer_record.status == "retrying":
                            continue
                else:
                    # 无 Stripe Connect → 入本地钱包
                    from app.wallet_service import credit_wallet
                    credit_wallet(
                        db,
                        user_id=taker.id,
                        amount=transfer_amount,
                        source="task_earning",
                        related_id=str(transfer_record.task_id),
                        related_type="task",
                        description=f"任务 #{transfer_record.task_id} 收入（待处理转账）",
                        currency=transfer_currency,
                        idempotency_key=payout_idempotency_key,
                    )
                    logger.info(
                        f"✅ 待处理转账入钱包: transfer_record_id={transfer_record.id}, "
                        f"taker={taker.id}（无 Stripe Connect）"
                    )

                transfer_record.status = "succeeded"
                transfer_record.succeeded_at = get_utc_time()
                from app.transaction_utils import safe_commit
                safe_commit(db, f"待处理转账完成 transfer_record_id={transfer_record.id}")
                stats["succeeded"] += 1

                # 转账成功后同步更新 Task 字段
                try:
                    locked_task = db.execute(
                        select(models.Task).where(
                            models.Task.id == transfer_record.task_id
                        ).with_for_update()
                    ).scalar_one_or_none()
                    if locked_task and locked_task.is_confirmed != 1:
                        locked_task.is_confirmed = 1
                        locked_task.confirmed_at = get_utc_time()
                        locked_task.paid_to_user_id = transfer_record.taker_id
                        locked_task.escrow_amount = Decimal('0.00')
                        from app.transaction_utils import safe_commit
                        if not safe_commit(db, f"更新任务确认状态 task_id={locked_task.id}"):
                            logger.error(f"更新任务确认状态失败: task_id={locked_task.id}")
                        else:
                            logger.info(f"✅ 转账成功后同步更新任务 {locked_task.id} 确认状态: is_confirmed=1, escrow_amount=0")
                except Exception as task_err:
                    logger.error(f"转账成功但更新任务状态失败: task_id={transfer_record.task_id}, error={task_err}", exc_info=True)
            
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
                except Exception as inner_e:
                    logger.error(f"更新转账记录异常状态时发生错误: transfer_record_id={transfer_record.id}, error={inner_e}")
        
        logger.info(f"✅ 转账处理完成: {stats}")
        return stats
        
    except Exception as e:
        logger.error(f"处理待处理转账失败: {e}", exc_info=True)
        return stats

