# 管理员子域名安全配置

本文档说明为 `admin.link2ur.com` 子域名实施的安全增强措施。

## 安全措施概览

### 1. 请求来源验证 ✅

**实现位置**: `backend/app/admin_security_middleware.py`

所有管理员路由（`/api/admin/*` 和 `/api/auth/admin/*`）都会验证请求来源：

- ✅ 检查 `Origin` 头必须包含 `admin.link2ur.com`
- ✅ 检查 `Referer` 头必须包含 `admin.link2ur.com`
- ✅ 开发环境允许 `localhost:3001`
- ❌ 来自其他域名的请求将被拒绝（403 Forbidden）

### 2. IP 白名单（可选）✅

**环境变量**: `ENABLE_ADMIN_IP_WHITELIST=true`
**环境变量**: `ADMIN_IP_WHITELIST=ip1,ip2,ip3`

如果启用 IP 白名单，只有白名单中的 IP 才能访问管理员路由。

**配置示例**:
```bash
ENABLE_ADMIN_IP_WHITELIST=true
ADMIN_IP_WHITELIST=203.0.113.1,203.0.113.2
```

### 3. 加强的速率限制 ✅

**实现位置**: `backend/app/rate_limiting.py`

管理员相关操作的速率限制：

| 操作 | 限制 | 时间窗口 |
|------|------|----------|
| 管理员登录 | 3次 | 5分钟 |
| 管理员验证码发送 | 3次 | 5分钟 |
| 管理员验证码验证 | 3次 | 5分钟 |
| 管理员刷新Token | 10次 | 1分钟 |
| 管理员登出 | 5次 | 1分钟 |
| 管理员操作（一般） | 100次 | 1分钟 |
| 管理员敏感操作 | 20次 | 1分钟 |

### 4. 会话安全 ✅

**实现位置**: `backend/app/admin_auth.py`

- ✅ 设备指纹验证（检测会话劫持）
- ✅ IP 地址记录和验证
- ✅ 会话超时（默认 8 小时）
- ✅ 最大活跃会话数限制（默认 3 个）
- ✅ 自动撤销旧会话

### 5. CSRF 保护 ✅

所有管理员 POST/PUT/DELETE 请求都需要 CSRF Token：

- ✅ 自动获取 CSRF Token
- ✅ 请求头验证：`X-CSRF-Token`
- ✅ Cookie 和 Header 双重验证

### 6. 邮箱验证码 ✅

**环境变量**: `ENABLE_ADMIN_EMAIL_VERIFICATION=true`

管理员登录时如果启用了邮箱验证：

- ✅ 登录后需要输入邮箱验证码
- ✅ 验证码有效期：5 分钟（可配置）
- ✅ 验证码发送速率限制：3次/5分钟

### 7. 安全日志记录 ✅

**实现位置**: `backend/app/admin_security_middleware.py`

所有管理员访问都会记录：

- ✅ 访问路径
- ✅ 客户端 IP
- ✅ 请求来源（Origin）
- ✅ User-Agent
- ✅ 访问状态（允许/拒绝/错误）

日志格式：
```
[ADMIN_SECURITY] ACCESS_GRANTED | Path: /api/admin/users | IP: 203.0.113.1 | Origin: https://admin.link2ur.com | Status: allowed
```

### 8. 安全响应头 ✅

所有管理员路由响应都会添加：

- ✅ `X-Admin-Access: verified` - 标识已验证的管理员访问
- ✅ `X-Content-Type-Options: nosniff`
- ✅ `X-Frame-Options: DENY`
- ✅ `X-XSS-Protection: 1; mode=block`

### 9. CORS 配置 ✅

**实现位置**: `backend/app/config.py` 和 `backend/app/main.py`

生产环境允许的来源：
- ✅ `https://admin.link2ur.com`
- ✅ `https://www.link2ur.com`
- ✅ `https://link2ur.com`

开发环境允许的来源：
- ✅ `http://localhost:3001` (管理后台)
- ✅ `http://localhost:3000` (主站)

## 配置步骤

### 1. 环境变量配置

在 `.env` 或生产环境配置中添加：

```bash
# 管理员邮箱验证
ENABLE_ADMIN_EMAIL_VERIFICATION=true
ADMIN_EMAIL=admin@link2ur.com
ADMIN_VERIFICATION_CODE_EXPIRE_MINUTES=5

# IP 白名单（可选，默认关闭）
ENABLE_ADMIN_IP_WHITELIST=false
ADMIN_IP_WHITELIST=203.0.113.1,203.0.113.2

# CORS 配置
ALLOWED_ORIGINS=https://www.link2ur.com,https://link2ur.com,https://admin.link2ur.com
```

### 2. 中间件已自动启用

管理员安全中间件已在 `main.py` 中注册，无需额外配置。

### 3. 速率限制已配置

所有速率限制已在 `rate_limiting.py` 中配置，无需额外操作。

## 安全最佳实践

### 1. 启用邮箱验证码

**强烈建议**在生产环境启用：

```bash
ENABLE_ADMIN_EMAIL_VERIFICATION=true
```

### 2. 使用 IP 白名单（可选）

如果管理员有固定 IP，可以启用白名单：

```bash
ENABLE_ADMIN_IP_WHITELIST=true
ADMIN_IP_WHITELIST=203.0.113.1,203.0.113.2
```

### 3. 定期审查日志

定期检查管理员访问日志，发现异常访问：

```bash
grep "ADMIN_SECURITY" logs/app.log | grep "blocked"
```

### 4. 监控失败登录

监控管理员登录失败次数，发现暴力破解：

```bash
grep "ADMIN_AUTH.*登录失败" logs/app.log
```

## 故障排查

### 问题：403 Forbidden - 来源验证失败

**原因**: 请求不是来自 `admin.link2ur.com`

**解决**:
1. 检查前端是否正确设置了 `Origin` 头
2. 检查 CORS 配置是否正确
3. 开发环境确保使用 `http://localhost:3001`

### 问题：403 Forbidden - IP 不在白名单

**原因**: IP 白名单已启用，但当前 IP 不在列表中

**解决**:
1. 检查 `ADMIN_IP_WHITELIST` 环境变量
2. 临时禁用白名单：`ENABLE_ADMIN_IP_WHITELIST=false`
3. 将当前 IP 添加到白名单

### 问题：429 Too Many Requests

**原因**: 超过了速率限制

**解决**:
1. 等待限制时间窗口过期
2. 检查速率限制配置是否过于严格
3. 联系管理员调整限制

## 安全审计清单

- [x] 请求来源验证
- [x] IP 白名单（可选）
- [x] 速率限制
- [x] CSRF 保护
- [x] 会话安全
- [x] 邮箱验证码
- [x] 安全日志
- [x] 安全响应头
- [x] CORS 配置

## 相关文件

- `backend/app/admin_security_middleware.py` - 管理员安全中间件
- `backend/app/rate_limiting.py` - 速率限制配置
- `backend/app/admin_auth.py` - 管理员认证和会话管理
- `backend/app/config.py` - 安全配置
- `backend/app/main.py` - 中间件注册
