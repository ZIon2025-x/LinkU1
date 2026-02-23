part of 'auth_bloc.dart';

/// 认证事件基类
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// 检查登录状态
class AuthCheckRequested extends AuthEvent {}

/// 邮箱密码登录
class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  @override
  List<Object> get props => [email, password];
}

/// 邮箱验证码登录
class AuthLoginWithCodeRequested extends AuthEvent {
  const AuthLoginWithCodeRequested({
    required this.email,
    required this.code,
  });

  final String email;
  final String code;

  @override
  List<Object> get props => [email, code];
}

/// 手机验证码登录
class AuthLoginWithPhoneRequested extends AuthEvent {
  const AuthLoginWithPhoneRequested({
    required this.phone,
    required this.code,
  });

  final String phone;
  final String code;

  @override
  List<Object> get props => [phone, code];
}

/// 注册
class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({
    required this.email,
    required this.password,
    required this.name,
    this.invitationCode,
  });

  final String email;
  final String password;
  final String name;
  /// 邀请码或8位邀请人用户ID（选填）
  final String? invitationCode;

  @override
  List<Object?> get props => [email, password, name, invitationCode];
}

/// 登出
class AuthLogoutRequested extends AuthEvent {}

/// 强制登出（Token刷新失败时由 ApiService 触发）
class AuthForceLogout extends AuthEvent {}

/// 发送邮箱验证码
class AuthSendEmailCodeRequested extends AuthEvent {
  const AuthSendEmailCodeRequested({required this.email});

  final String email;

  @override
  List<Object> get props => [email];
}

/// 发送手机验证码
class AuthSendPhoneCodeRequested extends AuthEvent {
  const AuthSendPhoneCodeRequested({required this.phone});

  final String phone;

  @override
  List<Object> get props => [phone];
}

/// 用户信息更新
class AuthUserUpdated extends AuthEvent {
  const AuthUserUpdated({required this.user});

  final User user;

  @override
  List<Object> get props => [user];
}

/// 重置密码（通过邮件链接中的 token）
class AuthResetPasswordRequested extends AuthEvent {
  const AuthResetPasswordRequested({
    required this.token,
    required this.newPassword,
  });

  final String token;
  final String newPassword;

  @override
  List<Object> get props => [token, newPassword];
}
