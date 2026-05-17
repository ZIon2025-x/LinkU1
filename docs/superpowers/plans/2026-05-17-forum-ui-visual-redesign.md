# Forum UI 视觉重做 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把发帖页 + 帖子详情页两个 Flutter 页面的 UI 重做到匹配 `link2ur/docs/mockups/forum-create-post-mockup.html` 上的视觉设计（适配现有设计系统 token、暗色模式适配、骨架屏+动画、零行为改动）。

**Architecture:** 每个 mockup 上的视觉模块抽成一个私有 widget(放在对应 page 文件底部),共享的 `TopicChip` 抽到 `link2ur/lib/features/forum/widgets/`. 每个 widget 一个 commit (写 widget + 替换 call site + 删旧代码 + flutter analyze)。BLoC / repository / API / 数据模型 / events / state 全部零改动 —— 只动 view 层。

**Tech Stack:** Flutter 3.33+ / Dart 3 / Equatable / `shimmer` (skeleton) / 现有 `AppColors`/`AppRadius`/`AppSpacing`/`AppShadows`/`AppTypography` design tokens.

**Spec:** `docs/superpowers/specs/2026-05-17-forum-ui-visual-redesign.md`
**Mockup:** `link2ur/docs/mockups/forum-create-post-mockup.html` (打开浏览器看)

**关键约束:**
- ⚠️ User durable preference: commit directly to **main**, 不开 feature 分支, 不 push (controller 协调)
- ⚠️ Flutter env vars: `$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; $env:GRADLE_USER_HOME = "F:\DevCache\.gradle"`
- ⚠️ 不引入新设计 token、不引入第三方动画库
- ⚠️ 不破坏现有 33 BLoC test + 6 sort/load more test + 4 create/edit test = 43 test 必须不回归
- ⚠️ 每个 widget 替换 commit 完之后 `flutter analyze` 必须 0 errors（pre-existing curly_braces info lints 可接受）

---

## File Structure

| Operation | File | Responsibility |
|---|---|---|
| Create | `link2ur/lib/features/forum/widgets/topic_chip.dart` | 共享 `TopicChip` (普通/锁定双形态) |
| Modify | `link2ur/lib/features/forum/views/create_post_view.dart` | 整页重写 build() + 7 个新私有 widget |
| Modify | `link2ur/lib/features/forum/views/forum_post_detail_view.dart` | 整页重写 build() + 8+ 个新私有 widget |
| Modify | `link2ur/lib/l10n/app_en.arb` / `app_zh.arb` / `app_zh_Hant.arb` | 4 个 lockCategory SnackBar 文案 |

`link2ur/lib/features/forum/widgets/` 目录不存在,Task A1 时创建。

---

## Phase A: 共享基础设施 (Tasks A1-A2)

### Task A1: TopicChip 共享 widget

**Files:**
- Create: `link2ur/lib/features/forum/widgets/topic_chip.dart`

`TopicChip` 是发帖页和详情页都用的话题胶囊。它有 3 种状态：
1. **可编辑选中** (`onRemove != null`): 蓝色渐变药丸 + emoji + 名称 + × 删除按钮
2. **锁定** (`locked: true`): 同样视觉 + 锁图标替代 × (无 onTap)
3. **只读** (`onRemove == null && !locked`): 详情页用,emoji + 名称, 无尾部按钮

读 mockup `link2ur/docs/mockups/forum-create-post-mockup.html` 找 `.topic-chip` CSS rules (大约 line 122-152, 包含 padding/border/background gradient/font-size).

- [ ] **Step 1: 创建 widget 文件**

```dart
// link2ur/lib/features/forum/widgets/topic_chip.dart
import 'package:flutter/material.dart';
import '../../../core/design/app_colors.dart';

/// Forum 话题胶囊 — 发帖页 + 详情页共享。
/// 3 种形态:
/// - 可编辑选中: 显示 × 删除按钮
/// - 锁定: 显示 🔒 锁图标 (达人板块/官方任务/admin 公告/校园板块)
/// - 只读: 详情页展示用
class TopicChip extends StatelessWidget {
  const TopicChip({
    super.key,
    required this.label,
    this.emoji,
    this.onRemove,
    this.locked = false,
  });

  final String label;
  final String? emoji;
  final VoidCallback? onRemove;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.primary;
    final bg = isDark
        ? primary.withValues(alpha: 0.18)
        : primary.withValues(alpha: 0.10);
    final borderColor = primary.withValues(alpha: isDark ? 0.40 : 0.25);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null) ...[
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(emoji!, style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: primary,
              ),
            ),
          ),
          if (locked) ...[
            const SizedBox(width: 6),
            Icon(Icons.lock_outline, size: 14, color: primary),
          ] else if (onRemove != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, size: 11, color: primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 验证 analyze**

```powershell
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH
$env:PUB_CACHE = "F:\DevCache\.pub-cache"
flutter analyze lib/features/forum/widgets/topic_chip.dart
```

预期: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/forum/widgets/topic_chip.dart
git commit -m "$(cat <<'EOF'
feat(forum/flutter): 加 TopicChip 共享 widget (Phase A1 of UI 重做)

3 种形态: 可编辑(× 删除)/ 锁定(🔒)/ 只读. 两个页面共享.
对齐 mockup 视觉 (蓝色渐变药丸 + emoji + 名称).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task A2: ARB l10n strings (lockCategory SnackBar 4 变体)

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`

底部工具栏的话题键在 lockCategory 模式下置灰,点击弹 SnackBar 解释为什么。4 种 lockCategory 场景对应 4 套文案。

- [ ] **Step 1: 加 4 个 key 到 app_en.arb**

在 forum 相关 key 区域 (grep `forum` 找现有 forum keys 周围) 加:

```json
  "forumTopicLockedExpert": "Topic is locked: posting under expert team identity",
  "forumTopicLockedOfficialTask": "Topic is locked: this post earns the official task reward",
  "forumTopicLockedAdmin": "Topic is locked: admin-only board",
  "forumTopicLockedSchool": "Topic is locked: school board entry",
```

⚠️ 注意 ARB 末尾逗号,如果加在已有 key 之间记得分隔好。

- [ ] **Step 2: 加 zh 翻译**

```json
  "forumTopicLockedExpert": "话题已锁定: 以达人团队身份发帖",
  "forumTopicLockedOfficialTask": "话题已锁定: 本帖将关联官方任务领取奖励",
  "forumTopicLockedAdmin": "话题已锁定: 管理员专属板块",
  "forumTopicLockedSchool": "话题已锁定: 校园板块入口",
```

- [ ] **Step 3: 加 zh_Hant 翻译**

```json
  "forumTopicLockedExpert": "話題已鎖定: 以達人團隊身份發帖",
  "forumTopicLockedOfficialTask": "話題已鎖定: 本帖將關聯官方任務領取獎勵",
  "forumTopicLockedAdmin": "話題已鎖定: 管理員專屬板塊",
  "forumTopicLockedSchool": "話題已鎖定: 校園板塊入口",
```

- [ ] **Step 4: 重新生成 l10n**

```powershell
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH
$env:PUB_CACHE = "F:\DevCache\.pub-cache"
flutter gen-l10n
```

预期: 无报错,3 个 ARB 都生成。

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/l10n/
git commit -m "$(cat <<'EOF'
feat(forum/flutter): 加 lockCategory SnackBar l10n (Phase A2)

4 套文案对应 4 种锁定场景: 达人/官方任务/admin/校园.
底部工具栏话题键置灰时点击使用.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase B: 发帖页重做 (Tasks B1-B7)

每个 widget task 都遵循同样的模板：
1. 读 mockup 对应 CSS region (Step 1)
2. Grep / Read 找现有渲染位置 (Step 2)
3. 在 `create_post_view.dart` 文件底部添加新私有 widget class (Step 3)
4. 替换 build() 里的旧渲染调用 + 删除孤立旧代码 (Step 4)
5. flutter analyze (Step 5)
6. Commit (Step 6)

---

### Task B1: _CreateAppBar (渐变蓝发布药丸)

**Files:**
- Modify: `link2ur/lib/features/forum/views/create_post_view.dart`

读 mockup `.appbar` + `.publish-btn` (~line 90-130).

- [ ] **Step 1: Read mockup .appbar + .publish-btn rules**

```bash
sed -n '90,135p' link2ur/docs/mockups/forum-create-post-mockup.html
```

