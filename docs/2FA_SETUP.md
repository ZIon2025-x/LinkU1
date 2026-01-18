# 管理员 2FA (双因素认证) 设置指南

本指南说明如何为管理员账户启用和配置 Authenticator (2FA/TOTP) 双因素认证。

> **适用范围**：此功能仅限管理员子域名 (`admin.link2ur.com`) 使用。所有 2FA API 路由都受管理员安全中间件保护，仅允许来自管理员子域名的请求。

## 功能概述

- ✅ 支持 Google Authenticator、Microsoft Authenticator 等标准 TOTP 应用
- ✅ QR 码扫描设置
- ✅ 手动输入密钥设置
- ✅ 备份代码（10 个，用于恢复账户）
- ✅ 登录时自动验证 2FA
- ✅ 支持使用备份代码登录

## 后端 API

### 1. 获取 2FA 设置信息（生成 QR 码）

```http
GET /api/auth/admin/2fa/setup
Authorization: Cookie (需要管理员登录)
```

**响应：**
```json
{
  "enabled": false,
  "secret": "JBSWY3DPEHPK3PXP",
  "qr_code": "data:image/png;base64,...",
  "totp_uri": "otpauth://totp/Link²Ur%20Admin:admin@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Link²Ur%20Admin",
  "message": "请使用 Authenticator 应用扫描 QR 码或手动输入密钥"
}
```

### 2. 验证并启用 2FA

```http
POST /api/auth/admin/2fa/verify-setup
Content-Type: application/json
Authorization: Cookie

{
  "secret": "JBSWY3DPEHPK3PXP",
  "code": "123456"
}
```

**响应：**
```json
{
  "message": "2FA 已成功启用",
  "backup_codes": ["12345678", "87654321", ...],
  "enabled": true
}
```

⚠️ **重要**：请妥善保存备份代码！如果丢失 Authenticator 设备，可以使用备份代码登录。

### 3. 获取 2FA 状态

```http
GET /api/auth/admin/2fa/status
Authorization: Cookie
```

**响应：**
```json
{
  "enabled": true,
  "has_backup_codes": true
}
```

### 4. 重新生成备份代码

```http
POST /api/auth/admin/2fa/regenerate-backup-codes
Authorization: Cookie
```

**响应：**
```json
{
  "message": "备份代码已重新生成",
  "backup_codes": ["11111111", "22222222", ...]
}
```

### 5. 禁用 2FA

```http
POST /api/auth/admin/2fa/disable
Content-Type: application/json
Authorization: Cookie

{
  "password": "your_password"  // 或 "totp_code": "123456" 或 "backup_code": "12345678"
}
```

## 登录流程

启用 2FA 后，登录流程如下：

1. **输入用户名/ID 和密码**
2. **如果启用了 2FA，后端返回 `202 Accepted`，header 包含 `X-Requires-2FA: true`**
3. **前端显示 2FA 输入框**
4. **用户输入 6 位 TOTP 代码或备份代码**
5. **重新提交登录请求，包含 `totp_code` 或 `backup_code`**

### 登录请求示例

```http
POST /api/auth/admin/login
Content-Type: application/json

{
  "username_or_id": "A1234",
  "password": "your_password",
  "totp_code": "123456"  // 或 "backup_code": "12345678"
}
```

## 前端集成

### 1. 2FA 设置页面

创建设置页面，显示 QR 码和设置选项：

```typescript
// 获取 2FA 设置
const response = await api.get('/api/auth/admin/2fa/setup');
const { secret, qr_code, totp_uri } = response.data;

// 显示 QR 码
<img src={qr_code} alt="2FA QR Code" />

// 显示密钥（用于手动输入）
<p>密钥: {secret}</p>
```

### 2. 验证并启用

```typescript
// 用户扫描 QR 码后，输入验证码
const verifyResponse = await api.post('/api/auth/admin/2fa/verify-setup', {
  secret: secret,
  code: userInputCode
});

// 保存备份代码
const { backup_codes } = verifyResponse.data;
// 显示给用户并提醒保存
```

### 3. 登录时处理 2FA

```typescript
try {
  const loginResponse = await api.post('/api/auth/admin/login', {
    username_or_id: username,
    password: password
  });
  // 登录成功
} catch (error) {
  if (error.response?.status === 202 && 
      error.response?.headers['x-requires-2fa'] === 'true') {
    // 显示 2FA 输入框
    setShow2FA(true);
  }
}

// 用户输入 2FA 代码后
const loginWith2FA = await api.post('/api/auth/admin/login', {
  username_or_id: username,
  password: password,
  totp_code: twoFactorCode  // 或 backup_code
});
```

## 数据库迁移

✅ **自动迁移**：迁移脚本会在应用启动时自动执行（如果 `AUTO_MIGRATE=true`）。

迁移脚本：`backend/migrations/055_add_2fa_to_admin_users.sql`

该脚本会自动添加以下字段到 `admin_users` 表：
- `totp_secret`: TOTP 密钥（Base32 编码）
- `totp_enabled`: 2FA 是否已启用（1=已启用，0=未启用）
- `totp_backup_codes`: 备份代码（JSON 数组）

**手动迁移**（如果需要）：
```bash
cd backend
python run_migrations.py --migration 055_add_2fa_to_admin_users.sql
```

**检查迁移状态**：
```bash
python run_migrations.py --status
```

## 安全建议

1. **备份代码**：生成后立即保存到安全位置（密码管理器）
2. **多设备**：可以在多个设备上使用同一个密钥
3. **禁用 2FA**：如果丢失设备，使用备份代码登录后可以禁用并重新设置
4. **定期检查**：定期验证 2FA 是否正常工作

## 故障排查

### 验证码总是错误

- 检查设备时间是否准确（TOTP 依赖时间同步）
- 确认输入的是 6 位数字
- 尝试使用备份代码

### 丢失 Authenticator 设备

1. 使用备份代码登录
2. 禁用 2FA
3. 重新设置 2FA 并生成新的备份代码

### 备份代码也用完了

联系超级管理员重置账户的 2FA 设置。

## 依赖包

后端需要安装以下 Python 包：

```bash
pip install pyotp qrcode[pil]
```

已在 `requirements.txt` 中添加。
