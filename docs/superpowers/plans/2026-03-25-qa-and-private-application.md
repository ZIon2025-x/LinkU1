# 问答功能 & 申请留言私有化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add public Q&A to task/service detail pages; make application messages private to poster+applicant only.

**Architecture:** New `questions` table with polymorphic `target_type`/`target_id`. Backend endpoints in `app/routes/questions.py`. Flutter shared `QASection` widget used by both TaskDetailBloc and TaskExpertBloc. Public application endpoints stripped of `message`/`negotiated_price`.

**Tech Stack:** Python FastAPI + SQLAlchemy (backend), Flutter BLoC (frontend), PostgreSQL

**Spec:** `docs/superpowers/specs/2026-03-25-qa-and-private-application-design.md`

---

## File Map

### Backend — New Files
| File | Responsibility |
|------|---------------|
| `backend/migrations/134_create_questions_table.sql` | Database migration |
| `backend/app/routes/questions.py` | Q&A API endpoints (GET, POST, POST reply, DELETE) |

### Backend — Modified Files
| File | Change |
|------|--------|
| `backend/app/models.py` | Add `Question` SQLAlchemy model |
| `backend/app/main.py` | Register questions router |
| `backend/app/async_routers.py` | Remove `message`/`negotiated_price` from `_format_public_application_item()` |
| `backend/app/task_expert_routes.py` | Conditionally include `application_message`/`negotiated_price` in service applications |

### Flutter — New Files
| File | Responsibility |
|------|---------------|
| `link2ur/lib/data/models/task_question.dart` | `TaskQuestion` model |
| `link2ur/lib/data/repositories/question_repository.dart` | Q&A API calls |
| `link2ur/lib/core/widgets/qa_section.dart` | Shared Q&A UI component |

### Flutter — Modified Files
| File | Change |
|------|--------|
| `link2ur/lib/core/constants/api_endpoints.dart` | Add question endpoints |
| `link2ur/lib/app_providers.dart` | Register `QuestionRepository` |
| `link2ur/lib/features/tasks/bloc/task_detail_bloc.dart` | Add Q&A events, state fields, handlers |
| `link2ur/lib/features/tasks/views/task_detail_view.dart` | Replace `PublicApplicationsSection` with `QASection` |
| `link2ur/lib/features/tasks/views/task_detail_components.dart` | Remove `PublicApplicationsSection` class (or keep unused) |
| `link2ur/lib/features/task_expert/bloc/task_expert_bloc.dart` | Add Q&A events, state fields, handlers |
| `link2ur/lib/features/task_expert/views/service_detail_view.dart` | Replace `_ServiceApplicationsSection` with `QASection` |
| `link2ur/lib/l10n/app_en.arb` | Add Q&A l10n keys |
| `link2ur/lib/l10n/app_zh.arb` | Add Q&A l10n keys |
| `link2ur/lib/l10n/app_zh_Hant.arb` | Add Q&A l10n keys |

---

## Task 1: Database Migration & Model

**Files:**
- Create: `backend/migrations/134_create_questions_table.sql`
- Modify: `backend/app/models.py`

- [ ] **Step 1: Create migration SQL**

Create `backend/migrations/134_create_questions_table.sql`:

```sql
CREATE TABLE IF NOT EXISTS questions (
    id SERIAL PRIMARY KEY,
    target_type VARCHAR(20) NOT NULL,
    target_id INTEGER NOT NULL,
    asker_id VARCHAR(8) NOT NULL REFERENCES users(id),
    content TEXT NOT NULL,
    reply TEXT,
    reply_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_questions_target ON questions(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_questions_asker ON questions(asker_id);
```

- [ ] **Step 2: Add SQLAlchemy model**

Add to `backend/app/models.py` after the existing `Notification` class:

```python
class Question(Base):
    __tablename__ = "questions"

    id = Column(Integer, primary_key=True, index=True)
    target_type = Column(String(20), nullable=False)  # 'task' / 'service'
    target_id = Column(Integer, nullable=False)
    asker_id = Column(String(8), ForeignKey("users.id"), nullable=False)
    content = Column(Text, nullable=False)
    reply = Column(Text, nullable=True)
    reply_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=func.now(), nullable=False)
```

- [ ] **Step 3: Run migration**

```bash
cd backend && python run_migrations.py --migration 134_create_questions_table
```

- [ ] **Step 4: Commit**

```bash
git add backend/migrations/134_create_questions_table.sql backend/app/models.py
git commit -m "feat: add questions table for public Q&A on tasks/services"
```

---

## Task 2: Backend Q&A API Endpoints

**Files:**
- Create: `backend/app/routes/questions.py`
- Modify: `backend/app/main.py`

- [ ] **Step 1: Create `backend/app/routes/questions.py`**