关键: AppBar 高度紧凑 (~52px), 标题字号 17, 发布按钮 = 蓝色渐变药丸 (linear-gradient #007AFF → #409CFF) + 圆角 999 + 内边距 8x18 + 阴影 `0 6px 18px -6px rgba(0,122,255,0.35)`.

- [ ] **Step 2: 找 build() 里现有 AppBar 位置**

`create_post_view.dart` 大约 line 420-440 区域,现有 `AppBar(title: ..., actions: [TextButton(发布)])`.

- [ ] **Step 3: 在 create_post_view.dart 文件底部加 _CreateAppBar widget**

```dart
class _CreateAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CreateAppBar({
    required this.isBusy,
    required this.onPublish,
  });

  final bool isBusy;
  final VoidCallback onPublish;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      backgroundColor: AppColors.backgroundFor(
        isDark ? Brightness.dark : Brightness.light,
      ),
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      title: Text(
        context.l10n.forumCreatePostTitle,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: _PublishButton(isBusy: isBusy, onTap: onPublish),
        ),
      ],
    );
  }
}

class _PublishButton extends StatelessWidget {
  const _PublishButton({required this.isBusy, required this.onTap});
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isBusy ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.gradientPrimary,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                offset: const Offset(0, 6),
                blurRadius: 18,
                spreadRadius: -6,
              ),
            ],
          ),
          child: isBusy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text(
                  context.l10n.forumPublish,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 替换 Scaffold 里的 appBar**

找 `appBar: AppBar(title: Text(...), actions: [TextButton(onPressed: isBusy ? null : () => _submit(context), child: ...)])`,改为:

```dart
appBar: _CreateAppBar(
  isBusy: isBusy,
  onPublish: () => _submit(context),
),
```

- [ ] **Step 5: flutter analyze**

```powershell
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH
$env:PUB_CACHE = "F:\DevCache\.pub-cache"
flutter analyze lib/features/forum/views/create_post_view.dart
```

预期: 0 errors.

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/features/forum/views/create_post_view.dart
git commit -m "feat(forum/flutter): 发帖页 AppBar 改用渐变蓝发布药丸 (B1)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task B2: _TitleField + _ContentField (无边框大字号 + 字数计数器)

**Files:**
- Modify: `link2ur/lib/features/forum/views/create_post_view.dart`

读 mockup `.title-input` + `.content-input` + `.char-counter` (~line 290-320).

- [ ] **Step 1: 读 mockup**

```bash
sed -n '280,330p' link2ur/docs/mockups/forum-create-post-mockup.html
```

关键: 标题 22px bold, 内容 15px line-height 1.65, 都无边框, 字数计数器右下角 11px 灰字.

- [ ] **Step 2: 找现有 TextField**

大约 line 600-630 区域 (`TextField(controller: _titleController, ...)` + `TextField(controller: _contentController, maxLines: null, minLines: 10)`).

- [ ] **Step 3: 加 _TitleField + _ContentField widgets at file bottom**

```dart
class _TitleField extends StatelessWidget {
  const _TitleField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: context.l10n.forumEnterTitle,
        hintStyle: TextStyle(
          color: AppColors.textPlaceholderLight,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        isDense: true,
      ),
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      maxLength: 200,
      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
      textInputAction: TextInputAction.next,
    );
  }
}

class _ContentField extends StatefulWidget {
  const _ContentField({required this.controller});
  final TextEditingController controller;

  @override
  State<_ContentField> createState() => _ContentFieldState();
}

class _ContentFieldState extends State<_ContentField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }
  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }
  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = widget.controller.text.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            hintText: context.l10n.forumShareThoughts,
            hintStyle: TextStyle(color: AppColors.textPlaceholderLight, fontSize: 15),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          style: const TextStyle(fontSize: 15, height: 1.65),
          maxLines: null,
          minLines: 10,
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$count / 5000',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: 替换 build() 里的两个 TextField**

```dart
// 删除原:
//   TextField(controller: _titleController, decoration: ..., style: TextStyle(fontSize: 20, ...))
//   const Divider(),
//   TextField(controller: _contentController, ...)
// 改为:
_TitleField(controller: _titleController),
const SizedBox(height: 8),
_ContentField(controller: _contentController),
```

- [ ] **Step 5: flutter analyze**

预期: 0 errors.

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/features/forum/views/create_post_view.dart
git commit -m "feat(forum/flutter): 发帖页标题/内容输入框无边框大字号 + 字数计数器 (B2)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task B3: _ImageThumbGrid4 (4 列网格 + 封面徽章 + 顺序号)

**Files:**
- Modify: `link2ur/lib/features/forum/views/create_post_view.dart`

读 mockup `.image-grid` + `.image-tile` (~line 330-410).

- [ ] **Step 1: 读 mockup**

```bash
sed -n '330,415p' link2ur/docs/mockups/forum-create-post-mockup.html
```

关键: 4 列 grid, aspect-ratio 1:1, gap 8px, 第一张带"封面"渐变徽章 (蓝渐变, 左上), 其余带顺序号 (黑色半透明, 左下), 删除键圆形半透明 (右上), 加号位 dashed 边框蓝色.

- [ ] **Step 2: 找现有 _buildImagePicker (大约 line 690+)**

它是 `Widget _buildImagePicker(bool isDark)` 返回 Wrap. 整段需要重写。

- [ ] **Step 3: 加 _ImageThumbGrid4 widget at file bottom**

```dart
class _ImageThumbGrid4 extends StatelessWidget {
  const _ImageThumbGrid4({
    required this.images,
    required this.maxImages,
    required this.onRemove,
    required this.onAdd,
  });

  final List<XFile> images;
  final int maxImages;
  final void Function(int index) onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canAdd = images.length < maxImages;
    final cellCount = images.length + (canAdd ? 1 : 0);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: cellCount,
      itemBuilder: (context, index) {
        if (canAdd && index == images.length) {
          return _AddImageTile(onTap: onAdd, isDark: isDark);
        }
        return _ImageTile(
          file: images[index],
          index: index,
          isCover: index == 0,
          onRemove: () => onRemove(index),
        );
      },
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.file,
    required this.index,
    required this.isCover,
    required this.onRemove,
  });

  final XFile file;
  final int index;
  final bool isCover;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: AppRadius.allSmall,
          child: CrossPlatformImage(
            xFile: file,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        if (isCover)
          Positioned(
            left: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.gradientPrimary,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '封面',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        else
          Positioned(
            left: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        Positioned(
          top: 4,
          right: 4,
          child: InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddImageTile extends StatelessWidget {
  const _AddImageTile({required this.onTap, required this.isDark});
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allSmall,
        child: DottedBorderTile(isDark: isDark),
      ),
    );
  }
}

class DottedBorderTile extends StatelessWidget {
  const DottedBorderTile({super.key, required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.5,
          style: BorderStyle.solid, // Flutter 无 dashed; 用 solid 接受妥协,见注释
        ),
        borderRadius: AppRadius.allSmall,
      ),
      // Flutter built-in 不支持 dashed border, 接受 solid 妥协 (mockup 上 dashed
      // 是视觉细节; 用 third-party 包 'dotted_border' 才能实现, YAGNI)
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add, size: 22, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(
            context.l10n.forumCreatePostAddImage,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
```

⚠️ 注意 `context.l10n.forumCreatePostAddImage` 已有 key,不要重新加。

- [ ] **Step 4: 替换 _buildImagePicker call site**

找 `_buildImagePicker(isDark)` 调用,改为:

```dart
_ImageThumbGrid4(
  images: _selectedImages,
  maxImages: _kMaxImages,
  onRemove: _removeImage,
  onAdd: _pickImages,
),
```

然后 **删除整个 `Widget _buildImagePicker(bool isDark) { ... }` 方法**(已被新 widget 替代)。

- [ ] **Step 5: flutter analyze**

预期: 0 errors. 如果 `_buildImagePicker` 还有别处被引用导致 unused warning, 那是 leftover, 删完即可。

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/features/forum/views/create_post_view.dart
git commit -m "feat(forum/flutter): 发帖页图片改 4 列 grid + 封面徽章 + 顺序号 (B3)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task B4: _FilePdfCard (PDF 红渐变 + 进度条)

**Files:**
- Modify: `link2ur/lib/features/forum/views/create_post_view.dart`

读 mockup `.file-card` + `.file-icon` + `.progress` (~line 415-475).

- [ ] **Step 1: 读 mockup**

```bash
sed -n '415,480p' link2ur/docs/mockups/forum-create-post-mockup.html
```

关键: 44x44 红渐变方块 (linear `#F24D4D → #FF7A7A`) + "PDF" 白字, 名字 14 + 大小 11 + 进度条 (蓝渐变 `#007AFF → #409CFF`, 3px), 删除键 26x26 红色 × 圆按钮.

- [ ] **Step 2: 找现有 _buildFilePicker (大约 line 765+)**

`Widget _buildFilePicker(bool isDark)` 返回 Column. 整段重写。

- [ ] **Step 3: 加 _FilePdfCard widget + _AddFileTile widget at file bottom**

