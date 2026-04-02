# Image Quality Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate multi-round JPEG re-encoding that causes blurry public images — store originals, serve thumbnails.

**Architecture:** Backend upload pipeline changes from 4-step lossy processing to: lossless EXIF strip (+ single rotation encode only when needed) + thumbnail generation. Flutter removes client-side compression, uses thumbnail URLs for lists/cards, originals for full-screen. Old images without thumbnails gracefully fall back to original URLs.

**Tech Stack:** Python/Pillow (backend), Flutter/CachedNetworkImage (frontend)

---

## File Structure

**Backend:**
- Modify: `backend/app/services/image_processor.py` — add `strip_exif_lossless()`, `orient_if_needed()`
- Modify: `backend/app/services/image_upload_service.py` — rewrite upload pipeline, update category configs

**Flutter:**
- Modify: `link2ur/lib/core/utils/helpers.dart` — add `getThumbnailUrl()`
- Modify: `link2ur/lib/core/widgets/async_image_view.dart` — add `fallbackUrl` support
- Modify: `link2ur/lib/features/forum/views/create_post_view.dart` — remove ImagePicker compression
- Modify: `link2ur/lib/features/forum/views/edit_post_view.dart` — remove ImagePicker compression
- Modify: `link2ur/lib/features/flea_market/views/create_flea_market_item_view.dart` — remove ImagePicker compression
- Modify: `link2ur/lib/features/flea_market/views/edit_flea_market_item_view.dart` — remove ImagePicker compression
- Modify: `link2ur/lib/features/tasks/views/create_task_view.dart` — remove ImagePicker compression
- Modify: `link2ur/lib/features/tasks/views/task_detail_view.dart` — remove ImagePicker compression
- Modify: `link2ur/lib/features/tasks/views/task_detail_components.dart` — remove ImagePicker compression
- Modify: `link2ur/lib/features/home/views/home_discovery_cards.dart` — use thumbnail URLs
- Modify: `link2ur/lib/features/tasks/views/task_detail_view.dart` — use thumbnail/original URLs by context

---

### Task 1: Backend — Add lossless EXIF strip and orientation-aware processing

**Files:**
- Modify: `backend/app/services/image_processor.py`

- [ ] **Step 1: Add `strip_exif_lossless()` method**

Add after the existing `strip_metadata()` method (around line 476) in `ImageProcessor` class:

```python
def strip_exif_lossless(self, content: bytes) -> bytes:
    """
    无损移除 JPEG EXIF 元数据（不解码像素，零质量损失）。
    对于 PNG/WebP/GIF 等不含 EXIF 的格式，直接返回原内容。

    原理：JPEG 文件由多个 segment 组成，EXIF 存储在 APP1 segment (marker 0xFFE1)。
    直接跳过 APP1 segment 即可无损移除 EXIF，不触碰图像数据。
    """
    if len(content) < 4:
        return content

    # 只处理 JPEG（以 0xFFD8 开头）
    if content[0:2] != b'\xff\xd8':
        return content

    # 遍历 JPEG segments，跳过所有 APP1 (EXIF) segments
    result = bytearray(b'\xff\xd8')  # SOI marker
    pos = 2

    while pos < len(content) - 1:
        # 查找下一个 marker
        if content[pos] != 0xFF:
            # 到达图像数据区域，复制剩余内容
            result.extend(content[pos:])
            break

        marker = content[pos + 1]

        # SOS (Start of Scan) marker — 之后是压缩图像数据，直接复制到结尾
        if marker == 0xDA:
            result.extend(content[pos:])
            break

        # 无长度的 marker (如 0xFF00 padding)
        if marker == 0x00 or (0xD0 <= marker <= 0xD9):
            result.extend(content[pos:pos + 2])
            pos += 2
            continue

        # 读取 segment 长度
        if pos + 3 >= len(content):
            result.extend(content[pos:])
            break

        seg_length = (content[pos + 2] << 8) | content[pos + 3]
        seg_end = pos + 2 + seg_length

        # 跳过 APP1 segment (0xFFE1) — 这是 EXIF 数据
        if marker == 0xE1:
            pos = seg_end
            continue

        # 保留其他 segment
        result.extend(content[pos:seg_end])
        pos = seg_end

    return bytes(result)
```

