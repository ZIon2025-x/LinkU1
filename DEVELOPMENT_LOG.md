# 活动与任务分离重构 - 完整开发日志

## 项目概述

本次重构将任务达人发布的多人活动从任务表中分离出来，创建独立的 `activities` 表，实现活动与任务的清晰分离。用户申请活动后，会在任务表中创建对应的任务，但活动本身保持独立。

## 重构背景

### 原有问题
1. 多人活动和普通任务混在一起，容易混淆
2. 活动状态和任务状态耦合，难以管理
3. 时间段关联逻辑复杂，难以维护
4. 数据查询和统计困难

### 重构目标
1. **清晰分离**：活动表和任务表分开，职责明确
2. **灵活管理**：活动可以独立管理，不受任务状态影响
3. **易于扩展**：活动可以关联多个任务，支持复杂的业务场景
4. **数据一致性**：通过外键和约束保证数据完整性

---

## 数据库设计

### 1. 活动表（activities）

**表结构**：
```sql
CREATE TABLE activities (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    expert_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expert_service_id INTEGER NOT NULL REFERENCES task_expert_services(id) ON DELETE RESTRICT,
    location VARCHAR(100) NOT NULL,
    task_type VARCHAR(50) NOT NULL,
    -- 价格相关
    reward_type VARCHAR(20) NOT NULL DEFAULT 'cash',
    original_price_per_participant DECIMAL(12, 2),
    discount_percentage DECIMAL(5, 2),
    discounted_price_per_participant DECIMAL(12, 2),
    currency VARCHAR(3) DEFAULT 'GBP',
    points_reward BIGINT,
    -- 参与者相关
    max_participants INTEGER NOT NULL DEFAULT 1,
    min_participants INTEGER NOT NULL DEFAULT 1,
    completion_rule VARCHAR(20) NOT NULL DEFAULT 'all',
    reward_distribution VARCHAR(20) NOT NULL DEFAULT 'equal',
    -- 活动状态
    status VARCHAR(20) NOT NULL DEFAULT 'open',
    is_public BOOLEAN DEFAULT TRUE,
    visibility VARCHAR(20) DEFAULT 'public',
    -- 截止日期
    deadline TIMESTAMPTZ,
    activity_end_date DATE,
    -- 图片
    images JSONB,
    -- 时间段相关
    has_time_slots BOOLEAN DEFAULT FALSE,
    -- 时间戳
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
```

**关键字段说明**：
- `expert_id`: 发布活动的任务达人ID
- `expert_service_id`: 关联的服务ID
- `status`: 活动状态（open, completed, cancelled）
- `has_time_slots`: 是否关联时间段服务
- `deadline`: 非时间段服务的截止日期
- `activity_end_date`: 时间段服务的活动结束日期

### 2. 活动时间段关联表（activity_time_slot_relations）

**表结构**：
```sql
CREATE TABLE activity_time_slot_relations (
    id SERIAL PRIMARY KEY,
    activity_id INTEGER NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    time_slot_id INTEGER REFERENCES service_time_slots(id) ON DELETE CASCADE,
    relation_mode VARCHAR(20) NOT NULL DEFAULT 'fixed',
    recurring_rule JSONB,
    auto_add_new_slots BOOLEAN NOT NULL DEFAULT TRUE,
    activity_end_date DATE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    -- 唯一约束：固定模式下，一个时间段只能被一个活动使用
    CONSTRAINT uq_activity_time_slot_fixed UNIQUE (time_slot_id) 
        WHERE relation_mode = 'fixed' AND time_slot_id IS NOT NULL
);
```

**关联模式**：
- `fixed`: 固定时间段模式，选择具体的时间段ID
- `recurring`: 重复模式，使用 `recurring_rule` 定义规则
  - `recurring_daily`: 每天重复，指定时间范围
  - `recurring_weekly`: 每周重复，指定星期几和时间范围

### 3. 任务表扩展（tasks）

**新增字段**：
- `parent_activity_id`: 关联的活动ID（如果任务是从活动申请创建的）
- `originating_user_id`: 记录实际申请人（冗余字段，便于查询）

**外键约束**：
- `parent_activity_id` → `activities.id` ON DELETE RESTRICT（防止活动被删除）

### 4. 任务参与者表扩展（task_participants）

