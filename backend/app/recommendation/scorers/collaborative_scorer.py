"""Collaborative filtering recommendation scorer.

Finds similar users via Jaccard similarity on task interaction overlap,
then recommends tasks those similar users liked (accepted/completed).
"""

import logging
from typing import Dict, List, Any, Tuple, Set

from sqlalchemy import desc, func

from ..base_scorer import BaseScorer, ScoredTask

logger = logging.getLogger(__name__)


class CollaborativeScorer(BaseScorer):
    """Score tasks using user-based collaborative filtering."""

    name = "collaborative"
    default_weight = 0.25

    # Minimum interactions needed before collaborative filtering is useful
    MIN_INTERACTIONS = 3

    def score(self, user, tasks: List, context: Dict[str, Any]) -> Dict[int, ScoredTask]:
        """Score tasks based on similar users' preferences.

        Context keys used:
            db: SQLAlchemy Session (required)

        Returns empty dict if the user has fewer than MIN_INTERACTIONS.
        """
        db = context["db"]

        # 1. Get user's interaction set
        user_interactions = self._get_user_interactions(db, user.id)

        if len(user_interactions) < self.MIN_INTERACTIONS:
            return {}

        # 2. Find similar users via Jaccard similarity
        similar_users = self._find_similar_users(db, user.id, user_interactions, k=10)
        if not similar_users:
            return {}

        # 3. Collect tasks liked by similar users (weighted by similarity)
        recommended_scores: Dict[int, float] = {}

        # Try batch helper first, fall back to per-user queries
        try:
            from app.recommendation_performance import batch_get_user_liked_tasks
            similar_user_ids = [uid for uid, _ in similar_users]
            user_liked_map = batch_get_user_liked_tasks(db, similar_user_ids)

            for similar_user_id, similarity in similar_users:
                liked_tasks = user_liked_map.get(similar_user_id, set())
                for task_id in liked_tasks:
                    if task_id not in user_interactions:
                        recommended_scores[task_id] = recommended_scores.get(task_id, 0.0) + similarity
        except ImportError:
            for similar_user_id, similarity in similar_users:
                liked_tasks = self._get_user_liked_tasks(db, similar_user_id)
                for task_id in liked_tasks:
                    if task_id not in user_interactions:
                        recommended_scores[task_id] = recommended_scores.get(task_id, 0.0) + similarity

        # 4. Build results — only for tasks in the candidate list
        results: Dict[int, ScoredTask] = {}

        for task in tasks:
            if task.id in recommended_scores:
                results[task.id] = ScoredTask(
                    score=recommended_scores[task.id],
                    reason="相似用户也喜欢这类任务",
                )

        return results

    # ------------------------------------------------------------------
    # Internal helpers (extracted verbatim from monolith)
    # ------------------------------------------------------------------

    @staticmethod
    def _get_user_interactions(db, user_id: str) -> Set[int]:
        """Get the set of task IDs the user has interacted with."""
        from app.models import TaskHistory
        history = db.query(TaskHistory).filter(
            TaskHistory.user_id == user_id
        ).order_by(desc(TaskHistory.timestamp)).limit(50).all()
        return {h.task_id for h in history}

    @staticmethod
    def _find_similar_users(
        db, user_id: str, user_interactions: Set[int], k: int = 10
    ) -> List[Tuple[str, float]]:
        """Find top-k similar users by Jaccard similarity on interactions.

        Uses a single batch query to load all candidate users' interactions
        instead of N+1 per-user queries.
        """
        if not user_interactions or len(user_interactions) < 2:
            return []

        from app.models import TaskHistory

        # Find candidate user IDs who interacted with the same tasks (max 100)
        # Uses TaskHistory (same source as _get_user_interactions) for consistency
        active_user_ids = db.query(
            func.distinct(TaskHistory.user_id)
        ).filter(
            TaskHistory.user_id != user_id,
            TaskHistory.task_id.in_(list(user_interactions))
        ).limit(100).all()

        if not active_user_ids:
            return []

        candidate_ids = [uid for (uid,) in active_user_ids]

        # Batch-load all interactions for candidate users in ONE query
        all_history = db.query(
            TaskHistory.user_id, TaskHistory.task_id
        ).filter(
            TaskHistory.user_id.in_(candidate_ids)
        ).order_by(desc(TaskHistory.timestamp)).all()

        # Group by user_id (limit to 50 per user, matching _get_user_interactions)
        user_interaction_map: Dict[str, Set[int]] = {}
        user_count: Dict[str, int] = {}
        for uid, tid in all_history:
            count = user_count.get(uid, 0)
            if count >= 50:
                continue
            user_count[uid] = count + 1
            if uid not in user_interaction_map:
                user_interaction_map[uid] = set()
            user_interaction_map[uid].add(tid)

        similar_users: List[Tuple[str, float]] = []
        min_similarity = 0.1 if len(user_interactions) >= 5 else 0.05

        for other_user_id in candidate_ids:
            other_interactions = user_interaction_map.get(other_user_id, set())
            if len(other_interactions) < 2:
                continue

            # Jaccard similarity
            intersection = len(user_interactions & other_interactions)
            union = len(user_interactions | other_interactions)

            if union > 0:
                similarity = intersection / union
                if similarity > min_similarity:
                    similar_users.append((other_user_id, similarity))

        similar_users.sort(key=lambda x: x[1], reverse=True)
        return similar_users[:k]

    @staticmethod
    def _get_user_liked_tasks(db, user_id: str) -> Set[int]:
        """Get tasks a user accepted or completed (positive signal)."""
        from app.models import TaskHistory
        history = db.query(TaskHistory).filter(
            TaskHistory.user_id == user_id,
            TaskHistory.action.in_(["accepted", "completed"])
        ).order_by(desc(TaskHistory.timestamp)).limit(100).all()
        return {h.task_id for h in history}