- [ ] **Step 2: Add `orient_if_needed()` method**

Add after `strip_exif_lossless()`:

```python
def orient_if_needed(self, content: bytes, quality: int = 95) -> tuple[bytes, bool]:
    """
    检查 EXIF orientation，仅在需要旋转时才解码和重新编码。

    Args:
        content: 原始图片内容
        quality: 旋转后重新编码的质量（仅在需要旋转时使用）

    Returns:
        (处理后的内容, 是否进行了旋转)
        如果不需要旋转，返回原始 content 不做任何修改。
    """
    if not self.pillow_available:
        return content, False

    try:
        from PIL import Image, ExifTags

        with Image.open(io.BytesIO(content)) as img:
            exif = img.getexif()
            if not exif:
                return content, False

            # 查找 Orientation 标签
            orientation_key = None
            for key, val in ExifTags.TAGS.items():
                if val == 'Orientation':
                    orientation_key = key
                    break

            if orientation_key is None or orientation_key not in exif:
                return content, False

            orientation = exif[orientation_key]

            # orientation == 1 表示正常方向，不需要旋转
            if orientation == 1:
                return content, False

            # 需要旋转 — 解码、旋转、编码（仅此一次）
            original_format = img.format or 'JPEG'

            if orientation == 2:
                img = img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            elif orientation == 3:
                img = img.rotate(180)
            elif orientation == 4:
                img = img.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            elif orientation == 5:
                img = img.rotate(-90, expand=True).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            elif orientation == 6:
                img = img.rotate(-90, expand=True)
            elif orientation == 7:
                img = img.rotate(90, expand=True).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            elif orientation == 8:
                img = img.rotate(90, expand=True)
            else:
                return content, False

            # 重新编码（高质量，仅这一次编码）
            output = io.BytesIO()
            save_kwargs = self._get_save_kwargs(original_format.lower(), quality)
            img.save(output, format=original_format, **save_kwargs)
            return output.getvalue(), True

    except Exception as e:
        logger.error(f"orient_if_needed 失败: {e}")
        return content, False
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/services/image_processor.py
git commit -m "feat: add lossless EXIF strip and orientation-aware processing"
```

---

### Task 2: Backend — Rewrite upload pipeline and update category configs

**Files:**
- Modify: `backend/app/services/image_upload_service.py`

- [ ] **Step 1: Update `UploadConfig` — add `store_original` field**

In `UploadConfig` dataclass (line 52), add a new field:

```python
@dataclass
class UploadConfig:
    """上传配置"""
    max_size: int = 5 * 1024 * 1024  # 最大文件大小（5MB）
    allowed_extensions: Tuple[str, ...] = ('.jpg', '.jpeg', '.png', '.gif', '.webp')
    store_original: bool = False  # True: 存原图(只剥离EXIF)，不压缩不缩小; False: 传统压缩流程
    compress: bool = True  # 是否压缩（store_original=True 时忽略）
    compress_quality: int = 85  # 压缩质量
    convert_to_webp: bool = False  # 是否转换为 WebP
    generate_thumbnails: bool = False  # 是否生成缩略图
    thumbnail_presets: Tuple[str, ...] = ('thumb', 'medium')  # 缩略图预设
    strip_metadata: bool = True  # 是否移除元数据
    auto_orient: bool = True  # 是否自动旋转
    max_dimension: Optional[int] = 2048  # 最大边长（像素），None 表示不限制（store_original=True 时忽略）
```

- [ ] **Step 2: Update `CATEGORY_CONFIGS` for public image categories**

Replace the CATEGORY_CONFIGS dict (lines 68-139):

