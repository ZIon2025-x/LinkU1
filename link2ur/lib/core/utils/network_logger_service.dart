import 'dart:convert';

import 'logger.dart';

/// 网络日志条目
class NetworkLog {
  NetworkLog({
    required this.id,
    required this.timestamp,
    required this.url,
    this.method,
    this.requestHeaders,
    this.requestBody,
    this.responseBody,
    this.statusCode,
    this.duration,
    this.error,
    this.responseHeaders,
  });

  final String id;
  final DateTime timestamp;
  final String url;
  String? method;
  Map<String, dynamic>? requestHeaders;
  String? requestBody;
  String? responseBody;
  int? statusCode;
  Duration? duration;
  String? error;
  Map<String, dynamic>? responseHeaders;

  bool get isSuccess =>
      statusCode != null && statusCode! >= 200 && statusCode! < 300;
  bool get isSlow =>
      duration != null && duration!.inMilliseconds > 3000;

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'url': url,
        'method': method,
        'statusCode': statusCode,
        'durationMs': duration?.inMilliseconds,
        'error': error,
      };
}

/// 网络日志服务
/// 对齐 iOS NetworkLogger.swift
/// 内存中记录网络请求/响应，支持导出
class NetworkLoggerService {
  NetworkLoggerService._();
  static final NetworkLoggerService instance = NetworkLoggerService._();

  final List<NetworkLog> _logs = [];
  static const int _maxLogs = 100;
  bool _isEnabled = true;
  int _requestIdCounter = 0;

  /// 是否启用
  bool get isEnabled => _isEnabled;
  set isEnabled(bool value) => _isEnabled = value;

  /// 所有日志
  List<NetworkLog> get logs => List.unmodifiable(_logs);

  /// 记录请求
  /// 返回请求 ID，用于后续匹配响应
  String logRequest({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    dynamic body,
  }) {
    if (!_isEnabled) return '';

    final requestId = 'req_${++_requestIdCounter}';

    final log = NetworkLog(
      id: requestId,
      timestamp: DateTime.now(),
      url: url,
      method: method,
      requestHeaders: headers,
      requestBody: body != null ? _formatBody(body) : null,
    );

    _logs.add(log);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }

    AppLogger.network(method, url);

    return requestId;
  }

  /// 记录响应
  void logResponse({
    required String requestId,
    required String url,
    int? statusCode,
    Map<String, dynamic>? headers,
    dynamic body,
    Duration? duration,
    String? error,
  }) {
    if (!_isEnabled) return;

    // 找到对应的请求日志
    final logIndex = _logs.indexWhere((l) => l.id == requestId);
    if (logIndex != -1) {
      final log = _logs[logIndex];
      log.statusCode = statusCode;
      log.responseHeaders = headers;
      log.responseBody = body != null ? _formatBody(body) : null;
      log.duration = duration;
      log.error = error;
    } else {
      // 如果找不到对应请求，创建新日志
      _logs.add(NetworkLog(
        id: requestId,
        timestamp: DateTime.now(),
        url: url,
        statusCode: statusCode,
        responseHeaders: headers,
        responseBody: body != null ? _formatBody(body) : null,
        duration: duration,
        error: error,
      ));
    }

    if (statusCode != null) {
      AppLogger.network(
          'RESPONSE', '$url [$statusCode] ${duration?.inMilliseconds}ms');
    }
    if (error != null) {
      AppLogger.error('Network error: $url', error);
    }
  }

  /// 获取日志（可选限制数量）
  List<NetworkLog> getLogs({int? limit}) {
    if (limit != null && limit < _logs.length) {
      return _logs.sublist(_logs.length - limit);
    }
    return List.unmodifiable(_logs);
  }

  /// 清除所有日志
  void clearLogs() {
    _logs.clear();
    AppLogger.info('NetworkLogger: Logs cleared');
  }

  /// 导出日志为 JSON
  List<Map<String, dynamic>> exportLogs() {
    return _logs.map((log) => log.toJson()).toList();
  }

  /// 获取摘要统计
  Map<String, dynamic> getStats() {
    final total = _logs.length;
    final successful = _logs.where((l) => l.isSuccess).length;
    final failed =
        _logs.where((l) => l.statusCode != null && !l.isSuccess).length;
    final slow = _logs.where((l) => l.isSlow).length;
    final pending = _logs.where((l) => l.statusCode == null).length;

    return {
      'total': total,
      'successful': successful,
      'failed': failed,
      'slow': slow,
      'pending': pending,
    };
  }

  // ==================== 内部方法 ====================

  String _formatBody(dynamic body) {
    if (body is String) {
      // 截断超长 body
      return body.length > 2000
          ? '${body.substring(0, 2000)}... [truncated]'
          : body;
    }
    try {
      final json = jsonEncode(body);
      return json.length > 2000
          ? '${json.substring(0, 2000)}... [truncated]'
          : json;
    } catch (_) {
      return body.toString();
    }
  }
}
