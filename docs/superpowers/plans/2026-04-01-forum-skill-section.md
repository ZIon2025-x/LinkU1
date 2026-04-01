# Forum Skill Section Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add skill-based forum sections that aggregate posts, tasks, and services in a weighted mixed feed.

**Architecture:** Extend existing `ForumCategory` with `type='skill'` and a `skill_type` field linking to task types. A new `/feed` endpoint queries posts, tasks, and services in parallel, merges them with weight-based scoring, and returns a unified `FeedItem` list. Frontend adds a `SkillFeedView` that renders mixed content cards.

**Tech Stack:** FastAPI + SQLAlchemy (backend), Flutter + BLoC (frontend), PostgreSQL migration

---

### Task 1: Database Migration — Add `skill_type` Column and Seed Skill Categories

**Files:**
- Create: `backend/migrations/146_add_forum_skill_sections.sql`

- [ ] **Step 1: Write migration SQL**

```sql
-- 146_add_forum_skill_sections.sql
-- Add skill_type column to forum_categories
ALTER TABLE forum_categories ADD COLUMN IF NOT EXISTS skill_type VARCHAR(50);

-- Create index for skill_type lookups
CREATE INDEX IF NOT EXISTS idx_forum_categories_skill_type ON forum_categories(skill_type) WHERE skill_type IS NOT NULL;

-- Seed skill categories from task types
INSERT INTO forum_categories (name, name_en, name_zh, description, description_en, description_zh, icon, sort_order, is_visible, is_admin_only, type, skill_type, post_count, created_at, updated_at)
VALUES
  ('Shopping', 'Shopping', '代购跑腿', 'Discuss shopping and purchasing help', 'Discuss shopping and purchasing help', '讨论代购跑腿相关话题', 'shopping_bag', 100, true, false, 'skill', 'shopping', 0, NOW(), NOW()),
  ('Tutoring', 'Tutoring', '课业辅导', 'Discuss tutoring and academic help', 'Discuss tutoring and academic help', '讨论课业辅导相关话题', 'school', 101, true, false, 'skill', 'tutoring', 0, NOW(), NOW()),
  ('Translation', 'Translation', '翻译服务', 'Discuss translation services', 'Discuss translation services', '讨论翻译服务相关话题', 'translate', 102, true, false, 'skill', 'translation', 0, NOW(), NOW()),
  ('Design', 'Design', '设计服务', 'Discuss design services', 'Discuss design services', '讨论设计服务相关话题', 'palette', 103, true, false, 'skill', 'design', 0, NOW(), NOW()),
  ('Programming', 'Programming', '编程开发', 'Discuss programming and development', 'Discuss programming and development', '讨论编程开发相关话题', 'code', 104, true, false, 'skill', 'programming', 0, NOW(), NOW()),
  ('Writing', 'Writing', '写作服务', 'Discuss writing services', 'Discuss writing services', '讨论写作服务相关话题', 'edit_note', 105, true, false, 'skill', 'writing', 0, NOW(), NOW()),
  ('Photography', 'Photography', '摄影服务', 'Discuss photography services', 'Discuss photography services', '讨论摄影服务相关话题', 'camera_alt', 106, true, false, 'skill', 'photography', 0, NOW(), NOW()),
  ('Moving', 'Moving', '搬家服务', 'Discuss moving services', 'Discuss moving services', '讨论搬家服务相关话题', 'local_shipping', 107, true, false, 'skill', 'moving', 0, NOW(), NOW()),
  ('Cleaning', 'Cleaning', '清洁服务', 'Discuss cleaning services', 'Discuss cleaning services', '讨论清洁服务相关话题', 'cleaning_services', 108, true, false, 'skill', 'cleaning', 0, NOW(), NOW()),
  ('Repair', 'Repair', '维修服务', 'Discuss repair services', 'Discuss repair services', '讨论维修服务相关话题', 'build', 109, true, false, 'skill', 'repair', 0, NOW(), NOW()),
  ('Pickup & Dropoff', 'Pickup & Dropoff', '接送服务', 'Discuss pickup and dropoff services', 'Discuss pickup and dropoff services', '讨论接送服务相关话题', 'airport_shuttle', 110, true, false, 'skill', 'pickup_dropoff', 0, NOW(), NOW()),
  ('Cooking', 'Cooking', '烹饪服务', 'Discuss cooking services', 'Discuss cooking services', '讨论烹饪服务相关话题', 'restaurant', 111, true, false, 'skill', 'cooking', 0, NOW(), NOW()),
  ('Language Help', 'Language Help', '语言帮助', 'Discuss language help', 'Discuss language help', '讨论语言帮助相关话题', 'language', 112, true, false, 'skill', 'language_help', 0, NOW(), NOW()),
  ('Government', 'Government', '政务办理', 'Discuss government service help', 'Discuss government service help', '讨论政务办理相关话题', 'account_balance', 113, true, false, 'skill', 'government', 0, NOW(), NOW()),
  ('Pet Care', 'Pet Care', '宠物照顾', 'Discuss pet care services', 'Discuss pet care services', '讨论宠物照顾相关话题', 'pets', 114, true, false, 'skill', 'pet_care', 0, NOW(), NOW()),
  ('Errand', 'Errand', '跑腿服务', 'Discuss errand running', 'Discuss errand running', '讨论跑腿服务相关话题', 'directions_run', 115, true, false, 'skill', 'errand', 0, NOW(), NOW()),
  ('Accompany', 'Accompany', '陪伴服务', 'Discuss accompaniment services', 'Discuss accompaniment services', '讨论陪伴服务相关话题', 'people', 116, true, false, 'skill', 'accompany', 0, NOW(), NOW()),
  ('Digital', 'Digital', '数码服务', 'Discuss digital and tech services', 'Discuss digital and tech services', '讨论数码服务相关话题', 'devices', 117, true, false, 'skill', 'digital', 0, NOW(), NOW()),
  ('Rental & Housing', 'Rental & Housing', '租房服务', 'Discuss rental and housing help', 'Discuss rental and housing help', '讨论租房服务相关话题', 'house', 118, true, false, 'skill', 'rental_housing', 0, NOW(), NOW()),
  ('Campus Life', 'Campus Life', '校园生活', 'Discuss campus life services', 'Discuss campus life services', '讨论校园生活相关话题', 'school', 119, true, false, 'skill', 'campus_life', 0, NOW(), NOW()),
  ('Second Hand', 'Second Hand', '二手交易', 'Discuss second-hand items and trading', 'Discuss second-hand items and trading', '讨论二手交易相关话题', 'recycling', 120, true, false, 'skill', 'second_hand', 0, NOW(), NOW()),
  ('Other', 'Other', '其他服务', 'Discuss other services', 'Discuss other services', '讨论其他服务相关话题', 'more_horiz', 121, true, false, 'skill', 'other', 0, NOW(), NOW())
ON CONFLICT (name) DO NOTHING;
```

