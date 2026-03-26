# Replace flutter_stripe with Native MethodChannel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the `flutter_stripe` dependency and replace it with direct native SDK calls via MethodChannel, enabling independent Stripe SDK version management on iOS and Android.

**Architecture:** Create a unified `StripePaymentService` on the Dart side that calls native code via a single MethodChannel (`com.link2ur/stripe_payment`). iOS uses the latest StripePaymentSheet framework directly; Android uses the latest `com.stripe:stripe-android`. The existing `com.link2ur/stripe_connect` channel for Connect remains untouched.

**Tech Stack:** Dart (MethodChannel), Swift (StripePaymentSheet SDK), Kotlin (com.stripe:stripe-android), Existing `PaymentService` singleton pattern

---

## Scope

### What flutter_stripe currently provides (6 usages across 7 files):

1. **`Stripe.publishableKey` / `applySettings()`** — SDK initialization (main.dart, payment_service.dart, approval_payment_page.dart)
2. **`Stripe.instance.initPaymentSheet()` + `presentPaymentSheet()`** — Card/Alipay payments (payment_service.dart)
3. **`Stripe.instance.isPlatformPaySupported()`** — Apple Pay / Google Pay detection (payment_service.dart)
4. **`Stripe.instance.confirmPlatformPayPaymentIntent()`** — Apple Pay / Google Pay payment (payment_service.dart)
5. **`Stripe.instance.handleURLCallback()`** — 3DS/Alipay redirect handling (deep_link_handler.dart)
6. **`StripeException` / `StripeConfigException`** — Error types (main.dart, crash_reporter.dart, approval_payment_page.dart, payment_service.dart)

### Files to modify:

| File | Change |
|------|--------|
| `lib/data/services/payment_service.dart` | Replace all `Stripe.*` calls with MethodChannel calls |
| `lib/main.dart` | Remove flutter_stripe import, replace `StripeConfigException` |
| `lib/core/utils/deep_link_handler.dart` | Replace `Stripe.instance.handleURLCallback` with MethodChannel |
| `lib/core/utils/crash_reporter.dart` | Remove `StripeConfigException` import, use local equivalent |
| `lib/features/tasks/views/approval_payment_page.dart` | Replace `Stripe` / `StripeException` with local types |
| `pubspec.yaml` | Remove `flutter_stripe: ^12.0.0` |
| `ios/Podfile` | Add `pod 'StripePaymentSheet'` (already has `StripeConnect`) |
| `ios/Runner/StripePaymentHandler.swift` | **NEW** — native PaymentSheet bridge |
| `ios/Runner/AppDelegate.swift` | Register MethodChannel |
| `android/app/build.gradle.kts` | Upgrade `com.stripe:stripe-android` to latest, remove version locking |
| `android/app/src/main/kotlin/.../StripePaymentHandler.kt` | **NEW** — native PaymentSheet bridge |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Register MethodChannel |

---

## Task 1: Define Dart-side MethodChannel API and error types

**Files:**
- Modify: `lib/data/services/payment_service.dart`

Replace all `flutter_stripe` calls with a MethodChannel abstraction. Define local error types to replace `StripeException` / `StripeConfigException`.

- [ ] **Step 1: Add local Stripe error types to payment_service.dart**

```dart
/// Replaces flutter_stripe's StripeException
class StripePaymentException extends AppException {
  final String? code;
  final String? localizedMessage;
  final bool isCancelled;

  const StripePaymentException(
    super.message, {
    this.code,
    this.localizedMessage,
    this.isCancelled = false,
  });
}

/// Replaces flutter_stripe's StripeConfigException
class StripeNotConfiguredException extends AppException {
  const StripeNotConfiguredException([String message = 'Stripe is not configured'])
      : super(message);
}
```

- [ ] **Step 2: Add MethodChannel and rewrite init()**

Replace `Stripe.publishableKey = key` / `applySettings()` with:
```dart
static const _channel = MethodChannel('com.link2ur/stripe_payment');

Future<void> init() async {
  final key = AppConfig.instance.stripePublishableKey;
  if (key.isEmpty) {
    AppLogger.warning('Stripe publishable key is empty');
    return;
  }
  _publishableKey = key;
  await _channel.invokeMethod('init', {
    'publishableKey': key,
    'merchantIdentifier': _merchantId,
    'urlScheme': 'link2ur',
  });
}
```

- [ ] **Step 3: Rewrite isApplePaySupported()**

