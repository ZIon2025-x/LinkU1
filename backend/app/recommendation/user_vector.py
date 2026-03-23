"""User preference vector construction.

Extracts user preferences from UserProfilePreference model, task history,
view history, search keywords, and skipped tasks (negative feedback).
"""

import json
import logging
from typing import Dict, List, Optional

from sqlalchemy.orm import Session
from sqlalchemy import desc

logger = logging.getLogger(__name__)


def get_user_preferences(db: Session, user_id: str):
    """Load user's explicit preference settings from DB."""
    from app.models import UserProfilePreference
    return db.query(UserProfilePreference).filter(
        UserProfilePreference.user_id == user_id
    ).first()


def get_user_task_history(db: Session, user_id: str) -> List:
    """Load user's recent task history (most recent 50)."""
    from app.models import TaskHistory
    return db.query(TaskHistory).filter(
        TaskHistory.user_id == user_id
    ).order_by(desc(TaskHistory.timestamp)).limit(50).all()


def _load_all_interactions(db: Session, user_id: str) -> Dict[str, List]:
    """Load ALL user interactions in ONE query and split by type.

    Returns dict with keys: "view", "click", "skip", each a list of ORM objects.
    Cached in Redis for 5 minutes.
    """
    from app.redis_cache import redis_cache

    cache_key = f"user_interactions_all:{user_id}"
    try:
        cached = redis_cache.get(cache_key)
        if cached:
            if isinstance(cached, bytes):
                cached = cached.decode('utf-8')
            return json.loads(cached)
    except Exception as e:
        logger.debug(f"读取交互缓存失败: {e}")

    try:
        from app.models import UserTaskInteraction
        interactions = db.query(UserTaskInteraction).filter(
            UserTaskInteraction.user_id == user_id,
            UserTaskInteraction.interaction_type.in_(["view", "click", "skip"])
        ).order_by(desc(UserTaskInteraction.interaction_time)).limit(200).all()

        grouped: Dict[str, List] = {"view": [], "click": [], "skip": []}
        for i in interactions:
            itype = i.interaction_type
            if itype in grouped:
                grouped[itype].append({
                    "task_id": i.task_id,
                    "duration_seconds": i.duration_seconds or 0,
                    "interaction_time": i.interaction_time.isoformat() if i.interaction_time else None,
                    "metadata": i.interaction_metadata if isinstance(i.interaction_metadata, dict) else {},
                })

        try:
            redis_cache.setex(cache_key, 300, json.dumps(grouped, default=str))
        except Exception as e:
            logger.debug(f"缓存交互数据失败: {e}")

        return grouped
    except Exception as e:
        logger.error(f"获取用户交互数据失败: {e}")
        return {"view": [], "click": [], "skip": []}


def get_user_view_history(db: Session, user_id: str) -> List[Dict]:
    """Load user's view interaction history (from batch-loaded interactions)."""
    grouped = _load_all_interactions(db, user_id)
    return grouped.get("view", [])[:100]


def get_user_search_keywords(db: Session, user_id: str) -> List[str]:
    """Extract search keywords from user's view/click interactions."""
    grouped = _load_all_interactions(db, user_id)
    keywords = []
    for i in (grouped.get("view", []) + grouped.get("click", []))[:50]:
        meta = i.get("metadata", {})
        if isinstance(meta, dict) and "search_keyword" in meta:
            keywords.append(meta["search_keyword"])
    return list(set(keywords))[:10]


def get_user_skipped_tasks(db: Session, user_id: str) -> List[int]:
    """Get task IDs the user has skipped (negative feedback)."""
    grouped = _load_all_interactions(db, user_id)
    return [s["task_id"] for s in grouped.get("skip", [])][:50]


