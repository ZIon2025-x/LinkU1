# TaskExpert Legacy 下线 Phase A 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Phase A — backend 读写路径从 `TaskExpert` / `FeaturedTaskExpert` 切换到 `Expert` / `FeaturedExpertV2`，并通过 migration 209 完成数据字段 catch-up；完成后 legacy 表仍存在但 Phase A 范围代码零引用（admin 端和模型定义留给 Phase B/C）。

**Architecture:** Read-First Swap — migration 209（单个大 DO block 原子同步所有字段 + ALTER TABLE 加 `success_rate`）先跑，读路径切 Expert / FeaturedExpertV2，再切写路径。单 PR 多 commit（按 10 个功能组分组），Railway 部署时自动跑 migration。

**Tech Stack:** Python 3.11 / FastAPI / SQLAlchemy 1.4 (sync + async) / PostgreSQL / pytest / Celery / Railway

**Spec:** `docs/superpowers/specs/2026-04-19-expert-unification-design.md` (v1.10)

---

## 文件结构地图

### 新建文件
- `backend/app/utils/expert_helpers.py` — 统一的 is_expert 判断 helper
- `backend/tests/test_expert_helpers.py` — helper 单测
- `backend/tests/migrations/__init__.py` — 测试子目录
- `backend/tests/migrations/test_209_sync_fields.py` — migration 209 单测
- `backend/migrations/209_sync_expert_fields_from_legacy.sql` — DO block 原子 migration

### 修改文件（按 spec §7.2-7.4 的功能组）

| 功能组 | 文件 | 改动描述 |
|-------|------|---------|
| is_expert 判断 | `backend/app/routers.py` | L4781-4791 + L5072-5082 换统一 helper |
| is_expert 判断 | `backend/app/secure_auth_routes.py` | L56-70 `_check_is_expert` 删除，所有调用点换 helper |
| 多人活动权限 | `backend/app/multi_participant_routes.py` | L31 import + L1619/1624/1887 换 helper |
| discovery 搜索 | `backend/app/discovery_routes.py` | L747-792 JOIN 从 TaskExpert 换成 Expert |
| 官方账户读 | `backend/app/admin_official_routes.py` | L58-69 / L202-219 |
| follow feed | `backend/app/follow_feed_routes.py` | L413/421/511/569 切 FeaturedExpertV2 |
| 服务申请 | `backend/app/user_service_application_routes.py` | L117 |
| AI 工具 | `backend/app/services/ai_tools.py` | 4 个 tool (L791/842/895/1101) |
| 官方账户写 | `backend/app/admin_official_routes.py` | L80-192 单写 Expert |
| 统计同步 | `backend/app/crud/user.py` | L55/87-110 |
| 定时任务 | `backend/app/crud/task_expert.py` | L46-195 |
| admin 检查 | `backend/app/crud/admin_ops.py` | L57/73-74 |
| 图片清理 | `backend/app/cleanup_tasks.py` | L1158-1166 / L1421-1428 化简 |

### Phase A 不改（§7.6 保留给 Phase B/C）
- `backend/app/routers.py` L12694-13576 admin 端点
- `backend/app/routers.py` L13751-13809 `_deprecated_get_public_task_experts` 死代码
- `backend/app/admin_task_expert_routes.py` 整文件
- `backend/app/models.py` TaskExpert / FeaturedTaskExpert / TaskExpertService 类定义
- `backend/app/main.py` L1242 / L1252 ORM 初始化 import
- `backend/app/service_public_routes.py` L11 注释
- `backend/app/expert_routes.py` L506 注释

---

## Task 0: 准备分支

**Files:**
- 无改动

- [ ] **Step 1：确认当前在 main 分支且干净**

Run:
```bash
cd F:/python_work/LinkU
git status
git branch --show-current
```
Expected: `main` 分支，working tree clean（或仅有 `.pyc` 等 ignore 文件）

- [ ] **Step 2：创建 feature 分支**

Run:
```bash
git checkout -b feature/expert-unification-phase-a
```
Expected: `Switched to a new branch 'feature/expert-unification-phase-a'`

---

## Task 1: 创建统一 helper `expert_helpers.py`（TDD）

**Files:**
- Create: `backend/app/utils/expert_helpers.py`
- Create: `backend/tests/test_expert_helpers.py`

- [ ] **Step 1：写失败的测试**

Create `backend/tests/test_expert_helpers.py`:

```python
"""expert_helpers 单元测试 — 验证 is_user_expert_sync 语义等价 legacy 双查"""

import pytest
from sqlalchemy.orm import Session

from app import models
from app.models_expert import Expert, ExpertMember
from app.utils.expert_helpers import (
    is_user_expert_sync,
    get_user_primary_expert_sync,
)


def _make_user(db: Session, user_id: str) -> models.User:
    user = models.User(
        id=user_id,
        name=f"User {user_id}",
        email=f"{user_id}@test.local",
    )
    db.add(user)
    db.flush()
    return user


def _make_expert_team(db: Session, expert_id: str, name: str = "Test Team") -> Expert:
    team = Expert(id=expert_id, name=name, status="active")
    db.add(team)
    db.flush()
    return team


def _add_member(db: Session, expert_id: str, user_id: str, role: str, status: str = "active"):
    member = ExpertMember(
        expert_id=expert_id,
        user_id=user_id,
        role=role,
        status=status,
    )
    db.add(member)
    db.flush()


def test_is_user_expert_sync_active_owner(db: Session):
    """active owner 应返回 True"""
    _make_user(db, "10000001")
    _make_expert_team(db, "T0000001")
    _add_member(db, "T0000001", "10000001", "owner", "active")
    assert is_user_expert_sync(db, "10000001") is True


def test_is_user_expert_sync_inactive(db: Session):
    """status='inactive' 的 member 应返回 False"""
    _make_user(db, "10000002")
    _make_expert_team(db, "T0000002")
    _add_member(db, "T0000002", "10000002", "owner", "inactive")
    assert is_user_expert_sync(db, "10000002") is False


def test_is_user_expert_sync_no_membership(db: Session):
    """完全没 ExpertMember 应返回 False"""
    _make_user(db, "10000003")
    assert is_user_expert_sync(db, "10000003") is False


def test_is_user_expert_sync_multi_teams_any_active(db: Session):
    """在 2 个团队,其一 active 应返回 True"""
    _make_user(db, "10000004")
    _make_expert_team(db, "T0000004")
    _make_expert_team(db, "T0000005", name="Other Team")
    _add_member(db, "T0000004", "10000004", "owner", "inactive")
    _add_member(db, "T0000005", "10000004", "member", "active")
    assert is_user_expert_sync(db, "10000004") is True


def test_get_user_primary_expert_returns_owner_team(db: Session):
    """用户是 team A 的 owner + team B 的 member → 返回 team A"""
    _make_user(db, "10000005")
    team_a = _make_expert_team(db, "T0000006", name="A")
    team_b = _make_expert_team(db, "T0000007", name="B")
    _add_member(db, "T0000006", "10000005", "owner", "active")
    _add_member(db, "T0000007", "10000005", "member", "active")

    result = get_user_primary_expert_sync(db, "10000005")
    assert result is not None
    assert result.id == team_a.id


def test_get_user_primary_expert_returns_none_when_no_owner(db: Session):
    """用户只是 member 不是 owner → 返回 None"""
    _make_user(db, "10000006")
    _make_expert_team(db, "T0000008")
    _add_member(db, "T0000008", "10000006", "member", "active")
    assert get_user_primary_expert_sync(db, "10000006") is None
```

- [ ] **Step 2：运行测试验证失败**

Run:
```bash
cd backend && python -m pytest tests/test_expert_helpers.py -v
```
Expected: FAIL — `ModuleNotFoundError: No module named 'app.utils.expert_helpers'`

- [ ] **Step 3：实现 helper**

Create `backend/app/utils/expert_helpers.py`:

```python
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
    """
    row = (
        db.query(ExpertMember)
        .filter(
            ExpertMember.user_id == user_id,
            ExpertMember.role == "owner",
            ExpertMember.status == "active",
        )
        .first()
    )
    if not row:
        return None
    return db.get(Expert, row.expert_id)
```

- [ ] **Step 4：运行测试验证通过**

Run:
```bash
cd backend && python -m pytest tests/test_expert_helpers.py -v
```
Expected: 6 passed

- [ ] **Step 5：Commit**

```bash
git add backend/app/utils/expert_helpers.py backend/tests/test_expert_helpers.py
git commit -m "feat(expert): add is_user_expert_sync / get_user_primary_expert_sync helpers

Phase A 准备：统一 TaskExpert OR ExpertMember 双查逻辑到单一 helper。
migration 185 已保证每个 active TaskExpert 有 ExpertMember(owner) 行，
所以单查 ExpertMember 语义等价。

Helper 位于 backend/app/utils/expert_helpers.py，带完整单测（6 个 case
覆盖 active/inactive/无成员/多团队/primary owner）。"
```

---

## Task 2: Migration 209 SQL + 单元测试（TDD）

**Files:**
- Create: `backend/migrations/209_sync_expert_fields_from_legacy.sql`
- Create: `backend/tests/migrations/__init__.py`
- Create: `backend/tests/migrations/test_209_sync_fields.py`

### Task 2.1: 创建 migration SQL

- [ ] **Step 1：创建 migration 文件**

Create `backend/migrations/209_sync_expert_fields_from_legacy.sql`:

