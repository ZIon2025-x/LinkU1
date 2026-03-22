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

        weights = self.registry.normalize_weights(user)
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
        """Pre-compute data needed by scorers for dynamic weight calculation."""
        if not user:
            return
        db = context.get("db")
        if not db:
            return
        try:
            from app.models import UserTaskInteraction
            count = db.query(UserTaskInteraction).filter(
                UserTaskInteraction.user_id == user.id
            ).count()
            user._interaction_count = count
        except Exception:
            pass

    def _get_candidates(self, user, filters: Dict, context: Dict) -> List:
        db = context.get("db")
        if not db:
            return []
        from app.models import Task
        from app.crud import get_utc_time
        query = db.query(Task).filter(
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
