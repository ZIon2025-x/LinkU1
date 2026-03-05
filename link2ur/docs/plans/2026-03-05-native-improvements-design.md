# Native Platform Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Improve platform-native experience across 7 areas: Cupertino dialogs, Android notification icon, Android badge, notification channels, map preview, iOS haptics, and dead dependency cleanup.

**Architecture:** Create shared utility classes (`AdaptiveDialogs`, enhanced `AppHaptics`, enhanced `BadgeService`) that detect the current platform and delegate to native APIs on iOS or Flutter fallbacks on Android. Notification channels are split by message type. Static map preview uses Google Static Maps API image.

**Tech Stack:** Flutter, Cupertino widgets, MethodChannel (iOS Swift), flutter_app_badger, Google Static Maps API

---

### Task 1: Create AdaptiveDialogs utility class

**Files:**
- Create: `lib/core/utils/adaptive_dialogs.dart`

**Step 1: Create the adaptive dialog utility**

```dart
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'responsive.dart';
import 'sheet_adaptation.dart';

/// Platform-adaptive dialog utilities.
/// iOS: CupertinoAlertDialog / CupertinoActionSheet
/// Android/Web: Material AlertDialog / ModalBottomSheet
class AdaptiveDialogs {
  AdaptiveDialogs._();

  static bool get _isIOS => !kIsWeb && Platform.isIOS;

  /// Show a confirm dialog with title, content, and action buttons.
  /// On iOS: CupertinoAlertDialog. On Android: AlertDialog.
  /// Returns the result of the dialog (typically bool or null).
  static Future<T?> showConfirmDialog<T>({
    required BuildContext context,
    required String title,
    String? content,
    Widget? contentWidget,
    required String confirmText,
    String? cancelText,
    bool isDestructive = false,
    bool barrierDismissible = true,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    final effectiveCancelText = cancelText ??
        (_isIOS ? '取消' : MaterialLocalizations.of(context).cancelButtonLabel);

    if (_isIOS) {
      return showCupertinoDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: contentWidget ?? (content != null ? Text(content) : null),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(context).pop();
                onCancel?.call();
              },
              child: Text(effectiveCancelText),
            ),
            CupertinoDialogAction(
              isDestructiveAction: isDestructive,
              isDefaultAction: !isDestructive,
              onPressed: () {
                Navigator.of(context).pop(true as T);
                onConfirm?.call();
              },
              child: Text(confirmText),
            ),
          ],
        ),
      );
    }

    return SheetAdaptation.showAdaptiveDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: contentWidget ?? (content != null ? Text(content) : null),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onCancel?.call();
            },
            child: Text(effectiveCancelText),
          ),
          isDestructive
              ? TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(true as T);
                    onConfirm?.call();
                  },
                  child: Text(confirmText),
                )
              : FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(true as T);
                    onConfirm?.call();
                  },
                  child: Text(confirmText),
                ),
        ],
      ),
    );
  }

  /// Show an info/alert dialog with a single OK button.
  static Future<void> showInfoDialog({
    required BuildContext context,
    required String title,
    String? content,
    Widget? contentWidget,
    String? okText,
    bool barrierDismissible = true,
  }) {
    final effectiveOkText = okText ?? (_isIOS ? '好' : 'OK');

    if (_isIOS) {
      return showCupertinoDialog(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: contentWidget ?? (content != null ? Text(content) : null),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(),
              child: Text(effectiveOkText),
            ),
          ],
        ),
      );
    }

    return SheetAdaptation.showAdaptiveDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: contentWidget ?? (content != null ? Text(content) : null),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(effectiveOkText),
          ),
        ],
      ),
    );
  }

  /// Show a dialog with a TextField for user input.
  /// Returns the entered text, or null if cancelled.
  static Future<String?> showInputDialog({
    required BuildContext context,
    required String title,
    String? message,
    String? placeholder,
    String? initialValue,
    String? confirmText,
    String? cancelText,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    final controller = TextEditingController(text: initialValue);
    final effectiveConfirmText = confirmText ?? (_isIOS ? '确定' : 'OK');
    final effectiveCancelText = cancelText ?? (_isIOS ? '取消' : MaterialLocalizations.of(context).cancelButtonLabel);

    if (_isIOS) {
      return showCupertinoDialog<String>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message != null) ...[
                Text(message),
                const SizedBox(height: 8),
              ],
              CupertinoTextField(
                controller: controller,
                placeholder: placeholder,
                maxLines: maxLines,
                keyboardType: keyboardType,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(effectiveCancelText),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(effectiveConfirmText),
            ),
          ],
        ),
      );
    }

    return SheetAdaptation.showAdaptiveDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message != null) ...[
              Text(message),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: controller,
              decoration: InputDecoration(hintText: placeholder),
              maxLines: maxLines,
              keyboardType: keyboardType,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(effectiveCancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(effectiveConfirmText),
          ),
        ],
      ),
    );
  }

  /// Show a platform-adaptive action sheet (bottom).
  /// iOS: CupertinoActionSheet. Android: ModalBottomSheet with ListTiles.
  static Future<T?> showActionSheet<T>({
    required BuildContext context,
    String? title,
    String? message,
    required List<AdaptiveAction<T>> actions,
    String? cancelText,
  }) {
    final effectiveCancelText = cancelText ?? '取消';

    if (_isIOS) {
      return showCupertinoModalPopup<T>(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: title != null ? Text(title) : null,
          message: message != null ? Text(message) : null,
          actions: actions.map((action) => CupertinoActionSheetAction(
            isDefaultAction: action.isDefault,
            isDestructiveAction: action.isDestructive,
            onPressed: () => Navigator.of(context).pop(action.value),
            child: Text(action.label),
          )).toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(effectiveCancelText),
          ),
        ),
      );
    }

    return SheetAdaptation.showAdaptiveModalBottomSheet<T>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(message, style: Theme.of(context).textTheme.bodySmall),
              ),
            ...actions.map((action) => ListTile(
              title: Text(
                action.label,
                style: action.isDestructive
                    ? TextStyle(color: Theme.of(context).colorScheme.error)
                    : null,
              ),
              leading: action.icon != null ? Icon(action.icon) : null,
              onTap: () => Navigator.of(context).pop(action.value),
            )),
          ],
        ),
      ),
    );
  }
}

/// Represents an action in an adaptive action sheet.
class AdaptiveAction<T> {
  final String label;
  final T value;
  final IconData? icon;
  final bool isDestructive;
  final bool isDefault;

  const AdaptiveAction({
    required this.label,
    required this.value,
    this.icon,
    this.isDestructive = false,
    this.isDefault = false,
  });
}
```

