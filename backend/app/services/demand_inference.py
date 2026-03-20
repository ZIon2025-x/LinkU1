"""Demand inference engine: predicts user needs based on stage and behavior."""
from datetime import datetime, timezone, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.models import UserDemand, UserStage
from app.models import User, UserTaskInteraction

INFERENCE_VERSION = "v1.0"

STAGE_PREDICTIONS = {
    UserStage.new_arrival: [
        {"category": "settling", "confidence": 0.85, "items": ["接机", "搬家", "银行开户", "电话卡办理"], "reason": "new_arrival_pattern"},
        {"category": "orientation", "confidence": 0.7, "items": ["校园导览", "超市指引", "交通卡办理"], "reason": "new_arrival_pattern"},
    ],
    UserStage.settling: [
        {"category": "housing", "confidence": 0.7, "items": ["租房看房", "搬家", "家具组装"], "reason": "settling_pattern"},
        {"category": "daily_life", "confidence": 0.6, "items": ["代买代取", "取快递", "陪同办事"], "reason": "settling_pattern"},
    ],
    UserStage.established: [
        {"category": "daily_life", "confidence": 0.5, "items": ["代买代取", "取快递"], "reason": "general_needs"},
    ],
    UserStage.experienced: [],
}


def determine_user_stage(db: Session, user: User) -> UserStage:
    """Determine user's current stage based on registration time and activity."""
    now = datetime.now(timezone.utc)
    days_since_registration = (now - user.created_at).days if user.created_at else 0
    if days_since_registration <= 7:
        return UserStage.new_arrival
    elif days_since_registration <= 30:
        return UserStage.settling
    elif user.completed_task_count and user.completed_task_count > 10 and days_since_registration > 90:
        return UserStage.experienced
    elif days_since_registration > 30:
        return UserStage.established
    return UserStage.new_arrival


def analyze_recent_interests(db: Session, user_id: str) -> dict:
    """Analyze user's browsing/interaction patterns in the last 7 days."""
    seven_days_ago = datetime.now(timezone.utc) - timedelta(days=7)
    interactions = db.query(
        UserTaskInteraction.interaction_type,
        func.count(UserTaskInteraction.id).label("count")
    ).filter(
        UserTaskInteraction.user_id == user_id,
        UserTaskInteraction.interaction_time >= seven_days_ago
    ).group_by(UserTaskInteraction.interaction_type).all()
    return {row.interaction_type: row.count for row in interactions}


def infer_demand(db: Session, user_id: str) -> UserDemand:
    """Run demand inference for a user. Creates or updates UserDemand record."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise ValueError(f"User {user_id} not found")
    stage = determine_user_stage(db, user)
    recent_interests = analyze_recent_interests(db, user_id)
    predicted_needs = list(STAGE_PREDICTIONS.get(stage, []))
    demand = db.query(UserDemand).filter(UserDemand.user_id == user_id).first()
    if not demand:
        demand = UserDemand(user_id=user_id)
        db.add(demand)
    demand.user_stage = stage
    demand.predicted_needs = predicted_needs
    demand.recent_interests = recent_interests
    demand.last_inferred_at = datetime.now(timezone.utc)
    demand.inference_version = INFERENCE_VERSION
    db.flush()
    return demand


def batch_infer_demands(db: Session, limit: int = 500):
    """Nightly batch: infer demands for all active users (7-day activity window)."""
    seven_days_ago = datetime.now(timezone.utc) - timedelta(days=7)
    active_user_ids = db.query(
        UserTaskInteraction.user_id.distinct()
    ).filter(
        UserTaskInteraction.interaction_time >= seven_days_ago
    ).limit(limit).all()
    results = []
    for (user_id,) in active_user_ids:
        try:
            demand = infer_demand(db, user_id)
            results.append(demand)
        except Exception:
            continue
    return results
