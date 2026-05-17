import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/l10n_extension.dart';

/// 任务聊天附件面板 — 微信风格 grid(4 列/行)。
///
/// 设计:
/// - 位于输入框**下方**,展开时替代键盘位置(微信/iMessage 模式)
/// - Grid 4 列,每行最多 4 个按钮;5 个按钮自然换行为 2 行
/// - 折叠/展开走 AnimatedSize + 缓动曲线,没有"闪一下"的 reflow
/// - 浅灰背景(#F7F7F7)区分输入区,顶部细线分隔
class TaskChatActionMenu extends StatelessWidget {
  const TaskChatActionMenu({
    super.key,
    required this.onImagePicker,
    required this.onCameraPick,
    required this.onFilePicker,
    required this.onTaskDetail,
    this.onViewLocation,
    this.isExpanded = false,
  });

  final VoidCallback onImagePicker;
  final VoidCallback onCameraPick;
  final VoidCallback onFilePicker;
  final VoidCallback onTaskDetail;
  final VoidCallback? onViewLocation;
  final bool isExpanded;

  /// 单个 grid cell 的高度(图标 56 + 间距 6 + 文字 ~14 + 上下 margin)≈ 92
  static const double _cellHeight = 92;
  static const double _gridPaddingV = 14;
  static const double _gridPaddingH = 8;

  @override
  Widget build(BuildContext context) {
    final actions = <_ActionItem>[
      _ActionItem(
        icon: Icons.photo_library,
        label: context.l10n.chatPhotoLabel,
        color: AppColors.success,
        onTap: onImagePicker,
      ),
      _ActionItem(
        icon: Icons.camera_alt,
        label: context.l10n.chatCameraLabel,
        color: AppColors.primary,
        onTap: onCameraPick,
      ),
      _ActionItem(
        icon: Icons.attach_file,
        label: context.l10n.chatFileLabel,
        color: AppColors.warning,
        onTap: onFilePicker,
      ),
      _ActionItem(
        icon: Icons.description,
        label: context.l10n.chatTaskDetailLabel,
        color: AppColors.primary,
        onTap: onTaskDetail,
      ),
      if (onViewLocation != null)
        _ActionItem(
          icon: Icons.location_on,
          label: context.l10n.chatAddressLabel,
          color: AppColors.warning,
          onTap: onViewLocation!,
        ),
    ];

    // AnimatedSize 让面板从 0 平滑撑开,无 layout reflow 闪烁;
    // 子树用 ClipRect 防止内容在过渡过程中越出。
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: ClipRect(
        child: isExpanded
            ? _GridPanel(
                actions: actions,
                cellHeight: _cellHeight,
                paddingV: _gridPaddingV,
                paddingH: _gridPaddingH,
              )
            : const SizedBox(width: double.infinity, height: 0),
      ),
    );
  }
}

class _GridPanel extends StatelessWidget {
  const _GridPanel({
    required this.actions,
    required this.cellHeight,
    required this.paddingV,
    required this.paddingH,
  });

  final List<_ActionItem> actions;
  final double cellHeight;
  final double paddingV;
  final double paddingH;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 微信浅灰背景;暗黑模式用稍微浅一档的卡片色
    final bg = isDark
        ? Theme.of(context).cardColor
        : const Color(0xFFF7F7F7);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        border: const Border(
          top: BorderSide(color: AppColors.dividerLight, width: 0.5),
        ),
      ),
      padding: EdgeInsets.symmetric(vertical: paddingV, horizontal: paddingH),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        // childAspectRatio 1.0 让格子接近正方形(图标 52 + 文字 + padding)
        children: actions
            .map((a) => _ActionCell(item: a, height: cellHeight))
            .toList(),
      ),
    );
  }
}

class _ActionItem {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _ActionCell extends StatelessWidget {
  const _ActionCell({required this.item, required this.height});

  final _ActionItem item;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: item.label,
      child: InkWell(
        onTap: () {
          AppHaptics.buttonTap();
          item.onTap();
        },
        borderRadius: AppRadius.allMedium,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.allMedium,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(item.icon, color: item.color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              item.label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
