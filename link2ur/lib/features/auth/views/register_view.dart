import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/validators.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/responsive.dart';
import '../bloc/auth_bloc.dart';

/// 注册页面
/// 对标登录页 LoginView 的 UIUX — 品牌渐变背景 + 毛玻璃卡片 + 序列动画
class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _codeController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeTerms = false;

  // ---- 动画 ----
  late AnimationController _animController;
  late Animation<double> _logoScale;
  late Animation<double> _fadeIn;
  // 背景流动渐变
  late AnimationController _bgAnimController;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _bgAnimController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  // ---- 业务逻辑 ----

  void _onRegister() {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.authPleaseAgreeToTerms)),
      );
      return;
    }

    context.read<AuthBloc>().add(AuthRegisterRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          code: _codeController.text.trim().isNotEmpty
              ? _codeController.text.trim()
              : null,
        ));
  }

  void _sendCode() {
    final email = _emailController.text.trim();
    if (Validators.validateEmail(email) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.authPleaseEnterValidEmail)),
      );
      return;
    }
    AppHaptics.selection();
    context.read<AuthBloc>().add(AuthSendEmailCodeRequested(email: email));
  }

  // ---- 构建 ----

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (prev, curr) =>
            prev.status != curr.status ||
            prev.errorMessage != curr.errorMessage ||
            prev.codeSendStatus != curr.codeSendStatus,
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
              SnackBar(content: Text(context.l10n.authCodeSent)),
            );
          }
        },
        buildWhen: (prev, curr) =>
            prev.status != curr.status ||
            prev.codeSendStatus != curr.codeSendStatus,
        builder: (context, state) {
          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Stack(
              children: [
                // 品牌渐变背景（同登录页）
                _buildBackground(isDark),

                // 内容（桌面端约束最大宽度）
                SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: ResponsiveUtils.isDesktop(context)
                            ? 440
                            : double.infinity,
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.lg,
                        ),
                        child: FadeTransition(
                        opacity: _fadeIn,
                        child: Column(
                          children: [
                            // Logo + 品牌名
                            _buildLogoSection(isDark),
                            const SizedBox(height: 32),

                            // 注册卡片
                            _buildFormCard(isDark, state),
                          ],
                        ),
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

  Widget _buildBackground(bool isDark) {
    return AnimatedBuilder(
      animation: _bgAnimController,
      builder: (context, child) {
        final t = _bgAnimController.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [AppColors.backgroundDark, AppColors.authDark]
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
              Positioned(
                left: -180 + t * 30,
                top: -350 + t * 20,
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
              Positioned(
                right: -80 - t * 25,
                bottom: -100 + t * 15,
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
              Positioned(
                left: 0,
                right: 0,
                top: -100 + t * 10,
                child: Center(
                  child: Container(
                    width: 200 + t * 20,
                    height: 200 + t * 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: isDark ? 0.03 : 0.04),
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
      },
    );
  }

  // ==================== Logo 区域 ====================

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
              Container(
                width: 120,
                height: 120,
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
              Container(
                width: 90,
                height: 90,
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
              ClipOval(
                child: Image.asset(
                  AppAssets.logo,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.link,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.l10n.authCreateAccount,
            style: AppTypography.largeTitle.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.l10n.authRegisterSubtitle,
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
                // 用户名
                _buildStyledTextField(
                  controller: _nameController,
                  label: context.l10n.authUsername,
                  placeholder: context.l10n.authEnterUsername,
                  icon: Icons.person_outlined,
                  isDark: isDark,
                  validator: (v) => Validators.validateUsername(v, l10n: context.l10n),
                ),
                const SizedBox(height: AppSpacing.md),

                // 邮箱
                _buildStyledTextField(
                  controller: _emailController,
                  label: context.l10n.authEmail,
                  placeholder: context.l10n.authEnterEmailPlaceholder,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  isDark: isDark,
                  validator: (v) => Validators.validateEmail(v, l10n: context.l10n),
                ),
                const SizedBox(height: AppSpacing.md),

                // 验证码
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildStyledTextField(
                        controller: _codeController,
                        label: context.l10n.authVerificationCode,
                        placeholder: context.l10n.authCodePlaceholder,
                        icon: Icons.pin_outlined,
                        keyboardType: TextInputType.number,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _buildSendCodeButton(state, isDark),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // 密码
                _buildStyledTextField(
                  controller: _passwordController,
                  label: context.l10n.authPasswordLabel,
                  placeholder: context.l10n.authPasswordRequirement,
                  icon: Icons.lock_outlined,
                  obscureText: _obscurePassword,
                  isDark: isDark,
                  validator: (v) => Validators.validatePassword(v, l10n: context.l10n),
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
                // 密码强度条
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _passwordController,
                  builder: (context, value, child) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return _PasswordStrengthBar(
                      password: value.text,
                      isDark: isDark,
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // 确认密码
                _buildStyledTextField(
                  controller: _confirmPasswordController,
                  label: context.l10n.authConfirmPassword,
                  placeholder: context.l10n.authConfirmPasswordPlaceholder,
                  icon: Icons.lock_outlined,
                  obscureText: _obscureConfirmPassword,
                  isDark: isDark,
                  validator: (value) => Validators.validateConfirmPassword(
                    value,
                    _passwordController.text,
                    l10n: context.l10n,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      size: 20,
                    ),
                    onPressed: () => setState(
                        () => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // 同意条款
                _buildTermsCheckbox(isDark),
                const SizedBox(height: AppSpacing.lg),

                // 注册按钮
                _buildGradientRegisterButton(state),
                const SizedBox(height: AppSpacing.md),

                // 已有账号
                _buildBottomLinks(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 精美输入框 ====================

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
  }) {
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
          onChanged: onChanged,
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

  // ==================== 发送验证码按钮 ====================

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
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Text(
                        context.l10n.forumSend,
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

  // ==================== 同意条款 ====================

  Widget _buildTermsCheckbox(bool isDark) {
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        setState(() => _agreeTerms = !_agreeTerms);
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 自定义复选框
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: _agreeTerms
                  ? AppColors.primary
                  : Colors.transparent,
              border: Border.all(
                color: _agreeTerms
                    ? AppColors.primary
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.3)
                        : AppColors.textSecondaryLight.withValues(alpha: 0.4)),
                width: 1.5,
              ),
              boxShadow: _agreeTerms
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: _agreeTerms
                ? const Icon(Icons.check, size: 15, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: context.l10n.authIAgreePrefix,
                style: AppTypography.subheadline.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                children: [
                  TextSpan(
                    text: context.l10n.authTermsOfService,
                    style: AppTypography.subheadline.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: context.l10n.authAnd),
                  TextSpan(
                    text: context.l10n.authPrivacyPolicy,
                    style: AppTypography.subheadline.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 注册按钮 ====================

  Widget _buildGradientRegisterButton(AuthState state) {
    final isDisabled = state.isLoading || !_agreeTerms;
    return GestureDetector(
      onTap: isDisabled ? null : _onRegister,
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
                            context.l10n.authCreateAccount,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          context.l10n.authAlreadyHaveAccount,
          style: AppTypography.subheadline.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        GestureDetector(
          onTap: () => context.pop(),
          child: Text(
            context.l10n.authLoginNow,
            style: AppTypography.subheadline.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// 密码强度指示条 — 渐变色 + 动画宽度
class _PasswordStrengthBar extends StatelessWidget {
  const _PasswordStrengthBar({
    required this.password,
    required this.isDark,
  });

  final String password;
  final bool isDark;

  /// 0 = 弱, 1 = 中, 2 = 强, 3 = 非常强
  int get _strength {
    int score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score++;
    return (score - 1).clamp(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    final strength = _strength;
    final labels = ['弱', '中', '强', '很强'];
    final gradients = [
      AppColors.gradientRed,
      AppColors.gradientOrange,
      AppColors.gradientPrimary,
      AppColors.gradientEmerald,
    ];
    final fraction = (strength + 1) / 4;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 进度条
          ClipRRect(
            borderRadius: AppRadius.allSmall,
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  // 背景
                  Container(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.dividerLight,
                  ),
                  // 填充 — 动画宽度
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: fraction),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value,
                        child: child,
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradients[strength]),
                        borderRadius: AppRadius.allSmall,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            labels[strength],
            style: AppTypography.caption2.copyWith(
              color: gradients[strength].first,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
