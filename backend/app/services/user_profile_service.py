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
            UserCapability.skill_name == cap_data["skill_name"],
            UserCapability.category_id == cap_data["category_id"]
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
    """Create or update preference. data keys match model field names.

    `city` 走手动覆盖语义：只有值真正变化时才写入并标记 city_source='manual'，
    避免用户开偏好页又原样保存就把 GPS 源锁成 manual。
    """
    pref = get_preference(db, user_id)
    if not pref:
        pref = UserProfilePreference(user_id=user_id)
        db.add(pref)
    for key in ["mode", "duration_type", "reward_preference",
                "preferred_time_slots", "preferred_categories", "preferred_helper_types",
                "nearby_push_enabled", "daily_digest_enabled"]:
        if key in data:
            setattr(pref, key, data[key])

    if "city" in data:
        new_city = (data["city"] or None) if data["city"] != "" else None
        if new_city != pref.city:
            pref.city = new_city
            pref.city_source = "manual"

    # Handle identity and interests — stored on UserDemand, not UserProfilePreference
    if "identity" in data or "interests" in data:
        from app.models import UserDemand
        demand = db.query(UserDemand).filter(UserDemand.user_id == user_id).first()
        if not demand:
            demand = UserDemand(user_id=user_id)
            db.add(demand)
        if "identity" in data and data["identity"]:
            demand.identity = data["identity"]
            try:
                from app.services.demand_inference import determine_user_stages
                demand.user_stage = determine_user_stages(data["identity"])
            except Exception:
                pass
        if "interests" in data and data["interests"] is not None:
            # Replace interests from profile edit (user explicitly chose these)
            # Keep non-profile-edit interests (from AI chat, task behavior, etc.)
            existing = dict(demand.recent_interests or {})
            # Remove old profile_edit/onboarding interests
            existing = {k: v for k, v in existing.items()
                        if isinstance(v, dict) and v.get("source") not in ("profile_edit", "onboarding")}
            # Add currently selected interests
            for key in data["interests"]:
                existing[key] = {
                    "confidence": 0.8,
                    "urgency": "medium",
                    "source": "profile_edit",
                }
            demand.recent_interests = existing

    db.flush()
    return pref


def update_city_from_gps(db: Session, user_id: str, city: str) -> UserProfilePreference | None:
    """GPS 反查到的城市自动同步到偏好。

    - 若用户偏好行不存在则创建（city_source 默认 'gps'）
    - 若 city_source == 'manual' 则不动（尊重用户手动选择）
    - 若新城市与现值相同则不动（去抖）
    - 否则写入新 city 并保持/设置 source='gps'

    返回更新后的 pref（caller 负责 commit）。空 city 直接返回 None 不写入。
    """
    city = (city or "").strip()
    if not city:
        return None
    pref = get_preference(db, user_id)
    if not pref:
        pref = UserProfilePreference(user_id=user_id, city=city, city_source="gps")
        db.add(pref)
        db.flush()
        return pref
    if pref.city_source == "manual":
        return pref
    if pref.city == city:
        return pref
    pref.city = city
    pref.city_source = "gps"
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
    if data.get("mode"):
        pref_data["mode"] = data["mode"]
    if data.get("preferred_categories"):
        pref_data["preferred_categories"] = data["preferred_categories"]
    if data.get("city"):
        pref_data["city"] = data["city"]
    if data.get("identity"):
        pref_data["identity"] = data["identity"]
    if data.get("interests"):
        pref_data["interests"] = data["interests"]
    pref = upsert_preference(db, user_id, pref_data) if pref_data else get_preference(db, user_id)
    return {"capabilities": caps, "preference": pref}
