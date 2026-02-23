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

  /// 提交学生认证（email 作为 query param）
  Future<void> submitVerification({required String email}) async {
    final response = await _apiService.post(
      ApiEndpoints.submitStudentVerification,
      queryParameters: {'email': email},
    );

    if (!response.isSuccess) {
      throw StudentVerificationException(response.message ?? '提交认证失败');
    }
  }

  /// 验证学生邮箱（GET /verify/{token}）
  Future<void> verifyStudentEmail({required String token}) async {
    final response = await _apiService.get(
      ApiEndpoints.verifyStudentEmail(token),
    );

    if (!response.isSuccess) {
      throw StudentVerificationException(response.message ?? '验证失败');
    }
  }

  /// 续期学生认证（email 作为 query param）
  Future<void> renewVerification({required String email}) async {
    final response = await _apiService.post(
      ApiEndpoints.renewStudentVerification,
      queryParameters: {'email': email},
    );

    if (!response.isSuccess) {
      throw StudentVerificationException(response.message ?? '续期失败');
    }
  }
  /// 更换验证邮箱
  Future<void> changeVerificationEmail({required String newEmail}) async {
    final response = await _apiService.post(
      ApiEndpoints.changeVerificationEmail,
      data: {'email': newEmail},
    );
    if (!response.isSuccess) {
      throw StudentVerificationException(response.message ?? '更换验证邮箱失败');
    }
  }

  /// 获取大学列表
  Future<List<Map<String, dynamic>>> listUniversities(
      {String? search}) async {
    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.listUniversities,
      queryParameters: {if (search != null) 'search': search},
    );
    if (!response.isSuccess || response.data == null) {
      throw StudentVerificationException(response.message ?? '获取大学列表失败');
    }
    return response.data!.cast<Map<String, dynamic>>();
  }
}

/// 学生认证异常
class StudentVerificationException extends AppException {
  const StudentVerificationException(super.message);
}
