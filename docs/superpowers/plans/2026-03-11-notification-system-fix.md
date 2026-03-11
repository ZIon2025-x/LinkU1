# Notification System Fix — 系统消息 & 互动消息

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the notification system so both system messages and interaction messages (forum + leaderboard) display correctly with proper real-time updates, pagination, navigation, and read status.

**Architecture:** Backend adds a unified interaction notifications endpoint that converts ForumNotification records into NotificationOut-compatible format and merges with leaderboard notifications. Backend also adds leaderboard interaction notification creation (vote/like). Unread count endpoint returns both system and forum counts. Both system and interaction endpoints use "unread-first" pagination: page 1 returns ALL unread + first batch of read; subsequent pages return read only. Flutter simplifies to call one endpoint per tab with full pagination support.

**Tech Stack:** Python/FastAPI (backend), Flutter/BLoC (frontend), SQLAlchemy async (ORM)

---

## Chunk 1: Backend Changes

### Task 1: Add leaderboard interaction notification creation

When a user votes on a leaderboard item or likes a vote comment, create a notification for the item owner / comment author. Skip self-notifications.

**Files:**
- Modify: `backend/app/custom_leaderboard_routes.py:1987-2021` (vote_item, new vote branch)
- Modify: `backend/app/custom_leaderboard_routes.py:2145-2165` (like_vote_comment, new like branch)

- [ ] **Step 1: Add notification on new vote**

In `vote_item()`, after the new vote is committed (after line 2021 `await db.commit()`), add notification creation. Only notify item owner, not self:

```python
# After: await db.commit() (line 2021)
# Add: notification for item owner on new vote
if item.submitted_by != current_user.id:
    try:
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=item.submitted_by,
            notification_type="leaderboard_vote",
            title="收到新投票",
            content=f"有人在排行榜「{leaderboard.name}」中为「{item.name}」投了一票",
            title_en=f"New vote on '{item.name}' in leaderboard '{leaderboard.name}'",
            content_en=f"Someone voted on '{item.name}' in leaderboard '{leaderboard.name}'",
            related_id=str(item.id),
            related_type="leaderboard_item",
        )
    except Exception as e:
        logger.warning(f"Failed to create leaderboard vote notification: {e}")
```

Place this block ONLY inside the `else:` branch (new vote, line 1987), NOT for vote changes or removals.

- [ ] **Step 2: Add notification on like vote comment**

In `like_vote_comment()`, after the new like is committed (after line 2159 `await db.commit()`), add notification. Only notify comment author, not self:

```python
# After: await db.commit() (line 2159, inside the else: new like branch)
# Add: notification for comment author
if vote.user_id != current_user.id:
    try:
        # Get item and leaderboard for context
        item = await db.get(models.LeaderboardItem, vote.item_id)
        leaderboard_name = ""
        if item:
            lb = await db.get(models.CustomLeaderboard, item.leaderboard_id)
            leaderboard_name = lb.name if lb else ""
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=vote.user_id,
            notification_type="leaderboard_like",
            title="留言被点赞",
            content=f"有人在排行榜「{leaderboard_name}」中点赞了你的留言",
            title_en=f"Someone liked your comment in leaderboard '{leaderboard_name}'",
            content_en=f"Someone liked your comment in leaderboard '{leaderboard_name}'",
            related_id=str(vote.item_id),
            related_type="leaderboard_item",
        )
    except Exception as e:
        logger.warning(f"Failed to create leaderboard like notification: {e}")
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/custom_leaderboard_routes.py
git commit -m "feat(notification): create notifications for leaderboard votes and likes"
```

---

### Task 2: Add unified interaction notifications endpoint

Create `GET /api/users/notifications/interaction` that merges forum notifications (converted to NotificationOut format) with leaderboard interaction notifications from the system table.

**Files:**
- Modify: `backend/app/routers.py` — add new endpoint after line 5788

- [ ] **Step 1: Add the endpoint**

Insert after the `get_unread_notification_count_api` function (after line 5788):

