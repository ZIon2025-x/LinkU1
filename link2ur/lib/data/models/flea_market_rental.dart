import 'package:equatable/equatable.dart';

/// 租赁申请模型
/// 参考后端 RentalRequestResponse
class FleaMarketRentalRequest extends Equatable {
  final int id;
  final String itemId;
  final String renterId;
  final String? renterName;
  final String? renterAvatar;
  final int rentalDuration;
  final String? desiredTime;
  final String? usageDescription;
  final double? proposedRentalPrice;
  final double? counterRentalPrice;
  final String status;
  final String? createdAt;
  final String? updatedAt;

  const FleaMarketRentalRequest({
    required this.id,
    required this.itemId,
    required this.renterId,
    this.renterName,
    this.renterAvatar,
    required this.rentalDuration,
    this.desiredTime,
    this.usageDescription,
    this.proposedRentalPrice,
    this.counterRentalPrice,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory FleaMarketRentalRequest.fromJson(Map<String, dynamic> json) {
    return FleaMarketRentalRequest(
      id: json['id'] as int? ?? 0,
      itemId: json['item_id']?.toString() ?? '',
      renterId: json['renter_id']?.toString() ?? '',
      renterName: json['renter_name'] as String?,
      renterAvatar: json['renter_avatar'] as String?,
      rentalDuration: json['rental_duration'] as int? ?? 0,
      desiredTime: json['desired_time'] as String?,
      usageDescription: json['usage_description'] as String?,
      proposedRentalPrice: (json['proposed_rental_price'] as num?)?.toDouble(),
      counterRentalPrice: (json['counter_rental_price'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, itemId, renterId, status, updatedAt];
}

/// 租赁记录模型
/// 参考后端 RentalResponse
class FleaMarketRental extends Equatable {
  final int id;
  final String itemId;
  final String renterId;
  final String? renterName;
  final String? renterAvatar;
  final int rentalDuration;
  final String rentalUnit;
  final double totalRent;
  final double depositAmount;
  final double totalPaid;
  final String currency;
  final String startDate;
  final String endDate;
  final String status;
  final String depositStatus;
  final String? returnedAt;
  final String? createdAt;
  // 后端填充的物品信息
  final String? itemTitle;
  final String? itemImage;

  const FleaMarketRental({
    required this.id,
    required this.itemId,
    required this.renterId,
    this.renterName,
    this.renterAvatar,
    required this.rentalDuration,
    required this.rentalUnit,
    required this.totalRent,
    required this.depositAmount,
    required this.totalPaid,
    required this.currency,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.depositStatus,
    this.returnedAt,
    this.createdAt,
    this.itemTitle,
    this.itemImage,
  });

  factory FleaMarketRental.fromJson(Map<String, dynamic> json) {
    return FleaMarketRental(
      id: json['id'] as int? ?? 0,
      itemId: json['item_id']?.toString() ?? '',
      renterId: json['renter_id']?.toString() ?? '',
      renterName: json['renter_name'] as String?,
      renterAvatar: json['renter_avatar'] as String?,
      rentalDuration: json['rental_duration'] as int? ?? 0,
      rentalUnit: json['rental_unit'] as String? ?? 'day',
      totalRent: (json['total_rent'] as num?)?.toDouble() ?? 0,
      depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0,
      totalPaid: (json['total_paid'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'GBP',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      depositStatus: json['deposit_status'] as String? ?? 'held',
      returnedAt: json['returned_at'] as String?,
      createdAt: json['created_at'] as String?,
      itemTitle: json['item_title'] as String?,
      itemImage: json['item_image'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, itemId, renterId, status, depositStatus, returnedAt];
}
