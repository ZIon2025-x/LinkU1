"""
咨询批准+支付公共逻辑

场景:双方在咨询会话里议价完成后,发布者直接点"批准并支付",跳过回到
申请列表再批准的多余步骤。采用"付款驱动批准"模式(和 accept_application 一致):
创建 Stripe PaymentIntent 时 T/TA1 不动,Stripe webhook 在 payment_intent.succeeded
时才触发真正的批准 + 归档咨询占位。失败/取消时解锁,允许重试或重新议价。

三类咨询(service / task / flea_market)将来都可以复用本模块:
- prepare_task_consultation_approval: 任务咨询专用的 TA1 查找/创建 + TA2 锁定
- finalize_consultation_on_payment_success: webhook 成功回调 — 关闭 T2 / cancel TA2 / 系统消息
- unlock_consultation_on_payment_failure: webhook 失败/取消 / 扫描超时 — TA2 回到 price_agreed

当前只实现 task_consultation。service / flea_market 等咨询类型后续迁入时参考同一套骨架。
"""
from __future__ import annotations

import json
import logging
from typing import Optional, Tuple

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from app import models
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)


# TA2 在"等待支付"期间的锁定状态字符串(不是枚举,约定值)
# 双方 UI 见到此状态都应禁用议价/关闭按钮
CONSULTATION_STATUS_PRICE_LOCKED = "price_locked"
# 锁定前的议价完成态
CONSULTATION_STATUS_PRICE_AGREED = "price_agreed"


# ─────────────────────────────────────────────────────────────
# 准备阶段 — 在创建 PaymentIntent 前调用
# ─────────────────────────────────────────────────────────────
async def prepare_task_consultation_approval(
    db: AsyncSession,
    *,
    placeholder_task: "models.Task",
    placeholder_application: "models.TaskApplication",
    negotiated_price,
    currency: Optional[str],
) -> Tuple["models.TaskApplication", int]:
    """
    发布者批准任务咨询前的准备:
    - 校验 placeholder_task 是 task_consultation 占位、有 original_task_id、原任务 open
    - 校验 placeholder_application 状态是 price_agreed 且有 negotiated_price
    - 在原任务上 find-or-create 一个 active TA(TA1 存在就更新价格/回链,否则新建)
    - 把 placeholder_application(TA2)锁到 price_locked
    返回 (target_ta_on_original, original_task_id)。

    调用方(endpoint)拿到返回值后:
    1. 把 target_ta.id 作为 PaymentIntent.metadata['application_id']
    2. 把 placeholder_task.id / placeholder_application.id 作为 consultation_* metadata
    3. 把 original_task_id 作为 metadata['task_id']
    4. 创建 PaymentIntent、保存 payment_intent_id 到原任务
    5. 所有更新一起 commit

    本函数只做 DB 修改(加入 session),**不 commit** — 让调用方统一事务。
    """
    # 1. 校验占位任务
    if not placeholder_task.is_consultation_placeholder:
        raise ValueError("placeholder_task 不是咨询占位任务")
    if placeholder_task.task_source != "task_consultation":
        raise ValueError(
            f"prepare_task_consultation_approval 仅支持 task_consultation,"
            f"当前 task_source={placeholder_task.task_source}"
        )
    original_task_id = getattr(placeholder_task, "original_task_id", None)
    if not original_task_id:
        # 兼容历史数据:description="original_task_id:{id}"
        desc = placeholder_task.description or ""
        if desc.startswith("original_task_id:"):
            try:
                original_task_id = int(desc.split(":", 1)[1])
            except (ValueError, IndexError):
                original_task_id = None
    if not original_task_id:
        raise ValueError("占位任务缺少 original_task_id,无法定位原任务")

    # 2. 加锁拉原任务
    orig_task_q = (
        select(models.Task).where(models.Task.id == original_task_id).with_for_update()
    )
    orig_task = (await db.execute(orig_task_q)).scalar_one_or_none()
    if not orig_task:
        raise ValueError("原任务不存在")
    if orig_task.status not in ("open", "chatting", "pending_acceptance"):
        raise ValueError(f"原任务状态 {orig_task.status} 不允许批准")
    if orig_task.is_paid:
        raise ValueError("原任务已支付,不能通过咨询批准流程")

    # 3. 校验 TA2 状态
    if placeholder_application.status != CONSULTATION_STATUS_PRICE_AGREED:
        raise ValueError(
            f"咨询申请状态必须为 price_agreed,当前 {placeholder_application.status}"
        )
    if placeholder_application.negotiated_price is None:
        raise ValueError("咨询议价价格缺失")

    applicant_id = placeholder_application.applicant_id
    if not applicant_id:
        raise ValueError("咨询申请缺少申请者")

    # 4. 在原任务上 find-or-create active TA
    existing_ta_q = (
        select(models.TaskApplication)
        .where(
            models.TaskApplication.task_id == original_task_id,
            models.TaskApplication.applicant_id == applicant_id,
            models.TaskApplication.status.notin_(["cancelled", "rejected"]),
        )
        .with_for_update()
    )
    target_ta = (await db.execute(existing_ta_q)).scalar_one_or_none()

    if target_ta is None:
        # 申请者尚未在原任务上申请(applicant-initiated 咨询场景)—— 代为创建一条 pending TA
        target_ta = models.TaskApplication(
            task_id=original_task_id,
            applicant_id=applicant_id,
            status="pending",
            currency=currency or orig_task.currency or "GBP",
            negotiated_price=negotiated_price,
            consultation_task_id=placeholder_task.id,
            created_at=get_utc_time(),
        )
        db.add(target_ta)
        await db.flush()
        logger.info(
            f"[consult-approve] 在原任务 {original_task_id} 创建新 TA {target_ta.id}, "
            f"applicant={applicant_id}, price={negotiated_price}"
        )
    else:
        # TA1 存在 — 更新议价价格 + 回链,状态保持(pending/chatting)
        target_ta.negotiated_price = negotiated_price
        target_ta.consultation_task_id = placeholder_task.id
        logger.info(
            f"[consult-approve] 更新原任务 {original_task_id} 现有 TA {target_ta.id} 价格"
            f"={negotiated_price}, status={target_ta.status}"
        )

    # 5. 锁定 TA2
    placeholder_application.status = CONSULTATION_STATUS_PRICE_LOCKED
    logger.info(
        f"[consult-approve] TA2 {placeholder_application.id} 锁定为 price_locked"
    )

    return target_ta, original_task_id


