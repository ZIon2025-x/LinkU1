import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons.dart';
import '../bloc/auth_bloc.dart';

/// 忘记密码页
/// 参考iOS 密码重置流程
/// 支持通过邮箱发送验证码重置密码
class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _codeSent = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  int _countdown = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _sendVerificationCode() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !Validators.isValidEmail(email)) return;

    context.read<AuthBloc>().add(
          AuthSendEmailCodeRequested(email: email),
        );
  }

  void _resetPassword() {
    if (!_formKey.currentState!.validate()) return;

    context.read<AuthBloc>().add(AuthResetPasswordRequested(
          email: _emailController.text.trim(),
          code: _codeController.text.trim(),
          newPassword: _passwordController.text,
        ));
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      return _countdown > 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // 验证码发送成功
        if (state.codeSendStatus == CodeSendStatus.sent && !_codeSent) {
          setState(() {
            _codeSent = true;
            _countdown = 60;
          });
          _startCountdown();
        }

        // 密码重置成功
        if (state.resetPasswordStatus == ResetPasswordStatus.success) {
          final navigator = Navigator.of(context);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) navigator.pop();
          });
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final isSendingCode =
              state.codeSendStatus == CodeSendStatus.sending;
          final isResetting =
              state.resetPasswordStatus == ResetPasswordStatus.loading;
          final errorMessage = ErrorLocalizer.localize(
            context,
            state.errorMessage ?? state.resetPasswordMessage,
          );
          final isSuccess =
              state.resetPasswordStatus == ResetPasswordStatus.success;

          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.authForgotPassword),
            ),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: ResponsiveUtils.isDesktop(context)
                        ? 440
                        : double.infinity,
                  ),
                  child: SingleChildScrollView(
                    padding: AppSpacing.allLg,
                    child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 图标
                      const Icon(
                        Icons.lock_reset,
                        size: 64,
                        color: AppColors.primary,
                      ),
                      AppSpacing.vLg,

                      // 说明
                      Text(
                        context.l10n.authResetPasswordDesc,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondaryLight,
                          fontSize: 14,
                        ),
                      ),
                      AppSpacing.vXl,

                      // 成功提示
                      if (isSuccess &&
                          state.resetPasswordMessage != null) ...[
                        Container(
                          padding: AppSpacing.allMd,
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: AppRadius.allMedium,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: AppColors.success, size: 20),
                              AppSpacing.hSm,
                              Expanded(
                                child: Text(
                                  ErrorLocalizer.localize(
                                    context,
                                    state.resetPasswordMessage,
                                  ),
                                  style: const TextStyle(
                                      color: AppColors.success),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.vMd,
                      ],

                      // 错误提示
                      if ((state.errorMessage != null ||
                              state.resetPasswordMessage != null) &&
                          !isSuccess) ...[
                        Container(
                          padding: AppSpacing.allMd,
                          decoration: BoxDecoration(
                            color: AppColors.errorLight,
                            borderRadius: AppRadius.allMedium,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.error, size: 20),
                              AppSpacing.hSm,
                              Expanded(
                                child: Text(
                                  errorMessage,
                                  style: const TextStyle(
                                      color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.vMd,
                      ],

                      // 邮箱
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_codeSent,
                        decoration: InputDecoration(
                          labelText: context.l10n.authEmail,
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.allMedium,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.l10n.authPleaseEnterEmail;
                          }
                          if (!Validators.isValidEmail(value.trim())) {
                            return context.l10n.authEmailFormatInvalid;
                          }
                          return null;
                        },
                      ),
                      AppSpacing.vMd,

                      // 发送验证码按钮
                      if (!_codeSent) ...[
                        PrimaryButton(
                          text: context.l10n.authSendCode,
                          isLoading: isSendingCode,
                          onPressed:
                              isSendingCode ? null : _sendVerificationCode,
                        ),
                      ] else ...[
                        // 验证码
                        TextFormField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: context.l10n.authVerificationCode,
                            prefixIcon: const Icon(Icons.pin),
                            suffixIcon: TextButton(
                              onPressed: _countdown > 0
                                  ? null
                                  : _sendVerificationCode,
                              child: Text(
                                _countdown > 0
                                    ? context.l10n.authResendCountdown(_countdown)
                                    : context.l10n.authResendCode,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.allMedium,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return context.l10n.authEnterCode;
                            }
                            return null;
                          },
                        ),
                        AppSpacing.vMd,

                        // 新密码
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: context.l10n.authNewPassword,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() =>
                                    _obscurePassword = !_obscurePassword);
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.allMedium,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return context.l10n.authEnterNewPassword;
                            }
                            if (value.length < 8) {
                              return context.l10n.authPasswordMinLength;
                            }
                            return null;
                          },
                        ),
                        AppSpacing.vMd,

                        // 确认密码
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: context.l10n.authConfirmNewPassword,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() =>
                                    _obscureConfirm = !_obscureConfirm);
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.allMedium,
                            ),
                          ),
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return context.l10n.authPasswordsDoNotMatch;
                            }
                            return null;
                          },
                        ),
                        AppSpacing.vLg,

                        // 重置按钮
                        PrimaryButton(
                          text: context.l10n.authResetPassword,
                          isLoading: isResetting,
                          onPressed: isResetting ? null : _resetPassword,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
            ),
          );
        },
      ),
    );
  }
}
