# App 版本检查功能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** App 启动时检查版本，支持强制更新和可选更新，跳转对应商店。

**Architecture:** 后端提供公开 GET 接口，通过环境变量配置版本号和商店链接。Flutter 端在 auth check 完成后、splash 移除前调用接口，根据返回结果弹出强制或可选更新 Dialog。

**Tech Stack:** FastAPI (backend), Flutter BLoC + url_launcher + package_info_plus (frontend)

---

## File Structure

### Backend (2 files)
- **Modify:** `backend/app/config.py` — 添加 5 个环境变量
- **Modify:** `backend/app/routers.py` — 添加公开端点 `GET /api/app/version-check`

### Flutter (7 files)
- **Modify:** `link2ur/lib/core/constants/api_endpoints.dart` — 添加端点常量
- **Create:** `link2ur/lib/data/models/version_check_response.dart` — 响应 model
- **Create:** `link2ur/lib/data/repositories/version_check_repository.dart` — repository
- **Modify:** `link2ur/lib/app.dart` — 版本检查逻辑 + 更新 Dialog
- **Modify:** `link2ur/lib/l10n/app_en.arb` — 英文文案
- **Modify:** `link2ur/lib/l10n/app_zh.arb` — 简体中文文案
- **Modify:** `link2ur/lib/l10n/app_zh_Hant.arb` — 繁体中文文案

---

## Task 1: 后端 — 添加环境变量配置

**Files:**
- Modify: `backend/app/config.py`

- [ ] **Step 1: 在 Config 类中添加版本检查相关环境变量**

在 `config.py` 的 Config 类中，找到合适位置（推荐在文件末尾、其他配置之后）添加：

```python
# ==================== App 版本检查 ====================
APP_LATEST_VERSION = os.getenv("APP_LATEST_VERSION", "1.1.1")
APP_MIN_VERSION = os.getenv("APP_MIN_VERSION", "1.0.0")
IOS_STORE_URL = os.getenv("IOS_STORE_URL", "")
ANDROID_STORE_URL = os.getenv("ANDROID_STORE_URL", "")
APP_RELEASE_NOTES = os.getenv("APP_RELEASE_NOTES", "")
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/config.py
git commit -m "feat: add version check env vars to Config"
```

---

## Task 2: 后端 — 添加版本检查接口

**Files:**
- Modify: `backend/app/routers.py`

- [ ] **Step 1: 在 routers.py 中添加 semver 比较工具函数和版本检查端点**

在 `routers.py` 文件中找到其他公开端点附近（如 `/banners`、`/health` 等），添加：

```python
def _parse_semver(version_str: str) -> tuple:
    """将版本字符串解析为 (major, minor, patch) 元组用于比较"""
    try:
        parts = version_str.strip().split(".")
        return tuple(int(p) for p in parts[:3])
    except (ValueError, AttributeError):
        return (0, 0, 0)


@app.get("/api/app/version-check")
def check_app_version(platform: str, current_version: str):
    """
    公开接口：检查 App 版本。
    - platform: ios / android
    - current_version: 当前 App 版本号，如 1.1.1
    返回最新版本、最低版本、是否强制更新、更新链接。
    """
    latest = Config.APP_LATEST_VERSION
    min_ver = Config.APP_MIN_VERSION
    release_notes = Config.APP_RELEASE_NOTES

    # 根据平台返回对应商店链接
    if platform.lower() == "ios":
        update_url = Config.IOS_STORE_URL
    else:
        update_url = Config.ANDROID_STORE_URL

    # 语义化版本比较
    current_parsed = _parse_semver(current_version)
    min_parsed = _parse_semver(min_ver)
    force_update = current_parsed < min_parsed

    return {
        "latest_version": latest,
        "min_version": min_ver,
        "force_update": force_update,
        "update_url": update_url,
        "release_notes": release_notes,
    }
```

- [ ] **Step 2: 验证接口**

在本地启动后端后，用 curl 或浏览器访问：
```
GET http://localhost:8000/api/app/version-check?platform=ios&current_version=1.1.1
```

预期返回：
```json
{
  "latest_version": "1.1.1",
  "min_version": "1.0.0",
  "force_update": false,
  "update_url": "",
  "release_notes": ""
}
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/routers.py
git commit -m "feat: add GET /api/app/version-check public endpoint"
```

---

## Task 3: Flutter — 添加端点常量和 Model

**Files:**
- Modify: `link2ur/lib/core/constants/api_endpoints.dart`
- Create: `link2ur/lib/data/models/version_check_response.dart`

- [ ] **Step 1: 在 api_endpoints.dart 的「通用/其他」区域添加端点**

在 `healthCheck` 附近添加：

```dart
static const String versionCheck = '/api/app/version-check';
```

- [ ] **Step 2: 创建 VersionCheckResponse model**

创建 `link2ur/lib/data/models/version_check_response.dart`：

