import 'dart:async';
import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/config/api_config.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/network_interceptor.dart';
import '../../core/utils/network_monitor.dart';
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

    // 添加Token
    final token = await StorageService.instance.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

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
    AppLogger.error(
      'API Error: ${error.requestOptions.uri}',
      error,
      error.stackTrace,
    );

    // 401未授权，尝试刷新Token
    if (error.response?.statusCode == 401) {
      // 如果是refresh接口本身返回401，直接失败，避免无限循环
      if (error.requestOptions.path.contains('/api/secure-auth/refresh')) {
        AppLogger.warning('Refresh token expired or invalid');
        // 清除token并触发登出
        await StorageService.instance.clearTokens();
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
        // 重试原请求
        try {
          final response = await _retry(error.requestOptions);
          return handler.resolve(response);
        } catch (e) {
          return handler.reject(error);
        }
      }
    }

    handler.next(error);
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

      final response = await refreshDio.post(
        '/api/secure-auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(
          // 设置较短的超时，refresh不应该很慢
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final newAccessToken = data['access_token'];
        final newRefreshToken = data['refresh_token'];

        if (newAccessToken != null && newRefreshToken != null) {
          await StorageService.instance.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );
          AppLogger.info('Token refresh successful');
          return true;
        } else {
          AppLogger.error('Invalid response: missing tokens');
          return false;
        }
      }

      AppLogger.warning('Token refresh failed: status ${response.statusCode}');
      return false;
    } catch (e, stackTrace) {
      AppLogger.error('Token refresh failed', e, stackTrace);
      // 如果是401或403，清除token
      if (e is DioException &&
          (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        await StorageService.instance.clearTokens();
      }
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

  // ==================== HTTP方法 ====================

  /// GET请求
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
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
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
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
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
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
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
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
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
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
class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException: $message (code: $statusCode)';
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
