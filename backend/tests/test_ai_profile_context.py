"""Tests for build_user_profile_context and get_proactive_suggestions."""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch


@pytest.fixture
def mock_db():
    """Create a mock async DB session."""
    db = AsyncMock()
    return db


def _make_scalar_result(obj):
    """Helper: wrap an object so result.scalars().first() returns it."""
    result = MagicMock()
    scalars_mock = MagicMock()
    scalars_mock.first.return_value = obj
    result.scalars.return_value = scalars_mock
    return result


@pytest.mark.asyncio
async def test_build_user_profile_context_empty(mock_db):
    """Returns empty string when no profile data exists."""
    from app.services.ai_agent import build_user_profile_context

    mock_db.execute = AsyncMock(return_value=_make_scalar_result(None))
    result = await build_user_profile_context("user123", mock_db)
    assert result == ""


@pytest.mark.asyncio
async def test_build_user_profile_context_with_preference(mock_db):
    """Returns profile context with preference data."""
    from app.services.ai_agent import build_user_profile_context

    pref = MagicMock()
    pref.mode = MagicMock()
    pref.mode.value = "online"
    pref.preferred_time_slots = ["morning", "evening"]
    pref.city = "London"

    demand = MagicMock()
    demand.recent_interests = {"cooking": 3, "tutoring": 2}
    demand.inferred_skills = {"python": 0.9, "math": 0.8}
    demand.predicted_needs = {"cleaning": 0.7}

    reliability = MagicMock()
    reliability.reliability_score = 4.5

    results = [
        _make_scalar_result(pref),
        _make_scalar_result(demand),
        _make_scalar_result(reliability),
    ]
    mock_db.execute = AsyncMock(side_effect=results)

    result = await build_user_profile_context("user123", mock_db)

    assert "用户画像:" in result
    assert "偏好模式: online" in result
    assert "可用时段: morning, evening" in result
    assert "所在城市: London" in result
    assert "兴趣领域: cooking, tutoring" in result
    assert "推断技能: python, math" in result
    assert "预测需求: cleaning" in result
    assert "可靠度评分: 4.5" in result


@pytest.mark.asyncio
async def test_build_user_profile_context_partial_data(mock_db):
    """Returns partial context when only some data exists."""
    from app.services.ai_agent import build_user_profile_context

    pref = MagicMock()
    pref.mode = MagicMock()
    pref.mode.value = "offline"
    pref.preferred_time_slots = None
    pref.city = None

    results = [
        _make_scalar_result(pref),
        _make_scalar_result(None),  # no demand
        _make_scalar_result(None),  # no reliability
    ]
    mock_db.execute = AsyncMock(side_effect=results)

    result = await build_user_profile_context("user123", mock_db)
    assert "偏好模式: offline" in result
    assert "可用时段" not in result
    assert "所在城市" not in result


@pytest.mark.asyncio
async def test_build_user_profile_context_db_error(mock_db):
    """Returns empty string on DB error."""
    from app.services.ai_agent import build_user_profile_context

    mock_db.execute = AsyncMock(side_effect=Exception("DB connection failed"))
    result = await build_user_profile_context("user123", mock_db)
    assert result == ""


@pytest.mark.asyncio
async def test_build_user_profile_context_list_interests(mock_db):
    """Handles list-type recent_interests (not dict)."""
    from app.services.ai_agent import build_user_profile_context

    demand = MagicMock()
    demand.recent_interests = ["cooking", "cleaning", "tutoring"]
    demand.inferred_skills = ["python", "math"]
    demand.predicted_needs = ["delivery"]

    results = [
        _make_scalar_result(None),  # no pref
        _make_scalar_result(demand),
        _make_scalar_result(None),  # no reliability
    ]
    mock_db.execute = AsyncMock(side_effect=results)

    result = await build_user_profile_context("user123", mock_db)
    assert "兴趣领域: cooking, cleaning, tutoring" in result
    assert "推断技能: python, math" in result


@pytest.mark.asyncio
async def test_get_proactive_suggestions_no_high_matches():
    """Returns empty string when no high-match tasks exist."""
    from app.services.ai_agent import get_proactive_suggestions

    mock_db = AsyncMock()
    low_score_recs = [
        {"match_score": 0.5, "title_zh": "Low task", "recommendation_reason": "some reason", "created_at": "2026-03-22T00:00:00Z"},
    ]

    with patch("app.services.ai_agent.get_proactive_suggestions.__module__", "app.services.ai_agent"):
        with patch("app.task_recommendation.get_task_recommendations", return_value=low_score_recs):
            with patch("app.deps.get_sync_db") as mock_sync:
                mock_sync_db = MagicMock()
                mock_sync.return_value = iter([mock_sync_db])
                result = await get_proactive_suggestions("user123", mock_db)

    assert result == ""


@pytest.mark.asyncio
async def test_get_proactive_suggestions_with_high_matches():
    """Returns suggestion text for high-match recent tasks."""
    from app.services.ai_agent import get_proactive_suggestions
    from datetime import datetime, timezone

    mock_db = AsyncMock()
    now = datetime.now(timezone.utc)
    high_score_recs = [
        {
            "match_score": 0.9,
            "title_zh": "帮忙搬家",
            "recommendation_reason": "技能匹配度高",
            "created_at": now,
        },
    ]

    with patch("app.task_recommendation.get_task_recommendations", return_value=high_score_recs):
        with patch("app.deps.get_sync_db") as mock_sync:
            mock_sync_db = MagicMock()
            mock_sync.return_value = iter([mock_sync_db])
            result = await get_proactive_suggestions("user123", mock_db)

    assert "帮忙搬家" in result
    assert "技能匹配度高" in result
    assert "0.90" in result


@pytest.mark.asyncio
async def test_get_proactive_suggestions_exception():
    """Returns empty string on exception."""
    from app.services.ai_agent import get_proactive_suggestions

    mock_db = AsyncMock()

    with patch("app.task_recommendation.get_task_recommendations", side_effect=Exception("boom")):
        with patch("app.deps.get_sync_db") as mock_sync:
            mock_sync_db = MagicMock()
            mock_sync.return_value = iter([mock_sync_db])
            result = await get_proactive_suggestions("user123", mock_db)

    assert result == ""
