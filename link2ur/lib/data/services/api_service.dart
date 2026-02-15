import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/config/api_config.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/network_interceptor.dart';
import '../../core/utils/network_monitor.dart';
import '../../core/utils/app_exception.dart';
import 'storage_service.dart';
import 'http_client_config_stub.dart'
    if (dart.library.io) 'http_client_config_io.dart'
    if (dart.library.html) 'http_client_config_web.dart' as http_config;

/// API服务
/// 参考iOS APIService.swift
class ApiService {
  ApiService() {
    _dio = Dio(_baseOptions);
    _configureHttpClient();
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

  /// 配置 HTTP 客户端（连接池、keep-alive）
  /// 使用条件导入：移动端用 IOHttpClientAdapter，Web 端用 BrowserHttpClientAdapter
  void _configureHttpClient() {
    http_config.configureHttpClient(_dio);
  }

  /// 内存缓存实例（GET 请求短时缓存）
  final _cache = _MemoryCache(maxEntries: 100);

  /// 配置拦截器
  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );

    // GET 请求内存缓存拦截器
    _dio.interceptors.add(_CacheInterceptor(cache: _cache));

    // 自动重试拦截器
    _dio.interceptors.add(_RetryInterceptor(
      dio: _dio,
      maxRetries: ApiConfig.maxRetries,
      retryDelayMs: ApiConfig.retryDelayMs,
    ));

    // 网络监控拦截器（NetworkLogger + PerformanceMonitor）
    _dio.interceptors.add(NetworkMonitorInterceptor());

