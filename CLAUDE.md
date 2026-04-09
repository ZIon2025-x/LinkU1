# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

**Link2Ur** — 技能互助平台 (skill exchange / task assistance platform). This is a monorepo containing:

- `link2ur/` — **Flutter mobile app (primary codebase)** — 功能最完整、最新，以 Flutter 为准。**iOS + Android 线上用户都运行 Flutter 构建的版本**。
- `ios/` — iOS native app (**已完全退役**) — 早期 Swift/SwiftUI 原生实现，已被 Flutter 完全取代，仅作为历史代码保留在仓库，**不产生任何真实流量**，不在 App Store 销售中。修改后端 API 时无需考虑 iOS 原生的兼容性。
- `backend/` — Python backend API (deployed on Railway)
- `frontend/` — React admin/web frontend
- `admin/` — Admin panel
- `service/` — Microservice components

## Flutter Environment Setup

Flutter SDK is at `F:\flutter\bin\`. All caches live on F: drive to avoid cross-drive issues.

When running Flutter/Dart commands, set environment first:

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; $env:GRADLE_USER_HOME = "F:\DevCache\.gradle"; flutter <command>
```

## Common Commands

All Flutter commands run from `link2ur/` subdirectory:

```bash
# Run the app
flutter run

# Run on web without auto-launching Chrome (if "Failed to launch browser" occurs)
# Then open the printed URL (e.g. http://localhost:xxxxx) in Chrome/Edge manually.
flutter run -d web-server

# Build
flutter build apk
flutter build ios

# Build iOS/Android with mobile request signing (eliminates backend "缺少签名或时间戳" WARNING)
# flutter build ios --dart-define=MOBILE_APP_SECRET=<same as backend MOBILE_APP_SECRET>
# See link2ur/docs/mobile-app-secret.md for details.

# Analyze code
flutter analyze

# Run tests
flutter test
flutter test test/widget_test.dart    # single test

# Install dependencies
flutter pub get

# Generate localization files
flutter gen-l10n

# Code generation (if using freezed/json_serializable)
dart run build_runner build --delete-conflicting-outputs
```

## Flutter App Architecture (`link2ur/lib/`)

Clean Architecture with **BLoC** state management, organized as feature-first with shared core/data layers:

```
lib/
├── main.dart              # Entry point: init logger, Hive, StorageService, AppConfig
├── app.dart               # Root widget: theme, locale, splash, MaterialApp.router
├── app_providers.dart     # Dependency wiring: MultiRepositoryProvider + MultiBlocProvider
├── core/
│   ├── config/            # AppConfig (environment/URLs), ApiConfig (headers/retry)
│   ├── constants/         # api_endpoints.dart, storage_keys.dart, app_constants.dart
│   ├── design/            # Design system: colors, typography, theme, spacing, radius, shadows
│   ├── router/            # GoRouter setup with 50+ routes, extension methods on BuildContext
│   ├── utils/             # Logger, analytics, crash reporter, validators, date formatter
│   └── widgets/           # Shared UI: buttons, cards, loading, error, skeleton, image views
├── data/
│   ├── models/            # Equatable models with manual fromJson/toJson/copyWith
│   ├── repositories/      # 15 repositories wrapping ApiService calls
│   └── services/          # ApiService (Dio), StorageService (Hive+SharedPrefs+SecureStorage), WebSocket
├── features/              # 22 feature modules, each with bloc/ and views/ subdirectories
│   ├── auth/              # AuthBloc (root-level)
│   ├── settings/          # SettingsBloc (root-level, theme/language)
│   ├── notification/      # NotificationBloc (root-level)
│   ├── tasks/, forum/, chat/, profile/, wallet/, payment/, flea_market/, ...
└── l10n/                  # ARB files: English, Simplified Chinese, Traditional Chinese
```

### Key Architectural Patterns

