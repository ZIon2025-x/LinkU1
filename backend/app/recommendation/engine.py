"""HybridEngine: orchestrates all scorers and aggregates results."""
import logging
from typing import List, Dict, Any, Optional

from .scorer_registry import ScorerRegistry

logger = logging.getLogger(__name__)


class HybridEngine:
    def __init__(self, registry: ScorerRegistry):
        self.registry = registry

    def recommend(self, user, limit: int = 20, context: Optional[Dict[str, Any]] = None,
                  filters: Optional[Dict[str, Any]] = None) -> List[Dict]:
        context = context or {}
        filters = filters or {}

        candidate_tasks = self._get_candidates(user, filters, context)
        if not candidate_tasks:
            return []

        # Pre-compute interaction count for dynamic weight scorers (e.g. DemandScorer)
        self._enrich_user_context(user, context)

        weights = self.registry.normalize_weights(user, context=context)
        aggregated: Dict[int, Dict] = {}
        task_map = {t.id: t for t in candidate_tasks}

        for scorer in self.registry.get_active_scorers():
            weight = weights.get(scorer.name, 0)
            if weight <= 0:
                continue
            try:
                results = scorer.score(user, candidate_tasks, context)
                for task_id, scored in results.items():
                    if task_id not in aggregated:
                        aggregated[task_id] = {"score": 0.0, "reasons": []}
                    aggregated[task_id]["score"] += scored.clamped_score * weight
                    if scored.reason:
                        aggregated[task_id]["reasons"].append(scored.reason)
            except Exception as e:
                logger.error(f"Scorer {scorer.name} failed: {e}", exc_info=True)
                continue

        ranked = sorted(aggregated.items(), key=lambda x: x[1]["score"], reverse=True)
        return [
            {"task_id": task_id, "score": round(data["score"], 4),
             "reasons": data["reasons"], "task": task_map.get(task_id)}
            for task_id, data in ranked[:limit]
            if task_map.get(task_id) is not None
        ]

    def _enrich_user_context(self, user, context: Dict) -> None:
        """Pre-compute shared data to avoid duplicate queries across scorers.

        Loads into context:
            _interaction_count: int — for DemandScorer dynamic weight
            user_preferences: UserProfilePreference — shared by Content/Location/Profile scorers
            user_task_history: List[TaskHistory] — shared by Content/Collab scorers
        """
        if not user:
            return
        db = context.get("db")
        if not db:
            return

        # 1. Interaction count (for DemandScorer dynamic weight)
        try:
            from app.models import UserTaskInteraction
            count = db.query(UserTaskInteraction).filter(
                UserTaskInteraction.user_id == user.id
            ).count()
            context["_interaction_count"] = count
        except Exception as e:
            logger.debug(f"Failed to load interaction count: {e}")

        # 2. UserProfilePreference (shared by Content, Location, Profile scorers)
        try:
            from app.models import UserProfilePreference
            context["user_preferences"] = db.query(UserProfilePreference).filter(
                UserProfilePreference.user_id == user.id
            ).first()
        except Exception as e:
            logger.debug(f"Failed to load user preferences: {e}")

        # 3. TaskHistory (shared by Content, Collaborative scorers)
        try:
            from app.models import TaskHistory
            from sqlalchemy import desc
            context["user_task_history"] = db.query(TaskHistory).filter(
                TaskHistory.user_id == user.id
            ).order_by(desc(TaskHistory.timestamp)).limit(50).all()
        except Exception as e:
            logger.debug(f"Failed to load task history: {e}")

    def _get_candidates(self, user, filters: Dict, context: Dict) -> List:
        db = context.get("db")
        if not db:
            return []
        from app.models import Task
        from app.crud import get_utc_time
        from sqlalchemy.orm import load_only
        query = db.query(Task).options(
            load_only(
                Task.id, Task.task_type, Task.status, Task.is_visible,
                Task.location, Task.reward, Task.base_reward, Task.agreed_reward,
                Task.reward_to_be_quoted, Task.deadline, Task.created_at,
                Task.poster_id, Task.taker_id, Task.title, Task.title_en, Task.title_zh,
                Task.description, Task.description_en, Task.description_zh,
                Task.latitude, Task.longitude, Task.is_flexible,
                Task.task_level, Task.images,
            )
        ).filter(
            Task.status == "open", Task.is_visible == True, Task.deadline > get_utc_time()
        )
        # Exclude user's own tasks
        if user:
            from .utils import get_excluded_task_ids
            excluded = get_excluded_task_ids(db, user.id)
            if excluded:
                query = query.filter(~Task.id.in_(excluded))
        if filters.get("task_type"):
            query = query.filter(Task.task_type == filters["task_type"])
        if filters.get("location"):
            query = query.filter(Task.location.ilike(f"%{filters['location']}%"))
        if filters.get("keyword"):
            kw = f"%{filters['keyword']}%"
            query = query.filter(
                (Task.title.ilike(kw)) | (Task.description.ilike(kw)) |
                (Task.title_zh.ilike(kw)) | (Task.title_en.ilike(kw))
            )
        return query.order_by(Task.created_at.desc()).limit(500).all()