```python
CATEGORY_CONFIGS: Dict[ImageCategory, UploadConfig] = {
    ImageCategory.TASK: UploadConfig(
        max_size=10 * 1024 * 1024,
        store_original=True,
        generate_thumbnails=True,
        thumbnail_presets=('medium', 'large'),
    ),
    ImageCategory.BANNER: UploadConfig(
        max_size=5 * 1024 * 1024,
        store_original=True,
        # Banner 是展示用，不需要缩略图
    ),
    ImageCategory.ACTIVITY: UploadConfig(
        max_size=10 * 1024 * 1024,
        store_original=True,
        generate_thumbnails=True,
        thumbnail_presets=('medium',),
    ),
    ImageCategory.LEADERBOARD_COVER: UploadConfig(
        max_size=5 * 1024 * 1024,
        store_original=True,
    ),
    ImageCategory.LEADERBOARD_ITEM: UploadConfig(
        max_size=5 * 1024 * 1024,
        store_original=True,
        generate_thumbnails=True,
        thumbnail_presets=('thumb',),
    ),
    ImageCategory.EXPERT_AVATAR: UploadConfig(
        max_size=2 * 1024 * 1024,
        store_original=True,
        # 头像天然小，不需要缩略图
    ),
    ImageCategory.SERVICE_IMAGE: UploadConfig(
        max_size=5 * 1024 * 1024,
        store_original=True,
        generate_thumbnails=True,
        thumbnail_presets=('medium',),
    ),
    ImageCategory.FORUM_POST: UploadConfig(
        max_size=5 * 1024 * 1024,
        store_original=True,
        generate_thumbnails=True,
        thumbnail_presets=('medium', 'large'),
    ),
    ImageCategory.FLEA_MARKET: UploadConfig(
        max_size=10 * 1024 * 1024,
        store_original=True,
        generate_thumbnails=True,
        thumbnail_presets=('thumb', 'medium', 'large'),
    ),
    # 私密图片保持传统压缩流程（对速度要求高，用户不会全屏看）
    ImageCategory.PRIVATE_TASK_CHAT: UploadConfig(
        max_size=5 * 1024 * 1024,
        compress=True,
        compress_quality=80,
        max_dimension=1920
    ),
    ImageCategory.PRIVATE_CS_CHAT: UploadConfig(
        max_size=5 * 1024 * 1024,
        compress=True,
        compress_quality=80,
        max_dimension=1920
    ),
}
```

- [ ] **Step 3: Rewrite the upload processing pipeline in `upload()` method**

Replace the image processing section in `upload()` (lines 240-279) with:

```python
            # 图片处理
            processed_content = content

            if cfg.store_original:
                # === 新管道：存原图，只处理 orientation 和 EXIF ===

                # 1. 检查是否需要旋转（仅需要时才编码一次）
                if cfg.auto_orient:
                    processed_content, was_rotated = self.processor.orient_if_needed(processed_content)

                # 2. 无损剥离 EXIF 元数据（不解码像素）
                if cfg.strip_metadata:
                    processed_content = self.processor.strip_exif_lossless(processed_content)

                # 获取图片尺寸信息
                processed_info = self.processor.get_image_info(processed_content)
                width = processed_info.get('width') if processed_info else None
                height = processed_info.get('height') if processed_info else None

                # 保持原始扩展名
                ext = self._detect_extension(processed_content, filename)
            else:
                # === 传统管道：压缩+缩小（私密图片等） ===

                # 自动旋转
                if cfg.auto_orient:
                    processed_content = self.processor.auto_orient(processed_content)

                # 移除元数据
                if cfg.strip_metadata:
                    processed_content, _ = self.processor.strip_metadata(processed_content)

                # 获取处理后的实际尺寸
                processed_info = self.processor.get_image_info(processed_content)
                width = processed_info.get('width') if processed_info else None
                height = processed_info.get('height') if processed_info else None

                # 调整尺寸
                if cfg.max_dimension and width and height:
                    if width > cfg.max_dimension or height > cfg.max_dimension:
                        processed_content, ext, new_size = self.processor.resize(
                            processed_content,
                            max_width=cfg.max_dimension,
                            max_height=cfg.max_dimension,
                            quality=cfg.compress_quality
                        )
                        width = new_size.width
                        height = new_size.height

                # 转换为 WebP
                if cfg.convert_to_webp:
                    processed_content, ext = self.processor.convert_to_webp(
                        processed_content,
                        quality=cfg.compress_quality
                    )
                # 或者压缩
                elif cfg.compress:
                    processed_content, ext = self.processor.compress(
                        processed_content,
                        quality=cfg.compress_quality
                    )
```

