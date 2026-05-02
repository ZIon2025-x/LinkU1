import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';

/// 用户主页的统一 section 卡片（对齐 user_profile_redesign.html · Plan B）。
///
/// 视觉：白底、圆角 22、轻阴影；header = title + subtitle (灰色) + optional 右侧 "全部 >"；
/// 内容由调用方填充（通常是 Column 子节点列表）。
class BSectionCard extends StatelessWidget {
  const BSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.onTapMore,
    this.moreLabel,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTapMore;
  final String? moreLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardBackgroundDark : Colors.white;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Head(
            title: title,
            subtitle: subtitle,
            moreLabel: moreLabel,
            onTapMore: onTapMore,
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({
    required this.title,
    required this.subtitle,
    required this.moreLabel,
    required this.onTapMore,
  });

  final String title;
  final String? subtitle;
  final String? moreLabel;
  final VoidCallback? onTapMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              if ((subtitle ?? '').isNotEmpty)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        if (onTapMore != null)
          InkWell(
            onTap: onTapMore,
            borderRadius: AppRadius.allSmall,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    moreLabel ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
