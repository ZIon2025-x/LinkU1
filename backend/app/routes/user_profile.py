"""User profile API routes for four-dimension profiling system."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app.deps import get_db, get_current_user_secure_sync_csrf
from app.services import user_profile_service as svc
from app.services.demand_inference import infer_demand

router = APIRouter(prefix="/api/profile", tags=["用户画像"])


# --- Schemas ---

class CapabilityItem(BaseModel):
    category_id: int
    skill_name: str
    proficiency: str = "beginner"

class PreferenceUpdate(BaseModel):
    mode: str | None = None
    duration_type: str | None = None
    reward_preference: str | None = None
    preferred_time_slots: list[str] | None = None
    preferred_categories: list[int] | None = None
    preferred_helper_types: list[str] | None = None

class OnboardingSubmit(BaseModel):
    capabilities: list[CapabilityItem] = []
    mode: str | None = None
    preferred_categories: list[int] = []


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
                "preferred_time_slots": [], "preferred_categories": [], "preferred_helper_types": []}
    return {
        "mode": pref.mode.value,
        "duration_type": pref.duration_type.value,
        "reward_preference": pref.reward_preference.value,
        "preferred_time_slots": pref.preferred_time_slots or [],
        "preferred_categories": pref.preferred_categories or [],
        "preferred_helper_types": pref.preferred_helper_types or [],
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
    return {
        "user_stage": demand.user_stage.value,
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
                 "preferred_time_slots": [], "preferred_categories": [], "preferred_helper_types": []} if not pref else {
        "mode": pref.mode.value, "duration_type": pref.duration_type.value,
        "reward_preference": pref.reward_preference.value,
        "preferred_time_slots": pref.preferred_time_slots or [],
        "preferred_categories": pref.preferred_categories or [],
        "preferred_helper_types": pref.preferred_helper_types or [],
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
    demand_data = {"user_stage": "new_arrival", "predicted_needs": []} if not demand else {
        "user_stage": demand.user_stage.value,
        "predicted_needs": demand.predicted_needs or [],
    }

    return {
        "capabilities": caps,
        "preference": pref_data,
        "reliability": rel_data,
        "demand": demand_data,
    }


# --- Onboarding ---

@router.post("/onboarding")
async def submit_onboarding(
    data: OnboardingSubmit,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    result = svc.submit_onboarding(db, current_user.id, data.model_dump())
    infer_demand(db, current_user.id)
    db.commit()
    return {"message": "ok"}
