"""AI demand prediction matching scorer."""
import logging
from typing import Dict, List, Any
from ..base_scorer import BaseScorer, ScoredTask

logger = logging.getLogger(__name__)

class DemandScorer(BaseScorer):
    name = "demand"
    default_weight = 0.12

    def get_weight(self, user) -> float:
        count = getattr(user, '_interaction_count', None)
        if count is None:
            return self.default_weight
        if count < 10:
            return 0.20
        elif count < 50:
            return 0.12
        else:
            return 0.05

    def score(self, user, tasks: List, context: Dict[str, Any]) -> Dict[int, ScoredTask]:
        db = context["db"]
        from app.models import UserDemand, UserTaskInteraction
        demand = db.query(UserDemand).filter_by(user_id=user.id).first()
        if not demand:
            return {}
        try:
            count = db.query(UserTaskInteraction).filter(UserTaskInteraction.user_id == user.id).count()
            user._interaction_count = count
        except Exception:
            pass
        results = {}
        for task in tasks:
            score, reasons = self._score_task(demand, task)
            if score > 0:
                results[task.id] = ScoredTask(score=min(1.0, score), reason="；".join(reasons) if reasons else "AI预测匹配")
        return results

    def _score_task(self, demand, task) -> tuple:
        score = 0.0
        reasons = []
        # 1. Predicted needs (0.35)
        predicted = demand.predicted_needs or []
        if isinstance(predicted, dict):
            predicted = list(predicted.keys())
        if predicted and task.task_type in predicted:
            score += 0.35
            reasons.append("匹配您的预测需求")
        # 2. Inferred skills (0.30)
        skills = demand.inferred_skills or {}
        if isinstance(skills, list):
            skills = {s: 1.0 for s in skills}
        if skills:
            task_text = f"{task.task_type} {task.title or ''} {task.description or ''}".lower()
            matched_skills = [s for s in skills if s.lower() in task_text]
            if matched_skills:
                max_conf = max(skills.get(s, 0.5) for s in matched_skills)
                score += 0.30 * min(1.0, max_conf)
                reasons.append(f"匹配您的技能：{', '.join(matched_skills[:2])}")
        # 3. Inferred preferences (0.20)
        inf_prefs = demand.inferred_preferences or {}
        if inf_prefs:
            pref_cats = inf_prefs.get("categories", [])
            if task.task_type in pref_cats:
                score += 0.20
        # 4. Recent interests (0.15)
        interests = demand.recent_interests or {}
        if isinstance(interests, list):
            interests = {i: 1.0 for i in interests}
        if interests:
            task_text = f"{task.task_type} {task.title or ''} {task.description or ''}".lower()
            matched = [k for k in interests if k.lower() in task_text]
            if matched:
                score += 0.15
                reasons.append("匹配您的近期兴趣")
        return score, reasons
