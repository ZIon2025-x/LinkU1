# Railway 自动修复数据库迁移指南

## 🎯 问题

Test 环境出现 "relation does not exist" 错误，因为迁移记录和实际数据库状态不同步。

## ✨ 自动修复方案（推荐）

我已经在应用中内置了自动修复功能，只需要设置一个环境变量即可。

### 步骤 1: 添加环境变量

1. 打开 [Railway Dashboard](https://railway.app/)
2. 选择你的 **Test 环境**
3. 点击后端服务（Backend Service）
4. 切换到 **Variables** 标签页
5. 点击 **New Variable**

添加以下环境变量：

```
FIX_MIGRATIONS=true
```

或者如果要强制重置（推荐用于首次修复）：

```
RESET_MIGRATIONS=true
```

**区别说明**：
- `FIX_MIGRATIONS=true`: 智能检测，只在检测到问题时才修复
- `RESET_MIGRATIONS=true`: 强制清空迁移记录，重新执行所有迁移（推荐）

### 步骤 2: 重新部署

设置完环境变量后，Railway 会自动触发重新部署。

或者手动触发：
- 点击右上角的 **Deploy** 按钮
- 或者推送一个新的 commit

### 步骤 3: 查看日志

部署后，查看日志应该看到：

```
🔧 自动修复已启用
🔍 开始检查迁移状态
📌 当前环境: test
📊 数据库状态:
  • 表总数: 9
  • 迁移记录数: 82
  • 关键表完整: ❌
  • 缺少表: users, tasks, universities
⚠️  RESET_MIGRATIONS=true, 将强制清空迁移记录
🔄 开始修复...
✅ 已清空 schema_migrations 表 (82 条记录)
✅ 修复完成！应用将重新创建表并执行所有迁移
```

然后会看到：

```
正在创建数据库表...
✅ 数据库表创建完成！
开始执行数据库迁移...
🔄 执行迁移: 001_add_flea_market_notice_agreed_at.sql
✅ 迁移执行成功: 001_add_flea_market_notice_agreed_at.sql
🔄 执行迁移: 002_add_flea_market_items.sql
✅ 迁移执行成功: 002_add_flea_market_items.sql
...
迁移完成: 82 个已执行, 0 个已跳过, 0 个失败
```

### 步骤 4: 删除环境变量（重要！）

修复完成后，**务必删除这个环境变量**，否则每次部署都会重置迁移！

1. 回到 **Variables** 标签页
2. 找到 `FIX_MIGRATIONS` 或 `RESET_MIGRATIONS`
3. 点击删除按钮
4. 不需要重新部署，删除即可

## 🎥 操作截图示例

### 1. 添加环境变量

```
Railway Dashboard
  └─ Select Project: LinkU1
      └─ Select Environment: test
          └─ Select Service: backend
              └─ Click "Variables" tab
                  └─ Click "New Variable"
                      ├─ Variable Name: RESET_MIGRATIONS
                      └─ Variable Value: true
```

### 2. 等待部署完成

Railway 会自动触发部署，等待几分钟。

### 3. 检查日志

```
Railway Dashboard
  └─ Select Service: backend
      └─ Click "Logs" tab
          └─ 查看自动修复的日志输出
```

## 📋 工作原理

1. **应用启动时**，在创建数据库表之前，会先运行自动检测
2. **检测逻辑**：
   - 检查 `schema_migrations` 表中的迁移记录数
   - 检查关键表（users, tasks, universities 等）是否存在
   - 如果有迁移记录但缺少关键表，说明状态不一致
3. **修复逻辑**：
   - 如果设置了 `RESET_MIGRATIONS=true` 或检测到不一致
   - 清空 `schema_migrations` 表
   - 应用会重新创建所有表并执行所有迁移
4. **安全保护**：
   - 生产环境不允许自动重置
   - 修复操作只会清空迁移记录，不会删除数据

## ⚠️ 注意事项

### ✅ 可以在 Test 环境使用
- Test 环境专门用于测试，可以安全重置
- 重置后会重新创建所有表结构

### ❌ 不能在 Production 环境使用
- 生产环境有保护机制，不会自动重置
- 生产环境如有问题需要手动处理

### 🔄 一次性操作
- 修复完成后必须删除环境变量
- 否则每次部署都会重置迁移记录

## 🐛 如果还是不行怎么办？

### 方案 A: 手动连接数据库

使用 Railway CLI：

```bash
# 安装 Railway CLI
npm i -g @railway/cli

# 登录并连接项目
railway login
railway link

# 选择 test 环境
railway environment

# 连接到数据库
railway run psql $DATABASE_URL

# 在 psql 中执行
TRUNCATE TABLE schema_migrations;

# 退出
\q

# 重新部署
railway up
```

### 方案 B: 完全重建数据库

在 Railway Dashboard 中：

1. 删除现有的 PostgreSQL 服务
2. 创建新的 PostgreSQL 服务
3. 重新连接后端服务
4. 重新部署

## 📞 需要帮助？

如果遇到问题：
1. 检查日志中的错误信息
2. 确认环境变量设置正确
3. 确认是在 Test 环境而不是 Production
4. 查看 `backend/scripts/check_db_state.py` 诊断详细状态

## ✅ 验证修复成功

修复成功的标志：
- ✅ 日志中看到 82 个迁移都执行成功
- ✅ 没有 "relation does not exist" 错误
- ✅ 应用正常启动并响应请求
- ✅ 健康检查返回 200 OK

## 📝 环境变量完整列表

其他相关环境变量（了解即可）：

```bash
# 自动迁移（默认启用）
AUTO_MIGRATE=true

# 智能修复（需要时启用）
FIX_MIGRATIONS=true

# 强制重置（首次修复推荐）
RESET_MIGRATIONS=true
```

---

**最后提醒**：修复完成后记得删除 `RESET_MIGRATIONS` 或 `FIX_MIGRATIONS` 环境变量！
