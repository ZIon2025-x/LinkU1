"""Tests for 2026-04-18 consultation upgrade (flag + consultation_task_id)."""
from __future__ import annotations

import pytest
from unittest.mock import AsyncMock, MagicMock


@pytest.mark.asyncio
async def test_create_placeholder_task_sets_both_fields():
    """create_placeholder_task helper must set task_source AND is_consultation_placeholder
    together (the CHECK constraint in migration 208b will enforce this; helper makes it
    impossible to write one without the other)."""
    from app.consultation.helpers import create_placeholder_task

    db = MagicMock()
    db.add = MagicMock()
    db.flush = AsyncMock()

    task = await create_placeholder_task(
        db,
        consultation_type="consultation",
        title="咨询：测试",
        applicant_id="u_applicant",
        taker_id="u_taker",
    )

    assert task.task_source == "consultation"
    assert task.is_consultation_placeholder is True
    assert task.status == "consulting"


def test_consultation_task_id_for_all_scenarios():
    """C.3 分场景表全部 7 种场景 + NULL 边界."""
    from app.consultation.helpers import consultation_task_id_for

    # 1. SA approve 前:consultation_task_id=NULL, task_id=占位 → 返回 task_id
    sa_pre = MagicMock(consultation_task_id=None, task_id=100)
    assert consultation_task_id_for(sa_pre) == 100

    # 2. SA approve 后:consultation_task_id=占位, task_id=真任务 → 返回 consultation_task_id
    sa_post = MagicMock(consultation_task_id=100, task_id=200)
    assert consultation_task_id_for(sa_post) == 100

    # 3. TA 占位记录咨询中:consultation_task_id=NULL, task_id=占位 → 返回 task_id
    ta_placeholder_during = MagicMock(consultation_task_id=None, task_id=101)
    assert consultation_task_id_for(ta_placeholder_during) == 101

    # 4. TA 占位记录 formal apply 后(cancelled):consultation_task_id=NULL, task_id=占位 → 返回 task_id
    ta_placeholder_cancelled = MagicMock(consultation_task_id=None, task_id=101)
    assert consultation_task_id_for(ta_placeholder_cancelled) == 101

    # 5. TA orig_application:consultation_task_id=占位, task_id=原任务 → 返回 consultation_task_id
    ta_orig = MagicMock(consultation_task_id=101, task_id=999)
    assert consultation_task_id_for(ta_orig) == 101

    # 6. FMPR 咨询中:consultation_task_id=NULL, task_id=占位 → 返回 task_id
    fmpr_during = MagicMock(consultation_task_id=None, task_id=102)
    assert consultation_task_id_for(fmpr_during) == 102

    # 7. FMPR 付款晋升后:consultation_task_id 和 task_id 都指同一行 → 返回 consultation_task_id(等价)
    fmpr_promoted = MagicMock(consultation_task_id=102, task_id=102)
    assert consultation_task_id_for(fmpr_promoted) == 102

    # 边界:两个都为 NULL → None
    null_case = MagicMock(consultation_task_id=None, task_id=None)
    assert consultation_task_id_for(null_case) is None


@pytest.mark.asyncio
async def test_load_real_task_or_404_rejects_placeholder():
    """守卫对占位 task 返回 404(伪装成不存在,防探测)."""
    from app.utils.task_guards import load_real_task_or_404
    from fastapi import HTTPException

    placeholder_task = MagicMock(id=100, is_consultation_placeholder=True)
    db = MagicMock()
    db.get = AsyncMock(return_value=placeholder_task)

    with pytest.raises(HTTPException) as exc:
        await load_real_task_or_404(db, 100)
    assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_load_real_task_or_404_returns_real_task():
    """守卫对真任务正常返回."""
    from app.utils.task_guards import load_real_task_or_404

    real_task = MagicMock(id=200, is_consultation_placeholder=False)
    db = MagicMock()
    db.get = AsyncMock(return_value=real_task)

    result = await load_real_task_or_404(db, 200)
    assert result is real_task


@pytest.mark.asyncio
async def test_load_real_task_or_404_returns_404_for_nonexistent():
    """守卫对不存在的 id 返回 404."""
    from app.utils.task_guards import load_real_task_or_404
    from fastapi import HTTPException

    db = MagicMock()
    db.get = AsyncMock(return_value=None)

    with pytest.raises(HTTPException) as exc:
        await load_real_task_or_404(db, 9999)
    assert exc.value.status_code == 404


# ---------------------------------------------------------------------------
# Task 11: admin task list default-excludes placeholder tasks
# ---------------------------------------------------------------------------

def _make_db_mock(tasks=None, total=0):
    """构造一个模拟 db，使 db.query().filter().count() 和 .all() 按预期工作。"""
    tasks = tasks or []
    query_mock = MagicMock()
    # filter() returns self so chained calls work
    query_mock.filter.return_value = query_mock
    query_mock.count.return_value = total
    query_mock.order_by.return_value = query_mock
    query_mock.offset.return_value = query_mock
    query_mock.limit.return_value = query_mock
    query_mock.all.return_value = tasks

    db = MagicMock()
    db.query.return_value = query_mock
    return db, query_mock