Note: the code after this section (generating filename, building storage path, uploading, generating thumbnails) remains unchanged.

- [ ] **Step 4: Commit**

```bash
git add backend/app/services/image_upload_service.py
git commit -m "feat: store originals for public images, enable thumbnails per category"
```

---

### Task 3: Flutter — Add `getThumbnailUrl()` helper

**Files:**
- Modify: `link2ur/lib/core/utils/helpers.dart`

- [ ] **Step 1: Add `getThumbnailUrl` method**

Add after `getImageUrl()` (after line 178):

```dart
  /// 根据原图 URL 获取缩略图 URL。
  ///
  /// 缩略图命名规则：`{uuid}_medium.webp`、`{uuid}_large.webp` 等，
  /// 与后端 `ThumbnailConfig.name` 一致。
  ///
  /// [size] 可选值: 'thumb'(150px), 'small'(320px), 'medium'(640px), 'large'(1280px)
  ///
  /// 对于无法识别的 URL 格式（旧图、本地路径等），直接返回原图 URL。
  static String getThumbnailUrl(String? url, {String size = 'medium'}) {
    if (url == null || url.isEmpty) return '';

    // 先获取完整 URL
    final fullUrl = getImageUrl(url);
    if (fullUrl.isEmpty) return '';

    // 只处理 CDN URL（包含 cdn.link2ur.com 或 .r2.dev）
    // 旧的本地路径图片没有缩略图，直接返回原图
    if (!fullUrl.contains('cdn.link2ur.com') && !fullUrl.contains('.r2.dev')) {
      return fullUrl;
    }

    // 找到最后一个 '.' 分割文件名和扩展名
    final lastDot = fullUrl.lastIndexOf('.');
    if (lastDot < 0) return fullUrl;

    final basePath = fullUrl.substring(0, lastDot);
    // 缩略图格式固定为 .webp（与后端 ThumbnailConfig 一致）
    return '${basePath}_$size.webp';
  }
```

- [ ] **Step 2: Commit**

```bash
cd link2ur && git add lib/core/utils/helpers.dart
git commit -m "feat: add getThumbnailUrl helper for thumbnail URL derivation"
```

---

### Task 4: Flutter — Add `fallbackUrl` support to `AsyncImageView`

**Files:**
- Modify: `link2ur/lib/core/widgets/async_image_view.dart`

- [ ] **Step 1: Add `fallbackUrl` parameter and fallback logic**

Replace the entire `AsyncImageView` class (lines 12-148) with:

