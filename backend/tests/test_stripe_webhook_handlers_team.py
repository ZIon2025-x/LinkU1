"""Tests for the account.updated Stripe webhook branch (expert team Connect sync).

spec: docs/superpowers/plans/2026-04-07-expert-team-as-task-taker.md — Phase 3
"""
from unittest.mock import MagicMock


def _make_db_with_expert(expert):
    """Build a MagicMock sync Session that returns `expert` on .filter().first().

    Also supports the chained update on TaskExpertService:
        db.query(TaskExpertService).filter(...).update({...}, synchronize_session=False)
    """
    db = MagicMock()

    # Track the last "model class" passed to .query() so we can branch
    state = {"last_query_model": None, "services_update_calls": []}

    def query_side_effect(model):
        state["last_query_model"] = model
        q = MagicMock()

        def filter_side_effect(*args, **kwargs):
            f = MagicMock()
            # For Expert query: .first() returns the fake expert
            f.first.return_value = expert
            # For TaskExpertService update: capture the call
            def update_side_effect(values, synchronize_session=False):
                state["services_update_calls"].append(values)
                return 1
            f.update.side_effect = update_side_effect
            return f
        q.filter.side_effect = filter_side_effect
        return q

    db.query.side_effect = query_side_effect
    db._state = state
    return db


def test_account_updated_charges_disabled_suspends_team_services():
    """When charges_enabled=False, expert.stripe_onboarding_complete flips to False
    and active team services are flipped to inactive."""
    from app.routers import _handle_account_updated

    expert = MagicMock()
    expert.id = "e_test01"
    expert.stripe_account_id = "acct_123"
    expert.stripe_onboarding_complete = True

    db = _make_db_with_expert(expert)
    event_obj = {"id": "acct_123", "charges_enabled": False}

    _handle_account_updated(db, event_obj)

    assert expert.stripe_onboarding_complete is False
    # should have issued an update on services with status=inactive
    assert len(db._state["services_update_calls"]) == 1
    assert db._state["services_update_calls"][0] == {"status": "inactive"}


def test_account_updated_charges_enabled_unfreezes():
    """When charges_enabled=True and expert was previously False, flips to True;
    services are NOT modified."""
    from app.routers import _handle_account_updated

    expert = MagicMock()
    expert.id = "e_test02"
    expert.stripe_account_id = "acct_456"
    expert.stripe_onboarding_complete = False

    db = _make_db_with_expert(expert)
    event_obj = {"id": "acct_456", "charges_enabled": True}

    _handle_account_updated(db, event_obj)

    assert expert.stripe_onboarding_complete is True
    assert db._state["services_update_calls"] == []


def test_account_updated_unrelated_account_ignored():
    """If no expert matches the stripe_account_id, no DB writes, no errors."""
    from app.routers import _handle_account_updated

    db = _make_db_with_expert(None)  # .first() returns None
    event_obj = {"id": "acct_unknown", "charges_enabled": True}

    # Should not raise
    _handle_account_updated(db, event_obj)

    assert db._state["services_update_calls"] == []


def test_account_updated_no_change_is_noop():
    """If state already matches, no service updates occur."""
    from app.routers import _handle_account_updated

    expert = MagicMock()
    expert.id = "e_test03"
    expert.stripe_account_id = "acct_789"
    expert.stripe_onboarding_complete = True

    db = _make_db_with_expert(expert)
    event_obj = {"id": "acct_789", "charges_enabled": True}

    _handle_account_updated(db, event_obj)

    assert expert.stripe_onboarding_complete is True
    assert db._state["services_update_calls"] == []
