"""Shared utilities for recommendation scorers."""
import math
import logging
from typing import Optional, Set
from datetime import datetime, timedelta

from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance in meters between two GPS coordinates using Haversine formula.

    Returns float('inf') if coordinates are invalid.
    """
    if not (-90 <= lat1 <= 90 and -90 <= lat2 <= 90 and
            -180 <= lon1 <= 180 and -180 <= lon2 <= 180):
        return float('inf')

    R = 6371000  # Earth radius in meters
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)

    a = (math.sin(dphi / 2) ** 2 +
         math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    return R * c


def get_excluded_task_ids(db: Session, user_id: str) -> Set[int]:
    """Get task IDs that should be excluded from recommendations.

    Excludes: user's own tasks, tasks user already applied to,
    tasks user completed, tasks user was assigned to.
    """
    from app.models import Task, TaskApplication

    excluded = set()

    # User's own tasks
    own_tasks = db.query(Task.id).filter(Task.poster_id == user_id).all()
    excluded.update(t.id for t in own_tasks)

    # Tasks user applied to
    applied = db.query(TaskApplication.task_id).filter(
        TaskApplication.applicant_id == user_id
    ).all()
    excluded.update(t.task_id for t in applied)

    # Tasks user is taker of
    taken = db.query(Task.id).filter(Task.taker_id == user_id).all()
    excluded.update(t.id for t in taken)

    return excluded


def is_new_user(user, days: int = 7) -> bool:
    """Check if user registered within the last N days."""
    if not user or not user.created_at:
        return True
    from app.crud import get_utc_time
    return (get_utc_time() - user.created_at).days <= days
