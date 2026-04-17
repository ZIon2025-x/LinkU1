"""
团队权限 helper 测试
"""
import pytest
from unittest.mock import AsyncMock, MagicMock
from fastapi import HTTPException

from app.permissions.expert_permissions import (
    get_team_role,
    require_team_role,
    reset_role_cache,
)


@pytest.fixture(autouse=True)
def _reset():
    reset_role_cache()
    yield
    reset_role_cache()


class _StubDB:
    """最小 mock:根据 fixture 数据返回 ExpertMember 记录"""
    def __init__(self, members: dict[tuple[str, int], str]):
        # members: {(expert_id, user_id): role}
        self._members = members
        self.query_count = 0

    async def execute(self, stmt):  # pragma: no cover - 简化实现
        self.query_count += 1
        raise NotImplementedError


@pytest.mark.asyncio
async def test_get_team_role_returns_owner(monkeypatch):
    async def fake_query(db, expert_id, user_id):
        return "owner"
    monkeypatch.setattr(
        "app.permissions.expert_permissions._query_team_role", fake_query
    )
    role = await get_team_role(None, "exp-1", 42)
    assert role == "owner"


@pytest.mark.asyncio
async def test_get_team_role_returns_none_for_non_member(monkeypatch):
    async def fake_query(db, expert_id, user_id):
        return None
    monkeypatch.setattr(
        "app.permissions.expert_permissions._query_team_role", fake_query
    )
    assert await get_team_role(None, "exp-1", 999) is None


@pytest.mark.asyncio
async def test_get_team_role_caches_within_request(monkeypatch):
    calls = {"n": 0}

    async def fake_query(db, expert_id, user_id):
        calls["n"] += 1
        return "admin"

    monkeypatch.setattr(
        "app.permissions.expert_permissions._query_team_role", fake_query
    )
    await get_team_role(None, "exp-1", 42)
    await get_team_role(None, "exp-1", 42)
    await get_team_role(None, "exp-1", 42)
    assert calls["n"] == 1  # 只查一次,后续命中缓存


@pytest.mark.asyncio
async def test_get_team_role_cache_resets_between_requests(monkeypatch):
    calls = {"n": 0}

    async def fake_query(db, expert_id, user_id):
        calls["n"] += 1
        return "member"

    monkeypatch.setattr(
        "app.permissions.expert_permissions._query_team_role", fake_query
    )
    await get_team_role(None, "exp-1", 42)
    reset_role_cache()
    await get_team_role(None, "exp-1", 42)
    assert calls["n"] == 2


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "role,minimum,should_pass",
    [
        ("owner", "owner", True),
        ("admin", "owner", False),
        ("member", "owner", False),
        ("owner", "admin", True),
        ("admin", "admin", True),
        ("member", "admin", False),
        ("owner", "member", True),
        ("admin", "member", True),
        ("member", "member", True),
        (None, "member", False),
    ],
)
async def test_require_team_role_matrix(monkeypatch, role, minimum, should_pass):
    async def fake_query(db, expert_id, user_id):
        return role
    monkeypatch.setattr(
        "app.permissions.expert_permissions._query_team_role", fake_query
    )
    if should_pass:
        got = await require_team_role(None, "exp-1", 42, minimum=minimum)
        assert got == role
    else:
        with pytest.raises(HTTPException) as exc:
            await require_team_role(None, "exp-1", 42, minimum=minimum)
        assert exc.value.status_code == 403
        assert isinstance(exc.value.detail, dict)
        expected_code = (
            "NOT_TEAM_MEMBER" if role is None else "INSUFFICIENT_TEAM_ROLE"
        )
        assert exc.value.detail.get("error_code") == expected_code
