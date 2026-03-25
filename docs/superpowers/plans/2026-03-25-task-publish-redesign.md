# 任务发布页重设计 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将任务发布页 (`create_task_view.dart`) 重写为 mockup 方案A 的卡片式表单设计，新增定价类型、任务方式、技能标签、截止时间快捷选项、AI 优化、本地草稿等功能。

**Architecture:**
- 后端新增 3 个数据库字段（`pricing_type`, `task_mode`, `required_skills`）+ 1 个 AI 优化接口
- Flutter 端重写 `create_task_view.dart` 为卡片式 UI，更新 `CreateTaskRequest` 模型，新增本地草稿 (Hive)
- **分类策略**：发布页只显示 mockup 的 7 个新分类（design/programming/photography/copywriting/music/lifestyle/tutoring）。后端 `task_type` 字段不做枚举校验，任意字符串均可存储。老分类的已有任务在列表/详情页正常显示（`taskTypeText` getter 已兼容新旧分类 key）。新分类使用小写英文 key（如 `design`），与老分类（如 `Housekeeping`）不冲突。

**Tech Stack:** Flutter/Dart, BLoC, Hive, Python/FastAPI/SQLAlchemy

---

## File Structure

### Backend
| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `backend/app/models.py` | Task model: 新增 `pricing_type`, `task_mode`, `required_skills` 列 |
| Modify | `backend/app/schemas.py` | TaskCreate + TaskOut schema: 新增 3 个字段 |
| Modify | `backend/app/async_crud.py` | create_task(): 处理新字段存储 |
| Modify | `backend/app/async_routers.py` | POST /api/tasks: 接收新字段 |
| Create | `backend/alembic/versions/xxxx_add_task_publish_fields.py` | 数据库迁移脚本 |
| Create | `backend/app/routes/ai_optimize.py` | AI 优化任务描述接口 |

### Flutter
| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `link2ur/lib/data/models/task.dart` | CreateTaskRequest 新增字段; Task model 解析新字段 |
| Modify | `link2ur/lib/features/tasks/bloc/create_task_bloc.dart` | 新增 AI 优化事件/状态 |
| Rewrite | `link2ur/lib/features/tasks/views/create_task_view.dart` | 卡片式 UI 重写 |
| Create | `link2ur/lib/features/tasks/views/create_task_widgets.dart` | 提取的表单组件(chips, price row等) |
| Create | `link2ur/lib/data/services/task_draft_service.dart` | 本地草稿 Hive 存储 |
| Modify | `link2ur/lib/data/repositories/task_repository.dart` | 新增 aiOptimizeTask() 方法 |
| Modify | `link2ur/lib/core/constants/api_endpoints.dart` | 新增 AI 优化 endpoint |
| Modify | `link2ur/lib/l10n/app_en.arb` | 新增英文 l10n strings |
| Modify | `link2ur/lib/l10n/app_zh.arb` | 新增简中 l10n strings |
| Modify | `link2ur/lib/l10n/app_zh_Hant.arb` | 新增繁中 l10n strings |

---

## Task 1: 数据库迁移 — 新增字段

**Files:**
- Modify: `backend/app/models.py:181-278` (Task model)
- Create: `backend/alembic/versions/xxxx_add_task_publish_fields.py`

- [ ] **Step 1: 在 Task model 中添加新列**

在 `backend/app/models.py` 的 Task class 中添加：

```python
# 定价类型: fixed(固定价), hourly(时薪), negotiable(协商定价)
pricing_type = Column(String(20), default='fixed', server_default='fixed')

# 任务方式: online(线上), offline(线下), both(都可以)
task_mode = Column(String(20), default='online', server_default='online')

# 所需技能标签 (JSON 数组, e.g. '["Figma","UI设计"]')
required_skills = Column(Text, nullable=True)
```

- [ ] **Step 2: 创建 Alembic 迁移脚本**

