"""Popularity-based recommendation scorer.

Scores tasks by actual popularity signals: application count and view count.
Higher engagement = higher score.

Scoring formula:
  application_score = min(1.0, application_count / 5)  weight 0.6
  view_score = min(1.0, view_count / 20)               weight 0.4
  final = application_score * 0.6 + view_score * 0.4
"""

import logging
from typing import Dict, List, Any

from sqlalchemy import func

from ..base_scorer import BaseScorer, ScoredTask

logger = logging.getLogger(__name__)


class PopularityScorer(BaseScorer):
    """Score tasks by engagement popularity (applications + views)."""

    name = "popularity"
    default_weight = 0.02

    def score(self, user, tasks: List, context: Dict[str, Any]) -> Dict[int, ScoredTask]:
        """Score tasks by application count and view interactions.

        Context keys used:
            db: SQLAlchemy Session (required)
        """
        db = context["db"]
        if not tasks:
            return {}

        task_ids = [t.id for t in tasks]

        # Batch-load application counts
        from app.models import TaskApplication, UserTaskInteraction
        app_counts = dict(
            db.query(
                TaskApplication.task_id,
                func.count(TaskApplication.id)
            ).filter(
                TaskApplication.task_id.in_(task_ids)
            ).group_by(TaskApplication.task_id).all()
        )

        # Batch-load view counts
        view_counts = dict(
            db.query(
                UserTaskInteraction.task_id,
                func.count(UserTaskInteraction.id)
            ).filter(
                UserTaskInteraction.task_id.in_(task_ids),
                UserTaskInteraction.interaction_type == "view"
            ).group_by(UserTaskInteraction.task_id).all()
        )

        results: Dict[int, ScoredTask] = {}
        for task in tasks:
            apps = app_counts.get(task.id, 0)
            views = view_counts.get(task.id, 0)

            if apps == 0 and views == 0:
                continue

            app_score = min(1.0, apps / 5)
            view_score = min(1.0, views / 20)
            final = app_score * 0.6 + view_score * 0.4

            if final > 0:
                reason = f"热门任务（{apps}人申请）" if apps > 0 else "关注度较高"
                results[task.id] = ScoredTask(score=final, reason=reason)

        return results