```dart
class AsyncImageView extends StatelessWidget {
  const AsyncImageView({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 150),
    this.memCacheWidth,
    this.memCacheHeight,
    this.semanticLabel,
    this.fallbackUrl,
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  /// 图片淡入时长，缓存命中时应尽量短以减少感知延迟
  final Duration fadeInDuration;

  /// 内存缓存宽度（像素），设置后解码图片会按此尺寸缩小，显著降低内存占用。
  /// 建议设置为 width * devicePixelRatio 的值。
  final int? memCacheWidth;

  /// 内存缓存高度（像素），设置后解码图片会按此尺寸缩小，显著降低内存占用。
  final int? memCacheHeight;

  /// Semantic label for accessibility.
  final String? semanticLabel;

  /// 备用图片 URL。当 [imageUrl] 加载失败时（如缩略图 404），自动尝试加载此 URL。
  /// 典型用法：imageUrl 传缩略图，fallbackUrl 传原图，兼容没有缩略图的旧图片。
  final String? fallbackUrl;

  @override
  Widget build(BuildContext context) {
    final url = Helpers.getImageUrl(imageUrl);

    if (url.isEmpty) {
      return _buildPlaceholder(context);
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);

    final knownCacheWidth = memCacheWidth ??
        (width != null && width!.isFinite ? (width! * dpr).round() : null);

    if (knownCacheWidth != null) {
      return _buildImage(url, knownCacheWidth, null);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final constraintWidth = constraints.maxWidth.isFinite
            ? (constraints.maxWidth * dpr).round()
            : null;
        return _buildImage(url, constraintWidth, null);
      },
    );
  }

  Widget _buildImage(String url, int? effectiveMemCacheWidth, int? effectiveMemCacheHeight) {
    Widget image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: fadeInDuration,
      memCacheWidth: effectiveMemCacheWidth,
      memCacheHeight: effectiveMemCacheHeight,
      placeholder: (context, url) => placeholder ?? _buildPlaceholder(context),
      errorWidget: (context, failedUrl, error) {
        // 如果有 fallbackUrl 且与主 URL 不同，尝试加载 fallback
        final fb = fallbackUrl;
        if (fb != null && fb.isNotEmpty && fb != url) {
          return CachedNetworkImage(
            imageUrl: fb,
            width: width,
            height: height,
            fit: fit,
            fadeInDuration: fadeInDuration,
            memCacheWidth: effectiveMemCacheWidth,
            memCacheHeight: effectiveMemCacheHeight,
            placeholder: (context, url) => placeholder ?? _buildPlaceholder(context),
            errorWidget: (context, url, error) => errorWidget ?? _buildError(context),
          );
        }
        return errorWidget ?? _buildError(context);
      },
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    if (semanticLabel != null) {
      image = Semantics(
        label: semanticLabel,
        image: true,
        child: image,
      );
    }

    return image;
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      decoration: BoxDecoration(
        color: AppColors.skeletonBase,
        borderRadius: borderRadius,
      ),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: AppColors.textTertiaryLight,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      decoration: BoxDecoration(
        color: AppColors.skeletonBase,
        borderRadius: borderRadius,
      ),
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AppColors.textTertiaryLight,
          size: 32,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
cd link2ur && git add lib/core/widgets/async_image_view.dart
git commit -m "feat: add fallbackUrl support to AsyncImageView for old image compatibility"
```

---

### Task 5: Flutter — Remove client-side ImagePicker compression

**Files:**
- Modify: `link2ur/lib/features/forum/views/create_post_view.dart:160-162`
- Modify: `link2ur/lib/features/forum/views/edit_post_view.dart:88-90`
- Modify: `link2ur/lib/features/flea_market/views/create_flea_market_item_view.dart:100-102`
- Modify: `link2ur/lib/features/flea_market/views/edit_flea_market_item_view.dart:141-143`
- Modify: `link2ur/lib/features/tasks/views/create_task_view.dart:368-370`
- Modify: `link2ur/lib/features/tasks/views/task_detail_view.dart:3106-3108`
- Modify: `link2ur/lib/features/tasks/views/task_detail_components.dart:2758`

- [ ] **Step 1: Remove compression from forum create_post_view**

In `create_post_view.dart`, change `_pickImages()` (line 160):

```dart
      final files = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        imageQuality: 85,
      );
```
→
```dart
      final files = await _imagePicker.pickMultiImage();
```

- [ ] **Step 2: Remove compression from forum edit_post_view**

In `edit_post_view.dart`, change `_pickImages()` (line 88):

```dart
      final files = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        imageQuality: 85,
      );
```
→
```dart
      final files = await _imagePicker.pickMultiImage();
```

- [ ] **Step 3: Remove compression from flea_market create view**

In `create_flea_market_item_view.dart`, change `_pickImages()` (line 100):

```dart
      final pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        imageQuality: 85,
      );
```
→
```dart
      final pickedFiles = await _imagePicker.pickMultiImage();
```

- [ ] **Step 4: Remove compression from flea_market edit view**

In `edit_flea_market_item_view.dart`, change `_pickImages()` (line 141):

