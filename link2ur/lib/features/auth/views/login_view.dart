import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/router/app_router.dart';
import '../bloc/auth_bloc.dart';

/// 登录页面
/// 参考iOS LoginView.swift — 品牌渐变背景 + 毛玻璃卡片 + 序列动画
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  bool _obscurePassword = true;
  LoginMethod _loginMethod = LoginMethod.password;

  // ---- 动画 ----
  late AnimationController _animController;
  late Animation<double> _logoScale;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Logo: 0.8→1.0 弹簧缩放
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    // 全局淡入
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // 启动
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  // ---- 业务逻辑 ----

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
    final input = _emailController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_loginMethod == LoginMethod.phoneCode
              ? '请输入手机号'
              : '请输入邮箱地址'),
        ),
      );
      return;
    }
    if (_loginMethod == LoginMethod.emailCode) {
      context.read<AuthBloc>().add(AuthSendEmailCodeRequested(email: input));
    } else {
      context.read<AuthBloc>().add(AuthSendPhoneCodeRequested(phone: input));
    }
  }

  void _onMethodChanged(LoginMethod method) {
    if (method == _loginMethod) return;
    HapticFeedback.selectionClick();
    setState(() {
      _loginMethod = method;
      _emailController.clear();
      _passwordController.clear();
      _codeController.clear();
    });
  }

  // ---- 构建 ----

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          TextButton(
            onPressed: () {
              // 稍后登录 → 直接回到主页
              context.go(AppRoutes.main);
            },
            child: Text(
              l10n.authLoginLater,
              style: AppTypography.body.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
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
          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Stack(
              children: [
                // 背景
                _buildBackground(isDark),

                // 内容
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.lg,
                      ),
                      child: AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) => Opacity(
                          opacity: _fadeIn.value,
                          child: child,
                        ),
                        child: Column(
                          children: [
                            // Logo + 品牌名
                            _buildLogoSection(isDark),
                            const SizedBox(height: 36),

                            // 登录卡片
                            _buildFormCard(isDark, state),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==================== 背景 ====================

  /// 对标iOS: 品牌渐变 + 装饰性弥散圆
  Widget _buildBackground(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppColors.backgroundDark,
                  const Color(0xFF0A0A14),
                ]
              : [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.primary.withValues(alpha: 0.06),
                  AppColors.primary.withValues(alpha: 0.02),
                  AppColors.backgroundLight,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // 左上装饰圆
          Positioned(
            left: -180,
            top: -350,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: isDark ? 0.06 : 0.08),
                    AppColors.primary.withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 右下装饰圆
          Positioned(
            right: -80,
            bottom: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: isDark ? 0.04 : 0.06),
                    AppColors.primary.withValues(alpha: 0.01),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 中间装饰圆
          Positioned(
            left: 0,
            right: 0,
            top: -100,
            child: Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary
                          .withValues(alpha: isDark ? 0.03 : 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Logo 区域 ====================

  /// 对标iOS: 渐变圆 + Logo图 + 弹簧缩放 + 品牌名淡入
  Widget _buildLogoSection(bool isDark) {
    return AnimatedBuilder(
      animation: _logoScale,
      builder: (context, child) => Transform.scale(
        scale: _logoScale.value,
        child: child,
      ),
      child: Column(
        children: [
          // Logo 带光晕
          Stack(
            alignment: Alignment.center,
            children: [
              // 外层光晕
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.primary.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // 渐变圆背景
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: AppColors.gradientPrimary,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
              ),
              // Logo 图片
              ClipOval(
                child: Image.asset(
                  AppAssets.logo,
                  width: 75,
                  height: 75,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.link,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // 品牌名
          Text(
            'Link²Ur',
            style: AppTypography.largeTitle.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.l10n.appTagline,
            style: AppTypography.subheadline.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 表单卡片 ====================

  /// 对标iOS: .ultraThinMaterial 毛玻璃 + 渐变边框 + 阴影
  Widget _buildFormCard(bool isDark, AuthState state) {
    return ClipRRect(
      borderRadius: AppRadius.allLarge,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.75),
            borderRadius: AppRadius.allLarge,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.05),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 分段选择器
                _buildSegmentedPicker(isDark),
                const SizedBox(height: AppSpacing.lg),

                // 输入区域
                _buildInputFields(isDark, state),
                const SizedBox(height: AppSpacing.xl),

                // 登录按钮
                _buildGradientLoginButton(state),
                const SizedBox(height: AppSpacing.md),

                // 底部链接
                _buildBottomLinks(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 分段选择器 ====================

  /// 对标iOS: SegmentedPickerStyle 胶囊分段
  Widget _buildSegmentedPicker(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : AppColors.backgroundLight,
        borderRadius: AppRadius.allSmall,
      ),
      child: Row(
        children: LoginMethod.values.map((method) {
          final isSelected = _loginMethod == method;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onMethodChanged(method),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                          ? AppColors.cardBackgroundDark
                          : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  method.label,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: isSelected
                        ? (isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight)
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==================== 输入区域 ====================

  Widget _buildInputFields(bool isDark, AuthState state) {
    switch (_loginMethod) {
      case LoginMethod.password:
        return _buildPasswordFields(isDark);
      case LoginMethod.emailCode:
        return _buildEmailCodeFields(isDark, state);
      case LoginMethod.phoneCode:
        return _buildPhoneCodeFields(isDark, state);
    }
  }

  /// 密码登录
  Widget _buildPasswordFields(bool isDark) {
    return Column(
      children: [
        _StyledTextField(
          controller: _emailController,
          label: context.l10n.authEmailPassword,
          placeholder: '邮箱 / ID',
          icon: Icons.person_outlined,
          keyboardType: TextInputType.emailAddress,
          isDark: isDark,
          validator: Validators.validateEmail,
        ),
        const SizedBox(height: AppSpacing.md),
        _StyledTextField(
          controller: _passwordController,
          label: '密码',
          placeholder: '请输入密码',
          icon: Icons.lock_outlined,
          obscureText: _obscurePassword,
          isDark: isDark,
          validator: Validators.validatePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      ],
    );
  }

  /// 邮箱验证码
  Widget _buildEmailCodeFields(bool isDark, AuthState state) {
    return Column(
      children: [
        _StyledTextField(
          controller: _emailController,
          label: '邮箱',
          placeholder: '请输入邮箱地址',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          isDark: isDark,
          validator: Validators.validateEmail,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _StyledTextField(
                controller: _codeController,
                label: '验证码',
                placeholder: '请输入验证码',
                icon: Icons.pin_outlined,
                keyboardType: TextInputType.number,
                isDark: isDark,
                validator: Validators.validateVerificationCode,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _buildSendCodeButton(state, isDark),
          ],
        ),
      ],
    );
  }

  /// 手机验证码
  Widget _buildPhoneCodeFields(bool isDark, AuthState state) {
    return Column(
      children: [
        _StyledTextField(
          controller: _emailController,
          label: '手机号',
          placeholder: '请输入手机号',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          isDark: isDark,
          validator: Validators.validatePhone,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _StyledTextField(
                controller: _codeController,
                label: '验证码',
                placeholder: '请输入验证码',
                icon: Icons.pin_outlined,
                keyboardType: TextInputType.number,
                isDark: isDark,
                validator: Validators.validateVerificationCode,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _buildSendCodeButton(state, isDark),
          ],
        ),
      ],
    );
  }

  /// 发送验证码按钮 - 对标iOS精美设计
  Widget _buildSendCodeButton(AuthState state, bool isDark) {
    final isSending = state.codeSendStatus == CodeSendStatus.sending;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: SizedBox(
        width: 100,
        height: 52,
        child: Material(
          color: isSending
              ? (isDark
                  ? AppColors.cardBackgroundDark
                  : AppColors.backgroundLight)
              : AppColors.primary.withValues(alpha: 0.12),
          borderRadius: AppRadius.allMedium,
          child: InkWell(
            onTap: isSending ? null : _sendCode,
            borderRadius: AppRadius.allMedium,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: AppRadius.allMedium,
                border: Border.all(
                  color: isSending
                      ? (isDark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight)
                      : AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Center(
                child: isSending
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Text(
                        '发送',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 登录按钮 ====================

  /// 对标iOS: 渐变 + 高光叠层 + 双重阴影
  Widget _buildGradientLoginButton(AuthState state) {
    final isDisabled = state.isLoading;
    return GestureDetector(
      onTap: isDisabled ? null : _onLogin,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: AppRadius.allMedium,
            gradient: const LinearGradient(
              colors: AppColors.gradientPrimary,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // 高光叠层
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.allMedium,
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              // 内容
              Center(
                child: state.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.l10n.authLogin,
                            style: AppTypography.bodyBold.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 底部链接 ====================

  Widget _buildBottomLinks(bool isDark) {
    final l10n = context.l10n;
    return Column(
      children: [
        // 忘记密码 & 注册
        if (_loginMethod == LoginMethod.password)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => context.push('/forgot-password'),
                child: Text(
                  '忘记密码？',
                  style: AppTypography.subheadline.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push(AppRoutes.register),
                child: Text(
                  '注册新账号',
                  style: AppTypography.subheadline.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

        const SizedBox(height: AppSpacing.sm),

        // 提示
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.authNoAccount,
              style: AppTypography.subheadline.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              l10n.authNoAccountUseCode,
              style: AppTypography.subheadline.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ==================== 统一输入框 ====================

/// 精美输入框组件，对标iOS EnhancedTextField
class _StyledTextField extends StatelessWidget {
  const _StyledTextField({
    required this.controller,
    required this.label,
    required this.placeholder,
    required this.icon,
    required this.isDark,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String placeholder;
  final IconData icon;
  final bool isDark;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.subheadline.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: AppTypography.body.copyWith(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: AppTypography.body.copyWith(
              color: isDark
                  ? AppColors.textPlaceholderDark
                  : AppColors.textPlaceholderLight,
            ),
            prefixIcon: Icon(
              icon,
              size: 20,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : AppColors.backgroundLight,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: AppRadius.allMedium,
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.dividerLight,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.allMedium,
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.dividerLight,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.allMedium,
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppRadius.allMedium,
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppRadius.allMedium,
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 1.5,
              ),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

// ==================== 登录方式枚举 ====================

enum LoginMethod {
  password('密码登录'),
  emailCode('邮箱验证码'),
  phoneCode('手机验证码');

  const LoginMethod(this.label);
  final String label;
}