```python
"""Q&A endpoints for tasks and services."""
import logging
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import select, func, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.database import get_async_db_dependency
from app.deps import get_current_user_secure_async_csrf
from app.async_routers import get_current_user_optional
from app.async_crud import AsyncNotificationCRUD

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/questions", tags=["questions"])


class AskQuestionRequest(BaseModel):
    target_type: str = Field(..., pattern="^(task|service)$")
    target_id: int
    content: str = Field(..., min_length=2, max_length=100)


class ReplyQuestionRequest(BaseModel):
    content: str = Field(..., min_length=2, max_length=100)


def _format_question(q: models.Question, current_user_id: Optional[str] = None) -> dict:
    return {
        "id": q.id,
        "target_type": q.target_type,
        "target_id": q.target_id,
        "content": q.content,
        "reply": q.reply,
        "reply_at": q.reply_at.isoformat() if q.reply_at else None,
        "created_at": q.created_at.isoformat() if q.created_at else None,
        "is_own": (current_user_id is not None and q.asker_id == current_user_id),
    }


async def _get_target_owner_id(
    db: AsyncSession, target_type: str, target_id: int
) -> Optional[str]:
    """Get the owner user_id of a task or service."""
    if target_type == "task":
        result = await db.execute(
            select(models.Task.user_id).where(models.Task.id == target_id)
        )
        row = result.scalar_one_or_none()
        return str(row) if row else None
    elif target_type == "service":
        # TaskExpertService — check user_id first (personal service), then expert_id
        result = await db.execute(
            select(models.TaskExpertService).where(models.TaskExpertService.id == target_id)
        )
        service = result.scalar_one_or_none()
        if not service:
            return None
        if service.user_id:
            return str(service.user_id)
        return str(service.expert_id) if service.expert_id else None
    return None


@router.get("")
async def list_questions(
    target_type: str = Query(..., pattern="^(task|service)$"),
    target_id: int = Query(...),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取问答列表（公开）"""
    current_user_id = current_user.id if current_user else None
    offset = (page - 1) * page_size

    # Count total
    count_q = select(func.count(models.Question.id)).where(
        models.Question.target_type == target_type,
        models.Question.target_id == target_id,
    )
    total = (await db.execute(count_q)).scalar() or 0

    # Fetch page
    q = (
        select(models.Question)
        .where(
            models.Question.target_type == target_type,
            models.Question.target_id == target_id,
        )
        .order_by(models.Question.created_at.desc())
        .offset(offset)
        .limit(page_size)
    )
    result = await db.execute(q)
    questions = result.scalars().all()

    return {
        "items": [_format_question(q, current_user_id) for q in questions],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


@router.post("")
async def ask_question(
    body: AskQuestionRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """提问"""
    owner_id = await _get_target_owner_id(db, body.target_type, body.target_id)
    if not owner_id:
        raise HTTPException(status_code=404, detail="Target not found")
    if current_user.id == owner_id:
        raise HTTPException(status_code=403, detail="Cannot ask on your own post")

    content = body.content.strip()
    if len(content) < 2:
        raise HTTPException(status_code=400, detail="Content too short")

    question = models.Question(
        target_type=body.target_type,
        target_id=body.target_id,
        asker_id=current_user.id,
        content=content,
    )
    db.add(question)
    await db.commit()
    await db.refresh(question)

    # Notify the owner
    try:
        target_label = "任务" if body.target_type == "task" else "服务"
        target_label_en = "task" if body.target_type == "task" else "service"
        await AsyncNotificationCRUD.create_notification(
            db=db,
            user_id=owner_id,
            notification_type="question_asked",
            title=f"有人对你的{target_label}提了一个问题",
            content=content[:50],
            related_id=str(question.id),
            title_en=f"Someone asked a question on your {target_label_en}",
            content_en=content[:50],
            related_type="question_id",
        )
    except Exception as e:
        logger.warning(f"Failed to create question notification: {e}")

    return _format_question(question, current_user.id)


@router.post("/{question_id}/reply")
async def reply_question(
    question_id: int,
    body: ReplyQuestionRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """回复问题（仅发布者/服务者）"""
    result = await db.execute(
        select(models.Question).where(models.Question.id == question_id)
    )
    question = result.scalar_one_or_none()
    if not question:
        raise HTTPException(status_code=404, detail="Question not found")

    if question.reply is not None:
        raise HTTPException(status_code=400, detail="Already replied")

    owner_id = await _get_target_owner_id(db, question.target_type, question.target_id)
    if not owner_id or current_user.id != owner_id:
        raise HTTPException(status_code=403, detail="Only the owner can reply")

    content = body.content.strip()
    if len(content) < 2:
        raise HTTPException(status_code=400, detail="Content too short")

    question.reply = content
    question.reply_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(question)

    # Notify the asker
    try:
        await AsyncNotificationCRUD.create_notification(
            db=db,
            user_id=question.asker_id,
            notification_type="question_replied",
            title="你的问题收到了回复",
            content=content[:50],
            related_id=str(question.id),
            title_en="Your question received a reply",
            content_en=content[:50],
            related_type="question_id",
        )
    except Exception as e:
        logger.warning(f"Failed to create reply notification: {e}")

    return _format_question(question, current_user.id)


@router.delete("/{question_id}", status_code=204)
async def delete_question(
    question_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """删除问题（仅提问者）"""
    result = await db.execute(
        select(models.Question).where(models.Question.id == question_id)
    )
    question = result.scalar_one_or_none()
    if not question:
        raise HTTPException(status_code=404, detail="Question not found")

    if question.asker_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the asker can delete")

    await db.execute(
        delete(models.Question).where(models.Question.id == question_id)
    )
    await db.commit()
```

- [ ] **Step 2: Register router in `backend/app/main.py`**

Find the section where routers are included (e.g. `app.include_router(async_router)`) and add:

```python
from app.routes.questions import router as questions_router
app.include_router(questions_router)
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/routes/questions.py backend/app/main.py
git commit -m "feat: add Q&A API endpoints (list, ask, reply, delete)"
```

