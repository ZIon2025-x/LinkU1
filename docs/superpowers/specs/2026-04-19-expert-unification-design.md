# TaskExpert Legacy 全面下线：统一 Expert 团队系统

**日期**: 2026-04-19
**状态**: 设计 — 待 writing-plans
**范围**: Phase A（Overview + Phase A 深度设计；Phase B/C/D 只做全景说明）

---

## 1. 目标

让 Link2Ur 后端/Admin/客户端的达人功能完全统一在新 Expert 团队系统上，彻底下线 TaskExpert / TaskExpertService / FeaturedTaskExpert legacy 模型与表。最终状态：

- 所有 `TaskExpert` / `FeaturedTaskExpert` 模型类从 `models.py` 删除
- `task_experts` / `task_expert_applications` / `task_expert_profile_update_requests` / `featured_task_experts` 四张表 DROP
- `admin_task_expert_routes.py` (845 行) 整体删除
- admin 前端 `/api/admin/task-experts/*` 调用全部迁到 `/api/admin/experts/*`
- Flutter/Web 的 TaskExpert 命名清理（数据类 / 路由文件 / cache key）

整个工程分 4 个独立 Phase 推进，本 spec 深入 **Phase A**。Phase B/C/D 的细节后续各自 brainstorm。

## 2. 四阶段分解

```
Phase A (本 spec) ──► Phase B ────────► Phase C ────────► Phase D (可平行)
后端代码去 TaskExpert    Admin 路由 + 前端    DB DROP + 模型删除    Flutter/Web 命名清理
+ FeaturedTaskExpert      迁移到新端点         最终 catch-up migration
切到 FeaturedExpertV2
(~21 处引用, 15+ 文件)
```

| Phase | 范围 | 前置 | 产出 |
|-------|------|------|------|
| **A** | catch-up migration + Phase A 范围内的 TaskExpert / FeaturedTaskExpert 引用切到新模型（详见 §7.2-7.4，涵盖 is_expert 判断 / 多人活动 / discovery / 官方账户 / follow feed / 用户服务申请 / AI 工具 / 统计 / 定时任务 / 图片清理 共 10 个功能组）。对外 API 返回 schema 保持不变（内部实现 swap），admin panel 继续工作 | — | 一个大 PR；后端单写新表；老表仍存在但只读 |
| **B** | `admin_task_expert_routes.py` 下线；admin 前端 `ExpertManagement.tsx` 改走 `/api/admin/experts/*` | A merged | admin 前端零 `/api/admin/task-experts/*` 调用 |
| **C** | DROP 4 张 legacy 表；删除 `TaskExpert` / `TaskExpertService` / `FeaturedTaskExpert` 模型；可选清理 `_expert_id_migration_map` | B merged | 代码库零 `TaskExpert` 引用 |
| **D** | Flutter `task_expert_model.dart` → `expert_model.dart` 等；Web `api.ts` 残留命名；可平行于 A-C 做 | 无 | 前端命名一致 |

## 3. Phase A 成功标准 (DoD)

1. **§7.2-7.4 列出的代码位置**全部切换到 `Expert` / `ExpertMember` / `FeaturedExpertV2`；§7.6 明确列出的 Phase B/C 保留引用不动；自检命令见 §7.6 末尾
2. `catch-up migration 209` 成功执行：`experts` 表 rating / completed_tasks / total_services / completion_rate / success_rate 与 `task_experts` 和 `featured_task_experts` 对齐；`featured_experts_v2` 与 `featured_task_experts` 对齐
3. 对外 API 现有返回字段的 schema 和语义保持不变（允许新增向后兼容字段如 `expert_team_id`，见 §7.5）；admin panel 和客户端的现有代码无需同步改动
4. `ALTER TABLE experts ADD COLUMN success_rate` 在 staging/prod 成功执行，回填后 `experts.success_rate` 与 `featured_task_experts.success_rate` 零 mismatch
5. Staging 5 条核心流程冒烟通过（见 §8）
6. CLAUDE.md 的 full-stack-consistency-check 通过

