# 异乡游戏 WebView 嵌入设计

**日期**: 2026-05-13
**状态**: 设计稿
**作者**: Brainstorm session

---

## Why · 为什么做

`game/` 目录下的「异乡 RPG」是一个 React/Vite 自研网页游戏，已部署到 Vercel。要把它嵌进 link2ur Flutter app，让用户在 app 内一键进入玩。

现有 `ExternalWebView` 是带 AppBar 的通用方案，**顶部那条栏会挤压游戏可视区**（游戏本身已经做了 100dvh 全屏布局 + 自己的 header），需要一个**无顶栏的全屏沉浸式 webview** 容器。

## What · 要做什么

5 件事：

1. **新组件 `GameWebView`** —— 无 AppBar 的全屏 webview 容器，沉浸模式（隐 status bar + nav bar）+ 锁竖屏 + 右上角悬浮 ✕ 关闭按钮
2. **AppConfig 加 `gameUrl`** —— dev/staging/prod 各自的 Vercel URL
3. **DeepLinkHandler 加 `/game` 路由** —— 任何指向 `link2ur://game` 或 `https://link2ur.com/game` 的链接都打开 GameWebView
4. **Banner 系统加 `link_type: 'game'`** —— admin banner 编辑面板新增"游戏类型"单选项；选中时不需要填 link_url，`BannerCarousel` 自动调起 `GameWebView`。运营加 banner 时不必记 deeplink URL，未来加新游戏 banner 也是同一类型。
5. **Game 端轻调** —— `index.html` 加 `apple-mobile-web-app-capable` meta（无害补丁），其他不动

## Out of Scope (V1) · Tracked for later · 6 项后续要做

> V1 都不做，但**全部明确跟踪**，按优先级排：

1. **发帖工具栏「🎮 链接游戏」按钮** —— V1 用户得手输 `https://link2ur.com/game`；V2 在论坛发帖工具栏加一个按钮一键插入。可能进一步把帖子里的游戏链接渲染成富卡片（缩略图 + "玩这个游戏" 按钮）。预计 1-2 天工时。
2. **跨设备存档同步** —— V1 存档走 webview localStorage 仅本机；后续加 backend `game_saves` 表 + game 端 sync API，玩家换设备能续上。预计 3-5 天（backend + game 端）。
3. **游戏内成就回报 → app** —— 游戏通关 / 解锁里程碑 → `window.postMessage` 给 Flutter → 自动 prompt "分享到论坛" sheet 或解锁 app 内 badge。需要 V2 同时落地双向桥（见下条）。预计 2-3 天。
4. **Native ↔ Web 通信桥** —— webview JS bridge：app → web (传当前用户基本信息让游戏个性化欢迎)；web → app (上面成就回报)。一旦做了 #3 这个就是前置依赖。预计 1-2 天 infra + 各 use case 自加。
5. **横屏支持** —— 现在强锁竖屏。要做需要游戏端重新设计 landscape 布局（小说式 RPG 横屏意义不大，低优先）。预计 5+ 天。
6. **Service Worker / 离线缓存** —— Vercel 热站第一次访问要下 ~1-2 MB；service worker 缓存 assets 后再访问秒开 + 离线可玩。预计 1-2 天。

---

## 详细设计

### 1. `GameWebView` 组件

**文件**：`link2ur/lib/core/widgets/game_web_view.dart`（新建）

**API**：
```dart
class GameWebView extends StatefulWidget {
  const GameWebView({super.key, required this.url});
  final String url;

  /// 推到 root navigator 全屏覆盖；进入即锁竖屏 + 沉浸模式，pop 时恢复
  static Future<void> open(BuildContext context, {required String url});
}
```

**生命周期**：

| 阶段 | 操作 |
|---|---|
| `initState` | `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])` <br> `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)` <br> 创建 `WebViewController`，loadRequest(url) |
| `dispose` | `SystemChrome.setPreferredOrientations([])` 恢复 free <br> `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` 或 `manual` 恢复 |
| WebView 加载中 | 显示纯黑 splash（`Container(color: Colors.black)`），不用 Flutter 的圆形 spinner — 避免与游戏自身的入场动画双层 loading 视觉割裂 |
| WebView 加载失败 | 显示离线 fallback：黑底 + "需要联网" 文字 + "重试" 按钮 + "✕ 关闭"（复用 `external_web_view.dart` 模式的精简版） |

**WebView 配置**：
- `setJavaScriptMode(JavaScriptMode.unrestricted)` — 游戏全是 JS
- `setBackgroundColor(Colors.black)` — 避免白底闪烁
- 不桥接任何 cookie / auth（A 路径，零互通）
- iOS 禁用 pull-to-refresh（webview_flutter 默认即如此）
- iOS allowsInlineMediaPlayback / Android `setMediaPlaybackRequiresUserGesture(false)` — 让背景音乐 unlock 链路（之前 fix 过的）能起作用

