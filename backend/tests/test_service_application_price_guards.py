"""Regression tests for price guards on service application flow.

Context (2026-04-18): Production 500 seen in user_service_application_routes.py:581
when owner approved an application whose computed price was 0 (base_price=0 on a
negotiable service + no counter-offer, no negotiated_price, no time_slot).
The 0 reward violated DB constraint `chk_tasks_reward_type_consistency` (none of
its 5 branches accept `reward_type='cash' AND reward=0` for `task_source='personal_service'`).

Fixes:
  1. approve-side guard (user_service_application_routes.py): reject price<=0 with
     negotiable-aware 400 error before Task INSERT.
  2. apply-side guard (expert_consultation_routes.py:apply_for_service): reject
     apply to negotiable+no_base_price+no_time_slot services; direct user to /consult.

These tests verify the guards fire with the right status code and error_code,
preventing regression to the 500 behaviour.
"""
from __future__ import annotations

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi import HTTPException


# ---------------------------------------------------------------------------
# Approve-side guard
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_owner_approve_rejects_negotiable_service_with_zero_price():
    """Reproduction of the SA#9 production 500.

    A negotiable service with base_price=0; applicant applied without a price;
    expert clicks approve. Expected: 400 approval_price_not_set_negotiable
    (NOT a 500 IntegrityError from DB constraint).
    """
    from app.user_service_application_routes import owner_approve_application

    application = MagicMock(
        status="pending",
        expert_counter_price=None,
        negotiated_price=None,
        time_slot_id=None,
        applicant_id="u_applicant",
        currency=None,
        is_flexible=0,
        deadline=None,
        task_id=None,
        service_id=9,
    )
    service = MagicMock(
        id=9,
        status="active",
        base_price=0,
        currency="GBP",
        pricing_type="negotiable",
        service_name="插花",
        description="...",
        location="线上",
        category="other",
        images=None,
    )
    current_user = MagicMock(
        id="u_owner",
        stripe_account_id="acct_xxx",
        user_level="normal",
    )

    db = MagicMock()
    db.get = AsyncMock(return_value=service)

    with patch(
        "app.user_service_application_routes._get_application_as_owner",
        AsyncMock(return_value=application),
    ), patch(
        "app.async_crud.AsyncTaskCRUD.get_system_settings_dict",
        AsyncMock(return_value={"vip_price_threshold": 10, "super_vip_price_threshold": 50}),
    ):
        with pytest.raises(HTTPException) as exc_info:
            await owner_approve_application(
                application_id=1,
                request=MagicMock(),
                current_user=current_user,
                db=db,
            )

    assert exc_info.value.status_code == 400
    assert exc_info.value.detail["error_code"] == "approval_price_not_set_negotiable"
    assert exc_info.value.detail["pricing_type"] == "negotiable"
    # Chinese keyword check — ensures the localized message is wired through
    assert "议价" in exc_info.value.detail["message"]


@pytest.mark.asyncio
async def test_owner_approve_rejects_fixed_service_with_zero_price_with_non_negotiable_code():
    """A fixed-price service that somehow has base_price=0 should still be blocked,
    with a distinct error_code 'approval_price_not_set' (no 'negotiable' suffix).
    """
    from app.user_service_application_routes import owner_approve_application

    application = MagicMock(
        status="pending",
        expert_counter_price=None,
        negotiated_price=None,
        time_slot_id=None,
        applicant_id="u_applicant",
        currency=None,
        is_flexible=0,
        deadline=None,
        task_id=None,
        service_id=9,
    )
    service = MagicMock(
        id=9,
        status="active",
        base_price=0,
        currency="GBP",
        pricing_type="fixed",
        service_name="svc",
        description="...",
        location="线上",
        category="other",
        images=None,
    )
    current_user = MagicMock(
        id="u_owner",
        stripe_account_id="acct_xxx",
        user_level="normal",
    )

    db = MagicMock()
    db.get = AsyncMock(return_value=service)

    with patch(
        "app.user_service_application_routes._get_application_as_owner",
        AsyncMock(return_value=application),
    ), patch(
        "app.async_crud.AsyncTaskCRUD.get_system_settings_dict",
        AsyncMock(return_value={"vip_price_threshold": 10, "super_vip_price_threshold": 50}),
    ):
        with pytest.raises(HTTPException) as exc_info:
            await owner_approve_application(
                application_id=1,
                request=MagicMock(),
                current_user=current_user,
                db=db,
            )

    assert exc_info.value.status_code == 400
    assert exc_info.value.detail["error_code"] == "approval_price_not_set"
    assert exc_info.value.detail["pricing_type"] == "fixed"


# ---------------------------------------------------------------------------
# Apply-side guard
# ---------------------------------------------------------------------------