```sql
-- 209: Phase A catch-up — 把 legacy TaskExpert / FeaturedTaskExpert 字段同步到 Expert / FeaturedExpertV2
--
-- 背景: migration 159/168/170/185 已把 task_experts → experts + expert_members 完成。
--       但 crud/user.py.sync_user_task_stats 只写 TaskExpert 不写 Expert,所以 Expert
--       的 rating/completed_tasks/... 从 159 之后一直停留在快照。migration 188 补过画像
--       字段但用 COALESCE 未覆盖 stats,并漏了 bio_en。
-- 目标:
--   1) ALTER experts 加 success_rate 列 (FTE 有但 Expert 无)
--   2) 从 task_experts 同步 rating/total_services/completed_tasks/is_official/official_badge/name/bio/avatar
--   3) 从 featured_task_experts 同步 completion_rate + success_rate (FTE 权威)
--   4) 从 featured_task_experts 补画像字段 (migration 188 漏项 bio_en 等)
--   5) featured_experts_v2 精简字段补刷
--
-- 执行机制: backend/app/db_migrations.py 的 execute_sql_file 会把 SQL 按 statement
--           拆分并逐条 commit。因此 ALTER 放 DO 外部 (幂等 IF NOT EXISTS),所有 UPDATE
--           + 验证打包进单个 DO 块 (psycopg2 当单 statement 执行),DO 内 RAISE EXCEPTION
--           会回滚整个 DO 块。

-- Schema 变更 (ALTER 不能放 DO 内部)
ALTER TABLE experts ADD COLUMN IF NOT EXISTS success_rate FLOAT NOT NULL DEFAULT 0.0;
CREATE INDEX IF NOT EXISTS ix_experts_success_rate ON experts(success_rate);

-- 数据回填 + 验证 (整个 DO 块作为单个 statement,RAISE EXCEPTION 回滚整个块)
DO $$
DECLARE
    orphan_count INTEGER;
    service_orphan_count INTEGER;
    stats_mismatch INTEGER;
    aggregate_mismatch INTEGER;
BEGIN
    -- 前置 orphan 检查: 任何 task_expert 没有映射即中止回滚
    SELECT COUNT(*) INTO orphan_count
    FROM task_experts te
    WHERE NOT EXISTS (SELECT 1 FROM _expert_id_migration_map m WHERE m.old_id = te.id);
    IF orphan_count > 0 THEN
        RAISE EXCEPTION '209: % orphan task_experts without mapping — run migration 185 first', orphan_count;
    END IF;

    -- 1. 统计字段 (TE 权威: rating/completed_tasks/total_services + is_official/official_badge)
    --    completion_rate 不从 TE 取 (TaskExpert 模型未定义,DB 列无维护)
    UPDATE experts e
    SET rating          = COALESCE(te.rating, e.rating),
        total_services  = COALESCE(te.total_services, e.total_services),
        completed_tasks = COALESCE(te.completed_tasks, e.completed_tasks),
        is_official     = COALESCE(te.is_official, e.is_official),
        official_badge  = COALESCE(te.official_badge, e.official_badge),
        updated_at      = NOW()
    FROM _expert_id_migration_map m
    JOIN task_experts te ON te.id = m.old_id
    WHERE e.id = m.new_id
      AND (te.rating IS DISTINCT FROM e.rating
        OR te.total_services IS DISTINCT FROM e.total_services
        OR te.completed_tasks IS DISTINCT FROM e.completed_tasks);

    -- 2. 基础展示字段 (updated_at 较新一侧为准)
    UPDATE experts e
    SET name   = CASE WHEN te.updated_at > e.updated_at
                      THEN COALESCE(te.expert_name, e.name) ELSE e.name END,
        bio    = CASE WHEN te.updated_at > e.updated_at
                      THEN COALESCE(te.bio, e.bio) ELSE e.bio END,
        avatar = CASE WHEN te.updated_at > e.updated_at
                      THEN COALESCE(te.avatar, e.avatar) ELSE e.avatar END
    FROM _expert_id_migration_map m
    JOIN task_experts te ON te.id = m.old_id
    WHERE e.id = m.new_id;

    -- 3. 聚合指标回填 (FTE 权威 — 由 crud/task_expert.py.update_task_expert_bio 聚合写入)
    UPDATE experts e
    SET completion_rate = COALESCE(fte.completion_rate, e.completion_rate),
        success_rate    = COALESCE(fte.success_rate, e.success_rate)
    FROM _expert_id_migration_map m
    JOIN featured_task_experts fte ON fte.user_id = m.old_id
    WHERE e.id = m.new_id
      AND (fte.completion_rate IS DISTINCT FROM e.completion_rate
        OR fte.success_rate    IS DISTINCT FROM e.success_rate);

    -- 4. 画像字段补刷 (补 migration 188 漏项; COALESCE 保留 Expert 已有值)
    --    WHERE 仅按 id 匹配,无 IS DISTINCT FROM 过滤 — 重跑会 touch 所有行的 updated_at,
    --    但值不变。折衷选择:写 ~12 字段的 IS DISTINCT FROM 条件串可读性差。
    UPDATE experts e
    SET bio_en             = COALESCE(e.bio_en, fte.bio_en),
        expertise_areas    = COALESCE(e.expertise_areas,
            CASE WHEN fte.expertise_areas IS NOT NULL AND fte.expertise_areas <> ''
                 THEN fte.expertise_areas::jsonb END),
        expertise_areas_en = COALESCE(e.expertise_areas_en,
            CASE WHEN fte.expertise_areas_en IS NOT NULL AND fte.expertise_areas_en <> ''
                 THEN fte.expertise_areas_en::jsonb END),
        featured_skills    = COALESCE(e.featured_skills,
            CASE WHEN fte.featured_skills IS NOT NULL AND fte.featured_skills <> ''
                 THEN fte.featured_skills::jsonb END),
        featured_skills_en = COALESCE(e.featured_skills_en,
            CASE WHEN fte.featured_skills_en IS NOT NULL AND fte.featured_skills_en <> ''
                 THEN fte.featured_skills_en::jsonb END),
        achievements       = COALESCE(e.achievements,
            CASE WHEN fte.achievements IS NOT NULL AND fte.achievements <> ''
                 THEN fte.achievements::jsonb END),
        achievements_en    = COALESCE(e.achievements_en,
            CASE WHEN fte.achievements_en IS NOT NULL AND fte.achievements_en <> ''
                 THEN fte.achievements_en::jsonb END),
        response_time      = COALESCE(e.response_time, fte.response_time),
        response_time_en   = COALESCE(e.response_time_en, fte.response_time_en),
        category           = COALESCE(e.category, fte.category),
        location           = COALESCE(e.location, fte.location),
        display_order      = CASE WHEN e.display_order = 0
                                  THEN COALESCE(fte.display_order, 0)
                                  ELSE e.display_order END,
        is_verified        = CASE WHEN e.is_verified = false
                                  THEN (COALESCE(fte.is_verified, 0) <> 0)
                                  ELSE e.is_verified END,
        user_level         = CASE WHEN e.user_level = 'normal'
                                  THEN COALESCE(fte.user_level, 'normal')
                                  ELSE e.user_level END
    FROM featured_task_experts fte
    JOIN _expert_id_migration_map m ON m.old_id = fte.user_id
    WHERE e.id = m.new_id;

    -- 5. FeaturedExpertV2 精简字段补刷
    UPDATE featured_experts_v2 fv2
    SET category      = COALESCE(fv2.category, fte.category),
        is_featured   = CASE WHEN fv2.is_featured = false
                             THEN COALESCE(fte.is_featured, 0) <> 0
                             ELSE fv2.is_featured END,
        display_order = CASE WHEN fv2.display_order = 0
                             THEN COALESCE(fte.display_order, 0)
                             ELSE fv2.display_order END
    FROM _expert_id_migration_map m
    JOIN featured_task_experts fte ON fte.user_id = m.old_id
    WHERE fv2.expert_id = m.new_id;

    -- 6. 后置验证 (WARNING 级别,不中止)
    SELECT COUNT(*) INTO service_orphan_count
    FROM task_expert_services
    WHERE service_type = 'expert' AND owner_id IS NULL;
    IF service_orphan_count > 0 THEN
        RAISE WARNING '209: % task_expert_services with service_type=expert have NULL owner_id', service_orphan_count;
    END IF;

    SELECT COUNT(*) INTO stats_mismatch
    FROM _expert_id_migration_map m
    JOIN task_experts te ON te.id = m.old_id
    JOIN experts e ON e.id = m.new_id
    WHERE te.rating IS DISTINCT FROM e.rating
       OR te.completed_tasks IS DISTINCT FROM e.completed_tasks;
    IF stats_mismatch > 0 THEN
        RAISE WARNING '209: % experts still have stats mismatch — manual check', stats_mismatch;
    END IF;

    SELECT COUNT(*) INTO aggregate_mismatch
    FROM _expert_id_migration_map m
    JOIN featured_task_experts fte ON fte.user_id = m.old_id
    JOIN experts e ON e.id = m.new_id
    WHERE fte.completion_rate IS DISTINCT FROM e.completion_rate
       OR fte.success_rate    IS DISTINCT FROM e.success_rate;
    IF aggregate_mismatch > 0 THEN
        RAISE WARNING '209: % experts completion_rate/success_rate mismatch with FTE', aggregate_mismatch;
    END IF;

    RAISE NOTICE '209 complete: orphans=%, service_orphans=%, stats_mismatch=%, aggregate_mismatch=%',
        orphan_count, service_orphan_count, stats_mismatch, aggregate_mismatch;
END $$;
```

### Task 2.2: 单元测试

- [ ] **Step 2：创建测试模块初始化文件**

Create `backend/tests/migrations/__init__.py`:

```python
"""Migration 单元测试。需要真实 PostgreSQL (TEST_DATABASE_URL 或 DATABASE_URL)。
SQLite fallback 不支持 DO block / JSONB cast / IS DISTINCT FROM 语法。
"""
```

- [ ] **Step 3：创建 migration 209 的测试**

Create `backend/tests/migrations/test_209_sync_fields.py`:

