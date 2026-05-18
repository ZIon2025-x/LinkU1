# AI 限时问答 P0 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 AI 限时问答 P0 MVP——admin 后台手填发题 + 用户答题 + AI 评分 + admin 终审 + 钱包入账发奖；不接 Celery 自动出题（P1）+ 不做用户面入口卡片（P2）。

**Architecture:** 5 张新表（ai_questions / ai_question_candidates / ai_qa_cycle_configs / ai_answer_scores / ai_qa_leaderboard）+ ForumPost 加 ai_question_id 字段 + 接现有 wallet_service.credit_wallet 入账 + 接 risk_control.check_risk 反作弊 + 接 create_audit_log 审计 + email_utils S6 告警。settle 事务用 SELECT FOR UPDATE 行锁 + wallet_transactions.idempotency_key UNIQUE 防双发。

**Tech Stack:** FastAPI + SQLAlchemy + PostgreSQL + Pydantic v2 + Anthropic SDK (Claude Sonnet 4.5 评分) + React Admin + Flutter BLoC。

**配套 spec:** `docs/superpowers/specs/2026-05-13-ai-qa-bounty-design.md`
**配套 mockup:** `docs/superpowers/specs/2026-05-13-ai-qa-bounty-mockup.html`

---

## 后续 spec 增量的 migration 编号策略

本 plan 只覆盖 P0 基础流程,migration 编号 **237**。两个增量 spec **不合并到 237**,各自独立编号 + 各自独立 plan,P0 上线在前。约定:

| spec | migration 编号 | DB 改动 | 上线节奏 |
|---|---|---|---|
| **P0 基础** (本 plan) | `237_ai_qa_bounty.sql` | 5 新表 + ForumPost.ai_question_id + SystemSettings 3 项 | 第一波 |
| **Sponsor 加注** (`2026-05-18-ai-qa-sponsor-pledge-design.md`) | `238_ai_qa_sponsor_pledge.sql` | 3 新表 (ai_qa_pledges / ai_qa_pledge_pool / ai_qa_pledge_pool_transactions) + ai_questions 加 sponsor_pool_pence + pledge_pool_carryover_pence 2 字段 | P0 上线观察一周后 |
| **社区限时问答** (`2026-05-18-ai-qa-user-submitted-design.md`) | `239_ai_qa_user_submitted.sql` | ai_questions 加 5 字段 (submitted_by_user_id / submitted_at / rejected_at / rejected_reason_code / rejected_reason_detail / withdrawn_at) + status enum 扩展 3 个 (pending_review / rejected / withdrawn) + 2 索引 | 依赖 sponsor 的混合付款流程,sponsor 之后 |

**关键 forward-compat 注释** (本 plan 实施时需埋点,避免 sponsor/user-submitted 上线时回头改):

- **`cancel_question` / `close_expired_ai_questions` / `score_closed_ai_questions` 三处状态切换** (P0 Task 4 + Task 10): 注释里写明 "TODO sponsor: 此处加 `carry_over_pledges_to_pool(db, qid)` hook"。sponsor 上线时同处加 hook,**不动 P0 代码结构**,只增量补 import + 一行调用。
- **`publish_draft` / `publish_candidate`** (P0 Task 4 + 未来 P1 cycle): 注释里写明 "TODO sponsor: 此处加 `consume_pledge_pool_for_new_question(db, q)` hook"。
- **`/api/ai-qa/{qid}/answer` 端点** (P0 Task 7): 注释里写明 "TODO user-submitted: 校验 if ai_questions.submitted_by_user_id == current_user.id → 拒 403 `ai_qa_self_submission_cannot_answer`"。
- **详情页 hero 区** (P0 Task 15 Flutter): 注释 "TODO user-submitted: 根据 submitted_by_user_id 是否 NULL 切金色 (AI 限时问答) / 蓝色 (社区限时问答) 皮肤"。

---

## 文件结构

### 后端新建（按职责）

| 文件 | 职责 |
|---|---|
| `backend/migrations/237_ai_qa_bounty.sql` | DB migration（5 新表 + ForumPost 字段 + SystemSettings 默认值 + CHECK 约束）|
| `backend/app/models_ai_qa.py` | SQLAlchemy 模型（5 个新表，独立文件避免动 models.py）|
| `backend/app/schemas_ai_qa.py` | Pydantic schemas（请求/响应 schema）|
| `backend/app/crud/ai_qa.py` | CRUD 函数（基础读写）|
| `backend/app/services/ai_qa_scoring.py` | 评分算法工具（distribute_pool 全员按比例分 + floor_pence 抹零）+ AI 评分服务（Claude API 调用 + JSON 解析）|
| `backend/app/services/ai_qa_settle.py` | settle 事务服务（S1 行锁 + S5 cap + wallet credit + S6 邮件 + audit）|
| `backend/app/ai_qa_user_routes.py` | 用户端路由 `/api/ai-qa/*` |
| `backend/app/ai_qa_admin_routes.py` | Admin 端路由 `/api/admin/ai-qa/*` |
| `backend/tests/test_ai_qa_scoring.py` | 评分算法单测 |
| `backend/tests/test_ai_qa_settle.py` | settle 事务集成测试 |
| `backend/tests/test_ai_qa_user_routes.py` | 用户端集成测试 |
| `backend/tests/test_ai_qa_admin_routes.py` | Admin 端集成测试 |

### 后端修改

| 文件 | 改动 |
|---|---|
| `backend/app/models.py` | ForumPost 加 `ai_question_id` 字段 + index |
| `backend/app/main.py` | include 新增的 2 个 router |
| `backend/app/scheduled_tasks.py` | 加 `close_expired_ai_questions()` + `score_closed_ai_questions()` beat 任务 + Celery wrapper |

### 前端新建（admin web）

