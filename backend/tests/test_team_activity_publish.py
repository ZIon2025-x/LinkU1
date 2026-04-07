"""Tests for POST /api/experts/{expert_id}/activities (team activity publish).

spec: docs/superpowers/plans/2026-04-07-expert-team-as-task-taker.md — Task 5.1, 5.3
"""
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi import HTTPException


def _make_body(currency='GBP', expert_service_id=42, activity_type='standard'):
    from app.expert_activity_routes import TeamActivityCreate
    return TeamActivityCreate(
        expert_service_id=expert_service_id,
        title="Team Yoga Class",
        description="A fun class",
        location="London",
        task_type="sports",
        reward_type="cash",
        original_price_per_participant=20.0,
        discount_percentage=0,
        discounted_price_per_participant=None,
        currency=currency,
        points_reward=0,
        max_participants=10,
        min_participants=1,
        deadline="2026-12-31T00:00:00Z",
        activity_end_date=None,
        images=None,
        activity_type=activity_type,
    )


def _make_service(
    service_id=42,
    owner_type='expert',
    owner_id='e_test01',
    status='active',
    has_time_slots=False,
    base_price=20.0,
    images=None,
):
    s = MagicMock()
    s.id = service_id
    s.owner_type = owner_type
    s.owner_id = owner_id
    s.status = status
    s.has_time_slots = has_time_slots
    s.base_price = base_price
    s.images = images
    return s


def _make_db(expert=None, owner_member=None, service=None):
    """Build a mock async DB.

    The endpoint calls ``db.execute`` twice: first to load the service, then
    to load the owner member. We return queued results in that order.
    """
    db = MagicMock()
    db.get = AsyncMock(return_value=expert)

    service_result = MagicMock()
    service_result.scalar_one_or_none.return_value = service

    owner_result = MagicMock()
    owner_result.scalar_one_or_none.return_value = owner_member

    db.execute = AsyncMock(side_effect=[service_result, owner_result])
    db.add = MagicMock()
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    return db


def _make_current_user():
    u = MagicMock()
    u.id = "u_caller1"
    return u


def _make_expert(stripe_ready=True, expert_id="e_test01"):
    expert = MagicMock()
    expert.id = expert_id
    expert.stripe_onboarding_complete = stripe_ready
    return expert


def _make_owner_member(user_id="u_owner01"):
    m = MagicMock()
    m.user_id = user_id
    m.role = "owner"
    m.status = "active"
    return m


@pytest.mark.asyncio
async def test_create_team_activity_happy_path():
    from app.expert_activity_routes import create_team_activity

    expert = _make_expert()
    owner_member = _make_owner_member()
    service = _make_service()
    db = _make_db(expert=expert, owner_member=owner_member, service=service)

    def refresh_side_effect(obj):
        obj.id = 999
    db.refresh.side_effect = refresh_side_effect

    captured = {}
    def add_capture(obj):
        captured['activity'] = obj
    db.add = MagicMock(side_effect=add_capture)

    with patch(
        'app.expert_activity_routes._get_member_or_403',
        new=AsyncMock(return_value=MagicMock()),
    ):
        result = await create_team_activity(
            expert_id="e_test01",
            body=_make_body(),
            db=db,
            current_user=_make_current_user(),
        )

    assert result["owner_type"] == "expert"
    assert result["owner_id"] == "e_test01"
    assert result["id"] == 999
    activity = captured['activity']
    assert activity.owner_type == 'expert'
    assert activity.owner_id == 'e_test01'
    assert activity.expert_id == 'u_owner01'  # legacy mirror
    assert activity.expert_service_id == 42
    assert activity.status == 'open'
    assert activity.is_public is True


@pytest.mark.asyncio
async def test_create_team_activity_blocked_no_stripe():
    from app.expert_activity_routes import create_team_activity

    expert = _make_expert(stripe_ready=False)
    db = _make_db(expert=expert)

    with patch(
        'app.expert_activity_routes._get_member_or_403',
        new=AsyncMock(return_value=MagicMock()),
    ):
        with pytest.raises(HTTPException) as exc:
            await create_team_activity(
                expert_id="e_test01",
                body=_make_body(),
                db=db,
                current_user=_make_current_user(),
            )
    assert exc.value.status_code == 409
    assert exc.value.detail["error_code"] == "expert_stripe_not_ready"


@pytest.mark.asyncio
async def test_create_team_activity_blocked_non_gbp():
    from app.expert_activity_routes import create_team_activity

    expert = _make_expert()
    db = _make_db(expert=expert)

    with patch(
        'app.expert_activity_routes._get_member_or_403',
        new=AsyncMock(return_value=MagicMock()),
    ):
        with pytest.raises(HTTPException) as exc:
            await create_team_activity(
                expert_id="e_test01",
                body=_make_body(currency='USD'),
                db=db,
                current_user=_make_current_user(),
            )
    # 409 (business state conflict), not 422 (Pydantic validation)
    assert exc.value.status_code == 409
    assert exc.value.detail["error_code"] == "expert_currency_unsupported"


