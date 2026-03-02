import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../utils/l10n_extension.dart';
import '../utils/offline_manager.dart';
import '../utils/network_monitor.dart';

/// 离线模式指示器
/// 对齐 iOS OfflineModeIndicatorModifier
/// 在离线时显示底部横幅提示
class OfflineModeIndicator extends StatelessWidget {
  const OfflineModeIndicator({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: NetworkMonitor.instance.statusStream,
      builder: (context, snapshot) {
        final isOffline = !NetworkMonitor.instance.isConnected;
        final pendingCount = OfflineManager.instance.pendingCount;

        return Stack(
          children: [
            child,
            if (isOffline)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _OfflineBanner(pendingCount: pendingCount),
              ),
          ],
        );
      },
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                pendingCount > 0
                    ? '${context.l10n.offlineMode} · ${context.l10n.offlinePendingSync(pendingCount)}'
                    : context.l10n.offlineMode,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (pendingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$pendingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 扩展方法 - 包裹离线模式指示器
extension OfflineModeIndicatorExtension on Widget {
  Widget withOfflineModeIndicator() {
    return OfflineModeIndicator(child: this);
  }
}
