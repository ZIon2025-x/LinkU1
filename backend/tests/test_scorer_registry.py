import pytest
from app.recommendation.base_scorer import BaseScorer, ScoredTask
from app.recommendation.scorer_registry import ScorerRegistry


class MockScorerA(BaseScorer):
    name = "scorer_a"
    default_weight = 0.6
    def score(self, user, tasks, context):
        return {}


class MockScorerB(BaseScorer):
    name = "scorer_b"
    default_weight = 0.4
    def score(self, user, tasks, context):
        return {}


class DynamicScorer(BaseScorer):
    name = "dynamic"
    default_weight = 0.2
    def get_weight(self, user, context=None):
        if user and getattr(user, "interaction_count", 0) > 50:
            return 0.05
        return 0.20
    def score(self, user, tasks, context):
        return {}


def test_register_and_get_scorers():
    reg = ScorerRegistry()
    a = MockScorerA()
    b = MockScorerB()
    reg.register(a)
    reg.register(b)
    scorers = reg.get_active_scorers()
    assert len(scorers) == 2
    assert a in scorers
    assert b in scorers


def test_duplicate_registration_raises():
    reg = ScorerRegistry()
    reg.register(MockScorerA())
    with pytest.raises(ValueError, match="already registered"):
        reg.register(MockScorerA())


def test_normalize_weights_sum_to_one():
    reg = ScorerRegistry()
    reg.register(MockScorerA())  # 0.6
    reg.register(MockScorerB())  # 0.4
    weights = reg.normalize_weights(user=None)
    assert abs(sum(weights.values()) - 1.0) < 0.001
    assert abs(weights["scorer_a"] - 0.6) < 0.001
    assert abs(weights["scorer_b"] - 0.4) < 0.001


def test_normalize_weights_with_dynamic_scorer():
    reg = ScorerRegistry()
    reg.register(MockScorerA())  # 0.6
    reg.register(DynamicScorer())  # 0.2 for new user
    weights = reg.normalize_weights(user=None)
    total = weights["scorer_a"] + weights["dynamic"]
    assert abs(total - 1.0) < 0.001

    class FakeUser:
        interaction_count = 100
    weights2 = reg.normalize_weights(user=FakeUser())
    assert weights2["dynamic"] < weights["dynamic"]


def test_normalize_weights_zero_total_returns_equal():
    class ZeroScorer(BaseScorer):
        name = "zero"
        default_weight = 0.0
        def score(self, user, tasks, context): return {}

    reg = ScorerRegistry()
    reg.register(ZeroScorer())
    weights = reg.normalize_weights(user=None)
    assert weights["zero"] == 0.0