```python
"""Migration 209 单元测试 — 验证字段回填策略、幂等性、orphan EXCEPTION 行为。

测试假设:
- DATABASE_URL / TEST_DATABASE_URL 指向一个已跑到 migration 208 的真实 PG 实例
- CI 里由 service 提供；本地开发者需自行运行 PG
- SQLite fallback 跳过（DO block + JSONB cast 不兼容）

使用 conftest.py 的 db fixture (rollback-based isolation)。每个 test 自
插入 legacy 数据 → 直接执行 209 SQL → 断言 → 由 fixture rollback。
"""
from decimal import Decimal
from pathlib import Path

import pytest
from sqlalchemy import text
from sqlalchemy.orm import Session

from app import models
from app.models_expert import Expert, ExpertMember

MIGRATION_209_PATH = (
    Path(__file__).resolve().parents[2] / "migrations" / "209_sync_expert_fields_from_legacy.sql"
)


def _pg_only(db: Session):
    """SQLite 不支持 DO block + JSONB cast;skip 该测试。"""
    dialect = db.bind.dialect.name
    if dialect != "postgresql":
        pytest.skip(f"migration 209 test requires PostgreSQL, got {dialect}")


def _run_209(db: Session) -> None:
    """把 SQL 文件分 statement 执行 (对齐 execute_sql_file 行为)。"""
    sql = MIGRATION_209_PATH.read_text(encoding="utf-8")
    # execute_sql_file 用 split_sql_statements,但 DO 块是一个整体;简化用 execute 整个文件
    # PG 的 psycopg2 cursor 对多 statement 单调用会按 \n; 拆分执行
    raw = db.connection().connection
    with raw.cursor() as cur:
        cur.execute(sql)


def _make_user(db: Session, user_id: str) -> models.User:
    u = models.User(id=user_id, name=f"U{user_id}", email=f"{user_id}@test.local")
    db.add(u)
    db.flush()
    return u


def _make_legacy_te(db: Session, user_id: str, **kwargs) -> models.TaskExpert:
    te = models.TaskExpert(
        id=user_id,
        expert_name=kwargs.get("expert_name", f"TE {user_id}"),
        bio=kwargs.get("bio"),
        avatar=kwargs.get("avatar"),
        status=kwargs.get("status", "active"),
        rating=kwargs.get("rating", Decimal("0.00")),
        total_services=kwargs.get("total_services", 0),
        completed_tasks=kwargs.get("completed_tasks", 0),
        is_official=kwargs.get("is_official", False),
        official_badge=kwargs.get("official_badge"),
    )
    db.add(te)
    db.flush()
    return te


def _make_legacy_fte(db: Session, user_id: str, **kwargs) -> models.FeaturedTaskExpert:
    fte = models.FeaturedTaskExpert(
        id=user_id,
        user_id=user_id,
        name=kwargs.get("name", f"FTE {user_id}"),
        bio_en=kwargs.get("bio_en"),
        avg_rating=kwargs.get("avg_rating", 0.0),
        completed_tasks=kwargs.get("completed_tasks", 0),
        total_tasks=kwargs.get("total_tasks", 0),
        completion_rate=kwargs.get("completion_rate", 0.0),
        success_rate=kwargs.get("success_rate", 0.0),
        expertise_areas=kwargs.get("expertise_areas"),
        expertise_areas_en=kwargs.get("expertise_areas_en"),
        response_time=kwargs.get("response_time"),
        category=kwargs.get("category"),
        location=kwargs.get("location"),
        is_verified=kwargs.get("is_verified", 0),
        created_by=kwargs.get("created_by", "ADMIN"),
    )
    db.add(fte)
    db.flush()
    return fte


def _make_expert_via_map(db: Session, user_id: str, new_id: str, **kwargs) -> Expert:
    """创建 Expert + ExpertMember(owner) + 写映射,模拟 migration 159/185 的产物。"""
    expert = Expert(
        id=new_id,
        name=kwargs.get("name", f"Team for {user_id}"),
        status="active",
        rating=kwargs.get("rating", Decimal("0.00")),
        total_services=kwargs.get("total_services", 0),
        completed_tasks=kwargs.get("completed_tasks", 0),
        completion_rate=kwargs.get("completion_rate", 0.0),
        # success_rate 列由 209 的 ALTER 添加; Expert model 已含该字段 default 0.0
    )
    db.add(expert)
    db.add(ExpertMember(expert_id=new_id, user_id=user_id, role="owner", status="active"))
    db.execute(
        text(
            "INSERT INTO _expert_id_migration_map (old_id, new_id) "
            "VALUES (:o, :n) ON CONFLICT DO NOTHING"
        ),
        {"o": user_id, "n": new_id},
    )
    db.flush()
    return expert


def test_209_syncs_stats_from_task_experts(db: Session):
    """TE 的 rating / total_services / completed_tasks 应覆盖到 Expert"""
    _pg_only(db)
    _make_user(db, "20000001")
    _make_legacy_te(
        db,
        "20000001",
        rating=Decimal("4.50"),
        total_services=10,
        completed_tasks=15,
    )
    _make_expert_via_map(db, "20000001", "E0000001")
    _run_209(db)

    expert = db.get(Expert, "E0000001")
    db.refresh(expert)
    assert expert.rating == Decimal("4.50")
    assert expert.total_services == 10
    assert expert.completed_tasks == 15


def test_209_syncs_completion_rate_from_fte(db: Session):
    """completion_rate 权威源是 FTE (TE 无此字段,模型未定义)"""
    _pg_only(db)
    _make_user(db, "20000002")
    _make_legacy_te(db, "20000002")
    _make_legacy_fte(db, "20000002", completion_rate=87.5)
    _make_expert_via_map(db, "20000002", "E0000002", completion_rate=0.0)
    _run_209(db)

    expert = db.get(Expert, "E0000002")
    db.refresh(expert)
    assert expert.completion_rate == pytest.approx(87.5)


def test_209_syncs_success_rate(db: Session):
    """success_rate 列由 209 的 ALTER 添加,然后从 FTE 回填"""
    _pg_only(db)
    _make_user(db, "20000003")
    _make_legacy_te(db, "20000003")
    _make_legacy_fte(db, "20000003", success_rate=92.3)
    _make_expert_via_map(db, "20000003", "E0000003")
    _run_209(db)

    row = db.execute(
        text("SELECT success_rate FROM experts WHERE id = :id"),
        {"id": "E0000003"},
    ).first()
    assert row is not None
    assert row[0] == pytest.approx(92.3)


def test_209_backfills_bio_en_for_null_only(db: Session):
    """COALESCE 策略: Expert.bio_en 为空时从 FTE 取;非空时保留"""
    _pg_only(db)
    _make_user(db, "20000004")
    _make_legacy_te(db, "20000004")
    _make_legacy_fte(db, "20000004", bio_en="FTE english bio")
    expert = _make_expert_via_map(db, "20000004", "E0000004")
    expert.bio_en = None
    db.flush()

    _make_user(db, "20000005")
    _make_legacy_te(db, "20000005")
    _make_legacy_fte(db, "20000005", bio_en="Should not overwrite")
    expert_existing = _make_expert_via_map(db, "20000005", "E0000005")
    expert_existing.bio_en = "Existing bio should stay"
    db.flush()

    _run_209(db)

    db.refresh(expert)
    db.refresh(expert_existing)
    assert expert.bio_en == "FTE english bio"
    assert expert_existing.bio_en == "Existing bio should stay"


def test_209_preserves_newer_expert_name(db: Session):
    """Expert.updated_at 更新过 (即 admin 改过 name) → TE 的 expert_name 不覆盖"""
    _pg_only(db)
    _make_user(db, "20000006")
    te = _make_legacy_te(db, "20000006", expert_name="OLD NAME")
    # 手动把 TE 的 updated_at 设为较早时间
    db.execute(
        text("UPDATE task_experts SET updated_at = NOW() - INTERVAL '1 day' WHERE id = :id"),
        {"id": "20000006"},
    )
    expert = _make_expert_via_map(db, "20000006", "E0000006", name="NEW NAME")
    db.flush()
    _run_209(db)
    db.refresh(expert)
    assert expert.name == "NEW NAME"


def test_209_idempotent(db: Session):
    """跑两次应无副作用"""
    _pg_only(db)
    _make_user(db, "20000007")
    _make_legacy_te(db, "20000007", rating=Decimal("3.25"), completed_tasks=5)
    _make_expert_via_map(db, "20000007", "E0000007")

    _run_209(db)
    expert = db.get(Expert, "E0000007")
    db.refresh(expert)
    first_updated_at = expert.updated_at
    assert expert.rating == Decimal("3.25")

    _run_209(db)
    db.refresh(expert)
    assert expert.rating == Decimal("3.25")
    # step 1 的 IS DISTINCT FROM 过滤保证第二次不 touch (updated_at 不变)
    # step 4 无此过滤会 touch updated_at — 这是 R13 已知折衷,不在此断言


def test_209_raises_on_orphan_task_experts(db: Session):
    """有 task_experts 行无映射 → DO 块 RAISE EXCEPTION 回滚"""
    _pg_only(db)
    _make_user(db, "20000008")
    _make_legacy_te(db, "20000008")
    # 不创建映射

    # execute 在 psycopg2 层会抛异常
    import psycopg2
    with pytest.raises((psycopg2.errors.RaiseException, Exception)) as exc_info:
        _run_209(db)
    assert "orphan task_experts" in str(exc_info.value).lower() or \
           "209" in str(exc_info.value)
```

- [ ] **Step 4：运行测试验证失败**

Run:
```bash
cd backend && python -m pytest tests/migrations/test_209_sync_fields.py -v
```
Expected: FAIL or ERROR — `FileNotFoundError` 或 SQL 执行失败（SQL 文件如 Step 1 已创建，应直接跑通；若 SQL 有语法错误会在此暴露）

**注意**：若在 Windows 本地无 PostgreSQL 而走 SQLite，所有测试会 `skip`。这不算失败。CI 里走 PG 应 PASS。

- [ ] **Step 5：修正 SQL 直到 PG 下全绿**

若测试失败：
- 读 error message 定位到 SQL 里具体语法错
- 修正 `backend/migrations/209_sync_expert_fields_from_legacy.sql`
- 重跑测试

若本地无 PG：记录跳过，待 CI 验证。

- [ ] **Step 6：Commit**

```bash
git add backend/migrations/209_sync_expert_fields_from_legacy.sql backend/tests/migrations/
git commit -m "feat(migration): 209 sync expert fields from legacy

Phase A 准备：单 DO block 原子回填 Expert / FeaturedExpertV2。
- ALTER TABLE experts ADD COLUMN success_rate (幂等 IF NOT EXISTS)
- 从 task_experts 取 rating/total_services/completed_tasks 等 TE 权威字段
- 从 featured_task_experts 取 completion_rate/success_rate (FTE 权威)
- 补 migration 188 遗漏的 bio_en 等画像字段
- 前置 orphan 检查 RAISE EXCEPTION 回滚整个 DO
- 后置 WARNING 汇总 (service_orphan / stats_mismatch / aggregate_mismatch)

单测覆盖:统计回填、completion_rate/success_rate FTE 权威、bio_en COALESCE
策略、newer updated_at 保留、幂等、orphan EXCEPTION。"
```

---

## Task 3: is_expert 判断 — 替换双查为统一 helper（Commit #1：读路径）

**Files:**
- Modify: `backend/app/routers.py:4781-4791`
- Modify: `backend/app/routers.py:5072-5082`
- Modify: `backend/app/secure_auth_routes.py:56-70`
- Modify: `backend/app/multi_participant_routes.py:31, 1619-1624, 1887`

- [ ] **Step 1：替换 `routers.py:4781-4791` (get_my_profile)**

在 `backend/app/routers.py` 找到 L4781-4791 这段（`get_my_profile` 里 `is_expert` 判断）：

OLD:
```python
        from app.models import TaskExpert
        from app.models_expert import ExpertMember
        task_expert = db.query(TaskExpert).filter(
            TaskExpert.id == current_user.id,
            TaskExpert.status == "active"
        ).first()
        expert_member = db.query(ExpertMember).filter(
            ExpertMember.user_id == current_user.id,
            ExpertMember.status == "active"
        ).first()
        is_expert = (task_expert is not None) or (expert_member is not None)
```

NEW:
```python
        from app.utils.expert_helpers import is_user_expert_sync
        is_expert = is_user_expert_sync(db, current_user.id)
```

- [ ] **Step 2：替换 `routers.py:5072-5082` (get_user_profile)**

OLD:
```python
    from app.models import TaskExpert
    from app.models_expert import ExpertMember
    task_expert = db.query(TaskExpert).filter(
        TaskExpert.id == user_id,
        TaskExpert.status == "active"
    ).first()
    expert_member = db.query(ExpertMember).filter(
        ExpertMember.user_id == user_id,
        ExpertMember.status == "active"
    ).first()
    is_expert = (task_expert is not None) or (expert_member is not None)
```

NEW:
```python
    from app.utils.expert_helpers import is_user_expert_sync
    is_expert = is_user_expert_sync(db, user_id)
```

- [ ] **Step 3：替换 `secure_auth_routes.py:56-70` 整个 `_check_is_expert` 函数**

OLD:
```python
def _check_is_expert(db: Session, user_id: str) -> bool:
    """Check if user is an expert (legacy TaskExpert or new ExpertMember)."""
    from app.models import TaskExpert
    from app.models_expert import ExpertMember
    task_expert = db.query(TaskExpert).filter(
        TaskExpert.id == user_id,
        TaskExpert.status == "active"
    ).first()
    if task_expert:
        return True
    expert_member = db.query(ExpertMember).filter(
        ExpertMember.user_id == user_id,
        ExpertMember.status == "active"
    ).first()
    return expert_member is not None
```

NEW:
```python
def _check_is_expert(db: Session, user_id: str) -> bool:
    """Check if user is an expert (active ExpertMember of any team)."""
    from app.utils.expert_helpers import is_user_expert_sync
    return is_user_expert_sync(db, user_id)
```

