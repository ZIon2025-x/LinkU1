import pytest
from unittest.mock import MagicMock
from app.recommendation.scorers.demand_scorer import DemandScorer

def _make_task(task_id, task_type="translation", title="Help translate", description="Need English translation"):
    task = MagicMock()
    task.id = task_id
    task.task_type = task_type
    task.title = title
    task.title_zh = title
    task.description = description
    task.description_zh = description
    return task

def _make_demand(predicted_needs=None, inferred_skills=None, inferred_preferences=None, recent_interests=None):
    demand = MagicMock()
    demand.predicted_needs = predicted_needs or []
    demand.inferred_skills = inferred_skills or {}
    demand.inferred_preferences = inferred_preferences or {}
    demand.recent_interests = recent_interests or {}
    return demand

def test_predicted_needs_match():
    scorer = DemandScorer()
    task = _make_task(1, task_type="translation")
    demand = _make_demand(predicted_needs=["translation", "tutoring"])
    db = MagicMock()
    db.query.return_value.filter_by.return_value.first.return_value = demand
    db.query.return_value.filter.return_value.count.return_value = 5
    results = scorer.score(MagicMock(id="u1"), [task], {"db": db})
    assert 1 in results
    assert results[1].score > 0

def test_no_demand_returns_empty():
    scorer = DemandScorer()
    db = MagicMock()
    db.query.return_value.filter_by.return_value.first.return_value = None
    results = scorer.score(MagicMock(id="u1"), [_make_task(1)], {"db": db})
    assert len(results) == 0

def test_smart_weight_no_interaction_data():
    scorer = DemandScorer()
    class _User:
        id = "u1"
    # No _interaction_count in context → returns default weight
    weight = scorer.get_weight(_User(), context={})
    assert weight == scorer.default_weight

def test_smart_weight_new_user():
    scorer = DemandScorer()
    class _User:
        id = "u1"
    # New user with < 10 interactions → higher weight (0.20)
    weight = scorer.get_weight(_User(), context={"_interaction_count": 5})
    assert weight == 0.20

def test_smart_weight_experienced_user():
    scorer = DemandScorer()
    class _User:
        id = "u1"
    # Experienced user with 50+ interactions → lower weight (0.05)
    weight = scorer.get_weight(_User(), context={"_interaction_count": 100})
    assert weight == 0.05

def test_inferred_skills_match():
    scorer = DemandScorer()
    task = _make_task(1, task_type="translation", description="需要翻译技能")
    demand = _make_demand(inferred_skills={"translation": 0.8, "writing": 0.6})
    db = MagicMock()
    db.query.return_value.filter_by.return_value.first.return_value = demand
    db.query.return_value.filter.return_value.count.return_value = 5
    results = scorer.score(MagicMock(id="u1"), [task], {"db": db})
    assert 1 in results
    assert results[1].score > 0
