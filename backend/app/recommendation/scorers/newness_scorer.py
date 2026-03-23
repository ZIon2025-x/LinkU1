"""Newness-based recommendation scorer.

Boosts recently created tasks with a linear time-decay score:
  score = max(0, 1.0 - hours_old / 24)

Tasks posted by new users (registered <= 7 days) receive an additional +0.3
boost (capped at 1.0).

Dynamic weight: 0.15 for new users, 0.10 for established users.
"""

import logging
from datetime import timedelta
from typing import Dict, List, Any, Set

from ..base_scorer import BaseScorer, ScoredTask
from ..utils import is_new_user

logger = logging.getLogger(__name__)


class NewnessScorer(BaseScorer):
    """Score new tasks with time-decay, extra boost for new-user posters."""

    name = "newness"
    default_weight = 0.10

    def get_weight(self, user, context=None) -> float:
        """New users get higher newness weight (0.15 vs 0.10)."""
        return 0.15 if is_new_user(user) else self.default_weight

    def score(self, user, tasks: List, context: Dict[str, Any]) -> Dict[int, ScoredTask]:
        """Score tasks by recency and new-user poster status.

        Context keys used:
            db: SQLAlchemy Session (required)
        """
        db = context["db"]
        from app.crud import get_utc_time
        from app.models import User as UserModel

        now = get_utc_time()
        recent_cutoff = now - timedelta(hours=24)

        # Filter to recent tasks first
        recent_tasks = [t for t in tasks if t.created_at and t.created_at >= recent_cutoff]
        if not recent_tasks:
            return {}

        # Batch-load all unique poster Users in ONE query (eliminates N+1)
        poster_ids: Set[str] = {t.poster_id for t in recent_tasks if t.poster_id}
        if poster_ids:
            posters = db.query(UserModel).filter(UserModel.id.in_(list(poster_ids))).all()
            poster_map = {p.id: p for p in posters}
        else:
            poster_map = {}

        results: Dict[int, ScoredTask] = {}

        for task in recent_tasks:
            hours_old = (now - task.created_at).total_seconds() / 3600
            time_score = max(0.0, 1.0 - (hours_old / 24))

            # Check if poster is a new user (from pre-loaded map)
            poster = poster_map.get(task.poster_id)
            is_poster_new = is_new_user(poster) if poster else False

            if is_poster_new:
                final_score = min(1.0, time_score + 0.3)
                reason = "新用户发布，优先推荐"
            else:
                final_score = time_score
                reason = "新发布任务"

            results[task.id] = ScoredTask(score=final_score, reason=reason)

        return results
