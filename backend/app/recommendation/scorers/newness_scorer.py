"""Newness-based recommendation scorer.

Boosts recently created tasks with a linear time-decay score:
  score = max(0, 1.0 - hours_old / 24)

Tasks posted by new users (registered <= 7 days) receive an additional +0.3
boost (capped at 1.0).

Dynamic weight: 0.15 for new users, 0.10 for established users.
"""

import logging
from datetime import timedelta
from typing import Dict, List, Any

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

        # Cache poster new-user status to avoid N+1 queries
        poster_new_cache: Dict[str, bool] = {}

        results: Dict[int, ScoredTask] = {}

        for task in tasks:
            if not task.created_at or task.created_at < recent_cutoff:
                continue

            hours_old = (now - task.created_at).total_seconds() / 3600
            time_score = max(0.0, 1.0 - (hours_old / 24))

            # Check if poster is a new user
            is_poster_new = self._is_new_user_task(
                db, task, poster_new_cache
            )

            if is_poster_new:
                final_score = min(1.0, time_score + 0.3)
                reason = "新用户发布，优先推荐"
            else:
                final_score = time_score
                reason = "新发布任务"

            results[task.id] = ScoredTask(score=final_score, reason=reason)

        return results

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _is_new_user_task(
        db, task, cache: Dict[str, bool]
    ) -> bool:
        """Check if a task was posted by a new user (registered <= 7 days)
        and the task itself was created within 24 hours."""
        from app.models import User as UserModel

        if not task.poster_id or not task.created_at:
            return False

        # Note: 24h recency check already done by caller (score() filters
        # tasks with created_at < recent_cutoff before calling this method)

        poster_id = task.poster_id
        if poster_id in cache:
            return cache[poster_id]

        poster = db.query(UserModel).filter(UserModel.id == poster_id).first()
        if not poster:
            cache[poster_id] = False
            return False

        result = is_new_user(poster)
        cache[poster_id] = result
        return result
