import 'dart:typed_data';

import 'package:link2ur/core/constants/api_endpoints.dart';
import 'package:link2ur/core/utils/app_exception.dart';
import 'package:link2ur/data/models/expert_team.dart';
import 'package:link2ur/data/services/api_service.dart';

class ExpertTeamRepository {
  final ApiService _apiService;

  ExpertTeamRepository({required ApiService apiService}) : _apiService = apiService;

  // ==================== 团队发现 ====================

  Future<List<ExpertTeam>> getExperts({
    String? keyword,
    String sort = 'created_at',
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'sort': sort,
      'limit': limit,
      'offset': offset,
    };
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;

    final response = await _apiService.get(ApiEndpoints.expertTeams, queryParameters: params);
    final list = response.data as List;
    return list.map((e) => ExpertTeam.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ExpertTeam> getExpertById(String id) async {
    final response = await _apiService.get(ApiEndpoints.expertTeamById(id));
    return ExpertTeam.fromJson(response.data as Map<String, dynamic>);
  }

  // ==================== 我的团队 ====================

  Future<List<ExpertTeam>> getMyTeams() async {
    final response = await _apiService.get(ApiEndpoints.expertTeamMyTeams);
    final list = response.data as List;
    return list.map((e) => ExpertTeam.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ==================== 申请创建团队 ====================

  Future<ExpertTeamApplication> applyToCreateTeam({
    required String expertName,
    String? bio,
    String? avatar,
    String? applicationMessage,
  }) async {
    final response = await _apiService.post(ApiEndpoints.expertTeamApply, data: {
      'expert_name': expertName,
      if (bio != null) 'bio': bio,
      if (avatar != null) 'avatar': avatar,
      if (applicationMessage != null) 'application_message': applicationMessage,
    });
    return ExpertTeamApplication.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ExpertTeamApplication>> getMyApplications() async {
    final response = await _apiService.get(ApiEndpoints.expertTeamMyApplications);
    final list = response.data as List;
    return list.map((e) => ExpertTeamApplication.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ==================== 成员管理 ====================

  Future<List<ExpertMember>> getMembers(String expertId) async {
    final response = await _apiService.get(ApiEndpoints.expertTeamMembers(expertId));
    final list = response.data as List;
    return list.map((e) => ExpertMember.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> inviteMember(String expertId, String inviteeId) async {
    await _apiService.post(ApiEndpoints.expertTeamInvite(expertId), data: {
      'invitee_id': inviteeId,
    });
  }

  Future<void> respondToInvitation(int invitationId, String action) async {
    await _apiService.post(ApiEndpoints.expertTeamRespondInvitation(invitationId), data: {
      'action': action,
    });
  }

  Future<void> changeMemberRole(String expertId, String userId, String role) async {
    await _apiService.put(ApiEndpoints.expertTeamMemberRole(expertId, userId), data: {
      'role': role,
    });
  }

  Future<void> removeMember(String expertId, String userId) async {
    await _apiService.delete(ApiEndpoints.expertTeamRemoveMember(expertId, userId));
  }

  Future<void> transferOwnership(String expertId, String newOwnerId) async {
    await _apiService.post(ApiEndpoints.expertTeamTransfer(expertId), data: {
      'new_owner_id': newOwnerId,
    });
  }

  Future<void> leaveTeam(String expertId) async {
    await _apiService.post(ApiEndpoints.expertTeamLeave(expertId));
  }

  // ==================== 加入申请 ====================

  Future<void> requestToJoin(String expertId, {String? message}) async {
    await _apiService.post(ApiEndpoints.expertTeamJoin(expertId), data: {
      if (message != null) 'message': message,
    });
  }

  Future<List<ExpertJoinRequest>> getJoinRequests(String expertId, {String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;

    final response = await _apiService.get(
      ApiEndpoints.expertTeamJoinRequests(expertId),
      queryParameters: params,
    );
    final list = response.data as List;
    return list.map((e) => ExpertJoinRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> reviewJoinRequest(String expertId, int requestId, String action) async {
    await _apiService.put(
      ApiEndpoints.expertTeamReviewJoinRequest(expertId, requestId),
      data: {'action': action},
    );
  }

  // ==================== 关注 ====================

  Future<bool> toggleFollow(String expertId) async {
    final response = await _apiService.post(ApiEndpoints.expertTeamFollow(expertId));
    return response.data['following'] as bool;
  }

  // ==================== 资料修改 ====================

  /// 上传团队头像图片，返回图片 URL
  Future<String> uploadAvatar(Uint8List bytes, String filename) async {
    final response = await _apiService.uploadFileBytes<Map<String, dynamic>>(
      '${ApiEndpoints.uploadPublicImage}?category=expert_avatar',
      bytes: bytes,
      filename: filename,
      fieldName: 'image',
    );
    if (!response.isSuccess || response.data == null) {
      throw AppException(response.errorCode ?? response.message ?? 'upload_avatar_failed');
    }
    return response.data!['url'] as String? ?? '';
  }

  /// 上传团队封面图（16:9，推荐卡片用），返回图片 URL
  Future<String> uploadCover(Uint8List bytes, String filename) async {
    final response = await _apiService.uploadFileBytes<Map<String, dynamic>>(
      '${ApiEndpoints.uploadPublicImage}?category=expert_cover',
      bytes: bytes,
      filename: filename,
      fieldName: 'image',
    );
    if (!response.isSuccess || response.data == null) {
      throw AppException(response.errorCode ?? response.message ?? 'upload_cover_failed');
    }
    return response.data!['url'] as String? ?? '';
  }

  /// 直接更新团队资料（Owner only，即时生效，无需审核）
  Future<void> updateProfile(String expertId, {
    String? newName,
    String? newBio,
    String? newAvatar,
    String? newCoverImage,
  }) async {
    await _apiService.put(ApiEndpoints.expertTeamProfileUpdate(expertId), data: {
      if (newName != null) 'new_name': newName,
      if (newBio != null) 'new_bio': newBio,
      if (newAvatar != null) 'new_avatar': newAvatar,
      if (newCoverImage != null) 'new_cover_image': newCoverImage,
    });
  }

  // ==================== 达人服务管理 ====================

  Future<List<Map<String, dynamic>>> getExpertServices(String expertId, {
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (status != null) params['status'] = status;

    final response = await _apiService.get(
      ApiEndpoints.expertTeamServices(expertId),
      queryParameters: params,
    );
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createService(String expertId, Map<String, dynamic> data) async {
    final response = await _apiService.post(
      ApiEndpoints.expertTeamServices(expertId),
      data: data,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getServiceDetail(String expertId, int serviceId) async {
    final response = await _apiService.get(
      ApiEndpoints.expertTeamServiceById(expertId, serviceId),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> updateService(String expertId, int serviceId, Map<String, dynamic> data) async {
    await _apiService.put(
      ApiEndpoints.expertTeamServiceById(expertId, serviceId),
      data: data,
    );
  }

  Future<void> deleteService(String expertId, int serviceId) async {
    await _apiService.delete(
      ApiEndpoints.expertTeamServiceById(expertId, serviceId),
    );
  }

  // ==================== 精选达人 ====================

  Future<List<ExpertTeam>> getFeaturedExperts({int limit = 20, int offset = 0}) async {
    final response = await _apiService.get(
      ApiEndpoints.expertTeamFeatured,
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final list = response.data as List;
    return list.map((e) => ExpertTeam.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ==================== 关注列表 ====================

  Future<List<ExpertTeam>> getMyFollowingExperts({int limit = 20, int offset = 0}) async {
    final response = await _apiService.get(
      ApiEndpoints.expertTeamMyFollowing,
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final list = response.data as List;
    return list.map((e) => ExpertTeam.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ==================== 达人注销 ====================

  Future<void> dissolveTeam(String expertId) async {
    await _apiService.post(ApiEndpoints.expertTeamDissolve(expertId));
  }

  // ==================== 营业时间 ====================

  Future<void> updateBusinessHours(String expertId, Map<String, dynamic> hours) async {
    await _apiService.put(
      ApiEndpoints.expertTeamBusinessHours(expertId),
      data: hours,
    );
  }

  // ==================== 开关申请 ====================

  Future<bool> toggleAllowApplications(String expertId, bool allow) async {
    final response = await _apiService.put(
      ApiEndpoints.expertTeamAllowApplications(expertId),
      data: {'allow_applications': allow},
    );
    return response.data['allow_applications'] as bool;
  }

  // ==================== 我的邀请 ====================

  Future<List<ExpertInvitation>> getMyInvitations() async {
    final response = await _apiService.get(ApiEndpoints.expertTeamMyInvitations);
    final list = response.data as List;
    return list.map((e) => ExpertInvitation.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ==================== 拼单 ====================

  Future<Map<String, dynamic>> joinGroupBuy(int activityId) async {
    final response = await _apiService.post(ApiEndpoints.groupBuyJoin(activityId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelGroupBuy(int activityId) async {
    final response = await _apiService.post(ApiEndpoints.groupBuyCancel(activityId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getGroupBuyStatus(int activityId) async {
    final response = await _apiService.get(ApiEndpoints.groupBuyStatus(activityId));
    return response.data as Map<String, dynamic>;
  }

  // ==================== 套餐 ====================

  Future<List<Map<String, dynamic>>> getMyPackages() async {
    final response = await _apiService.get<List<dynamic>>(ApiEndpoints.myPackages);
    if (!response.isSuccess || response.data == null) {
      throw ExpertTeamException(
        response.errorCode ?? response.message ?? 'fetch_my_packages_failed',
        code: response.errorCode,
      );
    }
    return response.data!
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> usePackageSession(String expertId, int packageId, {int? subServiceId, String? note}) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.redeemPackage(expertId),
      data: {
        'package_id': packageId,
        if (subServiceId != null) 'sub_service_id': subServiceId,
        if (note != null) 'note': note,
      },
    );
    if (!response.isSuccess || response.data == null) {
      throw ExpertTeamException(
        response.errorCode ?? response.message ?? 'use_package_failed',
        code: response.errorCode,
      );
    }
    return response.data!;
  }

  // ==================== 优惠券 ====================

  Future<List<Map<String, dynamic>>> getExpertCoupons(String expertId) async {
    final response = await _apiService.get(ApiEndpoints.expertTeamCoupons(expertId));
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createExpertCoupon(String expertId, Map<String, dynamic> data) async {
    final response = await _apiService.post(
      ApiEndpoints.expertTeamCoupons(expertId),
      data: data,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> deactivateExpertCoupon(String expertId, int couponId) async {
    await _apiService.delete(ApiEndpoints.expertTeamCouponById(expertId, couponId));
  }

  // ==================== 评价回复 ====================

  Future<void> replyToReview(int reviewId, String content) async {
    await _apiService.post(ApiEndpoints.reviewReply(reviewId), data: {'content': content});
  }

  // ==================== 聊天参与者 ====================

  Future<void> inviteToTaskChat(int taskId, String userId) async {
    await _apiService.post(ApiEndpoints.chatInviteToTask(taskId), data: {'user_id': userId});
  }

  Future<Map<String, dynamic>> getTaskChatParticipants(int taskId) async {
    final response = await _apiService.get(ApiEndpoints.chatTaskParticipants(taskId));
    return response.data as Map<String, dynamic>;
  }

  // ==================== 位置 ====================

  Future<void> updateExpertLocation(
    String expertId, {
    required String? location,
    required double? latitude,
    required double? longitude,
    required int? serviceRadiusKm,
  }) async {
    await _apiService.put(
      '${ApiEndpoints.expertTeams}/$expertId/location',
      data: {
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'service_radius_km': serviceRadiusKm,
      },
    );
  }

  // ==================== 板块编辑 ====================

  Future<Map<String, dynamic>> getExpertBoard(String expertId) async {
    final resp = await _apiService.get('/api/experts/$expertId/board');
    return resp.data as Map<String, dynamic>;
  }

  Future<void> updateExpertBoard(String expertId, Map<String, dynamic> data) async {
    await _apiService.put('/api/experts/$expertId/board', data: data);
  }

  // ==================== 优惠券编辑 ====================

  Future<void> updateExpertCoupon(String expertId, int couponId, Map<String, dynamic> data) async {
    await _apiService.put(ApiEndpoints.expertTeamCouponById(expertId, couponId), data: data);
  }

  // ==================== Stripe Connect ====================

  Future<Map<String, dynamic>> createStripeConnect(String expertId, {String country = 'GB'}) async {
    final response = await _apiService.post(
      '${ApiEndpoints.expertTeamStripeConnect(expertId)}?country=$country',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStripeConnectStatus(String expertId) async {
    final response = await _apiService.get(ApiEndpoints.expertTeamStripeStatus(expertId));
    return response.data as Map<String, dynamic>;
  }

  // ==================== 咨询 ====================

  /// 发起团队咨询（不绑定具体服务）
  Future<Map<String, dynamic>> createTeamConsultation(String expertId) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.consultExpert(expertId),
      data: {},
    );
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorCode ?? response.message ?? 'consultation_failed');
    }
    return response.data!;
  }

  // ==================== 活动发布 ====================

  /// 获取团队活动列表。
  Future<List<Map<String, dynamic>>> getTeamActivities(
    String expertId,
  ) async {
    final response = await _apiService.get(
      ApiEndpoints.expertTeamActivities(expertId),
    );
    final data = response.data;
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    final items = data['items'] ?? data['activities'] ?? [];
    return (items as List).cast<Map<String, dynamic>>();
  }

  /// 发布团队活动。
  /// [data] 包含 TeamActivityCreate 字段（title, description, location,
  /// task_type, deadline, max_participants, expert_service_id 等）。
  /// 可选地包含 latitude, longitude, service_radius_km。
  Future<Map<String, dynamic>> createTeamActivity(
    String expertId,
    Map<String, dynamic> data,
  ) async {
    final response = await _apiService.post(
      ApiEndpoints.expertTeamActivities(expertId),
      data: data,
    );
    return response.data as Map<String, dynamic>;
  }

  /// 达人手动开奖。
  Future<Map<String, dynamic>> drawTeamActivity(
    String expertId,
    int activityId,
  ) async {
    final response = await _apiService.post(
      ApiEndpoints.expertTeamActivityDraw(expertId, activityId),
      data: {},
    );
    return response.data as Map<String, dynamic>;
  }
}

class ExpertTeamException extends AppException {
  const ExpertTeamException(super.message, {super.code});
}
