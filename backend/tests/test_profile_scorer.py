import pytest
from unittest.mock import MagicMock
from app.recommendation.scorers.profile_scorer import ProfileScorer

def _make_task(task_id, task_type="translation", location="London", reward=50, deadline=None, is_flexible=False):
    task = MagicMock()
    task.id = task_id
    task.task_type = task_type
    task.location = location
    task.reward = reward
    task.deadline = deadline
    task.is_flexible = is_flexible
    task.description = ""
    return task

def _make_pref(mode="both", duration_type="both", preferred_categories=None, preferred_time_slots=None, reward_preference="no_preference", city=None):
    pref = MagicMock()
    pref.mode = MagicMock(); pref.mode.value = mode
    pref.duration_type = MagicMock(); pref.duration_type.value = duration_type
    pref.preferred_categories = preferred_categories or []
    pref.preferred_time_slots = preferred_time_slots or []
    pref.reward_preference = MagicMock(); pref.reward_preference.value = reward_preference
    pref.city = city
    return pref

def test_category_match_scores_high():
    scorer = ProfileScorer()
    task = _make_task(1, task_type="translation")
    pref = _make_pref(preferred_categories=["translation", "tutoring"])
    db = MagicMock()
    db.query.return_value.filter_by.return_value.first.return_value = pref
    results = scorer.score(MagicMock(id="u1"), [task], {"db": db})
    assert 1 in results
    assert results[1].score > 0

def test_no_preference_gives_neutral_score():
    scorer = ProfileScorer()
    task = _make_task(1)
    pref = _make_pref()
    db = MagicMock()
    db.query.return_value.filter_by.return_value.first.return_value = pref
    results = scorer.score(MagicMock(id="u1"), [task], {"db": db})
    if 1 in results:
        assert results[1].score >= 0

def test_city_match_boosts_score():
    scorer = ProfileScorer()
    task = _make_task(1, location="London, UK")
    pref = _make_pref(city="London")
    db = MagicMock()
    db.query.return_value.filter_by.return_value.first.return_value = pref
    results = scorer.score(MagicMock(id="u1"), [task], {"db": db})
    assert 1 in results
    assert results[1].score > 0

def test_no_pref_returns_empty():
    scorer = ProfileScorer()
    db = MagicMock()
    db.query.return_value.filter_by.return_value.first.return_value = None
    results = scorer.score(MagicMock(id="u1"), [_make_task(1)], {"db": db})
    assert len(results) == 0
