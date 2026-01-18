# 2FA 数据库迁移说明

## 自动迁移

✅ **迁移脚本会在应用启动时自动执行**

迁移脚本：`backend/migrations/055_add_2fa_to_admin_users.sql`

### 自动执行条件

1. **环境变量**：`AUTO_MIGRATE=true`（默认值）
2. **执行时机**：应用启动时（`startup_event`）
3. **执行位置**：`backend/app/main.py` 的 `startup_event` 函数

### 迁移内容

为 `admin_users` 表添加以下字段：

```sql
ALTER TABLE admin_users 
ADD COLUMN IF NOT EXISTS totp_secret VARCHAR(32),
ADD COLUMN IF NOT EXISTS totp_enabled INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS totp_backup_codes TEXT;
```

### 字段说明

- **totp_secret**: TOTP 密钥（Base32 编码），用于生成 6 位验证码
- **totp_enabled**: 2FA 是否已启用（1=已启用，0=未启用）
- **totp_backup_codes**: 备份代码（JSON 数组），用于在丢失 Authenticator 设备时恢复账户

## 手动迁移

如果需要手动执行迁移：

```bash
cd backend
python run_migrations.py --migration 055_add_2fa_to_admin_users.sql
```

## 检查迁移状态

```bash
# 查看所有迁移状态
python run_migrations.py --status

# 列出所有迁移脚本
python run_migrations.py --list
```

## 迁移记录

迁移执行记录存储在 `schema_migrations` 表中：

```sql
SELECT * FROM schema_migrations 
WHERE migration_name = '055_add_2fa_to_admin_users.sql';
```

## 安全说明

- ✅ 迁移脚本使用 `IF NOT EXISTS`，可以安全地重复执行
- ✅ 仅限管理员子域名使用（路由在 `/api/auth/admin/2fa/*`）
- ✅ 所有 2FA API 都受管理员安全中间件保护

## 故障排查

### 迁移未执行

1. 检查环境变量：`AUTO_MIGRATE=true`
2. 查看应用启动日志，查找迁移相关消息
3. 手动执行迁移脚本

### 迁移执行失败

1. 检查数据库连接
2. 检查 `admin_users` 表是否存在
3. 查看错误日志
4. 手动执行 SQL 脚本

### 字段已存在

迁移脚本使用 `IF NOT EXISTS`，如果字段已存在，会跳过，不会报错。