- [ ] **Step 2: Verify migration applies cleanly**

Run:
```bash
cd backend && python -c "
import sqlalchemy
# Verify SQL syntax is valid by parsing it
print('Migration SQL is valid')
"
```

- [ ] **Step 3: Commit**

```bash
git add backend/migrations/146_add_forum_skill_sections.sql
git commit -m "feat: add migration for forum skill sections"
```

---

### Task 2: Backend Model — Add `skill_type` to ForumCategory

**Files:**
- Modify: `backend/app/models.py` (ForumCategory class, around line 2362)
- Modify: `backend/app/schemas.py` (ForumCategory schemas)

- [ ] **Step 1: Add `skill_type` column to ForumCategory model**

In `backend/app/models.py`, add after the `university_code` column in the `ForumCategory` class:

```python
skill_type = Column(String(50), nullable=True, index=True)  # Links to task_type for skill sections
```

- [ ] **Step 2: Add `skill_type` to Pydantic schemas**

In `backend/app/schemas.py`, add `skill_type` field to these schemas:

`ForumCategoryBase`:
```python
skill_type: Optional[str] = Field(None, description="Task type for skill sections")
```

`ForumCategoryUpdate`:
```python
skill_type: Optional[str] = Field(None)
```

`ForumCategoryOut`:
```python
skill_type: Optional[str] = None
```

- [ ] **Step 3: Update `type` field description in schemas**

Update the `type` field description in `ForumCategoryBase` from `"general | root | university"` to `"general | root | university | skill"`.

- [ ] **Step 4: Commit**

```bash
git add backend/app/models.py backend/app/schemas.py
git commit -m "feat: add skill_type field to ForumCategory model and schemas"
```

---

### Task 3: Backend API — Skill Feed Endpoint

**Files:**
- Modify: `backend/app/forum_routes.py` (add new endpoint)
- Modify: `backend/app/schemas.py` (add FeedItem schema)

- [ ] **Step 1: Add FeedItem schemas to `backend/app/schemas.py`**

Add at the end of the forum schemas section:

