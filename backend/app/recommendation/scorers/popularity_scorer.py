"""Popularity-based recommendation scorer.

Assigns a fixed score of 0.8 to tasks created within the last 24 hours.
"""

import logging
from datetime import timedelta
from typing import Dict, List, Any

from ..base_scorer import BaseScorer, ScoredTask

logger = logging.getLogger(__name__)


class PopularityScorer(BaseScorer):
    """Score recent tasks as popular."""

    name = "popularity"
    default_weight = 0.02

    def score(self, user, tasks: List, context: Dict[str, Any]) -> Dict[int, ScoredTask]:
        """Give a fixed 0.8 score to tasks created in the last 24 hours.

        Context keys used:
            db: SQLAlchemy Session (required — unused here but kept for interface)
        """
        from app.crud import get_utc_time

        recent_cutoff = get_utc_time() - timedelta(hours=24)

        results: Dict[int, ScoredTask] = {}
        for task in tasks:
            if task.created_at and task.created_at >= recent_cutoff:
                results[task.id] = ScoredTask(score=0.8, reason="热门任务")

        return results
