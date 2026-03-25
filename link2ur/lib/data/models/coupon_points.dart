import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/helpers.dart';

/// 积分账户模型
/// 参考后端 PointsAccountOut
class PointsAccount extends Equatable {
  const PointsAccount({
    this.balance = 0,
    this.balanceDisplay = '0',
    this.currency = 'GBP',
    this.totalEarned = 0,
    this.totalSpent = 0,
    this.totalPaymentIncome = 0,
    this.totalPaymentSpent = 0,
    this.usageRestrictions,
  });

  final int balance;
  final String balanceDisplay;
  final String currency;
  final int totalEarned;       // 积分累计获得
  final int totalSpent;        // 积分累计消费
  final double totalPaymentIncome;  // 实际收入金额（英镑）
  final double totalPaymentSpent;   // 实际消费金额（英镑）
  final Map<String, dynamic>? usageRestrictions;

  factory PointsAccount.fromJson(Map<String, dynamic> json) {
    return PointsAccount(
      balance: json['balance'] as int? ?? 0,
      balanceDisplay: json['balance_display'] as String? ?? '0',
      currency: json['currency'] as String? ?? 'GBP',
      totalEarned: json['total_earned'] as int? ?? 0,
      totalSpent: json['total_spent'] as int? ?? 0,
      totalPaymentIncome: (json['total_payment_income'] as num?)?.toDouble() ?? 0,
      totalPaymentSpent: (json['total_payment_spent'] as num?)?.toDouble() ?? 0,
      usageRestrictions:
          json['usage_restrictions'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'balance': balance,
      'balance_display': balanceDisplay,
      'currency': currency,
      'total_earned': totalEarned,
      'total_spent': totalSpent,
      'total_payment_income': totalPaymentIncome,
      'total_payment_spent': totalPaymentSpent,
      'usage_restrictions': usageRestrictions,
    };
  }

  @override
  List<Object?> get props => [
        balance, balanceDisplay, currency,
        totalEarned, totalSpent,
        totalPaymentIncome, totalPaymentSpent,
      ];

  static const empty = PointsAccount();
}

/// 积分交易模型
/// 参考后端 PointsTransactionOut
class PointsTransaction extends Equatable {
  const PointsTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.amountDisplay = '',
    this.balanceAfter = 0,
    this.balanceAfterDisplay = '',
    this.currency = 'GBP',
    this.source,
    this.description,
    this.batchId,
    this.createdAt,
  });

  final int id;
  final String type; // earn, spend, refund, expire, coupon_redeem
  final int amount;
  final String amountDisplay;
  final int balanceAfter;
  final String balanceAfterDisplay;
  final String currency;
  final String? source;
  final String? description;
  final String? batchId;
  final DateTime? createdAt;

  /// 是否是收入
  bool get isIncome => type == 'earn' || type == 'refund';

  /// 是否是支出
  bool get isExpense => type == 'spend' || type == 'coupon_redeem' || type == 'expire';

  /// 类型标识（需要在 View 层通过 l10n 映射为本地化文本）
  String get typeKey {
    switch (type) {
      case 'earn':
        return 'points_type_earn';
      case 'spend':
        return 'points_type_spend';
      case 'refund':
        return 'points_type_refund';
      case 'expire':
        return 'points_type_expire';
      case 'coupon_redeem':
        return 'points_type_coupon_redeem';
      default:
        return type;
    }
  }

  factory PointsTransaction.fromJson(Map<String, dynamic> json) {
    return PointsTransaction(
      id: json['id'] as int,
      type: json['type'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      amountDisplay: json['amount_display'] as String? ?? '',
      balanceAfter: json['balance_after'] as int? ?? 0,
      balanceAfterDisplay: json['balance_after_display'] as String? ?? '',
      currency: json['currency'] as String? ?? 'GBP',
      source: json['source'] as String?,
      description: json['description'] as String?,
      batchId: json['batch_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  @override
  List<Object?> get props => [id, type, amount, createdAt];
}

/// 优惠券模型
/// 参考后端 CouponOut
class Coupon extends Equatable {
  const Coupon({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.discountValue = 0,
    this.discountValueDisplay = '',
    this.minAmount = 0,
    this.minAmountDisplay = '',
    this.currency = 'GBP',
    this.validUntil,
    this.usageConditions,
    this.pointsRequired = 0,
    this.description,
    this.validFrom,
    this.eligibilityType,
    this.applicableScenarios,
    this.totalQuantity,
    this.perUserLimit,
    this.distributionType = 'public',
  });

  final int id;
  final String code;
  final String name;
  final String type; // fixed_amount, percentage
  final int discountValue; // 单位：便士
  final String discountValueDisplay;
  final int minAmount; // 最低使用金额，单位：便士
  final String minAmountDisplay;
  final String currency;
  final DateTime? validUntil;
  final Map<String, dynamic>? usageConditions;
  final int pointsRequired;
  final String? description;
  final DateTime? validFrom;
  final String? eligibilityType;
  final List<String>? applicableScenarios;
  final int? totalQuantity;
  final int? perUserLimit;
  final String distributionType;

  /// 是否已过期
  bool get isExpired =>
      validUntil != null && validUntil!.isBefore(DateTime.now());

  /// 折扣类型标识（需要在 View 层通过 l10n 映射为本地化文本）
  String get typeKey {
    switch (type) {
      case 'fixed_amount':
        return 'coupon_type_fixed';
      case 'percentage':
        return 'coupon_type_percentage';
      default:
        return type;
    }
  }

  /// 格式化后的折扣显示（根据类型区分：percentage 为 8%/8.5%，fixed_amount 为 £8.00）
  /// discountValue: percentage 时为基点(800=8%, 850=8.5%)，fixed_amount 时为便士(800=£8)
  String get discountDisplayFormatted {
    if (type == 'percentage') {
      final pct = discountValue / 100;
      // 整数百分比不显示小数点（8.0% → 8%），非整数保留一位（8.5% → 8.5%）
      return pct == pct.roundToDouble()
          ? '${pct.round()}%'
          : '${pct.toStringAsFixed(1)}%';
    } else {
      return '${Helpers.currencySymbolFor(currency)}${(discountValue / 100).toStringAsFixed(2)}';
    }
  }

  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      id: json['id'] as int,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'fixed_amount',
      discountValue: json['discount_value'] as int? ?? 0,
      discountValueDisplay: json['discount_value_display'] as String? ?? '',
      minAmount: json['min_amount'] as int? ?? 0,
      minAmountDisplay: json['min_amount_display'] as String? ?? '',
      currency: json['currency'] as String? ?? 'GBP',
      validUntil: json['valid_until'] != null
          ? DateTime.tryParse(json['valid_until'])
          : null,
      usageConditions:
          json['usage_conditions'] as Map<String, dynamic>?,
      pointsRequired: json['points_required'] as int? ?? 0,
      description: json['description'] as String?,
      validFrom: json['valid_from'] != null
          ? DateTime.tryParse(json['valid_from'])
          : null,
      eligibilityType: json['eligibility_type'] as String?,
      applicableScenarios: (json['applicable_scenarios'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      totalQuantity: json['total_quantity'] as int?,
      perUserLimit: json['per_user_limit'] as int?,
      distributionType: json['distribution_type'] as String? ?? 'public',
    );
  }

  @override
  List<Object?> get props =>
      [id, code, name, type, discountValue, minAmount, validUntil, pointsRequired,
       description, validFrom, eligibilityType, applicableScenarios,
       totalQuantity, perUserLimit, distributionType];
}

/// 用户优惠券模型
/// 参考后端 UserCouponOut
class UserCoupon extends Equatable {
  const UserCoupon({
    required this.id,
    required this.coupon,
    this.status = AppConstants.couponStatusUnused,
    this.obtainedAt,
    this.validUntil,
    this.applicable,
    this.inapplicableReason,
  });

  final int id;
  final Coupon coupon;
  final String status; // unused, used, expired
  final DateTime? obtainedAt;
  final DateTime? validUntil;
  /// 是否适用于指定任务（仅当请求传了 task_id 时后端才返回此字段）
  final bool? applicable;
  /// 不适用原因（仅当 applicable == false 时有值）
  final String? inapplicableReason;

  /// 是否可用
  bool get isUsable => status == AppConstants.couponStatusUnused && !isExpired;

  /// 是否已过期
  bool get isExpired =>
      status == AppConstants.couponStatusExpired ||
      (validUntil != null && validUntil!.isBefore(DateTime.now()));

  /// 是否已使用
  bool get isUsed => status == AppConstants.couponStatusUsed;

  /// 状态标识（需要在 View 层通过 l10n 映射为本地化文本）
  String get statusKey {
    switch (status) {
      case AppConstants.couponStatusUnused:
        return 'coupon_status_unused';
      case AppConstants.couponStatusUsed:
        return 'coupon_status_used';
      case AppConstants.couponStatusExpired:
        return 'coupon_status_expired';
      default:
        return status;
    }
  }

  /// 是否适用于指定任务（applicable 为 null 表示未校验，true 表示可用）
  bool get isApplicable => applicable != false;

  factory UserCoupon.fromJson(Map<String, dynamic> json) {
    return UserCoupon(
      id: json['id'] as int,
      coupon: Coupon.fromJson(json['coupon'] as Map<String, dynamic>),
      status: json['status'] as String? ?? AppConstants.couponStatusUnused,
      obtainedAt: json['obtained_at'] != null
          ? DateTime.tryParse(json['obtained_at'])
          : null,
      validUntil: json['valid_until'] != null
          ? DateTime.tryParse(json['valid_until'])
          : null,
      applicable: json['applicable'] as bool?,
      inapplicableReason: json['inapplicable_reason'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, coupon, status, applicable];
}
