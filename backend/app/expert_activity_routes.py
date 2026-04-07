"""团队活动发布端点。spec §2.2 (E1)

POST /api/experts/{expert_id}/activities — create an activity owned by a team.
The team owner's user_id is mirrored into the legacy ``activities.expert_id``
column (Y-scheme alignment); ``owner_type`` is the source of truth.
"""
from typing import Optional, List

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.deps import get_async_db_dependency
from app.async_routers import get_current_user_secure_async_csrf
from app.expert_routes import _get_member_or_403
from app.models_expert import Expert, ExpertMember

router = APIRouter(prefix="/api/experts", tags=["expert-activities"])


class TeamActivityCreate(BaseModel):
    title: str
    description: Optional[str] = None
    location: str
    task_type: str
    reward_type: str = 'cash'
    original_price_per_participant: float
    discount_percentage: float = 0
    discounted_price_per_participant: Optional[float] = None
    currency: str = 'GBP'
    points_reward: int = 0
    max_participants: int
    min_participants: int = 1
    deadline: str
    activity_end_date: Optional[str] = None
    images: Optional[List] = None


@router.post("/{expert_id}/activities")
async def create_team_activity(
    expert_id: str,
    body: TeamActivityCreate,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """Create a team-owned activity.

    Required role: owner or admin of the team.
    Gates: team must have completed Stripe onboarding; currency must be GBP.
    """
    # Role check first (403 before 404 is fine here — the member lookup will
    # also 403 if the team does not exist because no member row matches).
    await _get_member_or_403(
        db, expert_id, current_user.id, required_roles=['owner', 'admin']
    )

    expert = await db.get(Expert, expert_id)
    if not expert:
        raise HTTPException(status_code=404, detail="Expert team not found")

    if not expert.stripe_onboarding_complete:
        raise HTTPException(status_code=409, detail={
            "error_code": "expert_stripe_not_ready",
            "message": "Team must complete Stripe onboarding before publishing activities",
        })

    if (body.currency or 'GBP').upper() != 'GBP':
        raise HTTPException(status_code=422, detail={
            "error_code": "expert_currency_unsupported",
            "message": "Team activities only support GBP currently",
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

    activity = models.Activity(
        title=body.title,
        description=body.description or '',
        location=body.location,
        task_type=body.task_type,
        reward_type=body.reward_type,
        original_price_per_participant=body.original_price_per_participant,
        discount_percentage=body.discount_percentage,
        discounted_price_per_participant=body.discounted_price_per_participant,
        currency=body.currency,
        points_reward=body.points_reward,
        max_participants=body.max_participants,
        min_participants=body.min_participants,
        deadline=body.deadline,
        activity_end_date=body.activity_end_date,
        images=body.images,
        # Legacy field: mirror owner's user_id so existing readers keep working.
        expert_id=owner.user_id,
        # New polymorphic fields (source of truth).
        owner_type='expert',
        owner_id=expert.id,
        status='open',
        is_public=True,
    )
    db.add(activity)
    await db.commit()
    await db.refresh(activity)

    return {
        "id": activity.id,
        "owner_type": "expert",
        "owner_id": expert.id,
    }
