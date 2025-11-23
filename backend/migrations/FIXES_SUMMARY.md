# 活动与任务分离重构 - 修复总结

## 修复日期
2025-11-23

## 修复内容

### ✅ 1. 数据迁移脚本（最优先）- 已完成
**文件**: `017_migrate_existing_multi_participant_tasks_to_activities.sql`

**内容**:
- 将现有的 `is_multi_participant=true` 且 `expert_creator_id IS NOT NULL` 的任务迁移到 `activities` 表
- 迁移时间段关联从 `task_time_slot_relations` 到 `activity_time_slot_relations`
- 更新原任务的 `parent_activity_id` 指向新创建的活动
- 包含完整的验证和统计输出

### ✅ 2. 修复 parent_activity_id 外键约束 - 已完成
**文件**: `018_fix_parent_activity_id_foreign_key_and_add_constraints.sql`

**修复**:
- 将外键约束从 `ON DELETE SET NULL` 改为 `ON DELETE RESTRICT`
- 防止活动被删除后导致任务关联丢失

**代码修改**:
- `backend/app/models.py`: 第226行，`ondelete="RESTRICT"`

### ✅ 3. 修复任务方向问题 - 已完成
**问题**: 申请活动时创建的任务，`poster_id` 和 `taker_id` 方向反了

**修复方案**: 
- **任务方向逻辑**：
  - `poster_id`（发布者）= 付钱的人 = 申请活动的普通用户
  - `taker_id`（接收者）= 收钱的人 = 任务达人
- 新增字段 `originating_user_id` 记录实际申请人

**代码修改**:
- `backend/app/models.py`: 添加 `originating_user_id` 字段
- `backend/app/multi_participant_routes.py`: 修复 `apply_to_activity` 函数中的任务创建逻辑
- `backend/migrations/018_*.sql`: 添加 `originating_user_id` 字段和迁移逻辑

### ✅ 4. 添加固定时间段唯一约束 - 已完成
**文件**: `018_fix_parent_activity_id_foreign_key_and_add_constraints.sql`

**修复**:
- 添加部分唯一索引：`uq_activity_time_slot_fixed`
- 确保固定模式下，一个时间段只能被一个活动使用

### ✅ 5. 时间段冲突检测（创建活动时） - 已完成
**代码位置**: `backend/app/multi_participant_routes.py` 第787-799行

**已实现**:
- 创建活动时检查时间段是否已被其他活动使用
- 在固定模式和重复模式中都有冲突检测

### ✅ 6. 活动管理页面参与者显示逻辑 - 待前端修复
**问题**: 一个活动可能对应多个任务，当前前端把所有任务的参与者混在一起展示

**建议**: 
- 前端需要按"任务分组"展示参与者
- 或者明确"一人一任务"原则，每个申请者创建一个独立任务

**后端支持**: 
- 已添加 `TaskParticipant.activity_id` 冗余字段，便于前端查询

### ✅ 7. 添加 TaskParticipant.activity_id 冗余字段 - 已完成
**文件**: `018_fix_parent_activity_id_foreign_key_and_add_constraints.sql`

**修复**:
- 添加 `activity_id` 字段到 `task_participants` 表
- 添加外键约束和索引
- 更新现有记录的 `activity_id` 值

**代码修改**:
- `backend/app/models.py`: 添加 `activity_id` 字段到 `TaskParticipant` 模型
- `backend/app/multi_participant_routes.py`: 创建参与者时设置 `activity_id`

### ✅ 8. 活动结束后的任务状态自动处理 - 已完成
**代码位置**: `backend/app/task_expert_routes.py` 第1560-1606行

**实现**:
- 当活动自动结束时，查询所有关联的任务（状态为 `open` 或 `taken`）
- 将这些任务的状态更新为 `cancelled`
- 记录审计日志

### ✅ 9. activities 表的 created_at/updated_at 字段 - 已存在
**验证**: `backend/migrations/015_create_activities_table.sql` 第46-47行

**状态**: 字段已存在，无需修复

## 迁移脚本执行顺序

1. `015_create_activities_table.sql` - 创建活动表
2. `016_add_parent_activity_id_foreign_key.sql` - 添加外键（旧版本，将被018替换）
3. `017_migrate_existing_multi_participant_tasks_to_activities.sql` - 数据迁移
4. `018_fix_parent_activity_id_foreign_key_and_add_constraints.sql` - 修复约束和添加新字段

## 注意事项

1. **数据迁移前备份**: 执行迁移前必须备份数据库
2. **测试环境验证**: 先在测试环境完整测试所有迁移脚本
3. **前端更新**: 前端需要更新以支持新的任务方向（`poster_id`/`taker_id`）
4. **活动管理页面**: 需要修复参与者显示逻辑（按任务分组）

## 待处理问题

1. **活动管理页面参与者显示逻辑**（前端任务）
   - 需要按任务分组显示参与者
   - 或明确"一人一任务"原则

2. **向后兼容性**（低优先级）
   - 建议旧API返回 410 Gone + 指明新路径
   - 或暂时内部转发到新逻辑

## 测试建议

1. 测试数据迁移脚本在测试环境的执行
2. 测试活动创建和申请流程
3. 测试时间段冲突检测
4. 测试活动结束后的任务状态自动更新
5. 测试外键约束（尝试删除活动，应该被阻止）

