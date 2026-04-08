"""
Phase 7: Tests for team task dispute reversal hook.

When a customer disputes a team task payment via Stripe, the money has
already been transferred to the team's Stripe Connect account. We need to
auto-reverse the Stripe Transfer so the disputed amount can be deducted
from the platform account.

spec §3.5 — dispute handling for team tasks
spec §1.3 — PaymentTransfer audit fields (stripe_reversal_id, reversed_at, reversed_reason)
"""

import pytest
from unittest.mock import MagicMock, patch
import stripe


def _make_db_with_pt(pt):
    """Build a mock db whose .query(...).filter(...).first() returns pt."""
    db = MagicMock()
    chain = db.query.return_value.filter.return_value
    chain.first.return_value = pt
    return db


def _make_pt(
    *,
    task_id=42,
    taker_expert_id="e_test01",
    status="succeeded",
    transfer_id="tr_test01",
    amount=100.0,
):
    """Build a mock PaymentTransfer row with the fields the helper touches."""
    pt = MagicMock()
    pt.id = 1
    pt.task_id = task_id
    pt.taker_expert_id = taker_expert_id
    pt.amount = amount
    pt.status = status
    pt.transfer_id = transfer_id
    pt.stripe_reversal_id = None
    pt.reversed_at = None
    pt.reversed_reason = None
    return pt


def test_team_dispute_reverses_succeeded_transfer():
    """Team task with a succeeded transfer — helper should call Stripe and
    fill audit fields."""
    from app.routers import _handle_dispute_team_reversal

    pt = _make_pt()
    db = _make_db_with_pt(pt)

    with patch("stripe.Transfer.create_reversal") as mock_reverse:
        mock_reverse.return_value = MagicMock(id="trr_test01")
        _handle_dispute_team_reversal(db, task_id=42)

    mock_reverse.assert_called_once()
    # amount passed to Stripe should be in pence
    _, kwargs = mock_reverse.call_args
    assert kwargs["amount"] == 10000
    assert kwargs["metadata"]["reason"] == "dispute"
    assert kwargs["metadata"]["task_id"] == "42"

    assert pt.stripe_reversal_id == "trr_test01"
    assert pt.status == "reversed"
    assert pt.reversed_reason == "dispute"
    assert pt.reversed_at is not None
    db.commit.assert_called_once()


def test_team_dispute_no_payment_transfer_noop():
    """If no PaymentTransfer row exists (dispute before payout), helper is a no-op."""
    from app.routers import _handle_dispute_team_reversal

    db = _make_db_with_pt(None)

    with patch("stripe.Transfer.create_reversal") as mock_reverse:
        _handle_dispute_team_reversal(db, task_id=42)

    mock_reverse.assert_not_called()
    db.commit.assert_not_called()


def test_individual_task_dispute_no_team_reversal():
    """Individual task (taker_expert_id=None) — existing freeze/refund flow
    handles it; helper should early-return without Stripe call."""
    from app.routers import _handle_dispute_team_reversal

    pt = _make_pt(taker_expert_id=None)
    db = _make_db_with_pt(pt)

    with patch("stripe.Transfer.create_reversal") as mock_reverse:
        _handle_dispute_team_reversal(db, task_id=42)

    mock_reverse.assert_not_called()
    assert pt.status == "succeeded"  # unchanged
    assert pt.stripe_reversal_id is None
    db.commit.assert_not_called()


def test_team_dispute_reversal_failure_keeps_succeeded():
    """If Stripe.create_reversal raises (e.g. insufficient team balance), the
    helper should log and NOT update pt.status — leaves it 'succeeded' so
    admin can intervene manually."""
    from app.routers import _handle_dispute_team_reversal

    pt = _make_pt()
    db = _make_db_with_pt(pt)

    with patch("stripe.Transfer.create_reversal") as mock_reverse:
        mock_reverse.side_effect = stripe.error.StripeError("insufficient funds")
        # Must not propagate
        _handle_dispute_team_reversal(db, task_id=42)

    assert pt.status == "succeeded"
    assert pt.stripe_reversal_id is None
    assert pt.reversed_at is None


def test_team_dispute_already_reversed_idempotent():
    """If pt.status == 'reversed' already, helper is a no-op."""
    from app.routers import _handle_dispute_team_reversal

    pt = _make_pt(status="reversed")
    pt.stripe_reversal_id = "trr_existing"
    db = _make_db_with_pt(pt)

    with patch("stripe.Transfer.create_reversal") as mock_reverse:
        _handle_dispute_team_reversal(db, task_id=42)

    mock_reverse.assert_not_called()
    assert pt.stripe_reversal_id == "trr_existing"
    db.commit.assert_not_called()
