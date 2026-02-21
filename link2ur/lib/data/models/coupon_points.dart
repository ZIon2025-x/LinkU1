import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';

/// 积分账户模型
/// 参考后端 PointsAccountOut
class PointsAccount extends Equatable {
  const PointsAccount({
    this.balance = 0,
    this.balanceDisplay = '0',
    this.currency = 'GBP',
    this.totalEarned = 0,
    this.totalSpent = 0,
    this.usageRestrictions,
  });

  final int balance;
  final String balanceDisplay;
  final String currency;
  final int totalEarned;
  final int totalSpent;
  final Map<String, dynamic>? usageRestrictions;

  factory PointsAccount.fromJson(Map<String, dynamic> json) {
    return PointsAccount(
      balance: json['balance'] as int? ?? 0,
      balanceDisplay: json['balance_display'] as String? ?? '0',
      currency: json['currency'] as String? ?? 'GBP',
      totalEarned: json['total_earned'] as int? ?? 0,
      totalSpent: json['total_spent'] as int? ?? 0,
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
      'usage_restrictions': usageRestrictions,
    };
  }

  @override
  List<Object?> get props => [balance, totalEarned, totalSpent];

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
  bool get isExpense => type == 'spend' || type == 'coupon_redeem';

  /// 类型显示文本
  String get typeText {
    switch (type) {
      case 'earn':
        return '获得积分';
      case 'spend':
        return '使用积分';
      case 'refund':
        return '退回积分';
      case 'expire':
        return '积分过期';
      case 'coupon_redeem':
        return '优惠券兑换';
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
          ? DateTime.parse(json['created_at'])
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

  /// 是否已过期
  bool get isExpired =>
      validUntil != null && validUntil!.isBefore(DateTime.now());

  /// 折扣类型显示
  String get typeText {
    switch (type) {
      case 'fixed_amount':
        return '满减券';
      case 'percentage':
        return '折扣券';
      default:
        return type;
    }
  }

  /// 格式化后的折扣显示（根据类型区分：percentage 为 8%，fixed_amount 为 £8.00）
  /// discountValue: percentage 时为基点(800=8%)，fixed_amount 时为便士(800=£8)
  String get discountDisplayFormatted {
    if (type == 'percentage') {
      return '${discountValue ~/ 100}%';
    } else {
      return '£${(discountValue / 100).toStringAsFixed(2)}';
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
          ? DateTime.parse(json['valid_until'])
          : null,
      usageConditions:
          json['usage_conditions'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [id, code, name, type];
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
  });

  final int id;
  final Coupon coupon;
  final String status; // unused, used, expired
  final DateTime? obtainedAt;
  final DateTime? validUntil;

  /// 是否可用
  bool get isUsable => status == AppConstants.couponStatusUnused && !isExpired;

  /// 是否已过期
  bool get isExpired =>
      status == AppConstants.couponStatusExpired ||
      (validUntil != null && validUntil!.isBefore(DateTime.now()));

  /// 是否已使用
  bool get isUsed => status == AppConstants.couponStatusUsed;

  /// 状态显示
  String get statusText {
    switch (status) {
      case AppConstants.couponStatusUnused:
        return '未使用';
      case AppConstants.couponStatusUsed:
        return '已使用';
      case AppConstants.couponStatusExpired:
        return '已过期';
      default:
        return status;
    }
  }

  factory UserCoupon.fromJson(Map<String, dynamic> json) {
    return UserCoupon(
      id: json['id'] as int,
      coupon: Coupon.fromJson(json['coupon'] as Map<String, dynamic>),
      status: json['status'] as String? ?? AppConstants.couponStatusUnused,
      obtainedAt: json['obtained_at'] != null
          ? DateTime.parse(json['obtained_at'])
          : null,
      validUntil: json['valid_until'] != null
          ? DateTime.parse(json['valid_until'])
          : null,
    );
  }

  @override
  List<Object?> get props => [id, coupon, status];
}
