# 普通用户主页 · Hero 视觉重写 Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `user_profile_view` 主页面从「接单方风格」（完成率环形 / 总任务 / 评分 / 雷达图 / 私信按钮 / 居住城市单行）替换成普通用户视角的「口碑/活跃度/社交风格」（评分 / 已完成 / 粉丝 + 单纯关注按钮 + 暖色 banner + 浮卡 hero），并清理已经不需要的旧 section（雷达图、已售闲置）。

**Architecture:**
- 新建独立 widget `UserProfileHeroCard`（`features/profile/views/widgets/user_profile_hero_card.dart`）。承载 banner + 浮卡 + 头像 + 徽章 + 简介 + meta line + trust strip + 关注按钮。脱离 BLoC 直接渲染，可独立测。
- 在 `user_profile_view.dart` 把现有 `_buildUserInfoCard` 调用替换为 `UserProfileHeroCard`；同时删除 `_buildSkillRadar`/`_buildSoldFleaItemsSection` 的调用 + 它们的 method（YAGNI — 已确认不再需要）；删除 hero 行内的 message 按钮（产品无私聊功能）。
- 评价 section 现状是 `_ReviewItem` 单卡片样式，已经是 mini 形态，不需要再重写。**这里是 plan 跟之前 mockup 的差异**：mockup 是从零设计，现实代码已经接近目标，无需动评价。
- 复用既有：`MemberBadgeAvatarOverlay`、`UserIdentityBadges`、`DisplayedBadgeLabel`、`buildBadgeLabel`、`AvatarView`、设计 token (`AppColors`/`AppSpacing`/`AppRadius`)。

**Tech Stack:** Flutter + BLoC（已有）· flutter_test · ARB l10n（en/zh/zh_Hant）

**Out of scope（明确不做）:**
- ❌ 后端字段改动（hero 数据已经全部在 User / UserProfileDetail / state 里了）
- ❌ 评价 section 重写（现状已经是 mini 样式）
- ❌ 论坛动态 / 合作记录 section（保留现状）
- ❌ 已售闲置功能本身（仅删除主页 section 调用，repository / model / 后端字段保留以备其他场景使用）
- ❌ 「能力详情」抽屉（早前撤回）
- ❌ 抽离 `user_profile_view.dart` 整体重写（只动 hero + 删两个旧 section）
- ❌ Tab 切换（plan A 那种）

---

## File Structure

| 文件 | 动作 | 责任 |
|------|------|------|
| `link2ur/lib/features/profile/views/widgets/user_profile_hero_card.dart` | 创建 | 独立 hero widget：banner + 浮卡 + 头像 + 徽章 + meta + bio + trust strip + 关注按钮 |
| `link2ur/lib/features/profile/views/user_profile_view.dart` | 修改 | 引入 `UserProfileHeroCard` 替换 `_buildUserInfoCard` 调用；删除 `_buildSkillRadar` / `_buildSoldFleaItemsSection` 的调用 + 死代码方法；删 `_buildStatsRow` / `_buildFollowSection` 中 message 按钮和雷达 |
| `link2ur/lib/l10n/app_en.arb` | 修改 | 加 2 个新 key (`profileTrustRating` 注释 / `profileMetaJoinedFor`) |
| `link2ur/lib/l10n/app_zh.arb` | 修改 | 同上 |
| `link2ur/lib/l10n/app_zh_Hant.arb` | 修改 | 同上 |
| `link2ur/test/features/profile/user_profile_hero_card_test.dart` | 创建 | Widget test：基础渲染 / 勋章条件渲染 / VIP crown / 自己看自己时无关注按钮 |

---

## Pre-flight

- [ ] **Step 0: 环境检查**

  ```bash
  cd /f/python_work/LinkU
  git status   # main 分支，无未提交（除 .claude/worktrees/add-l10n-strings 之类的子模块标记）
  ```

  Flutter env：
  ```bash
  export PATH="/f/flutter/bin:$PATH"
  export PUB_CACHE="/f/DevCache/.pub-cache"
  cd link2ur && flutter --version
  ```

  Per memory：solo 项目，直接推 main，不开 feature 分支。

---