```python
@router.get("/notifications/interaction")
async def get_interaction_notifications_api(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """
    获取互动消息（统一接口）
    合并论坛通知 + 排行榜互动通知，按时间倒序排列，支持分页。
    论坛通知从 ForumNotification 表转换为统一格式。
    排行榜互动通知（leaderboard_vote/like）从 Notification 表筛选。
    """
    from sqlalchemy.orm import selectinload
    from app.forum_routes import visible_forums

    # === 1. 查论坛通知（ForumNotification 表）===
    forum_query = (
        select(models.ForumNotification)
        .where(models.ForumNotification.to_user_id == current_user.id)
        .order_by(models.ForumNotification.created_at.desc())
        .options(selectinload(models.ForumNotification.from_user))
    )
    forum_result = await db.execute(forum_query)
    all_forum = forum_result.scalars().all()

    # 过滤学校板块（与 forum_routes.get_notifications 保持一致）
    visible_category_ids = []
    general_result = await db.execute(
        select(models.ForumCategory.id).where(
            models.ForumCategory.type == 'general',
            models.ForumCategory.is_visible == True
        )
    )
    visible_category_ids.extend([r[0] for r in general_result.all()])
    school_ids = await visible_forums(current_user, db)
    visible_category_ids.extend(school_ids)

    # 批量查 post/reply 的 category_id
    post_notifs = [n for n in all_forum if n.target_type == "post"]
    reply_notifs = [n for n in all_forum if n.target_type == "reply"]

    post_category_map = {}
    if post_notifs:
        res = await db.execute(
            select(models.ForumPost.id, models.ForumPost.category_id)
            .where(models.ForumPost.id.in_([n.target_id for n in post_notifs]))
        )
        post_category_map = {r[0]: r[1] for r in res.all()}

    reply_post_map = {}
    reply_category_map = {}
    if reply_notifs:
        res = await db.execute(
            select(models.ForumReply.id, models.ForumReply.post_id)
            .where(models.ForumReply.id.in_([n.target_id for n in reply_notifs]))
        )
        reply_post_map = {r[0]: r[1] for r in res.all()}
        if reply_post_map:
            res2 = await db.execute(
                select(models.ForumPost.id, models.ForumPost.category_id)
                .where(models.ForumPost.id.in_(list(reply_post_map.values())))
            )
            pid_to_cat = {r[0]: r[1] for r in res2.all()}
            reply_category_map = {
                rid: pid_to_cat.get(pid)
                for rid, pid in reply_post_map.items()
                if pid in pid_to_cat
            }

    # 过滤 + 转换论坛通知为 NotificationOut 兼容格式
    forum_converted = []
    # notification_type 到中文/英文描述
    _type_labels = {
        "reply_post": ("回复了你的帖子", "replied to your post"),
        "reply_reply": ("回复了你的评论", "replied to your comment"),
        "like_post": ("点赞了你的帖子", "liked your post"),
        "feature_post": ("精选了你的帖子", "featured your post"),
        "pin_post": ("置顶了你的帖子", "pinned your post"),
    }

    for n in all_forum:
        # 权限检查
        if n.target_type == "post":
            cat_id = post_category_map.get(n.target_id)
        else:
            cat_id = reply_category_map.get(n.target_id)
        if not cat_id or cat_id not in visible_category_ids:
            continue

        # 确定 post_id（用于导航）
        if n.target_type == "reply":
            post_id = reply_post_map.get(n.target_id)
        else:
            post_id = n.target_id

        from_name = n.from_user.name if n.from_user else "某人"
        from_name_en = n.from_user.name if n.from_user else "Someone"
        label_zh, label_en = _type_labels.get(
            n.notification_type, ("与你互动", "interacted with you")
        )

        forum_converted.append({
            "id": n.id,
            "user_id": current_user.id,
            "type": f"forum_{n.notification_type}",
            "title": f"{from_name}{label_zh}",
            "content": f"{from_name}{label_zh}",
            "title_en": f"{from_name_en} {label_en}",
            "content_en": f"{from_name_en} {label_en}",
            "related_id": post_id,
            "related_type": "forum_post_id",
            "is_read": 1 if n.is_read else 0,
            "created_at": n.created_at,
            "task_id": None,
            "variables": None,
        })

    # === 2. 查排行榜互动通知（Notification 表，leaderboard_vote/like）===
    leaderboard_types = ["leaderboard_vote", "leaderboard_like"]
    lb_result = await db.execute(
        select(models.Notification)
        .where(
            models.Notification.user_id == current_user.id,
            models.Notification.type.in_(leaderboard_types),
        )
        .order_by(models.Notification.created_at.desc())
    )
    lb_notifications = lb_result.scalars().all()

    lb_converted = []
    for n in lb_notifications:
        lb_converted.append({
            "id": n.id,
            "user_id": n.user_id,
            "type": n.type,
            "title": n.title,
            "content": n.content,
            "title_en": n.title_en,
            "content_en": n.content_en,
            "related_id": n.related_id,
            "related_type": n.related_type,
            "is_read": n.is_read,
            "created_at": n.created_at,
            "task_id": None,
            "variables": None,
        })

    # === 3. 合并 + 分离未读/已读 ===
    all_items = forum_converted + lb_converted
    unread_items = [x for x in all_items if not x["is_read"] and x["is_read"] != 1]
    # is_read 可能是 bool(False) 或 int(0)
    unread_items = [x for x in all_items if x["is_read"] in (False, 0)]
    read_items = [x for x in all_items if x["is_read"] not in (False, 0)]

    unread_items.sort(key=lambda x: x["created_at"] or datetime.min, reverse=True)
    read_items.sort(key=lambda x: x["created_at"] or datetime.min, reverse=True)

    # Page 1: 全部未读 + 前 page_size 条已读
    # Page 2+: 继续加载已读
    if page == 1:
        read_page = read_items[:page_size]
        result_items = unread_items + read_page
    else:
        offset = (page - 1) * page_size
        read_page = read_items[offset:offset + page_size]
        result_items = read_page

    has_more = len(read_items) > page * page_size

    return {
        "notifications": result_items,
        "total": len(all_items),
        "page": page,
        "page_size": page_size,
        "has_more": has_more,
    }
```

