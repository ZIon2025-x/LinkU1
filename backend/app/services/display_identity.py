"""Helpers for resolving publisher display identity (name + avatar).

Given an (owner_type, owner_id) pair where owner_type is 'user' or 'expert',
return the display name and avatar URL for rendering in list/detail responses.

Notes on id types:
    Both ``users.id`` and ``experts.id`` are ``String(8)`` in this codebase, and
    ``owner_id`` on carrier tables (services/activities/forum_posts) is also
    ``String(8)``. No casting needed — we treat owner_id as ``str`` end-to-end.
"""
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select


async def resolve_async(
    db: AsyncSession,
    owner_type: str,
    owner_id: str,
) -> tuple[str, Optional[str]]:
    """Resolve a single (owner_type, owner_id) to (display_name, display_avatar).

    Falls back to ('', None) if the referenced record does not exist.
    """
    from app.models_expert import Expert
    from app.models import User

    if not owner_id:
        return ("", None)

    if owner_type == "expert":
        result = await db.execute(
            select(Expert).where(Expert.id == owner_id)
        )
        team = result.scalar_one_or_none()
        return ((team.name or "") if team else "", team.avatar if team else None)
    else:
        result = await db.execute(
            select(User).where(User.id == owner_id)
        )
        user = result.scalar_one_or_none()
        return ((user.name or "") if user else "", user.avatar if user else None)


async def batch_resolve_async(
    db: AsyncSession,
    identities: list[tuple[str, str]],
) -> dict[tuple[str, str], tuple[str, Optional[str]]]:
    """Batch resolve to avoid N+1 on list endpoints.

    Returns a dict keyed by ``(owner_type, owner_id)`` tuples. Missing entries
    resolve to ``("", None)``. Duplicate identities in the input are deduped
    internally for the SQL queries; callers can pass the raw list.
    """
    from app.models_expert import Expert
    from app.models import User

    expert_ids = list({oid for otype, oid in identities if otype == "expert" and oid})
    user_ids = list({oid for otype, oid in identities if otype == "user" and oid})

    experts: dict[str, tuple[str, Optional[str]]] = {}
    users: dict[str, tuple[str, Optional[str]]] = {}

    if expert_ids:
        rows = (await db.execute(
            select(Expert.id, Expert.name, Expert.avatar)
            .where(Expert.id.in_(expert_ids))
        )).all()
        experts = {r.id: (r.name or "", r.avatar) for r in rows}

    if user_ids:
        rows = (await db.execute(
            select(User.id, User.name, User.avatar)
            .where(User.id.in_(user_ids))
        )).all()
        users = {r.id: (r.name or "", r.avatar) for r in rows}

    out: dict[tuple[str, str], tuple[str, Optional[str]]] = {}
    for otype, oid in identities:
        if not oid:
            out[(otype, oid)] = ("", None)
        elif otype == "expert":
            out[(otype, oid)] = experts.get(oid, ("", None))
        else:
            out[(otype, oid)] = users.get(oid, ("", None))
    return out