| 文件 | 职责 |
|---|---|
| `admin/src/pages/ai-qa/DraftsPage.tsx` | A3 草稿管理（列表 + 编辑 + 发布 + 删除）|
| `admin/src/pages/ai-qa/QuestionsPage.tsx` | A4 题目列表（状态过滤 + 撤稿 + 进入终审）|
| `admin/src/pages/ai-qa/ReviewPage.tsx` | A5 评分终审（表格 + 改分 + 发奖）|
| `admin/src/components/ai-qa/FloorPenceInput.tsx` | floor_pence 输入 + 实时预览（共享于 drafts + cycle config，未来 P1 cycle config 复用）|
| `admin/src/api/aiQa.ts` | API client（封装 /api/admin/ai-qa/* 调用）|

### 前端新建（Flutter）

| 文件 | 职责 |
|---|---|
| `link2ur/lib/features/ai_qa/bloc/ai_qa_bloc.dart` | 详情 + 答题 state |
| `link2ur/lib/features/ai_qa/views/ai_qa_detail_view.dart` | M3/M4/M5 详情页（published/canceled/settled 三态）|
| `link2ur/lib/features/ai_qa/views/ai_qa_answer_form_view.dart` | M6 答题表单 |
| `link2ur/lib/data/models/ai_qa.dart` | AiQuestion + AiAnswerScore Equatable models |
| `link2ur/lib/data/repositories/ai_qa_repository.dart` | Repository wrapping ApiService |

### 前端修改

| 文件 | 改动 |
|---|---|
| `link2ur/lib/core/router/app_router.dart` | 加 `/ai-qa/:id` + `/ai-qa/:id/answer` 路由 |
| `link2ur/lib/core/constants/api_endpoints.dart` | 加 ai_qa endpoint 常量 |
| `link2ur/lib/app_providers.dart` | MultiRepositoryProvider 加 AiQaRepository |
| `link2ur/lib/l10n/app_{en,zh,zh_Hant}.arb` | 加 ai_qa_* l10n key |
| `link2ur/lib/core/utils/error_localizer.dart` | 加 ai_qa_* 错误码映射 |

---

## 实施顺序

按依赖关系：
1. **数据层** (Task 1-3)：migration → models → schemas
2. **业务层** (Task 4-9)：CRUD → 评分算法 → AI 评分服务 → settle 服务 → 用户端路由 → admin 端路由
3. **调度层** (Task 10)：beat 任务
4. **Admin Web** (Task 11-13)：3 个页面
5. **Flutter** (Task 14-15)：3 个 view + 路由 + l10n

每个 task 完成后 commit。

---

### Task 1: DB Migration

**Files:**
- Create: `backend/migrations/237_ai_qa_bounty.sql`

- [ ] **Step 1: 创建 migration 文件**

```sql
-- backend/migrations/237_ai_qa_bounty.sql
-- AI 限时问答 P0 MVP: 5 新表 + ForumPost 字段 + SystemSettings 默认值

BEGIN;

-- ========== 1. ai_qa_cycle_configs (P1 才用,但 P0 建表) ==========
CREATE TABLE ai_qa_cycle_configs (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(80) NOT NULL,
    cadence         VARCHAR(20) NOT NULL,
    next_run_at     TIMESTAMPTZ,
    is_active       BOOLEAN DEFAULT TRUE,
    direction_prompt        TEXT NOT NULL,
    default_reward_pool_pence       INT NOT NULL DEFAULT 1000
        CHECK (default_reward_pool_pence BETWEEN 0 AND 100000),
    default_participation_points    INT NOT NULL DEFAULT 5
        CHECK (default_participation_points BETWEEN 0 AND 1000),
    default_floor_pence             INT NOT NULL DEFAULT 10 CHECK (default_floor_pence BETWEEN 1 AND 1000),
    default_duration_hours          INT NOT NULL DEFAULT 168,
    default_edit_lock_hours_before  INT NOT NULL DEFAULT 1,
    target_forum_category_id        INT NOT NULL REFERENCES forum_categories(id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ========== 2. ai_questions (主表) ==========
CREATE TABLE ai_questions (
    id              SERIAL PRIMARY KEY,
    title           VARCHAR(200) NOT NULL,
    content         TEXT NOT NULL,
    topic_tag       VARCHAR(50),
    posed_by_expert_id  VARCHAR(8) NOT NULL REFERENCES experts(id),
    status          VARCHAR(20) NOT NULL DEFAULT 'draft',
    published_at    TIMESTAMPTZ,
    deadline        TIMESTAMPTZ,
    edit_lock_at    TIMESTAMPTZ,
    canceled_at     TIMESTAMPTZ,
    cancel_reason   TEXT,
    settled_at      TIMESTAMPTZ,
    reward_pool_pence       INT NOT NULL DEFAULT 1000
        CHECK (reward_pool_pence BETWEEN 0 AND 100000),
    participation_points    INT NOT NULL DEFAULT 5
        CHECK (participation_points BETWEEN 0 AND 1000),
    floor_pence             INT NOT NULL DEFAULT 10 CHECK (floor_pence BETWEEN 1 AND 1000),
    ai_prompt_used          TEXT,
    target_forum_category_id INT NOT NULL REFERENCES forum_categories(id),
    cycle_config_id         INT REFERENCES ai_qa_cycle_configs(id),
    created_by_admin_id     VARCHAR(5) NOT NULL REFERENCES admin_users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_ai_questions_status ON ai_questions(status);
CREATE INDEX idx_ai_questions_deadline ON ai_questions(deadline) WHERE status = 'published';

-- ========== 3. ai_question_candidates (P1 才用,P0 建表) ==========
CREATE TABLE ai_question_candidates (
    id              SERIAL PRIMARY KEY,
    cycle_run_id    VARCHAR(36) NOT NULL,
    cycle_config_id INT NOT NULL REFERENCES ai_qa_cycle_configs(id),
    title           VARCHAR(200) NOT NULL,
    content         TEXT NOT NULL,
    topic_tag       VARCHAR(50),
    ai_model_used   VARCHAR(80),
    chosen          BOOLEAN DEFAULT FALSE,
    expired_at      TIMESTAMPTZ,
    snapshot_reward_pool_pence       INT NOT NULL,
    snapshot_floor_pence             INT NOT NULL,
    snapshot_duration_hours          INT NOT NULL,
    snapshot_edit_lock_hours_before  INT NOT NULL,
    snapshot_participation_points    INT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_ai_question_candidates_cycle ON ai_question_candidates(cycle_run_id);
CREATE INDEX idx_ai_question_candidates_cycle_config ON ai_question_candidates(cycle_config_id);

-- ========== 4. ai_answer_scores ("答案+评分"完整记录) ==========
CREATE TABLE ai_answer_scores (
    id              SERIAL PRIMARY KEY,
    ai_question_id  INT NOT NULL REFERENCES ai_questions(id) ON DELETE CASCADE,
    forum_post_id   INT NOT NULL,  -- 不加 FK,允许 ForumPost 删后保留历史
    user_id         VARCHAR(8) NOT NULL,
    risk_score      INT DEFAULT 0,
    risk_reasons    TEXT,
    ai_score        INT,
    off_topic       BOOLEAN DEFAULT FALSE,
    ai_generated    VARCHAR(10),
    ai_raw_response JSONB,
    admin_override_score    INT,
    admin_reviewer_id       VARCHAR(5) REFERENCES admin_users(id),
    admin_reviewed_at       TIMESTAMPTZ,
    hide_in_qa              BOOLEAN DEFAULT FALSE,
    final_score             INT,
    rank_final              INT,
    reward_pence            INT DEFAULT 0,
    reward_points           INT DEFAULT 0,
    settled_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (ai_question_id, forum_post_id),
    UNIQUE (ai_question_id, user_id)
);
CREATE INDEX idx_ai_answer_scores_question ON ai_answer_scores(ai_question_id);
CREATE INDEX idx_ai_answer_scores_user ON ai_answer_scores(user_id);

-- ========== 5. ai_qa_leaderboard (P0 写入,P2 才上前端入口) ==========
CREATE TABLE ai_qa_leaderboard (
    id              SERIAL PRIMARY KEY,
    user_id         VARCHAR(8) NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    total_won_pence INT DEFAULT 0,
    win_count       INT DEFAULT 0,
    answer_count    INT DEFAULT 0,
    last_won_at     TIMESTAMPTZ,
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ========== 6. ForumPost 加 ai_question_id 字段 ==========
ALTER TABLE forum_posts ADD COLUMN ai_question_id INT REFERENCES ai_questions(id);
CREATE INDEX idx_forum_posts_ai_question_id ON forum_posts(ai_question_id)
    WHERE ai_question_id IS NOT NULL;

-- ========== 7. SystemSettings 默认值 ==========
-- 这些是运行时可调的安全/告警参数
INSERT INTO system_settings (setting_key, setting_value, description) VALUES
    ('ai_qa_weekly_settle_cap_pence', '20000',
     'AI 限时问答周度发奖总额上限 (pence)，默认 £200/周'),
    ('ai_qa_settle_alert_threshold_pence', '10000',
     'AI 限时问答周度发奖告警阈值 (pence)，超过发邮件给 admin'),
    ('ai_qa_default_expert_id', '',
     'AI 限时问答 draft 路径默认 posed_by_expert_id (留空则 admin 提交时必填)')
ON CONFLICT (setting_key) DO NOTHING;

COMMIT;
```

- [ ] **Step 2: 测试 migration 可前向跑（linktest 环境）**

Run: `psql $LINKTEST_DATABASE_URL -f backend/migrations/237_ai_qa_bounty.sql`
Expected: `COMMIT` 输出，无错误

- [ ] **Step 3: 验证表结构正确**

Run:
```bash
psql $LINKTEST_DATABASE_URL -c "\d ai_questions"
psql $LINKTEST_DATABASE_URL -c "\d ai_answer_scores"
psql $LINKTEST_DATABASE_URL -c "\d forum_posts" | grep ai_question_id
```
Expected: 字段定义都在，CHECK 约束 + FK 都存在。

- [ ] **Step 4: 验证 CHECK 约束生效**

Run:
```bash
psql $LINKTEST_DATABASE_URL -c "INSERT INTO ai_questions (title, content, posed_by_expert_id, reward_pool_pence, floor_pence, target_forum_category_id, created_by_admin_id) VALUES ('test', 'test', 'EXP00001', 100001, 10, 1, 'AD001')"
```
Expected: ERROR: new row for relation "ai_questions" violates check constraint "ai_questions_reward_pool_pence_check"

- [ ] **Step 5: 验证 UNIQUE 约束**

Run:
```bash
psql $LINKTEST_DATABASE_URL << 'EOF'
INSERT INTO ai_questions (title, content, posed_by_expert_id, reward_pool_pence, floor_pence, target_forum_category_id, created_by_admin_id)
VALUES ('test', 'test', 'EXP00001', 1000, 10, 1, 'AD001') RETURNING id;
INSERT INTO ai_answer_scores (ai_question_id, forum_post_id, user_id) VALUES (currval('ai_questions_id_seq'), 1, 'U0000001');
INSERT INTO ai_answer_scores (ai_question_id, forum_post_id, user_id) VALUES (currval('ai_questions_id_seq'), 2, 'U0000001');
EOF
```
Expected: 第二个 INSERT 报 duplicate key value violates unique constraint "ai_answer_scores_ai_question_id_user_id_key"

- [ ] **Step 6: 清理测试数据**

Run:
```bash
psql $LINKTEST_DATABASE_URL << 'EOF'
DELETE FROM ai_answer_scores;
DELETE FROM ai_questions;
EOF
```

- [ ] **Step 7: Commit**

```bash
git add backend/migrations/237_ai_qa_bounty.sql
git commit -m "feat(ai-qa): migration 237 — 5 新表 + ForumPost.ai_question_id + SystemSettings"
```

---

### Task 2: SQLAlchemy Models

**Files:**
- Create: `backend/app/models_ai_qa.py`
- Modify: `backend/app/models.py:2540` (ForumPost 加字段)
- Modify: `backend/app/models.py:2554` (ForumPost __table_args__ 加 index)

- [ ] **Step 1: 创建 models_ai_qa.py**

```python
# backend/app/models_ai_qa.py
"""AI 限时问答相关 ORM 模型。独立文件避免污染 models.py。"""
from sqlalchemy import (
    Column, BigInteger, Integer, String, Text, Boolean, DateTime, JSON,
    ForeignKey, Index, UniqueConstraint, CheckConstraint, func
)
from sqlalchemy.dialects.postgresql import JSONB
from app.models import Base


class AiQaCycleConfig(Base):
    __tablename__ = "ai_qa_cycle_configs"
    id = Column(Integer, primary_key=True)
    name = Column(String(80), nullable=False)
    cadence = Column(String(20), nullable=False)
    next_run_at = Column(DateTime(timezone=True))
    is_active = Column(Boolean, default=True)
    direction_prompt = Column(Text, nullable=False)
    default_reward_pool_pence = Column(Integer, nullable=False, default=1000)
    default_participation_points = Column(Integer, nullable=False, default=5)
    default_floor_pence = Column(Integer, nullable=False, default=10)
    default_duration_hours = Column(Integer, nullable=False, default=168)
    default_edit_lock_hours_before = Column(Integer, nullable=False, default=1)
    target_forum_category_id = Column(Integer, ForeignKey("forum_categories.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    __table_args__ = (
        CheckConstraint("default_reward_pool_pence BETWEEN 0 AND 100000"),
        CheckConstraint("default_participation_points BETWEEN 0 AND 1000"),
    )


class AiQuestion(Base):
    __tablename__ = "ai_questions"
    id = Column(Integer, primary_key=True)
    title = Column(String(200), nullable=False)
    content = Column(Text, nullable=False)
    topic_tag = Column(String(50))
    posed_by_expert_id = Column(String(8), ForeignKey("experts.id"), nullable=False)
    status = Column(String(20), nullable=False, default="draft")
    published_at = Column(DateTime(timezone=True))
    deadline = Column(DateTime(timezone=True))
    edit_lock_at = Column(DateTime(timezone=True))
    canceled_at = Column(DateTime(timezone=True))
    cancel_reason = Column(Text)
    settled_at = Column(DateTime(timezone=True))
    reward_pool_pence = Column(Integer, nullable=False, default=1000)
    participation_points = Column(Integer, nullable=False, default=5)
    floor_pence = Column(Integer, nullable=False, default=10)
    ai_prompt_used = Column(Text)
    target_forum_category_id = Column(Integer, ForeignKey("forum_categories.id"), nullable=False)
    cycle_config_id = Column(Integer, ForeignKey("ai_qa_cycle_configs.id"))
    created_by_admin_id = Column(String(5), ForeignKey("admin_users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    __table_args__ = (
        Index("idx_ai_questions_status", "status"),
        CheckConstraint("reward_pool_pence BETWEEN 0 AND 100000"),
        CheckConstraint("participation_points BETWEEN 0 AND 1000"),
    )


class AiQuestionCandidate(Base):
    __tablename__ = "ai_question_candidates"
    id = Column(Integer, primary_key=True)
    cycle_run_id = Column(String(36), nullable=False)
    cycle_config_id = Column(Integer, ForeignKey("ai_qa_cycle_configs.id"), nullable=False)
    title = Column(String(200), nullable=False)
    content = Column(Text, nullable=False)
    topic_tag = Column(String(50))
    ai_model_used = Column(String(80))
    chosen = Column(Boolean, default=False)
    expired_at = Column(DateTime(timezone=True))
    snapshot_reward_pool_pence = Column(Integer, nullable=False)
    snapshot_floor_pence = Column(Integer, nullable=False)
    snapshot_duration_hours = Column(Integer, nullable=False)
    snapshot_edit_lock_hours_before = Column(Integer, nullable=False)
    snapshot_participation_points = Column(Integer, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class AiAnswerScore(Base):
    __tablename__ = "ai_answer_scores"
    id = Column(Integer, primary_key=True)
    ai_question_id = Column(Integer, ForeignKey("ai_questions.id", ondelete="CASCADE"), nullable=False)
    forum_post_id = Column(Integer, nullable=False)  # 不加 FK
    user_id = Column(String(8), nullable=False)
    risk_score = Column(Integer, default=0)
    risk_reasons = Column(Text)
    ai_score = Column(Integer)
    off_topic = Column(Boolean, default=False)
    ai_generated = Column(String(10))
    ai_raw_response = Column(JSONB)
    admin_override_score = Column(Integer)
    admin_reviewer_id = Column(String(5), ForeignKey("admin_users.id"))
    admin_reviewed_at = Column(DateTime(timezone=True))
    hide_in_qa = Column(Boolean, default=False)
    final_score = Column(Integer)
    rank_final = Column(Integer)
    reward_pence = Column(Integer, default=0)
    reward_points = Column(Integer, default=0)
    settled_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    __table_args__ = (
        UniqueConstraint("ai_question_id", "forum_post_id"),
        UniqueConstraint("ai_question_id", "user_id"),
        Index("idx_ai_answer_scores_question", "ai_question_id"),
        Index("idx_ai_answer_scores_user", "user_id"),
    )


class AiQaLeaderboard(Base):
    __tablename__ = "ai_qa_leaderboard"
    id = Column(Integer, primary_key=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    total_won_pence = Column(Integer, default=0)
    win_count = Column(Integer, default=0)
    answer_count = Column(Integer, default=0)
    last_won_at = Column(DateTime(timezone=True))
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
```

- [ ] **Step 2: ForumPost 加 ai_question_id 字段**

Edit `backend/app/models.py` 找 ForumPost 类（约 line 2508），在 `last_reply_at` 之后加：

```python
    # AI 限时问答关联（绑了则该 ForumPost 是某 ai_question 的答案）
    ai_question_id = Column(Integer, ForeignKey("ai_questions.id", ondelete="SET NULL"), nullable=True)
```

并在 `__table_args__` 加 index：
```python
    Index("idx_forum_posts_ai_question_id", ai_question_id, postgresql_where=text("ai_question_id IS NOT NULL")),
```

- [ ] **Step 3: 验证 import 不报错**

Run: `cd backend && python -c "from app import models_ai_qa; print(models_ai_qa.AiQuestion.__tablename__)"`
Expected: `ai_questions`

- [ ] **Step 4: 验证 ForumPost 修改不破坏现有 model**

Run: `cd backend && python -c "from app import models; print(models.ForumPost.ai_question_id)"`
Expected: 输出 Column 对象描述。

- [ ] **Step 5: Commit**

```bash
git add backend/app/models_ai_qa.py backend/app/models.py
git commit -m "feat(ai-qa): SQLAlchemy 模型 + ForumPost.ai_question_id"
```

---

### Task 3: Pydantic Schemas

**Files:**
- Create: `backend/app/schemas_ai_qa.py`

- [ ] **Step 1: 创建 schemas 文件**

```python
# backend/app/schemas_ai_qa.py
"""AI 限时问答 Pydantic schemas — 请求/响应。"""
from datetime import datetime
from decimal import Decimal
from typing import Optional, List, Literal
from pydantic import BaseModel, Field, field_validator


# ========== Draft Admin 写 ==========
class DraftCreate(BaseModel):
    title: str = Field(..., max_length=200)
    content: str
    topic_tag: Optional[str] = Field(None, max_length=50)
    target_forum_category_id: int
    deadline: datetime
    reward_pool_pence: int = Field(1000, ge=0, le=100000)
    participation_points: int = Field(5, ge=0, le=1000)
    floor_pence: int = Field(10, ge=1, le=1000)  # 单人最低分配（新算法替代 topn_formula）
    edit_lock_hours_before: int = Field(1, ge=0, le=24)
    posed_by_expert_id: Optional[str] = None  # 不填则后端用 SystemSettings 默认


class DraftUpdate(BaseModel):
    title: Optional[str] = Field(None, max_length=200)
    content: Optional[str] = None
    topic_tag: Optional[str] = None
    target_forum_category_id: Optional[int] = None
    deadline: Optional[datetime] = None
    reward_pool_pence: Optional[int] = Field(None, ge=0, le=100000)
    participation_points: Optional[int] = Field(None, ge=0, le=1000)
    floor_pence: Optional[int] = Field(None, ge=1, le=1000)
    edit_lock_hours_before: Optional[int] = Field(None, ge=0, le=24)


# ========== AdminScoreUpdate ==========
class AdminScoreUpdate(BaseModel):
    admin_override_score: Optional[int] = Field(None, ge=0, le=100)
    hide_in_qa: Optional[bool] = None


# ========== Cancel ==========
class CancelRequest(BaseModel):
    reason: str = Field(..., min_length=1, max_length=500)


# ========== 答题 ==========
class AnswerCreate(BaseModel):
    title: Optional[str] = Field(None, max_length=200)
    content: str = Field(..., min_length=1)
    images: List[str] = Field(default_factory=list, max_length=3)


# ========== 输出 ==========
class AiQuestionOut(BaseModel):
    id: int
    title: str
    content: str
    topic_tag: Optional[str]
    status: str
    posed_by_expert_id: str
    published_at: Optional[datetime]
    deadline: Optional[datetime]
    edit_lock_at: Optional[datetime]
    canceled_at: Optional[datetime]
    settled_at: Optional[datetime]
    reward_pool_pence: int
    participation_points: int
    floor_pence: int
    target_forum_category_id: int
    created_at: datetime

    class Config:
        from_attributes = True


class AiAnswerOut(BaseModel):
    id: int
    forum_post_id: int
    user_id: str
    user_name: Optional[str] = None  # 后端 join 填
    user_avatar: Optional[str] = None
    title: Optional[str] = None
    content: Optional[str] = None
    images: Optional[List[str]] = None
    created_at: Optional[datetime] = None
    is_deleted: bool = False
    # 评分相关 (settled 后才有)
    ai_score: Optional[int] = None
    ai_generated: Optional[str] = None
    final_score: Optional[int] = None
    rank_final: Optional[int] = None
    reward_pence: int = 0
    hide_in_qa: bool = False

    class Config:
        from_attributes = True


# ========== Admin Review 表格 ==========
class AdminReviewRow(BaseModel):
    id: int  # ai_answer_scores.id
    user_id: str
    user_name: Optional[str]
    forum_post_id: int
    forum_post_created_at: datetime
    forum_post_updated_at: Optional[datetime]
    is_edited: bool  # forum_post.updated_at != created_at
    content_preview: str  # 截断 200 字
    ai_score: Optional[int]
    ai_generated: Optional[str]
    risk_score: int
    risk_reasons: Optional[str]
    admin_override_score: Optional[int]
    hide_in_qa: bool
    cash_budget_pence: int  # 前端实时算


class AdminReviewData(BaseModel):
    question: AiQuestionOut
    rows: List[AdminReviewRow]
    weekly_settled_pence: int  # S5 当周累计
    weekly_cap_pence: int


# ========== Settings ==========
class SettingUpdate(BaseModel):
    key: Literal[
        "ai_qa_weekly_settle_cap_pence",
        "ai_qa_settle_alert_threshold_pence",
        "ai_qa_default_expert_id",
    ]
    new_value: str
    confirm_token: str  # 前端给的 2 步确认 token (简单 hash 验证)
```

- [ ] **Step 2: 验证 import 不报错**

Run: `cd backend && python -c "from app.schemas_ai_qa import DraftCreate; print(DraftCreate.model_fields.keys())"`
Expected: dict_keys 含 title, content, target_forum_category_id, deadline, reward_pool_pence, participation_points, floor_pence 等

- [ ] **Step 3: 验证 floor_pence 校验生效**

Run:
```python
cd backend && python -c "
from app.schemas_ai_qa import DraftCreate
from datetime import datetime, timezone, timedelta
DraftCreate(
    title='t', content='c', target_forum_category_id=1,
    deadline=datetime.now(timezone.utc) + timedelta(days=7),
    floor_pence=1001  # 应抛 ValidationError
)
"
```
Expected: `pydantic_core._pydantic_core.ValidationError: ... floor_pence ... Input should be less than or equal to 1000`

- [ ] **Step 4: Commit**

```bash
git add backend/app/schemas_ai_qa.py
git commit -m "feat(ai-qa): Pydantic schemas (DraftCreate / AnswerCreate / AdminReviewData 等,floor_pence 单字段简化算法)"
```

---

### Task 4: CRUD 函数

**Files:**
- Create: `backend/app/crud/ai_qa.py`

- [ ] **Step 1: 创建 CRUD 模块**

```python
# backend/app/crud/ai_qa.py
"""AI 限时问答 CRUD 函数。"""
from datetime import datetime, timezone, timedelta
from typing import Optional, List
from sqlalchemy.orm import Session
from sqlalchemy import select, func, and_

from app import models
from app.models_ai_qa import (
    AiQuestion, AiQuestionCandidate, AiAnswerScore,
    AiQaLeaderboard, AiQaCycleConfig,
)
from app.schemas_ai_qa import DraftCreate, DraftUpdate


# ========== Draft / Question 写 ==========
def create_draft(db: Session, admin_id: str, payload: DraftCreate, default_expert_id: str) -> AiQuestion:
    """创建草稿。posed_by_expert_id 默认用 SystemSettings 的值。"""
    expert_id = payload.posed_by_expert_id or default_expert_id
    if not expert_id:
        raise ValueError("posed_by_expert_id required (no default set)")
    edit_lock_at = payload.deadline - timedelta(hours=payload.edit_lock_hours_before)
    q = AiQuestion(
        title=payload.title,
        content=payload.content,
        topic_tag=payload.topic_tag,
        posed_by_expert_id=expert_id,
        status="draft",
        deadline=payload.deadline,
        edit_lock_at=edit_lock_at,
        reward_pool_pence=payload.reward_pool_pence,
        participation_points=payload.participation_points,
        floor_pence=payload.floor_pence,
        target_forum_category_id=payload.target_forum_category_id,
        cycle_config_id=None,
        created_by_admin_id=admin_id,
    )
    db.add(q)
    db.flush()
    return q


def update_draft(db: Session, q: AiQuestion, payload: DraftUpdate) -> AiQuestion:
    """更新草稿。仅 status='draft' 时可调（调用方校验）。"""
    data = payload.model_dump(exclude_unset=True)
    if "deadline" in data and "edit_lock_hours_before" in data:
        data["edit_lock_at"] = data["deadline"] - timedelta(hours=data["edit_lock_hours_before"])
        del data["edit_lock_hours_before"]
    elif "deadline" in data:
        # 重算 edit_lock_at 基于原 hours_before（默认 1）
        hours = 1
        data["edit_lock_at"] = data["deadline"] - timedelta(hours=hours)
    elif "edit_lock_hours_before" in data:
        del data["edit_lock_hours_before"]
    for k, v in data.items():
        setattr(q, k, v)
    db.flush()
    return q


def publish_draft(db: Session, q: AiQuestion) -> AiQuestion:
    """draft → published。"""
    if q.status != "draft":
        raise ValueError(f"only draft can be published, got status={q.status}")
    q.status = "published"
    q.published_at = datetime.now(timezone.utc)
    db.flush()
    return q


def cancel_question(db: Session, q: AiQuestion, admin_id: str, reason: str) -> AiQuestion:
    """published → canceled。只切状态;参与积分补发由 caller 在同事务调 award_participation_points_on_cancel。

    TODO sponsor: caller 在切状态后同事务还要调 carry_over_pledges_to_pool(db, qid) (sponsor spec §4.2),
    把本题 sponsor_pool_pence + pledge_pool_carryover_pence 进全局加注池。
    """
    if q.status != "published":
        raise ValueError(f"only published can be canceled, got status={q.status}")
    q.status = "canceled"
    q.canceled_at = datetime.now(timezone.utc)
    q.cancel_reason = reason
    db.flush()
    return q


def award_participation_points_on_cancel(db: Session, qid: int) -> int:
    """canceled 时补发参与积分给所有未删答主 (spec §7 + §4.4)。

    扫 forum_posts WHERE ai_question_id=qid AND is_deleted=False,逐个 add_points_transaction。
    幂等:用 source='ai_qa_cancel_participation' + related_id=qid + reference=user_id 防重 (依赖
    points_transactions 现有去重机制;如无 UNIQUE,可用 SystemSettings flag 兜底避免双发)。
    返回补发人数。

    注意:
    - 不写 ai_qa_leaderboard (spec §4.4 末段:canceled 题不写 leaderboard,保持数据干净只反映正常 settled)
    - 调用方必须先调 cancel_question 切状态,再调本函数;失败时事务回滚,状态也回滚
    """
    from app.models import ForumPost
    from app.coupon_points_crud import add_points_transaction  # 现有积分服务

    q = db.get(AiQuestion, qid)
    if not q or q.status != "canceled":
        raise ValueError(f"question {qid} not in canceled state")

    posts = db.execute(
        select(ForumPost).where(
            and_(ForumPost.ai_question_id == qid, ForumPost.is_deleted == False)
        )
    ).scalars().all()

    count = 0
    for post in posts:
        add_points_transaction(
            db,
            user_id=post.user_id,
            type='earn',  # add_points_transaction 必填 (signature: earn/spend/refund/expire)
            amount=q.participation_points,
            source='ai_qa_cancel_participation',
            related_type='ai_question',
            related_id=qid,  # signature Optional[int],不要 str()
            description=f'AI 限时问答 #{qid} 被取消,补发参与积分',
        )
        count += 1
    db.flush()
    return count


def list_questions(
    db: Session, status: Optional[str] = None, limit: int = 50, offset: int = 0
) -> List[AiQuestion]:
    stmt = select(AiQuestion)
    if status:
        stmt = stmt.where(AiQuestion.status == status)
    stmt = stmt.order_by(AiQuestion.created_at.desc()).limit(limit).offset(offset)
    return list(db.execute(stmt).scalars())


def get_question(db: Session, qid: int) -> Optional[AiQuestion]:
    return db.get(AiQuestion, qid)


# ========== Answer (ai_answer_scores 行) 写 ==========
def create_answer_score_row(
    db: Session, ai_question_id: int, forum_post_id: int, user_id: str,
    risk_score: int, risk_reasons: Optional[str],
) -> AiAnswerScore:
    """答题时建 ai_answer_scores 行,评分阶段 UPDATE。"""
    row = AiAnswerScore(
        ai_question_id=ai_question_id,
        forum_post_id=forum_post_id,
        user_id=user_id,
        risk_score=risk_score,
        risk_reasons=risk_reasons,
    )
    db.add(row)
    db.flush()
    return row


def list_answer_scores_for_question(
    db: Session, ai_question_id: int, include_hidden: bool = False,
) -> List[AiAnswerScore]:
    stmt = select(AiAnswerScore).where(AiAnswerScore.ai_question_id == ai_question_id)
    if not include_hidden:
        stmt = stmt.where(AiAnswerScore.hide_in_qa == False)
    return list(db.execute(stmt).scalars())


def get_user_answer(db: Session, ai_question_id: int, user_id: str) -> Optional[AiAnswerScore]:
    stmt = select(AiAnswerScore).where(
        and_(AiAnswerScore.ai_question_id == ai_question_id,
             AiAnswerScore.user_id == user_id)
    )
    return db.execute(stmt).scalar_one_or_none()


def update_admin_score(
    db: Session, row: AiAnswerScore, admin_id: str,
    admin_override_score: Optional[int], hide_in_qa: Optional[bool],
) -> AiAnswerScore:
    if admin_override_score is not None:
        row.admin_override_score = admin_override_score
    if hide_in_qa is not None:
        row.hide_in_qa = hide_in_qa
    row.admin_reviewer_id = admin_id
    row.admin_reviewed_at = datetime.now(timezone.utc)
    db.flush()
    return row


# ========== Leaderboard ==========
def upsert_leaderboard(
    db: Session, user_id: str, won_pence_delta: int, won: bool,
):
    """settle 时调,更新或插入 leaderboard 行。"""
    lb = db.get(AiQaLeaderboard, {"user_id": user_id})
    if lb is None:
        lb = AiQaLeaderboard(user_id=user_id, total_won_pence=0, win_count=0, answer_count=0)
        db.add(lb)
    lb.answer_count += 1
    if won:
        lb.total_won_pence += won_pence_delta
        lb.win_count += 1
        lb.last_won_at = datetime.now(timezone.utc)
    db.flush()
    return lb


def list_leaderboard(db: Session, limit: int = 50) -> List[AiQaLeaderboard]:
    stmt = select(AiQaLeaderboard).order_by(
        AiQaLeaderboard.total_won_pence.desc()
    ).limit(limit)
    return list(db.execute(stmt).scalars())


# ========== S5 周度发奖上限 ==========
def get_weekly_settled_pence(db: Session) -> int:
    """查 7 天内累计 settled pence 总和。"""
    cutoff = datetime.now(timezone.utc) - timedelta(days=7)
    stmt = select(func.coalesce(func.sum(AiAnswerScore.reward_pence), 0)).where(
        AiAnswerScore.settled_at >= cutoff
    )
    return db.execute(stmt).scalar_one()
```

- [ ] **Step 2: 验证 import + 函数签名**

Run: `cd backend && python -c "from app.crud import ai_qa; print([f for f in dir(ai_qa) if not f.startswith('_')])"`
Expected: 输出含 create_draft / publish_draft / cancel_question / list_questions / upsert_leaderboard 等函数名

- [ ] **Step 3: Commit**

```bash
git add backend/app/crud/ai_qa.py
git commit -m "feat(ai-qa): CRUD 函数 (create_draft / publish / cancel / leaderboard upsert)"
```

---

### Task 5: 评分算法工具 + AI 评分服务

**Files:**
- Create: `backend/app/services/ai_qa_scoring.py`
- Create: `backend/tests/test_ai_qa_scoring.py`

- [ ] **Step 1: 写算法函数单元测试**

```python
# backend/tests/test_ai_qa_scoring.py
"""新算法（spec §2.1 重写后）：无 winners_count cap，全员按 final_score 比例分配，floor_pence 抹零。"""
import pytest
from app.services.ai_qa_scoring import distribute_pool


class TestDistributePool:
    def test_empty_input(self):
        assert distribute_pool([], pool_pence=1000, floor_pence=10) == []

    def test_proportional_5_answers(self):
        scored = [(1, 100), (2, 50), (3, 50)]  # total 200
        result = distribute_pool(scored, pool_pence=1000, floor_pence=10)
        # 比例: 50% / 25% / 25%
        assert result[0] == (1, 500)
        assert result[1] == (2, 250)
        assert result[2] == (3, 250)
        assert sum(r[1] for r in result) == 1000

    def test_all_answers_get_share_no_cap(self):
        # 30 人答题，pool £10 = 1000p，分数均匀 [80, 79, ..., 51]，total ≈ 1965
        scored = [(i + 1, 80 - i) for i in range(30)]  # [(1, 80), (2, 79), ..., (30, 51)]
        result = distribute_pool(scored, pool_pence=1000, floor_pence=10)
        # 所有 30 个答主都进分配，没有 winners_count cap
        assert len(result) == 30
        # 所有人 reward_pence >= floor (10p)
        for aid, amt in result:
            assert amt >= 10
        # 总额 = 池子
        assert sum(r[1] for r in result) == 1000

    def test_floor_cuts_off_low_scores(self):
        # pool=100p, 5 答主, score=[100, 1, 1, 1, 1], total=104
        scored = [(1, 100), (2, 1), (3, 1), (4, 1), (5, 1)]
        result = distribute_pool(scored, pool_pence=100, floor_pence=10)
        # raw: top1≈96p, 其余各≈1p；1p < floor 10p → 抹零
        # 抹零后 4×0=0，第1名补差: 100 - 96 = 4p 给 top1 → top1=100p
        assert result[0] == (1, 100)
        for aid, amt in result[1:]:
            assert amt == 0

    def test_all_zero_scores(self):
        scored = [(1, 0), (2, 0)]
        result = distribute_pool(scored, pool_pence=1000, floor_pence=10)
        # 全 0 分，每人 0
        assert result == [(1, 0), (2, 0)]

    def test_round_diff_to_first(self):
        # round() 可能丢精度，差额自动加到第 1 名
        scored = [(1, 33), (2, 33), (3, 34)]
        result = distribute_pool(scored, pool_pence=100, floor_pence=1)
        # 必须满总额
        assert sum(r[1] for r in result) == 100

    def test_pool_larger_than_total_score(self):
        # 大 pool（含 sponsor 加注）让所有人都能拿到钱
        scored = [(1, 90), (2, 80), (3, 70), (4, 60), (5, 50)]  # total 350
        result = distribute_pool(scored, pool_pence=5500, floor_pence=10)  # £55 (含加注)
        # 比例: 90/350=25.7%, 80/350=22.9%, ...
        # 5 人都远高于 floor
        for aid, amt in result:
            assert amt >= 10
        assert sum(r[1] for r in result) == 5500
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd backend && pytest tests/test_ai_qa_scoring.py -v`
Expected: ImportError: cannot import name 'distribute_pool'

- [ ] **Step 3: 实现算法函数 + AI 评分服务**

```python
# backend/app/services/ai_qa_scoring.py
"""AI 限时问答 — 评分算法工具 + AI 评分服务。"""
import json
import logging
from typing import List, Tuple, Optional
from anthropic import Anthropic

from app.config import Config  # 注意:Config 是 class,无顶层 settings 变量;访问用 Config.XXX

logger = logging.getLogger(__name__)


# ========== 奖金分配算法 (spec §2.1 重写后) ==========
# 无 winners_count cap;所有 hide_in_qa=False 的答主都进分配;
# 按 final_score 比例分;低于 floor_pence (默认 10p) 抹零;差额给第 1 名
def distribute_pool(
    scored_answers: List[Tuple[int, int]],  # [(answer_id, final_score)] 已按分降序
    pool_pence: int,
    floor_pence: int,
) -> List[Tuple[int, int]]:
    """返回 [(answer_id, reward_pence)]，长度 = len(scored_answers)。"""
    if not scored_answers:
        return []
    total_score = sum(s for _, s in scored_answers)
    if total_score == 0:
        return [(aid, 0) for aid, _ in scored_answers]
    raw = [(aid, round(pool_pence * s / total_score)) for aid, s in scored_answers]
    # 抹零：低于 floor_pence 归零
    cleaned = [(aid, amt if amt >= floor_pence else 0) for aid, amt in raw]
    # 误差修正：差额加到第 1 名
    diff = pool_pence - sum(a for _, a in cleaned)
    if cleaned:
        first_aid, first_amt = cleaned[0]
        cleaned[0] = (first_aid, first_amt + diff)
    return cleaned


# ========== AI 评分服务 ==========
SCORING_PROMPT_TEMPLATE = """你是问答评分员。给每条答案打分,只输出 JSON 数组:
[{{"id": <answer_id>, "score": 0-100, "off_topic": bool, "ai_generated": "low|medium|high"}}]

评分维度（按权重）:
- 切题度（核心）: 偏题严重 score ≤ 30 且 off_topic=true
- 真人感: 明显 AI 味重 ai_generated="high",可疑"medium",自然"low"
- 内容质量: 信息量、表达、独特性

题目: {question}

答案列表:
{answers}
"""


def score_answers_batch(
    question_title: str, question_content: str,
    answers: List[dict],  # [{"id": int, "content": str}, ...]
) -> List[dict]:
    """调 Claude Sonnet 4.5 批量打分。返回 [{"id", "score", "off_topic", "ai_generated"}, ...]。"""
    client = Anthropic(api_key=Config.ANTHROPIC_API_KEY)
    prompt = SCORING_PROMPT_TEMPLATE.format(
        question=f"{question_title}\n\n{question_content}",
        answers=json.dumps(answers, ensure_ascii=False),
    )
    resp = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=4096,
        messages=[{"role": "user", "content": prompt}],
    )
    raw = resp.content[0].text.strip()
    # 容错: 去 ```json fence
    if raw.startswith("```"):
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as e:
        logger.error(f"AI scoring JSON parse failed: {e}, raw={raw[:500]}")
        raise
    return parsed


def score_all_answers(
    question_title: str, question_content: str,
    answers: List[dict],  # [{"id": int, "content": str}, ...]
    batch_size: int = 10,
) -> List[dict]:
    """分批送 AI 评分, 拼成完整结果。"""
    results = []
    for i in range(0, len(answers), batch_size):
        batch = answers[i:i + batch_size]
        batch_result = score_answers_batch(question_title, question_content, batch)
        results.extend(batch_result)
    return results
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd backend && pytest tests/test_ai_qa_scoring.py -v`
Expected: 所有 test 通过

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/ai_qa_scoring.py backend/tests/test_ai_qa_scoring.py
git commit -m "feat(ai-qa): 奖金分配算法 distribute_pool (全员按比例 + floor 抹零,无 winners cap) + AI 评分服务"
```

---

### Task 6: settle 事务服务

**Files:**
- Create: `backend/app/services/ai_qa_settle.py`

- [ ] **Step 1: 实现 settle 事务**

```python
# backend/app/services/ai_qa_settle.py
"""AI 限时问答 — settle 事务服务。
S1 行锁 + S3 audit + S5 周度上限 + S6 邮件 + wallet credit。"""
from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional, List, Tuple
import logging
from sqlalchemy import select
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from app.models_ai_qa import AiQuestion, AiAnswerScore
from app.crud import ai_qa as ai_qa_crud
from app.services.ai_qa_scoring import distribute_pool
from app.wallet_service import lock_wallet, credit_wallet
from app.crud.audit import create_audit_log
from app.crud import get_system_setting, add_points_transaction
from app import models
from app.email_utils import send_email
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)


class SettleError(Exception):
    """业务错误（如周度上限、状态非法）。"""
    pass


def settle_question(db: Session, qid: int, admin_id: str) -> dict:
    """
    执行 settle 事务。返回 {total_settled_pence, winner_count, top1_user_id}。
    失败抛 SettleError 或 Exception；调用方负责把 status 切到 settle_failed。
    """
    # === S1 行锁 + 状态二次校验 ===
    q = db.execute(
        select(AiQuestion).where(AiQuestion.id == qid).with_for_update()
    ).scalar_one_or_none()
    if q is None:
        raise SettleError(f"question {qid} not found")
    if q.status not in ("scored", "settle_failed"):
        raise SettleError(f"settle requires status in (scored, settle_failed), got {q.status}")

    # === S5 周度上限校验 ===
    cap_setting = get_system_setting(db, "ai_qa_weekly_settle_cap_pence")
    cap_pence = int(cap_setting.setting_value) if cap_setting else 20000
    weekly_pence = ai_qa_crud.get_weekly_settled_pence(db)
    if weekly_pence + q.reward_pool_pence > cap_pence:
        raise SettleError(
            f"weekly settle cap exceeded: already £{weekly_pence/100:.2f}, "
            f"plus £{q.reward_pool_pence/100:.2f} > cap £{cap_pence/100:.2f}"
        )

    # === 拉所有 active answer score 行（hide_in_qa=False）===
    rows = ai_qa_crud.list_answer_scores_for_question(db, qid, include_hidden=False)
    # 计算 final_score
    for r in rows:
        if r.hide_in_qa:
            r.final_score = 0
        elif r.admin_override_score is not None:
            r.final_score = r.admin_override_score
        else:
            r.final_score = r.ai_score or 0
    # 按分降序
    rows.sort(key=lambda r: r.final_score, reverse=True)

    # === 算 winner + 分钱 ===
    scored_tuples = [(r.id, r.final_score) for r in rows]
    distribution = distribute_pool(
        scored_tuples,
        pool_pence=q.reward_pool_pence,
        floor_pence=q.floor_pence,
    )
    distribution_map = dict(distribution)

    # === 写 rank_final + reward_pence + settled_at ===
    settled_at = datetime.now(timezone.utc)
    top1_user_id = None
    top1_forum_post_id = None
    total_settled_pence = 0
    for i, r in enumerate(rows):
        r.rank_final = i + 1
        r.reward_pence = distribution_map.get(r.id, 0)
        r.reward_points = q.participation_points  # 所有未 hide 答主都拿
        r.settled_at = settled_at
        if r.rank_final == 1:
            top1_user_id = r.user_id
            top1_forum_post_id = r.forum_post_id
        total_settled_pence += r.reward_pence

    # === wallet credit (每个答案被采纳的用户) ===
    for r in rows:
        if r.reward_pence <= 0:
            continue
        lock_wallet(db, r.user_id, currency="GBP")  # 行锁
        tx = credit_wallet(
            db,
            user_id=r.user_id,
            amount=Decimal(r.reward_pence) / 100,
            currency="GBP",
            source="ai_qa_reward",
            related_type="ai_question",
            related_id=str(qid),
            idempotency_key=f"ai_qa_settle_{qid}_{r.user_id}",
            description=f"AI 限时问答 #{qid} 第 {r.rank_final} 名奖金",
        )
        # wallet_service.credit_wallet 幂等冲突时返回 None (不抛 IntegrityError,
        # 见 wallet_service.py:156-158);这里检查 None 视为"已入账,跳过":
        if tx is None:
            # idempotency_key 命中已存在的 transaction — 该 user 已发过,跳过(重试场景)
            logger.info(f"settle ai_qa #{qid} user {r.user_id}: wallet credit skipped (idempotent)")
            continue
        # 真正的事务错误 (lock 超时 / DB 故障 / 余额异常) 由 credit_wallet raise,
        # 冒泡到外层 settle_question try/except → status=settle_failed

    # === add_points_transaction (所有未 hide 答主,含答案未被采纳的) ===
    for r in rows:
        add_points_transaction(
            db,
            user_id=r.user_id,
            amount=r.reward_points,
            type="earn",
            source="ai_qa_participation",
            related_id=qid,
        )

    # === leaderboard upsert ===
    for r in rows:
        ai_qa_crud.upsert_leaderboard(
            db,
            user_id=r.user_id,
            won_pence_delta=r.reward_pence,
            won=(r.reward_pence > 0),
        )

    # === L3.b ForumPost.is_featured ===
    if top1_forum_post_id:
        fp = db.get(models.ForumPost, top1_forum_post_id)
        if fp:
            fp.is_featured = True

    # === 切 status ===
    q.status = "settled"
    q.settled_at = settled_at

    # === S3 审计 ===
    # ⚠️ create_audit_log 函数内部自带 db.commit() (crud/audit.py:34) —
    # 该调用会一次性 commit 上面 lock+wallet credit+leaderboard+is_featured+status 切换的全部写入。
    # 这是隐式的事务边界,plan 接受此现状不动 audit_log 函数。
    # 任一前置写入失败 → 不会走到这里 (异常冒泡) → 外层路由 try/except 回滚到 settle_failed。
    # 后续 db.flush() / 路由层 db.commit() 都是 no-op。
    create_audit_log(
        db,
        action_type="ai_qa_settle",
        entity_type="ai_question",
        entity_id=str(qid),
        admin_id=admin_id,
        new_value={
            "total_settled_pence": total_settled_pence,
            "winner_count": sum(1 for r in rows if r.reward_pence > 0),
            "top1_user_id": top1_user_id,
        },
        reason=f"settle ai_question #{qid}",
    )

    db.flush()  # no-op (audit_log 内部 commit 已 flush 了全部);保留是为可读性
    return {
        "total_settled_pence": total_settled_pence,
        "winner_count": sum(1 for r in rows if r.reward_pence > 0),
        "top1_user_id": top1_user_id,
    }


def maybe_send_s6_alert(db: Session, qid: int, admin_id: str):
    """事务外异步调（事务 commit 后）。周累计 ≥ 阈值发 email。"""
    threshold = get_system_setting(db, "ai_qa_settle_alert_threshold_pence")
    threshold_pence = int(threshold.setting_value) if threshold else 10000
    weekly = ai_qa_crud.get_weekly_settled_pence(db)
    if weekly < threshold_pence:
        return
    # 拉所有 admin email
    admin_emails = [
        a.email for a in db.execute(
            select(models.AdminUser).where(models.AdminUser.is_active == True)
        ).scalars() if a.email
    ]
    if not admin_emails:
        return
    subject = "[Link2Ur] AI 限时问答周度发奖触达阈值"
    body = (
        f"本周 AI 限时问答累计已 settled £{weekly/100:.2f}（阈值 £{threshold_pence/100:.2f}）。\n"
        f"· 本次触发：题目 #{qid}\n"
        f"· 操作 admin：{admin_id}\n"
        f"· 时间：{get_utc_time().isoformat()}\n"
        f"· 若非预期，立即检查 audit log + admin 账号被陷可能。"
    )
    for email in admin_emails:
        try:
            send_email(to_email=email, subject=subject, body=body)  # 注意:to_email 不是 to (email_utils.py:183 signature)
        except Exception as e:
            logger.error(f"S6 email send failed to {email}: {e}")
```

- [ ] **Step 2: 验证 import 不报错（依赖的模块都存在）**

Run: `cd backend && python -c "from app.services.ai_qa_settle import settle_question, SettleError; print('ok')"`
Expected: `ok`

- [ ] **Step 3: Commit**

```bash
git add backend/app/services/ai_qa_settle.py
git commit -m "feat(ai-qa): settle 事务服务 (S1 行锁 + S3 audit + S5 cap + S6 邮件 + wallet credit)"
```

---

### Task 7: 用户端路由

**Files:**
- Create: `backend/app/ai_qa_user_routes.py`
- Modify: `backend/app/main.py` (include router)

- [ ] **Step 1: 实现用户端路由**

```python
# backend/app/ai_qa_user_routes.py
"""AI 限时问答 — 用户端路由 /api/ai-qa/*"""
from datetime import datetime, timezone
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app import models
from app.deps import get_db, get_current_user_secure_sync_csrf
from app.models_ai_qa import AiQuestion, AiAnswerScore
from app.schemas_ai_qa import AiQuestionOut, AiAnswerOut, AnswerCreate
from app.crud import ai_qa as ai_qa_crud
from app.crud import forum as forum_crud  # 现有论坛 CRUD
from app.risk_control import check_risk
from app.device_fingerprint import generate_device_fingerprint, get_ip_address

router = APIRouter(prefix="/api/ai-qa", tags=["AI Limited QA"])


@router.get("", response_model=List[AiQuestionOut])
def list_questions(
    status: Optional[str] = None,
    limit: int = 20,
    offset: int = 0,
    db: Session = Depends(get_db),
):
    """用户端列表（当期 + 历史）。无权限校验。"""
    qs = ai_qa_crud.list_questions(db, status=status, limit=limit, offset=offset)
    return qs


@router.get("/leaderboard")
def get_leaderboard(limit: int = 50, db: Session = Depends(get_db)):
    """P0 写入数据,P2 前端入口才上;端点 P0 可访问。"""
    lb = ai_qa_crud.list_leaderboard(db, limit=limit)
    return [
        {
            "user_id": item.user_id,
            "total_won_pence": item.total_won_pence,
            "win_count": item.win_count,
            "answer_count": item.answer_count,
            "last_won_at": item.last_won_at.isoformat() if item.last_won_at else None,
        }
        for item in lb
    ]


@router.get("/{qid}", response_model=AiQuestionOut)
def get_question(qid: int, db: Session = Depends(get_db)):
    q = ai_qa_crud.get_question(db, qid)
    if q is None or q.status == "draft":
        raise HTTPException(404, "ai_qa_not_found")
    return q


@router.get("/{qid}/answers", response_model=List[AiAnswerOut])
def list_answers(qid: int, db: Session = Depends(get_db)):
    """答案列表。published 期间显示所有人答案；settled 后含 reward。"""
    q = ai_qa_crud.get_question(db, qid)
    if q is None or q.status == "draft":
        raise HTTPException(404, "ai_qa_not_found")
    rows = ai_qa_crud.list_answer_scores_for_question(db, qid, include_hidden=False)
    if not rows:
        return []
    forum_post_ids = [r.forum_post_id for r in rows]
    posts = {
        p.id: p for p in db.query(models.ForumPost).filter(models.ForumPost.id.in_(forum_post_ids))
    }
    users = {
        u.id: u for u in db.query(models.User).filter(models.User.id.in_([r.user_id for r in rows]))
    }
    out = []
    for r in rows:
        post = posts.get(r.forum_post_id)
        user = users.get(r.user_id)
        out.append(AiAnswerOut(
            id=r.id,
            forum_post_id=r.forum_post_id,
            user_id=r.user_id,
            user_name=user.name if user else None,
            user_avatar=user.avatar_url if user else None,
            title=post.title if post and not post.is_deleted else None,
            content=post.content if post and not post.is_deleted else None,
            images=post.images if post and not post.is_deleted else None,
            created_at=post.created_at if post else None,
            is_deleted=bool(post.is_deleted) if post else True,
            ai_score=r.ai_score,
            ai_generated=r.ai_generated,
            final_score=r.final_score,
            rank_final=r.rank_final,
            reward_pence=r.reward_pence,
            hide_in_qa=r.hide_in_qa,
        ))
    # settled 后按 rank_final 升序;否则按 created_at 倒序
    if q.status == "settled":
        out.sort(key=lambda a: (a.rank_final or 999, a.id))
    else:
        out.sort(key=lambda a: a.created_at or datetime.min, reverse=True)
    return out


@router.post("/{qid}/answer")
def submit_answer(
    qid: int,
    payload: AnswerCreate,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """答题端点 (spec §4.2 校验顺序 1-8)。"""
    q = ai_qa_crud.get_question(db, qid)
    if q is None:
        raise HTTPException(404, "ai_qa_not_found")
    if q.status != "published":
        raise HTTPException(409, f"ai_qa_status_not_published")
    now = datetime.now(timezone.utc)
    if q.deadline and now >= q.deadline:
        raise HTTPException(409, "ai_qa_deadline_passed")
    if q.edit_lock_at and now >= q.edit_lock_at:
        raise HTTPException(409, "ai_qa_edit_locked")
    # 重复答 (DB UNIQUE 兜底, 这里先查避免反复 insert 失败)
    if ai_qa_crud.get_user_answer(db, qid, current_user.id):
        raise HTTPException(409, "ai_qa_already_answered")
    # 风控
    device_fp = generate_device_fingerprint(request=request)
    ip = get_ip_address(request)
    allowed, reason, risk_score = check_risk(
        db, user_id=current_user.id, action_type="ai_qa_answer",
        device_fingerprint=device_fp, ip_address=ip,
    )
    if not allowed:
        raise HTTPException(403, f"ai_qa_blocked_by_risk: {reason}")
    # 事务: 建 ForumPost + ai_answer_scores 行
    post = forum_crud.create_post(
        db,
        author_id=current_user.id,
        category_id=q.target_forum_category_id,
        title=payload.title or q.title[:200],
        content=payload.content,
        images=payload.images,
        ai_question_id=qid,
    )
    ai_qa_crud.create_answer_score_row(
        db,
        ai_question_id=qid,
        forum_post_id=post.id,
        user_id=current_user.id,
        risk_score=risk_score or 0,
        risk_reasons=reason,
    )
    db.commit()
    return {"forum_post_id": post.id, "ai_question_id": qid}
```

- [ ] **Step 2: 注册 router 到 main.py**

Edit `backend/app/main.py`，在其他 router include 附近加：
```python
from app.ai_qa_user_routes import router as ai_qa_user_router
app.include_router(ai_qa_user_router)
```

- [ ] **Step 3: 验证 import + 端点出现在 OpenAPI**

Run: `cd backend && python -c "from app.main import app; print([r.path for r in app.routes if 'ai-qa' in r.path])"`
Expected: 输出含 `/api/ai-qa`, `/api/ai-qa/{qid}`, `/api/ai-qa/{qid}/answers`, `/api/ai-qa/{qid}/answer`, `/api/ai-qa/leaderboard`

- [ ] **Step 4: Commit**

```bash
git add backend/app/ai_qa_user_routes.py backend/app/main.py
git commit -m "feat(ai-qa): 用户端路由 (list / detail / answers / submit / leaderboard)"
```

---

### Task 8: Admin 端路由

**Files:**
- Create: `backend/app/ai_qa_admin_routes.py`
- Modify: `backend/app/main.py` (include 第二个 router)

- [ ] **Step 1: 实现 admin 端路由**

```python
# backend/app/ai_qa_admin_routes.py
"""AI 限时问答 — Admin 端路由 /api/admin/ai-qa/*"""
from datetime import datetime, timezone, timedelta
from typing import Optional, List
import logging
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session

from app import models
from app.deps import get_db
from app.separate_auth_deps import get_current_admin  # 现有 admin auth (在 separate_auth_deps.py:20,不是 separate_auth)
from app.models_ai_qa import AiQuestion, AiAnswerScore
from app.schemas_ai_qa import (
    DraftCreate, DraftUpdate, AdminScoreUpdate, CancelRequest,
    SettingUpdate, AdminReviewData, AdminReviewRow, AiQuestionOut,
)
from app.crud import ai_qa as ai_qa_crud
from app.crud.system import get_system_setting, update_system_setting  # 注意:函数名是 update_ 不是 set_
from app.coupon_points_crud import add_points_transaction  # 积分入口在 coupon_points_crud,不在 crud.points
from app.crud.audit import create_audit_log
from app.services.ai_qa_settle import settle_question, maybe_send_s6_alert, SettleError

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin/ai-qa", tags=["Admin · AI Limited QA"])


def _audit(db, action, qid_or_score_id, admin_id, old=None, new=None, reason=None):
    create_audit_log(
        db, action_type=f"ai_qa_{action}", entity_type="ai_question",
        entity_id=str(qid_or_score_id), admin_id=admin_id,
        old_value=old, new_value=new, reason=reason,
    )


# ========== Drafts ==========
@router.post("/drafts", response_model=AiQuestionOut)
def create_draft(
    payload: DraftCreate,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    default_expert = get_system_setting(db, "ai_qa_default_expert_id")
    default_expert_id = (default_expert.setting_value if default_expert else "") or None
    try:
        q = ai_qa_crud.create_draft(db, admin.id, payload, default_expert_id)
    except ValueError as e:
        raise HTTPException(400, str(e))
    _audit(db, "draft_create", q.id, admin.id, new={"title": q.title, "reward_pool_pence": q.reward_pool_pence})
    db.commit()
    return q


@router.patch("/drafts/{qid}", response_model=AiQuestionOut)
def update_draft(
    qid: int, payload: DraftUpdate,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    q = ai_qa_crud.get_question(db, qid)
    if q is None:
        raise HTTPException(404, "ai_qa_not_found")
    if q.status != "draft":
        raise HTTPException(409, "ai_qa_only_draft_editable")
    old = {"title": q.title, "reward_pool_pence": q.reward_pool_pence}
    ai_qa_crud.update_draft(db, q, payload)
    _audit(db, "draft_update", qid, admin.id, old=old, new={"title": q.title, "reward_pool_pence": q.reward_pool_pence})
    db.commit()
    return q


@router.delete("/drafts/{qid}", status_code=204)
def delete_draft(
    qid: int,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    q = ai_qa_crud.get_question(db, qid)
    if q is None:
        raise HTTPException(404, "ai_qa_not_found")
    if q.status != "draft":
        raise HTTPException(409, "ai_qa_only_draft_deletable")
    _audit(db, "draft_delete", qid, admin.id, old={"title": q.title})
    db.delete(q)
    db.commit()
    return None


@router.post("/drafts/{qid}/publish", response_model=AiQuestionOut)
def publish_draft(
    qid: int,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    q = ai_qa_crud.get_question(db, qid)
    if q is None:
        raise HTTPException(404, "ai_qa_not_found")
    try:
        ai_qa_crud.publish_draft(db, q)
    except ValueError as e:
        raise HTTPException(409, str(e))
    _audit(db, "publish", qid, admin.id, new={"status": "published"})
    db.commit()
    # TODO: 全站通知 "新一期问答开放"（接现有通知 service）
    return q


# ========== Questions 管理 ==========
@router.get("/questions", response_model=List[AiQuestionOut])
def list_questions(
    status: Optional[str] = None,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    return ai_qa_crud.list_questions(db, status=status, limit=200)


@router.post("/questions/{qid}/cancel", response_model=AiQuestionOut)
def cancel_question(
    qid: int, payload: CancelRequest,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    Admin 撤稿。同事务保证:
      1. cancel_question 切状态 (published → canceled)
      2. award_participation_points_on_cancel 给所有未删答主补 participation_points (spec §7)
      3. 单独 audit log (action_type='ai_qa_cancel' + reason)

    任一步异常 → 整事务回滚,status 不变,积分不发,确保一致。

    TODO sponsor (上线时同事务追加):
      - ai_qa_sponsor.carry_over_pledges_to_pool(db, qid)  # sponsor spec §4.2
        把本题 sponsor_pool_pence + pledge_pool_carryover_pence 进全局加注池
    """
    q = ai_qa_crud.get_question(db, qid)
    if q is None:
        raise HTTPException(404, "ai_qa_not_found")
    try:
        ai_qa_crud.cancel_question(db, q, admin.id, payload.reason)
        # 同事务补发参与积分 (helper 内部扫 forum_posts 而非 ai_answer_scores,
        # 兼容用户绕过 /api/ai-qa/{id}/answer 入口直接塞 ai_question_id 进论坛的边缘 case)
        awarded_count = ai_qa_crud.award_participation_points_on_cancel(db, qid)
    except ValueError as e:
        raise HTTPException(409, str(e))
    _audit(
        db, "cancel", qid, admin.id,
        old={"status": "published"},
        new={"status": "canceled", "reason": payload.reason, "participation_awarded_count": awarded_count},
    )
    db.commit()
    # TODO: 全站通知 "本期问答已取消" (含已答用户的私推)
    return q


# ========== Review (终审表格) ==========
@router.get("/questions/{qid}/review", response_model=AdminReviewData)
def get_review_data(
    qid: int,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    q = ai_qa_crud.get_question(db, qid)
    if q is None:
        raise HTTPException(404, "ai_qa_not_found")
    rows = ai_qa_crud.list_answer_scores_for_question(db, qid, include_hidden=True)
    forum_post_ids = [r.forum_post_id for r in rows]
    posts = {p.id: p for p in db.query(models.ForumPost).filter(models.ForumPost.id.in_(forum_post_ids))}
    users = {u.id: u for u in db.query(models.User).filter(models.User.id.in_([r.user_id for r in rows]))}
    # 实时算预算 (本期已确认的)
    cap_setting = get_system_setting(db, "ai_qa_weekly_settle_cap_pence")
    cap_pence = int(cap_setting.setting_value) if cap_setting else 20000
    weekly_pence = ai_qa_crud.get_weekly_settled_pence(db)
    review_rows = []
    for r in rows:
        post = posts.get(r.forum_post_id)
        user = users.get(r.user_id)
        review_rows.append(AdminReviewRow(
            id=r.id, user_id=r.user_id, user_name=user.name if user else None,
            forum_post_id=r.forum_post_id,
            forum_post_created_at=post.created_at if post else datetime.min,
            forum_post_updated_at=post.updated_at if post else None,
            is_edited=bool(post and post.updated_at and post.updated_at != post.created_at),
            content_preview=(post.content[:200] if post and post.content else ""),
            ai_score=r.ai_score, ai_generated=r.ai_generated,
            risk_score=r.risk_score, risk_reasons=r.risk_reasons,
            admin_override_score=r.admin_override_score, hide_in_qa=r.hide_in_qa,
            cash_budget_pence=0,  # 前端实时算
        ))
    return AdminReviewData(
        question=q, rows=review_rows,
        weekly_settled_pence=weekly_pence,
        weekly_cap_pence=cap_pence,
    )


@router.patch("/scores/{score_id}")
def update_score(
    score_id: int, payload: AdminScoreUpdate,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    row = db.get(AiAnswerScore, score_id)
    if row is None:
        raise HTTPException(404, "ai_qa_score_not_found")
    if payload.admin_override_score is not None and not (0 <= payload.admin_override_score <= 100):
        raise HTTPException(422, "ai_qa_score_out_of_range")
    old = {"admin_override_score": row.admin_override_score, "hide_in_qa": row.hide_in_qa}
    ai_qa_crud.update_admin_score(db, row, admin.id, payload.admin_override_score, payload.hide_in_qa)
    _audit(db, "score_update", row.ai_question_id, admin.id, old=old,
           new={"admin_override_score": row.admin_override_score, "hide_in_qa": row.hide_in_qa},
           reason=f"score_id={score_id}")
    db.commit()
    return {"ok": True}


@router.post("/questions/{qid}/rescore")
def rescore(
    qid: int,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    q = ai_qa_crud.get_question(db, qid)
    if q is None:
        raise HTTPException(404, "ai_qa_not_found")
    if q.status != "scoring_failed":
        raise HTTPException(409, "ai_qa_rescore_requires_scoring_failed")
    q.status = "scoring"
    _audit(db, "rescore", qid, admin.id, new={"status": "scoring"})
    db.commit()
    # 异步触发评分 (复用 scheduled_tasks 的逻辑,见 Task 10)
    # prod 用 Celery 异步，linktest 无 Celery 时退化为同步
    try:
        from app.scheduled_tasks import celery_score_single_ai_question
        celery_score_single_ai_question.delay(qid)
    except (ImportError, AttributeError):
        from app.scheduled_tasks import score_single_ai_question
        score_single_ai_question(qid)
    return {"ok": True}


# ========== Settle ==========
@router.post("/questions/{qid}/settle")
def settle(
    qid: int,
    background: BackgroundTasks,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    try:
        result = settle_question(db, qid, admin.id)
    except SettleError as e:
        msg = str(e)
        # 失败 → 切 settle_failed (事务外的状态写)
        q = ai_qa_crud.get_question(db, qid)
        if q and q.status == "scored":
            q.status = "settle_failed"
            _audit(db, "settle_failed", qid, admin.id, reason=msg)
            db.commit()
        raise HTTPException(409, msg)
    except Exception as e:
        logger.exception(f"settle qid={qid} unexpected error")
        q = ai_qa_crud.get_question(db, qid)
        if q:
            q.status = "settle_failed"
            db.commit()
        _audit(db, "settle_failed", qid, admin.id, reason=str(e))
        db.commit()
        raise HTTPException(500, "ai_qa_settle_failed")
    db.commit()
    # 事务外 S6 邮件
    background.add_task(maybe_send_s6_alert, db, qid, admin.id)
    return result


# ========== Settings ==========
@router.post("/settings")
def update_settings(
    payload: SettingUpdate,
    admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    # 2 步确认 token 校验（简化版：要求 confirm_token == sha256(key + new_value)[:8]）
    import hashlib
    expected = hashlib.sha256(f"{payload.key}:{payload.new_value}".encode()).hexdigest()[:8]
    if payload.confirm_token != expected:
        raise HTTPException(400, "ai_qa_settings_confirm_token_invalid")
    old = get_system_setting(db, payload.key)
    old_val = old.setting_value if old else None  # get_system_setting 返回 SystemSettings 对象,需取 .setting_value
    update_system_setting(db, payload.key, payload.new_value)
    _audit(db, "settings_update", payload.key, admin.id, old={payload.key: old_val}, new={payload.key: payload.new_value})
    db.commit()
    return {"ok": True}
```

- [ ] **Step 2: 注册 admin router 到 main.py**

```python
from app.ai_qa_admin_routes import router as ai_qa_admin_router
app.include_router(ai_qa_admin_router)
```

- [ ] **Step 3: 验证端点出现**

Run: `cd backend && python -c "from app.main import app; print([r.path for r in app.routes if '/admin/ai-qa' in r.path])"`
Expected: 输出 11 个端点（drafts CRUD + publish + questions list + cancel + review + scores update + rescore + settle + settings）

- [ ] **Step 4: Commit**

```bash
git add backend/app/ai_qa_admin_routes.py backend/app/main.py
git commit -m "feat(ai-qa): admin 端路由 (drafts/cancel/review/scores/settle/settings)"
```

---

### Task 9: 答题事务支持（论坛 CRUD 加 ai_question_id）

**Files:**
- Modify: `backend/app/crud/forum.py` (or wherever `create_post` lives)

- [ ] **Step 1: 找到现有 create_post 函数**

Run: `cd backend && grep -rn "def create_post" app/crud/ app/forum_routes.py | head -5`

- [ ] **Step 2: 改 create_post 接受 ai_question_id 参数**

加 keyword argument `ai_question_id: Optional[int] = None`，在 ForumPost 创建时透传：

```python
def create_post(db, author_id, category_id, title, content, images=None, ai_question_id=None, ...):
    post = models.ForumPost(
        author_id=author_id,
        category_id=category_id,
        title=title,
        content=content,
        images=images,
        ai_question_id=ai_question_id,  # 新增
        ...
    )
    db.add(post)
    db.flush()
    return post
```

- [ ] **Step 3: 验证现有 forum 端点不破坏**

Run: `cd backend && pytest tests/test_forum* -v 2>&1 | tail -10`
Expected: 现有论坛测试全过

- [ ] **Step 4: Commit**

```bash
git add backend/app/crud/forum.py  # 或实际改的文件
git commit -m "feat(ai-qa): forum.create_post 加 ai_question_id 参数,支持 AI 限时问答答案绑定"
```

---

### Task 10: scheduled_tasks beat (deadline 扫描 + 评分管道)

**Files:**
- Modify: `backend/app/scheduled_tasks.py`

- [ ] **Step 1: 加 deadline 扫描函数**

在 `scheduled_tasks.py` 找一处合适位置加：

```python
def close_expired_ai_questions():
    """beat: 扫 status=published & deadline < now,切到 closed 或 closed_empty。"""
    from app.models_ai_qa import AiQuestion, AiAnswerScore
    from app.deps import get_db_sync
    from sqlalchemy import select, func
    db = next(get_db_sync())
    try:
        now = datetime.now(timezone.utc)
        questions = db.execute(
            select(AiQuestion).where(
                AiQuestion.status == "published",
                AiQuestion.deadline < now,
            )
        ).scalars().all()
        for q in questions:
            # 数 active answer (forum_post 没被删的)
            count = db.execute(
                select(func.count(AiAnswerScore.id))
                .join(models.ForumPost, AiAnswerScore.forum_post_id == models.ForumPost.id)
                .where(
                    AiAnswerScore.ai_question_id == q.id,
                    AiAnswerScore.hide_in_qa == False,
                    models.ForumPost.is_deleted == False,
                )
            ).scalar() or 0
            if count == 0:
                q.status = "closed_empty"
            else:
                q.status = "closed"
            db.commit()
            logger.info(f"ai_qa: closed question #{q.id}, answer_count={count}, new_status={q.status}")
    finally:
        db.close()


def score_closed_ai_questions():
    """beat: 扫 status=closed,跑 AI 评分,切到 scored 或 scoring_failed。"""
    from app.models_ai_qa import AiQuestion, AiAnswerScore
    from app.services.ai_qa_scoring import score_all_answers
    from app.deps import get_db_sync
    from sqlalchemy import select
    db = next(get_db_sync())
    try:
        questions = db.execute(
            select(AiQuestion).where(AiQuestion.status == "closed")
        ).scalars().all()
        for q in questions:
            score_single_ai_question(q.id)
    finally:
        db.close()


def score_single_ai_question(qid: int):
    """单题评分（rescore 也调这个）。"""
    from app.models_ai_qa import AiQuestion, AiAnswerScore
    from app.services.ai_qa_scoring import score_all_answers
    from app.deps import get_db_sync
    from sqlalchemy import select
    db = next(get_db_sync())
    try:
        q = db.get(AiQuestion, qid)
        if q is None or q.status not in ("closed", "scoring"):
            return
        q.status = "scoring"
        db.commit()
        # 拉所有 active answer
        rows = db.execute(
            select(AiAnswerScore)
            .where(AiAnswerScore.ai_question_id == qid, AiAnswerScore.hide_in_qa == False)
        ).scalars().all()
        forum_post_ids = [r.forum_post_id for r in rows]
        posts = {p.id: p for p in db.query(models.ForumPost).filter(models.ForumPost.id.in_(forum_post_ids))}
        # 过滤已删的（双保险）
        valid_rows = [r for r in rows if posts.get(r.forum_post_id) and not posts[r.forum_post_id].is_deleted]
        if not valid_rows:
            q.status = "closed_empty"
            db.commit()
            return
        answers_payload = [
            {"id": r.id, "content": posts[r.forum_post_id].content}
            for r in valid_rows
        ]
        try:
            scored = score_all_answers(q.title, q.content, answers_payload, batch_size=10)
        except Exception as e:
            logger.exception(f"ai_qa scoring failed qid={qid}")
            q.status = "scoring_failed"
            db.commit()
            return
        # UPDATE ai_answer_scores
        score_map = {s["id"]: s for s in scored}
        for r in valid_rows:
            s = score_map.get(r.id)
            if not s:
                continue
            r.ai_score = s.get("score", 0)
            r.off_topic = bool(s.get("off_topic", False))
            r.ai_generated = s.get("ai_generated", "low")
            r.ai_raw_response = s
        q.status = "scored"
        db.commit()
        logger.info(f"ai_qa: scored question #{qid}, {len(valid_rows)} answers")
        # TODO: 通知 admin 终审
    finally:
        db.close()
```

- [ ] **Step 2: 加 Celery 包装 + beat schedule**

在 `scheduled_tasks.py` 顶部已有 Celery imports，加：

```python
@celery_app.task(name="ai_qa.close_expired")
def celery_close_expired_ai_questions():
    close_expired_ai_questions()


@celery_app.task(name="ai_qa.score_closed")
def celery_score_closed_ai_questions():
    score_closed_ai_questions()


@celery_app.task(name="ai_qa.score_single")
def celery_score_single_ai_question(qid: int):
    score_single_ai_question(qid)
```

并在 beat_schedule 配置加：

```python
"ai-qa-close-expired": {
    "task": "ai_qa.close_expired",
    "schedule": crontab(minute="*/5"),  # 每 5 分钟检查
},
"ai-qa-score-closed": {
    "task": "ai_qa.score_closed",
    "schedule": crontab(minute="*/10"),  # 每 10 分钟评分
},
```

- [ ] **Step 3: 验证 import 不报错**

Run: `cd backend && python -c "from app.scheduled_tasks import close_expired_ai_questions, score_closed_ai_questions, score_single_ai_question; print('ok')"`
Expected: `ok`

- [ ] **Step 4: 手动跑一次（linktest 用，无 Celery）**

Run: `cd backend && python -c "from app.scheduled_tasks import close_expired_ai_questions; close_expired_ai_questions()"`
Expected: 不报错（无符合条件题目时静默）

- [ ] **Step 5: Commit**

```bash
git add backend/app/scheduled_tasks.py
git commit -m "feat(ai-qa): scheduled_tasks beat (close_expired + score_closed + score_single) + Celery 包装"
```

---

### Task 11: settle 事务集成测试

**Files:**
- Create: `backend/tests/test_ai_qa_settle.py`

- [ ] **Step 1: 写 settle 测试**

```python
# backend/tests/test_ai_qa_settle.py
"""settle 事务的集成测试 (spec §8 (a)-(h) 用例)。"""
import pytest
from decimal import Decimal
from unittest.mock import patch, MagicMock
from datetime import datetime, timezone, timedelta