**Step 2: Verify no syntax errors**

Run: `cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze lib/core/utils/adaptive_dialogs.dart`

**Step 3: Commit**

```bash
git add lib/core/utils/adaptive_dialogs.dart
git commit -m "feat: add AdaptiveDialogs utility for platform-native dialogs"
```

---

### Task 2: Migrate all AlertDialog call sites to AdaptiveDialogs

**Files:**
- Modify: `lib/features/task_expert/views/expert_applications_management_view.dart` (lines 411, 444, 498)
- Modify: `lib/features/forum/views/forum_category_request_view.dart` (line 114)
- Modify: `lib/features/info/views/vip_purchase_view.dart` (line 86)
- Modify: `lib/features/payment/views/wechat_pay_webview.dart` (line 80)
- Modify: `lib/features/flea_market/views/flea_market_detail_view.dart` (lines 421, 712, 743, 2260, 2291)
- Modify: `lib/features/ai_chat/views/unified_chat_view.dart` (lines 395, 554)
- Modify: `lib/features/customer_service/views/customer_service_view.dart` (lines 89, 315)
- Modify: `lib/features/forum/views/forum_post_detail_view.dart` (lines 76, 110, 1216)
- Modify: `lib/features/leaderboard/views/leaderboard_detail_view.dart` (line 107)
- Modify: `lib/features/notification/views/task_chat_list_view.dart` (line 128)
- Modify: `lib/features/tasks/views/task_detail_components.dart` (line 659)
- Modify: `lib/features/payment/views/payment_view.dart` (lines 232, 440)
- Modify: `lib/features/tasks/views/task_detail_view.dart` (lines 123, 377, 1075)
- Modify: `lib/features/tasks/views/task_detail_components.dart` (line 1828)
- Modify: `lib/features/profile/views/profile_menu_widgets.dart` (line 222)
- Modify: `lib/features/settings/views/settings_view.dart` (line 57)
- Modify: `lib/features/coupon_points/views/coupon_points_view.dart` (line 297)
- Modify: `lib/core/utils/permission_manager.dart` (line 114)
- Modify: `lib/core/widgets/notification_permission_view.dart` (line 148)

