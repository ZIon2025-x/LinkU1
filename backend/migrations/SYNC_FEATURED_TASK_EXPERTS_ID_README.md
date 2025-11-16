# FeaturedTaskExperts ID 同步功能说明

## 概述

此迁移脚本确保 `featured_task_experts` 表的 `id` 字段始终与 `user_id` 字段保持同步，并添加必要的索引以优化查询性能。

## 功能特性

### 1. 数据库层面

- **触发器**：自动确保 `id` 和 `user_id` 始终保持一致
  - 在 INSERT 时，如果 `id` 和 `user_id` 不一致，自动将 `id` 设置为 `user_id`
  - 在 UPDATE 时，如果 `user_id` 被修改，自动同步更新 `id`
  - 如果 `id` 和 `user_id` 不一致，自动将 `id` 设置为 `user_id`

- **索引**：为 `user_id` 字段添加索引，优化查询性能
  - 索引名：`ix_featured_task_experts_user_id`

- **数据修复**：修复现有数据中 `id` 和 `user_id` 不一致的记录

### 2. 代码层面

- **创建操作**（`create_task_expert`）：
  - 确保 `id` 和 `user_id` 在创建时保持一致
  - 如果只提供了 `user_id`，自动设置 `id = user_id`

- **更新操作**（`update_task_expert`）：
  - 检测 `user_id` 的更改，自动同步更新 `id`
  - 如果 `id` 和 `user_id` 不一致，自动将 `id` 同步为 `user_id`
  - 如果只提供了其中一个字段，自动同步另一个字段

### 3. 模型定义

- 在 `FeaturedTaskExpert` 模型中添加了 `user_id` 字段的显式索引
- 更新了注释，说明索引的用途

## 执行顺序

此迁移脚本应该在 `update_featured_task_experts_id_to_user_id.sql` 之后执行，确保表结构正确后再添加触发器和索引。

## 使用方法

### 自动执行

迁移脚本已添加到 `db_migrations.py` 的迁移列表中，会在数据库迁移时自动执行。

### 手动执行

如果需要手动执行：

```bash
psql -U your_username -d your_database -f backend/migrations/sync_featured_task_experts_id_user_id.sql
```

## 验证

执行迁移后，可以通过以下方式验证：

1. **检查触发器是否存在**：
```sql
SELECT * FROM pg_trigger WHERE tgname = 'trigger_sync_featured_task_experts_id_user_id';
```

2. **检查索引是否存在**：
```sql
SELECT * FROM pg_indexes WHERE tablename = 'featured_task_experts' AND indexname = 'ix_featured_task_experts_user_id';
```

3. **测试触发器**：
```sql
-- 测试 INSERT
INSERT INTO featured_task_experts (id, user_id, name, created_by) 
VALUES ('test123', 'test456', 'Test Expert', 'admin1');
-- 触发器应该自动将 id 设置为 'test456'

-- 测试 UPDATE
UPDATE featured_task_experts SET user_id = 'new_user' WHERE id = 'test456';
-- 触发器应该自动将 id 设置为 'new_user'
```

## 注意事项

1. **主键限制**：由于 `id` 是主键，通常不应该直接修改。如果确实需要更改用户关联，应该先删除旧记录，再创建新记录。

2. **外键约束**：`id` 和 `user_id` 都是外键，关联到 `users.id`，确保用户存在。

3. **唯一约束**：`user_id` 有唯一约束，确保每个用户只能有一个特色任务达人记录。

4. **级联删除**：`id` 字段设置了 `ondelete="CASCADE"`，当用户被删除时，相关的特色任务达人记录也会被自动删除。

## 相关文件

- `backend/migrations/sync_featured_task_experts_id_user_id.sql` - 迁移脚本
- `backend/app/models.py` - 模型定义（FeaturedTaskExpert）
- `backend/app/routers.py` - API 路由（create_task_expert, update_task_expert）
- `backend/app/admin_task_expert_routes.py` - 管理员路由（create_featured_expert_from_application）

