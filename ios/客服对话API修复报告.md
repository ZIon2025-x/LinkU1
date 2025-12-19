# 客服对话API修复报告

## 问题分析

根据web前端的实现，iOS端的客服对话功能使用了错误的API端点。原实现使用了已废弃的 `/api/users/messages/send` 接口。

## Web前端实现参考

Web前端使用以下API端点：

1. **分配/获取客服会话**: `POST /api/users/user/customer-service/assign`
2. **获取会话列表**: `GET /api/users/user/customer-service/chats`
3. **获取消息**: `GET /api/users/user/customer-service/chats/{chat_id}/messages`
4. **发送消息**: `POST /api/users/user/customer-service/chats/{chat_id}/messages` (body: `{ content: string }`)
5. **结束对话**: `POST /api/users/user/customer-service/chats/{chat_id}/end`
6. **评分**: `POST /api/users/user/customer-service/chats/{chat_id}/rate` (body: `{ rating: number, comment?: string }`)
7. **获取排队状态**: `GET /api/users/user/customer-service/queue-status`

## 修复内容

### 1. 新增数据模型 ✅

创建了 `Models/CustomerService.swift`，包含：
- `CustomerServiceAssignResponse`: 客服分配响应
- `CustomerServiceInfo`: 客服信息
- `CustomerServiceChat`: 客服会话
- `CustomerServiceMessage`: 客服消息
- `CustomerServiceQueueStatus`: 排队状态
- `SystemMessage`: 系统消息

### 2. 新增API端点 ✅

在 `APIService+Endpoints.swift` 中新增：
- `assignCustomerService()`: 分配或获取客服会话
- `getCustomerServiceChats()`: 获取会话列表
- `getCustomerServiceMessages(chatId:)`: 获取消息
- `sendCustomerServiceMessage(chatId:content:)`: 发送消息
- `endCustomerServiceChat(chatId:)`: 结束对话
- `rateCustomerService(chatId:rating:comment:)`: 评分
- `getCustomerServiceQueueStatus()`: 获取排队状态

### 3. 更新ViewModel ✅

重写了 `CustomerServiceViewModel.swift`：
- 使用新的API端点
- 实现连接客服流程
- 支持排队状态显示
- 支持消息发送和接收
- 支持结束对话和评分

### 4. 更新View ✅

更新了 `CustomerServiceView.swift`：
- 实现连接客服界面
- 显示排队状态
- 显示聊天界面
- 支持消息发送
- 支持结束对话

## API端点路径说明

所有客服对话API都在 `routers.py` 中定义，router注册在 `/api/users` 前缀下，所以完整路径是：
- `/api/users/user/customer-service/assign`
- `/api/users/user/customer-service/chats`
- `/api/users/user/customer-service/chats/{chat_id}/messages`
- `/api/users/user/customer-service/chats/{chat_id}/end`
- `/api/users/user/customer-service/chats/{chat_id}/rate`
- `/api/users/user/customer-service/queue-status`

## 使用流程

1. **连接客服**: 调用 `assignCustomerService()` 分配或获取会话
2. **加载消息**: 连接成功后自动加载消息，或手动调用 `loadMessages(chatId:)`
3. **发送消息**: 使用 `sendMessage(content:completion:)` 发送消息
4. **结束对话**: 使用 `endChat(completion:)` 结束对话
5. **评分**: 使用 `rateService(rating:comment:completion:)` 对客服进行评分

## 注意事项

1. **会话管理**: 如果用户已有未结束的对话，`assignCustomerService()` 会返回现有对话
2. **排队机制**: 如果没有可用客服，用户会被加入排队队列
3. **消息类型**: 支持文本、任务卡片、图片、文件等多种消息类型
4. **WebSocket**: 客服对话也支持WebSocket实时通信（需要后续实现）

## 测试建议

1. 测试连接客服流程
2. 测试消息发送和接收
3. 测试排队状态显示
4. 测试结束对话功能
5. 测试评分功能
6. 测试错误处理（无可用客服、对话已结束等）
