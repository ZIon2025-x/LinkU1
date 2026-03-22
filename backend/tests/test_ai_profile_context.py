"""Tests for build_user_profile_context and get_proactive_suggestions."""

import asyncio
import pytest
from unittest.mock import AsyncMock, MagicMock, patch


def _make_scalar_result(obj):
    """Helper: wrap an object so result.scalars().first() returns it."""
    result = MagicMock()
    scalars_mock = MagicMock()
    scalars_mock.first.return_value = obj
    result.scalars.return_value = scalars_mock
    return result


def test_build_user_profile_context_empty():
    """Returns empty string when no profile data exists."""
    from app.services.ai_agent import build_user_profile_context

    mock_db = AsyncMock()
    mock_db.execute = AsyncMock(return_value=_make_scalar_result(None))
    result = asyncio.get_event_loop().run_until_complete(
        build_user_profile_context("user123", mock_db)
    )
    assert result == ""


def test_build_user_profile_context_with_preference():
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

    mock_db = AsyncMock()
    mock_db.execute = AsyncMock(side_effect=[
        _make_scalar_result(pref),
        _make_scalar_result(demand),
        _make_scalar_result(reliability),
    ])

    result = asyncio.get_event_loop().run_until_complete(
        build_user_profile_context("user123", mock_db)
    )

    assert "用户画像:" in result
    assert "偏好模式: online" in result
    assert "所在城市: London" in result
    assert "cooking" in result
    assert "python" in result
    assert "4.5" in result


def test_build_user_profile_context_partial_data():
    """Returns partial context when only some data exists."""
    from app.services.ai_agent import build_user_profile_context

    pref = MagicMock()
    pref.mode = MagicMock()
    pref.mode.value = "offline"
    pref.preferred_time_slots = None
    pref.city = None

    mock_db = AsyncMock()
    mock_db.execute = AsyncMock(side_effect=[
        _make_scalar_result(pref),
        _make_scalar_result(None),
        _make_scalar_result(None),
    ])

    result = asyncio.get_event_loop().run_until_complete(
        build_user_profile_context("user123", mock_db)
    )
    assert "偏好模式: offline" in result
    assert "可用时段" not in result


def test_build_user_profile_context_db_error():
    """Returns empty string on DB error."""
    from app.services.ai_agent import build_user_profile_context

    mock_db = AsyncMock()
    mock_db.execute = AsyncMock(side_effect=Exception("DB connection failed"))

    result = asyncio.get_event_loop().run_until_complete(
        build_user_profile_context("user123", mock_db)
    )
    assert result == ""
