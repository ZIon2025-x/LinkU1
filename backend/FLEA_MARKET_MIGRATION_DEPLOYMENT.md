# 跳蚤市场数据库迁移部署指南

## 概述

跳蚤市场功能的数据库迁移已配置为自动执行。应用启动时会自动检测并执行所有未执行的迁移文件。

## 迁移文件

已创建以下3个迁移文件（按执行顺序）：

1. **001_add_flea_market_notice_agreed_at.sql**
   - 为用户表添加 `flea_market_notice_agreed_at` 字段
   - 添加索引

2. **002_add_flea_market_items.sql**
   - 创建 `flea_market_items` 表（商品表）
   - 创建所有必要的索引和触发器

3. **003_add_flea_market_purchase_requests.sql**
   - 创建 `flea_market_purchase_requests` 表（购买申请表）
   - 创建所有必要的索引和触发器

## 自动迁移机制

### 工作原理

1. **应用启动时自动执行**：
   - 在 `main.py` 的 `startup_event` 中调用 `run_migrations()`
   - 自动检测 `backend/migrations/` 目录下的所有 `.sql` 文件
   - 按文件名排序执行（确保顺序正确）

2. **幂等性保证**：
   - 所有迁移文件使用 `DO $$ ... END $$;` 块
   - 使用 `IF NOT EXISTS` 检查，避免重复创建
   - 已执行的迁移会记录在 `schema_migrations` 表中，不会重复执行

3. **错误处理**：
   - 迁移失败不会阻止应用启动
   - 错误会记录到日志中
   - 可以手动修复后重新启动应用

### 环境变量配置

通过 `AUTO_MIGRATE` 环境变量控制是否启用自动迁移：

```bash
# 启用自动迁移（默认）
export AUTO_MIGRATE=true

# 禁用自动迁移
export AUTO_MIGRATE=false
```

**默认值**：`true`（启用）

## 部署步骤

### 1. 确保迁移文件存在

确认以下文件存在于 `backend/migrations/` 目录：

```
backend/migrations/
├── 001_add_flea_market_notice_agreed_at.sql
├── 002_add_flea_market_items.sql
└── 003_add_flea_market_purchase_requests.sql
```

### 2. 设置环境变量（可选）

如果需要禁用自动迁移，设置：

```bash
export AUTO_MIGRATE=false
```

### 3. 启动应用

正常启动应用即可，迁移会自动执行：

```bash
# 开发环境
python -m uvicorn app.main:app --reload

# 生产环境
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### 4. 查看迁移日志

启动日志中会显示迁移执行情况：

```
INFO: 开始执行数据库迁移...
INFO: 找到 3 个迁移脚本
INFO: 🔄 执行迁移: 001_add_flea_market_notice_agreed_at.sql
INFO: ✅ 迁移执行成功: 001_add_flea_market_notice_agreed_at.sql (耗时: 45ms)
INFO: 🔄 执行迁移: 002_add_flea_market_items.sql
INFO: ✅ 迁移执行成功: 002_add_flea_market_items.sql (耗时: 120ms)
INFO: 🔄 执行迁移: 003_add_flea_market_purchase_requests.sql
INFO: ✅ 迁移执行成功: 003_add_flea_market_purchase_requests.sql (耗时: 80ms)
INFO: 迁移完成: 3 个已执行, 0 个已跳过, 0 个失败
INFO: 数据库迁移执行完成！
```

## 验证迁移结果

### 检查数据库表

连接数据库后，执行以下SQL检查表是否创建成功：

```sql
-- 检查用户表字段
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name = 'flea_market_notice_agreed_at';

-- 检查商品表
SELECT table_name 
FROM information_schema.tables 
WHERE table_name = 'flea_market_items';

-- 检查购买申请表
SELECT table_name 
FROM information_schema.tables 
WHERE table_name = 'flea_market_purchase_requests';
```

### 检查迁移记录

查看已执行的迁移记录：

```sql
SELECT * FROM schema_migrations 
WHERE migration_name LIKE '%flea_market%' 
ORDER BY executed_at;
```

## 手动执行迁移（可选）

如果需要手动执行迁移，可以使用以下方法：

### 方法1：使用Python脚本

```python
from app.database import sync_engine
from app.db_migrations import run_migrations

run_migrations(sync_engine, force=False)
```

### 方法2：直接执行SQL

```bash
# 使用psql执行
psql $DATABASE_URL -f backend/migrations/001_add_flea_market_notice_agreed_at.sql
psql $DATABASE_URL -f backend/migrations/002_add_flea_market_items.sql
psql $DATABASE_URL -f backend/migrations/003_add_flea_market_purchase_requests.sql
```

## 故障排查

### 迁移未执行

1. **检查环境变量**：
   ```bash
   echo $AUTO_MIGRATE
   ```
   确保值为 `true` 或未设置（默认为 `true`）

2. **检查迁移目录**：
   ```bash
   ls -la backend/migrations/*.sql
   ```
   确保迁移文件存在

3. **查看启动日志**：
   检查是否有迁移相关的日志输出

### 迁移执行失败

1. **查看错误日志**：
   启动日志中会显示详细的错误信息

2. **检查数据库连接**：
   确保 `DATABASE_URL` 环境变量正确设置

3. **检查数据库权限**：
   确保数据库用户有创建表、索引等权限

4. **手动修复**：
   根据错误信息手动修复数据库，然后重新启动应用

### 迁移重复执行

迁移系统会自动跳过已执行的迁移。如果遇到问题：

1. **检查迁移记录表**：
   ```sql
   SELECT * FROM schema_migrations;
   ```

2. **清理迁移记录**（谨慎操作）：
   ```sql
   DELETE FROM schema_migrations 
   WHERE migration_name = '001_add_flea_market_notice_agreed_at.sql';
   ```

## 注意事项

1. **生产环境**：
   - 建议在维护窗口期间部署
   - 部署前备份数据库
   - 监控迁移执行日志

2. **开发环境**：
   - 可以安全地多次执行迁移
   - 迁移文件已做幂等性处理

3. **迁移顺序**：
   - 迁移文件按文件名排序执行
   - 确保文件名使用数字前缀（如 `001_`, `002_`）

4. **回滚**：
   - 当前迁移文件不支持自动回滚
   - 如需回滚，需要手动编写回滚SQL

## 相关文件

- `backend/app/main.py` - 启动事件和自动迁移调用
- `backend/app/db_migrations.py` - 迁移执行模块
- `backend/migrations/` - 迁移文件目录
- `backend/AUTO_MIGRATION_GUIDE.md` - 自动迁移详细指南

## 支持

如有问题，请查看：
- 应用启动日志
- 数据库错误日志
- `backend/AUTO_MIGRATION_GUIDE.md` 文档