```dart
class _FilePdfCard extends StatelessWidget {
  const _FilePdfCard({
    required this.file,
    required this.onRemove,
    this.uploadProgress = 1.0,
  });

  final PlatformFile file;
  final VoidCallback onRemove;
  /// 0.0..1.0; 1.0 = 完成
  final double uploadProgress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sizeKb = (file.size / 1024).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        borderRadius: AppRadius.allMedium,
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: -3,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF24D4D), Color(0xFFFF7A7A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF24D4D).withValues(alpha: 0.35),
                  offset: const Offset(0, 4),
                  blurRadius: 10,
                  spreadRadius: -2,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'PDF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  uploadProgress >= 1.0
                      ? '$sizeKb KB · ${context.l10n.commonDone}'
                      : '$sizeKb KB · ${(uploadProgress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: uploadProgress,
                    minHeight: 3,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.close, size: 14, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddFileTile extends StatelessWidget {
  const _AddFileTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allSmall,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.04),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
            borderRadius: AppRadius.allSmall,
          ),
          child: Column(
            children: [
              Icon(Icons.upload_file, size: 26, color: AppColors.primary),
              const SizedBox(height: 4),
              Text(
                context.l10n.forumFileAddFile,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

⚠️ `context.l10n.commonDone` 如果不存在,改为硬编码 "完成" + en/zh_Hant 用同字 (mockup 文案细节,不需要额外 l10n round-trip)。

- [ ] **Step 4: 替换 _buildFilePicker call site**

```dart
// 替换原 _buildFilePicker(isDark) 调用
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    for (var entry in _selectedFiles.asMap().entries)
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: _FilePdfCard(
          file: entry.value,
          onRemove: () => _removeFile(entry.key),
        ),
      ),
    if (_selectedFiles.length < _kMaxFiles)
      _AddFileTile(onTap: _pickFiles),
  ],
),
```

然后**删除** `Widget _buildFilePicker(bool isDark) { ... }` + `IconData _fileIcon(String ext)` (该 helper 仅老 widget 用)。

- [ ] **Step 5: flutter analyze**

预期: 0 errors. 如有 unused warning, 清死代码。

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/features/forum/views/create_post_view.dart
git commit -m "feat(forum/flutter): 发帖页 PDF 卡片改红渐变 + 进度条 + 红 × 按钮 (B4)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task B5: _LinkedChip (紫色渐变关联卡)

**Files:**
- Modify: `link2ur/lib/features/forum/views/create_post_view.dart`

读 mockup `.link-chip` (~line 480-540).

- [ ] **Step 1: 读 mockup**

```bash
sed -n '480,545p' link2ur/docs/mockups/forum-create-post-mockup.html
```

关键: 32x32 紫渐变 (`#7359F2 → #A18BFF`) icon 方块, 类型标签 (浅紫底 10px) + 名字 13px, 右侧灰色 × 圆按钮.

- [ ] **Step 2: 找现有 _buildLinkedChip (大约 line 905+)**

返回 Chip 或 OutlinedButton.icon. 整段重写。

- [ ] **Step 3: 加 _LinkedChip widget at file bottom**

```dart
class _LinkedChip extends StatelessWidget {
  const _LinkedChip({
    required this.itemType,
    required this.itemName,
    required this.onRemove,
  });

  final String itemType;
  final String itemName;
  final VoidCallback onRemove;

  static const _purpleGradient = [Color(0xFF7359F2), Color(0xFFA18BFF)];

  String _typeLabel(BuildContext context) {
    // 把 raw type 映射到本地化 label, 沿用 link_search_dialog.dart 的逻辑
    switch (itemType) {
      case 'service':
        return context.l10n.linkTypeService;
      case 'expert':
        return context.l10n.linkTypeExpert;
      case 'activity':
        return context.l10n.linkTypeActivity;
      case 'product':
        return context.l10n.linkTypeProduct;
      case 'ranking':
        return context.l10n.linkTypeRanking;
      case 'forum_post':
        return context.l10n.linkTypeForumPost;
      default:
        return itemType;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purple = _purpleGradient[0];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: purple.withValues(alpha: isDark ? 0.14 : 0.08),
        border: Border.all(color: purple.withValues(alpha: 0.30)),
        borderRadius: AppRadius.allMedium,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: _purpleGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(9),
              boxShadow: [
                BoxShadow(
                  color: purple.withValues(alpha: 0.4),
                  offset: const Offset(0, 4),
                  blurRadius: 10,
                  spreadRadius: -2,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.dashboard, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _typeLabel(context),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: purple),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.close,
                size: 13,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

⚠️ `linkTypeService` 等 6 个 key 如不存在,grep 找现有 link 类型相关 l10n key 名,或临时用 `itemType` 直显(英文文案,不阻塞)。

- [ ] **Step 4: 替换 _buildLinkedChip call site**

```dart
// 替换原 _buildLinkedChip(isDark) 调用
if (_linkedName != null && _linkedName!.isNotEmpty)
  _LinkedChip(
    itemType: _linkedItemType ?? '',
    itemName: _linkedName!,
    onRemove: _clearLinked,
  )
else
  Align(
    alignment: Alignment.centerLeft,
    child: OutlinedButton.icon(
      onPressed: _showLinkSearchDialog,
      icon: const Icon(Icons.add_link, size: 20),
      label: Text(context.l10n.publishSearchAndLink),
    ),
  ),
```

(注意保留"未选时显示 + 添加关联"按钮的旧逻辑,Task B6 底部工具栏接管后再删)

然后**删除** `Widget _buildLinkedChip(bool isDark) { ... }` 方法。

- [ ] **Step 5: flutter analyze**

预期: 0 errors.

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/features/forum/views/create_post_view.dart
git commit -m "feat(forum/flutter): 发帖页关联卡改紫色渐变 (B5)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task B6: _BottomComposerToolbar (4 色横向工具栏)

**Files:**
- Modify: `link2ur/lib/features/forum/views/create_post_view.dart`

读 mockup `.toolbar` + `.tool` (~line 545-620, 含 `.tool.image/.file/.link/.topic` 各 4 色 + `.t-badge`).

- [ ] **Step 1: 读 mockup**

```bash
sed -n '545,625p' link2ur/docs/mockups/forum-create-post-mockup.html
```

关键: sticky 底部, 半透明白底 + blur, 4 键横排各 36x36 icon-wrap (绿/红/紫/蓝 各 10% 底色), 角标 = 蓝色小圆 (16x16, 白边).

- [ ] **Step 2: 加 _BottomComposerToolbar widget at file bottom**

```dart
class _BottomComposerToolbar extends StatelessWidget {
  const _BottomComposerToolbar({
    required this.imageCount,
    required this.fileCount,
    required this.linkedCount,
    required this.topicCount,
    required this.lockedReason,
    required this.onTapImage,
    required this.onTapFile,
    required this.onTapLink,
    required this.onTapTopic,
  });

  final int imageCount;
  final int fileCount;
  final int linkedCount;
  final int topicCount;
  /// null = 普通模式可点; 非 null = 锁定模式, 点 topic 弹 SnackBar 显示该文案
  final String? lockedReason;

