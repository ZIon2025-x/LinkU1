import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/utils/validators.dart';
import '../../../core/router/app_router.dart';
import '../bloc/auth_bloc.dart';

/// 登录页面
/// 参考iOS LoginView.swift
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  bool _obscurePassword = true;
  LoginMethod _loginMethod = LoginMethod.password;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onLogin() {
    if (!_formKey.currentState!.validate()) return;

    final bloc = context.read<AuthBloc>();

    switch (_loginMethod) {
      case LoginMethod.password:
        bloc.add(AuthLoginRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ));
        break;
      case LoginMethod.emailCode:
        bloc.add(AuthLoginWithCodeRequested(
          email: _emailController.text.trim(),
          code: _codeController.text.trim(),
        ));
        break;
      case LoginMethod.phoneCode:
        bloc.add(AuthLoginWithPhoneRequested(
          phone: _emailController.text.trim(),
          code: _codeController.text.trim(),
        ));
        break;
    }
  }

  void _sendCode() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入邮箱地址')),
      );
      return;
    }

    if (_loginMethod == LoginMethod.emailCode) {
      context.read<AuthBloc>().add(AuthSendEmailCodeRequested(email: email));
    } else {
      context.read<AuthBloc>().add(AuthSendPhoneCodeRequested(phone: email));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.authenticated) {
            context.go(AppRoutes.main);
          } else if (state.hasError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppColors.error,
              ),
            );
          } else if (state.codeSendStatus == CodeSendStatus.sent) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('验证码已发送')),
            );
          }
        },
        builder: (context, state) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF667eea),
                  Color(0xFF764ba2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: AppSpacing.allXl,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      _buildLogo(),
                      AppSpacing.vXxl,

                      // 登录表单卡片
                      _buildLoginCard(state),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              'L',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        AppSpacing.vMd,
        const Text(
          'Link²Ur',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        AppSpacing.vSm,
        Text(
          '校园任务互助平台',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(AuthState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: AppSpacing.allXl,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        borderRadius: AppRadius.allXlarge,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 登录方式切换
            _buildLoginMethodTabs(),
            AppSpacing.vLg,

            // 邮箱/手机输入框
            TextFormField(
              controller: _emailController,
              keyboardType: _loginMethod == LoginMethod.phoneCode
                  ? TextInputType.phone
                  : TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: _loginMethod == LoginMethod.phoneCode ? '手机号' : '邮箱',
                prefixIcon: Icon(
                  _loginMethod == LoginMethod.phoneCode 
                      ? Icons.phone_outlined 
                      : Icons.email_outlined,
                ),
              ),
              validator: (value) {
                if (_loginMethod == LoginMethod.phoneCode) {
                  return Validators.validatePhone(value);
                }
                return Validators.validateEmail(value);
              },
            ),
            AppSpacing.vMd,

            // 密码或验证码输入框
            if (_loginMethod == LoginMethod.password)
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: '密码',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword 
                          ? Icons.visibility_outlined 
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: Validators.validatePassword,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '验证码',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                      validator: (value) => Validators.validateVerificationCode(value),
                    ),
                  ),
                  AppSpacing.hMd,
                  SizedBox(
                    width: 100,
                    child: SecondaryButton(
                      text: state.codeSendStatus == CodeSendStatus.sending 
                          ? '发送中' 
                          : '发送',
                      onPressed: state.codeSendStatus == CodeSendStatus.sending 
                          ? null 
                          : _sendCode,
                      height: 48,
                    ),
                  ),
                ],
              ),
            AppSpacing.vXl,

            // 登录按钮
            PrimaryButton(
              text: '登录',
              onPressed: _onLogin,
              isLoading: state.isLoading,
            ),
            AppSpacing.vMd,

            // 忘记密码和注册
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextActionButton(
                  text: '忘记密码？',
                  onPressed: () {
                    // TODO: 忘记密码
                  },
                ),
                TextActionButton(
                  text: '注册新账号',
                  onPressed: () {
                    context.push(AppRoutes.register);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginMethodTabs() {
    return Row(
      children: LoginMethod.values.map((method) {
        final isSelected = _loginMethod == method;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _loginMethod = method;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                method.label,
                textAlign: TextAlign.center,
                style: AppTypography.subheadline.copyWith(
                  color: isSelected 
                      ? AppColors.primary 
                      : AppColors.textSecondaryLight,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

enum LoginMethod {
  password('密码登录'),
  emailCode('邮箱验证码'),
  phoneCode('手机验证码');

  const LoginMethod(this.label);
  final String label;
}
