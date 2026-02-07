import 'package:tencent_kit/tencent_kit.dart';

import 'logger.dart';

/// QQ 分享管理器
/// 对齐 iOS QQShareManager.swift
/// 支持分享链接到 QQ 好友和 QQ 空间
class QQShareManager {
  QQShareManager._();
  static final QQShareManager instance = QQShareManager._();

  bool _isInitialized = false;

  /// 初始化 QQ SDK
  /// [appId] QQ 开放平台 AppID
  /// [universalLink] iOS Universal Link
  Future<void> initialize({
    required String appId,
    String? universalLink,
  }) async {
    try {
      await TencentKitPlatform.instance.setIsPermissionGranted(
        granted: true,
      );
      await TencentKitPlatform.instance.registerApp(
        appId: appId,
        universalLink: universalLink,
      );
      _isInitialized = true;
      AppLogger.info('QQ SDK initialized');
    } catch (e) {
      AppLogger.error('QQ SDK initialization failed', e);
    }
  }

  /// 检查 QQ 是否已安装
  Future<bool> isQQInstalled() async {
    if (!_isInitialized) return false;
    try {
      return await TencentKitPlatform.instance.isQQInstalled();
    } catch (e) {
      AppLogger.warning('Check QQ installed failed: $e');
      return false;
    }
  }

  // ==================== 分享方法 ====================

  /// 分享链接到 QQ 好友
  Future<bool> shareToFriend({
    required String title,
    String description = '',
    required String url,
    String? imageUrl,
  }) async {
    return _shareWebPage(
      title: title,
      description: description,
      url: url,
      imageUrl: imageUrl,
      scene: TencentScene.kScene_QQ,
    );
  }

  /// 分享链接到 QQ 空间
  Future<bool> shareToQZone({
    required String title,
    String description = '',
    required String url,
    String? imageUrl,
  }) async {
    return _shareWebPage(
      title: title,
      description: description,
      url: url,
      imageUrl: imageUrl,
      scene: TencentScene.kScene_QZone,
    );
  }

  // ==================== 内部方法 ====================

  Future<bool> _shareWebPage({
    required String title,
    required String description,
    required String url,
    String? imageUrl,
    required int scene,
  }) async {
    if (!_isInitialized) {
      AppLogger.warning('QQ SDK not initialized');
      return false;
    }

    final installed = await isQQInstalled();
    if (!installed) {
      AppLogger.warning('QQ not installed');
      return false;
    }

    try {
      await TencentKitPlatform.instance.shareWebpage(
        scene: scene,
        title: title,
        summary: description,
        targetUrl: url,
        imageUri: imageUrl != null ? Uri.tryParse(imageUrl) : null,
      );

      AppLogger.info(
          'QQ share completed (scene: $scene)');
      return true;
    } catch (e) {
      AppLogger.error('QQ share failed', e);
      return false;
    }
  }
}
