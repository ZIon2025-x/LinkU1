import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'core/design/app_theme.dart';
import 'core/design/scroll_behavior.dart';
import 'core/router/app_router.dart';
import 'core/utils/deep_link_handler.dart';
import 'core/utils/logger.dart';
import 'data/services/websocket_service.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/notification/bloc/notification_bloc.dart';
import 'features/settings/bloc/settings_bloc.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/task_repository.dart';
import 'data/repositories/user_repository.dart';
import 'data/repositories/flea_market_repository.dart';
import 'data/repositories/task_expert_repository.dart';
import 'data/repositories/forum_repository.dart';
import 'data/repositories/leaderboard_repository.dart';
import 'data/repositories/message_repository.dart';
import 'data/repositories/notification_repository.dart';
import 'data/repositories/activity_repository.dart';
import 'data/repositories/coupon_points_repository.dart';
import 'data/repositories/payment_repository.dart';
import 'data/repositories/student_verification_repository.dart';
import 'data/repositories/common_repository.dart';
import 'data/repositories/discovery_repository.dart';
import 'data/services/ai_chat_service.dart';
import 'data/services/api_service.dart';
import 'data/services/push_notification_service.dart';
import 'l10n/app_localizations.dart';

class Link2UrApp extends StatefulWidget {
  const Link2UrApp({super.key});

  @override
  State<Link2UrApp> createState() => _Link2UrAppState();
}

class _Link2UrAppState extends State<Link2UrApp> {
  late final ApiService _apiService;
  late final AuthRepository _authRepository;
  late final TaskRepository _taskRepository;
  late final UserRepository _userRepository;
  late final ForumRepository _forumRepository;
  late final LeaderboardRepository _leaderboardRepository;
  late final MessageRepository _messageRepository;
  late final NotificationRepository _notificationRepository;
  late final ActivityRepository _activityRepository;
  late final DiscoveryRepository _discoveryRepository;
  late final AuthBloc _authBloc;
  late final AppRouter _appRouter;
  final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _authRepository = AuthRepository(apiService: _apiService);
    _taskRepository = TaskRepository(apiService: _apiService);
    _userRepository = UserRepository(apiService: _apiService);
    _forumRepository = ForumRepository(apiService: _apiService);
    _leaderboardRepository = LeaderboardRepository(apiService: _apiService);
    _messageRepository = MessageRepository(apiService: _apiService);
    _notificationRepository = NotificationRepository(apiService: _apiService);
    _activityRepository = ActivityRepository(apiService: _apiService);
    _discoveryRepository = DiscoveryRepository(apiService: _apiService);

    // 创建 AuthBloc 并连接 Token 刷新失败回调
    _authBloc = AuthBloc(authRepository: _authRepository)
      ..add(AuthCheckRequested());
    _apiService.onAuthFailure = () {
      _authBloc.add(AuthForceLogout());
    };

    // 创建路由，传入 AuthBloc 的 refreshListenable 以监听认证状态变化
    _appRouter = AppRouter(
      authBloc: _authBloc,
      navigatorKey: _rootNavigatorKey,
    );
    // 初始化深度链接处理（含 Stripe 支付回调 link2ur://stripe-redirect）
    unawaited(
      DeepLinkHandler.instance
          .initialize(navigatorKey: _rootNavigatorKey)
          .catchError((e, st) => AppLogger.error('DeepLink init failed', e, st)),
    );

