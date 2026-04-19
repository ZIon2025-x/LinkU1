import 'package:equatable/equatable.dart';

/// 跳蚤市场购买申请模型
///
/// 对应后端 `models.FleaMarketPurchaseRequest` + `flea_market_routes.py`
/// 里各咨询/议价端点返回的 JSON。
class FleaMarketPurchaseRequest extends Equatable {
  const FleaMarketPurchaseRequest({
    required this.id,
    required this.itemId,
    required this.buyerId,
    this.buyerName,
    this.buyerAvatar,
    this.proposedPrice,
    this.sellerCounterPrice,
    this.message,
    this.status = 'pending',
    this.finalPrice,
    this.taskId,
    this.consultationTaskId,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int itemId;
  final String buyerId;
  final String? buyerName;
  final String? buyerAvatar;
  final double? proposedPrice;
  final double? sellerCounterPrice;
  final String? message;

  /// 申请状态。可能的值：
  /// `pending` / `seller_negotiating` / `accepted` / `rejected` /
  /// `consulting` / `negotiating` / `price_agreed` / `cancelled`
  final String status;

  final double? finalPrice;

  /// 付款晋升后关联的真实任务 ID。
  ///
  /// - 咨询阶段：指向 `is_consultation_placeholder=true` 的占位 task。
  /// - 晋升后：占位 task 被改为真实任务（`is_consultation_placeholder=false`），
  ///   此字段仍指向同一行。
  ///
  /// 使用 [FleaMarketPurchaseRequestConsultationRoute.consultationMessageTaskId]
  /// 作为统一入口，无需在调用方判断。
  final int? taskId;

  /// 咨询占位 task id。
  ///
  /// **FMPR 特殊性**:flea_market 不新建真任务,而是把占位 task 直接晋升为真任务
  /// (改 `is_consultation_placeholder=false` + `task_source='flea_market'`)。
  /// 付款晋升后本字段和 [taskId] **指向同一行 task**,这是预期行为不是 bug。
  ///
  /// 判断"是否已成单"**不要**用 `consultationTaskId == taskId` 比较——这个比较
  /// 只在 FMPR 晋升后为 true,SA/TA 的任何阶段都是 false,**不是跨类型的成单判断**。
  /// 应该用 `task.isConsultationPlaceholder == false` 或 `purchaseRequest.status` 判断。
  final int? consultationTaskId;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory FleaMarketPurchaseRequest.fromJson(Map<String, dynamic> json) {
    return FleaMarketPurchaseRequest(
      id: (json['id'] as num?)?.toInt() ?? 0,
      itemId: (json['item_id'] as num?)?.toInt() ?? 0,
      buyerId: json['buyer_id']?.toString() ?? '',
      buyerName: json['buyer_name'] as String?,
      buyerAvatar: json['buyer_avatar'] as String?,
      proposedPrice: _parseDoubleOrNull(json['proposed_price']),
      sellerCounterPrice: _parseDoubleOrNull(json['seller_counter_price']),
      message: json['message'] as String?,
      status: json['status'] as String? ?? 'pending',
      finalPrice: _parseDoubleOrNull(json['final_price']),
      taskId: _parseIntOrNull(json['task_id']),
      consultationTaskId: _parseIntOrNull(json['consultation_task_id']),
      createdAt: _parseDateOrNull(json['created_at']),
      updatedAt: _parseDateOrNull(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'item_id': itemId,
        'buyer_id': buyerId,
        'buyer_name': buyerName,
        'buyer_avatar': buyerAvatar,
        'proposed_price': proposedPrice,
        'seller_counter_price': sellerCounterPrice,
        'message': message,
        'status': status,
        'final_price': finalPrice,
        'task_id': taskId,
        'consultation_task_id': consultationTaskId,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  FleaMarketPurchaseRequest copyWith({
    int? id,
    int? itemId,
    String? buyerId,
    String? buyerName,
    String? buyerAvatar,
    double? proposedPrice,
    double? sellerCounterPrice,
    String? message,
    String? status,
    double? finalPrice,
    int? taskId,
    int? consultationTaskId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FleaMarketPurchaseRequest(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      buyerId: buyerId ?? this.buyerId,
      buyerName: buyerName ?? this.buyerName,
      buyerAvatar: buyerAvatar ?? this.buyerAvatar,
      proposedPrice: proposedPrice ?? this.proposedPrice,
      sellerCounterPrice: sellerCounterPrice ?? this.sellerCounterPrice,
      message: message ?? this.message,
      status: status ?? this.status,
      finalPrice: finalPrice ?? this.finalPrice,
      taskId: taskId ?? this.taskId,
      consultationTaskId: consultationTaskId ?? this.consultationTaskId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        itemId,
        buyerId,
        buyerName,
        buyerAvatar,
        proposedPrice,
        sellerCounterPrice,
        message,
        status,
        finalPrice,
        taskId,
        consultationTaskId,
        createdAt,
        updatedAt,
      ];
}

int? _parseIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _parseDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

DateTime? _parseDateOrNull(dynamic v) {
  if (v == null) return null;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

extension FleaMarketPurchaseRequestConsultationRoute
    on FleaMarketPurchaseRequest {
  /// 咨询消息路由 id。C.3 规则。
  int? get consultationMessageTaskId => consultationTaskId ?? taskId;
}
