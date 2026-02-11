import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/router/app_router.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/repositories/flea_market_repository.dart';
import '../bloc/search_bloc.dart';

/// 全局搜索视图
/// 参考iOS SearchViewModel
class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SearchBloc(
        taskRepository: context.read<TaskRepository>(),
        forumRepository: context.read<ForumRepository>(),
        fleaMarketRepository: context.read<FleaMarketRepository>(),
      ),
      child: const _SearchContent(),
    );
  }
}

class _SearchContent extends StatefulWidget {
  const _SearchContent();

  @override
  State<_SearchContent> createState() => _SearchContentState();
}

class _SearchContentState extends State<_SearchContent> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 自动聚焦搜索框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
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
      context.read<SearchBloc>().add(SearchSubmitted(query));
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
        builder: (context, state) {
          if (state.status == SearchStatus.initial) {
            return _buildInitialState(isDark);
          }

          if (state.isLoading) {
            return const LoadingView();
          }

          if (state.status == SearchStatus.error) {
            return Center(
              child: Text(
                state.errorMessage ?? context.l10n.searchNoResults,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
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

  Widget _buildInitialState(bool isDark) {
    return Center(
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = result['title'] as String? ?? '';
    final description = result['description'] as String? ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allMedium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.bodyBold.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
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
          ],
        ),
      ),
    );
  }
}
