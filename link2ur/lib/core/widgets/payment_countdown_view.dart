import 'dart:async';
import 'package:flutter/material.dart';
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
  Duration _timeRemaining = Duration.zero;

  bool get _isExpired => _timeRemaining.inSeconds <= 0;

  String get _formattedTime {
    if (_isExpired) return '0:00';
    final minutes = _timeRemaining.inMinutes;
    final seconds = _timeRemaining.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _updateTimeRemaining();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTimeRemaining() {
    final expiresAt = widget.expiresAt;
    if (expiresAt == null || expiresAt.isEmpty) {
      _timeRemaining = Duration.zero;
      return;
    }

    final expiryDate = DateTime.tryParse(expiresAt);
    if (expiryDate == null) {
      _timeRemaining = Duration.zero;
      return;
    }

    final remaining = expiryDate.difference(DateTime.now());
    _timeRemaining = remaining.isNegative ? Duration.zero : remaining;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeRemaining();
      if (mounted) setState(() {});

      if (_isExpired) {
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

    final statusColor = _isExpired ? AppColors.error : AppColors.warning;

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
            _isExpired
                ? Icons.warning_amber_rounded
                : Icons.access_time_filled,
            size: 14,
            color: statusColor,
          ),
          const SizedBox(width: 6),
          Text(
            _isExpired ? '已过期' : '剩余 $_formattedTime',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: statusColor,
              fontFeatures: _isExpired
                  ? null
                  : const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
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
  Duration _timeRemaining = Duration.zero;

  bool get _isExpired => _timeRemaining.inSeconds <= 0;

  String get _formattedTime {
    if (_isExpired) return '0:00';
    final minutes = _timeRemaining.inMinutes;
    final seconds = _timeRemaining.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _updateTimeRemaining();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTimeRemaining() {
    final expiresAt = widget.expiresAt;
    if (expiresAt == null || expiresAt.isEmpty) {
      _timeRemaining = Duration.zero;
      return;
    }

    final expiryDate = DateTime.tryParse(expiresAt);
    if (expiryDate == null) {
      _timeRemaining = Duration.zero;
      return;
    }

    final remaining = expiryDate.difference(DateTime.now());
    _timeRemaining = remaining.isNegative ? Duration.zero : remaining;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeRemaining();
      if (mounted) setState(() {});
      if (_isExpired) {
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

    final statusColor = _isExpired ? AppColors.error : AppColors.warning;

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
            _isExpired
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
                  _isExpired ? '支付已超时' : '请在规定时间内完成支付',
                  style: AppTypography.bodyBold.copyWith(
                    color: statusColor,
                  ),
                ),
                if (!_isExpired)
                  Text(
                    '距离超时还剩 $_formattedTime',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
              ],
            ),
          ),
          if (!_isExpired)
            Text(
              _formattedTime,
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
  }
}