# ─────────────────────────────────────────────────────────────
# 终结阶段 — webhook 支付成功回调
# ─────────────────────────────────────────────────────────────
def finalize_consultation_on_payment_success(
    db: Session,
    *,
    consultation_task_id: int,
    consultation_application_id: int,
) -> None:
    """
    webhook payment_intent.succeeded 里调用(在主任务批准逻辑**之后**):
    - T2.status = 'closed'
    - TA2.status = 'cancelled'(之前是 price_locked)
    - 在 T2 聊天发系统消息告知双方
    幂等:T2 已 closed / TA2 已 cancelled 则直接返回。
    不 commit — 调用方统一事务。
    """
    t2 = db.query(models.Task).filter(models.Task.id == consultation_task_id).first()
    ta2 = (
        db.query(models.TaskApplication)
        .filter(models.TaskApplication.id == consultation_application_id)
        .first()
    )
    if not t2 or not ta2:
        logger.warning(
            f"[consult-finalize] T2={consultation_task_id} 或 TA2={consultation_application_id} "
            f"未找到,跳过"
        )
        return

    changed = False
    if t2.status != "closed":
        t2.status = "closed"
        changed = True
    if ta2.status != "cancelled":
        ta2.status = "cancelled"
        changed = True

    if changed:
        sys_msg = models.Message(
            task_id=t2.id,
            application_id=ta2.id,
            sender_id=None,
            receiver_id=None,
            content="议价已批准并支付完成,咨询已归档。可在此查看议价历史。",
            message_type="system",
            conversation_type="task",
            meta=json.dumps(
                {
                    "system_action": "consultation_approved_and_paid",
                    "content_en": "Negotiation approved and paid. Consultation archived; history remains viewable.",
                }
            ),
            created_at=get_utc_time(),
        )
        db.add(sys_msg)
        logger.info(
            f"[consult-finalize] 归档 T2={consultation_task_id} + TA2="
            f"{consultation_application_id}"
        )
    else:
        logger.info(
            f"[consult-finalize] T2={consultation_task_id}/TA2="
            f"{consultation_application_id} 已归档,跳过"
        )


