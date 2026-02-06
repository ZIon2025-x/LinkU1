part of 'auth_bloc.dart';

/// 认证状态
enum AuthStatus {
  initial,
  checking,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// 验证码发送状态
enum CodeSendStatus {
  initial,
  sending,
  sent,
  error,
}

/// 认证状态
class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.codeSendStatus = CodeSendStatus.initial,
  });

  final AuthStatus status;
  final User? user;
  final String? errorMessage;
  final CodeSendStatus codeSendStatus;

  /// 是否已认证
  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;

  /// 是否正在加载
  bool get isLoading => status == AuthStatus.loading || status == AuthStatus.checking;

  /// 是否有错误
  bool get hasError => status == AuthStatus.error && errorMessage != null;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    CodeSendStatus? codeSendStatus,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      codeSendStatus: codeSendStatus ?? this.codeSendStatus,
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage, codeSendStatus];
}
