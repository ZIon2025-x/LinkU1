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
    assert exc.value.detail['error_code'] == 'unknown_owner_type'


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


@pytest.mark.asyncio
async def test_resolve_activity_team_no_stripe(mock_db, fake_activity, fake_expert):
    from app.services.expert_task_resolver import resolve_task_taker_from_activity
    fake_expert.stripe_onboarding_complete = False
    mock_db.get.return_value = fake_expert
    with pytest.raises(HTTPException) as exc:
        await resolve_task_taker_from_activity(mock_db, fake_activity)
    assert exc.value.status_code == 409
    assert exc.value.detail['error_code'] == 'expert_stripe_not_ready'


@pytest.mark.asyncio
async def test_resolve_activity_team_no_owner(mock_db, fake_activity, fake_expert):
    from app.services.expert_task_resolver import resolve_task_taker_from_activity
    mock_db.get.return_value = fake_expert
    result_obj = MagicMock()
    result_obj.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = result_obj
    with pytest.raises(HTTPException) as exc:
        await resolve_task_taker_from_activity(mock_db, fake_activity)
    assert exc.value.status_code == 500
    assert exc.value.detail['error_code'] == 'expert_owner_missing'


@pytest.mark.asyncio
async def test_resolve_activity_unknown_owner_type(mock_db):
    from app.services.expert_task_resolver import resolve_task_taker_from_activity
    a = MagicMock()
    a.owner_type = 'alien'
    with pytest.raises(HTTPException) as exc:
        await resolve_task_taker_from_activity(mock_db, a)
    assert exc.value.status_code == 500
    assert exc.value.detail['error_code'] == 'unknown_owner_type'


# ==================== sync helper tests ====================


def _make_sync_db(first_results):
    """Build a sync MagicMock db.

    `first_results` is a list of return values for successive .first() calls
    on the chained db.query(...).filter(...).first() expression.
    """
    db = MagicMock()
    iterator = iter(first_results)

    def query_side_effect(model):
        q = MagicMock()
        f = MagicMock()
        f.first.side_effect = lambda: next(iterator)
        q.filter.return_value = f
        return q

    db.query.side_effect = query_side_effect
    return db


def test_resolve_activity_sync_team_happy_path():
    from app.services.expert_task_resolver import resolve_task_taker_from_activity_sync
    expert = MagicMock(id='e_test01', stripe_onboarding_complete=True)
    member = MagicMock(user_id='u_owner01')
    db = _make_sync_db([expert, member])
    activity = MagicMock(owner_type='expert', owner_id='e_test01', currency='GBP')
    result = resolve_task_taker_from_activity_sync(db, activity)
    assert result == ('u_owner01', 'e_test01')


def test_resolve_activity_sync_user_legacy():
    from app.services.expert_task_resolver import resolve_task_taker_from_activity_sync
    db = MagicMock()
    activity = MagicMock(owner_type='user', expert_id='u_legacy01')
    result = resolve_task_taker_from_activity_sync(db, activity)
    assert result == ('u_legacy01', None)


def test_resolve_activity_sync_team_no_stripe():
    from app.services.expert_task_resolver import resolve_task_taker_from_activity_sync
    expert = MagicMock(id='e_test01', stripe_onboarding_complete=False)
    db = _make_sync_db([expert])
    activity = MagicMock(owner_type='expert', owner_id='e_test01', currency='GBP')
    with pytest.raises(HTTPException) as exc:
        resolve_task_taker_from_activity_sync(db, activity)
    assert exc.value.status_code == 409
    assert exc.value.detail['error_code'] == 'expert_stripe_not_ready'
