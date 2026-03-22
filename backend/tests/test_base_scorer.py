import pytest
from app.recommendation.base_scorer import BaseScorer, ScoredTask


class DummyScorer(BaseScorer):
    name = "dummy"
    default_weight = 0.5

    def score(self, user, tasks, context):
        return {1: ScoredTask(score=0.8, reason="test reason")}


def test_scored_task_creation():
    st = ScoredTask(score=0.75, reason="matched interests")
    assert st.score == 0.75
    assert st.reason == "matched interests"


def test_scored_task_score_clamped():
    st = ScoredTask(score=1.5, reason="over")
    assert st.clamped_score == 1.0
    st2 = ScoredTask(score=-0.1, reason="under")
    assert st2.clamped_score == 0.0


def test_base_scorer_default_weight():
    scorer = DummyScorer()
    assert scorer.get_weight(None) == 0.5


def test_base_scorer_score_returns_dict():
    scorer = DummyScorer()
    result = scorer.score(None, [], {})
    assert isinstance(result, dict)
    assert 1 in result
    assert result[1].score == 0.8