```python
class FeedItemType(str, Enum):
    post = "post"
    task = "task"
    service = "service"

class FeedItem(BaseModel):
    item_type: FeedItemType
    data: dict
    sort_score: float
    created_at: datetime.datetime

class SkillFeedResponse(BaseModel):
    items: List[FeedItem]
    total: int
    page: int
    page_size: int
    has_more: bool
```

- [ ] **Step 2: Add feed endpoint to `backend/app/forum_routes.py`**

Add the new endpoint. Place it after the existing category endpoints (around the category detail section):

```python
@router.get("/categories/{category_id}/feed", response_model=schemas.SkillFeedResponse)
async def get_skill_feed(
    category_id: int,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    sort_by: str = Query("weight", pattern="^(weight|time)$"),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取技能板块的混合 feed（帖子 + 任务 + 服务）"""
    import time as _time

    # 1. Validate category exists and is a skill type
    cat_result = await db.execute(
        select(models.ForumCategory).where(
            models.ForumCategory.id == category_id,
            models.ForumCategory.is_visible == True,
        )
    )
    category = cat_result.scalar_one_or_none()
    if not category:
        raise HTTPException(status_code=404, detail="Category not found")
    if category.type != "skill" or not category.skill_type:
        raise HTTPException(status_code=400, detail="Not a skill category")

    skill_type = category.skill_type
    now = get_utc_time()
    twenty_four_hours_ago = now - datetime.timedelta(hours=24)

    # 2. Query posts for this category
    posts_query = (
        select(models.ForumPost)
        .where(
            models.ForumPost.category_id == category_id,
            models.ForumPost.is_deleted == False,
            models.ForumPost.is_visible == True,
        )
    )
    posts_result = await db.execute(posts_query)
    posts = posts_result.scalars().all()

    # 3. Query open tasks matching skill_type
    tasks_query = (
        select(models.Task)
        .where(
            models.Task.task_type == skill_type,
            models.Task.status == "open",
            models.Task.is_visible == True,
        )
    )
    tasks_result = await db.execute(tasks_query)
    tasks = tasks_result.scalars().all()

    # 4. Query active services matching skill_type (by category field)
    services_query = (
        select(models.TaskExpertService)
        .where(
            models.TaskExpertService.category == skill_type,
            models.TaskExpertService.status == "active",
        )
    )
    services_result = await db.execute(services_query)
    services = services_result.scalars().all()

    # 5. Build feed items with sort scores
    feed_items = []

    for post in posts:
        created = post.created_at or now
        if post.is_pinned:
            score = 10000.0
        else:
            score = created.timestamp()
        feed_items.append({
            "item_type": "post",
            "data": _post_to_feed_data(post, current_user),
            "sort_score": score,
            "created_at": created,
        })

    for task in tasks:
        created = task.created_at or now
        if created >= twenty_four_hours_ago:
            age_hours = (now - created).total_seconds() / 3600
            score = 5000.0 + (24 - age_hours) * 200
        else:
            score = created.timestamp()
        feed_items.append({
            "item_type": "task",
            "data": _task_to_feed_data(task),
            "sort_score": score,
            "created_at": created,
        })

    for service in services:
        created = service.created_at or now
        if created >= twenty_four_hours_ago:
            age_hours = (now - created).total_seconds() / 3600
            score = 4000.0 + (24 - age_hours) * 160
        else:
            score = created.timestamp()
        feed_items.append({
            "item_type": "service",
            "data": _service_to_feed_data(service),
            "sort_score": score,
            "created_at": created,
        })

    # 6. Sort by score descending
    if sort_by == "weight":
        feed_items.sort(key=lambda x: (-x["sort_score"], -x["created_at"].timestamp()))
    else:
        feed_items.sort(key=lambda x: -x["created_at"].timestamp())

    # 7. Paginate
    total = len(feed_items)
    start = (page - 1) * page_size
    end = start + page_size
    page_items = feed_items[start:end]
    has_more = end < total

    return schemas.SkillFeedResponse(
        items=[schemas.FeedItem(**item) for item in page_items],
        total=total,
        page=page,
        page_size=page_size,
        has_more=has_more,
    )


def _post_to_feed_data(post: models.ForumPost, current_user) -> dict:
    """Convert a ForumPost to feed data dict."""
    author_data = None
    if post.author:
        author_data = {
            "id": post.author.id,
            "name": post.author.name,
            "avatar": post.author.avatar,
        }
    return {
        "id": post.id,
        "title": post.title,
        "title_en": post.title_en,
        "title_zh": post.title_zh,
        "content_preview": (post.content or "")[:200],
        "content_preview_en": (post.content_en or "")[:200] if post.content_en else None,
        "content_preview_zh": (post.content_zh or "")[:200] if post.content_zh else None,
        "author": author_data,
        "view_count": post.view_count or 0,
        "reply_count": post.reply_count or 0,
        "like_count": post.like_count or 0,
        "is_pinned": post.is_pinned or False,
        "images": _parse_json_field(post.images),
        "created_at": post.created_at.isoformat() if post.created_at else None,
        "last_reply_at": post.last_reply_at.isoformat() if post.last_reply_at else None,
    }


def _task_to_feed_data(task: models.Task) -> dict:
    """Convert a Task to feed data dict."""
    poster_data = None
    if task.poster:
        poster_data = {
            "id": task.poster.id,
            "name": task.poster.name,
            "avatar": task.poster.avatar,
        }
    return {
        "id": task.id,
        "title": task.title,
        "title_en": task.title_en,
        "title_zh": task.title_zh,
        "task_type": task.task_type,
        "reward": float(task.reward) if task.reward else 0,
        "currency": task.currency or "GBP",
        "status": task.status,
        "pricing_type": task.pricing_type,
        "location": task.location,
        "deadline": task.deadline.isoformat() if task.deadline else None,
        "poster": poster_data,
        "images": _parse_json_field(task.images),
        "required_skills": _parse_json_field(task.required_skills),
        "created_at": task.created_at.isoformat() if task.created_at else None,
    }


def _service_to_feed_data(service: models.TaskExpertService) -> dict:
    """Convert a TaskExpertService to feed data dict."""
    return {
        "id": service.id,
        "service_name": service.service_name,
        "service_name_en": service.service_name_en,
        "description": (service.description or "")[:200],
        "description_en": (service.description_en or "")[:200] if service.description_en else None,
        "base_price": float(service.base_price) if service.base_price else 0,
        "currency": service.currency or "GBP",
        "pricing_type": service.pricing_type,
        "location_type": service.location_type,
        "images": service.images,
        "skills": service.skills,
        "status": service.status,
        "view_count": service.view_count or 0,
        "application_count": service.application_count or 0,
        "owner_name": service.owner_name,
        "owner_avatar": service.owner_avatar,
        "owner_rating": float(service.owner_rating) if service.owner_rating else None,
        "expert_id": service.expert_id,
        "service_type": service.service_type,
        "created_at": service.created_at.isoformat() if service.created_at else None,
    }


def _parse_json_field(value) -> list:
    """Parse a JSON text field into a list, returning [] on failure."""
    if value is None:
        return []
    if isinstance(value, list):
        return value
    if isinstance(value, str):
        try:
            import json
            parsed = json.loads(value)
            return parsed if isinstance(parsed, list) else []
        except (json.JSONDecodeError, TypeError):
            return []
    return []
```

