import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/logger.dart';
import '../models/payment.dart';

/// Stripe 支付服务
/// 封装 Stripe SDK 的支付流程
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  /// 初始化 Stripe
  Future<void> init() async {
    Stripe.publishableKey = AppConfig.instance.stripePublishableKey;
    await Stripe.instance.applySettings();
    AppLogger.info('Stripe initialized');
  }

  /// 使用 PaymentSheet 完成支付
  /// 传入后端返回的 TaskPaymentResponse
  Future<bool> presentPaymentSheet({
    required String clientSecret,
    required String customerId,
    required String ephemeralKeySecret,
    String? merchantDisplayName,
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