## 4. Non-Goals (Phase A 不做)

- 不 DROP 任何表（Phase C）
- 不删除 `TaskExpert` 等 ORM 模型类（Phase C）
- 不改 `admin_task_expert_routes.py`（Phase B）
- 不改 Flutter/Web 文件命名（Phase D）
- 不调整 `task_expert_services` 表本身（共享表，两系统都在用）
- 不包含 Phase B 的 admin 前端迁移

## 5. 技术路径：Read-First Swap

核心切换顺序：

1. **migration 209** 先跑（数据层 catch-up，加 `success_rate` 列并回填所有 legacy 字段）
2. **读路径**先切到 Expert / FeaturedExpertV2
3. **写路径**切到单写 Expert / FeaturedExpertV2
4. **删除** `TaskExpert` / `FeaturedTaskExpert` 的代码引用（模型和表保留，Phase C 删）

迁移 209 可独立预跑验证，代码 PR 合入前数据已就位，读路径切换零风险。

## 6. Migration 209 完整规格

**文件**: `backend/migrations/209_sync_expert_fields_from_legacy.sql`
**执行时机**: 随 Phase A PR deploy 时自动跑（Q-C 决定）

### 6.1 Schema 变更

```sql
ALTER TABLE experts ADD COLUMN IF NOT EXISTS success_rate FLOAT NOT NULL DEFAULT 0.0;
CREATE INDEX IF NOT EXISTS ix_experts_success_rate ON experts(success_rate);
CREATE INDEX IF NOT EXISTS ix_expert_id_migration_map_old_id ON _expert_id_migration_map(old_id);
```

### 6.2 字段回填清单

| 类别 | 字段 | 源 | 策略 |
|------|------|---|------|
| **基础展示** | name, bio, avatar | `task_experts.expert_name/.bio/.avatar` | `updated_at` 较新一侧为准 |
| **英文简介** | bio_en | `featured_task_experts.bio_en` | COALESCE（补 migration 188 漏项） |
| **统计** | rating, total_services, completed_tasks, completion_rate | `task_experts` 同名字段 | 覆盖式（源最新） |
| **成功率** 🆕 | success_rate | `featured_task_experts.success_rate` | 覆盖式（FTE 由 `crud/task_expert.py` 从 reviews 聚合） |
| **擅长领域** | expertise_areas[_en] | `featured_task_experts` 同名字段 | COALESCE（188 补漏） |
| **特色技能** | featured_skills[_en] | 同上 | COALESCE |
| **成就徽章** | achievements[_en] | 同上 | COALESCE |
| **响应时间** | response_time[_en] | 同上 | COALESCE |
| **画像杂项** | category, location, display_order, is_verified, user_level | 同上 | COALESCE |
| **官方标记** | is_official, official_badge | `task_experts` | migration 185 已同步，209 兜底再抄 |
| **FeaturedV2** | is_featured, display_order, category | `featured_task_experts` | COALESCE |
| **不同步** | name_en, name_zh | — | legacy 无此字段，保持 NULL（新团队管理员后续补） |

### 6.3 Migration SQL 骨架