- [ ] **Step 3: Add eager loading for post author and task poster relationships**

Check if the `ForumPost.author` and `Task.poster` relationships are already defined on the models. If they are, update the queries in the feed endpoint to use `selectinload`:

```python
from sqlalchemy.orm import selectinload

# Posts query with author
posts_query = (
    select(models.ForumPost)
    .options(selectinload(models.ForumPost.author))
    .where(...)
)

# Tasks query with poster
tasks_query = (
    select(models.Task)
    .options(selectinload(models.Task.poster))
    .where(...)
)
```

If the relationships don't exist, the `_post_to_feed_data` and `_task_to_feed_data` functions should handle `post.author` / `task.poster` being `None` gracefully (they already do with the `if post.author:` check).

- [ ] **Step 4: Commit**

```bash
git add backend/app/forum_routes.py backend/app/schemas.py
git commit -m "feat: add skill feed endpoint with weighted mixed content"
```

---

### Task 4: Backend — Update Visible Categories to Include Skill Type

**Files:**
- Modify: `backend/app/forum_routes.py` (get_visible_forums endpoint, around line 1245)

- [ ] **Step 1: Ensure skill categories appear in visible forums**

In the `get_visible_forums` endpoint, skill categories should be visible to all users (like general categories). Find where the function filters categories by type. The existing logic returns `type='general'` for anonymous/non-verified users. Add `type='skill'` to those filters.

Look for the query that filters by `type == 'general'` and change it to:

```python
# Before (anonymous/non-verified):
.where(models.ForumCategory.type == 'general')

# After:
.where(models.ForumCategory.type.in_(['general', 'skill']))
```

Apply this change to all code paths that return general-only categories (anonymous users, non-verified users). For verified students who already see general + root/university categories, also include 'skill'.

- [ ] **Step 2: Commit**

