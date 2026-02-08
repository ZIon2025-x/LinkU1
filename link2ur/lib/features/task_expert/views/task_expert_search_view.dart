import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/empty_state_view.dart';
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.large),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: expert.avatar != null
                  ? NetworkImage(expert.avatar!)
                  : null,
              child: expert.avatar == null
                  ? const Icon(Icons.person, size: 28)
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expert.name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  if (expert.specialties != null &&
                      expert.specialties!.isNotEmpty)
                    Text(
                      expert.specialties!.join(' · '),
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (expert.avgRating != null) ...[
              const Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              Text(expert.avgRating!.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}