```sql
BEGIN;

-- Schema 变更
ALTER TABLE experts ADD COLUMN IF NOT EXISTS success_rate FLOAT NOT NULL DEFAULT 0.0;
CREATE INDEX IF NOT EXISTS ix_experts_success_rate ON experts(success_rate);
CREATE INDEX IF NOT EXISTS ix_expert_id_migration_map_old_id ON _expert_id_migration_map(old_id);

-- 1. 统计字段 (覆盖式)
UPDATE experts e
SET rating          = COALESCE(te.rating, e.rating),
    total_services  = COALESCE(te.total_services, e.total_services),
    completed_tasks = COALESCE(te.completed_tasks, e.completed_tasks),
    completion_rate = COALESCE(te.completion_rate, e.completion_rate),
    is_official     = COALESCE(te.is_official, e.is_official),
    official_badge  = COALESCE(te.official_badge, e.official_badge),
    updated_at      = NOW()
FROM _expert_id_migration_map m
JOIN task_experts te ON te.id = m.old_id
WHERE e.id = m.new_id
  AND (te.rating IS DISTINCT FROM e.rating
    OR te.total_services IS DISTINCT FROM e.total_services
    OR te.completed_tasks IS DISTINCT FROM e.completed_tasks
    OR te.completion_rate IS DISTINCT FROM e.completion_rate);

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

-- 3. success_rate 回填 (覆盖式 — FTE 是从 reviews 聚合得到的权威值)
UPDATE experts e
SET success_rate = COALESCE(fte.success_rate, e.success_rate)
FROM _expert_id_migration_map m
JOIN featured_task_experts fte ON fte.user_id = m.old_id
WHERE e.id = m.new_id
  AND fte.success_rate IS DISTINCT FROM e.success_rate;

-- 4. 画像字段补刷 (补 migration 188 漏项; COALESCE 保留 Expert 已有值)
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

-- 5. FeaturedExpertV2 统计补刷
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

-- 6. 验证
DO $$
DECLARE
    orphan_count INTEGER;
    service_orphan_count INTEGER;
    stats_mismatch INTEGER;
    success_rate_mismatch INTEGER;
BEGIN
    SELECT COUNT(*) INTO orphan_count
    FROM task_experts te
    WHERE NOT EXISTS (SELECT 1 FROM _expert_id_migration_map m WHERE m.old_id = te.id);
    IF orphan_count > 0 THEN
        RAISE EXCEPTION '209: % orphan task_experts without mapping — run migration 185 first', orphan_count;
    END IF;

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

    SELECT COUNT(*) INTO success_rate_mismatch
    FROM _expert_id_migration_map m
    JOIN featured_task_experts fte ON fte.user_id = m.old_id
    JOIN experts e ON e.id = m.new_id
    WHERE fte.success_rate IS DISTINCT FROM e.success_rate;
    IF success_rate_mismatch > 0 THEN
        RAISE WARNING '209: % experts.success_rate mismatch with FTE', success_rate_mismatch;
    END IF;

    RAISE NOTICE '209 complete: orphans=%, service_orphans=%, stats_mismatch=%, success_rate_mismatch=%',
        orphan_count, service_orphan_count, stats_mismatch, success_rate_mismatch;
END $$;

COMMIT;
```

### 6.4 特性

- **幂等**：`IS DISTINCT FROM` 过滤无变动行，重跑零副作用
- **CASCADE 安全**：仅 UPDATE，无 INSERT/DELETE/DROP
- **失败即中止**：orphan 检测直接 EXCEPTION 回滚

## 7. 代码改造详解

### 7.1 新增统一 helper

**文件**: `backend/app/utils/expert_helpers.py`（新建）

```python
from typing import Optional
from sqlalchemy import select
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession
from app.models_expert import Expert, ExpertMember


def is_user_expert_sync(db: Session, user_id: str) -> bool:
    """判断用户是否为任一 Expert 团队的 active 成员 (owner/admin/member)"""
    return db.query(ExpertMember).filter(
        ExpertMember.user_id == user_id,
        ExpertMember.status == "active",
    ).first() is not None


async def is_user_expert_async(db: AsyncSession, user_id: str) -> bool:
    result = await db.execute(
        select(ExpertMember).where(
            ExpertMember.user_id == user_id,
            ExpertMember.status == "active",
        ).limit(1)
    )
    return result.scalar_one_or_none() is not None


def get_user_primary_expert_sync(db: Session, user_id: str) -> Optional[Expert]:
    """返回用户作为 owner 的 Expert 团队 (1 人团队或多人团队的 owner)"""
    row = db.query(ExpertMember).filter(
        ExpertMember.user_id == user_id,
        ExpertMember.role == "owner",
        ExpertMember.status == "active",
    ).first()
    if not row:
        return None
    return db.get(Expert, row.expert_id)
```