```bash
cd backend && alembic revision --autogenerate -m "add pricing_type task_mode required_skills to tasks"
```

- [ ] **Step 3: 执行迁移**

```bash
cd backend && alembic upgrade head
```

- [ ] **Step 4: 验证数据库**

```bash
cd backend && python -c "from app.models import Task; print([c.name for c in Task.__table__.columns if c.name in ('pricing_type','task_mode','required_skills')])"
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/models.py backend/alembic/versions/
git commit -m "feat(db): add pricing_type, task_mode, required_skills columns to tasks table"
```

---

## Task 2: 后端 Schema + CRUD + 路由

**Files:**
- Modify: `backend/app/schemas.py:369-399` (TaskCreate)
- Modify: `backend/app/async_crud.py:236-367` (create_task)
- Modify: `backend/app/async_routers.py:615-795` (POST /api/tasks)

- [ ] **Step 1: 更新 TaskCreate schema**

在 `backend/app/schemas.py` 的 TaskCreate class 中添加：

```python
pricing_type: Optional[str] = "fixed"       # fixed / hourly / negotiable
task_mode: Optional[str] = "online"          # online / offline / both
required_skills: Optional[List[str]] = []    # 技能标签列表

@validator('pricing_type')
def validate_pricing_type(cls, v):
    if v and v not in ('fixed', 'hourly', 'negotiable'):
        raise ValueError('pricing_type must be fixed, hourly, or negotiable')
    return v or 'fixed'

@validator('task_mode')
def validate_task_mode(cls, v):
    if v and v not in ('online', 'offline', 'both'):
        raise ValueError('task_mode must be online, offline, or both')
    return v or 'online'
```

- [ ] **Step 1b: 更新 TaskOut schema**

在 `backend/app/schemas.py` 的 TaskOut class 中也添加这 3 个字段（TaskOut 继承自 TaskBase，Pydantic 会过滤未声明的字段）：

```python
class TaskOut(TaskBase):
    # ... 现有字段 ...
    pricing_type: Optional[str] = "fixed"
    task_mode: Optional[str] = "online"
    required_skills: Optional[List[str]] = []
```

- [ ] **Step 2: 更新 async_crud.py create_task()**

在 `async_crud.py` 的 create_task 函数中，构建 Task 实例时传入新字段：

```python
import json

# 在构建 new_task 时添加:
pricing_type=task.pricing_type or 'fixed',
task_mode=task.task_mode or 'online',
required_skills=json.dumps(task.required_skills or [], ensure_ascii=False),
```

- [ ] **Step 3: 更新 POST /api/tasks 响应**

在 `async_routers.py` 返回的 response dict 中添加：

```python
"pricing_type": new_task.pricing_type or "fixed",
"task_mode": new_task.task_mode or "online",
"required_skills": json.loads(new_task.required_skills) if new_task.required_skills else [],
```

- [ ] **Step 4: 验证后端启动无报错**

```bash
cd backend && python -c "from app.schemas import TaskCreate; t = TaskCreate(title='test', description='', task_type='design', location='Online', pricing_type='hourly', task_mode='both', required_skills=['Figma']); print(t.dict())"
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/schemas.py backend/app/async_crud.py backend/app/async_routers.py
git commit -m "feat(api): support pricing_type, task_mode, required_skills in task creation"
```

---

## Task 3: 后端 AI 优化接口

**Files:**
- Create: `backend/app/routes/ai_optimize.py`
- Modify: `backend/app/async_routers.py` (注册路由)

- [ ] **Step 1: 创建 AI 优化路由**

创建 `backend/app/routes/ai_optimize.py`：

