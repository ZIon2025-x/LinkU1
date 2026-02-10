import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/models/task_expert.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../bloc/task_expert_bloc.dart';

/// 任务达人搜索页
/// 参考iOS TaskExpertSearchView.swift
class TaskExpertSearchView extends StatelessWidget {
  const TaskExpertSearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TaskExpertBloc(
        taskExpertRepository: context.read<TaskExpertRepository>(),
      ),
      child: const _TaskExpertSearchContent(),
    );
  }
}

class _TaskExpertSearchContent extends StatefulWidget {
  const _TaskExpertSearchContent();

  @override
  State<_TaskExpertSearchContent> createState() =>
      _TaskExpertSearchContentState();
}

class _TaskExpertSearchContentState
    extends State<_TaskExpertSearchContent> {
  final TextEditingController _searchController = TextEditingController();
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String keyword) {
    if (keyword.trim().isEmpty) return;
    setState(() => _hasSearched = true);
    context
        .read<TaskExpertBloc>()
        .add(TaskExpertSearchRequested(keyword));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.taskExpertSearchHint,
            border: InputBorder.none,
          ),
          onSubmitted: _search,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _search(_searchController.text),
          ),
        ],
      ),
      body: BlocBuilder<TaskExpertBloc, TaskExpertState>(
        builder: (context, state) {
          final results = state.searchResults;

          if (state.isLoading) {
            return const SkeletonList();
          }

          if (!_hasSearched) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search,
                      size: 64, color: AppColors.textTertiary),
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n.taskExpertSearchPrompt,
                      style:
                          const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          if (results.isEmpty) {
            return EmptyStateView(
              icon: Icons.search_off,
              title: l10n.commonNoResults,
              message: l10n.taskExpertNoResults,
            );
          }

          return ListView.separated(
            clipBehavior: Clip.none,
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: results.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final expert = results[index];
              return _ExpertCard(
                expert: expert,
                onTap: () =>
                    context.push('/task-experts/${expert.id}'),
              );
            },
          );
        },
      ),
    );
  }
}

class _ExpertCard extends StatelessWidget {
  const _ExpertCard({required this.expert, this.onTap});

  final TaskExpert expert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
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
            // 头像 + 光晕
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: AvatarView(
                  imageUrl: expert.avatar,
                  name: expert.displayName,
                  size: 54,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 名称 + 认证徽章
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          expert.displayName,
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
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 专长标签
                  if (expert.displaySpecialties != null &&
                      expert.displaySpecialties!.isNotEmpty)
                    Text(
                      expert.displaySpecialties!.join(' · '),
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // 评分胶囊
            if (expert.avgRating != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                      expert.avgRating!.toStringAsFixed(1),
                      style: AppTypography.caption2.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
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
