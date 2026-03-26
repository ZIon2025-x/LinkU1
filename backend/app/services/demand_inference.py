"""Demand inference engine: predicts user needs based on stage, behavior and history.

v3.0 — Comprehensive analysis across 7 dimensions:
1. Lifecycle stage (month + identity)
2. Task browsing/interaction patterns (task_type from UserTaskInteraction)
3. Posted task patterns (what types they publish, price ranges)
4. Taken task patterns (what types they accept, completion rate)
5. Service application patterns (what services they apply for)
6. Skills inference (from capabilities + taken tasks + services)
7. Preference inference (active hours, price sensitivity, category affinity)
"""
import logging
from collections import Counter
from datetime import datetime, timezone, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import func, case, extract

from app.models import (
    UserDemand, User, UserTaskInteraction,
    Task, TaskApplication, Review,
    ServiceApplication, TaskExpertService,
    UserCapability, ForumPost,
)

logger = logging.getLogger(__name__)

# ============================================================================
# Lifecycle stage definitions (rule-based)
# ============================================================================

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


# ============================================================================
# Dimension analyzers
# ============================================================================

def _analyze_browsed_task_types(db: Session, user_id: str, since: datetime) -> dict:
    """Analyze what task_types the user browses/interacts with (via UserTaskInteraction JOIN Task)."""
    rows = (
        db.query(Task.task_type, func.count().label("cnt"))
        .join(UserTaskInteraction, UserTaskInteraction.task_id == Task.id)
        .filter(
            UserTaskInteraction.user_id == user_id,
            UserTaskInteraction.interaction_time >= since,
        )
        .group_by(Task.task_type)
        .order_by(func.count().desc())
        .limit(8)
        .all()
    )
    if not rows:
        return {}
    total = sum(r.cnt for r in rows)
    return {
        r.task_type: {
            "count": r.cnt,
            "confidence": round(r.cnt / total, 2),
            "source": "browsing",
        }
        for r in rows
    }


def _analyze_posted_tasks(db: Session, user_id: str, since: datetime) -> dict:
    """Analyze the user's task posting patterns: types, avg reward, frequency."""
    rows = (
        db.query(
            Task.task_type,
            func.count().label("cnt"),
            func.avg(Task.reward).label("avg_reward"),
        )
        .filter(Task.poster_id == user_id, Task.created_at >= since)
        .group_by(Task.task_type)
        .order_by(func.count().desc())
        .limit(5)
        .all()
    )
    return {
        r.task_type: {
            "posted": r.cnt,
            "avg_reward": round(float(r.avg_reward or 0), 1),
            "source": "posted_tasks",
        }
        for r in rows
    }


def _analyze_taken_tasks(db: Session, user_id: str, since: datetime) -> dict:
    """Analyze what task types the user takes and their completion stats."""
    rows = (
        db.query(
            Task.task_type,
            func.count().label("cnt"),
            func.sum(case((Task.status == "completed", 1), else_=0)).label("completed"),
            func.avg(Task.reward).label("avg_reward"),
        )
        .filter(Task.taker_id == user_id, Task.accepted_at >= since)
        .group_by(Task.task_type)
        .order_by(func.count().desc())
        .limit(5)
        .all()
    )
    return {
        r.task_type: {
            "taken": r.cnt,
            "completed": int(r.completed or 0),
            "avg_reward": round(float(r.avg_reward or 0), 1),
            "source": "taken_tasks",
        }
        for r in rows
    }


def _analyze_service_applications(db: Session, user_id: str, since: datetime) -> dict:
    """Analyze what service categories the user applies for."""
    rows = (
        db.query(
            TaskExpertService.category,
            func.count().label("cnt"),
        )
        .join(ServiceApplication, ServiceApplication.service_id == TaskExpertService.id)
        .filter(
            ServiceApplication.applicant_id == user_id,
            ServiceApplication.created_at >= since,
        )
        .group_by(TaskExpertService.category)
        .order_by(func.count().desc())
        .limit(5)
        .all()
    )
    return {
        (r.category or "other"): {
            "applied": r.cnt,
            "source": "service_applications",
        }
        for r in rows
    }


