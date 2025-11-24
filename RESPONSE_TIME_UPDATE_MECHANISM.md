# Response Time 更新机制说明

## 📋 概述

`response_time`（响应时间）用于展示特征任务达人（FeaturedTaskExpert）的平均消息响应速度，帮助用户了解达人的响应效率。

## 🔄 更新流程

### 1. 数据来源

响应时间基于以下数据计算：
- **消息表（Message）**：存储用户接收到的消息
- **消息已读表（MessageRead）**：记录消息的已读时间

### 2. 计算逻辑

#### 步骤 1：查询已读消息
```python
read_messages = (
    db.query(Message, MessageRead)
    .join(MessageRead, MessageRead.message_id == Message.id)
    .filter(
        Message.receiver_id == user_id,  # 用户接收到的消息
        Message.sender_id != user_id,     # 排除自己发送的消息
        MessageRead.user_id == user_id    # 用户已读的消息
    )
    .all()
)
```

#### 步骤 2：计算每条消息的响应时间
```python
for message, message_read in read_messages:
    if message.created_at and message_read.read_at:
        # 响应时间 = 已读时间 - 消息创建时间（秒）
        response_time = (message_read.read_at - message.created_at).total_seconds()
        if response_time > 0:  # 只计算有效的响应时间
            response_times.append(response_time)
```

#### 步骤 3：计算平均响应时间
```python
if response_times:
    avg_response_time_seconds = sum(response_times) / len(response_times)
```

#### 步骤 4：格式化为文本
响应时间会被格式化为用户友好的文本：

| 时间范围 | 中文格式 | 英文格式 |
|---------|---------|---------|
| < 1小时 | "X分钟内" | "Within X minutes" |
| 1小时 - 1天 | "X小时内" | "Within X hours" |
| ≥ 1天 | "X天内" | "Within X days" |

示例：
- 30分钟 → "30分钟内" / "Within 30 minutes"
- 2小时 → "2小时内" / "Within 2 hours"
- 3天 → "3天内" / "Within 3 days"

### 3. 更新到数据库

计算完成后，更新到 `FeaturedTaskExpert` 表：

```python
featured_expert = db.query(FeaturedTaskExpert).filter(
    FeaturedTaskExpert.id == user_id
).first()

if featured_expert:
    featured_expert.response_time = response_time_zh      # 中文格式
    featured_expert.response_time_en = response_time_en   # 英文格式
    db.commit()
```

## ⏰ 更新频率

### 定时任务
- **执行时间**：每天凌晨3点
- **任务名称**：`update-featured-task-experts-response-time`
- **Celery 任务**：`app.celery_tasks.update_featured_task_experts_response_time_task`

### 更新范围
- 只更新 **特征任务达人（FeaturedTaskExpert）** 的响应时间
- 不更新普通任务达人（TaskExpert）的响应时间
- 不更新 bio（简介），bio 由用户或管理员手动填写

## 📊 数据统计

除了响应时间，任务还会更新以下统计字段：

1. **avg_rating**：平均评分
2. **completed_tasks**：已完成任务数
3. **total_tasks**：总任务数
4. **completion_rate**：完成率
5. **success_rate**：成功率

## 🔍 关键点

### 1. 响应时间定义
- **响应时间** = 用户**已读消息的时间** - **消息创建的时间**
- 只计算用户**接收到的消息**（`receiver_id == user_id`）
- 排除用户**自己发送的消息**（`sender_id != user_id`）

### 2. 数据要求
- 消息必须有 `created_at`（创建时间）
- 消息必须有 `read_at`（已读时间）
- 响应时间必须 > 0（排除异常数据）

### 3. 更新条件
- 只更新 `FeaturedTaskExpert` 表中存在的用户
- 如果用户不是特征任务达人，不会更新

## 🛠️ 手动触发

如果需要手动更新某个用户的响应时间：

```python
from app.crud import update_task_expert_bio
from app.database import SessionLocal

db = SessionLocal()
try:
    update_task_expert_bio(db, user_id="12345678")
finally:
    db.close()
```

## 📝 相关代码文件

- **计算逻辑**：`backend/app/crud.py` - `update_task_expert_bio()`
- **批量更新**：`backend/app/crud.py` - `update_all_featured_task_experts_response_time()`
- **Celery 任务**：`backend/app/celery_tasks.py` - `update_featured_task_experts_response_time_task()`
- **任务配置**：`backend/app/celery_app.py` - `beat_schedule`

## ⚠️ 注意事项

1. **数据依赖**：响应时间计算依赖于 `MessageRead` 表的数据，如果消息未标记为已读，不会计入统计
2. **性能考虑**：每天凌晨3点执行，避免影响业务高峰期性能
3. **错误处理**：如果某个用户更新失败，会记录错误日志但继续处理其他用户
4. **重试机制**：任务失败会自动重试（最多2次，延迟5分钟）

## 🔄 更新示例

假设用户 `12345678` 是特征任务达人：

1. **消息记录**：
   - 消息1：创建时间 `2025-01-01 10:00:00`，已读时间 `2025-01-01 10:15:00` → 响应时间 900秒（15分钟）
   - 消息2：创建时间 `2025-01-01 11:00:00`，已读时间 `2025-01-01 11:30:00` → 响应时间 1800秒（30分钟）

2. **计算平均**：
   - 平均响应时间 = (900 + 1800) / 2 = 1350秒（22.5分钟）

3. **格式化**：
   - `response_time` = "23分钟内"
   - `response_time_en` = "Within 23 minutes"

4. **更新到数据库**：
   ```sql
   UPDATE featured_task_experts 
   SET response_time = '23分钟内',
       response_time_en = 'Within 23 minutes'
   WHERE id = '12345678';
   ```