```dart
import 'package:equatable/equatable.dart';

class VersionCheckResponse extends Equatable {
  const VersionCheckResponse({
    required this.latestVersion,
    required this.minVersion,
    required this.forceUpdate,
    required this.updateUrl,
    this.releaseNotes = '',
  });

  final String latestVersion;
  final String minVersion;
  final bool forceUpdate;
  final String updateUrl;
  final String releaseNotes;

  factory VersionCheckResponse.fromJson(Map<String, dynamic> json) {
    return VersionCheckResponse(
      latestVersion: json['latest_version'] as String? ?? '0.0.0',
      minVersion: json['min_version'] as String? ?? '0.0.0',
      forceUpdate: json['force_update'] as bool? ?? false,
      updateUrl: json['update_url'] as String? ?? '',
      releaseNotes: json['release_notes'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [latestVersion, minVersion, forceUpdate, updateUrl, releaseNotes];
}
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/core/constants/api_endpoints.dart link2ur/lib/data/models/version_check_response.dart
git commit -m "feat: add VersionCheckResponse model and endpoint constant"
```

---

## Task 4: Flutter — 创建 VersionCheckRepository

**Files:**
- Create: `link2ur/lib/data/repositories/version_check_repository.dart`

- [ ] **Step 1: 创建 repository**

```dart
import 'package:dio/dio.dart';

import '../models/version_check_response.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/logger.dart';

class VersionCheckRepository {
  VersionCheckRepository({required ApiService apiService})
      : _apiService = apiService;

  final ApiService _apiService;

  /// 检查 App 版本，失败时返回 null（不阻塞用户）
  Future<VersionCheckResponse?> checkVersion({
    required String platform,
    required String currentVersion,
  }) async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiEndpoints.versionCheck,
        queryParameters: {
          'platform': platform,
          'current_version': currentVersion,
        },
        options: Options(extra: {'skipAuth': true}),
      );
      if (response.isSuccess && response.data != null) {
        return VersionCheckResponse.fromJson(response.data!);
      }
      return null;
    } catch (e) {
      AppLogger.error('Version check failed', e);
      return null;
    }
  }
}
```

注意：`extra: {'skipAuth': true}` 跳过 auth 拦截器，因为这是公开接口且在登录前就可能调用。

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/data/repositories/version_check_repository.dart
git commit -m "feat: add VersionCheckRepository"
```

---

## Task 5: Flutter — 添加国际化文案

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`

- [ ] **Step 1: 在三个 ARB 文件的末尾（`}` 之前）添加版本检查文案**

**app_en.arb:**
```json
"versionUpdateRequired": "Update Required",
"versionUpdateAvailable": "New Version Available",
"versionUpdateRequiredMessage": "Your current version is no longer supported. Please update to continue using the app.",
"versionUpdateAvailableMessage": "A new version {version} is available.",
"@versionUpdateAvailableMessage": {
  "placeholders": {
    "version": {"type": "String"}
  }
},
"versionUpdateNow": "Update Now",
"versionUpdateLater": "Later"
```

**app_zh.arb:**
```json
"versionUpdateRequired": "需要更新",
"versionUpdateAvailable": "发现新版本",
"versionUpdateRequiredMessage": "当前版本过旧，请更新到最新版本以继续使用。",
"versionUpdateAvailableMessage": "新版本 {version} 已发布。",
"@versionUpdateAvailableMessage": {
  "placeholders": {
    "version": {"type": "String"}
  }
},
"versionUpdateNow": "立即更新",
"versionUpdateLater": "稍后"
```

**app_zh_Hant.arb:**
```json
"versionUpdateRequired": "需要更新",
"versionUpdateAvailable": "發現新版本",
"versionUpdateRequiredMessage": "目前版本過舊，請更新至最新版本以繼續使用。",
"versionUpdateAvailableMessage": "新版本 {version} 已發佈。",
"@versionUpdateAvailableMessage": {
  "placeholders": {
    "version": {"type": "String"}
  }
},
"versionUpdateNow": "立即更新",
"versionUpdateLater": "稍後"
```

- [ ] **Step 2: 生成 l10n 文件**

```bash
cd link2ur && flutter gen-l10n
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/l10n/
git commit -m "feat: add version check i18n strings"
```

---

## Task 6: Flutter — 在 app.dart 中集成版本检查和更新弹窗

**Files:**
- Modify: `link2ur/lib/app.dart`

这是核心改动。需要：
1. 导入依赖
2. 创建 VersionCheckRepository 实例
3. 修改 splash 移除的 BlocListener，在移除 splash 前执行版本检查
4. 添加版本检查方法和两种 Dialog

- [ ] **Step 1: 添加 imports**

在 `app.dart` 顶部添加：

```dart
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;  // 已有，确认存在
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/models/version_check_response.dart';
import 'data/repositories/version_check_repository.dart';
```

