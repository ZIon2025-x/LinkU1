# 自动清空数据库表功能

## 功能说明

在应用启动时自动清空任务聊天功能相关的表，用于数据库重建场景。

## 使用方法

### 方法 1：通过环境变量控制（推荐）

在 Railway 项目设置中添加环境变量：

```
CLEAR_TABLES_ON_STARTUP=true
```

当设置为 `true` 时，应用启动时会自动清空以下表：
- `task_applications`
- `reviews`
- `task_history`
- `task_cancel_requests`
- `messages`
- `notifications`
- `tasks`

**注意：** 以下表会被保留（不会清空）：
- `users` (用户基础信息)
- `admin_users` (管理员账户)
- `system_settings` (系统设置)
- `pending_users` (待验证用户)
- `customer_service*` (客服相关表)
- `admin_*` (管理员相关表)
- `user_preferences` (用户偏好)

### 方法 2：手动运行脚本

```bash
# 在 Railway 控制台或本地运行
python backend/clear_tables_auto.py
```

## 安全提示

⚠️ **重要：** 此功能会永久删除数据，请谨慎使用！

- 仅在数据库重建时使用
- 清空前确保已备份重要数据
- 生产环境使用前请充分测试

## 部署步骤

1. 在 Railway 项目 → Variables 中添加：
   ```
   CLEAR_TABLES_ON_STARTUP=true
   ```

2. 部署应用（应用启动时会自动清空表）

3. **清空完成后，立即移除或设置为 false：**
   ```
   CLEAR_TABLES_ON_STARTUP=false
   ```
   避免每次重启都清空数据

## 日志输出

清空操作会在应用启动日志中显示：
```
[INFO] 检测到 CLEAR_TABLES_ON_STARTUP=true，开始清空指定表...
[INFO] ✅ 已清空表: task_applications
[INFO] ✅ 已清空表: reviews
...
[INFO] 清空完成！成功清空 7/7 个表
```

