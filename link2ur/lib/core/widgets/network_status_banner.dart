import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';

/// 网络状态横幅
/// 参考iOS NetworkStatusBannerViewModel.swift
/// 在网络断开或弱网时显示提示
class NetworkStatusBanner extends StatefulWidget {
  const NetworkStatusBanner({super.key, required this.child});

  final Widget child;

  @override
  State<NetworkStatusBanner> createState() => _NetworkStatusBannerState();
}

class _NetworkStatusBannerState extends State<NetworkStatusBanner>
    with SingleTickerProviderStateMixin {
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  late final AnimationController _animController;
  late final Animation<double> _slideAnimation;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _subscription =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);

    // 检查初始网络状态
    Connectivity().checkConnectivity().then(_onConnectivityChanged);
  }

  @override
  void dispose() {
    _subscription.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isOffline = results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none);

    if (isOffline != _isOffline) {
      setState(() => _isOffline = isOffline);
      if (isOffline) {
        _animController.forward();
      } else {
        // 恢复网络后短暂显示再隐藏
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !_isOffline) {
            _animController.reverse();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            if (!_isOffline && _animController.isDismissed) {
              return const SizedBox.shrink();
            }
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -1),
                end: Offset.zero,
              ).animate(_animController),
              child: Material(
                color: _isOffline
                    ? AppColors.error
                    : AppColors.success,
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isOffline
                              ? Icons.wifi_off
                              : Icons.wifi,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isOffline ? '网络已断开' : '网络已恢复',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
