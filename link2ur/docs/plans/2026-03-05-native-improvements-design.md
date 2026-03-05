# Native Improvements Design

## 1. Cupertino Full Adaptation (33 AlertDialog + bottom sheets)

Create `AdaptiveDialogs` utility class in `core/utils/adaptive_dialogs.dart`:
- `showAdaptiveConfirmDialog()` — iOS: `CupertinoAlertDialog`, Android: `AlertDialog`
- `showAdaptiveInputDialog()` — with TextField, platform-adaptive
- `showAdaptiveActionSheet()` — iOS: `CupertinoActionSheet`, Android: `showModalBottomSheet`
- Integrate with existing `SheetAdaptation` desktop constraints
- Replace all 33 AlertDialog instances across 15+ files

## 2. Android Notification Icon

- Create `ic_notification.png` placeholder in `drawable-hdpi` through `drawable-xxxhdpi` (white silhouette on transparent)
- `LinkUFirebaseMessagingService.kt`: change `android.R.drawable.ic_dialog_info` → `R.drawable.ic_notification`
- `push_notification_service.dart`: change `@mipmap/ic_launcher` → `@drawable/ic_notification`
- `AndroidManifest.xml`: add `com.google.firebase.messaging.default_notification_icon` metadata

## 3. Android Badge (flutter_app_badger)

- Add `flutter_app_badger` dependency
- Modify `BadgeService`: use `FlutterAppBadger` on Android, keep MethodChannel on iOS
- Remove silent failure on Android

## 4. Android Notification Channels

Create 3 channels:
- `link2ur_messages` — chat messages (high priority)
- `link2ur_tasks` — task notifications (high priority)
- `link2ur_default` — other notifications (default priority)

Route messages to appropriate channel based on notification type in both `LinkUFirebaseMessagingService.kt` and `push_notification_service.dart`.

## 5. Task Detail Map Preview (Google Static Maps)

- Show static map image when lat/lng coordinates available in `task_detail_view.dart`
- API Key via `--dart-define=GOOGLE_MAPS_KEY=xxx` (same pattern as Stripe keys)
- Tap map opens external map app via `url_launcher`
- Fallback to current text display when no coordinates

## 6. iOS Haptic Feedback Enhancement

- Add `com.link2ur/haptics` MethodChannel in `AppDelegate.swift`
- Expose: `notificationSuccess`, `notificationWarning`, `notificationError`, `impactRigid`, `impactSoft`
- Modify `haptic_feedback.dart`: iOS uses MethodChannel for richer haptics, Android keeps Flutter API

## 7. Cleanup keyboard_insets

- Remove `keyboard_insets: ^0.1.2` from `pubspec.yaml` (zero usages in lib/)