**布局**（`build`）：
```
Stack:
  - WebViewWidget (full-bleed)
  - 加载中 splash 覆盖层（黑底，loading 完成后淡出）
  - 右上角悬浮 ✕ 按钮：
    Positioned(
      top: MediaQuery.viewPaddingOf(context).top + 8,  // 安全区下偏 8
      right: 8,
      child: ✕ button,
    )
```

**✕ 按钮**：
- 直径 44pt（最小触控目标）
- 半透明黑底圆形 `bg: rgba(0,0,0,0.55)` + 1px 半透明白边 + 内嵌白色 `Icons.close`，size 22
- `onPressed`: `Navigator.of(context).pop()`
- 跨任何游戏背景都可见（深色游戏对暗按钮、浅色场景对半透明外圈也清晰）

---

### 2. AppConfig 加 `gameUrl`

**文件**：`link2ur/lib/core/config/app_config.dart`（修改）

新增：
```dart
String get gameUrl {
  if (_environment == AppEnvironment.production) {
    return 'https://game.link2ur.com';   // 占位，实际填 Vercel prod 域名
  }
  return 'https://game-staging.vercel.app';   // 占位，实际填 Vercel preview 域名
}
```

**注**：实际 URL 用户填。环境划分跟现有 `baseUrl` 同套切换逻辑（已用 `kDebugMode` 自动切）。

---

### 3. DeepLinkHandler 加 `/game` 路由

**文件**：`link2ur/lib/core/utils/deep_link_handler.dart`（修改）

a) 在 `_DeepLinkRoute` enum 加：
```dart
enum _DeepLinkRoute {
  task, forumPost, fleaMarketItem, userProfile, profileSubRoute,
  leaderboard, leaderboardItem, activity, taskExpert, home,
  game,   // 新增
  unknown,
}
```

b) 在 `_getRouteType(path)` 加路径匹配：
```dart
if (path == '/game' || path.startsWith('/game/')) return _DeepLinkRoute.game;
```

c) 在主 `switch` 加 case：
```dart
case _DeepLinkRoute.game:
  GameWebView.open(context, url: AppConfig.instance.gameUrl);
  break;
```

d) 顶部 import 加：
```dart
import '../widgets/game_web_view.dart';
import '../config/app_config.dart';
```

支持的入口 URL（自动都走这条路由）：
- 自定义 scheme：`link2ur://game`
- Universal Link：`https://link2ur.com/game`
- 在论坛帖子里粘贴上面任一 URL，发帖现有的 URL 识别会让它可点击 → tap → 走这条 → 全屏游戏

---

### 4. Banner 系统加 `link_type: 'game'`

#### 4a. 前端（Flutter）

**文件**：`link2ur/lib/core/widgets/banner_carousel.dart`（修改）

`_handleBannerTap` 当前根据 `link_type` 分支（`url` / `deep_link` / etc.）。新增一个分支：

```dart
case 'game':
  GameWebView.open(context, url: AppConfig.instance.gameUrl);
  return;
```

理由：把"游戏 banner"提升为一等类型，不依赖运营记 deeplink URL；将来要加另一个游戏，可以在 `link_url` 字段填游戏 id（例如 `'yixiang'` / `'another'`）按 id 路由不同 URL（V1 只有一个游戏，`link_url` 留空 / 忽略）。

#### 4b. Backend / Admin

Banner 表已有 `link_type` 字段（自由字符串）。需要在 admin banner 编辑面板的 type 单选 / 下拉里加一项：

| 选项 label | 内部值 |
|---|---|
| 内嵌游戏 (Game) | `game` |

选中"内嵌游戏"时，admin 表单可以把 `link_url` 输入框置灰 / 隐藏（V1 只有一个游戏，URL 走 AppConfig；V2 可改成游戏 id 选择器）。

后端 banner serialization 不变（`link_type` 已经透传任意字符串）。

#### 4c. 运营动作

加一条 banner：
- `image_url`: 你画的游戏推广图（建议 16:9 或 4:3，深色基调与游戏统一）
- `link_type`: `game`
- `link_url`: 留空

下次首页拉 banners 接口时新 banner 自动出现，tap → BannerCarousel.`_handleBannerTap` → `'game'` 分支 → `GameWebView.open(...)`。

---

### 5. Game 端轻调

**文件**：`game/index.html`（修改）

在 `<head>` 加：
```html
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
```

