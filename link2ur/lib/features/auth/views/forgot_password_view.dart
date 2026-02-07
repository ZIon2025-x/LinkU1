import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons.dart';
import '../../../data/repositories/auth_repository.dart';

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

  bool _isLoading = false;
  bool _codeSent = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  int _countdown = 0;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationCode() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _errorMessage = '请输入邮箱地址');
      return;
    }

    if (!Validators.isValidEmail(_emailController.text.trim())) {
      setState(() => _errorMessage = '请输入有效的邮箱地址');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<AuthRepository>();
      await repo.sendEmailCode(_emailController.text.trim());

      setState(() {
        _codeSent = true;
        _isLoading = false;
        _countdown = 60;
      });

      _startCountdown();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      return _countdown > 0;
    });
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<AuthRepository>();
      await repo.resetPassword(
        email: _emailController.text.trim(),
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      );

      setState(() {
        _isLoading = false;
        _successMessage = '密码重置成功，请使用新密码登录';
      });

      // 延迟后返回登录页
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('忘记密码'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.allLg,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 图标
                Icon(
                  Icons.lock_reset,
                  size: 64,
                  color: AppColors.primary,
                ),
                AppSpacing.vLg,

                // 说明
                Text(
                  '输入您的注册邮箱，我们将发送验证码帮助您重置密码。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontSize: 14,
                  ),
                ),
                AppSpacing.vXl,

                // 成功提示
                if (_successMessage != null) ...[
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
                            _successMessage!,
                            style: const TextStyle(color: AppColors.success),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.vMd,
                ],

                // 错误提示
                if (_errorMessage != null) ...[
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
                            _errorMessage!,
                            style: const TextStyle(color: AppColors.error),
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
                      return '请输入邮箱';
                    }
                    if (!Validators.isValidEmail(value.trim())) {
                      return '邮箱格式不正确';
                    }
                    return null;
                  },
                ),
                AppSpacing.vMd,

                // 发送验证码按钮
                if (!_codeSent) ...[
                  PrimaryButton(
                    text: '发送验证码',
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _sendVerificationCode,
                  ),
                ] else ...[
                  // 验证码
                  TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '验证码',
                      prefixIcon: const Icon(Icons.pin),
                      suffixIcon: TextButton(
                        onPressed: _countdown > 0 ? null : _sendVerificationCode,
                        child: Text(
                          _countdown > 0
                              ? '${_countdown}s 后重发'
                              : '重新发送',
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.allMedium,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入验证码';
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
                      labelText: '新密码',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(
                              () => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.allMedium,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入新密码';
                      }
                      if (value.length < 8) {
                        return '密码至少8位';
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
                      labelText: '确认新密码',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(
                              () => _obscureConfirm = !_obscureConfirm);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.allMedium,
                      ),
                    ),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return '两次输入的密码不一致';
                      }
                      return null;
                    },
                  ),
                  AppSpacing.vLg,

                  // 重置按钮
                  PrimaryButton(
                    text: '重置密码',
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _resetPassword,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
