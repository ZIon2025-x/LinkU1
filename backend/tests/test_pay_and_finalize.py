"""Tests for the `POST /api/applications/{id}/pay-and-finalize` endpoint.

This endpoint lets the applicant finalize the order + start payment in one step
after price_agreed, rather than applicant→formal_apply→provider→approve. It
delegates to the team or personal finalize helper depending on service type.

Scenarios covered:
  - Auth: non-applicant → 403
  - Status guard: wrong status → 400
  - Team path: delegates to _approve_team_service_application with the applicant
    as current_user
  - Personal path: loads service_owner_id → User, passes as owner_user to
    finalize_personal_service_application
  - Double-tap / race: second request sees status=approved (first request
    already committed), returns idempotent payment data (PI retrieve + fresh EK)
  - Strict payment-info validation: if helper silently degraded (missing
    ephemeral_key_secret etc.), endpoint returns 502 so Flutter doesn't open a
    broken payment sheet
"""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import HTTPException


def _mock_db_returning(application):
    db = MagicMock()
    db.execute = AsyncMock()
    db.execute.return_value.scalar_one_or_none = MagicMock(return_value=application)
    db.commit = AsyncMock()
    db.get = AsyncMock(return_value=None)
    db.add = MagicMock()
    return db


# ---------------------------------------------------------------------------
# Auth / status
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_rejects_non_applicant():
    from app.expert_consultation_routes import pay_and_finalize

    application = MagicMock(
        id=1,
        applicant_id="u_applicant",
        status="price_agreed",
        new_expert_id=None,
        service_owner_id="u_owner",
        task_id=None,
    )
    db = _mock_db_returning(application)
    current_user = MagicMock(id="u_stranger")

    with pytest.raises(HTTPException) as exc_info:
        await pay_and_finalize(
            application_id=1,
            body={},
            request=MagicMock(),
            db=db,
            current_user=current_user,
        )

    assert exc_info.value.status_code == 403


@pytest.mark.asyncio
async def test_rejects_wrong_status():
    from app.expert_consultation_routes import pay_and_finalize

    application = MagicMock(
        id=1,
        applicant_id="u_applicant",
        status="consulting",                 # not price_agreed and not approved
        new_expert_id=None,
        service_owner_id="u_owner",
        task_id=None,
    )
    db = _mock_db_returning(application)
    current_user = MagicMock(id="u_applicant")

    with pytest.raises(HTTPException) as exc_info:
        await pay_and_finalize(
            application_id=1,
            body={},
            request=MagicMock(),
            db=db,
            current_user=current_user,
        )

    assert exc_info.value.status_code == 400


# ---------------------------------------------------------------------------
# Happy paths — team and personal delegate to correct helper
# ---------------------------------------------------------------------------


_FULL_PAYMENT_RESPONSE = {
    "message": "OK",
    "application_id": 1,
    "task_id": 999,
    "task_status": "pending_payment",
    "payment_intent_id": "pi_test",
    "client_secret": "pi_test_secret",
    "amount": 10000,
    "amount_display": "100.00",
    "currency": "GBP",
    "customer_id": "cus_test",
    "ephemeral_key_secret": "ek_test_secret",
}


@pytest.mark.asyncio
async def test_team_path_delegates_to_team_helper():
    from app.expert_consultation_routes import pay_and_finalize

    application = MagicMock(
        id=1,
        applicant_id="u_applicant",
        status="price_agreed",
        new_expert_id="e_team123",           # team path
        service_owner_id=None,
        task_id=10,
    )
    db = _mock_db_returning(application)
    current_user = MagicMock(id="u_applicant")

    team_helper = AsyncMock(return_value=_FULL_PAYMENT_RESPONSE)
    with patch(
        "app.expert_consultation_routes._approve_team_service_application",
        team_helper,
    ):
        result = await pay_and_finalize(
            application_id=1,
            body={},
            request=MagicMock(),
            db=db,
            current_user=current_user,
        )

    team_helper.assert_awaited_once()
    # current_user argument was the applicant
    _, kw = team_helper.call_args
    assert kw["current_user"] is current_user
    assert kw["application"] is application
    assert result is _FULL_PAYMENT_RESPONSE