**新增字段**：
- `activity_id`: 冗余字段，关联的活动ID（性能优化）

---

## 后端实现

### 1. 数据模型（models.py）

**新增模型**：
- `Activity`: 活动模型
- `ActivityTimeSlotRelation`: 活动时间段关联模型

**更新模型**：
- `Task`: 添加 `parent_activity_id` 和 `originating_user_id` 字段
- `TaskParticipant`: 添加 `activity_id` 冗余字段
- `TaskExpertService`: 添加 `activities` 关系

### 2. API 端点（multi_participant_routes.py）

**新增端点**：

1. **`POST /api/expert/activities`** - 创建活动
   - 验证任务达人身份
   - 验证服务归属
   - 处理时间段选择（固定/每天重复/每周重复）
   - 创建活动和时间段关联

2. **`GET /api/activities`** - 获取活动列表
   - 支持按 `expert_id` 和 `status` 筛选
   - 支持分页

3. **`POST /api/activities/{activity_id}/apply`** - 申请参与活动
   - **非时间段服务**：创建单个任务，用户是发布者（付钱），达人是接收者（收钱）
   - **时间段服务**：创建多人任务，包含时间段信息，创建 TaskParticipant 记录
   - 验证活动状态和截止日期
   - 防止重复申请

4. **`DELETE /api/expert/activities/{activity_id}`** - 删除活动
   - 验证权限（只能删除自己的活动）
   - 检查活动状态（已完成或已取消的不允许删除）
   - 检查是否有已开始的任务（如果有，不允许删除）
   - 取消活动并自动取消关联的未开始任务

**重要业务逻辑**：

1. **任务方向**：
   - `poster_id` = 申请者（付钱的）
   - `taker_id` = 任务达人（收钱的）
   - `originating_user_id` = 申请者（记录实际申请人）

2. **时间段冲突检测**：
   - 创建活动时检查时间段是否已被其他活动使用
   - 使用唯一约束防止固定时间段冲突

3. **自动时间段添加**：
   - 重复模式下，当服务生成新时间段时，自动匹配并添加到活动
   - 检查 `activity_end_date`，超过日期不再添加

### 3. 活动结束逻辑（task_expert_routes.py）

**函数**：`check_and_end_activities`

**结束条件**：
1. **时间段服务**：
   - 达到 `activity_end_date`（如果设置）
   - 最后一个时间段已结束，且没有未来的匹配时间段

2. **非时间段服务**：
   - 达到 `deadline`

**自动处理**：
- 活动结束时，自动取消关联的未开始任务（状态为 `open` 或 `taken`）
- 记录审计日志

**定时任务**：
- 每5分钟自动执行一次
- 在 `scheduled_tasks.py` 中集成

### 4. 数据迁移脚本

**迁移 015**：`015_create_activities_table.sql`
- 创建 `activities` 表
- 创建 `activity_time_slot_relations` 表

**迁移 016**：`016_add_parent_activity_id_foreign_key.sql`
- 添加 `parent_activity_id` 外键约束（旧版本，将被018替换）

**迁移 017**：`017_migrate_existing_multi_participant_tasks_to_activities.sql` ⭐ **关键**
- 将现有的多人任务迁移到活动表
- 迁移时间段关联
- 更新任务的 `parent_activity_id`
- 包含完整的验证和统计

**迁移 018**：`018_fix_parent_activity_id_foreign_key_and_add_constraints.sql`
- 修复外键约束（SET NULL → RESTRICT）
- 添加固定时间段唯一约束
- 添加 `TaskParticipant.activity_id` 字段
- 添加 `Task.originating_user_id` 字段

---

## 前端实现

### 1. 任务达人页面（TaskExperts.tsx）

**功能**：
- 显示任务达人发布的多人活动
- 使用"活动卡片实例10"样式
- 支持折扣显示（原价删除线 + 现价）
- 点击卡片显示活动详情弹窗
- 支持申请参与活动

**API 调用**：
- `GET /api/activities?expert_id={expert_id}&status=open`

### 2. 任务大厅（Tasks.tsx）

**功能**：
- 同时显示活动和任务
- 活动优先显示，使用活动卡片样式
- 避免重复显示（已关联任务的活动不再单独显示）
- 支持申请参与活动

**数据加载**：
- 从 `/api/activities` 获取活动列表
- 从 `/api/tasks` 获取任务列表
- 合并显示，活动在前

