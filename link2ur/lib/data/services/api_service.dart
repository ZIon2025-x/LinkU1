import 'dart:async';
import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/config/api_config.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/network_interceptor.dart';
import '../../core/utils/network_monitor.dart';
import '../../core/utils/app_exception.dart';
import 'storage_service.dart';

/// API服务
/// 参考iOS APIService.swift
class ApiService {
  ApiService() {
    _dio = Dio(_baseOptions);
    _setupInterceptors();
  }

  late final Dio _dio;

  // Token刷新相关
  bool _isRefreshing = false;
  final List<Completer<void>> _refreshCompleters = [];

  /// 认证失败回调（token刷新失败时触发）
  /// 由 app.dart 设置，用于通知 AuthBloc 进入未认证状态
  void Function()? onAuthFailure;

  /// 防止 onAuthFailure 被并发的 401 请求重复触发
  bool _authFailureNotified = false;

  /// 基础配置
  BaseOptions get _baseOptions => BaseOptions(
        baseUrl: AppConfig.instance.baseUrl,
        connectTimeout: AppConfig.instance.requestTimeout,
        receiveTimeout: AppConfig.instance.requestTimeout,
        headers: ApiConfig.defaultHeaders,
      );

  /// 配置拦截器
  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );

    // 自动重试拦截器
    _dio.interceptors.add(_RetryInterceptor(
      dio: _dio,
      maxRetries: ApiConfig.maxRetries,
      retryDelayMs: ApiConfig.retryDelayMs,
    ));

    // 网络监控拦截器（NetworkLogger + PerformanceMonitor）
    _dio.interceptors.add(NetworkMonitorInterceptor());

    // 日志拦截器
    if (AppConfig.instance.enableDebugLog) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => AppLogger.network('DIO', obj.toString()),
      ));
    }
  }

  /// 请求拦截
  void _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 网络状态预检 — 无网络时立即失败，避免等待超时
    if (!NetworkMonitor.instance.isConnected) {
      AppLogger.warning('Request rejected: No network connection - ${options.uri}');
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'error_network_connection',
        ),
      );
      return;
    }

    // 添加Token（session_id 同时作为 Bearer token 和 X-Session-ID 发送）
    final token = await StorageService.instance.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      options.headers['X-Session-ID'] = token;

      // 检测到有效 token（用户重新登录），自动重置认证失败标志
      if (_authFailureNotified) {
        _authFailureNotified = false;
        AppLogger.info('Auth failure flag reset: valid token detected');
      }
    }
    // 注意：无 token 时不再短路拒绝请求。
    // 公开接口（论坛、排行榜等）无需认证也可访问，
    // 受保护接口会返回 401，由 _onError 正常处理。

    // 添加语言
    final language = StorageService.instance.getLanguage();
    options.headers['Accept-Language'] = language ?? 'zh-CN';

    AppLogger.network(
      options.method,
      options.uri.toString(),
    );

    handler.next(options);
  }

  /// 响应拦截
  void _onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    AppLogger.network(
      response.requestOptions.method,
      response.requestOptions.uri.toString(),
      statusCode: response.statusCode,
    );
    handler.next(response);
  }

  /// 错误拦截
  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    // 记录错误但脱敏处理（不输出完整 headers，避免泄露 token）
    AppLogger.error(
      'API Error: ${error.requestOptions.method} ${error.requestOptions.uri} '
      '[${error.response?.statusCode ?? 'no status'}]',
    );

    // 401未授权，尝试刷新Token
    if (error.response?.statusCode == 401) {
      // 如果是refresh接口本身返回401，直接失败，避免无限循环
      if (error.requestOptions.path.contains('/api/secure-auth/refresh')) {
        AppLogger.warning('Refresh token expired or invalid');
        _notifyAuthFailure(); // Token 清理统一由 AuthForceLogout → clearLocalAuthData 处理
        return handler.reject(error);
      }

      // 如果已经通知过认证失败，直接拒绝请求，不再重复处理
      if (_authFailureNotified) {
        return handler.reject(error);
      }

      // 如果正在刷新，等待刷新完成
      if (_isRefreshing) {
        try {
          final completer = Completer<void>();
          _refreshCompleters.add(completer);
          await completer.future;

          // 刷新完成后重试原请求
          final response = await _retry(error.requestOptions);
          return handler.resolve(response);
        } catch (e) {
          return handler.reject(error);
        }
      }

      // 开始刷新token
      _isRefreshing = true;
      final refreshed = await _refreshToken();
      _isRefreshing = false;

      // 通知所有等待的请求
      for (final completer in _refreshCompleters) {
        if (refreshed) {
          completer.complete();
        } else {
          completer.completeError('Token refresh failed');
        }
      }
      _refreshCompleters.clear();

      if (refreshed) {
        // 刷新成功，重置标志
        _authFailureNotified = false;
        // 重试原请求
        try {
          final response = await _retry(error.requestOptions);
          return handler.resolve(response);
        } catch (e) {
          return handler.reject(error);
        }
      }

      // Token 刷新失败，通知认证失败（Token 清理由 AuthForceLogout 统一处理）
      AppLogger.warning('Token refresh failed for 401 response, forcing logout');
      _notifyAuthFailure();
      return handler.reject(error);
    }

    handler.next(error);
  }

  /// 通知认证失败（仅通知一次，防止并发 401 重复触发）
  void _notifyAuthFailure() {
    if (!_authFailureNotified) {
      _authFailureNotified = true;
      onAuthFailure?.call();
    }
  }

  /// 刷新Token
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await StorageService.instance.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        AppLogger.warning('No refresh token available');
        return false;
      }

      AppLogger.info('Attempting to refresh access token...');

      // 创建独立的Dio实例，不使用auth拦截器避免循环
      // 但保留基础配置（超时、baseUrl等）
      final refreshDio = Dio(_baseOptions);

      // 后端接受 refresh_token 通过 X-Refresh-Token header
      final currentToken = await StorageService.instance.getAccessToken();
      final response = await refreshDio.post(
        '/api/secure-auth/refresh',
        options: Options(
          // 设置较短的超时，refresh不应该很慢
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          headers: {
            if (currentToken != null) 'X-Session-ID': currentToken,
            'X-Refresh-Token': refreshToken,
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        // 后端返回 session_id 作为新的认证凭证（兼容旧版 access_token）
        final newAccessToken = data['session_id'] ?? data['access_token'];
        final newRefreshToken = data['refresh_token'];

        if (newAccessToken != null) {
          await StorageService.instance.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );
          AppLogger.info('Token refresh successful');
          _authFailureNotified = false; // 刷新成功，重置标志
          return true;
        } else {
          AppLogger.error('Invalid refresh response: missing session_id. Keys: ${data is Map ? data.keys.toList() : data}');
          return false;
        }
      }

      AppLogger.warning('Token refresh failed: status ${response.statusCode}');
      return false;
    } catch (e, stackTrace) {
      AppLogger.error('Token refresh failed', e, stackTrace);
      // 注意：不在此处调用 onAuthFailure，统一由 _onError 在刷新失败后处理
      return false;
    }
  }

  /// 重试请求
  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final token = await StorageService.instance.getAccessToken();
    final options = Options(
      method: requestOptions.method,
      headers: {
        ...requestOptions.headers,
        'Authorization': 'Bearer $token',
      },
    );
    return _dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  // ==================== CancelToken 管理 ====================

  /// 创建一个新的 CancelToken，调用方可在 BLoC close 时取消
  CancelToken createCancelToken() => CancelToken();

  // ==================== HTTP方法 ====================

  /// GET请求
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return ApiResponse.success(
        data: fromJson != null ? fromJson(response.data) : response.data,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// POST请求
  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return ApiResponse.success(
        data: fromJson != null ? fromJson(response.data) : response.data,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// PUT请求
  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return ApiResponse.success(
        data: fromJson != null ? fromJson(response.data) : response.data,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// PATCH请求
  Future<ApiResponse<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return ApiResponse.success(
        data: fromJson != null ? fromJson(response.data) : response.data,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// DELETE请求
  Future<ApiResponse<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return ApiResponse.success(
        data: fromJson != null ? fromJson(response.data) : response.data,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// 上传文件
  Future<ApiResponse<T>> uploadFile<T>(
    String path, {
    required String filePath,
    String fieldName = 'file',
    Map<String, dynamic>? extraData,
    T Function(dynamic)? fromJson,
    void Function(int, int)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(filePath),
        if (extraData != null) ...extraData,
      });

      final response = await _dio.post(
        path,
        data: formData,
        onSendProgress: onProgress,
        cancelToken: cancelToken,
      );

      return ApiResponse.success(
        data: fromJson != null ? fromJson(response.data) : response.data,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// 处理错误
  /// 使用错误码标识，由 UI 层通过 l10n 转为本地化文本
  ApiResponse<T> _handleError<T>(DioException error) {
    String message;
    int? statusCode = error.response?.statusCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'error_network_timeout';
        break;
      case DioExceptionType.badResponse:
        message = _parseErrorMessage(error.response?.data) ?? 'error_request_failed';
        break;
      case DioExceptionType.cancel:
        message = 'error_request_cancelled';
        break;
      case DioExceptionType.connectionError:
        message = 'error_network_connection';
        break;
      default:
        message = 'error_unknown';
    }

    return ApiResponse.error(
      message: message,
      statusCode: statusCode,
      error: error,
    );
  }

  /// 解析错误信息
  String? _parseErrorMessage(dynamic data) {
    if (data == null) return null;
    if (data is String) return data;
    if (data is Map) {
      return data['message'] ?? data['detail'] ?? data['error'];
    }
    return null;
  }

  /// 释放资源
  void dispose() {
    _dio.close();
  }
}

/// API响应封装
class ApiResponse<T> {
  ApiResponse({
    required this.isSuccess,
    this.data,
    this.message,
    this.statusCode,
    this.error,
  });

  final bool isSuccess;
  final T? data;
  final String? message;
  final int? statusCode;
  final dynamic error;

  factory ApiResponse.success({
    T? data,
    int? statusCode,
  }) {
    return ApiResponse(
      isSuccess: true,
      data: data,
      statusCode: statusCode,
    );
  }

  factory ApiResponse.error({
    String? message,
    int? statusCode,
    dynamic error,
  }) {
    return ApiResponse(
      isSuccess: false,
      message: message,
      statusCode: statusCode,
      error: error,
    );
  }

  /// 获取数据或抛出异常
  T get dataOrThrow {
    if (!isSuccess || data == null) {
      throw ApiException(message ?? '获取数据失败', statusCode);
    }
    return data!;
  }
}

/// API异常
class ApiException extends AppException {
  ApiException(super.message, [this.statusCode]) 
      : super(code: statusCode?.toString());

  final int? statusCode;

  @override
  String toString() => 'ApiException: $message${statusCode != null ? ' (code: $statusCode)' : ''}';
}

/// 自动重试拦截器
/// 对连接超时、发送超时、接收超时和连接错误自动重试
class _RetryInterceptor extends Interceptor {
  _RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.retryDelayMs = 1000,
  });

  final Dio dio;
  final int maxRetries;
  final int retryDelayMs;

  static const String _retryCountKey = 'retry_count';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_shouldRetry(err)) {
      return handler.next(err);
    }

    final retryCount =
        (err.requestOptions.extra[_retryCountKey] as int?) ?? 0;

    if (retryCount >= maxRetries) {
      AppLogger.warning(
          'Max retries reached for ${err.requestOptions.uri}');
      return handler.next(err);
    }

    final nextRetry = retryCount + 1;
    // 指数退避：delay * 2^retryCount
    final delayMs = retryDelayMs * (1 << retryCount);

    AppLogger.info(
        'Retrying request ($nextRetry/$maxRetries) in ${delayMs}ms: ${err.requestOptions.uri}');

    await Future.delayed(Duration(milliseconds: delayMs));

    try {
      err.requestOptions.extra[_retryCountKey] = nextRetry;

      final response = await dio.fetch(err.requestOptions);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  bool _shouldRetry(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        // 重试 500+ 服务器错误（不含 401/403/404 等客户端错误）
        final statusCode = err.response?.statusCode;
        return statusCode != null && statusCode >= 500;
      default:
        return false;
    }
  }
}