def _infer_skills(db: Session, user_id: str, since: datetime) -> dict:
    """Infer skills from: declared capabilities, completed tasks, published services."""
    skills: dict[str, dict] = {}

    # 1. Declared capabilities (highest confidence)
    caps = db.query(UserCapability).filter(UserCapability.user_id == user_id).all()
    proficiency_score = {"beginner": 0.4, "intermediate": 0.7, "expert": 0.95}
    for cap in caps:
        level = cap.proficiency.value if cap.proficiency else "beginner"
        skills[cap.skill_name] = {
            "confidence": proficiency_score.get(level, 0.4),
            "source": "declared",
            "proficiency": level,
        }

    # 2. Completed tasks as taker → infer task_type as skill
    taken_types = (
        db.query(Task.task_type, func.count().label("cnt"))
        .filter(
            Task.taker_id == user_id,
            Task.status == "completed",
            Task.completed_at >= since,
        )
        .group_by(Task.task_type)
        .all()
    )
    for row in taken_types:
        conf = min(0.3 + row.cnt * 0.1, 0.85)
        if row.task_type not in skills or skills[row.task_type]["confidence"] < conf:
            skills[row.task_type] = {
                "confidence": round(conf, 2),
                "source": "completed_tasks",
                "task_count": row.cnt,
            }

    # 3. Published services → skills from service tags
    services = (
        db.query(TaskExpertService.skills)
        .filter(
            TaskExpertService.user_id == user_id,
            TaskExpertService.service_type == "personal",
            TaskExpertService.status == "active",
            TaskExpertService.skills.isnot(None),
        )
        .all()
    )
    for (svc_skills,) in services:
        if isinstance(svc_skills, list):
            for sk in svc_skills:
                if sk not in skills:
                    skills[sk] = {"confidence": 0.8, "source": "published_service"}

    return skills


def _infer_preferences(db: Session, user_id: str, since: datetime) -> dict:
    """Infer preferences: active hours, price sensitivity, category affinity, role tendency."""
    prefs: dict[str, object] = {}

    # 1. Active hours — from interaction timestamps
    hour_rows = (
        db.query(
            extract("hour", UserTaskInteraction.interaction_time).label("hr"),
            func.count().label("cnt"),
        )
        .filter(
            UserTaskInteraction.user_id == user_id,
            UserTaskInteraction.interaction_time >= since,
        )
        .group_by("hr")
        .order_by(func.count().desc())
        .limit(4)
        .all()
    )
    if hour_rows:
        active_hours = [int(r.hr) for r in hour_rows]
        time_labels = []
        for h in active_hours:
            if 6 <= h < 12:
                time_labels.append("morning")
            elif 12 <= h < 18:
                time_labels.append("afternoon")
            elif 18 <= h < 23:
                time_labels.append("evening")
            else:
                time_labels.append("night")
        prefs["active_periods"] = list(dict.fromkeys(time_labels))  # deduplicate, preserve order

    # 2. Price sensitivity — from posted + taken tasks
    price_row = (
        db.query(
            func.avg(Task.reward).label("avg"),
            func.min(Task.reward).label("min_r"),
            func.max(Task.reward).label("max_r"),
        )
        .filter(
            ((Task.poster_id == user_id) | (Task.taker_id == user_id)),
            Task.created_at >= since,
            Task.reward > 0,
        )
        .first()
    )
    if price_row and price_row.avg:
        avg_price = float(price_row.avg)
        if avg_price < 10:
            prefs["price_range"] = "low"
        elif avg_price < 30:
            prefs["price_range"] = "medium"
        else:
            prefs["price_range"] = "high"
        prefs["avg_price"] = round(avg_price, 1)

    # 3. Role tendency — poster vs taker
    posted_cnt = db.query(func.count(Task.id)).filter(
        Task.poster_id == user_id, Task.created_at >= since
    ).scalar() or 0
    taken_cnt = db.query(func.count(Task.id)).filter(
        Task.taker_id == user_id, Task.accepted_at >= since
    ).scalar() or 0
    if posted_cnt + taken_cnt > 0:
        if posted_cnt > taken_cnt * 2:
            prefs["role_tendency"] = "poster"
        elif taken_cnt > posted_cnt * 2:
            prefs["role_tendency"] = "taker"
        else:
            prefs["role_tendency"] = "balanced"
        prefs["posted_count"] = posted_cnt
        prefs["taken_count"] = taken_cnt

    # 4. Category affinity — merge posted + taken + browsed
    all_types: Counter = Counter()
    # posted
    posted_types = (
        db.query(Task.task_type, func.count().label("cnt"))
        .filter(Task.poster_id == user_id, Task.created_at >= since)
        .group_by(Task.task_type).all()
    )
    for r in posted_types:
        all_types[r.task_type] += r.cnt * 2  # posted = higher weight
    # taken
    taken_types = (
        db.query(Task.task_type, func.count().label("cnt"))
        .filter(Task.taker_id == user_id, Task.accepted_at >= since)
        .group_by(Task.task_type).all()
    )
    for r in taken_types:
        all_types[r.task_type] += r.cnt * 3  # taken = highest weight
    # browsed
    browsed_types = (
        db.query(Task.task_type, func.count().label("cnt"))
        .join(UserTaskInteraction, UserTaskInteraction.task_id == Task.id)
        .filter(UserTaskInteraction.user_id == user_id, UserTaskInteraction.interaction_time >= since)
        .group_by(Task.task_type).all()
    )
    for r in browsed_types:
        all_types[r.task_type] += r.cnt  # browsed = base weight

    if all_types:
        prefs["top_categories"] = [cat for cat, _ in all_types.most_common(5)]

    return prefs