```dart
      final picked = await picker.pickMultiImage(
        maxWidth: 1200,
        imageQuality: 80,
      );
```
→
```dart
      final picked = await picker.pickMultiImage();
```

- [ ] **Step 5: Remove compression from task create view**

In `create_task_view.dart`, change `_pickImages()` (line 368):

```dart
    final picked = await _imagePicker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1920,
    );
```
→
```dart
    final picked = await _imagePicker.pickMultiImage();
```

- [ ] **Step 6: Remove compression from task_detail_view evidence picker**

In `task_detail_view.dart`, change `_pickImages()` (line 3106):

```dart
    final picked = await _imagePicker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1920,
    );
```
→
```dart
    final picked = await _imagePicker.pickMultiImage();
```

- [ ] **Step 7: Remove compression from task_detail_components evidence picker**

In `task_detail_components.dart`, change `_pickImages()` (line 2758):

```dart
    final picked = await _imagePicker.pickMultiImage(imageQuality: 80, maxWidth: 1920);
```
→
```dart
    final picked = await _imagePicker.pickMultiImage();
```

- [ ] **Step 8: Commit**

```bash
cd link2ur && git add lib/features/forum/views/create_post_view.dart lib/features/forum/views/edit_post_view.dart lib/features/flea_market/views/create_flea_market_item_view.dart lib/features/flea_market/views/edit_flea_market_item_view.dart lib/features/tasks/views/create_task_view.dart lib/features/tasks/views/task_detail_view.dart lib/features/tasks/views/task_detail_components.dart
git commit -m "feat: remove client-side image compression, let backend handle processing"
```

---

### Task 6: Flutter — Use thumbnail URLs in discovery cards

**Files:**
- Modify: `link2ur/lib/features/home/views/home_discovery_cards.dart`

Discovery cards display public images in a small card layout (~180pt wide). These should use `_medium` (640px) thumbnails instead of full originals.

- [ ] **Step 1: Update all `AsyncImageView` calls in discovery cards to use thumbnail + fallback**

There are 7 `AsyncImageView` usages in `home_discovery_cards.dart` that display `item.firstImage!`. Each one needs to change from:

```dart
AsyncImageView(
  imageUrl: item.firstImage!,
  ...
)
```

to:

```dart
AsyncImageView(
  imageUrl: Helpers.getThumbnailUrl(item.firstImage!, size: 'medium'),
  fallbackUrl: Helpers.getImageUrl(item.firstImage!),
  ...
)
```

The 7 locations (all displaying `item.firstImage!`):
- Line 55 (`_PostCard`)
- Line 248 (`_TaskCard`)
- Line 675 (`_FleaMarketCard`)
- Line 834 (`_ActivityCard`)
- Line 1109 (leaderboard target thumbnail — this one is already tiny, skip it)
- Line 1271 (`_ServiceCard`)
- Line 1473 (`_ExpertCard`)

Apply the change to lines 55, 248, 675, 834, 1271, 1473 (skip 1109 which is already a different thumbnail).

Also add the import at the top of the file if not already present. Since this is `part of 'home_view.dart'`, `Helpers` should already be accessible. Verify by checking imports in `home_view.dart`.

- [ ] **Step 2: Commit**

```bash
cd link2ur && git add lib/features/home/views/home_discovery_cards.dart
git commit -m "feat: use thumbnail URLs in discovery cards for faster loading"
```

---

### Task 7: Flutter — Use appropriate image sizes in task detail and forum detail

**Files:**
- Modify: `link2ur/lib/features/tasks/views/task_detail_view.dart`
- Modify: `link2ur/lib/features/forum/views/forum_post_detail_view.dart`

- [ ] **Step 1: Update task detail image carousel (task_detail_view.dart:1544)**

The task detail carousel displays images at full width (~390pt). Use `_large` (1280px) thumbnail, with original as fallback.

Change (around line 1544):

