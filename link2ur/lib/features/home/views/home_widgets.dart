part of 'home_view.dart';

/// 对标iOS: GreetingSection - 个性化问候语
class _GreetingSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final authState = context.watch<AuthBloc>().state;
    final userName = authState.isAuthenticated
        ? (authState.user?.name ?? context.l10n.homeDefaultUser)
        : context.l10n.homeClassmate;

    final horizontalPadding = isDesktop ? 40.0 : AppSpacing.md;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          horizontalPadding, AppSpacing.lg, horizontalPadding, AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.homeGreeting(userName),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.homeWhatToDo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          // 对标iOS: Image(systemName: "sparkles") + .ultraThinMaterial + Circle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: AppColors.primary,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

/// 对标iOS: BannerCarouselSection - 横幅轮播
class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel();

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: SizedBox(
            height: 162,
            child: PageView(
              clipBehavior: Clip.none,
            controller: _controller,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: [
              // 对标iOS: 跳蚤市场Banner — 使用真实图片
              _BannerItem(
                title: context.l10n.homeSecondHandMarket,
                subtitle: context.l10n.homeSecondHandSubtitle,
                gradient: const [Color(0xFF34C759), Color(0xFF30D158)],
                icon: Icons.storefront,
                imagePath: AppAssets.fleaMarketBanner,
                onTap: () => context.push('/flea-market'),
              ),
              // 对标iOS: 学生认证Banner — 使用真实图片
              _BannerItem(
                title: context.l10n.homeStudentVerification,
                subtitle: context.l10n.homeStudentVerificationSubtitle,
                gradient: const [Color(0xFF5856D6), Color(0xFF007AFF)],
                icon: Icons.school,
                imagePath: AppAssets.studentVerificationBanner,
                onTap: () => context.push('/student-verification'),
              ),
              // 任务达人Banner
              _BannerItem(
                title: context.l10n.homeBecomeExpert,
                subtitle: context.l10n.homeBecomeExpertSubtitle,
                gradient: const [Color(0xFFFF9500), Color(0xFFFF6B00)],
                icon: Icons.star,
                onTap: () => context.push('/task-experts/intro'),
              ),
            ],
          ),
          ),
        ),
        // 页面指示器
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: _currentPage == index ? 18 : 6,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.2),
                borderRadius: AppRadius.allPill,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _BannerItem extends StatelessWidget {
  const _BannerItem({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
    required this.onTap,
    this.imagePath,
  });

  final String title;
  final String subtitle;
  final List<Color> gradient;
  final IconData icon;
  final VoidCallback onTap;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 4, 4, 10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: imagePath == null
              ? LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: AppRadius.allLarge,
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 真实图片背景
            if (imagePath != null)
              Image.asset(
                imagePath!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // 图片加载失败时回退到渐变背景
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  );
                },
              ),
            // 图片上的渐变遮罩，保证文字可读
            if (imagePath != null)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            // 装饰图标（无图片时显示）
            if (imagePath == null)
              Positioned(
                right: 20,
                bottom: 10,
                child: Icon(
                  icon,
                  size: 80,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            // 文字内容
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      shadows: const [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 对标iOS: PopularActivitiesSection - 热门活动区域
class _PopularActivitiesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 164,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.lg,
          top: 4,
          bottom: 10,
        ),
        children: [
          _ActivityCard(
            title: context.l10n.homeNewUserReward,
            subtitle: context.l10n.homeNewUserRewardSubtitle,
            gradient: const [Color(0xFFFF6B6B), Color(0xFFFF4757)],
            icon: Icons.card_giftcard,
            onTap: () => context.push('/activities'),
          ),
          const SizedBox(width: 12),
          _ActivityCard(
            title: context.l10n.homeInviteFriends,
            subtitle: context.l10n.homeInviteFriendsSubtitle,
            gradient: const [Color(0xFF7C5CFC), Color(0xFF5F27CD)],
            icon: Icons.people,
            onTap: () => context.push('/activities'),
          ),
          const SizedBox(width: 12),
          _ActivityCard(
            title: context.l10n.homeDailyCheckIn,
            subtitle: context.l10n.homeDailyCheckInSubtitle,
            gradient: const [Color(0xFF2ED573), Color(0xFF00B894)],
            icon: Icons.calendar_today,
            onTap: () => context.push('/activities'),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final List<Color> gradient;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.allLarge,
          // 对标iOS: 彩色阴影，更有深度感
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: gradient.last.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 装饰性大圆 (右下角，增加层次感)
            Positioned(
              right: -20,
              bottom: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            // 装饰性小圆 (右上角)
            Positioned(
              right: 20,
              top: -10,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            // 主内容
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 毛玻璃效果图标容器（对标iOS Material风格）
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 对标iOS: RecentActivitiesSection - 最新动态区域
class _RecentActivitiesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 模拟最新动态数据 (实际应从API获取)
    final activities = [
      _RecentActivityData(
        icon: Icons.forum,
        iconGradient: const [Color(0xFF34C759), Color(0xFF30D158)],
        userName: context.l10n.homeDefaultUser,
        actionText: context.l10n.homePostedNewPost,
        title: context.l10n.homeCampusLife,
        description: context.l10n.homeCampusLifeDesc,
      ),
      _RecentActivityData(
        icon: Icons.shopping_bag,
        iconGradient: const [Color(0xFFFF9500), Color(0xFFFF6B00)],
        userName: context.l10n.homeDefaultUser,
        actionText: context.l10n.homePostedNewProduct,
        title: context.l10n.homeUsedBooks,
      ),
      _RecentActivityData(
        icon: Icons.emoji_events,
        iconGradient: const [Color(0xFF5856D6), Color(0xFF007AFF)],
        userName: context.l10n.homeSystemUser,
        actionText: context.l10n.homeCreatedLeaderboard,
        title: context.l10n.homeWeeklyExperts,
      ),
    ];

    if (activities.isEmpty) {
      return Padding(
        padding: AppSpacing.allMd,
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.notifications_none,
                size: 48,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
              AppSpacing.vSm,
              Text(
                context.l10n.homeNoActivity,
                style: AppTypography.body.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              AppSpacing.vXs,
              Text(
                context.l10n.homeNoActivityMessage,
                style: AppTypography.caption.copyWith(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: AppSpacing.horizontalMd,
      child: Column(
        children: activities.map((activity) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ActivityRow(activity: activity),
          );
        }).toList(),
      ),
    );
  }
}

class _RecentActivityData {
  _RecentActivityData({
    required this.icon,
    required this.iconGradient,
    required this.userName,
    required this.actionText,
    required this.title,
    this.description,
  });

  final IconData icon;
  final List<Color> iconGradient;
  final String userName;
  final String actionText;
  final String title;

  final String? description;
}

/// 对标iOS: ActivityRow - 动态行组件（对标iOS .cardBackground + AppShadow.small）
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final _RecentActivityData activity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allLarge,
        // 对标iOS: 0.5pt separator边框
        border: Border.all(
          color: (isDark ? AppColors.separatorDark : AppColors.separatorLight)
              .withValues(alpha: 0.3),
          width: 0.5,
        ),
        // 对标iOS: 双层阴影
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // 对标iOS: 渐变图标 + 圆形 + 彩色阴影
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: activity.iconGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: activity.iconGradient.first.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              activity.icon,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 对标iOS: 合并用户名和动作文本 (body + semibold + secondary)
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: activity.userName,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      TextSpan(
                        text: ' ${activity.actionText}',
                        style: AppTypography.body.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  activity.title,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (activity.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    activity.description!,
                    style: AppTypography.caption.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 16,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
        ],
      ),
    );
  }
}

/// 对标iOS: 横向任务卡片 (完全对标 iOS TaskCard 风格)
/// 图片(160px) + 3段渐变遮罩 + ultraThinMaterial毛玻璃标签 + 任务类型标签 + 双层阴影
class _HorizontalTaskCard extends StatelessWidget {
  const _HorizontalTaskCard({required this.task});

  final Task task;

  // 任务类型图标映射（对标iOS SF Symbols → Material Icons）
  IconData _taskTypeIcon(String taskType) {
    switch (taskType) {
      case 'delivery':
        return Icons.local_shipping_outlined;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'tutoring':
        return Icons.school_outlined;
      case 'translation':
        return Icons.translate;
      case 'design':
        return Icons.design_services_outlined;
      case 'photography':
        return Icons.camera_alt_outlined;
      case 'moving':
        return Icons.local_shipping_outlined;
      case 'cleaning':
        return Icons.cleaning_services_outlined;
      case 'pet_care':
        return Icons.pets_outlined;
      case 'errand':
        return Icons.directions_run;
      default:
        return Icons.task_alt;
    }
  }

  String _formatDeadline(BuildContext context, DateTime deadline) {
    final now = DateTime.now();
    final diff = deadline.difference(now);
    if (diff.isNegative) return context.l10n.homeDeadlineExpired;
    if (diff.inDays > 0) return context.l10n.homeDeadlineDays(diff.inDays);
    if (diff.inHours > 0) return context.l10n.homeDeadlineHours(diff.inHours);
    return context.l10n.homeDeadlineMinutes(diff.inMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/tasks/${task.id}');
      },
      child: Container(
        width: 220,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allLarge,
          // 对标iOS: 0.5pt separator边框
          border: Border.all(
            color: (isDark ? AppColors.separatorDark : AppColors.separatorLight)
                .withValues(alpha: 0.3),
            width: 0.5,
          ),
          // 对标iOS: 双层阴影 - primary色柔和扩散 + 黑色紧密底部
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== 图片区域 (对标iOS + 3段渐变 + 毛玻璃标签) =====
            SizedBox(
              height: 170,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 图片或占位背景（对标iOS placeholderBackground）
                  if (task.firstImage != null)
                    Hero(
                      tag: 'task_image_${task.id}',
                      child: AsyncImageView(
                        imageUrl: task.firstImage!,
                        width: 220,
                        height: 170,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.12),
                            AppColors.primary.withValues(alpha: 0.04),
                          ],
                        ),
                      ),
                      child: Icon(
                        _taskTypeIcon(task.taskType),
                        color: AppColors.primary.withValues(alpha: 0.25),
                        size: 44,
                      ),
                    ),

                  // 对标iOS: 3段渐变遮罩（0.2→0.0→0.4）
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.20),
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.40),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),

                  // 左上: 位置标签 (对标iOS .ultraThinMaterial + Capsule)
                  if (task.location != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: ClipRRect(
                        borderRadius: AppRadius.allPill,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: AppRadius.allPill,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  task.isOnline
                                      ? Icons.language
                                      : Icons.location_on,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 3),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 80),
                                  child: Text(
                                    task.location!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 右下: 任务类型标签 (对标iOS taskType capsule + .ultraThinMaterial)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: ClipRRect(
                      borderRadius: AppRadius.allPill,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: AppRadius.allPill,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _taskTypeIcon(task.taskType),
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                task.taskTypeText,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ===== 内容区域 (对标iOS - title + deadline + price badge) =====
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题（对标iOS .body字号 + lineLimit(2)）
                  Text(
                    task.displayTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // 底部: 截止时间 + 价格标签（对标iOS底部信息栏）
                  Row(
                      children: [
                        // 截止时间 (对标iOS clock.fill + formatDeadline)
                        if (task.deadline != null) ...[
                          Icon(
                            Icons.schedule,
                            size: 12,
                            color: task.isExpired
                                ? AppColors.error
                                : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              _formatDeadline(context, task.deadline!),
                              style: TextStyle(
                                fontSize: 11,
                                color: task.isExpired
                                    ? AppColors.error
                                    : (isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else
                          const Spacer(),
                        // 价格标签 (对标iOS 绿色Capsule + £符号分离)
                        if (task.reward > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: AppRadius.allPill,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  task.currency == 'GBP' ? '£' : '\$',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  task.reward.toStringAsFixed(0),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 对标iOS: NearbyTasksView (附近Tab)
class _NearbyTab extends StatelessWidget {
  const _NearbyTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        if (state.nearbyTasks.isEmpty && !state.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_off_outlined,
                  size: 64,
                  color: AppColors.textTertiaryLight,
                ),
                AppSpacing.vMd,
                Text(
                  context.l10n.homeNoNearbyTasks,
                  style: const TextStyle(color: AppColors.textSecondaryLight),
                ),
                AppSpacing.vMd,
                TextButton.icon(
                  onPressed: () {
                    context.read<HomeBloc>().add(
                          const HomeLoadNearby(
                            latitude: 51.5074,
                            longitude: -0.1278,
                          ),
                        );
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.homeLoadNearbyTasks),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<HomeBloc>().add(
                  const HomeLoadNearby(
                    latitude: 51.5074,
                    longitude: -0.1278,
                  ),
                );
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.separated(
            padding: AppSpacing.allMd,
            itemCount: state.nearbyTasks.length,
            separatorBuilder: (_, __) => AppSpacing.vMd,
            itemBuilder: (context, index) {
              return _TaskCard(task: state.nearbyTasks[index]);
            },
          ),
        );
      },
    );
  }
}

/// 对标iOS: TaskExpertListContentView (达人Tab)
class _ExpertsTab extends StatelessWidget {
  const _ExpertsTab();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // 对标iOS: 搜索框
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: GestureDetector(
            onTap: () => context.push('/task-experts'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.cardBackgroundDark
                    : AppColors.cardBackgroundLight,
                borderRadius: AppRadius.allMedium,
                border: Border.all(
                  color: (isDark ? AppColors.dividerDark : AppColors.dividerLight)
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    context.l10n.homeSearchExperts,
                    style: AppTypography.subheadline.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 对标iOS: 达人列表
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.star_outline,
                  size: 64,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
                AppSpacing.vMd,
                Text(
                  context.l10n.homeExperts,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                AppSpacing.vMd,
                TextButton(
                  onPressed: () {
                    context.push('/task-experts');
                  },
                  child: Text(context.l10n.homeBrowseExperts),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 任务卡片 - 垂直列表（对标iOS TaskCard风格：图片在上 + 内容在下）
class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final Task task;

  IconData _taskTypeIcon(String taskType) {
    switch (taskType) {
      case 'delivery':
        return Icons.local_shipping_outlined;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'tutoring':
        return Icons.school_outlined;
      case 'translation':
        return Icons.translate;
      case 'design':
        return Icons.design_services_outlined;
      case 'photography':
        return Icons.camera_alt_outlined;
      case 'moving':
        return Icons.local_shipping_outlined;
      case 'cleaning':
        return Icons.cleaning_services_outlined;
      case 'pet_care':
        return Icons.pets_outlined;
      case 'errand':
        return Icons.directions_run;
      default:
        return Icons.task_alt;
    }
  }

  String _formatDeadline(BuildContext context, DateTime deadline) {
    final now = DateTime.now();
    final diff = deadline.difference(now);
    if (diff.isNegative) return context.l10n.homeDeadlineExpired;
    if (diff.inDays > 0) return context.l10n.homeDeadlineDays(diff.inDays);
    if (diff.inHours > 0) return context.l10n.homeDeadlineHours(diff.inHours);
    return context.l10n.homeDeadlineMinutes(diff.inMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/tasks/${task.id}');
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allLarge,
          // 对标iOS: 0.5pt separator边框
          border: Border.all(
            color: (isDark ? AppColors.separatorDark : AppColors.separatorLight)
                .withValues(alpha: 0.3),
            width: 0.5,
          ),
          // 对标iOS: 双层阴影
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== 图片区域 (对标iOS 140px + 渐变 + 毛玻璃标签) =====
            SizedBox(
              height: 140,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 图片或占位背景
                  if (task.firstImage != null)
                    AsyncImageView(
                      imageUrl: task.firstImage!,
                      width: double.infinity,
                      height: 140,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.12),
                            AppColors.primary.withValues(alpha: 0.04),
                          ],
                        ),
                      ),
                      child: Icon(
                        _taskTypeIcon(task.taskType),
                        color: AppColors.primary.withValues(alpha: 0.25),
                        size: 48,
                      ),
                    ),

                  // 3段渐变遮罩
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.35),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),

                  // 左上: 位置标签 (毛玻璃)
                  if (task.location != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: ClipRRect(
                        borderRadius: AppRadius.allPill,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: AppRadius.allPill,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  task.isOnline
                                      ? Icons.language
                                      : Icons.location_on,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 3),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 140),
                                  child: Text(
                                    task.location!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 右下: 任务类型标签 (毛玻璃)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: ClipRRect(
                      borderRadius: AppRadius.allPill,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: AppRadius.allPill,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _taskTypeIcon(task.taskType),
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                task.taskTypeText,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ===== 内容区域 =====
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(
                    task.displayTitle,
                    style: AppTypography.bodyBold.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (task.displayDescription != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.displayDescription!,
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  // 底部信息栏（对标iOS: 截止时间 + 状态 + 价格）
                  Row(
                    children: [
                      // 截止时间
                      if (task.deadline != null) ...[
                        Icon(
                          Icons.schedule,
                          size: 13,
                          color: task.isExpired
                              ? AppColors.error
                              : (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            _formatDeadline(context, task.deadline!),
                            style: TextStyle(
                              fontSize: 12,
                              color: task.isExpired
                                  ? AppColors.error
                                  : (isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else
                        const Spacer(),
                      // 状态标签（对标iOS StatusBadge: 圆点+文字）
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.taskStatusColor(task.status)
                              .withValues(alpha: 0.1),
                          borderRadius: AppRadius.allPill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.taskStatusColor(task.status),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              task.statusText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.taskStatusColor(task.status),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 价格标签（对标iOS绿色Capsule）
                      if (task.reward > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: AppRadius.allPill,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                task.currency == 'GBP' ? '£' : '\$',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                task.reward.toStringAsFixed(0),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 对标iOS: MenuView - 菜单视图
class _MenuView extends StatelessWidget {
  const _MenuView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 拖拽指示器
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.menuMenu,
                  style: AppTypography.title3.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.menuClose),
                ),
              ],
            ),
          ),
          // 对标iOS: 菜单项列表
          Expanded(
            child: ListView(
              padding: AppSpacing.horizontalMd,
              children: [
                _MenuListItem(
                  icon: Icons.person,
                  title: context.l10n.menuMy,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/profile');
                  },
                ),
                _MenuListItem(
                  icon: Icons.list_alt,
                  title: context.l10n.menuTaskHall,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/tasks');
                  },
                ),
                _MenuListItem(
                  icon: Icons.star,
                  title: context.l10n.menuTaskExperts,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/task-experts');
                  },
                ),
                _MenuListItem(
                  icon: Icons.forum,
                  title: context.l10n.menuForum,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/forum');
                  },
                ),
                _MenuListItem(
                  icon: Icons.emoji_events,
                  title: context.l10n.menuLeaderboard,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/leaderboard');
                  },
                ),
                _MenuListItem(
                  icon: Icons.shopping_cart,
                  title: context.l10n.menuFleaMarket,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/flea-market');
                  },
                ),
                _MenuListItem(
                  icon: Icons.calendar_month,
                  title: context.l10n.menuActivity,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/activities');
                  },
                ),
                _MenuListItem(
                  icon: Icons.stars,
                  title: context.l10n.menuPointsCoupons,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/coupon-points');
                  },
                ),
                _MenuListItem(
                  icon: Icons.verified_user,
                  title: context.l10n.menuStudentVerification,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/student-verification');
                  },
                ),
                const Divider(height: 32),
                _MenuListItem(
                  icon: Icons.settings,
                  title: context.l10n.menuSettings,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/settings');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuListItem extends StatelessWidget {
  const _MenuListItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(
        icon,
        color: isDark
            ? AppColors.textPrimaryDark
            : AppColors.textPrimaryLight,
        size: 22,
      ),
      title: Text(
        title,
        style: AppTypography.body.copyWith(
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark
            ? AppColors.textTertiaryDark
            : AppColors.textTertiaryLight,
        size: 18,
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// 对标iOS: SearchView - 搜索视图
class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';

  // 热门搜索关键词
  List<String> _getHotKeywords(BuildContext context) => [
    context.l10n.taskCategoryPickup,
    context.l10n.taskCategoryTutoring,
    context.l10n.taskCategoryMoving,
    context.l10n.taskCategoryPurchasing,
    context.l10n.taskCategoryDogWalking,
    context.l10n.taskCategoryTranslation,
    context.l10n.taskCategoryPhotography,
    context.l10n.taskCategoryTutor,
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 拖拽指示器
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          AppSpacing.vSm,

          // 搜索栏
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onChanged: (value) =>
                        setState(() => _searchQuery = value),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        Navigator.pop(context);
                        context.push('/tasks');
                      }
                    },
                    decoration: InputDecoration(
                      hintText: context.l10n.searchPlaceholder,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.secondaryBackgroundDark
                          : AppColors.backgroundLight,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.allSmall,
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                AppSpacing.hSm,
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.commonCancel),
                ),
              ],
            ),
          ),

          // 搜索内容
          Expanded(
            child: _searchQuery.isEmpty
                ? _buildSearchHome(isDark)
                : _buildSearchResults(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHome(bool isDark) {
    return SingleChildScrollView(
      padding: AppSpacing.allMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.homeHotSearches,
            style: AppTypography.title3.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          AppSpacing.vMd,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _getHotKeywords(context).map((keyword) {
              return GestureDetector(
                onTap: () {
                  _searchController.text = keyword;
                  setState(() => _searchQuery = keyword);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.secondaryBackgroundDark
                        : AppColors.backgroundLight,
                    borderRadius: AppRadius.allPill,
                  ),
                  child: Text(
                    keyword,
                    style: AppTypography.caption.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          AppSpacing.vXl,

          // 搜索分类
          Text(
            context.l10n.homeSearchCategory,
            style: AppTypography.title3.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          AppSpacing.vMd,
          _SearchCategoryItem(
            icon: Icons.task_alt,
            title: context.l10n.homeSearchTasks,
            color: AppColors.primary,
            onTap: () {
              Navigator.pop(context);
              context.push('/tasks');
            },
          ),
          _SearchCategoryItem(
            icon: Icons.star,
            title: context.l10n.homeSearchExperts,
            color: AppColors.accent,
            onTap: () {
              Navigator.pop(context);
              context.push('/task-experts');
            },
          ),
          _SearchCategoryItem(
            icon: Icons.storefront,
            title: context.l10n.homeSearchFleaMarket,
            color: AppColors.success,
            onTap: () {
              Navigator.pop(context);
              context.push('/flea-market');
            },
          ),
          _SearchCategoryItem(
            icon: Icons.forum,
            title: context.l10n.homeSearchPosts,
            color: AppColors.teal,
            onTap: () {
              Navigator.pop(context);
              context.push('/forum');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 48,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
          AppSpacing.vMd,
          Text(
            context.l10n.homeSearchQueryResult(_searchQuery),
            style: AppTypography.body.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          AppSpacing.vSm,
          Text(
            context.l10n.homePressEnterToSearch,
            style: AppTypography.caption.copyWith(
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchCategoryItem extends StatelessWidget {
  const _SearchCategoryItem({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppRadius.allSmall,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            AppSpacing.hMd,
            Expanded(
              child: Text(
                title,
                style: AppTypography.body.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ],
        ),
      ),
    );
  }
}
