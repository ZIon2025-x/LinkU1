"""add_task_chat_features

Revision ID: task_chat_features_001
Revises: make_task_history_nullable
Create Date: 2025-01-27 00:00:00.000000

任务聊天功能数据库改动：
1. 修改 Task 表（添加 base_reward, agreed_reward, currency）
2. 修改 TaskApplication 表（添加 negotiated_price, currency）
3. 修改 Message 表（添加 task_id, message_type, conversation_type, meta）
4. 修改 Notification 表（添加 read_at，调整字段）
5. 创建 MessageReads 表
6. 创建 MessageAttachments 表
7. 创建 NegotiationResponseLog 表
8. 创建 MessageReadCursors 表
9. 创建必要的索引和约束

"""
from alembic import op
import sqlalchemy as sa
from typing import Sequence, Union


# revision identifiers, used by Alembic.
revision: str = 'task_chat_features_001'
# 基于已迁移的 add_pending_user_table
down_revision: Union[str, Sequence[str], None] = 'add_pending_user_table'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ============================================
    # 1. 修改 Task 表
    # ============================================
    op.add_column('tasks', sa.Column('base_reward', sa.Numeric(precision=12, scale=2), nullable=True))
    op.add_column('tasks', sa.Column('agreed_reward', sa.Numeric(precision=12, scale=2), nullable=True))
    op.add_column('tasks', sa.Column('currency', sa.String(length=3), server_default='GBP', nullable=True))
    
    # ============================================
    # 2. 修改 TaskApplication 表
    # ============================================
    op.add_column('task_applications', sa.Column('negotiated_price', sa.Numeric(precision=12, scale=2), nullable=True))
    op.add_column('task_applications', sa.Column('currency', sa.String(length=3), server_default='GBP', nullable=True))
    # 唯一约束已存在，无需添加
    
    # ============================================
    # 3. 修改 Message 表
    # ============================================
    # 先修改 receiver_id 为可空（用于任务消息）
    op.alter_column('messages', 'receiver_id',
                    existing_type=sa.String(length=8),
                    nullable=True)
    
    # 添加新字段
    op.add_column('messages', sa.Column('task_id', sa.Integer(), nullable=True))
    op.add_column('messages', sa.Column('message_type', sa.String(length=20), server_default='normal', nullable=True))
    op.add_column('messages', sa.Column('conversation_type', sa.String(length=20), server_default='task', nullable=True))
    op.add_column('messages', sa.Column('meta', sa.Text(), nullable=True))
    
    # 创建外键
    op.create_foreign_key(
        'fk_messages_task_id',
        'messages', 'tasks',
        ['task_id'], ['id']
    )
    
    # 创建索引
    op.create_index('ix_messages_task_id', 'messages', ['task_id'])
    op.create_index('ix_messages_task_type', 'messages', ['task_id', 'message_type'])
    op.create_index('ix_messages_task_created', 'messages', ['task_id', 'created_at', 'id'])
    op.create_index('ix_messages_conversation_type', 'messages', ['conversation_type', 'task_id'])
    op.create_index('ix_messages_task_id_id', 'messages', ['task_id', 'id'])
    
    # 创建 CHECK 约束（如果数据库支持）
    # 注意：某些数据库可能不支持 CHECK 约束，如果失败会在应用层校验
    try:
        op.create_check_constraint(
            'ck_messages_task_bind',
            'messages',
            "(conversation_type <> 'task' OR task_id IS NOT NULL)"
        )
    except Exception:
        pass  # 如果数据库不支持，跳过（应用层会校验）
    
    try:
        op.create_check_constraint(
            'ck_messages_type',
            'messages',
            "message_type IN ('normal', 'system')"
        )
    except Exception:
        pass
    
    try:
        op.create_check_constraint(
            'ck_messages_conversation_type',
            'messages',
            "conversation_type IN ('task', 'customer_service', 'global')"
        )
    except Exception:
        pass
    
    # ============================================
    # 4. 修改 Notification 表
    # ============================================
    # 修改 user_id 为不可空（如果原来可空）
    op.alter_column('notifications', 'user_id',
                    existing_type=sa.String(length=8),
                    nullable=False)
    
    # 修改 type 字段长度（从50改为32）
    op.alter_column('notifications', 'type',
                    existing_type=sa.String(length=50),
                    type_=sa.String(length=32),
                    nullable=False)
    
    # 修改 title 为可空（向后兼容）
    op.alter_column('notifications', 'title',
                    existing_type=sa.String(length=200),
                    nullable=True)
    
    # 添加 read_at 字段
    op.add_column('notifications', sa.Column('read_at', sa.DateTime(), nullable=True))
    
    # 创建新索引
    op.create_index('ix_notifications_user', 'notifications', ['user_id', 'created_at'])
    op.create_index('ix_notifications_type', 'notifications', ['type', 'related_id'])
    
    # ============================================
    # 5. 创建 MessageReads 表
    # ============================================
    op.create_table(
        'message_reads',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('message_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.String(length=8), nullable=False),
        sa.Column('read_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['message_id'], ['messages.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('message_id', 'user_id', name='uq_message_reads_message_user')
    )
    op.create_index('ix_message_reads_message_id', 'message_reads', ['message_id'])
    op.create_index('ix_message_reads_user_id', 'message_reads', ['user_id'])
    op.create_index('ix_message_reads_task_user', 'message_reads', ['message_id', 'user_id'])
    
    # ============================================
    # 6. 创建 MessageAttachments 表
    # ============================================
    op.create_table(
        'message_attachments',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('message_id', sa.Integer(), nullable=False),
        sa.Column('attachment_type', sa.String(length=20), nullable=False),
        sa.Column('url', sa.String(length=500), nullable=True),
        sa.Column('blob_id', sa.String(length=100), nullable=True),
        sa.Column('meta', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['message_id'], ['messages.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_message_attachments_message_id', 'message_attachments', ['message_id'])
    
    # 创建 CHECK 约束：url 和 blob_id 必须二选一
    try:
        op.create_check_constraint(
            'ck_message_attachments_url_blob',
            'message_attachments',
            "(url IS NOT NULL AND blob_id IS NULL) OR (url IS NULL AND blob_id IS NOT NULL)"
        )
    except Exception:
        pass  # 如果数据库不支持，跳过（应用层会校验）
    
    # ============================================
    # 7. 创建 NegotiationResponseLog 表
    # ============================================
    op.create_table(
        'negotiation_response_logs',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('notification_id', sa.Integer(), nullable=True),
        sa.Column('task_id', sa.Integer(), nullable=False),
        sa.Column('application_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.String(length=8), nullable=False),
        sa.Column('action', sa.String(length=20), nullable=False),
        sa.Column('negotiated_price', sa.Numeric(precision=12, scale=2), nullable=True),
        sa.Column('responded_at', sa.DateTime(), nullable=False),
        sa.Column('ip_address', sa.String(length=45), nullable=True),
        sa.Column('user_agent', sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(['notification_id'], ['notifications.id']),
        sa.ForeignKeyConstraint(['task_id'], ['tasks.id']),
        sa.ForeignKeyConstraint(['application_id'], ['task_applications.id']),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('application_id', 'action', name='uq_negotiation_log_application_action')
    )
    op.create_index('ix_negotiation_log_notification', 'negotiation_response_logs', ['notification_id'])
    op.create_index('ix_negotiation_log_task', 'negotiation_response_logs', ['task_id'])
    op.create_index('ix_negotiation_log_application', 'negotiation_response_logs', ['application_id'])
    op.create_index('ix_negotiation_log_user', 'negotiation_response_logs', ['user_id'])
    
    # ============================================
    # 8. 创建 MessageReadCursors 表
    # ============================================
    op.create_table(
        'message_read_cursors',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('task_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.String(length=8), nullable=False),
        sa.Column('last_read_message_id', sa.Integer(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['task_id'], ['tasks.id']),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.ForeignKeyConstraint(['last_read_message_id'], ['messages.id']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('task_id', 'user_id', name='uq_message_read_cursors_task_user')
    )
    op.create_index('ix_message_read_cursors_task_user', 'message_read_cursors', ['task_id', 'user_id'])
    op.create_index('ix_message_read_cursors_message', 'message_read_cursors', ['last_read_message_id'])


def downgrade() -> None:
    # ============================================
    # 8. 删除 MessageReadCursors 表
    # ============================================
    op.drop_index('ix_message_read_cursors_message', table_name='message_read_cursors')
    op.drop_index('ix_message_read_cursors_task_user', table_name='message_read_cursors')
    op.drop_table('message_read_cursors')
    
    # ============================================
    # 7. 删除 NegotiationResponseLog 表
    # ============================================
    op.drop_index('ix_negotiation_log_user', table_name='negotiation_response_logs')
    op.drop_index('ix_negotiation_log_application', table_name='negotiation_response_logs')
    op.drop_index('ix_negotiation_log_task', table_name='negotiation_response_logs')
    op.drop_index('ix_negotiation_log_notification', table_name='negotiation_response_logs')
    op.drop_table('negotiation_response_logs')
    
    # ============================================
    # 6. 删除 MessageAttachments 表
    # ============================================
    try:
        op.drop_constraint('ck_message_attachments_url_blob', 'message_attachments', type_='check')
    except Exception:
        pass
    op.drop_index('ix_message_attachments_message_id', table_name='message_attachments')
    op.drop_table('message_attachments')
    
    # ============================================
    # 5. 删除 MessageReads 表
    # ============================================
    op.drop_index('ix_message_reads_task_user', table_name='message_reads')
    op.drop_index('ix_message_reads_user_id', table_name='message_reads')
    op.drop_index('ix_message_reads_message_id', table_name='message_reads')
    op.drop_table('message_reads')
    
    # ============================================
    # 4. 恢复 Notification 表
    # ============================================
    op.drop_index('ix_notifications_type', table_name='notifications')
    op.drop_index('ix_notifications_user', table_name='notifications')
    op.drop_column('notifications', 'read_at')
    op.alter_column('notifications', 'title',
                    existing_type=sa.String(length=200),
                    nullable=False)
    op.alter_column('notifications', 'type',
                    existing_type=sa.String(length=32),
                    type_=sa.String(length=50),
                    nullable=False)
    
    # ============================================
    # 3. 恢复 Message 表
    # ============================================
    try:
        op.drop_constraint('ck_messages_conversation_type', 'messages', type_='check')
    except Exception:
        pass
    try:
        op.drop_constraint('ck_messages_type', 'messages', type_='check')
    except Exception:
        pass
    try:
        op.drop_constraint('ck_messages_task_bind', 'messages', type_='check')
    except Exception:
        pass
    op.drop_index('ix_messages_task_id_id', table_name='messages')
    op.drop_index('ix_messages_conversation_type', table_name='messages')
    op.drop_index('ix_messages_task_created', table_name='messages')
    op.drop_index('ix_messages_task_type', table_name='messages')
    op.drop_index('ix_messages_task_id', table_name='messages')
    op.drop_constraint('fk_messages_task_id', 'messages', type_='foreignkey')
    op.drop_column('messages', 'meta')
    op.drop_column('messages', 'conversation_type')
    op.drop_column('messages', 'message_type')
    op.drop_column('messages', 'task_id')
    op.alter_column('messages', 'receiver_id',
                    existing_type=sa.String(length=8),
                    nullable=False)
    
    # ============================================
    # 2. 恢复 TaskApplication 表
    # ============================================
    op.drop_column('task_applications', 'currency')
    op.drop_column('task_applications', 'negotiated_price')
    
    # ============================================
    # 1. 恢复 Task 表
    # ============================================
    op.drop_column('tasks', 'currency')
    op.drop_column('tasks', 'agreed_reward')
    op.drop_column('tasks', 'base_reward')