理由：用户如果把 link2ur.com/game 用 iOS Safari 打开 + 加到主屏（PWA 风格），这几个 meta 让独立窗口模式也无浏览器 chrome。webview 内打开本身就全屏，加上无害但保险。

**部署**：游戏 `game/dist/` 已经走 Vercel，无新动作。CI 自动重建。

---

## 实现影响范围

### 新建文件
- `link2ur/lib/core/widgets/game_web_view.dart`
- `link2ur/lib/core/utils/orientation_lock.dart`（可选；如果 `SystemChrome` 调用需要复用，单独抽工具函数；不需要可以直接写在 GameWebView 里）

### 修改文件
- `link2ur/lib/core/config/app_config.dart`（新增 `gameUrl` getter）
- `link2ur/lib/core/utils/deep_link_handler.dart`（加 `_DeepLinkRoute.game` + 路径匹配 + case 分支 + import）
- `link2ur/lib/core/widgets/banner_carousel.dart`（加 `'game'` link_type 分支）
- `game/index.html`（加 3 行 meta）

### Backend / Admin（外部协作，不在此 spec 工时内）
- Admin banner 编辑 UI 加"内嵌游戏 (Game)"类型选项（值 `game`）
- 后端 banner serialization 不变

### 不动
- `ExternalWebView` 不变（其他地方仍用，例如 banner 跳第三方 URL）
- 论坛发帖 / 帖子渲染代码不变
- Game src/ 业务代码不变（只动 index.html meta）

---

## 测试

### 自动化
- 现有测试不受影响（纯添加新 widget，没改业务流程）
- 可加 1 个 widget test 验证 `GameWebView` 入口锁竖屏 + dispose 释放（`SystemChrome` 是平台 channel，需要 mock，不强求）

### 手动（必须）
1. **iOS 实机**：
   - 从 banner 点进游戏 → 全屏无顶栏 → 听到背景音乐（之前 fix 的 unlock 还在）
   - status bar 隐藏（看不到时间/电量）
   - 横屏物理旋转设备 → 不旋转
   - ✕ 按钮 tap → 退回 app，status bar / nav bar / orientation 恢复正常
   - 滑屏左缘返回 → 同样退回 + 恢复
2. **Android 实机**：
   - 同上 + 硬件返回键 → 退回 + 恢复
   - 沉浸模式生效（系统状态栏隐藏，从顶/底滑进可暂时拉出）
3. **论坛**：
   - 发一条帖子内容含 `https://link2ur.com/game`
   - 别的用户看到该帖子 → tap 链接 → 进游戏 webview
4. **离线**：
   - 飞行模式下打开 banner → 看到"需要联网" + 重试按钮
   - 切回有网，点重试 → 加载成功

---

## 风险

1. **Vercel 域名 latency / cold start**：游戏第一次访问要下载 ~1-2 MB JS。**Mitigation**：Vercel 默认 CDN + Cloudflare 之类的 edge cache 一般足够；如果用户反馈慢可以再上 service worker 缓存（V2）。
2. **沉浸模式在某些 Android ROM (MIUI / Vivo OS) 表现不一致**：`immersiveSticky` 偶尔不隐 nav bar。**Mitigation**：先按 immersiveSticky 实现，遇到反馈再 fallback 到 `manual`。
3. **iOS 13- WebView 旧 WebKit autoplay 策略与新版不同**：之前 fix 的 audio unlock 链路依赖 `play().catch()` retry。**Mitigation**：webview_flutter 走的是系统 WebView，iOS 13+ 行为一致；游戏端 unlock 已做 retry 兜底。
4. **`SystemChrome.setPreferredOrientations` 调用必须配对清理**：忘记 dispose 调用恢复会"传染"全 app。**Mitigation**：在 `dispose()` 里强制恢复，并写测试备注。
5. **跳出再回来时 webview 状态丢失**：用户在游戏中按 home 键切到别的 app，再回来时 webview 可能已被系统杀掉重新加载（iOS / 低内存 Android）。游戏存档在 localStorage 不丢，但当前对话/选择中的状态 reset。**Mitigation**：游戏自身的持久化（每次行动 save）已经覆盖大部分；webview 重载会回到上次 save 点。这是已知体验损耗，V1 接受。

---

## 上线 / 迁移

- Solo 项目，按用户偏好直接合 main，不开 feature 分支
- Flutter 一次 commit 即可（4 文件改动有耦合）
- 游戏 `index.html` 改动单独 commit（在 game repo / 子目录）
- Vercel 部署：你自己有 dashboard，CI 自动跟 push 走

## V3+（投机性，不做也不跟踪）

> 真要做需要重新评估必要性：

- Banner 上方显示"已通关"勋章（基于 backend 同步的存档元数据，依赖 #2 跨设备存档）
