import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';

/// 动画时间线组件
///
/// 时间线节点逐个动画出现（交错动画），
/// 连接线从上往下"画出"，当前步骤节点脉冲高亮。
class AnimatedTimeline extends StatelessWidget {
  const AnimatedTimeline({
    super.key,
    required this.items,
    this.activeIndex,
    this.activeColor,
    this.inactiveColor,
    this.lineColor,
  });

  /// 时间线条目列表
  final List<TimelineItem> items;

  /// 当前活跃步骤索引
  final int? activeIndex;

  /// 激活颜色
  final Color? activeColor;

  /// 未激活颜色
  final Color? inactiveColor;

  /// 连接线颜色
  final Color? lineColor;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: List.generate(items.length, (index) {
        return _AnimatedTimelineNode(
          item: items[index],
          index: index,
          isFirst: index == 0,
          isLast: index == items.length - 1,
          isActive: activeIndex != null && index == activeIndex,
          isCompleted: activeIndex != null && index < activeIndex!,
          activeColor: activeColor ?? AppColors.primary,
          inactiveColor: inactiveColor ?? AppColors.textTertiaryLight,
          lineColor: lineColor,
        );
      }),
    );
  }
}

/// 时间线条目数据
class TimelineItem {
  const TimelineItem({
    required this.title,
    this.subtitle,
    this.icon,
    this.content,
    this.timestamp,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? content;
  final String? timestamp;
}

class _AnimatedTimelineNode extends StatefulWidget {
  const _AnimatedTimelineNode({
    required this.item,
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.isActive,
    required this.isCompleted,
    required this.activeColor,
    required this.inactiveColor,
    this.lineColor,
  });

  final TimelineItem item;
  final int index;
  final bool isFirst;
  final bool isLast;
  final bool isActive;
  final bool isCompleted;
  final Color activeColor;
  final Color inactiveColor;
  final Color? lineColor;

  @override
  State<_AnimatedTimelineNode> createState() => _AnimatedTimelineNodeState();
}

class _AnimatedTimelineNodeState extends State<_AnimatedTimelineNode>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-20, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    ));

    // 交错入场
    Future.delayed(Duration(milliseconds: 120 * widget.index), () {
      if (mounted) _entryController.forward();
    });

    // 当前步骤脉冲
    if (widget.isActive) {
      _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      )..repeat(reverse: true);

      _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController?.dispose();
    super.dispose();
  }

  Color get _nodeColor {
    if (widget.isActive) return widget.activeColor;
    if (widget.isCompleted) return widget.activeColor.withValues(alpha: 0.6);
    return widget.inactiveColor;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lineColor = widget.lineColor ??
        (isDark
            ? AppColors.dividerDark
            : AppColors.dividerLight);

    return AnimatedBuilder(
      animation: Listenable.merge([
        _entryController,
        if (_pulseController != null) _pulseController!,
      ]),
      builder: (context, _) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: _slideAnimation.value,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 时间线指示器
                  SizedBox(
                    width: 32,
                    child: Column(
                      children: [
                        // 上方连接线
                        if (!widget.isFirst)
                          Container(
                            width: 2,
                            height: 8,
                            color: widget.isCompleted || widget.isActive
                                ? widget.activeColor.withValues(alpha: 0.4)
                                : lineColor,
                          ),
                        // 节点圆点
                        _buildNode(),
                        // 下方连接线
                        if (!widget.isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: widget.isCompleted
                                  ? widget.activeColor.withValues(alpha: 0.4)
                                  : lineColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 内容区域
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.item.title,
                                  style: AppTypography.subheadlineBold.copyWith(
                                    color: widget.isActive
                                        ? widget.activeColor
                                        : (isDark
                                            ? AppColors.textPrimaryDark
                                            : AppColors.textPrimaryLight),
                                  ),
                                ),
                              ),
                              if (widget.item.timestamp != null)
                                Text(
                                  widget.item.timestamp!,
                                  style: AppTypography.caption2.copyWith(
                                    color: isDark
                                        ? AppColors.textTertiaryDark
                                        : AppColors.textTertiaryLight,
                                  ),
                                ),
                            ],
                          ),
                          if (widget.item.subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.item.subtitle!,
                              style: AppTypography.caption.copyWith(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                          if (widget.item.content != null) ...[
                            const SizedBox(height: 8),
                            widget.item.content!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNode() {
    final size = widget.isActive ? 16.0 : 12.0;
    final icon = widget.item.icon;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _nodeColor,
        shape: BoxShape.circle,
        boxShadow: widget.isActive && _pulseAnimation != null
            ? [
                BoxShadow(
                  color: widget.activeColor
                      .withValues(alpha: 0.3 * (_pulseAnimation?.value ?? 0)),
                  blurRadius: 6 + (_pulseAnimation?.value ?? 0) * 4,
                  spreadRadius: (_pulseAnimation?.value ?? 0) * 2,
                ),
              ]
            : null,
      ),
      child: icon != null
          ? Icon(icon, size: size * 0.6, color: Colors.white)
          : widget.isCompleted
              ? Icon(Icons.check, size: size * 0.6, color: Colors.white)
              : null,
    );
  }
}