### 7.2 Phase A 读路径改造

按"功能层"分组列出所有需要改的引用（经彻底 audit，2026-04-19 行号）。

#### 7.2.1 is_expert 判断（3 个调用点，全换 `is_user_expert_sync`）

| 文件 | 行号 | 当前逻辑 | 改造 |
|------|------|----------|------|
| `routers.py` | 4781-4791 (`get_my_profile`) — TE 查询 L4781-4786 + ExpertMember 查询 L4787-4790 + 合并 L4791 | `TaskExpert OR ExpertMember` 双查 | `is_user_expert_sync(db, current_user.id)` |
| `routers.py` | 5072-5082 (`get_user_profile`) — TE 查询 L5072-5077 + ExpertMember 查询 L5078-5081 + 合并 L5082 | 同上 | `is_user_expert_sync(db, user_id)` |
| `secure_auth_routes.py` | 56-70 (`_check_is_expert`) | 双查 helper | 整函数删，改调用 `is_user_expert_sync` |

#### 7.2.2 多人活动权限检查

| 文件 | 行号 | 当前逻辑 | 改造 |
|------|------|----------|------|
| `multi_participant_routes.py` | 31 (import) | `from app.models import TaskExpertService, TaskExpert` | 改 import `from app.models_expert import Expert, ExpertMember` |
| `multi_participant_routes.py` | 1619, 1624 | 当前用户是否 TaskExpert | `is_user_expert_sync()` 或读 Expert 对象 |
| `multi_participant_routes.py` | 1887 | 同上 | 同上 |

#### 7.2.3 达人服务搜索（discovery）

| 文件 | 行号 | 当前逻辑 | 改造 |
|------|------|----------|------|
| `discovery_routes.py` | 747-792 (`_fetch_expert_services`) | JOIN `TaskExpertService.expert_id → TaskExpert → User` | JOIN `TaskExpertService.owner_type='expert' + owner_id → Expert`；personal 路径不变 |

#### 7.2.4 官方账户读取

| 文件 | 行号 | 当前逻辑 | 改造 |
|------|------|----------|------|
| `admin_official_routes.py` | 58-69 (`_get_official_expert`) | `SELECT TaskExpert WHERE is_official=True` | `SELECT Expert WHERE is_official=True` |
| `admin_official_routes.py` | 202-219 (`get_official_account`) | JOIN TaskExpert + User | 查 Expert + ExpertMember(owner) JOIN User，**返回 schema 不变** |

#### 7.2.5 用户 feed 展示

| 文件 | 行号 | 当前逻辑 | 改造 |
|------|------|----------|------|
| `follow_feed_routes.py` | 413 (注释), 421, 511, 569 | FTE alias 用于达人展示名/头像 | 切 FeaturedExpertV2 JOIN Expert；注释同步更新 |

#### 7.2.6 用户服务申请

| 文件 | 行号 | 当前逻辑 | 改造 |
|------|------|----------|------|
| `user_service_application_routes.py` | 117 | `db.get(TaskExpert, app.expert_id)` 取 expert_name | 改 `db.get(Expert, app.expert_id)` 取 `.name`（注意 app.expert_id 在新数据下是团队 id） |

#### 7.2.7 AI Agent 工具层（**原 spec 完全漏掉**）

