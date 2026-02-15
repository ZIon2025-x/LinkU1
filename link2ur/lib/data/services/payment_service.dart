import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/app_exception.dart';
import '../models/payment.dart';

String get _platformTag =>
    kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.iOS ? 'iOS' : 'Android');

/// Stripe 支付服务
/// 封装 Stripe SDK 的支付流程：信用卡、Apple Pay、支付宝
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  /// Apple Pay Merchant ID
  static const String _merchantId = 'merchant.com.link2ur';

  /// 初始化 Stripe
  Future<void> init() async {
    final key = AppConfig.instance.stripePublishableKey;
    if (key.isEmpty) {
      AppLogger.warning('Stripe publishable key is empty — Stripe will NOT be initialized. '
          'Payments will fail. Please provide --dart-define=STRIPE_PUBLISHABLE_KEY_TEST=pk_test_xxx');
      return;
    }
    Stripe.publishableKey = key;
    Stripe.merchantIdentifier = _merchantId;
    // 与 returnURL link2ur://stripe-redirect 一致，支付宝/3DS 等重定向返回时 SDK 可识别
    Stripe.urlScheme = 'link2ur';
    await Stripe.instance.applySettings();
    AppLogger.info('Stripe initialized: key=${key.substring(0, key.length.clamp(0, 15))}..., '
        'merchant=$_merchantId');
  }

  // ==================== Apple Pay ====================

  /// 检查 Apple Pay（iOS）/ Google Pay（Android）是否可用（使用 Platform Pay API）
  /// 不传 googlePay 时，iOS 端会检测 Apple Pay，Android 端会检测 Google Pay
  Future<bool> isApplePaySupported() async {
    if (kIsWeb) return false;
    try {
      return await Stripe.instance.isPlatformPaySupported();
    } catch (e) {
      AppLogger.warning('Platform Pay support check failed: $e');
      return false;
    }
  }

  /// 使用 Apple Pay 完成支付（通过 Platform Pay API）
  /// [clientSecret] 后端创建的 PaymentIntent clientSecret
  /// [amount] 支付金额（分）
  /// [currency] 货币代码（如 GBP）
  /// [label] 支付摘要标签
  Future<bool> presentApplePay({
    required String clientSecret,
    required int amount,
    String currency = 'GBP',
    String label = 'Link²Ur',
    String countryCode = 'GB',
  }) async {
    if (kIsWeb) {
      throw const PaymentServiceException('Apple Pay is not available on Web');
    }

    try {
      final confirmParams = defaultTargetPlatform == TargetPlatform.iOS
          ? PlatformPayConfirmParams.applePay(
              applePay: ApplePayParams(
                cartItems: [
                  ApplePayCartSummaryItem.immediate(
                    label: label,
                    amount: (amount / 100).toStringAsFixed(2),
                  ),
                ],
                currencyCode: currency,
                merchantCountryCode: countryCode,
              ),
            )
          : PlatformPayConfirmParams.googlePay(
              googlePay: GooglePayParams(
                merchantCountryCode: countryCode,
                currencyCode: currency,
                merchantName: label,
                testEnv: kDebugMode,
              ),
            );
      await Stripe.instance.confirmPlatformPayPaymentIntent(
        clientSecret: clientSecret,
        confirmParams: confirmParams,
      );

      AppLogger.info('Apple Pay payment completed successfully');
      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        AppLogger.info('Apple Pay [$_platformTag] cancelled by user');
        return false;
      }
      AppLogger.error('Apple Pay [$_platformTag] error: code=${e.error.code}, message=${e.error.message}', e);
      rethrow;
    } catch (e, st) {
      AppLogger.error('Apple Pay [$_platformTag] error: $e', e, st);
      if (e is PlatformException) {
        AppLogger.error('PlatformException: code=${e.code}, message=${e.message}, details=${e.details}', e);
      }
      rethrow;
    }
  }

  // ==================== PaymentSheet (Card / Alipay) ====================

  /// 使用 PaymentSheet 完成支付
  /// [customerId] / [ephemeralKeySecret] 可选：后端有时不返回（如复用未完成 PI 或创建 Customer 失败），
  /// 仅当两者均非空时传入，否则走「仅 client_secret」的一次性支付，避免「加载失败」
  static const Duration _paymentSheetTimeout = Duration(seconds: 90);

  Future<bool> presentPaymentSheet({
    required String clientSecret,
    String? customerId,
    String? ephemeralKeySecret,
    String? merchantDisplayName,
    String? preferredPaymentMethod,
    String? returnUrl,
  }) async {
    // ✅ 对标 iOS 原生 PaymentViewModel.setupPaymentElement：
    // 当 Customer + EphemeralKey 均有效时才配置，否则走一次性支付（guest flow）
    // 注意：flutter_stripe 11.5.0 对应 stripe-ios 24.7.x，
    // 后端 EphemeralKey 的 stripe_version 必须与 SDK 兼容，否则 initPaymentSheet 会卡住。
    // 为安全起见，仅当两者均非空时才传入。
    final hasCustomer = (customerId != null && customerId.isNotEmpty) &&
        (ephemeralKeySecret != null && ephemeralKeySecret.isNotEmpty);
    AppLogger.info(
      'PaymentSheet: ${hasCustomer ? "Customer + EphemeralKey" : "guest flow (no customer)"}, '
      'clientSecret=${clientSecret.substring(0, clientSecret.length.clamp(0, 25))}..., '
      'publishableKey=${Stripe.publishableKey.substring(0, Stripe.publishableKey.length.clamp(0, 15))}...',
    );

    // 验证 publishable key 已设置
    if (Stripe.publishableKey.isEmpty) {
      throw const PaymentServiceException(
        'Stripe publishable key is not configured. Please check your build configuration.',
      );
    }

    // 验证 clientSecret 格式
    if (!clientSecret.contains('_secret_')) {
      AppLogger.error('PaymentSheet: clientSecret format invalid: ${clientSecret.substring(0, clientSecret.length.clamp(0, 30))}...');
      throw const PaymentServiceException(
        'Invalid payment configuration. Please try again.',
      );
    }

    try {
      // ✅ 对标 iOS PaymentViewModel.setupPaymentElement 配置
      await _initAndPresentSheet(
        clientSecret: clientSecret,
        useCustomer: hasCustomer,
        customerId: customerId,
        ephemeralKeySecret: ephemeralKeySecret,
        merchantDisplayName: merchantDisplayName,
        returnUrl: returnUrl,
      );

      AppLogger.info('Payment completed successfully');
      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        AppLogger.info('Payment cancelled by user');
        return false;
      }

      // ✅ 如果使用 Customer+EphemeralKey 失败，自动 fallback 到 guest flow 重试
      // 这可以解决 EphemeralKey stripe_version 不兼容的问题
      if (hasCustomer) {
        AppLogger.warning(
          'PaymentSheet failed with Customer+EphemeralKey (${e.error.code}: ${e.error.message}), '
          'retrying with guest flow...',
        );
        try {
          await _initAndPresentSheet(
            clientSecret: clientSecret,
            useCustomer: false,
            merchantDisplayName: merchantDisplayName,
            returnUrl: returnUrl,
          );
          AppLogger.info('Payment completed successfully (guest flow fallback)');
          return true;
        } on StripeException catch (retryE) {
          if (retryE.error.code == FailureCode.Canceled) {
            AppLogger.info('Payment cancelled by user (guest flow fallback)');
            return false;
          }
          AppLogger.error(
            'Stripe payment error (guest flow fallback): code=${retryE.error.code}, '
            'message=${retryE.error.message}',
            retryE,
          );
          rethrow;
        }
      }

      AppLogger.error(
        'Stripe payment error: code=${e.error.code}, '
        'message=${e.error.message}, '
        'localizedMessage=${e.error.localizedMessage}',
        e,
      );
      rethrow;
    } on PaymentServiceException {
      // ✅ 超时等错误也尝试 fallback（如 initPaymentSheet 超时可能是 EphemeralKey 问题）
      if (hasCustomer) {
        AppLogger.warning('PaymentSheet timed out with Customer, retrying guest flow...');
        try {
          await _initAndPresentSheet(
            clientSecret: clientSecret,
            useCustomer: false,
            merchantDisplayName: merchantDisplayName,
            returnUrl: returnUrl,
          );
          AppLogger.info('Payment completed successfully (guest flow fallback after timeout)');
          return true;
        } on StripeException catch (retryE) {
          if (retryE.error.code == FailureCode.Canceled) return false;
          rethrow;
        } catch (_) {
          // fallback 也失败了，抛出原始错误
        }
      }
      rethrow;
    } catch (e, st) {
      AppLogger.error('Payment error [$_platformTag]: $e', e, st);
      if (e is PlatformException) {
        AppLogger.error(
          'PlatformException: code=${e.code}, message=${e.message}, details=${e.details}',
          e,
        );
      }
      rethrow;
    }
  }

  /// 内部方法：初始化并展示 PaymentSheet
  Future<void> _initAndPresentSheet({
    required String clientSecret,
    required bool useCustomer,
    String? customerId,
    String? ephemeralKeySecret,
    String? merchantDisplayName,
    String? returnUrl,
  }) async {
    AppLogger.info('PaymentSheet [$_platformTag]: initPaymentSheet (useCustomer=$useCustomer)...');
    final stopwatch = Stopwatch()..start();

    try {
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        customerId: useCustomer ? customerId : null,
        customerEphemeralKeySecret: useCustomer ? ephemeralKeySecret : null,
        merchantDisplayName: merchantDisplayName ?? 'Link²Ur',
        style: ThemeMode.system,
        // 对标 iOS: allowsDelayedPaymentMethods = true（支持支付宝等延迟支付方式）
        allowsDelayedPaymentMethods: true,
        // 对标 iOS: returnURL = "link2ur://stripe-redirect"
        returnURL: returnUrl ?? 'link2ur://stripe-redirect',
        // 对标 iOS: defaultBillingDetails.address.country = "GB"
        billingDetails: const BillingDetails(
          address: Address(
            country: 'GB',
            city: '',
            line1: '',
            line2: '',
            postalCode: '',
            state: '',
          ),
        ),
        billingDetailsCollectionConfiguration:
            const BillingDetailsCollectionConfiguration(
          address: AddressCollectionMode.never,
        ),
      ),
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw PaymentServiceException(
          'Payment sheet initialisation timed out (${stopwatch.elapsedMilliseconds}ms). '
          'Please check your network and try again.',
        );
      },
    );
    } catch (e, st) {
      AppLogger.error(
        'PaymentSheet initPaymentSheet FAILED [$_platformTag]: $e',
        e,
        st,
      );
      rethrow;
    }

    stopwatch.stop();
    AppLogger.info('PaymentSheet [$_platformTag]: initPaymentSheet completed in ${stopwatch.elapsedMilliseconds}ms, presenting...');

    // 展示 PaymentSheet
    final presentStopwatch = Stopwatch()..start();
    try {
      await Stripe.instance.presentPaymentSheet().timeout(
        _paymentSheetTimeout,
        onTimeout: () {
          throw PaymentServiceException(
            'Payment sheet did not respond in ${presentStopwatch.elapsedMilliseconds}ms. Please try again.',
          );
        },
      );
    } catch (e, st) {
      AppLogger.error(
        'PaymentSheet presentPaymentSheet FAILED [$_platformTag]: $e',
        e,
        st,
      );
      if (e is PlatformException) {
        AppLogger.error(
          'PlatformException details: code=${e.code}, message=${e.message}, details=${e.details}',
          e,
        );
      }
      rethrow;
    }
    presentStopwatch.stop();
    AppLogger.info('PaymentSheet [$_platformTag]: presentPaymentSheet completed in ${presentStopwatch.elapsedMilliseconds}ms');
  }

  /// 从 TaskPaymentResponse 发起支付
  Future<bool> processTaskPayment(TaskPaymentResponse paymentResponse) async {
    if (!paymentResponse.requiresStripePayment) {
      // 免费或不需要支付
      return true;
    }

    return presentPaymentSheet(
      clientSecret: paymentResponse.clientSecret!,
      customerId: paymentResponse.customerId,
      ephemeralKeySecret: paymentResponse.ephemeralKeySecret,
    );
  }
}

/// 支付服务异常
class PaymentServiceException extends AppException {
  const PaymentServiceException(super.message);
}
