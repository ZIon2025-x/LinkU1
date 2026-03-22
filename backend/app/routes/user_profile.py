"""User profile API routes for four-dimension profiling system."""
from enum import Enum as PyEnum
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel, field_validator
from app.deps import get_db, get_current_user_secure_sync_csrf
from app.services import user_profile_service as svc
from app.services.demand_inference import infer_demand

router = APIRouter(prefix="/api/profile", tags=["用户画像"])


# --- Schemas with enum validation ---

class ProficiencyStr(str, PyEnum):
    beginner = "beginner"
    intermediate = "intermediate"
    expert = "expert"

class TaskModeStr(str, PyEnum):
    online = "online"
    offline = "offline"
    both = "both"

class DurationTypeStr(str, PyEnum):
    one_time = "one_time"
    long_term = "long_term"
    both = "both"

class RewardPreferenceStr(str, PyEnum):
    high_freq_low_amount = "high_freq_low_amount"
    low_freq_high_amount = "low_freq_high_amount"
    no_preference = "no_preference"

class CapabilityItem(BaseModel):
    category_id: int
    skill_name: str
    proficiency: ProficiencyStr = ProficiencyStr.beginner

class PreferenceUpdate(BaseModel):
    mode: TaskModeStr | None = None
    duration_type: DurationTypeStr | None = None
    reward_preference: RewardPreferenceStr | None = None
    preferred_time_slots: list[str] | None = None
    preferred_categories: list[int] | None = None
    preferred_helper_types: list[str] | None = None
    nearby_push_enabled: bool | None = None

class LocationUpdate(BaseModel):
    latitude: float
    longitude: float

    @field_validator('latitude')
    @classmethod
    def validate_lat(cls, v):
        if not -90 <= v <= 90:
            raise ValueError('Latitude must be between -90 and 90')
        return v

    @field_validator('longitude')
    @classmethod
    def validate_lon(cls, v):
        if not -180 <= v <= 180:
            raise ValueError('Longitude must be between -180 and 180')
        return v

class OnboardingSubmit(BaseModel):
    capabilities: list[CapabilityItem] = []
    mode: TaskModeStr | None = None
    preferred_categories: list[int] = []
    identity: str | None = None  # "pre_arrival" or "in_uk"
    city: str | None = None
    name: str | None = None
    interests: list[str] | None = None  # e.g. ["moving_home", "food_cooking", "gaming"]


# --- Capability endpoints ---

@router.get("/capabilities")
async def get_capabilities(current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)):
    caps = svc.get_capabilities(db, current_user.id)
    return [{
        "id": c.id,
        "category_id": c.category_id,
        "category_name_zh": c.category.name_zh if c.category else None,
        "category_name_en": c.category.name_en if c.category else None,
        "skill_name": c.skill_name,
        "proficiency": c.proficiency.value,
        "verification_source": c.verification_source.value,
        "verified_task_count": c.verified_task_count,
    } for c in caps]


@router.put("/capabilities")
async def update_capabilities(
    items: list[CapabilityItem],
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    caps = svc.upsert_capabilities(db, current_user.id, [item.model_dump() for item in items])
    db.commit()
    return {"message": "ok", "count": len(caps)}


@router.delete("/capabilities/{capability_id}")
async def delete_capability(
    capability_id: int,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    if not svc.delete_capability(db, current_user.id, capability_id):
        raise HTTPException(status_code=404, detail="Capability not found")
    db.commit()
    return {"message": "ok"}


# --- Preference endpoints ---

@router.get("/preferences")
async def get_preferences(current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)):
    pref = svc.get_preference(db, current_user.id)
    if not pref:
        return {"mode": "both", "duration_type": "both", "reward_preference": "no_preference",
                "preferred_time_slots": [], "preferred_categories": [], "preferred_helper_types": [],
                "nearby_push_enabled": False, "city": None}
    return {
        "mode": pref.mode.value,
        "duration_type": pref.duration_type.value,
        "reward_preference": pref.reward_preference.value,
        "preferred_time_slots": pref.preferred_time_slots or [],
        "preferred_categories": pref.preferred_categories or [],
        "preferred_helper_types": pref.preferred_helper_types or [],
        "nearby_push_enabled": pref.nearby_push_enabled or False,
        "city": pref.city,
    }


@router.put("/preferences")
async def update_preferences(
    data: PreferenceUpdate,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    pref = svc.upsert_preference(db, current_user.id, data.model_dump(exclude_none=True))
    db.commit()
    return {"message": "ok"}


# --- Read-only endpoints ---

@router.get("/reliability")
async def get_reliability(current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)):
    rel = svc.get_reliability(db, current_user.id)
    if not rel:
        return {"reliability_score": None, "total_tasks_taken": 0, "insufficient_data": True,
                "response_speed_avg": 0, "completion_rate": 0, "on_time_rate": 0,
                "complaint_rate": 0, "communication_score": 0, "repeat_rate": 0,
                "cancellation_rate": 0}
    return {
        "response_speed_avg": rel.response_speed_avg or 0,
        "completion_rate": rel.completion_rate or 0,
        "on_time_rate": rel.on_time_rate or 0,
        "complaint_rate": rel.complaint_rate or 0,
        "communication_score": rel.communication_score or 0,
        "repeat_rate": rel.repeat_rate or 0,
        "cancellation_rate": rel.cancellation_rate or 0,
        "reliability_score": rel.reliability_score,
        "total_tasks_taken": rel.total_tasks_taken or 0,
        "insufficient_data": (rel.total_tasks_taken or 0) < 3,
    }


@router.get("/demand")
async def get_demand(current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)):
    demand = svc.get_demand(db, current_user.id)
    if not demand:
        try:
            demand = infer_demand(db, current_user.id)
            db.commit()
        except (ValueError, Exception):
            # Inference failed, return defaults
            return {"user_stage": "new_arrival", "predicted_needs": [],
                    "recent_interests": {}, "last_inferred_at": None}
    try:
        stage_value = demand.user_stage.value if hasattr(demand.user_stage, 'value') else str(demand.user_stage)
    except (ValueError, AttributeError):
        stage_value = "new_arrival"
    return {
        "user_stage": stage_value,
        "predicted_needs": demand.predicted_needs or [],
        "recent_interests": demand.recent_interests or {},
        "last_inferred_at": demand.last_inferred_at.isoformat() if demand.last_inferred_at else None,
    }


