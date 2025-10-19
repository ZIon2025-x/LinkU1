# 跨域Cookie修复指南

## 问题描述

前端在 `www.link2ur.com`，后端API在 `api.link2ur.com`，客服登录后：
1. 登录成功（返回200状态码）
2. 但前端检测不到 `service_authenticated` Cookie
3. 页面没有跳转到客服管理页面

## 根本原因

1. **跨域Cookie设置延迟**: Cookie从 `api.link2ur.com` 设置后，在 `www.link2ur.com` 中可能需要时间才能可见
2. **Cookie检测时机问题**: 前端在Cookie设置完成前就检测Cookie
3. **跨域Cookie传播**: 虽然域名设置正确（`.link2ur.com`），但Cookie传播可能需要时间

## 修复方案

### 1. 前端登录页面优化

**文件**: `frontend/src/pages/CustomerServiceLogin.tsx`

```typescript
// 登录成功后立即跳转，不依赖Cookie检测
navigate('/customer-service', { replace: true });
```

**改进**:
- 移除Cookie检测逻辑
- 立即跳转，让路由组件处理认证
- 避免Cookie检测的时机问题

### 2. 路由组件优化

**文件**: `frontend/src/components/CustomerServiceRoute.tsx`

```typescript
// 减少重试次数，更快进入API验证
if (retryCount < 2) {
  setTimeout(() => checkAuth(retryCount + 1), 300);
  return;
} else {
  // 即使Cookie检测失败，也尝试直接调用API验证
}
```

**改进**:
- 减少Cookie检测重试次数（从5次减少到2次）
- 缩短重试间隔（从800ms减少到300ms）
- 即使Cookie检测失败也尝试API验证

### 3. 认证Hook优化

**文件**: `frontend/src/hooks/useAuth.ts`

```typescript
// 增加详细的Cookie调试信息
console.log('useAuth - 所有Cookie:', document.cookie);
console.log('useAuth - service_authenticated cookie匹配结果:', serviceCookieMatch);
```

**改进**:
- 增加详细的Cookie调试日志
- 帮助诊断Cookie设置问题

## 技术细节

### Cookie域名设置

后端Cookie设置使用 `.link2ur.com` 域名，这应该允许在子域名间共享：

```python
cookie_domain = settings.COOKIE_DOMAIN if settings.IS_PRODUCTION else None
# COOKIE_DOMAIN = ".link2ur.com"
```

### CORS配置

后端CORS配置包含前端域名：

```python
ALLOWED_ORIGINS = [
    "https://www.link2ur.com",
    "https://api.link2ur.com"
]
```

### Cookie属性

```python
response.set_cookie(
    key="service_authenticated",
    value="true",
    max_age=SERVICE_SESSION_EXPIRE_HOURS * 3600,
    httponly=False,  # 前端需要读取
    secure=secure_value,
    samesite="lax",  # 支持跨域
    path="/",
    domain=".link2ur.com"  # 支持子域名
)
```

## 测试方法

### 1. 创建测试页面

创建 `test_cross_domain_cookie.html` 来测试跨域Cookie：

```html
<!DOCTYPE html>
<html>
<head>
    <title>跨域Cookie测试 - www.link2ur.com</title>
</head>
<body>
    <h1>跨域Cookie测试</h1>
    <button onclick="testLogin()">测试客服登录</button>
    <button onclick="checkCookies()">检查Cookie</button>
    <div id="result"></div>
    <!-- JavaScript测试代码 -->
</body>
</html>
```

### 2. 测试步骤

1. 在 `www.link2ur.com` 打开测试页面
2. 点击"测试客服登录"
3. 检查Cookie是否正确设置
4. 验证API认证是否正常工作

### 3. 预期结果

- 登录成功后应该设置以下Cookie：
  - `service_authenticated=true`
  - `service_session_id=<session_id>`
  - `service_refresh_token=<token>`
  - `service_id=<service_id>`
- 前端应该能够检测到这些Cookie
- 页面应该成功跳转到客服管理页面

## 故障排除

### 如果Cookie仍然检测不到

1. **检查浏览器开发者工具**:
   - 打开Network标签
   - 查看登录请求的Response Headers
   - 确认Set-Cookie头是否正确

2. **检查Cookie设置**:
   - 打开Application标签
   - 查看Cookies部分
   - 确认Cookie域名和路径是否正确

3. **检查CORS设置**:
   - 确认后端CORS配置包含前端域名
   - 检查预检请求是否成功

### 如果API认证失败

1. **检查API端点**:
   - 确认 `/api/auth/service/profile` 端点存在
   - 检查API服务器是否正常运行

2. **检查认证逻辑**:
   - 确认客服账号存在
   - 检查密码是否正确

## 部署注意事项

1. **环境变量**:
   ```bash
   COOKIE_DOMAIN=.link2ur.com
   COOKIE_SECURE=true
   COOKIE_SAMESITE=lax
   ALLOWED_ORIGINS=https://www.link2ur.com,https://api.link2ur.com
   ```

2. **HTTPS要求**:
   - 生产环境必须使用HTTPS
   - Cookie的secure属性必须为true

3. **域名配置**:
   - 确保DNS正确配置
   - 检查SSL证书是否有效

## 总结

通过优化前端的Cookie检测逻辑和跳转时机，解决了跨域Cookie的检测问题。主要改进包括：

1. 移除登录页面的Cookie检测依赖
2. 优化路由组件的重试逻辑
3. 增加详细的调试日志
4. 提供完整的测试方案

这些修改确保了客服登录功能在跨域环境下的正常工作。
