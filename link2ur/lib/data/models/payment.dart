import 'package:equatable/equatable.dart';

/// 任务支付响应模型
/// 参考后端 TaskPaymentResponse
class TaskPaymentResponse extends Equatable {
  const TaskPaymentResponse({
    this.paymentId,
    this.feeType = 'task_amount',
    required this.originalAmount,
    this.originalAmountDisplay = '',
    this.couponDiscount,
    this.couponDiscountDisplay,
    this.couponName,
    this.couponType,
    this.couponDescription,
    required this.finalAmount,
    this.finalAmountDisplay = '',
    this.currency = 'GBP',
    this.clientSecret,
    this.paymentIntentId,
    this.customerId,
    this.ephemeralKeySecret,
    this.note = '',
    this.calculationSteps,
  });

  final int? paymentId;
  final String feeType;
  final int originalAmount; // 单位：便士
  final String originalAmountDisplay;
  final int? couponDiscount; // 单位：便士
  final String? couponDiscountDisplay;
  final String? couponName;
  final String? couponType; // fixed_amount, percentage
  final String? couponDescription;
  final int finalAmount; // 单位：便士
  final String finalAmountDisplay;
  final String currency;
  final String? clientSecret; // Stripe PaymentIntent client_secret
  final String? paymentIntentId;
  final String? customerId; // Stripe Customer ID
  final String? ephemeralKeySecret;
  final String? note;
  final List<Map<String, dynamic>>? calculationSteps;

  /// 是否有优惠
  bool get hasDiscount => couponDiscount != null && couponDiscount! > 0;

  /// 是否免费
  bool get isFree => finalAmount == 0;

  /// 是否需要Stripe支付
  bool get requiresStripePayment => clientSecret != null && !isFree;

  factory TaskPaymentResponse.fromJson(Map<String, dynamic> json) {
    return TaskPaymentResponse(
      paymentId: json['payment_id'] as int?,
      feeType: json['fee_type'] as String? ?? 'task_amount',
      originalAmount: json['original_amount'] as int? ?? 0,
      originalAmountDisplay:
          json['original_amount_display'] as String? ?? '',
      couponDiscount: json['coupon_discount'] as int?,
      couponDiscountDisplay:
          json['coupon_discount_display'] as String?,
      couponName: json['coupon_name'] as String?,
      couponType: json['coupon_type'] as String?,
      couponDescription: json['coupon_description'] as String?,
      finalAmount: json['final_amount'] as int? ?? 0,
      finalAmountDisplay: json['final_amount_display'] as String? ?? '',
      currency: json['currency'] as String? ?? 'GBP',
      clientSecret: json['client_secret'] as String?,
      paymentIntentId: json['payment_intent_id'] as String?,
      customerId: json['customer_id'] as String?,
      ephemeralKeySecret: json['ephemeral_key_secret'] as String?,
      note: json['note'] as String? ?? '',
      calculationSteps: (json['calculation_steps'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'payment_id': paymentId,
      'fee_type': feeType,
      'original_amount': originalAmount,
      'original_amount_display': originalAmountDisplay,
      'coupon_discount': couponDiscount,
      'coupon_discount_display': couponDiscountDisplay,
      'coupon_name': couponName,
      'coupon_type': couponType,
      'coupon_description': couponDescription,
      'final_amount': finalAmount,
      'final_amount_display': finalAmountDisplay,
      'currency': currency,
      'client_secret': clientSecret,
      'payment_intent_id': paymentIntentId,
      'customer_id': customerId,
      'ephemeral_key_secret': ephemeralKeySecret,
      'note': note,
      'calculation_steps': calculationSteps,
    };
  }

  @override
  List<Object?> get props => [paymentId, finalAmount, clientSecret];
}

/// Stripe Connect 状态
class StripeConnectStatus extends Equatable {
  const StripeConnectStatus({
    this.isConnected = false,
    this.accountId,
    this.chargesEnabled = false,
    this.payoutsEnabled = false,
    this.onboardingUrl,
  });

  final bool isConnected;
  final String? accountId;
  final bool chargesEnabled;
  final bool payoutsEnabled;
  final String? onboardingUrl;

  /// 账户是否已完全激活
  bool get isFullyActive => isConnected && chargesEnabled && payoutsEnabled;

  factory StripeConnectStatus.fromJson(Map<String, dynamic> json) {
    return StripeConnectStatus(
      isConnected: json['is_connected'] as bool? ?? false,
      accountId: json['account_id'] as String?,
      chargesEnabled: json['charges_enabled'] as bool? ?? false,
      payoutsEnabled: json['payouts_enabled'] as bool? ?? false,
      onboardingUrl: json['onboarding_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [isConnected, accountId, chargesEnabled];
}

/// 钱包信息模型
class WalletInfo extends Equatable {
  const WalletInfo({
    this.balance = 0,
    this.currency = 'GBP',
    this.totalEarned = 0,
    this.totalSpent = 0,
    this.pendingBalance = 0,
    this.stripeConnectStatus,
  });

  final double balance;
  final String currency;
  final double totalEarned;
  final double totalSpent;
  final double pendingBalance;
  final StripeConnectStatus? stripeConnectStatus;

  String get balanceDisplay => '£${balance.toStringAsFixed(2)}';
  String get totalEarnedDisplay => '£${totalEarned.toStringAsFixed(2)}';
  String get totalSpentDisplay => '£${totalSpent.toStringAsFixed(2)}';

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    return WalletInfo(
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'GBP',
      totalEarned: (json['total_earned'] as num?)?.toDouble() ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0,
      pendingBalance: (json['pending_balance'] as num?)?.toDouble() ?? 0,
      stripeConnectStatus: json['stripe_connect_status'] != null
          ? StripeConnectStatus.fromJson(
              json['stripe_connect_status'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  List<Object?> get props => [balance, currency, totalEarned, totalSpent];
}

/// 交易记录模型
class Transaction extends Equatable {
  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    this.currency = 'GBP',
    this.description,
    this.status = 'completed',
    this.relatedTaskId,
    this.createdAt,
  });

  final int id;
  final String type; // payment, payout, refund, fee
  final double amount;
  final String currency;
  final String? description;
  final String status; // pending, completed, failed, refunded
  final int? relatedTaskId;
  final DateTime? createdAt;

  bool get isIncome => amount > 0;
  String get amountDisplay =>
      '${isIncome ? '+' : ''}£${amount.abs().toStringAsFixed(2)}';

  String get typeText {
    switch (type) {
      case 'payment':
        return '支付';
      case 'payout':
        return '收款';
      case 'refund':
        return '退款';
      case 'fee':
        return '服务费';
      default:
        return type;
    }
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as int,
      type: json['type'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'GBP',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'completed',
      relatedTaskId: json['related_task_id'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  @override
  List<Object?> get props => [id, type, amount, status];
}