**Step 1: Migrate each file**

For each file, replace `showDialog` + `AlertDialog` patterns with `AdaptiveDialogs` methods:

- **Simple confirm dialogs** (cancel task, delete, logout, reject, end CS chat): Use `AdaptiveDialogs.showConfirmDialog()`
- **Info/success dialogs** (VIP purchase success, payment success, permission info): Use `AdaptiveDialogs.showInfoDialog()`
- **Input dialogs** (counter-offer price, reject reason, report, invitation code, link search): These have complex custom widget content (TextFields, StatefulBuilder, star pickers) — convert the outer `showDialog`+`AlertDialog` shell to use Cupertino on iOS, keep the inner content. For complex ones with StatefulBuilder (rating dialogs), wrap with platform check.
- **Complex dialogs with StatefulBuilder** (rating dialogs in unified_chat_view and customer_service_view): Keep the builder pattern but swap outer AlertDialog to CupertinoAlertDialog on iOS.

Pattern for simple confirms:
```dart
// Before:
showDialog(context: context, builder: (_) => AlertDialog(
  title: Text('确认删除?'),
  actions: [
    TextButton(onPressed: () => Navigator.pop(context), child: Text('取消')),
    TextButton(onPressed: () { Navigator.pop(context); doDelete(); }, child: Text('删除')),
  ],
));

// After:
AdaptiveDialogs.showConfirmDialog(
  context: context,
  title: '确认删除?',
  confirmText: '删除',
  isDestructive: true,
  onConfirm: doDelete,
);
```

For dialogs with complex content widgets (counter-offer with TextField, rating with stars) that cannot easily map to `showConfirmDialog`, use a direct platform-switch approach:
```dart
// For complex dialogs, add import and use platform check:
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';

// In the dialog builder, swap AlertDialog for CupertinoAlertDialog on iOS:
final isIOS = !kIsWeb && Platform.isIOS;
// ... then use isIOS ? CupertinoAlertDialog(...) : AlertDialog(...)
```

**Step 2: Run analyze to verify**

Run: `cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze`

**Step 3: Commit**

```bash
git add -A
git commit -m "refactor: migrate AlertDialog call sites to platform-adaptive dialogs"
```

---

### Task 3: Android notification icon setup

**Files:**
- Create: `android/app/src/main/res/drawable-hdpi/ic_notification.png` (placeholder)
- Create: `android/app/src/main/res/drawable-mdpi/ic_notification.png` (placeholder)
- Create: `android/app/src/main/res/drawable-xhdpi/ic_notification.png` (placeholder)
- Create: `android/app/src/main/res/drawable-xxhdpi/ic_notification.png` (placeholder)
- Create: `android/app/src/main/res/drawable-xxxhdpi/ic_notification.png` (placeholder)
- Modify: `android/app/src/main/kotlin/com/link2ur/link2ur/LinkUFirebaseMessagingService.kt` (line 100)
- Modify: `lib/data/services/push_notification_service.dart` (line 164, lines 312-318)
- Modify: `android/app/src/main/AndroidManifest.xml` (after line 64)

**Step 1: Create notification icon placeholder**

Since we cannot generate image files programmatically, create a vector drawable XML as the notification icon (white silhouette of the app icon, works at all densities):

Create `android/app/src/main/res/drawable/ic_notification.xml`:
```xml
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24"
    android:tint="#FFFFFF">
    <!-- Simple link/chain icon representing Link2Ur -->
    <path
        android:fillColor="@android:color/white"
        android:pathData="M3.9,12c0,-1.71 1.39,-3.1 3.1,-3.1h4V7H7c-2.76,0 -5,2.24 -5,5s2.24,5 5,5h4v-1.9H7c-1.71,0 -3.1,-1.39 -3.1,-3.1zM8,13h8v-2H8v2zM17,7h-4v1.9h4c1.71,0 3.1,1.39 3.1,3.1s-1.39,3.1 -3.1,3.1h-4V17h4c2.76,0 5,-2.24 5,-5s-2.24,-5 -5,-5z"/>
</vector>
```

A vector drawable works across all densities without needing separate PNGs.

**Step 2: Update LinkUFirebaseMessagingService.kt**

