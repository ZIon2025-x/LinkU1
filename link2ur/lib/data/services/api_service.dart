import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/config/api_config.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/network_interceptor.dart';
import 'storage_service.dart';

/// API服务
/// 参考iOS APIService.swift
class ApiService {
  ApiService() {
    _dio = Dio(_baseOptions);
    _setupInterceptors();
  }

  late final Dio _dio;

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
    // 添加Token
    final token = await StorageService.instance.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // 添加语言
    final language = await StorageService.instance.getLanguage();
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
      final refreshed = await _refreshToken();
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
      if (refreshToken == null) return false;

      final response = await Dio(_baseOptions).post(
        '/api/secure-auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await StorageService.instance.saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
        );
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('Token refresh failed', e);
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
        'Retrying request (${nextRetry}/$maxRetries) in ${delayMs}ms: ${err.requestOptions.uri}');

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