### 3. 任务达人管理页面（TaskExpertDashboard.tsx）

**功能**：
- "我的多人活动"标签页显示自己发布的活动
- **按任务分组显示参与者**（修复了参与者混乱问题）
- 支持批准/拒绝参与者申请
- 支持处理退出申请
- **支持删除活动**（只有创建者可以删除）

**参与者显示逻辑**：
- 数据结构：`{activityId: {taskId: [participants]}}`
- UI 显示：按任务分组，每个任务独立显示参与者列表
- 操作按钮：使用正确的 `task_id`

**删除活动功能**：
- 删除按钮：只有活动创建者可见
- 确认对话框：说明删除后果
- 后端验证：检查活动状态和关联任务
- 自动处理：取消关联的未开始任务

---

## 问题修复记录

### 审查发现的问题及修复

#### ✅ 1. 历史数据迁移脚本缺失（★★★★★ 唯一致命）

**问题**：没有数据迁移脚本，上线后历史多人活动会丢失

**修复**：
- 创建 `017_migrate_existing_multi_participant_tasks_to_activities.sql`
- 完整的迁移逻辑，包含验证和统计
- 使用事务确保数据一致性

#### ✅ 2. parent_activity_id 外键约束问题（★★★★☆）

**问题**：使用 `ON DELETE SET NULL`，活动删除后任务关联丢失

**修复**：
- 改为 `ON DELETE RESTRICT`
- 防止活动被删除，保证数据完整性

#### ✅ 3. 固定时间段唯一约束缺失（★★★★☆）

**问题**：固定时间段可被多个活动绑定，导致冲突

**修复**：
- 添加部分唯一索引：`uq_activity_time_slot_fixed`
- 确保固定模式下，一个时间段只能被一个活动使用

#### ✅ 4. 前端参与者展示混乱（★★★☆☆）

**问题**：一个活动对应多个任务时，参与者混在一起显示

**修复**：
- 数据结构改为按任务分组：`{activityId: {taskId: [participants]}}`
- UI 按任务分组显示，每个任务独立显示参与者列表
- 添加任务标题和ID，便于区分

#### ✅ 5. 活动关闭后任务未自动处理（★★★☆☆）

**问题**：活动结束时，关联的任务状态没有自动更新

**修复**：
- `check_and_end_activities` 函数自动取消关联的未开始任务
- 记录审计日志
- 定时任务每5分钟执行一次

#### ✅ 6. 任务方向问题（★★★★☆）

**问题**：申请活动时创建的任务，`poster_id` 和 `taker_id` 方向反了

**修复**：
- `poster_id` = 申请者（付钱的）
- `taker_id` = 任务达人（收钱的）
- 添加 `originating_user_id` 记录实际申请人

#### ✅ 7. TaskParticipant.activity_id 冗余字段（★★★☆☆）

**问题**：统计活动参与人数需要 join，性能差

**修复**：
- 添加 `activity_id` 冗余字段
- 创建参与者时自动设置
- 提升查询性能

#### ✅ 8. 时间段冲突检测（创建活动时）（★★★☆☆）

**问题**：创建活动时没有检查时间段冲突

**修复**：
- 创建活动时检查时间段是否已被其他活动使用
- 固定模式和重复模式都有冲突检测

#### ✅ 9. 删除活动功能（新增需求）

**问题**：任务达人无法删除自己创建的活动

**修复**：
- 添加 `DELETE /api/expert/activities/{activity_id}` API
- 验证权限和活动状态
- 自动取消关联的未开始任务
- 前端添加删除按钮和确认对话框

---

## 当前系统状态

### 数据库结构

✅ **已创建的表**：
- `activities` - 活动表
- `activity_time_slot_relations` - 活动时间段关联表

✅ **已扩展的表**：
- `tasks` - 添加 `parent_activity_id` 和 `originating_user_id`
- `task_participants` - 添加 `activity_id`

✅ **已添加的约束**：
- `parent_activity_id` 外键约束（RESTRICT）
- 固定时间段唯一约束
- 各种检查约束

### 后端功能

✅ **已实现的 API**：
1. `POST /api/expert/activities` - 创建活动
2. `GET /api/activities` - 获取活动列表
3. `POST /api/activities/{activity_id}/apply` - 申请参与活动
4. `DELETE /api/expert/activities/{activity_id}` - 删除活动

