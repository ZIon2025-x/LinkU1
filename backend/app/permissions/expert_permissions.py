"""
团队(Expert)权限检查 helper + request-scoped 缓存。

Usage:
    role = await get_team_role(db, expert_id, user.id)
    # 或
    role = await require_team_role(db, expert_id, user.id, minimum="admin")
"""
import logging
from contextvars import ContextVar
from typing import Literal, Optional

from fastapi import HTTPException
from sqlalchemy import select

from app import models

logger = logging.getLogger(__name__)

TeamRole = Literal["owner", "admin", "member"]

_ROLE_HIERARCHY: dict[TeamRole, int] = {"member": 1, "admin": 2, "owner": 3}

# per-request cache: key = (expert_id, user_id), value = role or None
# 注意: user_id 在整个平台是 8 位字符串 (见 ExpertMember.user_id = String(8))
_role_cache: ContextVar[Optional[dict[tuple[str, str], Optional[TeamRole]]]] = (
    ContextVar("_expert_role_cache", default=None)
)


def reset_role_cache() -> None:
    """中间件在每个请求开始时调用,避免跨请求泄露。"""
    _role_cache.set({})


def _cache() -> dict[tuple[str, str], Optional[TeamRole]]:
    c = _role_cache.get()
    if c is None:
        c = {}
        _role_cache.set(c)
    return c


async def _query_team_role(db, expert_id: str, user_id: str) -> Optional[TeamRole]:
    """
    实际 DB 查询(不走缓存)。
    查 ExpertMember 表,对于 owner 也通过 ExpertMember.role='owner' 行识别。
    """
    stmt = select(models.ExpertMember).where(
        models.ExpertMember.expert_id == expert_id,
        models.ExpertMember.user_id == user_id,
        models.ExpertMember.status == "active",
    )
    result = await db.execute(stmt)
    member = result.scalar_one_or_none()
    if member is None:
        return None
    role = (member.role or "").strip().lower()
    if role not in ("owner", "admin", "member"):
        logger.warning(
            "ExpertMember %s has unknown role %r; treating as non-member",
            getattr(member, "id", (expert_id, user_id)),
            member.role,
        )
        return None
    return role  # type: ignore[return-value]


async def get_team_role(db, expert_id: str, user_id: str) -> Optional[TeamRole]:
    """返回当前用户在团队内的角色;非成员返回 None。结果在请求上下文内缓存。"""
    cache = _cache()
    key = (expert_id, user_id)
    if key in cache:
        return cache[key]
    role = await _query_team_role(db, expert_id, user_id)
    cache[key] = role
    return role


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
                "error_code": "NOT_TEAM_MEMBER",
                "message": "您不是该团队成员",
            },
        )
    if _ROLE_HIERARCHY[role] < _ROLE_HIERARCHY[minimum]:
        raise HTTPException(
            status_code=403,
            detail={
                "error_code": "INSUFFICIENT_TEAM_ROLE",
                "message": "角色权限不足",
                "required_role": minimum,
            },
        )
    return role
