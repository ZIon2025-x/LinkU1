import 'package:dio/dio.dart';

import '../models/user.dart';
import '../models/payment.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/cache_manager.dart';
import '../../core/utils/app_exception.dart';

/// 用户仓库
/// 与iOS APIService+Users + 后端路由对齐
class UserRepository {
  UserRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;
  final CacheManager _cache = CacheManager.shared;

  /// 获取当前用户资料（带内存+磁盘缓存，30分钟TTL）
  Future<User> getProfile({CancelToken? cancelToken, bool forceRefresh = false}) async {
    const cacheKey = 'user_profile_me';

    // 非强制刷新时先查缓存
    if (!forceRefresh) {
      final cached = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        return User.fromJson(cached);
      }
    }

    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.userProfile,
      cancelToken: cancelToken,
    );

    if (!response.isSuccess || response.data == null) {
      throw UserException(response.message ?? '获取用户资料失败');
    }

    final user = User.fromJson(response.data!);
    // 缓存用户信息（CacheManager 双层缓存 + StorageService 持久化）
    await _cache.set(cacheKey, response.data!, ttl: CacheManager.personalTTL);
    await StorageService.instance.saveUserInfo(user.toJson());
    return user;
  }

  /// 上传头像：先上传图片获取 URL，再 PATCH 更新
  Future<User> uploadAvatar(String filePath) async {
    final imageUrl = await uploadPublicImage(filePath);

    final response = await _apiService.patch<Map<String, dynamic>>(
      ApiEndpoints.uploadAvatar,
      data: {'avatar': imageUrl},
    );

    if (!response.isSuccess || response.data == null) {
      throw UserException(response.message ?? '上传头像失败');
    }

    final user = User.fromJson(response.data!);
    await StorageService.instance.saveUserInfo(user.toJson());
    return user;
  }

  /// 获取其他用户资料
  Future<User> getUserProfile(String userId, {CancelToken? cancelToken}) async {
    return getUserPublicProfile(userId, cancelToken: cancelToken);
  }

  /// 获取其他用户公开资料（简化版，仅基本信息）
  Future<User> getUserPublicProfile(String userId, {CancelToken? cancelToken}) async {
    final detail = await getPublicProfileDetail(userId, cancelToken: cancelToken);
    return detail.user;
  }

  /// 获取其他用户完整资料（含统计、近期任务、收到的评价）
  Future<UserProfileDetail> getPublicProfileDetail(
    String userId, {
    CancelToken? cancelToken,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.userById(userId),
      cancelToken: cancelToken,
    );

    if (!response.isSuccess || response.data == null) {
      throw UserException(response.message ?? '获取用户资料失败');
    }

    return UserProfileDetail.fromJson(response.data!);
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
      data: {'new_email': email},
    );

    if (!response.isSuccess) {
      throw UserException(response.message ?? '发送验证码失败');
    }
  }

  /// 发送手机更新验证码
  Future<void> sendPhoneUpdateCode(String phone) async {
    final response = await _apiService.post(
      ApiEndpoints.sendPhoneUpdateCode,
      data: {'new_phone': phone},
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

  /// 上传图片（私密，任务聊天等；后端 /api/upload/image 要求字段名为 image）
  Future<String> uploadImage(String filePath) async {
    final response = await _apiService.uploadFile<Map<String, dynamic>>(
      ApiEndpoints.uploadImage,
      filePath: filePath,
      fieldName: 'image',
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
      fieldName: 'image',
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

  /// 获取交易记录（游标分页）
  Future<List<Transaction>> getTransactions({
    int limit = 20,
    String? startingAfter,
    String? type,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectTransactions,
      queryParameters: {
        'limit': limit,
        if (startingAfter != null) 'starting_after': startingAfter,
        if (type != null) 'type': type,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw UserException(response.message ?? '获取交易记录失败');
    }

    final items = response.data!['transactions'] as List<dynamic>? ?? [];
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
