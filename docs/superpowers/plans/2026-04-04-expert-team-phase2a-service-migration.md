# 达人团队体系 Phase 2a — 服务表迁移

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给 `task_expert_services` 表新增 `owner_type` + `owner_id` 列并回填数据，更新 SQLAlchemy 模型。现有路由继续工作（使用旧列），为 Phase 2b 新路由做好准备。

**Architecture:** 采用「加列 + 回填 + 双写」策略，不重命名表、不删旧列。新增 `owner_type`（'expert'/'user'）和 `owner_id`（新 experts.id 或 users.id）列，通过迁移脚本从旧列回填。模型同时保留新旧字段，新代码读写新列，旧代码继续读写旧列。旧列在 Phase 2d 清理时删除。

**Tech Stack:** PostgreSQL, SQLAlchemy (async), Python 3.11

**Spec:** `docs/superpowers/specs/2026-04-04-expert-team-redesign.md` — "services" 表设计
**依赖:** Phase 1a 已完成（`experts` 表和 `_expert_id_migration_map` 映射表已存在）

---

## File Structure

### New Files
- `backend/migrations/160_add_owner_columns_to_services.sql` — 加列
- `backend/migrations/161_backfill_service_owner.sql` — 回填数据

### Modified Files
- `backend/app/models.py` — TaskExpertService 模型加新列 + 更新 ServiceApplication.expert_id FK
- `backend/app/models_expert.py` — Expert 模型加 services relationship

---

## Task 1: 数据库迁移 — 加列

**Files:**
- Create: `backend/migrations/160_add_owner_columns_to_services.sql`

- [ ] **Step 1: 编写加列 SQL**

```sql
-- ===========================================
-- 迁移 160: 给 task_expert_services 添加 owner_type + owner_id 列
-- ===========================================
--
-- 新增列：owner_type ('expert' | 'user')，owner_id (VARCHAR(8))
-- 不删除旧列（expert_id, service_type, user_id），保持向后兼容
-- 旧代码继续使用旧列，新代码使用新列
--
-- 执行时间: 2026-04-04
-- ===========================================

BEGIN;

-- 添加新列
ALTER TABLE task_expert_services
    ADD COLUMN IF NOT EXISTS owner_type VARCHAR(20),
    ADD COLUMN IF NOT EXISTS owner_id VARCHAR(8);

-- 添加约束（新列允许 NULL，回填后再设 NOT NULL）
-- owner_type 只允许 'expert' 或 'user'
ALTER TABLE task_expert_services
    DROP CONSTRAINT IF EXISTS chk_service_owner_type;
ALTER TABLE task_expert_services
    ADD CONSTRAINT chk_service_owner_type
    CHECK (owner_type IS NULL OR owner_type IN ('expert', 'user'));

-- 给 service_applications 添加 new_expert_id 列（指向新 experts 表）
ALTER TABLE service_applications
    ADD COLUMN IF NOT EXISTS new_expert_id VARCHAR(8);

-- 索引（先建，回填时不需要再建）
CREATE INDEX IF NOT EXISTS ix_services_owner ON task_expert_services(owner_type, owner_id)
    WHERE owner_type IS NOT NULL;

COMMIT;
```

- [ ] **Step 2: Commit**

```bash
git add backend/migrations/160_add_owner_columns_to_services.sql
git commit -m "db: add owner_type/owner_id columns to task_expert_services (migration 160)"
```

---

## Task 2: 数据库迁移 — 回填

**Files:**
- Create: `backend/migrations/161_backfill_service_owner.sql`

- [ ] **Step 1: 编写回填 SQL**

