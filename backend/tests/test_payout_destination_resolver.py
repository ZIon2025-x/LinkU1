"""单元测试 resolve_payout_destination. spec §3.2 (v2 — payout site team-awareness)"""
import pytest
from unittest.mock import MagicMock
from fastapi import HTTPException


def _make_db_with_expert(expert):
    """Helper: build a sync-style DB mock where db.query(...).filter(...).first() returns expert."""
    db = MagicMock()
    q = MagicMock()
    q.filter.return_value.first.return_value = expert
    db.query.return_value = q
    return db


def _make_db_with_expert_and_user(expert, user):
    """Helper: first query returns expert, second returns user."""
    db = MagicMock()
    results = [expert, user]

    def _query(*args, **kwargs):
        q = MagicMock()
        q.filter.return_value.first.return_value = results.pop(0) if results else None
        return q

    db.query.side_effect = _query
    return db


def test_resolve_team_task_returns_experts_stripe_account():
    from app.services.expert_task_resolver import resolve_payout_destination

    task = MagicMock(taker_expert_id='e_test01', taker_id='u_owner01')
    expert = MagicMock(
        id='e_test01',
        stripe_account_id='acct_team_01',
        stripe_onboarding_complete=True,
    )
    db = _make_db_with_expert(expert)

    result = resolve_payout_destination(db, task)
    assert result == 'acct_team_01'


def test_resolve_individual_task_returns_users_stripe_account():
    from app.services.expert_task_resolver import resolve_payout_destination

    task = MagicMock(taker_expert_id=None, taker_id='u_test01')
    user = MagicMock(id='u_test01', stripe_account_id='acct_user_01')
    db = _make_db_with_expert_and_user(None, user)

    result = resolve_payout_destination(db, task)
    assert result == 'acct_user_01'


def test_resolve_individual_no_stripe_returns_none():
    from app.services.expert_task_resolver import resolve_payout_destination

    task = MagicMock(taker_expert_id=None, taker_id='u_test01')
    user = MagicMock(id='u_test01', stripe_account_id=None)
    db = _make_db_with_expert_and_user(None, user)

    result = resolve_payout_destination(db, task)
    assert result is None


def test_resolve_team_missing_expert_raises_500():
    from app.services.expert_task_resolver import resolve_payout_destination

    task = MagicMock(taker_expert_id='e_missing', taker_id='u_owner01')
    db = _make_db_with_expert(None)

    with pytest.raises(HTTPException) as exc_info:
        resolve_payout_destination(db, task)
    assert exc_info.value.status_code == 500
    assert exc_info.value.detail['error_code'] == 'team_not_found'


def test_resolve_team_no_stripe_account_raises_500():
    from app.services.expert_task_resolver import resolve_payout_destination

    task = MagicMock(taker_expert_id='e_test01', taker_id='u_owner01')
    expert = MagicMock(
        id='e_test01',
        stripe_account_id=None,
        stripe_onboarding_complete=True,
    )
    db = _make_db_with_expert(expert)

    with pytest.raises(HTTPException) as exc_info:
        resolve_payout_destination(db, task)
    assert exc_info.value.status_code == 500
    assert exc_info.value.detail['error_code'] == 'team_no_stripe_account'


def test_resolve_team_onboarding_incomplete_raises_500():
    from app.services.expert_task_resolver import resolve_payout_destination

    task = MagicMock(taker_expert_id='e_test01', taker_id='u_owner01')
    expert = MagicMock(
        id='e_test01',
        stripe_account_id='acct_team_01',
        stripe_onboarding_complete=False,
    )
    db = _make_db_with_expert(expert)

    with pytest.raises(HTTPException) as exc_info:
        resolve_payout_destination(db, task)
    assert exc_info.value.status_code == 500
    assert exc_info.value.detail['error_code'] == 'team_stripe_not_ready'