```python
"""AI 任务描述优化接口"""
import json
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import List, Optional

from ..services.ai_llm_client import get_llm_client  # 实际 AI 基础设施
from ..async_routers import get_current_user_secure_async_csrf  # 实际 auth 依赖

router = APIRouter(prefix="/api/tasks", tags=["tasks"])

class AIOptimizeRequest(BaseModel):
    title: str
    description: str
    task_type: Optional[str] = None

class AIOptimizeResponse(BaseModel):
    optimized_title: str
    optimized_description: str
    suggested_skills: List[str]

@router.post("/ai-optimize", response_model=AIOptimizeResponse)
async def ai_optimize_task(
    request: AIOptimizeRequest,
    current_user=Depends(get_current_user_secure_async_csrf),
):
    prompt = f"""你是一个任务发布优化助手。请优化以下任务信息，使其更清晰、专业，更容易吸引合适的人接单。

原标题：{request.title}
原描述：{request.description}
任务分类：{request.task_type or '未指定'}

请返回 JSON 格式：
{{
  "optimized_title": "优化后的标题（50字以内）",
  "optimized_description": "优化后的详细描述",
  "suggested_skills": ["建议的技能标签1", "技能2", "技能3"]
}}
只返回 JSON，不要其他内容。"""

    try:
        llm = get_llm_client("small")  # 使用小模型即可
        response = await llm.chat([{"role": "user", "content": prompt}])
        data = json.loads(response.content)
        return AIOptimizeResponse(**data)
    except (json.JSONDecodeError, KeyError, Exception):
        return AIOptimizeResponse(
            optimized_title=request.title,
            optimized_description=request.description,
            suggested_skills=[],
        )
```

- [ ] **Step 2: 注册路由到主应用**

在 `backend/app/main.py` 中添加：
```python
from app.routes.ai_optimize import router as ai_optimize_router
app.include_router(ai_optimize_router)
```

注意：路由 prefix 是 `/api/tasks`，与 `async_router` 的任务路由不冲突（`async_router` 在 `/api` 下注册）。需确保 `ai_optimize_router` 在 `async_router` 之前 include，以免路径被通配符覆盖。

- [ ] **Step 3: 测试接口**

```bash
curl -X POST http://localhost:8000/api/tasks/ai-optimize \
  -H "Content-Type: application/json" \
  -d '{"title":"App UI 设计","description":"需要设计一款电商App","task_type":"design"}'
```

- [ ] **Step 4: Commit**

```bash
git add backend/app/routes/ai_optimize.py backend/app/async_routers.py
git commit -m "feat(api): add POST /api/tasks/ai-optimize endpoint"
```

---

## Task 4: Flutter Model 层更新

**Files:**
- Modify: `link2ur/lib/data/models/task.dart:642-697` (CreateTaskRequest)
- Modify: `link2ur/lib/data/models/task.dart:354-424` (Task.fromJson)
- Modify: `link2ur/lib/core/constants/api_endpoints.dart`

- [ ] **Step 1: 更新 CreateTaskRequest**

在 `link2ur/lib/data/models/task.dart` 的 `CreateTaskRequest` 中新增字段：

```dart
class CreateTaskRequest {
  const CreateTaskRequest({
    required this.title,
    this.description,
    required this.taskType,
    this.location,
    this.latitude,
    this.longitude,
    this.reward,
    this.currency = 'GBP',
    this.images = const [],
    this.deadline,
    this.isMultiParticipant = false,
    this.maxParticipants = 1,
    this.isPublic = 1,
    this.taskSource = 'normal',
    this.designatedTakerId,
    // 新增
    this.pricingType = 'fixed',
    this.taskMode = 'online',
    this.requiredSkills = const [],
  });

  // ... 现有字段 ...

  /// 定价类型: fixed(固定价), hourly(时薪), negotiable(协商)
  final String pricingType;
  /// 任务方式: online(线上), offline(线下), both(都可以)
  final String taskMode;
  /// 所需技能标签
  final List<String> requiredSkills;

  Map<String, dynamic> toJson() {
    return {
      // ... 现有字段 ...
      'pricing_type': pricingType,
      'task_mode': taskMode,
      if (requiredSkills.isNotEmpty) 'required_skills': requiredSkills,
    };
  }
}
```