---

## Task 3: Backend — Privatize Application Messages

**Files:**
- Modify: `backend/app/async_routers.py`

- [ ] **Step 1: Remove `message` and `negotiated_price` from `_format_public_application_item`**

In `backend/app/async_routers.py` around line 1183, find `_format_public_application_item` and remove the `message` and `negotiated_price` fields from the returned dict. Keep everything else.

Before:
```python
    return {
        "id": app.id,
        "task_id": app.task_id,
        "applicant_name": user.name if user else None,
        "applicant_avatar": user.avatar if user and hasattr(user, 'avatar') else None,
        "applicant_user_level": getattr(user, 'user_level', None) if user else None,
        "message": app.message,
        "negotiated_price": negotiated_price_value,
        "currency": app.currency or "GBP",
        ...
    }
```

After:
```python
    return {
        "id": app.id,
        "task_id": app.task_id,
        "applicant_name": user.name if user else None,
        "applicant_avatar": user.avatar if user and hasattr(user, 'avatar') else None,
        "applicant_user_level": getattr(user, 'user_level', None) if user else None,
        "currency": app.currency or "GBP",
        ...
    }
```

Remove the entire `negotiated_price_value` calculation block above the return statement too, since it's no longer used.

- [ ] **Step 2: Conditionally include in service applications endpoint**

In `backend/app/task_expert_routes.py`, find the service applications endpoint (`GET /services/{service_id}/applications`). The endpoint builds application dicts inline. Make `application_message` and `negotiated_price` conditional — only include them when the viewer is the service owner or the applicant themselves:

```python
# Only include private fields for owner or the applicant
if is_owner or (current_user and str(app.applicant_id) == current_user.id):
    item["application_message"] = app.application_message
    item["negotiated_price"] = float(app.negotiated_price) if app.negotiated_price else None
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/async_routers.py backend/app/task_expert_routes.py
git commit -m "feat: privatize application messages — remove from public API responses"
```

---

## Task 4: Flutter — TaskQuestion Model & QuestionRepository

**Files:**
- Create: `link2ur/lib/data/models/task_question.dart`
- Create: `link2ur/lib/data/repositories/question_repository.dart`
- Modify: `link2ur/lib/core/constants/api_endpoints.dart`

- [ ] **Step 1: Create `TaskQuestion` model**

Create `link2ur/lib/data/models/task_question.dart`:

```dart
import 'package:equatable/equatable.dart';

class TaskQuestion extends Equatable {
  const TaskQuestion({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.content,
    this.reply,
    this.replyAt,
    this.createdAt,
    this.isOwn = false,
  });

  final int id;
  final String targetType;
  final int targetId;
  final String content;
  final String? reply;
  final String? replyAt;
  final String? createdAt;
  final bool isOwn;

  bool get hasReply => reply != null && reply!.isNotEmpty;

  factory TaskQuestion.fromJson(Map<String, dynamic> json) {
    return TaskQuestion(
      id: json['id'] as int,
      targetType: json['target_type'] as String? ?? '',
      targetId: json['target_id'] as int? ?? 0,
      content: json['content'] as String? ?? '',
      reply: json['reply'] as String?,
      replyAt: json['reply_at'] as String?,
      createdAt: json['created_at'] as String?,
      isOwn: json['is_own'] as bool? ?? false,
    );
  }

  TaskQuestion copyWith({
    int? id,
    String? targetType,
    int? targetId,
    String? content,
    String? reply,
    String? replyAt,
    String? createdAt,
    bool? isOwn,
  }) {
    return TaskQuestion(
      id: id ?? this.id,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      content: content ?? this.content,
      reply: reply ?? this.reply,
      replyAt: replyAt ?? this.replyAt,
      createdAt: createdAt ?? this.createdAt,
      isOwn: isOwn ?? this.isOwn,
    );
  }

  @override
  List<Object?> get props => [id, targetType, targetId, content, reply, replyAt, createdAt, isOwn];
}
```

- [ ] **Step 2: Add API endpoints**

Add to `link2ur/lib/core/constants/api_endpoints.dart` in a new `// Questions` section:

```dart
// Questions (Q&A)
static const String questions = '/api/questions';
static String questionReply(int id) => '/api/questions/$id/reply';
static String questionDelete(int id) => '/api/questions/$id';
```

- [ ] **Step 3: Create `QuestionRepository`**

Create `link2ur/lib/data/repositories/question_repository.dart`:

