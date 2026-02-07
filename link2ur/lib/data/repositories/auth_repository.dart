import '../models/user.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/logger.dart';

/// 认证仓库
/// 参考iOS APIService+Endpoints.swift 认证相关
class AuthRepository {
  AuthRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;

  /// 邮箱密码登录
  Future<User> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      data: {
        'email': email,
        'password': password,
      },
    );

    if (!response.isSuccess) {
      throw AuthException(response.message ?? '登录失败');
    }

    final loginResponse = LoginResponse.fromJson(response.data!);

    // 保存Token
    await StorageService.instance.saveTokens(
      accessToken: loginResponse.accessToken,
      refreshToken: loginResponse.refreshToken,
    );

    // 保存用户信息
    await StorageService.instance.saveUserId(loginResponse.user.id);
    await StorageService.instance.saveUserInfo(loginResponse.user.toJson());

    // 连接WebSocket
    WebSocketService.instance.connect();

    AppLogger.info('User logged in: ${loginResponse.user.id}');
    return loginResponse.user;
  }

  /// 邮箱验证码登录
  Future<User> loginWithCode({
    required String email,
    required String code,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.loginWithCode,
      data: {
        'email': email,
        'code': code,
      },
    );

    if (!response.isSuccess) {
      throw AuthException(response.message ?? '登录失败');
    }

    final loginResponse = LoginResponse.fromJson(response.data!);

    await StorageService.instance.saveTokens(
      accessToken: loginResponse.accessToken,
      refreshToken: loginResponse.refreshToken,
    );

    await StorageService.instance.saveUserId(loginResponse.user.id);
    await StorageService.instance.saveUserInfo(loginResponse.user.toJson());

    WebSocketService.instance.connect();

    AppLogger.info('User logged in with code: ${loginResponse.user.id}');
    return loginResponse.user;
  }

  /// 手机验证码登录
  Future<User> loginWithPhoneCode({
    required String phone,
    required String code,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.loginWithPhoneCode,
      data: {
        'phone': phone,
        'code': code,
      },
    );

    if (!response.isSuccess) {
      throw AuthException(response.message ?? '登录失败');
    }

    final loginResponse = LoginResponse.fromJson(response.data!);

    await StorageService.instance.saveTokens(
      accessToken: loginResponse.accessToken,
      refreshToken: loginResponse.refreshToken,
    );

    await StorageService.instance.saveUserId(loginResponse.user.id);
    await StorageService.instance.saveUserInfo(loginResponse.user.toJson());

    WebSocketService.instance.connect();

    AppLogger.info('User logged in with phone: ${loginResponse.user.id}');
    return loginResponse.user;
  }

  /// 注册
  Future<User> register({
    required String email,
    required String password,
    required String name,
    String? code,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.register,
      data: {
        'email': email,
        'password': password,
        'name': name,
        if (code != null) 'code': code,
      },
    );

    if (!response.isSuccess) {
      throw AuthException(response.message ?? '注册失败');
    }

    final loginResponse = LoginResponse.fromJson(response.data!);

    await StorageService.instance.saveTokens(
      accessToken: loginResponse.accessToken,
      refreshToken: loginResponse.refreshToken,
    );

    await StorageService.instance.saveUserId(loginResponse.user.id);
    await StorageService.instance.saveUserInfo(loginResponse.user.toJson());

    WebSocketService.instance.connect();

    AppLogger.info('User registered: ${loginResponse.user.id}');
    return loginResponse.user;
  }

  /// 发送邮箱验证码
  Future<void> sendEmailCode(String email) async {
    final response = await _apiService.post(
      ApiEndpoints.sendVerificationCode,
      data: {'email': email},
    );

    if (!response.isSuccess) {
      throw AuthException(response.message ?? '发送验证码失败');
    }
  }

  /// 发送手机验证码
  Future<void> sendPhoneCode(String phone) async {
    final response = await _apiService.post(
      ApiEndpoints.sendPhoneCode,
      data: {'phone': phone},
    );

    if (!response.isSuccess) {
      throw AuthException(response.message ?? '发送验证码失败');
    }
  }

  /// 登出
  Future<void> logout() async {
    try {
      await _apiService.post(ApiEndpoints.logout);
    } catch (e) {
      AppLogger.warning('Logout API call failed', e);
    }

    // 断开WebSocket
    WebSocketService.instance.disconnect();

    // 清除本地数据
    await StorageService.instance.clearAllOnLogout();

    AppLogger.info('User logged out');
  }

  /// 获取当前用户
  Future<User?> getCurrentUser() async {
    final isLoggedIn = await StorageService.instance.isLoggedIn();
    if (!isLoggedIn) return null;

    // 先尝试从本地获取
    final cachedUser = StorageService.instance.getUserInfo();
    if (cachedUser != null) {
      // 异步更新用户信息
      _refreshUserInfo();
      return User.fromJson(cachedUser);
    }

    // 从服务器获取
    return await _fetchUserProfile();
  }

  /// 刷新用户信息
  Future<void> _refreshUserInfo() async {
    try {
      await _fetchUserProfile();
    } catch (e) {
      AppLogger.warning('Failed to refresh user info', e);
    }
  }

  /// 获取用户资料
  Future<User?> _fetchUserProfile() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.userProfile,
    );

    if (response.isSuccess && response.data != null) {
      final user = User.fromJson(response.data!);
      await StorageService.instance.saveUserInfo(user.toJson());
      return user;
    }

    return null;
  }

  /// 检查登录状态
  Future<bool> isLoggedIn() async {
    return await StorageService.instance.isLoggedIn();
  }

  /// 发起忘记密码请求（发送重置邮件/验证码）
  Future<void> forgotPassword({required String email}) async {
    final response = await _apiService.post(
      ApiEndpoints.forgotPassword,
      data: {'email': email},
    );

    if (!response.isSuccess) {
      throw AuthException(response.message ?? '发送重置邮件失败');
    }
  }

  /// 重置密码（邮箱+验证码方式）
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.forgotPassword,
      data: {
        'email': email,
        'code': code,
        'new_password': newPassword,
      },
    );

    if (!response.isSuccess) {
      throw AuthException(response.message ?? '重置密码失败');
    }
  }

  /// 通过token重置密码（邮件链接中的token）
  Future<void> resetPasswordWithToken({
    required String token,
    required String newPassword,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.resetPassword(token),
      data: {
        'new_password': newPassword,
      },
    );

    if (!response.isSuccess) {
      throw AuthException(response.message ?? '重置密码失败');
    }
  }
}

/// 认证异常
class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}