- [ ] **Step 2: 更新 Task.fromJson 解析新字段**

在 `Task` model 中添加 `pricingType`, `taskMode`, `requiredSkills` 字段，并在 `fromJson` 中解析：

```dart
// Task 类新增字段
final String pricingType;   // 'fixed', 'hourly', 'negotiable'
final String taskMode;      // 'online', 'offline', 'both'
final List<String> requiredSkills;

// fromJson 中:
pricingType: json['pricing_type'] as String? ?? 'fixed',
taskMode: json['task_mode'] as String? ?? 'online',
requiredSkills: (json['required_skills'] as List<dynamic>?)
    ?.map((e) => e as String).toList() ?? [],
```

- [ ] **Step 2b: 更新 Task.copyWith(), toJson(), props**

**重要**：Task 是 Equatable，新字段必须出现在 `props`、`copyWith()` 和 `toJson()` 中。

```dart
// props 中新增:
@override
List<Object?> get props => [
  id, title, status, reward, currency, hasApplied,
  userApplicationStatus, takerId, hasReviewed, updatedAt,
  counterOfferPrice, counterOfferStatus, counterOfferUserId,
  isPublic, takerPublic,
  pricingType, taskMode, requiredSkills,  // ← 新增
];

// copyWith 中新增参数和传递:
String? pricingType,
String? taskMode,
List<String>? requiredSkills,
// ... 在 return Task(...) 中:
pricingType: pricingType ?? this.pricingType,
taskMode: taskMode ?? this.taskMode,
requiredSkills: requiredSkills ?? this.requiredSkills,

// toJson 中新增:
'pricing_type': pricingType,
'task_mode': taskMode,
'required_skills': requiredSkills,
```

- [ ] **Step 3: 新增 AI 优化 endpoint**

在 `api_endpoints.dart` 中添加：

```dart
static const String aiOptimizeTask = '/api/tasks/ai-optimize';
```

- [ ] **Step 4: 运行 flutter analyze 确认无报错**

```powershell
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/data/models/task.dart link2ur/lib/core/constants/api_endpoints.dart
git commit -m "feat(model): add pricingType, taskMode, requiredSkills to task models"
```

---

## Task 5: TaskRepository + BLoC 更新

**Files:**
- Modify: `link2ur/lib/data/repositories/task_repository.dart`
- Modify: `link2ur/lib/features/tasks/bloc/create_task_bloc.dart`

- [ ] **Step 1: TaskRepository 新增 aiOptimizeTask()**

```dart
/// AI 优化任务描述
Future<Map<String, dynamic>> aiOptimizeTask({
  required String title,
  required String description,
  String? taskType,
}) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.aiOptimizeTask,
    data: {
      'title': title,
      'description': description,
      if (taskType != null) 'task_type': taskType,
    },
  );

  if (!response.isSuccess || response.data == null) {
    throw TaskException(response.message ?? 'ai_optimize_failed');
  }

  return response.data!;
}
```

- [ ] **Step 2: CreateTaskBloc 新增 AI 优化事件和状态**

