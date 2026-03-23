# Homepage Feed Redesign — Backend Spec

## Goal

Redesign the homepage backend to support a Xiaohongshu/Pinterest-style unified feed. Replace the separate "recommended tasks" section and "discover more" feed with a single mixed-content waterfall feed. Add a follow system and real-time ticker.

## Architecture Overview

The homepage has 5 tabs: Follow / Recommend / Nearby / Experts / Activities. This spec covers the backend changes needed to support all tabs. The "Recommend" tab is the primary change — it becomes a unified waterfall feed mixing tasks, forum posts, flea market products, services, activities, and reviews.

**Approach:** Extend the existing `/api/discovery/feed` endpoint to include `task` and `activity` content types. All visible, open tasks appear in the feed; the recommendation engine influences sort priority within the type, not whether tasks are included. A new follow system and ticker API are built from scratch.

## Subsystem 1: Discovery Feed Enhancement

### Current State

`GET /api/discovery/feed` returns 6 content types: `forum_post`, `product`, `competitor_review`, `service_review`, `ranking`, `service`. Uses weighted random mixing with seed-based deterministic pagination and 120s cache.

All feed items use a **flat normalized structure** with these keys:
`feed_type`, `id` (prefixed string like `"post_123"`), `title`, `title_zh`, `title_en`, `description`, `description_zh`, `description_en`, `images`, `user_id`, `user_name`, `user_avatar`, `price`, `original_price`, `discount_percentage`, `currency`, `rating`, `like_count`, `comment_count`, `view_count`, `upvote_count`, `downvote_count`, `linked_item`, `target_item`, `activity_info`, `is_experienced`, `is_favorited`, `user_vote_type`, `extra_data`, `created_at`.

The `_weighted_shuffle` function has a hardcoded `type_weights` dict that controls mixing frequency.

### Changes

Add two new content types: `task` and `activity`. Both must conform to the existing flat feed item structure.

#### Task Content Type

**Source:** All tasks with `status='open'`, `is_visible=True`, `deadline > now()`. The `is_visible` filter is a moderation gate — all tasks passing moderation appear in the feed.

**Scoring (for intra-type sort priority):**
- Composite score = `recommendation_score * 0.6 + recency_score * 0.2 + popularity_score * 0.2`
- `recommendation_score`: From recommendation engine (logged-in users), 0 for anonymous
- `recency_score`: Time decay — newer tasks score higher
- `popularity_score`: Based on application count (via `COUNT(*)` subquery on `task_applications`) + `view_count` column (normalized)
- Application count must be fetched via subquery — there is no counter column on `Task`

**Mixing rules:**
- Tasks occupy ~20-25% of the feed (roughly 1 task per 4-5 other items)
- Add to `_weighted_shuffle` `type_weights`: `"task": 1.5` (medium frequency)
- Subject to existing "no more than 2 consecutive same-type items" rule
- Exclude user's own tasks, applied tasks, completed tasks (same exclusion logic as recommendation engine via `get_excluded_task_ids`)

**Response format** — conforms to existing flat structure:
```json
{
  "feed_type": "task",
  "id": "task_123",
  "title": "Professional UI Design",
  "title_zh": "专业UI设计",
  "title_en": "Professional UI Design",
  "description": "App界面/网页设计，3天交付...",
  "description_zh": "App界面/网页设计...",
  "description_en": "App/web design...",
  "images": ["url1", "url2"],
  "user_id": "abc123",
  "user_name": "设计小王",
  "user_avatar": "https://...",
  "price": 80.0,
  "original_price": null,
  "discount_percentage": null,
  "currency": "GBP",
  "rating": null,
  "like_count": null,
  "comment_count": null,
  "view_count": 120,
  "upvote_count": null,
  "downvote_count": null,
  "linked_item": null,
  "target_item": null,
  "activity_info": null,
  "is_experienced": null,
  "is_favorited": null,
  "user_vote_type": null,
  "extra_data": {
    "task_type": "design",
    "reward": 80.0,
    "base_reward": 80.0,
    "agreed_reward": null,
    "reward_to_be_quoted": false,
    "location": "London",
    "deadline": "2026-04-01T00:00:00Z",
    "task_level": "intermediate",
    "application_count": 5,
    "match_score": 0.85,
    "recommendation_reason": "符合您的兴趣偏好"
  },
  "created_at": "2026-03-20T10:00:00Z"
}
```

Task-specific fields (`task_type`, `reward`, `location`, `deadline`, `match_score`, `recommendation_reason`, `application_count`) go into `extra_data`. The `price` field maps to `reward` for consistency with the flat structure.

#### Activity Content Type

**Source:** Activities with `status='open'`, `visibility='public'`, `deadline > now()` (or `deadline IS NULL`). Filter on `visibility` column (not `is_public`) per the Activity model schema.

**Mixing rules:**
- Add to `_weighted_shuffle` `type_weights`: `"activity": 2.0` (low frequency, higher priority per appearance since they previously had a dedicated section)
- Same consecutive-type limit applies

