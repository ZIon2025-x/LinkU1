"""AI 限时问答 — Admin 端路由 /api/admin/ai-qa/*"""
from datetime import datetime, timezone, timedelta
from typing import Optional, List
import logging
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session

from app import models
from app.deps import get_db
from app.separate_auth_deps import get_current_admin  # 现有 admin auth (在 separate_auth_deps.py:20,不是 separate_auth)
from app.models_ai_qa import AiQuestion, AiAnswerScore
from app.schemas_ai_qa import (
    DraftCreate, DraftUpdate, AdminScoreUpdate, CancelRequest,
    SettingUpdate, AdminReviewData, AdminReviewRow, AiQuestionOut,
)
from app.crud import ai_qa as ai_qa_crud
from app.crud.system import get_system_setting, update_system_setting  # 注意:函数名是 update_ 不是 set_
from app.coupon_points_crud import add_points_transaction  # 积分入口在 coupon_points_crud,不在 crud.points
from app.crud.audit import create_audit_log
from app.services.ai_qa_settle import settle_question, maybe_send_s6_alert, SettleError

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin/ai-qa", tags=["Admin · AI Limited QA"])


def _audit(db, action, qid_or_id, admin_id, *, entity_type: str = "ai_question",
           old=None, new=None, reason=None):
    """Audit log helper for ai-qa admin actions.

    entity_type defaults to 'ai_question' (most actions). Caller MUST override for:
      - score_update → 'ai_answer_score' (entity_id = score row id, not qid)
      - settings_update → 'system_setting' (entity_id = setting key)
    Final review hard issue #3.
    """
    create_audit_log(
        db, action_type=f"ai_qa_{action}", entity_type=entity_type,
        entity_id=str(qid_or_id), admin_id=admin_id,
        old_value=old, new_value=new, reason=reason,
    )