def _mock_service_lookup_then_empty_existing(service):
    """Return a db.execute side_effect that yields `service` on first call
    (service lookup) and an empty result on second call (existing-apps check).
    """
    first = MagicMock()
    first.scalar_one_or_none = MagicMock(return_value=service)
    second = MagicMock()
    second.scalar_one_or_none = MagicMock(return_value=None)
    calls = iter([first, second])

    async def _execute(*args, **kwargs):
        return next(calls)

    return _execute


@pytest.mark.asyncio
async def test_apply_rejects_negotiable_service_with_no_base_price_and_no_slot():
    """Applying to a negotiable + no-base-price + no-time-slot service through
    /apply has no viable price path. Must be 400 apply_requires_consultation
    with suggested_action='consult'.
    """
    from app.expert_consultation_routes import apply_for_service

    service = MagicMock(
        id=9,
        status="active",
        base_price=None,
        pricing_type="negotiable",
        owner_type="user",
        owner_id="u_owner",
        currency="GBP",
    )
    db = MagicMock()
    db.execute = AsyncMock(side_effect=_mock_service_lookup_then_empty_existing(service))

    current_user = MagicMock(id="u_applicant", name="test")

    with pytest.raises(HTTPException) as exc_info:
        await apply_for_service(
            service_id=9,
            body={"message": "I want this"},
            request=MagicMock(),
            db=db,
            current_user=current_user,
        )

    assert exc_info.value.status_code == 400
    assert exc_info.value.detail["error_code"] == "apply_requires_consultation"
    assert exc_info.value.detail["suggested_action"] == "consult"


@pytest.mark.asyncio
async def test_apply_allows_negotiable_service_with_time_slot():
    """A negotiable service WITH a time_slot_id is allowed through /apply —
    the slot supplies the price at approve time.

    We assert the guard does NOT fire; downstream slot-capacity check will fail
    because the slot lookup is not fully mocked, but that's fine — we only
    need to confirm the guard didn't short-circuit with our specific error_code.
    """
    from app.expert_consultation_routes import apply_for_service

    service = MagicMock(
        id=9,
        status="active",
        base_price=None,
        pricing_type="negotiable",
        owner_type="user",
        owner_id="u_owner",
        currency="GBP",
    )
    # Slot lookup will return None → 404 "时间段不存在或已删除"
    first = MagicMock()
    first.scalar_one_or_none = MagicMock(return_value=service)
    second = MagicMock()
    second.scalar_one_or_none = MagicMock(return_value=None)
    third = MagicMock()
    third.scalar_one_or_none = MagicMock(return_value=None)
    calls = iter([first, second, third])

    async def _execute(*args, **kwargs):
        return next(calls)

    db = MagicMock()
    db.execute = AsyncMock(side_effect=_execute)

    current_user = MagicMock(id="u_applicant", name="test")

    with pytest.raises(HTTPException) as exc_info:
        await apply_for_service(
            service_id=9,
            body={"message": "I want this", "time_slot_id": 42},
            request=MagicMock(),
            db=db,
            current_user=current_user,
        )

    # Should NOT be the guard's 400; it's the downstream 404 for missing slot.
    assert exc_info.value.detail != {
        "error_code": "apply_requires_consultation",
    }
    # Any detail that isn't our guard's code is OK — we only assert the guard
    # did NOT fire for negotiable + time_slot_id.
    if isinstance(exc_info.value.detail, dict):
        assert exc_info.value.detail.get("error_code") != "apply_requires_consultation"


@pytest.mark.asyncio
async def test_apply_allows_fixed_service_with_positive_base_price():
    """Fixed-price service with normal base_price should pass the apply guard.

    db.execute is called 3 times on this path (service lookup, existing-apps
    check, application_count increment); last two return objects are unused.
    """
    from app.expert_consultation_routes import apply_for_service

    service = MagicMock(
        id=9,
        status="active",
        base_price=10,
        pricing_type="fixed",
        owner_type="user",
        owner_id="u_owner",
        currency="GBP",
    )

    first = MagicMock()
    first.scalar_one_or_none = MagicMock(return_value=service)
    second = MagicMock()
    second.scalar_one_or_none = MagicMock(return_value=None)
    third = MagicMock()  # update application_count; return value unused
    calls = iter([first, second, third])

    async def _execute(*args, **kwargs):
        try:
            return next(calls)
        except StopIteration:
            # Any additional execute calls return a harmless mock
            return MagicMock()

    db = MagicMock()
    db.execute = AsyncMock(side_effect=_execute)
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    db.add = MagicMock()

    current_user = MagicMock(id="u_applicant", name="test")

    with patch(
        "app.expert_consultation_routes._notify_team_admins_new_application",
        AsyncMock(),
    ):
        result = await apply_for_service(
            service_id=9,
            body={"message": "I want this"},
            request=MagicMock(),
            db=db,
            current_user=current_user,
        )

    assert result["service_id"] == 9
    assert result["status"] == "pending"


