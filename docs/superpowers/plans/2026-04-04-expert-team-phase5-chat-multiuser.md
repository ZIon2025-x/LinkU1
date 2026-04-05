# 达人团队体系 Phase 5 — 任务聊天多人化

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 达人 Owner/Admin 可邀请团队成员进入任务聊天，消息广播给所有参与者。Owner 始终在每个达人任务聊天中。

**Architecture:** 新建 `chat_participants` 表记录聊天参与者。邀请时插入记录，消息广播时额外查此表。现有双人聊天逻辑不变（`chat_participants` 为空时走旧逻辑）。

---

## Task 1: 数据库迁移

Create: `backend/migrations/163_create_chat_participants.sql`

```sql
-- ===========================================
-- 迁移 163: 创建任务聊天参与者表
-- ===========================================

BEGIN;

CREATE TABLE IF NOT EXISTS chat_participants (
    id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL DEFAULT 'expert_member',
    invited_by VARCHAR(8) REFERENCES users(id) ON DELETE SET NULL,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_chat_participant_role CHECK (role IN ('client', 'expert_owner', 'expert_admin', 'expert_member')),
    CONSTRAINT uq_chat_participant UNIQUE (task_id, user_id)
);

CREATE INDEX IF NOT EXISTS ix_chat_participants_task ON chat_participants(task_id);
CREATE INDEX IF NOT EXISTS ix_chat_participants_user ON chat_participants(user_id);

COMMIT;
```

## Task 2: 模型

Add to `backend/app/models_expert.py`:

```python
class ChatParticipant(Base):
    """任务聊天参与者（多人聊天扩展）"""
    __tablename__ = "chat_participants"

    id = Column(Integer, primary_key=True, autoincrement=True)
    task_id = Column(Integer, ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    role = Column(String(20), nullable=False, default="expert_member")
    invited_by = Column(String(8), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    joined_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())

    __table_args__ = (
        UniqueConstraint("task_id", "user_id", name="uq_chat_participant"),
        Index("ix_chat_participants_task", "task_id"),
        Index("ix_chat_participants_user", "user_id"),
    )
```

Import in `models.py` at bottom.

## Task 3: 邀请进聊天端点

Add to `backend/app/expert_routes.py`:

```python
POST /api/chat/tasks/{task_id}/invite — 邀请团队成员进入任务聊天
GET /api/chat/tasks/{task_id}/participants — 获取聊天参与者列表
```

Actually these should go in a new small router since they're chat-related, not expert-management:

Create `backend/app/chat_participant_routes.py` with two endpoints.

## Task 4: 广播逻辑扩展

Modify `backend/app/task_chat_routes.py` — in the participant collection logic (~line 780 and ~line 1210), add:

```python
# 额外查 chat_participants 表
cp_query = select(ChatParticipant.user_id).where(ChatParticipant.task_id == task_id)
cp_result = await db.execute(cp_query)
for uid in cp_result.scalars().all():
    if str(uid) not in participants:
        participants.append(str(uid))
```