Add `from datetime import datetime` at the top of the function if not already imported.

- [ ] **Step 2: Commit**

```bash
git add backend/app/routers.py
git commit -m "feat(notification): add unified interaction notifications endpoint"
```

---

### Task 3: Update unread count endpoint to include forum count

**Files:**
- Modify: `backend/app/routers.py:5779-5788`

- [ ] **Step 1: Update the endpoint**

Replace the existing `get_unread_notification_count_api` (lines 5779-5788):

```python
@router.get("/notifications/unread/count")
@cache_response(ttl=30, key_prefix="notifications")
async def get_unread_notification_count_api(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    # 系统通知未读数（排除 leaderboard_vote/like，这些算互动消息）
    system_count = await async_crud.async_notification_crud.get_unread_notification_count(
        db, current_user.id
    )
    # 减去排行榜互动类型的未读数（它们属于互动消息）
    leaderboard_interaction_types = ["leaderboard_vote", "leaderboard_like"]
    lb_unread_result = await db.execute(
        select(func.count()).select_from(models.Notification).where(
            models.Notification.user_id == current_user.id,
            models.Notification.is_read == 0,
            models.Notification.type.in_(leaderboard_interaction_types),
        )
    )
    lb_unread = lb_unread_result.scalar() or 0

    # 论坛通知未读数
    forum_unread_result = await db.execute(
        select(func.count()).select_from(models.ForumNotification).where(
            models.ForumNotification.to_user_id == current_user.id,
            models.ForumNotification.is_read == False,
        )
    )
    forum_unread = forum_unread_result.scalar() or 0

    return {
        "unread_count": system_count - lb_unread,
        "forum_count": forum_unread + lb_unread,
    }
```

Add `from sqlalchemy import func` if not already imported at the file level.

- [ ] **Step 2: Commit**