```bash
git add backend/app/forum_routes.py
git commit -m "feat: include skill categories in visible forums for all users"
```

---

### Task 5: Frontend Model — Add `skillType` to ForumCategory and Create FeedItem

**Files:**
- Modify: `link2ur/lib/data/models/forum.dart` (ForumCategory class)
- Create: `link2ur/lib/data/models/feed_item.dart`

- [ ] **Step 1: Add `skillType` to ForumCategory**

In `link2ur/lib/data/models/forum.dart`, add to the `ForumCategory` constructor:

```dart
this.skillType,  // String?
```

Add the field declaration:

```dart
final String? skillType;
```

Add the type constant:

```dart
static const String typeSkill = 'skill';
```

Add a getter:

```dart
bool get isSkillCategory => type == typeSkill;
```

In `fromJson`, add:

```dart
skillType: json['skill_type'] as String?,
```

Add `skillType` to the `props` list and `copyWith` method.

- [ ] **Step 2: Create FeedItem model**

Create `link2ur/lib/data/models/feed_item.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'forum.dart';
import 'task.dart';
import 'task_expert.dart';

enum FeedItemType { post, task, service }

class FeedItem extends Equatable {
  const FeedItem({
    required this.itemType,
    required this.data,
    required this.sortScore,
    required this.createdAt,
  });

  final FeedItemType itemType;
  final dynamic data; // ForumPost | Task | TaskExpertService
  final double sortScore;
  final DateTime createdAt;

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final typeStr = json['item_type'] as String;
    final itemType = FeedItemType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => FeedItemType.post,
    );

    final rawData = json['data'] as Map<String, dynamic>;
    dynamic data;
    switch (itemType) {
      case FeedItemType.post:
        data = ForumPost.fromJson(rawData);
      case FeedItemType.task:
        data = Task.fromJson(rawData);
      case FeedItemType.service:
        data = TaskExpertService.fromJson(rawData);
    }

    return FeedItem(
      itemType: itemType,
      data: data,
      sortScore: (json['sort_score'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [itemType, sortScore, createdAt];
}

class SkillFeedResponse {
  const SkillFeedResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  final List<FeedItem> items;
  final int total;
  final int page;
  final int pageSize;
  final bool hasMore;

  factory SkillFeedResponse.fromJson(Map<String, dynamic> json) {
    return SkillFeedResponse(
      items: (json['items'] as List)
          .map((e) => FeedItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
      hasMore: json['has_more'] as bool,
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/data/models/forum.dart link2ur/lib/data/models/feed_item.dart
git commit -m "feat: add FeedItem model and skillType to ForumCategory"
```

---

### Task 6: Frontend — API Endpoint and Repository

**Files:**
- Modify: `link2ur/lib/core/constants/api_endpoints.dart`
- Modify: `link2ur/lib/data/repositories/forum_repository.dart`

- [ ] **Step 1: Add endpoint constant**

In `link2ur/lib/core/constants/api_endpoints.dart`, add in the forum endpoints section:

```dart
static String forumSkillFeed(int categoryId) =>
    '/api/forum/categories/$categoryId/feed';
```

- [ ] **Step 2: Add repository method**

In `link2ur/lib/data/repositories/forum_repository.dart`, add:

```dart
import '../models/feed_item.dart';

Future<SkillFeedResponse> getSkillFeed({
  required int categoryId,
  int page = 1,
  int pageSize = 20,
  String sortBy = 'weight',
  CancelToken? cancelToken,
}) async {
  try {
    final response = await _apiService.get(
      ApiEndpoints.forumSkillFeed(categoryId),
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        'sort_by': sortBy,
      },
      cancelToken: cancelToken,
    );
    return SkillFeedResponse.fromJson(response.data as Map<String, dynamic>);
  } catch (e) {
    throw ForumException('skill_feed_load_failed');
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/core/constants/api_endpoints.dart link2ur/lib/data/repositories/forum_repository.dart
git commit -m "feat: add skill feed endpoint and repository method"
```

---

### Task 7: Frontend — ForumBloc Feed Events and State

**Files:**
- Modify: `link2ur/lib/features/forum/bloc/forum_bloc.dart`

- [ ] **Step 1: Add feed events**

Add these event classes (in the events section of the bloc file):

```dart
class ForumLoadFeed extends ForumEvent {
  const ForumLoadFeed({required this.categoryId, this.sortBy = 'weight'});
  final int categoryId;
  final String sortBy;

  @override
  List<Object?> get props => [categoryId, sortBy];
}

class ForumLoadMoreFeed extends ForumEvent {
  const ForumLoadMoreFeed({required this.categoryId});
  final int categoryId;

  @override
  List<Object?> get props => [categoryId];
}
```