```dart
// 新事件
class CreateTaskAIOptimize extends CreateTaskEvent {
  const CreateTaskAIOptimize({
    required this.title,
    required this.description,
    this.taskType,
  });
  final String title;
  final String description;
  final String? taskType;

  @override
  List<Object?> get props => [title, description, taskType];
}

// 状态中新增
enum CreateTaskStatus { initial, submitting, success, error, aiOptimizing }

class CreateTaskState extends Equatable {
  const CreateTaskState({
    this.status = CreateTaskStatus.initial,
    this.createdTask,
    this.errorMessage,
    this.optimizedTitle,
    this.optimizedDescription,
    this.suggestedSkills = const [],
  });

  final CreateTaskStatus status;
  final Task? createdTask;
  final String? errorMessage;
  final String? optimizedTitle;
  final String? optimizedDescription;
  final List<String> suggestedSkills;

  bool get isSubmitting => status == CreateTaskStatus.submitting;
  bool get isSuccess => status == CreateTaskStatus.success;
  bool get isAiOptimizing => status == CreateTaskStatus.aiOptimizing;

  // 注意：errorMessage 使用直接赋值（不用 ?? this.x），传 null 即清空
  // optimizedTitle/optimizedDescription 同理 — 便于 reset
  // suggestedSkills 使用 ?? 保留，因为通常不需要清空
  CreateTaskState copyWith({
    CreateTaskStatus? status,
    Task? createdTask,
    String? errorMessage,
    String? optimizedTitle,
    String? optimizedDescription,
    List<String>? suggestedSkills,
  }) {
    return CreateTaskState(
      status: status ?? this.status,
      createdTask: createdTask ?? this.createdTask,
      errorMessage: errorMessage,  // 直接赋值，null = 清空
      optimizedTitle: optimizedTitle,  // 直接赋值
      optimizedDescription: optimizedDescription,  // 直接赋值
      suggestedSkills: suggestedSkills ?? this.suggestedSkills,
    );
  }

  @override
  List<Object?> get props => [status, createdTask, errorMessage,
      optimizedTitle, optimizedDescription, suggestedSkills];
}

// handler
Future<void> _onAIOptimize(
  CreateTaskAIOptimize event,
  Emitter<CreateTaskState> emit,
) async {
  emit(state.copyWith(status: CreateTaskStatus.aiOptimizing));
  try {
    final result = await _taskRepository.aiOptimizeTask(
      title: event.title,
      description: event.description,
      taskType: event.taskType,
    );
    emit(state.copyWith(
      status: CreateTaskStatus.initial,
      optimizedTitle: result['optimized_title'] as String?,
      optimizedDescription: result['optimized_description'] as String?,
      suggestedSkills: (result['suggested_skills'] as List<dynamic>?)
          ?.map((e) => e as String).toList() ?? [],
    ));
  } catch (e) {
    emit(state.copyWith(
      status: CreateTaskStatus.error,
      errorMessage: 'ai_optimize_failed',
    ));
  }
}
```

- [ ] **Step 3: 运行 flutter analyze**

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/data/repositories/task_repository.dart link2ur/lib/features/tasks/bloc/create_task_bloc.dart
git commit -m "feat(bloc): add AI optimize support to CreateTaskBloc"
```

---

## Task 6: 本地草稿服务

**Files:**
- Create: `link2ur/lib/data/services/task_draft_service.dart`

- [ ] **Step 1: 创建 TaskDraftService**

```dart
import 'package:hive/hive.dart';

/// 任务发布草稿的本地存储服务（Hive）
/// 使用 Hive 原生 Map 存储（不做 jsonEncode），与项目缓存模式一致
class TaskDraftService {
  static const String _boxName = 'task_drafts';

  static Future<Box> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  /// 保存草稿（Hive 原生支持 Map 存储）
  static Future<void> saveDraft(Map<String, dynamic> draft) async {
    final box = await _getBox();
    draft['saved_at'] = DateTime.now().toIso8601String();
    await box.put('current_draft', draft);
  }

