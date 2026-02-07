import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../bloc/task_expert_bloc.dart';

/// 服务详情页
/// 参考iOS ServiceDetailView.swift
class ServiceDetailView extends StatelessWidget {
  const ServiceDetailView({super.key, required this.serviceId});

  final int serviceId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocProvider(
      create: (context) => TaskExpertBloc(
        taskExpertRepository: context.read<TaskExpertRepository>(),
      )..add(TaskExpertLoadServiceDetail(serviceId)),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.taskExpertServiceDetail),
        ),
        body: BlocBuilder<TaskExpertBloc, TaskExpertState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const LoadingView();
            }

            if (state.errorMessage != null) {
              return ErrorStateView(
                message: state.errorMessage!,
                onRetry: () => context
                    .read<TaskExpertBloc>()
                    .add(TaskExpertLoadServiceDetail(serviceId)),
              );
            }

            final service = state.serviceDetail;
            if (service == null) {
              return const SizedBox.shrink();
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 服务标题
                  Text(
                    service['title'] as String? ?? '',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 价格
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppRadius.medium),
                    ),
                    child: Row(
                      children: [
                        Text(l10n.taskExpertPrice,
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary)),
                        const Spacer(),
                        Text(
                          '£${(service['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 描述
                  Text(l10n.taskExpertDescription,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    service['description'] as String? ?? '',
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.6),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 类别
                  if (service['category'] != null) ...[
                    _buildInfoRow(
                      l10n.taskExpertCategory,
                      service['category'] as String,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // 完成时间
                  if (service['delivery_time'] != null)
                    _buildInfoRow(
                      l10n.taskExpertDeliveryTime,
                      service['delivery_time'] as String,
                    ),

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
