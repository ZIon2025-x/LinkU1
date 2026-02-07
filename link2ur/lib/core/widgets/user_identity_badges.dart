import 'package:flutter/material.dart';

/// 用户身份标识组件 - 显示VIP、super、达人、学生等标识
/// 参考iOS UserIdentityBadges.swift
class UserIdentityBadges extends StatelessWidget {
  const UserIdentityBadges({
    super.key,
    this.userLevel,
    this.isExpert,
    this.isStudentVerified,
    this.compact = false,
  });

  final String? userLevel;
  final bool? isExpert;
  final bool? isStudentVerified;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        // VIP标识
        if (userLevel == 'vip')
          IdentityBadge(
            text: 'VIP',
            icon: Icons.workspace_premium,
            gradientColors: const [Color(0xFFFFD700), Color(0xFFFF9500)],
            compact: compact,
          ),

        // Super标识
        if (userLevel == 'super')
          IdentityBadge(
            text: 'Super',
            icon: Icons.local_fire_department,
            gradientColors: const [Color(0xFFAF52DE), Color(0xFFFF2D55)],
            compact: compact,
          ),

        // 达人标识
        if (isExpert == true)
          IdentityBadge(
            text: '达人',
            icon: Icons.star,
            gradientColors: const [Color(0xFF007AFF), Color(0xFF5AC8FA)],
            compact: compact,
          ),

        // 学生标识
        if (isStudentVerified == true)
          IdentityBadge(
            text: '学生',
            icon: Icons.school,
            gradientColors: const [Color(0xFF5856D6), Color(0xFF007AFF)],
            compact: compact,
          ),
      ],
    );
  }
}

/// 头像角标 - 用于个人页/他人页头像右下角
/// 仅 VIP/超级 显示
/// 参考iOS MemberBadgeAvatarOverlay
class MemberBadgeAvatarOverlay extends StatelessWidget {
  const MemberBadgeAvatarOverlay({
    super.key,
    this.userLevel,
    this.size = 28,
  });

  final String? userLevel;
  final double size;

  bool get _isVIP => userLevel == 'vip';
  bool get _isSuper => userLevel == 'super';
  bool get _showBadge => _isVIP || _isSuper;

  @override
  Widget build(BuildContext context) {
    if (!_showBadge) return const SizedBox.shrink();

    final gradientColors = _isSuper
        ? [const Color(0xFFA68CF8), const Color(0xFF8C5CF7)]
        : [const Color(0xFFFABF23), const Color(0xFFF59E07)];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          _isSuper ? Icons.local_fire_department : Icons.star,
          size: size * 0.5,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// 单个身份标识徽章
/// 参考iOS IdentityBadge
class IdentityBadge extends StatelessWidget {
  const IdentityBadge({
    super.key,
    required this.text,
    required this.icon,
    required this.gradientColors,
    this.compact = false,
  });

  final String text;
  final IconData icon;
  final List<Color> gradientColors;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 9.0 : 11.0;
    final iconSize = compact ? 8.0 : 10.0;
    final hPadding = compact ? 6.0 : 8.0;
    final vPadding = compact ? 2.0 : 4.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: Colors.white,
          ),
          SizedBox(width: compact ? 2 : 4),
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