  /// 读取草稿
  static Future<Map<String, dynamic>?> loadDraft() async {
    final box = await _getBox();
    final raw = box.get('current_draft');
    if (raw == null) return null;
    // 兼容读取：原生 Map 或旧 String 格式
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  /// 删除草稿
  static Future<void> deleteDraft() async {
    final box = await _getBox();
    await box.delete('current_draft');
  }

  /// 是否有草稿
  static Future<bool> hasDraft() async {
    final box = await _getBox();
    return box.containsKey('current_draft');
  }
}
```

- [ ] **Step 2: 运行 flutter analyze**

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/data/services/task_draft_service.dart
git commit -m "feat: add local task draft service using Hive"
```

---

## Task 7: l10n 国际化字符串

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`

- [ ] **Step 1: 添加新 l10n 条目**

在三个 ARB 文件中添加以下 key（以中文为例）：

```json
"createTaskPricingType": "预算",
"createTaskPricingFixed": "固定价",
"createTaskPricingHourly": "时薪",
"createTaskPricingNegotiable": "协商定价",
"createTaskMode": "任务方式",
"createTaskModeOnline": "线上/远程",
"createTaskModeOffline": "线下见面",
"createTaskModeBoth": "都可以",
"createTaskDeadline24h": "24小时内",
"createTaskDeadline3d": "3天内",
"createTaskDeadline1w": "1周内",
"createTaskDeadline2w": "2周内",
"createTaskDeadlineNoRush": "不急",
"createTaskDeadlineCustom": "自定义",
"createTaskRequiredSkills": "需要的技能",
"createTaskAddCustomSkill": "+ 自定义",
"createTaskAiOptimize": "AI 智能优化",
"createTaskAiOptimizeDesc": "让 AI 帮你优化任务描述，提升匹配率",
"createTaskAiOptimizeBtn": "优化",
"createTaskAiTipTitle": "AI 建议",
"createTaskSaveDraft": "存为草稿",
"createTaskPreview": "预览效果",
"createTaskDraftSaved": "草稿已保存",
"createTaskDraftLoaded": "已恢复草稿",
"createTaskPublishBtn": "发布任务",
"createTaskTitleHintNew": "简洁描述你需要的帮助",
"createTaskDescHintNew": "详细描述你的需求，帮助达人更好理解...",
"createTaskRefImages": "参考图片",
"createTaskRefImagesHint": "最多 9 张，展示参考案例或需求说明",
"createTaskCategoryDesign": "设计",
"createTaskCategoryProgramming": "编程",
"createTaskCategoryPhotography": "摄影",
"createTaskCategoryCopywriting": "文案",
"createTaskCategoryMusic": "音乐",
"createTaskCategoryLifestyle": "生活",
"createTaskCategoryTutoring": "辅导",
"errorAiOptimizeFailed": "AI 优化失败，请稍后重试"
```

同时在 `core/utils/error_localizer.dart` 的 `localize()` 中添加 case：
```dart
case 'ai_optimize_failed': return context.l10n.errorAiOptimizeFailed;
```

- [ ] **Step 2: 运行 gen-l10n**

```powershell
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter gen-l10n
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/l10n/
git commit -m "feat(l10n): add task publish redesign strings for en/zh/zh_Hant"
```

---

## Task 8: 提取表单组件

**Files:**
- Create: `link2ur/lib/features/tasks/views/create_task_widgets.dart`

- [ ] **Step 1: 创建可复用表单组件文件**

包含以下 widget：

1. **`SectionCard`** — 白底圆角卡片容器，带标题和可选必填标记
2. **`CategoryChips`** — 分类选择 Wrap chips（新 7 分类 + emoji）
3. **`PriceRow`** — 价格输入 + 定价类型三选一
4. **`TaskModeSelector`** — 任务方式三选卡片（线上/线下/都可以）
5. **`DeadlineChips`** — 截止时间快捷选项 chips
6. **`SkillTagSelector`** — 技能标签选择 + 自定义输入
7. **`AIOptimizeBar`** — AI 优化渐变按钮
8. **`AITipCard`** — 描述框下方的 AI 建议提示

每个 widget 接收回调参数，不持有业务逻辑。

```dart
// SectionCard 示例
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.label,
    this.isRequired = false,
    required this.child,
  });

  final String label;
  final bool isRequired;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isRequired)
                const Text('* ', style: TextStyle(color: Color(0xFFFF4757), fontSize: 15)),
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 实现 CategoryChips**

