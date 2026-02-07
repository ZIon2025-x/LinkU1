import 'dart:typed_data';

import 'package:fluwx/fluwx.dart' as fluwx;

import 'logger.dart';

/// 微信分享管理器
/// 对齐 iOS WeChatShareManager.swift
/// 支持分享到好友和朋友圈，内容类型：链接、图片
class WeChatShareManager {
  WeChatShareManager._();
  static final WeChatShareManager instance = WeChatShareManager._();

  final fluwx.Fluwx _fluwx = fluwx.Fluwx();
  bool _isInitialized = false;

  /// 初始化微信 SDK
  /// [appId] 微信开放平台 AppID
  /// [universalLink] iOS Universal Link
  Future<void> initialize({
    required String appId,
    String? universalLink,
  }) async {
    try {
      await _fluwx.registerApi(
        appId: appId,
        universalLink: universalLink ?? '',
      );
      _isInitialized = true;
      AppLogger.info('WeChat SDK initialized');
    } catch (e) {
      AppLogger.error('WeChat SDK initialization failed', e);
    }
  }

  /// 检查微信是否已安装
  Future<bool> isWeChatInstalled() async {
    try {
      return await _fluwx.isWeChatInstalled;
    } catch (e) {
      AppLogger.warning('Check WeChat installed failed: $e');
      return false;
    }
  }

  // ==================== 分享方法 ====================

  /// 分享链接到微信好友
  Future<bool> shareToFriend({
    required String title,
    String description = '',
    required String url,
    Uint8List? thumbnail,
  }) async {
    return _shareWebPage(
      title: title,
      description: description,
      url: url,
      thumbnail: thumbnail,
      scene: fluwx.WeChatScene.session,
    );
  }

  /// 分享链接到朋友圈
  Future<bool> shareToMoments({
    required String title,
    String description = '',
    required String url,
    Uint8List? thumbnail,
  }) async {
    return _shareWebPage(
      title: title,
      description: description,
      url: url,
      thumbnail: thumbnail,
      scene: fluwx.WeChatScene.timeline,
    );
  }

  /// 分享图片到微信好友
  Future<bool> shareImageToFriend({
    required Uint8List imageData,
    Uint8List? thumbnail,
  }) async {
    return _shareImage(
      imageData: imageData,
      thumbnail: thumbnail,
      scene: fluwx.WeChatScene.session,
    );
  }

  /// 分享图片到朋友圈
  Future<bool> shareImageToMoments({
    required Uint8List imageData,
    Uint8List? thumbnail,
  }) async {
    return _shareImage(
      imageData: imageData,
      thumbnail: thumbnail,
      scene: fluwx.WeChatScene.timeline,
    );
  }

  // ==================== 内部方法 ====================

  Future<bool> _shareWebPage({
    required String title,
    required String description,
    required String url,
    Uint8List? thumbnail,
    required fluwx.WeChatScene scene,
  }) async {
    if (!_isInitialized) {
      AppLogger.warning('WeChat SDK not initialized');
      return false;
    }

    final installed = await isWeChatInstalled();
    if (!installed) {
      AppLogger.warning('WeChat not installed');
      return false;
    }

    try {
      final model = fluwx.WeChatShareWebPageModel(
        url,
        title: title,
        description: description,
        thumbnail: thumbnail != null
            ? fluwx.WeChatImage.binary(thumbnail)
            : null,
        scene: scene,
      );

      final result = await _fluwx.share(model);
      AppLogger.info('WeChat share result: $result');
      return result;
    } catch (e) {
      AppLogger.error('WeChat share failed', e);
      return false;
    }
  }

  Future<bool> _shareImage({
    required Uint8List imageData,
    Uint8List? thumbnail,
    required fluwx.WeChatScene scene,
  }) async {
    if (!_isInitialized) {
      AppLogger.warning('WeChat SDK not initialized');
      return false;
    }

    final installed = await isWeChatInstalled();
    if (!installed) {
      AppLogger.warning('WeChat not installed');
      return false;
    }

    try {
      final model = fluwx.WeChatShareImageModel(
        fluwx.WeChatImage.binary(imageData),
        thumbnail: thumbnail != null
            ? fluwx.WeChatImage.binary(thumbnail)
            : null,
        scene: scene,
      );

      final result = await _fluwx.share(model);
      AppLogger.info('WeChat image share result: $result');
      return result;
    } catch (e) {
      AppLogger.error('WeChat image share failed', e);
      return false;
    }
  }
}
