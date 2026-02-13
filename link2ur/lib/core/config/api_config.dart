import 'package:flutter/foundation.dart' show kIsWeb;
import 'platform_helper_stub.dart'
    if (dart.library.io) 'platform_helper_io.dart' as platform_helper;

/// API配置
class ApiConfig {
  ApiConfig._();

  /// API版本
  static const String apiVersion = 'v1';

  /// 运行时平台标识（ios / android / web / other）
  /// 后端通过 X-Platform 判断移动端应用并给予长期会话
  static String get platformId {
    if (kIsWeb) return 'web';
    return platform_helper.getPlatformId();
  }

  /// 请求头
  /// 注意：X-Platform / User-Agent 依赖运行时平台检测，后端用其校验移动端请求
  static Map<String, String> get defaultHeaders {
    final platform = platformId;
    final ua = platform == 'ios'
        ? 'Link2Ur-iOS'
        : platform == 'android'
            ? 'Link2Ur-Android'
            : 'Link2Ur-Flutter';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip, deflate',
      'User-Agent': '$ua/1.0.0 ($apiVersion)',
      'X-App-Platform': 'flutter',
      'X-Platform': platform,
      'X-App-Version': '1.0.0',
    };
  }

  /// 重试次数
  static const int maxRetries = 3;

  /// 重试延迟（毫秒）
  static const int retryDelayMs = 1000;

  /// 分页默认大小
  static const int defaultPageSize = 20;

  /// 缓存过期时间（秒）
  static const int cacheExpireSeconds = 300; // 5分钟
}
