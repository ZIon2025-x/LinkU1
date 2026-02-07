import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../design/app_radius.dart';

/// 全局网络状态横幅
/// 在网络断开时显示提示，网络恢复时自动隐藏
/// 参考iOS NetworkStatusBanner.swift
class NetworkStatusBanner extends StatefulWidget {
  const NetworkStatusBanner({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<NetworkStatusBanner> createState() => _NetworkStatusBannerState();
}

class _NetworkStatusBannerState extends State<NetworkStatusBanner>
    with SingleTickerProviderStateMixin {
  bool _isVisible = false;
  bool _isConnected = true;
  bool _showRetryButton = false;
  String _title = '';
  String? _subtitle;
  IconData _iconName = Icons.wifi_off;
  Color _backgroundColor = AppColors.error;
  Timer? _dismissTimer;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _setupNetworkObserver();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _subscription?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _setupNetworkObserver() {
    _subscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      _handleNetworkStateChange(isConnected, results);
    });

    // 检查初始状态
    Connectivity().checkConnectivity().then((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (!isConnected) {
        _handleNetworkStateChange(false, results);
      }
    });
  }

  void _handleNetworkStateChange(
      bool isConnected, List<ConnectivityResult> results) {
    _dismissTimer?.cancel();

    if (!isConnected) {
      _showOfflineBanner();
    } else if (!_isConnected) {
      // 网络恢复（之前是断开状态）
      _showOnlineBanner(results);
    }

    _isConnected = isConnected;
  }

  void _showOfflineBanner() {
    setState(() {
      _title = '网络连接断开';
      _subtitle = '请检查网络设置';
      _iconName = Icons.wifi_off;
      _backgroundColor = AppColors.error;
      _showRetryButton = false;
      _isVisible = true;
    });
    _animController.forward();
  }

  void _showOnlineBanner(List<ConnectivityResult> results) {
    String typeDesc = '网络已连接';
    if (results.contains(ConnectivityResult.wifi)) {
      typeDesc = '已连接到 Wi-Fi';
    } else if (results.contains(ConnectivityResult.mobile)) {
      typeDesc = '已连接到移动网络';
    }

    setState(() {
      _title = '网络已恢复';
      _subtitle = typeDesc;
      _iconName = Icons.wifi;
      _backgroundColor = AppColors.success;
      _showRetryButton = true;
      _isVisible = true;
    });
    _animController.forward();

    // 3秒后自动隐藏
    _dismissTimer = Timer(const Duration(seconds: 3), _dismiss);
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isVisible)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: FadeTransition(
              opacity: _animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -1),
                  end: Offset.zero,
                ).animate(_animation),
                child: _buildBannerContent(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBannerContent() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: AppRadius.allMedium,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 状态图标
          Icon(
            _iconName,
            size: 16,
            color: Colors.white,
          ),
          AppSpacing.hMd,

          // 状态文本
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _title,
                  style: AppTypography.subheadlineBold.copyWith(
                    color: Colors.white,
                  ),
                ),
                if (_subtitle != null)
                  Text(
                    _subtitle!,
                    style: AppTypography.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),

          // 重试按钮
          if (_showRetryButton)
            GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: AppRadius.allSmall,
                ),
                child: Text(
                  '确定',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          AppSpacing.hSm,

          // 关闭按钮
          GestureDetector(
            onTap: _dismiss,
            child: Icon(
              Icons.close,
              size: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// 小型网络状态指示器（用于状态栏等位置）
/// 参考iOS NetworkStatusIndicator
class NetworkStatusIndicator extends StatefulWidget {
  const NetworkStatusIndicator({super.key});

  @override
  State<NetworkStatusIndicator> createState() => _NetworkStatusIndicatorState();
}

class _NetworkStatusIndicatorState extends State<NetworkStatusIndicator> {
  bool _isConnected = true;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription =
        Connectivity().onConnectivityChanged.listen((results) {
      setState(() {
        _isConnected = results.any((r) => r != ConnectivityResult.none);
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _isConnected ? AppColors.success : AppColors.error,
            shape: BoxShape.circle,
          ),
        ),
        if (!_isConnected) ...[
          const SizedBox(width: 4),
          Text(
            '离线',
            style: AppTypography.caption2.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ],
    );
  }
}
