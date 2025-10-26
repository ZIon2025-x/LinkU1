# CSRF Token 修复总结

## 问题描述

用户在尝试接受任务时遇到 401 Unauthorized 错误。请求信息显示：
- Cookie 中有 `csrf_token=nd3xdATrAPdJoQbriRAVGBcFgw3Yshy8UPMEd_oekAM`
- 请求头中**没有** `X-CSRF-Token`
- 后端需要验证 CSRF token（Cookie 和 Header 中的 token 必须匹配）

## 根本原因

在 `frontend/src/components/TaskDetailModal.tsx` 和 `frontend/src/pages/Tasks.tsx` 中，`handleAcceptTask` 函数直接使用 `fetch` API 调用 `/api/tasks/{taskId}/accept` 端点，而没有使用 `api` 实例。

虽然代码尝试从 Cookie 中读取 CSRF token，但存在以下问题：
1. Cookie 读取逻辑可能不正确
2. 没有使用标准的 `api` 实例，因此绕过了自动 CSRF token 处理

## 修复方案

### 1. TaskDetailModal.tsx

**修复前：**
```typescript
// 获取 CSRF token
const csrfToken = document.cookie
  .split('; ')
  .find(row => row.startsWith('csrf_token='))
  ?.split('=')[1];

const response = await fetch(`${API_BASE_URL}/api/tasks/${taskId}/accept`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    ...(csrfToken && { 'X-CSRF-Token': csrfToken }),
  },
  credentials: 'include',
});
```

**修复后：**
```typescript
// 使用 api 实例自动处理 CSRF token
const result = await api.post(`/api/tasks/${taskId}/accept`, {});
```

### 2. Tasks.tsx

同样修改了 `handleAcceptTask` 函数，使用 `api` 实例替代 `fetch`。

## 工作原理

在 `frontend/src/api.ts` 中，axios 请求拦截器会自动处理 CSRF token：

```typescript
api.interceptors.request.use(async config => {
  // 对于写操作，添加CSRF token
  if (config.method && ['post', 'put', 'patch', 'delete'].includes(config.method.toLowerCase())) {
    const url = config.url || '';
    const isLoginRequest = url.includes('/login') || url.includes('/register') || url.includes('/auth/login');
    
    if (!isLoginRequest) {
      try {
        const token = await getCSRFToken();
        config.headers['X-CSRF-Token'] = token;
      } catch (error) {
        console.warn('无法获取CSRF token，请求可能失败:', error);
      }
    }
  }
  
  return config;
});
```

## 后端验证逻辑

后端在 `backend/app/csrf.py` 中验证 CSRF token：

```python
def verify_csrf_token(request: Request) -> bool:
    """验证CSRF token"""
    cookie_token = CSRFProtection.get_csrf_token_from_cookie(request)
    header_token = CSRFProtection.get_csrf_token_from_header(request)
    
    if not cookie_token or not header_token:
        logger.warning("CSRF token missing from cookie or header")
        return False
    
    if cookie_token != header_token:
        logger.warning("CSRF token mismatch between cookie and header")
        return False
    
    return True
```

## 验证修复

修复后，所有使用 `api` 实例的请求都会自动：
1. 获取最新的 CSRF token
2. 将其添加到请求头 `X-CSRF-Token`
3. 后端验证 Cookie 和 Header 中的 token 是否匹配

## 建议

为了避免类似问题，建议：
1. 始终使用 `api` 实例而不是直接使用 `fetch`
2. 如果必须使用 `fetch`，确保正确添加 CSRF token
3. 使用统一的错误处理和重试逻辑

## 相关文件

- `frontend/src/components/TaskDetailModal.tsx` - 任务详情模态框
- `frontend/src/pages/Tasks.tsx` - 任务列表页面
- `frontend/src/api.ts` - API 客户端配置
- `backend/app/csrf.py` - CSRF 保护模块
- `backend/app/routers.py` - API 路由定义

