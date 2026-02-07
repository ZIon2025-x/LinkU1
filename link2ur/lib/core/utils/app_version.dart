import 'package:package_info_plus/package_info_plus.dart';

import 'logger.dart';

/// 应用版本管理
/// 参考iOS AppVersion.swift
/// 管理应用版本信息，支持版本比较和更新检测
class AppVersion {
  AppVersion._();

  static final AppVersion instance = AppVersion._();

  PackageInfo? _packageInfo;

  /// 初始化
  Future<void> initialize() async {
    try {
      _packageInfo = await PackageInfo.fromPlatform();
      AppLogger.info(
        'AppVersion - ${_packageInfo!.appName} '
        'v${_packageInfo!.version} (${_packageInfo!.buildNumber})',
      );
    } catch (e) {
      AppLogger.error('AppVersion - Initialization failed', e);
    }
  }

  /// 应用名称
  String get appName => _packageInfo?.appName ?? 'LinkU';

  /// 版本号 (如 1.0.0)
  String get version => _packageInfo?.version ?? '0.0.0';

  /// 构建号
  String get buildNumber => _packageInfo?.buildNumber ?? '0';

  /// 包名
  String get packageName => _packageInfo?.packageName ?? '';

  /// 完整版本字符串
  String get fullVersion => '$version ($buildNumber)';

  /// 版本比较
  /// 返回: -1 (当前版本较低), 0 (相同), 1 (当前版本较高)
  int compareVersion(String otherVersion) {
    return _compareVersionStrings(version, otherVersion);
  }

  /// 检查是否需要更新
  bool needsUpdate(String latestVersion) {
    return compareVersion(latestVersion) < 0;
  }

  /// 比较两个版本号字符串
  static int _compareVersionStrings(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLength =
        parts1.length > parts2.length ? parts1.length : parts2.length;

    for (int i = 0; i < maxLength; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;

      if (p1 < p2) return -1;
      if (p1 > p2) return 1;
    }

    return 0;
  }
}
