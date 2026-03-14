import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/bloc/auth_bloc.dart';
import '../router/app_routes.dart';

/// 登录守卫：未登录时跳转到登录页，已登录时执行回调
///
/// 用法：
/// ```dart
/// onTap: () => requireAuth(context, () {
///   context.read<SomeBloc>().add(SomeEvent());
/// }),
/// ```
bool requireAuth(BuildContext context, [VoidCallback? onAuthenticated]) {
  final authState = context.read<AuthBloc>().state;
  if (!authState.isAuthenticated) {
    context.push(AppRoutes.login);
    return false;
  }
  onAuthenticated?.call();
  return true;
}