```dart
import '../models/task_question.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

class QuestionRepository {
  QuestionRepository({required ApiService apiService}) : _apiService = apiService;

  final ApiService _apiService;

  /// 获取问答列表
  Future<Map<String, dynamic>> getQuestions({
    required String targetType,
    required int targetId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get(
      ApiEndpoints.questions,
      queryParameters: {
        'target_type': targetType,
        'target_id': targetId,
        'page': page,
        'page_size': pageSize,
      },
    );
    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      final items = (data['items'] as List?)
              ?.map((e) => TaskQuestion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      return {
        'items': items,
        'total': data['total'] as int? ?? 0,
        'page': data['page'] as int? ?? 1,
        'page_size': data['page_size'] as int? ?? 20,
      };
    }
    throw Exception(response.message ?? 'Failed to load questions');
  }

  /// 提问
  Future<TaskQuestion> askQuestion({
    required String targetType,
    required int targetId,
    required String content,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.questions,
      data: {
        'target_type': targetType,
        'target_id': targetId,
        'content': content,
      },
    );
    if (response.isSuccess && response.data != null) {
      return TaskQuestion.fromJson(response.data!);
    }
    throw Exception(response.message ?? 'Failed to ask question');
  }

  /// 回复问题
  Future<TaskQuestion> replyQuestion({
    required int questionId,
    required String content,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.questionReply(questionId),
      data: {'content': content},
    );
    if (response.isSuccess && response.data != null) {
      return TaskQuestion.fromJson(response.data!);
    }
    throw Exception(response.message ?? 'Failed to reply question');
  }

  /// 删除问题
  Future<void> deleteQuestion(int questionId) async {
    final response = await _apiService.delete(
      ApiEndpoints.questionDelete(questionId),
    );
    if (!response.isSuccess) {
      throw Exception(response.message ?? 'Failed to delete question');
    }
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/data/models/task_question.dart link2ur/lib/data/repositories/question_repository.dart link2ur/lib/core/constants/api_endpoints.dart
git commit -m "feat: add TaskQuestion model and QuestionRepository"
```

---

## Task 5: Flutter — Register QuestionRepository

**Files:**
- Modify: `link2ur/lib/app_providers.dart`

- [ ] **Step 1: Add QuestionRepository to MultiRepositoryProvider**

Import `QuestionRepository` and add it to the `MultiRepositoryProvider` providers list (follow the pattern of existing inline-created repositories like `FleaMarketRepository`):

```dart
import 'data/repositories/question_repository.dart';

// Inside MultiRepositoryProvider providers list:
RepositoryProvider<QuestionRepository>(
  create: (context) => QuestionRepository(
    apiService: apiService,
  ),
),
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/app_providers.dart
git commit -m "feat: register QuestionRepository in app providers"
```

---

## Task 6: Flutter — Localization Keys

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`

- [ ] **Step 1: Add Q&A l10n keys to all three ARB files**

Add to `app_en.arb`:
```json
"qaTitle": "Q&A ({count})",
"@qaTitle": { "placeholders": { "count": { "type": "int" } } },
"qaAskPlaceholder": "Ask the poster a question...",
"qaReplyPlaceholder": "Write your reply...",
"qaAskButton": "Ask",
"qaReplyButton": "Reply",
"qaDeleteConfirm": "Delete this question?",
"qaDeleteConfirmBody": "The reply will also be deleted.",
"qaNoQuestions": "No questions yet",
"qaOwnerReply": "Poster's reply",
"qaServiceOwnerReply": "Provider's reply",
"qaCannotAskOwn": "Cannot ask questions on your own post",
"qaAlreadyReplied": "Already replied",
"qaLoadMore": "Load more",
"qaAskSuccess": "Question submitted",
"qaReplySuccess": "Reply submitted",
"qaDeleteSuccess": "Question deleted"
```

Add to `app_zh.arb`:
```json
"qaTitle": "问答 ({count})",
"@qaTitle": { "placeholders": { "count": { "type": "int" } } },
"qaAskPlaceholder": "向发布者提问...",
"qaReplyPlaceholder": "写下你的回复...",
"qaAskButton": "提问",
"qaReplyButton": "回复",
"qaDeleteConfirm": "确定删除这个问题？",
"qaDeleteConfirmBody": "回复也会一起删除。",
"qaNoQuestions": "暂无问答",
"qaOwnerReply": "发布者回复",
"qaServiceOwnerReply": "服务者回复",
"qaCannotAskOwn": "不能在自己的帖子里提问",
"qaAlreadyReplied": "已回复",
"qaLoadMore": "加载更多",
"qaAskSuccess": "提问成功",
"qaReplySuccess": "回复成功",
"qaDeleteSuccess": "已删除"
```

Add to `app_zh_Hant.arb`:
```json
"qaTitle": "問答 ({count})",
"@qaTitle": { "placeholders": { "count": { "type": "int" } } },
"qaAskPlaceholder": "向發布者提問...",
"qaReplyPlaceholder": "寫下你的回覆...",
"qaAskButton": "提問",
"qaReplyButton": "回覆",
"qaDeleteConfirm": "確定刪除這個問題？",
"qaDeleteConfirmBody": "回覆也會一起刪除。",
"qaNoQuestions": "暫無問答",
"qaOwnerReply": "發布者回覆",
"qaServiceOwnerReply": "服務者回覆",
"qaCannotAskOwn": "不能在自己的帖子裡提問",
"qaAlreadyReplied": "已回覆",
"qaLoadMore": "載入更多",
"qaAskSuccess": "提問成功",
"qaReplySuccess": "回覆成功",
"qaDeleteSuccess": "已刪除"
```

- [ ] **Step 2: Run gen-l10n**

```powershell
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter gen-l10n
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/l10n/
git commit -m "feat: add Q&A localization keys (en, zh, zh_Hant)"
```

---

## Task 7: Flutter — TaskDetailBloc Q&A Integration

**Files:**
- Modify: `link2ur/lib/features/tasks/bloc/task_detail_bloc.dart`

- [ ] **Step 1: Add Q&A events**

Add these event classes (follow existing event pattern in the file):

```dart
class TaskDetailLoadQuestions extends TaskDetailEvent {
  const TaskDetailLoadQuestions({this.page = 1});
  final int page;
  @override
  List<Object?> get props => [page];
}

