"""Tests for team-aware service approval flow.

Validates _resolve_taker_for_service_application — the helper that resolves
the (taker_id, taker_expert_id, taker_stripe_account_id) tuple from a
ServiceApplication. For team services (owner_type='expert'), the Stripe
Connect destination must come from experts.stripe_account_id, not from a
User row referenced via the (NULL) application.expert_id column.

spec: docs/superpowers/plans/2026-04-07-expert-team-as-task-taker.md — Phase 4.5
"""
import pytest
from unittest.mock import AsyncMock, MagicMock
from fastapi import HTTPException


def _make_async_db(get_results):
    """Build a MagicMock AsyncSession whose .get(Model, key) returns from a dict.

    `get_results` is a dict keyed by (ModelClassName, key) -> object|None.
    """
    db = MagicMock()

    async def get_side_effect(model, key):
        return get_results.get((model.__name__, key))

    db.get = AsyncMock(side_effect=get_side_effect)
    return db


@pytest.mark.asyncio
async def test_team_service_approval_uses_team_stripe_account(monkeypatch):
    """For owner_type='expert' services, taker_stripe_account_id must come
    from the Expert row, not from a (non-existent) User row."""
    from app.task_expert_routes import _resolve_taker_for_service_application
    from app import models
    from app.models_expert import Expert

    application = MagicMock()
    application.service_id = 1
    application.expert_id = None  # team service: NULL

    service = MagicMock()
    service.id = 1
    service.owner_type = "expert"
    service.owner_id = "e_team01"
    service.currency = "GBP"

    expert = MagicMock(spec=Expert)
    expert.id = "e_team01"
    expert.stripe_account_id = "acct_team_123"

    db = _make_async_db({
        ("TaskExpertService", 1): service,
        ("Expert", "e_team01"): expert,
    })

    # Mock the resolver to return team values without doing real DB work
    async def fake_resolver(_db, _service):
        assert _service is service
        return ("u_owner_01", "e_team01")

    monkeypatch.setattr(
        "app.task_expert_routes.resolve_task_taker_from_service",
        fake_resolver,
    )

    taker_id, taker_expert_id, stripe_account_id = await _resolve_taker_for_service_application(
        db, application
    )

    assert taker_id == "u_owner_01"
    assert taker_expert_id == "e_team01"
    assert stripe_account_id == "acct_team_123"


@pytest.mark.asyncio
async def test_team_service_approval_propagates_resolver_error(monkeypatch):
    """When the resolver raises 409 (e.g., team Stripe not ready),
    the helper must propagate the HTTPException unchanged."""
    from app.task_expert_routes import _resolve_taker_for_service_application

    application = MagicMock()
    application.service_id = 1

    service = MagicMock()
    service.id = 1
    service.owner_type = "expert"

    db = _make_async_db({("TaskExpertService", 1): service})

    async def failing_resolver(_db, _service):
        raise HTTPException(status_code=409, detail={
            "error_code": "expert_stripe_not_ready",
            "message": "This service is temporarily unavailable",
        })

    monkeypatch.setattr(
        "app.task_expert_routes.resolve_task_taker_from_service",
        failing_resolver,
    )

    with pytest.raises(HTTPException) as exc_info:
        await _resolve_taker_for_service_application(db, application)

    assert exc_info.value.status_code == 409
    assert exc_info.value.detail["error_code"] == "expert_stripe_not_ready"


@pytest.mark.asyncio
async def test_individual_service_approval_uses_user_stripe_account(monkeypatch):
    """Regression: for owner_type='user' services, taker_stripe_account_id
    comes from the User row."""
    from app.task_expert_routes import _resolve_taker_for_service_application

    application = MagicMock()
    application.service_id = 7
    application.expert_id = "u_indiv_01"

    service = MagicMock()
    service.id = 7
    service.owner_type = "user"
    service.owner_id = "u_indiv_01"
    service.currency = "GBP"

    user = MagicMock()
    user.id = "u_indiv_01"
    user.stripe_account_id = "acct_indiv_999"
    user.name = "Indie Dev"

    db = _make_async_db({
        ("TaskExpertService", 7): service,
        ("User", "u_indiv_01"): user,
    })

    async def fake_resolver(_db, _service):
        return ("u_indiv_01", None)

    monkeypatch.setattr(
        "app.task_expert_routes.resolve_task_taker_from_service",
        fake_resolver,
    )

    taker_id, taker_expert_id, stripe_account_id = await _resolve_taker_for_service_application(
        db, application
    )

    assert taker_id == "u_indiv_01"
    assert taker_expert_id is None
    assert stripe_account_id == "acct_indiv_999"


@pytest.mark.asyncio
async def test_individual_service_no_stripe_account_raises_400(monkeypatch):
    """If the individual taker User has no Stripe Connect account, helper raises 400."""
    from app.task_expert_routes import _resolve_taker_for_service_application

    application = MagicMock()
    application.service_id = 8
    application.expert_id = "u_indiv_02"

    service = MagicMock()
    service.id = 8
    service.owner_type = "user"

    user = MagicMock()
    user.id = "u_indiv_02"
    user.stripe_account_id = None

    db = _make_async_db({
        ("TaskExpertService", 8): service,
        ("User", "u_indiv_02"): user,
    })

    async def fake_resolver(_db, _service):
        return ("u_indiv_02", None)

    monkeypatch.setattr(
        "app.task_expert_routes.resolve_task_taker_from_service",
        fake_resolver,
    )

    with pytest.raises(HTTPException) as exc_info:
        await _resolve_taker_for_service_application(db, application)

    assert exc_info.value.status_code == 400
    assert exc_info.value.detail["error_code"] == "taker_no_stripe_account"


@pytest.mark.asyncio
async def test_service_not_found_raises_404():
    """If the application's service has been deleted, helper raises 404."""
    from app.task_expert_routes import _resolve_taker_for_service_application

    application = MagicMock()
    application.service_id = 999

    db = _make_async_db({})  # no service in get_results

    with pytest.raises(HTTPException) as exc_info:
        await _resolve_taker_for_service_application(db, application)

    assert exc_info.value.status_code == 404