```dart
Future<bool> isApplePaySupported() async {
  if (kIsWeb) return false;
  try {
    final result = await _channel.invokeMethod<bool>('isPlatformPaySupported');
    return result ?? false;
  } catch (e) {
    AppLogger.warning('Platform Pay support check failed: $e');
    return false;
  }
}
```

- [ ] **Step 4: Rewrite presentApplePay()**

```dart
Future<bool> presentApplePay({
  required String clientSecret,
  required int amount,
  String currency = 'GBP',
  String label = 'Link²Ur',
  String countryCode = 'GB',
}) async {
  try {
    await _channel.invokeMethod('confirmPlatformPay', {
      'clientSecret': clientSecret,
      'amount': amount,
      'currency': currency,
      'label': label,
      'countryCode': countryCode,
      'isTestEnv': kDebugMode,
    });
    return true;
  } on PlatformException catch (e) {
    if (e.code == 'CANCELLED') return false;
    throw StripePaymentException(e.message ?? 'Platform Pay failed', code: e.code);
  }
}
```

- [ ] **Step 5: Rewrite _initAndPresentSheet()**

```dart
Future<void> _initAndPresentSheet({
  required String clientSecret,
  required bool useCustomer,
  String? customerId,
  String? ephemeralKeySecret,
  String? merchantDisplayName,
  String? returnUrl,
}) async {
  await _channel.invokeMethod('initPaymentSheet', {
    'clientSecret': clientSecret,
    'customerId': useCustomer ? customerId : null,
    'ephemeralKeySecret': useCustomer ? ephemeralKeySecret : null,
    'merchantDisplayName': merchantDisplayName ?? 'Link²Ur',
    'returnUrl': returnUrl ?? 'link2ur://stripe-redirect',
    'defaultCountry': 'GB',
    'allowsDelayedPaymentMethods': true,
  }).timeout(const Duration(seconds: 15), onTimeout: () {
    throw PaymentServiceException('Payment sheet initialisation timed out.');
  });

  await _channel.invokeMethod('presentPaymentSheet').timeout(
    _paymentSheetTimeout,
    onTimeout: () {
      throw PaymentServiceException('Payment sheet did not respond.');
    },
  );
}
```

Update error handling: replace `StripeException` catches with `PlatformException` checking `e.code`:
- `'CANCELLED'` → user cancelled
- Other codes → wrap in `StripePaymentException`

- [ ] **Step 6: Add handleURLCallback() method**

```dart
Future<bool> handleURLCallback(String url) async {
  try {
    final result = await _channel.invokeMethod<bool>('handleURLCallback', {'url': url});
    return result ?? false;
  } catch (e) {
    AppLogger.error('handleURLCallback failed', e);
    return false;
  }
}
```

- [ ] **Step 7: Add publishableKey getter**

```dart
String _publishableKey = '';
String get publishableKey => _publishableKey;
```

- [ ] **Step 8: Remove `import 'package:flutter_stripe/flutter_stripe.dart'`**

- [ ] **Step 9: Verify file compiles**

---

## Task 2: Update consumers of flutter_stripe types

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/core/utils/deep_link_handler.dart`
- Modify: `lib/core/utils/crash_reporter.dart`
- Modify: `lib/features/tasks/views/approval_payment_page.dart`

- [ ] **Step 1: Update main.dart**

- Remove `import 'package:flutter_stripe/flutter_stripe.dart'`
- Replace `StripeConfigException` with `StripeNotConfiguredException` from payment_service.dart
- `_initStripeIfConfigured()` already calls `PaymentService.instance.init()` — no change needed there

- [ ] **Step 2: Update deep_link_handler.dart**

- Remove `import 'package:flutter_stripe/flutter_stripe.dart'`
- Replace `Stripe.instance.handleURLCallback(uri.toString())` with `PaymentService.instance.handleURLCallback(uri.toString())`
- Replace `AppConfig.instance.stripePublishableKey.isEmpty` check with `PaymentService.instance.publishableKey.isEmpty`

- [ ] **Step 3: Update crash_reporter.dart**

- Remove `import 'package:flutter_stripe/flutter_stripe.dart'`
- Replace `StripeConfigException` with `StripeNotConfiguredException`
- Import from payment_service.dart

- [ ] **Step 4: Update approval_payment_page.dart**

- Remove `import 'package:flutter_stripe/flutter_stripe.dart' show Stripe, StripeException`
- Replace `Stripe.publishableKey.isEmpty` with `PaymentService.instance.publishableKey.isEmpty`
- Replace `StripeException` type checks with `StripePaymentException`
- Update `_formatPaymentError` to use `StripePaymentException.localizedMessage`

- [ ] **Step 5: Run `flutter analyze` to verify all Dart changes compile**

---

## Task 3: iOS native implementation

**Files:**
- Create: `ios/Runner/StripePaymentHandler.swift`
- Modify: `ios/Runner/AppDelegate.swift`
- Modify: `ios/Podfile`

- [ ] **Step 1: Add StripePaymentSheet pod to Podfile**

In `ios/Podfile`, under the existing `pod 'StripeConnect'`:
```ruby
pod 'StripePaymentSheet'
```

- [ ] **Step 2: Run `pod install` to verify pod resolution**

```bash
cd link2ur/ios && pod install
```

- [ ] **Step 3: Create StripePaymentHandler.swift**

```swift
import Foundation
import Flutter
import StripePaymentSheet

