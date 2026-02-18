part of 'home_view.dart';

/// 对标iOS: TaskExpertListContentView (达人Tab)
/// 内嵌达人列表，点击搜索框跳转到完整搜索页
class _ExpertsTab extends StatelessWidget {
  const _ExpertsTab();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TaskExpertBloc(
        taskExpertRepository: context.read<TaskExpertRepository>(),
      )..add(const TaskExpertLoadRequested()),
      child: const _ExpertsTabContent(),
    );
  }
}

class _ExpertsTabContent extends StatefulWidget {
  const _ExpertsTabContent();

  @override
  State<_ExpertsTabContent> createState() => _ExpertsTabContentState();
}

class _ExpertsTabContentState extends State<_ExpertsTabContent> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  static const _debounceDuration = Duration(milliseconds: 400);

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      if (!mounted) return;
      context.read<TaskExpertBloc>().add(
            TaskExpertLoadRequested(skill: query.isEmpty ? null : query),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final column = Column(
      children: [
        // 搜索框 + 筛选按钮
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              // 搜索框
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: AppTypography.subheadline.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  decoration: InputDecoration(
                    hintText: context.l10n.homeSearchExperts,
                    hintStyle: AppTypography.subheadline.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                      size: 20,
                    ),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, _) {
                        if (value.text.isEmpty) return const SizedBox.shrink();
                        return GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                        );
                      },
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.cardBackgroundDark
                        : AppColors.cardBackgroundLight,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.allMedium,
                      borderSide: BorderSide(
                        color: (isDark ? AppColors.dividerDark : AppColors.dividerLight)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.allMedium,
                      borderSide: BorderSide(
                        color: (isDark ? AppColors.dividerDark : AppColors.dividerLight)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.allMedium,
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 筛选按钮
              BlocBuilder<TaskExpertBloc, TaskExpertState>(
                buildWhen: (prev, curr) =>
                    prev.hasActiveFilters != curr.hasActiveFilters,
                builder: (context, state) {
                  return GestureDetector(
                    onTap: () => _showFilterPanel(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.cardBackgroundDark
                            : AppColors.cardBackgroundLight,
                        borderRadius: AppRadius.allMedium,
                        border: Border.all(
                          color: state.hasActiveFilters
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.dividerDark
                                  : AppColors.dividerLight)
                                  .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.tune,
                            size: 20,
                            color: state.hasActiveFilters
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                          ),
                          if (state.hasActiveFilters)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // 对标iOS: 达人卡片列表
        Expanded(
          child: BlocBuilder<TaskExpertBloc, TaskExpertState>(
            buildWhen: (prev, curr) =>
                prev.status != curr.status ||
                prev.experts != curr.experts ||
                prev.errorMessage != curr.errorMessage ||
                prev.hasMore != curr.hasMore,
            builder: (context, state) {
              if (state.status == TaskExpertStatus.loading &&
                  state.experts.isEmpty) {
                return const SkeletonList(imageSize: 68);
              }

              if (state.status == TaskExpertStatus.error &&
                  state.experts.isEmpty) {
                return ErrorStateView.loadFailed(
                  message: state.errorMessage,
                  onRetry: () {
                    context.read<TaskExpertBloc>().add(
                          const TaskExpertLoadRequested(),
                        );
                  },
                );
              }

              if (state.experts.isEmpty) {
                return EmptyStateView.noData(
                  context,
                  title: context.l10n.homeExperts,
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<TaskExpertBloc>().add(
                        const TaskExpertRefreshRequested(),
                      );
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: ListView.separated(
                  padding: AppSpacing.allMd,
                  itemCount: state.experts.length + (state.hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => AppSpacing.vMd,
                  itemBuilder: (context, index) {
                    if (index == state.experts.length) {
                      context.read<TaskExpertBloc>().add(
                            const TaskExpertLoadMore(),
                          );
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: LoadingIndicator(),
                        ),
                      );
                    }
                    return AnimatedListItem(
                      index: index,
                      child: _ExpertCard(expert: state.experts[index]),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
    return isDesktop ? ContentConstraint(child: column) : column;
  }

  // ==================== 达人类型 & 城市常量 ====================

  static const List<String> _expertCategoryKeys = [
    'all', 'programming', 'translation', 'tutoring', 'food',
    'beverage', 'cake', 'errand_transport', 'social_entertainment',
    'beauty_skincare', 'handicraft',
  ];

  static const List<String> _ukCities = [
    'London', 'Edinburgh', 'Manchester', 'Birmingham', 'Glasgow',
    'Bristol', 'Sheffield', 'Leeds', 'Nottingham', 'Newcastle',
    'Southampton', 'Liverpool', 'Cardiff', 'Coventry', 'Exeter',
    'Leicester', 'York', 'Aberdeen', 'Bath', 'Dundee',
    'Reading', 'St Andrews', 'Belfast', 'Brighton', 'Durham',
    'Norwich', 'Swansea', 'Loughborough', 'Lancaster', 'Warwick',
    'Cambridge', 'Oxford',
  ];

  String _categoryLabel(BuildContext context, String key) {
    final l10n = context.l10n;
    switch (key) {
      case 'all': return l10n.expertCategoryAll;
      case 'programming': return l10n.expertCategoryProgramming;
      case 'translation': return l10n.expertCategoryTranslation;
      case 'tutoring': return l10n.expertCategoryTutoring;
      case 'food': return l10n.expertCategoryFood;
      case 'beverage': return l10n.expertCategoryBeverage;
      case 'cake': return l10n.expertCategoryCake;
      case 'errand_transport': return l10n.expertCategoryErrandTransport;
      case 'social_entertainment': return l10n.expertCategorySocialEntertainment;
      case 'beauty_skincare': return l10n.expertCategoryBeautySkincare;
      case 'handicraft': return l10n.expertCategoryHandicraft;
      default: return key;
    }
  }

  void _showFilterPanel(BuildContext context) {
    final bloc = context.read<TaskExpertBloc>();
    final currentState = bloc.state;
    String tempCategory = currentState.selectedCategory;
    String tempCity = currentState.selectedCity;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final l10n = ctx.l10n;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 拖拽条
                    Center(
                      child: Container(
                        width: 36, height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 标题 + 重置
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.commonFilter,
                          style: AppTypography.title2.copyWith(fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () => setModalState(() {
                            tempCategory = 'all';
                            tempCity = 'all';
                          }),
                          child: Text(l10n.commonReset,
                            style: const TextStyle(color: AppColors.primary, fontSize: 14)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── 达人类型 ──
                    Text(l10n.taskExpertCategory, style: AppTypography.bodyBold),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10, runSpacing: 10,
                      children: _expertCategoryKeys.map((key) {
                        return _buildChip(
                          label: _categoryLabel(ctx, key),
                          isSelected: tempCategory == key,
                          isDark: isDark,
                          onTap: () => setModalState(() => tempCategory = key),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // ── 城市 ──
                    Text(l10n.taskFilterCity, style: AppTypography.bodyBold),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 10, runSpacing: 10,
                          children: [
                            _buildChip(
                              label: l10n.commonAll,
                              isSelected: tempCity == 'all',
                              isDark: isDark,
                              onTap: () => setModalState(() => tempCity = 'all'),
                            ),
                            ..._ukCities.map((city) {
                              final display = CityDisplayHelper.getDisplayName(city, l10n);
                              return _buildChip(
                                label: display,
                                isSelected: tempCity == city,
                                isDark: isDark,
                                onTap: () => setModalState(() => tempCity = city),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── 确认 ──
                    SizedBox(
                      width: double.infinity, height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          if (tempCategory != currentState.selectedCategory ||
                              tempCity != currentState.selectedCity) {
                            bloc.add(TaskExpertFilterChanged(
                              category: tempCategory,
                              city: tempCity,
                            ));
                          }
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(l10n.commonConfirm,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () { AppHaptics.selection(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(colors: AppColors.gradientPrimary) : null,
          color: isSelected ? null
              : (isDark ? AppColors.surface2(Brightness.dark) : AppColors.surface1(Brightness.light)),
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(
            color: (isDark ? AppColors.separatorDark : AppColors.separatorLight)
                .withValues(alpha: 0.3)),
        ),
        child: Text(label,
          style: TextStyle(
            color: isSelected ? Colors.white
                : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          )),
      ),
    );
  }
}

/// 达人卡片 - 对标iOS ExpertCard
/// 头像光晕(74背景+68头像) + 认证徽章 + 名称/简介/统计 + chevron
class _ExpertCard extends StatelessWidget {
  const _ExpertCard({required this.expert});

  final TaskExpert expert;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        if (expert.id.isNotEmpty) {
          context.safePush('/task-experts/${expert.id}');
        }
      },
      child: Container(
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allLarge,
          border: Border.all(
            color: (isDark ? AppColors.separatorDark : AppColors.separatorLight)
                .withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            // 头像 + 光晕 (对标iOS: 74背景圆 + 68头像 + shadow)
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: AvatarView(
                  imageUrl: expert.avatar,
                  name: expert.displayNameWith(context.l10n),
                  size: 68,
                ),
              ),
            ),
            AppSpacing.hMd,
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 名称 + 认证徽章 (对标iOS checkmark.seal.fill)
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          expert.displayNameWith(context.l10n),
                          style: AppTypography.bodyBold.copyWith(
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  // 简介（双语）— 为空时显示占位文本 (对标iOS)
                  const SizedBox(height: 4),
                  Text(
                    (expert.displayBio(locale)?.isNotEmpty ?? false)
                        ? expert.displayBio(locale)!
                        : context.l10n.taskExpertNoIntro,
                    style: AppTypography.caption.copyWith(
                      color: (expert.displayBio(locale)?.isNotEmpty ?? false)
                          ? (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight)
                          : (isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // 统计行 (对标iOS: 胶囊评分 + 完成数·完成率)
                  Row(
                    children: [
                      // 评分胶囊
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: AppRadius.allPill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 12, color: AppColors.warning),
                            const SizedBox(width: 3),
                            Text(
                              expert.ratingDisplay,
                              style: AppTypography.caption2.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 完成单数 · 完成率
                      Text(
                        context.l10n
                            .leaderboardCompletedCount(expert.completedTasks),
                        style: AppTypography.caption2.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      if (expert.totalServices > 0) ...[
                        Text(
                          ' · ',
                          style: AppTypography.caption2.copyWith(
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                        ),
                        Text(
                          context.l10n.taskExpertServiceCount(
                              expert.totalServices),
                          style: AppTypography.caption2.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
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

/// 任务卡片 - 垂直列表（对标iOS TaskCard风格：图片在上 + 内容在下）
class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final Task task;

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

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        context.safePush('/tasks/${task.id}');
      },
      child: Container(
        clipBehavior: Clip.hardEdge,
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
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
                                task.blurredLocation ?? task.location!,
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

                  // 右上: 模糊距离标签
                  if (task.blurredDistanceText != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.85),
                          borderRadius: AppRadius.allPill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.near_me,
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              task.blurredDistanceText!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 右下: 任务类型标签 (半透明容器)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.taskTypeBadgeGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: AppRadius.allPill,
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
                            TaskTypeHelper.getLocalizedLabel(task.taskType, context.l10n),
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
                    task.displayTitle(locale),
                    style: AppTypography.bodyBold.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (task.displayDescription(locale) != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.displayDescription(locale)!,
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
                              TaskStatusHelper.getLocalizedLabel(task.status, context.l10n),
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
