part of 'home_view.dart';

/// 推荐Tab — 桌面端使用 Grid 布局，移动端保持原样
class _RecommendedTab extends StatelessWidget {
  const _RecommendedTab();

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        return RefreshIndicator(
          onRefresh: () async {
            context.read<HomeBloc>().add(const HomeRefreshRequested());
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: CustomScrollView(
            slivers: [
              // 欢迎区域
              SliverToBoxAdapter(
                child: _GreetingSection(),
              ),

              // Banner 区域 — 桌面端并排，移动端轮播
              SliverToBoxAdapter(
                child: isDesktop
                    ? const _DesktopBannerRow()
                    : const _BannerCarousel(),
              ),

              // 推荐任务标题
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 40 : AppSpacing.md,
                    AppSpacing.lg,
                    isDesktop ? 40 : AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.homeRecommendedTasks,
                        style: AppTypography.title3.copyWith(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textPrimaryDark
                              : const Color(0xFF37352F),
                        ),
                      ),
                      _ViewAllButton(
                        onTap: () => context.push('/tasks'),
                      ),
                    ],
                  ),
                ),
              ),

              // 推荐任务内容
              if (state.isLoading && state.recommendedTasks.isEmpty)
                const SliverFillRemaining(
                  child: SkeletonList(),
                )
              else if (state.hasError && state.recommendedTasks.isEmpty)
                SliverFillRemaining(
                  child: ErrorStateView(
                    message: state.errorMessage ?? context.l10n.homeLoadFailed,
                    onRetry: () {
                      context.read<HomeBloc>().add(const HomeLoadRequested());
                    },
                  ),
                )
              else if (state.recommendedTasks.isEmpty)
                SliverFillRemaining(
                  child: EmptyStateView.noTasks(
                    actionText: context.l10n.homePublishTask,
                    onAction: () => context.push('/tasks/create'),
                  ),
                )
              else ...[
                // 推荐任务 — 桌面端 3 列 Grid，移动端横向滚动
                if (isDesktop)
                  _buildDesktopTaskGrid(context, state)
                else
                  _buildMobileTaskScroll(state),

                // 热门活动标题
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 40 : AppSpacing.md,
                      AppSpacing.lg,
                      isDesktop ? 40 : AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.homeHotEvents,
                          style: AppTypography.title3.copyWith(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.textPrimaryDark
                                : const Color(0xFF37352F),
                          ),
                        ),
                        _ViewAllButton(
                          onTap: () => context.push('/activities'),
                        ),
                      ],
                    ),
                  ),
                ),

                // 热门活动 — 桌面端 3 列 Row，移动端横向滚动
                SliverToBoxAdapter(
                  child: isDesktop
                      ? const _DesktopActivitiesRow()
                      : _PopularActivitiesSection(),
                ),

                // 最新动态标题
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 40 : AppSpacing.md,
                      AppSpacing.lg,
                      isDesktop ? 40 : AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Text(
                      context.l10n.homeLatestActivity,
                      style: AppTypography.title3.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textPrimaryDark
                            : const Color(0xFF37352F),
                      ),
                    ),
                  ),
                ),

                // 最新动态列表
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 40 : AppSpacing.md,
                    ),
                    child: _RecentActivitiesSection(),
                  ),
                ),
              ],

              const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
            ],
          ),
        );
      },
    );
  }

  /// 桌面端 3 列 Grid 任务卡片
  Widget _buildDesktopTaskGrid(BuildContext context, HomeState state) {
    final tasks = state.recommendedTasks.take(9).toList();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: ResponsiveUtils.gridColumnCount(context, type: GridItemType.task),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.82,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _DesktopTaskCard(task: tasks[index]),
          childCount: tasks.length,
        ),
      ),
    );
  }

  /// 移动端横向滚动任务卡片（保持原样）
  Widget _buildMobileTaskScroll(HomeState state) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 256,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.only(
            left: AppSpacing.md, right: AppSpacing.lg, top: 4, bottom: 10,
          ),
          itemCount: state.recommendedTasks.length > 10
              ? 10
              : state.recommendedTasks.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final task = state.recommendedTasks[index];
            return AnimatedListItem(
              index: index,
              child: _HorizontalTaskCard(task: task),
            );
          },
        ),
      ),
    );
  }
}

/// "查看全部" 按钮 — Notion 风格
class _ViewAllButton extends StatefulWidget {
  const _ViewAllButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_ViewAllButton> createState() => _ViewAllButtonState();
}