```dart
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  static const categories = [
    ('design', '🎨', 'createTaskCategoryDesign'),
    ('programming', '💻', 'createTaskCategoryProgramming'),
    ('photography', '📷', 'createTaskCategoryPhotography'),
    ('copywriting', '📝', 'createTaskCategoryCopywriting'),
    ('music', '🎵', 'createTaskCategoryMusic'),
    ('lifestyle', '🏠', 'createTaskCategoryLifestyle'),
    ('tutoring', '📚', 'createTaskCategoryTutoring'),
  ];
  // ... build Wrap with ChoiceChip-style containers
}
```

- [ ] **Step 3: 实现 PriceRow, TaskModeSelector, DeadlineChips, SkillTagSelector, AIOptimizeBar, AITipCard**

每个 widget 独立，遵循 mockup 设计。样式使用项目 `AppColors` 和 `AppRadius`。渐变色用 `AppColors.gradientPrimary` 或自定义紫色渐变。

- [ ] **Step 4: 运行 flutter analyze**

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/tasks/views/create_task_widgets.dart
git commit -m "feat(ui): add reusable form widgets for task publish redesign"
```

---

## Task 9: 重写 create_task_view.dart

**Files:**
- Rewrite: `link2ur/lib/features/tasks/views/create_task_view.dart`

- [ ] **Step 1: 重写页面结构**

新的页面结构（对应 mockup）：

```
Scaffold
├── AppBar: "发布任务" + 发布按钮
├── Body: SingleChildScrollView
│   ├── SectionCard: 任务标题 (TextFormField, max 50)
│   ├── SectionCard: 参考图片 (ImagePicker, max 9)
│   ├── SectionCard: 详细描述 (TextFormField, max 2000) + AITipCard
│   ├── SectionCard: 任务分类 (CategoryChips)
│   ├── SectionCard: 预算 (PriceRow)
│   ├── SectionCard: 任务方式 (TaskModeSelector)
│   ├── SectionCard: 截止时间 (DeadlineChips)
│   ├── SectionCard: 需要的技能 (SkillTagSelector)
│   └── AIOptimizeBar
├── BottomBar (固定):
│   ├── PrimaryButton: 发布任务
│   └── Row: 存为草稿 | 预览效果
```

- [ ] **Step 2: 实现状态管理**

```dart
// 新增状态变量
String _pricingType = 'fixed';          // fixed / hourly / negotiable
String _taskMode = 'online';            // online / offline / both
String? _deadlinePreset;                // '24h', '3d', '1w', '2w', 'no_rush', null(custom)
final List<String> _selectedSkills = [];
```

- [ ] **Step 3: 实现截止时间快捷选项逻辑**

```dart
void _onDeadlinePreset(String preset) {
  setState(() {
    _deadlinePreset = preset;
    final now = DateTime.now();
    switch (preset) {
      case '24h': _deadline = now.add(const Duration(hours: 24));
      case '3d':  _deadline = now.add(const Duration(days: 3));
      case '1w':  _deadline = now.add(const Duration(days: 7));
      case '2w':  _deadline = now.add(const Duration(days: 14));
      case 'no_rush': _deadline = null; // 不急 = 无截止
      default: _selectDeadline(); // 自定义弹出 DatePicker
    }
  });
}
```

- [ ] **Step 4: 实现草稿保存/恢复**

```dart
// initState 中检查是否有草稿
Future<void> _checkDraft() async {
  final draft = await TaskDraftService.loadDraft();
  if (draft != null && mounted) {
    // 显示 SnackBar 问用户是否恢复
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.createTaskDraftLoaded),
        action: SnackBarAction(
          label: context.l10n.commonRestore,
          onPressed: () => _restoreDraft(draft),
        ),
      ),
    );
  }
}