    // 注意：不再使用 Dio LogInterceptor。
    // 它会逐行打印每个请求头、响应头和完整 body，单个请求产生 40+ 行日志，
    // 通过 debugPrint 节流后会造成严重的控制台 I/O 延迟，让页面看起来「一直在加载」。
    // 网络日志已由上方两层拦截器覆盖：
    //   1. _onRequest/_onResponse → 简洁的 method + URL + status
    //   2. NetworkMonitorInterceptor → 结构化日志（内存存储 + RESPONSE 耗时）
  }

  /// 请求拦截
  void _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Token 刷新请求跳过 auth 拦截器，防止覆盖已设置的 header
    if (options.extra['skipAuth'] == true) {
      // 仅添加语言 header
      final language = StorageService.instance.getLanguage();
      options.headers['Accept-Language'] = language ?? 'zh-CN';
      return handler.next(options);
    }

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

      // 移动端签名（与后端 MOBILE_APP_SECRET 一致时消除「缺少签名或时间戳」WARNING）
      final secret = AppConfig.mobileAppSecret;
      if (secret.isNotEmpty) {
        final timestamp = (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000).toString();
        final message = utf8.encode('$token$timestamp');
        final key = utf8.encode(secret);
        final hmacSha256 = Hmac(sha256, key);
        final digest = hmacSha256.convert(message);
        final signature = digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        options.headers['X-App-Timestamp'] = timestamp;
        options.headers['X-App-Signature'] = signature;
      }

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

    // 网络日志由 NetworkMonitorInterceptor 统一记录，此处不再重复打印
    handler.next(options);
  }

  /// 响应拦截
  void _onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    // 网络日志由 NetworkMonitorInterceptor 统一记录，此处不再重复打印
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

      // 如果请求本身没有携带 token（未登录用户访问了受保护接口），
      // 直接拒绝，不触发 refresh/logout 流程
      final authHeader = error.requestOptions.headers['Authorization'];
      if (authHeader == null || authHeader.toString().isEmpty) {
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
  ///
  /// 复用主 _dio 实例以利用连接池，通过 extra 标记跳过 auth 拦截器防止循环。
  /// _onError 中已对 refresh 路径做了独立的 401 短路处理。
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await StorageService.instance.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        AppLogger.warning('No refresh token available');
        return false;
      }

      AppLogger.info('Attempting to refresh access token...');

      // 后端接受 refresh_token 通过 X-Refresh-Token header
      final currentToken = await StorageService.instance.getAccessToken();
      final response = await _dio.post(
        '/api/secure-auth/refresh',
        options: Options(
          // 设置较短的超时，refresh不应该很慢
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          headers: {
            if (currentToken != null) 'X-Session-ID': currentToken,
            'X-Refresh-Token': refreshToken,
          },
          // 跳过 _onRequest 中的 auth 拦截器，防止覆盖 header
          extra: {'skipAuth': true},
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
      cancelToken: requestOptions.cancelToken,
    );
  }

  // ==================== CancelToken 管理 ====================

  /// 创建一个新的 CancelToken，调用方可在 BLoC close 时取消
  CancelToken createCancelToken() => CancelToken();

  // ==================== GET 请求去重 ====================

  /// 正在进行中的 GET 请求（防止重复请求）
  final Map<String, Future<ApiResponse>> _pendingGetRequests = {};

  /// 构建去重键（path + queryParameters）
  String _buildDeduplicationKey(String path, Map<String, dynamic>? queryParameters) {
    if (queryParameters == null || queryParameters.isEmpty) return path;
    final sortedKeys = queryParameters.keys.toList()..sort();
    final paramStr = sortedKeys.map((k) => '$k=${queryParameters[k]}').join('&');
    return '$path?$paramStr';
  }

  // ==================== HTTP方法 ====================

  /// GET请求（自动去重：相同 path + queryParameters 的并发请求共享同一个 Future）
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final deduplicationKey = _buildDeduplicationKey(path, queryParameters);

    // 如果有相同的请求正在进行中，直接复用其 Future
    final pending = _pendingGetRequests[deduplicationKey];
    if (pending != null) {
      AppLogger.debug('GET request deduplicated: $deduplicationKey');
      final result = await pending;
      // 对复用的结果重新应用 fromJson（因为泛型 T 可能不同）
      if (result.isSuccess && fromJson != null) {
        return ApiResponse.success(
          data: fromJson(result.data),
          statusCode: result.statusCode,
        );
      }
      return result as ApiResponse<T>;
    }

    // 创建新请求并注册到去重 Map
    final future = _executeGet<T>(path,
      queryParameters: queryParameters,
      fromJson: fromJson,
      options: options,
      cancelToken: cancelToken,
    );
    _pendingGetRequests[deduplicationKey] = future;

    try {
      final result = await future;
      return result;
    } finally {
      _pendingGetRequests.remove(deduplicationKey);
    }
  }

  /// 实际执行 GET 请求
  Future<ApiResponse<T>> _executeGet<T>(
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

  /// 上传文件（通过文件路径，仅限移动端/桌面端）
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

  /// 上传文件（通过字节数据，Web 和移动端通用）
  Future<ApiResponse<T>> uploadFileBytes<T>(
    String path, {
    required List<int> bytes,
    required String filename,
    String fieldName = 'file',
    Map<String, dynamic>? extraData,
    T Function(dynamic)? fromJson,
    void Function(int, int)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final formData = FormData.fromMap({
        fieldName: MultipartFile.fromBytes(bytes, filename: filename),
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

  /// 清除所有缓存（登出时调用）
  void clearCache() => _cache.clear();

  /// 使指定路径前缀的缓存失效（如写操作后主动刷新）
  void invalidateCache(String pathPrefix) => _cache.invalidate(pathPrefix);

  /// 释放资源
  void dispose() {
    _cache.clear();
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
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
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

// ==================== 内存缓存 ====================

/// 缓存条目
class _CacheEntry {
  _CacheEntry({required this.response, required this.expiry});

  final Response response;
  final DateTime expiry;

  bool get isExpired => DateTime.now().isAfter(expiry);
}

/// 简单的 LRU 内存缓存，用于 GET 请求响应
class _MemoryCache {
  _MemoryCache({this.maxEntries = 100});

  final int maxEntries;
  final LinkedHashMap<String, _CacheEntry> _store = LinkedHashMap();

  /// 可缓存的 GET 路径前缀及其 TTL（秒）
  /// 只缓存读取型、变化频率低的接口
  static const Map<String, int> _cachePolicies = {
    '/api/tasks': 30,                   // 任务列表 30s
    '/api/forum': 30,                   // 论坛帖子 30s
    '/api/flea-market': 30,             // 跳蚤市场 30s
    '/api/task-experts': 60,            // 达人列表 60s
    '/api/users/profile/': 120,         // 用户资料 120s
    '/api/leaderboard': 300,            // 排行榜 5min
    '/api/categories': 600,             // 分类 10min
    '/api/app-config': 600,             // 应用配置 10min
  };

  /// 根据路径获取 TTL，返回 null 表示不缓存
  int? _getTtl(String path) {
    for (final entry in _cachePolicies.entries) {
      if (path.startsWith(entry.key)) return entry.value;
    }
    return null;
  }

  /// 构建缓存键
  String _buildKey(RequestOptions options) {
    final params = options.queryParameters;
    if (params.isEmpty) return options.path;
    final sortedKeys = params.keys.toList()..sort();
    final paramStr = sortedKeys.map((k) => '$k=${params[k]}').join('&');
    return '${options.path}?$paramStr';
  }

  /// 尝试获取缓存
  Response? get(RequestOptions options) {
    final ttl = _getTtl(options.path);
    if (ttl == null) return null;

    final key = _buildKey(options);
    final entry = _store[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _store.remove(key);
      return null;
    }

    // LRU: 移到末尾
    _store.remove(key);
    _store[key] = entry;
    return entry.response;
  }

  /// 存入缓存
  void put(RequestOptions options, Response response) {
    final ttl = _getTtl(options.path);
    if (ttl == null) return;

    // 只缓存成功响应
    if (response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300) {
      final key = _buildKey(options);

      // LRU 淘汰
      if (_store.length >= maxEntries && !_store.containsKey(key)) {
        _store.remove(_store.keys.first);
      }

      _store[key] = _CacheEntry(
        response: response,
        expiry: DateTime.now().add(Duration(seconds: ttl)),
      );
    }
  }

  /// 清除所有缓存
  void clear() => _store.clear();

  /// 清除匹配前缀的缓存（用于写操作后主动失效）
  void invalidate(String pathPrefix) {
    _store.removeWhere((key, _) => key.startsWith(pathPrefix));
  }
}

/// GET 请求缓存拦截器
class _CacheInterceptor extends Interceptor {
  _CacheInterceptor({required this.cache});

  final _MemoryCache cache;

  /// 请求头标记：跳过缓存（用于下拉刷新等场景）
  static const String skipCacheHeader = 'x-skip-cache';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 只缓存 GET 请求
    if (options.method.toUpperCase() != 'GET') {
      return handler.next(options);
    }

    // 检查是否要求跳过缓存
    if (options.headers[skipCacheHeader] == 'true') {
      options.headers.remove(skipCacheHeader);
      return handler.next(options);
    }

    final cached = cache.get(options);
    if (cached != null) {
      AppLogger.debug('Cache HIT: ${options.path}');
      return handler.resolve(
        Response(
          requestOptions: options,
          data: cached.data,
          statusCode: cached.statusCode,
          headers: cached.headers,
        ),
      );
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // 缓存 GET 成功响应
    if (response.requestOptions.method.toUpperCase() == 'GET') {
      cache.put(response.requestOptions, response);
    }

    // 写操作自动失效相关缓存
    final method = response.requestOptions.method.toUpperCase();
    if (method == 'POST' || method == 'PUT' || method == 'PATCH' || method == 'DELETE') {
      // 提取路径前缀进行失效（例如 /api/tasks/123 → /api/tasks）
      final path = response.requestOptions.path;
      final segments = path.split('/');
      if (segments.length >= 3) {
        final prefix = segments.sublist(0, 3).join('/');
        cache.invalidate(prefix);
      }
    }

    handler.next(response);
  }
}