```bash
git add backend/app/routers.py
git commit -m "feat(notification): return forum_count in unread count endpoint"
```

---

### Task 4: Update mark-all-as-read to support interaction type

**Files:**
- Modify: `backend/app/routers.py:6120-6137`

- [ ] **Step 1: Update the endpoint**

Replace the existing `mark_all_notifications_read_api` (lines 6120-6137):

```python
@router.post("/notifications/read-all")
async def mark_all_notifications_read_api(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
    type: Optional[str] = Query(None, description="system, interaction, or all (default: all)"),
):
    """
    标记通知为已读。
    type=system: 只标记系统通知（排除 leaderboard_vote/like）
    type=interaction: 标记论坛通知 + 排行榜互动通知
    type=all 或 None: 标记全部
    """
    effective_type = type or "all"
    leaderboard_interaction_types = ["leaderboard_vote", "leaderboard_like"]

    if effective_type in ("system", "all"):
        # 标记系统通知（排除排行榜互动类型，除非是 all）
        if effective_type == "system":
            await db.execute(
                update(models.Notification)
                .where(
                    models.Notification.user_id == current_user.id,
                    models.Notification.is_read == 0,
                    models.Notification.type.notin_(leaderboard_interaction_types),
                )
                .values(is_read=1)
            )
        else:
            await async_crud.async_notification_crud.mark_all_notifications_read(
                db, current_user.id
            )

    if effective_type in ("interaction", "all"):
        # 标记论坛通知
        await db.execute(
            update(models.ForumNotification)
            .where(
                models.ForumNotification.to_user_id == current_user.id,
                models.ForumNotification.is_read == False,
            )
            .values(is_read=True)
        )
        # 标记排行榜互动通知
        if effective_type == "interaction":
            await db.execute(
                update(models.Notification)
                .where(
                    models.Notification.user_id == current_user.id,
                    models.Notification.is_read == 0,
                    models.Notification.type.in_(leaderboard_interaction_types),
                )
                .values(is_read=1)
            )

    await db.commit()
    return {"message": "Notifications marked as read"}
```

Add `from sqlalchemy import update` if not already imported.

- [ ] **Step 2: Commit**

```bash
git add backend/app/routers.py
git commit -m "feat(notification): mark-all-as-read supports type param (system/interaction/all)"
```

---

### Task 5: Update system notifications endpoint with unread-first pagination

The existing `GET /api/users/notifications` loads all notifications with flat pagination. Change it so page 1 returns ALL unread + first page_size read items; subsequent pages return read only.

**Files:**
- Modify: `backend/app/routers.py:5725-5745`

- [ ] **Step 1: Update the endpoint**

Replace the existing `get_notifications_api` (lines 5725-5745):

```python
@router.get("/notifications", response_model=None)
@cache_response(ttl=30, key_prefix="notifications")
async def get_notifications_api(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
    page: int = Query(1, ge=1, description="页码"),
    page_size: int = Query(20, ge=1, le=100, description="每页数量"),
    limit: Optional[int] = Query(None, ge=1, le=100, description="兼容旧版：直接限制条数"),
):
    """
    获取系统通知列表（排除排行榜互动类型）。
    Page 1: 全部未读 + 前 page_size 条已读
    Page 2+: 继续加载已读
    兼容旧版 limit 参数（直接限制条数，不区分未读/已读）。
    """
    from app.utils.notification_utils import enrich_notifications_with_task_id_async

    leaderboard_interaction_types = ["leaderboard_vote", "leaderboard_like"]

    # 兼容旧版 limit 参数
    if limit is not None:
        notifications = await async_crud.async_notification_crud.get_user_notifications(
            db, current_user.id, skip=0, limit=limit, unread_only=False
        )
        enriched = await enrich_notifications_with_task_id_async(notifications, db)
        # 过滤掉排行榜互动类型
        return [n for n in enriched if n.type not in leaderboard_interaction_types]

    # 新版分页：未读优先
    # 1. 查全部未读（排除排行榜互动类型）
    all_notifications = await async_crud.async_notification_crud.get_user_notifications(
        db, current_user.id, skip=0, limit=1000, unread_only=False
    )
    enriched = await enrich_notifications_with_task_id_async(all_notifications, db)

    # 过滤掉排行榜互动类型
    filtered = [n for n in enriched if n.type not in leaderboard_interaction_types]

    unread = [n for n in filtered if n.is_read == 0]
    read = [n for n in filtered if n.is_read != 0]

    if page == 1:
        read_page = read[:page_size]
        result = unread + read_page
    else:
        offset = (page - 1) * page_size
        result = read[offset:offset + page_size]

    has_more = len(read) > page * page_size

    return {
        "notifications": result,
        "total": len(filtered),
        "page": page,
        "page_size": page_size,
        "has_more": has_more,
    }
```

