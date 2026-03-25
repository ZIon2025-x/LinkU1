"""add application_id to messages for per-application chat channels

Revision ID: 001
Revises: None
Create Date: 2026-03-16
"""

from alembic import op
import sqlalchemy as sa

# revision identifiers
revision = '001'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. Add application_id column to messages table
    op.add_column('messages', sa.Column(
        'application_id', sa.Integer(),
        sa.ForeignKey('task_applications.id', ondelete='CASCADE'),
        nullable=True
    ))

    # 2. Add composite index on (task_id, application_id)
    op.create_index('ix_messages_task_application', 'messages', ['task_id', 'application_id'])

    # 3. Drop old message_type CHECK constraint and create new one with 'price_proposal'
    op.drop_constraint('ck_messages_type', 'messages', type_='check')
    op.create_check_constraint(
        'ck_messages_type', 'messages',
        "message_type IN ('normal', 'system', 'price_proposal')"
    )

    # 4. Add application_id column to message_read_cursors table
    op.add_column('message_read_cursors', sa.Column(
        'application_id', sa.Integer(),
        sa.ForeignKey('task_applications.id', ondelete='CASCADE'),
        nullable=True
    ))

    # 5. Drop old unique constraint and create new one including application_id
    op.drop_constraint('uq_message_read_cursors_task_user', 'message_read_cursors', type_='unique')
    op.create_unique_constraint(
        'uq_message_read_cursors_task_user_application',
        'message_read_cursors',
        ['task_id', 'user_id', 'application_id']
    )


def downgrade() -> None:
    # 1. Restore old unique constraint on message_read_cursors
    op.drop_constraint('uq_message_read_cursors_task_user_application', 'message_read_cursors', type_='unique')
    op.create_unique_constraint(
        'uq_message_read_cursors_task_user',
        'message_read_cursors',
        ['task_id', 'user_id']
    )

    # 2. Remove application_id from message_read_cursors
    op.drop_column('message_read_cursors', 'application_id')

    # 3. Restore old message_type CHECK constraint
    op.drop_constraint('ck_messages_type', 'messages', type_='check')
    op.create_check_constraint(
        'ck_messages_type', 'messages',
        "message_type IN ('normal', 'system')"
    )

    # 4. Drop composite index
    op.drop_index('ix_messages_task_application', 'messages')

    # 5. Remove application_id from messages
    op.drop_column('messages', 'application_id')