# ---------------------------------------------------------------------------
# Team-service approve guard (_approve_team_service_application)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_team_service_approve_rejects_zero_price_with_negotiable_code():
    """Mirror of the personal-service approve guard but for team services
    (expert_consultation_routes._approve_team_service_application). Same SA#9
    class of bug: price falls through to service.base_price=0 -> DB constraint
    violation. Guard must fire first.
    """
    from app.expert_consultation_routes import _approve_team_service_application

    application = MagicMock(
        status="pending",
        expert_counter_price=None,
        final_price=None,
        negotiated_price=None,
        time_slot_id=None,
        applicant_id="u_applicant",
        currency=None,
        is_flexible=0,
        deadline=None,
        task_id=None,
        service_id=9,
    )
    service = MagicMock(
        id=9,
        status="active",
        base_price=0,
        currency="GBP",
        pricing_type="negotiable",
        service_name="team svc",
        description="...",
        location="线上",
        category="other",
        images=None,
    )
    expert = MagicMock(id="e_team", stripe_account_id="acct_team")

    # db.get is called for: service, expert, applicant. Return service first,
    # then expert, then an applicant user.
    applicant = MagicMock(id="u_applicant", name="Alice", email="a@x.com")
    get_calls = iter([service, expert, applicant])

    db = MagicMock()
    db.get = AsyncMock(side_effect=lambda *a, **kw: next(get_calls))

    current_user = MagicMock(
        id="u_owner",
        stripe_account_id="acct_owner",
        user_level="normal",
    )

    with patch(
        "app.services.expert_task_resolver.resolve_task_taker_from_service",
        AsyncMock(return_value=("u_team_owner", "e_team")),
    ):
        with pytest.raises(HTTPException) as exc_info:
            await _approve_team_service_application(
                db=db,
                request=MagicMock(),
                current_user=current_user,
                application=application,
            )

    assert exc_info.value.status_code == 400
    assert exc_info.value.detail["error_code"] == "approval_price_not_set_negotiable"


# ---------------------------------------------------------------------------
# Pydantic schema guard (F)
# ---------------------------------------------------------------------------


def test_personal_service_create_rejects_zero_base_price_for_fixed():
    """Tightening PersonalServiceCreate: base_price=0 is not allowed when
    pricing_type='fixed' (or any non-negotiable). Prevents an admin/API caller
    from seeding the SA#9 failure mode into the DB in the first place.
    """
    from pydantic import ValidationError
    from app.schemas import PersonalServiceCreate

    with pytest.raises(ValidationError) as exc_info:
        PersonalServiceCreate(
            service_name="svc",
            description="x",
            base_price=0,
            pricing_type="fixed",
        )
    errors = exc_info.value.errors()
    assert any("greater than 0" in str(e.get("msg", "")) for e in errors), (
        f"expected 'greater than 0' validator, got: {errors}"
    )


def test_personal_service_create_allows_zero_base_price_for_negotiable():
    """Negotiable personal services legitimately have base_price=0 (面议).
    The create schema must still let this through — approve-side guard is the
    correct backstop for negotiable-with-no-price.
    """
    from app.schemas import PersonalServiceCreate

    svc = PersonalServiceCreate(
        service_name="面议svc",
        description="x",
        base_price=0,
        pricing_type="negotiable",
    )
    assert svc.pricing_type == "negotiable"
    assert float(svc.base_price) == 0.0


def test_personal_service_create_allows_positive_base_price_for_fixed():
    """Happy path sanity: pricing_type='fixed' + base_price>0 goes through."""
    from app.schemas import PersonalServiceCreate

    svc = PersonalServiceCreate(
        service_name="svc",
        description="x",
        base_price=10,
        pricing_type="fixed",
    )
    assert float(svc.base_price) == 10.0


# ---------------------------------------------------------------------------
# Static check — Flutter error_localizer wiring (G)
# ---------------------------------------------------------------------------


def test_flutter_error_localizer_has_all_three_codes():
    """Regression: ensure the 3 backend error_codes remain wired into the
    Flutter error_localizer switch. If someone removes a case, this fails
    before the app silently shows raw backend strings.
    """
    from pathlib import Path

    # tests/ -> backend/ -> repo_root/
    repo_root = Path(__file__).resolve().parent.parent.parent
    localizer_path = repo_root / "link2ur" / "lib" / "core" / "utils" / "error_localizer.dart"
    assert localizer_path.exists(), f"error_localizer.dart not found at {localizer_path}"

    content = localizer_path.read_text(encoding="utf-8")
    required_codes = [
        ("approval_price_not_set_negotiable", "errorApprovalPriceNotSetNegotiable"),
        ("approval_price_not_set", "errorApprovalPriceNotSet"),
        ("apply_requires_consultation", "errorApplyRequiresConsultation"),
    ]
    for code, l10n_key in required_codes:
        assert f"case '{code}'" in content, (
            f"error_localizer.dart missing switch case for '{code}' — "
            f"backend fix 25992bb0c is not surfaced to users"
        )
        assert l10n_key in content, (
            f"error_localizer.dart references '{code}' but does not return "
            f"context.l10n.{l10n_key}"
        )
