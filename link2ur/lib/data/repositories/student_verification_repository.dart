import '../models/student_verification.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

/// 学生认证仓库
/// 参考iOS APIService+Endpoints.swift 学生认证相关
class StudentVerificationRepository {
  StudentVerificationRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;

  /// 获取学生认证状态
  Future<StudentVerification> getVerificationStatus() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.studentVerificationStatus,
    );

    if (!response.isSuccess || response.data == null) {
      throw StudentVerificationException(
          response.message ?? '获取认证状态失败');
    }

    return StudentVerification.fromJson(response.data!);
  }

  /// 提交学生认证
  Future<void> submitVerification(
      SubmitStudentVerificationRequest request) async {
    final response = await _apiService.post(
      ApiEndpoints.submitStudentVerification,
      data: request.toJson(),
    );

    if (!response.isSuccess) {
      throw StudentVerificationException(response.message ?? '提交认证失败');
    }
  }

  /// 验证学生邮箱
  Future<void> verifyEmail({
    required String token,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.verifyStudentEmail,
      data: {'token': token},
    );

    if (!response.isSuccess) {
      throw StudentVerificationException(response.message ?? '邮箱验证失败');
    }
  }

  /// 获取大学列表
  Future<List<University>> getUniversities({
    String? keyword,
  }) async {
    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.universities,
      queryParameters: {
        if (keyword != null) 'keyword': keyword,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw StudentVerificationException(
          response.message ?? '获取大学列表失败');
    }

    return response.data!
        .map((e) => University.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// 学生认证异常
class StudentVerificationException implements Exception {
  StudentVerificationException(this.message);

  final String message;

  @override
  String toString() => 'StudentVerificationException: $message';
}
