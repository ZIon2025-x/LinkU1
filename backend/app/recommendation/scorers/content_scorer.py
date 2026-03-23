"""Content-based recommendation scorer.

Scores tasks by matching user preference vector against task attributes:
  task_type (0.30), location (0.25), price (0.20), level (0.15), keywords (0.10).
"""

import logging
from typing import Dict, List, Any

from ..base_scorer import BaseScorer, ScoredTask
from ..user_vector import (
    build_user_preference_vector,
    get_default_preference_vector,
    get_user_preferences,
    get_user_task_history,
    get_user_view_history,
    get_user_search_keywords,
    get_user_skipped_tasks,
)

logger = logging.getLogger(__name__)


class ContentScorer(BaseScorer):
    """Score tasks based on content similarity to user preferences."""

    name = "content"
    default_weight = 0.30

    def score(self, user, tasks: List, context: Dict[str, Any]) -> Dict[int, ScoredTask]:
        """Score each candidate task against the user's preference vector.

        Context keys used:
            db: SQLAlchemy Session (required)
            user_vector: pre-built preference vector (optional, avoids rebuild)
        """
        db = context["db"]

        # Use pre-built vector if available, otherwise build one
        user_vector = context.get("user_vector")
        if user_vector is None:
            # Prefer engine-preloaded data from context, fall back to own queries
            # Use `in` check (not truthiness) — None/[] are valid preloaded results
            preferences = context["user_preferences"] if "user_preferences" in context else get_user_preferences(db, user.id)
            history = context["user_task_history"] if "user_task_history" in context else get_user_task_history(db, user.id)
            view_history = get_user_view_history(db, user.id)
            search_keywords = get_user_search_keywords(db, user.id)
            skipped_tasks = get_user_skipped_tasks(db, user.id)

            user_vector = build_user_preference_vector(
                db, user, preferences, history,
                view_history=view_history,
                search_keywords=search_keywords,
                skipped_tasks=skipped_tasks,
            )

            # Cold-start: no history and no preferences -> use defaults
            if not history and not preferences:
                user_vector = get_default_preference_vector(user)

        results: Dict[int, ScoredTask] = {}
        for task in tasks:
            content_score = self._calculate_content_match(user_vector, task)
            if content_score > 0:
                reason = self._build_reason(user_vector, task, content_score)
                results[task.id] = ScoredTask(score=content_score, reason=reason)

        return results

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _calculate_content_match(user_vector: Dict, task) -> float:
        """Calculate content match score using the weighted formula.

        Weights:
            task_type  : 0.30
            location   : 0.25
            price      : 0.20
            level      : 0.15
            keywords   : 0.10
        """
        score = 0.0
        is_negative = False

        # Negative feedback: penalise disliked task types
        if "negative_task_types" in user_vector:
            if task.task_type in user_vector["negative_task_types"]:
                is_negative = True

        # 1. Task type match (0.30)
        if user_vector["task_types"] and task.task_type in user_vector["task_types"]:
            score += 0.3

        # 2. Location match (0.25)
        if user_vector["locations"] and task.location:
            for loc in user_vector["locations"]:
                if loc.lower() in task.location.lower() or task.location.lower() in loc.lower():
                    score += 0.25
                    break

        # 3. Price match (0.20)
        if task.reward:
            price = float(task.reward)
            price_range = user_vector["price_range"]
            if price_range["min"] <= price <= price_range["max"]:
                score += 0.2

        # 4. Task level match (0.15)
        if user_vector["task_levels"] and getattr(task, "task_level", None) in user_vector["task_levels"]:
            score += 0.15

        # 5. Keyword match (0.10)
        if user_vector["keywords"]:
            task_text = f"{task.title or ''} {task.description or ''}".lower()
            matched_keywords = sum(
                1 for keyword in user_vector["keywords"]
                if keyword.lower() in task_text
            )
            if matched_keywords > 0:
                score += 0.1 * min(matched_keywords / len(user_vector["keywords"]), 1.0)

        # Apply negative feedback damper: strongly reduce score for disliked types
        if is_negative:
            score *= 0.15

        return min(score, 1.0)

    @staticmethod
    def _build_reason(user_vector: Dict, task, score: float) -> str:
        """Generate a human-readable recommendation reason."""
        reasons: List[str] = []

        if user_vector["task_types"] and task.task_type in user_vector["task_types"]:
            if user_vector.get("task_types_from_preference"):
                reasons.append(f"符合您的兴趣偏好({task.task_type})")
            else:
                reasons.append(f"您常参与{task.task_type}类任务")

        if user_vector["locations"] and task.location:
            for loc in user_vector["locations"]:
                if loc.lower() in task.location.lower() or task.location.lower() in loc.lower():
                    reasons.append(f"位于{loc}")
                    break

        if task.reward:
            price = float(task.reward)
            price_range = user_vector["price_range"]
            if price_range["min"] <= price <= price_range["max"] and user_vector.get("price_range_from_history"):
                reasons.append("价格在您的偏好范围内")

        if not reasons:
            reasons.append("为您推荐" if score >= 0.5 else "可能适合您")

        return "；".join(reasons)