# 假定 conftest 提供 db, admin_user, sample_user 等 fixture
# 此处省略 fixture 定义（按 backend/tests/conftest.py 现有模式）


def _create_settled_ready_question(db, admin_id: str, reward_pool_pence: int = 1000):
    """Helper: 建一个 status=scored 的题 + 3 个已评分的答案。"""
    from app.models_ai_qa import AiQuestion, AiAnswerScore
    from app import models
    q = AiQuestion(
        title="test q", content="test", posed_by_expert_id="EXP00001",
        status="scored", reward_pool_pence=reward_pool_pence,
        participation_points=5,
        floor_pence=10,
        target_forum_category_id=1, created_by_admin_id=admin_id,
        deadline=datetime.now(timezone.utc) - timedelta(hours=1),
    )
    db.add(q)
    db.flush()
    for i, (user_id, score) in enumerate([("U0000001", 90), ("U0000002", 80), ("U0000003", 70)]):
        # 假设已有 ForumPost
        post = models.ForumPost(
            title="ans", content="ans content", author_id=user_id, category_id=1,
            ai_question_id=q.id,
        )
        db.add(post)
        db.flush()
        row = AiAnswerScore(
            ai_question_id=q.id, forum_post_id=post.id, user_id=user_id,
            ai_score=score,
        )
        db.add(row)
    db.commit()
    return q