class TaskDetailAskQuestion extends TaskDetailEvent {
  const TaskDetailAskQuestion(this.content);
  final String content;
  @override
  List<Object?> get props => [content];
}

class TaskDetailReplyQuestion extends TaskDetailEvent {
  const TaskDetailReplyQuestion({required this.questionId, required this.content});
  final int questionId;
  final String content;
  @override
  List<Object?> get props => [questionId, content];
}

class TaskDetailDeleteQuestion extends TaskDetailEvent {
  const TaskDetailDeleteQuestion(this.questionId);
  final int questionId;
  @override
  List<Object?> get props => [questionId];
}
```

- [ ] **Step 2: Add Q&A state fields**

Add to `TaskDetailState`:

```dart
// Q&A
final List<TaskQuestion> questions;
final bool isLoadingQuestions;
final int questionsTotalCount;
final int questionsCurrentPage;
```

Initialize in constructor with defaults: `this.questions = const []`, `this.isLoadingQuestions = false`, `this.questionsTotalCount = 0`, `this.questionsCurrentPage = 1`.

Add to `props`. In `copyWith`, use the `?? this.x` pattern (NOT direct assignment) so existing copyWith calls don't reset these fields:

```dart
TaskDetailState copyWith({
  // ... existing params ...
  List<TaskQuestion>? questions,
  bool? isLoadingQuestions,
  int? questionsTotalCount,
  int? questionsCurrentPage,
}) {
  return TaskDetailState(
    // ... existing fields ...
    questions: questions ?? this.questions,
    isLoadingQuestions: isLoadingQuestions ?? this.isLoadingQuestions,
    questionsTotalCount: questionsTotalCount ?? this.questionsTotalCount,
    questionsCurrentPage: questionsCurrentPage ?? this.questionsCurrentPage,
  );
}
```

- [ ] **Step 3: Add QuestionRepository to BLoC constructor**

The BLoC constructor needs a `QuestionRepository` parameter. Add it alongside the existing `TaskRepository`:

```dart
TaskDetailBloc({
  required TaskRepository taskRepository,
  required QuestionRepository questionRepository,
}) : _taskRepository = taskRepository,
     _questionRepository = questionRepository;
```

Register the event handlers in the constructor body:

```dart
on<TaskDetailLoadQuestions>(_onLoadQuestions);
on<TaskDetailAskQuestion>(_onAskQuestion);
on<TaskDetailReplyQuestion>(_onReplyQuestion);
on<TaskDetailDeleteQuestion>(_onDeleteQuestion);
```

- [ ] **Step 4: Implement Q&A event handlers**

```dart
Future<void> _onLoadQuestions(
  TaskDetailLoadQuestions event,
  Emitter<TaskDetailState> emit,
) async {
  emit(state.copyWith(isLoadingQuestions: true));
  try {
    final taskId = state.task?.id;
    if (taskId == null) return;
    final result = await _questionRepository.getQuestions(
      targetType: 'task',
      targetId: taskId,
      page: event.page,
    );
    final items = result['items'] as List<TaskQuestion>;
    final allQuestions = event.page == 1
        ? items
        : [...state.questions, ...items];
    emit(state.copyWith(
      questions: allQuestions,
      isLoadingQuestions: false,
      questionsTotalCount: result['total'] as int,
      questionsCurrentPage: event.page,
    ));
  } catch (e) {
    emit(state.copyWith(isLoadingQuestions: false));
  }
}

Future<void> _onAskQuestion(
  TaskDetailAskQuestion event,
  Emitter<TaskDetailState> emit,
) async {
  try {
    final taskId = state.task?.id;
    if (taskId == null) return;
    final question = await _questionRepository.askQuestion(
      targetType: 'task',
      targetId: taskId,
      content: event.content,
    );
    emit(state.copyWith(
      questions: [question, ...state.questions],
      questionsTotalCount: state.questionsTotalCount + 1,
      actionMessage: 'qa_ask_success',
    ));
  } catch (e) {
    emit(state.copyWith(actionMessage: 'qa_ask_failed'));
  }
}

Future<void> _onReplyQuestion(
  TaskDetailReplyQuestion event,
  Emitter<TaskDetailState> emit,
) async {
  try {
    final updated = await _questionRepository.replyQuestion(
      questionId: event.questionId,
      content: event.content,
    );
    final updatedList = state.questions.map((q) =>
      q.id == updated.id ? updated : q
    ).toList();
    emit(state.copyWith(
      questions: updatedList,
      actionMessage: 'qa_reply_success',
    ));
  } catch (e) {
    emit(state.copyWith(actionMessage: 'qa_reply_failed'));
  }
}

