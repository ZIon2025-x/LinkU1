"""Tests for POST /api/experts/{expert_id}/activities (team activity publish).

spec: docs/superpowers/plans/2026-04-07-expert-team-as-task-taker.md — Task 5.1
"""
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi import HTTPException


def _make_body(currency='GBP'):
    from app.expert_activity_routes import TeamActivityCreate
    return TeamActivityCreate(
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
    )


def _make_db(expert=None, owner_member=None):
    db = MagicMock()
    db.get = AsyncMock(return_value=expert)
    result_obj = MagicMock()
    result_obj.scalar_one_or_none.return_value = owner_member
    db.execute = AsyncMock(return_value=result_obj)
    db.add = MagicMock()
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    return db


def _make_current_user():
    u = MagicMock()
    u.id = "u_caller1"
    return u


@pytest.mark.asyncio
async def test_create_team_activity_happy_path():
    from app.expert_activity_routes import create_team_activity

    expert = MagicMock()
    expert.id = "e_test01"
    expert.stripe_onboarding_complete = True

    owner_member = MagicMock()
    owner_member.user_id = "u_owner01"
    owner_member.role = "owner"
    owner_member.status = "active"

    db = _make_db(expert=expert, owner_member=owner_member)

    # Inject activity.id on refresh so we can return a sensible id
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
    assert activity.status == 'open'
    assert activity.is_public is True


@pytest.mark.asyncio
async def test_create_team_activity_blocked_no_stripe():
    from app.expert_activity_routes import create_team_activity

    expert = MagicMock()
    expert.id = "e_test01"
    expert.stripe_onboarding_complete = False
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

    expert = MagicMock()
    expert.id = "e_test01"
    expert.stripe_onboarding_complete = True
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
    assert exc.value.status_code == 422
    assert exc.value.detail["error_code"] == "expert_currency_unsupported"


@pytest.mark.asyncio
async def test_create_team_activity_no_owner_500():
    from app.expert_activity_routes import create_team_activity

    expert = MagicMock()
    expert.id = "e_test01"
    expert.stripe_onboarding_complete = True
    db = _make_db(expert=expert, owner_member=None)

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