**注意**：函数名保留不删（有调用者），只替换内部实现。

- [ ] **Step 4：修改 `multi_participant_routes.py:31` 的 import**

OLD (L31):
```python
from app.models import TaskExpertService, TaskExpert
```

NEW:
```python
from app.models import TaskExpertService  # TaskExpert 已移除,is_expert 判断改走 utils.expert_helpers
```

- [ ] **Step 5：修改 `multi_participant_routes.py:1619-1624` (delete_expert_activity)**

OLD:
```python
    from app.models import TaskExpert, Task, TaskAuditLog
    import logging
    logger = logging.getLogger(__name__)
    
    # 验证用户是否为任务达人
    expert = db.query(TaskExpert).filter(TaskExpert.id == current_user.id).first()
    if not expert or expert.status != "active":
        raise HTTPException(status_code=403, detail="User is not an active task expert")
```

NEW:
```python
    from app.models import Task, TaskAuditLog
    from app.utils.expert_helpers import is_user_expert_sync
    import logging
    logger = logging.getLogger(__name__)

    # 验证用户是否为任务达人
    if not is_user_expert_sync(db, current_user.id):
        raise HTTPException(status_code=403, detail="User is not an active task expert")
```

- [ ] **Step 6：修改 `multi_participant_routes.py:1887` (create_expert_activity)**

OLD:
```python
    # 验证用户是否为任务达人
    expert = db.query(TaskExpert).filter(TaskExpert.id == current_user.id).first()
    if not expert or expert.status != "active":
        raise HTTPException(status_code=403, detail="User is not an active task expert")
```

NEW:
```python
    # 验证用户是否为任务达人
    from app.utils.expert_helpers import is_user_expert_sync
    if not is_user_expert_sync(db, current_user.id):
        raise HTTPException(status_code=403, detail="User is not an active task expert")
```

- [ ] **Step 7：跑现有测试确保没破坏**

Run:
```bash
cd backend && python -m pytest tests/test_expert_helpers.py -v
```
Expected: 6 passed

Run:
```bash
cd backend && python -m pytest tests/ -v -k "expert_permission or profile" --tb=short
```
Expected: 相关 test 全绿（或至少没有新增失败）

- [ ] **Step 8：Commit**

```bash
git add backend/app/routers.py backend/app/secure_auth_routes.py backend/app/multi_participant_routes.py
git commit -m "refactor(expert): 统一 is_expert 判断到 expert_helpers

替换 3 个文件 5 处 'TaskExpert OR ExpertMember' 双查逻辑为 is_user_expert_sync:
- routers.py:4781-4791 get_my_profile
- routers.py:5072-5082 get_user_profile
- secure_auth_routes.py:56-70 _check_is_expert (保留函数签名,替换内部实现)
- multi_participant_routes.py:1619/1887 活动权限检查

迁移 185 保证每个 active TaskExpert 有 ExpertMember(owner) 行,
单查 ExpertMember 语义等价。"
```

---

## Task 4: discovery_routes.py JOIN 改造（Commit #2）

**Files:**
- Modify: `backend/app/discovery_routes.py:745-810`

- [ ] **Step 1：替换 `_fetch_expert_services` 函数的 JOIN 逻辑**

找到 L745-810 函数体，整体替换：

OLD (L745-810 的 select/join 段):
```python
async def _fetch_expert_services(db: AsyncSession, limit: int) -> list:
    """获取达人服务 + 个人服务推荐
    注意:
    - TaskExpertService 用 service_name 而非 name
    - TaskExpertService 用 images (JSONB) 而非 cover_image
    - TaskExpertService 用 status == 'active' 而非 is_active == True
    - TaskExpert 用 rating 而非 average_rating
    - service_type='expert' 通过 expert_id JOIN TaskExpert → User
    - service_type='personal' 通过 user_id 直接 JOIN User（无 TaskExpert）
    """
    # 给个人服务 owner 用户起别名，避免与达人用户表冲突
    PersonalOwner = aliased(models.User, name="personal_owner")

    query = (
        select(
            models.TaskExpertService.id,
            models.TaskExpertService.service_type,
            models.TaskExpertService.service_name,
            models.TaskExpertService.service_name_en,
            models.TaskExpertService.service_name_zh,
            models.TaskExpertService.description,
            models.TaskExpertService.description_en,
            models.TaskExpertService.description_zh,
            models.TaskExpertService.category,
            models.TaskExpertService.location.label("service_location"),
            models.TaskExpertService.images.label("service_images"),
            models.TaskExpertService.base_price,
            models.TaskExpertService.currency,
            models.TaskExpertService.user_id.label("personal_owner_id"),
            models.TaskExpertService.created_at,
            models.TaskExpert.id.label("expert_user_id"),
            models.TaskExpert.expert_name.label("expert_display_name"),
            models.TaskExpert.avatar.label("expert_avatar_url"),
            models.TaskExpert.rating.label("expert_rating"),
            models.User.name.label("user_name"),
            models.User.avatar.label("user_avatar_url"),
            PersonalOwner.name.label("personal_owner_name"),
            PersonalOwner.avatar.label("personal_owner_avatar"),
        )
        .outerjoin(models.TaskExpert, models.TaskExpertService.expert_id == models.TaskExpert.id)
        .outerjoin(models.User, models.TaskExpert.id == models.User.id)
        .outerjoin(PersonalOwner, models.TaskExpertService.user_id == PersonalOwner.id)
        .where(models.TaskExpertService.status == "active")
        .order_by(desc(models.TaskExpertService.created_at))
        .limit(limit)
    )
```

NEW:
```python
async def _fetch_expert_services(db: AsyncSession, limit: int) -> list:
    """获取达人服务 + 个人服务推荐
    注意:
    - TaskExpertService 用 service_name 而非 name
    - TaskExpertService 用 images (JSONB) 而非 cover_image
    - TaskExpertService 用 status == 'active' 而非 is_active == True
    - Expert 用 rating 而非 average_rating
    - service_type='expert' 通过 owner_type='expert' + owner_id JOIN Expert (团队)
    - service_type='personal' 通过 user_id 直接 JOIN User (无 Expert)
    - 返回 JSON key expert_id/user_id 对 expert 服务现填 team_id (Phase A 语义迁移,
      修复现有 /api/experts/{id} 404 bug; 详见 spec §7.5)
    """
    from app.models_expert import Expert

    # 给个人服务 owner 用户起别名，避免与达人团队可能的 User JOIN 冲突（本实现无此 JOIN,保留别名兼容原结构)
    PersonalOwner = aliased(models.User, name="personal_owner")

    query = (
        select(
            models.TaskExpertService.id,
            models.TaskExpertService.service_type,
            models.TaskExpertService.service_name,
            models.TaskExpertService.service_name_en,
            models.TaskExpertService.service_name_zh,
            models.TaskExpertService.description,
            models.TaskExpertService.description_en,
            models.TaskExpertService.description_zh,
            models.TaskExpertService.category,
            models.TaskExpertService.location.label("service_location"),
            models.TaskExpertService.images.label("service_images"),
            models.TaskExpertService.base_price,
            models.TaskExpertService.currency,
            models.TaskExpertService.user_id.label("personal_owner_id"),
            models.TaskExpertService.created_at,
            Expert.id.label("expert_team_id"),
            Expert.name.label("expert_display_name"),
            Expert.avatar.label("expert_avatar_url"),
            Expert.rating.label("expert_rating"),
            PersonalOwner.name.label("personal_owner_name"),
            PersonalOwner.avatar.label("personal_owner_avatar"),
        )
        .outerjoin(
            Expert,
            and_(
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == Expert.id,
            ),
        )
        .outerjoin(PersonalOwner, models.TaskExpertService.user_id == PersonalOwner.id)
        .where(models.TaskExpertService.status == "active")
        .order_by(desc(models.TaskExpertService.created_at))
        .limit(limit)
    )
```

- [ ] **Step 2：更新下方 items.append 构造里的字段读取**

找到 L795 之后的循环（原代码约 L794-845），修改 `owner_id` 赋值逻辑：

OLD（内部 for row 循环里）:
```python
        if is_personal:
            display_name = row.personal_owner_name
            display_avatar = row.personal_owner_avatar
            owner_id = str(row.personal_owner_id) if row.personal_owner_id else None
            expert_id_val = None
        else:
            display_name = row.expert_display_name or row.user_name
            display_avatar = row.expert_avatar_url or row.user_avatar_url
            owner_id = str(row.expert_user_id) if row.expert_user_id else None
            expert_id_val = owner_id
```

NEW:
```python
        if is_personal:
            display_name = row.personal_owner_name
            display_avatar = row.personal_owner_avatar
            owner_id = str(row.personal_owner_id) if row.personal_owner_id else None
            expert_id_val = None
        else:
            # Expert 服务: team_id 作为 expert_id / user_id JSON 值 (spec §7.5)
            display_name = row.expert_display_name
            display_avatar = row.expert_avatar_url
            owner_id = str(row.expert_team_id) if row.expert_team_id else None
            expert_id_val = owner_id
```

**注意**：删除对 `row.user_name` / `row.user_avatar_url` 的引用 — Expert 没有 User JOIN，Expert.name / Expert.avatar 本身足够。

- [ ] **Step 3：检查 `and_` 是否已 import**

Run:
```bash
grep -n "^from sqlalchemy\|^import sqlalchemy\|from sqlalchemy import" backend/app/discovery_routes.py | head
```

若没有 `and_` 在 import list，在文件顶部加。通常 SQLAlchemy 的 import 行会有类似 `from sqlalchemy import select, and_, or_, ...`，确保 `and_` 在内。

- [ ] **Step 4：文件内语法检查**

Run:
```bash
cd backend && python -c "import app.discovery_routes" 2>&1 | head
```
Expected: 无输出或仅 warning；有 SyntaxError / ImportError 则修复

- [ ] **Step 5：Commit**

```bash
git add backend/app/discovery_routes.py
git commit -m "refactor(discovery): 切 expert 服务 JOIN 到 Expert 团队

_fetch_expert_services 改为用 owner_type='expert' + owner_id JOIN Expert
(不再走 TaskExpertService.expert_id → TaskExpert → User legacy 链).

JSON 返回的 expert_id/user_id 对 expert 服务现填 team_id,和 /api/experts/{id}
端点语义一致。详见 spec §7.5: 这实际上修复了现有的 /api/experts/{user_id}
404 bug (Flutter 跳转逻辑已依赖 team_id)."
```

---

## Task 5: 官方账户读路径（Commit #3）

**Files:**
- Modify: `backend/app/admin_official_routes.py:56-69, 195-219`

- [ ] **Step 1：替换 `_get_official_expert` helper**

OLD (L56-69):
```python
async def _get_official_expert(db: AsyncSession) -> models.TaskExpert:
    """获取官方达人账号，不存在则报错"""
    result = await db.execute(
        select(models.TaskExpert).where(models.TaskExpert.is_official == True)
    )
    expert = result.scalar_one_or_none()
    if not expert:
        raise HTTPException(
            status_code=400,
            detail="尚未设置官方账号，请先调用 /api/admin/official/account/setup"
        )
    return expert
```