Future<void> _onDeleteQuestion(
  TaskDetailDeleteQuestion event,
  Emitter<TaskDetailState> emit,
) async {
  try {
    await _questionRepository.deleteQuestion(event.questionId);
    final updatedList = state.questions.where((q) => q.id != event.questionId).toList();
    emit(state.copyWith(
      questions: updatedList,
      questionsTotalCount: state.questionsTotalCount - 1,
      actionMessage: 'qa_delete_success',
    ));
  } catch (e) {
    emit(state.copyWith(actionMessage: 'qa_delete_failed'));
  }
}
```

- [ ] **Step 5: Update BLoC creation site**

Find where `TaskDetailBloc` is created (in `task_detail_view.dart` or route builder) and pass `QuestionRepository`:

```dart
TaskDetailBloc(
  taskRepository: context.read<TaskRepository>(),
  questionRepository: context.read<QuestionRepository>(),
)
```

- [ ] **Step 6: Fire `TaskDetailLoadQuestions` on page load**

Add `..add(TaskDetailLoadQuestions())` after the existing `add(TaskDetailLoadRequested(...))` in the BlocProvider creation.

- [ ] **Step 7: Commit**

```bash
git add link2ur/lib/features/tasks/bloc/task_detail_bloc.dart link2ur/lib/features/tasks/views/task_detail_view.dart
git commit -m "feat: add Q&A events and handlers to TaskDetailBloc"
```

---

## Task 8: Flutter — TaskExpertBloc Q&A Integration

**Files:**
- Modify: `link2ur/lib/features/task_expert/bloc/task_expert_bloc.dart`

- [ ] **Step 1: Add Q&A events**

Follow the same pattern as Task 8 but with service-specific naming:

```dart
class TaskExpertLoadServiceQuestions extends TaskExpertEvent {
  const TaskExpertLoadServiceQuestions(this.serviceId, {this.page = 1});
  final int serviceId;
  final int page;
  @override
  List<Object?> get props => [serviceId, page];
}

class TaskExpertAskServiceQuestion extends TaskExpertEvent {
  const TaskExpertAskServiceQuestion({required this.serviceId, required this.content});
  final int serviceId;
  final String content;
  @override
  List<Object?> get props => [serviceId, content];
}

class TaskExpertReplyServiceQuestion extends TaskExpertEvent {
  const TaskExpertReplyServiceQuestion({required this.questionId, required this.content});
  final int questionId;
  final String content;
  @override
  List<Object?> get props => [questionId, content];
}

class TaskExpertDeleteServiceQuestion extends TaskExpertEvent {
  const TaskExpertDeleteServiceQuestion(this.questionId);
  final int questionId;
  @override
  List<Object?> get props => [questionId];
}
```

- [ ] **Step 2: Add Q&A state fields**

Add to the BLoC's state:

```dart
final List<TaskQuestion> serviceQuestions;
final bool isLoadingServiceQuestions;
final int serviceQuestionsTotalCount;
final int serviceQuestionsCurrentPage;
```

Initialize with defaults. Add to `copyWith` and `props`.

- [ ] **Step 3: Add QuestionRepository to constructor and implement handlers**

Same pattern as Task 7 (TaskDetailBloc) but using `targetType: 'service'` and the serviceId from events. Also update `TaskExpertBloc`'s constructor to accept `QuestionRepository` and update all creation sites of `TaskExpertBloc` (in `service_detail_view.dart` and any route builders) to pass it.

- [ ] **Step 4: Fire `TaskExpertLoadServiceQuestions` on service detail load**

In `service_detail_view.dart`, add `..add(TaskExpertLoadServiceQuestions(serviceId))` alongside the existing `..add(TaskExpertLoadServiceApplications(serviceId))`.

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/task_expert/bloc/task_expert_bloc.dart link2ur/lib/features/task_expert/views/service_detail_view.dart
git commit -m "feat: add Q&A events and handlers to TaskExpertBloc"
```

---

## Task 9: Flutter — QASection Shared Widget

**Files:**
- Create: `link2ur/lib/core/widgets/qa_section.dart`

- [ ] **Step 1: Create `QASection` widget**

Create `link2ur/lib/core/widgets/qa_section.dart`:

