/// API配置
class ApiConfig {
  ApiConfig._();

  /// API版本
  static const String apiVersion = 'v1';

  /// 请求头
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-App-Platform': 'flutter',
    'X-App-Version': '1.0.0',
  };

  /// 重试次数
  static const int maxRetries = 3;

  /// 重试延迟（毫秒）
  static const int retryDelayMs = 1000;

  /// 分页默认大小
  static const int defaultPageSize = 20;

  /// 缓存过期时间（秒）
  static const int cacheExpireSeconds = 300; // 5分钟
}
