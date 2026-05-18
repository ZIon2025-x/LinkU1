"""AI 限时问答 CRUD 函数。"""
from datetime import datetime, timezone, timedelta
from typing import Optional, List
from sqlalchemy.orm import Session
from sqlalchemy import select, func, and_

from app import models
from app.models_ai_qa import (
    AiQuestion, AiQuestionCandidate, AiAnswerScore,
    AiQaLeaderboard, AiQaCycleConfig,
)
from app.schemas_ai_qa import DraftCreate, DraftUpdate


# ========== Draft / Question 写 ==========
def create_draft(db: Session, admin_id: str, payload: DraftCreate, default_expert_id: str) -> AiQuestion:
    """创建草稿。posed_by_expert_id 默认用 SystemSettings 的值。"""
    expert_id = payload.posed_by_expert_id or default_expert_id
    if not expert_id:
        raise ValueError("posed_by_expert_id required (no default set)")
    edit_lock_at = payload.deadline - timedelta(hours=payload.edit_lock_hours_before)
    q = AiQuestion(
        title=payload.title,
        content=payload.content,
        topic_tag=payload.topic_tag,
        posed_by_expert_id=expert_id,
        status="draft",
        deadline=payload.deadline,
        edit_lock_at=edit_lock_at,
        reward_pool_pence=payload.reward_pool_pence,
        participation_points=payload.participation_points,
        floor_pence=payload.floor_pence,
        target_forum_category_id=payload.target_forum_category_id,
        cycle_config_id=None,
        created_by_admin_id=admin_id,
    )
    db.add(q)
    db.flush()
    return q


def update_draft(db: Session, q: AiQuestion, payload: DraftUpdate) -> AiQuestion:
    """更新草稿。仅 status='draft' 时可调（调用方校验）。"""
    data = payload.model_dump(exclude_unset=True)
    if "deadline" in data and "edit_lock_hours_before" in data:
        data["edit_lock_at"] = data["deadline"] - timedelta(hours=data["edit_lock_hours_before"])
        del data["edit_lock_hours_before"]
    elif "deadline" in data:
        # 重算 edit_lock_at 基于原 hours_before（默认 1）
        hours = 1
        data["edit_lock_at"] = data["deadline"] - timedelta(hours=hours)
    elif "edit_lock_hours_before" in data:
        del data["edit_lock_hours_before"]
    for k, v in data.items():
        setattr(q, k, v)
    db.flush()
    return q


def publish_draft(db: Session, q: AiQuestion) -> AiQuestion:
    """draft → published。"""
    if q.status != "draft":
        raise ValueError(f"only draft can be published, got status={q.status}")
    q.status = "published"
    q.published_at = datetime.now(timezone.utc)
    db.flush()
    return q


def cancel_question(db: Session, q: AiQuestion, admin_id: str, reason: str) -> AiQuestion:
    """published → canceled。只切状态;参与积分补发由 caller 在同事务调 award_participation_points_on_cancel。

    TODO sponsor: caller 在切状态后同事务还要调 carry_over_pledges_to_pool(db, qid) (sponsor spec §4.2),
    把本题 sponsor_pool_pence + pledge_pool_carryover_pence 进全局加注池。
    """
    if q.status != "published":
        raise ValueError(f"only published can be canceled, got status={q.status}")
    q.status = "canceled"
    q.canceled_at = datetime.now(timezone.utc)
    q.cancel_reason = reason
    db.flush()
    return q


def award_participation_points_on_cancel(db: Session, qid: int) -> int:
    """canceled 时补发参与积分给所有未删答主 (spec §7 + §4.4)。

    扫 forum_posts WHERE ai_question_id=qid AND is_deleted=False,逐个 add_points_transaction。
    幂等:用 source='ai_qa_cancel_participation' + related_id=qid + reference=user_id 防重 (依赖
    points_transactions 现有去重机制;如无 UNIQUE,可用 SystemSettings flag 兜底避免双发)。
    返回补发人数。

    注意:
    - 不写 ai_qa_leaderboard (spec §4.4 末段:canceled 题不写 leaderboard,保持数据干净只反映正常 settled)
    - 调用方必须先调 cancel_question 切状态,再调本函数;失败时事务回滚,状态也回滚
    """
    from app.models import ForumPost
    from app.coupon_points_crud import add_points_transaction  # 现有积分服务

    q = db.get(AiQuestion, qid)
    if not q or q.status != "canceled":
        raise ValueError(f"question {qid} not in canceled state")

    posts = db.execute(
        select(ForumPost).where(
            and_(ForumPost.ai_question_id == qid, ForumPost.is_deleted == False)
        )
    ).scalars().all()

    count = 0
    for post in posts:
        add_points_transaction(
            db,
            user_id=post.user_id,
            type='earn',  # add_points_transaction 必填 (signature: earn/spend/refund/expire)
            amount=q.participation_points,
            source='ai_qa_cancel_participation',
            related_type='ai_question',
            related_id=qid,  # Optional[int],不要 str()
            description=f'AI 限时问答 #{qid} 被取消,补发参与积分',
            # 幂等防双发: 双击撤稿/重试 cancel 都走同一个 key,add_points_transaction
            # 命中 idempotency_key 时直接 return 已存在 txn (coupon_points_crud:96-102),
            # 不会双发。Final review critical issue #4.
            idempotency_key=f'ai_qa_cancel_{qid}_{post.user_id}',
        )
        count += 1
    db.flush()
    return count