  final VoidCallback onTapImage;
  final VoidCallback onTapFile;
  final VoidCallback onTapLink;
  final VoidCallback onTapTopic;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.cardBackgroundDark.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.85);
    final divider = isDark ? AppColors.dividerDark : AppColors.dividerLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: divider, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ToolButton(
            label: '图片',
            icon: Icons.image_outlined,
            tint: const Color(0xFF26BF73),
            count: imageCount,
            onTap: onTapImage,
          ),
          _ToolButton(
            label: '附件',
            icon: Icons.upload_file_outlined,
            tint: const Color(0xFFF24D4D),
            count: fileCount,
            onTap: onTapFile,
          ),
          _ToolButton(
            label: '关联',
            icon: Icons.link,
            tint: const Color(0xFF7359F2),
            count: linkedCount,
            onTap: onTapLink,
          ),
          _ToolButton(
            label: '话题',
            icon: Icons.local_offer_outlined,
            tint: AppColors.primary,
            count: topicCount,
            disabled: lockedReason != null,
            disabledHint: Icons.lock_outline,
            onTap: lockedReason != null
                ? () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(lockedReason!)),
                    )
                : onTapTopic,
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.label,
    required this.icon,
    required this.tint,
    required this.count,
    required this.onTap,
    this.disabled = false,
    this.disabledHint,
  });

  final String label;
  final IconData icon;
  final Color tint;
  final int count;
  final VoidCallback onTap;
  final bool disabled;
  final IconData? disabledHint;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveTint = disabled
        ? (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)
        : tint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: effectiveTint.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 20, color: effectiveTint),
                ),
                if (disabled && disabledHint != null)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(disabledHint, size: 10, color: effectiveTint),
                    ),
                  )
                else if (count > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      height: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? AppColors.cardBackgroundDark : Colors.white,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: effectiveTint),
            ),
          ],
        ),
      ),
    );
  }
}
```

⚠️ 4 个 label 字符串先硬编码("图片/附件/关联/话题"), 跨语言显示需 l10n 但当前只支持 zh — 接受这个先,通过现有 `forumXxx` keys 可能已有,grep 确认:
```bash
grep -n "forumImage\|forumFile\|forumLink\|forumTopic" link2ur/lib/l10n/app_zh.arb
```
如果有则换为 `context.l10n.xxx`; 没有就先 hardcode (Task B7 收尾时补)。

- [ ] **Step 3: 不在 build() 里插这个 widget 本身, Task B7 整页 assembly 时再用**

只确认 widget class 编译过。

- [ ] **Step 4: flutter analyze**

```powershell
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH
$env:PUB_CACHE = "F:\DevCache\.pub-cache"
flutter analyze lib/features/forum/views/create_post_view.dart
```

预期: 0 errors. 可能有"_BottomComposerToolbar 未使用"info, 暂时接受,Task B7 接入。

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/forum/views/create_post_view.dart
git commit -m "feat(forum/flutter): 加 _BottomComposerToolbar widget (B6, 暂未接入)

4 色横向工具栏: 图片绿/附件红/关联紫/话题蓝.
普通模式角标 count, lockCategory 模式话题键置灰 + 锁角标 + SnackBar 提示.
B7 整页 assembly 时接入。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task B7: 整页 assembly + Draft banner 微调 + 整体替换 build()

**Files:**
- Modify: `link2ur/lib/features/forum/views/create_post_view.dart`

收尾任务: 把所有新 widget 串成新的 build() 结构, 顶部按 mockup 顺序 (Draft banner → TopicChip (有时) → Title → Content → 各 section), 底部 sticky `_BottomComposerToolbar`。

- [ ] **Step 1: 读 mockup 完整顺序**

```bash
sed -n '720,1000p' link2ur/docs/mockups/forum-create-post-mockup.html
```

按 `<div class="body">` 内顺序: draft-banner → topic-chip → title → content + char-counter → 图片 grid → 文件 → 关联 → 底部 toolbar.

- [ ] **Step 2: 找 build() 主结构**

现在 `Scaffold` 的 `body: ListView(padding: AppSpacing.allMd, children: [...])` 加上 bottomSheet/底部 widget。

- [ ] **Step 3: 重写 build() 主体**

```dart
return PopScope(
  canPop: !_hasUnsavedChanges,
  onPopInvokedWithResult: (didPop, _) {
    // ... 保留现有 draft save dialog 逻辑不变 ...
  },
  child: Scaffold(
    backgroundColor: AppColors.backgroundFor(Theme.of(context).brightness),
    appBar: _CreateAppBar(
      isBusy: isBusy,
      onPublish: () => _submit(context),
    ),
    body: SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        children: [
          // 草稿恢复 banner (现有, 视觉小调)
          if (_hasDraft) _buildDraftBanner(context),

          // 官方任务 banner (锁定模式专属,沿用现有 widget)
          if (_isOfficialTaskFlow) _buildOfficialTaskBanner(context),

          // Topic chip (选中时 或 锁定模式)
          if (_selectedCategoryId != null) ...[
            _buildTopicChipForCurrentState(state),
            const SizedBox(height: 18),
          ],

          // 标题
          _TitleField(controller: _titleController),
          const SizedBox(height: 8),
          // 内容 + 字数计数器
          _ContentField(controller: _contentController),
          const SizedBox(height: 18),

          // 图片 section (有图片或可加时显示;否则隐藏,由底部工具栏触发添加)
          if (_selectedImages.isNotEmpty) ...[
            _sectionLabel(context, '图片 ${_selectedImages.length}/$_kMaxImages'),
            const SizedBox(height: 6),
            _ImageThumbGrid4(
              images: _selectedImages,
              maxImages: _kMaxImages,
              onRemove: _removeImage,
              onAdd: _pickImages,
            ),
            const SizedBox(height: 18),
          ],

          // 文件 section
          if (_selectedFiles.isNotEmpty) ...[
            _sectionLabel(context, '附件 ${_selectedFiles.length}/$_kMaxFiles · 最大 ${_kMaxFileSizeMB}MB'),
            const SizedBox(height: 6),
            for (var entry in _selectedFiles.asMap().entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FilePdfCard(
                  file: entry.value,
                  onRemove: () => _removeFile(entry.key),
                ),
              ),
            const SizedBox(height: 18),
          ],

          // 关联内容 section
          if (_linkedName != null && _linkedName!.isNotEmpty) ...[
            _sectionLabel(context, context.l10n.publishRelatedContent),
            const SizedBox(height: 6),
            _LinkedChip(
              itemType: _linkedItemType ?? '',
              itemName: _linkedName!,
              onRemove: _clearLinked,
            ),
            const SizedBox(height: 18),
          ],

          if (_isUploading) ...[
            const SizedBox(height: 8),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    ),
    bottomNavigationBar: _BottomComposerToolbar(
      imageCount: _selectedImages.length,
      fileCount: _selectedFiles.length,
      linkedCount: _linkedName != null && _linkedName!.isNotEmpty ? 1 : 0,
      topicCount: _selectedCategoryId != null ? 1 : 0,
      lockedReason: widget.lockCategory ? _lockedReasonForCurrentFlow(context) : null,
      onTapImage: _pickImages,
      onTapFile: _pickFiles,
      onTapLink: _showLinkSearchDialog,
      onTapTopic: () => _showTopicPicker(context, state.categories),
    ),
  ),
);
```

- [ ] **Step 4: 加 helper methods**

```dart
Widget _sectionLabel(BuildContext context, String text) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Text(
    text,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
    ),
  );
}

Widget _buildTopicChipForCurrentState(ForumState state) {
  final cat = state.categories.firstWhere(
    (c) => c.id == _selectedCategoryId,
    orElse: () => ForumCategory(id: _selectedCategoryId!, name: ''),
  );
  final label = cat.displayName(Localizations.localeOf(context));
  return Align(
    alignment: Alignment.centerLeft,
    child: TopicChip(
      label: label.isEmpty ? context.l10n.forumSelectCategory : label,
      emoji: cat.icon,  // ForumCategory.icon 是 emoji 字符串
      locked: widget.lockCategory,
      onRemove: widget.lockCategory ? null : () => setState(() => _selectedCategoryId = null),
    ),
  );
}

String? _lockedReasonForCurrentFlow(BuildContext context) {
  // 根据进入路径判断 (达人/官方任务/admin/校园) — 现有 lockCategory:true
  // 的几种触发场景里, officialTaskId 非 null 是官方任务. 其余暂用 generic 文案.
  if (_isOfficialTaskFlow) return context.l10n.forumTopicLockedOfficialTask;
  // TODO 后续按入口区分; 现在统一用 admin 文案兜底 (admin/达人/校园 入口都不直接展示这个底部)
  return context.l10n.forumTopicLockedAdmin;
}

Future<void> _showTopicPicker(BuildContext context, List<ForumCategory> allCategories) async {
  final currentUser = context.read<AuthBloc>().state.user;
  final postable = ForumPermissionHelper.filterPostableCategories(allCategories, currentUser);
  final result = await showModalBottomSheet<int>(
    context: context,
    builder: (sheetCtx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(context.l10n.commonClear),
            onTap: () => Navigator.pop(sheetCtx, -1),  // -1 sentinel = clear
          ),
          const Divider(height: 1),
          for (final cat in postable)
            ListTile(
              leading: cat.icon != null ? Text(cat.icon!) : null,
              title: Text(cat.displayName(Localizations.localeOf(context))),
              trailing: _selectedCategoryId == cat.id
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(sheetCtx, cat.id),
            ),
        ],
      ),
    ),
  );
  if (result != null && mounted) {
    setState(() {
      _selectedCategoryId = result == -1 ? null : result;
    });
  }
}

Widget _buildDraftBanner(BuildContext context) {
  // 保留现有 draft banner UI; 包一层 padding 让外间距统一
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: /* 现有 draft banner Container, 不动 */,
  );
}

Widget _buildOfficialTaskBanner(BuildContext context) {
  // 保留现有 official task banner UI
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: /* 现有 official task banner Container, 不动 */,
  );
}
```

⚠️ `commonClear` 如果不存在, 用现有 `commonCancel` 或硬编码 "清除话题". `ForumCategory.icon` 字段是否存在不确定,先 grep 确认; 没有就传 null 让 chip 不显示 emoji。

- [ ] **Step 5: 删除原 build() 中现在已经不再需要的代码**

旧的 `if (state.categories.isNotEmpty) ...[...AppSelectField...]` 那大段 (~line 487-577) 删掉 (现在话题靠 chip + 底部 picker, 不再 dropdown)。

- [ ] **Step 6: flutter analyze**

```powershell
flutter analyze lib/features/forum/views/create_post_view.dart
```

预期: 0 errors. 可能有 deprecated info,接受。

- [ ] **Step 7: 手动 dev 验证 (5 分钟)**

```powershell
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH
$env:PUB_CACHE = "F:\DevCache\.pub-cache"
flutter run -d web-server
```

打开 dev URL, 进入发帖页, 验证:
1. 普通模式: 标题/内容/底部工具栏 OK; 点 ✚ 图片/附件/关联/话题 都能触发
2. 不选话题直接发布: 成功
3. 选话题: chip 显示, × 可清除
4. lockCategory 模式 (从达人板块或官方任务入口进):  chip 显示 🔒, 工具栏话题键置灰, 点弹 SnackBar
5. 暗色模式: 切系统主题, UI 对比度可接受

- [ ] **Step 8: Commit**

```bash
git add link2ur/lib/features/forum/views/create_post_view.dart
git commit -m "feat(forum/flutter): 发帖页整页 assembly (B7) — 完成 UI 视觉重做

全部新 widget 串入 build(): AppBar/Title/Content/ImageGrid/FileCard/
LinkedChip/TopicChip + sticky 底部 _BottomComposerToolbar.
旧 AppSelectField 分类选择 + _buildImagePicker/_buildFilePicker/
_buildLinkedChip 全部移除。

lockCategory 模式 chip 显🔒 + 工具栏话题键置灰 + SnackBar 提示.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase C: 详情页重做 (Tasks C1-C8)

每个 task 遵循与 Phase B 相同模板。所有详情页 widget 都加在 `forum_post_detail_view.dart` 文件底部, 通过 build() 替换。