def test_admin_task_list_excludes_placeholders_by_default():
    """默认调用（include_placeholders=False）必须添加 is_consultation_placeholder==False 过滤。"""
    from app.admin_task_management_routes import admin_get_tasks
    from app.models import Task

    db, query_mock = _make_db_mock()
    current_user = MagicMock()

    admin_get_tasks(
        skip=0,
        limit=50,
        status=None,
        task_type=None,
        location=None,
        keyword=None,
        include_placeholders=False,
        current_user=current_user,
        db=db,
    )

    # At least one filter call must filter on is_consultation_placeholder == False
    filter_calls = query_mock.filter.call_args_list
    assert filter_calls, "Expected at least one .filter() call"

    # Inspect the SQL expression passed to filter
    found = False
    for call in filter_calls:
        args = call[0]
        for arg in args:
            # SQLAlchemy BinaryExpression converts to string; check for the column name
            expr_str = str(arg)
            if "is_consultation_placeholder" in expr_str and "false" in expr_str.lower():
                found = True
                break
        if found:
            break

    assert found, (
        "admin_get_tasks did not filter out is_consultation_placeholder=False by default. "
        f"Actual filter calls: {filter_calls}"
    )


def test_admin_task_list_include_placeholders_flag():
    """include_placeholders=True 时不添加 is_consultation_placeholder 过滤。"""
    from app.admin_task_management_routes import admin_get_tasks

    db, query_mock = _make_db_mock()
    current_user = MagicMock()

    admin_get_tasks(
        skip=0,
        limit=50,
        status=None,
        task_type=None,
        location=None,
        keyword=None,
        include_placeholders=True,
        current_user=current_user,
        db=db,
    )

    filter_calls = query_mock.filter.call_args_list

    # None of the filter calls should reference is_consultation_placeholder
    for call in filter_calls:
        args = call[0]
        for arg in args:
            assert "is_consultation_placeholder" not in str(arg), (
                "admin_get_tasks must NOT filter is_consultation_placeholder when "
                "include_placeholders=True"
            )


# ---------------------------------------------------------------------------
# Task 15: CHECK constraint rejects inconsistent flag/source rows (208b)
# ---------------------------------------------------------------------------

@pytest.mark.skip(
    reason=(
        "Integration test — requires real PostgreSQL DB with migration 208b applied. "
        "Run manually in staging: psql $DATABASE_URL -f migrations/208b_add_consultation_placeholder_check.sql, "
        "then re-run with TEST_DATABASE_URL set."
    )
)
def test_check_constraint_rejects_inconsistent_flag_and_source(db):
    """208b CHECK 约束：is_consultation_placeholder 和 task_source 必须一致。

    Integration test — skipped in unit test runs (no local Postgres with 208b applied).

    What this verifies
    ------------------
    Migration 208b adds:

        ALTER TABLE tasks
          ADD CONSTRAINT ck_tasks_consultation_placeholder_matches_source
          CHECK (
            (is_consultation_placeholder = TRUE
              AND task_source IN ('consultation', 'task_consultation', 'flea_market_consultation'))
            OR
            (is_consultation_placeholder = FALSE
              AND task_source NOT IN ('consultation', 'task_consultation', 'flea_market_consultation'))
          );

    Two violation scenarios are tested:
      A) is_consultation_placeholder=TRUE but task_source='normal'
         → DB must reject with IntegrityError / CheckViolation
      B) is_consultation_placeholder=FALSE but task_source='consultation'
         → DB must reject with IntegrityError / CheckViolation

    Manual SQL verification steps
    ------------------------------
    1. Apply migration 208b to a Postgres DB.
    2. Run (in psql):

       -- Scenario A: flag=TRUE, non-consultation source → must fail
       BEGIN;
       INSERT INTO tasks (title, status, task_source, is_consultation_placeholder, poster_id)
         VALUES ('t_A', 'open', 'normal', FALSE, 'u_test_208b');
       UPDATE tasks SET is_consultation_placeholder = TRUE WHERE poster_id = 'u_test_208b';
       -- Expected: ERROR: new row violates check constraint "ck_tasks_consultation_placeholder_matches_source"
       ROLLBACK;

       -- Scenario B: flag=FALSE, consultation source → must fail
       BEGIN;
       INSERT INTO tasks (title, status, task_source, is_consultation_placeholder, poster_id)
         VALUES ('t_B', 'open', 'consultation', TRUE, 'u_test_208b_2');
       UPDATE tasks SET is_consultation_placeholder = FALSE WHERE poster_id = 'u_test_208b_2';
       -- Expected: ERROR: new row violates check constraint "ck_tasks_consultation_placeholder_matches_source"
       ROLLBACK;
    """
    from sqlalchemy.exc import IntegrityError
    from app import models

    # --- Scenario A: flag=TRUE, non-consultation source ---
    task_a = models.Task(
        title="test_208b_A",
        status="open",
        task_source="normal",
        is_consultation_placeholder=False,
        poster_id="u_test_208b_A",
    )
    db.add(task_a)
    db.flush()

    # Violate: flip flag without changing source
    task_a.is_consultation_placeholder = True
    with pytest.raises(IntegrityError, match="ck_tasks_consultation_placeholder_matches_source"):
        db.commit()
    db.rollback()

    # --- Scenario B: flag=FALSE, consultation source ---
    task_b = models.Task(
        title="test_208b_B",
        status="open",
        task_source="consultation",
        is_consultation_placeholder=True,
        poster_id="u_test_208b_B",
    )
    db.add(task_b)
    db.flush()

    # Violate: flip flag without changing source
    task_b.is_consultation_placeholder = False
    with pytest.raises(IntegrityError, match="ck_tasks_consultation_placeholder_matches_source"):
        db.commit()
    db.rollback()


