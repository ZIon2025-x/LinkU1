# Railway后端部署指南

## 🚀 部署步骤

### 1. 准备代码
确保backend目录包含所有必要文件：
- app/ (FastAPI应用)
- alembic/ (数据库迁移)
- requirements.txt (Python依赖)
- railway.json (Railway配置)

### 2. 创建Railway项目
1. 访问 https://railway.app
2. 点击 "New Project"
3. 选择 "Deploy from GitHub repo" 或 "Deploy from template"
4. 如果选择GitHub，连接你的仓库
5. 选择backend目录作为根目录

### 3. 配置环境变量
在Railway控制台的Variables标签页添加：

```env
# 环境设置
ENVIRONMENT=production

# 安全密钥 (必须更改)
SECRET_KEY=your-super-secure-random-secret-key-here

# 数据库配置 (Railway会自动提供)
DATABASE_URL=postgresql://username:password@host:port/database
ASYNC_DATABASE_URL=postgresql+asyncpg://username:password@host:port/database

# Redis配置 (Railway会自动提供)
# 注意：需要先在Railway中添加Redis服务
# 如果没有Redis服务，请设置 USE_REDIS=false
REDIS_URL=redis://host:port/0
USE_REDIS=true

# Cookie配置 - Railway生产环境
COOKIE_SECURE=true
COOKIE_SAMESITE=none
COOKIE_DOMAIN=your-railway-domain.railway.app

# CORS配置
ALLOWED_ORIGINS=https://your-vercel-app.vercel.app,https://your-domain.com

# 邮箱配置 - 用于用户注册验证
EMAIL_FROM=noreply@linku.com
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SMTP_USE_TLS=true
SMTP_USE_SSL=false
EMAIL_VERIFICATION_EXPIRE_HOURS=24

# 开发环境配置 - 跳过邮件验证
# 生产环境建议设为false，开发环境设为true
SKIP_EMAIL_VERIFICATION=true

# 基础URL配置
BASE_URL=https://your-app.railway.app

# JWT配置
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=30
```

### 4. 添加数据库服务
1. 在Railway项目中点击 "+ New"
2. 选择 "Database" -> "PostgreSQL"
3. 等待数据库创建完成
4. 复制DATABASE_URL到环境变量

### 5. 添加Redis服务
1. 在Railway项目中点击 "+ New"
2. 选择 "Database" -> "Redis"
3. 等待Redis创建完成
4. 复制REDIS_URL到环境变量

### 6. 配置邮箱服务（可选）
如果需要邮箱验证功能：

**方案1：使用Gmail SMTP（推荐）**
1. 在Gmail中启用两步验证
2. 生成应用专用密码
3. 设置环境变量：
   - `SMTP_USER`: 你的Gmail邮箱
   - `SMTP_PASS`: 应用专用密码
   - `SKIP_EMAIL_VERIFICATION=false`

**方案2：跳过邮箱验证（开发环境）**
1. 设置环境变量：`SKIP_EMAIL_VERIFICATION=true`
2. 用户注册后直接激活，无需邮箱验证

### 7. 运行数据库迁移
Railway会自动运行数据库迁移，如果没有：
1. 在Railway控制台打开Terminal
2. 运行: `alembic upgrade head`

### 8. 检查部署状态
- 查看Deployments标签页
- 检查日志确保没有错误
- 测试API端点是否可访问

## 🔧 配置说明

### railway.json
```json
{
  "build": {
    "builder": "NIXPACKS",
    "buildCommand": "pip install -r requirements.txt"
  },
  "deploy": {
    "startCommand": "python -m uvicorn app.main:app --host 0.0.0.0 --port $PORT"
  }
}
```

### nixpacks.toml
```toml
[phases.setup]
nixPkgs = ["python311", "postgresql"]

[phases.install]
cmds = ["pip install -r requirements.txt"]

[start]
cmd = "python -m uvicorn app.main:app --host 0.0.0.0 --port $PORT"
```

## 🚨 故障排除

### 常见错误
1. **ModuleNotFoundError**: 检查requirements.txt
2. **Database connection failed**: 检查DATABASE_URL
3. **Redis连接失败**: 检查是否添加了Redis服务，或设置USE_REDIS=false
4. **CORS error**: 检查ALLOWED_ORIGINS
5. **Port binding error**: 确保使用$PORT环境变量
6. **注册失败400错误**: 检查邮箱配置或设置SKIP_EMAIL_VERIFICATION=true
7. **邮件发送失败**: 检查SMTP配置或使用跳过验证模式

### Redis连接问题
如果看到 "Redis连接失败，使用内存缓存" 错误：

**方案1：添加Redis服务（推荐）**
1. 在Railway项目中添加Redis服务
2. 复制REDIS_URL到环境变量
3. 重新部署

**方案2：禁用Redis（临时）**
1. 设置环境变量：`USE_REDIS=false`
2. 重新部署
3. 应用将使用内存缓存

### 邮箱配置问题
如果用户注册时出现400错误：

**快速解决方案（推荐）**
1. 在Railway环境变量中设置：`SKIP_EMAIL_VERIFICATION=true`
2. 重新部署应用
3. 用户注册后直接激活，无需邮箱验证

**完整邮箱配置（如果需要邮箱验证）**
1. 使用Gmail SMTP：
   - 在Gmail中启用两步验证
   - 生成应用专用密码
   - 设置环境变量：
     ```
     SMTP_USER=your-email@gmail.com
     SMTP_PASS=your-app-password
     SKIP_EMAIL_VERIFICATION=false
     ```

2. 使用其他SMTP服务：
   - 修改SMTP_SERVER、SMTP_PORT等配置
   - 确保SMTP_USER和SMTP_PASS正确

### 查看日志
1. 在Railway控制台点击Deployments
2. 选择最新的部署
3. 查看Build Logs和Deploy Logs

### 重启服务
1. 在Railway控制台点击Settings
2. 点击 "Restart Service"