@pytest.mark.asyncio
async def test_personal_path_loads_owner_and_delegates():
    from app.expert_consultation_routes import pay_and_finalize

    application = MagicMock(
        id=2,
        applicant_id="u_applicant",
        status="price_agreed",
        new_expert_id=None,                  # personal path
        service_owner_id="u_owner",
        task_id=20,
    )
    owner_user = MagicMock(id="u_owner")
    db = _mock_db_returning(application)
    db.get = AsyncMock(return_value=owner_user)
    current_user = MagicMock(id="u_applicant")

    personal_helper = AsyncMock(return_value=_FULL_PAYMENT_RESPONSE)
    with patch(
        "app.user_service_application_routes.finalize_personal_service_application",
        personal_helper,
    ):
        result = await pay_and_finalize(
            application_id=2,
            body={"deadline": "2026-12-31T00:00:00Z", "is_flexible": False},
            request=MagicMock(),
            db=db,
            current_user=current_user,
        )

    personal_helper.assert_awaited_once()
    _, kw = personal_helper.call_args
    assert kw["owner_user"] is owner_user
    assert kw["application"] is application
    assert kw["deadline_override"] is not None     # parsed from ISO string
    assert kw["is_flexible_override"] is False
    assert result is _FULL_PAYMENT_RESPONSE


# ---------------------------------------------------------------------------
# Idempotency — double-tap race: second request sees approved
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_idempotent_when_already_approved_returns_fresh_payment_info():
    """When status=approved already (first request committed), the endpoint
    must re-hydrate payment info: retrieve existing PI + create fresh
    EphemeralKey. This is what lets a double-tap converge instead of creating
    a second Task + PI."""
    from app.expert_consultation_routes import pay_and_finalize

    application = MagicMock(
        id=3,
        applicant_id="u_applicant",
        status="approved",                   # first request already committed
        new_expert_id="e_team",
        service_owner_id=None,
        task_id=777,
    )
    existing_task = MagicMock(id=777, payment_intent_id="pi_prev", status="pending_payment")
    applicant_user = MagicMock(id="u_applicant")
    db = _mock_db_returning(application)
    db.get = AsyncMock(side_effect=[existing_task, applicant_user])
    current_user = MagicMock(id="u_applicant")

    pi = MagicMock(id="pi_prev", client_secret="cs_prev", amount=5000, currency="gbp")
    ek = MagicMock(secret="ek_fresh")

    with patch("stripe.PaymentIntent.retrieve", return_value=pi), \
         patch("stripe.EphemeralKey.create", return_value=ek), \
         patch(
             "app.utils.stripe_utils.get_or_create_stripe_customer",
             return_value="cus_prev",
         ):
        result = await pay_and_finalize(
            application_id=3,
            body={},
            request=MagicMock(),
            db=db,
            current_user=current_user,
        )

    assert result["task_id"] == 777
    assert result["client_secret"] == "cs_prev"
    assert result["customer_id"] == "cus_prev"
    assert result["ephemeral_key_secret"] == "ek_fresh"


# ---------------------------------------------------------------------------
# Strict payment-info validation
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_missing_ephemeral_key_raises_502():
    """If the helper silently degraded (Stripe EphemeralKey failed), the
    endpoint must refuse to return a broken response that would leave Flutter
    stuck on a misconfigured payment sheet."""
    from app.expert_consultation_routes import pay_and_finalize

    application = MagicMock(
        id=4,
        applicant_id="u_applicant",
        status="price_agreed",
        new_expert_id="e_team",
        service_owner_id=None,
        task_id=40,
    )
    db = _mock_db_returning(application)
    current_user = MagicMock(id="u_applicant")

    degraded_response = dict(_FULL_PAYMENT_RESPONSE)
    degraded_response["ephemeral_key_secret"] = None

    team_helper = AsyncMock(return_value=degraded_response)
    with patch(
        "app.expert_consultation_routes._approve_team_service_application",
        team_helper,
    ):
        with pytest.raises(HTTPException) as exc_info:
            await pay_and_finalize(
                application_id=4,
                body={},
                request=MagicMock(),
                db=db,
                current_user=current_user,
            )

    assert exc_info.value.status_code == 502
    assert "付款准备失败" in exc_info.value.detail


@pytest.mark.asyncio
async def test_missing_client_secret_raises_502():
    from app.expert_consultation_routes import pay_and_finalize

    application = MagicMock(
        id=5,
        applicant_id="u_applicant",
        status="price_agreed",
        new_expert_id="e_team",
        service_owner_id=None,
        task_id=50,
    )
    db = _mock_db_returning(application)
    current_user = MagicMock(id="u_applicant")

    degraded_response = dict(_FULL_PAYMENT_RESPONSE)
    degraded_response["client_secret"] = None

    team_helper = AsyncMock(return_value=degraded_response)
    with patch(
        "app.expert_consultation_routes._approve_team_service_application",
        team_helper,
    ):
        with pytest.raises(HTTPException) as exc_info:
            await pay_and_finalize(
                application_id=5,
                body={},
                request=MagicMock(),
                db=db,
                current_user=current_user,
            )

    assert exc_info.value.status_code == 502
