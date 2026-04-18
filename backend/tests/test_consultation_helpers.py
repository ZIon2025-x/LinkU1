"""
consultation.helpers 单元测试。
不依赖真实 DB,使用内存对象模拟 SQLAlchemy 行为。
"""
from datetime import datetime, timedelta
import pytest
from unittest.mock import AsyncMock, MagicMock

from app.consultation.helpers import (
    check_consultation_idempotency,
    close_consultation_task,
)


@pytest.mark.asyncio
async def test_check_consultation_idempotency_returns_existing(monkeypatch):
    existing = MagicMock(id=123, status="consulting")

    async def fake_execute(stmt):
        r = MagicMock()
        r.scalar_one_or_none = MagicMock(return_value=existing)
        return r

    db = MagicMock()
    db.execute = fake_execute
    got = await check_consultation_idempotency(
        db, applicant_id="u0000042", subject_id=7, subject_type="service"
    )
    assert got is existing


@pytest.mark.asyncio
async def test_check_consultation_idempotency_returns_none_when_absent():
    async def fake_execute(stmt):
        r = MagicMock()
        r.scalar_one_or_none = MagicMock(return_value=None)
        return r

    db = MagicMock()
    db.execute = fake_execute
    got = await check_consultation_idempotency(
        db, applicant_id="u0000042", subject_id=7, subject_type="service"
    )
    assert got is None


@pytest.mark.asyncio
async def test_close_consultation_task_sets_status_closed():
    app_row = MagicMock()
    app_row.task_id = 55
    app_row.applicant_id = "u0000042"

    task_row = MagicMock(id=55, status="consulting")
    task_row.taker_id = "u0000099"
    task_row.poster_id = "u0000042"

    async def fake_get(model, pk):
        return task_row

    db = MagicMock()
    db.get = fake_get
    db.add = MagicMock()
    db.flush = AsyncMock()

    await close_consultation_task(db, app_row, reason="转为正式订单")
    assert task_row.status == "closed"


@pytest.mark.asyncio
async def test_check_consultation_idempotency_returns_none_for_non_service_type():
    """Task/flea_market 主体不走 service_applications 表,helper 必须返回 None。"""
    db = MagicMock()
    db.execute = AsyncMock()  # should not be called
    got = await check_consultation_idempotency(
        db, applicant_id="u0000042", subject_id=7, subject_type="task"
    )
    assert got is None
    db.execute.assert_not_called()

    got = await check_consultation_idempotency(
        db, applicant_id="u0000042", subject_id=7, subject_type="flea_market_item"
    )
    assert got is None


@pytest.mark.asyncio
async def test_close_consultation_task_inserts_system_message():
    """验证 pre-approved deviation:helper 不仅 flip status,还要插入 system message。"""
    app_row = MagicMock()
    app_row.task_id = 55
    app_row.applicant_id = "u0000001"
    task_row = MagicMock(id=55, status="consulting", title="咨询测试", poster_id="u0000001", taker_id="u0000002")

    async def fake_get(model, pk):
        return task_row

    db = MagicMock()
    db.get = fake_get
    db.add = MagicMock()
    db.flush = AsyncMock()

    await close_consultation_task(db, app_row, reason="转为正式订单")

    # Assert task mutated + at least one db.add (for Message)
    assert task_row.status == "closed"
    # close_consultation_task may call db.add once for the message
    assert db.add.called, "Expected system Message insert via db.add"