| 文件 | 行号 | 当前逻辑 | 改造 |
|------|------|----------|------|
| `services/ai_tools.py` | 791-827 (`list_task_experts` tool) | 搜 TaskExpert.expert_name/.bio，按 rating 排序 | 搜 Expert.name/.bio，按 rating 排序 |
| `services/ai_tools.py` | 842-880 (`get_activity_detail`) 里 L860-862 | 查 activity.expert_id 的 expert_name | 查 Expert.name（activity.expert_id 在新数据下是团队 id） |
| `services/ai_tools.py` | 895-927 (某 get_expert_detail tool) | 查 expert 详情 + 服务列表 | 查 Expert + 通过 owner_type/owner_id 查 TaskExpertService |
| `services/ai_tools.py` | 1101-1118 (list_service_applications tool) | JOIN ServiceApplication + TaskExpertService + TaskExpert + User | JOIN ServiceApplication + TaskExpertService + Expert（通过 owner_id） |

### 7.3 Phase A 写路径改造

| 文件 | 行号 | 当前行为 | 改造 |
|------|------|----------|------|
| `admin_official_routes.py` | 80-192 (`setup_official_account`) | 双写 TaskExpert + Expert | 单写 Expert + ExpertMember + `_expert_id_migration_map`（删除 L94-113 TaskExpert 写入） |
| `crud/user.py` | 55 注释 + 87-110 统计同步 | 写 User + TaskExpert + FeaturedTaskExpert | 写 User + Expert（通过 `_expert_id_migration_map` 查 new_id）；不写 FeaturedExpertV2（其精简 schema 的 is_featured/display_order/category 由 admin_expert_routes 的 admin 操作驱动，Phase B 完整迁移） |
| `crud/task_expert.py` | 141-163 (`update_task_expert_bio`) — 聚合 success_rate (L141-145) + 写 FeaturedTaskExpert 7 个字段 response_time/response_time_en/avg_rating/completed_tasks/total_tasks/completion_rate/success_rate (L147-161) | 写 FeaturedTaskExpert | 改写 `Expert` 同名字段（通过映射查 new_id），success_rate 用 Phase A §6 新增列 |
| `crud/task_expert.py` | 166-168 (`update_all_task_experts_bio` — deprecated wrapper，委托给下一行函数) | — | 随下方函数一起处理 |
| `crud/task_expert.py` | 171-195 (`update_all_featured_task_experts_response_time` 定时任务) — L179 `db.query(FeaturedTaskExpert).all()` 遍历 | 遍历 FeaturedTaskExpert 调 `update_task_expert_bio` | 改遍历 `Expert` 表；**writing-plans 阶段需先 grep 该函数调用点确认是否活跃调度**（scheduled_tasks.py / celery tasks） |
| `crud/admin_ops.py` | 57 注释 + 73-74 | 删 admin 时检查 FeaturedTaskExpert.created_by | 改检查 FeaturedExpertV2.created_by（表结构相同） |

### 7.4 边缘改造

| 文件 | 行号 | 改造 |
|------|------|------|
| `cleanup_tasks.py` | 1158, 1162-1163, 1421, 1424-1425 | 图片清理遍历 `TaskExpert.id` → 遍历 `ExpertMember where role='owner'` 的 user_id（语义等价） |

### 7.5 Schema 变更与向后兼容（Q-B 决策）

新加字段 `expert_team_id`（Pydantic schema 层）：

```python
# schemas.py - 受影响的 Out schema (discovery/expert services 列表 + 详情)
class ExpertServiceListItemOut(BaseModel):
    ...
    expert_user_id: Optional[str] = None  # 保留 — 现在填 team id (值相同但语义变)
    expert_team_id: Optional[str] = None  # 新增 — 未来首选字段
    ...
```

读路径改造时：
- `expert_user_id` 和 `expert_team_id` 都返回团队 id（字符串相同）
- Phase D 在 Flutter/Web 切换到 `expert_team_id` 后，Phase D 末尾 PR 移除 `expert_user_id`

### 7.6 Phase A **不改**的引用（Phase B/C 范围）

以下文件的 TaskExpert / FeaturedTaskExpert 引用**Phase A 保留不动**，完成后仍应能 grep 到（归属 Phase B/C）：

#### Phase B 保留（admin 端路由，Phase B 整体迁移）

