"""Tests for build_taker_display. spec §4.6 (U2 scheme)"""
import pytest
from unittest.mock import AsyncMock, MagicMock


@pytest.fixture
def mock_db():
    db = MagicMock()
    db.get = AsyncMock()
    return db


@pytest.mark.asyncio
async def test_taker_display_team_task(mock_db):
    from app.serializers.task_taker_display import build_taker_display
    task = MagicMock()
    task.taker_id = 'u_owner01'
    task.taker_expert_id = 'e_test01'

    expert = MagicMock()
    expert.id = 'e_test01'
    expert.name = '星光摄影团队'
    expert.avatar = 'https://example.com/team_logo.png'
    mock_db.get.return_value = expert

    result = await build_taker_display(task, mock_db)
    assert result is not None
    assert result['type'] == 'expert'
    assert result['entity_id'] == 'e_test01'
    assert result['name'] == '星光摄影团队'
    assert result['avatar'] == 'https://example.com/team_logo.png'


@pytest.mark.asyncio
async def test_taker_display_individual_task(mock_db):
    from app.serializers.task_taker_display import build_taker_display
    task = MagicMock()
    task.taker_id = 'u_indiv01'
    task.taker_expert_id = None

    user = MagicMock()
    user.id = 'u_indiv01'
    user.name = '李四'
    user.avatar = 'https://example.com/user_avatar.png'
    mock_db.get.return_value = user

    result = await build_taker_display(task, mock_db)
    assert result is not None
    assert result['type'] == 'user'
    assert result['entity_id'] == 'u_indiv01'
    assert result['name'] == '李四'


@pytest.mark.asyncio
async def test_taker_display_unclaimed_task(mock_db):
    from app.serializers.task_taker_display import build_taker_display
    task = MagicMock()
    task.taker_id = None
    task.taker_expert_id = None

    result = await build_taker_display(task, mock_db)
    assert result is None


@pytest.mark.asyncio
async def test_taker_display_team_expert_missing(mock_db):
    """Team task but Expert row missing — should return None or fallback gracefully."""
    from app.serializers.task_taker_display import build_taker_display
    task = MagicMock()
    task.taker_id = 'u_owner01'
    task.taker_expert_id = 'e_missing'
    mock_db.get.return_value = None

    result = await build_taker_display(task, mock_db)
    # Either None or fallback to individual is acceptable
    assert result is None or result['type'] == 'user'