NEW:
```python
async def _get_official_expert(db: AsyncSession):
    """获取官方达人团队，不存在则报错"""
    from app.models_expert import Expert
    result = await db.execute(
        select(Expert).where(Expert.is_official == True).limit(1)
    )
    expert = result.scalar_one_or_none()
    if not expert:
        raise HTTPException(
            status_code=400,
            detail="尚未设置官方账号，请先调用 /api/admin/official/account/setup"
        )
    return expert
```

- [ ] **Step 2：替换 `get_official_account` 实现**

找到 L195-219 `get_official_account` 的实现段：

OLD:
```python
    result = await db.execute(
        select(models.TaskExpert, models.User)
        .join(models.User, models.User.id == models.TaskExpert.id)
        .where(models.TaskExpert.is_official == True)
    )
    row = result.first()
    if not row:
        return {"official_account": None}
    expert, user = row
    return {
        "official_account": {
            "user_id": expert.id,
            "name": user.name,
            "badge": expert.official_badge,
            "avatar": expert.avatar,
            "status": expert.status,
        }
    }
```

NEW:
```python
    from app.models_expert import Expert, ExpertMember
    result = await db.execute(
        select(Expert).where(Expert.is_official == True).limit(1)
    )
    expert = result.scalar_one_or_none()
    if not expert:
        return {"official_account": None}

    # 从 ExpertMember(owner) JOIN User 取代表用户
    owner_row = await db.execute(
        select(ExpertMember, models.User)
        .join(models.User, models.User.id == ExpertMember.user_id)
        .where(
            ExpertMember.expert_id == expert.id,
            ExpertMember.role == "owner",
            ExpertMember.status == "active",
        )
        .limit(1)
    )
    rec = owner_row.first()
    if not rec:
        # 数据异常(Expert 存在但无 active owner),不崩
        return {"official_account": None}
    _member, owner_user = rec
    return {
        "official_account": {
            "user_id": owner_user.id,      # 保持兼容 key: 填代表 user 的 id
            "name": owner_user.name,
            "badge": expert.official_badge,
            "avatar": expert.avatar,
            "status": expert.status,
        }
    }
```

- [ ] **Step 3：语法检查**

Run:
```bash
cd backend && python -c "import app.admin_official_routes" 2>&1 | head
```
Expected: 无输出

- [ ] **Step 4：Commit**

```bash
git add backend/app/admin_official_routes.py
git commit -m "refactor(official): 官方账户读路径切到 Expert 团队

_get_official_expert + get_official_account 改读 experts.is_official=true
+ ExpertMember(owner) JOIN User 取代表用户.

对外 API 返回 schema 不变 (user_id/name/badge/avatar/status) -
admin panel 无感知. 若多行 is_official=true 由于历史数据, .limit(1)
取任意一个 (Phase A 不强制唯一约束, 见 R11)."
```

---

## Task 6: follow feed 展示切到 FeaturedExpertV2（Commit #4）

**Files:**
- Modify: `backend/app/follow_feed_routes.py:413, 421, 511, 569`

- [ ] **Step 1：看上下文确认 alias 用法**

Run:
```bash
grep -n "FeaturedTaskExpert\|aliased" backend/app/follow_feed_routes.py | head -20
```

记录 L421 和 L569 的 `FTE = aliased(models.FeaturedTaskExpert)` 两处 alias 在用于什么 JOIN。

- [ ] **Step 2：替换 L413 注释**

OLD (L413):
```python
    - 个人服务：展示 User.name / User.avatar（FeaturedTaskExpert 优先作为达人展示名）
```

NEW:
```python
    - 个人服务：展示 User.name / User.avatar（Expert 团队名/头像优先作为达人展示名）
```

- [ ] **Step 3：替换 L421 的 alias**

OLD (L421):
```python
    FTE = aliased(models.FeaturedTaskExpert)
```

NEW:
```python
    from app.models_expert import Expert, FeaturedExpertV2
    FV2 = aliased(FeaturedExpertV2)
    EXP = aliased(Expert)
```

- [ ] **Step 4：读 L422-510 附近的 JOIN 和字段引用，改 FTE → Expert/FV2**

找到本段 query，把所有：
- `FTE.name` → `EXP.name`
- `FTE.avatar` → `EXP.avatar`
- `FTE.avg_rating` → `EXP.rating`
- `FTE.expertise_areas` → `EXP.expertise_areas`
- 类似字段用 Expert 对应字段
- JOIN 条件 `FTE.user_id == ...` → `FV2.expert_id == EXP.id`，并通过 `_expert_id_migration_map` 把原来的 user_id 转成 team_id；或更直接：若有 `owner_type='expert' + owner_id` 字段可用，用 `EXP.id == <owner_id>`

具体替换依赖这段代码的具体 JOIN 目标。典型模式：
```python
# OLD
.outerjoin(FTE, FTE.user_id == some_user_id_column)

# NEW — 通过映射表 或 owner_id
.outerjoin(FV2, FV2.expert_id == <new_team_id_source>)
.outerjoin(EXP, EXP.id == FV2.expert_id)
```

**具体 follow feed 的 JOIN 来源**（基于 memory）：
- services/activities 用 `owner_type/owner_id` 匹配
- forum_posts 用 `ForumPost.expert_id` 匹配团队发帖

所以这里 JOIN `owner_id == EXP.id` 即可。

- [ ] **Step 5：同样处理 L511 注释 + L569 alias**

L511 注释更新："Expert 团队展示名优先"
L569 alias 同 Step 3（若是独立函数的第二处）

- [ ] **Step 6：语法检查**

Run:
```bash
cd backend && python -c "import app.follow_feed_routes" 2>&1 | head
```
Expected: 无输出

- [ ] **Step 7：Commit**

```bash
git add backend/app/follow_feed_routes.py
git commit -m "refactor(follow-feed): FeaturedTaskExpert 展示改走 Expert + FeaturedExpertV2

L421/L569 的 FTE alias 换成 FV2 + Expert alias. 字段映射:
- FTE.name → Expert.name
- FTE.avg_rating → Expert.rating (字段名不同)
- FTE.expertise_areas 等画像字段 → Expert 同名字段 (migration 188 已迁)

JOIN 源用 owner_id (services/activities 场景) 或 forum_posts.expert_id."
```

---

## Task 7: 用户服务申请的 expert_name 查询（Commit #5）

**Files:**
- Modify: `backend/app/user_service_application_routes.py:117`

- [ ] **Step 1：替换 L115-120 段**

OLD (L114-120 附近):
```python
            if owner:
                app_dict["owner_name"] = owner.name
        elif app.expert_id:
            expert = await db.get(models.TaskExpert, app.expert_id)
            if expert:
                app_dict["owner_name"] = expert.expert_name
        items.append(app_dict)
```

NEW:
```python
            if owner:
                app_dict["owner_name"] = owner.name
        elif app.new_expert_id:
            # 用 new_expert_id (FK → experts.id, team_id 语义)
            # 而非 legacy expert_id (FK → task_experts.id, user_id 语义)
            from app.models_expert import Expert
            expert_team = await db.get(Expert, app.new_expert_id)
            if expert_team:
                app_dict["owner_name"] = expert_team.name
        items.append(app_dict)
```

- [ ] **Step 2：语法检查**

Run:
```bash
cd backend && python -c "import app.user_service_application_routes" 2>&1 | head
```

- [ ] **Step 3：Commit**

```bash
git add backend/app/user_service_application_routes.py
git commit -m "refactor(service-app): 用 new_expert_id 列 + Expert 团队名

ServiceApplication 同时有 legacy expert_id (FK→task_experts) 和
new_expert_id (FK→experts, migration 182 加). Phase A 切到新列,
读 Expert.name 代替 TaskExpert.expert_name."
```

---

## Task 8: AI Agent 工具层 4 个 tool（Commit #6）

**Files:**
- Modify: `backend/app/services/ai_tools.py:791-827, 860-862, 895-927, 1101-1118`

### Task 8.1: `list_task_experts` tool (L791-827)

- [ ] **Step 1：替换 query**

OLD (L802-817):
```python
async def _list_task_experts(executor: ToolExecutor, input: dict) -> dict:
    keyword = input.get("keyword", "")
    conditions = [models.TaskExpert.status == "active"]
    if keyword:
        like_kw = f"%{keyword}%"
        conditions.append(or_(
            models.TaskExpert.expert_name.ilike(like_kw),
            models.TaskExpert.bio.ilike(like_kw),
        ))

    rows = (await executor.db.execute(
        select(models.TaskExpert, models.User.name)
        .join(models.User, models.TaskExpert.id == models.User.id)
        .where(and_(*conditions))
        .order_by(desc(models.TaskExpert.rating)).limit(10)
    )).all()

    experts = [{
        "id": expert.id,
        "name": expert.expert_name or user_name,
        "bio": _truncate(expert.bio, 80),
        "rating": float(expert.rating) if expert.rating else 0,
        "completed_tasks": expert.completed_tasks,
    } for expert, user_name in rows]

    return {"experts": experts, "count": len(experts)}
```

NEW:
```python
async def _list_task_experts(executor: ToolExecutor, input: dict) -> dict:
    from app.models_expert import Expert
    keyword = input.get("keyword", "")
    conditions = [Expert.status == "active"]
    if keyword:
        like_kw = f"%{keyword}%"
        conditions.append(or_(
            Expert.name.ilike(like_kw),
            Expert.bio.ilike(like_kw),
        ))

    rows = (await executor.db.execute(
        select(Expert)
        .where(and_(*conditions))
        .order_by(desc(Expert.rating)).limit(10)
    )).scalars().all()

    experts = [{
        "id": e.id,
        "name": e.name,
        "bio": _truncate(e.bio, 80),
        "rating": float(e.rating) if e.rating else 0,
        "completed_tasks": e.completed_tasks,
    } for e in rows]

    return {"experts": experts, "count": len(experts)}
```

### Task 8.2: `get_activity_detail` 的 expert_name lookup (L842-880 里 L857-865)

- [ ] **Step 2：替换 activity expert 查询**

OLD (L857-865):
```python
    lang = executor._tool_lang()
    expert_name = None
    if activity.expert_id:
        row = (await executor.db.execute(
            select(models.TaskExpert.expert_name, models.User.name)
            .join(models.User, models.TaskExpert.id == models.User.id)
            .where(models.TaskExpert.id == activity.expert_id)
        )).first()
        if row:
            expert_name = row[0] or row[1]
```

NEW:
```python
    lang = executor._tool_lang()
    expert_name = None
    # 用新字段 owner_type='expert' + owner_id → Expert (activity.expert_id 是 legacy
    # FK→users.id, 值是 user_id, Phase A 后不应使用)
    if activity.owner_type == "expert" and activity.owner_id:
        from app.models_expert import Expert
        row = (await executor.db.execute(
            select(Expert.name).where(Expert.id == activity.owner_id)
        )).first()
        if row:
            expert_name = row[0]
    elif activity.owner_type == "user" and activity.owner_id:
        row = (await executor.db.execute(
            select(models.User.name).where(models.User.id == activity.owner_id)
        )).first()
        if row:
            expert_name = row[0]
```

### Task 8.3: `get_expert_detail` tool (L895-927)

- [ ] **Step 3：替换 query**