| 文件 | 引用数 | 说明 |
|------|--------|------|
| `routers.py` | TE ~28 处 (L12842-13576), FTE ~16 处 (L12705-13084) | `/api/admin/task-experts/*` + `/api/admin/featured-experts/*` 一整块 admin 端点 |
| `routers.py` L12973-13011 | TE 双写逻辑（admin 更新 FeaturedTaskExpert 时同步写 TaskExpert.expert_name/avatar） | Phase B 随 `admin_task_expert_routes.py` 下线一起处理 |
| `admin_task_expert_routes.py` | 全文件 (845 行) | Phase B 删 |

#### Phase C 保留（模型定义、Python import、死代码、注释）

| 文件 | 引用 | 说明 |
|------|------|------|
| `models.py` | `class TaskExpert`, `class FeaturedTaskExpert`, `class TaskExpertService`, relationship (L1646, 1787) | Phase C 删除模型类 |
| `main.py` | L1242 `FeaturedTaskExpert`, L1252 `TaskExpert`（ORM 初始化 import） | Phase C 删 import |
| `routers.py` | L13751-13809 `_deprecated_get_public_task_experts` 函数（路由已 comment 化） | 死代码，Phase C 或 D 清理 |
| `service_public_routes.py` | L11 注释（说明 user_id 语义） | Phase C 更新注释或删除 |
| `expert_routes.py` | L506 注释（说明迁移来源） | 可保留作为历史说明，或 Phase D 清理 |

#### Phase A 完成后的 DoD 自检命令

```bash
# 改动边界验证:以下命令返回的匹配行应该 **只** 出现在 §7.6 列出的 Phase B/C 文件/函数中
# 注意: pattern 用 \b 单词边界,不会误匹配 TaskExpertService (那是共享表,Phase A/C 都不动)
grep -rn "\bmodels\.TaskExpert\b\|\bmodels\.FeaturedTaskExpert\b\|\bTaskExpert\b\|\bFeaturedTaskExpert\b" backend/app/ | grep -v -E "TaskExpertService|\.pyc"
```

预期匹配（排除后应归零）:
- Phase A 完成后，此命令返回的行应全部来自 §7.6 列出的文件（`routers.py` L12694-13576 + L13751-13809 死代码、`admin_task_expert_routes.py`、`models.py` 模型定义、`main.py` imports、`service_public_routes.py`/`expert_routes.py` 注释）
- 如果返回行包含 §7.6 **未列出**的文件或行号，说明 Phase A 有遗漏

## 8. 验证策略

### 8.1 单元测试（必写）

**`backend/tests/utils/test_expert_helpers.py`**:
- `test_is_user_expert_sync_active_owner` — 有 active ExpertMember(owner) → True
- `test_is_user_expert_sync_inactive` — status='inactive' → False
- `test_is_user_expert_sync_no_membership` → False
- `test_is_user_expert_sync_multi_teams` — 任一 active 即 True
- `test_get_user_primary_expert_returns_owner_team` — 返回 owner 所属团队

**`backend/tests/migrations/test_209_sync_fields.py`**（testcontainers / pytest-postgresql）:
- `test_209_syncs_stats_from_task_experts` — rating/completed_tasks 回填
- `test_209_preserves_newer_expert_name` — updated_at 规则验证
- `test_209_backfills_bio_en_for_null_only` — COALESCE 策略验证
- `test_209_idempotent` — 重跑零副作用
- `test_209_raises_on_orphan_task_experts` — orphan 抛 EXCEPTION
- `test_209_syncs_success_rate` — 覆盖式回填

**执行**: `cd backend && pytest tests/utils tests/migrations -v`

### 8.2 Staging 冒烟（5 条核心流程）

