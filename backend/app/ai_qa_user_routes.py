"""AI 限时问答 — 用户端路由 /api/ai-qa/*"""
from datetime import datetime, timezone
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app import models
from app.deps import get_db, get_current_user_secure_sync_csrf
from app.models_ai_qa import AiQuestion, AiAnswerScore
from app.schemas_ai_qa import AiQuestionOut, AiAnswerOut, AnswerCreate
from app.crud import ai_qa as ai_qa_crud
from app.risk_control import check_risk
from app.device_fingerprint import generate_device_fingerprint, get_ip_address

router = APIRouter(prefix="/api/ai-qa", tags=["AI Limited QA"])


@router.get("", response_model=List[AiQuestionOut])
def list_questions(
    status: Optional[str] = None,
    limit: int = 20,
    offset: int = 0,
    db: Session = Depends(get_db),
):
    """用户端列表（当期 + 历史）。无权限校验。"""
    qs = ai_qa_crud.list_questions(db, status=status, limit=limit, offset=offset)
    return qs


@router.get("/leaderboard")
def get_leaderboard(limit: int = 50, db: Session = Depends(get_db)):
    """P0 写入数据,P2 前端入口才上;端点 P0 可访问。"""
    lb = ai_qa_crud.list_leaderboard(db, limit=limit)
    return [
        {
            "user_id": item.user_id,
            "total_won_pence": item.total_won_pence,
            "win_count": item.win_count,
            "answer_count": item.answer_count,
            "last_won_at": item.last_won_at.isoformat() if item.last_won_at else None,
        }
        for item in lb
    ]


@router.get("/{qid}", response_model=AiQuestionOut)
def get_question(qid: int, db: Session = Depends(get_db)):
    q = ai_qa_crud.get_question(db, qid)
    if q is None or q.status == "draft":
        raise HTTPException(404, "ai_qa_not_found")
    return q


@router.get("/{qid}/answers", response_model=List[AiAnswerOut])
def list_answers(qid: int, db: Session = Depends(get_db)):
    """答案列表。published 期间显示所有人答案；settled 后含 reward。"""
    q = ai_qa_crud.get_question(db, qid)
    if q is None or q.status == "draft":
        raise HTTPException(404, "ai_qa_not_found")
    rows = ai_qa_crud.list_answer_scores_for_question(db, qid, include_hidden=False)
    if not rows:
        return []
    forum_post_ids = [r.forum_post_id for r in rows]
    posts = {
        p.id: p for p in db.query(models.ForumPost).filter(models.ForumPost.id.in_(forum_post_ids))
    }
    users = {
        u.id: u for u in db.query(models.User).filter(models.User.id.in_([r.user_id for r in rows]))
    }
    out = []
    for r in rows:
        post = posts.get(r.forum_post_id)
        user = users.get(r.user_id)
        out.append(AiAnswerOut(
            id=r.id,
            forum_post_id=r.forum_post_id,
            user_id=r.user_id,
            user_name=user.name if user else None,
            user_avatar=user.avatar if user else None,
            title=post.title if post and not post.is_deleted else None,
            content=post.content if post and not post.is_deleted else None,
            images=post.images if post and not post.is_deleted else None,
            created_at=post.created_at if post else None,
            is_deleted=bool(post.is_deleted) if post else True,
            ai_score=r.ai_score,
            ai_generated=r.ai_generated,
            final_score=r.final_score,
            rank_final=r.rank_final,
            reward_pence=r.reward_pence,
            hide_in_qa=r.hide_in_qa,
        ))
    # settled 后按 rank_final 升序;否则按 created_at 倒序
    if q.status == "settled":
        out.sort(key=lambda a: (a.rank_final or 999, a.id))
    else:
        out.sort(key=lambda a: a.created_at or datetime.min, reverse=True)
    return out


