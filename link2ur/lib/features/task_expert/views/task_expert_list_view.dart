import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../../../data/models/task_expert.dart';
import '../bloc/task_expert_bloc.dart';

/// 任务达人列表页
/// 参考iOS TaskExpertListView.swift
class TaskExpertListView extends StatelessWidget {
  const TaskExpertListView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TaskExpertBloc(
        taskExpertRepository: context.read<TaskExpertRepository>(),
      )..add(const TaskExpertLoadRequested()),
      child: const _TaskExpertListViewContent(),
    );
  }
}

class _TaskExpertListViewContent extends StatefulWidget {
  const _TaskExpertListViewContent();

  @override
  State<_TaskExpertListViewContent> createState() =>
      _TaskExpertListViewContentState();
}

class _TaskExpertListViewContentState extends State<_TaskExpertListViewContent> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _isSearching = false;

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

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _debounceTimer?.cancel();
        context.read<TaskExpertBloc>().add(const TaskExpertLoadRequested());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: context.l10n.taskExpertSearchPrompt,
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : Text(context.l10n.expertsExperts),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: BlocBuilder<TaskExpertBloc, TaskExpertState>(
        builder: (context, state) {
            // Loading state
            if (state.status == TaskExpertStatus.loading &&
                state.experts.isEmpty) {
              return const LoadingView();
            }

            // Error state
            if (state.status == TaskExpertStatus.error &&
                state.experts.isEmpty) {
              return ErrorStateView.loadFailed(
                message: state.errorMessage ?? context.l10n.tasksLoadFailed,
                onRetry: () {
                  context.read<TaskExpertBloc>().add(
                        const TaskExpertLoadRequested(),
                      );
                },
              );
            }

            // Empty state
            if (state.experts.isEmpty) {
              return EmptyStateView.noData(
                title: context.l10n.taskExpertNoExperts,
                description: context.l10n.taskExpertNoExpertsMessage,
              );
            }

            // List with pull-to-refresh and infinite scroll
            return RefreshIndicator(
              onRefresh: () async {
                context.read<TaskExpertBloc>().add(
                      const TaskExpertRefreshRequested(),
                    );
                // Wait for refresh to complete
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: ListView.separated(
                padding: AppSpacing.allMd,
                itemCount: state.experts.length + (state.hasMore ? 1 : 0),
                separatorBuilder: (context, index) => AppSpacing.vMd,
                itemBuilder: (context, index) {
                  // Load more trigger
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

                  final expert = state.experts[index];
                  return _ExpertCard(expert: expert);
                },
              ),
            );
          },
        ),
    );
  }
}

class _ExpertCard extends StatelessWidget {
  const _ExpertCard({required this.expert});

  final TaskExpert expert;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      onTap: () {
        // Convert String id to int for navigation
        final expertId = int.tryParse(expert.id) ?? 0;
        if (expertId > 0) {
          context.push('/task-experts/$expertId');
        }
      },
      child: Row(
        children: [
          // Avatar（使用 AvatarView 正确处理相对路径）
          AvatarView(
            imageUrl: expert.avatar,
            name: expert.displayName,
            size: 60,
          ),
          AppSpacing.hMd,
          // Expert info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expert.displayName,
                  style: AppTypography.title3.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                if (expert.displayBio != null && expert.displayBio!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    expert.displayBio!,
                    style: AppTypography.subheadline.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Rating
                    const Icon(Icons.star, size: 14, color: AppColors.gold),
                    const SizedBox(width: 4),
                    Text(
                      expert.ratingDisplay,
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Completed tasks
                    Text(
                      context.l10n.leaderboardCompletedCount(expert.completedTasks),
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    if (expert.totalServices > 0) ...[
                      const SizedBox(width: 12),
                      Text(
                        context.l10n.taskExpertServiceCount(expert.totalServices),
                        style: AppTypography.caption.copyWith(
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
          const Icon(
            Icons.chevron_right,
            color: AppColors.textTertiaryLight,
          ),
        ],
      ),
    );
  }
}