```dart
              final imageWidget = AsyncImageView(
                imageUrl: images[index],
                width: double.infinity,
                height: 300,
              );
```
→
```dart
              final imageWidget = AsyncImageView(
                imageUrl: Helpers.getThumbnailUrl(images[index], size: 'large'),
                fallbackUrl: Helpers.getImageUrl(images[index]),
                width: double.infinity,
                height: 300,
              );
```

Note: `FullScreenImageView.show()` already uses original URLs via `Helpers.getImageUrl()` in `full_screen_image_view.dart:95`, so full-screen viewing is unaffected.

- [ ] **Step 2: Update task detail evidence images (task_detail_view.dart:3053)**

The 80x80 evidence thumbnails. Use `_medium` (640px):

Change (around line 3053):

```dart
                              child: AsyncImageView(
                                imageUrl: url,
                                width: 80,
                                height: 80,
```
→
```dart
                              child: AsyncImageView(
                                imageUrl: Helpers.getThumbnailUrl(url, size: 'medium'),
                                fallbackUrl: Helpers.getImageUrl(url),
                                width: 80,
                                height: 80,
```

- [ ] **Step 3: Check forum_post_detail_view for image display**

Search for `AsyncImageView` usage in `forum_post_detail_view.dart` and apply the same pattern — `_large` for full-width images, `_medium` for thumbnails. The `FullScreenImageView` calls should continue using original URLs (they already do via `Helpers.getImageUrl`).

Find the post image gallery (around line 1353 based on earlier search) and update similarly:

```dart
AsyncImageView(
  imageUrl: Helpers.getThumbnailUrl(imageUrl, size: 'large'),
  fallbackUrl: Helpers.getImageUrl(imageUrl),
  ...
)
```

- [ ] **Step 4: Commit**

```bash
cd link2ur && git add lib/features/tasks/views/task_detail_view.dart lib/features/forum/views/forum_post_detail_view.dart
git commit -m "feat: use large thumbnails in detail views, originals for full-screen"
```

---

### Task 8: Flutter — Use thumbnail URLs in remaining list views

**Files:**
- Modify: `link2ur/lib/features/tasks/views/tasks_view.dart` (task list)
- Modify: `link2ur/lib/features/flea_market/views/flea_market_view.dart` (flea market list)
- Modify: `link2ur/lib/features/flea_market/views/flea_market_detail_view.dart` (flea market detail)
- Modify: `link2ur/lib/features/forum/views/forum_view.dart` (forum list, if applicable)

- [ ] **Step 1: Search for AsyncImageView usages displaying public images in each file**

For each file, find `AsyncImageView` calls that display user-uploaded public images (not avatars, not local assets). Apply the pattern:

- List/card views: use `Helpers.getThumbnailUrl(url, size: 'medium')` with `fallbackUrl: Helpers.getImageUrl(url)`
- Detail/full-width views: use `Helpers.getThumbnailUrl(url, size: 'large')` with `fallbackUrl: Helpers.getImageUrl(url)`
- Full-screen viewers: keep using original URL (already the case)

- [ ] **Step 2: Commit**

```bash
cd link2ur && git add lib/features/tasks/views/tasks_view.dart lib/features/flea_market/views/flea_market_view.dart lib/features/flea_market/views/flea_market_detail_view.dart lib/features/forum/views/forum_view.dart
git commit -m "feat: use thumbnail URLs in task, flea market, and forum list views"
```

---

### Task 9: Verify — Run Flutter analyze

- [ ] **Step 1: Run flutter analyze**

```powershell
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"
flutter analyze
```

Expected: No new errors. Fix any issues found.

- [ ] **Step 2: Commit fixes if any**

```bash
git add -A && git commit -m "fix: resolve flutter analyze issues"
```

---

### Task 10: Final commit — Update CLAUDE.md memory

- [ ] **Step 1: Commit all remaining changes**

```bash
git add -A && git commit -m "feat: image quality optimization — store originals, serve thumbnails

- Backend: store original images (lossless EXIF strip only), generate thumbnails
- Flutter: remove client-side compression, use thumbnail URLs for lists/cards
- Backward compatible: old images without thumbnails fall back to original URL"
```
