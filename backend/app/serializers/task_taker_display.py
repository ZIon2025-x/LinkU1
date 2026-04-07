"""
Unified taker display info serializer for Task responses.
spec §4.6 (U2 scheme)

For team tasks (taker_expert_id non-null): returns team logo + team name
For individual tasks: returns user avatar + user name
For unclaimed tasks: returns None
"""
from typing import Optional, Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.models_expert import Expert


async def build_taker_display(
    task: "models.Task",
    db: AsyncSession,
) -> Optional[Dict[str, Any]]:
    """
    Build the unified taker_display info dict for a Task.

    Returns:
        - Team task: {type:'expert', entity_id, name, avatar}
        - Individual task: {type:'user', entity_id, name, avatar}
        - Unclaimed task: None
    """
    if task.taker_expert_id:
        expert = await db.get(Expert, task.taker_expert_id)
        if expert:
            return {
                "type": "expert",
                "entity_id": expert.id,
                "name": expert.name,
                "avatar": expert.avatar,
            }
        # Expert row missing — fall through to individual fallback (defensive)

    if task.taker_id:
        user = await db.get(models.User, task.taker_id)
        if user:
            return {
                "type": "user",
                "entity_id": user.id,
                "name": getattr(user, 'name', None),
                "avatar": getattr(user, 'avatar', None),
            }

    return None
