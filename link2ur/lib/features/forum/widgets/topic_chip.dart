import 'package:flutter/material.dart';
import '../../../core/design/app_colors.dart';

/// Forum 话题胶囊 — 发帖页 + 详情页共享。
/// 3 种形态:
/// - 可编辑选中: 显示 × 删除按钮
/// - 锁定: 显示 🔒 锁图标 (达人板块/官方任务/admin 公告/校园板块)
/// - 只读: 详情页展示用
class TopicChip extends StatelessWidget {
  const TopicChip({
    super.key,
    required this.label,
    this.emoji,
    this.onRemove,
    this.locked = false,
  });

  final String label;
  final String? emoji;
  final VoidCallback? onRemove;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primary = AppColors.primary;
    final bg = isDark
        ? primary.withValues(alpha: 0.18)
        : primary.withValues(alpha: 0.10);
    final borderColor = primary.withValues(alpha: isDark ? 0.40 : 0.25);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null) ...[
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(emoji!, style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: primary,
              ),
            ),
          ),
          if (locked) ...[
            const SizedBox(width: 6),
            const Icon(Icons.lock_outline, size: 14, color: primary),
          ] else if (onRemove != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 11, color: primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
