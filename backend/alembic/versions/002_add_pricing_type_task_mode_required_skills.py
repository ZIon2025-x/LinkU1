"""add pricing_type, task_mode, required_skills to tasks

Revision ID: 002
Revises: 001
Create Date: 2026-03-25
"""

from alembic import op
import sqlalchemy as sa

# revision identifiers
revision = '002'
down_revision = '001'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 定价类型: fixed(固定价), hourly(时薪), negotiable(协商定价)
    op.add_column('tasks', sa.Column(
        'pricing_type', sa.String(20),
        server_default='fixed', nullable=True
    ))

    # 任务方式: online(线上), offline(线下), both(都可以)
    op.add_column('tasks', sa.Column(
        'task_mode', sa.String(20),
        server_default='online', nullable=True
    ))

    # 所需技能标签 (JSON 数组)
    op.add_column('tasks', sa.Column(
        'required_skills', sa.Text(),
        nullable=True
    ))


def downgrade() -> None:
    op.drop_column('tasks', 'required_skills')
    op.drop_column('tasks', 'task_mode')
    op.drop_column('tasks', 'pricing_type')