Change line 100:
```kotlin
// Before:
.setSmallIcon(android.R.drawable.ic_dialog_info)
// After:
.setSmallIcon(R.drawable.ic_notification)
```

Also add notification color:
```kotlin
.setColor(0xFF2196F3.toInt())
```

**Step 3: Update push_notification_service.dart**

Change line 164:
```dart
// Before:
const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
// After:
const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
```

**Step 4: Update AndroidManifest.xml**

After the existing `default_notification_channel_id` metadata (line 64), add:
```xml
<meta-data
    android:name="com.google.firebase.messaging.default_notification_icon"
    android:resource="@drawable/ic_notification"/>
<meta-data
    android:name="com.google.firebase.messaging.default_notification_color"
    android:resource="@color/notification_color"/>
```

Create `android/app/src/main/res/values/notification_colors.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="notification_color">#2196F3</color>
</resources>
```

**Step 5: Commit**

```bash
git add android/app/src/main/res/drawable/ic_notification.xml
git add android/app/src/main/res/values/notification_colors.xml
git add android/app/src/main/kotlin/com/link2ur/link2ur/LinkUFirebaseMessagingService.kt
git add lib/data/services/push_notification_service.dart
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat: add branded Android notification icon and color"
```

---

### Task 4: Android notification channels (multi-channel)

**Files:**
- Modify: `android/app/src/main/kotlin/com/link2ur/link2ur/LinkUFirebaseMessagingService.kt`
- Modify: `lib/data/services/push_notification_service.dart`

**Step 1: Update LinkUFirebaseMessagingService.kt**

Replace the single channel with three channels. Update companion object constants and `showNotification`:

```kotlin
companion object {
    var onTokenRefresh: ((String) -> Unit)? = null
    var onRemoteMessage: ((Map<String, Any?>) -> Unit)? = null

    // Notification channels
    private const val CHANNEL_MESSAGES = "link2ur_messages"
    private const val CHANNEL_TASKS = "link2ur_tasks"
    private const val CHANNEL_DEFAULT = "link2ur_default"
}

private fun getChannelForType(type: String?): Pair<String, String> {
    return when (type) {
        "message", "task_chat" -> CHANNEL_MESSAGES to "消息通知"
        "task_update", "task_applied", "task_accepted",
        "task_completed", "task_confirmed", "task_cancelled" -> CHANNEL_TASKS to "任务通知"
        else -> CHANNEL_DEFAULT to "Link²Ur 通知"
    }
}

private fun showNotification(title: String, body: String, data: Map<String, String>) {
    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    val type = data["type"]
    val (channelId, channelName) = getChannelForType(type)

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        // Create all channels
        listOf(
            Triple(CHANNEL_MESSAGES, "消息通知", NotificationManager.IMPORTANCE_HIGH),
            Triple(CHANNEL_TASKS, "任务通知", NotificationManager.IMPORTANCE_HIGH),
            Triple(CHANNEL_DEFAULT, "Link²Ur 通知", NotificationManager.IMPORTANCE_DEFAULT),
        ).forEach { (id, name, importance) ->
            notificationManager.createNotificationChannel(
                NotificationChannel(id, name, importance)
            )
        }
    }

    val intent = Intent(this, MainActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        putExtra("notification_data", HashMap(data))
    }
    val pendingIntent = PendingIntent.getActivity(
        this, 0, intent,
        PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
    )

    val notification = NotificationCompat.Builder(this, channelId)
        .setContentTitle(title)
        .setContentText(body)
        .setSmallIcon(R.drawable.ic_notification)
        .setColor(0xFF2196F3.toInt())
        .setAutoCancel(true)
        .setContentIntent(pendingIntent)
        .setPriority(NotificationCompat.PRIORITY_HIGH)
        .build()

    notificationManager.notify(System.currentTimeMillis().toInt(), notification)
}
```

**Step 2: Update push_notification_service.dart**

Replace single channel creation with three channels, and route notifications to the appropriate channel:

```dart
// In _initLocalNotifications(), replace the single channel creation with:
if (!kIsWeb && ApiConfig.platformId == 'android') {
  const channels = [
    AndroidNotificationChannel(
      'link2ur_messages',
      '消息通知',
      description: '聊天消息通知',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'link2ur_tasks',
      '任务通知',
      description: '任务状态更新通知',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'link2ur_default',
      'Link²Ur 通知',
      description: '其他通知',
      importance: Importance.defaultImportance,
    ),
  ];
  final android = _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  for (final channel in channels) {
    await android?.createNotificationChannel(channel);
  }
}
```