**Response format** — conforms to existing flat structure:
```json
{
  "feed_type": "activity",
  "id": "activity_456",
  "title": "留学生求职分享会",
  "title_zh": "留学生求职分享会",
  "title_en": "Job Hunting Workshop for International Students",
  "description": "前Google/Amazon工程师分享...",
  "description_zh": "...",
  "description_en": "...",
  "images": ["url1"],
  "user_id": "def456",
  "user_name": "Link²Ur Official",
  "user_avatar": "https://...",
  "price": 15.0,
  "original_price": 15.0,
  "discount_percentage": null,
  "currency": "GBP",
  "rating": null,
  "like_count": null,
  "comment_count": null,
  "view_count": null,
  "upvote_count": null,
  "downvote_count": null,
  "linked_item": null,
  "target_item": null,
  "activity_info": {
    "activity_type": "standard",
    "max_participants": 50,
    "current_participants": 32,
    "reward_type": "cash",
    "location": "线上 Zoom",
    "deadline": "2026-04-15T00:00:00Z"
  },
  "is_experienced": null,
  "is_favorited": null,
  "user_vote_type": null,
  "extra_data": null,
  "created_at": "2026-03-15T08:00:00Z"
}
```

Activity-specific fields go into `activity_info` (which already exists in the flat structure but was previously always `null`).

### Implementation Notes

- The recommendation engine call should be **optional and non-blocking**: if it fails or times out (>500ms), fall back to recency+popularity scoring for tasks. The feed must not fail because recommendations are unavailable.
- Location obfuscation applies to task locations (reuse existing `obfuscate_location()`).
- Anonymous users see tasks sorted by recency+popularity only (no recommendation score).
- The existing `cache_response` decorator already handles user-specific cache keys (extracts `_uid` from `current_user`). No additional cache key logic needed.

### File Changes

- `app/discovery_routes.py`:
  - Add `_fetch_tasks()` and `_fetch_activities()` content fetchers following existing patterns (SAVEPOINT isolation, flat format)
  - Update `_weighted_shuffle` `type_weights` dict: add `"task": 1.5`, `"activity": 2.0`
  - Integrate new fetchers into the main feed assembly pipeline

---

## Subsystem 2: Follow System

### Data Model

```python
class UserFollow(Base):
    __tablename__ = "user_follows"

    id = Column(Integer, primary_key=True, autoincrement=True)
    follower_id = Column(String(8), ForeignKey("users.id"), nullable=False)
    following_id = Column(String(8), ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        UniqueConstraint("follower_id", "following_id", name="uq_user_follow"),
        Index("ix_user_follows_follower", "follower_id"),
        Index("ix_user_follows_following", "following_id"),
    )
```

**Constraints:**
- Users cannot follow themselves (validated in API layer, returns 400)
- Duplicate follows are idempotent (return success, no error)
- Unfollow non-existing follow is idempotent (return success)

### API Endpoints

#### Follow/Unfollow

`POST /api/users/{user_id}/follow` — Follow a user
- Auth: Required (`get_current_user_secure_sync_csrf`)
- Response: `{"status": "followed", "followers_count": N}`
- Self-follow returns 400
- Rate limit: 30 follow/unfollow actions per minute per user

`DELETE /api/users/{user_id}/follow` — Unfollow a user
- Auth: Required
- Response: `{"status": "unfollowed", "followers_count": N}`
- Same rate limit

#### Lists

`GET /api/users/{user_id}/followers?page=1&page_size=20` — Follower list
- Auth: Optional (`get_current_user_optional`)
- Response: `{"users": [...], "total": N, "page": 1, "has_more": bool}`
- Each user: `{id, name, avatar, bio, is_following}` (is_following: whether current user follows this person back)

`GET /api/users/{user_id}/following?page=1&page_size=20` — Following list
- Auth: Optional
- Same response format

#### Follow Feed

`GET /api/follow/feed?page=1&page_size=20` — Timeline of followed users' activities
- Auth: Required
- Response: Same flat structure as discovery feed (`{items: [...], page, has_more}`)

**Feed content from followed users (using the same flat `feed_type` format):**

| Source | `feed_type` | Time filter | Join key |
|--------|-------------|-------------|----------|
| Tasks published | `task` | Last 30 days | `Task.poster_id` |
| Forum posts | `forum_post` | Last 30 days | `ForumPost.author_id` |
| Flea market items | `product` | Last 30 days | `FleaMarketItem.seller_id` |
| Services created/updated | `service` | Last 30 days | `TaskExpertService.owner_user_id` |
| Task completions | `completion` | Last 7 days | `TaskHistory.user_id` (action=completed) |

`completion` is a new feed_type for the follow feed only (not in discovery feed). Fields:
```json
{
  "feed_type": "completion",
  "id": "completion_789",
  "title": "完成了一个设计任务",
  "title_zh": "完成了一个设计任务",
  "title_en": "Completed a design task",
  "description": null,
  "user_id": "abc123",
  "user_name": "Lisa",
  "user_avatar": "...",
  "extra_data": {"task_type": "design", "task_id": 456},
  ... (other flat fields null)
}
```

