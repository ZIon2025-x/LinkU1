# App 版本检查功能设计

## 概述

在 App 启动时检查当前版本是否满足最低要求，支持强制更新和可选更新两种模式。后端通过环境变量配置版本信息，无需建表。

## 后端

### 环境变量

| 变量名 | 示例值 | 说明 |
|--------|--------|------|
| `APP_LATEST_VERSION` | `1.2.0` | 最新版本号 |
| `APP_MIN_VERSION` | `1.0.0` | 最低支持版本（低于此强制更新） |
| `IOS_STORE_URL` | `https://apps.apple.com/app/xxx` | iOS App Store 链接 |
| `ANDROID_STORE_URL` | `https://play.google.com/store/apps/details?id=xxx` | Android 下载链接 |
| `APP_RELEASE_NOTES` | `修复了一些问题` | 更新说明（可选，默认空） |

### 接口

**`GET /api/app/version-check`**

公开接口，无需认证。

**请求参数（query）：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `platform` | string | 是 | `ios` 或 `android` |
| `current_version` | string | 是 | 当前 App 版本号，如 `1.1.1` |

**响应：**

```json
{
  "latest_version": "1.2.0",
  "min_version": "1.0.0",
  "force_update": true,
  "update_url": "https://apps.apple.com/app/xxx",
  "release_notes": "修复了一些问题"
}
```

**逻辑：**
- `force_update`：`current_version < min_version` 时为 `true`
- `update_url`：根据 `platform` 返回 `IOS_STORE_URL` 或 `ANDROID_STORE_URL`
- 版本比较使用语义化版本（semver）：逐段比较 major.minor.patch
- 若环境变量未配置，返回 `latest_version` 为 `0.0.0`，`force_update` 为 `false`（不阻塞用户）

### 路由位置

添加到 `secure_auth_routes.py` 或 `routers.py` 中作为公开端点，不需要 auth 依赖。

## Flutter 端

### API 层

1. **端点常量**：`ApiEndpoints.versionCheck = '/api/app/version-check'`
2. **Model**：`VersionCheckResponse`（`latestVersion`, `minVersion`, `forceUpdate`, `updateUrl`, `releaseNotes`）
3. **Repository**：`VersionCheckRepository.checkVersion(platform, currentVersion)` — 调用 API，返回 `VersionCheckResponse`

### 检查时机

在 `app.dart` 的 `initState` 中，监听 AuthBloc 状态变化。当 auth check 完成后（状态从 `checking` 变为 `authenticated` 或 `unauthenticated`），在移除 splash 之前执行版本检查。

```
main() → initState → AuthCheckRequested → auth 完成 → 版本检查 → 弹窗或移除 splash
```

### 版本检查逻辑

不使用 BLoC（这是一次性启动检查，不需要状态管理）。直接在 `app.dart` 中调用 repository，根据返回结果决定是否弹窗。

```dart
Future<void> _checkAppVersion(BuildContext context) async {
  final packageInfo = await PackageInfo.fromPlatform();
  final platform = Platform.isIOS ? 'ios' : 'android';
  final response = await versionCheckRepository.checkVersion(platform, packageInfo.version);

  if (response.forceUpdate) {
    _showForceUpdateDialog(context, response);
  } else if (response.latestVersion > packageInfo.version) {
    _showOptionalUpdateDialog(context, response);
  }
}
```

### UI

**强制更新 Dialog：**
- `barrierDismissible: false`
- `WillPopScope` 阻止返回键关闭
- 标题：「需要更新」
- 内容：显示 release notes（如有）
- 按钮：仅「立即更新」→ `url_launcher` 打开 `updateUrl`

**可选更新 Dialog：**
- 可关闭
- 标题：「发现新版本」
- 内容：显示新版本号和 release notes（如有）
- 按钮：「稍后」（关闭）+「立即更新」（跳转商店）

### 错误处理

版本检查失败（网络错误等）时**静默跳过**，不阻塞用户使用 App。只在控制台打日志。

### 国际化

在三个 ARB 文件中添加：
- `versionUpdateRequired`：「需要更新」
- `versionUpdateAvailable`：「发现新版本」
- `versionUpdateMessage`：「当前版本过旧，请更新到最新版本以继续使用」
- `versionUpdateOptionalMessage`：「新版本 {version} 已发布」
- `versionUpdateNow`：「立即更新」
- `versionUpdateLater`：「稍后」

## 文件变更清单

### 后端
1. `backend/app/config.py` — 添加 5 个环境变量读取
2. `backend/app/routers.py`（或 `secure_auth_routes.py`）— 添加 `GET /api/app/version-check` 端点

### Flutter
1. `link2ur/lib/core/constants/api_endpoints.dart` — 添加 `versionCheck` 端点
2. `link2ur/lib/data/models/version_check_response.dart` — 新建 model
3. `link2ur/lib/data/repositories/version_check_repository.dart` — 新建 repository
4. `link2ur/lib/app.dart` — 添加版本检查调用逻辑和弹窗 UI
5. `link2ur/lib/l10n/app_en.arb` — 添加英文文案
6. `link2ur/lib/l10n/app_zh.arb` — 添加简体中文文案
7. `link2ur/lib/l10n/app_zh_Hant.arb` — 添加繁体中文文案
