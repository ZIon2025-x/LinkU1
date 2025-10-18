# Railway 环境变量配置指南

## 前端环境变量

在 Railway 项目设置中添加以下环境变量：

### 必需的环境变量
```
REACT_APP_API_URL=https://api.link2ur.com
REACT_APP_WS_URL=wss://api.link2ur.com
```

### 可选的环境变量
```
REACT_APP_ENVIRONMENT=production
REACT_APP_VERSION=1.0.0
```

## 后端环境变量

### 独立认证系统配置
```
# 会话过期时间（小时）
ADMIN_SESSION_EXPIRE_HOURS=8
SERVICE_SESSION_EXPIRE_HOURS=12
USER_SESSION_EXPIRE_HOURS=24

# 最大活跃会话数
ADMIN_MAX_ACTIVE_SESSIONS=3
SERVICE_MAX_ACTIVE_SESSIONS=2
USER_MAX_ACTIVE_SESSIONS=5
```

### 现有环境变量
```
# 数据库
DATABASE_URL=postgresql://...

# Redis
REDIS_URL=redis://...

# JWT
SECRET_KEY=your-secret-key
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=30

# 其他
USE_REDIS=true
```

## 重要说明

### 🔒 **最高安全等级认证系统**

#### 客服认证系统
- ✅ **Cookie会话认证**：使用 `service_session_id` Cookie
- ✅ **最高安全等级**：`httponly=True`, `secure=True`, `samesite="strict"`
- ✅ **路径设置**：根路径 `/` 确保前端可读取
- ✅ **设备指纹验证**：防止会话劫持
- ✅ **IP地址验证**：检测异常登录
- ✅ **会话活跃检查**：实时验证会话状态

#### 管理员认证系统
- ✅ **Cookie会话认证**：使用 `admin_session_id` Cookie
- ✅ **最高安全等级**：`httponly=True`, `secure=True`, `samesite="strict"`
- ✅ **路径设置**：根路径 `/` 确保前端可读取
- ✅ **设备指纹验证**：防止会话劫持
- ✅ **IP地址验证**：检测异常登录
- ✅ **会话活跃检查**：实时验证会话状态

#### 用户认证系统
- ✅ **混合认证**：支持Cookie会话 + JWT token
- ✅ **标准安全等级**：`httponly=True`, `secure=True`, `samesite="lax"`
- ✅ **向后兼容**：支持旧JWT认证系统

### 🚫 **安全隔离**
- ❌ **客服不能访问用户路由**：完全分离
- ❌ **管理员不能访问用户路由**：完全分离
- ❌ **用户不能访问客服/管理员路由**：完全分离

## 配置说明

### 独立认证系统特性
1. **完全分离的会话管理**：
   - 用户：`session_id` Cookie，24小时过期
   - 客服：`service_session_id` Cookie，12小时过期
   - 管理员：`admin_session_id` Cookie，8小时过期

2. **独立的API端点**：
   - 用户：`/api/users/*`
   - 客服：`/api/auth/service/*`
   - 管理员：`/api/auth/admin/*`

3. **安全特性**：
   - 设备指纹验证
   - 会话劫持检测
   - 自动会话清理
   - 密码修改功能

### 环境变量优先级
1. Railway 环境变量（生产环境）
2. `.env.local` 文件（本地开发）
3. 默认值（代码中定义）

## 部署检查清单

- [ ] 前端环境变量已设置
- [ ] 后端环境变量已设置
- [ ] 数据库连接正常
- [ ] Redis 连接正常
- [ ] 独立认证系统路由已注册
- [ ] 硬编码 URL 已替换为环境变量
- [ ] 测试所有认证端点

## 测试端点

### 管理员认证
```
POST /api/auth/admin/login
POST /api/auth/admin/logout
GET  /api/auth/admin/profile
```

### 客服认证
```
POST /api/auth/service/login
POST /api/auth/service/logout
GET  /api/auth/service/profile
```

### 用户认证（保持原有）
```
POST /api/users/login
POST /api/users/logout
GET  /api/users/profile
```