Future<void> _saveDraft() async {
  await TaskDraftService.saveDraft({
    'title': _titleController.text,
    'description': _descriptionController.text,
    'task_type': _selectedCategory,
    'pricing_type': _pricingType,
    'task_mode': _taskMode,
    'reward': _rewardController.text,
    'deadline_preset': _deadlinePreset,
    'required_skills': _selectedSkills,
  });
  if (mounted) {
    AppFeedback.showSuccess(context, context.l10n.createTaskDraftSaved);
  }
}
```

- [ ] **Step 5: 实现 AI 优化交互**

点击 AIOptimizeBar → dispatch `CreateTaskAIOptimize` → 监听 BLoC 状态 → 弹出 dialog 显示优化结果 → 用户确认后填入表单。

- [ ] **Step 5b: 预览功能（placeholder）**

预览按钮暂时弹出一个简单的 dialog 显示当前表单数据的概览（标题、分类、预算、描述摘要），作为 MVP 版本。后续迭代可做完整的任务卡片预览。

```dart
void _preview() {
  AdaptiveDialogs.showInfoDialog(
    context: context,
    title: context.l10n.createTaskPreview,
    content: '${_titleController.text}\n\n'
        '${context.l10n.createTaskPricingType}: $_pricingType\n'
        '${context.l10n.createTaskMode}: $_taskMode\n\n'
        '${_descriptionController.text.length > 100
            ? '${_descriptionController.text.substring(0, 100)}...'
            : _descriptionController.text}',
  );
}
```

- [ ] **Step 6: 实现底部固定栏**

```dart
// 使用 Scaffold.bottomNavigationBar
bottomNavigationBar: Container(
  padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
  decoration: BoxDecoration(
    color: Theme.of(context).scaffoldBackgroundColor,
    border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.06), width: 0.5)),
  ),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      PrimaryButton(text: context.l10n.createTaskPublishBtn, onPressed: _submitTask),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton.icon(icon: Icon(Icons.drafts_outlined), label: Text(context.l10n.createTaskSaveDraft), onPressed: _saveDraft),
          const SizedBox(width: 20),
          TextButton.icon(icon: Icon(Icons.visibility_outlined), label: Text(context.l10n.createTaskPreview), onPressed: _preview),
        ],
      ),
    ],
  ),
),
```

- [ ] **Step 7: 更新 _submitTask() 传入新字段**

```dart
final request = CreateTaskRequest(
  title: _titleController.text.trim(),
  description: _descriptionController.text.trim().isNotEmpty
      ? _descriptionController.text.trim() : null,
  taskType: _selectedCategory,
  reward: reward,
  currency: _selectedCurrency,
  location: _taskMode == 'online' ? 'Online' : _location,
  latitude: _latitude,
  longitude: _longitude,
  deadline: _deadline,
  images: imageUrls,
  isPublic: 1,
  pricingType: _pricingType,
  taskMode: _taskMode,
  requiredSkills: _selectedSkills,
);
```

- [ ] **Step 8: 发布成功后删除草稿**

在 `BlocConsumer.listener` 中，`state.isSuccess` 时调用 `TaskDraftService.deleteDraft()`。

- [ ] **Step 9: 运行 flutter analyze 确认无报错**

- [ ] **Step 10: Commit**

```bash
git add link2ur/lib/features/tasks/views/create_task_view.dart
git commit -m "feat(ui): rewrite task publish page with card-style form matching mockup A"
```

---

## Task 10: 集成测试和最终验证

**Files:**
- Modify: `link2ur/test/` (可选新增测试)

- [ ] **Step 1: 运行现有测试确认不破坏**

```powershell
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter test
```

- [ ] **Step 2: 手动验证（flutter run -d web-server）**

验证清单：
- [ ] 页面渲染无报错
- [ ] 分类 chips 可点击切换
- [ ] 定价类型三选一正常
- [ ] 任务方式三选一正常
- [ ] 截止时间快捷选项正常，自定义弹出 DatePicker
- [ ] 技能标签可选择/取消/自定义添加
- [ ] 图片上传正常（max 9）
- [ ] 存为草稿 → 退出 → 重进 → 恢复草稿
- [ ] AI 优化按钮点击触发请求
- [ ] 发布任务成功

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete task publish page redesign (mockup A)"
```
