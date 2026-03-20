import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

class UserProfileException implements Exception {
  final String message;
  const UserProfileException(this.message);
  @override
  String toString() => message;
}

class UserProfileRepository {
  final ApiService _apiService;

  UserProfileRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  Future<List<UserCapability>> getCapabilities() async {
    final response = await _apiService.get(ApiEndpoints.profileCapabilities);
    if (!response.isSuccess) {
      throw UserProfileException(response.message ?? 'Failed to load capabilities');
    }
    return (response.data as List)
        .map((e) => UserCapability.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateCapabilities(List<Map<String, dynamic>> capabilities) async {
    final response = await _apiService.put(
      ApiEndpoints.profileCapabilities,
      data: capabilities,
    );
    if (!response.isSuccess) {
      throw UserProfileException(response.message ?? 'Failed to update capabilities');
    }
  }

  Future<void> deleteCapability(int id) async {
    final response = await _apiService.delete(
      '${ApiEndpoints.profileCapabilities}/$id',
    );
    if (!response.isSuccess) {
      throw UserProfileException(response.message ?? 'Failed to delete capability');
    }
  }

  Future<UserProfilePreference> getPreferences() async {
    final response = await _apiService.get(ApiEndpoints.profilePreferences);
    if (!response.isSuccess) {
      throw UserProfileException(response.message ?? 'Failed to load preferences');
    }
    return UserProfilePreference.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> updatePreferences(Map<String, dynamic> data) async {
    final response = await _apiService.put(
      ApiEndpoints.profilePreferences,
      data: data,
    );
    if (!response.isSuccess) {
      throw UserProfileException(response.message ?? 'Failed to update preferences');
    }
  }

  Future<UserReliability> getReliability() async {
    final response = await _apiService.get(ApiEndpoints.profileReliability);
    if (!response.isSuccess) {
      throw UserProfileException(response.message ?? 'Failed to load reliability');
    }
    return UserReliability.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserDemand> getDemand() async {
    final response = await _apiService.get(ApiEndpoints.profileDemand);
    if (!response.isSuccess) {
      throw UserProfileException(response.message ?? 'Failed to load demand');
    }
    return UserDemand.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserProfileSummary> getSummary() async {
    final response = await _apiService.get(ApiEndpoints.profileSummary);
    if (!response.isSuccess) {
      throw UserProfileException(response.message ?? 'Failed to load profile summary');
    }
    return UserProfileSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> submitOnboarding({
    required List<Map<String, dynamic>> capabilities,
    String? mode,
    List<int> preferredCategories = const [],
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.profileOnboarding,
      data: {
        'capabilities': capabilities,
        if (mode != null) 'mode': mode,
        'preferred_categories': preferredCategories,
      },
    );
    if (!response.isSuccess) {
      throw UserProfileException(response.message ?? 'Failed to submit onboarding');
    }
  }
}
