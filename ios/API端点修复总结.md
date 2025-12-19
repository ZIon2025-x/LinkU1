# API端点修复总结

## 已修复的端点问题

### 1. 跳蚤市场API路径 ✅
- **问题**: 使用了 `/api/items`，但后端实际路径是 `/api/flea-market/items`
- **修复**: 统一为 `/api/flea-market/*`
- **影响文件**: `APIService+Endpoints.swift`

### 2. 论坛API路径 ✅
- **问题**: 
  - `favoritePost` 使用了 `/api/favorites`
  - `getMyPosts` 和 `getMyReplies` 缺少 `/api/forum` 前缀
- **修复**:
  - `/api/favorites` → `/api/forum/favorites`
  - `/api/my/posts` → `/api/forum/my/posts`
  - `/api/my/replies` → `/api/forum/my/replies`

### 3. 服务申请端点 ✅
- **问题**: `getMyServiceApplications` 使用了错误的端点
- **修复**: `/api/task-experts/me/applications` → `/api/users/me/service-applications`
- **参数修复**: 将 `page/pageSize` 转换为 `limit/offset`

### 4. 消息相关端点 ✅
- **问题**: 
  - `CustomerServiceViewModel` 使用了错误的路径 `/api/users/messages/conversation`
  - `sendMessage` 端点路径不一致
- **修复**:
  - `/api/users/messages/conversation/{id}` → `/api/messages/conversation/{id}` (async_router注册在/api前缀下)
  - `/api/messages/send` → `/api/users/messages/send` (router注册在/api/users前缀下)
  - **注意**: `/api/users/messages/send` 接口已废弃（返回410错误），需要确认替代方案

### 5. 通知端点 ✅
- **验证**: `/api/users/notifications` 正确（router注册在/api/users前缀下）

### 6. 任务达人端点 ✅
- **验证**: `/api/task-experts/my-application` 存在且正确

## 端点路径规则

### 路由注册位置
- `routers.py` 中的 `router` → 注册在 `/api/users` 前缀下
- `async_routers.py` 中的 `async_router` → 注册在 `/api` 前缀下
- `secure_auth_routes.py` 中的 `secure_auth_router` → 注册时无前缀，但定义时已有 `/api/secure-auth` 前缀
- `forum_routes.py` 中的 `router` → 注册时无前缀，但定义时已有 `/api/forum` 前缀
- `flea_market_routes.py` 中的 `flea_market_router` → 注册时无前缀，但定义时已有 `/api/flea-market` 前缀
- `task_expert_routes.py` 中的 `task_expert_router` → 注册时无前缀，但定义时已有 `/api/task-experts` 前缀

### 完整路径计算
- `routers.py`: `/api/users` + 路由路径
- `async_routers.py`: `/api` + 路由路径
- 其他路由文件: 路由定义时已包含完整前缀

## 已废弃的接口

### `/api/users/messages/send`
- **状态**: 已废弃（返回410错误）
- **原因**: 联系人聊天功能已移除
- **替代方案**: 使用任务聊天接口 `POST /api/messages/task/{task_id}/send`
- **影响**: 
  - `APIService+Endpoints.swift` 中的 `sendMessage` 方法
  - `CustomerServiceViewModel` 中的 `sendMessage` 方法
- **建议**: 需要确认客服消息的正确接口或使用任务聊天接口

## 最新修复

### 7. Profile相关端点 ✅
- **问题**: `sendEmailUpdateCode` 和 `sendPhoneUpdateCode` 使用了 `/api/profile/*`
- **修复**: 改为 `/api/users/profile/*` (router注册在/api/users前缀下)
- **已验证**: `/api/users/profile/me`, `/api/users/profile/avatar` 等端点都正确

### 8. 上传图片端点 ✅
- **验证**: `/api/upload/image` 正确 (main_router注册在/api前缀下)

## 待确认的问题

1. **客服消息接口**: `/api/users/messages/send` 已废弃，需要确认客服消息的正确接口
2. **消息对话接口**: `/api/messages/conversation/{user_id}` 是否正确用于客服消息

## 测试建议

1. 测试所有修复后的端点是否正常工作
2. 测试分页参数转换是否正确
3. 测试已废弃接口的错误处理
4. 确认客服消息功能的替代方案
