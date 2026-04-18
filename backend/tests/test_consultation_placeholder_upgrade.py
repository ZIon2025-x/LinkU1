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
