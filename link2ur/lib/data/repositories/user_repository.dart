import '../models/user.dart';
import '../models/payment.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/app_exception.dart';

/// 用户仓库
/// 与iOS APIService+Users + 后端路由对齐
class UserRepository {
  UserRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;

  /// 获取当前用户资料
  Future<User> getProfile() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.userProfile,
    );

    if (!response.isSuccess || response.data == null) {
      throw UserException(response.message ?? '获取用户资料失败');
    }

    final user = User.fromJson(response.data!);
    // 缓存用户信息
    await StorageService.instance.saveUserInfo(user.toJson());
    return user;
  }

  /// 上传头像
  Future<User> uploadAvatar(String filePath) async {
    final response = await _apiService.uploadFile<Map<String, dynamic>>(
      ApiEndpoints.uploadAvatar,
      filePath: filePath,
      fieldName: 'avatar',
    );

    if (!response.isSuccess || response.data == null) {
      throw UserException(response.message ?? '上传头像失败');
    }

    final user = User.fromJson(response.data!);
    await StorageService.instance.saveUserInfo(user.toJson());
    return user;
  }

  /// 获取其他用户资料
  Future<User> getUserProfile(String userId) async {
    return getUserPublicProfile(userId);
  }

  /// 获取其他用户公开资料
  Future<User> getUserPublicProfile(String userId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.userById(userId),
    );

    if (!response.isSuccess || response.data == null) {
      throw UserException(response.message ?? '获取用户资料失败');
    }

    return User.fromJson(response.data!);
  }

  /// 更新头像（预设头像路径）
  Future<User> updateAvatar(String avatarPath) async {
    return updateProfile(avatar: avatarPath);
  }

  /// 更新用户资料（含头像路径）
  Future<User> updateProfile({
    String? name,
    String? bio,
    String? residenceCity,
    String? languagePreference,
    String? avatar,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (bio != null) data['bio'] = bio;
    if (residenceCity != null) data['residence_city'] = residenceCity;
    if (languagePreference != null) {
      data['language_preference'] = languagePreference;
    }
    if (avatar != null) data['avatar'] = avatar;

    final response = await _apiService.patch<Map<String, dynamic>>(
      ApiEndpoints.updateProfile,
      data: data,
    );

    if (!response.isSuccess || response.data == null) {
      throw UserException(response.message ?? '更新用户资料失败');
    }

    final user = User.fromJson(response.data!);
    await StorageService.instance.saveUserInfo(user.toJson());
    return user;
  }

  /// 发送邮箱更新验证码
  Future<void> sendEmailUpdateCode(String email) async {
    final response = await _apiService.post(
      ApiEndpoints.sendEmailUpdateCode,
      data: {'email': email},
    );

    if (!response.isSuccess) {
      throw UserException(response.message ?? '发送验证码失败');
    }
  }

  /// 发送手机更新验证码
  Future<void> sendPhoneUpdateCode(String phone) async {
    final response = await _apiService.post(
      ApiEndpoints.sendPhoneUpdateCode,
      data: {'phone': phone},
    );

    if (!response.isSuccess) {
      throw UserException(response.message ?? '发送验证码失败');
    }
  }

  /// 删除账号
  Future<void> deleteAccount() async {
    final response = await _apiService.delete(
      ApiEndpoints.deleteAccount,
    );

    if (!response.isSuccess) {
      throw UserException(response.message ?? '删除账号失败');
    }
  }

  /// 获取用户偏好设置
  Future<Map<String, dynamic>> getUserPreferences() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.userPreferences,
    );

    if (!response.isSuccess || response.data == null) {
      throw UserException(response.message ?? '获取偏好设置失败');
    }

    return response.data!;
  }

  /// 更新用户偏好设置
  Future<void> updateUserPreferences(Map<String, dynamic> preferences) async {
    await updatePreferences(preferences);
  }

  /// 更新用户偏好设置
  Future<void> updatePreferences(Map<String, dynamic> preferences) async {
    final response = await _apiService.put(
      ApiEndpoints.userPreferences,
      data: preferences,
    );

    if (!response.isSuccess) {
      throw UserException(response.message ?? '更新偏好设置失败');
    }
  }

  /// 上传图片（私密）
  Future<String> uploadImage(String filePath) async {
    final response = await _apiService.uploadFile<Map<String, dynamic>>(
      ApiEndpoints.uploadImage,
      filePath: filePath,
      fieldName: 'file',
    );

    if (!response.isSuccess || response.data == null) {
      throw UserException(response.message ?? '上传图片失败');
    }

    return response.data!['url'] as String? ?? '';
  }

  /// 上传公开图片（头像、任务图片等）
  Future<String> uploadPublicImage(String filePath) async {
    final response = await _apiService.uploadFile<Map<String, dynamic>>(
      ApiEndpoints.uploadPublicImage,
      filePath: filePath,
      fieldName: 'file',
    );

    if (!response.isSuccess || response.data == null) {
      throw UserException(response.message ?? '上传图片失败');
    }

    return response.data!['url'] as String? ?? '';
  }

  /// 上传文件
  Future<String> uploadFile(String filePath) async {
    final response = await _apiService.uploadFile<Map<String, dynamic>>(
      ApiEndpoints.uploadFile,
      filePath: filePath,
      fieldName: 'file',
    );

    if (!response.isSuccess || response.data == null) {
      throw UserException(response.message ?? '上传文件失败');
    }

    return response.data!['url'] as String? ?? '';
  }

  // ==================== 钱包相关 ====================

  /// 获取钱包信息（聚合 Stripe Connect 余额）
  Future<WalletInfo> getWalletInfo() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectAccountBalance,
    );

    if (!response.isSuccess || response.data == null) {
      throw UserException(response.message ?? '获取钱包信息失败');
    }

    return WalletInfo.fromJson(response.data!);
  }

  /// 获取交易记录
  Future<List<Transaction>> getTransactions({
    int page = 1,
    int pageSize = 20,
    String? type,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectTransactions,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (type != null) 'type': type,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw UserException(response.message ?? '获取交易记录失败');
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取VIP状态
  Future<Map<String, dynamic>> getVipStatus() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.vipStatus,
    );

    if (!response.isSuccess || response.data == null) {
      throw UserException(response.message ?? '获取VIP状态失败');
    }

    return response.data!;
  }
}

/// 用户异常
class UserException extends AppException {
  const UserException(super.message);
}
