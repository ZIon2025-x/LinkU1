"""
团队(Expert)权限检查 helper + request-scoped 缓存。

Usage:
    member = await get_team_member(db, expert_id, user.id)  # 完整 ExpertMember 行(或 None)
    role = await get_team_role(db, expert_id, user.id)      # 仅 role 字符串
    role = await require_team_role(db, expert_id, user.id, minimum="admin")  # 校验 + 抛 403

所有 3 个 helper 共享同一 request-scoped 缓存(key = (expert_id, user_id)),
因此在单次请求里连续调用不会重复打 DB。
"""
import logging
from contextvars import ContextVar
from typing import Literal, Optional

from fastapi import HTTPException
from sqlalchemy import select

from app import models
from app.consultation import error_codes

logger = logging.getLogger(__name__)

TeamRole = Literal["owner", "admin", "member"]

_ROLE_HIERARCHY: dict[TeamRole, int] = {"member": 1, "admin": 2, "owner": 3}

# per-request cache: key = (expert_id, user_id), value = ExpertMember row or None
# 缓存整行而非仅 role,让 _get_member_or_403 之类需要 row 的 caller 也能命中缓存。
# 注意: user_id 在整个平台是 8 位字符串 (见 ExpertMember.user_id = String(8))
_member_cache: ContextVar[
    Optional[dict[tuple[str, str], Optional[models.ExpertMember]]]
] = ContextVar("_expert_member_cache", default=None)


def reset_role_cache() -> None:
    """中间件在每个请求开始时调用,避免跨请求泄露。"""
    _member_cache.set({})


def _cache() -> dict[tuple[str, str], Optional[models.ExpertMember]]:
    c = _member_cache.get()
    if c is None:
        c = {}
        _member_cache.set(c)
    return c


async def _query_team_member(db, expert_id: str, user_id: str) -> Optional[models.ExpertMember]:
    """实际 DB 查询(不走缓存)。返回活跃成员行,或 None。"""
    stmt = select(models.ExpertMember).where(
        models.ExpertMember.expert_id == expert_id,
        models.ExpertMember.user_id == user_id,
        models.ExpertMember.status == "active",
    )
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def get_team_member(
    db, expert_id: str, user_id: str
) -> Optional[models.ExpertMember]:
    """返回当前用户的 ExpertMember 行;非成员返回 None。单请求内缓存。

    供需要 ExpertMember 对象的调用方(如 `expert_routes._get_member_or_403`
    和修改 member.status 的场景)使用。

    **缓存新鲜度注意事项**:
    - 缓存存的是 SQLAlchemy ORM 行对象本身,同一请求内多次调用返回同一实例。
    - 如果调用方原地修改了 `member.status`(如 "离开团队" 端点把 status 从
      'active' 改成 'left'),随后同一请求再次调用 `get_team_member` 仍会拿到
      这个已修改的对象 — 它从数据库角度看是 stale 的,但仍被视为成员存在。
    - 当前所有已知 mutation 调用方都是 "写完立即返回响应",不会同请求内再查,
      因此此行为无风险。未来若添加需要读取最新 DB 状态的路径,显式调用
      `reset_role_cache()` 或直接走 `_query_team_member(db, ...)` 绕过缓存。
    """
    cache = _cache()
    key = (expert_id, user_id)
    if key in cache:
        return cache[key]
    member = await _query_team_member(db, expert_id, user_id)
    cache[key] = member
    return member


def _normalize_role(member: Optional[models.ExpertMember]) -> Optional[TeamRole]:
    """从 ExpertMember 行提取并规范化 role;未知 role 记 warning 并返回 None。"""
    if member is None:
        return None
    role = (member.role or "").strip().lower()
    if role not in ("owner", "admin", "member"):
        logger.warning(
            "ExpertMember %s has unknown role %r; treating as non-member",
            getattr(member, "id", None),
            member.role,
        )
        return None
    return role  # type: ignore[return-value]


async def _query_team_role(db, expert_id: str, user_id: str) -> Optional[TeamRole]:
    """Legacy 内部 helper — 供测试 monkeypatch 使用。新代码走 get_team_role。"""
    member = await _query_team_member(db, expert_id, user_id)
    return _normalize_role(member)


async def get_team_role(db, expert_id: str, user_id: str) -> Optional[TeamRole]:
    """返回当前用户在团队内的角色;非成员返回 None。结果在请求上下文内缓存。"""
    member = await get_team_member(db, expert_id, user_id)
    return _normalize_role(member)


async def require_team_role(
    db,
    expert_id: str,
    user_id: str,
    *,
    minimum: TeamRole,
) -> TeamRole:
    """
    不满足最低角色抛 403。
    - minimum='owner' 仅 owner 通过
    - minimum='admin' owner + admin 通过
    - minimum='member' 所有活跃成员通过
    """
    role = await get_team_role(db, expert_id, user_id)
    if role is None:
        raise HTTPException(
            status_code=403,
            detail={
                "error_code": error_codes.NOT_TEAM_MEMBER,
                "message": "您不是该团队成员",
            },
        )
    if _ROLE_HIERARCHY[role] < _ROLE_HIERARCHY[minimum]:
        raise HTTPException(
            status_code=403,
            detail={
                "error_code": error_codes.INSUFFICIENT_TEAM_ROLE,
                "message": "角色权限不足",
                "required_role": minimum,
            },
        )
    return role
