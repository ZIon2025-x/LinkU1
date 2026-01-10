# 代码优化建议

## 1. 推送通知代码重复问题

### 问题
在多个文件中，推送通知的代码模式重复：
- 重复导入 `from app.push_notification_service import send_push_notification`
- 在异步函数中重复创建同步数据库会话 `SessionLocal()`
- 错误处理模式重复

### 优化方案
创建一个辅助函数来处理异步环境中的推送通知：

```python
# 在 push_notification_service.py 中添加
def send_push_notification_async_safe(
    async_db: AsyncSession,
    user_id: str,
    title: str,
    body: str,
    notification_type: str = "general",
    data: Optional[Dict[str, Any]] = None
) -> bool:
    """
    在异步环境中安全地发送推送通知
    自动处理同步/异步数据库会话转换
    """
    try:
        from app.database import SessionLocal
        sync_db = SessionLocal()
        try:
            return send_push_notification(
                db=sync_db,
                user_id=user_id,
                title=title,
                body=body,
                notification_type=notification_type,
                data=data
            )
        finally:
            sync_db.close()
    except Exception as e:
        logger.error(f"发送推送通知失败: {e}")
        return False
```

### 影响文件
- `backend/app/task_chat_routes.py` (10处)
- `backend/app/forum_routes.py` (2处)
- `backend/app/main.py` (4处)

## 2. 数据库提交性能优化

### 问题
在 `push_notification_service.py` 中，每个设备令牌推送后都调用 `db.commit()`，在批量推送时性能较差。

### 优化方案
```python
# 在 send_push_notification 中
success_count = 0
failed_tokens = []
for device_token in device_tokens:
    try:
        # ... 推送逻辑 ...
        if result:
            success_count += 1
            device_token.last_used_at = get_utc_time()
        else:
            failed_tokens.append(device_token)
    except Exception as e:
        logger.error(f"发送推送通知到设备失败: {e}")
        failed_tokens.append(device_token)
        continue

# 批量更新和提交
if success_count > 0 or failed_tokens:
    for token in failed_tokens:
        token.is_active = False
    db.commit()  # 只提交一次
```

### 影响文件
- `backend/app/push_notification_service.py`

## 3. 错误处理一致性

### 问题
错误处理不一致：
- 有些用 `logger.error`
- 有些用 `logger.warning`
- 有些没有记录错误

### 优化方案
统一错误处理标准：
- **关键错误**（影响主流程）：`logger.error`
- **非关键错误**（推送失败等）：`logger.warning`
- **调试信息**：`logger.debug`

### 影响文件
- `backend/app/crud.py`
- `backend/app/routers.py`
- `backend/app/task_chat_routes.py`

## 4. 导入优化

### 问题
在函数内部重复导入模块，影响性能。

### 优化方案
将导入移到文件顶部：
```python
# 在文件顶部
from app.push_notification_service import send_push_notification
from app.database import SessionLocal
```

### 影响文件
- `backend/app/crud.py`
- `backend/app/routers.py`
- `backend/app/task_chat_routes.py`

## 5. 批量推送通知优化

### 问题
在 `cancel_expired_tasks` 中，循环中逐个发送推送通知，性能较差。

### 优化方案
使用批量推送函数：
```python
# 收集所有需要通知的用户
users_to_notify = [task.poster_id] + participant_user_ids

# 批量发送推送通知
from app.push_notification_service import send_batch_push_notifications
send_batch_push_notifications(
    db=db,
    user_ids=users_to_notify,
    title="任务自动取消",
    body=f'任务"{task.title}"因超过截止日期已自动取消',
    notification_type="task_cancelled",
    data={"task_id": task.id}
)
```

### 影响文件
- `backend/app/crud.py::cancel_expired_tasks`

## 6. 代码结构优化

### 问题
`TaskDetailView.swift` 的 `body` 属性过于复杂，导致编译器类型检查超时。

### 优化方案
已经通过将 `showConfirmCompletionSuccess` 作为绑定传递解决，但可以进一步优化：
- 将更多的修饰符拆分成独立的计算属性
- 使用 `@ViewBuilder` 创建更小的子视图

### 影响文件
- `ios/link2ur/link2ur/Views/Tasks/TaskDetailView.swift`

## 7. 日志记录优化

### 问题
`push_notification_service.py` 第96行有语法错误：
```python
logger.info  # 缺少括号和参数
```

### 优化方案
修复为：
```python
logger.info(f"向用户 {user_id} 发送推送通知: {success_count}/{len(device_tokens)} 成功")
```

### 影响文件
- `backend/app/push_notification_service.py`

## 优先级

1. **高优先级**（影响功能）：
   - 修复 `push_notification_service.py` 第96行的语法错误
   - 优化数据库提交性能

2. **中优先级**（影响性能）：
   - 创建异步推送通知辅助函数
   - 批量推送通知优化

3. **低优先级**（代码质量）：
   - 统一错误处理
   - 优化导入位置
