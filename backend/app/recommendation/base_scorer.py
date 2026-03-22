from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Dict, List, Any


@dataclass
class ScoredTask:
    """A task with a relevance score and human-readable reason."""
    score: float        # 0.0 - 1.0 (raw, may exceed bounds)
    reason: str         # Human-readable recommendation reason

    @property
    def clamped_score(self) -> float:
        """Score clamped to [0.0, 1.0]."""
        return max(0.0, min(1.0, self.score))


class BaseScorer(ABC):
    """Abstract base class for all recommendation scorers."""
    name: str
    default_weight: float

    @abstractmethod
    def score(self, user, tasks: List, context: Dict[str, Any]) -> Dict[int, ScoredTask]:
        """Score tasks for a user.

        Args:
            user: SQLAlchemy User object
            tasks: List of candidate Task objects
            context: Shared context dict (db session, caches, GPS coords, etc.)

        Returns:
            Dict mapping task_id -> ScoredTask for relevant tasks.
            Tasks not in the dict receive score 0.
        """

    def get_weight(self, user) -> float:
        """Return this scorer's weight for the given user.

        Override in subclasses for dynamic weight adjustment (e.g., demand_scorer).
        """
        return self.default_weight