✅ **已实现的逻辑**：
1. 时间段选择（固定/每天重复/每周重复）
2. 时间段冲突检测
3. 自动时间段添加（重复模式）
4. 活动自动结束检查
5. 活动删除时的任务自动取消

### 前端功能

✅ **已实现的页面**：
1. **任务达人页面**（TaskExperts.tsx）
   - 显示达人发布的多人活动
   - 活动卡片和详情弹窗
   - 支持申请参与

2. **任务大厅**（Tasks.tsx）
   - 同时显示活动和任务
   - 活动卡片样式
   - 支持申请参与

3. **任务达人管理页面**（TaskExpertDashboard.tsx）
   - 我的多人活动列表
   - 按任务分组显示参与者
   - 参与者管理（批准/拒绝）
   - 删除活动功能

### 数据迁移

✅ **迁移脚本**：
1. `015_create_activities_table.sql` - 创建活动表
2. `016_add_parent_activity_id_foreign_key.sql` - 添加外键（旧版本）
3. `017_migrate_existing_multi_participant_tasks_to_activities.sql` - **数据迁移（关键）**
4. `018_fix_parent_activity_id_foreign_key_and_add_constraints.sql` - 修复约束

### 待执行事项

⚠️ **上线前必须执行**：
1. **备份数据库**（必须！）
2. **在测试环境完整测试所有迁移脚本**
3. **验证数据迁移结果**
4. **测试所有功能**

---

## 核心业务逻辑

### 活动创建流程

1. 任务达人选择服务（必须关联服务）
2. 填写活动信息（标题、描述、价格、参与者数量等）
3. **如果服务有时间段**：
   - 选择时间段模式（固定/每天重复/每周重复）
   - 固定模式：选择具体的时间段ID
   - 重复模式：设置时间范围和规则
   - 设置是否自动添加新时间段
   - 可选：设置活动结束日期
4. 创建活动记录
5. 创建时间段关联记录

### 活动申请流程

1. 用户查看活动详情
2. 点击"申请参与"
3. **后端处理**：
   - 验证活动状态和截止日期
   - 检查是否已申请过
   - **非时间段服务**：
     - 创建单个任务
     - `poster_id` = 用户（付钱的）
     - `taker_id` = 达人（收钱的）
   - **时间段服务**：
     - 选择时间段
     - 创建多人任务
     - 创建 TaskParticipant 记录
4. 返回成功，前端刷新

### 活动结束流程

1. **定时任务检查**（每5分钟）：
   - 查询所有开放中的活动
   - 检查结束条件：
     - 时间段服务：最后一个时间段结束 + 没有未来时间段
     - 非时间段服务：达到截止日期
2. **自动处理**：
   - 更新活动状态为 `completed`
   - 取消关联的未开始任务
   - 记录审计日志

### 活动删除流程

1. 任务达人点击"删除活动"
2. **前端确认**：显示确认对话框
3. **后端验证**：
   - 验证用户是否为任务达人
   - 验证活动是否属于当前用户
   - 检查活动状态（已完成/已取消的不允许删除）
   - 检查是否有已开始的任务（如果有，不允许删除）
4. **执行删除**：
   - 更新活动状态为 `cancelled`
   - 取消关联的未开始任务
   - 记录审计日志
5. 返回成功，前端刷新

---

## 技术亮点

### 1. 数据分离设计

- 活动表和任务表完全分离
- 通过 `parent_activity_id` 关联
- 支持一个活动对应多个任务

### 2. 时间段管理

- 支持固定和重复两种模式
- 自动匹配和添加新时间段
- 唯一约束防止冲突

### 3. 数据一致性

- 外键约束（RESTRICT）防止数据丢失
- 唯一约束防止时间段冲突
- 冗余字段提升查询性能

### 4. 前端优化

- 按任务分组显示参与者，避免混乱
- 活动卡片和详情弹窗统一样式
- 支持折扣显示

### 5. 自动化处理

- 定时任务自动结束活动
- 活动结束时自动取消任务
- 删除活动时自动取消任务

---

## 文件清单

### 后端文件

