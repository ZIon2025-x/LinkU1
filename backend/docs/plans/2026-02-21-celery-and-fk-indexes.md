# Celery Concurrency + FK Indexes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix two backend performance issues: make Celery concurrency configurable via env var, and add two missing FK indexes.

**Architecture:** (1) Replace hardcoded `--concurrency=2` in `start_celery.sh` with `${CELERY_CONCURRENCY:-4}` so Railway env vars control it at runtime. (2) Add migration `094_add_missing_fk_indexes.sql` with two `CREATE INDEX IF NOT EXISTS` statements for columns confirmed missing after auditing all 93 existing migrations and `__table_args__` definitions.

**Tech Stack:** Bash, PostgreSQL SQL

---

### Task 1: Celery Concurrency — Env Var

**Files:**
- Modify: `backend/start_celery.sh:10`

**Step 1: Edit the file**

Change line 10 from:
```bash
celery -A app.celery_app worker --loglevel=info --concurrency=2
```
To:
```bash
celery -A app.celery_app worker --loglevel=info --concurrency=${CELERY_CONCURRENCY:-4}
```

**Step 2: Verify the change**

Run: `cat backend/start_celery.sh`
Expected: Line 10 shows `--concurrency=${CELERY_CONCURRENCY:-4}`

**Step 3: Commit**

```bash
git add backend/start_celery.sh
git commit -m "fix(celery): make worker concurrency configurable via CELERY_CONCURRENCY env var (default 4)"
```

**Railway 操作（部署后）：**
在 Railway Celery worker service 的 Variables 面板中添加：
```
CELERY_CONCURRENCY=4
```
不设置时自动回退到默认值 4，随时可调整无需重新部署代码。

---

### Task 2: FK Indexes — Migration 094

**Background:**
经过对全部 93 个迁移文件和 models.py `__table_args__` 的完整审计，确认以下两处 FK 列真正缺少索引：

| 表 | 缺失列 | 原因 |
|---|---|---|
| `task_audit_logs` | `user_id` | Migration 007 创建表时只建了 task_id/participant_id/created_at 三个索引 |
| `oauth_refresh_token` | `user_id` | Migration 081 只建了 token/client_id/expires_at 三个索引 |

其余原分析报告中提及的"缺失索引"（tasks.poster_id、messages.sender_id、notifications.user_id 等）均已被 migration 035/050 或 `__table_args__` 覆盖，无需重复添加。

**Files:**
- Create: `backend/migrations/094_add_missing_fk_indexes.sql`

**Step 1: Create the migration file**

```sql
-- 补充两处真正缺失的外键索引
-- 审计依据：逐一检查 migrations/001-093 + models.py __table_args__，确认以下列无索引

-- task_audit_logs.user_id
-- Migration 007 建表时创建了 task_id/participant_id/created_at 索引，遗漏了 user_id
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON task_audit_logs(user_id)
    WHERE user_id IS NOT NULL;

-- oauth_refresh_token.user_id
-- Migration 081 建表时创建了 token/client_id/expires_at 索引，遗漏了 user_id
CREATE INDEX IF NOT EXISTS idx_oauth_refresh_token_user_id ON oauth_refresh_token(user_id);
```

**Step 2: Verify file exists and content is correct**

Run: `cat backend/migrations/094_add_missing_fk_indexes.sql`
Expected: Shows both CREATE INDEX statements

**Step 3: Commit**

```bash
git add backend/migrations/094_add_missing_fk_indexes.sql
git commit -m "fix(db): add missing FK indexes on task_audit_logs.user_id and oauth_refresh_token.user_id"
```

**部署后需手动在 Railway 控制台执行此 SQL**（或通过 psql 连接执行）。
两条语句均有 `IF NOT EXISTS`，幂等安全，可重复执行。
