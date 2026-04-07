"""
Resolve (taker_id, taker_expert_id) from expert_service or activity.
spec §4.2 §4.3a
"""
from typing import Optional, Tuple
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session
from fastapi import HTTPException

from app import models
from app.models_expert import Expert, ExpertMember


async def _resolve_team_taker(
    db: AsyncSession,
    expert_id: str,
    currency: Optional[str],
    unavailable_message: str,
    currency_message: str,
) -> Tuple[str, str]:
    """
    Internal helper: load expert, validate stripe + currency + owner.
    Returns (team_owner.user_id, expert.id).

    Raises:
        HTTPException 404 if expert team not found
        HTTPException 409 if stripe not ready
        HTTPException 409 if currency not GBP
        HTTPException 500 if no active owner
    """
    expert = await db.get(Expert, expert_id)
    if not expert:
        raise HTTPException(status_code=404, detail="Expert team not found")
    if not expert.stripe_onboarding_complete:
        raise HTTPException(status_code=409, detail={
            "error_code": "expert_stripe_not_ready",
            "message": unavailable_message,
        })
    if (currency or 'GBP').upper() != 'GBP':
        raise HTTPException(status_code=409, detail={
            "error_code": "expert_currency_unsupported",
            "message": currency_message,
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


async def resolve_task_taker_from_service(
    db: AsyncSession,
    service: "models.TaskExpertService",
) -> Tuple[str, Optional[str]]:
    """
    Resolve (taker_id, taker_expert_id) from a TaskExpertService row.
    spec §4.2

    Returns:
      - owner_type='expert': (team_owner.user_id, expert.id)
      - owner_type='user':   (service.owner_id, None)
    """
    if service.owner_type == 'expert':
        return await _resolve_team_taker(
            db,
            expert_id=service.owner_id,
            currency=service.currency,
            unavailable_message="This service is temporarily unavailable",
            currency_message="Team services only support GBP currently",
        )
    elif service.owner_type == 'user':
        return (service.owner_id, None)
    else:
        raise HTTPException(status_code=500, detail={
            "error_code": "unknown_owner_type",
            "message": f"Unknown service owner_type: {service.owner_type}",
        })


async def resolve_task_taker_from_activity(
    db: AsyncSession,
    activity: "models.Activity",
) -> Tuple[str, Optional[str]]:
    """
    Resolve (taker_id, taker_expert_id) from an Activity row.
    spec §4.3a

    Returns:
      - owner_type='expert': (team_owner.user_id, expert.id)
      - owner_type='user':   (activity.expert_id, None)  # legacy field; see note
    """
    if activity.owner_type == 'expert':
        return await _resolve_team_taker(
            db,
            expert_id=activity.owner_id,
            currency=activity.currency,
            unavailable_message="Team is temporarily unable to accept sign-ups",
            currency_message="Team activities only support GBP currently",
        )
    elif activity.owner_type == 'user':
        # Legacy: pre-polymorphism activities store the creator's user_id in expert_id,
        # NOT in owner_id. Don't "fix" this to activity.owner_id — it would break backward compat.
        return (activity.expert_id, None)
    else:
        raise HTTPException(status_code=500, detail={
            "error_code": "unknown_owner_type",
            "message": f"Unknown activity owner_type: {activity.owner_type}",
        })


def resolve_task_taker_from_activity_sync(
    db: Session,
    activity: "models.Activity",
) -> Tuple[str, Optional[str]]:
    """Sync version of resolve_task_taker_from_activity for use in sync endpoints.
    spec §4.3a

    Mirrors the async version exactly:
      - owner_type='expert': (team_owner.user_id, expert.id)
      - owner_type='user':   (activity.expert_id, None)  # legacy mirror
    Raises HTTPException for the same conditions as the async version.
    """
    if activity.owner_type == 'expert':
        expert = db.query(Expert).filter(Expert.id == activity.owner_id).first()
        if not expert:
            raise HTTPException(status_code=404, detail="Expert team not found")
        if not expert.stripe_onboarding_complete:
            raise HTTPException(status_code=409, detail={
                "error_code": "expert_stripe_not_ready",
                "message": "Team is temporarily unable to accept sign-ups",
            })
        if (activity.currency or 'GBP').upper() != 'GBP':
            raise HTTPException(status_code=409, detail={
                "error_code": "expert_currency_unsupported",
                "message": "Team activities only support GBP currently",
            })
        owner = (
            db.query(ExpertMember)
            .filter(
                ExpertMember.expert_id == expert.id,
                ExpertMember.role == 'owner',
                ExpertMember.status == 'active',
            )
            .first()
        )
        if not owner:
            raise HTTPException(status_code=500, detail={
                "error_code": "expert_owner_missing",
                "message": "Team has no active owner",
            })
        return (owner.user_id, expert.id)

    elif activity.owner_type == 'user':
        # Legacy: see note on the async version above.
        return (activity.expert_id, None)

    else:
        raise HTTPException(status_code=500, detail={
            "error_code": "unknown_owner_type",
            "message": f"Unknown activity owner_type: {activity.owner_type}",
        })