**模型和路由**：
- `backend/app/models.py` - 数据模型（Activity, ActivityTimeSlotRelation）
- `backend/app/multi_participant_routes.py` - 活动相关API
- `backend/app/task_expert_routes.py` - 活动结束逻辑
- `backend/app/scheduled_tasks.py` - 定时任务集成
- `backend/app/schemas.py` - API 请求/响应模型

**数据库迁移**：
- `backend/migrations/015_create_activities_table.sql` - 创建活动表
- `backend/migrations/016_add_parent_activity_id_foreign_key.sql` - 添加外键（旧版本）
- `backend/migrations/017_migrate_existing_multi_participant_tasks_to_activities.sql` - **数据迁移（关键）**
- `backend/migrations/018_fix_parent_activity_id_foreign_key_and_add_constraints.sql` - 修复约束

**文档**：
- `backend/migrations/FIXES_SUMMARY.md` - 修复总结
- `backend/migrations/ISSUES_VERIFICATION.md` - 问题验证清单

### 前端文件

**页面组件**：
- `frontend/src/pages/TaskExperts.tsx` - 任务达人页面（显示活动）
- `frontend/src/pages/Tasks.tsx` - 任务大厅（显示活动和任务）
- `frontend/src/pages/TaskExpertDashboard.tsx` - 任务达人管理页面（管理活动）

**API 函数**：
- `frontend/src/api.ts` - API 调用函数（getActivities, applyToActivity, deleteActivity）

---

## 测试建议

### 1. 数据迁移测试

```sql
-- 执行迁移前检查
SELECT COUNT(*) FROM tasks 
WHERE is_multi_participant = true AND expert_creator_id IS NOT NULL;

-- 执行迁移后验证
SELECT COUNT(*) FROM activities;
SELECT COUNT(*) FROM tasks WHERE parent_activity_id IS NOT NULL;
```

### 2. 功能测试

1. **活动创建**：
   - 创建固定时间段活动
   - 创建每天重复活动
   - 创建每周重复活动
   - 创建非时间段活动

2. **活动申请**：
   - 申请非时间段活动
   - 申请时间段活动
   - 测试重复申请（应该失败）

3. **活动管理**：
   - 查看活动列表
   - 查看参与者（按任务分组）
   - 批准/拒绝参与者
   - 删除活动

4. **活动结束**：
   - 等待定时任务执行
   - 或手动触发检查
   - 验证任务是否自动取消

### 3. 边界情况测试

1. 时间段冲突检测
2. 活动删除时的任务处理
3. 活动结束时的任务处理
4. 外键约束验证（尝试删除活动，应该被阻止）

---

## 已知问题和限制

### 1. 前端参与者显示（已修复）

✅ **已解决**：按任务分组显示参与者，避免混乱

### 2. 活动统计

- 当前参与人数需要从关联任务统计
- 建议：在活动表中添加 `current_participants` 字段，定期更新

### 3. 向后兼容

- 旧API `createExpertMultiParticipantTask` 仍然保留，内部调用新API
- 建议：添加 deprecation 警告

---

## 上线检查清单

- [x] 数据迁移脚本已创建
- [x] 外键约束已修复
- [x] 唯一约束已添加
- [x] 活动结束逻辑已实现
- [x] 前端参与者显示已修复
- [x] 删除活动功能已实现
- [x] 所有代码已通过 lint 检查
- [ ] **在测试环境完整测试所有迁移脚本**（必须！）
- [ ] **备份生产数据库**（必须！）
- [ ] **准备回滚方案**

---

## 总结

本次重构成功实现了活动与任务的清晰分离，建立了完整的数据模型和业务逻辑。所有审查发现的问题都已修复，系统已准备好进行测试和部署。

**关键成就**：
1. ✅ 完整的数据迁移方案
2. ✅ 严格的数据一致性约束
3. ✅ 灵活的时间段管理
4. ✅ 自动化的活动结束处理
5. ✅ 清晰的前端展示逻辑
6. ✅ 完善的权限和验证机制

**系统状态**：✅ **已准备好进行测试和部署**

---

## 更新记录

- **2025-11-23**: 初始重构完成
- **2025-11-23**: 修复所有审查发现的问题
- **2025-11-23**: 添加删除活动功能
- **2025-11-23**: 修复前端参与者显示逻辑
- **2025-11-23**: 修复任务方向问题
- **2025-11-23**: 更新开发日志
