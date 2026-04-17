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

    - standard: requires expert_service_id (existing flow)
    - lottery / first_come: expert_service_id is optional
    """
    expert_service_id: Optional[int] = None  # required for standard, optional for lottery/first_come
    title: str
    description: str
    location: str
    task_type: str
    deadline: datetime

    # Pricing (inherited from service for standard, manual for independent)
    original_price_per_participant: Optional[float] = Field(None, ge=0)
    discount_percentage: Optional[float] = Field(None, ge=0, le=100)
    discounted_price_per_participant: Optional[float] = Field(None, ge=0)
    currency: str = 'GBP'

    # Reward
    reward_type: str = 'cash'  # 'cash' | 'points' | 'both'
    points_reward: Optional[int] = None

    # Participants
    max_participants: Optional[int] = None  # auto-derived for lottery/first_come
    min_participants: int = 1

    # Activity behavior
    completion_rule: str = 'all'
    reward_distribution: str = 'equal'
    activity_type: str = 'standard'  # 'standard' | 'lottery' | 'first_come'
    is_public: bool = True
    visibility: str = 'public'
    activity_end_date: Optional[datetime] = None

    # Reward applicants
    reward_applicants: bool = False
    applicant_reward_amount: Optional[float] = None
    applicant_points_reward: Optional[int] = None

    # Images
    images: Optional[List[str]] = None

    # Location coordinates + radius
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    service_radius_km: Optional[Literal[0, 5, 10, 25, 50]] = None

    # ── Lottery / First-come fields ──
    prize_type: Optional[str] = None        # 'physical' | 'in_person' (expert-only)
    prize_description: Optional[str] = None
    prize_description_en: Optional[str] = None
    prize_count: Optional[int] = Field(None, gt=0)
    draw_mode: Optional[str] = None         # 'auto' | 'manual' (lottery only)
    draw_trigger: Optional[str] = None      # 'by_time' | 'by_count' | 'both' (auto only)
    draw_at: Optional[datetime] = None      # auto + by_time/both
    draw_participant_count: Optional[int] = Field(None, gt=0)  # auto + by_count/both


def _validate_lottery_first_come_fields(body: TeamActivityCreate):
    """Validate fields specific to lottery / first_come activity types.

    Raises HTTPException on invalid input.
    Called for ALL activity types — standard just checks expert_service_id.
    """
    if body.activity_type == 'standard':
        if body.expert_service_id is None:
            raise HTTPException(status_code=422, detail={
                "error_code": "service_required_for_standard",
                "message": "Standard activities require expert_service_id",
            })
        return

    if body.activity_type not in ('lottery', 'first_come'):
        raise HTTPException(status_code=422, detail={
            "error_code": "activity_type_invalid",
            "message": "activity_type must be 'standard', 'lottery', or 'first_come'",
        })

    if not body.prize_type:
        raise HTTPException(status_code=422, detail={
            "error_code": "prize_type_required",
            "message": "prize_type is required for lottery/first_come activities",
        })
    if body.prize_type not in ('physical', 'in_person'):
        raise HTTPException(status_code=422, detail={
            "error_code": "prize_type_invalid",
            "message": "Expert activities only support 'physical' or 'in_person' prize types",
        })
    if not body.prize_count or body.prize_count < 1:
        raise HTTPException(status_code=422, detail={
            "error_code": "prize_count_required",
            "message": "prize_count is required and must be > 0",
        })

    if body.activity_type == 'lottery':
        if body.draw_mode not in ('auto', 'manual'):
            raise HTTPException(status_code=422, detail={
                "error_code": "draw_mode_required",
                "message": "Lottery activities require draw_mode ('auto' or 'manual')",
            })
        if body.draw_mode == 'auto':
            if body.draw_trigger not in ('by_time', 'by_count', 'both'):
                raise HTTPException(status_code=422, detail={
                    "error_code": "draw_trigger_required",
                    "message": "Auto lottery requires draw_trigger ('by_time', 'by_count', or 'both')",
                })
            if body.draw_trigger in ('by_time', 'both') and not body.draw_at:
                raise HTTPException(status_code=422, detail={
                    "error_code": "draw_at_required",
                    "message": "draw_at is required for by_time/both trigger",
                })
            if body.draw_trigger in ('by_count', 'both'):
                if not body.draw_participant_count or body.draw_participant_count <= body.prize_count:
                    raise HTTPException(status_code=422, detail={
                        "error_code": "draw_participant_count_required",
                        "message": "draw_participant_count is required and must be > prize_count",
                    })


def _derive_max_participants(body: TeamActivityCreate) -> int:
    """Auto-derive max_participants based on activity type and draw trigger."""
    if body.activity_type == 'first_come':
        return body.prize_count

    if body.activity_type == 'lottery':
        if body.draw_trigger in ('by_count', 'both'):
            return body.draw_participant_count
        return body.max_participants or (body.prize_count * 10)

    return body.max_participants


@router.post("/{expert_id}/activities")
async def create_team_activity(
    expert_id: str,
    body: TeamActivityCreate,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """Create a team-owned activity.

    Supports three activity types:
    - standard: requires expert_service_id, full service validation
    - lottery: optional service, prize fields required, draw config required
    - first_come: optional service, prize fields required
    """
    await _get_member_or_403(
        db, expert_id, current_user.id, required_roles=['owner', 'admin']
    )

    expert = await db.get(Expert, expert_id)
    if not expert:
        raise HTTPException(status_code=404, detail="Expert team not found")

    if (body.currency or 'GBP').upper() != 'GBP':
        raise HTTPException(status_code=409, detail={
            "error_code": "expert_currency_unsupported",
            "message": "Team activities only support GBP currently",
        })

    _validate_lottery_first_come_fields(body)

    max_participants = _derive_max_participants(body)

    service = None
    if body.expert_service_id is not None:
        service_result = await db.execute(
            select(TaskExpertService).where(TaskExpertService.id == body.expert_service_id)
        )
        service = service_result.scalar_one_or_none()
        if not service:
            raise HTTPException(status_code=404, detail={
                "error_code": "service_not_found",
                "message": "Service not found",
            })
        if service.owner_type != 'expert' or service.owner_id != expert_id:
            raise HTTPException(status_code=403, detail={
                "error_code": "service_not_owned_by_team",
                "message": "This service does not belong to your team",
            })
        if service.status != 'active':
            raise HTTPException(status_code=400, detail={
                "error_code": "service_inactive",
                "message": "Cannot create activity from inactive service",
            })

    is_paid = (body.original_price_per_participant or 0) > 0
    needs_stripe = (body.activity_type == 'standard') or is_paid
    if needs_stripe and not expert.stripe_onboarding_complete:
        raise HTTPException(status_code=409, detail={
            "error_code": "expert_stripe_not_ready",
            "message": "Team must complete Stripe onboarding before publishing paid activities",
        })

    if service and body.activity_type == 'standard':
        is_package = service.package_type in ("multi", "bundle")
        if is_package:
            pkg_price = float(service.package_price) if service.package_price else None
            if not pkg_price or pkg_price <= 0:
                raise HTTPException(status_code=422, detail={
                    "error_code": "package_price_missing",
                    "message": "套餐服务必须设置 package_price 才能发布活动",
                })
            body.original_price_per_participant = pkg_price
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
        expert_service_id=service.id if service else None,
        title=body.title,
        description=body.description,
        location=body.location,
        task_type=body.task_type,
        reward_type=body.reward_type,
        original_price_per_participant=(
            body.original_price_per_participant
            if body.original_price_per_participant is not None
            else (float(service.base_price) if service else None)
        ),
        discount_percentage=body.discount_percentage,
        discounted_price_per_participant=body.discounted_price_per_participant,
        currency=body.currency,
        points_reward=body.points_reward,
        max_participants=max_participants,
        min_participants=body.min_participants,
        completion_rule=body.completion_rule,
        reward_distribution=body.reward_distribution,
        activity_type=body.activity_type,
        visibility=body.visibility,
        activity_end_date=body.activity_end_date,
        deadline=body.deadline,
        images=body.images if body.images else (service.images if service else None),
        has_time_slots=service.has_time_slots if service else False,
        reward_applicants=body.reward_applicants,
        applicant_reward_amount=body.applicant_reward_amount,
        applicant_points_reward=body.applicant_points_reward,
        expert_id=owner.user_id,
        latitude=body.latitude,
        longitude=body.longitude,
        service_radius_km=body.service_radius_km,
        owner_type='expert',
        owner_id=expert.id,
        status='open',
        is_public=body.is_public,
        prize_type=body.prize_type,
        prize_description=body.prize_description,
        prize_description_en=body.prize_description_en,
        prize_count=body.prize_count,
        draw_mode=body.draw_mode,
        draw_trigger=body.draw_trigger,
        draw_at=body.draw_at if body.activity_type == 'lottery' else None,
        draw_participant_count=body.draw_participant_count,
    )
    db.add(activity)
    await db.commit()
    await db.refresh(activity)

    return {
        "id": activity.id,
        "owner_type": "expert",
        "owner_id": expert.id,
    }


def _validate_draw_request(activity: models.Activity):
    """Validate that an activity can be drawn."""
    if activity.activity_type != "lottery":
        raise HTTPException(status_code=400, detail={
            "error_code": "not_lottery",
            "message": "Only lottery activities can be drawn",
        })
    if activity.is_drawn:
        raise HTTPException(status_code=400, detail={
            "error_code": "already_drawn",
            "message": "This activity has already been drawn",
        })


@router.post("/{expert_id}/activities/{activity_id}/draw")
async def expert_manual_draw(
    expert_id: str,
    activity_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """Manually trigger lottery draw for an expert team activity."""
    await _get_member_or_403(
        db, expert_id, current_user.id, required_roles=['owner', 'admin']
    )

    result = await db.execute(
        select(models.Activity).where(
            models.Activity.id == activity_id,
            models.Activity.owner_type == 'expert',
            models.Activity.owner_id == expert_id,
        )
    )
    activity = result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="Activity not found")

    _validate_draw_request(activity)

    from app.draw_logic import perform_draw_async
    winners = await perform_draw_async(db, activity)
    return {
        "success": True,
        "winner_count": len(winners),
        "winners": winners,
    }