Note: `response_model` changed from `list[schemas.NotificationOut]` to `None` because the response format changes from a flat list to a dict with metadata.

- [ ] **Step 2: Commit**

```bash
git add backend/app/routers.py
git commit -m "feat(notification): system notifications with unread-first pagination"
```

---

### Task 6: Add interaction notification endpoint to api_endpoints.dart

**Files:**
- Modify: `link2ur/lib/core/constants/api_endpoints.dart:326-337`

- [ ] **Step 1: Add the endpoint constant**

After line 328 (`unreadNotificationCount`), add:

```dart
  static const String interactionNotifications =
      '/api/users/notifications/interaction';
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/core/constants/api_endpoints.dart
git commit -m "feat(notification): add interaction notifications endpoint constant"
```

---

## Chunk 2: Flutter Changes

### Task 7: Update NotificationListResponse model to support has_more

The backend now returns `has_more` in the response. Update the model to use it instead of guessing from list length.

**Files:**
- Modify: `link2ur/lib/data/models/notification.dart:130-172`

- [ ] **Step 1: Add hasMore field to NotificationListResponse**

Replace the `NotificationListResponse` class (lines 130-172):

```dart
class NotificationListResponse {
  const NotificationListResponse({
    required this.notifications,
    required this.total,
    required this.page,
    required this.pageSize,
    this.hasMoreFromServer,
  });

  final List<AppNotification> notifications;
  final int total;
  final int page;
  final int pageSize;
  final bool? hasMoreFromServer;

  /// 优先使用后端返回的 has_more，回退到根据列表长度推断
  bool get hasMore => hasMoreFromServer ?? notifications.length >= pageSize;

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] ?? json['notifications'] ?? json['data'])
        as List<dynamic>?;
    return NotificationListResponse(
      notifications: items
              ?.map((e) =>
                  AppNotification.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      hasMoreFromServer: json['has_more'] as bool?,
    );
  }

  factory NotificationListResponse.fromList(List<dynamic> list) {
    return NotificationListResponse(
      notifications: list
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: list.length,
      page: 1,
      pageSize: 20,
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/data/models/notification.dart
git commit -m "feat(notification): support has_more from backend response"
```

---

### Task 8: Update notification repository

Replace the forum+system merge logic with a single call to the new interaction endpoint. Add type param to markAllAsRead.

**Files:**
- Modify: `link2ur/lib/data/repositories/notification_repository.dart`

- [ ] **Step 1: Replace getForumNotifications with getInteractionNotifications**

Replace the `getForumNotifications` method (lines 151-168) with:

```dart
  /// 获取互动消息（论坛 + 排行榜互动，统一接口）
  Future<NotificationListResponse> getInteractionNotifications({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<dynamic>(
      ApiEndpoints.interactionNotifications,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw NotificationException(response.message ?? '获取互动消息失败');
    }

    return _parseNotificationResponse(response.data);
  }
```

- [ ] **Step 2: Add type param to markAllAsRead**

Update the `markAllAsRead` method (lines 104-114) to accept an optional type:

```dart
  Future<void> markAllAsRead({String? type}) async {
    final response = await _apiService.post<dynamic>(
      ApiEndpoints.markAllNotificationsRead,
      queryParameters: {
        if (type != null) 'type': type,
      },
    );

    if (!response.isSuccess) {
      throw NotificationException(response.message ?? '标记全部已读失败');
    }

    CacheManager.invalidatePattern('notifications');
  }
```