def test_settle_happy_path(db_session, admin_user, sample_users):
    """case (b): settle 正确分钱 + leaderboard + ForumPost.is_featured。"""
    from app.services.ai_qa_settle import settle_question
    q = _create_settled_ready_question(db_session, admin_user.id, reward_pool_pence=1000)
    result = settle_question(db_session, q.id, admin_user.id)
    assert result["winner_count"] >= 1
    assert result["total_settled_pence"] == 1000
    db_session.refresh(q)
    assert q.status == "settled"
    # 验证 top 1 ForumPost.is_featured
    from app.models_ai_qa import AiAnswerScore
    from app import models
    top1 = db_session.query(AiAnswerScore).filter_by(ai_question_id=q.id, rank_final=1).one()
    fp = db_session.get(models.ForumPost, top1.forum_post_id)
    assert fp.is_featured is True


def test_settle_idempotency_lock(db_session, admin_user):
    """case (d): S1 行锁 + 重复 settle 拒绝。"""
    from app.services.ai_qa_settle import settle_question, SettleError
    q = _create_settled_ready_question(db_session, admin_user.id)
    settle_question(db_session, q.id, admin_user.id)
    # 第二次 settle 应失败：status 已是 settled
    with pytest.raises(SettleError, match="status"):
        settle_question(db_session, q.id, admin_user.id)


