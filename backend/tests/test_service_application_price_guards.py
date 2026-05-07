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
        final_price=None,
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
        final_price=None,
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


@pytest.mark.asyncio
async def test_apply_allows_negotiable_no_base_no_slot_when_user_provides_negotiated_price():
    """议价服务 + 无 base_price + 无 slot 时,只要 body 提供有效 negotiated_price (>0),
    apply 应当放行,并把价格写到 ServiceApplication.negotiated_price 上 ——
    供 owner 端在审批/还价流程里看到议价金额。
    """
    from app.expert_consultation_routes import apply_for_service

    service = MagicMock(
        id=19,
        status="active",
        base_price=None,
        pricing_type="negotiable",
        owner_type="user",
        owner_id="u_owner",
        currency="GBP",
    )

    first = MagicMock()
    first.scalar_one_or_none = MagicMock(return_value=service)
    second = MagicMock()
    second.scalar_one_or_none = MagicMock(return_value=None)
    third = MagicMock()  # update application_count
    calls = iter([first, second, third])

    async def _execute(*args, **kwargs):
        try:
            return next(calls)
        except StopIteration:
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
            service_id=19,
            body={"message": "我想要", "negotiated_price": 50.0},
            request=MagicMock(),
            db=db,
            current_user=current_user,
        )

    assert result["service_id"] == 19
    # 创建的 application 必须带上议价金额
    db.add.assert_called_once()
    application = db.add.call_args.args[0]
    assert float(application.negotiated_price) == 50.0


