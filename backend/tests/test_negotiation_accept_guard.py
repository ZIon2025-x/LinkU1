"""Regression tests for the accept-guard on service consultation negotiation.

Context (2026-04-19): `POST /api/applications/{id}/negotiate-response` with
`action=accept` only verified the caller was party to the application but did not
verify that the caller was accepting the OTHER party's offer. Combined with a
sender/receiver bug that made every negotiation card render as "incoming" with
action buttons on both sides, a user could propose a price and then click "accept"
on their own card — backend would set `final_price = their own price` and
transition to `price_agreed`.

Fix in `expert_consultation_routes.respond_to_negotiation`:
  - is_applicant accepts → other_side_price = expert_counter_price (must exist)
  - is_provider accepts → other_side_price = negotiated_price (must exist)
  - Missing → HTTPException 400 "尚未收到对方报价,不能接受"

Plus clear-invariant: new offers clear the opposite side's price field so at most
one is non-None at a time. These tests pin the behaviour.
"""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import HTTPException


def _mock_app_result(application):
    result = MagicMock()
    result.scalar_one_or_none = MagicMock(return_value=application)
    return result


def _mock_db_with_application(application):
    db = MagicMock()
    db.execute = AsyncMock(return_value=_mock_app_result(application))
    db.commit = AsyncMock()
    db.get = AsyncMock(return_value=None)  # task not needed for auth/guard tests
    db.add = MagicMock()
    return db


# ---------------------------------------------------------------------------
# Applicant self-accept (the reported bug)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_applicant_cannot_self_accept_own_offer():
    """Applicant proposed price X via /negotiate-price → negotiated_price=X,
    expert_counter_price=None (cleared by the clear-invariant). Applicant
    immediately calls /negotiate-response action=accept. Must 400 — applicant
    has nothing to accept (provider hasn't quoted)."""
    from app.expert_consultation_routes import respond_to_negotiation

    application = MagicMock(
        id=42,
        applicant_id="u_applicant",
        new_expert_id=None,
        service_owner_id="u_owner",
        status="negotiating",
        negotiated_price=100,              # applicant's own offer
        expert_counter_price=None,         # provider has NOT offered
        task_id=None,
    )
    db = _mock_db_with_application(application)
    current_user = MagicMock(id="u_applicant")

    with pytest.raises(HTTPException) as exc_info:
        await respond_to_negotiation(
            application_id=42,
            body={"action": "accept"},
            request=MagicMock(),
            db=db,
            current_user=current_user,
        )

    assert exc_info.value.status_code == 400
    assert "尚未收到对方报价" in exc_info.value.detail


@pytest.mark.asyncio
async def test_provider_cannot_self_accept_own_quote():
    """Symmetric: provider quoted Y → expert_counter_price=Y, negotiated_price=None.
    Provider tries to accept their own quote → 400."""
    from app.expert_consultation_routes import respond_to_negotiation

    application = MagicMock(
        id=43,
        applicant_id="u_applicant",
        new_expert_id=None,
        service_owner_id="u_owner",
        status="negotiating",
        negotiated_price=None,             # applicant has NOT offered
        expert_counter_price=150,          # provider's own quote
        task_id=None,
    )
    db = _mock_db_with_application(application)
    current_user = MagicMock(id="u_owner")

    with pytest.raises(HTTPException) as exc_info:
        await respond_to_negotiation(
            application_id=43,
            body={"action": "accept"},
            request=MagicMock(),
            db=db,
            current_user=current_user,
        )

    assert exc_info.value.status_code == 400
    assert "尚未收到对方报价" in exc_info.value.detail


# ---------------------------------------------------------------------------
# Correct accept paths
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_applicant_accepts_provider_quote_uses_counter_price():
    """Provider quoted Y → applicant accepts → final_price = Y, price_agreed."""
    from app.expert_consultation_routes import respond_to_negotiation

    application = MagicMock(
        id=44,
        applicant_id="u_applicant",
        new_expert_id=None,
        service_owner_id="u_owner",
        status="negotiating",
        negotiated_price=None,             # cleared by provider's quote
        expert_counter_price=200,          # provider's quote
        final_price=None,
        price_agreed_at=None,
        updated_at=None,
        task_id=None,
    )
    db = _mock_db_with_application(application)
    current_user = MagicMock(id="u_applicant")

    await respond_to_negotiation(
        application_id=44,
        body={"action": "accept"},
        request=MagicMock(),
        db=db,
        current_user=current_user,
    )

    assert application.final_price == 200
    assert application.status == "price_agreed"


@pytest.mark.asyncio
async def test_provider_accepts_applicant_offer_uses_negotiated_price():
    """Applicant offered X → provider accepts → final_price = X, price_agreed."""
    from app.expert_consultation_routes import respond_to_negotiation

    application = MagicMock(
        id=45,
        applicant_id="u_applicant",
        new_expert_id=None,
        service_owner_id="u_owner",
        status="negotiating",
        negotiated_price=180,              # applicant's offer
        expert_counter_price=None,         # cleared
        final_price=None,
        price_agreed_at=None,
        updated_at=None,
        task_id=None,
    )
    db = _mock_db_with_application(application)
    current_user = MagicMock(id="u_owner")

    await respond_to_negotiation(
        application_id=45,
        body={"action": "accept"},
        request=MagicMock(),
        db=db,
        current_user=current_user,
    )

    assert application.final_price == 180
    assert application.status == "price_agreed"


# ---------------------------------------------------------------------------
# Clear-invariant: new counter clears the other side's stale price
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_applicant_counter_clears_expert_counter_price():
    """After provider quoted Y then applicant counters Z via /negotiate-response,
    expert_counter_price must be None (cleared). This ensures provider's
    subsequent `accept` picks up Z (applicant's latest), not Y (stale)."""
    from app.expert_consultation_routes import respond_to_negotiation

    application = MagicMock(
        id=46,
        applicant_id="u_applicant",
        new_expert_id=None,
        service_owner_id="u_owner",
        status="negotiating",
        negotiated_price=100,              # applicant's earlier offer
        expert_counter_price=200,          # provider's quote we want cleared
        updated_at=None,
        task_id=None,
    )
    db = _mock_db_with_application(application)
    current_user = MagicMock(id="u_applicant")

    await respond_to_negotiation(
        application_id=46,
        body={"action": "counter", "price": 150},
        request=MagicMock(),
        db=db,
        current_user=current_user,
    )

    assert application.negotiated_price == 150
    assert application.expert_counter_price is None  # cleared
    assert application.status == "negotiating"