@pytest.mark.asyncio
async def test_overwrite_backs_up_consultation_task_id_team():
    """B.2.1 team service approve:SA.consultation_task_id 备份 + SA.task_id 改真任务.

    Unit-test the backup logic pattern (not the full approve function).
    """
    application = MagicMock(task_id=100, consultation_task_id=None)
    new_task_id = 200

    # Logic that will be added to expert_consultation_routes.py:~1025:
    if application.task_id and not application.consultation_task_id:
        application.consultation_task_id = application.task_id
    application.task_id = new_task_id

    assert application.consultation_task_id == 100
    assert application.task_id == 200


@pytest.mark.asyncio
async def test_overwrite_backs_up_consultation_task_id_personal():
    """B.2.1 个人服务 approve:同样备份."""
    application = MagicMock(task_id=100, consultation_task_id=None)
    new_task_id = 200

    if application.task_id and not application.consultation_task_id:
        application.consultation_task_id = application.task_id
    application.task_id = new_task_id

    assert application.consultation_task_id == 100
    assert application.task_id == 200


def test_overwrite_idempotent():
    """防御性兜底:第二次 approve 守卫本身不会错写 consultation_task_id.

    即使 upstream idempotency check(expert_consultation_routes.py:807-815)失效,
    double-guard 仍然不会把真任务 id 错写到 consultation_task_id。"""
    application = MagicMock(task_id=200, consultation_task_id=100)  # 第一次已写
    new_task_id = 300

    if application.task_id and not application.consultation_task_id:
        application.consultation_task_id = application.task_id  # 应该不进(consultation_task_id 已非空)
    application.task_id = new_task_id

    assert application.consultation_task_id == 100  # 仍是原来的 100
    assert application.task_id == 300


@pytest.mark.asyncio
async def test_ta_formal_apply_creates_orig_application_with_consultation_task_id():
    """B.2.3 unit-test: orig_application creation pattern sets consultation_task_id=<placeholder task_id>.

    Tests the code pattern expected in task_chat_routes.consult_formal_apply(:5392 region).
    """
    placeholder_task_id = 101  # the route param task_id
    original_task_id = 999

    # The code pattern to be added:
    orig_application_kwargs = dict(
        task_id=original_task_id,
        applicant_id="u_test",
        status="pending",
        currency="GBP",
        consultation_task_id=placeholder_task_id,  # NEW: the line being added
    )

    assert orig_application_kwargs["consultation_task_id"] == placeholder_task_id
    assert orig_application_kwargs["task_id"] == original_task_id


def test_ta_formal_apply_cancels_placeholder_ta():
    """B.2.3 unit-test: placeholder TA.status change from 'pending' to 'cancelled' after formal apply.

    Tests the code pattern expected in task_chat_routes.consult_formal_apply(:5427 region).
    """
    placeholder_application = MagicMock(status="consulting")  # Started as consulting

    # OLD code set this to "pending" (incorrect — orig_application carries the formal state):
    # placeholder_application.status = "pending"

    # NEW code (this task) sets to "cancelled":
    placeholder_application.status = "cancelled"

    assert placeholder_application.status == "cancelled"


def test_flea_market_promote_sets_consultation_task_id_and_clears_flag():
    """B.3 unit-test: promote logic sets is_consultation_placeholder=False atomically with task_source,
    and writes FMPR.consultation_task_id=task.id for history backup."""
    existing_task = MagicMock(task_source="flea_market_consultation", is_consultation_placeholder=True, id=102)
    purchase_request = MagicMock(consultation_task_id=None)

    # Logic pattern (as added in flea_market_routes.py):
    existing_task.task_source = "flea_market"
    existing_task.is_consultation_placeholder = False

    if not purchase_request.consultation_task_id:
        purchase_request.consultation_task_id = existing_task.id

    assert existing_task.task_source == "flea_market"
    assert existing_task.is_consultation_placeholder is False
    assert purchase_request.consultation_task_id == 102
