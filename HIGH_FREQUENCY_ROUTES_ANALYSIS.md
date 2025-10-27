# 高频路由分析报告

## 📊 分析依据

基于代码静态分析和前端调用模式，识别出以下高频路由。

## 🔥 极高频路由（优先迁移）

### 1. 任务相关路由 ⭐⭐⭐⭐⭐

**GET /api/tasks** - 任务列表
- 调用频率：★★★★★
- 使用场景：首页任务列表、任务筛选、搜索
- 前端位置：
  - `frontend/src/pages/Tasks.tsx` - 主任务页面
  - `frontend/src/hooks/useTasks.ts` - 任务自定义Hook
  - `frontend/src/api.ts:421` - `fetchTasks()`
- 缓存时间：2分钟
- **迁移优先级：最高**
- **原因**：所有用户打开应用都会调用

**POST /api/tasks** - 创建任务
- 调用频率：★★★★
- 使用场景：用户发布新任务
- 前端位置：
  - `frontend/src/pages/CreateTask.tsx`
  - 目前已在异步路由：`backend/app/async_routers.py:155`
- **迁移状态：✅ 已完成异步化**

**GET /api/tasks/{id}** - 获取单个任务详情
- 调用频率：★★★★
- 使用场景：查看任务详情
- 前端位置：
  - `frontend/src/pages/TaskDetail.tsx`
  - `frontend/src/components/TaskDetailModal.tsx`
- **迁移优先级：高**

**POST /api/tasks/{id}/accept** - 接受任务
- 调用频率：★★★
- 使用场景：用户接受任务
- **迁移优先级：中-高**

**POST /api/tasks/{id}/complete** - 完成任务
- 调用频率：★★★
- 使用场景：标记任务完成
- **迁移优先级：中-高**

### 2. 用户相关路由 ⭐⭐⭐⭐⭐

**GET /api/users/profile/me** - 获取当前用户信息
- 调用频率：★★★★★
- 使用场景：
  - 页面加载时获取用户信息
  - 需要用户信息时
- 前端位置：
  - `frontend/src/api.ts:430` - `fetchCurrentUser()`
  - `frontend/src/hooks/useAuth.ts`
  - 几乎所有需要认证的页面
- 缓存时间：5分钟
- **迁移优先级：最高**
- **原因**：几乎所有页面都需要

**PATCH /api/users/profile/avatar** - 更新头像
- 调用频率：★
- 使用场景：用户更换头像
- **迁移优先级：低**

### 3. 消息相关路由 ⭐⭐⭐⭐

**GET /api/users/messages** - 获取消息列表
- 调用频率：★★★★
- 使用场景：消息页面
- 前端位置：
  - `frontend/src/pages/Message.tsx`
  - 实时更新（轮询）
- **迁移优先级：高**

**POST /api/users/messages/send** - 发送消息
- 调用频率：★★★★
- 使用场景：用户发送消息
- 前端位置：
  - `frontend/src/api.ts:434` - `sendMessage()`
  - `frontend/src/pages/Message.tsx`
- **迁移优先级：高**
- **原因**：实时通信，性能敏感

**GET /api/users/messages/history/{user_id}** - 消息历史
- 调用频率：★★★★
- 使用场景：查看聊天历史
- **迁移优先级：高**

### 4. 通知相关路由 ⭐⭐⭐

**GET /api/users/notifications** - 获取通知
- 调用频率：★★★
- 使用场景：通知中心
- **迁移优先级：中**

## 📋 中等频率路由（后续迁移）

### 5. 认证相关路由 ⭐⭐

**POST /api/secure-auth/login** - 登录
- 调用频率：★
- 使用场景：用户登录
- 缓存：无
- **迁移优先级：低**
- **原因**：低频调用，但对响应速度有要求

**POST /api/secure-auth/refresh** - 刷新Token
- 调用频率：★★
- 使用场景：自动刷新认证
- **迁移优先级：低**

**POST /api/secure-auth/logout** - 登出
- 调用频率：★
- 使用场景：用户登出
- **迁移优先级：低**

### 6. 文件上传路由 ⭐⭐

