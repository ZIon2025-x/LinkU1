import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
import 'features/auth/bloc/auth_bloc.dart';
import 'features/notification/bloc/notification_bloc.dart';
import 'features/settings/bloc/settings_bloc.dart';

/// Assembles all repository & bloc providers used across the app.
///
/// Keeps [Link2UrApp] focused on UI (MaterialApp.router, theme, locale)
/// while this file owns dependency wiring. If a DI framework (e.g. get_it)
/// is introduced later, only this file needs to change.
class AppProviders extends StatelessWidget {
  const AppProviders({
    super.key,
    required this.apiService,
    required this.authRepository,
    required this.taskRepository,
    required this.userRepository,
    required this.forumRepository,
    required this.leaderboardRepository,
    required this.messageRepository,
    required this.notificationRepository,
    required this.activityRepository,
    required this.discoveryRepository,
    required this.authBloc,
    required this.child,
  });

  final ApiService apiService;
  final AuthRepository authRepository;
  final TaskRepository taskRepository;
  final UserRepository userRepository;
  final ForumRepository forumRepository;
  final LeaderboardRepository leaderboardRepository;
  final MessageRepository messageRepository;
  final NotificationRepository notificationRepository;
  final ActivityRepository activityRepository;
  final DiscoveryRepository discoveryRepository;
  final AuthBloc authBloc;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiService>.value(value: apiService),
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<TaskRepository>.value(value: taskRepository),
        RepositoryProvider<UserRepository>.value(value: userRepository),
        RepositoryProvider<ForumRepository>.value(value: forumRepository),
        RepositoryProvider<LeaderboardRepository>.value(
            value: leaderboardRepository),
        RepositoryProvider<MessageRepository>.value(
            value: messageRepository),
        RepositoryProvider<NotificationRepository>.value(
            value: notificationRepository),
        RepositoryProvider<ActivityRepository>.value(
            value: activityRepository),
        RepositoryProvider<DiscoveryRepository>.value(
            value: discoveryRepository),
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
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<SettingsBloc>(
            create: (context) => SettingsBloc(userRepository: userRepository),
          ),
          BlocProvider<NotificationBloc>(
            create: (context) => NotificationBloc(
              notificationRepository: notificationRepository,
            ),
          ),
        ],
        child: child,
      ),
    );
  }
}