Update `_showLocalNotification` to accept an optional `type` parameter and route to the right channel:

```dart
Future<void> _showLocalNotification({
  required String title,
  required String body,
  String? payload,
  String? type,
}) async {
  final channelId = _channelForType(type);
  final channelName = _channelNameForType(type);

  final androidDetails = AndroidNotificationDetails(
    channelId,
    channelName,
    channelDescription: channelName,
    importance: Importance.high,
    priority: Priority.high,
  );
  // ... rest stays the same
}

static String _channelForType(String? type) {
  switch (type) {
    case 'message':
    case 'task_chat':
      return 'link2ur_messages';
    case 'task_update':
    case 'task_applied':
    case 'task_accepted':
    case 'task_completed':
    case 'task_confirmed':
    case 'task_cancelled':
      return 'link2ur_tasks';
    default:
      return 'link2ur_default';
  }
}

static String _channelNameForType(String? type) {
  switch (type) {
    case 'message':
    case 'task_chat':
      return '消息通知';
    case 'task_update':
    case 'task_applied':
    case 'task_accepted':
    case 'task_completed':
    case 'task_confirmed':
    case 'task_cancelled':
      return '任务通知';
    default:
      return 'Link²Ur 通知';
  }
}
```

Update `_handleRemoteMessage` to pass the type to `_showLocalNotification`:

```dart
// In _handleRemoteMessage, change the _showLocalNotification call:
_showLocalNotification(
  title: title,
  body: body,
  payload: data.toString(),
  type: data['type'] as String?,
);
```

**Step 3: Update AndroidManifest.xml default channel**

Change the default channel to `link2ur_default` (already matches, no change needed).

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/link2ur/link2ur/LinkUFirebaseMessagingService.kt
git add lib/data/services/push_notification_service.dart
git commit -m "feat: split Android notifications into message/task/default channels"
```

---

### Task 5: Android badge support via flutter_app_badger

**Files:**
- Modify: `pubspec.yaml` (add dependency)
- Modify: `lib/core/utils/badge_service.dart`

**Step 1: Add flutter_app_badger dependency**

Run: `cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter pub add flutter_app_badger`

**Step 2: Update BadgeService**

Replace `lib/core/utils/badge_service.dart` — use `FlutterAppBadger` on Android, keep MethodChannel on iOS:

```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

import 'logger.dart';

/// App 角标管理服务
/// iOS: MethodChannel (原生 UNUserNotificationCenter)
/// Android: flutter_app_badger (支持三星、华为、小米等启动器)
class BadgeService {
  BadgeService._();
  static final BadgeService instance = BadgeService._();

  static const _channel = MethodChannel('com.link2ur/badge');

  static bool get _useNativeChannel => !kIsWeb && Platform.isIOS;

  Future<void> updateBadge(int count) async {
    if (kIsWeb) return;

    try {
      if (_useNativeChannel) {
        await _channel.invokeMethod('updateBadge', count);
      } else {
        if (count > 0) {
          FlutterAppBadger.updateBadgeCount(count);
        } else {
          FlutterAppBadger.removeBadge();
        }
      }
    } catch (e) {
      AppLogger.error('BadgeService - updateBadge failed', e);
    }
  }

  Future<void> clearBadge() async {
    if (kIsWeb) return;

    try {
      if (_useNativeChannel) {
        await _channel.invokeMethod('clearBadge');
      } else {
        FlutterAppBadger.removeBadge();
      }
    } catch (e) {
      AppLogger.error('BadgeService - clearBadge failed', e);
    }
  }

  Future<int> getBadgeCount() async {
    if (kIsWeb) return 0;

    try {
      if (_useNativeChannel) {
        final count = await _channel.invokeMethod<int>('getBadgeCount');
        return count ?? 0;
      }
      // flutter_app_badger doesn't support reading badge count on Android
      return 0;
    } catch (e) {
      AppLogger.error('BadgeService - getBadgeCount failed', e);
      return 0;
    }
  }

  Future<void> updateBadgeFromCounts({
    required int unreadNotificationCount,
    required int unreadMessageCount,
  }) async {
    final totalUnread = unreadNotificationCount + unreadMessageCount;
    await updateBadge(totalUnread);
  }
}
```

**Step 3: Run pub get**

Run: `cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter pub get`

**Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/utils/badge_service.dart
git commit -m "feat: add Android badge support via flutter_app_badger"
```

