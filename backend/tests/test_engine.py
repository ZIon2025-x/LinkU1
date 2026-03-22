import pytest
from unittest.mock import MagicMock
from app.recommendation.base_scorer import BaseScorer, ScoredTask
from app.recommendation.scorer_registry import ScorerRegistry
from app.recommendation.engine import HybridEngine


class FakeScorerHigh(BaseScorer):
    name = "high"
    default_weight = 0.7
    def score(self, user, tasks, context):
        return {1: ScoredTask(score=0.9, reason="high match")}


class FakeScorerLow(BaseScorer):
    name = "low"
    default_weight = 0.3
    def score(self, user, tasks, context):
        return {
            1: ScoredTask(score=0.5, reason="low match"),
            2: ScoredTask(score=0.8, reason="good match"),
        }


def test_engine_aggregates_scores():
    reg = ScorerRegistry()
    reg.register(FakeScorerHigh())
    reg.register(FakeScorerLow())
    engine = HybridEngine(registry=reg)
    task1 = MagicMock(id=1)
    task2 = MagicMock(id=2)
    engine._get_candidates = lambda user, filters, context: [task1, task2]
    results = engine.recommend(user=None, limit=10, context={"db": None})
    assert len(results) == 2
    assert results[0]["task_id"] == 1
    assert results[0]["score"] > results[1]["score"]


def test_engine_respects_limit():
    reg = ScorerRegistry()
    reg.register(FakeScorerLow())
    engine = HybridEngine(registry=reg)
    engine._get_candidates = lambda user, filters, context: [MagicMock(id=i) for i in range(100)]
    results = engine.recommend(user=None, limit=5, context={"db": None})
    assert len(results) <= 5


def test_engine_empty_scorers():
    reg = ScorerRegistry()
    engine = HybridEngine(registry=reg)
    engine._get_candidates = lambda user, filters, context: [MagicMock(id=1)]
    results = engine.recommend(user=None, limit=10, context={"db": None})
    assert len(results) == 0
