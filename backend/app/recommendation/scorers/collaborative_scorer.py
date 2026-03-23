"""Collaborative filtering recommendation scorer.

Finds similar users via weighted cosine similarity on task interactions,
then recommends tasks those similar users liked (accepted/completed).

Weights: completed=1.0, accepted=0.8, view(>30s)=0.4, view=0.2, click=0.3.
Time decay: interactions older than 30 days are halved.
"""

import logging
import math
from datetime import timedelta
from typing import Dict, List, Any, Tuple, Set

from sqlalchemy import desc, func

from ..base_scorer import BaseScorer, ScoredTask

logger = logging.getLogger(__name__)

# Action weights for interaction strength (0.0 = ignore, negative actions excluded)
_ACTION_WEIGHTS = {
    "completed": 1.0,
    "auto_confirmed_3days": 0.9,
    "accepted": 0.8,
    "applied": 0.6,
    "click": 0.3,
    "view": 0.2,
    "cancelled": 0.0,
    "rejected": 0.0,
    "expired": 0.0,
}
_DEFAULT_ACTION_WEIGHT = 0.1


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

        # 1. Get user's interaction set (prefer preloaded from context)
        preloaded_history = context.get("user_task_history")
        if preloaded_history is not None:
            user_interactions = {h.task_id for h in preloaded_history}
        else:
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

        # 4. Normalize scores to [0, 1] by dividing by sum of similarities
        total_similarity = sum(sim for _, sim in similar_users) or 1.0
        for task_id in recommended_scores:
            recommended_scores[task_id] /= total_similarity

        # 5. Build results — only for tasks in the candidate list
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
        """Find top-k similar users by weighted cosine similarity.

        Uses action weights (completed > accepted > click > view) and time
        decay (>30 days halved). Single batch query for all candidates.
        """
        if not user_interactions or len(user_interactions) < 2:
            return []

        from app.models import TaskHistory
        from app.crud import get_utc_time

        now = get_utc_time()
        decay_cutoff = now - timedelta(days=30)

        # Find candidate user IDs who interacted with the same tasks (max 100)
        active_user_ids = db.query(
            func.distinct(TaskHistory.user_id)
        ).filter(
            TaskHistory.user_id != user_id,
            TaskHistory.task_id.in_(list(user_interactions))
        ).limit(100).all()

        if not active_user_ids:
            return []

        candidate_ids = [uid for (uid,) in active_user_ids]

        # Batch-load interactions with action and timestamp for weighting
        all_history = db.query(
            TaskHistory.user_id, TaskHistory.task_id,
            TaskHistory.action, TaskHistory.timestamp
        ).filter(
            TaskHistory.user_id.in_(candidate_ids)
        ).order_by(desc(TaskHistory.timestamp)).all()

        # Build weighted interaction vectors: {user_id: {task_id: weight}}
        user_vectors: Dict[str, Dict[int, float]] = {}
        user_count: Dict[str, int] = {}
        for uid, tid, action, ts in all_history:
            count = user_count.get(uid, 0)
            if count >= 50:
                continue
            user_count[uid] = count + 1

            action_weight = _ACTION_WEIGHTS.get(action, _DEFAULT_ACTION_WEIGHT)
            if action_weight <= 0:
                continue  # Skip negative signals
            # Time decay: halve weight for interactions older than 30 days
            if ts and hasattr(ts, 'tzinfo') and ts < decay_cutoff:
                action_weight *= 0.5

            if uid not in user_vectors:
                user_vectors[uid] = {}
            # Keep max weight per task (e.g., completed > viewed)
            user_vectors[uid][tid] = max(user_vectors[uid].get(tid, 0), action_weight)

        # Build user's own weighted vector (uniform weight for simplicity)
        user_vec = {tid: 1.0 for tid in user_interactions}

        similar_users: List[Tuple[str, float]] = []
        min_similarity = 0.1 if len(user_interactions) >= 5 else 0.05

        for other_user_id in candidate_ids:
            other_vec = user_vectors.get(other_user_id, {})
            if len(other_vec) < 2:
                continue

            # Cosine similarity on shared task dimensions
            shared_tasks = user_interactions & set(other_vec.keys())
            if not shared_tasks:
                continue

            dot_product = sum(user_vec.get(t, 0) * other_vec.get(t, 0) for t in shared_tasks)
            norm_a = math.sqrt(sum(v ** 2 for v in user_vec.values()))
            norm_b = math.sqrt(sum(v ** 2 for v in other_vec.values()))

            if norm_a > 0 and norm_b > 0:
                similarity = dot_product / (norm_a * norm_b)
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
