"""
Admin: AI System Prompt 管理路由

后端 system prompt 模板支持从 DB 动态加载（AI_SYSTEM_PROMPT_SOURCE=db），
此路由提供 admin 后台的查看、新建版本与激活历史版本能力。
保存即新建一条 active 记录，旧版本自动 archive 但保留在表里以便回滚。
"""

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import desc
from sqlalchemy.orm import Session

from app import models
from app.deps import get_sync_db
from app.rate_limiting import rate_limit
from app.separate_auth_deps import get_current_admin
from app.services.ai_agent import invalidate_prompt_cache, _DEFAULT_SYSTEM_PROMPT
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin/ai", tags=["Admin-AI Prompt"])


class PromptOut(BaseModel):
    id: int
    name: str
    content: str
    is_active: bool
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


class PromptSaveRequest(BaseModel):
    name: str = Field(default="default", max_length=100)
    content: str = Field(..., min_length=10, max_length=20000)


def _serialize(p: models.AISystemPrompt) -> dict:
    return {
        "id": p.id,
        "name": p.name,
        "content": p.content,
        "is_active": bool(p.is_active),
        "created_at": p.created_at.isoformat() if p.created_at else None,
        "updated_at": p.updated_at.isoformat() if p.updated_at else None,
    }


@router.get("/system-prompts")
@rate_limit("admin_operation")
def list_prompts(
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_sync_db),
):
    rows = (
        db.query(models.AISystemPrompt)
        .order_by(desc(models.AISystemPrompt.is_active), desc(models.AISystemPrompt.updated_at))
        .limit(50)
        .all()
    )
    return {"prompts": [_serialize(r) for r in rows]}


@router.get("/system-prompts/active")
@rate_limit("admin_operation")
def get_active_prompt(
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_sync_db),
):
    row = (
        db.query(models.AISystemPrompt)
        .filter(models.AISystemPrompt.is_active == True)
        .order_by(desc(models.AISystemPrompt.updated_at))
        .first()
    )
    return {
        "active": _serialize(row) if row else None,
        "default_template": _DEFAULT_SYSTEM_PROMPT,
    }


@router.post("/system-prompts")
@rate_limit("admin_operation")
def save_prompt(
    payload: PromptSaveRequest,
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_sync_db),
):
    db.query(models.AISystemPrompt).filter(
        models.AISystemPrompt.is_active == True
    ).update({"is_active": False, "updated_at": get_utc_time()}, synchronize_session=False)

    new_row = models.AISystemPrompt(
        name=payload.name,
        content=payload.content,
        is_active=True,
    )
    db.add(new_row)
    db.commit()
    db.refresh(new_row)

    invalidate_prompt_cache()
    logger.info("AI system prompt saved by admin %s, new id=%s", current_admin.id, new_row.id)
    return _serialize(new_row)


@router.post("/system-prompts/{prompt_id}/activate")
@rate_limit("admin_operation")
def activate_prompt(
    prompt_id: int,
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_sync_db),
):
    target = db.query(models.AISystemPrompt).filter(
        models.AISystemPrompt.id == prompt_id
    ).first()
    if not target:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="prompt not found")

    db.query(models.AISystemPrompt).filter(
        models.AISystemPrompt.is_active == True,
        models.AISystemPrompt.id != prompt_id,
    ).update({"is_active": False, "updated_at": get_utc_time()}, synchronize_session=False)

    target.is_active = True
    target.updated_at = get_utc_time()
    db.commit()
    db.refresh(target)

    invalidate_prompt_cache()
    logger.info("AI system prompt %s activated by admin %s", prompt_id, current_admin.id)
    return _serialize(target)
