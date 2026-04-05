"""达人板块权限检查辅助函数"""
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from app.models import ForumCategory
from app.models_expert import ExpertMember


async def is_expert_board(db: AsyncSession, category_id: int) -> tuple[bool, str | None]:
    """检查板块是否为达人板块，返回 (is_expert, expert_id)"""
    result = await db.execute(
        select(ForumCategory.type, ForumCategory.expert_id)
        .where(ForumCategory.id == category_id)
    )
    row = result.first()
    if row and row[0] == 'expert':
        return True, row[1]
    return False, None


async def check_expert_board_post_permission(db: AsyncSession, expert_id: str, user_id: str) -> bool:
    """检查用户是否可以在达人板块发帖（必须是团队活跃成员）"""
    result = await db.execute(
        select(ExpertMember).where(
            and_(
                ExpertMember.expert_id == expert_id,
                ExpertMember.user_id == user_id,
                ExpertMember.status == "active",
            )
        )
    )
    return result.scalar_one_or_none() is not None


async def check_expert_board_manage_permission(db: AsyncSession, expert_id: str, user_id: str) -> bool:
    """检查用户是否可以管理达人板块（Owner/Admin）"""
    result = await db.execute(
        select(ExpertMember).where(
            and_(
                ExpertMember.expert_id == expert_id,
                ExpertMember.user_id == user_id,
                ExpertMember.status == "active",
                ExpertMember.role.in_(["owner", "admin"]),
            )
        )
    )
    return result.scalar_one_or_none() is not None
