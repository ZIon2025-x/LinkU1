"""AI 限时问答 — settle 事务服务。
S1 行锁 + S3 audit + S5 周度上限 + S6 邮件 + wallet credit。"""
from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional, List, Tuple
import logging
from sqlalchemy import select
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from app.models_ai_qa import AiQuestion, AiAnswerScore
from app.crud import ai_qa as ai_qa_crud
from app.services.ai_qa_scoring import distribute_pool
from app.wallet_service import lock_wallet, credit_wallet
from app.crud.audit import create_audit_log
from app.crud.system import get_system_setting, update_system_setting
from app.coupon_points_crud import add_points_transaction
from app import models
from app.email_utils import send_email
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)


class SettleError(Exception):
    """业务错误（如周度上限、状态非法）。"""
    pass


def settle_question(db: Session, qid: int, admin_id: str) -> dict:
    """
    执行 settle 事务。返回 {total_settled_pence, winner_count, top1_user_id}。
    失败抛 SettleError 或 Exception；调用方负责把 status 切到 settle_failed。
    """
    # === S1 行锁 + 状态二次校验 ===
    q = db.execute(
        select(AiQuestion).where(AiQuestion.id == qid).with_for_update()
    ).scalar_one_or_none()
    if q is None:
        raise SettleError(f"question {qid} not found")
    if q.status not in ("scored", "settle_failed"):
        raise SettleError(f"settle requires status in (scored, settle_failed), got {q.status}")

    # === S5 周度上限校验 ===
    cap_setting = get_system_setting(db, "ai_qa_weekly_settle_cap_pence")
    cap_pence = int(cap_setting.setting_value) if cap_setting else 20000
    weekly_pence = ai_qa_crud.get_weekly_settled_pence(db)
    if weekly_pence + q.reward_pool_pence > cap_pence:
        raise SettleError(
            f"weekly settle cap exceeded: already £{weekly_pence/100:.2f}, "
            f"plus £{q.reward_pool_pence/100:.2f} > cap £{cap_pence/100:.2f}"
        )

    # === 拉所有 active answer score 行（hide_in_qa=False）===
    rows = ai_qa_crud.list_answer_scores_for_question(db, qid, include_hidden=False)
    # 计算 final_score
    for r in rows:
        if r.hide_in_qa:
            r.final_score = 0
        elif r.admin_override_score is not None:
            r.final_score = r.admin_override_score
        else:
            r.final_score = r.ai_score or 0
    # 按分降序
    rows.sort(key=lambda r: r.final_score, reverse=True)

    # === 算 winner + 分钱 ===
    scored_tuples = [(r.id, r.final_score) for r in rows]
    distribution = distribute_pool(
        scored_tuples,
        pool_pence=q.reward_pool_pence,
        floor_pence=q.floor_pence,
    )
    distribution_map = dict(distribution)

    # === 写 rank_final + reward_pence + settled_at ===
    # rank_final 用密集排名 (dense ranking): 并列分共享 rank,下一个不跳号
    # 例: scores=[90,80,80,70,60] → ranks=[1,2,2,3,4] (不是 [1,2,2,4,5])
    # spec §6.1 "rank_final ∈ [1,3] 且 settled" 金边规则:并列时多人都享金边
    settled_at = datetime.now(timezone.utc)
    top1_user_id = None
    top1_forum_post_id = None
    total_settled_pence = 0
    prev_score = None
    current_rank = 0
    for i, r in enumerate(rows):
        if r.final_score != prev_score:
            current_rank = i + 1
        r.rank_final = current_rank
        prev_score = r.final_score
        r.reward_pence = distribution_map.get(r.id, 0)
        r.reward_points = q.participation_points  # 所有未 hide 答主都拿
        r.settled_at = settled_at
        if r.rank_final == 1 and top1_user_id is None:
            top1_user_id = r.user_id
            top1_forum_post_id = r.forum_post_id
        total_settled_pence += r.reward_pence

    # === wallet credit (每个答案被采纳的用户) ===
    for r in rows:
        if r.reward_pence <= 0:
            continue
        lock_wallet(db, r.user_id, currency="GBP")  # 行锁
        tx = credit_wallet(
            db,
            user_id=r.user_id,
            amount=Decimal(r.reward_pence) / 100,
            currency="GBP",
            source="ai_qa_reward",
            related_type="ai_question",
            related_id=str(qid),
            idempotency_key=f"ai_qa_settle_{qid}_{r.user_id}",
            description=f"AI 限时问答 #{qid} 第 {r.rank_final} 名奖金",
        )
        # wallet_service.credit_wallet 幂等冲突时返回 None (不抛 IntegrityError,
        # 见 wallet_service.py:156-158);这里检查 None 视为"已入账,跳过":
        if tx is None:
            # idempotency_key 命中已存在的 transaction — 该 user 已发过,跳过(重试场景)
            logger.info(f"settle ai_qa #{qid} user {r.user_id}: wallet credit skipped (idempotent)")
            continue
        # 真正的事务错误 (lock 超时 / DB 故障 / 余额异常) 由 credit_wallet raise,
        # 冒泡到外层 settle_question try/except → status=settle_failed

    # === add_points_transaction (所有未 hide 答主,含答案未被采纳的) ===
    # 幂等防双发: settle_failed 重试场景下 add_points_transaction 命中 idempotency_key
    # 会直接 return 已存在 txn (coupon_points_crud:96-102),不会双发。
    # Final review critical issue #5.
    for r in rows:
        add_points_transaction(
            db,
            user_id=r.user_id,
            amount=r.reward_points,
            type="earn",
            source="ai_qa_participation",
            related_id=qid,
            idempotency_key=f"ai_qa_settle_points_{qid}_{r.user_id}",
        )

    # === leaderboard upsert ===
    for r in rows:
        ai_qa_crud.upsert_leaderboard(
            db,
            user_id=r.user_id,
            won_pence_delta=r.reward_pence,
            won=(r.reward_pence > 0),
        )

    # === L3.b ForumPost.is_featured ===
    if top1_forum_post_id:
        fp = db.get(models.ForumPost, top1_forum_post_id)
        if fp:
            fp.is_featured = True

    # === 切 status ===
    q.status = "settled"
    q.settled_at = settled_at

    # === S3 审计 ===
    # ⚠️ create_audit_log 函数内部自带 db.commit() (crud/audit.py:34) —
    # 该调用会一次性 commit 上面 lock+wallet credit+leaderboard+is_featured+status 切换的全部写入。
    # 这是隐式的事务边界,plan 接受此现状不动 audit_log 函数。
    # 任一前置写入失败 → 不会走到这里 (异常冒泡) → 外层路由 try/except 回滚到 settle_failed。
    # 后续 db.flush() / 路由层 db.commit() 都是 no-op。
    create_audit_log(
        db,
        action_type="ai_qa_settle",
        entity_type="ai_question",
        entity_id=str(qid),
        admin_id=admin_id,
        new_value={
            "total_settled_pence": total_settled_pence,
            "winner_count": sum(1 for r in rows if r.reward_pence > 0),
            "top1_user_id": top1_user_id,
        },
        reason=f"settle ai_question #{qid}",
    )

    db.flush()  # no-op (audit_log 内部 commit 已 flush 了全部);保留是为可读性
    return {
        "total_settled_pence": total_settled_pence,
        "winner_count": sum(1 for r in rows if r.reward_pence > 0),
        "top1_user_id": top1_user_id,
    }


