import 'package:equatable/equatable.dart';

import '../../core/utils/helpers.dart';
import '../../core/utils/json_utils.dart';

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
    this.paymentType,
    this.walletAmountUsed,
    this.stripeAmountDue,
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
  /// 支付类型：'stripe' (纯Stripe), 'wallet' (纯余额), 'mixed' (混合支付)
  final String? paymentType;
  /// 使用的钱包余额金额（便士）
  final int? walletAmountUsed;
  /// 需要 Stripe 支付的金额（便士），混合支付时有值
  final int? stripeAmountDue;

  /// 是否有优惠
  bool get hasDiscount => couponDiscount != null && couponDiscount! > 0;

  /// 是否免费
  bool get isFree => finalAmount == 0;

  /// 是否纯钱包支付（无需 Stripe）
  bool get isWalletOnly => paymentType == 'wallet';

  /// 是否混合支付（钱包 + Stripe）
  bool get isMixedPayment => paymentType == 'mixed';

  /// 是否需要Stripe支付
  bool get requiresStripePayment => clientSecret != null && !isFree && !isWalletOnly;

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
      paymentType: json['payment_type'] as String?,
      walletAmountUsed: json['wallet_amount_used'] as int?,
      stripeAmountDue: json['stripe_amount_due'] as int?,
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
      'payment_type': paymentType,
      'wallet_amount_used': walletAmountUsed,
      'stripe_amount_due': stripeAmountDue,
    };
  }

  @override
  List<Object?> get props => [
        paymentId, feeType, originalAmount, originalAmountDisplay,
        couponDiscount, couponDiscountDisplay, couponName, couponType, couponDescription,
        finalAmount, finalAmountDisplay, currency,
        clientSecret, paymentIntentId, customerId, ephemeralKeySecret,
        note, calculationSteps, paymentType, walletAmountUsed, stripeAmountDue,
      ];
}

/// Stripe Connect 状态
class StripeConnectStatus extends Equatable {
  const StripeConnectStatus({
    this.isConnected = false,
    this.accountId,
    this.chargesEnabled = false,
    this.payoutsEnabled = false,
    this.detailsSubmitted = false,
    this.needsOnboarding = true,
    this.clientSecret,
    this.onboardingUrl,
  });

  final bool isConnected;
  final String? accountId;
  final bool chargesEnabled;
  final bool payoutsEnabled;
  final bool detailsSubmitted;
  final bool needsOnboarding;
  final String? clientSecret;
  final String? onboardingUrl;

  /// 账户是否已完全激活
  bool get isFullyActive => isConnected && chargesEnabled && payoutsEnabled;