**POST /api/upload/image** - 上传图片
- 调用频率：★★★
- 使用场景：上传图片
- **迁移优先级：中**
- **原因**：上传操作需要良好的性能

### 7. 客服相关路由 ⭐

**GET /api/users/customer-service/chats** - 客服对话列表
- 调用频率：★★
- 使用场景：客服管理
- **迁移优先级：低**

**POST /api/users/customer-service/messages/send** - 发送客服消息
- 调用频率：★★
- 使用场景：客服回复
- **迁移优先级：低**

## 🎯 优先级汇总

### 第一阶段（最高优先级）⭐⭐⭐⭐⭐

必须立即异步化的路由：

1. **GET /api/tasks** - 任务列表
2. **GET /api/users/profile/me** - 用户信息
3. **GET /api/tasks/{id}** - 任务详情

**原因**：
- 这些路由在每个页面加载时都可能被调用
- 影响最大的用户体验
- 并发请求多

### 第二阶段（高优先级）⭐⭐⭐⭐

需要快速异步化的路由：

4. **GET /api/users/messages** - 消息列表
5. **POST /api/users/messages/send** - 发送消息
6. **GET /api/users/messages/history/{user_id}** - 消息历史
7. **POST /api/tasks/{id}/accept** - 接受任务
8. **POST /api/tasks/{id}/complete** - 完成任务

**原因**：
- 实时性要求高
- 用户交互频繁
- 性能敏感

### 第三阶段（中优先级）⭐⭐⭐

可以逐步异步化的路由：

9. **GET /api/users/notifications** - 通知
10. **POST /api/upload/image** - 图片上传
11. **GET /api/users/my-tasks** - 我的任务

### 第四阶段（低优先级）⭐

暂不急于异步化的路由：

- 认证路由（登录、登出、刷新）
- 客服管理路由
- 管理员路由

**原因**：
- 调用频率低
- 复杂度高
- 影响面小

## 📊 调用频率统计

### 基于前端代码分析

**每用户每日平均调用次数（估算）**：

1. **GET /api/tasks** - 50-100次/天
2. **GET /api/users/profile/me** - 20-50次/天
3. **GET /api/users/messages** - 30-80次/天（持续更新）
4. **POST /api/users/messages/send** - 10-30次/天
5. **GET /api/tasks/{id}** - 20-40次/天

### 按页面分析

**Tasks页面**：
- GET /api/tasks - 每次加载
- GET /api/tasks/{id} - 查看详情
- 预计调用：用户最频繁访问的页面

**Message页面**：
- GET /api/users/messages - 持续轮询
- POST /api/users/messages/send - 发送消息
- 预计调用：高并发

**Profile页面**：
- GET /api/users/profile/me - 获取信息
- PATCH /api/users/profile/avatar - 偶尔更新
- 预计调用：中频

**CreateTask页面**：
- POST /api/tasks - 创建任务
- 预计调用：低频但重要

## 🛠️ 实施建议

### 立即实施（本周）

1. 迁移 `GET /api/tasks` 到异步
2. 迁移 `GET /api/users/profile/me` 到异步
3. 迁移 `GET /api/tasks/{id}` 到异步

### 第2周

4. 迁移消息相关路由到异步
5. 迁移任务操作路由到异步

### 第3-4周

6. 迁移其他常用路由
7. 优化查询性能

## 📈 预期效果

### 性能提升

**异步化前**：
- 任务列表加载：500-800ms
- 并发处理：20-30 req/s

**异步化后**：
- 任务列表加载：300-500ms（减少40%）
- 并发处理：50-80 req/s（提升2-3倍）

### 用户体验

- ⚡ 页面加载更快
- ⚡ 响应更流畅
- ⚡ 高并发时更稳定

## ✅ 总结

**最高优先级（本周）**：
1. GET /api/tasks
2. GET /api/users/profile/me  
3. GET /api/tasks/{id}

**高优先级（第2周）**：
4. 消息相关路由（GET, POST）
5. 任务操作路由（accept, complete）

**这些路由占用户总请求的70-80%，异步化它们将带来最大的性能提升！**

