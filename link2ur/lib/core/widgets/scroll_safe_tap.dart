import 'package:flutter/material.dart';

/// 滚动安全的点击检测器
///
/// 解决在可滚动列表中，手指按住按钮后滑动，松手时误触发点击的问题。
///
/// 原理：通过底层 [Listener] 追踪手指移动距离，如果超过阈值则判定为滑动意图，
/// 即使 [GestureDetector.onTap] 触发也不执行回调。
///
/// 用法：替换 `GestureDetector(onTap: ..., child: ...)` 为
/// `ScrollSafeTap(onTap: ..., child: ...)`
class ScrollSafeTap extends StatefulWidget {
  const ScrollSafeTap({
    super.key,
    required this.onTap,
    required this.child,
    this.behavior,
  });

  /// 点击回调（仅在非滑动时触发）
  final VoidCallback onTap;

  /// 子组件
  final Widget child;

  /// 命中测试行为（同 GestureDetector.behavior）
  final HitTestBehavior? behavior;

  @override
  State<ScrollSafeTap> createState() => _ScrollSafeTapState();
}

class _ScrollSafeTapState extends State<ScrollSafeTap> {
  Offset? _pointerDownPosition;

  /// 移动距离阈值（逻辑像素）
  /// Flutter 默认 kTouchSlop = 18，这里取更小值以在模糊地带也能防误触
  static const double _moveThreshold = 10.0;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _pointerDownPosition = event.position;
      },
      onPointerMove: (event) {
        // 手指移动超过阈值 → 判定为滑动意图，清除落点记录
        if (_pointerDownPosition != null) {
          final distance = (event.position - _pointerDownPosition!).distance;
          if (distance > _moveThreshold) {
            _pointerDownPosition = null;
          }
        }
      },
      child: GestureDetector(
        behavior: widget.behavior,
        onTap: () {
          // 仅当手指未明显移动时才触发点击
          if (_pointerDownPosition != null) {
            widget.onTap();
          }
          _pointerDownPosition = null;
        },
        child: widget.child,
      ),
    );
  }
}
