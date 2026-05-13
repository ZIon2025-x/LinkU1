# 异乡游戏 WebView 嵌入实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 link2ur Flutter app 通过无顶栏全屏 WebView 加载部署在 Vercel 上的异乡 RPG，banner 和论坛帖子里的链接都能一键进入。

**Architecture:** 新建 `GameWebView` widget — 沉浸模式 + 锁竖屏 + 右上悬浮 ✕ + 黑底 splash + 离线 fallback。`AppConfig` 加 `gameUrl` getter；`DeepLinkHandler` 加 `/game` 路由匹配；`BannerCarousel._handleBannerTap` 加 `'game'` link_type 分支。Vercel 部署 + Universal Link `https://link2ur.com/game` 已通。

**Tech Stack:** Flutter 3.x + `webview_flutter: ^4.10.0` + go_router + 现有 `pushWithSwipeBack` 工具。

**Spec:** `link2ur/docs/superpowers/specs/2026-05-13-game-webview-embed-design.md`

---

## File Structure

| 路径 | 操作 | 责任 |
|---|---|---|
| `link2ur/lib/core/config/app_config.dart` | Modify | 加 `gameUrl` getter（三环境分支） |
| `link2ur/lib/core/widgets/game_web_view.dart` | **Create** | 全屏沉浸 webview 组件 + `open()` 静态便捷方法 |
| `link2ur/lib/core/utils/deep_link_handler.dart` | Modify | 加 `_DeepLinkRoute.game` enum + 路径匹配 + switch case + import |
| `link2ur/lib/core/widgets/banner_carousel.dart` | Modify | `_handleBannerTap` 加 `'game'` link_type 分支 |
| `game/index.html` | Modify | 加 3 行 PWA / web-app-capable meta |

---

## 测试策略

- **没有新增单测**：GameWebView 是平台集成层（SystemChrome / WebViewController），jsdom-style unit test 价值低 + 需要重 mock 平台 channel。
- **现有 `flutter test` 必须全过**（无回归）。
- **必须手动验证**：iOS 真机 + Android 真机 + DevTools mobile 模拟。Task 6 列出完整 checklist。

---

## Task 1: AppConfig 加 gameUrl getter

**Files:**
- Modify: `link2ur/lib/core/config/app_config.dart` (在 `webAppUrl` getter 之后插入)

- [ ] **Step 1: 读现有 webAppUrl getter 作为模板**

```bash
grep -n "webAppUrl" F:/python_work/LinkU/link2ur/lib/core/config/app_config.dart
```

确认行号（应在 80-89 附近）。

- [ ] **Step 2: 添加 gameUrl getter**

在 `webAppUrl` getter（line 80-89）的 `}` 之后、`/// 请求超时时间` 之前插入：

```dart
  /// 游戏 WebView URL（异乡 RPG，部署在 Vercel）
  /// 由 GameWebView 全屏沉浸式加载；详见
  /// docs/superpowers/specs/2026-05-13-game-webview-embed-design.md
  String get gameUrl {
    switch (_environment) {
      case AppEnvironment.development:
        return const String.fromEnvironment(
          'GAME_URL_DEV',
          defaultValue: 'https://yixiang-staging.vercel.app',
        );
      case AppEnvironment.staging:
        return const String.fromEnvironment(
          'GAME_URL_STAGING',
          defaultValue: 'https://yixiang-staging.vercel.app',
        );
      case AppEnvironment.production:
        return const String.fromEnvironment(
          'GAME_URL_PROD',
          defaultValue: 'https://yixiang.vercel.app',
        );
    }
  }
```

**注**：`defaultValue` 是占位符；实际 Vercel 域名由用户填，或在 build 时用 `--dart-define=GAME_URL_PROD=https://...` 覆盖。和 `mobileAppSecret` 处理风格一致。

- [ ] **Step 3: 验证 dart analyze 没新警告**

```bash
cd F:/python_work/LinkU/link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze lib/core/config/app_config.dart 2>&1 | tail -5
```

Expected: `No issues found!` 或现有 warning 数不增加。

- [ ] **Step 4: Run tests**

```bash
cd F:/python_work/LinkU/link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter test 2>&1 | tail -5
```