# ========== Drafts ==========
@router.post("/drafts", response_model=AiQuestionOut)
def create_draft(
    payload: DraftCreate,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    default_expert = get_system_setting(db, "ai_qa_default_expert_id")
    default_expert_id = (default_expert.setting_value if default_expert else "") or None
    try:
        q = ai_qa_crud.create_draft(db, admin.id, payload, default_expert_id)
    except ValueError as e:
        raise HTTPException(400, str(e))
    _audit(db, "draft_create", q.id, admin.id, new={"title": q.title, "reward_pool_pence": q.reward_pool_pence})
    db.commit()
    return q


@router.patch("/drafts/{qid}", response_model=AiQuestionOut)
def update_draft(
    qid: int, payload: DraftUpdate,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    q = ai_qa_crud.get_question(db, qid)
    if q is None:
        raise HTTPException(404, "ai_qa_not_found")
    if q.status != "draft":
        raise HTTPException(409, "ai_qa_only_draft_editable")
    # FK preflight: target_forum_category_id 改时校验 forum_categories 存在,避免 commit 时 500
    if payload.target_forum_category_id is not None:
        category = db.get(models.ForumCategory, payload.target_forum_category_id)
        if category is None:
            raise HTTPException(422, "ai_qa_forum_category_not_found")
    old = {"title": q.title, "reward_pool_pence": q.reward_pool_pence}
    ai_qa_crud.update_draft(db, q, payload)
    _audit(db, "draft_update", qid, admin.id, old=old, new={"title": q.title, "reward_pool_pence": q.reward_pool_pence})
    db.commit()
    return q


@router.delete("/drafts/{qid}", status_code=204)
def delete_draft(
    qid: int,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    q = ai_qa_crud.get_question(db, qid)
    if q is None:
        raise HTTPException(404, "ai_qa_not_found")
    if q.status != "draft":
        raise HTTPException(409, "ai_qa_only_draft_deletable")
    _audit(db, "draft_delete", qid, admin.id, old={"title": q.title})
    db.delete(q)
    db.commit()
    return None


@router.post("/drafts/{qid}/publish", response_model=AiQuestionOut)
def publish_draft(
    qid: int,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    q = ai_qa_crud.get_question(db, qid)
    if q is None:
        raise HTTPException(404, "ai_qa_not_found")
    try:
        ai_qa_crud.publish_draft(db, q)
    except ValueError as e:
        raise HTTPException(409, str(e))
    _audit(db, "publish", qid, admin.id, new={"status": "published"})
    db.commit()
    # TODO: 全站通知 "新一期问答开放"（接现有通知 service）
    return q


# ========== Questions 管理 ==========
@router.get("/questions", response_model=List[AiQuestionOut])
def list_questions(
    status: Optional[str] = None,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    return ai_qa_crud.list_questions(db, status=status, limit=200)


@router.post("/questions/{qid}/cancel", response_model=AiQuestionOut)
def cancel_question(
    qid: int, payload: CancelRequest,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    Admin 撤稿。同事务保证:
      1. cancel_question 切状态 (published → canceled)
      2. award_participation_points_on_cancel 给所有未删答主补 participation_points (spec §7)
      3. 单独 audit log (action_type='ai_qa_cancel' + reason)

    任一步异常 → 整事务回滚,status 不变,积分不发,确保一致。

    TODO P1 admin 安全: 当前 solo admin 模式可接受;多 admin 时此端点应改 require_super_admin
    (cancel 影响用户积分发放 + 全站可见状态切换)。

    TODO sponsor (上线时同事务追加):
      - ai_qa_sponsor.carry_over_pledges_to_pool(db, qid)  # sponsor spec §4.2
        把本题 sponsor_pool_pence + pledge_pool_carryover_pence 进全局加注池
    """
    q = ai_qa_crud.get_question(db, qid)
    if q is None:
        raise HTTPException(404, "ai_qa_not_found")
    try:
        ai_qa_crud.cancel_question(db, q, admin.id, payload.reason)
        # 同事务补发参与积分 (helper 内部扫 forum_posts 而非 ai_answer_scores,
        # 兼容用户绕过 /api/ai-qa/{id}/answer 入口直接塞 ai_question_id 进论坛的边缘 case)
        awarded_count = ai_qa_crud.award_participation_points_on_cancel(db, qid)
    except ValueError as e:
        raise HTTPException(409, str(e))
    _audit(
        db, "cancel", qid, admin.id,
        old={"status": "published"},
        new={"status": "canceled", "reason": payload.reason, "participation_awarded_count": awarded_count},
    )
    db.commit()
    # TODO: 全站通知 "本期问答已取消" (含已答用户的私推)
    return q


# ========== Review (终审表格) ==========
@router.get("/questions/{qid}/review", response_model=AdminReviewData)
def get_review_data(
    qid: int,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    q = ai_qa_crud.get_question(db, qid)
    if q is None:
        raise HTTPException(404, "ai_qa_not_found")
    rows = ai_qa_crud.list_answer_scores_for_question(db, qid, include_hidden=True)
    forum_post_ids = [r.forum_post_id for r in rows]
    posts = {p.id: p for p in db.query(models.ForumPost).filter(models.ForumPost.id.in_(forum_post_ids))}
    users = {u.id: u for u in db.query(models.User).filter(models.User.id.in_([r.user_id for r in rows]))}
    # 实时算预算 (本期已确认的)
    cap_setting = get_system_setting(db, "ai_qa_weekly_settle_cap_pence")
    cap_pence = int(cap_setting.setting_value) if cap_setting else 20000
    weekly_pence = ai_qa_crud.get_weekly_settled_pence(db)
    review_rows = []
    for r in rows:
        post = posts.get(r.forum_post_id)
        user = users.get(r.user_id)
        review_rows.append(AdminReviewRow(
            id=r.id, user_id=r.user_id, user_name=user.name if user else None,
            forum_post_id=r.forum_post_id,
            forum_post_created_at=post.created_at if post else datetime.min,
            forum_post_updated_at=post.updated_at if post else None,
            is_edited=bool(post and post.updated_at and post.updated_at != post.created_at),
            content_preview=(post.content[:200] if post and post.content else ""),
            ai_score=r.ai_score, ai_generated=r.ai_generated,
            risk_score=r.risk_score, risk_reasons=r.risk_reasons,
            admin_override_score=r.admin_override_score, hide_in_qa=r.hide_in_qa,
            cash_budget_pence=0,  # 前端实时算
        ))
    return AdminReviewData(
        question=q, rows=review_rows,
        weekly_settled_pence=weekly_pence,
        weekly_cap_pence=cap_pence,
    )


@router.patch("/scores/{score_id}")
def update_score(
    score_id: int, payload: AdminScoreUpdate,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    row = db.get(AiAnswerScore, score_id)
    if row is None:
        raise HTTPException(404, "ai_qa_score_not_found")
    # 不允许改 settled / canceled / closed_empty 状态的答案分数 — settle 已 commit 钱跟 leaderboard,
    # 改分会造成 ghost data (deep audit issue #10)
    parent_q = db.get(AiQuestion, row.ai_question_id)
    if parent_q and parent_q.status not in ("scored", "settle_failed", "scoring", "scoring_failed", "closed"):
        raise HTTPException(409, "ai_qa_score_update_status_forbidden")
    if payload.admin_override_score is not None and not (0 <= payload.admin_override_score <= 100):
        raise HTTPException(422, "ai_qa_score_out_of_range")
    old = {"admin_override_score": row.admin_override_score, "hide_in_qa": row.hide_in_qa}
    ai_qa_crud.update_admin_score(db, row, admin.id, payload.admin_override_score, payload.hide_in_qa)
    # entity_type='ai_answer_score' (entity_id = score row id), 不是 ai_question;
    # 把 ai_question_id 放到 reason 里供溯源
    _audit(db, "score_update", score_id, admin.id,
           entity_type="ai_answer_score",
           old=old,
           new={"admin_override_score": row.admin_override_score, "hide_in_qa": row.hide_in_qa},
           reason=f"ai_question_id={row.ai_question_id}")
    db.commit()
    return {"ok": True}


@router.post("/questions/{qid}/rescore")
def rescore(
    qid: int,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    q = ai_qa_crud.get_question(db, qid)
    if q is None:
        raise HTTPException(404, "ai_qa_not_found")
    if q.status != "scoring_failed":
        raise HTTPException(409, "ai_qa_rescore_requires_scoring_failed")
    q.status = "scoring"
    _audit(db, "rescore", qid, admin.id, new={"status": "scoring"})
    db.commit()
    # 异步触发评分 (复用 scheduled_tasks 的逻辑,见 Task 10)
    # prod 用 Celery 异步，linktest 无 Celery 时退化为同步
    try:
        from app.celery_tasks import celery_score_single_ai_question
        celery_score_single_ai_question.delay(qid)
    except (ImportError, AttributeError):
        from app.scheduled_tasks import score_single_ai_question
        score_single_ai_question(qid)
    return {"ok": True}


# ========== Settle ==========
@router.post("/questions/{qid}/settle")
def settle(
    qid: int,
    background: BackgroundTasks,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Admin settle 端点 — 触发 settle_question 事务 + 异步 S6 邮件。

    TODO P1 admin 安全: 当前 solo admin 模式可接受;多 admin 时此端点应改 require_super_admin
    (settle 直接发钱到 wallet,周度 cap 之内一次最多 £200)。
    """
    try:
        result = settle_question(db, qid, admin.id)
    except SettleError as e:
        msg = str(e)
        # 失败 → 切 settle_failed (事务外的状态写)
        q = ai_qa_crud.get_question(db, qid)
        if q and q.status == "scored":
            q.status = "settle_failed"
            _audit(db, "settle_failed", qid, admin.id, reason=msg)
            db.commit()
        raise HTTPException(409, msg)
    except Exception as e:
        logger.exception(f"settle qid={qid} unexpected error")
        q = ai_qa_crud.get_question(db, qid)
        if q:
            q.status = "settle_failed"
            db.commit()
        _audit(db, "settle_failed", qid, admin.id, reason=str(e))
        db.commit()
        raise HTTPException(500, "ai_qa_settle_failed")
    db.commit()
    # 事务外 S6 邮件
    # maybe_send_s6_alert 内部自开 SessionLocal session (BackgroundTasks 在 response
    # 返回后才执行,届时这个 db 已 close),不接收 db 参数
    background.add_task(maybe_send_s6_alert, qid, admin.id)
    return result


# ========== Settings ==========
@router.post("/settings")
def update_settings(
    payload: SettingUpdate,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """更新 ai-qa 系统设置 (周度 cap / 阈值 / 默认 expert_id 等)。

    TODO P1 admin 安全: 当前 solo admin 模式可接受;多 admin 时此端点应改 require_super_admin
    (能改周度发奖 cap → 间接控制所有未来 settle 上限,影响全站发钱总额)。
    """
    # 2 步确认 token 校验（简化版：要求 confirm_token == sha256(key + new_value)[:8]）
    import hashlib
    expected = hashlib.sha256(f"{payload.key}:{payload.new_value}".encode()).hexdigest()[:8]
    if payload.confirm_token != expected:
        raise HTTPException(400, "ai_qa_settings_confirm_token_invalid")
    old = get_system_setting(db, payload.key)
    old_val = old.setting_value if old else None  # get_system_setting 返回 SystemSettings 对象,需取 .setting_value
    update_system_setting(db, payload.key, payload.new_value)
    # entity_type='system_setting' (entity_id = setting key), 不是 ai_question
    _audit(db, "settings_update", payload.key, admin.id,
           entity_type="system_setting",
           old={payload.key: old_val}, new={payload.key: payload.new_value})
    db.commit()
    return {"ok": True}