```dart
import 'package:flutter/material.dart';
import '../../data/models/task_question.dart';
import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_radius.dart';
import '../design/app_typography.dart';
import '../utils/date_formatter.dart';
import '../utils/l10n_extension.dart';
import '../utils/adaptive_dialogs.dart';

/// Shared Q&A section for task and service detail pages.
class QASection extends StatefulWidget {
  const QASection({
    super.key,
    required this.targetType,
    required this.isOwner,
    required this.isDark,
    required this.questions,
    required this.isLoading,
    required this.totalCount,
    required this.onAsk,
    required this.onReply,
    required this.onDelete,
    required this.onLoadMore,
    this.isLoggedIn = true,
    this.allowAsk = true,
  });

  final String targetType; // 'task' / 'service'
  final bool isOwner;
  final bool isDark;
  final List<TaskQuestion> questions;
  final bool isLoading;
  final int totalCount;
  final ValueChanged<String> onAsk;
  final void Function(int questionId, String content) onReply;
  final ValueChanged<int> onDelete;
  final VoidCallback onLoadMore;
  final bool isLoggedIn;
  /// Whether the user can ask (false when task is not open/chatting)
  final bool allowAsk;

  @override
  State<QASection> createState() => _QASectionState();
}

class _QASectionState extends State<QASection> {
  final _askController = TextEditingController();

  @override
  void dispose() {
    _askController.dispose();
    super.dispose();
  }

  void _handleAsk() {
    final content = _askController.text.trim();
    if (content.length < 2) return;
    widget.onAsk(content);
    _askController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: widget.isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allMedium,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              const Icon(Icons.question_answer_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                l10n.qaTitle(widget.totalCount),
                style: AppTypography.title3.copyWith(
                  color: widget.isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),

          // Ask input (logged in + not owner + allowAsk)
          if (widget.isLoggedIn && !widget.isOwner && widget.allowAsk) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _askController,
                    maxLength: 100,
                    decoration: InputDecoration(
                      hintText: l10n.qaAskPlaceholder,
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.allSmall,
                        borderSide: BorderSide(
                          color: widget.isDark
                              ? AppColors.dividerDark
                              : AppColors.dividerLight,
                        ),
                      ),
                    ),
                    style: AppTypography.body.copyWith(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _handleAsk,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text(l10n.qaAskButton),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // Questions list
          if (widget.isLoading && widget.questions.isEmpty)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (widget.questions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  l10n.qaNoQuestions,
                  style: AppTypography.body.copyWith(
                    color: widget.isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ),
            )
          else ...[
            ...widget.questions.map((q) => _QACard(
              key: ValueKey('qa_${q.id}'),
              question: q,
              isDark: widget.isDark,
              isOwner: widget.isOwner,
              targetType: widget.targetType,
              onReply: widget.onReply,
              onDelete: widget.onDelete,
            )),

            // Load more button
            if (widget.questions.length < widget.totalCount)
              Center(
                child: TextButton(
                  onPressed: widget.isLoading ? null : widget.onLoadMore,
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.qaLoadMore),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _QACard extends StatefulWidget {
  const _QACard({
    super.key,
    required this.question,
    required this.isDark,
    required this.isOwner,
    required this.targetType,
    required this.onReply,
    required this.onDelete,
  });

  final TaskQuestion question;
  final bool isDark;
  final bool isOwner;
  final String targetType;
  final void Function(int questionId, String content) onReply;
  final ValueChanged<int> onDelete;

  @override
  State<_QACard> createState() => _QACardState();
}

class _QACardState extends State<_QACard> {
  final _replyController = TextEditingController();
  bool _showReplyInput = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  void _handleReply() {
    final content = _replyController.text.trim();
    if (content.length < 2) return;
    widget.onReply(widget.question.id, content);
    setState(() => _showReplyInput = false);
    _replyController.clear();
  }

  void _handleDelete() {
    AdaptiveDialogs.showConfirmDialog(
      context: context,
      title: context.l10n.qaDeleteConfirm,
      content: context.l10n.qaDeleteConfirmBody,
      onConfirm: () => widget.onDelete(widget.question.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final q = widget.question;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: widget.isDark
              ? AppColors.backgroundDark
              : AppColors.backgroundLight,
          borderRadius: AppRadius.allMedium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question header: icon + time + delete button
            Row(
              children: [
                Icon(Icons.help_outline, size: 16,
                    color: AppColors.primary.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                if (q.createdAt != null)
                  Text(
                    DateFormatter.formatRelative(DateTime.parse(q.createdAt!).toLocal()),
                    style: AppTypography.caption.copyWith(
                      color: widget.isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                      fontSize: 11,
                    ),
                  ),
                const Spacer(),
                if (q.isOwn)
                  GestureDetector(
                    onTap: _handleDelete,
                    child: Icon(Icons.delete_outline, size: 16,
                        color: widget.isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight),
                  ),
              ],
            ),

            // Question content
            const SizedBox(height: 6),
            Text(
              q.content,
              style: AppTypography.body.copyWith(
                color: widget.isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                height: 1.5,
              ),
            ),

            // Reply section
            if (q.hasReply) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(left: AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: AppRadius.allSmall,
                  border: Border(
                    left: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.reply, size: 14,
                            color: AppColors.primary.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(
                          widget.targetType == 'service'
                              ? l10n.qaServiceOwnerReply
                              : l10n.qaOwnerReply,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        if (q.replyAt != null)
                          Text(
                            DateFormatter.formatRelative(DateTime.parse(q.replyAt!).toLocal()),
                            style: AppTypography.caption.copyWith(
                              color: widget.isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      q.reply!,
                      style: AppTypography.body.copyWith(
                        color: widget.isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (widget.isOwner) ...[
              // Reply button / input for owner
              const SizedBox(height: AppSpacing.sm),
              if (_showReplyInput)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          maxLength: 100,
                          decoration: InputDecoration(
                            hintText: l10n.qaReplyPlaceholder,
                            counterText: '',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.allSmall,
                            ),
                          ),
                          style: AppTypography.body.copyWith(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _handleReply,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Text(l10n.qaReplyButton, style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.lg),
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showReplyInput = true),
                    icon: const Icon(Icons.reply, size: 16),
                    label: Text(l10n.qaReplyButton),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/core/widgets/qa_section.dart
git commit -m "feat: add shared QASection widget for task/service detail pages"
```

---

## Task 10: Flutter — Wire QASection into Task Detail Page

**Files:**
- Modify: `link2ur/lib/features/tasks/views/task_detail_view.dart`

- [ ] **Step 1: Replace `PublicApplicationsSection` with `QASection`**

In `task_detail_view.dart`, find the `PublicApplicationsSection` usage (around line 624-634). Replace:

```dart
if (!isPoster &&
    (task.status == AppConstants.taskStatusOpen ||
     task.status == AppConstants.taskStatusChatting)) ...[
  AnimatedListItem(
    index: 3,
    child: PublicApplicationsSection(
      applications: state.applications,
      isLoading: state.isLoadingApplications,
      isDark: isDark,
    ),
  ),
```

With:

