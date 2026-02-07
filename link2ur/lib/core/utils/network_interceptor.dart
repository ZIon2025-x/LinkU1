import 'package:dio/dio.dart';

import 'network_logger_service.dart';
import 'performance_monitor.dart';

/// 请求拦截器函数类型
typedef RequestInterceptorFn = RequestOptions? Function(RequestOptions request);

/// 响应拦截器函数类型
typedef ResponseInterceptorFn = Response? Function(Response response);

/// 网络拦截器管理器
/// 对齐 iOS NetworkInterceptor.swift
/// 提供请求/响应拦截链
class NetworkInterceptorManager {
  NetworkInterceptorManager._();
  static final NetworkInterceptorManager instance =
      NetworkInterceptorManager._();

  final List<RequestInterceptorFn> _requestInterceptors = [];
  final List<ResponseInterceptorFn> _responseInterceptors = [];

  /// 添加请求拦截器
  void addRequestInterceptor(RequestInterceptorFn interceptor) {
    _requestInterceptors.add(interceptor);
  }

  /// 添加响应拦截器
  void addResponseInterceptor(ResponseInterceptorFn interceptor) {
    _responseInterceptors.add(interceptor);
  }

  /// 执行请求拦截链
  /// 返回 null 表示请求被拦截（取消）
  RequestOptions? interceptRequest(RequestOptions request) {
    RequestOptions? current = request;
    for (final interceptor in _requestInterceptors) {
      if (current == null) return null;
      current = interceptor(current);
    }
    return current;
  }

  /// 执行响应拦截链
  /// 返回 null 表示响应被拦截
  Response? interceptResponse(Response response) {
    Response? current = response;
    for (final interceptor in _responseInterceptors) {
      if (current == null) return null;
      current = interceptor(current);
    }
    return current;
  }

  /// 清除所有拦截器
  void clear() {
    _requestInterceptors.clear();
    _responseInterceptors.clear();
  }
}

/// Dio 集成拦截器
/// 将 NetworkLoggerService 和 PerformanceMonitor 集成到 Dio 中
class NetworkMonitorInterceptor extends Interceptor {
  final NetworkLoggerService _logger = NetworkLoggerService.instance;
  final PerformanceMonitor _perfMonitor = PerformanceMonitor.instance;
  final NetworkInterceptorManager _interceptorManager =
      NetworkInterceptorManager.instance;

  /// 请求 ID 映射（requestOptions hashCode -> requestId）
  final Map<int, String> _requestIds = {};

  /// 请求开始时间映射
  final Map<int, DateTime> _requestStartTimes = {};

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) {
    // 执行自定义拦截器链
    final intercepted = _interceptorManager.interceptRequest(options);
    if (intercepted == null) {
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        error: 'Request intercepted',
      ));
      return;
    }

    // 记录请求日志
    final requestId = _logger.logRequest(
      method: intercepted.method,
      url: intercepted.uri.toString(),
      headers: intercepted.headers.map(
          (k, v) => MapEntry(k, v)),
      body: intercepted.data,
    );

    final key = intercepted.hashCode;
    _requestIds[key] = requestId;
    _requestStartTimes[key] = DateTime.now();

    handler.next(intercepted);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final key = response.requestOptions.hashCode;
    final requestId = _requestIds.remove(key) ?? '';
    final startTime = _requestStartTimes.remove(key);
    final duration = startTime != null
        ? DateTime.now().difference(startTime)
        : null;

    // 记录响应日志
    _logger.logResponse(
      requestId: requestId,
      url: response.requestOptions.uri.toString(),
      statusCode: response.statusCode,
      body: response.data,
      duration: duration,
    );

    // 记录性能指标
    _perfMonitor.recordNetworkRequest(NetworkRequestMetric(
      endpoint: response.requestOptions.path,
      method: response.requestOptions.method,
      startTime: startTime ?? DateTime.now(),
      duration: duration,
      statusCode: response.statusCode,
      responseSize: response.data?.toString().length,
    ));

    // 执行自定义响应拦截器
    final intercepted = _interceptorManager.interceptResponse(response);
    if (intercepted != null) {
      handler.next(intercepted);
    } else {
      handler.reject(DioException(
        requestOptions: response.requestOptions,
        type: DioExceptionType.cancel,
        error: 'Response intercepted',
      ));
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final key = err.requestOptions.hashCode;
    final requestId = _requestIds.remove(key) ?? '';
    final startTime = _requestStartTimes.remove(key);
    final duration = startTime != null
        ? DateTime.now().difference(startTime)
        : null;

    // 记录错误日志
    _logger.logResponse(
      requestId: requestId,
      url: err.requestOptions.uri.toString(),
      statusCode: err.response?.statusCode,
      duration: duration,
      error: err.message ?? err.type.name,
    );

    // 记录性能指标
    _perfMonitor.recordNetworkRequest(NetworkRequestMetric(
      endpoint: err.requestOptions.path,
      method: err.requestOptions.method,
      startTime: startTime ?? DateTime.now(),
      duration: duration,
      statusCode: err.response?.statusCode,
      error: err.message,
    ));

    handler.next(err);
  }
}