@router.get("/summary")
async def get_summary(current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)):
    summary = svc.get_profile_summary(db, current_user.id)
    caps = [{
        "id": c.id, "category_id": c.category_id,
        "category_name_zh": c.category.name_zh if c.category else None,
        "category_name_en": c.category.name_en if c.category else None,
        "skill_name": c.skill_name,
        "proficiency": c.proficiency.value, "verification_source": c.verification_source.value,
        "verified_task_count": c.verified_task_count,
    } for c in summary["capabilities"]]

    pref = summary["preference"]
    pref_data = {"mode": "both", "duration_type": "both", "reward_preference": "no_preference",
                 "preferred_time_slots": [], "preferred_categories": [], "preferred_helper_types": [],
                 "nearby_push_enabled": False, "city": None} if not pref else {
        "mode": pref.mode.value, "duration_type": pref.duration_type.value,
        "reward_preference": pref.reward_preference.value,
        "preferred_time_slots": pref.preferred_time_slots or [],
        "preferred_categories": pref.preferred_categories or [],
        "preferred_helper_types": pref.preferred_helper_types or [],
        "nearby_push_enabled": pref.nearby_push_enabled or False,
        "city": pref.city,
    }

    rel = summary["reliability"]
    rel_data = {"reliability_score": None, "total_tasks_taken": 0, "insufficient_data": True,
                "response_speed_avg": 0, "completion_rate": 0, "on_time_rate": 0,
                "complaint_rate": 0, "communication_score": 0, "repeat_rate": 0,
                "cancellation_rate": 0} if not rel else {
        "response_speed_avg": rel.response_speed_avg or 0,
        "completion_rate": rel.completion_rate or 0,
        "on_time_rate": rel.on_time_rate or 0,
        "complaint_rate": rel.complaint_rate or 0,
        "communication_score": rel.communication_score or 0,
        "repeat_rate": rel.repeat_rate or 0,
        "cancellation_rate": rel.cancellation_rate or 0,
        "reliability_score": rel.reliability_score,
        "total_tasks_taken": rel.total_tasks_taken or 0,
        "insufficient_data": (rel.total_tasks_taken or 0) < 3,
    }

    demand = summary["demand"]
    if not demand:
        demand_data = {"user_stage": "new_arrival", "predicted_needs": []}
    else:
        try:
            stage_val = demand.user_stage.value if hasattr(demand.user_stage, 'value') else str(demand.user_stage)
        except (ValueError, AttributeError):
            stage_val = "new_arrival"
        demand_data = {"user_stage": stage_val, "predicted_needs": demand.predicted_needs or []}

    return {
        "capabilities": caps,
        "preference": pref_data,
        "reliability": rel_data,
        "demand": demand_data,
    }


# --- Location ---

@router.post("/location")
async def upload_location(
    data: LocationUpdate,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    from app.services.nearby_task_service import upsert_user_location, process_nearby_push
    upsert_user_location(db, current_user.id, data.latitude, data.longitude)
    db.commit()
    # Push runs in same request but failure won't affect response
    try:
        process_nearby_push(db, current_user.id, data.latitude, data.longitude)
        db.commit()
    except Exception:
        db.rollback()
    return {"message": "ok"}


# --- Onboarding ---

@router.post("/onboarding")
async def submit_onboarding(
    data: OnboardingSubmit,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    svc.submit_onboarding(db, current_user.id, data.model_dump())

    # Save identity to UserDemand
    if data.identity:
        from app.models import UserDemand
        from app.services.demand_inference import determine_user_stages
        demand = db.query(UserDemand).filter(UserDemand.user_id == current_user.id).first()
        if not demand:
            demand = UserDemand(user_id=current_user.id)
            db.add(demand)
        demand.identity = data.identity
        demand.user_stage = determine_user_stages(data.identity)
        db.flush()

    # Save city to preferences
    if data.city:
        from app.models import UserProfilePreference
        pref = db.query(UserProfilePreference).filter(
            UserProfilePreference.user_id == current_user.id
        ).first()
        if pref:
            pref.city = data.city
        else:
            pref = UserProfilePreference(user_id=current_user.id, city=data.city)
            db.add(pref)

    # Save interests to UserDemand.recent_interests
    if data.interests:
        from app.models import UserDemand
        demand = db.query(UserDemand).filter(UserDemand.user_id == current_user.id).first()
        if not demand:
            demand = UserDemand(user_id=current_user.id)
            db.add(demand)
        existing = demand.recent_interests or {}
        for interest_key in data.interests:
            existing[interest_key] = {
                "confidence": 0.8,
                "urgency": "medium",
                "source": "onboarding",
            }
        demand.recent_interests = existing
        db.flush()

    # Update name if provided
    if data.name and data.name.strip():
        current_user.name = data.name.strip()

    # Mark onboarding complete
    current_user.onboarding_completed = True

    # Run demand inference
    infer_demand(db, current_user.id)
    db.commit()
    return {"message": "ok"}