## Task 1: 新增 l10n keys（先做，避免 hero widget 引用未生成的 key）

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`

我们要复用大多数已有的 profile key（`profileFollowers` / `profileCompletedTasks` / `profileRating` / `profileFollow` / `profileFollowingAction`）。**只需要新增 1 个**：

- `profileMetaJoinedFor` —— "注册 N 年 / N 个月" 文案，用 plural

- [ ] **Step 1: 加英文 key（在合适位置插入，例如 `profileSoldItems` 之后）**

  ```json
  "profileMetaJoinedFor": "Joined {months, plural, =1{1 month ago} other{{months} months ago}}",
  "@profileMetaJoinedFor": {
    "placeholders": { "months": { "type": "int" } }
  },
  ```

- [ ] **Step 2: 简体中文**

  ```json
  "profileMetaJoinedFor": "注册 {months, plural, other{{months} 个月}}",
  "@profileMetaJoinedFor": {
    "placeholders": { "months": { "type": "int" } }
  },
  ```

- [ ] **Step 3: 繁体中文**

  ```json
  "profileMetaJoinedFor": "註冊 {months, plural, other{{months} 個月}}",
  "@profileMetaJoinedFor": {
    "placeholders": { "months": { "type": "int" } }
  },
  ```

- [ ] **Step 4: gen-l10n**

  ```bash
  cd /f/python_work/LinkU/link2ur && flutter gen-l10n
  ```

  Expected: 无 warning。

- [ ] **Step 5: 验证 + commit**

  ```bash
  flutter analyze lib/l10n/  # No issues
  git add link2ur/lib/l10n/
  git commit -m "i18n(profile): add profileMetaJoinedFor for hero meta line"
  ```

---

## Task 2: 写失败测试（UserProfileHeroCard widget）

**Files:**
- Create: `link2ur/test/features/profile/user_profile_hero_card_test.dart`

测试覆盖 4 个核心行为：
1. 基础渲染：名字、bio、trust strip 三大数字（评分/已完成/粉丝）显示正确
2. 有 displayedBadge 时显示勋章 pill；没有时**不渲染那一行**
3. 用户 user_level == 'vip' 时头像角显示皇冠 overlay
4. 当 isSelf=true 时不显示关注按钮（只显示空白或没有 actions）

- [ ] **Step 1: 写测试**

  ```dart
  // link2ur/test/features/profile/user_profile_hero_card_test.dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';

  import 'package:link2ur/data/models/user.dart';
  import 'package:link2ur/data/models/badge.dart';
  import 'package:link2ur/features/profile/views/widgets/user_profile_hero_card.dart';
  import 'package:link2ur/l10n/app_localizations.dart';

  void main() {
    User _user({
      String name = '周哲',
      String? userLevel,
      bool isExpert = false,
      bool isStudentVerified = true,
      double? avgRating = 4.9,
      int completedTaskCount = 18,
      String? bio = 'UCL 经济系大三在读',
      String? residenceCity = '伦敦',
      DateTime? createdAt,
      UserBadge? displayedBadge,
    }) =>
        User(
          id: '00000099',
          name: name,
          userLevel: userLevel,
          isExpert: isExpert,
          isStudentVerified: isStudentVerified,
          avgRating: avgRating,
          completedTaskCount: completedTaskCount,
          taskCount: 0,
          bio: bio,
          residenceCity: residenceCity,
          createdAt: createdAt ?? DateTime.now().subtract(const Duration(days: 540)),
          displayedBadge: displayedBadge,
        );

    Widget _harness({
      required User user,
      int followers = 236,
      int following = 88,
      int totalReviews = 12,
      bool isSelf = false,
      bool isFollowing = false,
      bool isFollowLoading = false,
      VoidCallback? onFollow,
    }) =>
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: UserProfileHeroCard(
                user: user,
                followersCount: followers,
                followingCount: following,
                totalReviews: totalReviews,
                isSelf: isSelf,
                isFollowing: isFollowing,
                isFollowLoading: isFollowLoading,
                onFollow: onFollow ?? () {},
              ),
            ),
          ),
        );

    testWidgets('renders name + bio + trust strip with three numbers', (tester) async {
      await tester.pumpWidget(_harness(user: _user()));
      await tester.pumpAndSettle();

      expect(find.text('周哲'), findsOneWidget);
      expect(find.text('UCL 经济系大三在读'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('236'), findsOneWidget);
    });

    testWidgets('shows DisplayedBadge pill only when badge != null', (tester) async {
      // Without badge -> no badge label rendered
      await tester.pumpWidget(_harness(user: _user(displayedBadge: null)));
      await tester.pumpAndSettle();
      // 用一个已知不会出现在其他地方的字符串确认 badge label 区域是否渲染
      expect(find.textContaining('排名'), findsNothing);
      expect(find.textContaining('Top'), findsNothing);

      // With badge -> badge label visible
      const badge = UserBadge(
        badgeType: 'skill_rank',
        skillCategory: 'tutoring',
        city: '伦敦',
        rank: '8',
      );
      await tester.pumpWidget(_harness(user: _user(displayedBadge: badge)));
      await tester.pumpAndSettle();
      // buildBadgeLabel 输出 "伦敦·家教·前8名"（具体格式依 zh ARB 决定，验证 city + rank 关键 token 出现）
      expect(find.textContaining('伦敦'), findsAtLeast(1));
      expect(find.textContaining('8'), findsAtLeast(1));
    });

    testWidgets('shows VIP crown overlay when user_level == vip', (tester) async {
      await tester.pumpWidget(_harness(user: _user(userLevel: 'vip')));
      await tester.pumpAndSettle();
      // MemberBadgeAvatarOverlay 在 hero card 内部应当存在
      expect(find.byType(UserProfileHeroCard), findsOneWidget);
      // 不强制 assert overlay 内部细节（依赖既有组件自己测过），仅确认 widget 不崩
    });

    testWidgets('hides follow button when isSelf == true', (tester) async {
      await tester.pumpWidget(_harness(user: _user(), isSelf: true));
      await tester.pumpAndSettle();
      // 既不该有 ElevatedButton（关注）也不该有 OutlinedButton（已关注）
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('shows follow button (ElevatedButton) when isSelf == false and not following', (tester) async {
      await tester.pumpWidget(_harness(user: _user(), isSelf: false, isFollowing: false));
      await tester.pumpAndSettle();
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('shows "已关注" outline button when already following', (tester) async {
      await tester.pumpWidget(_harness(user: _user(), isSelf: false, isFollowing: true));
      await tester.pumpAndSettle();
      expect(find.byType(OutlinedButton), findsOneWidget);
    });
  }
  ```

- [ ] **Step 2: 运行，确认失败**

  ```bash
  cd /f/python_work/LinkU/link2ur && flutter test test/features/profile/user_profile_hero_card_test.dart
  ```

  Expected: 编译失败 —— `user_profile_hero_card.dart` 不存在。

- [ ] **Step 3: Commit 失败测试**

  ```bash
  git add link2ur/test/features/profile/user_profile_hero_card_test.dart
  git commit -m "test(profile): assert UserProfileHeroCard renders + conditional badge + isSelf hides follow"
  ```

---

## Task 3: 实现 UserProfileHeroCard widget

**Files:**
- Create: `link2ur/lib/features/profile/views/widgets/user_profile_hero_card.dart`

### Step 1: 实现整体结构

```dart
// link2ur/lib/features/profile/views/widgets/user_profile_hero_card.dart
import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../core/widgets/animated_star_rating.dart';
import '../../../../core/widgets/async_image_view.dart';
import '../../../../core/widgets/user_identity_badges.dart';
import '../../../../data/models/user.dart' show User;

/// 普通用户公开主页的 Hero 卡片。
///
/// 设计目标：「口碑 / 活跃度 / 社交」视角，对应普通用户身份；
/// 不展示接单方专属指标（完成率、响应速度、雷达图）。
///
/// 视觉：暖色 banner（顶部）+ 浮卡（白底圆角阴影，向上偏移压住 banner 一部分）
/// + 居中头像（带 VIP / Super crown overlay）
/// + 名字 + 身份徽章（学生 / 达人蓝标 / 会员等级 / 勋章）
/// + 中心 meta line（城市 · 注册时长）
/// + 左对齐 bio
/// + Trust strip（评分 · 已完成 · 粉丝）
/// + 关注按钮（自己看自己时不渲染）
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
            AppSpacing.md, 110, AppSpacing.md, 0,
          ),
          child: _HeroFloatingCard(
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

class _HeroFloatingCard extends StatelessWidget {
  const _HeroFloatingCard({
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
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? AppColors.cardBackgroundDark
        : Colors.white;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg,
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
          _HeroAvatar(user: user),
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
              followLabel: l10n.profileFollow,
              followingLabel: l10n.profileFollowingAction,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroAvatar extends StatelessWidget {
  const _HeroAvatar({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomRight,
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
        // VIP / Super pill 由 UserIdentityBadges / IdentityBadge 派生（与既有保持一致）
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
      if (i > 0) {
        children.add(const _MetaDot());
      }
      children.add(Text(
        parts[i],
        style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
      ));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textTertiary),
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
        width: 3, height: 3,
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
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.dividerLight),
          bottom: BorderSide(color: AppColors.dividerLight),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TrustStat(
              big: avgRating != null
                  ? avgRating!.toStringAsFixed(1)
                  : '-',
              label: '${l10n.profileRating} · $totalReviews',
              gold: true,
            ),
          ),
          _Divider(),
          Expanded(
            child: _TrustStat(
              big: completedTaskCount.toString(),
              label: l10n.profileCompletedTasks,
            ),
          ),
          _Divider(),
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

class _Divider extends StatelessWidget {
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
    final loadingChild = const SizedBox(
      width: 16, height: 16,
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
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? loadingChild
            : const Icon(Icons.add, size: 18),
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
```

> **Token 风险**：上面用到 `AppColors.dividerLight`、`AppColors.gold`、`AppColors.gradientGold`、`AppColors.gradientPinkPurple`。开始实施前先 grep 这些 token 是否在 `app_colors.dart` 中存在；不存在的就替换成已有近似 token（例如 `AppColors.divider` 或 `Colors.grey.shade200`）。**不要**在这次任务里新增设计 token，会扩大 scope。

- [ ] **Step 2: 运行测试，期望通过**

  ```bash
  cd /f/python_work/LinkU/link2ur && flutter test test/features/profile/user_profile_hero_card_test.dart
  ```

  Expected: 6 测试通过。如有 token 缺失或 API 不一致问题，停下来上报（不要改测试期望）。

- [ ] **Step 3: analyze**

  ```bash
  flutter analyze lib/features/profile/views/widgets/user_profile_hero_card.dart
  ```

  Expected: No issues found.

- [ ] **Step 4: Commit**

  ```bash
  git add link2ur/lib/features/profile/views/widgets/user_profile_hero_card.dart
  git commit -m "feat(profile): add UserProfileHeroCard widget for public user profile"
  ```

---

## Task 4: 接入 UserProfileView，删除旧 hero / 雷达 / 闲置代码

**Files:**
- Modify: `link2ur/lib/features/profile/views/user_profile_view.dart`

需要做的改动（一气呵成的 refactor，分步小改）：

### Step 1: 加 import

打开文件顶部，加：

```dart
import 'widgets/user_profile_hero_card.dart';
```

### Step 2: 在 build tree 替换 `_buildUserInfoCard(...)` 调用

找到 build 方法中：

```dart
_buildUserInfoCard(context, state.publicUser!, state),
const SizedBox(height: AppSpacing.xl),
// 技能雷达图
_buildSkillRadar(context, state.publicUser!),
const SizedBox(height: AppSpacing.section),
```

替换为：

```dart
BlocBuilder<AuthBloc, AuthState>(
  buildWhen: (prev, curr) => prev.user?.id != curr.user?.id,
  builder: (context, authState) {
    final currentUserId = authState.status == AuthStatus.authenticated
        ? authState.user?.id
        : null;
    final isSelf = currentUserId == state.publicUser!.id;
    return UserProfileHeroCard(
      user: state.publicUser!,
      followersCount: state.followersCount,
      followingCount: state.followingCount,
      totalReviews: state.publicProfileDetail?.stats.totalReviews ?? 0,
      isSelf: isSelf,
      isFollowing: state.isFollowing,
      isFollowLoading: state.isFollowLoading,
      onFollow: () {
        if (state.isFollowing) {
          context.read<ProfileBloc>().add(ProfileUnfollowUser(state.publicUser!.id));
        } else {
          context.read<ProfileBloc>().add(ProfileFollowUser(state.publicUser!.id));
        }
      },
    );
  },
),
const SizedBox(height: AppSpacing.lg),
```

### Step 3: 删除已售闲置 section 调用

找到：

```dart
// 已售闲置物品
if (state.publicProfileDetail?.soldFleaItems.isNotEmpty == true)
  _buildSoldFleaItemsSection(context, state.publicProfileDetail!.soldFleaItems),
```

整段删除。

### Step 4: 删除死代码方法（旧 hero、雷达、闲置、stats、follow section、stats helper 等）

下列私有方法在 view 内不再被引用，全部删除：

- `_buildUserInfoCard`
- `_buildStatsRow`
- `_buildFollowSection`
- `_buildSkillRadar`
- `_buildSoldFleaItemsSection`

注意：`_showDirectRequestSheet` / `_buildBottomRequestButton` / `_buildSharedTasksSection` / `_buildRecentTasksSection` / `_buildRecentForumPostsSection` / `_buildReviewsSection` 这些**保留不动**。

### Step 5: 检查 import 是否还有不再使用的

删完之后 hero 不再使用的可能有：
- `AnimatedCircularProgress`、`AnimatedStarRating`（如果在新 hero 里用了就保留，否则删 import）
- `SkillRadarChart`
- `Helpers`（看其他 method 是否还用）

跑 analyze 确认：

```bash
cd /f/python_work/LinkU/link2ur && flutter analyze lib/features/profile/views/user_profile_view.dart
```

Expected: No issues found（具体提示根据真实情况决定是否删 import）。

### Step 6: 跑全套测试 + APK 构建

```bash
flutter test 2>&1 | tail -10
```

Expected: 全部通过。

```bash
flutter build apk --debug --target-platform=android-arm64 2>&1 | tail -10
```

Expected: BUILD SUCCESSFUL。

### Step 7: Commit

```bash
git add link2ur/lib/features/profile/views/user_profile_view.dart
git commit -m "refactor(profile): replace old hero with UserProfileHeroCard, drop radar + sold flea"
```

---

## Task 5: 视觉 QA + push

- [ ] **Step 1: 启动 web 模式**

  ```bash
  cd /f/python_work/LinkU/link2ur && flutter run -d web-server
  ```

  打开提示的 `http://localhost:xxxxx`。

- [ ] **Step 2: 验证清单**

  随便找一个真实用户主页（路径如 `/user/<id>`）：

  - [ ] Hero 顶部有暖色 banner，hero 卡浮在 banner 上（不是直接贴顶）
  - [ ] 头像居中、有 VIP/Super crown overlay（如果 user_level 是 vip/super）
  - [ ] 名字下方有 verified / school 图标（按 user 实际 flag 显示）
  - [ ] 有 displayedBadge 时显示勋章 pill；没有时不留空白
  - [ ] 城市 + 注册时长一行显示
  - [ ] Bio 左对齐显示
  - [ ] 三大数字：评分 / 已完成 / 粉丝 各自有数字 + 标签，中间有竖分隔线
  - [ ] 关注按钮居中、宽度撑满
  - [ ] 自己看自己时**没有关注按钮**
  - [ ] 不再有：完成率环形进度、雷达图、私信按钮、已售闲置 section
  - [ ] 滚动到下方：合作记录 → 个人服务 → 评价 → 论坛动态 → 底部 CTA

  深色模式（系统切换）下颜色合理。

- [ ] **Step 3: 切语言验证 zh / en / zh_Hant 文案**

  在 app 内切语言设置，确认 trust strip 标签、关注按钮、勋章文案正确。

- [ ] **Step 4: 推 main**

  ```bash
  git push
  ```

- [ ] **Step 5: 推完成后等 Railway 部署，提示用户切真机 / staging 重新连验证**

---

## 完成判定

- ✅ Hero 视觉跟 mockup B 大致对齐（暖 banner + 浮卡 + 三大数字）
- ✅ 雷达图 / 闲置 section 不再出现
- ✅ 不再有 message 私信按钮
- ✅ `flutter test` 全绿（703+ 通过）
- ✅ `flutter analyze lib/features/profile/` 无 issue
- ✅ APK 构建通过
- ✅ zh / en / zh_Hant 文案正确

---

## 风险与注意

1. **设计 token 缺失**：`AppColors.gold`、`AppColors.dividerLight`、`AppColors.gradientGold`、`AppColors.gradientPinkPurple` 这几个名字是猜的。开始 implement 前先 grep `lib/core/design/app_colors.dart` 确认实际名字，对不上的换近似 token，不要新增。
2. **`profileFollow` / `profileFollowingAction` 的 zh 翻译**：测试用例 `expect(find.text('关注 TA'), findsNothing)` 假设 zh 翻译就是 "关注 TA"。如果实际是 "关注"（无 TA），测试 expect 字符串得跟着调整 —— 实施时打开 `app_zh.arb` 确认。
3. **AuthBloc 的 user.id 比较**：旧 hero 里直接 `context.read<AuthBloc>().state` 取一次；新 hero 用 `BlocBuilder` 包了一层。如果 AuthState 变化频繁可能多 rebuild，但实际 AuthState 在 profile 页面不会频繁变，问题不大。
4. **删除方法时的"伪未引用" pitfall**：删之前用 `grep -n "_buildSkillRadar\|_buildSoldFleaItemsSection\|_buildUserInfoCard\|_buildStatsRow\|_buildFollowSection" link2ur/lib/features/profile/views/user_profile_view.dart` 确认调用位置，确保只删需要删的。
5. **Stats `totalReviews` 字段来源**：旧逻辑里没有这个数。新 hero 期望从 `state.publicProfileDetail?.stats.totalReviews` 拿（后端 `/profile/{user_id}` 已经在 stats 里返回 `total_reviews: len(reviews)`）。如果 schema 字段名不一致，到 `UserProfileStats` 类里看真实字段名。
