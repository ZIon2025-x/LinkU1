"""Q&A endpoints for tasks and services."""
import logging
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import select, func, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.deps import get_async_db_dependency
from app.deps import get_current_user_secure_async_csrf
from app.async_routers import get_current_user_optional
from app.async_crud import AsyncNotificationCRUD

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/questions", tags=["questions"])


class AskQuestionRequest(BaseModel):
    target_type: str = Field(..., pattern="^(task|service)$")
    target_id: int
    content: str = Field(..., min_length=2, max_length=100)


class ReplyQuestionRequest(BaseModel):
    content: str = Field(..., min_length=2, max_length=100)


def _format_question(q: models.Question, current_user_id: Optional[str] = None) -> dict:
    return {
        "id": q.id,
        "target_type": q.target_type,
        "target_id": q.target_id,
        "content": q.content,
        "reply": q.reply,
        "reply_at": q.reply_at.isoformat() if q.reply_at else None,
        "created_at": q.created_at.isoformat() if q.created_at else None,
        "is_own": (current_user_id is not None and q.asker_id == current_user_id),
    }


async def _get_target_owner_id(
    db: AsyncSession, target_type: str, target_id: int
) -> Optional[str]:
    """Get the owner user_id of a task or service."""
    if target_type == "task":
        result = await db.execute(
            select(models.Task.poster_id).where(models.Task.id == target_id)
        )
        row = result.scalar_one_or_none()
        return str(row) if row else None
    elif target_type == "service":
        result = await db.execute(
            select(models.TaskExpertService).where(models.TaskExpertService.id == target_id)
        )
        service = result.scalar_one_or_none()
        if not service:
            return None
        if service.user_id:
            return str(service.user_id)
        return str(service.expert_id) if service.expert_id else None
    return None


@router.get("")
async def list_questions(
    target_type: str = Query(..., pattern="^(task|service)$"),
    target_id: int = Query(...),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取问答列表（公开）"""
    current_user_id = current_user.id if current_user else None
    offset = (page - 1) * page_size

    count_q = select(func.count(models.Question.id)).where(
        models.Question.target_type == target_type,
        models.Question.target_id == target_id,
    )
    total = (await db.execute(count_q)).scalar() or 0

    q = (
        select(models.Question)
        .where(
            models.Question.target_type == target_type,
            models.Question.target_id == target_id,
        )
        .order_by(models.Question.created_at.desc())
        .offset(offset)
        .limit(page_size)
    )
    result = await db.execute(q)
    questions = result.scalars().all()

    return {
        "items": [_format_question(q, current_user_id) for q in questions],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


@router.post("")
async def ask_question(
    body: AskQuestionRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """提问"""
    owner_id = await _get_target_owner_id(db, body.target_type, body.target_id)
    if not owner_id:
        raise HTTPException(status_code=404, detail="Target not found")
    if current_user.id == owner_id:
        raise HTTPException(status_code=403, detail="Cannot ask on your own post")

    content = body.content.strip()
    if len(content) < 2:
        raise HTTPException(status_code=400, detail="Content too short")

    question = models.Question(
        target_type=body.target_type,
        target_id=body.target_id,
        asker_id=current_user.id,
        content=content,
    )
    db.add(question)
    await db.commit()
    await db.refresh(question)

    try:
        target_label = "任务" if body.target_type == "task" else "服务"
        target_label_en = "task" if body.target_type == "task" else "service"
        await AsyncNotificationCRUD.create_notification(
            db=db,
            user_id=owner_id,
            notification_type="question_asked",
            title=f"有人对你的{target_label}提了一个问题",
            content=content[:50],
            related_id=str(question.id),
            title_en=f"Someone asked a question on your {target_label_en}",
            content_en=content[:50],
            related_type="question_id",
        )
    except Exception as e:
        logger.warning(f"Failed to create question notification: {e}")

    return _format_question(question, current_user.id)


@router.post("/{question_id}/reply")
async def reply_question(
    question_id: int,
    body: ReplyQuestionRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """回复问题（仅发布者/服务者）"""
    result = await db.execute(
        select(models.Question).where(models.Question.id == question_id)
    )
    question = result.scalar_one_or_none()
    if not question:
        raise HTTPException(status_code=404, detail="Question not found")

    if question.reply is not None:
        raise HTTPException(status_code=400, detail="Already replied")

    owner_id = await _get_target_owner_id(db, question.target_type, question.target_id)
    if not owner_id or current_user.id != owner_id:
        raise HTTPException(status_code=403, detail="Only the owner can reply")

    content = body.content.strip()
    if len(content) < 2:
        raise HTTPException(status_code=400, detail="Content too short")

    question.reply = content
    question.reply_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(question)

    try:
        await AsyncNotificationCRUD.create_notification(
            db=db,
            user_id=question.asker_id,
            notification_type="question_replied",
            title="你的问题收到了回复",
            content=content[:50],
            related_id=str(question.id),
            title_en="Your question received a reply",
            content_en=content[:50],
            related_type="question_id",
        )
    except Exception as e:
        logger.warning(f"Failed to create reply notification: {e}")

    return _format_question(question, current_user.id)


@router.delete("/{question_id}", status_code=204)
async def delete_question(
    question_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """删除问题（仅提问者）"""
    result = await db.execute(
        select(models.Question).where(models.Question.id == question_id)
    )
    question = result.scalar_one_or_none()
    if not question:
        raise HTTPException(status_code=404, detail="Question not found")

    if question.asker_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the asker can delete")

    await db.execute(
        delete(models.Question).where(models.Question.id == question_id)
    )
    await db.commit()
