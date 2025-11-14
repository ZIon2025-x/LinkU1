# 自动数据库迁移指南

## 概述

应用现在支持在启动时自动执行数据库迁移，无需手动运行迁移脚本。

## 功能特性

- ✅ **自动执行迁移**：应用启动时自动执行所有数据库迁移
- ✅ **幂等性**：迁移脚本可以安全地多次执行，不会重复创建已存在的对象
- ✅ **错误处理**：迁移失败不会阻止应用启动，但会记录错误日志
- ✅ **环境控制**：可以通过环境变量控制是否启用自动迁移

## 迁移脚本

当前包含以下迁移脚本：

1. **优惠券和积分系统迁移** (`migrations/create_coupon_points_tables.sql`)
   - 创建优惠券表
   - 创建积分账户表
   - 创建邀请码表
   - 创建相关索引和约束

2. **任务表索引迁移** (`migrations/add_task_indexes.sql`)
   - 创建任务表的性能优化索引

## 配置

### 环境变量

通过 `AUTO_MIGRATE` 环境变量控制是否启用自动迁移：

- `AUTO_MIGRATE=true`（默认）：启用自动迁移
- `AUTO_MIGRATE=false`：禁用自动迁移

### 示例配置

```bash
# 启用自动迁移（默认）
export AUTO_MIGRATE=true

# 禁用自动迁移
export AUTO_MIGRATE=false
```

## 部署流程

### 开发环境

默认启用自动迁移，应用启动时会自动执行：

```bash
# 启动应用
python -m uvicorn app.main:app --reload
```

### 生产环境

**推荐方式**：启用自动迁移（默认，已启用）

生产环境默认启用自动迁移，应用启动时会自动执行所有迁移脚本。迁移脚本已经过幂等性处理，可以安全地多次执行。

```bash
# Railway / 其他平台
# 默认启用自动迁移（AUTO_MIGRATE=true 或留空）
# 无需额外配置，应用启动时自动执行迁移
```

**可选方式**：禁用自动迁移，手动执行

如果出于特殊原因需要禁用自动迁移：

```bash
# 设置环境变量
export AUTO_MIGRATE=false

# 手动执行迁移
python migrate_railway.py
# 或
alembic upgrade head
```

**注意**：生产环境建议使用自动迁移，因为：
- ✅ 迁移脚本具有幂等性，可以安全地多次执行
- ✅ 自动迁移确保数据库结构始终与代码同步
- ✅ 减少手动操作，降低人为错误风险
- ✅ 迁移失败不会阻止应用启动，只会记录错误日志

## 迁移执行顺序

1. 创建数据库表（SQLAlchemy models）
2. 执行优惠券和积分系统迁移
3. 执行任务表索引迁移

## 日志输出

迁移执行时会输出详细的日志：

```
🚀 开始执行自动数据库迁移...
🚀 开始执行优惠券和积分系统数据库迁移...
✅ 优惠券和积分系统迁移完成！
   执行: 45, 跳过: 12, 错误: 0
✅ 任务表索引迁移完成
✅ 自动数据库迁移完成！
```

## 错误处理

- 如果迁移失败，错误会被记录到日志，但**不会阻止应用启动**
- 已存在的对象（表、索引、约束等）会被自动跳过
- 非关键错误不会中断迁移过程

## 注意事项

1. **生产环境建议**：
   - ✅ **生产环境默认启用自动迁移**，无需额外配置
   - 首次部署前建议先备份数据库
   - 可以在测试环境先验证迁移脚本
   - 迁移脚本已经过幂等性处理，可以安全地多次执行
   - 迁移失败不会阻止应用启动，只会记录错误日志

2. **迁移脚本编写**：
   - 使用 `IF NOT EXISTS` 或 `DO $$ ... END $$` 确保幂等性
   - 避免使用会破坏数据的 DROP 语句
   - 测试迁移脚本的可重复执行性

3. **性能考虑**：
   - 迁移在应用启动时执行，可能会稍微延长启动时间
   - 大型迁移建议在维护窗口期间执行

## 手动迁移

如果需要手动执行迁移（例如在禁用自动迁移时）：

```bash
# 方式1：使用迁移脚本
python migrate_railway.py

# 方式2：直接执行 SQL
psql $DATABASE_URL -f backend/migrations/create_coupon_points_tables.sql
psql $DATABASE_URL -f backend/migrations/add_task_indexes.sql

# 方式3：使用 Alembic（如果配置了）
alembic upgrade head
```

## 故障排查

### 迁移失败

1. 查看应用日志，找到具体的错误信息
2. 检查数据库连接是否正常
3. 确认迁移脚本文件是否存在
4. 验证数据库用户是否有足够的权限

### 迁移未执行

1. 检查 `AUTO_MIGRATE` 环境变量设置
2. 查看启动日志，确认是否输出了迁移相关信息
3. 检查 `app/db_migrations.py` 模块是否正确导入

## 相关文件

- `backend/app/main.py` - 启动事件和自动迁移调用
- `backend/app/db_migrations.py` - 迁移执行模块
- `backend/migrations/create_coupon_points_tables.sql` - 优惠券系统迁移脚本
- `backend/migrations/add_task_indexes.sql` - 任务索引迁移脚本
- `migrate_railway.py` - Railway 手动迁移脚本