```sql
-- ===========================================
-- 迁移 161: 回填 task_expert_services 的 owner_type + owner_id
-- ===========================================
--
-- 利用 _expert_id_migration_map（Phase 1a 创建）将旧 expert_id → 新 experts.id
-- 个人服务的 owner_id 直接用 user_id
--
-- 依赖：迁移 158（experts 表）、迁移 159（_expert_id_migration_map）、迁移 160（新列）
-- 执行时间: 2026-04-04
-- ===========================================

BEGIN;

-- 1. 回填达人服务：service_type = 'expert'
-- owner_type = 'expert', owner_id = 新 experts.id（通过映射表）
UPDATE task_expert_services s
SET
    owner_type = 'expert',
    owner_id = m.new_id
FROM _expert_id_migration_map m
WHERE s.expert_id = m.old_id
  AND s.service_type = 'expert'
  AND s.owner_type IS NULL;

-- 2. 回填个人服务：service_type = 'personal'
-- owner_type = 'user', owner_id = user_id
UPDATE task_expert_services
SET
    owner_type = 'user',
    owner_id = user_id
WHERE service_type = 'personal'
  AND owner_type IS NULL
  AND user_id IS NOT NULL;

-- 3. 回填 service_applications.new_expert_id
UPDATE service_applications sa
SET new_expert_id = m.new_id
FROM _expert_id_migration_map m
WHERE sa.expert_id = m.old_id
  AND sa.new_expert_id IS NULL;

-- 4. 验证回填结果
DO $$
DECLARE
    unfilled_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO unfilled_count
    FROM task_expert_services
    WHERE owner_type IS NULL;
    
    IF unfilled_count > 0 THEN
        RAISE WARNING '% services still have NULL owner_type after backfill', unfilled_count;
    END IF;
END $$;

-- 5. 设置 NOT NULL 约束（仅当所有行都已回填时）
-- 如果有未回填的行，这步会失败，需要手动检查
DO $$
DECLARE
    unfilled_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO unfilled_count
    FROM task_expert_services
    WHERE owner_type IS NULL;
    
    IF unfilled_count = 0 THEN
        EXECUTE 'ALTER TABLE task_expert_services ALTER COLUMN owner_type SET NOT NULL';
        EXECUTE 'ALTER TABLE task_expert_services ALTER COLUMN owner_id SET NOT NULL';
        RAISE NOTICE 'owner_type and owner_id set to NOT NULL';
    ELSE
        RAISE NOTICE 'Skipping NOT NULL — % rows still unfilled', unfilled_count;
    END IF;
END $$;

COMMIT;
```

- [ ] **Step 2: Commit**

```bash
git add backend/migrations/161_backfill_service_owner.sql
git commit -m "db: backfill owner_type/owner_id from legacy columns (migration 161)"
```

---

## Task 3: 更新 SQLAlchemy 模型 — TaskExpertService

**Files:**
- Modify: `backend/app/models.py` (TaskExpertService 类)

- [ ] **Step 1: 给 TaskExpertService 添加新列**

在 `backend/app/models.py` 的 `TaskExpertService` 类中，在 `user_id` 列之后添加：

```python
    # 新多态 owner 列（Phase 2a）——与旧列共存，新代码用新列
    owner_type = Column(String(20), nullable=True)  # 'expert' | 'user'，回填后为 NOT NULL
    owner_id = Column(String(8), nullable=True)  # experts.id 或 users.id，回填后为 NOT NULL
```

- [ ] **Step 2: 更新 owner_user_id 属性**

更新现有的 `owner_user_id` 属性，优先使用新列：

```python
    @property
    def owner_user_id(self):
        """Resolve owner user ID regardless of service type.
        
        New path (Phase 2a+): use owner_type + owner_id
        Legacy path: use service_type + expert_id/user_id
        """
        # 新列优先
        if self.owner_type == 'user':
            return self.owner_id
        if self.owner_type == 'expert':
            # expert 服务的 owner 是 expert 的 owner 成员，需要查询
            # 但这里返回 owner_id（expert team id），调用方需知道这不是 user_id
            return self.expert_id  # 保持旧行为兼容
        # 旧列兜底
        if self.service_type == "personal":
            return self.user_id
        return self.expert_id
```

- [ ] **Step 3: 添加索引到 __table_args__**

在 `TaskExpertService.__table_args__` 中添加：

```python
        Index("ix_services_owner", "owner_type", "owner_id"),
```

- [ ] **Step 4: Commit**

```bash
git add backend/app/models.py
git commit -m "feat: add owner_type/owner_id columns to TaskExpertService model"
```

---

## Task 4: 更新 SQLAlchemy 模型 — Expert relationship

**Files:**
- Modify: `backend/app/models_expert.py` (Expert 类)

- [ ] **Step 1: 给 Expert 添加 services relationship**

在 `backend/app/models_expert.py` 的 `Expert` 类的 relationships 区域添加：

```python
    # 达人服务（通过 owner_type='expert' + owner_id=self.id 关联）
    # 使用 primaryjoin 因为不是标准 FK（owner_id 是多态的）
    # 注意：这个 relationship 在回填完成前不可用
```

实际上，由于 `owner_id` 是多态字段（不是标准 FK），不应该用 SQLAlchemy relationship。改为在路由中用查询：

```python
# 在路由中查询达人服务：
# select(TaskExpertService).where(
#     and_(TaskExpertService.owner_type == 'expert', TaskExpertService.owner_id == expert_id)
# )
```

所以 Task 4 实际不需要改 models_expert.py。跳过。

- [ ] **Step 1: 验证模型可正常导入**

Run: `cd backend && python -c "from app.models import TaskExpertService; print(hasattr(TaskExpertService, 'owner_type'))"`
Expected: `True`

- [ ] **Step 2: Commit（如有改动）**

如果 Task 3 的改动尚未提交，合并提交。

---

## Task 5: 更新 ServiceApplication 模型

**Files:**
- Modify: `backend/app/models.py` (ServiceApplication 类)