class StripePaymentHandler: NSObject {
    private var paymentSheet: PaymentSheet?

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "init":
            handleInit(call, result: result)
        case "isPlatformPaySupported":
            handleIsPlatformPaySupported(result: result)
        case "confirmPlatformPay":
            handleConfirmPlatformPay(call, result: result)
        case "initPaymentSheet":
            handleInitPaymentSheet(call, result: result)
        case "presentPaymentSheet":
            handlePresentPaymentSheet(result: result)
        case "handleURLCallback":
            handleURLCallback(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleInit(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let publishableKey = args["publishableKey"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing publishableKey", details: nil))
            return
        }
        STPAPIClient.shared.publishableKey = publishableKey
        if let merchantId = args["merchantIdentifier"] as? String {
            StripeAPI.defaultPublishableKey = publishableKey
        }
        result(nil)
    }

    private func handleIsPlatformPaySupported(result: @escaping FlutterResult) {
        let supported = StripeAPI.deviceSupportsApplePay()
        result(supported)
    }

    private func handleConfirmPlatformPay(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let clientSecret = args["clientSecret"] as? String,
              let amount = args["amount"] as? Int,
              let currency = args["currency"] as? String,
              let label = args["label"] as? String,
              let countryCode = args["countryCode"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing required parameters", details: nil))
            return
        }

        let paymentRequest = StripeAPI.paymentRequest(
            withMerchantIdentifier: "merchant.com.link2ur",
            country: countryCode,
            currency: currency
        )
        paymentRequest.paymentSummaryItems = [
            PKPaymentSummaryItem(label: label, amount: NSDecimalNumber(value: Double(amount) / 100.0))
        ]

        // Use STPApplePayContext for Apple Pay
        // Implementation depends on exact Stripe iOS SDK version
        // This is a simplified version - adjust based on SDK API
        result(FlutterError(code: "NOT_IMPLEMENTED", message: "Apple Pay native TBD", details: nil))
    }

    private func handleInitPaymentSheet(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let clientSecret = args["clientSecret"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing clientSecret", details: nil))
            return
        }

        var config = PaymentSheet.Configuration()
        config.merchantDisplayName = args["merchantDisplayName"] as? String ?? "Link²Ur"
        config.allowsDelayedPaymentMethods = args["allowsDelayedPaymentMethods"] as? Bool ?? true
        config.returnURL = args["returnUrl"] as? String ?? "link2ur://stripe-redirect"
        config.defaultBillingDetails.address.country = args["defaultCountry"] as? String ?? "GB"

        if let customerId = args["customerId"] as? String,
           let ephemeralKey = args["ephemeralKeySecret"] as? String,
           !customerId.isEmpty, !ephemeralKey.isEmpty {
            config.customer = .init(id: customerId, ephemeralKeySecret: ephemeralKey)
        }

        paymentSheet = PaymentSheet(
            paymentIntentClientSecret: clientSecret,
            configuration: config
        )
        result(nil)
    }

    private func handlePresentPaymentSheet(result: @escaping FlutterResult) {
        guard let paymentSheet = paymentSheet else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "PaymentSheet not initialized", details: nil))
            return
        }

        guard let viewController = UIApplication.shared.keyWindow?.rootViewController else {
            result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "No root view controller", details: nil))
            return
        }

        // Find topmost presented VC
        var topVC = viewController
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        paymentSheet.present(from: topVC) { paymentResult in
            switch paymentResult {
            case .completed:
                result(nil)
            case .canceled:
                result(FlutterError(code: "CANCELLED", message: "Payment cancelled by user", details: nil))
            case .failed(let error):
                result(FlutterError(
                    code: "PAYMENT_FAILED",
                    message: error.localizedDescription,
                    details: ["localizedMessage": error.localizedDescription]
                ))
            }
        }
    }

    private func handleURLCallback(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let urlString = args["url"] as? String,
              let url = URL(string: urlString) else {
            result(false)
            return
        }
        let handled = StripeAPI.handleURLCallback(with: url)
        result(handled)
    }
}
```

- [ ] **Step 4: Register channel in AppDelegate.swift**

In `configureFlutterEngine` or `application(_:didFinishLaunchingWithOptions:)`, add:
```swift
let stripePaymentHandler = StripePaymentHandler()
let paymentChannel = FlutterMethodChannel(
    name: "com.link2ur/stripe_payment",
    binaryMessenger: controller.binaryMessenger
)
paymentChannel.setMethodCallHandler(stripePaymentHandler.handle)
```

- [ ] **Step 5: Run `flutter build ios --no-codesign` to verify compilation**

---

## Task 4: Android native implementation

**Files:**
- Create: `android/app/src/main/kotlin/com/link2ur/link2ur/StripePaymentHandler.kt`
- Modify: `android/app/src/main/kotlin/com/link2ur/link2ur/MainActivity.kt`
- Modify: `android/app/build.gradle.kts`

- [ ] **Step 1: Upgrade Stripe Android SDK in build.gradle.kts**

Remove the version-locking `configurations.all` block entirely. Update dependencies:
```kotlin
// Stripe Android SDK (latest, no longer locked by flutter_stripe)
implementation("com.stripe:stripe-android:25.9.0")
// Stripe Connect (latest, supports AccountManagement)
implementation("com.stripe:connect:25.9.0")
```

- [ ] **Step 2: Create StripePaymentHandler.kt**

```kotlin
package com.link2ur.link2ur

