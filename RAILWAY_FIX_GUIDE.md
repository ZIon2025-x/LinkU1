# Railway 数据库修复指南

## ⚠️ 最新更新（2026-02-05 14:30）

**已修复关键Bug：**
- ✅ **PostgreSQL事务中止问题** - 每个SQL语句独立提交，避免级联失败
- ✅ **数据库对象清理** - 删除表时同时清理函数、序列、触发器
- ✅ **孤立索引清理问题** - 使用 pg_class 直接查询索引对象，使用 AUTOCOMMIT 确保立即生效
- ✅ **改进错误处理** - 更好的回滚机制和日志输出

**关键修复：**
之前的版本在清理数据库时可能遗留孤立索引（如 `ix_notifications_type`），导致表创建失败。

**根本原因（已修复）：**
- `models.py` 中存在**重复的索引定义**：
  - `Notification.__table_args__` 定义 `ix_notifications_type` 为复合索引 `(type, related_id)`
  - 文件末尾重复定义同名索引为单列索引 `(type)`
- 即使删除孤立索引，`create_all` 仍会尝试创建两个同名索引导致冲突

**现在包含四层防护：**
1. **修复重复索引定义**：注释掉 models.py 中的重复索引（最重要！）
2. 使用 `pg_class` 系统表查询并删除所有索引对象
3. **使用 raw psycopg2 + autocommit**：绕过 SQLAlchemy 事务层，确保 DROP 立即生效
4. **引擎连接池重置**：删除对象后调用 `engine.dispose()` 确保新连接可见
5. **智能重试机制**：如果创建失败并报"已存在"错误，自动删除孤立对象并重试（最多3次）

**重要：** 如果之前部署失败，请重新部署以获取这些修复。

---

## 问题描述

数据库迁移状态不一致：
- ❌ 有 82 条迁移记录，但缺少 7 个关键表（users, tasks, universities, notifications, messages, conversations, reviews）
- ❌ SQL 迁移脚本解析错误（dollar-quoted functions）
- ❌ 迁移执行时出现 "current transaction is aborted" 错误

## 解决方案

### 方案 1: 智能修复（推荐）

适用于：有数据且想保留的情况

**步骤：**

1. 在 Railway 项目中添加环境变量：
   ```
   FIX_MIGRATIONS=true
   ```

2. 点击 "Deploy" 重新部署

3. 观察日志，确认修复成功：
   ```
   ✅ 修复完成！应用将重新创建缺失的表并执行所有迁移
   ```

4. 修复完成后，**删除** `FIX_MIGRATIONS` 环境变量（避免每次启动都执行）

---

### 方案 2: 完全重置（推荐用于开发/测试环境）

适用于：可以清空所有数据，重新开始

**步骤：**

1. 在 Railway 项目中添加环境变量：
   ```
   RESET_MIGRATIONS=true
   DROP_ALL_TABLES=true
   ```

2. 点击 "Deploy" 重新部署

3. 观察日志，确认：
   ```
   ⚠️  DROP_ALL_TABLES=true，将删除所有数据库表！
   🗑️  开始删除所有数据库表...
   ✅ 已删除 XX 个表
   ✅ 修复完成！已删除所有表，应用将重新创建表并执行所有迁移
   ```

4. 等待应用完全启动（会创建所有表并执行迁移）

5. 确认成功后，**删除**这两个环境变量：
   - `RESET_MIGRATIONS`
   - `DROP_ALL_TABLES`

---

## 环境变量说明

| 环境变量 | 作用 | 危险程度 |
|---------|------|---------|
| `FIX_MIGRATIONS=true` | 智能检测并修复不一致 | ⚠️ 低 - 不删除数据 |
| `RESET_MIGRATIONS=true` | 清空迁移记录，重新执行 | ⚠️ 中 - 不删除表，但会重新运行迁移 |
| `DROP_ALL_TABLES=true` | 删除所有表（需要配合上面之一使用） | 🔴 高 - **会清除所有数据！** |

## 验证修复成功

部署完成后，检查日志中的以下信息：

1. **表创建成功：**
   ```
   INFO:app.main:已创建的表: ['users', 'tasks', 'universities', 'messages', ...]
   ```

2. **迁移执行成功：**
   ```
   INFO:app.db_migrations:迁移完成: 82 个已执行, 0 个已跳过, 0 个失败
   ```

3. **没有关键错误：**
   ```
   ERROR:app.cleanup_tasks:... relation "tasks" does not exist  ❌ 不应该出现
   ERROR:app.crud:... relation "users" does not exist  ❌ 不应该出现
   ```

## 常见问题

### Q: 遇到 "relation 'ix_notifications_type' already exists" 错误怎么办？

**A:** 这是孤立索引问题，说明之前的表删除操作遗留了索引对象。解决方法：

1. **确认已部署最新代码**（2026-02-05 14:30 之后的版本）
2. 使用**方案2（完全重置）**：
   ```
   DROP_ALL_TABLES=true
   RESET_MIGRATIONS=true
   ```
3. 重新部署
4. 最新代码会使用 AUTOCOMMIT 模式彻底清理所有索引对象
5. 部署成功后删除这两个环境变量

**如果仍然失败：**
- 检查 Railway 日志中的 "已删除索引" 信息
- 确认看到 `✓ 已删除索引: ix_notifications_type` 的日志
- 如果没有看到，可能是权限问题，联系 Railway 支持

### Q: 我应该使用方案1还是方案2？

**A:**
- 如果是**生产环境**或有重要数据：使用**方案1**（智能修复）
- 如果是**开发/测试环境**或可以清空数据：使用**方案2**（完全重置）

### Q: 为什么需要删除环境变量？

**A:** 这些环境变量会在每次应用启动时触发修复逻辑。修复完成后继续保留会导致：
- 不必要的性能开销
- 可能干扰正常的数据库操作

### Q: 如果修复失败怎么办？

**A:**
1. 检查 Railway 日志中的错误信息
2. 确认数据库连接正常
3. 如果方案1失败，尝试方案2
4. 如果仍然失败，查看日志中的详细错误堆栈

## 生产环境保护

代码已内置生产环境保护：
```python
if env.lower() == "production":
    logger.error("❌ 生产环境不允许自动重置迁移！")
    return False
```

如果您的 `RAILWAY_ENVIRONMENT=production`，自动修复将被禁用，需要手动处理。

## 技术细节

### 修复了什么？

1. **`auto_fix_migrations.py`**:
   - 新增 `drop_tables` 参数，支持完全重置
   - 改进日志输出，更清晰的状态提示
   - 新增 `DROP_ALL_TABLES` 环境变量支持

2. **`db_migrations.py`**:
   - 新增 `split_sql_statements()` 函数
   - 正确处理 PostgreSQL dollar-quoted 字符串 (`$$`)
   - 改进多语句执行逻辑，每个语句独立执行
   - 更好的错误处理，区分真实错误和"已存在"错误

### 为什么会出现这个问题？

1. 之前的 `RESET_MIGRATIONS` 只清空迁移记录，不删除表
2. `Base.metadata.create_all(checkfirst=True)` 发现表已存在，跳过创建
3. 但某些表可能损坏或缺失，导致状态不一致
4. SQL 解析器无法正确处理 `$$` 包裹的函数定义，导致语句被错误分割

---

**推荐操作：** 使用方案2（完全重置），快速解决问题，然后删除环境变量。