| # | 流程 | 验证点 |
|---|------|--------|
| 1 | Flutter 登录已知 TaskExpert 用户 → 打开 profile | `/api/profile` 返回 `is_expert=true` |
| 2 | Admin 设置 user 为官方账号 | `experts` 有 `is_official=true` 行；`expert_members` 有 owner；`task_experts` **不再被写入** |
| 3 | Flutter 首页 → 达人服务 tab | 返回列表的 `expert_display_name/avatar/rating` 与 `experts` 表一致 |
| 4 | 关注 featured 达人 → Follow Feed 展示 | 达人头像/名字/评分正确 |
| 5 | 用户完成任务被评 5 星 | User.avg_rating ✓；Expert.rating ✓；`task_experts` **不再被写入** ✓ |

### 8.3 Full-Stack Consistency Check

CLAUDE.md 强制走一遍：`DB Model → Pydantic Schema → API Route → Frontend Endpoint → Repository → Model.fromJson → BLoC → UI`

Phase A 重点覆盖：
- `Expert.success_rate` 新字段 → 所有 Out schema → API 返回 → Flutter/Web 反序列化
- `/api/admin/official/account/*` 和 `/api/discovery/expert-services` 前后 JSON 逐字段对比

## 9. 发布流程

| Step | 动作 | 回滚 |
|------|------|------|
| T-1 | PR 进入 review | — |
| T+0 | Staging Railway deploy：migration 209 自动跑 + backend 代码部署 | migration 事务回滚；代码 revert |
| T+0.5 | Staging smoke test（§8.2 5 流程） | — |
| T+1 | Prod Railway deploy：migration 209 自动跑 + backend 代码 | 同 T+0 |
| T+2 | Prod 监控 30min（Sentry 搜 `AttributeError: TaskExpert`） | git revert + redeploy；数据无损（TE 表仍在） |

## 10. 风险清单

| # | 风险 | 影响 | 缓解 |
|---|------|------|------|
| R1 | migration 209 漏字段同步 → Expert 页面空/陈旧 | 中 | §6 字段对照表 + test_209_syncs_* 单测 |
| R2 | `is_user_expert_sync` 漏判老 TaskExpert 孤儿行（有 TaskExpert 行但没对应 ExpertMember） | 高（用户失去达人入口） | migration 209 内置 orphan EXCEPTION 检查（任何老 `task_experts` 行无映射会中止事务回滚）；上线前验证 staging `SELECT COUNT(*) FROM task_experts te LEFT JOIN expert_members em ON em.user_id = te.id AND em.status = 'active' WHERE em.id IS NULL` = 0 |
| R3 | 老 admin 面板读 TaskExpert 的画像数据分叉 | 中 | **Q-A 决策：接受分叉**，Phase B 前不动 |
| R4 | `task_expert_services.owner_id=NULL` 导致服务搜索漏项 | 中 | migration 209 检查 `service_type='expert' AND owner_id IS NULL` 为 0 |
| R5 | `crud/user.py` 多查 `_expert_id_migration_map` 性能损耗 | 低 | migration 209 给 `old_id` 加索引 |
| R6 | `admin_task_expert_routes.py` 仍能写 TaskExpert 表 | 中 | **Q-A 决策：接受分叉**，写入不影响读（读全切 Expert） |
| R7 | `expert_user_id` 字段值从 user_id 变 team_id 破坏客户端 | 高 | **Q-B 决策：同时返回 `expert_user_id` + `expert_team_id`**；Phase D 再删前者 |
| R8 | ALTER TABLE 锁表 | 低 | `ADD COLUMN ... DEFAULT 0.0` Postgres 11+ fast default |
| R9 | 大 PR 审查疲劳（§7 audit 显示实际改动 25+ 点 / 15 文件，含 AI 工具层 4 个 tool 大改） | 中-高 | PR 按 §7.2.1-7.2.7 的 7 个功能组分 commit，每个 commit 单一 scope；reviewer 可分组审 |

## 11. Open Questions 决议

