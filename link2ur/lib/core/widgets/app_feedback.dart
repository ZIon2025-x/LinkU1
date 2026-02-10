import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/haptic_feedback.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';

// ============================================================
// AppFeedback — 统一的操作结果反馈工具
// ============================================================

/// 操作反馈类型
enum FeedbackType { success, error, warning, info }

/// 全局操作反馈工具
///
/// 提供三种反馈方式:
/// 1. Toast — 顶部轻提示，自动消失
/// 2. 结果弹窗 — 居中动画弹窗（成功✓/失败✗），适合重要操作
/// 3. SnackBar — 底部提示条，可带操作按钮
class AppFeedback {
  AppFeedback._();

  // ==================== Toast 轻提示 ====================

  /// 显示顶部 Toast 提示
  static void showToast(
    BuildContext context, {
    required String message,
    FeedbackType type = FeedbackType.info,
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        type: type,
        duration: duration,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }

  /// 成功提示
  static void showSuccess(BuildContext context, String message) {
    AppHaptics.success();
    showToast(context, message: message, type: FeedbackType.success);
  }

  /// 错误提示
  static void showError(BuildContext context, String message) {
    AppHaptics.error();
    showToast(
      context,
      message: message,
      type: FeedbackType.error,
      duration: const Duration(seconds: 3),
    );
  }

  /// 警告提示
  static void showWarning(BuildContext context, String message) {
    AppHaptics.warning();
    showToast(context, message: message, type: FeedbackType.warning);
  }

  /// 信息提示
  static void showInfo(BuildContext context, String message) {
    showToast(context, message: message, type: FeedbackType.info);
  }

  // ==================== 结果弹窗 ====================

  /// 显示操作结果弹窗（居中弹出，带动画图标）
  ///
  /// 适用于提交订单、支付成功、删除确认等重要操作完成后的反馈。
  /// [autoDismiss] 为 true 时会自动关闭。
  static Future<void> showResultDialog(
    BuildContext context, {
    required FeedbackType type,
    required String title,
    String? message,
    String? actionText,
    VoidCallback? onAction,
    bool autoDismiss = true,
    Duration autoDismissDuration = const Duration(seconds: 2),
  }) async {
    if (type == FeedbackType.success) {
      AppHaptics.success();
    } else if (type == FeedbackType.error) {
      AppHaptics.error();
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, _) {
        return _ResultDialog(
          animation: animation,
          type: type,
          title: title,
          message: message,
          actionText: actionText,
          onAction: onAction,
          autoDismiss: autoDismiss,
          autoDismissDuration: autoDismissDuration,
        );
      },
    );
  }

  // ==================== SnackBar ====================

  /// 显示底部 SnackBar（可带操作按钮）
  static void showSnackBar(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    FeedbackType type = FeedbackType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final colors = _getTypeColors(type);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(colors.icon, color: Colors.white, size: 20),
              AppSpacing.hSm,
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.footnote.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: colors.background,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.allMedium),
          duration: duration,
          action: actionLabel != null
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: Colors.white,
                  onPressed: onAction ?? () {},
                )
              : null,
        ),
      );
  }
}

// ============================================================
// 内部实现
// ============================================================

/// 类型配色
class _TypeColors {
  const _TypeColors({
    required this.background,
    required this.icon,
    required this.iconBackground,
  });
  final Color background;
  final IconData icon;
  final Color iconBackground;
}

_TypeColors _getTypeColors(FeedbackType type) {
  switch (type) {
    case FeedbackType.success:
      return const _TypeColors(
        background: AppColors.success,
        icon: Icons.check_circle_rounded,
        iconBackground: AppColors.success,
      );
    case FeedbackType.error:
      return const _TypeColors(
        background: AppColors.error,
        icon: Icons.cancel_rounded,
        iconBackground: AppColors.error,
      );
    case FeedbackType.warning:
      return const _TypeColors(
        background: AppColors.warning,
        icon: Icons.warning_rounded,
        iconBackground: AppColors.warning,
      );
    case FeedbackType.info:
      return const _TypeColors(
        background: AppColors.primary,
        icon: Icons.info_rounded,
        iconBackground: AppColors.primary,
      );
  }
}

// ==================== Toast 组件 ====================

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  final String message;
  final FeedbackType type;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getTypeColors(widget.type);
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              // 上划关闭
              if (details.velocity.pixelsPerSecond.dy < -100) {
                _dismissTimer?.cancel();
                _dismiss();
              }
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: AppRadius.allMedium,
                  boxShadow: [
                    BoxShadow(
                      color: colors.background.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(colors.icon, color: Colors.white, size: 22),
                    AppSpacing.hSm,
                    Expanded(
                      child: Text(
                        widget.message,
                        style: AppTypography.footnote.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== 结果弹窗组件 ====================

class _ResultDialog extends StatefulWidget {
  const _ResultDialog({
    required this.animation,
    required this.type,
    required this.title,
    this.message,
    this.actionText,
    this.onAction,
    this.autoDismiss = true,
    this.autoDismissDuration = const Duration(seconds: 2),
  });

  final Animation<double> animation;
  final FeedbackType type;
  final String title;
  final String? message;
  final String? actionText;
  final VoidCallback? onAction;
  final bool autoDismiss;
  final Duration autoDismissDuration;

  @override
  State<_ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<_ResultDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _iconController;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();

    _iconController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // 弹窗出现后播放图标动画
    widget.animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _iconController.forward();
      }
    });

    // 自动关闭
    if (widget.autoDismiss && widget.actionText == null) {
      _autoDismissTimer = Timer(widget.autoDismissDuration, () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getTypeColors(widget.type);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: widget.animation,
        curve: Curves.easeOutBack,
      ),
    );

    return Center(
      child: FadeTransition(
        opacity: widget.animation,
        child: ScaleTransition(
          scale: scaleAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 260,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: isDark ? AppColors.secondaryBackgroundDark : Colors.white,
                borderRadius: AppRadius.allLarge,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 动画图标
                  _AnimatedResultIcon(
                    controller: _iconController,
                    type: widget.type,
                    colors: colors,
                  ),
                  AppSpacing.vLg,
                  // 标题
                  Text(
                    widget.title,
                    style: AppTypography.title3.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // 描述
                  if (widget.message != null) ...[
                    AppSpacing.vSm,
                    Text(
                      widget.message!,
                      style: AppTypography.subheadline.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  // 操作按钮
                  if (widget.actionText != null) ...[
                    AppSpacing.vLg,
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onAction?.call();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.background,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.allMedium,
                          ),
                          elevation: 0,
                        ),
                        child: Text(widget.actionText!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== 动画图标 ====================

class _AnimatedResultIcon extends StatelessWidget {
  const _AnimatedResultIcon({
    required this.controller,
    required this.type,
    required this.colors,
  });

  final AnimationController controller;
  final FeedbackType type;
  final _TypeColors colors;

  @override
  Widget build(BuildContext context) {
    // 外圈缩放
    final ringScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    // 图标缩放（稍后出现）
    final iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.3, 0.8, curve: Curves.elasticOut),
      ),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 外圈
              Transform.scale(
                scale: ringScale.value,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.iconBackground.withValues(alpha: 0.12),
                  ),
                ),
              ),
              // 图标
              Transform.scale(
                scale: iconScale.value,
                child: Icon(
                  colors.icon,
                  color: colors.iconBackground,
                  size: 48,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