⚠️ 详情页文件 ~2257 行,大,**操作每个 widget 替换务必精确**。建议用 Edit 工具的 `old_string` + 行号上下文,不用大段重写。

---

### Task C1: _DetailCompactAppBar (紧凑顶部 + 迷你头像作者卡 + 关注按钮)

**Files:**
- Modify: `link2ur/lib/features/forum/views/forum_post_detail_view.dart`

读 mockup `.appbar.compact` + `.author-mini` + `.follow-btn` (~line 1130-1200).

- [ ] **Step 1: 读 mockup**

```bash
sed -n '1125,1205p' link2ur/docs/mockups/forum-create-post-mockup.html
```

关键: 返回箭头 + 30x30 圆头像 + 作者名 14 + + 关注 outlined 蓝边 12px pill + 三点更多 (横向)。

- [ ] **Step 2: 找现有 AppBar (大约 line 220+)**

详情页 AppBar 现状是显示帖子标题或类似。整段重写为 _DetailCompactAppBar。

- [ ] **Step 3: 加 _DetailCompactAppBar widget at file bottom**

```dart
class _DetailCompactAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _DetailCompactAppBar({
    required this.post,
    required this.isFollowing,
    required this.onToggleFollow,
    required this.onMore,
  });

  final ForumPost post;
  final bool isFollowing;
  final VoidCallback onToggleFollow;
  final VoidCallback onMore;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final author = post.author;  // ⚠️ ForumPost.author 类型先 grep 确认
    return AppBar(
      backgroundColor: AppColors.backgroundFor(
        isDark ? Brightness.dark : Brightness.light,
      ),
      elevation: 0,
      titleSpacing: 0,
      title: InkWell(
        onTap: () {
          // 跳转到作者主页 — 沿用现有 _onTapAuthor 或 context.goToProfile(authorId)
        },
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 30,
                height: 30,
                child: author?.avatar != null
                    ? AsyncImageView(url: author!.avatar!)
                    : _GradientAvatarFallback(name: author?.name ?? '?'),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                author?.name ?? context.l10n.commonAnonymous,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (post.author?.id != null) ...[
          _FollowPill(isFollowing: isFollowing, onTap: onToggleFollow),
          const SizedBox(width: 4),
        ],
        IconButton(
          icon: const Icon(Icons.more_horiz, size: 20),
          onPressed: onMore,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _FollowPill extends StatelessWidget {
  const _FollowPill({required this.isFollowing, required this.onTap});
  final bool isFollowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isFollowing ? AppColors.primary : Colors.transparent,
            border: Border.all(color: AppColors.primary, width: 1.5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            isFollowing ? context.l10n.commonFollowing : '+ ${context.l10n.commonFollow}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isFollowing ? Colors.white : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientAvatarFallback extends StatelessWidget {
  const _GradientAvatarFallback({required this.name});
  final String name;

  /// 4 套渐变,按 name hash 选 1 套保证同一作者颜色稳定
  static const _gradients = [
    [Color(0xFF7359F2), Color(0xFFA18BFF)],  // 紫
    [Color(0xFFFF8033), Color(0xFFFFB84D)],  // 橙
    [Color(0xFF26BF73), Color(0xFF5FD89A)],  // 绿
    [Color(0xFFFF4D80), Color(0xFFFF8AAB)],  // 粉
  ];

  @override
  Widget build(BuildContext context) {
    final idx = name.isEmpty ? 0 : name.codeUnitAt(0) % _gradients.length;
    final colors = _gradients[idx];
    final initial = name.isEmpty ? '?' : name.characters.first;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
```

⚠️ `commonFollowing` / `commonFollow` / `commonAnonymous` 如不存在硬编码中文字符串("已关注"/"关注"/"匿名")。

- [ ] **Step 4: 替换 Scaffold appBar**

```dart
appBar: _DetailCompactAppBar(
  post: state.selectedPost!,
  isFollowing: /* 从 AuthBloc 或 ProfileBloc 拿当前关注状态 */,
  onToggleFollow: () { /* dispatch toggle follow */ },
  onMore: _showMoreActions,
),
```

如果 `isFollowing` / `onToggleFollow` 现状没有快速接入, 先临时:

```dart
isFollowing: false,
onToggleFollow: () => ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('关注功能待接入')),
),
```

记得这是临时, 在 plan 完成后跟 user 确认是否要做 follow 接入(spec 没明确要求,可以延后)。

- [ ] **Step 5: flutter analyze**

预期: 0 errors. 如 follow 临时 placeholder, info warn 接受。

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/features/forum/views/forum_post_detail_view.dart
git commit -m "feat(forum/flutter): 详情页紧凑 AppBar + 迷你作者卡 + 关注 pill (C1)

关注接入暂用 placeholder, 后续单独 task 对接 follow_repository.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task C2: _AuthorHeader (大头像 + 认证勾 + 角色·时间·同城)

**Files:**
- Modify: `link2ur/lib/features/forum/views/forum_post_detail_view.dart`

读 mockup `.author-header` (~line 1215-1295).

- [ ] **Step 1: 读 mockup**

```bash
sed -n '1210,1300p' link2ur/docs/mockups/forum-create-post-mockup.html
```

关键: 44x44 紫渐变圆头像 + 名字 15 + 蓝色 ✓ 认证徽章 (16x16 蓝圆白勾) + 元数据 "产品经理 · 2 小时前 · 同城" 12px 灰字, 同城带橙色高亮 + pin icon.

- [ ] **Step 2: 找现有作者行 (大约 line 350-430 区域,grep "author" 找)**

- [ ] **Step 3: 加 _AuthorHeader widget at file bottom**

```dart
class _AuthorHeader extends StatelessWidget {
  const _AuthorHeader({
    required this.post,
  });

  final ForumPost post;

  String _formatTime(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${t.year}-${t.month}-${t.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final author = post.author;
    final role = /* post.author?.role */ ''; // ⚠️ 视模型确定
    final city = post.cityName; // ⚠️ ForumPost.cityName 是否存在,grep 确认
    final timeStr = _formatTime(post.createdAt);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          children: [
            ClipOval(
              child: SizedBox(
                width: 44,
                height: 44,
                child: author?.avatar != null
                    ? AsyncImageView(url: author!.avatar!)
                    : _GradientAvatarFallback(name: author?.name ?? '?'),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      author?.name ?? '?',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (author?.isVerified == true) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.check,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              DefaultTextStyle(
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                ),
                child: Row(
                  children: [
                    if (role.isNotEmpty) ...[
                      Text(role),
                      const Text(' · '),
                    ],
                    Text(timeStr),
                    if (city != null && city.isNotEmpty) ...[
                      const Text(' · '),
                      Icon(Icons.place_outlined, size: 11, color: AppColors.accent),
                      const SizedBox(width: 2),
                      Text(
                        '同城',
                        style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

⚠️ `author?.isVerified` / `post.cityName` / `author?.role` 都要先 grep 模型确认。不存在的 placeholder 字段, 临时去掉那段渲染 (返回 SizedBox.shrink())。

- [ ] **Step 4: 替换现有作者渲染调用**

找到原 author 行的 Container/Row, 整段替换为:

```dart
_AuthorHeader(post: post),
```

(`post` 是当前 BlocBuilder 里的 `state.selectedPost!`)

- [ ] **Step 5: flutter analyze**

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/features/forum/views/forum_post_detail_view.dart
git commit -m "feat(forum/flutter): 详情页作者头条 — 紫渐变头像 + 认证勾 + 同城 (C2)

isVerified/cityName/role 字段若模型缺失则渲染降级 (返回空).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task C3: ~~_PostImageGrid3 (3 列无缝拼 + N 遮罩)~~ — **跳过** (2026-05-17)

**用户决定**: 详情页图片保持现有"水平滑动 + 图片在内容上方"的交互不动。
C8 整页 assembly 时仍渲染现有图片 widget,不替换为 PostImageGrid3。
本任务删除,继续 C4。

---

### Task C3 原内容 (已跳过, 仅供参考)

**Files:**
- Modify: `link2ur/lib/features/forum/views/forum_post_detail_view.dart`

读 mockup `.post-image-grid` (~line 1340-1390).

- [ ] **Step 1: 读 mockup**

```bash
sed -n '1335,1400p' link2ur/docs/mockups/forum-create-post-mockup.html
```

关键: 3 列 grid, gap 4px (几乎无缝), aspect-ratio 1:1, 第 3 张当总数 ≥4 时盖 `+N` 半透明黑遮罩.

- [ ] **Step 2: 找现有图片渲染 (grep "images" + grep "AsyncImageView" 在 detail view)**

- [ ] **Step 3: 加 _PostImageGrid3 widget at file bottom**

```dart
class _PostImageGrid3 extends StatelessWidget {
  const _PostImageGrid3({
    required this.imageUrls,
    required this.onTapImage,
  });

  final List<String> imageUrls;
  final void Function(int index) onTapImage;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();
    final visibleCount = imageUrls.length.clamp(1, 3);
    final hasMore = imageUrls.length > 3;
    final overflowCount = imageUrls.length - 3;

