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
