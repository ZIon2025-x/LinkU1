import 'package:flutter/material.dart';
import '../../data/models/badge.dart';
import '../design/app_colors.dart';
import '../utils/l10n_extension.dart';

/// 构建勋章显示文本，如 "伦敦 · 翻译 · 前1名" (zh) / "London · Translation · Top 1" (en)
String buildBadgeLabel(BuildContext context, UserBadge badge) {
  final locale = Localizations.localeOf(context);
  final parts = <String>[];

  final city = badge.city;
  if (city != null && city.isNotEmpty && city != 'all') {
    parts.add(city);
  }

  final skillName = badge.displaySkillName(locale);
  if (skillName != null && skillName.isNotEmpty) {
    parts.add(skillName);
  }

  final rankStr = badge.rank;
  if (rankStr != null && rankStr.isNotEmpty) {
    final rankNum = int.tryParse(rankStr);
    if (rankNum != null) {
      parts.add(context.l10n.badgeTop(rankNum.toString()));
    } else {
      parts.add(rankStr);
    }
  }

  return parts.isNotEmpty ? parts.join('·') : badge.badgeType;
}

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
    final l10n = context.l10n;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        // VIP标识
        if (userLevel == 'vip')
          IdentityBadge(
            text: l10n.badgeVip,
            icon: Icons.workspace_premium,
            gradientColors: AppColors.gradientGold,
            compact: compact,
          ),

        // Super标识
        if (userLevel == 'super')
          IdentityBadge(
            text: l10n.badgeSuper,
            icon: Icons.local_fire_department,
            gradientColors: AppColors.gradientPinkPurple,
            compact: compact,
          ),

        // 达人标识
        if (isExpert == true)
          IdentityBadge(
            text: l10n.badgeExpert,
            icon: Icons.star,
            gradientColors: AppColors.gradientBlueTeal,
            compact: compact,
          ),

        // 学生标识
        if (isStudentVerified == true)
          IdentityBadge(
            text: l10n.badgeStudent,
            icon: Icons.school,
            gradientColors: AppColors.gradientIndigo,
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

/// 勋章文字标签 — 显示 "城市 · 类型 · 第N名"
/// 用于名字下方单独一行展示
class DisplayedBadgeLabel extends StatelessWidget {
  const DisplayedBadgeLabel({
    super.key,
    required this.badge,
    this.compact = false,
  });

  final UserBadge badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = buildBadgeLabel(context, badge);
    if (label == badge.badgeType && badge.badgeType.isEmpty) {
      return const SizedBox.shrink();
    }
    final fontSize = compact ? 10.0 : 12.0;

    final Color badgeColor = _rankColor(badge.rank);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [badgeColor, badgeColor.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.military_tech,
            size: fontSize + 2,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static Color _rankColor(String? rank) {
    if (rank == null) return AppColors.primary;
    final n = int.tryParse(rank);
    if (n == 1) return const Color(0xFFD4A017); // gold
    if (n == 2) return const Color(0xFF8A8A8A); // silver
    if (n == 3) return const Color(0xFFCD7F32); // bronze
    return AppColors.primary;
  }
}

/// 内联勋章标签 — 显示在名字后面，紧凑亮色
/// 格式: "🏅 城市 · 类型 · #N"
class InlineBadgeTag extends StatelessWidget {
  const InlineBadgeTag({super.key, required this.badge});

  final UserBadge badge;

  @override
  Widget build(BuildContext context) {
    final label = buildBadgeLabel(context, badge);
    if (label == badge.badgeType && badge.badgeType.isEmpty) {
      return const SizedBox.shrink();
    }

    final Color color = DisplayedBadgeLabel._rankColor(badge.rank);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.military_tech, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