def list_questions(
    db: Session, status: Optional[str] = None, limit: int = 50, offset: int = 0
) -> List[AiQuestion]:
    stmt = select(AiQuestion)
    if status:
        stmt = stmt.where(AiQuestion.status == status)
    stmt = stmt.order_by(AiQuestion.created_at.desc()).limit(limit).offset(offset)
    return list(db.execute(stmt).scalars())


def get_question(db: Session, qid: int) -> Optional[AiQuestion]:
    return db.get(AiQuestion, qid)


# ========== Answer (ai_answer_scores 行) 写 ==========
def create_answer_score_row(
    db: Session, ai_question_id: int, forum_post_id: int, user_id: str,
    risk_score: int, risk_reasons: Optional[str],
) -> AiAnswerScore:
    """答题时建 ai_answer_scores 行,评分阶段 UPDATE。"""
    row = AiAnswerScore(
        ai_question_id=ai_question_id,
        forum_post_id=forum_post_id,
        user_id=user_id,
        risk_score=risk_score,
        risk_reasons=risk_reasons,
    )
    db.add(row)
    db.flush()
    return row


def list_answer_scores_for_question(
    db: Session, ai_question_id: int, include_hidden: bool = False,
) -> List[AiAnswerScore]:
    stmt = select(AiAnswerScore).where(AiAnswerScore.ai_question_id == ai_question_id)
    if not include_hidden:
        stmt = stmt.where(AiAnswerScore.hide_in_qa == False)
    return list(db.execute(stmt).scalars())


def get_user_answer(db: Session, ai_question_id: int, user_id: str) -> Optional[AiAnswerScore]:
    stmt = select(AiAnswerScore).where(
        and_(AiAnswerScore.ai_question_id == ai_question_id,
             AiAnswerScore.user_id == user_id)
    )
    return db.execute(stmt).scalar_one_or_none()


def update_admin_score(
    db: Session, row: AiAnswerScore, admin_id: str,
    admin_override_score: Optional[int], hide_in_qa: Optional[bool],
) -> AiAnswerScore:
    if admin_override_score is not None:
        row.admin_override_score = admin_override_score
    if hide_in_qa is not None:
        row.hide_in_qa = hide_in_qa
    row.admin_reviewer_id = admin_id
    row.admin_reviewed_at = datetime.now(timezone.utc)
    db.flush()
    return row


# ========== Leaderboard ==========
def upsert_leaderboard(
    db: Session, user_id: str, won_pence_delta: int, won: bool,
):
    """settle 时调,更新或插入 leaderboard 行。"""
    lb = db.get(AiQaLeaderboard, {"user_id": user_id})
    if lb is None:
        lb = AiQaLeaderboard(user_id=user_id, total_won_pence=0, win_count=0, answer_count=0)
        db.add(lb)
    lb.answer_count += 1
    if won:
        lb.total_won_pence += won_pence_delta
        lb.win_count += 1
        lb.last_won_at = datetime.now(timezone.utc)
    db.flush()
    return lb


def list_leaderboard(db: Session, limit: int = 50) -> List[AiQaLeaderboard]:
    stmt = select(AiQaLeaderboard).order_by(
        AiQaLeaderboard.total_won_pence.desc()
    ).limit(limit)
    return list(db.execute(stmt).scalars())


# ========== S5 周度发奖上限 ==========
def get_weekly_settled_pence(db: Session) -> int:
    """查 7 天内累计 settled pence 总和。"""
    cutoff = datetime.now(timezone.utc) - timedelta(days=7)
    stmt = select(func.coalesce(func.sum(AiAnswerScore.reward_pence), 0)).where(
        AiAnswerScore.settled_at >= cutoff
    )
    return db.execute(stmt).scalar_one()