- [ ] **Step 2: 在 _Link2UrAppState 中添加 VersionCheckRepository 字段**

在 `_Link2UrAppState` 类的 `late final` 声明区域添加：

```dart
late final VersionCheckRepository _versionCheckRepository;
```

在 `initState()` 中 `_apiService = ApiService();` 之后添加初始化：

```dart
_versionCheckRepository = VersionCheckRepository(apiService: _apiService);
```

- [ ] **Step 3: 修改 splash 移除的 BlocListener**

将 `app.dart` 第 127-138 行的 BlocListener 替换为：

```dart
BlocListener<AuthBloc, AuthState>(
  listenWhen: (prev, curr) {
    final wasChecking = prev.status == AuthStatus.initial ||
        prev.status == AuthStatus.checking;
    final isChecking = curr.status == AuthStatus.initial ||
        curr.status == AuthStatus.checking;
    return wasChecking && !isChecking;
  },
  listener: (context, state) async {
    // Auth check 完成 → 版本检查 → 移除 splash
    await _checkAppVersion(context);
    FlutterNativeSplash.remove();
  },
),
```

- [ ] **Step 4: 添加版本检查和 Dialog 方法**

在 `_Link2UrAppState` 类的 `build` 方法之后（`}` 之前），添加以下私有方法：

```dart
/// 比较语义化版本号，返回 current < other
bool _isVersionLessThan(String current, String other) {
  final currentParts = current.split('.').map(int.tryParse).toList();
  final otherParts = other.split('.').map(int.tryParse).toList();
  for (var i = 0; i < 3; i++) {
    final c = (i < currentParts.length ? currentParts[i] : 0) ?? 0;
    final o = (i < otherParts.length ? otherParts[i] : 0) ?? 0;
    if (c < o) return true;
    if (c > o) return false;
  }
  return false;
}

Future<void> _checkAppVersion(BuildContext context) async {
  // Web 端不检查版本
  if (kIsWeb) return;

  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final platform = Platform.isIOS ? 'ios' : 'android';
    final result = await _versionCheckRepository.checkVersion(
      platform: platform,
      currentVersion: packageInfo.version,
    );
    if (result == null || !context.mounted) return;

    if (result.forceUpdate) {
      _showUpdateDialog(context, result, force: true);
    } else if (_isVersionLessThan(packageInfo.version, result.latestVersion)) {
      _showUpdateDialog(context, result, force: false);
    }
  } catch (e) {
    AppLogger.error('Version check error', e);
  }
}

void _showUpdateDialog(BuildContext context, VersionCheckResponse response, {required bool force}) {
  final l10n = AppLocalizations.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: !force,
    builder: (dialogContext) => PopScope(
      canPop: !force,
      child: AlertDialog(
        title: Text(
          force
              ? (l10n?.versionUpdateRequired ?? '需要更新')
              : (l10n?.versionUpdateAvailable ?? '发现新版本'),
        ),
        content: Text(
          force
              ? (l10n?.versionUpdateRequiredMessage ?? '当前版本过旧，请更新到最新版本以继续使用。')
              : (l10n?.versionUpdateAvailableMessage(response.latestVersion) ?? '新版本 ${response.latestVersion} 已发布。'),
        ),
        actions: [
          if (!force)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n?.versionUpdateLater ?? '稍后'),
            ),
          TextButton(
            onPressed: () async {
              final uri = Uri.tryParse(response.updateUrl);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(l10n?.versionUpdateNow ?? '立即更新'),
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 5: 运行 flutter analyze 确认无错误**

```bash
cd link2ur && flutter analyze
```

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/app.dart
git commit -m "feat: integrate version check on app startup with update dialogs"
```

---

## Task 7: 手动测试验证

- [ ] **Step 1: 后端设置环境变量测试强制更新**

在 `.env` 或环境变量中设置：
```
APP_LATEST_VERSION=9.0.0
APP_MIN_VERSION=9.0.0
IOS_STORE_URL=https://apps.apple.com/app/xxx
ANDROID_STORE_URL=https://play.google.com/store/apps/details?id=xxx
```

启动后端，然后运行 Flutter App，应该弹出不可关闭的强制更新 Dialog。

- [ ] **Step 2: 测试可选更新**

```
APP_LATEST_VERSION=9.0.0
APP_MIN_VERSION=1.0.0
```

App 当前版本 1.1.1 < 9.0.0，应弹出可关闭的可选更新 Dialog。

- [ ] **Step 3: 测试无需更新**

```
APP_LATEST_VERSION=1.1.1
APP_MIN_VERSION=1.0.0
```

不应弹出任何 Dialog。

- [ ] **Step 4: 测试网络错误**

断网或不启动后端，App 应正常启动，不弹窗，控制台有错误日志。

- [ ] **Step 5: 恢复环境变量为实际值并 commit**

```bash
git add -A
git commit -m "feat: complete version check feature"
```
