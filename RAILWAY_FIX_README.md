# 🔧 Railway Test 环境数据库修复指南

> **快速修复**：只需设置一个环境变量，应用会自动修复！

## 🚀 最简单的修复方法（推荐）

### 1️⃣ 在 Railway 添加环境变量

1. 打开 Railway Dashboard → 选择 **Test 环境** → 点击 **Backend 服务**
2. 切换到 **Variables** 标签
3. 添加新变量：
   ```
   名称: RESET_MIGRATIONS
   值:   true
   ```
4. 保存后 Railway 会自动重新部署

### 2️⃣ 等待部署完成（约 2-3 分钟）

查看日志，应该看到：
```
✅ 已清空 schema_migrations 表 (82 条记录)
✅ 修复完成！应用将重新创建表并执行所有迁移
迁移完成: 82 个已执行, 0 个已跳过, 0 个失败
```

### 3️⃣ 删除环境变量（重要！）

修复完成后，回到 Variables 标签，**删除** `RESET_MIGRATIONS` 变量。

---

## ✅ 完成！

应用现在应该正常运行，不再有 "relation does not exist" 错误。

---

## 📚 详细文档

- **自动修复完整指南**: [docs/railway_auto_fix_guide.md](docs/railway_auto_fix_guide.md)
- **问题分析和其他方案**: [docs/fix_test_db.md](docs/fix_test_db.md)

## 🛠️ 工具脚本

- **诊断脚本**: [backend/scripts/check_db_state.py](backend/scripts/check_db_state.py)
- **手动重置脚本**: [backend/scripts/reset_test_db.py](backend/scripts/reset_test_db.py)

## ❓ 工作原理

1. 设置 `RESET_MIGRATIONS=true` 环境变量
2. 应用启动时检测到该变量
3. 自动清空 `schema_migrations` 表
4. 重新创建所有表并执行所有迁移
5. 删除环境变量防止重复执行

## ⚠️ 重要提醒

- ✅ **Test 环境**：可以安全使用自动修复
- ❌ **Production 环境**：有保护机制，不会自动重置
- 🔄 **一次性操作**：修复后务必删除环境变量

## 🐛 遇到问题？

运行诊断脚本查看详细状态：
```bash
railway run python backend/scripts/check_db_state.py
```

---

**快速总结**：
1. 加环境变量 `RESET_MIGRATIONS=true`
2. 等部署完成
3. 删除环境变量