**Sort:** Reverse chronological (pure timeline, no recommendation ranking).

**Pagination:** Offset-based (page + page_size). No seed needed since it's time-ordered.

**Query strategy:** Fan-out-on-read with UNION ALL across source tables, ordered by `created_at DESC`, `LIMIT page_size OFFSET (page-1)*page_size`. Following list is fetched first, then used as `IN` filter. For users following >200 people, cap the following list to the 200 most recently followed to keep the query performant.

### Caching

- Follow relationship check (is_following): 300s per user pair
- Follower/following counts: 300s per user
- Follow feed: No cache (personal timeline, must be fresh)

### File Changes

- `app/models.py`: Add UserFollow model import
- New `app/models/user_follow.py`: UserFollow model definition
- New `app/follow_routes.py`: Follow/unfollow + follower/following list endpoints
- New `app/follow_feed_routes.py`: Follow feed endpoint
- `app/main.py`: Register new routers

---

## Subsystem 3: Real-time Ticker

### Purpose

Scrolling announcement bar showing recent platform activity. Purely auto-generated from existing data — no admin involvement (admin announcements use the existing Banner system).

### API

`GET /api/feed/ticker` — Returns recent platform activity for the ticker
- Auth: Not required
- Cache: 120s (shared across all users)

**Response:**
```json
{
  "items": [
    {
      "text_zh": "👩‍🎨 Lisa 刚完成了一个 Logo设计 订单，获得5星好评",
      "text_en": "👩‍🎨 Lisa completed a Logo Design order, 5-star review",
      "link_type": "user",
      "link_id": "abc123"
    }
  ]
}
```

Only `text_zh` and `text_en` — client selects based on locale. No redundant `text` field.

### Dynamic Sources (aggregated from existing tables)

1. **Recent task completions with good reviews**
   - Source: `TaskHistory` (action=completed, last 24h) JOIN `Review` (rating >= 4)
   - Template zh: `"{user} 刚完成了一个 {task_type} 订单，获得{rating}星好评"`
   - Template en: `"{user} completed a {task_type} order, {rating}-star review"`

2. **Active user stats**
   - Source: `TaskHistory` (action=accepted, today) GROUP BY user_id, count
   - Template zh: `"{user} 今日已接 {count} 单，累计完成 {total} 单"`
   - Template en: `"{user} took {count} orders today, {total} total"`

3. **Activity participation updates**
   - Source: `OfficialActivityApplication` (recent) + `Activity`
   - Template zh: `"{activity_title} 还剩{remaining}个名额，快来报名"`
   - Template en: `"{remaining} spots left for {activity_title_en}, sign up now"`

### Implementation Notes

- Returns 5-10 items, client rotates through them
- All user names should respect privacy — use display name only
- If no recent activity data, return empty list (client hides ticker)
- Ticker is a non-critical feature — any aggregation failure returns empty list

### File Changes

- New `app/ticker_routes.py`: Ticker endpoint with data aggregation logic
- `app/main.py`: Register ticker router

---

## Database Migration

**New table:** `user_follows`

```sql
CREATE TABLE user_follows (
    id SERIAL PRIMARY KEY,
    follower_id VARCHAR(8) NOT NULL REFERENCES users(id),
    following_id VARCHAR(8) NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_user_follow UNIQUE (follower_id, following_id)
);
CREATE INDEX ix_user_follows_follower ON user_follows(follower_id);
CREATE INDEX ix_user_follows_following ON user_follows(following_id);
```

Migration via raw SQL in a migration script (project does not use Alembic). No other schema changes needed — all other data comes from existing tables.

---

## Error Handling

- All new endpoints follow existing patterns: try/except with appropriate HTTP status codes
- Follow system: 400 for self-follow, 404 for non-existent user, idempotent for duplicate follow/unfollow
- Discovery feed: Task/activity fetch failures are isolated (existing SAVEPOINT pattern) — one content type failing doesn't break the feed
- Ticker: Returns empty list on any aggregation failure (non-critical feature)
- Rate limiting: Follow/unfollow endpoints limited to 30 actions/minute/user

---

## Testing Strategy

- **Follow system:** Unit tests for model constraints, API tests for follow/unfollow/lists/feed, edge cases (self-follow, idempotent ops, rate limits)
- **Discovery feed:** Test task and activity injection, verify flat format compliance, mixing ratios, anonymous vs authenticated behavior, recommendation engine failure fallback
- **Ticker:** Test data aggregation from each source, bilingual output, empty data handling

---

## Out of Scope

- Flutter frontend changes (separate spec)
- Admin panel for managing announcements (existing Banner system suffices)
- Push notifications for follow events (can be added later)
- Real-time WebSocket updates for ticker (polling with cache is sufficient for MVP)
- Follow suggestions / "people you may know" feature