```dart
// Q&A section — visible to all users on all task statuses
AnimatedListItem(
  index: 3,
  child: QASection(
    targetType: 'task',
    isOwner: isPoster,
    isDark: isDark,
    questions: state.questions,
    isLoading: state.isLoadingQuestions,
    totalCount: state.questionsTotalCount,
    isLoggedIn: currentUserId != null,
    allowAsk: task.status == AppConstants.taskStatusOpen ||
              task.status == AppConstants.taskStatusChatting,
    onAsk: (content) => context.read<TaskDetailBloc>().add(
      TaskDetailAskQuestion(content),
    ),
    onReply: (questionId, content) => context.read<TaskDetailBloc>().add(
      TaskDetailReplyQuestion(questionId: questionId, content: content),
    ),
    onDelete: (questionId) => context.read<TaskDetailBloc>().add(
      TaskDetailDeleteQuestion(questionId),
    ),
    onLoadMore: () => context.read<TaskDetailBloc>().add(
      TaskDetailLoadQuestions(page: state.questionsCurrentPage + 1),
    ),
  ),
),
```

Add the import at top of file:
```dart
import '../../../core/widgets/qa_section.dart';
import '../../../data/models/task_question.dart';
```

- [ ] **Step 2: Add SnackBar feedback for Q&A actions**

In the `BlocListener` for `TaskDetailBloc`, add cases for Q&A action messages:

```dart
case 'qa_ask_success':
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.l10n.qaAskSuccess)),
  );
case 'qa_reply_success':
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.l10n.qaReplySuccess)),
  );
case 'qa_delete_success':
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.l10n.qaDeleteSuccess)),
  );
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/tasks/views/task_detail_view.dart
git commit -m "feat: replace PublicApplicationsSection with QASection in task detail"
```

---

## Task 11: Flutter — Wire QASection into Service Detail Page

**Files:**
- Modify: `link2ur/lib/features/task_expert/views/service_detail_view.dart`

- [ ] **Step 1: Replace `_ServiceApplicationsSection` with `QASection`**

Find the `_ServiceApplicationsSection` usage (around line 168-177). Replace:

```dart
if (state.serviceApplications.isNotEmpty ||
    state.isLoadingServiceApplications)
  _ServiceApplicationsSection(
    applications: state.serviceApplications,
    isLoading: state.isLoadingServiceApplications,
    isDark: isDark,
    isOwner: _isServiceOwner(state.selectedService),
    serviceId: serviceId,
  ),
```

With:

```dart
QASection(
  targetType: 'service',
  isOwner: _isServiceOwner(state.selectedService),
  isDark: isDark,
  questions: state.serviceQuestions,
  isLoading: state.isLoadingServiceQuestions,
  totalCount: state.serviceQuestionsTotalCount,
  isLoggedIn: StorageService.instance.getUserId() != null,
  allowAsk: true,
  onAsk: (content) => context.read<TaskExpertBloc>().add(
    TaskExpertAskServiceQuestion(serviceId: serviceId, content: content),
  ),
  onReply: (questionId, content) => context.read<TaskExpertBloc>().add(
    TaskExpertReplyServiceQuestion(questionId: questionId, content: content),
  ),
  onDelete: (questionId) => context.read<TaskExpertBloc>().add(
    TaskExpertDeleteServiceQuestion(questionId),
  ),
  onLoadMore: () => context.read<TaskExpertBloc>().add(
    TaskExpertLoadServiceQuestions(serviceId, page: state.serviceQuestionsCurrentPage + 1),
  ),
),
```

Add imports:
```dart
import '../../../core/widgets/qa_section.dart';
import '../../../data/models/task_question.dart';
```

- [ ] **Step 2: Add SnackBar feedback for Q&A actions**

Add a `BlocListener` for Q&A action messages (same pattern as Task 11 Step 2). Check how the service detail page currently handles action messages and follow that pattern.

- [ ] **Step 3: The old `_ServiceApplicationsSection` and `_ServiceApplicationCard` classes can be removed**

Delete the `_ServiceApplicationsSection` and `_ServiceApplicationCard` classes from the bottom of `service_detail_view.dart` (around lines 1992-2190) since they are no longer used.

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/task_expert/views/service_detail_view.dart
git commit -m "feat: replace ServiceApplicationsSection with QASection in service detail"
```

---

## Task 12: Flutter — Add error localizer entries for Q&A

**Files:**
- Modify: `link2ur/lib/core/utils/error_localizer.dart`

- [ ] **Step 1: Add Q&A error codes**

Add cases for Q&A error codes in `ErrorLocalizer.localize()`:

```dart
case 'qa_ask_failed':
  return l10n.errorGeneric; // or a dedicated key if needed
case 'qa_reply_failed':
  return l10n.errorGeneric;
case 'qa_delete_failed':
  return l10n.errorGeneric;
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/core/utils/error_localizer.dart
git commit -m "feat: add Q&A error codes to error localizer"
```

---

## Task 13: Verify & Clean Up

- [ ] **Step 1: Run Flutter analyze**

```powershell
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze
```

Fix any analysis errors.

- [ ] **Step 2: Run existing tests**

```powershell
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter test
```

Fix any broken tests (likely `TaskDetailBloc` tests need `QuestionRepository` mock added).

- [ ] **Step 3: Verify backend starts**

```bash
cd backend && python -c "from app.models import Question; print('Model OK')"
```

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "chore: fix analysis warnings and test compatibility after Q&A feature"
```
