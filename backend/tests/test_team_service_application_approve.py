"""Tests for team service application approval — POST /api/applications/{id}/approve.

When a team owner/admin approves a customer's application to a team-owned
TaskExpertService, the endpoint MUST:

  1. Resolve the team taker via resolve_task_taker_from_service →
     (team_owner.user_id, expert.id)
  2. Create a Task with both taker_id (legal payee) AND taker_expert_id
     (economic taker)
  3. Create a Stripe PaymentIntent so the customer can pay
  4. Link application.task_id and set status='approved'
  5. Return enough info for the customer's app to complete payment

Spec: 2026-04-06-expert-team-as-task-taker-design.md §4.2
This test covers the gap that plan v3 left by reverting commits 31ad8fc5c
and 879d876a0 without providing a replacement Task creation site.
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi import HTTPException


def _make_application(
    application_id=101,
    service_id=42,
    applicant_id="u_customer1",
    new_expert_id="e_team01",
    status="pending",
    final_price=None,
    negotiated_price=None,
    is_flexible=0,
    deadline=None,
    task_id=None,
):
    a = MagicMock()
    a.id = application_id
    a.service_id = service_id
    a.applicant_id = applicant_id
    a.new_expert_id = new_expert_id
    a.service_owner_id = None  # team service: no individual owner
    a.expert_id = None
    a.status = status
    a.final_price = final_price
    a.negotiated_price = negotiated_price
    a.expert_counter_price = None
    a.is_flexible = is_flexible
    a.deadline = deadline
    a.task_id = task_id
    a.currency = "GBP"
    return a


def _make_service(
    service_id=42,
    owner_type="expert",
    owner_id="e_team01",
    base_price=20.0,
    currency="GBP",
    status="active",
    name="Team Yoga 1-on-1",
):
    s = MagicMock()
    s.id = service_id
    s.owner_type = owner_type
    s.owner_id = owner_id
    s.base_price = base_price
    s.currency = currency
    s.status = status
    s.service_name = name
    s.description = "A team yoga class"
    s.location = "London"
    s.category = "sports"
    s.images = None
    return s


def _make_expert(
    expert_id="e_team01",
    stripe_account_id="acct_team_xyz",
    stripe_ready=True,
    name="Yoga Team",
):
    e = MagicMock()
    e.id = expert_id
    e.stripe_account_id = stripe_account_id
    e.stripe_onboarding_complete = stripe_ready
    e.name = name
    return e


def _make_owner_member(user_id="u_owner01"):
    m = MagicMock()
    m.user_id = user_id
    m.role = "owner"
    m.status = "active"
    return m


def _make_current_user(user_id="u_admin01", name="Admin"):
    u = MagicMock()
    u.id = user_id
    u.name = name
    return u


def _make_applicant_user(user_id="u_customer1", name="Customer"):
    u = MagicMock()
    u.id = user_id
    u.name = name
    u.stripe_customer_id = None
    return u


def _build_db(application, service, expert, owner_member, applicant_user):
    """Build a mock AsyncSession threading through the endpoint's DB calls.

    Order of awaited operations in the fixed endpoint:
      1. db.execute(select(ServiceApplication)) → application
      2. _get_member_or_403 (patched)
      3. db.get(TaskExpertService, service_id) → service
      4. resolve_task_taker_from_service:
            db.get(Expert, expert_id) → expert
            db.execute(select(ExpertMember)) → owner_member
      5. db.get(User, applicant_id) → applicant_user
      6. db.add(new_task)
      7. db.flush() (allocates task.id)
      8. stripe.PaymentIntent.create (patched)
      9. db.commit()
    """
    db = MagicMock()

    application_result = MagicMock()
    application_result.scalar_one_or_none.return_value = application

    member_result = MagicMock()
    member_result.scalar_one_or_none.return_value = owner_member

    db.execute = AsyncMock(side_effect=[application_result, member_result])

    # db.get is called in this order by the fixed endpoint:
    # 1. TaskExpertService (in our new code)
    # 2. Expert (inside resolve_task_taker_from_service → _resolve_team_taker)
    # 3. Expert (in our new code, to read stripe_account_id + name for metadata)
    # 4. User (applicant lookup)
    db.get = AsyncMock(side_effect=[service, expert, expert, applicant_user])

    db.add = MagicMock()
    db.flush = AsyncMock()
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    db.rollback = AsyncMock()

    return db


@pytest.mark.asyncio
async def test_team_service_approve_creates_task_with_taker_expert_id():
    """Happy path: approve a team service application creates a Task with
    taker_expert_id set to the team's id and taker_id set to the team owner's
    user_id."""
    from app.expert_consultation_routes import approve_application

    application = _make_application()
    service = _make_service()
    expert = _make_expert()
    owner_member = _make_owner_member(user_id="u_owner01")
    applicant_user = _make_applicant_user()

    db = _build_db(application, service, expert, owner_member, applicant_user)

    captured = {}

    def add_capture(obj):
        captured.setdefault("added", []).append(obj)
        # Simulate db assigning an id after flush
        if not hasattr(obj, "id") or obj.id is None:
            obj.id = 999

    db.add.side_effect = add_capture

    fake_payment_intent = MagicMock()
    fake_payment_intent.id = "pi_test_team_001"
    fake_payment_intent.client_secret = "pi_test_team_001_secret_xyz"
    fake_payment_intent.amount = 2000
    fake_payment_intent.currency = "gbp"

    with patch(
        "app.expert_consultation_routes._get_member_or_403",
        new=AsyncMock(return_value=MagicMock()),
    ), patch("stripe.PaymentIntent.create", return_value=fake_payment_intent), patch(
        "app.task_notifications.send_service_application_approved_notification",
        new=AsyncMock(),
    ):
        result = await approve_application(
            application_id=101,
            body={},
            request=MagicMock(),
            db=db,
            current_user=_make_current_user(),
        )

    # A Task must have been created
    added_tasks = [
        o for o in captured.get("added", []) if type(o).__name__ in ("Task", "MagicMock")
    ]
    # Find the actual Task instance among added objects
    from app import models
    task_objs = [o for o in captured.get("added", []) if isinstance(o, models.Task)]
    assert len(task_objs) == 1, f"Expected exactly one Task to be created, got {captured.get('added')}"
    new_task = task_objs[0]

    # CRITICAL: taker_expert_id must be the team id
    assert new_task.taker_expert_id == "e_team01", (
        f"Task.taker_expert_id should be team id, got {new_task.taker_expert_id}"
    )
    # taker_id must be the team owner's user_id (not the approving member)
    assert new_task.taker_id == "u_owner01", (
        f"Task.taker_id should be team owner user_id, got {new_task.taker_id}"
    )
    # Posted by the customer
    assert new_task.poster_id == "u_customer1"
    # Linked to the service
    assert new_task.expert_service_id == 42
    # Pending payment, not directly in_progress
    assert new_task.status == "pending_payment"
    assert new_task.is_paid == 0
    # Task source must mark this as expert service
    assert new_task.task_source == "expert_service"

    # Application got linked to the task
    assert application.task_id == new_task.id
    assert application.status == "approved"

    # Response carries the client_secret so the customer's app can pay
    assert result["task_id"] == new_task.id
    assert result["client_secret"] == "pi_test_team_001_secret_xyz"
    assert result["payment_intent_id"] == "pi_test_team_001"


@pytest.mark.asyncio
async def test_team_service_approve_idempotent_when_already_approved():
    """If the application was already approved and a task exists, the
    endpoint must return the existing task without creating a new one."""
    from app.expert_consultation_routes import approve_application

    application = _make_application(status="approved", task_id=555)
    service = _make_service()
    expert = _make_expert()
    owner_member = _make_owner_member()
    applicant_user = _make_applicant_user()

    db = _build_db(application, service, expert, owner_member, applicant_user)

    with patch(
        "app.expert_consultation_routes._get_member_or_403",
        new=AsyncMock(return_value=MagicMock()),
    ):
        result = await approve_application(
            application_id=101,
            body={},
            request=MagicMock(),
            db=db,
            current_user=_make_current_user(),
        )

    # No new Task should be added on the idempotent path
    db.add.assert_not_called()
    assert result["task_id"] == 555


@pytest.mark.asyncio
async def test_team_service_approve_blocked_when_stripe_not_ready():
    """Team without completed Stripe Connect onboarding → 409, no Task."""
    from app.expert_consultation_routes import approve_application

    application = _make_application()
    service = _make_service()
    expert = _make_expert(stripe_ready=False)
    owner_member = _make_owner_member()
    applicant_user = _make_applicant_user()

    db = _build_db(application, service, expert, owner_member, applicant_user)

    with patch(
        "app.expert_consultation_routes._get_member_or_403",
        new=AsyncMock(return_value=MagicMock()),
    ):
        with pytest.raises(HTTPException) as exc:
            await approve_application(
                application_id=101,
                body={},
                request=MagicMock(),
                db=db,
                current_user=_make_current_user(),
            )

    assert exc.value.status_code == 409
    db.add.assert_not_called()


@pytest.mark.asyncio
async def test_team_service_approve_blocked_when_currency_not_gbp():
    """Team service in non-GBP currency → 409, no Task."""
    from app.expert_consultation_routes import approve_application

    application = _make_application()
    service = _make_service(currency="USD")
    expert = _make_expert()
    owner_member = _make_owner_member()
    applicant_user = _make_applicant_user()

    db = _build_db(application, service, expert, owner_member, applicant_user)

    with patch(
        "app.expert_consultation_routes._get_member_or_403",
        new=AsyncMock(return_value=MagicMock()),
    ):
        with pytest.raises(HTTPException) as exc:
            await approve_application(
                application_id=101,
                body={},
                request=MagicMock(),
                db=db,
                current_user=_make_current_user(),
            )

    assert exc.value.status_code == 409
    db.add.assert_not_called()


@pytest.mark.asyncio
async def test_team_service_approve_blocked_when_service_inactive():
    """Inactive (suspended/draft) service → 400, no Task."""
    from app.expert_consultation_routes import approve_application

    application = _make_application()
    service = _make_service(status="suspended")
    expert = _make_expert()
    owner_member = _make_owner_member()
    applicant_user = _make_applicant_user()

    db = _build_db(application, service, expert, owner_member, applicant_user)

    with patch(
        "app.expert_consultation_routes._get_member_or_403",
        new=AsyncMock(return_value=MagicMock()),
    ):
        with pytest.raises(HTTPException) as exc:
            await approve_application(
                application_id=101,
                body={},
                request=MagicMock(),
                db=db,
                current_user=_make_current_user(),
            )

    assert exc.value.status_code == 400
    db.add.assert_not_called()
