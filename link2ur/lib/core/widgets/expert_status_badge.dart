import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../utils/l10n_extension.dart';

/// 达人团队营业状态徽章
/// - [isOpen] null → 隐藏（未设置营业时间 / 字段缺失）
/// - [isOpen] true → 绿底"运营中"
/// - [isOpen] false → 灰底"休息中"
///
/// 使用说明: 列表卡片、详情页头部都可复用。size=[ExpertStatusBadgeSize.compact]
/// 适合列表卡片的小角标, [standard] 用于详情页主内容区。
enum ExpertStatusBadgeSize { compact, standard }

class ExpertStatusBadge extends StatelessWidget {
  const ExpertStatusBadge({
    super.key,
    required this.isOpen,
    this.size = ExpertStatusBadgeSize.compact,
  });

  final bool? isOpen;
  final ExpertStatusBadgeSize size;

  @override
  Widget build(BuildContext context) {
    if (isOpen == null) return const SizedBox.shrink();

    final bool open = isOpen!;
    final String label = open
        ? context.l10n.expertTeamStatusActive
        : context.l10n.expertTeamStatusResting;
    final Color bg = open
        ? const Color(0xFF34C759)
        : AppColors.textSecondaryLight.withValues(alpha: 0.5);
    final IconData icon = open ? Icons.circle : Icons.nightlight_round;

    final double fontSize = size == ExpertStatusBadgeSize.compact ? 10 : 12;
    final double iconSize = size == ExpertStatusBadgeSize.compact ? 8 : 10;
    final EdgeInsets padding = size == ExpertStatusBadgeSize.compact
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 4);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
