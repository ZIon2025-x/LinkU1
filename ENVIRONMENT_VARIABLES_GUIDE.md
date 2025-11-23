# 🔧 环境变量配置指南

## 📋 **重要说明**

### ✅ **Cookie配置 - 无需手动设置**
由于我们实现了智能Cookie检测系统，**您不需要手动设置 `COOKIE_SAMESITE`**！

- **系统会自动检测**：根据User-Agent判断移动端/桌面端
- **移动端**：自动使用 `SameSite=none + Secure=true`
- **桌面端**：自动使用 `SameSite=strict + Secure=true`

## 🚀 **Railway生产环境配置**

### **必须设置的环境变量**
```env
# 安全密钥 (必须更改)
SECRET_KEY=your-super-secure-random-secret-key-here

# 环境配置
ENVIRONMENT=production
COOKIE_SECURE=true
COOKIE_DOMAIN=
COOKIE_PATH=/

# CORS配置 (替换为您的实际域名)
ALLOWED_ORIGINS=https://your-vercel-app.vercel.app,https://your-domain.com

# 邮件配置 (必需)
EMAIL_FROM=noreply@yourdomain.com
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SMTP_USE_TLS=true
SMTP_USE_SSL=false
EMAIL_VERIFICATION_EXPIRE_HOURS=24

# Redis配置 (如果使用Redis)
USE_REDIS=true
# Railway会自动提供REDIS_URL

# 支付配置 (如果使用Stripe)
STRIPE_PUBLIC_KEY=pk_live_your_stripe_public_key
STRIPE_SECRET_KEY=sk_live_your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret
```

### **可选的环境变量**
```env
# 性能优化
ENABLE_QUERY_OPTIMIZATION=true
ENABLE_CACHE_WARMING=true
ENABLE_RESPONSE_COMPRESSION=true
ENABLE_GZIP=true

# 监控配置
ENABLE_MONITORING=true
SLOW_QUERY_THRESHOLD=1.0
SLOW_REQUEST_THRESHOLD=2.0

# 安全配置
RATE_LIMIT_ENABLED=true
RATE_LIMIT_REQUESTS=100
RATE_LIMIT_WINDOW=60
CSRF_PROTECTION=true
SECURITY_HEADERS=true

# 文件上传
MAX_FILE_SIZE=10485760
ALLOWED_EXTENSIONS=jpg,jpeg,png,gif,webp,pdf,doc,docx
UPLOAD_PATH=uploads

# 日志配置
LOG_LEVEL=INFO
SECURITY_LOG_FILE=security.log
```

## 🏠 **本地开发环境配置**

### **基本配置**
```env
# 环境配置
ENVIRONMENT=development
DEBUG=true

# 数据库配置
DATABASE_URL=postgresql+psycopg2://postgres:your-database-password@localhost:5432/linku_db
ASYNC_DATABASE_URL=postgresql+asyncpg://postgres:your-database-password@localhost:5432/linku_db

# 安全配置
SECRET_KEY=your-secret-key-change-in-production
COOKIE_SECURE=false

# CORS配置
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080

# 邮件配置 (测试用)
EMAIL_FROM=noreply@linku.com
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SMTP_USE_TLS=true
SMTP_USE_SSL=false
```

## 🔍 **Cookie配置详解**

### **智能检测系统**
我们的系统会自动处理Cookie配置：

1. **检测User-Agent**：
   - 移动端关键词：`Mobile`, `iPhone`, `iPad`, `Android`, `BlackBerry`
   - 桌面端：其他所有设备

2. **自动配置**：
   ```python
   # 移动端
   SameSite = "none"
   Secure = True
   
   # 桌面端  
   SameSite = "strict"
   Secure = True (生产环境) / False (开发环境)
   ```

3. **无需手动设置**：
   - ❌ 不要设置 `COOKIE_SAMESITE`
   - ❌ 不要设置 `MOBILE_COOKIE_*`
   - ✅ 只需设置 `COOKIE_SECURE=true` (生产环境)

## 📊 **配置优先级**

### **环境变量优先级**
1. **环境变量** (最高优先级)
2. **配置文件默认值**
3. **代码默认值** (最低优先级)

### **重要配置说明**
- `ENVIRONMENT=production` → 启用生产模式
- `COOKIE_SECURE=true` → 生产环境必须
- `ALLOWED_ORIGINS` → 必须包含您的前端域名
- `EMAIL_*` → 邮箱验证必需

## 🚨 **常见问题**

### **Q: 需要设置COOKIE_SAMESITE吗？**
**A: 不需要！** 系统会自动检测移动端并使用合适的配置。

### **Q: 移动端Cookie还是不工作？**
**A: 检查以下配置：**
- `ENVIRONMENT=production`
- `COOKIE_SECURE=true`
- `ALLOWED_ORIGINS` 包含您的前端域名
- 确保使用HTTPS

### **Q: 如何验证配置？**
**A: 查看日志：**
```
设置会话Cookie - session_id: ZhLV5Pg2..., user_id: 27167013, 移动端: true, SameSite: none, Secure: true
```

## 📝 **快速配置清单**

### **Railway生产环境**
- [ ] `SECRET_KEY` (必须更改)
- [ ] `ENVIRONMENT=production`
- [ ] `COOKIE_SECURE=true`
- [ ] `ALLOWED_ORIGINS` (您的域名)
- [ ] `EMAIL_*` (邮箱配置)
- [ ] `USE_REDIS=true` (如果使用Redis)

### **本地开发环境**
- [ ] `ENVIRONMENT=development`
- [ ] `COOKIE_SECURE=false`
- [ ] `ALLOWED_ORIGINS=http://localhost:3000`
- [ ] `EMAIL_*` (测试邮箱配置)

## 🎯 **总结**

**重要**：由于实现了智能Cookie检测，您只需要设置基本的环境变量，Cookie配置会自动处理。这确保了移动端和桌面端的最佳兼容性和安全性。
