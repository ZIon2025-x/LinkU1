import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/router/app_router.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/repositories/flea_market_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../../../data/repositories/personal_service_repository.dart';
import '../../../data/repositories/trending_search_repository.dart';
import '../bloc/search_bloc.dart';

/// 全局搜索视图
/// 参考iOS SearchViewModel
class SearchView extends StatelessWidget {
  const SearchView({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SearchBloc(
        taskRepository: context.read<TaskRepository>(),
        forumRepository: context.read<ForumRepository>(),
        fleaMarketRepository: context.read<FleaMarketRepository>(),
        taskExpertRepository: context.read<TaskExpertRepository>(),
        activityRepository: context.read<ActivityRepository>(),
        leaderboardRepository: context.read<LeaderboardRepository>(),
        personalServiceRepository: context.read<PersonalServiceRepository>(),
        trendingSearchRepository: context.read<TrendingSearchRepository>(),
      ),
      child: _SearchContent(initialQuery: initialQuery),
    );
  }
}

class _SearchContent extends StatefulWidget {
  const _SearchContent({this.initialQuery});

  final String? initialQuery;

  @override
  State<_SearchContent> createState() => _SearchContentState();
}

class _SearchContentState extends State<_SearchContent> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
        _searchController.text = widget.initialQuery!;
        context.read<SearchBloc>().add(
          SearchSubmitted(widget.initialQuery!, Localizations.localeOf(context)),
        );
      } else {
        _focusNode.requestFocus();
        context.read<SearchBloc>().add(const LoadRecentSearches());
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      context.read<SearchBloc>().add(SearchSubmitted(query, Localizations.localeOf(context)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _buildSearchBar(isDark),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonCancel),
          ),
        ],
      ),
      body: BlocBuilder<SearchBloc, SearchState>(
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.recentSearches != current.recentSearches ||
            previous.taskResults != current.taskResults ||
            previous.forumResults != current.forumResults ||
            previous.fleaMarketResults != current.fleaMarketResults ||
            previous.expertResults != current.expertResults ||
            previous.activityResults != current.activityResults ||
            previous.leaderboardResults != current.leaderboardResults ||
            previous.leaderboardItemResults != current.leaderboardItemResults ||
            previous.forumCategoryResults != current.forumCategoryResults ||
            previous.serviceResults != current.serviceResults,
        builder: (context, state) {
          if (state.status == SearchStatus.initial) {
            return _buildInitialState(context, state, isDark);
          }

          if (state.isLoading) {
            return const LoadingView();
          }

          if (state.status == SearchStatus.error) {
            return ErrorStateView(
              message: context.localizeError(state.errorMessage ?? ''),
              onRetry: () => context.read<SearchBloc>().add(
                    SearchSubmitted(
                      state.query,
                      Localizations.localeOf(context),
                    ),
                  ),
            );
          }

          if (!state.hasResults) {
            return EmptyStateView(
              icon: Icons.search_off,
              title: context.l10n.searchNoResults,
              message: context.l10n.searchTryDifferent,
            );
          }

          return _buildResults(state, isDark);
        },
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.secondaryBackgroundDark
            : AppColors.backgroundLight,
        borderRadius: AppRadius.allSmall,
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: context.l10n.commonSearch,
          prefixIcon:
              const Icon(Icons.search, size: 20, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (_, value, __) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.clear, size: 18),
                tooltip: 'Clear',
                onPressed: () {
                  _searchController.clear();
                  context.read<SearchBloc>().add(const SearchCleared());
                },
              );
            },
          ),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _onSearch(),
      ),
    );
  }

  Widget _buildInitialState(
      BuildContext context, SearchState state, bool isDark) {
    final recent = state.recentSearches;
    final hasRecent = recent.isNotEmpty;
    return SingleChildScrollView(
      padding: AppSpacing.allMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasRecent) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.searchRecentSearches,
                  style: AppTypography.subheadline.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    context.read<SearchBloc>().add(const SearchHistoryCleared());
                  },
                  child: Text(context.l10n.searchClearHistory),
                ),
              ],
            ),
            AppSpacing.vSm,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recent.map((keyword) {
                return ActionChip(
                  label: Text(keyword),
                  onPressed: () {
                    _searchController.text = keyword;
                    _searchController.selection = TextSelection.collapsed(
                      offset: keyword.length,
                    );
                    context.read<SearchBloc>().add(
                          SearchSubmitted(
                            keyword,
                            Localizations.localeOf(context),
                          ),
                        );
                  },
                  backgroundColor: isDark
                      ? AppColors.secondaryBackgroundDark
                      : AppColors.backgroundLight,
                  side: BorderSide(
                    color: isDark
                        ? AppColors.separatorDark
                        : AppColors.separatorLight,
                  ),
                );
              }).toList(),
            ),
            AppSpacing.vLg,
          ],
          if (!hasRecent) ...[
            AppSpacing.vXl,
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search,
                    size: 64,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                  AppSpacing.vMd,
                  Text(
                    context.l10n.searchHint,
                    style: AppTypography.subheadline.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResults(SearchState state, bool isDark) {
    return SingleChildScrollView(
      padding: AppSpacing.allMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 搜索统计
          Text(
            context.l10n.searchResultCount(state.totalResults),
            style: AppTypography.caption.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          AppSpacing.vMd,

          // 达人结果
          if (state.expertResults.isNotEmpty) ...[
            _SectionHeader(
              title: context.l10n.searchExpertsTitle,
              count: state.expertResults.length,
              icon: Icons.person_search,
              color: AppColors.accent,
            ),
            AppSpacing.vSm,
            ...state.expertResults.map((result) => _SearchResultCard(
                  result: result,
                  onTap: () {
                    final id = result['id'];
                    if (id != null) context.safePush('/task-experts/$id');
                  },
                )),
            AppSpacing.vLg,
          ],

          // 任务结果
          if (state.taskResults.isNotEmpty) ...[
            _SectionHeader(
              title: context.l10n.searchTasksTitle,
              count: state.taskResults.length,
              icon: Icons.task_alt,
              color: AppColors.primary,
            ),
            AppSpacing.vSm,
            ...state.taskResults.map((result) => _SearchResultCard(
                  result: result,
                  onTap: () {
                    final id = result['id'];
                    if (id != null) context.safePush('/tasks/$id');
                  },
                )),
            AppSpacing.vLg,
          ],

          // 论坛结果
          if (state.forumResults.isNotEmpty) ...[
            _SectionHeader(
              title: context.l10n.searchForumTitle,
              count: state.forumResults.length,
              icon: Icons.forum,
              color: AppColors.accent,
            ),
            AppSpacing.vSm,
            ...state.forumResults.map((result) => _SearchResultCard(
                  result: result,
                  onTap: () {
                    final id = result['id'];
                    if (id != null) context.safePush('/forum/posts/$id');
                  },
                )),
            AppSpacing.vLg,
          ],

          // 活动结果
          if (state.activityResults.isNotEmpty) ...[
            _SectionHeader(
              title: context.l10n.searchActivitiesTitle,
              count: state.activityResults.length,
              icon: Icons.event,
              color: AppColors.info,
            ),
            AppSpacing.vSm,
            ...state.activityResults.map((result) => _SearchResultCard(
                  result: result,
                  onTap: () {
                    final id = result['id'];
                    if (id != null) context.safePush('/activities/$id');
                  },
                )),
            AppSpacing.vLg,
          ],

          // 个人服务结果
          if (state.serviceResults.isNotEmpty) ...[
            _SectionHeader(
              title: context.l10n.searchServicesTitle,
              count: state.serviceResults.length,
              icon: Icons.home_repair_service,
              color: AppColors.primary,
            ),
            AppSpacing.vSm,
            ...state.serviceResults.map((result) => _SearchResultCard(
                  result: result,
                  onTap: () {
                    final id = result['id'];
                    if (id != null) context.safePush('/service/$id');
                  },
                )),
            AppSpacing.vLg,
          ],

          // 排行榜结果
          if (state.leaderboardResults.isNotEmpty) ...[
            _SectionHeader(
              title: context.l10n.searchLeaderboardsTitle,
              count: state.leaderboardResults.length,
              icon: Icons.leaderboard,
              color: AppColors.success,
            ),
            AppSpacing.vSm,
            ...state.leaderboardResults.map((result) => _SearchResultCard(
                  result: result,
                  onTap: () {
                    final id = result['id'];
                    if (id != null) context.safePush('/leaderboard/$id');
                  },
                )),
            AppSpacing.vLg,
          ],

          // 排行榜竞品结果
          if (state.leaderboardItemResults.isNotEmpty) ...[
            _SectionHeader(
              title: context.l10n.searchLeaderboardItemsTitle,
              count: state.leaderboardItemResults.length,
              icon: Icons.emoji_events,
              color: AppColors.success,
            ),
            AppSpacing.vSm,
            ...state.leaderboardItemResults.map((result) => _SearchResultCard(
                  result: result,
                  onTap: () {
                    final id = result['id'];
                    if (id != null) context.safePush('/leaderboard/item/$id');
                  },
                )),
            AppSpacing.vLg,
          ],

          // 论坛板块结果
          if (state.forumCategoryResults.isNotEmpty) ...[
            _SectionHeader(
              title: context.l10n.searchForumCategoriesTitle,
              count: state.forumCategoryResults.length,
              icon: Icons.category,
              color: AppColors.accent,
            ),
            AppSpacing.vSm,
            ...state.forumCategoryResults.map((result) => _SearchResultCard(
                  result: result,
                  onTap: () {
                    final id = result['id'];
                    if (id != null) context.safePush('/forum/category/$id');
                  },
                )),
            AppSpacing.vLg,
          ],

          // 跳蚤市场结果
          if (state.fleaMarketResults.isNotEmpty) ...[
            _SectionHeader(
              title: context.l10n.searchFleaMarketTitle,
              count: state.fleaMarketResults.length,
              icon: Icons.store,
              color: AppColors.warning,
            ),
            AppSpacing.vSm,
            ...state.fleaMarketResults.map((result) => _SearchResultCard(
                  result: result,
                  onTap: () {
                    final id = result['id'];
                    if (id != null) context.safePush('/flea-market/$id');
                  },
                )),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          '$title ($count)',
          style: AppTypography.title3.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.result,
    required this.onTap,
  });

  final Map<String, dynamic> result;
  final VoidCallback onTap;

  /// Type-specific fallback icon
  static const _typeIcons = <String, IconData>{
    'task': Icons.task_alt,
    'forum': Icons.forum,
    'flea_market': Icons.store,
    'expert': Icons.person,
    'activity': Icons.event,
    'leaderboard': Icons.leaderboard,
    'leaderboard_item': Icons.emoji_events,
    'forum_category': Icons.category,
    'service': Icons.handyman_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = result['title'] as String? ?? '';
    final description = result['description'] as String? ?? '';
    final type = result['type'] as String? ?? '';
    final price = result['price'] as String?;
    final subtitle = result['subtitle'] as String?;

    // Image handling
    final imageUrl = _resolveImage();
    final isAvatar = result['is_avatar'] == true;
    final fallbackIcon = _typeIcons[type] ?? Icons.article;

    return Semantics(
      button: true,
      label: 'View details',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundLight,
            borderRadius: AppRadius.allMedium,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail / Avatar
              ClipRRect(
                borderRadius: isAvatar
                    ? BorderRadius.circular(32)
                    : AppRadius.allSmall,
                child: Container(
                  width: 64,
                  height: 64,
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            fallbackIcon,
                            size: 28,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                        )
                      : Icon(
                          fallbackIcon,
                          size: 28,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Info column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: AppTypography.bodyBold.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: AppTypography.caption.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    // Bottom row: price + subtitle
                    Row(
                      children: [
                        if (price != null && price.isNotEmpty) ...[
                          Text(
                            price,
                            style: AppTypography.bodyBold.copyWith(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (subtitle != null && subtitle.isNotEmpty)
                          Flexible(
                            child: Text(
                              subtitle,
                              style: AppTypography.caption.copyWith(
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  String? _resolveImage() {
    // Direct image URL (avatar, cover image, icon URL)
    final image = result['image'];
    if (image is String && image.isNotEmpty) return image;

    // Images array (services, flea market, etc.)
    final images = result['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is String && first.isNotEmpty) return first;
    }

    return null;
  }
}
