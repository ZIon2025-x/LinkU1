import logging
from typing import Dict, List, Optional

from .base_scorer import BaseScorer

logger = logging.getLogger(__name__)


class ScorerRegistry:
    """Manages scorer registration and weight normalization."""

    def __init__(self):
        self._scorers: Dict[str, BaseScorer] = {}

    def register(self, scorer: BaseScorer) -> None:
        """Register a scorer instance. Raises ValueError on duplicate name."""
        if scorer.name in self._scorers:
            raise ValueError(f"Scorer '{scorer.name}' already registered")
        self._scorers[scorer.name] = scorer
        logger.info(f"Registered scorer: {scorer.name} (default_weight={scorer.default_weight})")

    def get_active_scorers(self) -> List[BaseScorer]:
        """Return all registered scorers."""
        return list(self._scorers.values())

    def get_scorer(self, name: str) -> Optional[BaseScorer]:
        """Get a scorer by name."""
        return self._scorers.get(name)

    def normalize_weights(self, user, context=None) -> Dict[str, float]:
        """Get weights for all scorers, normalized to sum to 1.0.

        Calls each scorer's get_weight(user, context) for dynamic adjustment,
        then scales proportionally.
        """
        raw_weights = {}
        for name, scorer in self._scorers.items():
            raw_weights[name] = scorer.get_weight(user, context=context)

        total = sum(raw_weights.values())
        if total <= 0:
            return {name: 0.0 for name in raw_weights}

        return {name: w / total for name, w in raw_weights.items()}