def test_settle_weekly_cap(db_session, admin_user, monkeypatch):
    """case (f): S5 周度上限超出拒绝。"""
    from app.services.ai_qa_settle import settle_question, SettleError
    # mock SystemSettings cap 极低
    from app.crud.system import update_system_setting
    update_system_setting(db_session, "ai_qa_weekly_settle_cap_pence", "100")
    db_session.commit()
    q = _create_settled_ready_question(db_session, admin_user.id, reward_pool_pence=1000)
    with pytest.raises(SettleError, match="weekly settle cap"):
        settle_question(db_session, q.id, admin_user.id)


def test_settle_audit_log(db_session, admin_user):
    """case (g): 成功 settle 产生 1 条 audit log。"""
    from app.services.ai_qa_settle import settle_question
    from app import models
    q = _create_settled_ready_question(db_session, admin_user.id)
    settle_question(db_session, q.id, admin_user.id)
    db_session.commit()
    logs = db_session.query(models.AuditLog).filter_by(
        action_type="ai_qa_settle", entity_id=str(q.id)
    ).all()
    assert len(logs) == 1
    assert "total_settled_pence" in logs[0].new_value


def test_settle_canceled_not_in_leaderboard(db_session, admin_user):
    """case (c): canceled 题不写 leaderboard。"""
    from app.models_ai_qa import AiQuestion, AiQaLeaderboard
    # 直接建 canceled 题(不走 settle)
    q = AiQuestion(
        title="t", content="c", posed_by_expert_id="EXP00001", status="canceled",
        reward_pool_pence=1000, participation_points=5,
        floor_pence=10,
        target_forum_category_id=1, created_by_admin_id=admin_user.id,
    )
    db_session.add(q)
    db_session.commit()
    # canceled 流程不会调 settle_question,所以 leaderboard 不动
    assert db_session.query(AiQaLeaderboard).count() == 0


# ============================================================================
# 以下 3 个 case 覆盖新算法 (spec §2.1) 关键场景:验证 settle 集成层在
# floor_pence 抹零 / 全 0 分 / 并列分 等情况下 wallet+leaderboard+rank 链路对
# ============================================================================

def test_settle_floor_cuts_off_bottom_at_scale(db_session, admin_user):
    """case (i): 100 人答 + floor 抹零 → top X 拿钱, bottom 被归零;
    全员 leaderboard.answer_count += 1 但仅 winners win_count += 1。

    spec §2.1 表第 4 行场景:pool=£10 (1000p), floor=10p, 100 人分数 [80..0]。
    多数 score 低 → bottom 被 floor 抹零,只有 top X 实际拿钱。
    """
    from app.services.ai_qa_settle import settle_question
    from app.models_ai_qa import AiQuestion, AiAnswerScore, AiQaLeaderboard
    from app import models

    q = AiQuestion(
        title="100q", content="c", posed_by_expert_id="EXP00001", status="scored",
        reward_pool_pence=1000, participation_points=5, floor_pence=10,
        target_forum_category_id=1, created_by_admin_id=admin_user.id,
        deadline=datetime.now(timezone.utc) - timedelta(hours=1),
    )
    db_session.add(q); db_session.flush()
    # 100 个答主, score 从 80 递减到 0 (人为构造大量低分被 floor 抹零)
    for i in range(100):
        uid = f"U{i:07d}"
        post = models.ForumPost(
            title=f"a{i}", content="c", author_id=uid, category_id=1,
            ai_question_id=q.id,
        )
        db_session.add(post); db_session.flush()
        score = max(0, 80 - i)  # i=0 → 80, i=80+ → 0
        db_session.add(AiAnswerScore(
            ai_question_id=q.id, forum_post_id=post.id, user_id=uid, ai_score=score,
        ))
    db_session.commit()

    settle_question(db_session, q.id, admin_user.id)
    db_session.commit()

    rows = db_session.query(AiAnswerScore).filter_by(ai_question_id=q.id).all()
    winners = [r for r in rows if r.reward_pence > 0]
    losers = [r for r in rows if r.reward_pence == 0]

    # 关键断言:
    assert len(winners) < 100, "floor 抹零应过滤掉一些低分,而非全员都拿钱"
    assert len(winners) >= 1, "至少 top 1 应拿到钱"
    assert all(r.reward_pence >= 10 for r in winners), "winners 单人 ≥ floor (10p)"
    assert sum(r.reward_pence for r in rows) == 1000, "总额 = 池子"
    # rank_final 全员都有 (排名给所有人,跟 reward_pence 是否 0 无关)
    assert all(r.rank_final is not None for r in rows)
    # leaderboard: 100 行 (每人 answer_count +=1), 但 win_count > 0 只在 winners
    lb_rows = db_session.query(AiQaLeaderboard).all()
    assert len(lb_rows) == 100
    win_lb = [lb for lb in lb_rows if lb.win_count > 0]
    assert len(win_lb) == len(winners), "leaderboard win_count 跟 reward_pence>0 一致"


