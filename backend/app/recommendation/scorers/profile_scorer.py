"""Profile preference matching scorer."""
import logging
from typing import Dict, List, Any
from ..base_scorer import BaseScorer, ScoredTask

logger = logging.getLogger(__name__)

class ProfileScorer(BaseScorer):
    name = "profile"
    default_weight = 0.10

    def score(self, user, tasks: List, context: Dict[str, Any]) -> Dict[int, ScoredTask]:
        db = context["db"]
        from app.models import UserProfilePreference
        pref = db.query(UserProfilePreference).filter_by(user_id=user.id).first()
        if not pref:
            return {}
        results = {}
        for task in tasks:
            score, reasons = self._score_task(pref, task)
            if score > 0:
                results[task.id] = ScoredTask(score=min(1.0, score), reason="；".join(reasons) if reasons else "画像匹配")
        return results

    def _score_task(self, pref, task) -> tuple:
        score = 0.0
        reasons = []
        # 1. Mode matching (0.10)
        mode = getattr(pref.mode, 'value', pref.mode) if pref.mode else "both"
        if mode == "both":
            score += 0.10
        else:
            task_is_online = not task.location or task.location.strip() == ""
            if (mode == "online" and task_is_online) or (mode == "offline" and not task_is_online):
                score += 0.10
                reasons.append("匹配您的协作方式偏好")
        # 2. Duration type (0.10)
        dur = getattr(pref.duration_type, 'value', pref.duration_type) if pref.duration_type else "both"
        if dur == "both":
            score += 0.10
        else:
            is_flexible = getattr(task, 'is_flexible', None)
            task_is_long = bool(is_flexible) if is_flexible is not None else False
            if (dur == "long_term" and task_is_long) or (dur == "one_time" and not task_is_long):
                score += 0.10
        # 3. Time slots (0.20)
        slots = pref.preferred_time_slots or []
        if not slots or "anytime" in slots:
            score += 0.20
        elif task.deadline:
            hour = task.deadline.hour
            weekday = task.deadline.weekday()
            matched = False
            if "weekday_daytime" in slots and weekday < 5 and 8 <= hour < 18:
                matched = True
            if "weekday_evening" in slots and weekday < 5 and hour >= 18:
                matched = True
            if "weekend" in slots and weekday >= 5:
                matched = True
            if matched:
                score += 0.20
                reasons.append("匹配您的可用时段")
        # 4. Categories (0.30)
        categories = pref.preferred_categories or []
        if not categories:
            score += 0.15
        elif task.task_type in categories:
            score += 0.30
            reasons.append("匹配您偏好的任务类型")
        # 5. Reward (0.15)
        rew = getattr(pref.reward_preference, 'value', pref.reward_preference) if pref.reward_preference else "no_preference"
        if rew == "no_preference":
            score += 0.15
        else:
            reward = float(task.reward or 0)
            if rew == "high_freq_low_amount" and reward <= 3000:
                score += 0.15
                reasons.append("匹配您的报酬偏好")
            elif rew == "low_freq_high_amount" and reward > 3000:
                score += 0.15
                reasons.append("匹配您的报酬偏好")
        # 6. City (0.15)
        if not pref.city:
            score += 0.075
        elif task.location and pref.city.lower() in task.location.lower():
            score += 0.15
            reasons.append("位于您所在的城市")
        return score, reasons