- **State management**: BLoC with Equatable states/events, status enums (`loading`/`loaded`/`error`), `copyWith()` for immutability
- **Dependency injection**: Manual — repositories instantiated in `app.dart` `initState()`, wired in `app_providers.dart` via `MultiRepositoryProvider`
- **Singletons**: `StorageService.instance`, `WebSocketService.instance`, `AppConfig.instance`, `AppLogger` (static)
- **Networking**: Dio-based `ApiService` with auth token interceptor, 401 auto-refresh, `ApiResponse<T>` wrapper. All endpoints centralized in `api_endpoints.dart`
- **Routing**: GoRouter with `ShellRoute` for bottom tabs (`/`, `/community`, `/messages-tab`, `/profile-tab`). Type-safe extensions: `context.goToTaskDetail(id)`, `context.goToChat(userId)`
- **Storage**: Three-tier — `FlutterSecureStorage` for tokens, `SharedPreferences` for prefs, `Hive` for cache
- **WebSocket**: Singleton service with heartbeat, auto-reconnect (exponential backoff), `StreamController` broadcast
- **Models**: Hand-written with `Equatable`, manual `fromJson()`/`toJson()`. Support multilingual fields (`titleZh`, `titleEn`, `descriptionZh`, `descriptionEn`). `freezed`/`json_serializable` are in dev deps but not currently generating code
- **Localization**: 3 locales (en, zh, zh_Hant). Access via `AppLocalizations.of(context)` or `context.l10n` extension

### Adding a New Feature

1. Create `lib/features/<name>/bloc/` (events, states, bloc) and `lib/features/<name>/views/`
2. Create repository in `lib/data/repositories/<name>_repository.dart`
3. Add API endpoint constants to `lib/core/constants/api_endpoints.dart`
4. Register repository in `MultiRepositoryProvider` in `app_providers.dart`
5. Add routes in `lib/core/router/app_router.dart`

### Bloc Provider Hierarchy

Blocs are provided at three levels:

| Level | Where | Blocs | Lifetime |
|-------|-------|-------|----------|
| **Root** | `app_providers.dart` (`MultiBlocProvider`) | `AuthBloc`, `SettingsBloc`, `NotificationBloc` | App lifetime — survive navigation |
| **Route** | GoRouter route builders (e.g. `forum_routes.dart`) | `ForumBloc` | Lives as long as the route subtree |
| **Page** | Individual view `build()` methods | `TaskDetailBloc`, `WalletBloc`, `ChatBloc`, `PaymentBloc`, `FleaMarketBloc`, `AIChatBloc`, etc. | Created when page mounts, closed on dispose |

When adding a new Bloc, choose the **narrowest scope** that satisfies its data sharing needs. Most feature blocs belong at **page level**; promote to route or root only if multiple sibling/descendant pages need the same instance.

### Error Handling Conventions

1. **Bloc layer**: Store an `errorMessage` string on the state. Use **error code strings** (e.g. `'ai_chat_load_conversations_failed'`), never hardcoded user-facing text. Raw `e.toString()` is acceptable as a fallback for unexpected errors.
2. **UI layer**: Convert error codes to localized text via `context.localizeError(state.errorMessage)` (extension from `core/utils/error_localizer.dart`). This maps known codes to `context.l10n.*` keys and passes unknown strings through as-is.
3. **Display patterns**:
   - Full-page errors → `ErrorStateView` with `onRetry` callback
   - Transient / toast errors → `SnackBar(content: Text(context.localizeError(...)))`
4. **Adding new error codes**: Add the l10n key in all three ARB files, then add a `case` in `ErrorLocalizer.localize()`.

### Environment Configuration

`AppConfig` in `core/config/app_config.dart`:
- **Dev/Staging**: `https://linktest.up.railway.app` / `wss://linktest.up.railway.app`
- **Production**: `https://api.link2ur.com` / `wss://api.link2ur.com`
- Environment auto-detected via `kDebugMode`

**密钥不会从文件导入**：Stripe 公钥、`MOBILE_APP_SECRET` 等均通过 **`--dart-define`** 在运行/构建时传入，不读 `.env`。未传时 Stripe 公钥为空，支付会失败。详见 `link2ur/docs/stripe-keys-setup.md`。

## Full-Stack Consistency Check

当任何改动涉及前后端（`backend/` + `link2ur/`），实施完成后**必须**按照 `~/.claude/skills/full-stack-consistency-check/SKILL.md` 的跨层检查清单逐项验证，确保 DB → Backend Model → Pydantic Schema → API Route → Frontend Endpoint → Repository → Model.fromJson → BLoC → UI 整条链路对齐。

### Android Build Notes

- Kotlin 2.1.0 with API compatibility set to 1.9 (for fluwx 4.x plugin compatibility)
- Jetifier enabled for legacy AndroidX support
- Gradle JVM: `-Xmx8G -XX:MaxMetaspaceSize=4G`
- Java compatibility: Java 17