| # | 问题 | 决议 |
|---|------|------|
| Q-A | Phase A → Phase B 过渡期策略 | **(1) 接受数据分叉** — 老 admin 面板改的画像不生效（读路径全切 Expert），影响 1-2 周；不禁用老 admin 写入 |
| Q-B | `expert_user_id` 字段语义迁移 | **(2) 保留 `expert_user_id` + 新加 `expert_team_id`** — 零破坏，Phase D 再删前者 |
| Q-C | migration 209 执行时机 | **(2) 随 Phase A PR deploy 时自动跑** — Railway startup hook |

## 12. 遗留到 Phase B/C/D 的事项

**Phase B**:
- 下线 `admin_task_expert_routes.py` (845 行)
- admin 前端 `ExpertManagement.tsx` 全部迁到 `/api/admin/experts/*`
- `/api/admin/official/*` 的 admin 端端点审查

**Phase C**:
- 写最终 catch-up migration（把 Phase A → B 之间可能产生的 TaskExpert 表写入同步回 Expert）
- DROP 4 张 legacy 表（`task_experts` / `task_expert_applications` / `task_expert_profile_update_requests` / `featured_task_experts`）
- 删除 `TaskExpert` / `TaskExpertService` / `FeaturedTaskExpert` 模型类
- 决定是否保留 `_expert_id_migration_map`（建议保留作为历史索引）

**Phase D**:
- Flutter `task_expert_model.dart` → `expert_model.dart`
- Flutter cache key / route 路径命名清理
- Web `api.ts` 中 `getExpertByUser` 等残留命名
- Phase A 里 `expert_user_id` 字段的客户端切换到 `expert_team_id`，Phase D 末删除 `expert_user_id`

---

## 修订历史

- **2026-04-19 v1.0** 初始 spec，§7 代码改造列 "11 处 TaskExpert + 10 处 FeaturedTaskExpert"（基于早期 Explore agent audit）
- **2026-04-19 v1.2** 二次核验：逐一 grep 核对 §7 所有行号，修正 v1.1 中记忆错误的几处行号：
  - `routers.py:4804-4808` → **实际 4787-4791**（`get_my_profile` 的 ExpertMember 双查部分）
  - `routers.py:5089-5093` → **实际 5078-5082**（`get_user_profile` 同上）
  - `crud/task_expert.py:141-165` 函数名 `update_task_expert_featured_response_time` → **实际 `update_task_expert_bio` L141-163**
  - `crud/task_expert.py:172-179` 函数名 `update_all_response_times` → **实际 `update_all_featured_task_experts_response_time` L171-195**；补齐 deprecated wrapper `update_all_task_experts_bio` L166-168
  - R2 缓解措施改为具体的 SQL orphan 自检查询
  - §7.6 DoD 自检 grep 命令加 `grep -v TaskExpertService` 排除共享表误报
  - §3 DoD 条 1 措辞精确化（按"代码位置"而非"文件"判定）
- **2026-04-19 v1.1** 自检发现 v1.0 严重低估改动面：实际 `TaskExpert` 87 处 / 13 文件，`FeaturedTaskExpert` 55 处 / 8 文件。重写 §7 分为：
  - §7.2 **Phase A 读路径**（7 类：is_expert 判断 / 多人活动 / discovery / 官方账户 / follow feed / 用户服务申请 / AI 工具层）
  - §7.3 **Phase A 写路径**
  - §7.4 边缘
  - §7.5 Schema 扩展
  - §7.6 **Phase A 不改的引用**（明确列出 Phase B / Phase C 保留的引用，含 `routers.py` L12694-13576 的 admin 端整块和死代码 `_deprecated_get_public_task_experts`）
  - §3 DoD 条 1 同步精确化；§10 R9 升级为"中-高"
  - 新发现的 Phase A 文件：`secure_auth_routes.py` (5 处) / `services/ai_tools.py` (15 处, 4 个 AI tool 大改) / `user_service_application_routes.py` (1 处) / `crud/task_expert.py:172-179` 定时任务