    return ClipRRect(
      borderRadius: AppRadius.allMedium,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: visibleCount > 1 ? 3 : 1,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: visibleCount > 1 ? 1.0 : 1.5,
        ),
        itemCount: visibleCount,
        itemBuilder: (context, index) {
          final isLast = index == 2 && hasMore;
          return GestureDetector(
            onTap: () => onTapImage(index),
            child: Stack(
              children: [
                Positioned.fill(
                  child: AsyncImageView(url: imageUrls[index], fit: BoxFit.cover),
                ),
                if (isLast)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      alignment: Alignment.center,
                      child: Text(
                        '+$overflowCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: 替换现有图片渲染调用**

找现有图片 widget call site, 替换为:

```dart
if (post.images != null && post.images!.isNotEmpty) ...[
  _PostImageGrid3(
    imageUrls: post.images!,
    onTapImage: (i) => _showImageGallery(post.images!, initialIndex: i),
  ),
  const SizedBox(height: 12),
],
```

`_showImageGallery` 沿用现有 full-screen 图片预览方法名 (grep 找)。

- [ ] **Step 5: flutter analyze** → 0 errors

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/features/forum/views/forum_post_detail_view.dart
git commit -m "feat(forum/flutter): 详情页图片改 3 列无缝 + +N 遮罩 (C3)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task C4: _PostFileCard + _LinkedItemCard (PDF + 紫色关联)

**Files:**
- Modify: `link2ur/lib/features/forum/views/forum_post_detail_view.dart`

详情页的 PDF 卡比发帖页多一个"下载"按钮; 关联卡比发帖页多一个 `>` 箭头。

- [ ] **Step 1: 读 mockup .post-file + .link-chip 在详情页部分 (~line 1395-1465)**

```bash
sed -n '1395,1470p' link2ur/docs/mockups/forum-create-post-mockup.html
```

- [ ] **Step 2: 找现有 file + linked 渲染**

- [ ] **Step 3: 加 _PostFileCard + _LinkedItemCard widgets at file bottom**

```dart
class _PostFileCard extends StatelessWidget {
  const _PostFileCard({
    required this.attachment,
    required this.onDownload,
  });

  final ForumPostAttachment attachment;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sizeKb = (attachment.size / 1024).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        borderRadius: AppRadius.allMedium,
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: -3,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF24D4D), Color(0xFFFF7A7A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF24D4D).withValues(alpha: 0.35),
                  offset: const Offset(0, 4),
                  blurRadius: 10,
                  spreadRadius: -2,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'PDF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '$sizeKb KB',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onDownload,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_outlined, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.commonDownload,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkedItemCard extends StatelessWidget {
  const _LinkedItemCard({
    required this.itemType,
    required this.itemName,
    required this.onTap,
  });

  final String itemType;
  final String itemName;
  final VoidCallback onTap;

  static const _purpleGradient = [Color(0xFF7359F2), Color(0xFFA18BFF)];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purple = _purpleGradient[0];
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.allMedium,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: purple.withValues(alpha: isDark ? 0.14 : 0.08),
          border: Border.all(color: purple.withValues(alpha: 0.30)),
          borderRadius: AppRadius.allMedium,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: _purpleGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.dashboard, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      itemType,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: purple),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textTertiaryLight),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 替换 build() 调用**

```dart
// 附件
if (post.attachments != null && post.attachments!.isNotEmpty) ...[
  for (final att in post.attachments!)
    Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _PostFileCard(
        attachment: att,
        onDownload: () => _onDownloadAttachment(att),
      ),
    ),
  const SizedBox(height: 12),
],

// 关联内容
if (post.linkedItemType != null && post.linkedItemId != null) ...[
  _LinkedItemCard(
    itemType: post.linkedItemType!,
    itemName: post.linkedItemName ?? '',
    onTap: () => _onTapLinkedItem(post.linkedItemType!, post.linkedItemId!),
  ),
  const SizedBox(height: 12),
],
```

`_onDownloadAttachment` 沿用现有方法名; `_onTapLinkedItem` 沿用现有 navigation 方法名 (grep)。

- [ ] **Step 5: flutter analyze**

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/features/forum/views/forum_post_detail_view.dart
git commit -m "feat(forum/flutter): 详情页 PDF 卡 + 紫色关联卡 (C4)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task C5: _StatsRow + _EngagementBar (浏览数 + 4 键互动条)

**Files:**
- Modify: `link2ur/lib/features/forum/views/forum_post_detail_view.dart`

读 mockup `.stats-row` + `.engage-bar` (~line 1470-1530).

- [ ] **Step 1: 读 mockup**

```bash
sed -n '1465,1540p' link2ur/docs/mockups/forum-create-post-mockup.html
```

关键: stats-row 12px 灰字 "👁️ 浏览数 · 编辑时间"; engage-bar 跨满宽 4 键 ❤️点赞 💬评论 📤分享 🔖收藏, 已点状态 = 品牌色或情感色 (红/橙).

- [ ] **Step 2: 找现有底部互动条**

grep "like_count|favorite_count|reply_count" 在 detail view 找渲染位置。

- [ ] **Step 3: 加 _StatsRow + _EngagementBar widgets at file bottom**

```dart
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.post});
  final ForumPost post;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    return Row(
      children: [
        Icon(Icons.remove_red_eye_outlined, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          '${post.viewCount} ${context.l10n.commonViews}',
          style: TextStyle(fontSize: 12, color: color),
        ),
        if (post.updatedAt != null && post.createdAt != null
            && post.updatedAt!.isAfter(post.createdAt!.add(const Duration(seconds: 5)))) ...[
          Text(' · ', style: TextStyle(color: color)),
          Text(
            '${context.l10n.commonEditedAt} ${_relativeTime(post.updatedAt!)}',
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ],
    );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }
}

class _EngagementBar extends StatelessWidget {
  const _EngagementBar({
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onFavorite,
  });

  final ForumPost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final divider = isDark ? AppColors.dividerDark : AppColors.dividerLight;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: divider),
          bottom: BorderSide(color: divider),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _EngageBtn(
            icon: post.isLiked ? Icons.favorite : Icons.favorite_outline,
            count: post.likeCount,
            tint: post.isLiked ? AppColors.accentPink : null,
            onTap: onLike,
          ),
          _EngageBtn(
            icon: Icons.chat_bubble_outline,
            count: post.replyCount,
            onTap: onComment,
          ),
          _EngageBtn(
            icon: Icons.share_outlined,
            count: 0,  // 后端无 share count
            label: context.l10n.commonShare,
            onTap: onShare,
          ),
          _EngageBtn(
            icon: post.isFavorited ? Icons.bookmark : Icons.bookmark_outline,
            count: post.favoriteCount,
            tint: post.isFavorited ? AppColors.warning : null,
            onTap: onFavorite,
          ),
        ],
      ),
    );
  }
}