    // 推送通知：设置 Router/ApiService 并初始化（Token 上传、点击通知导航）
    PushNotificationService.instance.setRouter(_appRouter.router);
    PushNotificationService.instance.setApiService(_apiService);
    unawaited(
      PushNotificationService.instance
          .init()
          .catchError((e, st) => AppLogger.error('Push notification init failed', e, st)),
    );
  }

  @override
  void dispose() {
    _authBloc.close();
    _apiService.dispose();
    DeepLinkHandler.instance.dispose();
    WebSocketService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiService>.value(value: _apiService),
        RepositoryProvider<AuthRepository>.value(value: _authRepository),
        RepositoryProvider<TaskRepository>.value(value: _taskRepository),
        RepositoryProvider<UserRepository>.value(value: _userRepository),
        RepositoryProvider<ForumRepository>.value(value: _forumRepository),
        RepositoryProvider<LeaderboardRepository>.value(
            value: _leaderboardRepository),
        RepositoryProvider<MessageRepository>.value(
            value: _messageRepository),
        RepositoryProvider<NotificationRepository>.value(
            value: _notificationRepository),
        RepositoryProvider<ActivityRepository>.value(
            value: _activityRepository),
        RepositoryProvider<DiscoveryRepository>.value(
            value: _discoveryRepository),
        // 懒加载：首次访问时创建
        RepositoryProvider<FleaMarketRepository>(
          create: (context) =>
              FleaMarketRepository(apiService: context.read<ApiService>()),
        ),
        RepositoryProvider<TaskExpertRepository>(
          create: (context) =>
              TaskExpertRepository(apiService: context.read<ApiService>()),
        ),
        RepositoryProvider<CouponPointsRepository>(
          create: (context) => CouponPointsRepository(
              apiService: context.read<ApiService>()),
        ),
        RepositoryProvider<PaymentRepository>(
          create: (context) =>
              PaymentRepository(apiService: context.read<ApiService>()),
        ),
        RepositoryProvider<StudentVerificationRepository>(
          create: (context) => StudentVerificationRepository(
              apiService: context.read<ApiService>()),
        ),
        RepositoryProvider<CommonRepository>(
          create: (context) =>
              CommonRepository(apiService: context.read<ApiService>()),
        ),
        RepositoryProvider<AIChatService>(
          create: (context) =>
              AIChatService(apiService: context.read<ApiService>()),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: _authBloc),
          BlocProvider<SettingsBloc>(
            create: (context) => SettingsBloc(userRepository: _userRepository),
          ),
          BlocProvider<NotificationBloc>(
            create: (context) => NotificationBloc(
              notificationRepository: _notificationRepository,
            ),
          ),
        ],
        child: _DeferredBlocLoader(
          child: _WebSplashTimeout(
            child: BlocListener<AuthBloc, AuthState>(
              listenWhen: (prev, curr) {
                final wasChecking = prev.status == AuthStatus.initial ||
                    prev.status == AuthStatus.checking;
                final isChecking = curr.status == AuthStatus.initial ||
                    curr.status == AuthStatus.checking;
                return wasChecking && !isChecking;
              },
              listener: (context, state) {
                FlutterNativeSplash.remove();
              },
              child: BlocBuilder<SettingsBloc, SettingsState>(
                buildWhen: (prev, curr) =>
                    prev.themeMode != curr.themeMode ||
                    prev.locale != curr.locale,
                builder: (context, settingsState) {
                  return GestureDetector(
                    onTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                    child: MaterialApp.router(
                      title: 'Link²Ur',
                      debugShowCheckedModeBanner: false,
                      scrollBehavior: const AppScrollBehavior(),
                      theme: AppTheme.lightTheme,
                      darkTheme: AppTheme.darkTheme,
                      themeMode: settingsState.themeMode,
                      routerConfig: _appRouter.router,
                      localizationsDelegates: const [
                        AppLocalizations.delegate,
                        GlobalMaterialLocalizations.delegate,
                        GlobalWidgetsLocalizations.delegate,
                        GlobalCupertinoLocalizations.delegate,
                      ],
                      supportedLocales: const [
                        Locale('zh', 'CN'),
                        Locale('zh', 'TW'),
                        Locale('en', 'US'),
                      ],
                      locale: _localeFromString(settingsState.locale),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Web 端：2 秒后强制移除 splash，避免 CORS/API 挂起时无限转圈
class _WebSplashTimeout extends StatefulWidget {
  const _WebSplashTimeout({required this.child});
  final Widget child;

  @override
  State<_WebSplashTimeout> createState() => _WebSplashTimeoutState();
}

class _WebSplashTimeoutState extends State<_WebSplashTimeout> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) FlutterNativeSplash.remove();
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 延迟加载非关键 BLoC 数据，避免阻塞首帧渲染
/// 对齐 iOS：60 秒轮询未读数 + 应用恢复前台时刷新（不依赖后端 WebSocket 推送）
class _DeferredBlocLoader extends StatefulWidget {
  const _DeferredBlocLoader({required this.child});
  final Widget child;

  @override
  State<_DeferredBlocLoader> createState() => _DeferredBlocLoaderState();
}

class _DeferredBlocLoaderState extends State<_DeferredBlocLoader>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 延迟到首帧渲染完成后再触发非关键数据加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SettingsBloc>().add(const SettingsLoadRequested());
      final authState = context.read<AuthBloc>().state;
      if (authState.isAuthenticated) {
        context.read<NotificationBloc>().add(
          const NotificationLoadUnreadNotificationCount(),
        );
        context.read<NotificationBloc>().add(const NotificationStartPolling());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final authState = context.read<AuthBloc>().state;
      if (authState.isAuthenticated) {
        context.read<NotificationBloc>().add(
          const NotificationLoadUnreadNotificationCount(),
        );
        context.read<NotificationBloc>().add(
          const NotificationRefreshListIfLoaded(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, curr) => prev.isAuthenticated != curr.isAuthenticated,
      listener: (context, state) {
        if (state.isAuthenticated) {
          context.read<NotificationBloc>().add(const NotificationStartPolling());
        } else {
          context.read<NotificationBloc>().add(const NotificationStopPolling());
        }
      },
      child: widget.child,
    );
  }
}

Locale _localeFromString(String s) {
  if (s == 'zh_Hant') {
    return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
  }
  if (s.contains('-')) {
    final parts = s.split('-');
    return Locale(parts[0], parts[1]);
  }
  if (s.contains('_')) {
    final parts = s.split('_');
    return Locale(parts[0], parts[1]);
  }
  return Locale(s);
}
