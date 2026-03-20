"""User profile service: CRUD for all four dimensions."""
from datetime import datetime, timezone
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func
from app.models import (
    UserCapability, UserProfilePreference, UserReliability, UserDemand,
    ProficiencyLevel, VerificationSource, TaskMode, DurationType,
    RewardPreference, UserStage
)


# --- Capability ---

def get_capabilities(db: Session, user_id: str) -> list[UserCapability]:
    return db.query(UserCapability).filter(
        UserCapability.user_id == user_id
    ).options(joinedload(UserCapability.category)).all()


def upsert_capabilities(db: Session, user_id: str, capabilities: list[dict]) -> list[UserCapability]:
    """Batch upsert capabilities. Each dict: {category_id, skill_name, proficiency?}"""
    results = []
    for cap_data in capabilities:
        existing = db.query(UserCapability).filter(
            UserCapability.user_id == user_id,
            UserCapability.skill_name == cap_data["skill_name"]
        ).first()
        if existing:
            existing.category_id = cap_data["category_id"]
            if "proficiency" in cap_data:
                existing.proficiency = cap_data["proficiency"]
            results.append(existing)
        else:
            cap = UserCapability(
                user_id=user_id,
                category_id=cap_data["category_id"],
                skill_name=cap_data["skill_name"],
                proficiency=cap_data.get("proficiency", ProficiencyLevel.beginner),
                verification_source=VerificationSource.self_declared,
            )
            db.add(cap)
            results.append(cap)
    db.flush()
    return results


def delete_capability(db: Session, user_id: str, capability_id: int) -> bool:
    cap = db.query(UserCapability).filter(
        UserCapability.id == capability_id,
        UserCapability.user_id == user_id
    ).first()
    if not cap:
        return False
    db.delete(cap)
    return True


# --- Preference ---

def get_preference(db: Session, user_id: str) -> UserProfilePreference | None:
    return db.query(UserProfilePreference).filter(
        UserProfilePreference.user_id == user_id
    ).first()


def upsert_preference(db: Session, user_id: str, data: dict) -> UserProfilePreference:
    """Create or update preference. data keys match model field names."""
    pref = get_preference(db, user_id)
    if not pref:
        pref = UserProfilePreference(user_id=user_id)
        db.add(pref)
    for key in ["mode", "duration_type", "reward_preference",
                "preferred_time_slots", "preferred_categories", "preferred_helper_types"]:
        if key in data:
            setattr(pref, key, data[key])
    db.flush()
    return pref


# --- Reliability ---

def get_reliability(db: Session, user_id: str) -> UserReliability | None:
    return db.query(UserReliability).filter(
        UserReliability.user_id == user_id
    ).first()


# --- Demand ---

def get_demand(db: Session, user_id: str) -> UserDemand | None:
    return db.query(UserDemand).filter(
        UserDemand.user_id == user_id
    ).first()


# --- Summary ---

def get_profile_summary(db: Session, user_id: str) -> dict:
    """Get all four dimensions in one call."""
    return {
        "capabilities": get_capabilities(db, user_id),
        "preference": get_preference(db, user_id),
        "reliability": get_reliability(db, user_id),
        "demand": get_demand(db, user_id),
    }


# --- Onboarding ---

def submit_onboarding(db: Session, user_id: str, data: dict) -> dict:
    """Handle onboarding submission: batch set capabilities + preference."""
    caps = []
    if "capabilities" in data:
        caps = upsert_capabilities(db, user_id, data["capabilities"])
    pref_data = {}
    if "mode" in data:
        pref_data["mode"] = data["mode"]
    if "preferred_categories" in data:
        pref_data["preferred_categories"] = data["preferred_categories"]
    pref = upsert_preference(db, user_id, pref_data) if pref_data else get_preference(db, user_id)
    return {"capabilities": caps, "preference": pref}