@router.post("/{qid}/answer")
def submit_answer(
    qid: int,
    payload: AnswerCreate,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """答题端点 (spec §4.2 校验顺序 1-8)。"""
    q = ai_qa_crud.get_question(db, qid)
    if q is None:
        raise HTTPException(404, "ai_qa_not_found")
    if q.status != "published":
        raise HTTPException(409, f"ai_qa_status_not_published")
    now = datetime.now(timezone.utc)
    if q.deadline and now >= q.deadline:
        raise HTTPException(409, "ai_qa_deadline_passed")
    if q.edit_lock_at and now >= q.edit_lock_at:
        raise HTTPException(409, "ai_qa_edit_locked")
    # 重复答 (DB UNIQUE 兜底, 这里先查避免反复 insert 失败)
    if ai_qa_crud.get_user_answer(db, qid, current_user.id):
        raise HTTPException(409, "ai_qa_already_answered")
    # 风控
    device_fp = generate_device_fingerprint(request=request)
    ip = get_ip_address(request)
    allowed, reason, risk_score = check_risk(
        db, user_id=current_user.id, action_type="ai_qa_answer",
        device_fingerprint=device_fp, ip_address=ip,
    )
    if not allowed:
        raise HTTPException(403, f"ai_qa_blocked_by_risk: {reason}")
    # 事务: 建 ForumPost + ai_answer_scores 行
    # NOTE(P0-T7): plan 原文调用 `forum_crud.create_post(...)`,但 `app.crud.forum` 模块不存在
    # (现有 forum post 创建逻辑在 `app.routes.forum_posts_routes.create_post`,异步、带速率限制/内容审核,
    # 不能直接复用)。这里 inline 一个最小 ForumPost insert——同样写到 forum_posts 表,带 ai_question_id 反向关联。
    post = models.ForumPost(
        author_id=current_user.id,
        category_id=q.target_forum_category_id,
        title=payload.title or q.title[:200],
        content=payload.content,
        images=payload.images,
        ai_question_id=qid,
    )
    db.add(post)
    db.flush()
    ai_qa_crud.create_answer_score_row(
        db,
        ai_question_id=qid,
        forum_post_id=post.id,
        user_id=current_user.id,
        risk_score=risk_score or 0,
        risk_reasons=reason,
    )
    db.commit()
    return {"forum_post_id": post.id, "ai_question_id": qid}


@router.patch("/{qid}/answer", response_model=dict)
def edit_answer(
    qid: int,
    payload: AnswerCreate,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    编辑答案 (spec §2 "截止前 1 小时锁编辑")。

    校验顺序:
    1. ai_question 存在 → 404
    2. status='published' → 否则 409 ai_qa_status_not_published
    3. now < deadline → 否则 409 ai_qa_deadline_passed
    4. now < edit_lock_at → 否则 409 ai_qa_edit_locked
    5. 当前 user 在此题有答案 → 否则 404 ai_qa_answer_not_found
    6. UPDATE ForumPost.title/content/images (ai_question_id / author_id 不动)
    7. ai_answer_scores 行不变 (评分阶段未到,不需要重置)
    """
    q = db.get(AiQuestion, qid)
    if q is None:
        raise HTTPException(404, "ai_qa_not_found")
    if q.status != "published":
        raise HTTPException(409, "ai_qa_status_not_published")
    now = datetime.now(timezone.utc)
    if q.deadline and now >= q.deadline:
        raise HTTPException(409, "ai_qa_deadline_passed")
    if q.edit_lock_at and now >= q.edit_lock_at:
        raise HTTPException(409, "ai_qa_edit_locked")
    row = ai_qa_crud.get_user_answer(db, qid, current_user.id)
    if row is None:
        raise HTTPException(404, "ai_qa_answer_not_found")
    post = db.get(models.ForumPost, row.forum_post_id)
    if post is None or post.is_deleted:
        raise HTTPException(404, "ai_qa_answer_not_found")
    # 更新 ForumPost (post 字段; ai_question_id / author_id / category_id 不动)
    post.title = payload.title or q.title[:200]
    post.content = payload.content
    if payload.images is not None:
        post.images = payload.images
    db.flush()
    db.commit()
    return {
        "forum_post_id": post.id,
        "ai_question_id": qid,
        "updated_at": post.updated_at.isoformat() if post.updated_at else None,
    }
