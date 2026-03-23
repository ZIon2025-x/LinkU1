"""Time-based recommendation scorer.

Scores tasks by deadline proximity and alignment with the user's active time
slots (derived from UserTaskInteraction history over the last 30 days).

Scoring formula:
  base  = 0.7 (all future-deadline tasks)
  +0.2  deadline hour in user's top-3 active hours
  +0.1  deadline weekday in user's top-3 active days
  +0.1  current time is user's active period
  +0.2  deadline < 24 h away
  +0.1  deadline 24-72 h away
  cap   = 1.0
"""

import json
import logging
from datetime import timedelta
from typing import Dict, List, Any

from ..base_scorer import BaseScorer, ScoredTask

logger = logging.getLogger(__name__)


class TimeScorer(BaseScorer):
    """Score tasks by deadline urgency and user active-time alignment."""

    name = "time"
    default_weight = 0.08

    def score(self, user, tasks: List, context: Dict[str, Any]) -> Dict[int, ScoredTask]:
        """Score each candidate task by time signals.

        Context keys used:
            db: SQLAlchemy Session (required)
        """
        db = context["db"]
        from app.crud import get_utc_time

        active_time_slots = self._get_user_active_time_slots(db, user.id)
        now = get_utc_time()
        current_hour = now.hour
        current_day = now.weekday()

        is_active_time = (
            current_hour in active_time_slots.get("active_hours", [])
            or current_day in active_time_slots.get("active_days", [])
        )

        results: Dict[int, ScoredTask] = {}

        for task in tasks:
            # Only score tasks with a future deadline
            if not task.deadline or task.deadline <= now:
                continue

            score = 0.7
            reason = "即将截止"

            deadline_hour = task.deadline.hour
            deadline_day = task.deadline.weekday()

            if deadline_hour in active_time_slots.get("active_hours", []):
                score += 0.2
                reason = "适合您的活跃时间；" + reason

            if deadline_day in active_time_slots.get("active_days", []):
                score += 0.1

            if is_active_time:
                score += 0.1
                if "您当前活跃" not in reason:
                    reason = "您当前活跃；" + reason

            hours_until_deadline = (task.deadline - now).total_seconds() / 3600
            if hours_until_deadline < 24:
                score += 0.2
                reason = "24小时内截止；" + reason
            elif hours_until_deadline < 72:
                score += 0.1
                reason = "3天内截止；" + reason

            results[task.id] = ScoredTask(
                score=min(score, 1.0),
                reason=reason,
            )

        return results

    # ------------------------------------------------------------------
    # Active time-slot analysis
    # ------------------------------------------------------------------

    @staticmethod
    def _get_user_active_time_slots(db, user_id: str) -> Dict[str, Any]:
        """Analyse user's active hours/days from recent interactions (cached 1 h)."""
        from app.redis_cache import redis_cache
        from app.crud import get_utc_time

        cache_key = f"user_active_time_slots:{user_id}"
        try:
            cached = redis_cache.get(cache_key)
            if cached:
                if isinstance(cached, bytes):
                    cached = cached.decode("utf-8")
                return json.loads(cached)
        except Exception as e:
            logger.debug(f"读取活跃时间段缓存失败: {e}")

        try:
            from app.models import UserTaskInteraction
            from sqlalchemy import extract

            cutoff_date = get_utc_time() - timedelta(days=30)
            interactions = db.query(
                extract("hour", UserTaskInteraction.interaction_time).label("hour"),
                extract("dow", UserTaskInteraction.interaction_time).label("day_of_week"),
            ).filter(
                UserTaskInteraction.user_id == user_id,
                UserTaskInteraction.interaction_time >= cutoff_date,
            ).all()

            hour_counts: Dict[int, int] = {}
            day_counts: Dict[int, int] = {}
            for hour, dow in interactions:
                hour_counts[int(hour)] = hour_counts.get(int(hour), 0) + 1
                # PostgreSQL extract("dow"): 0=Sunday..6=Saturday
                # Python weekday(): 0=Monday..6=Sunday
                # Convert: (dow - 1) % 7 maps PG dow to Python weekday
                py_weekday = (int(dow) - 1) % 7
                day_counts[py_weekday] = day_counts.get(py_weekday, 0) + 1

            active_hours = sorted(hour_counts.items(), key=lambda x: x[1], reverse=True)[:3]
            active_days = sorted(day_counts.items(), key=lambda x: x[1], reverse=True)[:3]

            if not hour_counts:
                now = get_utc_time()
                result: Dict[str, Any] = {
                    "active_hours": [now.hour],
                    "active_days": [now.weekday()],
                    "hour_distribution": {},
                }
            else:
                result = {
                    "active_hours": [h[0] for h in active_hours],
                    "active_days": [d[0] for d in active_days],
                    "hour_distribution": hour_counts,
                }

            try:
                redis_cache.setex(cache_key, 3600, json.dumps(result, default=str))
            except Exception as e:
                logger.debug(f"缓存活跃时间段失败: {e}")

            return result
        except Exception as e:
            logger.error(f"获取用户活跃时间段失败: {e}")
            now = get_utc_time()
            return {
                "active_hours": [now.hour],
                "active_days": [now.weekday()],
                "hour_distribution": {},
            }