@pytest.mark.asyncio
async def test_create_team_activity_no_owner_500():
    from app.expert_activity_routes import create_team_activity

    expert = _make_expert()
    service = _make_service()
    db = _make_db(expert=expert, owner_member=None, service=service)

    with patch(
        'app.expert_activity_routes._get_member_or_403',
        new=AsyncMock(return_value=MagicMock()),
    ):
        with pytest.raises(HTTPException) as exc:
            await create_team_activity(
                expert_id="e_test01",
                body=_make_body(),
                db=db,
                current_user=_make_current_user(),
            )
    assert exc.value.status_code == 500
    assert exc.value.detail["error_code"] == "expert_owner_missing"


@pytest.mark.asyncio
async def test_create_team_activity_member_forbidden():
    from app.expert_activity_routes import create_team_activity

    db = _make_db()

    async def deny(*args, **kwargs):
        raise HTTPException(status_code=403, detail="权限不足")

    with patch('app.expert_activity_routes._get_member_or_403', new=deny):
        with pytest.raises(HTTPException) as exc:
            await create_team_activity(
                expert_id="e_test01",
                body=_make_body(),
                db=db,
                current_user=_make_current_user(),
            )
    assert exc.value.status_code == 403


# ---------------------------------------------------------------------------
# Task 5.3: service validation tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_create_team_activity_service_not_found_404():
    from app.expert_activity_routes import create_team_activity

    expert = _make_expert()
    db = _make_db(expert=expert, owner_member=_make_owner_member(), service=None)

    with patch(
        'app.expert_activity_routes._get_member_or_403',
        new=AsyncMock(return_value=MagicMock()),
    ):
        with pytest.raises(HTTPException) as exc:
            await create_team_activity(
                expert_id="e_test01",
                body=_make_body(),
                db=db,
                current_user=_make_current_user(),
            )
    assert exc.value.status_code == 404
    assert exc.value.detail["error_code"] == "service_not_found"


@pytest.mark.asyncio
async def test_create_team_activity_service_belongs_to_other_team_403():
    from app.expert_activity_routes import create_team_activity

    expert = _make_expert()
    service = _make_service(owner_type='expert', owner_id='e_other99')
    db = _make_db(expert=expert, owner_member=_make_owner_member(), service=service)

    with patch(
        'app.expert_activity_routes._get_member_or_403',
        new=AsyncMock(return_value=MagicMock()),
    ):
        with pytest.raises(HTTPException) as exc:
            await create_team_activity(
                expert_id="e_test01",
                body=_make_body(),
                db=db,
                current_user=_make_current_user(),
            )
    assert exc.value.status_code == 403
    assert exc.value.detail["error_code"] == "service_not_owned_by_team"


@pytest.mark.asyncio
async def test_create_team_activity_service_owned_by_user_403():
    from app.expert_activity_routes import create_team_activity

    expert = _make_expert()
    service = _make_service(owner_type='user', owner_id='u_someone1')
    db = _make_db(expert=expert, owner_member=_make_owner_member(), service=service)

    with patch(
        'app.expert_activity_routes._get_member_or_403',
        new=AsyncMock(return_value=MagicMock()),
    ):
        with pytest.raises(HTTPException) as exc:
            await create_team_activity(
                expert_id="e_test01",
                body=_make_body(),
                db=db,
                current_user=_make_current_user(),
            )
    assert exc.value.status_code == 403
    assert exc.value.detail["error_code"] == "service_not_owned_by_team"


@pytest.mark.asyncio
async def test_create_team_activity_service_inactive_400():
    from app.expert_activity_routes import create_team_activity

    expert = _make_expert()
    service = _make_service(status='inactive')
    db = _make_db(expert=expert, owner_member=_make_owner_member(), service=service)

    with patch(
        'app.expert_activity_routes._get_member_or_403',
        new=AsyncMock(return_value=MagicMock()),
    ):
        with pytest.raises(HTTPException) as exc:
            await create_team_activity(
                expert_id="e_test01",
                body=_make_body(),
                db=db,
                current_user=_make_current_user(),
            )
    assert exc.value.status_code == 400
    assert exc.value.detail["error_code"] == "service_inactive"


@pytest.mark.asyncio
async def test_create_team_activity_inherits_has_time_slots_from_service():
    from app.expert_activity_routes import create_team_activity

    expert = _make_expert()
    service = _make_service(has_time_slots=True)
    db = _make_db(expert=expert, owner_member=_make_owner_member(), service=service)

    def refresh_side_effect(obj):
        obj.id = 1234
    db.refresh.side_effect = refresh_side_effect

    captured = {}
    db.add = MagicMock(side_effect=lambda obj: captured.update(activity=obj))

    with patch(
        'app.expert_activity_routes._get_member_or_403',
        new=AsyncMock(return_value=MagicMock()),
    ):
        await create_team_activity(
            expert_id="e_test01",
            body=_make_body(),
            db=db,
            current_user=_make_current_user(),
        )

    activity = captured['activity']
    assert activity.has_time_slots is True
    assert activity.expert_service_id == 42
