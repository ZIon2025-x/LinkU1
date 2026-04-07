"""End-to-end mock-based smoke tests for team task money flow.

Doesn't use FastAPI TestClient or real DB — these are 'integration tests'
that verify the chain of helpers/services produces the expected end state
for a team task lifecycle.
"""
import pytest
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock, patch
from datetime import datetime


# ========== Test 1: Team service order → task creation → payout ==========

@pytest.mark.asyncio
async def test_e2e_team_service_order_resolves_team_taker():
    """A team service order resolves to (team_owner.user_id, expert.id) via the helper."""
    from app.services.expert_task_resolver import resolve_task_taker_from_service

    db = MagicMock()
    db.get = AsyncMock()

    expert = MagicMock(
        id='e_team01',
        stripe_account_id='acct_team01',
        stripe_onboarding_complete=True,
    )
    member = MagicMock(user_id='u_owner01', role='owner', status='active')
    db.get.return_value = expert
    result = MagicMock()
    result.scalar_one_or_none.return_value = member
    db.execute = AsyncMock(return_value=result)

    service = MagicMock(
        owner_type='expert',
        owner_id='e_team01',
        currency='GBP',
    )

    taker_id, taker_expert_id = await resolve_task_taker_from_service(db, service)
    assert taker_id == 'u_owner01'
    assert taker_expert_id == 'e_team01'


# ========== Test 2: Resolved taker_expert_id → payout destination is team Stripe ==========

def test_e2e_team_task_payout_destination_is_team_stripe():
    """resolve_payout_destination returns experts.stripe_account_id for team tasks."""
    from app.services.expert_task_resolver import resolve_payout_destination

    db = MagicMock()
    task = MagicMock(taker_expert_id='e_team01', taker_id='u_owner01')
    expert = MagicMock(
        id='e_team01',
        stripe_account_id='acct_team_stripe_xyz',
        stripe_onboarding_complete=True,
    )
    db.query.return_value.filter.return_value.first.return_value = expert

    destination = resolve_payout_destination(db, task)
    assert destination == 'acct_team_stripe_xyz'
    assert destination != 'u_owner01'  # NOT the user's stripe — the team's


# ========== Test 3: create_transfer_record persists taker_expert_id ==========

def test_e2e_team_task_transfer_record_persists_taker_expert_id():
    """create_transfer_record sets taker_expert_id on the PaymentTransfer row."""
    from app.payment_transfer_service import create_transfer_record

    db = MagicMock()
    # No existing PaymentTransfer
    db.query.return_value.filter.return_value.first.return_value = None
    db.add = MagicMock()
    db.flush = MagicMock()
    db.refresh = MagicMock()

    transfer_record = create_transfer_record(
        db=db,
        task_id=42,
        taker_id='u_owner01',
        poster_id='u_customer01',
        amount=Decimal('100.00'),
        currency='GBP',
        taker_expert_id='e_team01',
        commit=False,
    )

    assert transfer_record is not None
    db.add.assert_called_once()
    added = db.add.call_args[0][0]
    # The created PaymentTransfer should have taker_expert_id set from the kwarg
    assert getattr(added, 'taker_expert_id', None) == 'e_team01'
    assert getattr(added, 'task_id', None) == 42
    assert getattr(added, 'taker_id', None) == 'u_owner01'
