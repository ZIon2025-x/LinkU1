"""Demand inference engine: predicts user needs based on stage and behavior."""
import logging
from datetime import datetime, timezone, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.models import UserDemand
from app.models import User, UserTaskInteraction

logger = logging.getLogger(__name__)

# Lifecycle stage definitions by month and identity
STAGE_MAP_PRE_ARRIVAL = {
    5: ["pre_arrival"], 6: ["pre_arrival"], 7: ["pre_arrival"],
    8: ["pre_arrival", "new_arrival"], 9: ["new_arrival"],
}
STAGE_MAP_IN_UK = {
    1: ["settled"], 2: ["settled"],
    3: ["settled", "easter_break"], 4: ["settled", "easter_break"],
    5: ["exam_season"], 6: ["exam_season", "graduation", "house_hunting", "moving"],
    7: ["graduation", "house_hunting", "moving", "returning"],
    8: ["house_hunting", "moving", "returning"],
    9: ["settled", "returning"],
    10: ["settled"], 11: ["settled"],
    12: ["settled", "christmas_break"],
}

STAGE_PREDICTIONS = {
    "pre_arrival": [
        {"category": "arrival_prep", "confidence": 0.9, "items": ["接机", "住宿", "行李"], "reason": "行前准备阶段"},
    ],
    "new_arrival": [
        {"category": "settling", "confidence": 0.85, "items": ["银行卡", "电话卡", "注册"], "reason": "新生入学阶段"},
        {"category": "orientation", "confidence": 0.7, "items": ["校园", "超市", "交通"], "reason": "熟悉环境"},
    ],
    "exam_season": [
        {"category": "academic", "confidence": 0.8, "items": ["论文", "打印", "复习"], "reason": "期末阶段"},
    ],
    "graduation": [
        {"category": "graduation", "confidence": 0.85, "items": ["毕业照", "签证", "PSW"], "reason": "毕业阶段"},
    ],
    "house_hunting": [
        {"category": "housing", "confidence": 0.9, "items": ["租房", "合同", "看房"], "reason": "找房阶段"},
    ],
    "moving": [
        {"category": "moving", "confidence": 0.9, "items": ["搬家", "家具", "清洁"], "reason": "搬家阶段"},
    ],
    "returning": [
        {"category": "returning", "confidence": 0.85, "items": ["退租", "行李海运", "闲置转让"], "reason": "回国阶段"},
    ],
    "settled": [
        {"category": "daily", "confidence": 0.6, "items": ["代购", "代取", "日常"], "reason": "日常生活"},
    ],
    "christmas_break": [
        {"category": "travel", "confidence": 0.7, "items": ["旅游搭子", "短租", "寄存"], "reason": "圣诞假期"},
    ],
    "easter_break": [
        {"category": "travel", "confidence": 0.7, "items": ["旅游搭子", "短途出行"], "reason": "复活节假期"},
    ],
}


def determine_user_stages(identity: str | None) -> list[str]:
    """Determine lifecycle stages based on identity and current month."""
    month = datetime.now(timezone.utc).month
    if identity == "pre_arrival":
        return STAGE_MAP_PRE_ARRIVAL.get(month, ["pre_arrival"])
    elif identity == "in_uk":
        return STAGE_MAP_IN_UK.get(month, ["settled"])
    else:
        return ["settled"]


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


def infer_demand(db: Session, user_id: str):
    """Infer or update user demand. Merges with existing data."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        return None

    demand = db.query(UserDemand).filter(UserDemand.user_id == user_id).first()
    if not demand:
        demand = UserDemand(user_id=user_id)
        db.add(demand)

    # Compute stages from month + identity
    stages = determine_user_stages(demand.identity)

    # Merge with existing stages (may include AI-inferred stages)
    existing_stages = demand.user_stage if isinstance(demand.user_stage, list) else []
    merged_stages = list(set(stages) | set(existing_stages))
    demand.user_stage = merged_stages

    # Build predicted_needs from all active stages
    needs = []
    seen_categories = set()
    for stage in merged_stages:
        for need in STAGE_PREDICTIONS.get(stage, []):
            if need["category"] not in seen_categories:
                needs.append(need)
                seen_categories.add(need["category"])
    demand.predicted_needs = needs

    # Merge recent interests from task behavior (don't overwrite AI interests)
    task_interests = analyze_recent_interests(db, user_id)
    existing_interests = dict(demand.recent_interests or {})
    for topic, count in task_interests.items():
        # Convert raw count to dict format for consistency
        task_data = {"confidence": min(count / 10, 1.0), "urgency": "medium", "source": "task_behavior"}
        if topic not in existing_interests:
            existing_interests[topic] = task_data
        else:
            existing = existing_interests[topic]
            # Don't overwrite higher-confidence AI interests
            if isinstance(existing, dict) and existing.get("confidence", 0) >= task_data["confidence"]:
                continue
            existing_interests[topic] = task_data
    demand.recent_interests = existing_interests

    demand.last_inferred_at = datetime.now(timezone.utc)
    demand.inference_version = "v2.0"
    db.flush()
    return demand


def batch_infer_demands(db: Session, limit: int = 500) -> dict:
    """Nightly batch: infer demands for all active users (7-day activity window).
    Returns dict with 'succeeded' count and 'failed' list of user_ids."""
    seven_days_ago = datetime.now(timezone.utc) - timedelta(days=7)
    active_user_ids = db.query(
        UserTaskInteraction.user_id.distinct()
    ).filter(
        UserTaskInteraction.interaction_time >= seven_days_ago
    ).limit(limit).all()
    succeeded = 0
    failed_ids = []
    for (user_id,) in active_user_ids:
        try:
            infer_demand(db, user_id)
            succeeded += 1
        except Exception as e:
            logger.warning(f"Failed to infer demand for user {user_id}: {e}")
            db.rollback()
            failed_ids.append(user_id)
            continue
    if failed_ids:
        logger.warning(f"Batch inference: {len(failed_ids)} users failed: {failed_ids[:10]}")
    return {"succeeded": succeeded, "failed": len(failed_ids), "total": len(active_user_ids)}
