import 'package:equatable/equatable.dart';

/// 任务达人模型
/// 参考后端 TaskExpertOut
class TaskExpert extends Equatable {
  const TaskExpert({
    required this.id,
    this.expertName,
    this.bio,
    this.avatar,
    this.status = 'active',
    this.rating = 0.0,
    this.totalServices = 0,
    this.completedTasks = 0,
    this.createdAt,
  });

  final String id;
  final String? expertName;
  final String? bio;
  final String? avatar;
  final String status;
  final double rating;
  final int totalServices;
  final int completedTasks;
  final DateTime? createdAt;

  /// 显示名称
  String get displayName => expertName ?? '达人$id';

  /// 评分显示
  String get ratingDisplay => rating > 0 ? rating.toStringAsFixed(1) : '-';

  factory TaskExpert.fromJson(Map<String, dynamic> json) {
    return TaskExpert(
      id: json['id']?.toString() ?? '',
      expertName: json['expert_name'] as String?,
      bio: json['bio'] as String?,
      avatar: json['avatar'] as String?,
      status: json['status'] as String? ?? 'active',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalServices: json['total_services'] as int? ?? 0,
      completedTasks: json['completed_tasks'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expert_name': expertName,
      'bio': bio,
      'avatar': avatar,
      'status': status,
      'rating': rating,
      'total_services': totalServices,
      'completed_tasks': completedTasks,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, expertName, rating, status];
}

/// 任务达人服务模型
/// 参考后端 TaskExpertServiceOut
class TaskExpertService extends Equatable {
  const TaskExpertService({
    required this.id,
    required this.expertId,
    required this.serviceName,
    this.description = '',
    this.images,
    required this.basePrice,
    this.currency = 'GBP',
    this.status = 'active',
    this.displayOrder = 0,
    this.viewCount = 0,
    this.applicationCount = 0,
    this.createdAt,
    this.hasTimeSlots = false,
    this.timeSlotDurationMinutes,
    this.timeSlotStartTime,
    this.timeSlotEndTime,
    this.participantsPerSlot,
    this.userApplicationId,
    this.userApplicationStatus,
    this.userTaskId,
    this.userTaskStatus,
    this.userTaskIsPaid,
    this.userApplicationHasNegotiation,
  });

  final int id;
  final String expertId;
  final String serviceName;
  final String description;
  final List<String>? images;
  final double basePrice;
  final String currency;
  final String status;
  final int displayOrder;
  final int viewCount;
  final int applicationCount;
  final DateTime? createdAt;

  // 时间段相关
  final bool hasTimeSlots;
  final int? timeSlotDurationMinutes;
  final String? timeSlotStartTime;
  final String? timeSlotEndTime;
  final int? participantsPerSlot;

  // 用户申请状态
  final int? userApplicationId;
  final String? userApplicationStatus;
  final int? userTaskId;
  final String? userTaskStatus;
  final bool? userTaskIsPaid;
  final bool? userApplicationHasNegotiation;

  /// 价格显示
  String get priceDisplay => '£${basePrice.toStringAsFixed(2)}';

  /// 第一张图片
  String? get firstImage =>
      images != null && images!.isNotEmpty ? images!.first : null;

  /// 是否已申请
  bool get hasApplied => userApplicationId != null;

  factory TaskExpertService.fromJson(Map<String, dynamic> json) {
    return TaskExpertService(
      id: json['id'] as int,
      expertId: json['expert_id']?.toString() ?? '',
      serviceName: json['service_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      images: (json['images'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'GBP',
      status: json['status'] as String? ?? 'active',
      displayOrder: json['display_order'] as int? ?? 0,
      viewCount: json['view_count'] as int? ?? 0,
      applicationCount: json['application_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      hasTimeSlots: json['has_time_slots'] as bool? ?? false,
      timeSlotDurationMinutes: json['time_slot_duration_minutes'] as int?,
      timeSlotStartTime: json['time_slot_start_time'] as String?,
      timeSlotEndTime: json['time_slot_end_time'] as String?,
      participantsPerSlot: json['participants_per_slot'] as int?,
      userApplicationId: json['user_application_id'] as int?,
      userApplicationStatus: json['user_application_status'] as String?,
      userTaskId: json['user_task_id'] as int?,
      userTaskStatus: json['user_task_status'] as String?,
      userTaskIsPaid: json['user_task_is_paid'] as bool?,
      userApplicationHasNegotiation:
          json['user_application_has_negotiation'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expert_id': expertId,
      'service_name': serviceName,
      'description': description,
      'images': images,
      'base_price': basePrice,
      'currency': currency,
      'status': status,
      'display_order': displayOrder,
      'view_count': viewCount,
      'application_count': applicationCount,
      'has_time_slots': hasTimeSlots,
      'time_slot_duration_minutes': timeSlotDurationMinutes,
      'time_slot_start_time': timeSlotStartTime,
      'time_slot_end_time': timeSlotEndTime,
      'participants_per_slot': participantsPerSlot,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, expertId, serviceName, basePrice, status];
}

/// 任务达人列表响应
class TaskExpertListResponse {
  const TaskExpertListResponse({
    required this.experts,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<TaskExpert> experts;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => experts.length >= pageSize;

  factory TaskExpertListResponse.fromJson(Map<String, dynamic> json) {
    return TaskExpertListResponse(
      experts: (json['items'] as List<dynamic>?)
              ?.map((e) => TaskExpert.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
    );
  }
}