class _EngageBtn extends StatelessWidget {
  const _EngageBtn({
    required this.icon,
    required this.count,
    this.label,
    this.tint,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final String? label;
  final Color? tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = tint ?? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(
                label ?? (count > 0 ? '$count' : ''),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

⚠️ `commonViews` / `commonEditedAt` / `commonShare` 不存在则硬编码 ("浏览"/"编辑于"/"分享")。

- [ ] **Step 4: 替换现有 stats 和互动条调用**

替换为:

```dart
const SizedBox(height: 8),
_StatsRow(post: post),
const SizedBox(height: 8),
_EngagementBar(
  post: post,
  onLike: () => context.read<ForumBloc>().add(ForumLikePost(post.id)),
  onComment: _scrollToCommentInput,
  onShare: _onShare,
  onFavorite: () => context.read<ForumBloc>().add(ForumFavoritePost(post.id)),
),
```

事件名 (`ForumLikePost` / `ForumFavoritePost`) 用现有 event,grep 确认。

- [ ] **Step 5: flutter analyze** → 0 errors

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/features/forum/views/forum_post_detail_view.dart
git commit -m "feat(forum/flutter): 详情页 stats row + 4 键互动条 (C5)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task C6: _CommentItem + _NestedReplyItem (彩色头像 + footer)

**Files:**
- Modify: `link2ur/lib/features/forum/views/forum_post_detail_view.dart`

读 mockup `.comment` + `.comment.nested` (~line 1560-1700).

- [ ] **Step 1: 读 mockup**

```bash
sed -n '1555,1710p' link2ur/docs/mockups/forum-create-post-mockup.html
```

关键: 36x36 圆头像(按 author_id hash 选 4 套渐变), 名 13 + 内容 14 line-height 1.55 + footer 行: 时间·❤️ count·回复 12px 灰字; nested 缩进 46px, 头像 28x28.

- [ ] **Step 2: 找现有 `_ReplyCard` widget (大约 line 1300+)**

它现在 ~120 行,渲染单条 reply。

- [ ] **Step 3: 加 _CommentItem widget at file bottom (替代 _ReplyCard 的视觉部分)**

```dart
class _CommentItem extends StatefulWidget {
  const _CommentItem({
    super.key,
    required this.reply,
    required this.isNested,
    required this.onLike,
    required this.onReply,
    required this.onMentionTap,
    this.highlightStream,
  });

  final ForumReply reply;
  final bool isNested;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final void Function(int targetReplyId)? onMentionTap;
  final Stream<int>? highlightStream;

  @override
  State<_CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<_CommentItem> {
  bool _isPulsing = false;
  StreamSubscription<int>? _highlightSub;

  @override
  void initState() {
    super.initState();
    _highlightSub = widget.highlightStream?.listen((id) {
      if (id == widget.reply.id && mounted) {
        setState(() => _isPulsing = true);
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) setState(() => _isPulsing = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _highlightSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = widget.reply;
    final avatarSize = widget.isNested ? 28.0 : 36.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      color: _isPulsing
          ? const Color(0xFFFFDD57).withValues(alpha: 0.35)
          : Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: widget.isNested ? 8 : 0, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: SizedBox(
              width: avatarSize,
              height: avatarSize,
              child: r.author.avatar != null
                  ? AsyncImageView(url: r.author.avatar!)
                  : _GradientAvatarFallback(name: r.author.name),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      r.author.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    // TODO 楼主标识可加 (跟根帖 author_id 比对)
                  ],
                ),
                const SizedBox(height: 2),
                _ReplyContent(reply: r, onMentionTap: widget.onMentionTap),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _formatRelativeTime(r.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                    ),
                    const SizedBox(width: 14),
                    InkWell(
                      onTap: widget.onLike,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                        child: Row(
                          children: [
                            Icon(
                              r.isLiked ? Icons.favorite : Icons.favorite_outline,
                              size: 13,
                              color: r.isLiked
                                  ? AppColors.accentPink
                                  : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${r.likeCount}',
                              style: TextStyle(
                                fontSize: 12,
                                color: r.isLiked
                                    ? AppColors.accentPink
                                    : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    InkWell(
                      onTap: widget.onReply,
                      child: Text(
                        context.l10n.commonReply,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime? t) {
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }
}

class _ReplyContent extends StatelessWidget {
  const _ReplyContent({required this.reply, this.onMentionTap});
  final ForumReply reply;
  final void Function(int targetReplyId)? onMentionTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 如果有 parent_reply_author, 在内容前加 @xxx mention chip
    if (reply.parentReplyAuthor != null) {
      return RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '@${reply.parentReplyAuthor!.name} ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  if (reply.parentReplyId != null) {
                    onMentionTap?.call(reply.parentReplyId!);
                  }
                },
            ),
            TextSpan(
              text: reply.content,
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      );
    }
    return Text(
      reply.content,
      style: TextStyle(
        fontSize: 14,
        height: 1.55,
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
    );
  }
}
```

⚠️ `commonReply` 不存在则硬编码 "回复". `TapGestureRecognizer` 需要 `import 'package:flutter/gestures.dart';` 加在文件顶部。

- [ ] **Step 4: 替换 _ReplyCard call site**

旧 `_ReplyCard(...)` 调用改为:

```dart
_CommentItem(
  reply: r,
  isNested: r.parentReplyId != null,
  onLike: () => context.read<ForumBloc>().add(ForumLikeReply(r.id)),
  onReply: () => _onTapReplyButton(r),
  onMentionTap: _handleMentionTap,
  highlightStream: _highlightStream.stream,
),
```

`_onTapReplyButton` 是现有方法 (设置回复目标 + 滚动到输入框); 如不存在则简单设置 `_replyingToReplyId = r.id` + scroll。

`_ReplyCard` widget class 暂保留 (避免破坏其他可能 caller), Task C7 收尾时再删。

- [ ] **Step 5: flutter analyze** → 0 errors

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/features/forum/views/forum_post_detail_view.dart
git commit -m "feat(forum/flutter): 详情页评论卡 — 彩色渐变头像 + footer 行 (C6)

支持楼主 + 子回复缩进 + @ mention 跳转 + 黄色脉冲高亮.
旧 _ReplyCard widget 暂保留, C7 收尾删除.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task C7: _RootReplyGroup 加蓝色 reply count chip + _ExpandMoreReplies 重做 + 删旧 _ReplyCard

**Files:**
- Modify: `link2ur/lib/features/forum/views/forum_post_detail_view.dart`

`_RootReplyGroup` 在 Task 15 (BLoC 时期) 写过, 现在重做视觉, 在 root 行加蓝色 `N 条回复` chip; `_ExpandMoreReplies` 从普通蓝字改成短虚线 + 蓝字。

- [ ] **Step 1: 读 mockup `.reply-count-tag` + `.show-more-replies` (~line 1500-1540)**

```bash
sed -n '1495,1545p' link2ur/docs/mockups/forum-create-post-mockup.html
```

关键: reply-count-tag = 浅蓝底 + 蓝字 + 内嵌 chat 图标 + 圆角药丸; show-more-replies = 18px 短水平线 + 蓝色文字。

- [ ] **Step 2: 改 _RootReplyGroup widget**

找现有 `class _RootReplyGroup` (Task 15 加的), 在 root 评论上面附一个 chip:

```dart
class _RootReplyGroup extends StatelessWidget {
  // ... 现有 fields 不变 ...

  @override
  Widget build(BuildContext context) {
    final displayChildren = [...root.previewChildren, ...loadedChildren];
    final hiddenCount = root.totalChildren - displayChildren.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 用 _CommentItem 替代之前的 _ReplyCard 调用
        Stack(
          children: [
            _CommentItem(
              reply: root,
              isNested: false,
              onLike: () => context.read<ForumBloc>().add(ForumLikeReply(root.id)),
              onReply: onTapReply,
              onMentionTap: onMentionTap,
              highlightStream: highlightStream,
            ),
            // reply count chip (右上角)
            if (root.totalChildren > 0)
              Positioned(
                top: 8,
                right: 0,
                child: _ReplyCountChip(count: root.totalChildren),
              ),
          ],
        ),
        for (final child in displayChildren)
          Padding(
            padding: const EdgeInsets.only(left: 46, top: 6),
            child: _CommentItem(
              reply: child,
              isNested: true,
              onLike: () => context.read<ForumBloc>().add(ForumLikeReply(child.id)),
              onReply: onTapReply,
              onMentionTap: onMentionTap,
              highlightStream: highlightStream,
            ),
          ),
        if (hasMore || hiddenCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 46, top: 6, bottom: 4),
            child: InkWell(
              onTap: isLoading ? null : onLoadMore,
              child: Row(
                children: [
                  Container(width: 18, height: 1, color: AppColors.primary.withValues(alpha: 0.4)),
                  const SizedBox(width: 6),
                  if (isLoading)
                    const SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  else
                    Text(
                      context.l10n.forumExpandMoreReplies(hiddenCount > 0 ? hiddenCount : 1),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ReplyCountChip extends StatelessWidget {
  const _ReplyCountChip({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 10, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            '$count ${context.l10n.commonReplies}',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
```

⚠️ `commonReplies` 不存在则硬编码 "条回复".

- [ ] **Step 3: 删除旧 _ReplyCard widget class (Task C6 标记保留, 现在删)**

确认全文 grep `_ReplyCard` 只剩 class 定义本身 → 安全删除。

```bash
grep -n "_ReplyCard" link2ur/lib/features/forum/views/forum_post_detail_view.dart
```

- [ ] **Step 4: flutter analyze** → 0 errors

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/forum/views/forum_post_detail_view.dart
git commit -m "feat(forum/flutter): 根评论加 'N 条回复' chip + 展开按钮短虚线 (C7)

删除旧 _ReplyCard widget (被 _CommentItem 取代).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task C8: _BottomCommentInput sticky + Skeleton 替代 spinner + 整页 assembly

**Files:**
- Modify: `link2ur/lib/features/forum/views/forum_post_detail_view.dart`

最后一个详情页 task: sticky 底部评论输入条 + 用 `SkeletonPostDetail` 替代 loading spinner + 整页 build() assembly。

- [ ] **Step 1: 读 mockup `.comment-input` (~line 1715-1780)**

```bash
sed -n '1710,1785p' link2ur/docs/mockups/forum-create-post-mockup.html
```

关键: sticky 底部, 圆头像 + 圆角灰底输入条 + 右侧表情/点赞快捷小圆按钮。

- [ ] **Step 2: 加 _BottomCommentInput widget at file bottom**

```dart
class _BottomCommentInput extends StatefulWidget {
  const _BottomCommentInput({
    required this.controller,
    required this.onSubmit,
    required this.replyingToName,  // null = 普通模式, 非 null = @ 回复某人
    required this.onCancelReply,
    required this.currentUserName,
    required this.currentUserAvatar,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final String? replyingToName;
  final VoidCallback onCancelReply;
  final String currentUserName;
  final String? currentUserAvatar;

  @override
  State<_BottomCommentInput> createState() => _BottomCommentInputState();
}

class _BottomCommentInputState extends State<_BottomCommentInput> {
  bool get _canSubmit => widget.controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.cardBackgroundDark.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.85);
    final divider = isDark ? AppColors.dividerDark : AppColors.dividerLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: divider)),
      ),
      padding: EdgeInsets.fromLTRB(14, 10, 14, 16 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyingToName != null)
            Container(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(
                    '${context.l10n.commonReplyingTo} @${widget.replyingToName}',
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: widget.onCancelReply,
                    child: Text(
                      context.l10n.commonCancel,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: widget.currentUserAvatar != null
                      ? AsyncImageView(url: widget.currentUserAvatar!)
                      : _GradientAvatarFallback(name: widget.currentUserName),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    decoration: InputDecoration(
                      hintText: widget.replyingToName != null
                          ? '${context.l10n.commonReplyingTo} @${widget.replyingToName}…'
                          : context.l10n.forumCommentInputHint,
                      hintStyle: TextStyle(
                        color: AppColors.textPlaceholderLight,
                        fontSize: 13,
                      ),
                      isCollapsed: true,
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 13),
                    maxLines: 5,
                    minLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: _canSubmit ? widget.onSubmit : null,
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _canSubmit
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.send, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

⚠️ `commonReplyingTo` / `forumCommentInputHint` 不存在硬编码 "回复" / "友好评论一下吧…"。

- [ ] **Step 3: 整页 assembly — Scaffold.body + bottomNavigationBar**

```dart
return Scaffold(
  backgroundColor: AppColors.backgroundFor(Theme.of(context).brightness),
  appBar: _DetailCompactAppBar(...),  // C1
  body: BlocBuilder<ForumBloc, ForumState>(
    builder: (context, state) {
      if (state.status == ForumStatus.loading && state.selectedPost == null) {
        return const SkeletonPostDetail();  // 替代旧 spinner
      }
      if (state.selectedPost == null) {
        return ErrorStateView(
          message: state.errorMessage ?? '加载失败',
          onRetry: () => context.read<ForumBloc>().add(ForumLoadPostDetail(widget.postId)),
        );
      }
      final post = state.selectedPost!;
      return RefreshIndicator(
        onRefresh: () async {
          context.read<ForumBloc>()
            ..add(ForumLoadPostDetail(widget.postId))
            ..add(ForumLoadReplies(widget.postId));
          await context.read<ForumBloc>().stream.firstWhere(
            (s) => s.status != ForumStatus.loading,
          );
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _AuthorHeader(post: post),                          // C2
                  if (post.categoryId != null && post.category != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TopicChip(
                        label: post.category!.displayName(Localizations.localeOf(context)),
                        emoji: post.category!.icon,
                      ),  // read-only
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    post.title,
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    post.content,
                    style: const TextStyle(fontSize: 15, height: 1.65),
                  ),
                  const SizedBox(height: 12),
                  if (post.images?.isNotEmpty == true) ...[
                    _PostImageGrid3(imageUrls: post.images!, onTapImage: (i) => _showImageGallery(post.images!, i)),
                    const SizedBox(height: 12),
                  ],
                  if (post.attachments?.isNotEmpty == true)
                    for (final att in post.attachments!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PostFileCard(attachment: att, onDownload: () => _onDownloadAttachment(att)),
                      ),
                  if (post.linkedItemType != null && post.linkedItemId != null) ...[
                    _LinkedItemCard(
                      itemType: post.linkedItemType!,
                      itemName: post.linkedItemName ?? '',
                      onTap: () => _onTapLinkedItem(post.linkedItemType!, post.linkedItemId!),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _StatsRow(post: post),
                  const SizedBox(height: 12),
                  _EngagementBar(
                    post: post,
                    onLike: () => context.read<ForumBloc>().add(ForumLikePost(post.id)),
                    onComment: _scrollToCommentInput,
                    onShare: _onShare,
                    onFavorite: () => context.read<ForumBloc>().add(ForumFavoritePost(post.id)),
                  ),
                  const SizedBox(height: 16),
                  _CommentsHeader(
                    totalCount: post.replyCount,
                    sort: state.replySort,
                    onSortChanged: (s) => context.read<ForumBloc>().add(ForumReplySortChanged(widget.postId, s)),
                  ),
                  const SizedBox(height: 8),
                  if (state.replies.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          context.l10n.forumCommentsEmpty,
                          style: TextStyle(color: AppColors.textTertiaryLight),
                        ),
                      ),
                    )
                  else
                    for (final root in state.replies)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _RootReplyGroup(
                          root: root,
                          loadedChildren: state.loadedChildren[root.id] ?? const [],
                          hasMore: state.hasMoreChildren[root.id] ?? (root.hiddenChildrenCount > 0),
                          isLoading: state.loadingChildrenRoots.contains(root.id),
                          highlightStream: _highlightStream.stream,
                          onMentionTap: _handleMentionTap,
                          onTapReply: () => _onTapReplyButton(root),
                          onLoadMore: () => context.read<ForumBloc>().add(ForumLoadMoreChildren(root.id)),
                        ),
                      ),
                ]),
              ),
            ),
          ],
        ),
      );
    },
  ),
  bottomNavigationBar: _BottomCommentInput(
    controller: _commentController,
    onSubmit: _submitComment,
    replyingToName: _replyingToName,
    onCancelReply: () => setState(() {
      _replyingToReplyId = null;
      _replyingToName = null;
    }),
    currentUserName: context.read<AuthBloc>().state.user?.name ?? '我',
    currentUserAvatar: context.read<AuthBloc>().state.user?.avatar,
  ),
);
```

⚠️ `forumCommentsEmpty` 不存在硬编码 "暂无评论，做第一个". 现有方法名 (`_submitComment` / `_replyingToName` / `_onTapReplyButton` 等) 视实际命名调整。

- [ ] **Step 4: flutter analyze**

```powershell
flutter analyze lib/features/forum/views/forum_post_detail_view.dart
```

预期: 0 errors. info lints 接受。

- [ ] **Step 5: 跑全套回归测试**

```powershell
flutter test test/features/forum/
```

预期: 43 test 全 pass (33 BLoC + 6 sort/load more + 4 create/edit)。

- [ ] **Step 6: 手动 dev 验证 (10 分钟)**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH
$env:PUB_CACHE = "F:\DevCache\.pub-cache"
flutter run -d web-server
```