---

### Task 6: Task detail map preview (Google Static Maps)

**Files:**
- Modify: `lib/core/config/app_config.dart` (add Google Maps key getter)
- Modify: `lib/features/tasks/views/task_detail_view.dart` (lines 1418-1440, add map preview)

**Step 1: Add Google Maps key to AppConfig**

In `lib/core/config/app_config.dart`, add after the `mobileAppSecret` getter:

```dart
/// Google Maps API Key for static map images.
/// Pass via --dart-define=GOOGLE_MAPS_KEY=xxx
static String get googleMapsKey =>
    const String.fromEnvironment('GOOGLE_MAPS_KEY');
```

**Step 2: Add static map preview widget in task_detail_view.dart**

Replace the location tag section (lines 1418-1440) with a map preview when coordinates are available. Add a `_buildLocationSection` method and replace the `_buildTag` for location:

After the existing `Wrap` for category+location tags, add a map preview below when lat/lng exist:

```dart
// After the Wrap widget (line 1440), add:
if (!task.isOnline && task.latitude != null && task.longitude != null && AppConfig.googleMapsKey.isNotEmpty)
  Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: _buildStaticMapPreview(context),
  ),
```

Add the map preview builder method:

```dart
Widget _buildStaticMapPreview(BuildContext context) {
  final lat = task.latitude!;
  final lng = task.longitude!;
  final key = AppConfig.googleMapsKey;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final mapStyle = isDark ? '&style=element:geometry|color:0x242f3e' : '';
  final size = '600x200';
  final url = 'https://maps.googleapis.com/maps/api/staticmap'
      '?center=$lat,$lng&zoom=15&size=$size'
      '&markers=color:red|$lat,$lng'
      '$mapStyle'
      '&key=$key';

  return GestureDetector(
    onTap: () => _openExternalMap(lat, lng),
    child: ClipRRect(
      borderRadius: AppRadius.allMd,
      child: Image.network(
        url,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 150,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(child: CircularProgressIndicator.adaptive()),
          );
        },
      ),
    ),
  );
}

void _openExternalMap(double lat, double lng) {
  final uri = Platform.isIOS
      ? Uri.parse('https://maps.apple.com/?ll=$lat,$lng&z=15')
      : Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
  launchUrl(uri, mode: LaunchMode.externalApplication);
}
```

Make sure to add imports at top of file:
```dart
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart'; // if not already imported
```

**Step 3: Commit**

```bash
git add lib/core/config/app_config.dart lib/features/tasks/views/task_detail_view.dart
git commit -m "feat: add static map preview in task detail view"
```

---

### Task 7: iOS haptic feedback enhancement via MethodChannel

**Files:**
- Modify: `ios/Runner/AppDelegate.swift` (add haptics channel)
- Modify: `lib/core/utils/haptic_feedback.dart` (use MethodChannel on iOS)

**Step 1: Add haptics MethodChannel in AppDelegate.swift**

Add a new channel declaration (after line 19):
```swift
/// MethodChannel 用于 iOS 增强触觉反馈
private var hapticsChannel: FlutterMethodChannel?
```

Add channel setup in `didInitializeImplicitFlutterEngine` (after the Stripe Connect channel, before the closing `}`):

```swift
// 触觉反馈 channel
hapticsChannel = FlutterMethodChannel(name: "com.link2ur/haptics", binaryMessenger: messenger)
hapticsChannel?.setMethodCallHandler { call, result in
  switch call.method {
  case "notificationSuccess":
    UINotificationFeedbackGenerator().notificationOccurred(.success)
    result(nil)
  case "notificationWarning":
    UINotificationFeedbackGenerator().notificationOccurred(.warning)
    result(nil)
  case "notificationError":
    UINotificationFeedbackGenerator().notificationOccurred(.error)
    result(nil)
  case "impactRigid":
    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    result(nil)
  case "impactSoft":
    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    result(nil)
  default:
    result(FlutterMethodNotImplemented)
  }
}
```

**Step 2: Update haptic_feedback.dart**

Add iOS MethodChannel support. On iOS, `success()`, `warning()`, `error()` use native notification feedback; on Android, keep Flutter API:

```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// 触觉反馈管理器
/// iOS: 增强触觉反馈通过 MethodChannel (UINotificationFeedbackGenerator, UIImpactFeedbackGenerator rigid/soft)
/// Android/Web: Flutter 内置 HapticFeedback
class AppHaptics {
  AppHaptics._();

  static const _channel = MethodChannel('com.link2ur/haptics');
  static bool get _useNativeHaptics => !kIsWeb && Platform.isIOS;

  // ==================== 基础反馈 ====================

  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void heavy() => HapticFeedback.heavyImpact();
  static void selection() => HapticFeedback.selectionClick();

  // ==================== 通知反馈 (iOS 增强) ====================

  static void success() {
    if (_useNativeHaptics) {
      _channel.invokeMethod('notificationSuccess');
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  static void warning() {
    if (_useNativeHaptics) {
      _channel.invokeMethod('notificationWarning');
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  static void error() {
    if (_useNativeHaptics) {
      _channel.invokeMethod('notificationError');
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  // ==================== iOS 独有反馈 ====================

  /// 刚性碰撞反馈 (iOS only, Android falls back to medium)
  static void rigid() {
    if (_useNativeHaptics) {
      _channel.invokeMethod('impactRigid');
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  /// 柔和碰撞反馈 (iOS only, Android falls back to light)
  static void soft() {
    if (_useNativeHaptics) {
      _channel.invokeMethod('impactSoft');
    } else {
      HapticFeedback.lightImpact();
    }
  }

  // ==================== 场景反馈 ====================
  // (keep all existing scene methods unchanged)

  static void buttonTap() => HapticFeedback.lightImpact();
  static void cardTap() => HapticFeedback.lightImpact();
  static void listSelect() => HapticFeedback.selectionClick();
  static void toggle() => HapticFeedback.mediumImpact();
  static void slider() => HapticFeedback.selectionClick();
  static void longPress() => HapticFeedback.mediumImpact();
  static void drag() => HapticFeedback.selectionClick();
  static void drop() => HapticFeedback.lightImpact();
  static void pullToRefresh() => HapticFeedback.mediumImpact();
  static void deleteAction() => HapticFeedback.heavyImpact();
  static void favorite() => HapticFeedback.lightImpact();
  static void like() => HapticFeedback.lightImpact();
  static void share() => HapticFeedback.lightImpact();
  static void sendMessage() => HapticFeedback.lightImpact();
  static void screenshot() => HapticFeedback.mediumImpact();
  static void paymentSuccess() => success(); // Now uses native iOS feedback!
  static void tabSwitch() => HapticFeedback.selectionClick();
  static void popupAppear() => soft(); // Now uses native iOS soft impact!
  static void notification() => HapticFeedback.mediumImpact();

  // ==================== 触发通用反馈 ====================

  static void trigger(HapticType type) {
    switch (type) {
      case HapticType.light:
        light();
      case HapticType.medium:
        medium();
      case HapticType.heavy:
        heavy();
      case HapticType.selection:
        selection();
      case HapticType.success:
        success();
      case HapticType.warning:
        warning();
      case HapticType.error:
        error();
    }
  }

  static void prepareAll() {
    // Flutter HapticFeedback 不需要显式预热
  }
}

enum HapticType {
  light,
  medium,
  heavy,
  selection,
  success,
  warning,
  error,
}
```

**Step 3: Commit**

```bash
git add ios/Runner/AppDelegate.swift lib/core/utils/haptic_feedback.dart
git commit -m "feat: add iOS native haptic feedback via MethodChannel"
```

---

### Task 8: Remove keyboard_insets dead dependency

**Files:**
- Modify: `pubspec.yaml` (line 104-105, remove keyboard_insets)

**Step 1: Remove from pubspec.yaml**

Remove these two lines:
```yaml
  # 键盘高度（iOS 真机 MediaQuery.viewInsets 可能为 0，用原生 insets 顶起输入区）
  keyboard_insets: ^0.1.2
```

**Step 2: Run pub get to update lock file**

Run: `cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter pub get`

**Step 3: Verify no breakage**

Run: `cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze`

**Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: remove unused keyboard_insets dependency"
```

---

### Task 9: Final verification

**Step 1: Run full analyze**

Run: `cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze`
Expected: No errors

**Step 2: Run tests**

Run: `cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter test`
Expected: All existing tests pass

**Step 3: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: address analyze warnings from native improvements"
```
