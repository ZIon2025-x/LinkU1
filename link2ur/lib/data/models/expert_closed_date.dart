import 'package:equatable/equatable.dart';

/// 达人团队休息日（临时关门）
///
/// 对齐后端 `ExpertClosedDateOut` (schemas.py) 和 `UpcomingClosedDate` (schemas_expert.py)。
/// `closedDate` 用字符串 "YYYY-MM-DD" 以匹配后端响应；`id` 仅在 owner/admin 管理
/// 端点返回，公开详情端点中可能缺失。
class ExpertClosedDate extends Equatable {
  const ExpertClosedDate({
    this.id,
    required this.closedDate,
    this.reason,
  });

  /// 后端记录主键；公开详情响应中可能为 null。
  final int? id;

  /// "YYYY-MM-DD" 形式，匹配后端返回。
  final String closedDate;

  /// 关门原因（可选）。
  final String? reason;

  factory ExpertClosedDate.fromJson(Map<String, dynamic> json) {
    return ExpertClosedDate(
      id: json['id'] is int
          ? json['id'] as int
          : (json['id'] == null ? null : int.tryParse(json['id'].toString())),
      closedDate: json['closed_date']?.toString() ?? '',
      reason: json['reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'closed_date': closedDate,
        if (reason != null) 'reason': reason,
      };

  /// 解析为 DateTime（仅取日期部分）。解析失败返回 null。
  DateTime? get date => DateTime.tryParse(closedDate);

  @override
  List<Object?> get props => [id, closedDate, reason];
}
