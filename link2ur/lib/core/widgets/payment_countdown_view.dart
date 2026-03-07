import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../design/app_radius.dart';

/// 支付倒计时视图组件
/// 参考iOS PaymentCountdownView.swift
class PaymentCountdownView extends StatefulWidget {
  const PaymentCountdownView({
    super.key,
    this.expiresAt,
    this.onExpired,
  });

  /// ISO格式的过期时间字符串
  final String? expiresAt;

  /// 过期回调
  final VoidCallback? onExpired;

  @override
  State<PaymentCountdownView> createState() => _PaymentCountdownViewState();
}

class _PaymentCountdownViewState extends State<PaymentCountdownView> {
  Timer? _timer;
  final ValueNotifier<Duration> _timeRemaining = ValueNotifier(Duration.zero);

  @override
  void initState() {
    super.initState();
    _updateTimeRemaining();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timeRemaining.dispose();
    super.dispose();
  }

  void _updateTimeRemaining() {
    final expiresAt = widget.expiresAt;
    if (expiresAt == null || expiresAt.isEmpty) {
      _timeRemaining.value = Duration.zero;
      return;
    }

    final expiryDate = DateTime.tryParse(expiresAt);
    if (expiryDate == null) {
      _timeRemaining.value = Duration.zero;
      return;
    }

    final remaining = expiryDate.difference(DateTime.now());
    _timeRemaining.value = remaining.isNegative ? Duration.zero : remaining;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeRemaining();

      if (_timeRemaining.value.inSeconds <= 0) {
        _timer?.cancel();
        widget.onExpired?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.expiresAt == null || widget.expiresAt!.isEmpty) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<Duration>(
      valueListenable: _timeRemaining,
      builder: (context, remaining, _) {
        final isExpired = remaining.inSeconds <= 0;
        final statusColor = isExpired ? AppColors.error : AppColors.warning;
        final formattedTime = isExpired
            ? '0:00'
            : '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: AppRadius.allSmall,
            border: Border.all(
              color: statusColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isExpired
                    ? Icons.warning_amber_rounded
                    : Icons.access_time_filled,
                size: 14,
                color: statusColor,
              ),
              const SizedBox(width: 6),
              Text(
                isExpired
                    ? AppLocalizations.of(context)!.paymentCountdownExpired
                    : AppLocalizations.of(context)!.paymentCountdownRemaining(formattedTime),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                  fontFeatures: isExpired
                      ? null
                      : const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 支付倒计时横幅（用于支付页面顶部）
/// 参考iOS PaymentCountdownBanner
class PaymentCountdownBanner extends StatefulWidget {
  const PaymentCountdownBanner({
    super.key,
    this.expiresAt,
    this.onExpired,
  });

  final String? expiresAt;
  final VoidCallback? onExpired;

  @override
  State<PaymentCountdownBanner> createState() =>
      _PaymentCountdownBannerState();
}

class _PaymentCountdownBannerState extends State<PaymentCountdownBanner> {
  Timer? _timer;
  final ValueNotifier<Duration> _timeRemaining = ValueNotifier(Duration.zero);

  @override
  void initState() {
    super.initState();
    _updateTimeRemaining();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timeRemaining.dispose();
    super.dispose();
  }

  void _updateTimeRemaining() {
    final expiresAt = widget.expiresAt;
    if (expiresAt == null || expiresAt.isEmpty) {
      _timeRemaining.value = Duration.zero;
      return;
    }

    final expiryDate = DateTime.tryParse(expiresAt);
    if (expiryDate == null) {
      _timeRemaining.value = Duration.zero;
      return;
    }

    final remaining = expiryDate.difference(DateTime.now());
    _timeRemaining.value = remaining.isNegative ? Duration.zero : remaining;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeRemaining();
      if (_timeRemaining.value.inSeconds <= 0) {
        _timer?.cancel();
        widget.onExpired?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.expiresAt == null || widget.expiresAt!.isEmpty) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<Duration>(
      valueListenable: _timeRemaining,
      builder: (context, remaining, _) {
        final isExpired = remaining.inSeconds <= 0;
        final statusColor = isExpired ? AppColors.error : AppColors.warning;
        final formattedTime = isExpired
            ? '0:00'
            : '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';

        return Container(
          padding: AppSpacing.allMd,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: AppRadius.allMedium,
            border: Border.all(
              color: statusColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isExpired
                    ? Icons.warning_amber_rounded
                    : Icons.access_time_filled,
                size: 20,
                color: statusColor,
              ),
              AppSpacing.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isExpired
                          ? AppLocalizations.of(context)!.paymentCountdownTimeout
                          : AppLocalizations.of(context)!.paymentCountdownCompleteInTime,
                      style: AppTypography.bodyBold.copyWith(
                        color: statusColor,
                      ),
                    ),
                    if (!isExpired)
                      Text(
                        AppLocalizations.of(context)!.paymentCountdownTimeLeft(formattedTime),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                  ],
                ),
              ),
              if (!isExpired)
                Text(
                  formattedTime,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
