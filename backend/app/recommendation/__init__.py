"""Task recommendation engine with pluggable scorer architecture."""
from .engine import HybridEngine
from .scorer_registry import ScorerRegistry
from .base_scorer import BaseScorer, ScoredTask


def create_engine() -> HybridEngine:
    """Create and configure the recommendation engine with all scorers."""
    from .scorers.content_scorer import ContentScorer
    from .scorers.collaborative_scorer import CollaborativeScorer
    from .scorers.location_scorer import LocationScorer
    from .scorers.social_scorer import SocialScorer
    from .scorers.time_scorer import TimeScorer
    from .scorers.popularity_scorer import PopularityScorer
    from .scorers.newness_scorer import NewnessScorer
    from .scorers.profile_scorer import ProfileScorer
    from .scorers.demand_scorer import DemandScorer

    registry = ScorerRegistry()
    registry.register(ContentScorer())
    registry.register(CollaborativeScorer())
    registry.register(LocationScorer())
    registry.register(SocialScorer())
    registry.register(TimeScorer())
    registry.register(PopularityScorer())
    registry.register(NewnessScorer())
    registry.register(ProfileScorer())
    registry.register(DemandScorer())

    return HybridEngine(registry=registry)
