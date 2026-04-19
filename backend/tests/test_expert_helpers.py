"""expert_helpers 单元测试 — 验证 is_user_expert_sync 语义等价 legacy 双查"""

from sqlalchemy.orm import Session

from app import models
from app.models_expert import Expert, ExpertMember
from app.utils.expert_helpers import (
    is_user_expert_sync,
    get_user_primary_expert_sync,
)


def _make_user(db: Session, user_id: str) -> None:
    db.add(models.User(
        id=user_id,
        name=f"User {user_id}",
        email=f"{user_id}@test.local",
        hashed_password="x",
    ))
    db.flush()


def _make_expert_team(db: Session, expert_id: str, name: str = "Test Team") -> Expert:
    team = Expert(id=expert_id, name=name, status="active")
    db.add(team)
    db.flush()
    return team


def _add_member(db: Session, expert_id: str, user_id: str, role: str, status: str = "active"):
    member = ExpertMember(
        expert_id=expert_id,
        user_id=user_id,
        role=role,
        status=status,
    )
    db.add(member)
    db.flush()


def test_is_user_expert_sync_active_owner(db: Session):
    """active owner 应返回 True"""
    _make_user(db, "10000001")
    _make_expert_team(db, "T0000001")
    _add_member(db, "T0000001", "10000001", "owner", "active")
    assert is_user_expert_sync(db, "10000001") is True


def test_is_user_expert_sync_inactive(db: Session):
    """status='inactive' 的 member 应返回 False"""
    _make_user(db, "10000002")
    _make_expert_team(db, "T0000002")
    _add_member(db, "T0000002", "10000002", "owner", "inactive")
    assert is_user_expert_sync(db, "10000002") is False


def test_is_user_expert_sync_no_membership(db: Session):
    """完全没 ExpertMember 应返回 False"""
    _make_user(db, "10000003")
    assert is_user_expert_sync(db, "10000003") is False


def test_is_user_expert_sync_multi_teams_any_active(db: Session):
    """在 2 个团队,其一 active 应返回 True"""
    _make_user(db, "10000004")
    _make_expert_team(db, "T0000004")
    _make_expert_team(db, "T0000005", name="Other Team")
    _add_member(db, "T0000004", "10000004", "owner", "inactive")
    _add_member(db, "T0000005", "10000004", "member", "active")
    assert is_user_expert_sync(db, "10000004") is True


def test_get_user_primary_expert_returns_owner_team(db: Session):
    """用户是 team A 的 owner + team B 的 member → 返回 team A"""
    _make_user(db, "10000005")
    team_a = _make_expert_team(db, "T0000006", name="A")
    _make_expert_team(db, "T0000007", name="B")
    _add_member(db, "T0000006", "10000005", "owner", "active")
    _add_member(db, "T0000007", "10000005", "member", "active")

    result = get_user_primary_expert_sync(db, "10000005")
    assert result is not None
    assert result.id == team_a.id


def test_get_user_primary_expert_returns_none_when_no_owner(db: Session):
    """用户只是 member 不是 owner → 返回 None"""
    _make_user(db, "10000006")
    _make_expert_team(db, "T0000008")
    _add_member(db, "T0000008", "10000006", "member", "active")
    assert get_user_primary_expert_sync(db, "10000006") is None
