# 🚨 紧急修复：数据库表创建问题

## 问题

Test 环境的数据库表无法创建，因为 `Base.metadata.create_all()` 只会创建**已导入的**模型类对应的表。

## 修复内容

已修改 [backend/app/main.py](backend/app/main.py:1000-1017)，明确导入所有模型类：

```python
from app.models import (
    Base, User, Task, Review, Message, Notification, Conversation,
    University, FeaturedTaskExpert, AdminUser, CustomerService,
    TaskHistory, UserTaskInteraction, RecommendationFeedback,
    TaskDispute, RefundRequest, TaskCancelRequest, AdminRequest,
    AdminChatMessage, StaffNotification, SystemSettings,
    CustomerServiceChat, CustomerServiceMessage
)
```

## 立即部署

### 方式 1: Git 提交并推送（推荐）

```bash
git add backend/app/main.py backend/app/auto_fix_migrations.py
git commit -m "Fix: Explicitly import all models to ensure database tables are created"
git push
```

Railway 会自动部署，环境变量 `RESET_MIGRATIONS=true` 还在的话会自动触发修复。

### 方式 2: 直接在 Railway 重新部署

如果不想提交代码，可以直接：
1. Railway 会从最新的 GitHub commit 部署
2. 确保 `RESET_MIGRATIONS=true` 环境变量还在
3. 点击 **Deploy** 按钮

## 预期结果

修复后，日志应该显示：

```
已创建的表: ['users', 'tasks', 'universities', 'notifications', 'messages',
             'conversations', 'reviews', 'featured_task_experts', ...]
```

✅ 不再有 "relation does not exist" 错误！

## 修复后记得

删除 `RESET_MIGRATIONS` 环境变量，防止每次部署都重置数据库。
