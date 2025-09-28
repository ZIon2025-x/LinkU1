# Railway生产环境Cookie配置指南

## 🚀 Railway部署Cookie配置

### ✅ **已实装的生产模式Cookie配置**

您的后端部署在Railway，我已经为Railway环境优化了Cookie配置：

#### 1. **智能环境检测**
```python
# 自动检测Railway生产环境
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")
IS_PRODUCTION = ENVIRONMENT == "production"

# Railway生产环境自动启用安全Cookie
COOKIE_SECURE = os.getenv("COOKIE_SECURE", "true" if IS_PRODUCTION else "false")
COOKIE_SAMESITE = os.getenv("COOKIE_SAMESITE", "none" if IS_PRODUCTION else "lax")
```

#### 2. **Railway生产环境Cookie设置**
- ✅ `COOKIE_SECURE=true` - 仅通过HTTPS传输
- ✅ `COOKIE_SAMESITE=none` - 支持跨域请求（前端在Vercel）
- ✅ `COOKIE_HTTPONLY=true` - 防止XSS攻击
- ✅ `COOKIE_DOMAIN` - 可配置Railway域名

### 🔧 **Railway环境变量配置**

在Railway控制台的Variables标签页添加以下环境变量：

```env
# 环境设置
ENVIRONMENT=production

# 安全密钥 (必须更改)
SECRET_KEY=your-super-secure-random-secret-key-here

# 数据库配置 (Railway会自动提供)
DATABASE_URL=postgresql://username:password@host:port/database
ASYNC_DATABASE_URL=postgresql+asyncpg://username:password@host:port/database

# Redis配置 (Railway会自动提供)
REDIS_URL=redis://host:port/0
USE_REDIS=true

# Cookie配置 - Railway生产环境
COOKIE_SECURE=true
COOKIE_SAMESITE=none
COOKIE_DOMAIN=your-app.railway.app

# CORS配置
ALLOWED_ORIGINS=https://your-vercel-app.vercel.app,https://your-domain.com

# JWT配置
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=30
```

### 🔒 **Railway Cookie安全特性**

#### 生产环境Cookie响应头示例：
```
set-cookie: session_id=session_123; HttpOnly; Max-Age=300; Path=/; SameSite=none; Secure
set-cookie: refresh_token=refresh_456; HttpOnly; Max-Age=604800; Path=/; SameSite=none; Secure
set-cookie: user_id=user_789; Max-Age=604800; Path=/; SameSite=none; Secure
set-cookie: csrf_token=csrf_token; Max-Age=3600; Path=/; SameSite=none; Secure
```

#### 安全特性说明：
- **Secure标志**: 确保Cookie仅通过HTTPS传输
- **SameSite=none**: 支持跨域请求（Railway后端 ↔ Vercel前端）
- **HttpOnly**: 防止JavaScript访问敏感Cookie
- **Max-Age**: 自动过期时间管理

### 🚀 **Railway部署步骤**

#### 1. 更新Railway环境变量
1. 登录Railway控制台
2. 选择您的项目
3. 点击"Variables"标签页
4. 添加上述环境变量

#### 2. 重新部署
1. 在Railway控制台点击"Deployments"
2. 点击"Redeploy"触发重新部署
3. 等待部署完成

#### 3. 验证Cookie配置
```bash
# 测试Railway API端点
curl -I https://your-app.railway.app/api/auth/login

# 检查Set-Cookie响应头
# 应该看到Secure和SameSite=none标志
```

### 🔍 **故障排除**

#### 常见问题：

1. **Cookie不生效**
   - 检查`ENVIRONMENT=production`是否设置
   - 确认`COOKIE_SECURE=true`
   - 验证`COOKIE_SAMESITE=none`

2. **跨域Cookie问题**
   - 确保`COOKIE_SAMESITE=none`
   - 检查前端请求是否包含`credentials: 'include'`
   - 验证CORS配置正确

3. **HTTPS问题**
   - Railway自动提供HTTPS
   - 确保`COOKIE_SECURE=true`
   - 检查域名配置

### 📋 **验证清单**

- [ ] `ENVIRONMENT=production` 已设置
- [ ] `COOKIE_SECURE=true` 已设置
- [ ] `COOKIE_SAMESITE=none` 已设置
- [ ] `COOKIE_DOMAIN` 设置为Railway域名
- [ ] `ALLOWED_ORIGINS` 包含前端域名
- [ ] 重新部署已完成
- [ ] Cookie响应头包含Secure标志
- [ ] 跨域请求正常工作

### 🎉 **总结**

您的Railway后端现在完全支持生产环境Cookie配置：

- ✅ **自动环境检测** - 根据`ENVIRONMENT`变量自动切换
- ✅ **安全Cookie设置** - 生产环境自动启用最高安全级别
- ✅ **跨域支持** - 支持Railway后端与Vercel前端的跨域通信
- ✅ **统一配置管理** - 所有Cookie设置使用统一配置
- ✅ **Railway优化** - 专门为Railway环境优化的配置

**您的Railway后端Cookie配置已完全就绪！** 🚀