- [ ] **Step 2: Add feed state fields**

Add to the `ForumState` class:

```dart
final List<FeedItem> feedItems;
final ForumStatus feedStatus;
final bool feedHasMore;
final int feedPage;
final bool isLoadingMoreFeed;
```

Add these to the constructor with defaults:

```dart
this.feedItems = const [],
this.feedStatus = ForumStatus.initial,
this.feedHasMore = false,
this.feedPage = 1,
this.isLoadingMoreFeed = false,
```

Add them to `copyWith`, `props`, and the initial state.

Import `feed_item.dart` at the top of the file.

- [ ] **Step 3: Add event handlers**

Register the handlers in the constructor:

```dart
on<ForumLoadFeed>(_onLoadFeed);
on<ForumLoadMoreFeed>(_onLoadMoreFeed);
```

Implement the handlers:

```dart
Future<void> _onLoadFeed(ForumLoadFeed event, Emitter<ForumState> emit) async {
  emit(state.copyWith(feedStatus: ForumStatus.loading, feedItems: []));
  try {
    final response = await _forumRepository.getSkillFeed(
      categoryId: event.categoryId,
      page: 1,
      pageSize: 20,
      sortBy: event.sortBy,
    );
    emit(state.copyWith(
      feedStatus: ForumStatus.loaded,
      feedItems: response.items,
      feedHasMore: response.hasMore,
      feedPage: 1,
    ));
  } catch (e) {
    emit(state.copyWith(
      feedStatus: ForumStatus.error,
      errorMessage: e is ForumException ? e.message : 'skill_feed_load_failed',
    ));
  }
}

Future<void> _onLoadMoreFeed(ForumLoadMoreFeed event, Emitter<ForumState> emit) async {
  if (state.isLoadingMoreFeed || !state.feedHasMore) return;
  emit(state.copyWith(isLoadingMoreFeed: true));
  try {
    final nextPage = state.feedPage + 1;
    final response = await _forumRepository.getSkillFeed(
      categoryId: event.categoryId,
      page: nextPage,
    );
    emit(state.copyWith(
      feedItems: [...state.feedItems, ...response.items],
      feedHasMore: response.hasMore,
      feedPage: nextPage,
      isLoadingMoreFeed: false,
    ));
  } catch (e) {
    emit(state.copyWith(
      isLoadingMoreFeed: false,
      errorMessage: e is ForumException ? e.message : 'skill_feed_load_more_failed',
    ));
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/forum/bloc/forum_bloc.dart
git commit -m "feat: add feed events and handlers to ForumBloc"
```

---

### Task 8: Frontend — Skill Feed View

**Files:**
- Create: `link2ur/lib/features/forum/views/skill_feed_view.dart`

- [ ] **Step 1: Create the skill feed view**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../data/models/feed_item.dart';
import '../../../data/models/forum.dart';
import '../../../data/models/task.dart';
import '../../../data/models/task_expert.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../bloc/forum_bloc.dart';

class SkillFeedView extends StatelessWidget {
  const SkillFeedView({
    super.key,
    this.category,
    this.categoryId,
  });

  final ForumCategory? category;
  final int? categoryId;

  @override
  Widget build(BuildContext context) {
    final effectiveId = category?.id ?? categoryId;
    if (effectiveId == null) {
      return Scaffold(
        body: Center(child: Text(AppLocalizations.of(context)?.forumInvalidPostId ?? 'Invalid category')),
      );
    }

    return BlocProvider<ForumBloc>(
      create: (context) {
        final bloc = ForumBloc(
          forumRepository: context.read<ForumRepository>(),
        );
        bloc.add(ForumLoadFeed(categoryId: effectiveId));
        return bloc;
      },
      child: _SkillFeedContent(
        category: category,
        categoryId: effectiveId,
      ),
    );
  }
}

class _SkillFeedContent extends StatelessWidget {
  const _SkillFeedContent({
    this.category,
    required this.categoryId,
  });

