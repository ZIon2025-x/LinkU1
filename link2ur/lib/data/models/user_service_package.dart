import 'package:equatable/equatable.dart';

/// 用户购买的套餐(次卡)模型 — 含生命周期字段和操作权限标志
class UserServicePackage extends Equatable {
  final int id;
  final int serviceId;
  final String? expertId;
  final String? serviceName;
  final String? packageType;
  /// multi 套餐关联的单次服务 ID（buyer 侧只读展示用）
  final int? linkedServiceId;
  /// 关联服务名（后端 join 填充）
  final String? linkedServiceName;
  final String? linkedServiceNameEn;
  final String? linkedServiceNameZh;
  final int totalSessions;
  final int usedSessions;
  final int remainingSessions;
  final String status;
  final String statusDisplay;
  final DateTime? purchasedAt;
  final DateTime? cooldownUntil;
  final bool inCooldown;
  final DateTime? expiresAt;
  final String? paymentIntentId;
  final double? paidAmount;
  final String? currency;
  final Map<String, dynamic>? bundleBreakdown;
  final int? releasedAmountPence;
  final int? refundedAmountPence;
  final int? platformFeePence;
  final DateTime? releasedAt;
  final DateTime? refundedAt;
  final DateTime? lastRedeemedAt;
  final bool canRefundFull;
  final bool canRefundPartial;
  final bool canReview;
  final bool canDispute;

  const UserServicePackage({
    required this.id,
    required this.serviceId,
    this.expertId,
    this.serviceName,
    this.packageType,
    this.linkedServiceId,
    this.linkedServiceName,
    this.linkedServiceNameEn,
    this.linkedServiceNameZh,
    required this.totalSessions,
    required this.usedSessions,
    required this.remainingSessions,
    required this.status,
    required this.statusDisplay,
    this.purchasedAt,
    this.cooldownUntil,
    required this.inCooldown,
    this.expiresAt,
    this.paymentIntentId,
    this.paidAmount,
    this.currency,
    this.bundleBreakdown,
    this.releasedAmountPence,
    this.refundedAmountPence,
    this.platformFeePence,
    this.releasedAt,
    this.refundedAt,
    this.lastRedeemedAt,
    required this.canRefundFull,
    required this.canRefundPartial,
    required this.canReview,
    required this.canDispute,
  });

  factory UserServicePackage.fromJson(Map<String, dynamic> json) {
    return UserServicePackage(
      id: json['id'] as int,
      serviceId: json['service_id'] as int,
      expertId: json['expert_id'] as String?,
      serviceName: json['service_name'] as String?,
      packageType: json['package_type'] as String?,
      linkedServiceId: json['linked_service_id'] as int?,
      linkedServiceName: json['linked_service_name'] as String?,
      linkedServiceNameEn: json['linked_service_name_en'] as String?,
      linkedServiceNameZh: json['linked_service_name_zh'] as String?,
      totalSessions: json['total_sessions'] as int,
      usedSessions: json['used_sessions'] as int,
      remainingSessions: json['remaining_sessions'] as int,
      status: json['status'] as String,
      statusDisplay:
          json['status_display'] as String? ?? 'package_status_unknown',
      purchasedAt: json['purchased_at'] != null
          ? DateTime.parse(json['purchased_at'] as String)
          : null,
      cooldownUntil: json['cooldown_until'] != null
          ? DateTime.parse(json['cooldown_until'] as String)
          : null,
      inCooldown: json['in_cooldown'] as bool? ?? false,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      paymentIntentId: json['payment_intent_id'] as String?,
      paidAmount: (json['paid_amount'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      bundleBreakdown: json['bundle_breakdown'] as Map<String, dynamic>?,
      releasedAmountPence: json['released_amount_pence'] as int?,
      refundedAmountPence: json['refunded_amount_pence'] as int?,
      platformFeePence: json['platform_fee_pence'] as int?,
      releasedAt: json['released_at'] != null
          ? DateTime.parse(json['released_at'] as String)
          : null,
      refundedAt: json['refunded_at'] != null
          ? DateTime.parse(json['refunded_at'] as String)
          : null,
      lastRedeemedAt: json['last_redeemed_at'] != null
          ? DateTime.parse(json['last_redeemed_at'] as String)
          : null,
      canRefundFull: json['can_refund_full'] as bool? ?? false,
      canRefundPartial: json['can_refund_partial'] as bool? ?? false,
      canReview: json['can_review'] as bool? ?? false,
      canDispute: json['can_dispute'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        id,
        status,
        usedSessions,
        remainingSessions,
        inCooldown,
        canRefundFull,
        canRefundPartial,
        canReview,
        canDispute,
        lastRedeemedAt,
      ];
}