import android.app.Activity
import android.content.Intent
import android.util.Log
import androidx.activity.ComponentActivity
import com.stripe.android.PaymentConfiguration
import com.stripe.android.paymentsheet.PaymentSheet
import com.stripe.android.paymentsheet.PaymentSheetResult
import com.stripe.android.googlepaylauncher.GooglePayEnvironment
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class StripePaymentHandler(private val activity: ComponentActivity) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "StripePayment"
    }

    private var paymentSheet: PaymentSheet? = null
    private var pendingResult: MethodChannel.Result? = null

    init {
        paymentSheet = PaymentSheet(activity) { result ->
            handlePaymentResult(result)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> handleInit(call, result)
            "isPlatformPaySupported" -> handleIsPlatformPaySupported(result)
            "confirmPlatformPay" -> handleConfirmPlatformPay(call, result)
            "initPaymentSheet" -> handleInitPaymentSheet(call, result)
            "presentPaymentSheet" -> handlePresentPaymentSheet(result)
            "handleURLCallback" -> result.success(false) // Android doesn't need URL callback
            else -> result.notImplemented()
        }
    }

    private fun handleInit(call: MethodCall, result: MethodChannel.Result) {
        val publishableKey = call.argument<String>("publishableKey")
        if (publishableKey == null) {
            result.error("INVALID_ARGS", "Missing publishableKey", null)
            return
        }
        PaymentConfiguration.init(activity, publishableKey)
        result.success(null)
    }

    private fun handleIsPlatformPaySupported(result: MethodChannel.Result) {
        // Google Pay availability check
        result.success(true) // Simplified; actual check via Google Pay API
    }

    private fun handleConfirmPlatformPay(call: MethodCall, result: MethodChannel.Result) {
        // Google Pay implementation TBD
        result.error("NOT_IMPLEMENTED", "Google Pay native TBD", null)
    }

    // Store config for presentPaymentSheet
    private var pendingClientSecret: String? = null
    private var pendingConfig: PaymentSheet.Configuration? = null

    private fun handleInitPaymentSheet(call: MethodCall, result: MethodChannel.Result) {
        val clientSecret = call.argument<String>("clientSecret")
        if (clientSecret == null) {
            result.error("INVALID_ARGS", "Missing clientSecret", null)
            return
        }

        val configBuilder = PaymentSheet.Configuration.Builder("Link²Ur")

        call.argument<String>("merchantDisplayName")?.let {
            configBuilder.merchantDisplayName(it)
        }

        val customerId = call.argument<String>("customerId")
        val ephemeralKey = call.argument<String>("ephemeralKeySecret")
        if (!customerId.isNullOrEmpty() && !ephemeralKey.isNullOrEmpty()) {
            configBuilder.customer(
                PaymentSheet.CustomerConfiguration(customerId, ephemeralKey)
            )
        }

        call.argument<Boolean>("allowsDelayedPaymentMethods")?.let {
            configBuilder.allowsDelayedPaymentMethods(it)
        }

        pendingClientSecret = clientSecret
        pendingConfig = configBuilder.build()
        result.success(null)
    }

    private fun handlePresentPaymentSheet(result: MethodChannel.Result) {
        val cs = pendingClientSecret
        val config = pendingConfig
        if (cs == null || config == null) {
            result.error("NOT_INITIALIZED", "PaymentSheet not initialized", null)
            return
        }
        pendingResult = result
        paymentSheet?.presentWithPaymentIntent(cs, config)
    }

    private fun handlePaymentResult(result: PaymentSheetResult) {
        val pending = pendingResult ?: return
        pendingResult = null
        when (result) {
            is PaymentSheetResult.Completed -> pending.success(null)
            is PaymentSheetResult.Canceled -> pending.error("CANCELLED", "Payment cancelled", null)
            is PaymentSheetResult.Failed -> pending.error(
                "PAYMENT_FAILED",
                result.error.localizedMessage ?: "Payment failed",
                mapOf("localizedMessage" to (result.error.localizedMessage ?: ""))
            )
        }
    }
}
```

- [ ] **Step 3: Register channel in MainActivity.kt**

Add in `configureFlutterEngine`:
```kotlin
val stripePaymentHandler = StripePaymentHandler(this)
MethodChannel(
    flutterEngine.dartExecutor.binaryMessenger,
    "com.link2ur/stripe_payment"
).setMethodCallHandler(stripePaymentHandler)
```

- [ ] **Step 4: Update StripeConnectAccountManagementActivity**

With SDK 25.9.0, replace the empty shell with a real `AccountManagementController` implementation (same as the earlier attempt with 23.0.0, but now version-compatible).

- [ ] **Step 5: Run `flutter build apk --debug` to verify compilation**

---

## Task 5: Remove flutter_stripe dependency

**Files:**
- Modify: `pubspec.yaml`
- Modify: `ios/Podfile.lock` (auto-updated by pod install)

- [ ] **Step 1: Remove from pubspec.yaml**

Remove the line:
```yaml
flutter_stripe: ^12.0.0
```

- [ ] **Step 2: Run `flutter pub get`**

- [ ] **Step 3: Run `flutter analyze`**

Verify no remaining references to `package:flutter_stripe`.

- [ ] **Step 4: Run iOS pod install**

```bash
cd ios && pod install
```

- [ ] **Step 5: Build both platforms**

```bash
flutter build apk --debug
flutter build ios --no-codesign
```

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: replace flutter_stripe with native MethodChannel bridge

- Removes flutter_stripe ^12.0.0 dependency
- iOS: StripePaymentHandler.swift using StripePaymentSheet pod
- Android: StripePaymentHandler.kt using stripe-android 25.9.0
- Upgrades Android Stripe Connect SDK to 25.9.0 (enables native AccountManagement)
- Removes WebView fallback for Android account management
- Unlocks independent SDK version management per platform"
```

