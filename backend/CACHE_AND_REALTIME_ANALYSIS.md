# 缓存与实时性分析

## 问题：缓存是否影响未读信息实时显示？

### 答案：✅ **不会影响**

## 分析

### 1. 缓存的是什么？

**已缓存的API：**
- `fetchCurrentUser()` - 用户信息（5分钟缓存）
  - 用途：获取用户基本信息（姓名、头像等）
  - **不影响未读信息**

**未缓存的API：**
- `/api/users/messages/unread/count` - 未读消息数量
  - 用途：获取未读消息数量
  - **直接调用，无缓存**

### 2. 未读信息的更新机制

**实时更新方式：**

1. **WebSocket实时推送**（主要方式）
   ```typescript
   // 收到新消息时立即刷新
   WebSocketManager.subscribe((msg) => {
     if (msg.type === 'message_sent' || (msg.from && msg.content)) {
       setTimeout(() => {
         refreshUnreadCount(); // 立即调用API获取最新数量
       }, 500);
     }
   });
   ```

2. **定期轮询**（备用方式）
   ```typescript
   // 每10秒更新一次
   setInterval(() => {
     refreshUnreadCount(); // 直接调用API，无缓存
   }, 10000);
   ```

3. **页面可见性变化**
   ```typescript
   // 页面变为可见时更新
   document.addEventListener('visibilitychange', () => {
     refreshUnreadCount(); // 直接调用API，无缓存
   });
   ```

### 3. 代码验证

**`refreshUnreadCount()` 函数：**
```typescript
const refreshUnreadCount = useCallback(async () => {
  if (!user) {
    setUnreadCount(0);
    return;
  }
  
  try {
    // 直接调用API，没有使用cachedRequest
    const response = await api.get('/api/users/messages/unread/count');
    const count = response.data.unread_count || 0;
    setUnreadCount(count);
  } catch (error) {
    // 静默处理错误
  }
}, [user]);
```

**关键点：**
- ✅ 使用 `api.get()` 直接调用，**没有使用 `cachedRequest`**
- ✅ 每次调用都是实时请求后端
- ✅ 不会被缓存影响

## 缓存策略说明

### 已缓存的API（不影响实时性）

| API | 缓存时间 | 用途 | 影响 |
|-----|---------|------|------|
| `fetchCurrentUser()` | 5分钟 | 用户基本信息 | 不影响未读信息 |

### 未缓存的API（保证实时性）

| API | 缓存 | 用途 | 实时性 |
|-----|------|------|--------|
| `/api/users/messages/unread/count` | ❌ 无 | 未读消息数量 | ✅ 实时 |
| `/api/users/messages/unread` | ❌ 无 | 未读消息列表 | ✅ 实时 |
| `/api/users/notifications/unread/count` | ❌ 无 | 未读通知数量 | ✅ 实时 |

## 实时性保证机制

### 1. WebSocket实时推送

**工作流程：**
1. 用户A发送消息给用户B
2. 后端通过WebSocket推送消息给用户B
3. 用户B的 `UnreadMessageContext` 收到消息
4. 立即调用 `refreshUnreadCount()` 获取最新数量
5. 更新UI显示（红点）

**延迟：** 约 500ms（包括网络延迟和API调用）

### 2. 定期轮询

**工作流程：**
1. 每10秒自动调用 `refreshUnreadCount()`
2. 获取最新未读数量
3. 更新UI显示

**延迟：** 最多10秒（作为WebSocket的备用）

### 3. 页面可见性

**工作流程：**
1. 用户切换回页面
2. 立即调用 `refreshUnreadCount()`
3. 获取最新未读数量
4. 更新UI显示

**延迟：** 几乎实时

## 结论

### ✅ 未读信息不会被缓存影响

**原因：**
1. 未读信息API（`/api/users/messages/unread/count`）**没有使用缓存**
2. 每次调用都是实时请求后端
3. WebSocket实时推送确保及时更新
4. 定期轮询作为备用机制

### ✅ 缓存只影响用户信息

**缓存的内容：**
- 用户基本信息（姓名、头像、邮箱等）
- 这些信息变化不频繁，5分钟缓存是合理的

**不缓存的内容：**
- 未读消息数量
- 未读消息列表
- 未读通知数量
- 所有需要实时性的数据

## 建议

### 如果需要进一步优化

**选项1：给未读信息API添加短缓存（可选）**
```typescript
// 1-2秒的短缓存，减少频繁请求
export async function getUnreadCount() {
  return cachedRequest(
    '/api/users/messages/unread/count',
    async () => {
      const res = await api.get('/api/users/messages/unread/count');
      return res.data.unread_count;
    },
    2000 // 2秒缓存（很短，基本不影响实时性）
  );
}
```

**选项2：保持现状（推荐）**
- 当前实现已经很好
- WebSocket确保实时性
- 定期轮询作为备用
- 不需要额外优化

## 总结

✅ **未读信息（红点）会准时显示**

- 缓存只影响用户基本信息，不影响未读信息
- 未读信息API没有缓存，每次都是实时请求
- WebSocket实时推送 + 定期轮询确保及时更新
- 页面可见性变化时立即更新

**用户可以放心，汉堡菜单上的红点会准时显示！** 🎯

