"""AI 限时问答 — 用户端路由 /api/ai-qa/*"""
from datetime import datetime, timezone
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import func, select, case
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

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
    status_in: Optional[str] = None,
    limit: int = 20,
    offset: int = 0,
    db: Session = Depends(get_db),
):
    """用户端列表（当期 + 历史）。无权限校验。

    M2 列表页支持 status_in (逗号分隔多状态)，例如:
      ?status_in=published,scoring,scored   → 当期
      ?status_in=settled,canceled,closed_empty → 历史
    单 status 参数保留兼容老调用方。response 包含 answer_count / winners_count
    便于 list-card UI 渲染 "X 人作答 / 采纳 Y 条"，不影响详情页/admin端逻辑。
    """
    statuses: Optional[List[str]] = None
    if status_in:
        statuses = [s.strip() for s in status_in.split(",") if s.strip()]
    qs = ai_qa_crud.list_questions(
        db, status=status, statuses=statuses, limit=limit, offset=offset,
    )
    if not qs:
        return []
    qids = [q.id for q in qs]
    # 一次性统计 answer_count + winners_count，避免 N+1
    rows = db.execute(
        select(
            AiAnswerScore.ai_question_id,
            func.count(AiAnswerScore.id).label("answer_count"),
            func.sum(case((AiAnswerScore.reward_pence > 0, 1), else_=0)).label("winners_count"),
        )
        .where(AiAnswerScore.ai_question_id.in_(qids))
        .where(AiAnswerScore.hide_in_qa == False)  # noqa: E712
        .group_by(AiAnswerScore.ai_question_id)
    ).all()
    stats = {r.ai_question_id: (r.answer_count or 0, r.winners_count or 0) for r in rows}
    out: List[AiQuestionOut] = []
    for q in qs:
        item = AiQuestionOut.model_validate(q)
        ac, wc = stats.get(q.id, (0, 0))
        item.answer_count = ac
        item.winners_count = wc
        out.append(item)
    return out


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
        # spec §7: 帖子被论坛 hidden 机制隐藏 (is_visible=False) 应跟 is_deleted 一样不显示内容,
        # 但保留 ai_answer_scores 行 (settle 后仍展示 reward) — deep audit issue #9
        post_hidden = bool(post and (post.is_deleted or not post.is_visible)) if post else True
        # ForumPost.images 是 JSON 字段,理论上是 List[str] (Pydantic AnswerCreate.images 已 validate),
        # 但 legacy data 或 admin 直接改可能塞非 str — defensive coerce 兜底 (deep audit issue #11)
        post_images = post.images if (post and not post_hidden) else None
        if post_images is not None:
            if isinstance(post_images, list):
                post_images = [str(x) for x in post_images if x is not None]
            else:
                post_images = None  # 不是 list 直接丢
        out.append(AiAnswerOut(
            id=r.id,
            forum_post_id=r.forum_post_id,
            user_id=r.user_id,
            user_name=user.name if user else None,
            user_avatar=user.avatar if user else None,
            title=post.title if post and not post_hidden else None,
            content=post.content if post and not post_hidden else None,
            images=post_images,
            created_at=post.created_at if post else None,
            is_deleted=post_hidden,  # is_deleted 字段对外语义="不显示内容",含论坛 hidden
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
        # detail 仅放 error code(让 Flutter error_localizer 命中 l10n),
        # reason 通过 response header 透传 admin debug
        raise HTTPException(
            status_code=403,
            detail="ai_qa_blocked_by_risk",
            headers={"X-Risk-Reason": reason or "unknown"},
        )
    # 事务: 建 ForumPost + ai_answer_scores 行
    # NOTE(P0-T7): plan 原文调用 `forum_crud.create_post(...)`,但 `app.crud.forum` 模块不存在
    # (现有 forum post 创建逻辑在 `app.routes.forum_posts_routes.create_post`,异步、带速率限制/内容审核,
    # 不能直接复用)。这里 inline 一个最小 ForumPost insert——同样写到 forum_posts 表,带 ai_question_id 反向关联。
    #
    # TODO P1 安全收口: 当前绕过 forum_posts_routes 的敏感词/速率限制 helper,
    # 仅靠 risk_control.check_risk 覆盖反作弊。Spec §7 要求"敏感词命中走现有论坛 hidden 机制",
    # P1 接入 _check_content_moderation 或加专用 ai-qa 敏感词检查。
    # 当前接受风险: admin 控制题目方向,UGC 答题量小,人工 admin 审兜底。
    # title [:200] 后端兜底防止恶意客户端绕过 Pydantic max_length=200 校验
    safe_title = (payload.title or q.title)[:200]
    post = models.ForumPost(
        author_id=current_user.id,
        category_id=q.target_forum_category_id,
        title=safe_title,
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
    # 兜底并发场景: 两个客户端同时提交,get_user_answer 都返 None,但 UNIQUE 约束在 commit 时
    # 触发 IntegrityError。把它转成 409 而不是 500 (deep audit issue #8)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "ai_qa_already_answered")
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
    # title [:200] 后端兜底防止恶意客户端绕过 Pydantic max_length=200 校验
    post.title = (payload.title or q.title)[:200]
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
