import 'package:flutter/material.dart';
import '../utils/responsive.dart';

/// 内容区宽度约束组件
/// 在桌面端限制内容最大宽度并居中显示，避免内容拉伸到全屏宽度
class ContentConstraint extends StatelessWidget {
  const ContentConstraint({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.maxContentWidth,
    this.alignment = Alignment.topCenter,
    this.padding,
  });

  /// 子组件
  final Widget child;

  /// 最大宽度，默认 960px
  final double maxWidth;

  /// 对齐方式，默认顶部居中
  final Alignment alignment;

  /// 外部边距（可选）
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    Widget content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    return Align(
      alignment: alignment,
      child: content,
    );
  }
}
