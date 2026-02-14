import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_links/app_links.dart';
import '../router/app_router.dart';

import 'logger.dart';

/// 深度链接处理器
/// 参考iOS DeepLinkHandler.swift
/// 处理自定义 scheme (link2ur://) 和 Universal Links
class DeepLinkHandler {
  DeepLinkHandler._();

  static final DeepLinkHandler instance = DeepLinkHandler._();

  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  GlobalKey<NavigatorState>? _navigatorKey;

  /// 初始化深度链接处理
  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    _navigatorKey = navigatorKey;
    _appLinks = AppLinks();

    // 处理应用启动时的初始链接
    try {
      final initialUri = await _appLinks!.getInitialLink();
      if (initialUri != null) {
        AppLogger.info('Deep link - Initial: $initialUri');
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      AppLogger.error('Deep link - Failed to get initial link', e);
    }

    // 监听后续的深度链接
    _linkSubscription = _appLinks!.uriLinkStream.listen(
      (Uri uri) {
        AppLogger.info('Deep link - Incoming: $uri');
        _handleDeepLink(uri);
      },
      onError: (Object error) {
        AppLogger.error('Deep link - Stream error', error);
      },
    );
  }

  /// 处理深度链接
  void _handleDeepLink(Uri uri) {
    final context = _navigatorKey?.currentContext;
    if (context == null) {
      AppLogger.warning('Deep link - No navigator context available');
      return;
    }

    final path = uri.path;
    final queryParams = uri.queryParameters;

    AppLogger.info('Deep link - Path: $path, Params: $queryParams');

    try {
      // 根据路径匹配路由
      switch (_getRouteType(path)) {
        case _DeepLinkRoute.task:
          final id = _extractId(path);
          if (id != null) context.safePush('/tasks/$id');
          break;
        case _DeepLinkRoute.forumPost:
          final id = _extractId(path);
          if (id != null) context.safePush('/forum/posts/$id');
          break;
        case _DeepLinkRoute.fleaMarketItem:
          final id = _extractLastSegment(path);
          if (id != null && id.isNotEmpty) context.safePush('/flea-market/$id');
          break;
        case _DeepLinkRoute.userProfile:
          final id = _extractId(path);
          if (id != null) context.push('/user/$id');
          break;
        case _DeepLinkRoute.leaderboard:
          final id = _extractId(path);
          if (id != null) context.push('/leaderboard/$id');
          break;
        case _DeepLinkRoute.activity:
          final id = _extractId(path);
          if (id != null) context.push('/activities/$id');
          break;
        case _DeepLinkRoute.taskExpert:
          final id = _extractId(path);
          if (id != null) context.safePush('/task-experts/$id');
          break;
        case _DeepLinkRoute.unknown:
          AppLogger.warning('Deep link - Unknown route: $path');
          break;
      }
    } catch (e) {
      AppLogger.error('Deep link - Navigation failed', e);
    }
  }

  /// 根据路径匹配路由类型
  _DeepLinkRoute _getRouteType(String path) {
    if (path.startsWith('/tasks/') || path.startsWith('/task/')) {
      return _DeepLinkRoute.task;
    } else if (path.startsWith('/forum/posts/') ||
        path.startsWith('/forum/post/')) {
      return _DeepLinkRoute.forumPost;
    } else if (path.startsWith('/flea-market/') ||
        path.startsWith('/market/')) {
      return _DeepLinkRoute.fleaMarketItem;
    } else if (path.startsWith('/user/') || path.startsWith('/profile/')) {
      return _DeepLinkRoute.userProfile;
    } else if (path.startsWith('/leaderboard/')) {
      return _DeepLinkRoute.leaderboard;
    } else if (path.startsWith('/activity/') ||
        path.startsWith('/activities/')) {
      return _DeepLinkRoute.activity;
    } else if (path.startsWith('/task-expert/') ||
        path.startsWith('/task-experts/')) {
      return _DeepLinkRoute.taskExpert;
    }
    return _DeepLinkRoute.unknown;
  }

  /// 从路径中提取ID
  int? _extractId(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length >= 2) {
      return int.tryParse(segments.last);
    }
    return null;
  }

  /// 提取路径最后一段为字符串（用于跳蚤市场等 id 为 S0001 格式）
  String? _extractLastSegment(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length >= 2) {
      return segments.last;
    }
    return null;
  }

  /// 生成深度链接URL
  static String generateDeepLink({
    required String path,
    Map<String, String>? queryParams,
  }) {
    final uri = Uri(
      scheme: 'link2ur',
      host: 'app',
      path: path,
      queryParameters: queryParams,
    );
    return uri.toString();
  }

  /// 生成分享用的Universal Link
  static String generateUniversalLink({
    required String path,
    Map<String, String>? queryParams,
  }) {
    final uri = Uri(
      scheme: 'https',
      host: 'link2ur.com',
      path: path,
      queryParameters: queryParams,
    );
    return uri.toString();
  }

  /// 释放资源
  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}

enum _DeepLinkRoute {
  task,
  forumPost,
  fleaMarketItem,
  userProfile,
  leaderboard,
  activity,
  taskExpert,
  unknown,
}