OLD (L900-914):
```python
    row = (await executor.db.execute(
        select(models.TaskExpert, models.User.name)
        .join(models.User, models.TaskExpert.id == models.User.id)
        .where(models.TaskExpert.id == expert_id)
    )).first()
    if not row:
        return {"error": msgs["expert_not_found"]}

    expert, user_name = row
    svc_rows = (await executor.db.execute(
        select(models.TaskExpertService).where(and_(
            models.TaskExpertService.expert_id == expert_id,
            models.TaskExpertService.status == "active",
        )).order_by(models.TaskExpertService.display_order)
    )).scalars().all()
```

NEW:
```python
    from app.models_expert import Expert
    # input expert_id 在 Phase A 后语义是 team_id (见 spec §7.5)
    expert = (await executor.db.execute(
        select(Expert).where(Expert.id == expert_id)
    )).scalar_one_or_none()
    if not expert:
        return {"error": msgs["expert_not_found"]}

    # Service 用新字段 owner_type='expert' + owner_id (不是 legacy expert_id 列)
    svc_rows = (await executor.db.execute(
        select(models.TaskExpertService).where(and_(
            models.TaskExpertService.owner_type == "expert",
            models.TaskExpertService.owner_id == expert_id,
            models.TaskExpertService.status == "active",
        )).order_by(models.TaskExpertService.display_order)
    )).scalars().all()
```

- [ ] **Step 4：替换 return 体里的字段读取**

OLD (L920-927):
```python
    return {
        "id": expert.id, "name": expert.expert_name or user_name,
        "bio": _truncate(expert.bio, 200),
        "rating": float(expert.rating) if expert.rating else 0,
        "completed_tasks": expert.completed_tasks,
        "services": services,
    }
```

NEW:
```python
    return {
        "id": expert.id, "name": expert.name,
        "bio": _truncate(expert.bio, 200),
        "rating": float(expert.rating) if expert.rating else 0,
        "completed_tasks": expert.completed_tasks,
        "services": services,
    }
```

### Task 8.4: `list_my_service_applications` tool (L1101-1127)

- [ ] **Step 5：替换 JOIN**

OLD (L1105-1127):
```python
    rows = (await executor.db.execute(
        select(
            models.ServiceApplication,
            models.TaskExpertService.service_name,
            models.TaskExpert.expert_name,
            models.User.name,
        )
        .join(models.TaskExpertService, models.ServiceApplication.service_id == models.TaskExpertService.id)
        .join(models.TaskExpert, models.ServiceApplication.expert_id == models.TaskExpert.id)
        .join(models.User, models.TaskExpert.id == models.User.id)
        .where(and_(*conditions))
        .order_by(desc(models.ServiceApplication.created_at))
        .offset((page - 1) * page_size).limit(page_size)
    )).all()

    applications = [{
        "id": app.id, "service_name": service_name,
        "expert_name": expert_name or user_name,
        "status": app.status,
        "final_price": app.final_price,
        "negotiated_price": app.negotiated_price,
        "currency": app.currency,
    } for app, service_name, expert_name, user_name in rows]
```

NEW:
```python
    from app.models_expert import Expert
    rows = (await executor.db.execute(
        select(
            models.ServiceApplication,
            models.TaskExpertService.service_name,
            Expert.name,
        )
        .join(models.TaskExpertService, models.ServiceApplication.service_id == models.TaskExpertService.id)
        .outerjoin(Expert, models.ServiceApplication.new_expert_id == Expert.id)
        .where(and_(*conditions))
        .order_by(desc(models.ServiceApplication.created_at))
        .offset((page - 1) * page_size).limit(page_size)
    )).all()

    applications = [{
        "id": app.id, "service_name": service_name,
        "expert_name": expert_name or "",
        "status": app.status,
        "final_price": app.final_price,
        "negotiated_price": app.negotiated_price,
        "currency": app.currency,
    } for app, service_name, expert_name in rows]
```

- [ ] **Step 6：语法检查**

Run:
```bash
cd backend && python -c "import app.services.ai_tools" 2>&1 | head
```
Expected: 无输出

- [ ] **Step 7：Commit**

```bash
git add backend/app/services/ai_tools.py
git commit -m "refactor(ai-tools): 4 个 tool JOIN 换到 Expert + 新 owner 列

- list_task_experts: SELECT Expert, 不再 JOIN User
- get_activity_detail: 用 activity.owner_type='expert' + owner_id 查 Expert.name
  (不用 activity.expert_id legacy FK→users.id)
- get_expert_detail: SELECT Expert WHERE id=team_id; 服务用 TaskExpertService
  .owner_type+owner_id (不用 legacy expert_id 列)
- list_my_service_applications: 用 ServiceApplication.new_expert_id → Expert
  (不用 legacy expert_id 列)

JOIN 目标表全部从 TaskExpert 切到 Expert, 消除 legacy 列的依赖."
```

---

## Task 9: 官方账户写路径 setup_official_account（Commit #7）

**Files:**
- Modify: `backend/app/admin_official_routes.py:80-192`

- [ ] **Step 1：整体替换 `setup_official_account` 函数体**

找 L80-192 的 `setup_official_account` 函数。**删除**原来的"查 TaskExpert / 创建 TaskExpert / 设 is_official"逻辑（L94-113 段），**保留**下方 "B1: 同时 mirror 到新 Expert" 的逻辑（L115-192）。

OLD (L80-192 完整函数，重点删除 L94-113 的 TaskExpert 写入段):
```python
@admin_official_router.post("/account/setup", response_model=dict)
async def setup_official_account(
    data: schemas.OfficialAccountSetup,
    db: AsyncSession = Depends(get_async_db_dependency),
    admin: models.AdminUser = Depends(get_current_admin_async),
):
    """将指定用户设为官方达人账号"""
    user_result = await db.execute(
        select(models.User).where(models.User.id == data.user_id)
    )
    user = user_result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    expert_result = await db.execute(
        select(models.TaskExpert).where(models.TaskExpert.id == data.user_id)
    )
    expert = expert_result.scalar_one_or_none()

    if not expert:
        expert = models.TaskExpert(
            id=data.user_id,
            expert_name=user.name,
            status="active",
            rating=5.0,
            total_services=0,
            completed_tasks=0,
            is_official=True,
            official_badge=data.official_badge or "官方",
        )
        db.add(expert)
    else:
        expert.is_official = True
        expert.official_badge = data.official_badge or "官方"

    # B1: 同时 mirror 到新 Expert/ExpertMember/_expert_id_migration_map
    # 让官方账号在新模型(团队 dashboard / 公开主页)下也可见。
    # 1 人团队语义: 这位 user 自己就是 owner。
    from app.models_expert import (
        Expert,
        ExpertMember,
        generate_expert_id,
    )
    from sqlalchemy import text as sa_text

    map_check = await db.execute(
        sa_text("SELECT new_id FROM _expert_id_migration_map WHERE old_id = :old_id"),
        {"old_id": data.user_id},
    )
    map_row = map_check.first()

    if not map_row:
        # 生成新 8 位 id (避免与现有 experts.id 撞)
        new_expert_id = None
        for _ in range(10):
            candidate = generate_expert_id()
            exists = await db.execute(
                select(Expert).where(Expert.id == candidate)
            )
            if exists.scalar_one_or_none() is None:
                new_expert_id = candidate
                break
        if not new_expert_id:
            raise HTTPException(
                status_code=500,
                detail="无法生成唯一 expert id,请重试",
            )

        new_expert = Expert(
            id=new_expert_id,
            name=user.name or f"User {data.user_id}",
            bio=None,
            avatar=None,
            status="active",
            allow_applications=True,
            max_members=20,
            member_count=1,
            rating=5.0,
            total_services=0,
            completed_tasks=0,
            completion_rate=0.0,
            is_official=True,
            official_badge=data.official_badge or "官方",
            stripe_onboarding_complete=False,
        )
        db.add(new_expert)

        owner_member = ExpertMember(
            expert_id=new_expert_id,
            user_id=data.user_id,
            role="owner",
            status="active",
        )
        db.add(owner_member)

        # 持久化映射
        await db.execute(
            sa_text(
                "INSERT INTO _expert_id_migration_map (old_id, new_id) "
                "VALUES (:old_id, :new_id) ON CONFLICT DO NOTHING"
            ),
            {"old_id": data.user_id, "new_id": new_expert_id},
        )
    else:
        # 已有映射 — 同步 official 标记到新 Expert
        existing_new_id = map_row[0]
        existing_expert = await db.get(Expert, existing_new_id)
        if existing_expert:
            existing_expert.is_official = True
            existing_expert.official_badge = data.official_badge or "官方"

    await db.commit()
    return {"success": True, "user_id": data.user_id, "badge": expert.official_badge}
```

NEW:
```python
@admin_official_router.post("/account/setup", response_model=dict)
async def setup_official_account(
    data: schemas.OfficialAccountSetup,
    db: AsyncSession = Depends(get_async_db_dependency),
    admin: models.AdminUser = Depends(get_current_admin_async),
):
    """将指定用户设为官方达人账号 (Phase A 后单写 Expert)"""
    from app.models_expert import Expert, ExpertMember, generate_expert_id
    from sqlalchemy import text as sa_text

    user_result = await db.execute(
        select(models.User).where(models.User.id == data.user_id)
    )
    user = user_result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    badge = data.official_badge or "官方"

    # 查映射: user 是否已有 legacy → team 映射
    map_check = await db.execute(
        sa_text("SELECT new_id FROM _expert_id_migration_map WHERE old_id = :old_id"),
        {"old_id": data.user_id},
    )
    map_row = map_check.first()

    if not map_row:
        # 无映射 — 创建新 Expert 1 人团队 + ExpertMember(owner) + 写映射
        # 已知 edge case (R11): 若 user 已是某新 ExpertApplication 创建团队的 owner,
        # 此处会创建第 2 个团队。Phase A 保留此行为, 由业务评估是否 Phase B 修复.
        new_expert_id = None
        for _ in range(10):
            candidate = generate_expert_id()
            exists = await db.execute(
                select(Expert).where(Expert.id == candidate)
            )
            if exists.scalar_one_or_none() is None:
                new_expert_id = candidate
                break
        if not new_expert_id:
            raise HTTPException(
                status_code=500,
                detail="无法生成唯一 expert id,请重试",
            )

        new_expert = Expert(
            id=new_expert_id,
            name=user.name or f"User {data.user_id}",
            bio=None,
            avatar=None,
            status="active",
            allow_applications=True,
            max_members=20,
            member_count=1,
            rating=5.0,
            total_services=0,
            completed_tasks=0,
            completion_rate=0.0,
            is_official=True,
            official_badge=badge,
            stripe_onboarding_complete=False,
        )
        db.add(new_expert)

        owner_member = ExpertMember(
            expert_id=new_expert_id,
            user_id=data.user_id,
            role="owner",
            status="active",
        )
        db.add(owner_member)

        await db.execute(
            sa_text(
                "INSERT INTO _expert_id_migration_map (old_id, new_id) "
                "VALUES (:old_id, :new_id) ON CONFLICT DO NOTHING"
            ),
            {"old_id": data.user_id, "new_id": new_expert_id},
        )
    else:
        # 已有映射 — 设 official 标记到既有 Expert
        existing_new_id = map_row[0]
        existing_expert = await db.get(Expert, existing_new_id)
        if existing_expert:
            existing_expert.is_official = True
            existing_expert.official_badge = badge

    await db.commit()
    return {"success": True, "user_id": data.user_id, "badge": badge}
```

