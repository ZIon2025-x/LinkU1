"""单元测试 expert_task_resolver. spec §4.2"""
import pytest
from unittest.mock import AsyncMock, MagicMock
from fastapi import HTTPException


@pytest.fixture
def mock_db():
    db = MagicMock()
    db.get = AsyncMock()
    db.execute = AsyncMock()
    return db


@pytest.fixture
def fake_service():
    s = MagicMock()
    s.owner_type = 'expert'
    s.owner_id = 'e_test01'
    s.currency = 'GBP'
    return s


@pytest.fixture
def fake_expert():
    e = MagicMock()
    e.id = 'e_test01'
    e.stripe_onboarding_complete = True
    return e


@pytest.fixture
def fake_owner_member():
    m = MagicMock()
    m.user_id = 'u_owner01'
    m.role = 'owner'
    m.status = 'active'
    return m


@pytest.mark.asyncio
async def test_resolve_service_team_happy_path(mock_db, fake_service, fake_expert, fake_owner_member):
    from app.services.expert_task_resolver import resolve_task_taker_from_service
    mock_db.get.return_value = fake_expert
    result_obj = MagicMock()
    result_obj.scalar_one_or_none.return_value = fake_owner_member
    mock_db.execute.return_value = result_obj

    taker_id, taker_expert_id = await resolve_task_taker_from_service(mock_db, fake_service)
    assert taker_id == 'u_owner01'
    assert taker_expert_id == 'e_test01'


@pytest.mark.asyncio
async def test_resolve_service_user_personal(mock_db):
    from app.services.expert_task_resolver import resolve_task_taker_from_service
    s = MagicMock()
    s.owner_type = 'user'
    s.owner_id = 'u_personal01'
    taker_id, taker_expert_id = await resolve_task_taker_from_service(mock_db, s)
    assert taker_id == 'u_personal01'
    assert taker_expert_id is None


@pytest.mark.asyncio
async def test_resolve_service_team_no_stripe(mock_db, fake_service, fake_expert):
    from app.services.expert_task_resolver import resolve_task_taker_from_service
    fake_expert.stripe_onboarding_complete = False
    mock_db.get.return_value = fake_expert
    with pytest.raises(HTTPException) as exc:
        await resolve_task_taker_from_service(mock_db, fake_service)
    assert exc.value.status_code == 409
    assert exc.value.detail['error_code'] == 'expert_stripe_not_ready'


@pytest.mark.asyncio
async def test_resolve_service_team_non_gbp(mock_db, fake_service, fake_expert):
    from app.services.expert_task_resolver import resolve_task_taker_from_service
    fake_service.currency = 'USD'
    mock_db.get.return_value = fake_expert
    with pytest.raises(HTTPException) as exc:
        await resolve_task_taker_from_service(mock_db, fake_service)
    assert exc.value.status_code == 409
    assert exc.value.detail['error_code'] == 'expert_currency_unsupported'


@pytest.mark.asyncio
async def test_resolve_service_team_no_owner(mock_db, fake_service, fake_expert):
    from app.services.expert_task_resolver import resolve_task_taker_from_service
    mock_db.get.return_value = fake_expert
    result_obj = MagicMock()
    result_obj.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = result_obj
    with pytest.raises(HTTPException) as exc:
        await resolve_task_taker_from_service(mock_db, fake_service)
    assert exc.value.status_code == 500
    assert exc.value.detail['error_code'] == 'expert_owner_missing'


@pytest.mark.asyncio
async def test_resolve_service_unknown_owner_type(mock_db):
    from app.services.expert_task_resolver import resolve_task_taker_from_service
    s = MagicMock()
    s.owner_type = 'alien'
    with pytest.raises(HTTPException) as exc:
        await resolve_task_taker_from_service(mock_db, s)
    assert exc.value.status_code == 500


@pytest.fixture
def fake_activity():
    a = MagicMock()
    a.owner_type = 'expert'
    a.owner_id = 'e_test01'
    a.currency = 'GBP'
    a.expert_id = 'u_legacy01'
    return a


@pytest.mark.asyncio
async def test_resolve_activity_team_happy_path(mock_db, fake_activity, fake_expert, fake_owner_member):
    from app.services.expert_task_resolver import resolve_task_taker_from_activity
    mock_db.get.return_value = fake_expert
    result_obj = MagicMock()
    result_obj.scalar_one_or_none.return_value = fake_owner_member
    mock_db.execute.return_value = result_obj
    taker_id, taker_expert_id = await resolve_task_taker_from_activity(mock_db, fake_activity)
    assert taker_id == 'u_owner01'
    assert taker_expert_id == 'e_test01'


@pytest.mark.asyncio
async def test_resolve_activity_user_legacy(mock_db):
    from app.services.expert_task_resolver import resolve_task_taker_from_activity
    a = MagicMock()
    a.owner_type = 'user'
    a.expert_id = 'u_legacy01'
    taker_id, taker_expert_id = await resolve_task_taker_from_activity(mock_db, a)
    assert taker_id == 'u_legacy01'
    assert taker_expert_id is None


@pytest.mark.asyncio
async def test_resolve_activity_team_non_gbp(mock_db, fake_activity, fake_expert):
    from app.services.expert_task_resolver import resolve_task_taker_from_activity
    fake_activity.currency = 'EUR'
    mock_db.get.return_value = fake_expert
    with pytest.raises(HTTPException) as exc:
        await resolve_task_taker_from_activity(mock_db, fake_activity)
    assert exc.value.status_code == 409
    assert exc.value.detail['error_code'] == 'expert_currency_unsupported'