def test_settle_all_zero_scores(db_session, admin_user):
    """case (j): 全 0 分 settle → wallet 没 credit + leaderboard 不写 win_count + status 仍切 settled。

    spec §2.1 表第 5 行场景:5 人都拿 0 分。distribute_pool 返回全 0;
    钱留在 reward_pool_pence (不退不补);但 status 仍走完 settled 流程 + 参与积分照发。
    """
    from app.services.ai_qa_settle import settle_question
    from app.models_ai_qa import AiQuestion, AiAnswerScore, AiQaLeaderboard
    from app import models

    q = AiQuestion(
        title="zeroq", content="c", posed_by_expert_id="EXP00001", status="scored",
        reward_pool_pence=1000, participation_points=5, floor_pence=10,
        target_forum_category_id=1, created_by_admin_id=admin_user.id,
        deadline=datetime.now(timezone.utc) - timedelta(hours=1),
    )
    db_session.add(q); db_session.flush()
    for i in range(5):
        uid = f"U{i:07d}"
        post = models.ForumPost(
            title=f"a{i}", content="c", author_id=uid, category_id=1,
            ai_question_id=q.id,
        )
        db_session.add(post); db_session.flush()
        db_session.add(AiAnswerScore(
            ai_question_id=q.id, forum_post_id=post.id, user_id=uid, ai_score=0,
        ))
    db_session.commit()

    settle_question(db_session, q.id, admin_user.id)
    db_session.commit()
    db_session.refresh(q)

    # 状态切 settled (走完完整流程)
    assert q.status == "settled"
    rows = db_session.query(AiAnswerScore).filter_by(ai_question_id=q.id).all()
    # 全员 reward_pence = 0 (无答案被采纳)
    assert all(r.reward_pence == 0 for r in rows)
    # 全员 reward_points > 0 (参与积分照发)
    assert all(r.reward_points > 0 for r in rows)
    # wallet 没 credit (查 wallet_transactions WHERE related_type='ai_question' AND related_id=qid)
    from app.wallet_models import WalletTransaction  # 注意:wallet 模型在 wallet_models.py 不在 models.py
    tx = db_session.query(WalletTransaction).filter_by(
        related_type="ai_question", related_id=str(q.id),
    ).all()
    assert len(tx) == 0, "全 0 分不应触发任何 wallet credit"
    # leaderboard: 5 行都写 (answer_count +=1) 但 win_count 全 0
    lb_rows = db_session.query(AiQaLeaderboard).all()
    assert len(lb_rows) == 5
    assert all(lb.win_count == 0 and lb.total_won_pence == 0 for lb in lb_rows)


def test_settle_rank_final_with_ties(db_session, admin_user):
    """case (k): rank_final 排名正确性 (含并列分场景)。

    并列分时 rank_final 不应跳号 (1, 2, 2, 4) 或乱排;具体决策跟 spec §6.1
    "rank_final ∈ [1, 3] 且 settled" 金边规则相关,影响前端 top3 高亮。
    """
    from app.services.ai_qa_settle import settle_question
    from app.models_ai_qa import AiQuestion, AiAnswerScore
    from app import models

    q = AiQuestion(
        title="tieq", content="c", posed_by_expert_id="EXP00001", status="scored",
        reward_pool_pence=1000, participation_points=5, floor_pence=10,
        target_forum_category_id=1, created_by_admin_id=admin_user.id,
        deadline=datetime.now(timezone.utc) - timedelta(hours=1),
    )
    db_session.add(q); db_session.flush()
    # 分数: [90, 80, 80, 70, 60] — 第 2/3 名并列
    scores = [("U0000001", 90), ("U0000002", 80), ("U0000003", 80),
              ("U0000004", 70), ("U0000005", 60)]
    for uid, score in scores:
        post = models.ForumPost(
            title="a", content="c", author_id=uid, category_id=1,
            ai_question_id=q.id,
        )
        db_session.add(post); db_session.flush()
        db_session.add(AiAnswerScore(
            ai_question_id=q.id, forum_post_id=post.id, user_id=uid, ai_score=score,
        ))
    db_session.commit()
    settle_question(db_session, q.id, admin_user.id)
    db_session.commit()

    rows = {r.user_id: r for r in db_session.query(AiAnswerScore).filter_by(ai_question_id=q.id).all()}
    # 关键断言:并列分 reward_pence 必须相等 (按比例分)
    assert rows["U0000002"].reward_pence == rows["U0000003"].reward_pence
    # rank_final:第 1 名 rank=1;第 2/3 名 (并列 80) 都应该 rank=2 (不跳号到 3)
    # 注意:此断言依赖实现决策。如选"密集排名 1,2,2,3,4" → 改下面;如选"标准 1,2,2,4,5" → 改下面
    # spec §6.1 没明确,但 settle 服务 (Task 6) 实现时应当 explicit 选一种,这里跟 settle 实现保持一致
    assert rows["U0000001"].rank_final == 1
    assert rows["U0000002"].rank_final == rows["U0000003"].rank_final  # 并列必须相同
    # 总额对齐池子
    assert sum(r.reward_pence for r in rows.values()) == 1000
```

- [ ] **Step 2: 跑测试**

Run: `cd backend && pytest tests/test_ai_qa_settle.py -v`
Expected: 8 个测试通过（可能需要根据 conftest fixture 适配）

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_ai_qa_settle.py
git commit -m "test(ai-qa): settle 事务集成测试 (S1 幂等 / S5 cap / audit / canceled 边界)"
```

---

### Task 12: Admin Web · 草稿管理页 (A3)

**Files:**
- Create: `admin/src/pages/ai-qa/DraftsPage.tsx`
- Create: `admin/src/components/ai-qa/FloorPenceInput.tsx`
- Create: `admin/src/api/aiQa.ts`
- Modify: `admin/src/App.tsx` (加路由)

- [ ] **Step 1: 创建 API client**

```typescript
// admin/src/api/aiQa.ts
import { http } from "./http";  // 现有 axios wrapper

// 注: 算法已重写(spec §2.1) — 不再有 TopnFormula 概念,只保留 floor_pence 单字段

export interface Draft {
  id?: number;
  title: string;
  content: string;
  topic_tag?: string;
  target_forum_category_id: number;
  deadline: string;  // ISO 8601
  reward_pool_pence: number;
  participation_points: number;
  floor_pence: number;  // 默认 10, 范围 1-1000 pence
  edit_lock_hours_before: number;
  posed_by_expert_id?: string;
}

export const aiQaApi = {
  listDrafts: () => http.get("/api/admin/ai-qa/questions?status=draft").then(r => r.data),
  createDraft: (data: Draft) => http.post("/api/admin/ai-qa/drafts", data).then(r => r.data),
  updateDraft: (id: number, data: Partial<Draft>) =>
    http.patch(`/api/admin/ai-qa/drafts/${id}`, data).then(r => r.data),
  deleteDraft: (id: number) => http.delete(`/api/admin/ai-qa/drafts/${id}`),
  publishDraft: (id: number) => http.post(`/api/admin/ai-qa/drafts/${id}/publish`).then(r => r.data),
  listQuestions: (status?: string) =>
    http.get("/api/admin/ai-qa/questions", { params: { status } }).then(r => r.data),
  cancelQuestion: (id: number, reason: string) =>
    http.post(`/api/admin/ai-qa/questions/${id}/cancel`, { reason }).then(r => r.data),
  getReview: (id: number) => http.get(`/api/admin/ai-qa/questions/${id}/review`).then(r => r.data),
  updateScore: (scoreId: number, data: { admin_override_score?: number; hide_in_qa?: boolean }) =>
    http.patch(`/api/admin/ai-qa/scores/${scoreId}`, data).then(r => r.data),
  rescore: (id: number) => http.post(`/api/admin/ai-qa/questions/${id}/rescore`).then(r => r.data),
  settle: (id: number) => http.post(`/api/admin/ai-qa/questions/${id}/settle`).then(r => r.data),
};
```

- [ ] **Step 2: 创建 FloorPenceInput 组件**

```tsx
// admin/src/components/ai-qa/FloorPenceInput.tsx
import React from "react";

interface Props {
  value: number;       // floor_pence, 1-1000
  onChange: (next: number) => void;
  poolPence: number;   // 用于实时预览
}

/** 模拟后端 distribute_pool 算法,生成给定答题人数下的预览 */
function preview(floorPence: number, poolPence: number, scores: number[]): string {
  if (scores.length === 0) return "—";
  const total = scores.reduce((a, b) => a + b, 0);
  if (total === 0) return `${scores.length} 人全 0 分 → 每人 £0`;
  const raw = scores.map(s => Math.round(poolPence * s / total));
  const cleaned = raw.map(amt => amt >= floorPence ? amt : 0);
  const nonZero = cleaned.filter(amt => amt > 0).length;
  const minAmt = nonZero > 0 ? Math.min(...cleaned.filter(amt => amt > 0)) : 0;
  const maxAmt = Math.max(...cleaned);
  return `${scores.length} 人 → ${nonZero} 人分到 £${(minAmt/100).toFixed(2)}-£${(maxAmt/100).toFixed(2)}`;
}

export const FloorPenceInput: React.FC<Props> = ({ value, onChange, poolPence }) => {
  return (
    <div style={{ background: "#f9fafb", border: "1px solid #e5e7eb", padding: 14, borderRadius: 6 }}>
      <label style={{ display: "block", maxWidth: 320 }}>
        单人最低金额 <code>floor_pence</code> (1-1000)
        <input
          type="number" min={1} max={1000}
          value={value} onChange={e => onChange(parseInt(e.target.value) || 10)}
          style={{ width: "100%", marginTop: 4, padding: 6 }}
        />
        <div style={{ fontSize: 11, color: "#9ca3af", marginTop: 4 }}>
          默认 10 = £0.10。所有答主按 final_score 比例分,低于此值抹零(钱留池子不发)。
        </div>
      </label>

      <div style={{ marginTop: 10, padding: 8, background: "#fff", borderRadius: 4, fontSize: 12, lineHeight: 1.6 }}>
        <strong>📊 实时预览</strong>（按 £{(poolPence / 100).toFixed(2)} 池子 + floor £{(value / 100).toFixed(2)}）：<br />
        · {preview(value, poolPence, [90, 80, 70, 60, 50])}（5 人均匀分数）<br />
        · {preview(value, poolPence, Array.from({length: 30}, (_, i) => 80 - i))}（30 人均匀）<br />
        · {preview(value, poolPence, [100, ...Array(99).fill(5)])}（100 人，top 1 一枝独秀）<br />
        <span style={{ color: "#6b7280", fontSize: 11 }}>💡 池子越大 → 能高于 floor 的人越多。</span>
      </div>
    </div>
  );
};
```

- [ ] **Step 3: 创建 DraftsPage**