@pytest.mark.asyncio
@pytest.mark.parametrize("invalid_price", [0, -10, "abc", None])
async def test_apply_rejects_negotiable_no_base_no_slot_with_invalid_negotiated_price(invalid_price):
    """议价 + 无 base_price + 无 slot 但 negotiated_price 不是有效正数 (0/负/非数字/缺失) ——
    仍然应当 400 apply_requires_consultation,因为没有可落地的价格。
    """
    from app.expert_consultation_routes import apply_for_service

    service = MagicMock(
        id=19,
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

    body = {"message": "x"}
    if invalid_price is not None:
        body["negotiated_price"] = invalid_price

    with pytest.raises(HTTPException) as exc_info:
        await apply_for_service(
            service_id=19,
            body=body,
            request=MagicMock(),
            db=db,
            current_user=current_user,
        )

    assert exc_info.value.status_code == 400
    assert exc_info.value.detail["error_code"] == "apply_requires_consultation"


@pytest.mark.asyncio
async def test_apply_persists_application_message():
    """前端 task_expert_repository.applyService 用 'application_message' 作为 key
    (commit 099f416e4 起);后端必须按这个 key 读,否则用户留言全部丢失。
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
    third = MagicMock()
    calls = iter([first, second, third])

    async def _execute(*args, **kwargs):
        try:
            return next(calls)
        except StopIteration:
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
        await apply_for_service(
            service_id=9,
            body={"application_message": "我想要这个服务"},
            request=MagicMock(),
            db=db,
            current_user=current_user,
        )

    db.add.assert_called_once()
    application = db.add.call_args.args[0]
    assert application.application_message == "我想要这个服务"


@pytest.mark.asyncio
async def test_apply_persists_negotiated_price_for_fixed_service():
    """Fixed 价 + base_price>0 的服务,如果用户在 body 里同时提供了 negotiated_price,
    也要把这个值写到 ServiceApplication.negotiated_price 上 —— 表示用户想还价 / 提价。
    apply 自身不再因有 negotiated_price 而改变状态语义,owner 侧后续可以选择 approve 或 quote。
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
    third = MagicMock()
    calls = iter([first, second, third])

    async def _execute(*args, **kwargs):
        try:
            return next(calls)
        except StopIteration:
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
        await apply_for_service(
            service_id=9,
            body={"message": "还价", "negotiated_price": 15.0},
            request=MagicMock(),
            db=db,
            current_user=current_user,
        )

    db.add.assert_called_once()
    application = db.add.call_args.args[0]
    assert float(application.negotiated_price) == 15.0


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


# ---------------------------------------------------------------------------
# Chat-route application resolver — TaskApplication / ServiceApplication 兼容
# ---------------------------------------------------------------------------
#
# 背景:支付完成后 Flutter 仍持有 ServiceApplication.id (=16) 调用
#   GET /api/messages/task/{task_id}?application_id=16
#   GET /api/tasks/{task_id}/applications/{application_id}/consult-status
# 但这两个端点原本只查 task_applications 表 → 永远 404 "申请不存在"。
# _resolve_chat_application 应该先查 TaskApplication, 没有再 fallback
# 查 ServiceApplication, 让两类 id 都能命中。


@pytest.mark.asyncio
async def test_resolve_chat_application_prefers_task_application():
    """同一 application_id 在 TaskApplication 命中时优先返回它,is_service_app=False。"""
    from app.task_chat_routes import _resolve_chat_application

    ta = MagicMock(spec=["id", "task_id", "applicant_id"])
    ta.id = 16
    ta.task_id = 331
    ta.applicant_id = "u_applicant"

    first = MagicMock()
    first.scalar_one_or_none = MagicMock(return_value=ta)
    db = MagicMock()
    db.execute = AsyncMock(return_value=first)

    result, is_service_app = await _resolve_chat_application(db, 16, 331)
    assert result is ta
    assert is_service_app is False


@pytest.mark.asyncio
async def test_resolve_chat_application_falls_back_to_service_application():
    """TaskApplication 没命中时,fallback 查 ServiceApplication;命中则返回
    (sa_obj, True)。"""
    from app.task_chat_routes import _resolve_chat_application

    sa = MagicMock(spec=["id", "task_id", "applicant_id"])
    sa.id = 16
    sa.task_id = 331
    sa.applicant_id = "u_applicant"

    first = MagicMock()
    first.scalar_one_or_none = MagicMock(return_value=None)  # TA miss
    second = MagicMock()
    second.scalar_one_or_none = MagicMock(return_value=sa)   # SA hit
    calls = iter([first, second])

    async def _execute(*args, **kwargs):
        return next(calls)

    db = MagicMock()
    db.execute = AsyncMock(side_effect=_execute)

    result, is_service_app = await _resolve_chat_application(db, 16, 331)
    assert result is sa
    assert is_service_app is True


@pytest.mark.asyncio
async def test_resolve_chat_application_returns_none_when_neither_matches():
    """两张表都 miss → (None, False)。调用方应当抛 404。"""
    from app.task_chat_routes import _resolve_chat_application

    miss = MagicMock()
    miss.scalar_one_or_none = MagicMock(return_value=None)
    db = MagicMock()
    db.execute = AsyncMock(return_value=miss)

    result, is_service_app = await _resolve_chat_application(db, 99999, 331)
    assert result is None
    assert is_service_app is False


@pytest.mark.asyncio
async def test_consult_status_returns_service_application_fields():
    """consult-status 端点在客户端传 ServiceApplication.id 时,从 SA 取字段返回,
    不再 404。回归生产 17:41:57 的 'CONSULTATION_NOT_FOUND'。
    """
    from app.task_chat_routes import consult_status

    task = MagicMock(
        id=331,
        poster_id="u_applicant",
        taker_id="u_owner",
        original_task_id=None,
        description="",
    )
    sa = MagicMock(
        id=16,
        task_id=331,
        applicant_id="u_applicant",
        status="approved",
        negotiated_price=50,
        currency="GBP",
        created_at=None,
    )

    task_lookup = MagicMock()
    task_lookup.scalar_one_or_none = MagicMock(return_value=task)
    ta_miss = MagicMock()
    ta_miss.scalar_one_or_none = MagicMock(return_value=None)
    sa_hit = MagicMock()
    sa_hit.scalar_one_or_none = MagicMock(return_value=sa)
    calls = iter([task_lookup, ta_miss, sa_hit])

    async def _execute(*args, **kwargs):
        try:
            return next(calls)
        except StopIteration:
            return MagicMock()

    db = MagicMock()
    db.execute = AsyncMock(side_effect=_execute)

    current_user = MagicMock(id="u_applicant")

    result = await consult_status(
        task_id=331,
        application_id=16,
        current_user=current_user,
        db=db,
    )
    assert result["id"] == 16
    assert result["task_id"] == 331
    assert result["applicant_id"] == "u_applicant"
    assert result["status"] == "approved"


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
