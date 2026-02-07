import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/logger.dart';
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

  /// 检查 Apple Pay 是否可用（使用 Platform Pay API）
  Future<bool> isApplePaySupported() async {
    if (!Platform.isIOS) return false;
    try {
      return await Stripe.instance.isPlatformPaySupported(
        googlePay: const IsGooglePaySupportedParams(),
      );
    } catch (e) {
      AppLogger.warning('Apple Pay support check failed: $e');
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
    if (!Platform.isIOS) {
      throw PaymentServiceException('Apple Pay is only available on iOS');
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
  /// [preferredPaymentMethod] 可选：card / alipay
  Future<bool> presentPaymentSheet({
    required String clientSecret,
    required String customerId,
    required String ephemeralKeySecret,
    String? merchantDisplayName,
    String? preferredPaymentMethod,
    String? returnUrl,
  }) async {
    try {
      // 初始化 PaymentSheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          customerEphemeralKeySecret: ephemeralKeySecret,
          customerId: customerId,
          merchantDisplayName: merchantDisplayName ?? 'Link²Ur',
          style: ThemeMode.system,
          allowsDelayedPaymentMethods: true,
          returnURL: returnUrl ?? 'link2ur://stripe-redirect',
          billingDetailsCollectionConfiguration:
              const BillingDetailsCollectionConfiguration(
            address: AddressCollectionMode.never,
          ),
        ),
      );

      // 展示 PaymentSheet
      await Stripe.instance.presentPaymentSheet();

      AppLogger.info('Payment completed successfully');
      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        AppLogger.info('Payment cancelled by user');
        return false;
      }
      AppLogger.error('Stripe payment error', e);
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
      customerId: paymentResponse.customerId ?? '',
      ephemeralKeySecret: paymentResponse.ephemeralKeySecret ?? '',
    );
  }
}

/// 支付服务异常
class PaymentServiceException implements Exception {
  PaymentServiceException(this.message);
  final String message;

  @override
  String toString() => 'PaymentServiceException: $message';
}