- [ ] **Step 1: 给 ServiceApplication 添加 new_expert_id 列**

在 `ServiceApplication` 类中，在 `expert_id` 列之后添加：

```python
    # 指向新 experts 表的 ID（Phase 2a）——与旧 expert_id 共存
    new_expert_id = Column(String(8), nullable=True)  # 指向 experts.id（新表）
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/models.py
git commit -m "feat: add new_expert_id column to ServiceApplication model"
```

---

## Task 6: 补充后端端点 — GET /my-invitations + ExpertOut.my_role

**Files:**
- Modify: `backend/app/expert_routes.py`
- Modify: `backend/app/schemas_expert.py`

Phase 1b code review 发现两个后端缺口，趁 Phase 2a 一起补上：

- [ ] **Step 1: 给 ExpertOut schema 添加 my_role 字段**

在 `backend/app/schemas_expert.py` 的 `ExpertOut` 类中添加：

```python
    my_role: Optional[str] = None  # 当前用户在此团队中的角色（接口层填充）
```

- [ ] **Step 2: 更新 my-teams 端点返回 my_role**

在 `backend/app/expert_routes.py` 的 `list_my_teams` 函数中，修改查询以包含成员角色：

```python
@expert_router.get("/my-teams", response_model=List[ExpertOut])
async def list_my_teams(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """查看我加入的团队"""
    result = await db.execute(
        select(Expert, ExpertMember.role)
        .join(ExpertMember, ExpertMember.expert_id == Expert.id)
        .where(
            and_(
                ExpertMember.user_id == current_user.id,
                ExpertMember.status == "active",
                Expert.status.in_(["active", "inactive"]),
            )
        )
        .order_by(Expert.created_at.desc())
    )
    rows = result.all()

    # 批量查询关注状态
    expert_ids = [e.id for e, _ in rows]
    followed_ids: set = set()
    if expert_ids:
        follow_result = await db.execute(
            select(ExpertFollow.expert_id).where(
                and_(
                    ExpertFollow.user_id == current_user.id,
                    ExpertFollow.expert_id.in_(expert_ids),
                )
            )
        )
        followed_ids = set(follow_result.scalars().all())

    out = []
    for expert, role in rows:
        d = ExpertOut.model_validate(expert)
        d.is_following = expert.id in followed_ids
        d.my_role = role
        out.append(d)
    return out
```

- [ ] **Step 3: 添加 GET /my-invitations 端点**

在 `backend/app/expert_routes.py` 中添加：

```python
@expert_router.get("/my-invitations", response_model=List[ExpertInvitationOut])
async def list_my_invitations(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """查看我收到的团队邀请"""
    result = await db.execute(
        select(ExpertInvitation, Expert)
        .join(Expert, Expert.id == ExpertInvitation.expert_id)
        .where(
            and_(
                ExpertInvitation.invitee_id == current_user.id,
                ExpertInvitation.status == "pending",
            )
        )
        .order_by(ExpertInvitation.created_at.desc())
    )
    rows = result.all()
    out = []
    for invitation, expert in rows:
        d = ExpertInvitationOut.model_validate(invitation)
        d.invitee_name = current_user.name
        d.invitee_avatar = current_user.avatar
        out.append(d)
    return out
```

注意：需要在文件顶部导入中确认 `ExpertInvitation` 和 `ExpertInvitationOut` 已导入（Phase 1a 已添加）。

同时需要在 `ExpertInvitationOut` schema 中添加团队信息字段：

```python
# 在 schemas_expert.py 的 ExpertInvitationOut 中添加：
    expert_name: Optional[str] = None
    expert_avatar: Optional[str] = None
```

- [ ] **Step 4: 在 api_endpoints.dart 添加 my-invitations 端点**

在 Flutter `api_endpoints.dart` 中添加：

```dart
static const String expertTeamMyInvitations = '/api/experts/my-invitations';
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/expert_routes.py backend/app/schemas_expert.py link2ur/lib/core/constants/api_endpoints.dart
git commit -m "feat: add GET /my-invitations endpoint and my_role to ExpertOut"
```

---

## Self-Review Checklist

- [x] **Spec coverage:** services 表 owner_type/owner_id ✅, 数据回填 ✅, ServiceApplication.new_expert_id ✅, Phase 1b 缺口补充 ✅
- [x] **Placeholder scan:** 无 TBD/TODO（owner_type 在迁移中处理了 NULL 情况）
- [x] **Type consistency:** owner_type='expert'/'user', owner_id VARCHAR(8) 全文一致
- [x] **Not in scope:** 新服务路由（Phase 2b）、Flutter 服务适配（Phase 2c）、旧路由清理（Phase 2d）
- [x] **Backward compatibility:** 旧列不删除，旧路由继续工作，新列允许 NULL 直到回填完成
