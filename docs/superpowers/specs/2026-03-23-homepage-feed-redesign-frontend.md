# Homepage Feed Redesign — Frontend Spec

## Goal

Redesign the Flutter home page from 3-tab layout (Experts/Recommended/Nearby) to 5-tab Xiaohongshu-style layout (Follow/Recommend/Nearby/Experts/Activities) with a unified mixed-content waterfall feed.

## Design Reference

Mockup: `homepage_mockups/option_A_xiaohongshu.html`

## Architecture Changes

### Tab Structure: 3 → 5

| Index | Old | New |
|-------|-----|-----|
| 0 | Experts | Follow (关注) — NEW |
| 1 | Recommended | Recommend (推荐) — REDESIGNED |
| 2 | Nearby | Nearby (附近) — KEEP |
| 3 | — | Experts (达人) — MOVED |
| 4 | — | Activities (活动) — NEW |

Default tab: index 1 (Recommend).

### Recommend Tab Layout (top to bottom)

1. **Story Row** — Horizontal scrollable circles, each is a navigation entry (AI chat, flea market, category pages, etc.)
2. **Ticker + Banner** — Scrolling announcement overlay on top of banner card. Ticker from `GET /api/feed/ticker`, banner from existing banner API.
3. **Waterfall Feed** — 2-column masonry layout mixing all content types from `GET /api/discovery/feed` (now includes `task` and `activity` types)

Removed: Greeting section, Linker thought cloud, separate recommended tasks horizontal scroll, separate hot activities section.

### Follow Tab

New tab showing content from followed users via `GET /api/follow/feed`. Same flat feed format, pure timeline (reverse chronological). Includes a new `completion` feed_type.

### Activities Tab

Standalone activity list (extracted from the old "Hot Events" section). Uses existing Activity API.

### Bottom Nav

Rename "社区/Community" → "发现/Discover". No functional change.

### New Data Layer

| Component | Purpose |
|-----------|---------|
| `FollowRepository` | Follow/unfollow, follower/following lists, follow feed |
| `TickerRepository` | Fetch ticker data |
| `DiscoveryFeedItem` model update | Handle new `task`, `activity`, `completion` feed types |

### New Card Widgets (in waterfall)

- **TaskCard** — For `feed_type: "task"`. Shows image, title, task_type tag, price tag, poster avatar+name, view count.
- **ActivityCard** — For `feed_type: "activity"`. Shows image, title, participant count badge, price, organizer.
- **CompletionCard** — For `feed_type: "completion"` (follow feed only). Shows user avatar, "completed a {type} task" text.

Existing cards (PostCard, ProductCard, CompetitorReviewCard, ServiceReviewCard) remain unchanged.

## Out of Scope

- Follow suggestions / "people you may know"
- Push notifications for follow events
- Desktop-specific layout changes (mobile-first, desktop adapts)
