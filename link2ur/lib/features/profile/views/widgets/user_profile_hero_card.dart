import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../core/widgets/async_image_view.dart';
import '../../../../core/widgets/user_identity_badges.dart';
import '../../../../data/models/user.dart' show User;

/// Public user profile hero card.
///
/// 包含: 暖色 banner、悬浮白卡、头像 + VIP/Super 角标、姓名 + 身份徽章、
/// 勋章标签、地点 · 注册时长、bio、信任三联条 (评分/已完成/粉丝) 与关注按钮。
class UserProfileHeroCard extends StatelessWidget {
  const UserProfileHeroCard({
    super.key,
    required this.user,
    required this.followersCount,
    required this.followingCount,
    required this.totalReviews,
    required this.isSelf,
    required this.isFollowing,
    required this.isFollowLoading,
    required this.onFollow,
  });

  final User user;
  final int followersCount;
  final int followingCount;
  final int totalReviews;
  final bool isSelf;
  final bool isFollowing;
  final bool isFollowLoading;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const _Banner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            110,
            AppSpacing.md,
            0,
          ),
          child: _FloatingCard(
            user: user,
            followersCount: followersCount,
            totalReviews: totalReviews,
            isSelf: isSelf,
            isFollowing: isFollowing,
            isFollowLoading: isFollowLoading,
            onFollow: onFollow,
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 168,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF2A2A35), Color(0xFF1F1F28)]
              : const [Color(0xFFF3E7D4), Color(0xFFFAF7F2)],
        ),
      ),
    );
  }
}

class _FloatingCard extends StatelessWidget {
  const _FloatingCard({
    required this.user,
    required this.followersCount,
    required this.totalReviews,
    required this.isSelf,
    required this.isFollowing,
    required this.isFollowLoading,
    required this.onFollow,
  });

  final User user;
  final int followersCount;
  final int totalReviews;
  final bool isSelf;
  final bool isFollowing;
  final bool isFollowLoading;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardBackgroundDark : Colors.white;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _Avatar(user: user),
          const SizedBox(height: AppSpacing.md),
          _NameRow(user: user),
          if (user.displayedBadge != null) ...[
            const SizedBox(height: 6),
            DisplayedBadgeLabel(badge: user.displayedBadge!, compact: true),
          ],
          const SizedBox(height: AppSpacing.sm),
          _MetaLine(user: user),
          if ((user.bio ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                user.bio!,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: AppColors.textSecondary,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _TrustStrip(
            avgRating: user.avgRating,
            totalReviews: totalReviews,
            completedTaskCount: user.completedTaskCount,
            followersCount: followersCount,
          ),
          if (!isSelf) ...[
            const SizedBox(height: AppSpacing.lg),
            _FollowButton(
              isFollowing: isFollowing,
              isLoading: isFollowLoading,
              onPressed: onFollow,
              followLabel: context.l10n.profileFollow,
              followingLabel: context.l10n.profileFollowingAction,
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AvatarView(
            imageUrl: user.avatar,
            name: user.displayNameWith(context.l10n),
            size: 88,
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: MemberBadgeAvatarOverlay(
              userLevel: user.userLevel,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        Text(
          user.displayNameWith(context.l10n),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        if (user.isExpert)
          const Icon(Icons.verified, color: AppColors.primary, size: 18),
        if (user.isStudentVerified)
          const Icon(Icons.school, color: Colors.blue, size: 18),
        if (user.userLevel == 'vip')
          IdentityBadge(
            text: context.l10n.badgeVip,
            icon: Icons.workspace_premium,
            gradientColors: AppColors.gradientGold,
            compact: true,
          ),
        if (user.userLevel == 'super')
          IdentityBadge(
            text: context.l10n.badgeSuper,
            icon: Icons.local_fire_department,
            gradientColors: AppColors.gradientPinkPurple,
            compact: true,
          ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final parts = <String>[];

    if ((user.residenceCity ?? '').isNotEmpty) {
      parts.add(user.residenceCity!);
    }

    final createdAt = user.createdAt;
    if (createdAt != null) {
      final months = _monthsBetween(createdAt, DateTime.now());
      if (months >= 1) {
        parts.add(l10n.profileMetaJoinedFor(months));
      }
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) children.add(const _MetaDot());
      children.add(
        Text(
          parts[i],
          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.location_on_outlined,
            size: 12, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        ...children,
      ],
    );
  }

  static int _monthsBetween(DateTime from, DateTime to) {
    final diff = to.year * 12 + to.month - (from.year * 12 + from.month);
    return diff < 0 ? 0 : diff;
  }
}

class _MetaDot extends StatelessWidget {
  const _MetaDot();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 3,
        height: 3,
        decoration: const BoxDecoration(
          color: AppColors.textTertiary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip({
    required this.avgRating,
    required this.totalReviews,
    required this.completedTaskCount,
    required this.followersCount,
  });

  final double? avgRating;
  final int totalReviews;
  final int completedTaskCount;
  final int followersCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.dividerLight),
          bottom: BorderSide(color: AppColors.dividerLight),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TrustStat(
              big: avgRating != null ? avgRating!.toStringAsFixed(1) : '-',
              label: '${l10n.profileRating} · $totalReviews',
              gold: true,
            ),
          ),
          const _TrustDivider(),
          Expanded(
            child: _TrustStat(
              big: completedTaskCount.toString(),
              label: l10n.profileCompletedTasks,
            ),
          ),
          const _TrustDivider(),
          Expanded(
            child: _TrustStat(
              big: followersCount.toString(),
              label: l10n.profileFollowers,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustDivider extends StatelessWidget {
  const _TrustDivider();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: AppColors.dividerLight,
    );
  }
}

class _TrustStat extends StatelessWidget {
  const _TrustStat({
    required this.big,
    required this.label,
    this.gold = false,
  });
  final String big;
  final String label;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          big,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: gold ? AppColors.gold : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.isFollowing,
    required this.isLoading,
    required this.onPressed,
    required this.followLabel,
    required this.followingLabel,
  });

  final bool isFollowing;
  final bool isLoading;
  final VoidCallback onPressed;
  final String followLabel;
  final String followingLabel;

  @override
  Widget build(BuildContext context) {
    const loadingChild = SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
    if (isFollowing) {
      return SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.textTertiary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          child: isLoading
              ? loadingChild
              : Text(
                  followingLabel,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading ? loadingChild : const Icon(Icons.add, size: 18),
        label: Text(followLabel, style: const TextStyle(fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
    );
  }
}