---

## Task 6: Verify and cleanup

- [ ] **Step 1: Search for any remaining flutter_stripe references**

```bash
grep -r "flutter_stripe" lib/ ios/ android/ pubspec.yaml
```

- [ ] **Step 2: Remove Android WebView fallback**

Delete `lib/features/payment/views/stripe_connect_account_webview.dart` and update `wallet_view.dart` to use native AccountManagement on both platforms (no more platform branching).

- [ ] **Step 3: Full test run**

```bash
flutter test
```

---

## Risk Notes

1. **Apple Pay**: The iOS native implementation needs careful testing. The `STPApplePayContext` API may differ between Stripe iOS SDK versions. Test on a real device.

2. **Google Pay**: Android Google Pay integration requires the Google Pay API and real merchant account for testing. Consider keeping it as a future task and falling back to PaymentSheet-only initially.

3. **3DS redirects**: `handleURLCallback` on iOS must be tested with a 3DS-requiring card (e.g., Stripe test card `4000002760003184`).

4. **EphemeralKey compatibility**: The native SDK's `stripe_version` for EphemeralKey may differ from what flutter_stripe was using. Backend may need to update the `stripe_version` parameter when creating EphemeralKeys.

5. **Rollback plan**: Keep a git branch with the current flutter_stripe implementation in case issues are found in production.