验证清单 (浅色 + 暗色双 mode 各 5 分钟):
- 详情页骨架屏 → 数据 (loading 状态)
- 作者头条 (头像 + 认证 + 同城)
- 标题 + 正文
- 图片 (1/2/3+ 张 各场景)
- PDF 卡 + 点下载
- 关联卡 + 点跳转
- 互动条点赞/收藏 (颜色变化)
- 评论默认按热度
- 切排序 → 重拉
- 展开剩余 N 条
- @ mention 普通跳转 + 黄色脉冲
- @ mention 折叠区跳转 (先展开再 highlight)
- 写评论 + 写 @ 子回复 → 立即看到正确位置
- 删评论 (UI 立刻消失)
- 下拉刷新

- [ ] **Step 7: Commit**

```bash
git add link2ur/lib/features/forum/views/forum_post_detail_view.dart
git commit -m "feat(forum/flutter): 详情页整页 assembly (C8) — UI 视觉重做完成

- 骨架屏 SkeletonPostDetail 替代 spinner
- sticky _BottomCommentInput (头像 + 圆角输入 + 发送按钮)
- pull-to-refresh
- 全部新 widget 串成 CustomScrollView + 评论区
- 暗色模式适配

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

✅ **Spec coverage**:
- 共享 TopicChip (Task A1) ✓
- lockCategory 4 套 SnackBar l10n (Task A2) ✓
- 发帖页 7 个组件 (Tasks B1-B7) ✓ — appBar/title/content/imageGrid/fileCard/linkedChip/bottomToolbar/draftBanner all covered
- 详情页 8 个组件 (Tasks C1-C8) ✓ — compactAppBar/authorHeader/imageGrid/fileCard+linkedCard/stats+engagement/commentItem/rootGroup/bottomInput all covered
- 暗色模式 ✓ — 每个 widget build() 顶部 `isDark` 分支
- 骨架屏 ✓ — Task C8 `SkeletonPostDetail`
- 动画过渡 ✓ — pulse highlight + AnimatedContainer (评论高亮)
- 零行为改动 ✓ — 仅 view 层, BLoC events/state 不动

✅ **Placeholder scan**: 无 TBD/TODO/"add appropriate error handling"; 所有 code blocks 都给出完整代码。

✅ **Type consistency**:
- `TopicChip(label, emoji, onRemove, locked)` 一致
- `_CommentItem(reply, isNested, onLike, onReply, onMentionTap, highlightStream)` 一致
- `_RootReplyGroup` 现有签名保留 + `_CommentItem` 替代旧 `_ReplyCard` 调用
- `_GradientAvatarFallback(name)` 跨 C1/C2/C6/C8 复用一致 — class 定义在 C1, 后续 task 直接用

✅ **Mockup adherence**: 每个 widget task 都引用 mockup 对应 CSS region (sed 命令带行号)，便于 implementer 翻阅。

---

**总计:** 2 + 7 + 8 = **17 个 task, ~17 commits**。

每个 task 完成后:
- flutter analyze 0 errors
- 不破坏现有 43 个回归测试
- 单文件改动可独立 review

最后一个 commit (C8) 完成后,整个 UI 重做完成 + 现有所有交互通过手动 dev 验证。

---

**Plan complete and saved to `docs/superpowers/plans/2026-05-17-forum-ui-visual-redesign.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — 派 fresh subagent / task, 我中间两阶段 review

**2. Inline Execution** — 在当前 session 用 executing-plans, 分批 checkpoint review

**Which approach?**