- [ ] **Step 2：语法检查**

Run:
```bash
cd backend && python -c "import app.admin_official_routes" 2>&1 | head
```
Expected: 无输出

- [ ] **Step 3：Commit**

```bash
git add backend/app/admin_official_routes.py
git commit -m "refactor(official): setup_official_account 单写 Expert

移除 L94-113 的 TaskExpert 查/写/setOfficial 段, 只保留 B1 mirror 逻辑.
无映射时创建 1 人团队 Expert + ExpertMember(owner) + map; 有映射时设
既有 Expert.is_official=True.

已知 R11 edge case: user 若已是某新 ExpertApplication 团队的 owner,
会创建第二个团队 — Phase A 保留此行为, 业务评估 Phase B 是否修复.

返回 schema 保持 {success,user_id,badge} — admin panel 无感知."
```

---

## Task 10: `crud/user.py` 统计同步改写 Expert（Commit #8）

**Files:**
- Modify: `backend/app/crud/user.py:55, 80-110`

- [ ] **Step 1：更新函数 docstring (L55)**

OLD (L55 左右):
```python
    """...同时同步更新 TaskExpert 与 FeaturedTaskExpert（如存在）。"""
```

NEW:
```python
    """...同时同步更新 Expert 团队的统计字段 (通过 _expert_id_migration_map 查 team_id)。
    Phase A: 不再写 legacy TaskExpert/FeaturedTaskExpert;
    FeaturedExpertV2 精简 schema 的 is_featured/display_order/category 由 admin
    操作驱动,不在此同步."""
```

- [ ] **Step 2：替换 L80-110 的统计同步逻辑**

OLD:
```python
    if user:
        user.task_count = total_tasks
        user.completed_task_count = completed_tasks
        user.avg_rating = avg_rating
        db.commit()
        db.refresh(user)

        task_expert = (
            db.query(models.TaskExpert)
            .options(joinedload(models.TaskExpert.services))
            .filter(models.TaskExpert.id == user_id)
            .first()
        )
        if task_expert:
            task_expert.completed_tasks = completed_tasks
            task_expert.rating = Decimal(str(avg_rating)).quantize(Decimal("0.01"))
            db.commit()
            db.refresh(task_expert)

        featured_expert = (
            db.query(models.FeaturedTaskExpert)
            .filter(models.FeaturedTaskExpert.id == user_id)
            .first()
        )
        if featured_expert:
            featured_expert.avg_rating = avg_rating
            featured_expert.completed_tasks = completed_tasks
            featured_expert.total_tasks = total_tasks
            featured_expert.completion_rate = completion_rate
            db.commit()
            db.refresh(featured_expert)
```

NEW:
```python
    if user:
        user.task_count = total_tasks
        user.completed_task_count = completed_tasks
        user.avg_rating = avg_rating
        db.commit()
        db.refresh(user)

        # Phase A: 通过 _expert_id_migration_map 查出用户作为 owner 的 Expert 团队
        # 并同步统计字段到 Expert 表 (不再写 legacy TaskExpert/FeaturedTaskExpert)
        from sqlalchemy import text as sa_text
        from app.models_expert import Expert

        map_row = db.execute(
            sa_text(
                "SELECT new_id FROM _expert_id_migration_map WHERE old_id = :uid"
            ),
            {"uid": user_id},
        ).first()

        if map_row:
            expert_id = map_row[0]
            expert = db.get(Expert, expert_id)
            if expert:
                expert.rating = Decimal(str(avg_rating)).quantize(Decimal("0.01"))
                expert.completed_tasks = completed_tasks
                expert.completion_rate = completion_rate
                db.commit()
                db.refresh(expert)
```

- [ ] **Step 3：语法检查**

Run:
```bash
cd backend && python -c "import app.crud.user" 2>&1 | head
```

- [ ] **Step 4：Commit**

```bash
git add backend/app/crud/user.py
git commit -m "refactor(crud/user): sync_user_task_stats 写 Expert 代替 TaskExpert/FTE

Phase A 核心写路径迁移:
- 不再写 TaskExpert.rating / completed_tasks
- 不再写 FeaturedTaskExpert.avg_rating / completed_tasks / total_tasks /
  completion_rate
- 改写 Expert.rating / completed_tasks / completion_rate
  (通过 _expert_id_migration_map 查 old_id → new_id)
- FeaturedExpertV2 精简字段 (is_featured/display_order/category) 由 admin
  操作驱动,不在此同步

非达人用户 (无映射) 只更新 User.avg_rating 等."
```

---

## Task 11: `crud/task_expert.py` 聚合写 + 定时任务改造（Commit #9）

**Files:**
- Modify: `backend/app/crud/task_expert.py:46-195`

- [ ] **Step 1：替换 `update_task_expert_bio` 函数内的写入段 (L147-161)**

找到函数内部 L147-161 的 FeaturedTaskExpert 写入段：

OLD:
```python
    featured_expert = (
        db.query(models.FeaturedTaskExpert)
        .filter(models.FeaturedTaskExpert.id == user_id)
        .first()
    )
    if featured_expert:
        featured_expert.response_time = response_time_zh
        featured_expert.response_time_en = response_time_en
        featured_expert.avg_rating = avg_rating
        featured_expert.completed_tasks = completed_tasks
        featured_expert.total_tasks = total_tasks
        featured_expert.completion_rate = completion_rate
        featured_expert.success_rate = success_rate
        db.commit()
        db.refresh(featured_expert)

    return response_time_zh
```

NEW:
```python
    # Phase A: 写 Expert 代替 FeaturedTaskExpert (通过 _expert_id_migration_map 查 team_id)
    from sqlalchemy import text as sa_text
    from app.models_expert import Expert

    map_row = db.execute(
        sa_text(
            "SELECT new_id FROM _expert_id_migration_map WHERE old_id = :uid"
        ),
        {"uid": user_id},
    ).first()

    if map_row:
        expert_id = map_row[0]
        expert = db.get(Expert, expert_id)
        if expert:
            expert.response_time = response_time_zh
            expert.response_time_en = response_time_en
            expert.rating = avg_rating  # FTE.avg_rating → Expert.rating (字段名不同)
            expert.completed_tasks = completed_tasks
            # Expert 无 total_tasks 字段;该统计只在 FTE 有过,Phase A 不迁
            expert.completion_rate = completion_rate
            expert.success_rate = success_rate  # 209 migration 已加此列
            db.commit()
            db.refresh(expert)

    return response_time_zh
```

- [ ] **Step 2：替换 `update_all_featured_task_experts_response_time` 定时任务 (L171-195)**

OLD:
```python
def update_all_featured_task_experts_response_time():
    """更新所有 FeaturedTaskExpert 的响应时间（每天执行一次）。"""
    from app.database import SessionLocal
    from app.models import FeaturedTaskExpert

    db = None
    try:
        db = SessionLocal()
        featured_experts = db.query(FeaturedTaskExpert).all()
        updated_count = 0
        for expert in featured_experts:
            try:
                update_task_expert_bio(db, expert.id)
                updated_count += 1
            except Exception as e:
                logger.error(
                    "更新特征任务达人 %s 的响应时间时出错: %s",
                    expert.id,
                    e,
                )
                continue
        if updated_count > 0:
            logger.info(
                "成功更新 %s 个特征任务达人的响应时间",
                updated_count,
            )
```

NEW:
```python
def update_all_featured_task_experts_response_time():
    """更新所有 Expert 团队 owner 的响应时间/统计（每天执行一次）。

    Phase A: 遍历 Expert owner users 调 update_task_expert_bio (签名保持
    user_id,内部通过映射找 Expert 团队写入).
    函数名保留(已有 Celery/scheduler 调用),语义迁移到 Expert.
    """
    from app.database import SessionLocal
    from app.models_expert import ExpertMember

    db = None
    try:
        db = SessionLocal()
        # 取所有 active owner 的 user_id
        owner_rows = (
            db.query(ExpertMember.user_id)
            .filter(
                ExpertMember.role == "owner",
                ExpertMember.status == "active",
            )
            .all()
        )
        updated_count = 0
        for (user_id,) in owner_rows:
            try:
                update_task_expert_bio(db, user_id)
                updated_count += 1
            except Exception as e:
                logger.error(
                    "更新 expert team owner %s 的响应时间时出错: %s",
                    user_id,
                    e,
                )
                continue
        if updated_count > 0:
            logger.info(
                "成功更新 %s 个 expert team owner 的响应时间/统计",
                updated_count,
            )
    finally:
        if db is not None:
            db.close()
```

**注意**：确保 `finally` 块存在（原代码可能有），避免 db leak。

- [ ] **Step 3：`update_all_task_experts_bio` (L166-168) 保持不变**

该函数是 deprecated wrapper 委托给 `update_all_featured_task_experts_response_time`。内部函数已改，wrapper 不用动。

- [ ] **Step 4：语法检查**

Run:
```bash
cd backend && python -c "import app.crud.task_expert" 2>&1 | head
```

- [ ] **Step 5：Commit**

```bash
git add backend/app/crud/task_expert.py
git commit -m "refactor(crud/task_expert): 聚合函数写 Expert 代替 FeaturedTaskExpert

update_task_expert_bio (L46-163):
- L147-161 写入段从 FeaturedTaskExpert 改为 Expert (通过 map 查 team_id)
- 字段映射 FTE.avg_rating → Expert.rating (字段名不同)
- Expert 无 total_tasks 字段, 不迁
- success_rate 用 209 migration 新增的列

update_all_featured_task_experts_response_time (L171-195, 活跃定时任务):
- celery_tasks.py/task_scheduler.py/main.py 三处调度, 每日 UTC 3:00
- 遍历从 FeaturedTaskExpert 改为 ExpertMember(role=owner,status=active)
  取 user_id, 保持 update_task_expert_bio 的 user_id 签名
- 函数名保留 (调度点未改)"
```

---

## Task 12: `crud/admin_ops.py` 改检查 FeaturedExpertV2（Commit #10）

**Files:**
- Modify: `backend/app/crud/admin_ops.py:57, 73-74`

- [ ] **Step 1：更新 docstring + 查询**

OLD (L55-80 左右):
```python
def delete_admin_by_superadmin(db: Session, admin_id: str):
    """超级管理员删除管理员账号。不可删自己；若有关联 JobPosition/FeaturedTaskExpert/AdminReward 则不可删。"""
    # ...
    related_featured = (
        db.query(models.FeaturedTaskExpert)
        .filter(models.FeaturedTaskExpert.created_by == admin_id)
        .count()
    )
```

NEW:
```python
def delete_admin_by_superadmin(db: Session, admin_id: str):
    """超级管理员删除管理员账号。不可删自己；若有关联 JobPosition/FeaturedExpertV2/AdminReward 则不可删。"""
    # ...
    from app.models_expert import FeaturedExpertV2
    related_featured = (
        db.query(FeaturedExpertV2)
        .filter(FeaturedExpertV2.created_by == admin_id)
        .count()
    )
```

