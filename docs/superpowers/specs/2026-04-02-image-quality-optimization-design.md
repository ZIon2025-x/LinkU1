# Image Quality Optimization Design

**Date:** 2026-04-02
**Problem:** Public images in Flutter app appear blurry due to multiple JPEG re-encoding rounds.

## Root Cause

Images go through 4 lossy JPEG re-encodings:

1. **Client** `ImagePicker`: maxWidth 1024, quality 85
2. **Backend** `auto_orient()`: decode → encode q95
3. **Backend** `strip_metadata()`: decode → encode q95
4. **Backend** `compress()`: decode → encode q85

Cumulative quality ~65%. Clearly blurry.

## Solution

**Store originals, serve thumbnails.**

- Client: send original image, no compression
- Backend: store original (only lossless EXIF strip), generate thumbnails
- Flutter: use thumbnail URLs for lists/cards, original for full-screen

---

## Backend Changes

### 1. `image_processor.py` — Lossless EXIF strip

New method `strip_exif_lossless(content: bytes) -> bytes`:
- Remove EXIF data without decoding pixels (manipulate JPEG segments directly, or use `piexif`)
- PNG/WebP/GIF: return as-is (no EXIF)
- Zero quality loss

### 2. `image_processor.py` — Orientation handling

Before stripping EXIF, check orientation tag:
- If orientation == 1 (normal): no rotation needed, just strip EXIF losslessly
- If orientation != 1: single decode → rotate → encode at q95, then strip EXIF
- Most photos have orientation=1, so most images get zero re-encoding

### 3. `image_upload_service.py` — New upload pipeline

**Before (4 encodes):**
```
auto_orient → strip_metadata → resize → compress → store
```

**After (0 or 1 encode):**
```
check_orientation
  ├─ needs rotation → decode → rotate → encode(q95) → strip_exif_lossless → store original
  └─ no rotation   → strip_exif_lossless → store original
                          ↓
              generate_thumbnails(presets) → store thumbnails
```

Remove `compress` step entirely for public images. Remove `max_dimension` resize on originals — originals are stored as-is (after possible rotation). Thumbnails handle size reduction.

### 4. Enable thumbnails per category

| Category | Thumbnail presets |
|----------|------------------|
| TASK | medium(640), large(1280) |
| FORUM_POST | medium(640), large(1280) |
| FLEA_MARKET | thumb(150), medium(640), large(1280) |
| ACTIVITY | medium(640) |
| BANNER | none (display-only, already sized) |
| LEADERBOARD_COVER | none |
| LEADERBOARD_ITEM | thumb(150) (unchanged) |
| EXPERT_AVATAR | none (small by nature) |
| SERVICE_IMAGE | medium(640) |

### 5. Upload API response

No schema change. `thumbnails` field already exists in upload response:
```json
{
  "url": "https://cdn.link2ur.com/.../uuid.jpg",
  "thumbnails": {
    "medium": "https://cdn.link2ur.com/.../uuid_medium.webp",
    "large": "https://cdn.link2ur.com/.../uuid_large.webp"
  }
}
```

Thumbnails are stored as WebP (already the default format in `ThumbnailConfig`).

---

## Flutter Changes

### 1. Remove client-side compression

Remove `imageQuality` and `maxWidth` from all public image `ImagePicker` calls:

| File | Current | New |
|------|---------|-----|
| `create_post_view.dart` | maxWidth:1024, q85 | removed |
| `edit_post_view.dart` | maxWidth:1024, q85 | removed |
| `create_flea_market_item_view.dart` | maxWidth:1024, q85 | removed |
| `edit_flea_market_item_view.dart` | maxWidth:1200, q80 | removed |
| `create_task_view.dart` | maxWidth:1920, q80 | removed |
| `task_detail_view.dart` | maxWidth:1920, q80 | removed |
| `task_detail_components.dart` | maxWidth:1920, q80 | removed |

Chat images unchanged (private pipeline, different trade-offs).

### 2. `Helpers.getThumbnailUrl()` — New utility

```dart
static String getThumbnailUrl(String? url, {String size = 'medium'}) {
  // Returns thumbnail URL by replacing extension:
  //   .../uuid.jpg → .../uuid_medium.webp
  // If URL is not CDN format (old local paths), returns original URL unchanged.
}
```

Naming convention matches backend: `{file_id}_{preset}.webp` in same directory.

### 3. Display size selection

| Context | Image size | Rationale |
|---------|-----------|-----------|
| Discovery cards, list thumbnails | `_medium` (640px) | Cards are ~180pt wide, 640px covers 3x DPR |
| Task detail carousel, forum post images | `_large` (1280px) | Full-width display ~390pt, 1280px covers 3x+ |
| Full-screen `FullScreenImageView` | Original | User explicitly zooming, wants full quality |
| Avatars | Unchanged | Already has separate logic |

### 4. `AsyncImageView` — Thumbnail fallback

Add optional `fallbackUrl` parameter. When the primary URL (thumbnail) fails to load, automatically try `fallbackUrl` (original). This handles old images without thumbnails gracefully — no error flash.

```dart
AsyncImageView(
  imageUrl: Helpers.getThumbnailUrl(url, size: 'medium'),
  fallbackUrl: Helpers.getImageUrl(url),  // for old images
  ...
)
```

### 5. Backward compatibility

- Old images (no thumbnails on CDN): `AsyncImageView` fallback loads original URL on 404
- Old local-path images (`/uploads/...`): `getThumbnailUrl` returns original URL directly, no conversion attempted
- No backfill migration needed

---

## Files Changed

**Backend:**
- `backend/app/services/image_processor.py` — add `strip_exif_lossless()`, add `check_and_fix_orientation()`
- `backend/app/services/image_upload_service.py` — rewrite upload pipeline, enable thumbnails for more categories
- `backend/requirements.txt` — add `piexif` if needed

**Flutter:**
- `link2ur/lib/core/utils/helpers.dart` — add `getThumbnailUrl()`
- `link2ur/lib/core/widgets/async_image_view.dart` — add `fallbackUrl` support
- `link2ur/lib/features/forum/views/create_post_view.dart` — remove ImagePicker compression
- `link2ur/lib/features/forum/views/edit_post_view.dart` — remove ImagePicker compression
- `link2ur/lib/features/flea_market/views/create_flea_market_item_view.dart` — remove ImagePicker compression
- `link2ur/lib/features/flea_market/views/edit_flea_market_item_view.dart` — remove ImagePicker compression
- `link2ur/lib/features/tasks/views/create_task_view.dart` — remove ImagePicker compression
- `link2ur/lib/features/tasks/views/task_detail_view.dart` — remove ImagePicker compression
- `link2ur/lib/features/tasks/views/task_detail_components.dart` — remove ImagePicker compression
- Display views using `AsyncImageView` for public images — pass thumbnail URL + fallback

## Not in scope

- Backfill thumbnails for existing images
- Chat/private image pipeline changes
- Cloudflare Image Resizing (not available on current plan)
