# 客服认证系统Refresh Token实现

## 概述

为客服认证系统添加了refresh token机制，使其与用户认证系统保持一致，提供更好的安全性和用户体验。

## 主要改进

### 1. 新增Refresh Token支持
- **客服登录时**：自动生成refresh token并存储在Cookie中
- **Token刷新**：提供专门的API端点刷新access token和refresh token
- **安全性**：refresh token使用HttpOnly Cookie，防止XSS攻击

### 2. Cookie结构更新
客服认证现在使用以下Cookie：
- `service_session_id` - 会话ID (HttpOnly, 12小时)
- `service_refresh_token` - 刷新令牌 (HttpOnly, 7天) **新增**
- `service_authenticated` - 身份标识 (前端可读, 12小时)
- `service_id` - 客服ID (前端可读, 12小时)

### 3. 新增API端点

#### `/api/auth/service/refresh-token` (POST)
- **功能**：使用refresh token生成新的access token和refresh token
- **认证**：需要有效的`service_refresh_token` Cookie
- **返回**：新的access token、refresh token和客服信息

## 实现细节

### 后端修改

#### 1. `backend/app/service_auth.py`
```python
def create_service_session_cookie(response: Response, session_id: str, user_agent: str = "", service_id: Optional[str] = None) -> Response:
    # 生成refresh token（如果提供了service_id）
    refresh_token = None
    if service_id:
        refresh_token = create_refresh_token(data={"sub": service_id, "role": "service"})
    
    # 设置refresh token Cookie
    if refresh_token:
        response.set_cookie(
            key="service_refresh_token",
            value=refresh_token,
            max_age=7 * 24 * 3600,  # 7天
            httponly=True,
            secure=secure_value,
            samesite=samesite_value,
            path=cookie_path,
            domain=cookie_domain
        )
```

#### 2. `backend/app/separate_auth_routes.py`
```python
@router.post("/service/refresh-token", response_model=Dict[str, Any])
def service_refresh_token(request: Request, response: Response, db: Session = Depends(get_sync_db)):
    # 从cookie中获取refresh token
    refresh_token = request.cookies.get("service_refresh_token")
    
    # 验证refresh token
    payload = verify_token(refresh_token, "refresh")
    service_id = payload.get("sub")
    role = payload.get("role")
    
    # 生成新的access token和refresh token
    new_access_token, new_refresh_token = refresh_access_token(refresh_token)
    
    # 设置新的Cookie
    response = create_service_session_cookie(response, "", user_agent, str(service.id))
```

### 前端使用

#### 1. 自动Token刷新
前端可以在API请求失败时自动尝试刷新token：

```javascript
// 在api.ts中添加token刷新逻辑
const refreshServiceToken = async () => {
  try {
    const response = await fetch('/api/auth/service/refresh-token', {
      method: 'POST',
      credentials: 'include'
    });
    
    if (response.ok) {
      const data = await response.json();
      return data.access_token;
    }
  } catch (error) {
    console.error('Token刷新失败:', error);
  }
  return null;
};
```

#### 2. Cookie检测
前端可以检测refresh token的存在：

```javascript
const hasServiceRefreshToken = document.cookie.includes('service_refresh_token=');
```

## 安全特性

### 1. Token安全
- **HttpOnly Cookie**：防止XSS攻击
- **短期Access Token**：减少泄露风险
- **长期Refresh Token**：提供便利性
- **可撤销性**：可以撤销特定设备的访问权限

### 2. 角色验证
- refresh token包含`role: "service"`标识
- 确保只有客服可以使用客服相关的refresh token

### 3. 自动过期
- refresh token自动过期（7天）
- 过期后需要重新登录

## 使用场景

### 1. 正常登录流程
1. 客服登录 → 获得session_id和refresh_token
2. 使用session_id进行API调用
3. 会话过期时自动使用refresh_token刷新

### 2. 长期使用
1. 客服可以保持登录状态7天
2. 期间无需重新输入密码
3. 可以随时撤销特定设备的访问权限

### 3. 安全登出
1. 登出时清除所有相关Cookie
2. 撤销refresh token
3. 确保无法继续访问

## 配置选项

### 环境变量
```bash
# 客服会话过期时间（小时）
SERVICE_SESSION_EXPIRE_HOURS=12

# 客服最大活跃会话数
SERVICE_MAX_ACTIVE_SESSIONS=2

# Cookie安全设置
COOKIE_SECURE=true
COOKIE_SAMESITE=lax
COOKIE_DOMAIN=your-domain.com
```

## 测试验证

### 1. 登录测试
```bash
# 测试客服登录
curl -X POST "https://your-domain.com/api/auth/service/login" \
  -H "Content-Type: application/json" \
  -d '{"cs_id": "CS8888", "password": "password123"}' \
  -c cookies.txt
```

### 2. Token刷新测试
```bash
# 测试refresh token
curl -X POST "https://your-domain.com/api/auth/service/refresh-token" \
  -b cookies.txt \
  -c new_cookies.txt
```

### 3. Cookie验证
检查返回的Cookie是否包含：
- `service_session_id`
- `service_refresh_token`
- `service_authenticated`
- `service_id`

## 兼容性

### 向后兼容
- 现有的session-based认证仍然有效
- 前端可以逐步迁移到refresh token机制
- 不影响现有的客服功能

### 前端适配
- 前端需要添加token刷新逻辑
- 可以检测refresh token的存在
- 在API请求失败时自动刷新token

## 总结

通过添加refresh token机制，客服认证系统现在具有：

1. **更好的安全性**：短期access token + 长期refresh token
2. **更好的用户体验**：减少重新登录的频率
3. **与用户认证一致**：使用相同的安全模式
4. **可撤销性**：可以撤销特定设备的访问权限
5. **自动过期**：防止长期未使用的会话

这使客服认证系统更加完善和安全，同时保持了良好的用户体验。