def maybe_send_s6_alert(qid: int, admin_id: str):
    """事务外异步调（事务 commit 后）。周累计 ≥ 阈值发 email。

    BackgroundTasks 在 response 返回后才执行,届时 request-scoped db session 已 close。
    所以内部必须自开 session,不能接收外部传入的 db (final review hard issue #1)。
    """
    from app.database import SessionLocal
    with SessionLocal() as db:
        threshold = get_system_setting(db, "ai_qa_settle_alert_threshold_pence")
        threshold_pence = int(threshold.setting_value) if threshold else 10000
        weekly = ai_qa_crud.get_weekly_settled_pence(db)
        if weekly < threshold_pence:
            return
        # 拉所有 admin email
        admin_emails = [
            a.email for a in db.execute(
                select(models.AdminUser).where(models.AdminUser.is_active == True)
            ).scalars() if a.email
        ]
    if not admin_emails:
        return
    subject = "[Link2Ur] AI 限时问答周度发奖触达阈值"
    body = (
        f"本周 AI 限时问答累计已 settled £{weekly/100:.2f}（阈值 £{threshold_pence/100:.2f}）。\n"
        f"· 本次触发：题目 #{qid}\n"
        f"· 操作 admin：{admin_id}\n"
        f"· 时间：{get_utc_time().isoformat()}\n"
        f"· 若非预期，立即检查 audit log + admin 账号被陷可能。"
    )
    for email in admin_emails:
        try:
            send_email(to_email=email, subject=subject, body=body)  # email_utils.py:183 signature
        except Exception as e:
            logger.error(f"S6 email send failed to {email}: {e}")
