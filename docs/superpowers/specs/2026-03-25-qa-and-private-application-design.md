# 问答功能 & 申请留言私有化设计

> 日期：2026-03-25
> 状态：已确认

## 背景

当前任务详情页和服务详情页的 `PublicApplicationsSection` / `_ServiceApplicationsSection` 会把申请人的留言（message）、议价金额、发布者回复展示给所有人。这存在两个问题：

1. 申请留言属于私密沟通，不应公开
2. 缺少一个公开的问答渠道，让潜在用户向发布者提问

## 需求总结

### 变更一：申请留言私有化

- 申请的 `message`（留言）和 `negotiated_price`（议价金额）仅对**发布者/服务者**和**申请人本人**可见
- 其他人看不到申请留言内容
- 后端公开 API 不再返回 `message` 和 `negotiated_price` 字段

### 变更二：新增公开问答功能

- 任何登录用户可以在任务/服务详情页向发布者/服务者提问
- 发布者/服务者可以对每个问题回复一次，不可追问
- 问答对所有人可见（含未登录用户）
- 提问者信息不公开展示（不显示头像和昵称），但后端记录 `asker_id`
- 提问者可以删除自己的问题（连带删除回复），不可编辑
- 每个用户可以提多个问题

## 数据模型

### 新建 `questions` 表

```sql
CREATE TABLE questions (
    id          SERIAL PRIMARY KEY,
    target_type VARCHAR(20) NOT NULL,   -- 'task' 或 'service'
    target_id   INTEGER NOT NULL,       -- 任务ID 或 服务ID
    asker_id    VARCHAR(8) NOT NULL REFERENCES users(id),
    content     TEXT NOT NULL,
    reply       TEXT,                    -- 发布者/服务者的回复，NULL 表示未回复
    reply_at    TIMESTAMP,              -- 回复时间
    created_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_questions_target ON questions(target_type, target_id);
CREATE INDEX idx_questions_asker ON questions(asker_id);
```

### SQLAlchemy Model

```python
class Question(Base):
    __tablename__ = "questions"

    id = Column(Integer, primary_key=True, index=True)
    target_type = Column(String(20), nullable=False)  # 'task' / 'service'
    target_id = Column(Integer, nullable=False)
    asker_id = Column(String(8), ForeignKey("users.id"), nullable=False)
    content = Column(Text, nullable=False)
    reply = Column(Text, nullable=True)
    reply_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=func.now(), nullable=False)
```

### Flutter Model: `TaskQuestion`

```dart
class TaskQuestion extends Equatable {
  final int id;
  final String targetType;    // 'task' / 'service'
  final int targetId;
  final String content;
  final String? reply;
  final String? replyAt;
  final String? createdAt;
  final bool isOwn;           // 后端根据当前用户计算，用于显示删除按钮
}
```

## API 设计

### 1. 获取问答列表

```
GET /questions?target_type={task|service}&target_id={id}
```

- **权限**：公开（不需要登录）
- **认证**：可选。使用 `get_optional_current_user` 依赖——有 token 时解析用户，无 token 时返回 `None`
- **返回**：问答列表，按 `created_at` 倒序，分页
- **分页参数**：`page`（默认 1）、`page_size`（默认 20，最大 50）
- **响应格式**：`{ "items": [...], "total": N, "page": 1, "page_size": 20 }`
- **响应字段**：`id`, `target_type`, `target_id`, `content`, `reply`, `reply_at`, `created_at`, `is_own`（当前用户是否为提问者）
- **`is_own` 逻辑**：有当前用户时比较 `asker_id`；未登录时全部返回 `false`
- **注意**：不返回 `asker_id`，不暴露提问者身份

### 2. 提问

```
POST /questions
Body: { "target_type": "task|service", "target_id": 123, "content": "..." }
```

- **权限**：登录用户，不能是发布者/服务者本人
- **校验**：`content` trim 后非空，长度 2~100 字符
- **返回**：创建的问题对象

### 3. 回复

```
POST /questions/{question_id}/reply
Body: { "content": "..." }
```

- **权限**：仅发布者/服务者
- **校验**：该问题尚未被回复（`reply IS NULL`），`content` trim 后非空，长度 2~100 字符
- **返回**：更新后的问题对象

### 4. 删除

```
DELETE /questions/{question_id}
```

- **权限**：仅提问者本人
- **行为**：硬删除整条记录（含回复）
- **返回**：204 No Content

## Flutter 前端改动

### 1. 新建文件

| 文件 | 说明 |
|------|------|
| `lib/data/models/task_question.dart` | `TaskQuestion` model |
| `lib/data/repositories/question_repository.dart` | 问答 API 调用 |
| `lib/core/widgets/qa_section.dart` | 共享的问答区 UI 组件 |

### 2. 共享 QASection 组件

取代任务详情的 `PublicApplicationsSection` 和服务详情的 `_ServiceApplicationsSection`。

**组件结构**：

