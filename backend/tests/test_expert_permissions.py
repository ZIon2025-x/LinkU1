"""
团队权限 helper 测试
"""
import pytest
from fastapi import HTTPException

from app.permissions.expert_permissions import (
    get_team_member,
    get_team_role,
    require_team_role,
    reset_role_cache,
)


def _make_member(role: str | None, member_id: int = 1):
    """构造一个"返回指定 role 的假 ExpertMember"对象。"""
    if role is None:
        return None
    return type("_FakeMember", (), {"role": role, "id": member_id})()


@pytest.fixture(autouse=True)
def _reset():
    reset_role_cache()
    yield
    reset_role_cache()


@pytest.mark.asyncio
async def test_get_team_role_returns_owner(monkeypatch):
    async def fake_query(db, expert_id, user_id):
        return _make_member("owner")
    monkeypatch.setattr(
        "app.permissions.expert_permissions._query_team_member", fake_query
    )
    role = await get_team_role(None, "exp-1", "u0000042")
    assert role == "owner"


@pytest.mark.asyncio
async def test_get_team_role_returns_none_for_non_member(monkeypatch):
    async def fake_query(db, expert_id, user_id):
        return None
    monkeypatch.setattr(
        "app.permissions.expert_permissions._query_team_member", fake_query
    )
    assert await get_team_role(None, "exp-1", "u0000999") is None


@pytest.mark.asyncio
async def test_get_team_role_caches_within_request(monkeypatch):
    calls = {"n": 0}

    async def fake_query(db, expert_id, user_id):
        calls["n"] += 1
        return _make_member("admin")

    monkeypatch.setattr(
        "app.permissions.expert_permissions._query_team_member", fake_query
    )
    await get_team_role(None, "exp-1", "u0000042")
    await get_team_role(None, "exp-1", "u0000042")
    await get_team_role(None, "exp-1", "u0000042")
    assert calls["n"] == 1  # 只查一次,后续命中缓存


@pytest.mark.asyncio
async def test_get_team_role_cache_resets_between_requests(monkeypatch):
    calls = {"n": 0}

    async def fake_query(db, expert_id, user_id):
        calls["n"] += 1
        return _make_member("member")

    monkeypatch.setattr(
        "app.permissions.expert_permissions._query_team_member", fake_query
    )
    await get_team_role(None, "exp-1", "u0000042")
    reset_role_cache()
    await get_team_role(None, "exp-1", "u0000042")
    assert calls["n"] == 2


@pytest.mark.asyncio
async def test_get_team_member_and_get_team_role_share_cache(monkeypatch):
    """两个 helper 共享 request-scoped 缓存,避免重复 DB 查询。"""
    calls = {"n": 0}

    async def fake_query(db, expert_id, user_id):
        calls["n"] += 1
        return _make_member("admin")

    monkeypatch.setattr(
        "app.permissions.expert_permissions._query_team_member", fake_query
    )
    member = await get_team_member(None, "exp-1", "u0000042")
    role = await get_team_role(None, "exp-1", "u0000042")
    assert member is not None and member.role == "admin"
    assert role == "admin"
    assert calls["n"] == 1  # 两个 helper 合计只查一次 DB


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
        return _make_member(role)
    monkeypatch.setattr(
        "app.permissions.expert_permissions._query_team_member", fake_query
    )
    if should_pass:
        got = await require_team_role(None, "exp-1", "u0000042", minimum=minimum)
        assert got == role
    else:
        with pytest.raises(HTTPException) as exc:
            await require_team_role(None, "exp-1", "u0000042", minimum=minimum)
        assert exc.value.status_code == 403
        assert isinstance(exc.value.detail, dict)
        expected_code = (
            "NOT_TEAM_MEMBER" if role is None else "INSUFFICIENT_TEAM_ROLE"
        )
        assert exc.value.detail.get("error_code") == expected_code
        # INSUFFICIENT_TEAM_ROLE 带 required_role 字段,message 始终为纯中文
        if expected_code == "INSUFFICIENT_TEAM_ROLE":
            assert exc.value.detail.get("required_role") == minimum
            assert exc.value.detail.get("message") == "角色权限不足"


@pytest.mark.asyncio
async def test_query_team_role_returns_none_for_unknown_role(caplog):
    """未知角色值应当被记录告警并视为非成员 (None),而不是静默降级到 member。"""
    from app.permissions import expert_permissions as mod

    # 构造一个"返回未知角色的 ExpertMember"的假 db.execute 结果
    fake_member = type(
        "_FakeMember", (), {"role": "super_admin", "id": 12345}
    )()

    class _FakeResult:
        def scalar_one_or_none(self):
            return fake_member

    class _FakeDB:
        async def execute(self, stmt):
            return _FakeResult()

    with caplog.at_level("WARNING", logger="app.permissions.expert_permissions"):
        role = await mod._query_team_role(_FakeDB(), "exp-1", "u0000042")

    assert role is None
    # 确认 warning 被记录
    assert any(
        "unknown role" in rec.message
        for rec in caplog.records
        if rec.name == "app.permissions.expert_permissions"
    )


@pytest.mark.asyncio
async def test_query_team_role_strips_whitespace_in_role(caplog):
    """role 字段两侧的空白应当被 strip,而不是因此被判成 unknown role。"""
    from app.permissions import expert_permissions as mod

    fake_member = type(
        "_FakeMember", (), {"role": "  Admin  ", "id": 1}
    )()

    class _FakeResult:
        def scalar_one_or_none(self):
            return fake_member

    class _FakeDB:
        async def execute(self, stmt):
            return _FakeResult()

    with caplog.at_level("WARNING", logger="app.permissions.expert_permissions"):
        role = await mod._query_team_role(_FakeDB(), "exp-1", "u0000042")

    assert role == "admin"
    # 不应该有 unknown role 告警
    assert not any(
        "unknown role" in rec.message
        for rec in caplog.records
        if rec.name == "app.permissions.expert_permissions"
    )