- [ ] **Step 3: Add markForumNotificationAsRead method**

Add a new method to mark individual forum notifications as read (they use a different endpoint with PUT):

```dart
  /// 标记论坛通知为已读（PUT 方法）
  Future<void> markForumNotificationAsRead(int notificationId) async {
    final response = await _apiService.put<dynamic>(
      ApiEndpoints.forumNotificationRead(notificationId),
    );

    if (!response.isSuccess) {
      throw NotificationException(response.message ?? '标记已读失败');
    }
  }
```

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/data/repositories/notification_repository.dart
git commit -m "feat(notification): update repository for unified interaction endpoint"
```

---

### Task 9: Update notification BLoC

Fix interaction loading to use new endpoint with pagination. Fix mark-all-as-read to pass type. Fix leaderboard_approved/rejected classification. Fix mark-as-read to call correct backend endpoint for forum notifications.

**Files:**
- Modify: `link2ur/lib/features/notification/bloc/notification_bloc.dart`

- [ ] **Step 1: Fix interaction type classification**

Update the static filter (lines 198-203). `leaderboard_approved` and `leaderboard_rejected` are system notifications (admin review results), not interaction:

```dart
  static const _interactionTypePrefixes = ['forum_'];
  static const _interactionExactTypes = ['leaderboard_vote', 'leaderboard_like'];

  static bool _isInteractionType(String type) =>
      _interactionTypePrefixes.any((prefix) => type.startsWith(prefix)) ||
      _interactionExactTypes.contains(type);
