import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_routes.dart';
import '../page_transitions.dart';
import '../../../features/auth/views/login_view.dart';
import '../../../features/auth/views/register_view.dart';
import '../../../features/auth/views/forgot_password_view.dart';
import '../../../features/onboarding/views/onboarding_view.dart';

/// 认证与引导相关路由（登录、注册、忘记密码、引导页）
List<RouteBase> get authRoutes => [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => FadeScaleTransitionPage(
          key: state.pageKey,
          child: const LoginView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        pageBuilder: (context, state) => FadeScaleTransitionPage(
          key: state.pageKey,
          child: const RegisterView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        pageBuilder: (context, state) => FadeScaleTransitionPage(
          key: state.pageKey,
          child: const ForgotPasswordView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        pageBuilder: (context, state) => FadeScaleTransitionPage(
          key: state.pageKey,
          child: OnboardingView(
            onComplete: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    ];
