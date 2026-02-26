import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';
import '../../features/tasks/views/create_task_view.dart' show TaskDraftData;

/// 全局导航防抖：防止快速双击导致同一页面被 push 两次
/// 所有导航方法（go/push）都经过此锁，500ms 内只允许一次导航
class _NavigationThrottle {
  static DateTime _lastNavigationTime = DateTime(2000);
  static const _minInterval = Duration(milliseconds: 500);

  /// 如果距上次导航超过 500ms 返回 true，否则返回 false（丢弃本次导航）
  static bool acquire() {
    final now = DateTime.now();
    if (now.difference(_lastNavigationTime) < _minInterval) {
      return false;
    }
    _lastNavigationTime = now;
    return true;
  }
}

/// 路由扩展方法
extension GoRouterExtension on BuildContext {
  /// 带防抖的 push，防止快速双击导致同一页面被 push 两次
  void safePush(String location, {Object? extra}) {
    if (!_NavigationThrottle.acquire()) return;
    push(location, extra: extra);
  }

  /// 带防抖的 go
  void safeGo(String location, {Object? extra}) {
    if (!_NavigationThrottle.acquire()) return;
    go(location);
  }

  /// 跳转到任务详情
  void goToTaskDetail(int taskId) {
    if (!_NavigationThrottle.acquire()) return;
    push('/tasks/$taskId');
  }

  /// 跳转到创建任务页（可选 AI 草稿预填）
  void goToCreateTask({TaskDraftData? draft}) {
    if (!_NavigationThrottle.acquire()) return;
    push(AppRoutes.createTask, extra: draft);
  }

  /// 跳转到跳蚤市场详情（id 为后端返回的字符串格式，如 S0001）
  void goToFleaMarketDetail(String itemId) {
    if (!_NavigationThrottle.acquire()) return;
    if (itemId.isEmpty) return;
    push('/flea-market/$itemId');
  }

  /// 跳转到达人详情
  void goToTaskExpertDetail(String expertId) {
    if (!_NavigationThrottle.acquire()) return;
    if (expertId.isEmpty) return;
    push('/task-experts/$expertId');
  }

  /// 跳转到帖子详情
  void goToForumPostDetail(int postId) {
    if (!_NavigationThrottle.acquire()) return;
    push('/forum/posts/$postId');
  }

  /// 跳转到聊天
  void goToChat(String userId) {
    if (!_NavigationThrottle.acquire()) return;
    push('/chat/$userId');
  }

  /// 跳转到任务聊天
  void goToTaskChat(int taskId) {
    if (!_NavigationThrottle.acquire()) return;
    push('/task-chat/$taskId');
  }

  /// 跳转到用户资料
  void goToUserProfile(String userId) {
    if (!_NavigationThrottle.acquire()) return;
    push('/user/$userId');
  }

  /// 跳转到排行榜条目详情
  void goToLeaderboardItemDetail(int itemId) {
    if (!_NavigationThrottle.acquire()) return;
    push('/leaderboard/item/$itemId');
  }

  /// 跳转到服务详情
  void goToServiceDetail(int serviceId) {
    if (!_NavigationThrottle.acquire()) return;
    push('/service/$serviceId');
  }

  /// 跳转到论坛分类
  void goToForumCategory(dynamic category) {
    if (!_NavigationThrottle.acquire()) return;
    push('/forum/category/${category.id}', extra: category);
  }

  /// 跳转到VIP购买
  void goToVIPPurchase() {
    if (!_NavigationThrottle.acquire()) return;
    push('/vip/purchase');
  }

  /// 跳转到任务偏好
  void goToTaskPreferences() {
    if (!_NavigationThrottle.acquire()) return;
    push('/profile/task-preferences');
  }

  /// 跳转到我的论坛帖子
  void goToMyForumPosts() {
    if (!_NavigationThrottle.acquire()) return;
    push('/forum/my-posts');
  }

  /// 跳转到任务达人搜索
  void goToTaskExpertSearch() {
    if (!_NavigationThrottle.acquire()) return;
    push('/task-experts/search');
  }

  /// 跳转到统一聊天页（Linker，原 AI 助手入口）
  void goToAIChat() {
    if (!_NavigationThrottle.acquire()) return;
    push(AppRoutes.supportChat);
  }

  /// 跳转到 AI 对话列表
  void goToAIChatList() {
    if (!_NavigationThrottle.acquire()) return;
    push(AppRoutes.aiChatList);
  }

  /// 跳转到 AI 助手聊天
  void goToSupportChat() {
    if (!_NavigationThrottle.acquire()) return;
    push(AppRoutes.supportChat);
  }
}

/// 将 Bloc Stream 转为 GoRouter 可监听的 ChangeNotifier
/// 当 AuthBloc 状态变化时通知 GoRouter 重新评估 redirect
class GoRouterBlocRefreshStream extends ChangeNotifier {
  GoRouterBlocRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
