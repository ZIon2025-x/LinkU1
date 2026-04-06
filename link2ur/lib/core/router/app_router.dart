import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../utils/logger.dart';
import 'app_routes.dart';
export 'app_routes.dart';
import 'go_router_extensions.dart';
export 'go_router_extensions.dart';
import 'routes/auth_routes.dart';
import 'routes/task_routes.dart';
import 'routes/forum_routes.dart';
import 'routes/flea_market_routes.dart';
import 'routes/leaderboard_routes.dart';
import 'routes/message_routes.dart';
import 'routes/profile_routes.dart';
import 'routes/activity_routes.dart';
import 'routes/task_expert_routes.dart';
import 'routes/expert_dashboard_routes.dart';
import 'routes/expert_team_routes.dart';
import 'routes/info_routes.dart';
import 'routes/payment_routes.dart';
import 'routes/misc_routes.dart';
import 'routes/ai_chat_routes.dart';
import 'routes/personal_service_routes.dart';
import '../../features/auth/bloc/auth_bloc.dart';

import '../../features/main/main_tab_view.dart';
import '../../features/home/views/home_view.dart';
import '../../features/discover/views/discover_view.dart';
import '../../features/message/views/message_view.dart';
import '../../features/profile/views/profile_view.dart';

/// 应用路由配置
class AppRouter {
  AppRouter({
    required AuthBloc authBloc,
    GlobalKey<NavigatorState>? navigatorKey,
  })  : _authBloc = authBloc,
        _navigatorKey = navigatorKey;

  final AuthBloc _authBloc;
  final GlobalKey<NavigatorState>? _navigatorKey;

  /// 检查路径是否需要认证（支持参数化路径匹配）
  static bool _requiresAuth(String location) {
    for (final route in authRequiredRoutes) {
      // 将路由模板转为正则：/chat/:userId → /chat/[^/]+
      final pattern = route.replaceAllMapped(
        RegExp(r':(\w+)'),
        (m) => r'[^/]+',
      );
      if (RegExp('^$pattern\$').hasMatch(location)) return true;
    }
    return false;
  }

  late final GoRouter router = GoRouter(
    navigatorKey: _navigatorKey,
    initialLocation: AppRoutes.main,
    // 监听 AuthBloc 状态变化，自动触发路由重定向（如 Token 失效时跳转登录页）
    refreshListenable: GoRouterBlocRefreshStream(_authBloc.stream),
    redirect: (BuildContext context, GoRouterState state) {
      final path = state.uri.path;

      // 剥离语言前缀：/zh/tasks/123 → /tasks/123, /en/ → /
      // 网站使用 /zh/、/en/ 前缀做多语言，但 App 路由没有语言前缀
      final langMatch = RegExp(r'^/(zh-Hant|zh|en)(/.*)?$').firstMatch(path);
      if (langMatch != null) {
        final remaining = langMatch.group(2);
        return (remaining != null && remaining.isNotEmpty) ? remaining : '/';
      }

      final authState = context.read<AuthBloc>().state;
      final isAuthenticated = authState.isAuthenticated;
      final location = state.matchedLocation;

      // 认证检查中，不做跳转
      if (authState.status == AuthStatus.initial ||
          authState.status == AuthStatus.checking) {
        return null;
      }

      final isAuthRoute = location == AppRoutes.login ||
          location == AppRoutes.register ||
          location == AppRoutes.forgotPassword;

      // 未登录 + 需要认证的路由 → 跳转到登录
      if (!isAuthenticated && _requiresAuth(location)) {
        return AppRoutes.login;
      }

      // 已登录 + 在认证页 → 跳转到首页
      if (isAuthenticated && isAuthRoute) {
        return AppRoutes.main;
      }

      // 已登录 + 未完成身份引导 → 跳转到引导页
      if (isAuthenticated && !location.startsWith('/onboarding')) {
        final user = authState.user;
        if (user != null && !user.onboardingCompleted) {
          return AppRoutes.identityOnboarding;
        }
      }

      // 达人专属路由：非达人用户重定向到达人介绍页
      if (location.startsWith(AppRoutes.expertDashboard) ||
          location.startsWith(AppRoutes.expertProfileEdit)) {
        final isExpert = authState.user?.isExpert ?? false;
        if (!isExpert) {
          return AppRoutes.taskExpertsIntro;
        }
      }

      return null;
    },
    routes: [
      // 主页面（底部导航栏）
      // StatefulShellRoute.indexedStack 原生保持各分支 State，避免手动缓存导致 GlobalKey 冲突
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainTabView(navigationShell: navigationShell),
        branches: [
          // Branch 0: 首页
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.main,
                name: 'main',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HomeView(),
                ),
              ),
            ],
          ),
          // Branch 1: 发现
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/community',
                name: 'community',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: DiscoverView(),
                ),
              ),
            ],
          ),
          // Branch 2: 消息
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messages-tab',
                name: 'messages-tab',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: MessageView(),
                ),
              ),
            ],
          ),
          // Branch 3: 我的
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile-tab',
                name: 'profile-tab',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ProfileView(),
                ),
              ),
            ],
          ),
        ],
      ),

      ...authRoutes,

      ...miscRoutes,

      ...taskRoutes,

      ...fleaMarketRoutes,

      ...taskExpertRoutes,

      ...expertDashboardRoutes,

      ...expertTeamRoutes,

      ...personalServiceRoutes,

      ...forumRoutes,

      ...leaderboardRoutes,

      ...messageRoutes,

      ...profileRoutes,

      ...activityRoutes,

      ...aiChatRoutes(_navigatorKey),

      ...infoRoutes,

      ...paymentRoutes,
    ],
    // 未匹配路由（包括外部深度链接传入的未知路径）→ 跳转首页
    onException: (_, GoRouterState state, GoRouter router) {
      AppLogger.warning('GoRouter - No route matched: ${state.uri}, redirecting to home');
      router.go('/');
    },
  );
}