Expected: 所有 tests pass。

- [ ] **Step 5: Commit**

```bash
git -C F:/python_work/LinkU add link2ur/lib/core/config/app_config.dart
git -C F:/python_work/LinkU commit -m "feat(config): AppConfig 加 gameUrl getter (Vercel 部署)"
```

---

## Task 2: 新建 GameWebView 组件

**Files:**
- Create: `link2ur/lib/core/widgets/game_web_view.dart`

- [ ] **Step 1: 创建文件**

`link2ur/lib/core/widgets/game_web_view.dart` 写入：

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../router/page_transitions.dart';
import '../utils/l10n_extension.dart';

/// 异乡游戏全屏沉浸式 WebView。
///
/// 与通用 [ExternalWebView] 不同：
/// - 无 AppBar，无导航按钮，无 chrome
/// - 进入即 immersiveSticky 模式（隐 status bar + nav bar）
/// - 强锁竖屏（pop 时恢复 free orientation）
/// - 右上角悬浮 ✕ 关闭按钮作为唯一退出 UI（外加 iOS 滑返 / Android 硬返）
/// - 黑底 splash + 离线 fallback
/// - 不桥接 cookie / auth（spec A 路径，零互通）
class GameWebView extends StatefulWidget {
  const GameWebView({super.key, required this.url});

  final String url;

  /// 推到 root navigator 全屏覆盖。
  /// 进入即设沉浸模式 + 锁竖屏；pop 时由 GameWebView dispose 还原。
  static Future<void> open(BuildContext context, {required String url}) {
    return pushWithSwipeBack(
      context,
      GameWebView(url: url),
      useRootNavigator: true,
    );
  }

  @override
  State<GameWebView> createState() => _GameWebViewState();
}