```

- [ ] **Step 2: Simplify _onLoadRequested for interaction**

Replace the interaction branch in `_onLoadRequested` (lines 234-267) with:

```dart
      if (event.type == 'interaction') {
        response = await _notificationRepository.getInteractionNotifications(
          page: 1,
        );
      } else {
```

And update line 283 to enable pagination for interaction:

```dart
        hasMore: response.hasMore,
```

(Remove the `event.type == 'interaction' ? false :` conditional.)

- [ ] **Step 3: Fix _onLoadMore for interaction**

Replace the `_onLoadMore` handler (lines 295-320) to support interaction pagination:

```dart
  Future<void> _onLoadMore(
    NotificationLoadMore event,
    Emitter<NotificationState> emit,
  ) async {
    if (!state.hasMore) return;

    try {
      final nextPage = state.page + 1;
      final NotificationListResponse response;

      if (state.selectedType == 'interaction') {
        response = await _notificationRepository.getInteractionNotifications(
          page: nextPage,
        );
      } else {
        response = await _notificationRepository.getNotifications(
          page: nextPage,
          type: state.selectedType,
        );
      }

      final filtered = _filterNotifications(
          response.notifications, state.selectedType);

      emit(state.copyWith(
        notifications: [...state.notifications, ...filtered],
        page: nextPage,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to load more notifications', e);
      emit(state.copyWith(hasMore: false));
    }
  }
```

- [ ] **Step 4: Fix _onMarkAsRead for forum notifications**

Update `_onMarkAsRead` (lines 322-359). Forum notifications (from the interaction endpoint) have IDs from the ForumNotification table, so need to call the forum mark-as-read endpoint:

```dart
    // 2. 异步请求后端
    if (isInteraction && target != null && target.type.startsWith('forum_')) {
      _notificationRepository.markForumNotificationAsRead(event.notificationId).catchError((e) {
        AppLogger.error('Failed to mark forum notification as read', e);
      });
    } else {
      _notificationRepository.markAsRead(event.notificationId).catchError((e) {
        AppLogger.error('Failed to mark notification as read', e);
      });
    }
```

- [ ] **Step 5: Fix _onMarkAllAsRead to pass type**

Update `_onMarkAllAsRead` (lines 361-379) to pass the current tab type:

```dart
  Future<void> _onMarkAllAsRead(
    NotificationMarkAllAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    final updatedList = state.notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();

    final resetUnread = state.selectedType == 'interaction'
        ? UnreadNotificationCount(
            count: state.unreadCount.count, forumCount: 0)
        : UnreadNotificationCount(
            count: 0, forumCount: state.unreadCount.forumCount);

    emit(state.copyWith(
      notifications: updatedList,
      unreadCount: resetUnread,
    ));

    final markType = state.selectedType == 'interaction'
        ? 'interaction'
        : 'system';
    _notificationRepository.markAllAsRead(type: markType).catchError((e) {
      AppLogger.error('Failed to mark all as read', e);
    });
  }
```

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/features/notification/bloc/notification_bloc.dart
git commit -m "feat(notification): fix BLoC for unified interaction endpoint with pagination"
```

---

### Task 10: Fix notification_center_view navigation

The `_navigateToRelated` method in `notification_center_view.dart` is too simple. It should reuse the comprehensive routing from `notification_list_view.dart`.

**Files:**
- Modify: `link2ur/lib/features/notification/views/notification_center_view.dart:367-384`

- [ ] **Step 1: Replace _navigateToRelated with comprehensive routing**

Replace lines 367-384 with routing that handles all notification types (matching `notification_list_view.dart`'s logic):

```dart
  void _navigateToRelated(
      BuildContext context, models.AppNotification notification) {
    final type = notification.type;
    final relatedId = notification.relatedId;
    final taskId = notification.taskId;

    // 论坛
    if (type.startsWith('forum_')) {
      if (type == 'forum_category_approved') {
        context.safePush('/forum');
        return;
      }
      if (type == 'forum_category_rejected') return;
      if (relatedId != null) context.safePush('/forum/posts/$relatedId');
      return;
    }

    // 排行榜
    if (type.startsWith('leaderboard_')) {
      if (relatedId == null) return;
      if (type == 'leaderboard_approved' || type == 'leaderboard_rejected') {
        context.safePush('/leaderboard/$relatedId');
      } else {
        context.goToLeaderboardItemDetail(relatedId);
      }
      return;
    }

    // 其他系统通知：跳任务详情
    if (relatedId == null && taskId == null) return;
    switch (notification.relatedType) {
      case 'task_id':
        context.safePush('/tasks/$relatedId');
        break;
      case 'forum_post_id':
        context.safePush('/forum/posts/$relatedId');
        break;
      case 'flea_market_id':
        context.safePush('/flea-market/$relatedId');
        break;
      default:
        final id = taskId ?? relatedId;
        if (id != null) context.safePush('/tasks/$id');
        break;
    }
  }
```

Ensure `app_router.dart` extension import is present (it already is on line 11).

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/features/notification/views/notification_center_view.dart
git commit -m "fix(notification): comprehensive navigation for all notification types"
```

---

### Task 11: Verify and test

- [ ] **Step 1: Run Flutter analyze**

```bash
cd link2ur && flutter analyze lib/features/notification/ lib/data/repositories/notification_repository.dart lib/data/models/notification.dart lib/core/constants/api_endpoints.dart
```

Expected: No issues found.

- [ ] **Step 2: Run existing tests**

```bash
cd link2ur && flutter test
```

Expected: All existing tests pass.

- [ ] **Step 3: Manual verification checklist**

Verify these scenarios work:
1. System tab loads and shows only system notifications (no forum/leaderboard_vote/like)
2. Interaction tab loads and shows forum + leaderboard_vote/like notifications
3. `leaderboard_approved`/`leaderboard_rejected` appear in system tab (not interaction)
4. Interaction tab supports pagination (scroll to load more)
5. Tapping a forum notification navigates to the correct post
6. Tapping a leaderboard_vote notification navigates to item detail
7. Unread badge shows correct counts for both tabs
8. "Mark all as read" in system tab only marks system notifications
9. "Mark all as read" in interaction tab marks forum + leaderboard interaction notifications
10. New notification via WebSocket updates the unread badge

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat(notification): complete system & interaction message fix"
```
