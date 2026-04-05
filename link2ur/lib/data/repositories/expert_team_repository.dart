import 'package:link2ur/core/constants/api_endpoints.dart';
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

  Future<void> requestProfileUpdate(String expertId, {
    String? newName,
    String? newBio,
    String? newAvatar,
  }) async {
    await _apiService.post(ApiEndpoints.expertTeamProfileUpdateRequest(expertId), data: {
      if (newName != null) 'new_name': newName,
      if (newBio != null) 'new_bio': newBio,
      if (newAvatar != null) 'new_avatar': newAvatar,
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
}
