import 'dart:async';
import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';
import '../design/app_radius.dart';
import '../utils/haptic_feedback.dart';

/// 操作结果 Overlay
/// 参考 iOS OperationResultOverlay - 显示成功/失败动画后自动消失
///
/// 用法：
/// ```dart
/// OperationResultOverlay.show(
///   context,
///   type: ResultType.success,
///   message: '操作成功',
/// );
/// ```
class OperationResultOverlay {
  OperationResultOverlay._();

  /// 显示操作结果
  static void show(
    BuildContext context, {
    required ResultType type,
    required String message,
    Duration duration = const Duration(milliseconds: 1500),
    VoidCallback? onDismiss,
  }) {
    // 触发对应触觉反馈
    switch (type) {
      case ResultType.success:
        AppHaptics.success();
        break;
      case ResultType.error:
        AppHaptics.error();
        break;
      case ResultType.warning:
        AppHaptics.warning();
        break;
      case ResultType.info:
        AppHaptics.light();
        break;
    }

    final overlay = OverlayEntry(
      builder: (context) => _ResultOverlayWidget(
        type: type,
        message: message,
        duration: duration,
        onDismiss: onDismiss,
      ),
    );

    Overlay.of(context).insert(overlay);

    // 自动消失（动画时长 + 展示时长 + 退出动画时长）
    Timer(duration + const Duration(milliseconds: 600), () {
      overlay.remove();
    });
  }
}

/// 结果类型
enum ResultType {
  success,
  error,
  warning,
  info,
}

class _ResultOverlayWidget extends StatefulWidget {
  const _ResultOverlayWidget({
    required this.type,
    required this.message,
    required this.duration,
    this.onDismiss,
  });

  final ResultType type;
  final String message;
  final Duration duration;
  final VoidCallback? onDismiss;

  @override
  State<_ResultOverlayWidget> createState() => _ResultOverlayWidgetState();
}

class _ResultOverlayWidgetState extends State<_ResultOverlayWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    ));

    // 入场动画
    _controller.forward();

    // 定时退场
    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = _getConfig(widget.type);

    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                constraints: const BoxConstraints(
                  minWidth: 150,
                  maxWidth: 250,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.elevatedBackgroundDark.withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.95),
                  borderRadius: AppRadius.allLarge,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 图标
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: config.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        config.icon,
                        color: config.color,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 消息文字
                    Text(
                      widget.message,
                      style: AppTypography.subheadlineBold.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

  _ResultConfig _getConfig(ResultType type) {
    switch (type) {
      case ResultType.success:
        return const _ResultConfig(
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
        );
      case ResultType.error:
        return const _ResultConfig(
          icon: Icons.error_rounded,
          color: AppColors.error,
        );
      case ResultType.warning:
        return const _ResultConfig(
          icon: Icons.warning_rounded,
          color: AppColors.warning,
        );
      case ResultType.info:
        return const _ResultConfig(
          icon: Icons.info_rounded,
          color: AppColors.info,
        );
    }
  }
}

class _ResultConfig {
  const _ResultConfig({required this.icon, required this.color});
  final IconData icon;
  final Color color;
}
