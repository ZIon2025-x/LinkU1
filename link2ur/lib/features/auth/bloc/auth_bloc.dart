import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../data/models/user.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../core/utils/logger.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// 认证Bloc
/// 参考iOS AuthViewModel.swift
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required AuthRepository authRepository,
  })  : _authRepository = authRepository,
        super(const AuthState()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLoginWithCodeRequested>(_onLoginWithCodeRequested);
    on<AuthLoginWithPhoneRequested>(_onLoginWithPhoneRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSendEmailCodeRequested>(_onSendEmailCodeRequested);
    on<AuthSendPhoneCodeRequested>(_onSendPhoneCodeRequested);
    on<AuthUserUpdated>(_onUserUpdated);
  }

  final AuthRepository _authRepository;

  /// 检查登录状态
  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.checking));

    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
        ));
        AppLogger.info('User authenticated: ${user.id}');
      } else {
        emit(state.copyWith(status: AuthStatus.unauthenticated));
        AppLogger.info('User not authenticated');
      }
    } catch (e) {
      AppLogger.error('Auth check failed', e);
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  /// 邮箱密码登录
  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      status: AuthStatus.loading,
      errorMessage: null,
    ));

    try {
      final user = await _authRepository.login(
        email: event.email,
        password: event.password,
      );

      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
      ));
    } on AuthException catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      ));
    } catch (e) {
      AppLogger.error('Login failed', e);
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: '登录失败，请重试',
      ));
    }
  }

  /// 邮箱验证码登录
  Future<void> _onLoginWithCodeRequested(
    AuthLoginWithCodeRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      status: AuthStatus.loading,
      errorMessage: null,
    ));

    try {
      final user = await _authRepository.loginWithCode(
        email: event.email,
        code: event.code,
      );

      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
      ));
    } on AuthException catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      ));
    } catch (e) {
      AppLogger.error('Login with code failed', e);
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: '登录失败，请重试',
      ));
    }
  }

  /// 手机验证码登录
  Future<void> _onLoginWithPhoneRequested(
    AuthLoginWithPhoneRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      status: AuthStatus.loading,
      errorMessage: null,
    ));

    try {
      final user = await _authRepository.loginWithPhoneCode(
        phone: event.phone,
        code: event.code,
      );

      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
      ));
    } on AuthException catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      ));
    } catch (e) {
      AppLogger.error('Login with phone failed', e);
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: '登录失败，请重试',
      ));
    }
  }

  /// 注册
  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      status: AuthStatus.loading,
      errorMessage: null,
    ));

    try {
      final user = await _authRepository.register(
        email: event.email,
        password: event.password,
        name: event.name,
        code: event.code,
      );

      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
      ));
    } on AuthException catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      ));
    } catch (e) {
      AppLogger.error('Register failed', e);
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: '注册失败，请重试',
      ));
    }
  }

  /// 登出
  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  /// 发送邮箱验证码
  Future<void> _onSendEmailCodeRequested(
    AuthSendEmailCodeRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      codeSendStatus: CodeSendStatus.sending,
      errorMessage: null,
    ));

    try {
      await _authRepository.sendEmailCode(event.email);
      emit(state.copyWith(codeSendStatus: CodeSendStatus.sent));
    } on AuthException catch (e) {
      emit(state.copyWith(
        codeSendStatus: CodeSendStatus.error,
        errorMessage: e.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        codeSendStatus: CodeSendStatus.error,
        errorMessage: '发送验证码失败',
      ));
    }
  }

  /// 发送手机验证码
  Future<void> _onSendPhoneCodeRequested(
    AuthSendPhoneCodeRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      codeSendStatus: CodeSendStatus.sending,
      errorMessage: null,
    ));

    try {
      await _authRepository.sendPhoneCode(event.phone);
      emit(state.copyWith(codeSendStatus: CodeSendStatus.sent));
    } on AuthException catch (e) {
      emit(state.copyWith(
        codeSendStatus: CodeSendStatus.error,
        errorMessage: e.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        codeSendStatus: CodeSendStatus.error,
        errorMessage: '发送验证码失败',
      ));
    }
  }

  /// 用户信息更新
  void _onUserUpdated(
    AuthUserUpdated event,
    Emitter<AuthState> emit,
  ) {
    emit(state.copyWith(user: event.user));
  }
}
