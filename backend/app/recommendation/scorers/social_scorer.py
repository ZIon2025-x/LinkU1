"""Social-based recommendation scorer.

Scores tasks from socially relevant users via three sub-strategies:
  1. School users  — same university via StudentVerification (weight 0.4, score 0.9)
  2. High-rated    — avg_rating >= 4.5, completed >= 5  (weight 0.3, score 0.85)
  3. Local rated   — same city, rating >= 4.0, completed >= 3 (weight 0.3, score 0.9)

Sub-strategy scores are additively combined (one task may match multiple).
"""

import logging
from typing import Dict, List, Any

from sqlalchemy import desc

from ..base_scorer import BaseScorer, ScoredTask

logger = logging.getLogger(__name__)


class SocialScorer(BaseScorer):
    """Score tasks from socially trustworthy users."""

    name = "social"
    default_weight = 0.15

    def score(self, user, tasks: List, context: Dict[str, Any]) -> Dict[int, ScoredTask]:
        """Score candidate tasks using three social sub-strategies.

        Context keys used:
            db: SQLAlchemy Session (required)
        """
        db = context["db"]

        # Build a set of candidate task IDs for fast membership check
        candidate_ids = {t.id for t in tasks}
        if not candidate_ids:
            return {}

        scored: Dict[int, float] = {}
        reasons: Dict[int, str] = {}

        # 1. School users (weight 0.4)
        for item in self._get_school_user_tasks(db, user, candidate_ids):
            tid = item["task_id"]
            scored[tid] = scored.get(tid, 0) + item["score"] * 0.4
            reasons.setdefault(tid, item["reason"])

        # 2. High-rated users (weight 0.3)
        for item in self._get_high_rated_user_tasks(db, user, candidate_ids):
            tid = item["task_id"]
            scored[tid] = scored.get(tid, 0) + item["score"] * 0.3
            reasons.setdefault(tid, item["reason"])

        # 3. Local high-rated users (weight 0.3)
        for item in self._get_local_high_rated_user_tasks(db, user, candidate_ids):
            tid = item["task_id"]
            scored[tid] = scored.get(tid, 0) + item["score"] * 0.3
            reasons.setdefault(tid, item["reason"])

        results: Dict[int, ScoredTask] = {}
        for tid, raw_score in scored.items():
            results[tid] = ScoredTask(
                score=min(raw_score, 1.0),
                reason=reasons.get(tid, "社交关系推荐"),
            )
        return results

    # ------------------------------------------------------------------
    # Sub-strategy helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _get_school_user_tasks(
        db, user, candidate_ids: set
    ) -> List[Dict[str, Any]]:
        """Find candidate tasks posted by same-university users."""
        from app.models import StudentVerification, Task

        user_verification = db.query(StudentVerification).filter(
            StudentVerification.user_id == user.id,
            StudentVerification.status == "approved",
        ).first()

        if not user_verification or not user_verification.university_id:
            return []

        school_user_ids = [
            uid
            for (uid,) in db.query(StudentVerification.user_id).filter(
                StudentVerification.university_id == user_verification.university_id,
                StudentVerification.user_id != user.id,
                StudentVerification.status == "approved",
            ).limit(50).all()
        ]
        if not school_user_ids:
            return []

        tasks = db.query(Task).filter(
            Task.id.in_(candidate_ids),
            Task.poster_id.in_(school_user_ids),
        ).all()

        return [
            {"task_id": t.id, "score": 0.9, "reason": "同校用户发布"}
            for t in tasks
        ]

    @staticmethod
    def _get_high_rated_user_tasks(
        db, user, candidate_ids: set
    ) -> List[Dict[str, Any]]:
        """Find candidate tasks posted by high-rated users."""
        from app.models import User as UserModel, Task

        high_rated_user_ids = [
            u.id
            for u in db.query(UserModel).filter(
                UserModel.avg_rating >= 4.5,
                UserModel.completed_task_count >= 5,
                UserModel.id != user.id,
            ).order_by(desc(UserModel.avg_rating)).limit(30).all()
        ]
        if not high_rated_user_ids:
            return []

        tasks = db.query(Task).filter(
            Task.id.in_(candidate_ids),
            Task.poster_id.in_(high_rated_user_ids),
        ).all()

        return [
            {"task_id": t.id, "score": 0.85, "reason": "高评分用户发布"}
            for t in tasks
        ]

    @staticmethod
    def _get_local_high_rated_user_tasks(
        db, user, candidate_ids: set
    ) -> List[Dict[str, Any]]:
        """Find candidate tasks posted by same-city high-rated users."""
        from app.models import User as UserModel, Task

        if not user.residence_city:
            return []

        local_user_ids = [
            u.id
            for u in db.query(UserModel).filter(
                UserModel.residence_city == user.residence_city,
                UserModel.avg_rating >= 4.0,
                UserModel.completed_task_count >= 3,
                UserModel.id != user.id,
            ).order_by(desc(UserModel.avg_rating)).limit(20).all()
        ]
        if not local_user_ids:
            return []

        tasks = db.query(Task).filter(
            Task.id.in_(candidate_ids),
            Task.poster_id.in_(local_user_ids),
            Task.location.ilike(f"%{user.residence_city}%"),
        ).all()

        return [
            {"task_id": t.id, "score": 0.9, "reason": "同城高评分用户发布"}
            for t in tasks
        ]
