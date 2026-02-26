"""
AI Agent API 路由 — SSE 流式响应
"""

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sse_starlette.sse import EventSourceResponse

from app import models
from app.ai_schemas import AIMessageRequest
from app.config import Config
from app.csrf import csrf_cookie_bearer
from app.deps import get_async_db_dependency
from app.services.ai_agent import AIAgent, _state

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/ai", tags=["AI Agent"])


def _parse_accept_language(header_value: str | None) -> str | None:
    if not header_value or not header_value.strip():
        return None
    for part in header_value.split(","):
        part = part.split(";")[0].strip().lower()
        if part.startswith("zh"):
            return "zh"
        if part.startswith("en"):
            return "en"
    return None


async def _get_current_user(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(csrf_cookie_bearer),
) -> models.User:
    from app.secure_auth import validate_session
    from app import async_crud

    session = validate_session(request)
    if session:
        user = await async_crud.async_user_crud.get_user_by_id(db, session.user_id)
        if user:
            if hasattr(user, "is_suspended") and user.is_suspended:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="账户已被暂停")
            if hasattr(user, "is_banned") and user.is_banned:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="账户已被封禁")
            return user

    raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供有效的认证信息")


@router.post("/conversations")
async def create_conversation(
    current_user: models.User = Depends(_get_current_user),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    agent = AIAgent(db, current_user)
    conv = await agent.create_conversation()
    return {
        "id": conv.id,
        "title": conv.title or "",
        "created_at": conv.created_at.isoformat() if conv.created_at else None,
    }


@router.get("/conversations")
async def list_conversations(
    page: int = 1,
    current_user: models.User = Depends(_get_current_user),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    agent = AIAgent(db, current_user)
    return await agent.get_conversations(page=max(1, page))


@router.get("/conversations/{conversation_id}")
async def get_conversation(
    conversation_id: str,
    current_user: models.User = Depends(_get_current_user),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    agent = AIAgent(db, current_user)
    messages = await agent.get_conversation_messages(conversation_id)
    if not messages and conversation_id:
        from sqlalchemy import select, and_
        q = select(models.AIConversation).where(and_(
            models.AIConversation.id == conversation_id,
            models.AIConversation.user_id == current_user.id,
        ))
        conv = (await db.execute(q)).scalar_one_or_none()
        if not conv:
            raise HTTPException(status_code=404, detail="对话不存在")
    return {"messages": messages}


@router.post("/conversations/{conversation_id}/messages")
async def send_message(
    conversation_id: str,
    request_body: AIMessageRequest,
    request: Request,
    current_user: models.User = Depends(_get_current_user),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    has_key = bool(Config.ANTHROPIC_API_KEY or Config.AI_MODEL_SMALL_API_KEY or Config.AI_MODEL_LARGE_API_KEY)
    if not has_key:
        raise HTTPException(status_code=503, detail="AI 服务未配置")

    if not _state.check_rate_limit(current_user.id):
        raise HTTPException(status_code=429, detail="请求过于频繁，请稍后再试")

    from sqlalchemy import select, and_
    q = select(models.AIConversation).where(and_(
        models.AIConversation.id == conversation_id,
        models.AIConversation.user_id == current_user.id,
        models.AIConversation.status == "active",
    ))
    conv = (await db.execute(q)).scalar_one_or_none()
    if not conv:
        raise HTTPException(status_code=404, detail="对话不存在或已归档")

    accept_lang = _parse_accept_language(request.headers.get("Accept-Language"))
    agent = AIAgent(db, current_user, accept_lang=accept_lang)

    return EventSourceResponse(
        agent.process_message_stream(conversation_id, request_body.content),
        media_type="text/event-stream",
        headers={
            "X-Accel-Buffering": "no",
            "Cache-Control": "no-cache",
        },
    )


@router.delete("/conversations/{conversation_id}")
async def archive_conversation(
    conversation_id: str,
    current_user: models.User = Depends(_get_current_user),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    agent = AIAgent(db, current_user)
    success = await agent.archive_conversation(conversation_id)
    if not success:
        raise HTTPException(status_code=404, detail="对话不存在")
    return {"status": "archived"}