class _ViewAllButtonState extends State<_ViewAllButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.commonViewAll,
              style: TextStyle(
                fontSize: 14,
                color: _isHovered ? AppColors.primary : AppColors.primary.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: _isHovered ? AppColors.primary : AppColors.primary.withValues(alpha: 0.8),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

/// 桌面端 Banner 并排行
class _DesktopBannerRow extends StatelessWidget {
  const _DesktopBannerRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: SizedBox(
        height: 180,
        child: Row(
          children: [
            Expanded(
              child: _BannerItem(
                title: context.l10n.homeSecondHandMarket,
                subtitle: context.l10n.homeSecondHandSubtitle,
                gradient: const [Color(0xFF34C759), Color(0xFF30D158)],
                icon: Icons.storefront,
                imagePath: AppAssets.fleaMarketBanner,
                onTap: () => context.push('/flea-market'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BannerItem(
                title: context.l10n.homeStudentVerification,
                subtitle: context.l10n.homeStudentVerificationSubtitle,
                gradient: const [Color(0xFF5856D6), Color(0xFF007AFF)],
                icon: Icons.school,
                imagePath: AppAssets.studentVerificationBanner,
                onTap: () => context.push('/student-verification'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BannerItem(
                title: context.l10n.homeBecomeExpert,
                subtitle: context.l10n.homeBecomeExpertSubtitle,
                gradient: const [Color(0xFFFF9500), Color(0xFFFF6B00)],
                icon: Icons.star,
                onTap: () => context.push('/task-experts/intro'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 桌面端活动 3 列行
class _DesktopActivitiesRow extends StatelessWidget {
  const _DesktopActivitiesRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: SizedBox(
        height: 160,
        child: Row(
          children: [
            Expanded(
              child: _ActivityCard(
                title: context.l10n.homeNewUserReward,
                subtitle: context.l10n.homeNewUserRewardSubtitle,
                gradient: const [Color(0xFFFF6B6B), Color(0xFFFF4757)],
                icon: Icons.card_giftcard,
                onTap: () => context.push('/activities'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActivityCard(
                title: context.l10n.homeInviteFriends,
                subtitle: context.l10n.homeInviteFriendsSubtitle,
                gradient: const [Color(0xFF7C5CFC), Color(0xFF5F27CD)],
                icon: Icons.people,
                onTap: () => context.push('/activities'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActivityCard(
                title: context.l10n.homeDailyCheckIn,
                subtitle: context.l10n.homeDailyCheckInSubtitle,
                gradient: const [Color(0xFF2ED573), Color(0xFF00B894)],
                icon: Icons.calendar_today,
                onTap: () => context.push('/activities'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 桌面端任务卡片（自适应宽度，带 hover 效果）
class _DesktopTaskCard extends StatefulWidget {
  const _DesktopTaskCard({required this.task});
  final Task task;

  @override
  State<_DesktopTaskCard> createState() => _DesktopTaskCardState();
}

class _DesktopTaskCardState extends State<_DesktopTaskCard> {
  bool _isHovered = false;

  // 任务类型图标 — 使用统一映射
  IconData _taskTypeIcon(String taskType) => TaskTypeHelper.getIcon(taskType);

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
    final task = widget.task;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push('/tasks/${task.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardBackgroundDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? (isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFCCCCCC))
                  : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE8E8E5)),
              width: 1,
            ),
            boxShadow: _isHovered
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          transform: _isHovered
              ? Matrix4.translationValues(0.0, -2.0, 0.0)
              : Matrix4.identity(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图片区域
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (task.firstImage != null)
                      AsyncImageView(
                        imageUrl: task.firstImage!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.08),
                              AppColors.primary.withValues(alpha: 0.03),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            _taskTypeIcon(task.taskType),
                            color: AppColors.primary.withValues(alpha: 0.2),
                            size: 36,
                          ),
                        ),
                      ),
                    // 位置标签
                    if (task.location != null)
                      Positioned(
                        top: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                task.isOnline ? Icons.language : Icons.location_on,
                                size: 11, color: isDark ? Colors.white : const Color(0xFF37352F),
                              ),
                              const SizedBox(width: 3),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 80),
                                child: Text(
                                  task.location!,
                                  style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white : const Color(0xFF37352F),
                                  ),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // 右上: 推荐徽章
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF9500), Color(0xFFFF6B00)],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF9500).withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome, size: 10, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              context.l10n.homeRecommendedBadge,
                              style: const TextStyle(
                                fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 内容区域
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.displayTitle,
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textPrimaryDark : const Color(0xFF37352F),
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      if (task.displayDescription != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          task.displayDescription!,
                          style: TextStyle(
                            fontSize: 12, color: isDark ? AppColors.textSecondaryDark : const Color(0xFF9B9A97),
                            height: 1.4,
                          ),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          if (task.deadline != null) ...[
                            Icon(Icons.schedule, size: 12,
                                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF9B9A97)),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                _formatDeadline(context, task.deadline!),
                                style: TextStyle(fontSize: 11,
                                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF9B9A97)),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ] else
                            const Spacer(),
                          if (task.reward > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${task.currency == 'GBP' ? '£' : '\$'}${task.reward.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