def build_user_preference_vector(
    db: Session,
    user,
    preferences,
    history: List,
    view_history: Optional[List[Dict]] = None,
    search_keywords: Optional[List[str]] = None,
    skipped_tasks: Optional[List[int]] = None,
) -> Dict:
    """Build a user preference vector from multiple data sources.

    Args:
        db: SQLAlchemy session
        user: User model instance
        preferences: UserProfilePreference instance (or None)
        history: List of TaskHistory records
        view_history: List of view interaction dicts
        search_keywords: List of extracted search keywords
        skipped_tasks: List of skipped task IDs (negative feedback)

    Returns:
        Dict with keys: task_types, task_types_from_preference, locations,
        locations_from_preference, price_range, price_range_from_history,
        task_levels, keywords, negative_task_types
    """
    from app.models import Task

    vector = {
        "task_types": [],
        "task_types_from_preference": False,
        "locations": [],
        "locations_from_preference": False,
        "price_range": {"min": 0, "max": 999999},
        "price_range_from_history": False,
        "task_levels": [],
        "keywords": [],
    }

    # --- Explicit preferences ---
    if preferences:
        def _parse_json_field(val):
            """Parse a JSON field that may be a string (Text) or already parsed (JSON column)."""
            if not val:
                return []
            if isinstance(val, list):
                return val
            try:
                return json.loads(val)
            except (json.JSONDecodeError, TypeError):
                return []

        if preferences.task_types:
            vector["task_types"] = _parse_json_field(preferences.task_types)
            vector["task_types_from_preference"] = True
        if preferences.locations:
            vector["locations"] = _parse_json_field(preferences.locations)
            vector["locations_from_preference"] = True
        if preferences.task_levels:
            vector["task_levels"] = _parse_json_field(preferences.task_levels)
        if preferences.keywords:
            vector["keywords"] = _parse_json_field(preferences.keywords)

    # --- Learn from view history (long views > 30s indicate interest) ---
    if view_history:
        try:
            long_view_tasks = [
                v["task_id"] for v in view_history
                if v.get("duration_seconds", 0) > 30
            ]
            if long_view_tasks:
                tasks = db.query(
                    Task.id,
                    Task.task_type,
                    Task.location
                ).filter(Task.id.in_(long_view_tasks[:20])).all()

                for task_id, task_type, location in tasks:
                    if task_type and task_type not in vector["task_types"]:
                        vector["task_types"].append(task_type)
                    if location and location not in vector["locations"]:
                        vector["locations"].append(location)
        except Exception as e:
            logger.warning(f"从浏览行为学习偏好失败: {e}")

    # --- Learn from search keywords ---
    if search_keywords:
        existing_keywords = set(vector["keywords"])
        for keyword in search_keywords:
            if keyword and keyword not in existing_keywords:
                vector["keywords"].append(keyword)
                existing_keywords.add(keyword)

    # --- Negative feedback from skipped tasks ---
    if skipped_tasks:
        try:
            skipped_task_types = db.query(Task.task_type).filter(
                Task.id.in_(skipped_tasks[:20])
            ).distinct().all()
            vector["negative_task_types"] = [t[0] for t in skipped_task_types if t[0]]
        except Exception as e:
            logger.warning(f"获取跳过任务类型失败: {e}")
            vector["negative_task_types"] = []
    else:
        vector["negative_task_types"] = []

    # --- Learn from task history ---
    if history:
        task_ids = [h.task_id for h in history[:20]]
        if task_ids:
            tasks_data = db.query(
                Task.id,
                Task.task_type,
                Task.location,
                Task.reward
            ).filter(Task.id.in_(task_ids)).all()

            type_counts: Dict[str, int] = {}
            location_counts: Dict[str, int] = {}
            prices: List[float] = []

            for task_id, task_type, location, reward in tasks_data:
                if task_type:
                    type_counts[task_type] = type_counts.get(task_type, 0) + 1
                if location:
                    location_counts[location] = location_counts.get(location, 0) + 1
                if reward:
                    prices.append(float(reward))

            if type_counts:
                existing_types = set(vector["task_types"])
                for task_type, count in sorted(
                    type_counts.items(), key=lambda x: x[1], reverse=True
                )[:5]:
                    if task_type not in existing_types:
                        vector["task_types"].append(task_type)
                        existing_types.add(task_type)

            if location_counts:
                existing_locs = set(vector["locations"])
                for loc, count in sorted(
                    location_counts.items(), key=lambda x: x[1], reverse=True
                )[:3]:
                    if loc not in existing_locs:
                        vector["locations"].append(loc)
                        existing_locs.add(loc)

            if prices:
                vector["price_range"]["min"] = min(prices) * 0.8
                vector["price_range"]["max"] = max(prices) * 1.2
                vector["price_range_from_history"] = True

    return vector


def get_default_preference_vector(user) -> Dict:
    """Build a default preference vector for cold-start users."""
    return {
        "task_types": [],
        "task_types_from_preference": False,
        "locations": [user.residence_city] if user.residence_city else [],
        "locations_from_preference": False,
        "price_range": {"min": 0, "max": 999999},
        "price_range_from_history": False,
        "task_levels": [user.user_level] if user.user_level else ["normal"],
        "keywords": [],
        "negative_task_types": [],
    }
