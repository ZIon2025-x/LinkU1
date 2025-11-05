"""make_task_history_user_id_nullable

Revision ID: make_task_history_nullable
Revises: 618c4cce1eb7
Create Date: 2025-11-05 17:46:00.000000

"""
from alembic import op
import sqlalchemy as sa
from typing import Sequence, Union


# revision identifiers, used by Alembic.
revision: str = 'make_task_history_nullable'
down_revision: Union[str, Sequence[str], None] = '618c4cce1eb7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 查找并删除现有的外键约束
    # 使用 PostgreSQL 系统表查找实际的约束名称
    connection = op.get_bind()
    result = connection.execute(sa.text("""
        SELECT constraint_name 
        FROM information_schema.table_constraints 
        WHERE table_name = 'task_history' 
        AND constraint_type = 'FOREIGN KEY' 
        AND constraint_name LIKE '%user_id%'
    """))
    
    constraint_name = result.scalar()
    if constraint_name:
        op.drop_constraint(constraint_name, 'task_history', type_='foreignkey')
    
    # 修改 user_id 字段为可空
    op.alter_column('task_history', 'user_id',
                    existing_type=sa.String(length=8),
                    nullable=True,
                    existing_nullable=False)
    
    # 重新创建外键约束（允许 NULL 值）
    op.create_foreign_key(
        'task_history_user_id_fkey',
        'task_history', 'users',
        ['user_id'], ['id'],
        ondelete='SET NULL'
    )


def downgrade() -> None:
    # 删除外键约束
    op.drop_constraint('task_history_user_id_fkey', 'task_history', type_='foreignkey')
    
    # 修改 user_id 字段为不可空（需要先清理 NULL 值）
    # 注意：如果有 NULL 值，需要先更新为有效值或删除记录
    op.execute("""
        UPDATE task_history 
        SET user_id = (SELECT id FROM users LIMIT 1) 
        WHERE user_id IS NULL
    """)
    
    op.alter_column('task_history', 'user_id',
                    existing_type=sa.String(length=8),
                    nullable=False)
    
    # 重新创建外键约束
    op.create_foreign_key(
        'task_history_user_id_fkey',
        'task_history', 'users',
        ['user_id'], ['id']
    )

