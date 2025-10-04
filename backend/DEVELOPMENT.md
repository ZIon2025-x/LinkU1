# 开发环境配置指南

## 快速开始

### 开发环境（跳过邮件验证）

```bash
# 使用开发环境启动脚本
python start_dev.py
```

或者手动设置环境变量：

```bash
# 设置环境变量
export SKIP_EMAIL_VERIFICATION=true
export DEBUG=true
export ENVIRONMENT=development

# 启动应用
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### 生产环境（需要邮件验证）

```bash
# 使用生产环境启动脚本
python start_prod.py
```

或者手动设置环境变量：

```bash
# 设置环境变量
export SKIP_EMAIL_VERIFICATION=false
export DEBUG=false
export ENVIRONMENT=production

# 启动应用
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

## 环境变量说明

### 开发环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `SKIP_EMAIL_VERIFICATION` | `false` | 是否跳过邮件验证（开发环境设为 `true`） |
| `DEBUG` | `true` | 是否开启调试模式 |
| `ENVIRONMENT` | `development` | 环境类型 |
| `COOKIE_SECURE` | `false` | Cookie是否使用HTTPS |
| `COOKIE_SAMESITE` | `lax` | Cookie SameSite策略 |

### 生产环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `SKIP_EMAIL_VERIFICATION` | `false` | 是否跳过邮件验证（生产环境必须为 `false`） |
| `DEBUG` | `false` | 是否开启调试模式 |
| `ENVIRONMENT` | `production` | 环境类型 |
| `COOKIE_SECURE` | `true` | Cookie是否使用HTTPS |
| `COOKIE_SAMESITE` | `strict` | Cookie SameSite策略 |

## 注册流程

### 开发环境
1. 用户填写注册信息
2. 直接创建用户账户（跳过邮件验证）
3. 用户可以直接登录

### 生产环境
1. 用户填写注册信息
2. 创建待验证用户
3. 发送验证邮件
4. 用户点击邮件链接完成验证
5. 用户才能登录

## 注意事项

⚠️ **重要**：`SKIP_EMAIL_VERIFICATION=true` 仅用于开发环境，生产环境必须设为 `false`！

## 故障排除

### 注册失败
- 检查数据库连接
- 检查用户名/邮箱是否重复
- 查看控制台日志

### 邮件发送失败（生产环境）
- 检查SMTP配置
- 检查邮箱凭据
- 查看邮件发送日志

### Cookie问题
- 开发环境：使用 `COOKIE_SECURE=false`
- 生产环境：使用 `COOKIE_SECURE=true`
- 检查CORS配置
