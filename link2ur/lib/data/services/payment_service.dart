import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/app_exception.dart';
import '../models/payment.dart';

/// Stripe 支付服务
/// 封装 Stripe SDK 的支付流程：信用卡、Apple Pay、支付宝
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  /// Apple Pay Merchant ID
  static const String _merchantId = 'merchant.com.link2ur';

  /// 初始化 Stripe
  Future<void> init() async {
    Stripe.publishableKey = AppConfig.instance.stripePublishableKey;
    Stripe.merchantIdentifier = _merchantId;
    await Stripe.instance.applySettings();
    AppLogger.info('Stripe initialized');
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
      await Stripe.instance.confirmPlatformPayPaymentIntent(
        clientSecret: clientSecret,
        confirmParams: PlatformPayConfirmParams.applePay(
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
        ),
      );

      AppLogger.info('Apple Pay payment completed successfully');
      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        AppLogger.info('Apple Pay cancelled by user');
        return false;
      }
      AppLogger.error('Apple Pay error', e);
      rethrow;
    } catch (e) {
      AppLogger.error('Apple Pay error', e);
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
    final hasCustomer = (customerId != null && customerId.isNotEmpty) &&
        (ephemeralKeySecret != null && ephemeralKeySecret.isNotEmpty);
    if (hasCustomer) {
      AppLogger.info('PaymentSheet: using Customer + EphemeralKey');
    } else {
      AppLogger.info('PaymentSheet: guest flow (no customer)');
    }
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          customerId: hasCustomer ? customerId : null,
          customerEphemeralKeySecret: hasCustomer ? ephemeralKeySecret : null,
          merchantDisplayName: merchantDisplayName ?? 'Link²Ur',
          style: ThemeMode.system,
          allowsDelayedPaymentMethods: true,
          returnURL: returnUrl ?? 'link2ur://stripe-redirect',
          billingDetailsCollectionConfiguration:
              const BillingDetailsCollectionConfiguration(
            address: AddressCollectionMode.never,
          ),
        ),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw PaymentServiceException(
            'Payment sheet initialisation timed out. Please check your network and try again.',
          );
        },
      );

      // 展示 PaymentSheet（含超时，避免一直转圈）
      await Stripe.instance.presentPaymentSheet().timeout(
        _paymentSheetTimeout,
        onTimeout: () {
          throw PaymentServiceException(
            'Payment sheet did not open in time. Please try again.',
          );
        },
      );

      AppLogger.info('Payment completed successfully');
      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        AppLogger.info('Payment cancelled by user');
        return false;
      }
      AppLogger.error('Stripe payment error', e);
      rethrow;
    } on PaymentServiceException {
      rethrow;
    } catch (e) {
      AppLogger.error('Payment error', e);
      rethrow;
    }
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