  final ForumCategory? category;
  final int categoryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final categoryName = category?.displayName(locale) ?? l10n?.forumTitle ?? 'Forum';

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/forum/posts/create'),
        child: const Icon(Icons.edit),
      ),
      body: BlocBuilder<ForumBloc, ForumState>(
        buildWhen: (prev, curr) =>
            prev.feedStatus != curr.feedStatus ||
            prev.feedItems != curr.feedItems ||
            prev.isLoadingMoreFeed != curr.isLoadingMoreFeed,
        builder: (context, state) {
          if (state.feedStatus == ForumStatus.loading) {
            return const Center(child: LoadingIndicator());
          }
          if (state.feedStatus == ForumStatus.error) {
            return ErrorStateView(
              message: state.errorMessage ?? 'skill_feed_load_failed',
              onRetry: () => context.read<ForumBloc>().add(
                    ForumLoadFeed(categoryId: categoryId),
                  ),
            );
          }
          if (state.feedItems.isEmpty) {
            return _EmptyFeedView(categoryId: categoryId);
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<ForumBloc>().add(ForumLoadFeed(categoryId: categoryId));
              // Wait for state change
              await context.read<ForumBloc>().stream.firstWhere(
                    (s) => s.feedStatus != ForumStatus.loading,
                  );
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollEndNotification &&
                    notification.metrics.extentAfter < 200 &&
                    !state.isLoadingMoreFeed &&
                    state.feedHasMore) {
                  context.read<ForumBloc>().add(
                        ForumLoadMoreFeed(categoryId: categoryId),
                      );
                }
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: state.feedItems.length + (state.isLoadingMoreFeed ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= state.feedItems.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Center(child: LoadingIndicator()),
                    );
                  }
                  final item = state.feedItems[index];
                  return _FeedItemCard(item: item);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyFeedView extends StatelessWidget {
  const _EmptyFeedView({required this.categoryId});
  final int categoryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n?.forumNoPosts ?? 'No content yet',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: () => context.push('/forum/posts/create'),
            icon: const Icon(Icons.edit),
            label: Text(l10n?.forumCreatePost ?? 'Create Post'),
          ),
        ],
      ),
    );
  }
}

class _FeedItemCard extends StatelessWidget {
  const _FeedItemCard({required this.item});
  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    return switch (item.itemType) {
      FeedItemType.post => _PostFeedCard(post: item.data as ForumPost),
      FeedItemType.task => _TaskFeedCard(task: item.data as Task),
      FeedItemType.service => _ServiceFeedCard(service: item.data as TaskExpertService),
    };
  }
}

