import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/repositories/personal_service_repository.dart';
import '../bloc/personal_service_bloc.dart';

/// 服务评价列表页面
class ServiceReviewsView extends StatelessWidget {
  const ServiceReviewsView({super.key, required this.serviceId, this.serviceName});

  final int serviceId;
  final String? serviceName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PersonalServiceBloc(
        repository: context.read<PersonalServiceRepository>(),
      )..add(PersonalServiceLoadReviews(serviceId)),
      child: _Content(serviceName: serviceName),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({this.serviceName});

  final String? serviceName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(serviceName ?? l10n.serviceReviewTitle),
      ),
      body: BlocBuilder<PersonalServiceBloc, PersonalServiceState>(
        builder: (context, state) {
          if (state.status == PersonalServiceStatus.loading) {
            return const SkeletonList();
          }

          if (state.status == PersonalServiceStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 48,
                      color: AppColors.error.withValues(alpha: 0.5)),
                  AppSpacing.vMd,
                  Text(state.errorMessage ?? ''),
                  AppSpacing.vMd,
                  TextButton(
                    onPressed: () => context
                        .read<PersonalServiceBloc>()
                        .add(PersonalServiceLoadReviews(
                          int.tryParse(serviceName ?? '') ?? 0,
                        )),
                    child: Text(l10n.commonRetry),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Summary header
              if (state.reviewSummary != null)
                _ReviewSummaryHeader(summary: state.reviewSummary!),

              // Reviews list
              Expanded(
                child: state.reviews.isEmpty
                    ? EmptyStateView(
                        icon: Icons.rate_review_outlined,
                        title: l10n.serviceReviewEmpty,
                        message: l10n.serviceReviewEmptyMessage,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: state.reviews.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          return _ReviewCard(review: state.reviews[index]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewSummaryHeader extends StatelessWidget {
  const _ReviewSummaryHeader({required this.summary});

  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avgRating =
        (summary['average_rating'] as num?)?.toDouble() ?? 0.0;
    final totalReviews = (summary['total_reviews'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            children: [
              Text(
                avgRating.toStringAsFixed(1),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  if (avgRating >= starValue) {
                    return const Icon(Icons.star,
                        size: 20, color: AppColors.warning);
                  } else if (avgRating >= starValue - 0.5) {
                    return const Icon(Icons.star_half,
                        size: 20, color: AppColors.warning);
                  }
                  return Icon(Icons.star_border,
                      size: 20,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight);
                }),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$totalReviews ${context.l10n.serviceReviewTitle}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reviewerName = review['reviewer_name'] as String? ?? 'Unknown';
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final comment = review['comment'] as String? ?? '';
    final createdAt = review['created_at'] as String?;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reviewer info
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  reviewerName.isNotEmpty ? reviewerName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reviewerName,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (createdAt != null)
                      Text(
                        _formatDate(createdAt),
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? AppColors.textTertiaryDark
                                      : AppColors.textTertiaryLight,
                                ),
                      ),
                  ],
                ),
              ),
              // Stars
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    size: 16,
                    color: index < rating
                        ? AppColors.warning
                        : (isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight),
                  );
                }),
              ),
            ],
          ),

          // Comment
          if (comment.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              comment,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}
