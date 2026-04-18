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