  factory StripeConnectStatus.fromJson(Map<String, dynamic> json) {
    final accountId = json['account_id'] as String?;
    return StripeConnectStatus(
      isConnected: accountId != null,
      accountId: accountId,
      chargesEnabled: parseBool(json['charges_enabled']),
      payoutsEnabled: parseBool(json['payouts_enabled']),
      detailsSubmitted: parseBool(json['details_submitted']),
      needsOnboarding: parseBool(json['needs_onboarding'], true),
      clientSecret: json['client_secret'] as String?,
      onboardingUrl: json['onboarding_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [isConnected, accountId, chargesEnabled, payoutsEnabled, detailsSubmitted, needsOnboarding, clientSecret];
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

  String get balanceDisplay => '${Helpers.currencySymbolFor(currency)}${balance.toStringAsFixed(2)}';
  String get totalEarnedDisplay => '${Helpers.currencySymbolFor(currency)}${totalEarned.toStringAsFixed(2)}';
  String get totalSpentDisplay => '${Helpers.currencySymbolFor(currency)}${totalSpent.toStringAsFixed(2)}';

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
  List<Object?> get props => [balance, currency, totalEarned, totalSpent, pendingBalance, stripeConnectStatus];
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
      '${isIncome ? '+' : ''}${Helpers.currencySymbolFor(currency)}${amount.abs().toStringAsFixed(2)}';

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
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  @override
  List<Object?> get props => [id, type, amount, status];
}

/// Stripe Connect 余额模型（对标 iOS StripeConnectBalance）
class StripeConnectBalance extends Equatable {
  const StripeConnectBalance({
    this.available = 0,
    this.pending = 0,
    this.currency = 'gbp',
  });

  final double available;
  final double pending;
  final String currency;

  double get total => available + pending;

  String formatAmount(double amount) {
    return '${Helpers.currencySymbolFor(currency)}${amount.toStringAsFixed(2)}';
  }

  factory StripeConnectBalance.fromJson(Map<String, dynamic> json) {
    // 后端已将 pence 转换为英镑（/100），这里直接使用
    final available = json['available'];
    final pending = json['pending'];

    double parseAmount(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is List && val.isNotEmpty) {
        final first = val.first;
        if (first is Map<String, dynamic>) {
          return (first['amount'] as num?)?.toDouble() ?? 0;
        }
      }
      return 0;
    }

    return StripeConnectBalance(
      available: parseAmount(available),
      pending: parseAmount(pending),
      currency: json['currency'] as String? ?? 'gbp',
    );
  }

  @override
  List<Object?> get props => [available, pending, currency];
}

/// Stripe Connect 账户详情（对标 iOS StripeConnectAccountDetails）
class StripeConnectAccountDetails extends Equatable {
  const StripeConnectAccountDetails({
    required this.accountId,
    this.displayName,
    this.email,
    this.country = '',
    this.type = '',
    this.detailsSubmitted = false,
    this.chargesEnabled = false,
    this.payoutsEnabled = false,
    this.dashboardUrl,
    this.dashboardUnavailableReason,
  });

  final String accountId;
  final String? displayName;
  final String? email;
  final String country;
  final String type;
  final bool detailsSubmitted;
  final bool chargesEnabled;
  final bool payoutsEnabled;
  final String? dashboardUrl;
  final String? dashboardUnavailableReason;

  factory StripeConnectAccountDetails.fromJson(Map<String, dynamic> json) {
    return StripeConnectAccountDetails(
      accountId: json['account_id'] as String? ?? '',
      displayName: json['display_name'] as String?,
      email: json['email'] as String?,
      country: json['country'] as String? ?? '',
      type: json['type'] as String? ?? '',
      detailsSubmitted: parseBool(json['details_submitted']),
      chargesEnabled: parseBool(json['charges_enabled']),
      payoutsEnabled: parseBool(json['payouts_enabled']),
      dashboardUrl: json['dashboard_url'] as String?,
      dashboardUnavailableReason: json['dashboard_unavailable_reason'] as String?,
    );
  }

  @override
  List<Object?> get props => [accountId, chargesEnabled, payoutsEnabled];
}

/// 外部账户（银行账户/银行卡）（对标 iOS ExternalAccount）
class ExternalAccount extends Equatable {
  const ExternalAccount({
    required this.id,
    required this.object, // bank_account 或 card
    this.bankName,
    this.last4,
    this.routingNumber,
    this.accountHolderName,
    this.accountHolderType,
    this.currency,
    this.country,
    this.status,
    this.brand,
    this.expMonth,
    this.expYear,
    this.funding,
    this.isDefault = false,
  });

  final String id;
  final String object;
  final String? bankName;
  final String? last4;
  final String? routingNumber;
  final String? accountHolderName;
  final String? accountHolderType;
  final String? currency;
  final String? country;
  final String? status;
  final String? brand;
  final int? expMonth;
  final int? expYear;
  final String? funding;
  final bool isDefault;

  bool get isBankAccount => object == 'bank_account';
  bool get isCard => object == 'card';

  factory ExternalAccount.fromJson(Map<String, dynamic> json) {
    return ExternalAccount(
      id: json['id'] as String? ?? '',
      object: json['object'] as String? ?? 'bank_account',
      bankName: json['bank_name'] as String?,
      last4: json['last4'] as String?,
      routingNumber: json['routing_number'] as String?,
      accountHolderName: json['account_holder_name'] as String?,
      accountHolderType: json['account_holder_type'] as String?,
      currency: json['currency'] as String?,
      country: json['country'] as String?,
      status: json['status'] as String?,
      brand: json['brand'] as String?,
      expMonth: json['exp_month'] as int?,
      expYear: json['exp_year'] as int?,
      funding: json['funding'] as String?,
      isDefault: parseBool(json['default_for_currency']),
    );
  }

  @override
  List<Object?> get props => [id, object, last4];
}

/// Stripe Connect 交易记录（对标 iOS StripeConnectTransaction）
class StripeConnectTransaction extends Equatable {
  const StripeConnectTransaction({
    required this.id,
    required this.amount,
    this.currency = 'gbp',
    this.description = '',
    this.status = '',
    this.type = '',
    this.source = '',
    this.createdAt = '',
    this.created,
    this.metadata,
  });

  final String id;
  final double amount;
  final String currency;
  final String description;
  final String status;
  final String type; // income / expense
  final String source; // payout / transfer / charge / payment_intent
  final String createdAt; // ISO 格式时间
  final int? created; // Unix 时间戳（对标 iOS）
  final Map<String, String>? metadata;

  bool get isIncome => type != 'expense';

  String get amountDisplay {
    final prefix = isIncome ? '+' : '-';
    return '$prefix${Helpers.currencySymbolFor(currency)}${amount.abs().toStringAsFixed(2)}';
  }

  factory StripeConnectTransaction.fromJson(Map<String, dynamic> json) {
    return StripeConnectTransaction(
      id: json['id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'gbp',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? '',
      type: json['type'] as String? ?? '',
      source: json['source'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      created: json['created'] as int?,
      metadata: (json['metadata'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  @override
  List<Object?> get props => [id, amount, status];
}

/// 任务支付记录（对标 iOS TaskPaymentRecord）
class TaskPaymentRecord extends Equatable {
  const TaskPaymentRecord({
    required this.id,
    this.taskId,
    this.taskTitle,
    this.amount = 0,
    this.currency = 'gbp',
    this.status = '',
    this.paymentMethod,
    this.createdAt,
    this.totalAmount,
    this.stripeAmount,
    this.pointsUsed,
    this.couponDiscount,
    this.applicationFee,
    this.paymentIntentId,
  });

  final int id;
  final int? taskId;
  final String? taskTitle;
  final double amount; // final_amount in pounds
  final String currency;
  final String status;
  final String? paymentMethod;
  final String? createdAt;
  final double? totalAmount; // original total in pounds
  final double? stripeAmount; // actual Stripe charge in pounds
  final int? pointsUsed;
  final double? couponDiscount; // discount in pounds
  final double? applicationFee; // platform fee in pounds
  final String? paymentIntentId;

  factory TaskPaymentRecord.fromJson(Map<String, dynamic> json) {
    // 后端返回 final_amount（便士），转换为英镑
    final rawAmount = json['amount'] ?? json['final_amount'] ?? json['total_amount'];
    final amount = (rawAmount as num?)?.toDouble() ?? 0;
    // 如果是 final_amount / total_amount（便士），需要 /100
    final needsConversion = json.containsKey('final_amount') || json.containsKey('total_amount');
    final amountPounds = (needsConversion && !json.containsKey('amount'))
        ? amount / 100
        : amount;

    // task_title 可能在顶层或嵌套在 task 对象中
    final taskData = json['task'] as Map<String, dynamic>?;
    final taskTitle = json['task_title'] as String? ?? taskData?['title'] as String?;
    final taskId = json['task_id'] as int? ?? taskData?['id'] as int?;

    // 解析其他金额字段（便士→英镑）
    double? parsePence(dynamic val) {
      if (val == null) return null;
      return (val as num).toDouble() / 100;
    }

    return TaskPaymentRecord(
      id: json['id'] as int? ?? 0,
      taskId: taskId,
      taskTitle: taskTitle,
      amount: amountPounds,
      currency: json['currency'] as String? ?? 'gbp',
      status: json['status'] as String? ?? '',
      paymentMethod: json['payment_method'] as String?,
      createdAt: json['created_at'] as String?,
      totalAmount: json.containsKey('total_amount') ? parsePence(json['total_amount']) : null,
      stripeAmount: json.containsKey('stripe_amount') ? parsePence(json['stripe_amount']) : null,
      pointsUsed: json['points_used'] as int?,
      couponDiscount: json.containsKey('coupon_discount') ? parsePence(json['coupon_discount']) : null,
      applicationFee: json.containsKey('application_fee') ? parsePence(json['application_fee']) : null,
      paymentIntentId: json['payment_intent_id'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, taskId, amount, status, paymentIntentId];
}

class WalletBalance extends Equatable {
  final double balance;
  final double totalEarned;
  final double totalWithdrawn;
  final double totalSpent;
  final String currency;

  const WalletBalance({
    this.balance = 0.0,
    this.totalEarned = 0.0,
    this.totalWithdrawn = 0.0,
    this.totalSpent = 0.0,
    this.currency = 'GBP',
  });

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      totalEarned: (json['total_earned'] as num?)?.toDouble() ?? 0.0,
      totalWithdrawn: (json['total_withdrawn'] as num?)?.toDouble() ?? 0.0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'GBP',
    );
  }

  @override
  List<Object?> get props => [balance, totalEarned, totalWithdrawn, totalSpent, currency];
}

class WalletTransactionItem extends Equatable {
  final int id;
  final String type;
  final double amount;
  final double balanceAfter;
  final String status;
  final String source;
  final String? relatedId;
  final String? relatedType;
  final String? description;
  final double? feeAmount;
  final double? grossAmount;
  final String currency;
  final String createdAt;

  const WalletTransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.status,
    required this.source,
    this.relatedId,
    this.relatedType,
    this.description,
    this.feeAmount,
    this.grossAmount,
    this.currency = 'GBP',
    required this.createdAt,
  });

  factory WalletTransactionItem.fromJson(Map<String, dynamic> json) {
    return WalletTransactionItem(
      id: json['id'] as int,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      balanceAfter: (json['balance_after'] as num).toDouble(),
      status: json['status'] as String,
      source: json['source'] as String,
      relatedId: json['related_id'] as String?,
      relatedType: json['related_type'] as String?,
      description: json['description'] as String?,
      feeAmount: (json['fee_amount'] as num?)?.toDouble(),
      grossAmount: (json['gross_amount'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'GBP',
      createdAt: json['created_at'] as String,
    );
  }

  @override
  List<Object?> get props => [id, type, amount, status, source, currency, createdAt];
}
