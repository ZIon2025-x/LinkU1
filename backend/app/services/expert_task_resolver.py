"""
Resolve (taker_id, taker_expert_id) from expert_service or activity.
spec §4.2 §4.3a
"""
from typing import Optional, Tuple
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException

from app import models
from app.models_expert import Expert, ExpertMember


async def resolve_task_taker_from_service(
    db: AsyncSession,
    service: "models.TaskExpertService",
) -> Tuple[str, Optional[str]]:
    """
    返回 (taker_id, taker_expert_id):
      - owner_type='expert': (team_owner.user_id, expert.id)
      - owner_type='user':   (service.owner_id, None)
    """
    if service.owner_type == 'expert':
        expert = await db.get(Expert, service.owner_id)
        if not expert:
            raise HTTPException(status_code=404, detail="Expert team not found")
        if not expert.stripe_onboarding_complete:
            raise HTTPException(status_code=409, detail={
                "error_code": "expert_stripe_not_ready",
                "message": "This service is temporarily unavailable",
            })
        if (service.currency or 'GBP').upper() != 'GBP':
            raise HTTPException(status_code=409, detail={
                "error_code": "expert_currency_unsupported",
                "message": "Team services only support GBP currently",
            })

        result = await db.execute(
            select(ExpertMember).where(
                ExpertMember.expert_id == expert.id,
                ExpertMember.role == 'owner',
                ExpertMember.status == 'active',
            ).limit(1)
        )
        owner = result.scalar_one_or_none()
        if not owner:
            raise HTTPException(status_code=500, detail={
                "error_code": "expert_owner_missing",
                "message": "Team has no active owner",
            })
        return (owner.user_id, expert.id)

    elif service.owner_type == 'user':
        return (service.owner_id, None)

    else:
        raise HTTPException(
            status_code=500,
            detail=f"Unknown service owner_type: {service.owner_type}"
        )