```
QASection
├── 标题栏："问答 (N)"
├── 提问输入框（登录 + 非发布者时显示）
└── 问答列表
    └── QACard（每个问题）
        ├── 问题内容 + 时间
        ├── 删除按钮（仅提问者可见，is_own=true）
        └── 回复区域
            ├── 已回复 → 显示回复内容 + 时间
            └── 未回复 + 是发布者 → 显示回复输入框
```

**参数**：

```dart
class QASection extends StatefulWidget {
  const QASection({
    required this.targetType,    // 'task' / 'service'
    required this.targetId,
    required this.isOwner,       // 是否为发布者/服务者
    required this.isDark,
    required this.questions,
    required this.isLoading,
    required this.onAsk,         // 提问回调
    required this.onReply,       // 回复回调
    required this.onDelete,      // 删除回调
  });
}
```

### 3. TaskDetailBloc 改动

新增事件：
- `TaskDetailLoadQuestions` — 加载问答列表
- `TaskDetailAskQuestion` — 提问
- `TaskDetailReplyQuestion` — 回复
- `TaskDetailDeleteQuestion` — 删除

新增状态字段：
- `List<TaskQuestion> questions`
- `bool isLoadingQuestions`

### 4. TaskExpertBloc 改动

新增事件：
- `TaskExpertLoadServiceQuestions(int serviceId)` — 加载问答列表
- `TaskExpertAskServiceQuestion(int serviceId, String content)` — 提问
- `TaskExpertReplyServiceQuestion(int questionId, String content)` — 回复
- `TaskExpertDeleteServiceQuestion(int questionId)` — 删除

新增状态字段：
- `List<TaskQuestion> serviceQuestions`
- `bool isLoadingServiceQuestions`

### 5. 申请留言私有化

**任务详情页** (`task_detail_view.dart`)：
- 移除 `PublicApplicationsSection` 的引用
- 在原位置放置 `QASection`
- `QASection` 对所有用户可见（包括发布者），在所有任务状态下都显示（已完成的任务问答仍有参考价值，但提问输入框在非 open/chatting 状态隐藏）
- `ApplicationStatusCard`（申请人自己看的）保持不变

**服务详情页** (`service_detail_view.dart`)：
- 移除 `_ServiceApplicationsSection`
- 在原位置放置 `QASection`
- `QASection` 对所有用户可见（包括服务者）

**后端**：
- `_format_public_application_item()` 移除 `message` 和 `negotiated_price` 字段
- `_format_application_item()`（发布者/申请人视角）保持不变

### 6. API 端点常量

```dart
// api_endpoints.dart
static const String questions = '/questions';
static String questionReply(int id) => '/questions/$id/reply';
static String questionDelete(int id) => '/questions/$id';
```

### 7. 本地化

需新增的 l10n key（三语）：

| Key | EN | ZH | ZH_Hant |
|-----|----|----|---------|
| `qaTitle` | Q&A ({count}) | 问答 ({count}) | 問答 ({count}) |
| `qaAskPlaceholder` | Ask the poster a question... | 向发布者提问... | 向發布者提問... |
| `qaReplyPlaceholder` | Write your reply... | 写下你的回复... | 寫下你的回覆... |
| `qaAskButton` | Ask | 提问 | 提問 |
| `qaReplyButton` | Reply | 回复 | 回覆 |
| `qaDeleteConfirm` | Delete this question? | 确定删除这个问题？ | 確定刪除這個問題？ |
| `qaNoQuestions` | No questions yet | 暂无问答 | 暫無問答 |
| `qaOwnerReply` | Poster's reply | 发布者回复 | 發布者回覆 |
| `qaCannotAskOwn` | Cannot ask questions on your own post | 不能在自己的帖子里提问 | 不能在自己的帖子裡提問 |

## 权限矩阵

| 操作 | 未登录 | 登录用户 | 发布者/服务者 | 申请人 |
|------|--------|----------|---------------|--------|
| 查看问答 | O | O | O | O |
| 提问 | X | O | X（不能在自己的帖子提问） | O |
| 回复问题 | X | X | O（每题限一次） | X |
| 删除问题 | X | 仅自己的 | X | 仅自己的 |
| 查看申请留言 | X | X | O（所有申请） | O（仅自己的） |

## 后端路由文件

新端点放入 `app/routes/` 下新建的 `questions.py`，在 `app/routes/__init__.py` 中注册 router，不往 `async_routers.py` 追加。

## 不做的事

- 不做问题编辑功能
- 不做追问功能（严格一问一答）
- 不做问答点赞/排序
- 不做匿名提问开关（统一不显示提问者信息）
- 问答分页：每页 20 条，前端做"加载更多"按钮（非无限滚动）
- 不做问答举报/审核（后续可复用论坛举报机制）
- 提问时通知发布者/服务者（"有人对你的XX提了一个问题"）
- 回复时通知提问者（"你的问题收到了回复"）
- 通知类型：`question_asked`、`question_replied`，复用现有通知系统
