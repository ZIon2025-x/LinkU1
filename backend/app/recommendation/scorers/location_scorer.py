"""Location-based recommendation scorer.

Scores tasks by GPS distance (Haversine) and city matching.
Distance scoring:
  - <= 10 km  : 1.0 - (distance / 10000)   (linear decay, minimum 0.5)
  - > 10 km   : 0.5  (same-city fallback)
  - no GPS    : 0.8  (city-match default)
  - inf dist  : 0.8  (coordinate error fallback)
"""

import json
import logging
from typing import Dict, List, Any

from sqlalchemy import desc

from ..base_scorer import BaseScorer, ScoredTask
from ..utils import haversine_distance

logger = logging.getLogger(__name__)


class LocationScorer(BaseScorer):
    """Score tasks based on geographic proximity to the user."""

    name = "location"
    default_weight = 0.10

    def score(self, user, tasks: List, context: Dict[str, Any]) -> Dict[int, ScoredTask]:
        """Score tasks by distance and city match.

        Context keys used:
            db: SQLAlchemy Session (required)
            latitude: float or None — user's current GPS latitude
            longitude: float or None — user's current GPS longitude
        """
        db = context["db"]
        user_lat = context.get("latitude")
        user_lon = context.get("longitude")

        # Gather the user's preferred locations for city-level matching
        frequent_locations = self._get_user_frequent_locations(db, user.id)
        preferred_cities = self._get_user_preferred_cities(db, user)

        # Build a set of all location keywords for quick city matching
        city_keywords: List[str] = []
        if user.residence_city:
            city_keywords.append(user.residence_city)
        city_keywords.extend(frequent_locations[:3])
        for city in preferred_cities:
            if city not in city_keywords:
                city_keywords.append(city)

        if not city_keywords and (user_lat is None or user_lon is None):
            # No location signals at all — cannot score
            return {}

        results: Dict[int, ScoredTask] = {}

        for task in tasks:
            score_val, reason = self._score_task(
                task, user_lat, user_lon, city_keywords
            )
            if score_val is not None:
                results[task.id] = ScoredTask(score=score_val, reason=reason)

        return results

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _score_task(task, user_lat, user_lon, city_keywords: List[str]):
        """Score a single task by location.

        Returns (score, reason) or (None, None) if no location match.
        """
        # Check city-level match first
        city_match = False
        if task.location and city_keywords:
            task_loc_lower = task.location.lower()
            for kw in city_keywords:
                if kw.lower() in task_loc_lower:
                    city_match = True
                    break

        # GPS distance scoring
        if user_lat is not None and user_lon is not None:
            try:
                task_lat = float(task.latitude) if task.latitude is not None else None
                task_lon = float(task.longitude) if task.longitude is not None else None

                if task_lat is not None and task_lon is not None:
                    distance = haversine_distance(user_lat, user_lon, task_lat, task_lon)

                    if distance == float('inf'):
                        # Coordinate error — fallback to city match score
                        if city_match:
                            return 0.8, "同城任务"
                        return None, None

                    # Within 10 km: linear decay from 1.0, minimum 0.5
                    score = max(0.5, 1.0 - (distance / 10000))
                    if distance < 10000:
                        reason = f"距离您{distance / 1000:.1f}km"
                    else:
                        reason = "同城任务"
                    return score, reason
                else:
                    # Task has no GPS coordinates — use city match
                    if city_match:
                        return 0.8, "同城任务"
                    return None, None
            except Exception as e:
                logger.warning(f"计算任务距离失败 (task_id={task.id}): {e}")
                if city_match:
                    return 0.8, "同城任务"
                return None, None
        else:
            # No user GPS — pure city-level matching
            if city_match:
                return 1.0, "同城任务"
            return None, None

    @staticmethod
    def _get_user_frequent_locations(db, user_id: str) -> List[str]:
        """Get user's frequently visited locations from task history (cached 30 min)."""
        from app.redis_cache import redis_cache

        cache_key = f"user_frequent_locations:{user_id}"
        try:
            cached = redis_cache.get(cache_key)
            if cached:
                if isinstance(cached, bytes):
                    cached = cached.decode('utf-8')
                return json.loads(cached)
        except Exception as e:
            logger.debug(f"读取常去地点缓存失败: {e}")

        try:
            from app.models import TaskHistory, Task
            history = db.query(TaskHistory).filter(
                TaskHistory.user_id == user_id
            ).order_by(desc(TaskHistory.timestamp)).limit(50).all()

            if not history:
                return []

            task_ids = [h.task_id for h in history[:30]]
            if not task_ids:
                return []

            locations = db.query(Task.location).filter(
                Task.id.in_(task_ids),
                Task.location.isnot(None)
            ).all()

            location_counts: Dict[str, int] = {}
            for (location,) in locations:
                if location:
                    city = location.split(',')[-1].strip() if ',' in location else location
                    location_counts[city] = location_counts.get(city, 0) + 1

            result = [
                loc for loc, count in sorted(
                    location_counts.items(), key=lambda x: x[1], reverse=True
                )[:3]
            ]

            try:
                redis_cache.setex(cache_key, 1800, json.dumps(result))
            except Exception as e:
                logger.debug(f"缓存常去地点失败: {e}")

            return result
        except Exception as e:
            logger.error(f"获取用户常去地点失败: {e}")
            return []

    @staticmethod
    def _get_user_preferred_cities(db, user) -> List[str]:
        """Get user's preferred cities from residence + explicit preferences."""
        cities: List[str] = []

        if user.residence_city:
            cities.append(user.residence_city)

        from app.models import UserProfilePreference
        preferences = db.query(UserProfilePreference).filter(
            UserProfilePreference.user_id == user.id
        ).first()

        if preferences and preferences.locations:
            try:
                preferred_locations = preferences.locations if isinstance(preferences.locations, list) else json.loads(preferences.locations)
                for loc in preferred_locations:
                    city = loc.split(',')[-1].strip() if ',' in loc else loc
                    if city not in cities:
                        cities.append(city)
            except (json.JSONDecodeError, TypeError):
                pass

        return cities[:5]
