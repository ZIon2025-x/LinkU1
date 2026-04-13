"""团队活动发布端点。spec §2.2 (E1)

POST /api/experts/{expert_id}/activities — create an activity owned by a team.
The team owner's user_id is mirrored into the legacy ``activities.expert_id``
column (Y-scheme alignment); ``owner_type`` is the source of truth.
"""
from datetime import datetime
from typing import Optional, List, Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.deps import get_async_db_dependency
from app.async_routers import get_current_user_secure_async_csrf
from app.expert_routes import _get_member_or_403
from app.models import TaskExpertService
from app.models_expert import Expert, ExpertMember

router = APIRouter(prefix="/api/experts", tags=["expert-activities"])


class TeamActivityCreate(BaseModel):
    """Body for creating a team-owned activity.

    An ``Activity`` is a scheduled instance of a ``TaskExpertService``;
    ``expert_service_id`` is therefore REQUIRED so that downstream
    apply / payment flows (which strictly require the link) keep working.
    """
    expert_service_id: int  # REQUIRED — the team service this activity wraps
    title: str
    description: str  # required (model column is non-nullable)
    location: str
    task_type: str
    deadline: datetime  # required, ISO format from JSON

    # Pricing (mostly inherited from service if not provided, but allow override)
    original_price_per_participant: Optional[float] = Field(None, ge=0)
    discount_percentage: Optional[float] = Field(None, ge=0, le=100)
    discounted_price_per_participant: Optional[float] = Field(None, ge=0)
    currency: str = 'GBP'

    # Reward
    reward_type: str = 'cash'  # 'cash' | 'points' | 'both'
    points_reward: Optional[int] = None

    # Participants
    max_participants: int
    min_participants: int = 1

    # Activity behavior
    completion_rule: str = 'all'  # 'all' | 'min'
    reward_distribution: str = 'equal'  # 'equal' | 'custom'
    activity_type: str = 'standard'  # team v1: only 'standard'
    is_public: bool = True
    visibility: str = 'public'  # 'public' | 'private'
    activity_end_date: Optional[datetime] = None

    # Reward applicants (for activities that pay applicants)
    reward_applicants: bool = False
    applicant_reward_amount: Optional[float] = None
    applicant_points_reward: Optional[int] = None

    # Images
    images: Optional[List[str]] = None

    # Location coordinates + radius
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    service_radius_km: Optional[Literal[0, 5, 10, 25, 50]] = None


@router.post("/{expert_id}/activities")
async def create_team_activity(
    expert_id: str,
    body: TeamActivityCreate,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """Create a team-owned activity.

    Required role: owner or admin of the team.
    Gates: team must have completed Stripe onboarding; currency must be GBP;
    referenced service must exist, belong to this team, and be active.
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
        raise HTTPException(status_code=409, detail={
            "error_code": "expert_currency_unsupported",
            "message": "Team activities only support GBP currently",
        })

    # Reject lottery / first_come for v1
    if body.activity_type != 'standard':
        raise HTTPException(status_code=422, detail={
            "error_code": "activity_type_unsupported",
            "message": "Team activities only support 'standard' type currently",
        })

    # Load and validate the service.
    service_result = await db.execute(
        select(TaskExpertService).where(TaskExpertService.id == body.expert_service_id)
    )
    service = service_result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail={
            "error_code": "service_not_found",
            "message": "Service not found",
        })

    # Service must belong to this team (polymorphic owner columns).
    if service.owner_type != 'expert' or service.owner_id != expert_id:
        raise HTTPException(status_code=403, detail={
            "error_code": "service_not_owned_by_team",
            "message": "This service does not belong to your team",
        })

    # Service must be active.
    if service.status != 'active':
        raise HTTPException(status_code=400, detail={
            "error_code": "service_inactive",
            "message": "Cannot create activity from inactive service",
        })

    # ---- 套餐服务价格校验 ----
    is_package = service.package_type in ("multi", "bundle")
    if is_package:
        pkg_price = float(service.package_price) if service.package_price else None
        if not pkg_price or pkg_price <= 0:
            raise HTTPException(status_code=422, detail={
                "error_code": "package_price_missing",
                "message": "套餐服务必须设置 package_price 才能发布活动",
            })

        # 原价自动取 package_price（前端传了也覆盖，防止误填单次价）
        body.original_price_per_participant = pkg_price

        # 折扣价不能低于原价的 50%
        if body.discounted_price_per_participant is not None:
            if body.discounted_price_per_participant < pkg_price * 0.5:
                raise HTTPException(status_code=422, detail={
                    "error_code": "discount_too_deep",
                    "message": f"折扣价不能低于套餐原价的 50%（最低 £{pkg_price * 0.5:.2f}）",
                })
            if body.discounted_price_per_participant >= pkg_price:
                raise HTTPException(status_code=422, detail={
                    "error_code": "discount_not_lower",
                    "message": "折扣价必须低于套餐原价",
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
        expert_service_id=service.id,
        title=body.title,
        description=body.description,
        location=body.location,
        task_type=body.task_type,
        reward_type=body.reward_type,
        original_price_per_participant=(
            body.original_price_per_participant
            if body.original_price_per_participant is not None
            else float(service.base_price)
        ),
        discount_percentage=body.discount_percentage,
        discounted_price_per_participant=body.discounted_price_per_participant,
        currency=body.currency,
        points_reward=body.points_reward,
        max_participants=body.max_participants,
        min_participants=body.min_participants,
        completion_rule=body.completion_rule,
        reward_distribution=body.reward_distribution,
        activity_type=body.activity_type,
        visibility=body.visibility,
        activity_end_date=body.activity_end_date,
        deadline=body.deadline,
        images=body.images if body.images else service.images,
        has_time_slots=service.has_time_slots,  # inherited from service
        reward_applicants=body.reward_applicants,
        applicant_reward_amount=body.applicant_reward_amount,
        applicant_points_reward=body.applicant_points_reward,
        # Legacy field: mirror owner's user_id so existing readers keep working.
        expert_id=owner.user_id,
        # Geo-location and service radius
        latitude=body.latitude,
        longitude=body.longitude,
        service_radius_km=body.service_radius_km,
        # New polymorphic fields (source of truth).
        owner_type='expert',
        owner_id=expert.id,
        status='open',
        is_public=body.is_public,
    )
    db.add(activity)
    await db.commit()
    await db.refresh(activity)

    return {
        "id": activity.id,
        "owner_type": "expert",
        "owner_id": expert.id,
    }
