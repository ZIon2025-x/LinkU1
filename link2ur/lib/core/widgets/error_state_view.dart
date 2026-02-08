import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../design/app_radius.dart';

/// 错误状态视图
/// 参考iOS ErrorStateView.swift
/// retryText / title / message 等默认值全部使用 l10n，不再硬编码中文
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    this.icon = Icons.error_outline,
    this.title,
    this.retryText,
    this.onRetry,
    this.iconSize = 64,
    this.iconColor,
  });

  final String message;
  final IconData icon;
  final String? title;
  /// 传 null 时自动使用 l10n.commonRetry
  final String? retryText;
  final VoidCallback? onRetry;
  final double iconSize;
  final Color? iconColor;

  /// 网络错误
  factory ErrorStateView.network({
    String? title,
    String? message,
    VoidCallback? onRetry,
  }) {
    return ErrorStateView(
      icon: Icons.wifi_off_outlined,
      title: title,
      message: message ?? '',
      onRetry: onRetry,
    );
  }

  /// 服务器错误
  factory ErrorStateView.server({
    String? title,
    String? message,
    VoidCallback? onRetry,
  }) {
    return ErrorStateView(
      icon: Icons.cloud_off_outlined,
      title: title,
      message: message ?? '',
      onRetry: onRetry,
    );
  }

  /// 加载失败
  factory ErrorStateView.loadFailed({
    String? title,
    String? message,
    VoidCallback? onRetry,
  }) {
    return ErrorStateView(
      icon: Icons.refresh,
      title: title,
      message: message ?? '',
      onRetry: onRetry,
    );
  }

  /// 权限不足
  factory ErrorStateView.unauthorized({
    String? title,
    String? message,
  }) {
    return ErrorStateView(
      icon: Icons.lock_outline,
      title: title,
      message: message ?? '',
    );
  }

  /// 内容不存在
  factory ErrorStateView.notFound({
    String? title,
    String? message,
  }) {
    return ErrorStateView(
      icon: Icons.search_off,
      title: title,
      message: message ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    // 运行时解析默认文本（l10n 优先，兼容无 context 场景）
    final resolvedRetryText = retryText ?? l10n?.commonRetry ?? 'Retry';
    final resolvedMessage = message.isNotEmpty ? message : (l10n?.errorUnknown ?? '');

    return Center(
      child: Padding(
        padding: AppSpacing.allXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标
            Container(
              width: iconSize + 40,
              height: iconSize + 40,
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.error).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: iconColor ?? AppColors.error,
              ),
            ),
            AppSpacing.vLg,
            // 标题
            if (title != null)
              Text(
                title!,
                style: AppTypography.title3.copyWith(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
                textAlign: TextAlign.center,
              ),
            if (title != null) AppSpacing.vSm,
            // 错误信息
            if (resolvedMessage.isNotEmpty)
              Text(
                resolvedMessage,
                style: AppTypography.subheadline.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
            if (onRetry != null) ...[
              AppSpacing.vLg,
              // 重试按钮
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 20),
                label: Text(resolvedRetryText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.button,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 内联错误提示
class InlineError extends StatelessWidget {
  const InlineError({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: AppRadius.allMedium,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.error,
            size: 20,
          ),
          AppSpacing.hSm,
          Expanded(
            child: Text(
              message,
              style: AppTypography.subheadline.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
          if (onRetry != null) ...[
            AppSpacing.hSm,
            GestureDetector(
              onTap: onRetry,
              child: const Icon(
                Icons.refresh,
                color: AppColors.error,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
