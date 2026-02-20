part of 'home_view.dart';

/// 推荐Tab — 桌面端使用 Grid 布局，移动端保持原样
class _RecommendedTab extends StatelessWidget {
  const _RecommendedTab();

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return BlocBuilder<HomeBloc, HomeState>(
      // 推荐任务、热门活动（开放中）数据或状态变化时重建
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.recommendedTasks != curr.recommendedTasks ||
          prev.isRefreshing != curr.isRefreshing ||
          prev.openActivities != curr.openActivities ||
          prev.isLoadingOpenActivities != curr.isLoadingOpenActivities ||
          prev.recommendedFilterCategory != curr.recommendedFilterCategory ||
          prev.recommendedSortBy != curr.recommendedSortBy,
      builder: (context, state) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return RefreshIndicator(
          onRefresh: () async {
            final bloc = context.read<HomeBloc>();
            bloc.add(const HomeRefreshRequested());
            await bloc.stream.firstWhere(
              (s) => !s.isRefreshing,
              orElse: () => state,
            );
          },
          child: CustomScrollView(
            slivers: [
              // 欢迎区域（桌面端全宽滚动，内容 1200 居中）
              SliverToBoxAdapter(
                child: isDesktop
                    ? const ContentConstraint(child: _GreetingSection())
                    : const _GreetingSection(),
              ),

              // Banner 区域 — 紧跟问候语，无分隔线（对标iOS VStack spacing）
              SliverToBoxAdapter(
                child: isDesktop
                    ? ContentConstraint(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: isDesktop
                              ? const _DesktopBannerRow()
                              : const _BannerCarousel(),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: isDesktop
                            ? const _DesktopBannerRow()
                            : const _BannerCarousel(),
                      ),
              ),

              // 推荐任务标题 — 与 Banner 紧凑衔接
              SliverToBoxAdapter(
                child: isDesktop
                    ? ContentConstraint(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            isDesktop ? 24 : AppSpacing.md,
                            AppSpacing.md,
                            isDesktop ? 24 : AppSpacing.md,
                            AppSpacing.sm,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.l10n.homeRecommendedTasks,
                                style: AppTypography.title3.copyWith(
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.desktopTextLight,
                                ),
                              ),
                              _ViewAllButton(
                                onTap: () => context.push('/tasks'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Padding(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 24 : AppSpacing.md,
                    AppSpacing.md,
                    isDesktop ? 24 : AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.homeRecommendedTasks,
                        style: AppTypography.title3.copyWith(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.desktopTextLight,
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
                SliverToBoxAdapter(
                  child: isDesktop
                      ? ContentConstraint(
                          child: SizedBox(
                            height: 256,
                            child: _SkeletonHorizontalCards(isDesktop: isDesktop),
                          ),
                        )
                      : SizedBox(
                          height: 256,
                          child: _SkeletonHorizontalCards(isDesktop: isDesktop),
                        ),
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
                    context,
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

                // 热门活动区域：无开放中活动时隐藏（与 iOS 一致）
                if (state.isLoadingOpenActivities && state.openActivities.isEmpty)
                  SliverToBoxAdapter(
                    child: isDesktop
                        ? ContentConstraint(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                isDesktop ? 24 : AppSpacing.md,
                                AppSpacing.lg,
                                isDesktop ? 24 : AppSpacing.md,
                                AppSpacing.sm,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    context.l10n.homeHotEvents,
                                    style: AppTypography.title3.copyWith(
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.desktopTextLight,
                                    ),
                                  ),
                                  _ViewAllButton(
                                    onTap: () => context.push('/activities'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Padding(
                            padding: EdgeInsets.fromLTRB(
                              isDesktop ? 24 : AppSpacing.md,
                              AppSpacing.lg,
                              isDesktop ? 24 : AppSpacing.md,
                              AppSpacing.sm,
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  context.l10n.homeHotEvents,
                                  style: AppTypography.title3.copyWith(
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.desktopTextLight,
                                  ),
                                ),
                                _ViewAllButton(
                                  onTap: () => context.push('/activities'),
                                ),
                              ],
                            ),
                          ),
                  ),
                if (state.isLoadingOpenActivities && state.openActivities.isEmpty)
                  SliverToBoxAdapter(
                    child: isDesktop
                        ? const ContentConstraint(
                            child: _HomeActivitiesSkeleton(),
                          )
                        : const _HomeActivitiesSkeleton(),
                  ),
                if (state.openActivities.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: isDesktop
                        ? ContentConstraint(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                isDesktop ? 24 : AppSpacing.md,
                                AppSpacing.lg,
                                isDesktop ? 24 : AppSpacing.md,
                                AppSpacing.sm,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    context.l10n.homeHotEvents,
                                    style: AppTypography.title3.copyWith(
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.desktopTextLight,
                                    ),
                                  ),
                                  _ViewAllButton(
                                    onTap: () => context.push('/activities'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Padding(
                            padding: EdgeInsets.fromLTRB(
                              isDesktop ? 24 : AppSpacing.md,
                              AppSpacing.lg,
                              isDesktop ? 24 : AppSpacing.md,
                              AppSpacing.sm,
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  context.l10n.homeHotEvents,
                                  style: AppTypography.title3.copyWith(
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.desktopTextLight,
                                  ),
                                ),
                                _ViewAllButton(
                                  onTap: () => context.push('/activities'),
                                ),
                              ],
                            ),
                          ),
                  ),
                  SliverToBoxAdapter(
                    child: isDesktop
                        ? const ContentConstraint(child: _DesktopActivitiesRow())
                        : const _PopularActivitiesSection(),
                  ),
                ],

                // 发现更多标题（与 discovery_feed_prototype 一致：左侧标题 + 右侧筛选）
                SliverToBoxAdapter(
                  child: isDesktop
                      ? ContentConstraint(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              isDesktop ? 24 : 20,
                              AppSpacing.lg,
                              isDesktop ? 24 : 20,
                              12,
                            ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              size: 22,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context.l10n.homeDiscoverMore,
                              style: AppTypography.title3.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.desktopTextLight,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.cardBackgroundDark
                                : Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: () => _showFilterSheet(context, state),
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.tune,
                                    size: 16,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    context.l10n.commonFilter,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                      : Padding(
                          padding: EdgeInsets.fromLTRB(
                            isDesktop ? 24 : 20,
                            AppSpacing.lg,
                            isDesktop ? 24 : 20,
                            12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.auto_awesome,
                                    size: 22,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.l10n.homeDiscoverMore,
                                    style: AppTypography.title3.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.desktopTextLight,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.cardBackgroundDark
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  onTap: () => _showFilterSheet(context, state),
                                  borderRadius: BorderRadius.circular(999),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.tune,
                                          size: 16,
                                          color: isDark
                                              ? AppColors.textSecondaryDark
                                              : AppColors.textSecondaryLight,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '筛选',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),

                // 发现更多瀑布流 — 桌面端约束 1200 居中；移动端限制最大 520 避免卡片过宽
                SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.crossAxisExtent;
                    final double outerPad;
                    final double innerPad;
                    if (isDesktop) {
                      outerPad = ((w - Breakpoints.maxContentWidth) / 2).clamp(0.0, double.infinity);
                      innerPad = 24;
                    } else {
                      // 限制最大宽度 520，居中，避免平板/横屏时卡片过宽
                      outerPad = w > 520 ? (w - 520) / 2 : 10;
                      innerPad = 0; // _SliverDiscoveryFeed 内部会转为 10
                    }
                    return SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: outerPad),
                      sliver: _SliverDiscoveryFeed(horizontalPadding: innerPad),
                    );
                  },
                ),
              ],

              const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
            ],
          ),
        );
      },
    );
  }

  /// 获取经过筛选和排序的推荐任务列表
  List<Task> _getFilteredTasks(HomeState state) {
    var tasks = List<Task>.from(state.recommendedTasks);

    // 类别筛选
    final category = state.recommendedFilterCategory;
    if (category != null && category.isNotEmpty) {
      tasks = tasks.where((t) => t.taskType == category).toList();
    }

    // 排序
    switch (state.recommendedSortBy) {
      case 'highest_pay':
        tasks.sort((a, b) => b.reward.compareTo(a.reward));
        break;
      case 'near_deadline':
        tasks.sort((a, b) {
          if (a.deadline == null && b.deadline == null) return 0;
          if (a.deadline == null) return 1;
          if (b.deadline == null) return -1;
          return a.deadline!.compareTo(b.deadline!);
        });
        break;
      case 'latest':
      default:
        // Keep original order (API returns latest first)
        break;
    }

    return tasks;
  }

  /// 打开筛选/排序底部弹窗
  void _showFilterSheet(BuildContext context, HomeState state) {
    final bloc = context.read<HomeBloc>();
    final l10n = context.l10n;

    // 收集所有不重复的任务类别
    final categories = state.recommendedTasks
        .map((t) => t.taskType)
        .toSet()
        .toList()
      ..sort();

    var selectedCategory = state.recommendedFilterCategory;
    var selectedSort = state.recommendedSortBy;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 拖动手柄
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.textTertiaryLight.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 排序
                  Text(l10n.taskSortBy, style: AppTypography.title3),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(
                        label: l10n.taskSortLatest,
                        isSelected: selectedSort == 'latest',
                        isDark: isDark,
                        onTap: () => setSheetState(() => selectedSort = 'latest'),
                      ),
                      _FilterChip(
                        label: l10n.taskSortHighestPay,
                        isSelected: selectedSort == 'highest_pay',
                        isDark: isDark,
                        onTap: () => setSheetState(() => selectedSort = 'highest_pay'),
                      ),
                      _FilterChip(
                        label: l10n.taskSortNearDeadline,
                        isSelected: selectedSort == 'near_deadline',
                        isDark: isDark,
                        onTap: () => setSheetState(() => selectedSort = 'near_deadline'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 类别
                  if (categories.isNotEmpty) ...[
                    Text(l10n.taskFilterCategory, style: AppTypography.title3),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChip(
                          label: l10n.commonAll,
                          isSelected: selectedCategory == null,
                          isDark: isDark,
                          onTap: () => setSheetState(() => selectedCategory = null),
                        ),
                        ...categories.map((cat) => _FilterChip(
                              label: cat,
                              isSelected: selectedCategory == cat,
                              isDark: isDark,
                              onTap: () => setSheetState(() => selectedCategory = cat),
                            )),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 操作按钮
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setSheetState(() {
                              selectedCategory = null;
                              selectedSort = 'latest';
                            });
                          },
                          child: Text(l10n.commonReset),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            bloc.add(HomeRecommendedFilterChanged(
                              category: selectedCategory,
                              sortBy: selectedSort,
                              clearCategory: selectedCategory == null,
                            ));
                            Navigator.of(context).pop();
                          },
                          child: Text(l10n.commonConfirm),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 桌面端 3 列 Grid 任务卡片（SliverGrid 实现视口懒加载，替代 shrinkWrap）
  Widget _buildDesktopTaskGrid(BuildContext context, HomeState state) {
    final tasks = _getFilteredTasks(state).take(9).toList();
    final crossAxisCount = ResponsiveUtils.gridColumnCount(context, type: GridItemType.task);
    const spacing = 14.0;
    const aspectRatio = 0.82;

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final pad = ((constraints.crossAxisExtent - Breakpoints.maxContentWidth) / 2)
            .clamp(0.0, double.infinity);
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: aspectRatio,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => RepaintBoundary(
                child: _DesktopTaskCard(
                  key: ValueKey(tasks[index].id),
                  task: tasks[index],
                ),
              ),
              childCount: tasks.length,
            ),
          ),
        );
      },
    );
  }

  /// 移动端横向滚动任务卡片（保持原样）
  Widget _buildMobileTaskScroll(HomeState state) {
    final filteredTasks = _getFilteredTasks(state);
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 256,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.only(
            left: AppSpacing.md, right: AppSpacing.lg, top: 4, bottom: 10,
          ),
          itemCount: filteredTasks.length > 10
              ? 10
              : filteredTasks.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final task = filteredTasks[index];
            return RepaintBoundary(
              child: AnimatedListItem(
                key: ValueKey(task.id),
                index: index,
                child: _HorizontalTaskCard(task: task),
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        height: 180,
        child: Row(
          children: [
            Expanded(
              child: _BannerItem(
                title: context.l10n.homeSecondHandMarket,
                subtitle: context.l10n.homeSecondHandSubtitle,
                gradient: AppColors.gradientGreen,
                icon: Icons.storefront,
                imagePath: AppAssets.fleaMarketBanner,
                parallaxOffset: 0,
                onTap: () => context.push('/flea-market'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BannerItem(
                title: context.l10n.homeStudentVerification,
                subtitle: context.l10n.homeStudentVerificationSubtitle,
                gradient: AppColors.gradientIndigo,
                icon: Icons.school,
                imagePath: AppAssets.studentVerificationBanner,
                parallaxOffset: 0,
                onTap: () => context.push('/student-verification'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BannerItem(
                title: context.l10n.homeBecomeExpert,
                subtitle: context.l10n.homeBecomeExpertSubtitle,
                gradient: AppColors.gradientOrange,
                icon: Icons.star,
                parallaxOffset: 0,
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        height: 160,
        child: Row(
          children: [
            Expanded(
              child: _ActivityCard(
                title: context.l10n.homeNewUserReward,
                subtitle: context.l10n.homeNewUserRewardSubtitle,
                gradient: AppColors.gradientCoral,
                icon: Icons.card_giftcard,
                onTap: () => context.push('/activities'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActivityCard(
                title: context.l10n.homeInviteFriends,
                subtitle: context.l10n.homeInviteFriendsSubtitle,
                gradient: AppColors.gradientPurple,
                icon: Icons.people,
                onTap: () => context.push('/activities'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActivityCard(
                title: context.l10n.homeDailyCheckIn,
                subtitle: context.l10n.homeDailyCheckInSubtitle,
                gradient: AppColors.gradientEmerald,
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
  const _DesktopTaskCard({super.key, required this.task});
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
    final locale = Localizations.localeOf(context);
    final task = widget.task;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.safePush('/tasks/${task.id}'),
        // 简化：去掉 AnimatedContainer + BoxShadow 动画 + Matrix4 transform
        // 改为静态容器 + Opacity 控制 hover 效果（成本远低于 shadow 动画）
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _isHovered ? 0.85 : 1.0,
          child: Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardBackgroundDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.desktopBorderLight,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
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
                        memCacheWidth: 360,
                        memCacheHeight: 270,
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
                                size: 11, color: isDark ? Colors.white : AppColors.desktopTextLight,
                              ),
                              const SizedBox(width: 3),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 80),
                                child: Text(
                                  task.blurredLocation ?? task.location!,
                                  style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white : AppColors.desktopTextLight,
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
                            colors: AppColors.gradientOrange,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.busy.withValues(alpha: 0.4),
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
                        task.displayTitle(locale),
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.desktopTextLight,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      if (task.displayDescription(locale) != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          task.displayDescription(locale)!,
                          style: TextStyle(
                            fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.desktopPlaceholderLight,
                            height: 1.4,
                          ),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          // 任务类型徽章（与 frontend 一致：蓝紫渐变）
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: AppColors.taskTypeBadgeGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_taskTypeIcon(task.taskType), size: 10, color: Colors.white),
                                const SizedBox(width: 2),
                                Text(
                                  TaskTypeHelper.getLocalizedLabel(task.taskType, context.l10n),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (task.deadline != null) ...[
                            Icon(Icons.schedule, size: 12,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.desktopPlaceholderLight),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                _formatDeadline(context, task.deadline!),
                                style: TextStyle(fontSize: 11,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.desktopPlaceholderLight),
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
      ),
    );
  }
}

/// 推荐任务骨架屏 — 匹配横向滚动卡片布局
class _SkeletonHorizontalCards extends StatelessWidget {
  const _SkeletonHorizontalCards({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    // 桌面端用 Grid 骨架，移动端用横向滚动骨架
    if (isDesktop) {
      return const SkeletonGrid(
        crossAxisCount: 3,
        aspectRatio: 0.82,
      );
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.only(
        left: AppSpacing.md, right: AppSpacing.lg, top: 4, bottom: 10,
      ),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        return Container(
          width: 220,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundLight,
            borderRadius: AppRadius.allLarge,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图片占位
              Container(
                height: 170,
                width: double.infinity,
                color: baseColor,
              ),
              // 内容占位
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          height: 12,
                          width: 80,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          height: 22,
                          width: 48,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 筛选弹窗中的选择标签
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : (isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.skeletonBase),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
          ),
        ),
      ),
    );
  }
}
