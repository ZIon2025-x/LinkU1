# Stripe 数据库迁移自动部署指南

## 当前状态

✅ **自动迁移已配置完成**

项目已有完整的自动迁移机制，**无需手动操作**：

1. ✅ 迁移文件已创建：`backend/migrations/038_add_stripe_connect_account_id.sql`
2. ✅ 自动迁移机制已启用：在 `startup_event` 中自动执行
3. ✅ 默认启用：`AUTO_MIGRATE` 默认为 `true`
4. ✅ 幂等性保证：已执行的迁移不会重复执行

---

## 自动迁移机制

### 工作原理

1. **启动时检查**：应用启动时检查 `AUTO_MIGRATE` 环境变量
2. **自动执行**：如果 `AUTO_MIGRATE=true`，自动运行所有未执行的迁移
3. **幂等性**：已执行的迁移不会重复执行（通过 `schema_migrations` 表记录）

### 代码位置

```python
# backend/app/main.py (startup_event)
auto_migrate = os.getenv("AUTO_MIGRATE", "true").lower() == "true"
if auto_migrate:
    from app.db_migrations import run_migrations
    run_migrations(sync_engine, force=False)
```

---

## Railway 部署配置

### 1. 确保环境变量已设置

在 Railway Dashboard 中，确保后端项目有：

```env
AUTO_MIGRATE=true  # 启用自动迁移（默认已启用）
DATABASE_URL=postgresql://...  # 数据库连接字符串
```

**注意**：
- `AUTO_MIGRATE` 默认为 `true`，如果没有设置，会自动启用
- 如果设置为 `false`，迁移不会自动执行

### 2. 迁移文件位置

迁移文件位于：`backend/migrations/038_add_stripe_connect_account_id.sql`

### 3. 部署流程

**Railway 自动部署流程**：

1. **代码推送** → Railway 检测到变更
2. **构建阶段** → 安装依赖，构建应用
3. **启动阶段** → 执行 `startup_event`
4. **自动迁移** → 检查并执行未执行的迁移
5. **应用运行** → 迁移完成后，应用正常启动

---

## 验证迁移是否执行

### 方法一：查看 Railway 日志

1. 进入 Railway Dashboard → 你的后端项目
2. 点击 **Deployments** → 最新的部署
3. 查看日志，应该看到：
   ```
   开始执行数据库迁移...
   🔄 执行迁移: 038_add_stripe_connect_account_id.sql
   ✅ 迁移执行成功: 038_add_stripe_connect_account_id.sql (耗时: XXms)
   数据库迁移执行完成！
   ```

### 方法二：检查数据库

在 Railway PostgreSQL 控制台中执行：

```sql
-- 检查迁移是否已执行
SELECT migration_name, executed_at 
FROM schema_migrations 
WHERE migration_name = '038_add_stripe_connect_account_id.sql';

-- 检查字段是否已添加
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name = 'stripe_account_id';
```

### 方法三：使用迁移工具

如果需要在本地验证：

```bash
cd backend
python run_migrations.py --status
```

---

## 迁移文件内容

**文件**：`backend/migrations/038_add_stripe_connect_account_id.sql`

```sql
-- 添加 Stripe Connect 账户 ID 字段到 users 表
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS stripe_account_id VARCHAR(255) UNIQUE;

-- 添加索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_users_stripe_account_id ON users(stripe_account_id);

-- 添加注释
COMMENT ON COLUMN users.stripe_account_id IS 'Stripe Connect Express Account ID，用于接收任务奖励支付';
```

**特点**：
- ✅ 使用 `IF NOT EXISTS`，可以安全地重复执行
- ✅ 不会影响现有数据
- ✅ 幂等性：多次执行结果相同

---

## 故障排查

### 问题 1：迁移未自动执行

**检查**：
1. 查看 Railway 日志，确认 `AUTO_MIGRATE` 是否为 `true`
2. 检查是否有错误信息
3. 确认 `DATABASE_URL` 是否正确

**解决**：
- 在 Railway Dashboard 中设置 `AUTO_MIGRATE=true`
- 检查数据库连接是否正常

### 问题 2：迁移执行失败

**检查**：
- 查看 Railway 日志中的错误信息
- 检查数据库权限
- 确认字段是否已存在

**解决**：
- 如果字段已存在，迁移会自动跳过（使用 `IF NOT EXISTS`）
- 如果权限问题，检查数据库用户权限

### 问题 3：需要手动执行迁移

如果自动迁移失败，可以手动执行：

**在 Railway 中**：
1. Railway Dashboard → PostgreSQL → Query
2. 执行迁移 SQL：
   ```sql
   ALTER TABLE users 
   ADD COLUMN IF NOT EXISTS stripe_account_id VARCHAR(255) UNIQUE;
   
   CREATE INDEX IF NOT EXISTS idx_users_stripe_account_id ON users(stripe_account_id);
   ```

**或使用迁移工具**：
```bash
# 在本地或通过 Railway CLI
python backend/run_migrations.py --migration 038_add_stripe_connect_account_id.sql
```

---

## 最佳实践

### 1. 生产环境

- ✅ **启用自动迁移**：`AUTO_MIGRATE=true`
- ✅ **监控日志**：每次部署后检查迁移日志
- ✅ **备份数据库**：重要迁移前备份

### 2. 开发环境

- ✅ 本地开发时，迁移会自动执行
- ✅ 可以使用 `run_migrations.py` 手动管理迁移

### 3. 迁移文件命名

- ✅ 使用序号前缀：`038_xxx.sql`
- ✅ 使用描述性名称：`add_stripe_connect_account_id.sql`
- ✅ 按顺序递增：038, 039, 040...

---

## 总结

✅ **自动迁移已配置**：
- 应用启动时自动执行
- 通过 `AUTO_MIGRATE` 环境变量控制
- 幂等性保证，可安全重复执行

✅ **部署时**：
- Railway 部署后，迁移会自动执行
- 无需手动操作
- 查看日志确认执行状态

✅ **迁移文件**：
- `038_add_stripe_connect_account_id.sql` 已创建
- 使用 `IF NOT EXISTS`，安全可靠

---

**最后更新**：2024年

