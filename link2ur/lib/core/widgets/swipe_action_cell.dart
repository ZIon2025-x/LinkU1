import 'package:flutter/material.dart';

import '../design/app_radius.dart';
import '../utils/haptic_feedback.dart';

/// 左滑操作按钮数据
class SwipeAction {
  const SwipeAction({
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

// ── 全局：同一时刻只允许一个 SwipeActionCell 打开 ──
SwipeActionCellState? _currentlyOpenCell;

/// 左滑操作列表项
///
/// 内容向左平移，按钮从屏幕右侧外同步滑入。
/// 按钮不在内容后面（不是 reveal），而是和内容右边缘紧贴，一起运动。
class SwipeActionCell extends StatefulWidget {
  const SwipeActionCell({
    super.key,
    required this.child,
    required this.actions,
    this.actionMargin,
  });

  final Widget child;
  final List<SwipeAction> actions;

  /// 按钮区域的外边距，用于对齐内容卡片的 margin。
  /// 例如卡片有 `margin: EdgeInsets.only(bottom: 8)` 时，
  /// 传入 `EdgeInsets.only(bottom: 8)` 让按钮高度与卡片视觉一致。
  final EdgeInsets? actionMargin;

  @override
  State<SwipeActionCell> createState() => SwipeActionCellState();
}

class SwipeActionCellState extends State<SwipeActionCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  /// 每个按钮宽度
  static const _actionWidth = 72.0;

  /// 按钮之间间距
  static const _actionGap = 6.0;

  /// 按钮与内容右边缘的间距
  static const _leadingGap = 8.0;

  /// 总需要平移的距离
  double get _totalShift =>
      _leadingGap +
      _actionWidth * widget.actions.length +
      _actionGap * (widget.actions.length - 1);

  double get _snapThreshold => _totalShift * 0.35;

  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    if (_currentlyOpenCell == this) _currentlyOpenCell = null;
    _controller.dispose();
    super.dispose();
  }

  void close() {
    if (_isOpen) {
      _controller.reverse();
      _isOpen = false;
      if (_currentlyOpenCell == this) _currentlyOpenCell = null;
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    // 开始拖新的卡片时，自动关闭上一个
    if (_currentlyOpenCell != null && _currentlyOpenCell != this) {
      _currentlyOpenCell!.close();
    }

    final delta = details.primaryDelta ?? 0;
    final newValue = _controller.value - delta / _totalShift;
    _controller.value = newValue.clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -300) {
      _open();
    } else if (velocity > 300) {
      _close();
    } else if (_controller.value * _totalShift > _snapThreshold) {
      _open();
    } else {
      _close();
    }
  }

  void _open() {
    // 关闭其他已打开的 cell
    if (_currentlyOpenCell != null && _currentlyOpenCell != this) {
      _currentlyOpenCell!.close();
    }
    if (!_isOpen) AppHaptics.selection();
    _controller.animateTo(1.0);
    _isOpen = true;
    _currentlyOpenCell = this;
  }

  void _close() {
    _controller.animateTo(0.0);
    _isOpen = false;
    if (_currentlyOpenCell == this) _currentlyOpenCell = null;
  }

  void _onActionTap(SwipeAction action) {
    AppHaptics.light();
    _close();
    Future.delayed(const Duration(milliseconds: 220), action.onTap);
  }

  @override
  Widget build(BuildContext context) {
    final margin = widget.actionMargin ?? EdgeInsets.zero;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth;

        return GestureDetector(
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              final shift = _animation.value * _totalShift;

              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // ── 主内容：向左平移 ──
                  Transform.translate(
                    offset: Offset(-shift, 0),
                    child: SizedBox(
                      width: contentWidth,
                      child: GestureDetector(
                        onTap: _isOpen ? close : null,
                        child: widget.child,
                      ),
                    ),
                  ),

                  // ── 操作按钮：从右侧屏幕外滑入，紧跟内容右边缘 ──
                  Positioned(
                    right: shift - _totalShift,
                    top: margin.top,
                    bottom: margin.bottom,
                    child: _ActionsRow(
                      actions: widget.actions,
                      actionWidth: _actionWidth,
                      actionGap: _actionGap,
                      leadingGap: _leadingGap,
                      onTap: _onActionTap,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// 操作按钮行
class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.actions,
    required this.actionWidth,
    required this.actionGap,
    required this.leadingGap,
    required this.onTap,
  });

  final List<SwipeAction> actions;
  final double actionWidth;
  final double actionGap;
  final double leadingGap;
  final void Function(SwipeAction) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: leadingGap),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < actions.length; i++) ...[
            if (i > 0) SizedBox(width: actionGap),
            _ActionButton(
              action: actions[i],
              width: actionWidth,
              onTap: () => onTap(actions[i]),
            ),
          ],
        ],
      ),
    );
  }
}

/// 单个操作按钮
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.width,
    required this.onTap,
  });

  final SwipeAction action;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: isDark ? action.color.withValues(alpha: 0.88) : action.color,
          borderRadius: BorderRadius.circular(AppRadius.large),
          boxShadow: [
            BoxShadow(
              color: action.color.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(action.icon, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              action.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