- [ ] **Step 2：语法检查**

Run:
```bash
cd backend && python -c "import app.crud.admin_ops" 2>&1 | head
```

- [ ] **Step 3：Commit**

```bash
git add backend/app/crud/admin_ops.py
git commit -m "refactor(crud/admin_ops): 删 admin 时检查 FeaturedExpertV2 代替 FTE

L57 docstring + L73-74 查询切到 FeaturedExpertV2.
created_by 字段语义相同 (FK→admin_users, RESTRICT)."
```

---

## Task 13: `cleanup_tasks.py` 化简（Commit #11）

**Files:**
- Modify: `backend/app/cleanup_tasks.py:1156-1167, 1419-1429`

- [ ] **Step 1：替换 L1155-1167 的第一处 (sync 本地存储清理)**

OLD (L1155-1167):
```python
                # 5. 清理不存在的服务图片文件夹
                # 目录名是 user_id（上传时 resource_id=user_id），需同时匹配
                # TaskExpert.id（达人服务）和 User.id（个人服务）
                service_images_dir = base_upload_dir / "public" / "images" / "service_images"
                if service_images_dir.exists():
                    from sqlalchemy import select
                    experts_result = db.execute(select(models.TaskExpert.id))
                    existing_expert_ids = {expert_id for expert_id, in experts_result.all()}
                    users_result = db.execute(select(models.User.id))
                    existing_user_ids = {uid for uid, in users_result.all()}
                    valid_ids = existing_expert_ids | existing_user_ids
```

NEW:
```python
                # 5. 清理不存在的服务图片文件夹
                # 目录名是 user_id（上传时 resource_id=user_id）
                # TaskExpert.id 是 FK→users.id, 所以 TaskExpert.id 集合 ⊂ User.id 集合;
                # Phase A 移除冗余的 TaskExpert 查询, 只保留 User.id 即可。
                service_images_dir = base_upload_dir / "public" / "images" / "service_images"
                if service_images_dir.exists():
                    from sqlalchemy import select
                    users_result = db.execute(select(models.User.id))
                    existing_user_ids = {uid for uid, in users_result.all()}
                    valid_ids = existing_user_ids
```

- [ ] **Step 2：替换 L1419-1429 的第二处 (云存储清理)**

OLD:
```python
            # 5. 清理不存在的服务图片文件夹
            # 目录名是 user_id（上传时 resource_id=user_id），需同时匹配
            # TaskExpert.id（达人服务）和 User.id（个人服务）
            service_images_prefix = "public/images/service_images/"
            if cleaned_count < max_dirs_per_run:
                experts_result = db.execute(select(models.TaskExpert.id))
                existing_expert_ids = {str(expert_id) for expert_id, in experts_result.all()}
                users_result = db.execute(select(models.User.id))
                existing_user_ids = {str(uid) for uid, in users_result.all()}
                valid_ids = existing_expert_ids | existing_user_ids
```

NEW:
```python
            # 5. 清理不存在的服务图片文件夹
            # 目录名是 user_id（上传时 resource_id=user_id）
            # TaskExpert.id 是 FK→users.id, Phase A 移除冗余 TaskExpert 查询
            service_images_prefix = "public/images/service_images/"
            if cleaned_count < max_dirs_per_run:
                users_result = db.execute(select(models.User.id))
                existing_user_ids = {str(uid) for uid, in users_result.all()}
                valid_ids = existing_user_ids
```

- [ ] **Step 3：语法检查**

Run:
```bash
cd backend && python -c "import app.cleanup_tasks" 2>&1 | head
```

- [ ] **Step 4：Commit**

```bash
git add backend/app/cleanup_tasks.py
git commit -m "refactor(cleanup): 化简 service_images 清理, 移除冗余 TaskExpert 查询

TaskExpert.id 定义为 ForeignKey('users.id'), 所以 TaskExpert.id 集合是
User.id 集合的子集. 原代码的 'valid_ids = existing_expert_ids | existing_user_ids'
== existing_user_ids, TaskExpert 查询纯粹多余.

Phase A 两处 (本地存储 L1155-1167 + 云存储 L1419-1429) 均删除 TaskExpert
查询, 行为完全等价, 少一次 DB query, 不再依赖 TaskExpert 模型."
```

---

## Task 14: 整体冒烟测试（pre-PR）

**Files:** 无改动（测试现有功能）

- [ ] **Step 1：跑所有 helper + migration 单测**

Run:
```bash
cd backend && python -m pytest tests/test_expert_helpers.py tests/migrations/ -v
```
Expected: helper 6 passed；migration 测试 6+ passed 或全 skipped（本地无 PG）

- [ ] **Step 2：跑 Phase A 相关的现有测试**

Run:
```bash
cd backend && python -m pytest tests/ -v -k "expert or follow_feed or consultation" --tb=short 2>&1 | tail -50
```
Expected: 相关测试全绿（无 Phase A 引入的新失败）

- [ ] **Step 3：静态检查 — grep 确认 §7.6 外无 TE/FTE 残留**

Run:
```bash
cd F:/python_work/LinkU && grep -rn "\bmodels\.TaskExpert\b\|\bmodels\.FeaturedTaskExpert\b\|\bTaskExpert\b\|\bFeaturedTaskExpert\b" backend/app/ | grep -v "TaskExpertService" | grep -v "\.pyc"
```

Expected: 所有返回行**只**出现在以下文件/位置：
- `backend/app/models.py`（类定义 + relationship）
- `backend/app/main.py:1242, 1252`（ORM import）
- `backend/app/admin_task_expert_routes.py`（Phase B 删）
- `backend/app/routers.py:12694-13576` + `L13751-13809`（Phase B admin + 死代码）
- `backend/app/service_public_routes.py:11`（注释）
- `backend/app/expert_routes.py:506`（注释）

**若有别的文件出现**——说明 Phase A 有遗漏，返回对应 Task 修正。

- [ ] **Step 4：跑 full-stack-consistency-check（CLAUDE.md 强制）**

按 CLAUDE.md 的清单过一遍：
- DB Model (`models.py` + `models_expert.py`) → 无新增/删除
- Pydantic Schema (`schemas.py`) → Phase A 不动 (§7.5 修正版)
- API Route 返回 JSON 字段名 → 对外不变
- Frontend Endpoint → 不变
- Repository → 不变
- Model.fromJson → 不变
- BLoC → 不变
- UI → 不变

记录 pass/fail。

---

## Task 15: 发布前最终检查 + 本地启动

**Files:** 无改动

- [ ] **Step 1：查看所有 commit**

Run:
```bash
git log --oneline main..HEAD
```
Expected: 约 11 条 commit，每条对应一个功能组

- [ ] **Step 2：重新启动 backend 本地验证**

Run:
```bash
cd backend && python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload 2>&1 | head -50
```
Expected:
- 启动日志显示 `执行迁移: 209_sync_expert_fields_from_legacy.sql` → `✅ 迁移执行成功`
- 无 `ModuleNotFoundError` / `AttributeError`
- backend 正常监听

若看到 migration 209 `RAISE EXCEPTION` → 本地 DB 是空的/无 mapping 数据 → 手动跑 `_expert_id_migration_map` fixture 或 skip

按 Ctrl+C 停止。

- [ ] **Step 3：查阅 spec §8.2 确认 smoke test 计划**

熟读 spec §8.2 的 5 流程，准备 staging 测试 checklist：
1. Flutter 登录已知 TaskExpert 用户 → `/api/profile` 返回 `is_expert=true`
2. Admin 设置用户为官方账号 → experts 表出现 is_official=true + expert_members 有 owner
3. Flutter 首页达人服务 tab → 返回列表数据与 experts 表一致
4. 关注 featured 达人 → Follow Feed 展示正确
5. 用户完成任务被评 5 星 → Expert.rating 更新，TaskExpert 不再被写入

---

## Task 16: 推分支 + 创建 PR

**Files:** 无改动

- [ ] **Step 1：推分支到远程**

Run:
```bash
git push -u origin feature/expert-unification-phase-a
```

- [ ] **Step 2：创建 PR**

Run:
```bash
gh pr create --title "Phase A: 后端下线 TaskExpert legacy, 统一 Expert 团队" --body "$(cat <<'EOF'
## Summary
- Phase A of the TaskExpert legacy unification (spec v1.10)
- Adds migration 209 (atomic DO block) syncing TE/FTE fields to Expert / FeaturedExpertV2, plus ALTER TABLE experts ADD COLUMN success_rate
- Switches all Phase A read + write paths (10 functional groups, ~15 files, 21+ code points) from TaskExpert/FeaturedTaskExpert to Expert/FeaturedExpertV2
- Preserves all Phase B/C references (admin routes, model definitions, dead code) per spec §7.6

## Commit Structure
11 focused commits per spec §7's functional groups:
1. `feat(expert)`: add helpers
2. `feat(migration)`: 209 sync
3. `refactor(expert)`: is_expert judgement (3 files)
4. `refactor(discovery)`: JOIN switch
5. `refactor(official)`: read path
6. `refactor(follow-feed)`: FTE → FV2
7. `refactor(service-app)`: new_expert_id
8. `refactor(ai-tools)`: 4 tools
9. `refactor(official)`: setup_official_account single-write
10. `refactor(crud/user)`: stats sync
11. `refactor(crud/task_expert)`: scheduled task
12. `refactor(crud/admin_ops)`: admin delete check
13. `refactor(cleanup)`: simplify

## Rollout
- Migration 209 runs automatically at Railway startup
- CRITICAL: After deploy, check backend logs for `209 complete: orphans=0, ...` NOTICE
- If `RAISE EXCEPTION` appears: human intervention required (do NOT revert code)
- Monitor celery worker logs 30s for `column experts.success_rate does not exist` — Celery's retry usually recovers

## Test Plan
- [x] helper 6 unit tests pass
- [x] migration 209 tests (7 cases) pass on PG
- [x] static grep confirms no TE/FTE references outside §7.6 scope
- [ ] staging smoke test per spec §8.2 5 flows:
  - [ ] Flutter is_expert check
  - [ ] Admin official account setup
  - [ ] Expert service search on home
  - [ ] Follow feed display
  - [ ] Stats sync after review submission
- [ ] full-stack-consistency-check pass

Spec: docs/superpowers/specs/2026-04-19-expert-unification-design.md (v1.10)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL 打印出来

- [ ] **Step 3：后续跟进 staging 部署 + 冒烟**

- 等 CI 通过
- 合入到 staging（或按仓库惯例）
- **强制**：部署后 30 秒内看 backend logs 确认 migration 209 NOTICE
- **强制**：看 celery worker logs 确认无 `column does not exist`
- 跑 spec §8.2 的 5 个冒烟流程
- 全绿后 prod merge（同样检查 prod logs）

---

## 执行交接

Plan 已写入 `docs/superpowers/plans/2026-04-19-expert-unification-phase-a.md`。两种执行方式：

**1. Subagent-Driven（推荐）** — 每个 Task 派独立 subagent，两阶段 review，适合这个 16 任务 / 11 commit 的大 PR

**2. Inline Execution** — 在当前会话按 Task 顺序执行，batch checkpoints

选哪个？