class _GameWebViewState extends State<GameWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _enterImmersiveMode();
    _initWebView();
  }

  void _enterImmersiveMode() {
    // 强锁竖屏（游戏是 portrait-only 设计）
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    // 隐 status bar + nav bar，让游戏沾满整个屏幕
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitImmersiveMode() {
    // 恢复 free orientation
    SystemChrome.setPreferredOrientations([]);
    // 恢复正常 system UI（status bar 可见 + nav bar 可见）
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            // 只对主资源失败显示离线 UI；子资源失败（图片/音频）静默处理
            if (mounted && error.isForMainFrame == true) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    _exitImmersiveMode();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // WebView 全屏
          if (!_hasError)
            Positioned.fill(child: WebViewWidget(controller: _controller)),

          // 加载中：纯黑 splash（让位给游戏自己的入场动画，不放 spinner）
          if (_isLoading && !_hasError)
            const Positioned.fill(
              child: ColoredBox(color: Colors.black),
            ),

          // 离线 fallback
          if (_hasError)
            Positioned.fill(
              child: _OfflineFallback(onRetry: _retry),
            ),

          // 右上角悬浮 ✕ 按钮（始终在最上，离线/加载/正常都可见）
          Positioned(
            top: topInset + 8,
            right: 8,
            child: _CloseButton(
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.close,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _OfflineFallback extends StatelessWidget {
  const _OfflineFallback({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off,
              color: Colors.white54,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.webviewLoading.contains('载入')
                  ? '需要联网才能玩'
                  : 'Network required',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: Text(
                context.l10n.webviewLoading.contains('载入') ? '重试' : 'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**注意：**
- 离线 fallback 文案目前是 inline 的 `context.l10n.webviewLoading.contains('载入')` ad-hoc 中英切换，避免 V1 就动 .arb 文件。l10n 正规化留 V2 polish（用现有 l10n 键名 / 加新键）。
- `pushWithSwipeBack` 已有，自动支持 iOS 滑返 + Android 硬键返回，pop 时自动 dispose → 触发 `_exitImmersiveMode`。
- `WebViewWidget` 走平台默认配置（iOS 用 WKWebView，Android 用 WebView）。媒体自动播放 by default：Android 需要 user gesture（与 web 标准一致；游戏内 audio unlock 已处理），iOS 默认允许 inline media。

- [ ] **Step 2: 验证 dart analyze**

```bash
cd F:/python_work/LinkU/link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze lib/core/widgets/game_web_view.dart 2>&1 | tail -10
```

Expected: `No issues found!`

- [ ] **Step 3: Run flutter test (无新单测，确认不破坏现有)**

```bash
cd F:/python_work/LinkU/link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter test 2>&1 | tail -5
```

Expected: 所有 tests pass。

- [ ] **Step 4: Commit**

```bash
git -C F:/python_work/LinkU add link2ur/lib/core/widgets/game_web_view.dart
git -C F:/python_work/LinkU commit -m "feat(ui): 新建 GameWebView 全屏沉浸 webview 组件"
```

---

## Task 3: DeepLinkHandler 加 /game 路由

**Files:**
- Modify: `link2ur/lib/core/utils/deep_link_handler.dart`

- [ ] **Step 1: 加 import**

文件顶部（在现有 import 后）增加：

```dart
import '../widgets/game_web_view.dart';
import '../config/app_config.dart';
```

注：`app_config.dart` 可能已在文件其他地方被 import，先 grep 确认避免重复：

```bash
grep -n "app_config" F:/python_work/LinkU/link2ur/lib/core/utils/deep_link_handler.dart
```

如已 import 则只加 `game_web_view.dart` 那行。

- [ ] **Step 2: 加 enum case**

找到 `_DeepLinkRoute` enum 定义（在文件下部，包含 `task / forumPost / fleaMarketItem / userProfile / ... / unknown`）。在 `unknown` 之前加 `game`：

```dart
enum _DeepLinkRoute {
  task,
  forumPost,
  fleaMarketItem,
  userProfile,
  profileSubRoute,
  leaderboard,
  leaderboardItem,
  activity,
  taskExpert,
  home,
  game,   // 新增
  unknown,
}
```

（具体 enum 字段名 / 顺序按现有为准；只在末尾 `unknown` 之前插 `game`。）

- [ ] **Step 3: 加路径匹配**

在 `_getRouteType(String path)`（约 line 178）中，在 `return _DeepLinkRoute.unknown;` 之前加：

```dart
} else if (path == '/game' || path.startsWith('/game/')) {
  return _DeepLinkRoute.game;
}
```

应放在 `path.startsWith('/task-expert/')` 那段之后、`return _DeepLinkRoute.unknown;` 之前。

- [ ] **Step 4: 加 switch case**

在主 `switch (_getRouteType(path))`（约 line 104-155）的 `case _DeepLinkRoute.home:` 之后、`case _DeepLinkRoute.unknown:` 之前加：

```dart
case _DeepLinkRoute.game:
  GameWebView.open(context, url: AppConfig.instance.gameUrl);
  break;
```

- [ ] **Step 5: dart analyze**

```bash
cd F:/python_work/LinkU/link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze lib/core/utils/deep_link_handler.dart 2>&1 | tail -5
```

Expected: `No issues found!`

- [ ] **Step 6: Run tests**

```bash
cd F:/python_work/LinkU/link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter test 2>&1 | tail -5
```

Expected: 所有 tests pass。

- [ ] **Step 7: Commit**

```bash
git -C F:/python_work/LinkU add link2ur/lib/core/utils/deep_link_handler.dart
git -C F:/python_work/LinkU commit -m "feat(deeplink): /game 路由打开 GameWebView"
```

---

## Task 4: BannerCarousel 加 'game' link_type 分支

**Files:**
- Modify: `link2ur/lib/core/widgets/banner_carousel.dart`

- [ ] **Step 1: 加 import**

文件顶部加：

```dart
import '../config/app_config.dart';
import 'game_web_view.dart';
```

（若 `app_config.dart` 已 import 则只加 `game_web_view.dart`。先 grep 检查。）

- [ ] **Step 2: 改 _handleBannerTap**

找到 `_handleBannerTap` 方法（约 line 87-103），把现有逻辑：

```dart
void _handleBannerTap(Map<String, dynamic> banner) {
  if (widget.onBannerTap != null) {
    widget.onBannerTap!(banner);
    return;
  }

  final linkType = banner['link_type'] as String?;
  final linkUrl = banner['link_url'] as String?;

  if (linkUrl == null || linkUrl.isEmpty) return;

  if (linkType == 'external') {
    ExternalWebView.openInApp(context, url: linkUrl);
  } else {
    context.safePush(linkUrl);
  }
}
```

改为：

```dart
void _handleBannerTap(Map<String, dynamic> banner) {
  if (widget.onBannerTap != null) {
    widget.onBannerTap!(banner);
    return;
  }

  final linkType = banner['link_type'] as String?;
  final linkUrl = banner['link_url'] as String?;

  // 游戏类型 banner：忽略 link_url（V1 只一个游戏，URL 来自 AppConfig）
  if (linkType == 'game') {
    GameWebView.open(context, url: AppConfig.instance.gameUrl);
    return;
  }

  if (linkUrl == null || linkUrl.isEmpty) return;

  if (linkType == 'external') {
    ExternalWebView.openInApp(context, url: linkUrl);
  } else {
    context.safePush(linkUrl);
  }
}
```

**关键改动**：`'game'` 分支在 `linkUrl null check` 之前 —— 游戏 banner 后台可以填空 link_url（V1 设计），不应被 null check short-circuit。

- [ ] **Step 3: dart analyze + tests**

```bash
cd F:/python_work/LinkU/link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze lib/core/widgets/banner_carousel.dart 2>&1 | tail -5
flutter test 2>&1 | tail -5
```

Expected: analyze no issues, tests pass.

- [ ] **Step 4: Commit**

```bash
git -C F:/python_work/LinkU add link2ur/lib/core/widgets/banner_carousel.dart
git -C F:/python_work/LinkU commit -m "feat(banner): 加 'game' link_type 分支调起 GameWebView"
```

---

## Task 5: game/index.html PWA meta

**Files:**
- Modify: `game/index.html`

- [ ] **Step 1: 读现状**

```bash
cat F:/python_work/LinkU/game/index.html
```

应已含 `<meta name="viewport" content="...viewport-fit=cover" />`（T1 of mobile optimization 中加过）。

- [ ] **Step 2: 在 viewport meta 之后追加 3 行 meta**

用 Edit 工具找到 viewport meta 那一行，在其下加：

```html
    <meta name="apple-mobile-web-app-capable" content="yes" />
    <meta name="mobile-web-app-capable" content="yes" />
    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
```

注：4 空格缩进与现有 viewport 一致（看一下现有 viewport 行的实际缩进，对齐）。

- [ ] **Step 3: 本地 build 验证**

```bash
cd F:/python_work/LinkU/game
npm run build 2>&1 | tail -5
```

Expected: build success。`dist/index.html` 应含新加的 3 个 meta。

- [ ] **Step 4: Commit**

```bash
git -C F:/python_work/LinkU add game/index.html
git -C F:/python_work/LinkU commit -m "feat(game): 加 PWA / web-app-capable meta (iOS Safari 全屏支持)"
```

下次 Vercel 部署会自动 pull 这个 commit。如需手动触发部署，看你 Vercel dashboard。

---

## Task 6: 端到端手动验证

**Files:** 无（纯 manual QA）

无 commit。验证完成后把此 task checkbox 勾掉。如有问题列出。

- [ ] **Step 1: 本地 dev 启动 Flutter app**

```bash
cd F:/python_work/LinkU/link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; $env:GRADLE_USER_HOME = "F:\DevCache\.gradle"; flutter run --dart-define=GAME_URL_DEV=<你的 Vercel 预览域名>
```

把 `<你的 Vercel 预览域名>` 替换成实际，例如 `https://yixiang-git-main-username.vercel.app`。

- [ ] **Step 2: 用 DeepLink 直接打开（最快路径）**

在 dev 模式下，跑：

```bash
# Android（adb）
adb shell am start -W -a android.intent.action.VIEW -d "link2ur://game" com.link2ur.app

# iOS Simulator
xcrun simctl openurl booted "link2ur://game"
```

预期：app 直接跳出全屏沉浸式 GameWebView，看到游戏 BEGIN 屏。

- [ ] **Step 3: iOS 真机验证清单**

打开 GameWebView 后逐项验证：

| 项 | 预期 |
|---|---|
| 进入即全屏 | ✅ 看不到 status bar (时间/电量) |
| 看不到 AppBar / 顶部栏 | ✅ 游戏 BEGIN 屏顶部直接是游戏内容 |
| 右上角 ✕ 按钮 | ✅ 半透明圆形，44pt，离 safe-area top 8px |
| 物理横屏旋转设备 | ✅ 游戏不旋转，保持竖屏 |
| 听到背景音乐 | ✅ 点 BEGIN 进入 playing → 听到 ambient（之前 fix 的 audio unlock 还在） |
| 点 ✕ 退出 | ✅ 退回 app，status bar / 方向恢复正常 |
| 滑屏左缘返回 | ✅ 同上 |
| home 键切走再回来 | ✅ webview 状态 best-effort 保留；最差 reload 一次（游戏 localStorage 存档不丢） |

- [ ] **Step 4: Android 真机验证**

| 项 | 预期 |
|---|---|
| 同 iOS 1-7 | ✅ |
| 硬件返回键 | ✅ 退回 app |
| 沉浸模式 | ✅ status bar + nav bar 都隐；从顶/底滑进可暂时拉出 |
| 横屏旋转 | ✅ 不旋转 |

注：MIUI / VivoOS / OPPO ColorOS 某些版本对 `immersiveSticky` 表现不一致，nav bar 可能仍可见。这是已知 ROM 差异，先 ship，反馈再 fallback `SystemUiMode.manual` + 自定义 `SystemUiOverlay.empty`。

- [ ] **Step 5: Banner 入口验证**

需要先在 admin 工具加一条 banner 记录（**这步是运营 / 后端管理工作，不在本计划工时**）：
- `image_url`: 你画的游戏推广图
- `link_type`: `game`
- `link_url`: 留空（可选）

预期：首页打开后 banner 轮播显示 → tap → 跳进 GameWebView。

如果 admin 工具暂时没有"game" type 选项，可以临时直接走 DB INSERT 或临时改 link_type 为 `'external'` + URL 写 `'link2ur://game'` 走 deeplink 兜底路径。

- [ ] **Step 6: 论坛帖子链接验证**

1. 发一条帖子，body 含 `https://link2ur.com/game`
2. 让别的账号查看该帖子，验证链接可点击
3. tap 链接 → 走 deep link handler → 全屏游戏

如果论坛帖子的链接识别不自动激活（例如纯文本不可点），那是论坛渲染层的现状，**V2 加工具栏按钮时一并解决**（spec 已记录）。

- [ ] **Step 7: 离线 fallback 验证**

1. iOS / Android 开飞行模式
2. 触发任意入口（deeplink / banner）→ 看到黑底 + 📡 + "需要联网才能玩" + "重试"按钮
3. 关飞行模式，点重试 → 加载成功

- [ ] **Step 8: 关闭 + 恢复 system UI 验证**

走完游戏几屏，点 ✕ 退出。回到 app 后：
- status bar 恢复可见
- 屏幕方向可自由旋转（除非 app 自身有方向锁）
- 再次开 deeplink → 重新进入沉浸模式

**任何步骤失败就列出来，针对性修。**

---

## 验证矩阵

| 测试项 | 方式 | 通过条件 |
|---|---|---|
| `flutter analyze` | 自动 | `No issues found!` 4 个修改文件 |
| `flutter test` | 自动 | 全 PASS（无新单测，确认不回归） |
| `flutter build apk` (smoke) | 半自动 | build 成功，APK 产出 |
| iOS 模拟器 deeplink 进入 | manual | 全屏沉浸式打开 |
| 真机 deeplink (iOS + Android) | manual | 同上 + 手势 / 硬键退出 |
| Banner 路径 | manual | 经过 admin 加 banner |
| 论坛链接路径 | manual | 帖子链接可点 |
| 离线 fallback | manual | 飞行模式触发 |
| 关闭后 system UI 恢复 | manual | 退出后状态栏正常 |

---

## Out-of-scope（明确不做）

- 单测：GameWebView 平台集成层，mock 成本 > 价值，V1 跳过
- Backend / admin banner 工具 UI 加 "game" 类型选项：另外 issue，由 backend repo 负责
- 跨设备存档同步、双向 JS bridge、横屏、Service Worker：spec 全部记入 V2 跟踪