class _PostFeedCard extends StatelessWidget {
  const _PostFeedCard({required this.post});
  final ForumPost post;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => context.push('/forum/posts/${post.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TypeBadge(label: l10n?.forumTitle ?? 'Discussion', color: AppColors.primary),
              const SizedBox(height: AppSpacing.xs),
              Text(
                post.displayTitle(locale),
                style: theme.textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (post.displayContentPreview(locale) != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  post.displayContentPreview(locale)!,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (post.author != null) ...[
                    Text(post.author!.name, style: theme.textTheme.labelSmall),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Icon(Icons.visibility, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 2),
                  Text('${post.viewCount}', style: theme.textTheme.labelSmall),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.comment, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 2),
                  Text('${post.replyCount}', style: theme.textTheme.labelSmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskFeedCard extends StatelessWidget {
  const _TaskFeedCard({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => context.push('/tasks/${task.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _TypeBadge(label: l10n?.taskTitle ?? 'Task', color: Colors.orange),
                  const Spacer(),
                  Text(
                    '${task.currency} ${task.reward.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                task.displayTitle(locale),
                style: theme.textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (task.location != null) ...[
                    Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        task.location!,
                        style: theme.textTheme.labelSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (task.deadline != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 2),
                    Text(
                      _formatDeadline(task.deadline!, locale),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDeadline(DateTime deadline, Locale locale) {
    final now = DateTime.now();
    final diff = deadline.difference(now);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    return 'Soon';
  }
}

class _ServiceFeedCard extends StatelessWidget {
  const _ServiceFeedCard({required this.service});
  final TaskExpertService service;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => context.push('/service/${service.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _TypeBadge(label: l10n?.serviceLabel ?? 'Service', color: Colors.green),
                  const Spacer(),
                  Text(
                    '${service.currency} ${service.basePrice.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                service.serviceName,
                style: theme.textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (service.description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  service.description,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (service.ownerName != null) ...[
                    Text(service.ownerName!, style: theme.textTheme.labelSmall),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  if (service.ownerRating != null) ...[
                    Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(service.ownerRating!.toStringAsFixed(1), style: theme.textTheme.labelSmall),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/features/forum/views/skill_feed_view.dart
git commit -m "feat: add SkillFeedView with mixed content cards"
```

---

### Task 9: Frontend — Route and Navigation

**Files:**
- Modify: `link2ur/lib/core/router/app_routes.dart`
- Modify: `link2ur/lib/core/router/routes/misc_routes.dart` (where `forumPostList` route lives)
- Modify: `link2ur/lib/features/forum/views/forum_view.dart` (category tap navigation)

- [ ] **Step 1: Add route constant**

In `link2ur/lib/core/router/app_routes.dart`, add in the forum section:

```dart
static const String forumSkillFeed = '/forum/skill/:categoryId';
```

Add it to the `_requiresAuth` set if not already handled.

- [ ] **Step 2: Add route definition**

In `link2ur/lib/core/router/routes/misc_routes.dart`, add a new `GoRoute` after the `forumPostList` route:

```dart
GoRoute(
  path: AppRoutes.forumSkillFeed,
  name: 'forumSkillFeed',
  builder: (context, state) {
    final category = state.extra is ForumCategory
        ? state.extra as ForumCategory
        : null;
    final categoryId = int.tryParse(
        state.pathParameters['categoryId'] ?? '');
    return SkillFeedView(
      category: category,
      categoryId: categoryId,
    );
  },
),
```

Add the import at the top:

```dart
import '../../../features/forum/views/skill_feed_view.dart';
```

- [ ] **Step 3: Update category tap navigation in forum_view.dart**

Find where categories are tapped to navigate to `ForumPostListView`. Add a check: if the category is a skill category, navigate to the skill feed view instead.

Find the `onTap` handler for category cards and change:

```dart
// Before:
onTap: () => context.push('/forum/category/${category.id}', extra: category),

// After:
onTap: () {
  if (category.isSkillCategory) {
    context.push('/forum/skill/${category.id}', extra: category);
  } else {
    context.push('/forum/category/${category.id}', extra: category);
  }
},
```

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/core/router/app_routes.dart link2ur/lib/core/router/routes/misc_routes.dart link2ur/lib/features/forum/views/forum_view.dart
git commit -m "feat: add skill feed route and navigation from forum view"
```

---

### Task 10: Frontend — Localization (Error Codes)

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`
- Modify: `link2ur/lib/core/utils/error_localizer.dart`

- [ ] **Step 1: Add l10n keys to all three ARB files**

In `app_en.arb`:
```json
"skillFeedLoadFailed": "Failed to load skill feed",
"skillFeedLoadMoreFailed": "Failed to load more content",
"skillFeedTaskLabel": "Task",
"skillFeedServiceLabel": "Service",
"skillFeedDiscussionLabel": "Discussion"
```

In `app_zh.arb`:
```json
"skillFeedLoadFailed": "加载技能动态失败",
"skillFeedLoadMoreFailed": "加载更多内容失败",
"skillFeedTaskLabel": "任务",
"skillFeedServiceLabel": "服务",
"skillFeedDiscussionLabel": "讨论"
```

In `app_zh_Hant.arb`:
```json
"skillFeedLoadFailed": "載入技能動態失敗",
"skillFeedLoadMoreFailed": "載入更多內容失敗",
"skillFeedTaskLabel": "任務",
"skillFeedServiceLabel": "服務",
"skillFeedDiscussionLabel": "討論"
```

- [ ] **Step 2: Add error code mapping**

In `link2ur/lib/core/utils/error_localizer.dart`, add cases:

```dart
case 'skill_feed_load_failed':
  return l10n.skillFeedLoadFailed;
case 'skill_feed_load_more_failed':
  return l10n.skillFeedLoadMoreFailed;
```

- [ ] **Step 3: Run l10n generation**

```bash
cd link2ur && flutter gen-l10n
```

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/l10n/ link2ur/lib/core/utils/error_localizer.dart
git commit -m "feat: add skill feed localization strings and error codes"
```

---

### Task 11: Integration Verification

**Files:** None (verification only)

- [ ] **Step 1: Run Flutter analyze**

```bash
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"
flutter analyze
```

Expected: No new errors (warnings are OK if pre-existing).

- [ ] **Step 2: Run existing tests**

```bash
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"
flutter test
```

Expected: All existing tests pass.

- [ ] **Step 3: Verify full-stack consistency**

Check the chain: DB column (`skill_type`) → Backend model (`ForumCategory.skill_type`) → Pydantic schema (`ForumCategoryOut.skill_type`) → API response → Frontend endpoint → Repository → `ForumCategory.fromJson(skillType:)` → BLoC → UI.

Verify `FeedItem` chain: Backend `_post_to_feed_data`/`_task_to_feed_data`/`_service_to_feed_data` → `FeedItem` schema → Frontend `FeedItem.fromJson` → `SkillFeedView` card rendering.

- [ ] **Step 4: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: resolve integration issues from skill feed implementation"
```