# ============================================================================
# Main inference function
# ============================================================================

def infer_demand(db: Session, user_id: str):
    """Infer or update user demand. Comprehensive analysis across 7 dimensions."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        return None

    demand = db.query(UserDemand).filter(UserDemand.user_id == user_id).first()
    if not demand:
        demand = UserDemand(user_id=user_id)
        db.add(demand)

    now = datetime.now(timezone.utc)
    since_30d = now - timedelta(days=30)
    since_90d = now - timedelta(days=90)

    # ── 1. Lifecycle stages ──
    stages = determine_user_stages(demand.identity)
    existing_stages = demand.user_stage if isinstance(demand.user_stage, list) else []
    merged_stages = list(set(stages) | set(existing_stages))
    demand.user_stage = merged_stages

    # ── 2. Predicted needs from stages ──
    needs = []
    seen_categories = set()
    for stage in merged_stages:
        for need in STAGE_PREDICTIONS.get(stage, []):
            if need["category"] not in seen_categories:
                needs.append(need)
                seen_categories.add(need["category"])
    demand.predicted_needs = needs

    # ── 3. Recent interests (browsed task types + posted + taken + service apps) ──
    existing_interests = dict(demand.recent_interests or {})
    # Keep AI-sourced interests, rebuild behavior-sourced ones
    ai_interests = {k: v for k, v in existing_interests.items()
                    if isinstance(v, dict) and v.get("source") == "ai_insight"}

    browsed = _analyze_browsed_task_types(db, user_id, since_30d)
    posted = _analyze_posted_tasks(db, user_id, since_90d)
    taken = _analyze_taken_tasks(db, user_id, since_90d)
    svc_apps = _analyze_service_applications(db, user_id, since_90d)

    merged_interests: dict = {}
    # Merge all sources, prefer higher confidence
    for source_data in [browsed, posted, taken, svc_apps]:
        for topic, data in source_data.items():
            conf = data.get("confidence", 0.5)
            if topic not in merged_interests or merged_interests[topic].get("confidence", 0) < conf:
                merged_interests[topic] = data

    # AI interests take priority
    merged_interests.update(ai_interests)
    demand.recent_interests = merged_interests

    # ── 4. Inferred skills ──
    demand.inferred_skills = _infer_skills(db, user_id, since_90d)

    # ── 5. Inferred preferences ──
    demand.inferred_preferences = _infer_preferences(db, user_id, since_30d)

    demand.last_inferred_at = now
    demand.inference_version = "v3.0"
    db.flush()
    return demand


# ============================================================================
# Batch inference
# ============================================================================

def batch_infer_demands(db: Session, limit: int = 500) -> dict:
    """Nightly batch: infer demands for all active users (7-day activity window).
    Returns dict with 'succeeded' count and 'failed' list of user_ids."""
    seven_days_ago = datetime.now(timezone.utc) - timedelta(days=7)

    # Include users with recent interactions OR recent task activity
    from sqlalchemy import union_all, literal_column

    interaction_users = (
        db.query(UserTaskInteraction.user_id.distinct().label("uid"))
        .filter(UserTaskInteraction.interaction_time >= seven_days_ago)
    )
    poster_users = (
        db.query(Task.poster_id.distinct().label("uid"))
        .filter(Task.created_at >= seven_days_ago)
    )
    taker_users = (
        db.query(Task.taker_id.distinct().label("uid"))
        .filter(Task.taker_id.isnot(None), Task.accepted_at >= seven_days_ago)
    )

    combined = union_all(
        interaction_users.statement,
        poster_users.statement,
        taker_users.statement,
    ).alias("active_users")

    active_user_ids = (
        db.query(combined.c.uid.distinct())
        .limit(limit)
        .all()
    )

    succeeded = 0
    failed_ids = []
    for (user_id,) in active_user_ids:
        if not user_id:
            continue
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