# ─────────────────────────────────────────────────────────────
# 解锁阶段 — webhook 支付失败/取消回调 或 超时扫描
# ─────────────────────────────────────────────────────────────
def close_placeholders_for_task(
    db: Session,
    *,
    original_task_id: int,
    exclude_t2_id: Optional[int] = None,
    reason_zh: str = "任务已被其他申请者接下,咨询自动关闭",
    reason_en: str = "Task assigned to another applicant. Consultation auto-closed.",
    system_action: str = "consultation_auto_closed_on_task_assigned",
) -> int:
    """
    原任务 T 不再 open(被批准/取消/完成)时,把所有指向它的 task_consultation
    占位任务一并归档:
    - 找 Task.original_task_id == original_task_id AND is_consultation_placeholder=True
    - 排除 exclude_t2_id(通常是刚走了 finalize 的那一个,避免重复)
    - 只归档 status 还在 consulting/open 的占位;已 closed/cancelled 的跳过
    - 每个占位:t2.status='closed' + 活跃 TA2 status='cancelled' + 系统消息

    不 commit,调用方统一事务。返回归档的占位数量。
    """
    from sqlalchemy import update

    placeholders_q = db.query(models.Task).filter(
        models.Task.original_task_id == original_task_id,
        models.Task.is_consultation_placeholder == True,  # noqa: E712
        models.Task.status != "closed",
    )
    if exclude_t2_id is not None:
        placeholders_q = placeholders_q.filter(models.Task.id != exclude_t2_id)
    placeholders = placeholders_q.all()

    if not placeholders:
        return 0

    current_time = get_utc_time()
    closed_count = 0
    for t2 in placeholders:
        t2.status = "closed"
        closed_count += 1

        # 把该 T2 上还"活着"的 TA2 都 cancel 掉
        db.query(models.TaskApplication).filter(
            models.TaskApplication.task_id == t2.id,
            models.TaskApplication.status.in_([
                "consulting",
                "negotiating",
                "price_agreed",
                CONSULTATION_STATUS_PRICE_LOCKED,
                "pending",
                "chatting",
            ]),
        ).update(
            {"status": "cancelled"},
            synchronize_session=False,
        )

        # 系统消息 — 让双方 UI 立刻看到"咨询关闭,任务已成交"
        sys_msg = models.Message(
            task_id=t2.id,
            application_id=None,
            sender_id=None,
            receiver_id=None,
            content=reason_zh,
            message_type="system",
            conversation_type="task",
            meta=json.dumps(
                {
                    "system_action": system_action,
                    "content_en": reason_en,
                    "original_task_id": original_task_id,
                }
            ),
            created_at=current_time,
        )
        db.add(sys_msg)

    logger.info(
        f"[close-placeholders] 原任务 {original_task_id} 归档 {closed_count} 个咨询占位 "
        f"(exclude={exclude_t2_id}, reason={system_action})"
    )
    return closed_count


def unlock_consultation_on_payment_failure(
    db: Session,
    *,
    consultation_task_id: int,
    consultation_application_id: int,
) -> None:
    """
    webhook payment_intent.payment_failed / canceled 里调用:
    - TA2 从 price_locked 回到 price_agreed(允许重试或再议价)
    - T2 保持 consulting 状态
    幂等:TA2 已不是 price_locked 则跳过。
    不 commit — 调用方统一事务。
    """
    ta2 = (
        db.query(models.TaskApplication)
        .filter(models.TaskApplication.id == consultation_application_id)
        .first()
    )
    if not ta2:
        logger.warning(
            f"[consult-unlock] TA2={consultation_application_id} 未找到,跳过"
        )
        return
    if ta2.status != CONSULTATION_STATUS_PRICE_LOCKED:
        logger.info(
            f"[consult-unlock] TA2={consultation_application_id} 状态={ta2.status} "
            f"非 price_locked,跳过"
        )
        return
    ta2.status = CONSULTATION_STATUS_PRICE_AGREED
    logger.info(
        f"[consult-unlock] TA2={consultation_application_id} 解锁回 price_agreed"
    )

    # 在 T2 聊天发一条系统消息,提示可以重试
    sys_msg = models.Message(
        task_id=consultation_task_id,
        application_id=consultation_application_id,
        sender_id=None,
        receiver_id=None,
        content="支付未完成,议价已解锁,双方可重试支付或重新议价。",
        message_type="system",
        conversation_type="task",
        meta=json.dumps(
            {
                "system_action": "consultation_payment_unlocked",
                "content_en": "Payment incomplete. Negotiation unlocked — retry payment or renegotiate.",
            }
        ),
        created_at=get_utc_time(),
    )
    db.add(sys_msg)
