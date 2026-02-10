import 'package:flutter/material.dart';
import '../design/app_colors.dart';

/// 渐变文字组件 — ShaderMask 实现
///
/// 使用 ShaderMask + LinearGradient 让文字呈现渐变色效果。
/// 支持自定义渐变方向和颜色列表。
class GradientText extends StatelessWidget {
  const GradientText({
    super.key,
    required this.text,
    required this.style,
    this.gradient,
    this.colors,
    this.begin = Alignment.centerLeft,
    this.end = Alignment.centerRight,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  /// 文本内容
  final String text;

  /// 文字样式（颜色会被渐变覆盖）
  final TextStyle style;

  /// 自定义渐变（与 colors 互斥）
  final Gradient? gradient;

  /// 渐变颜色列表（与 gradient 互斥）
  final List<Color>? colors;

  /// 渐变起点
  final Alignment begin;

  /// 渐变终点
  final Alignment end;

  /// 最大行数
  final int? maxLines;

  /// 文字溢出方式
  final TextOverflow? overflow;

  /// 文字对齐方式
  final TextAlign? textAlign;

  /// 品牌色渐变（蓝色→深蓝）
  factory GradientText.brand({
    Key? key,
    required String text,
    required TextStyle style,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return GradientText(
      key: key,
      text: text,
      style: style,
      colors: AppColors.gradientPrimary,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  /// 金色渐变（VIP 用户名等）
  factory GradientText.gold({
    Key? key,
    required String text,
    required TextStyle style,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return GradientText(
      key: key,
      text: text,
      style: style,
      colors: AppColors.gradientGold,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  /// 排行榜奖牌渐变
  factory GradientText.medal({
    Key? key,
    required String text,
    required TextStyle style,
    required int rank,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    final colors = switch (rank) {
      1 => [const Color(0xFFFFD700), const Color(0xFFFFA000)], // 金色
      2 => [const Color(0xFFC0C0C0), const Color(0xFF9E9E9E)], // 银色
      3 => [const Color(0xFFCD7F32), const Color(0xFFA0522D)], // 铜色
      _ => AppColors.gradientPrimary,
    };

    return GradientText(
      key: key,
      text: text,
      style: style,
      colors: colors,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = gradient ??
        LinearGradient(
          colors: colors ?? AppColors.gradientPrimary,
          begin: begin,
          end: end,
        );

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => effectiveGradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      ),
    );
  }
}
