import '../models/student_verification.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/app_exception.dart';

/// 学生认证仓库
/// 与iOS StudentVerificationViewModel + 后端路由对齐
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

    // 后端返回 {"code": 200, "data": {...}}，需要解包 data
    final raw = response.data!;
    final data = raw['data'] as Map<String, dynamic>? ?? raw;
    return StudentVerification.fromJson(data);
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

  /// 验证学生邮箱（输入验证码）
  Future<void> verifyStudentEmail({required String code}) async {
    final response = await _apiService.post(
      ApiEndpoints.verifyStudentEmail,
      data: {'code': code},
    );

    if (!response.isSuccess) {
      throw StudentVerificationException(response.message ?? '验证失败');
    }
  }

  /// 续期学生认证
  Future<void> renewVerification() async {
    final response = await _apiService.post(
      ApiEndpoints.renewStudentVerification,
    );

    if (!response.isSuccess) {
      throw StudentVerificationException(response.message ?? '续期失败');
    }
  }
}

/// 学生认证异常
class StudentVerificationException extends AppException {
  const StudentVerificationException(super.message);
}
