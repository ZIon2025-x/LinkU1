# Test 环境数据库修复指南

## 问题描述

Test 环境出现迁移状态不一致的问题:
- ✅ `schema_migrations` 表显示所有 82 个迁移都已执行
- ❌ 但关键数据表（users, tasks, universities 等）不存在
- 💥 导致应用启动后出现大量 "relation does not exist" 错误

## 原因分析

这是由于之前删除了一些迁移文件，但数据库的迁移记录表（schema_migrations）仍然保留了这些记录，导致:
1. 迁移系统认为所有迁移都已执行，跳过了所有迁移
2. 但实际上基础表从未被创建
3. 数据库状态和迁移记录不同步

## 修复方案

### 方案一：使用 Railway CLI（推荐）

#### 步骤 1: 诊断问题

```bash
# 连接到 test 环境
railway link

# 选择 test 环境
railway environment

# 运行诊断脚本
railway run python backend/scripts/check_db_state.py
```

#### 步骤 2: 重置数据库

```bash
# 运行重置脚本（会提示确认）
railway run python backend/scripts/reset_test_db.py

# 输入 'YES' 确认重置
```

#### 步骤 3: 重新部署

```bash
# 触发重新部署
railway up

# 或者在 Railway Dashboard 中手动重新部署
```

### 方案二：在 Railway Dashboard 中操作

#### 步骤 1: 进入数据库

1. 打开 Railway Dashboard
2. 选择 Test 环境
3. 点击 PostgreSQL 数据库服务
4. 点击 "Data" 标签页

#### 步骤 2: 执行 SQL

在 Query 面板中执行以下 SQL：

```sql
-- 1. 查看当前状态
SELECT COUNT(*) FROM schema_migrations;

-- 2. 列出所有表
SELECT tablename FROM pg_tables WHERE schemaname = 'public';

-- 3. 清空迁移记录表
TRUNCATE TABLE schema_migrations;

-- 4. （可选）如果需要完全重置，删除所有表
-- ⚠️ 警告：这会删除所有数据！
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        EXECUTE 'DROP TABLE IF EXISTS ' || quote_ident(r.tablename) || ' CASCADE';
    END LOOP;
END $$;
```

#### 步骤 3: 重新部署

在 Railway Dashboard 中点击 "Deploy" 按钮重新部署应用。

### 方案三：直接 SQL 修复（最简单）

如果只是想快速修复而不删除现有数据：

```sql
-- 只清空迁移记录，让应用重新执行迁移
TRUNCATE TABLE schema_migrations;
```

然后重新部署应用。应用会：
1. 运行 `Base.metadata.create_all()` 创建缺失的表
2. 重新执行所有迁移（会跳过已存在的表/字段）

## 验证修复

重新部署后，检查日志应该看到：

```
✅ 迁移执行成功: 001_add_flea_market_notice_agreed_at.sql
✅ 迁移执行成功: 002_add_flea_market_items.sql
...
✅ 迁移执行成功: 082_stripe_account_id_allow_multiple_nulls.sql
迁移完成: 82 个已执行, 0 个已跳过, 0 个失败
```

不应该再看到 "relation does not exist" 错误。

## Railway CLI 常用命令

```bash
# 安装 Railway CLI
npm i -g @railway/cli

# 登录
railway login

# 连接项目
railway link

# 切换环境
railway environment

# 查看日志
railway logs

# 运行命令
railway run <command>

# 连接到数据库
railway run psql $DATABASE_URL
```

## 预防措施

为了避免将来再次出现此问题：

1. **不要手动删除迁移文件**
   - 如果需要回滚迁移，创建新的迁移文件来撤销更改
   - 保持迁移文件和数据库记录同步

2. **使用迁移版本控制**
   - 所有迁移文件都应该提交到 Git
   - 确保所有环境使用相同的迁移文件

3. **定期备份数据库**
   - Railway 提供自动备份功能
   - 在执行危险操作前手动创建快照

4. **分离环境**
   - Test 环境用于测试，可以随时重置
   - Production 环境谨慎操作，必要时咨询团队

## 需要帮助？

如果遇到问题：
1. 先运行诊断脚本查看详细状态
2. 检查 Railway 日志中的错误信息
3. 确认环境变量设置正确（DATABASE_URL 等）
