import 'dart:async';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_select_sheet.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/responsive.dart';
import '../bloc/auth_bloc.dart';

/// 登录页面
/// 参考iOS LoginView.swift — 品牌渐变背景 + 毛玻璃卡片 + 序列动画
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  final _invitationCodeController = TextEditingController();

  bool _obscurePassword = true;
  LoginMethod _loginMethod = LoginMethod.password;
  bool _showSessionExpiredBanner = false;
  bool _agreeTerms = false;

  /// 手机区号选择
  static const _phoneCodes = [
    ('🇬🇧', '+44', 'UK'),
    ('🇫🇷', '+33', 'France'),
    ('🇩🇪', '+49', 'Germany'),
    ('🇪🇸', '+34', 'Spain'),
    ('🇮🇹', '+39', 'Italy'),
    ('🇳🇱', '+31', 'Netherlands'),
    ('🇧🇪', '+32', 'Belgium'),
    ('🇦🇹', '+43', 'Austria'),
    ('🇮🇪', '+353', 'Ireland'),
    ('🇵🇹', '+351', 'Portugal'),
    ('🇬🇷', '+30', 'Greece'),
    ('🇸🇪', '+46', 'Sweden'),
    ('🇩🇰', '+45', 'Denmark'),
    ('🇫🇮', '+358', 'Finland'),
    ('🇳🇴', '+47', 'Norway'),
    ('🇵🇱', '+48', 'Poland'),
    ('🇨🇿', '+420', 'Czech'),
    ('🇨🇭', '+41', 'Switzerland'),
  ];
  int _selectedPhoneCodeIndex = 0; // default UK
  late TapGestureRecognizer _termsTapRecognizer;
  late TapGestureRecognizer _privacyTapRecognizer;

  // ---- 倒计时 ----
  int _countdown = 0;
  Timer? _countdownTimer;

  // ---- 动画 ----
  late final AnimationController _animController;
  late final Animation<double> _logoScale;
  late final Animation<double> _fadeIn;
  // 背景流动渐变 — 缓慢循环，极低开销
  late final AnimationController _bgAnimController;

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

    // 协议链接手势
    _termsTapRecognizer = TapGestureRecognizer()
      ..onTap = () => launchUrl(Uri.parse('https://link2ur.com/terms'));
    _privacyTapRecognizer = TapGestureRecognizer()
      ..onTap = () => launchUrl(Uri.parse('https://link2ur.com/privacy'));

    // 启动
    _animController.forward();

    // 如果是因为会话过期被重定向到登录页，显示横幅提示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authState = context.read<AuthBloc>().state;
      if (authState.sessionExpired) {
        setState(() => _showSessionExpiredBanner = true);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animController.dispose();
    _bgAnimController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    _invitationCodeController.dispose();
    _termsTapRecognizer.dispose();
    _privacyTapRecognizer.dispose();
    super.dispose();
  }

  // ---- 业务逻辑 ----

  void _onLogin({bool skipInvitationCode = false}) {
    if (!_formKey.currentState!.validate()) return;

    // 验证码登录需勾选协议
    if (_loginMethod != LoginMethod.password && !_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.authPleaseAgreeToTerms),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final bloc = context.read<AuthBloc>();
    final invitationCode = skipInvitationCode
        ? null
        : _invitationCodeController.text.trim();

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
          invitationCode: invitationCode,
        ));
        break;
      case LoginMethod.phoneCode:
        final rawPhone = _emailController.text.trim();
        final localNumber = rawPhone.startsWith('0') ? rawPhone.substring(1) : rawPhone;
        final code = _phoneCodes[_selectedPhoneCodeIndex].$2;
        final fullPhone = '$code$localNumber';
        bloc.add(AuthLoginWithPhoneRequested(
          phone: fullPhone,
          code: _codeController.text.trim(),
          invitationCode: invitationCode,
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
              ? context.l10n.authPhonePlaceholder
              : context.l10n.authEnterEmailPlaceholder),
        ),
      );
      return;
    }
    if (_loginMethod == LoginMethod.emailCode) {
      context.read<AuthBloc>().add(AuthSendEmailCodeRequested(email: input));
    } else {
      // 去掉前导0后拼接所选区号
      final localNumber = input.startsWith('0') ? input.substring(1) : input;
      final code = _phoneCodes[_selectedPhoneCodeIndex].$2;
      final fullPhone = '$code$localNumber';
      context.read<AuthBloc>().add(AuthSendPhoneCodeRequested(phone: fullPhone));
    }
  }

  void _showPhoneCodePicker(bool isDark) async {
    final options = [
      for (int i = 0; i < _phoneCodes.length; i++)
        SelectOption(
          value: i,
          label: '${_phoneCodes[i].$1}  ${_phoneCodes[i].$2}  ${_phoneCodes[i].$3}',
        ),
    ];
    final result = await showAppSelectSheet<int>(
      context: context,
      options: options,
      value: _selectedPhoneCodeIndex,
      title: context.l10n.authSelectCountryCode,
    );
    if (result != null && result.value != _selectedPhoneCodeIndex) {
      setState(() => _selectedPhoneCodeIndex = result.value);
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _countdown <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
    });
  }

  void _onMethodChanged(LoginMethod method) {
    if (method == _loginMethod) return;
    AppHaptics.selection();
    setState(() {
      _loginMethod = method;
      _emailController.clear();
      _passwordController.clear();
      _codeController.clear();
      _invitationCodeController.clear();
      _agreeTerms = false;
    });
  }

  /// 邀请码无效时弹对话框，让用户选择是否跳过邀请码继续登录
  void _showInvitationCodeErrorDialog() {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.authInvitationCodeInvalidTitle),
        content: Text(l10n.authInvitationCodeInvalidMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _onLogin(skipInvitationCode: true);
            },
            child: Text(l10n.authContinueWithoutInvitation),
          ),
        ],
      ),
    );
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
                tooltip: 'Back',
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
        listenWhen: (prev, curr) =>
            prev.status != curr.status ||
            prev.errorMessage != curr.errorMessage ||
            prev.codeSendStatus != curr.codeSendStatus,
        listener: (context, state) {
          if (state.status == AuthStatus.authenticated) {
            context.go(AppRoutes.main);
          } else if (state.status == AuthStatus.loading) {
            // 用户开始登录操作时隐藏过期横幅
            if (_showSessionExpiredBanner) {
              setState(() => _showSessionExpiredBanner = false);
            }
          } else if (state.hasError) {
            final errMsg = state.errorMessage ?? '';
            if (errMsg.contains('invitation_code_invalid')) {
              // 邀请码无效 — 弹对话框让用户选择是否继续登录
              _showInvitationCodeErrorDialog();
            } else {
              final localizedError =
                  ErrorLocalizer.localize(context, state.errorMessage);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(localizedError),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          } else if (state.codeSendStatus == CodeSendStatus.sent) {
            setState(() => _countdown = 60);
            _startCountdown();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.authCodeSent)),
            );
          }
        },
        buildWhen: (prev, curr) =>
            prev.status != curr.status ||
            prev.errorMessage != curr.errorMessage ||
            prev.codeSendStatus != curr.codeSendStatus,
        builder: (context, state) {
          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Stack(
              children: [
                // 背景
                _buildBackground(isDark),

                // 内容（桌面端约束最大宽度，避免表单过宽）
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
                            const SizedBox(height: 36),

                            // 会话过期横幅提示
                            if (_showSessionExpiredBanner)
                              _buildSessionExpiredBanner(isDark),

                            // 内联错误提示
                            _buildInlineError(state),

                            // 登录卡片
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

  /// 对标iOS: 品牌渐变 + 缓慢流动装饰圆
  Widget _buildBackground(bool isDark) {
    return AnimatedBuilder(
      animation: _bgAnimController,
      builder: (context, child) {
        final t = _bgAnimController.value; // 0→1→0 (reverse)
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
              // 左上装饰圆 — 缓慢漂移
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
              // 右下装饰圆 — 反向漂移
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
              // 中间装饰圆
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

  // ==================== 会话过期横幅 ====================

  Widget _buildSessionExpiredBanner(bool isDark) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.orange.shade900.withValues(alpha: 0.4)
              : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: isDark
                ? Colors.orange.shade700.withValues(alpha: 0.5)
                : Colors.orange.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: isDark
                  ? Colors.orange.shade300
                  : Colors.orange.shade700,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.authSessionExpired,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? Colors.orange.shade200
                      : Colors.orange.shade900,
                  height: 1.3,
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'Close banner',
              child: GestureDetector(
                onTap: () => setState(() => _showSessionExpiredBanner = false),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: isDark
                      ? Colors.orange.shade400
                      : Colors.orange.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 内联错误提示 ====================

  Widget _buildInlineError(AuthState state) {
    final hasError = state.hasError && state.errorMessage != null;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: hasError
          ? Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(25),
                borderRadius: AppRadius.allSmall,
                border: Border.all(color: AppColors.error.withAlpha(76)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ErrorLocalizer.localize(context, state.errorMessage),
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
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

                // 邀请码（仅验证码登录显示）
                if (_loginMethod != LoginMethod.password) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildInvitationCodeField(isDark),
                ],

                // 协议勾选（仅验证码登录显示）
                if (_loginMethod != LoginMethod.password) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildTermsCheckbox(isDark),
                ],

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
            child: Semantics(
              button: true,
              label: 'Select login method',
              child: GestureDetector(
                onTap: () => _onMethodChanged(method),
                child: Container(
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
                    _getMethodLabel(method),
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
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==================== 登录方式标签 ====================

  String _getMethodLabel(LoginMethod method) {
    switch (method) {
      case LoginMethod.password:
        return context.l10n.authEmailPassword;
      case LoginMethod.emailCode:
        return context.l10n.authEmailCode;
      case LoginMethod.phoneCode:
        return context.l10n.authPhoneCode;
    }
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
          label: context.l10n.authEmail,
          placeholder: context.l10n.authEnterEmailOrId,
          icon: Icons.person_outlined,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          isDark: isDark,
          validator: (v) => Validators.validateEmail(v, l10n: context.l10n),
        ),
        const SizedBox(height: AppSpacing.md),
        _StyledTextField(
          controller: _passwordController,
          label: context.l10n.authPasswordLabel,
          placeholder: context.l10n.authPasswordPlaceholder,
          icon: Icons.lock_outlined,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          isDark: isDark,
          validator: (v) => (v == null || v.isEmpty) ? context.l10n.validatorPasswordRequired : null,
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
            tooltip: 'Toggle password visibility',
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
          label: context.l10n.authEmail,
          placeholder: context.l10n.authEnterEmailPlaceholder,
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          isDark: isDark,
          validator: (v) => Validators.validateEmail(v, l10n: context.l10n),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _StyledTextField(
                controller: _codeController,
                label: context.l10n.authVerificationCode,
                placeholder: context.l10n.authCodePlaceholder,
                icon: Icons.pin_outlined,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                isDark: isDark,
                validator: (v) => Validators.validateVerificationCode(v, l10n: context.l10n),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.authPhone,
              style: AppTypography.subheadline.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 可选区号
                GestureDetector(
                  onTap: () => _showPhoneCodePicker(isDark),
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : AppColors.backgroundLight,
                      borderRadius: AppRadius.allMedium,
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppColors.dividerLight,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_phoneCodes[_selectedPhoneCodeIndex].$1,
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        Text(
                          _phoneCodes[_selectedPhoneCodeIndex].$2,
                          style: AppTypography.body.copyWith(
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down,
                            size: 20,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // 手机号输入框
                Expanded(
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    style: AppTypography.body.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    decoration: InputDecoration(
                      hintText: context.l10n.authPhonePlaceholder,
                      hintStyle: AppTypography.body.copyWith(
                        color: isDark
                            ? AppColors.textPlaceholderDark
                            : AppColors.textPlaceholderLight,
                      ),
                      prefixIcon: Icon(
                        Icons.phone_outlined,
                        size: 20,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
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
                    validator: (v) => Validators.validateUKPhone(v, l10n: context.l10n),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _StyledTextField(
                controller: _codeController,
                label: context.l10n.authVerificationCode,
                placeholder: context.l10n.authCodePlaceholder,
                icon: Icons.pin_outlined,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                isDark: isDark,
                validator: (v) => Validators.validateVerificationCode(v, l10n: context.l10n),
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
    final isDisabled = isSending || _countdown > 0;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: SizedBox(
        width: 100,
        height: 52,
        child: Material(
          color: isDisabled
              ? (isDark
                  ? AppColors.cardBackgroundDark
                  : AppColors.backgroundLight)
              : AppColors.primary.withValues(alpha: 0.12),
          borderRadius: AppRadius.allMedium,
          child: InkWell(
            onTap: isDisabled ? null : _sendCode,
            borderRadius: AppRadius.allMedium,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: AppRadius.allMedium,
                border: Border.all(
                  color: isDisabled
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
                        _countdown > 0
                            ? context.l10n.authResendCountdown(_countdown)
                            : context.l10n.forumSend,
                        style: AppTypography.caption.copyWith(
                          color: _countdown > 0
                              ? (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight)
                              : AppColors.primary,
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

  // ==================== 邀请码输入框 ====================

  Widget _buildInvitationCodeField(bool isDark) {
    return _StyledTextField(
      controller: _invitationCodeController,
      label: context.l10n.authInvitationCodeOptional,
      placeholder: context.l10n.authInvitationCodeHint,
      icon: Icons.card_giftcard_outlined,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.done,
      isDark: isDark,
    );
  }

  // ==================== 同意条款 ====================

  Widget _buildTermsCheckbox(bool isDark) {
    return Semantics(
      button: true,
      label: 'Toggle terms agreement',
      child: GestureDetector(
        onTap: () {
          AppHaptics.selection();
          setState(() => _agreeTerms = !_agreeTerms);
        },
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: _agreeTerms ? AppColors.primary : Colors.transparent,
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
                      recognizer: _termsTapRecognizer,
                    ),
                    TextSpan(text: context.l10n.authAnd),
                    TextSpan(
                      text: context.l10n.authPrivacyPolicy,
                      style: AppTypography.subheadline.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      recognizer: _privacyTapRecognizer,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 登录按钮 ====================

  /// 对标iOS: 渐变 + 高光叠层 + 双重阴影
  Widget _buildGradientLoginButton(AuthState state) {
    final isDisabled = state.isLoading;
    return Semantics(
      button: true,
      label: 'Log in',
      child: GestureDetector(
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
                  context.l10n.authForgotPasswordQuestion,
                  style: AppTypography.subheadline.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push(AppRoutes.register),
                child: Text(
                  context.l10n.authRegisterNewAccount,
                  style: AppTypography.subheadline.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

        const SizedBox(height: AppSpacing.sm),

        // 提示（窄屏时“Login with verification code”可换行，避免溢出）
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
            Flexible(
              child: Semantics(
                button: true,
                label: 'Use verification code',
                child: GestureDetector(
                  onTap: () => _onMethodChanged(LoginMethod.emailCode),
                  child: Text(
                    l10n.authNoAccountUseCode,
                    style: AppTypography.subheadline.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    softWrap: true,
                  ),
                ),
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
    this.textInputAction,
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
  final TextInputAction? textInputAction;
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
          textInputAction: textInputAction,
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
  emailCode('邮箱登录'),
  phoneCode('手机登录');

  const LoginMethod(this.label);
  final String label;
}

