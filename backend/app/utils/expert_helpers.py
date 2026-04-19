"""Expert 团队判断的统一 helper。

Phase A 范围用：替换 `routers.py` / `secure_auth_routes.py` /
`multi_participant_routes.py` 里多处 "TaskExpert OR ExpertMember" 双查逻辑。

Phase A 之前 migration 185 已保证每个 active TaskExpert 都有对应
ExpertMember(owner, active) 行，所以 Phase A 后单查 ExpertMember 不丢人。
"""
from typing import Optional

from sqlalchemy.orm import Session

from app.models_expert import Expert, ExpertMember


def is_user_expert_sync(db: Session, user_id: str) -> bool:
    """判断用户是否为任一 Expert 团队的 active 成员 (owner / admin / member)"""
    return (
        db.query(ExpertMember)
        .filter(
            ExpertMember.user_id == user_id,
            ExpertMember.status == "active",
        )
        .first()
        is not None
    )


def get_user_primary_expert_sync(db: Session, user_id: str) -> Optional[Expert]:
    """返回用户作为 owner 的 Expert 团队 (1 人团队或多人团队的 owner)。

    多个 owner 场景理论不应出现（业务保证），此处只取任意一个。
    使用 joinedload 一次 query 拿到 Expert,避免 2 次 round-trip。
    """
    from sqlalchemy.orm import joinedload

    row = (
        db.query(ExpertMember)
        .options(joinedload(ExpertMember.expert))
        .filter(
            ExpertMember.user_id == user_id,
            ExpertMember.role == "owner",
            ExpertMember.status == "active",
        )
        .first()
    )
    return row.expert if row else None
