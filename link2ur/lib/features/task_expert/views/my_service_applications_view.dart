import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../bloc/task_expert_bloc.dart';

/// 我的服务申请页
/// 参考iOS MyServiceApplicationsView.swift
class MyServiceApplicationsView extends StatelessWidget {
  const MyServiceApplicationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TaskExpertBloc(
        taskExpertRepository: context.read<TaskExpertRepository>(),
      )..add(const TaskExpertLoadMyApplications()),
      child: const _MyServiceApplicationsContent(),
    );
  }
}

class _MyServiceApplicationsContent extends StatelessWidget {
  const _MyServiceApplicationsContent();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<TaskExpertBloc, TaskExpertState>(
      builder: (context, state) {
        final applications = state.applications;

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.taskExpertMyApplications),
          ),
          body: state.isLoading && applications.isEmpty
              ? const SkeletonList()
              : applications.isEmpty
                  ? EmptyStateView(
                      icon: Icons.assignment_outlined,
                      title: l10n.taskExpertNoApplications,
                      message: l10n.taskExpertNoApplicationsMessage,
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        context
                            .read<TaskExpertBloc>()
                            .add(const TaskExpertLoadMyApplications());
                      },
                      child: ListView.separated(
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: applications.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final app = applications[index];
                          return _ApplicationCard(application: app);
                        },
                      ),
                    ),
        );
      },
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application});

  final Map<String, dynamic> application;

  @override
  Widget build(BuildContext context) {
    final title = application['service_title'] as String? ?? '';
    final status = application['status'] as String? ?? 'pending';
    final createdAt = application['created_at'] as String? ?? '';

    Color statusColor;
    switch (status) {
      case 'approved':
        statusColor = AppColors.success;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.warning;
    }

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                      fontSize: 11,
                      color: statusColor,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (createdAt.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(createdAt,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textTertiary)),
          ],
        ],
      ),
    );
  }
}