```tsx
// admin/src/pages/ai-qa/DraftsPage.tsx
import React, { useEffect, useState } from "react";
import { aiQaApi, Draft } from "../../api/aiQa";
import { FloorPenceInput } from "../../components/ai-qa/FloorPenceInput";

const EMPTY_DRAFT: Draft = {
  title: "", content: "", target_forum_category_id: 0,
  deadline: new Date(Date.now() + 7 * 86400000).toISOString().slice(0, 16),
  reward_pool_pence: 1000, participation_points: 5,
  floor_pence: 10, edit_lock_hours_before: 1,
};

export const DraftsPage: React.FC = () => {
  const [drafts, setDrafts] = useState<any[]>([]);
  const [editing, setEditing] = useState<Draft | null>(null);
  const [confirmHigh, setConfirmHigh] = useState(false);

  const reload = () => aiQaApi.listDrafts().then(setDrafts);
  useEffect(() => { reload(); }, []);

  const handleSave = async () => {
    if (!editing) return;
    if (editing.reward_pool_pence > 5000 && !confirmHigh) {
      alert("⚠ 大额奖金池（>£50）请勾选下方确认");
      return;
    }
    if (editing.id) {
      await aiQaApi.updateDraft(editing.id, editing);
    } else {
      await aiQaApi.createDraft(editing);
    }
    setEditing(null);
    setConfirmHigh(false);
    reload();
  };

  const handlePublish = async (id: number) => {
    if (!confirm("确认发布到 published?")) return;
    await aiQaApi.publishDraft(id);
    reload();
  };

  const handleDelete = async (id: number) => {
    if (!confirm("确认删除草稿?")) return;
    await aiQaApi.deleteDraft(id);
    reload();
  };

  return (
    <div>
      <h2>草稿管理</h2>
      <button onClick={() => setEditing({ ...EMPTY_DRAFT })}>+ 新建草稿</button>

      <table style={{ marginTop: 16, width: "100%", borderCollapse: "collapse" }}>
        <thead>
          <tr>
            <th>ID</th><th>题面</th><th>板块</th><th>奖金池</th><th>截止</th><th>操作</th>
          </tr>
        </thead>
        <tbody>
          {drafts.map(d => (
            <tr key={d.id}>
              <td>#{d.id}</td>
              <td>{d.title}</td>
              <td>{d.target_forum_category_id}</td>
              <td>£{(d.reward_pool_pence / 100).toFixed(2)}</td>
              <td>{new Date(d.deadline).toLocaleString()}</td>
              <td>
                <button onClick={() => handlePublish(d.id)}>发布</button>
                <button onClick={() => setEditing(d)}>编辑</button>
                <button onClick={() => handleDelete(d.id)}>删除</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      {editing && (
        <div style={{ marginTop: 24, padding: 20, background: "#fff", borderRadius: 8 }}>
          <h3>{editing.id ? `编辑草稿 #${editing.id}` : "新建草稿"}</h3>
          <label>题面<input value={editing.title}
            onChange={e => setEditing({ ...editing, title: e.target.value })} /></label>
          <label>正文<textarea value={editing.content}
            onChange={e => setEditing({ ...editing, content: e.target.value })} /></label>
          <label>目标论坛板块 id<input type="number" value={editing.target_forum_category_id}
            onChange={e => setEditing({ ...editing, target_forum_category_id: parseInt(e.target.value) })} /></label>
          <label>截止时间<input type="datetime-local" value={editing.deadline}
            onChange={e => setEditing({ ...editing, deadline: e.target.value })} /></label>
          <label>奖金池 pence (上限 100000)<input type="number" min={0} max={100000}
            value={editing.reward_pool_pence}
            onChange={e => setEditing({ ...editing, reward_pool_pence: parseInt(e.target.value) })} /></label>
          {editing.reward_pool_pence > 5000 && (
            <label style={{ color: "red" }}>
              <input type="checkbox" checked={confirmHigh}
                     onChange={e => setConfirmHigh(e.target.checked)} />
              ⚠ 我已确认 £{(editing.reward_pool_pence / 100).toFixed(2)} 大额奖金池
            </label>
          )}
          <FloorPenceInput
            value={editing.floor_pence}
            onChange={fp => setEditing({ ...editing, floor_pence: fp })}
            poolPence={editing.reward_pool_pence}
          />
          <div style={{ marginTop: 16 }}>
            <button onClick={handleSave}>💾 保存草稿</button>
            <button onClick={() => { setEditing(null); setConfirmHigh(false); }}>取消</button>
          </div>
        </div>
      )}
    </div>
  );
};
```

- [ ] **Step 4: 注册路由到 App.tsx**

```tsx
import { DraftsPage } from "./pages/ai-qa/DraftsPage";
// 在 <Routes> 内加：
<Route path="/admin/ai-qa/drafts" element={<DraftsPage />} />
```

- [ ] **Step 5: 跑 npm dev 手动测试**

Run: `cd admin && npm run dev`
Expected: 浏览器打开 `/admin/ai-qa/drafts` 看到草稿列表 + 新建按钮

- [ ] **Step 6: Commit**

```bash
git add admin/src/api/aiQa.ts admin/src/components/ai-qa/FloorPenceInput.tsx admin/src/pages/ai-qa/DraftsPage.tsx admin/src/App.tsx
git commit -m "feat(ai-qa/admin): A3 草稿管理页 + FloorPenceInput 组件 (单字段算法) + API client"
```

---

### Task 13: Admin Web · 题目列表页 (A4)

**Files:**
- Create: `admin/src/pages/ai-qa/QuestionsPage.tsx`
- Modify: `admin/src/App.tsx`

- [ ] **Step 1: 创建 QuestionsPage**

```tsx
// admin/src/pages/ai-qa/QuestionsPage.tsx
import React, { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { aiQaApi } from "../../api/aiQa";

const STATUS_LABELS: Record<string, { label: string; color: string }> = {
  draft: { label: "draft", color: "#6b7280" },
  published: { label: "published", color: "#1e40af" },
  canceled: { label: "canceled", color: "#991b1b" },
  closed: { label: "closed", color: "#4338ca" },
  closed_empty: { label: "closed_empty", color: "#6b7280" },
  scoring: { label: "scoring", color: "#92400e" },
  scoring_failed: { label: "scoring_failed", color: "#7f1d1d" },
  scored: { label: "scored", color: "#5b21b6" },
  settled: { label: "settled", color: "#065f46" },
  settle_failed: { label: "settle_failed", color: "#7f1d1d" },
};

export const QuestionsPage: React.FC = () => {
  const [questions, setQuestions] = useState<any[]>([]);
  const [filter, setFilter] = useState<string>("");

  useEffect(() => {
    aiQaApi.listQuestions(filter || undefined).then(setQuestions);
  }, [filter]);

  const handleCancel = async (id: number) => {
    const reason = prompt("撤稿原因？");
    if (!reason) return;
    await aiQaApi.cancelQuestion(id, reason);
    aiQaApi.listQuestions(filter || undefined).then(setQuestions);
  };

  return (
    <div>
      <h2>题目列表</h2>
      <label>
        状态：
        <select value={filter} onChange={e => setFilter(e.target.value)}>
          <option value="">全部</option>
          {Object.keys(STATUS_LABELS).map(s => <option key={s} value={s}>{s}</option>)}
        </select>
      </label>

      <table style={{ marginTop: 16, width: "100%", borderCollapse: "collapse" }}>
        <thead>
          <tr><th>ID</th><th>题面</th><th>状态</th><th>奖金池</th><th>截止</th><th>操作</th></tr>
        </thead>
        <tbody>
          {questions.map(q => {
            const st = STATUS_LABELS[q.status] || { label: q.status, color: "#000" };
            return (
              <tr key={q.id}>
                <td>#{q.id}</td>
                <td>{q.title}</td>
                <td><span style={{ background: st.color + "22", color: st.color, padding: "2px 8px", borderRadius: 99 }}>{st.label}</span></td>
                <td>£{(q.reward_pool_pence / 100).toFixed(2)}</td>
                <td>{q.deadline ? new Date(q.deadline).toLocaleString() : "—"}</td>
                <td>
                  {(q.status === "scored" || q.status === "settle_failed") && (
                    <Link to={`/admin/ai-qa/review/${q.id}`}>→ 终审</Link>
                  )}
                  {q.status === "published" && (
                    <button onClick={() => handleCancel(q.id)}>撤稿</button>
                  )}
                  {q.status === "scoring_failed" && (
                    <button onClick={() => aiQaApi.rescore(q.id).then(() => aiQaApi.listQuestions(filter || undefined).then(setQuestions))}>重跑评分</button>
                  )}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
};
```

- [ ] **Step 2: 注册路由**

```tsx
<Route path="/admin/ai-qa/questions" element={<QuestionsPage />} />
```

- [ ] **Step 3: 手测**

打开 `/admin/ai-qa/questions`，验证状态过滤 + cancel 按钮 + 跳转 review 链接。

- [ ] **Step 4: Commit**

```bash
git add admin/src/pages/ai-qa/QuestionsPage.tsx admin/src/App.tsx
git commit -m "feat(ai-qa/admin): A4 题目列表页 (状态过滤 + 撤稿 + 跳转终审)"
```

---

### Task 14: Admin Web · 评分终审页 (A5)

**Files:**
- Create: `admin/src/pages/ai-qa/ReviewPage.tsx`
- Modify: `admin/src/App.tsx`

- [ ] **Step 1: 创建 ReviewPage（包含表格 + 改分 + 一键发奖）**

```tsx
// admin/src/pages/ai-qa/ReviewPage.tsx
import React, { useEffect, useState, useMemo } from "react";
import { useParams } from "react-router-dom";
import { aiQaApi } from "../../api/aiQa";

export const ReviewPage: React.FC = () => {
  const { qid } = useParams<{ qid: string }>();
  const [data, setData] = useState<any>(null);
  const [rows, setRows] = useState<any[]>([]);
  const [sortBy, setSortBy] = useState<"risk" | "created" | "ai_score">("risk");

  const reload = () => {
    if (qid) aiQaApi.getReview(parseInt(qid)).then(d => {
      setData(d);
      setRows(d.rows);
    });
  };
  useEffect(() => { reload(); }, [qid]);

  const totalBudget = useMemo(() => {
    // 新算法：全员按比例分,floor_pence 抹零;预算估算 = 池子全发完
    if (!data) return 0;
    const activeRows = rows.filter(r => !r.hide_in_qa);
    const scores = activeRows.map(r => r.admin_override_score ?? r.ai_score ?? 0);
    const total = scores.reduce((a, b) => a + b, 0);
    if (total === 0) return 0;
    return data.question.reward_pool_pence;  // 全发完 (无 winners_count cap)
  }, [data, rows]);

  if (!data) return <div>Loading...</div>;

  const sorted = [...rows].sort((a, b) => {
    if (sortBy === "risk") return b.risk_score - a.risk_score;
    if (sortBy === "created") return new Date(a.forum_post_created_at).getTime() - new Date(b.forum_post_created_at).getTime();
    return (b.ai_score ?? 0) - (a.ai_score ?? 0);
  });

  const handleScoreChange = (id: number, score: number) => {
    setRows(rows.map(r => r.id === id ? { ...r, admin_override_score: score } : r));
    aiQaApi.updateScore(id, { admin_override_score: score });
  };

  const handleHideChange = (id: number, hide: boolean) => {
    setRows(rows.map(r => r.id === id ? { ...r, hide_in_qa: hide } : r));
    aiQaApi.updateScore(id, { hide_in_qa: hide });
  };

  const handleSettle = async () => {
    if (!confirm(`确认发放 £${(data.question.reward_pool_pence / 100).toFixed(2)} 奖金给 ${rows.filter(r => !r.hide_in_qa).length} 位答主？不可撤回`)) return;
    try {
      const result = await aiQaApi.settle(parseInt(qid!));
      alert(`✅ 已发奖：£${(result.total_settled_pence / 100).toFixed(2)} 给 ${result.winner_count} 人`);
      reload();
    } catch (e: any) {
      alert(`❌ 发奖失败：${e.response?.data?.detail || e.message}`);
      reload();
    }
  };

  return (
    <div>
      <h2>{data.question.title} · 终审</h2>
      <div style={{ display: "flex", gap: 24, background: "#fef3c7", padding: 12, borderRadius: 8, marginBottom: 16 }}>
        <div>奖金池: <strong>£{(data.question.reward_pool_pence / 100).toFixed(2)}</strong></div>
        <div>分配预算: <strong>£{(totalBudget / 100).toFixed(2)}</strong></div>
        <div>本周已 settled: <strong>£{(data.weekly_settled_pence / 100).toFixed(2)}</strong> / 上限 £{(data.weekly_cap_pence / 100).toFixed(2)}</div>
        <button onClick={() => aiQaApi.rescore(parseInt(qid!)).then(reload)}>重跑 AI 评分</button>
        <button onClick={handleSettle} style={{ background: "#10b981", color: "white" }}>✓ 确认发奖</button>
      </div>

      <div>
        排序：
        <button onClick={() => setSortBy("risk")}>风险降序</button>
        <button onClick={() => setSortBy("created")}>发布时间升序</button>
        <button onClick={() => setSortBy("ai_score")}>AI 分降序</button>
      </div>

      <table style={{ marginTop: 12, width: "100%", borderCollapse: "collapse" }}>
        <thead>
          <tr>
            <th>#</th><th>用户</th><th>发布时间</th><th>答案预览</th>
            <th>AI 分</th><th>AI 检测</th><th>风险</th>
            <th>改分</th><th>屏蔽</th>
          </tr>
        </thead>
        <tbody>
          {sorted.map((r, idx) => {
            const isEdited = r.is_edited;
            const isHighRisk = r.risk_score >= 30;
            return (
              <tr key={r.id} style={{ background: isHighRisk ? "#fff5f5" : undefined }}>
                <td>{idx + 1}</td>
                <td>{r.user_name || r.user_id}</td>
                <td>
                  {new Date(r.forum_post_created_at).toLocaleString()}<br />
                  {isEdited && <small style={{ color: "#dc2626" }}>⚠ 已编辑</small>}
                </td>
                <td style={{ maxWidth: 280, overflow: "hidden", textOverflow: "ellipsis" }}>{r.content_preview}</td>
                <td>{r.ai_score ?? "—"}</td>
                <td><span style={{ background: r.ai_generated === "high" ? "#fee2e2" : r.ai_generated === "medium" ? "#fef3c7" : "#d1fae5", padding: "1px 6px", borderRadius: 4, fontSize: 10 }}>{r.ai_generated ?? "—"}</span></td>
                <td>{r.risk_score} {r.risk_reasons && <small>({r.risk_reasons})</small>}</td>
                <td>
                  <input type="number" min={0} max={100}
                         value={r.admin_override_score ?? r.ai_score ?? 0}
                         onChange={e => handleScoreChange(r.id, parseInt(e.target.value))}
                         style={{ width: 56 }} />
                </td>
                <td>
                  <input type="checkbox" checked={r.hide_in_qa}
                         onChange={e => handleHideChange(r.id, e.target.checked)} />
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
};
```

- [ ] **Step 2: 注册路由**

```tsx
<Route path="/admin/ai-qa/review/:qid" element={<ReviewPage />} />
```

- [ ] **Step 3: 手测完整流程**

1. 在 admin 后台建一个 draft
2. publish 该 draft
3. 用 curl 模拟 2-3 用户答题
4. 让 deadline 过 + 跑 scheduled_tasks.close_expired_ai_questions + score_closed_ai_questions
5. 进 review 页改分 + 点确认发奖
6. 验证 wallet 余额到账（查 wallet_accounts）+ audit log 记录

- [ ] **Step 4: Commit**

```bash
git add admin/src/pages/ai-qa/ReviewPage.tsx admin/src/App.tsx
git commit -m "feat(ai-qa/admin): A5 评分终审页 (改分 + 一键发奖 + 周度 cap 显示)"
```

---

### Task 15: Flutter · 详情/答题/结算页 + 路由 + l10n

**Files:**
- Create: `link2ur/lib/features/ai_qa/bloc/ai_qa_bloc.dart`
- Create: `link2ur/lib/features/ai_qa/views/ai_qa_detail_view.dart`
- Create: `link2ur/lib/features/ai_qa/views/ai_qa_answer_form_view.dart`
- Create: `link2ur/lib/data/models/ai_qa.dart`
- Create: `link2ur/lib/data/repositories/ai_qa_repository.dart`
- Modify: `link2ur/lib/core/router/app_router.dart`
- Modify: `link2ur/lib/core/constants/api_endpoints.dart`
- Modify: `link2ur/lib/app_providers.dart`
- Modify: `link2ur/lib/l10n/app_{en,zh,zh_Hant}.arb`
- Modify: `link2ur/lib/core/utils/error_localizer.dart`

- [ ] **Step 1: 加 api_endpoints + l10n key**

`api_endpoints.dart` 加：
```dart
class ApiEndpoints {
  static const aiQaList = '/api/ai-qa';
  static String aiQaDetail(int id) => '/api/ai-qa/$id';
  static String aiQaAnswers(int id) => '/api/ai-qa/$id/answers';
  static String aiQaAnswer(int id) => '/api/ai-qa/$id/answer';
  static const aiQaLeaderboard = '/api/ai-qa/leaderboard';
}
```

l10n（每个 .arb 加，下方 zh 为例）：
```json
{
  "aiQaTitle": "AI 限时问答",
  "aiQaAnswerButton": "我来答",
  "aiQaCanceledBanner": "本期问答已被取消",
  "aiQaSettledBanner": "本期已结算，奖金已发到你的钱包",
  "aiQaCountdown": "倒计时",
  "aiQaPool": "奖金池",
  "aiQaAnswered": "已作答",
  "aiQaDeadlinePassed": "答题已截止",
  "aiQaEditLocked": "已锁定编辑",
  "aiQaAlreadyAnswered": "你已答过本题",
  "aiQaBlockedByRisk": "风控拒绝答题",
  "aiQaStatusNotPublished": "本题不在答题中"
}
```

> 注意:ARB key 必须 **camelCase** (`aiQaDeadlinePassed`),不是 snake_case;否则 `AppLocalizations` getter 不生成,编译报错。
> 后端返的错误码 (`ai_qa_deadline_passed`) 保持 snake_case,在 error_localizer 里做映射。

error_localizer.dart 加 (在 L99 起的 `switch (code)` 块):
```dart
case 'ai_qa_deadline_passed': return l10n.aiQaDeadlinePassed;
case 'ai_qa_edit_locked': return l10n.aiQaEditLocked;
case 'ai_qa_already_answered': return l10n.aiQaAlreadyAnswered;
case 'ai_qa_blocked_by_risk': return l10n.aiQaBlockedByRisk;
case 'ai_qa_status_not_published': return l10n.aiQaStatusNotPublished;
```

- [ ] **Step 2: 创建 models/ai_qa.dart**

```dart
// link2ur/lib/data/models/ai_qa.dart
import 'package:equatable/equatable.dart';

class AiQuestion extends Equatable {
  final int id;
  final String title;
  final String content;
  final String status;
  final DateTime? deadline;
  final DateTime? editLockAt;
  final DateTime? canceledAt;
  final DateTime? settledAt;
  final int rewardPoolPence;
  final int participationPoints;
  final int targetForumCategoryId;

  const AiQuestion({
    required this.id, required this.title, required this.content,
    required this.status, this.deadline, this.editLockAt,
    this.canceledAt, this.settledAt,
    required this.rewardPoolPence, required this.participationPoints,
    required this.targetForumCategoryId,
  });

  factory AiQuestion.fromJson(Map<String, dynamic> json) => AiQuestion(
    id: json['id'],
    title: json['title'],
    content: json['content'],
    status: json['status'],
    deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
    editLockAt: json['edit_lock_at'] != null ? DateTime.parse(json['edit_lock_at']) : null,
    canceledAt: json['canceled_at'] != null ? DateTime.parse(json['canceled_at']) : null,
    settledAt: json['settled_at'] != null ? DateTime.parse(json['settled_at']) : null,
    rewardPoolPence: json['reward_pool_pence'],
    participationPoints: json['participation_points'],
    targetForumCategoryId: json['target_forum_category_id'],
  );

  @override
  List<Object?> get props => [id, title, content, status, deadline,
      editLockAt, canceledAt, settledAt, rewardPoolPence,
      participationPoints, targetForumCategoryId];
}

class AiAnswer extends Equatable {
  final int id;
  final int forumPostId;
  final String userId;
  final String? userName;
  final String? userAvatar;
  final String? title;
  final String? content;
  final List<String>? images;
  final DateTime? createdAt;
  final bool isDeleted;
  final int? aiScore;
  final String? aiGenerated;
  final int? finalScore;
  final int? rankFinal;
  final int rewardPence;
  final bool hideInQa;

  const AiAnswer({
    required this.id, required this.forumPostId, required this.userId,
    this.userName, this.userAvatar, this.title, this.content, this.images,
    this.createdAt, this.isDeleted = false,
    this.aiScore, this.aiGenerated, this.finalScore, this.rankFinal,
    this.rewardPence = 0, this.hideInQa = false,
  });

  factory AiAnswer.fromJson(Map<String, dynamic> json) => AiAnswer(
    id: json['id'],
    forumPostId: json['forum_post_id'],
    userId: json['user_id'],
    userName: json['user_name'],
    userAvatar: json['user_avatar'],
    title: json['title'],
    content: json['content'],
    images: json['images'] != null ? List<String>.from(json['images']) : null,
    createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    isDeleted: json['is_deleted'] ?? false,
    aiScore: json['ai_score'],
    aiGenerated: json['ai_generated'],
    finalScore: json['final_score'],
    rankFinal: json['rank_final'],
    rewardPence: json['reward_pence'] ?? 0,
    hideInQa: json['hide_in_qa'] ?? false,
  );

  @override
  List<Object?> get props => [id, forumPostId, userId, content, isDeleted,
      aiScore, aiGenerated, finalScore, rankFinal, rewardPence, hideInQa];
}
```

- [ ] **Step 3: 创建 repository**

```dart
// link2ur/lib/data/repositories/ai_qa_repository.dart
import '../models/ai_qa.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

/// 现有 27/29 repository 都用 ({required ApiService apiService}) 命名参数;
/// ApiService 方法返回 ApiResponse<T>,必须先判 isSuccess 才能用 .data —
/// 否则 .data 是 null 时会 NPE。参考 question_repository.dart / badges_repository.dart。
class AiQaRepository {
  final ApiService _apiService;
  AiQaRepository({required ApiService apiService}) : _apiService = apiService;

  Future<AiQuestion> getQuestion(int id) async {
    final resp = await _apiService.get(ApiEndpoints.aiQaDetail(id));
    if (resp.isSuccess && resp.data != null) {
      return AiQuestion.fromJson(resp.data as Map<String, dynamic>);
    }
    throw Exception(resp.errorCode ?? resp.message ?? 'ai_qa_load_detail_failed');
  }

  Future<List<AiAnswer>> getAnswers(int id) async {
    final resp = await _apiService.get(ApiEndpoints.aiQaAnswers(id));
    if (resp.isSuccess && resp.data != null) {
      final List items = resp.data as List;
      return items.map((j) => AiAnswer.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception(resp.errorCode ?? resp.message ?? 'ai_qa_load_answers_failed');
  }

  Future<Map<String, dynamic>> submitAnswer(int id, {
    String? title, required String content, List<String> images = const [],
  }) async {
    final resp = await _apiService.post(ApiEndpoints.aiQaAnswer(id), data: {
      'title': title, 'content': content, 'images': images,
    });
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    throw Exception(resp.errorCode ?? resp.message ?? 'ai_qa_submit_answer_failed');
  }
}
```

- [ ] **Step 4: 注册 repository in app_providers.dart**

跟现有 RepositoryProvider 命名参数风格保持一致 (参考 app_providers.dart L92-150)。

```dart
RepositoryProvider<AiQaRepository>(
  create: (_) => AiQaRepository(apiService: apiService),
),
```

- [ ] **Step 5: 创建 BLoC (单文件,跟现有 settings_bloc / ai_chat_bloc 风格一致;不用 part of)**

> 注意: CLAUDE.md memory 里写 "AuthEvent/AuthState are part of 'auth_bloc.dart'" 是**历史模式,只对 auth_bloc 属实**。
> 现有 30+ bloc (settings/ai_chat/wallet/...) 全是 events/state/bloc 同文件,不拆 part。新 bloc 沿用新风格。

```dart
// link2ur/lib/features/ai_qa/bloc/ai_qa_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/repositories/ai_qa_repository.dart';
import '../../../data/models/ai_qa.dart';

// ============================================================================
// Events
// ============================================================================

abstract class AiQaEvent extends Equatable {
  const AiQaEvent();
  @override List<Object?> get props => [];
}

class AiQaLoadDetail extends AiQaEvent {
  final int qid;
  const AiQaLoadDetail(this.qid);
  @override List<Object?> get props => [qid];
}

class AiQaSubmitAnswer extends AiQaEvent {
  final int qid;
  final String? title;
  final String content;
  final List<String> images;
  const AiQaSubmitAnswer({required this.qid, this.title, required this.content, this.images = const []});
  @override List<Object?> get props => [qid, title, content, images];
}

// ============================================================================
// State
// ============================================================================

enum AiQaStatus { initial, loading, loaded, submitting, submitted, error }

class AiQaState extends Equatable {
  final AiQaStatus status;
  final AiQuestion? question;
  final List<AiAnswer> answers;
  final String? errorMessage;

  const AiQaState({
    this.status = AiQaStatus.initial,
    this.question, this.answers = const [], this.errorMessage,
  });

  AiQaState copyWith({
    AiQaStatus? status, AiQuestion? question,
    List<AiAnswer>? answers, String? errorMessage,
  }) => AiQaState(
    status: status ?? this.status,
    question: question ?? this.question,
    answers: answers ?? this.answers,
    errorMessage: errorMessage,
  );

  @override
  List<Object?> get props => [status, question, answers, errorMessage];
}

// ============================================================================
// Bloc
// ============================================================================

class AiQaBloc extends Bloc<AiQaEvent, AiQaState> {
  final AiQaRepository _repository;

  AiQaBloc({required AiQaRepository repository})
      : _repository = repository,
        super(const AiQaState()) {
    on<AiQaLoadDetail>(_onLoadDetail);
    on<AiQaSubmitAnswer>(_onSubmit);
  }

  Future<void> _onLoadDetail(AiQaLoadDetail event, Emitter<AiQaState> emit) async {
    emit(state.copyWith(status: AiQaStatus.loading));
    try {
      final q = await _repository.getQuestion(event.qid);
      final answers = await _repository.getAnswers(event.qid);
      emit(state.copyWith(status: AiQaStatus.loaded, question: q, answers: answers));
    } catch (err) {
      // err 是 Exception(errorCode);err.toString() 是 "Exception: <code>"
      // 走 error_localizer.localize 映射成 l10n 文本
      emit(state.copyWith(status: AiQaStatus.error, errorMessage: err.toString()));
    }
  }

  Future<void> _onSubmit(AiQaSubmitAnswer event, Emitter<AiQaState> emit) async {
    emit(state.copyWith(status: AiQaStatus.submitting));
    try {
      await _repository.submitAnswer(
        event.qid,
        title: event.title,
        content: event.content,
        images: event.images,
      );
      emit(state.copyWith(status: AiQaStatus.submitted));
      add(AiQaLoadDetail(event.qid));
    } catch (err) {
      emit(state.copyWith(status: AiQaStatus.error, errorMessage: err.toString()));
    }
  }
}
```

- [ ] **Step 6: 创建 detail view (M3/M4/M5 三态)**

```dart
// link2ur/lib/features/ai_qa/views/ai_qa_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/ai_qa_bloc.dart';
import '../../../data/repositories/ai_qa_repository.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../l10n/app_localizations.dart';

class AiQaDetailView extends StatelessWidget {
  final int qid;
  const AiQaDetailView({super.key, required this.qid});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => AiQaBloc(repository: ctx.read<AiQaRepository>())..add(AiQaLoadDetail(qid)),
      child: const _Body(),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<AiQaBloc, AiQaState>(
      builder: (context, state) {
        if (state.status == AiQaStatus.loading) {
          return Scaffold(appBar: AppBar(title: Text(l10n.aiQaTitle)), body: const Center(child: CircularProgressIndicator()));
        }
        if (state.status == AiQaStatus.error || state.question == null) {
          return Scaffold(appBar: AppBar(title: Text(l10n.aiQaTitle)), body: Center(child: Text(context.localizeError(state.errorMessage ?? ''))));
        }
        final q = state.question!;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.aiQaTitle)),
          body: CustomScrollView(
            slivers: [
              if (q.status == 'canceled')
                SliverToBoxAdapter(child: Container(
                  margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(l10n.aiQaCanceledBanner),
                )),
              if (q.status == 'settled')
                SliverToBoxAdapter(child: Container(
                  margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(l10n.aiQaSettledBanner),
                )),
              SliverToBoxAdapter(child: _Hero(q: q)),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _AnswerCard(answer: state.answers[i], questionStatus: q.status),
                  childCount: state.answers.length,
                ),
              ),
            ],
          ),
          floatingActionButton: q.status == 'published' ? FloatingActionButton.extended(
            onPressed: () => context.push('/ai-qa/${q.id}/answer'),
            label: Text(l10n.aiQaAnswerButton),
            icon: const Icon(Icons.edit),
          ) : null,
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  final AiQuestion q;
  const _Hero({required this.q});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(q.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(q.content),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.amber.shade50, border: Border.all(color: Colors.amber), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(child: Column(children: [
              Text(l10n.aiQaPool, style: const TextStyle(fontSize: 10)),
              Text('£${(q.rewardPoolPence/100).toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ])),
            if (q.deadline != null && q.status == 'published')
              Expanded(child: Column(children: [
                Text(l10n.aiQaCountdown, style: const TextStyle(fontSize: 10)),
                Text(_formatCountdown(q.deadline!), style: const TextStyle(fontSize: 14, color: Colors.red)),
              ])),
          ]),
        ),
      ]),
    );
  }

  String _formatCountdown(DateTime deadline) {
    final diff = deadline.difference(DateTime.now());
    if (diff.isNegative) return '已截止';
    final d = diff.inDays;
    final h = diff.inHours % 24;
    return d > 0 ? '$d天$h小时' : '$h小时';
  }
}

class _AnswerCard extends StatelessWidget {
  final AiAnswer answer;
  final String questionStatus;
  const _AnswerCard({required this.answer, required this.questionStatus});
  @override
  Widget build(BuildContext context) {
    if (answer.hideInQa) return const SizedBox.shrink();
    final isDeleted = answer.isDeleted;
    final isSettledOrCanceled = questionStatus == 'settled' || questionStatus == 'canceled';
    if (isDeleted && !isSettledOrCanceled) return const SizedBox.shrink();
    // top3 高亮: 新算法 (spec §2.1) 下排名前 3 但 reward_pence 被 floor 抹零为 0 的情况
    // (小池子大池子边界 case) 不应贴金边,否则会展示"#2 金边 + 无奖金"的矛盾视觉
    final isTop = (answer.rankFinal ?? 999) <= 3
        && answer.rewardPence > 0
        && questionStatus == 'settled';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDeleted ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isTop ? Border.all(color: Colors.amber, width: 2) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (isTop) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)), child: Text('#${answer.rankFinal}')),
          if (isTop) const SizedBox(width: 6),
          Text(answer.userName ?? answer.userId, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        if (isDeleted) const Text('该答案已被删除', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
        else Text(answer.content ?? ''),
        if (answer.rewardPence > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('£${(answer.rewardPence/100).toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600))),
        if (answer.aiGenerated == 'high' && (questionStatus == 'scored' || questionStatus == 'settled'))
          Padding(padding: const EdgeInsets.only(top: 4), child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), color: Colors.grey.shade200, child: const Text('⚠ 可能为 AI 生成', style: TextStyle(fontSize: 10)))),
      ]),
    );
  }
}
```

- [ ] **Step 7: 创建 answer form view (M6)**

```dart
// link2ur/lib/features/ai_qa/views/ai_qa_answer_form_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ai_qa_bloc.dart';
import '../../../data/repositories/ai_qa_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/utils/error_localizer.dart';

class AiQaAnswerFormView extends StatefulWidget {
  final int qid;
  const AiQaAnswerFormView({super.key, required this.qid});
  @override
  State<AiQaAnswerFormView> createState() => _AiQaAnswerFormViewState();
}

class _AiQaAnswerFormViewState extends State<AiQaAnswerFormView> {
  final _contentCtl = TextEditingController();
  final _titleCtl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocProvider(
      create: (ctx) => AiQaBloc(repository: ctx.read<AiQaRepository>())..add(AiQaLoadDetail(widget.qid)),
      child: BlocConsumer<AiQaBloc, AiQaState>(
        listener: (context, state) {
          if (state.status == AiQaStatus.submitted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已提交')));
            Navigator.of(context).pop();
          } else if (state.status == AiQaStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.localizeError(state.errorMessage ?? ''))));
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: const Text('写答案')),
            body: state.question == null
                ? const Center(child: CircularProgressIndicator())
                : Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                    Container(padding: const EdgeInsets.all(12), color: Colors.blue.shade50, child: Text('回答中：${state.question!.title}')),
                    const SizedBox(height: 12),
                    TextField(controller: _titleCtl, decoration: const InputDecoration(labelText: '标题 (可选)')),
                    const SizedBox(height: 12),
                    Expanded(child: TextField(controller: _contentCtl, maxLines: null, expands: true, decoration: const InputDecoration(labelText: '正文（建议 100-1500 字）', alignLabelWithHint: true))),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: state.status == AiQaStatus.submitting ? null : () {
                        context.read<AiQaBloc>().add(AiQaSubmitAnswer(
                          qid: widget.qid,
                          title: _titleCtl.text.isEmpty ? null : _titleCtl.text,
                          content: _contentCtl.text,
                        ));
                      },
                      child: const Text('提交答案'),
                    ),
                  ])),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _contentCtl.dispose();
    _titleCtl.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 8: 注册路由 + AppRoutes 常量 + BuildContext 扩展**

50+ 路由按 feature 拆到 `lib/core/router/routes/*.dart` 16 个模块,**不直接编辑 `app_router.dart`**。
参照 `routes/ai_chat_routes.dart`,新建 `routes/ai_qa_routes.dart`:

```dart
// link2ur/lib/core/router/routes/ai_qa_routes.dart
import 'package:go_router/go_router.dart';
import '../../../features/ai_qa/views/ai_qa_detail_view.dart';
import '../../../features/ai_qa/views/ai_qa_answer_form_view.dart';
import '../app_routes.dart';

final List<GoRoute> aiQaRoutes = [
  GoRoute(
    path: AppRoutes.aiQaDetail,
    builder: (ctx, st) => AiQaDetailView(qid: int.parse(st.pathParameters['id']!)),
  ),
  GoRoute(
    path: AppRoutes.aiQaAnswer,
    builder: (ctx, st) => AiQaAnswerFormView(qid: int.parse(st.pathParameters['id']!)),
  ),
];
```

在 `app_routes.dart` 加常量 (参考现有 AppRoutes.taskDetail 等):
```dart
class AppRoutes {
  // ... 现有
  static const aiQaDetail = '/ai-qa/:id';
  static const aiQaAnswer = '/ai-qa/:id/answer';
}
```

在 `app_router.dart` (L194 后) 加 spread:
```dart
routes: [
  // ... 现有 routes
  ...aiQaRoutes,
],
```

(可选) 加 `BuildContext` extension 在 `go_router_extensions.dart`:
```dart
void goToAiQaDetail(int qid) => go('/ai-qa/$qid');
void goToAiQaAnswer(int qid) => go('/ai-qa/$qid/answer');
```

- [ ] **Step 9: 跑 flutter analyze + flutter gen-l10n**

Run:
```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH
cd link2ur
flutter gen-l10n
flutter analyze --no-fatal-infos
```
Expected: 0 errors

- [ ] **Step 10: 手动测试**

Run: `flutter run -d web-server`，然后浏览器手动 navigate 到 `/ai-qa/{id}`（id 用 admin 后台已 publish 的题），验证：
- M3 published 显示倒计时 + "我来答"
- M4 canceled 显示 banner
- M5 settled 显示前 3 名 (且 rewardPence > 0) 金边 + 奖金;floor 抹零导致 reward=0 的不贴金边

- [ ] **Step 11: Commit**

```bash
git add link2ur/lib/features/ai_qa/ link2ur/lib/data/models/ai_qa.dart link2ur/lib/data/repositories/ai_qa_repository.dart link2ur/lib/core/router/app_router.dart link2ur/lib/core/constants/api_endpoints.dart link2ur/lib/app_providers.dart link2ur/lib/l10n/ link2ur/lib/core/utils/error_localizer.dart
git commit -m "feat(ai-qa/flutter): M3/M4/M5/M6 详情+答题页 + Bloc + repository + l10n"
```

---

## 上线前 manual ops checklist (在 P0 验收前必做)

migration 237 给 `system_settings.ai_qa_default_expert_id` 留了**空字符串**占位 (Task 1 Step 1)。如果不补值,**第一道 admin draft publish 会直接 500** (FK 校验 `posed_by_expert_id NOT NULL REFERENCES experts(id)` 失败)。同样,migration 跑了不等于功能就绪 —— 下面 3 步是真实的"开第一道题之前必须做"checklist:

- [ ] **Step 1: linktest 先建一个 official Expert**

  在 admin web `/admin/experts` 新建一个 team:
  - name: `Link2Ur AI` (用户面 hero 显示这个名字)
  - is_official: `True` (db 字段)
  - 头像: AI 主题 (机器人 emoji or Link2Ur logo 变体)
  - 不需要 owner_user_id (官方账号)

  拿到 expert_id (类似 `EXP_xxx` 8 字符 ID)。

- [ ] **Step 2: 写进 SystemSettings**

  ```sql
  -- linktest 先做
  UPDATE system_settings
    SET setting_value = '<刚建的 expert_id>'
    WHERE setting_key = 'ai_qa_default_expert_id';
  ```

  或 admin web `/admin/settings` 找 `ai_qa_default_expert_id` 改值。

- [ ] **Step 3: verify draft 路径**

  linktest:
  ```bash
  curl -X POST https://linktest.up.railway.app/api/admin/ai-qa/drafts \
    -H "Authorization: Bearer <admin_token>" \
    -H "Content-Type: application/json" \
    -d '{
      "title": "smoke test",
      "content": "smoke",
      "target_forum_category_id": 1,
      "deadline": "2027-01-01T00:00:00Z"
    }'
  ```
  应返回 200 + 含 `posed_by_expert_id` 字段 (= step 1 expert_id)。如果返回 500/422 提示 "posed_by_expert_id required",回 step 2 检查 SystemSettings。

- [ ] **Step 4: linktest 验证通过后 prod 重做 step 1+2**

  prod 的 expert_id 跟 linktest 不一样,**不可直接 copy linktest 的 SystemSettings 值**。

---

## P0 验收清单（实施完所有 Task 后做）

- [ ] **跨层一致性**：按 CLAUDE.md `full-stack-consistency-check` skill 跑一遍 DB → schema → route → frontend
- [ ] **migration 顺序**：先 push DB migration（[`feedback_migration_before_deploy`]），再 push 代码
- [ ] **manual ops checklist**: 上面 4 步必须做完 (尤其 SystemSettings 不补值会触发 500)
- [ ] **linktest 端到端**：admin 建 draft → publish → 多用户答题 → 手动跑 close_expired + score_closed → admin 改分 → settle → 验证 wallet 余额 + audit log + leaderboard
- [ ] **scheduled_tasks 同步 Celery**：beat_schedule 加 ai_qa.close_expired + ai_qa.score_closed（[`feedback_scheduled_tasks_celery_sync`]）
- [ ] **prod 灰度**：linktest 验证完后 push main → Railway 自动部署 prod,**prod manual ops 单独重做一遍** → 观察 1 个完整周期

## P1/P2/P3+ 后续 plan（不在本 P0 范围）

- **P1**：Cycle 自动出题（candidate 生成 + admin 审核 + snapshot pre-fill）+ A1/A2 admin web 页面
- **P2**：Flutter 首页入口（M1 home discovery 卡片 + M2 列表）+ M7 leaderboard 页 + L3.c/d 勋章
- **P3+**：Admin 数据看板 + L3.e 首页 banner + L3.f Expert 邀请通道
