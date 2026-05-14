import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';

/// Linker 渐变头像：圆形 + 蓝紫渐变 + 火花图标 + 柔光阴影。
///
/// 默认 30pt 用于消息气泡左侧。传入更大尺寸（如 76）用于欢迎页主头像，
/// 通过 [withGlow] 打开外发光层。
class LinkerAvatar extends StatelessWidget {
  const LinkerAvatar({
    super.key,
    this.size = 30,
    this.withGlow = false,
  });

  final double size;
  final bool withGlow;

  @override
  Widget build(BuildContext context) {
    final iconSize = size * 0.55;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: AppColors.taskTypeBadgeGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: withGlow
            ? [
                BoxShadow(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.30),
                  blurRadius: size * 0.50,
                  spreadRadius: size * 0.06,
                ),
                BoxShadow(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.18),
                  blurRadius: size * 0.30,
                  offset: Offset(0, size * 0.12),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.28),
                  blurRadius: size * 0.32,
                  offset: Offset(0, size * 0.10),
                ),
              ],
      ),
      child: Icon(
        Icons.auto_awesome,
        color: Colors.white,
        size: iconSize,
      ),
    );
  }
}

/// 客服橙粉渐变头像（人工客服气泡左侧）。
class CSAvatar extends StatelessWidget {
  const CSAvatar({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8033), Color(0xFFFF4D80)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D80).withValues(alpha: 0.3),
            blurRadius: size * 0.28,
            offset: Offset(0, size * 0.10),
          ),
        ],
      ),
      child: Icon(
        Icons.support_agent,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}

/// 蓝白渐变文字（标题等小段文字）。
class LinkerGradientText extends StatelessWidget {
  const LinkerGradientText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign,
  });

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: AppColors.taskTypeBadgeGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(text, style: style, textAlign: textAlign),
    );
  }
}
