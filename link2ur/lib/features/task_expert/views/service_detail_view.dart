import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/sheet_adaptation.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/scroll_safe_tap.dart';
import '../../../data/models/activity.dart';
import '../../../data/models/task_expert.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import 'activity_price_widget.dart';
import '../bloc/task_expert_bloc.dart';

/// 服务详情页
/// 对标iOS ServiceDetailView.swift
class ServiceDetailView extends StatelessWidget {
  const ServiceDetailView({super.key, required this.serviceId});

  final int serviceId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TaskExpertBloc(
        taskExpertRepository: context.read<TaskExpertRepository>(),
        activityRepository: context.read<ActivityRepository>(),
      )
        ..add(TaskExpertLoadServiceDetail(serviceId))
        ..add(TaskExpertLoadServiceReviews(serviceId))
        ..add(TaskExpertLoadServiceTimeSlots(serviceId)),
      child: _ServiceDetailContent(serviceId: serviceId),
    );
  }
}

class _ServiceDetailContent extends StatelessWidget {
  const _ServiceDetailContent({required this.serviceId});

  final int serviceId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ResponsiveUtils.detailMaxWidth(context)),
          child: BlocConsumer<TaskExpertBloc, TaskExpertState>(
        listenWhen: (prev, curr) => prev.actionMessage != curr.actionMessage,
        listener: (context, state) {
          if (state.actionMessage != null) {
            final isError = state.actionMessage!.contains('failed');
            final message = switch (state.actionMessage) {
              'application_submitted' => context.l10n.actionApplicationSubmitted,
              'application_failed' => state.errorMessage != null
                  ? '${context.l10n.actionApplicationFailed}: ${state.errorMessage}'
                  : context.l10n.actionApplicationFailed,
              _ => state.actionMessage!,
            };
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: isError ? AppColors.error : AppColors.success,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.isLoading && state.selectedService == null) {
            return const LoadingView();
          }

          if (state.status == TaskExpertStatus.error &&
              state.selectedService == null) {
            return ErrorStateView.loadFailed(
              message:
                  state.errorMessage ?? context.l10n.serviceLoadFailed,
              onRetry: () => context
                  .read<TaskExpertBloc>()
                  .add(TaskExpertLoadServiceDetail(serviceId)),
            );
          }

          final service = state.selectedService;
          if (service == null) return const SizedBox.shrink();

          return Stack(
            children: [
              // 可滚动内容
              SingleChildScrollView(
                child: Column(
                  children: [
                    // 1. 图片画廊
                    _ImageGallery(images: service.images),

                    // 2. 内容区域
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // 价格与标题卡片（浮动效果）
                          Transform.translate(
                            offset: const Offset(0, -40),
                            child: _PriceAndTitleCard(service: service),
                          ),

                          // 描述卡片
                          _DescriptionCard(service: service),
                          const SizedBox(height: 24),

                          // 评价卡片
                          _ReviewsCard(
                            reviews: state.reviews,
                            isLoading: state.isLoadingReviews,
                          ),
                          const SizedBox(height: 24),

                          // 时间段卡片
                          if (service.hasTimeSlots)
                            _TimeSlotsCard(
                              timeSlots: state.timeSlots,
                              isLoading: state.isLoadingTimeSlots,
                            ),

                          // 方案C：达人的相关活动（仅开放中，无则隐藏）
                          if (!(state.expertActivities.isEmpty &&
                              !state.isLoadingExpertActivities)) ...[
                            _RelatedActivitiesSection(
                              activities: state.expertActivities,
                              isLoading: state.isLoadingExpertActivities,
                            ),
                            const SizedBox(height: 24),
                          ],

                          // 底部留白给底部栏
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 3. 固定底部申请栏
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _BottomApplyBar(
                  service: service,
                  serviceId: serviceId,
                ),
              ),
            ],
          );
        },
          ),
        ),
      ),
    );
  }
}

// =============================================================
// 图片画廊
// =============================================================

class _ImageGallery extends StatefulWidget {
  const _ImageGallery({this.images});

  final List<String>? images;

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    if (images != null && images.isNotEmpty) {
      return AspectRatio(
        aspectRatio: 5 / 4,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PageView.builder(
              itemCount: images.length,
              onPageChanged: (index) =>
                  setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return AsyncImageView(
                  imageUrl: images[index],
                  width: double.infinity,
                  height: double.infinity,
                );
              },
            ),
            if (images.length > 1)
              Positioned(
                bottom: 50,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(images.length, (i) {
                      final isActive = i == _currentIndex;
                      return Container(
                        width: isActive ? 8 : 6,
                        height: isActive ? 8 : 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                      );
                    }),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // 无图片占位
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 40,
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.serviceNoImages,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// 价格与标题卡片
// =============================================================

class _PriceAndTitleCard extends StatelessWidget {
  const _PriceAndTitleCard({required this.service});

  final TaskExpertService service;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 价格行
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '£',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                service.basePrice.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const Spacer(),
              Text(
                service.currency,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 服务名称
          Text(
            service.serviceName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// 描述卡片
// =============================================================

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.service});

  final TaskExpertService service;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题 + 装饰条
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.serviceDetail,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 描述内容
          Text(
            service.description.isNotEmpty
                ? service.description
                : context.l10n.serviceNoDescription,
            style: TextStyle(
              fontSize: 15,
              color: service.description.isNotEmpty
                  ? AppColors.textSecondaryLight
                  : AppColors.textTertiaryLight,
              height: 1.6,
              fontStyle: service.description.isNotEmpty
                  ? FontStyle.normal
                  : FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// 评价卡片
// =============================================================

class _ReviewsCard extends StatelessWidget {
  const _ReviewsCard({
    required this.reviews,
    required this.isLoading,
  });

  final List<Map<String, dynamic>> reviews;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.taskExpertReviews,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (reviews.isNotEmpty)
                Text(
                  context.l10n.taskExpertReviewsCount(reviews.length),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiaryLight,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // 内容
          if (isLoading && reviews.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: LoadingView(),
              ),
            )
          else if (reviews.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  context.l10n.taskExpertNoReviews,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiaryLight,
                  ),
                ),
              ),
            )
          else
            ...reviews.map((review) => _ReviewRow(review: review)),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.review});

  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final rating = (review['rating'] as num?)?.toDouble() ?? 0;
    final comment = review['comment'] as String?;
    final createdAt = review['created_at'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 星级评分
              ...List.generate(5, (i) {
                final star = i + 1;
                final fullStars = rating.floor();
                final hasHalf = rating - fullStars >= 0.5;
                IconData icon;
                Color color;
                if (star <= fullStars) {
                  icon = Icons.star;
                  color = AppColors.gold;
                } else if (star == fullStars + 1 && hasHalf) {
                  icon = Icons.star_half;
                  color = AppColors.gold;
                } else {
                  icon = Icons.star_border;
                  color = AppColors.textTertiaryLight;
                }
                return Icon(icon, size: 14, color: color);
              }),
              const Spacer(),
              if (createdAt != null)
                Text(
                  _formatTime(createdAt),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiaryLight,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}

// =============================================================
// 时间段卡片
// =============================================================

class _TimeSlotsCard extends StatelessWidget {
  const _TimeSlotsCard({
    required this.timeSlots,
    required this.isLoading,
  });

  final List<ServiceTimeSlot> timeSlots;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.taskExpertOptionalTimeSlots,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LoadingView(),
              ),
            )
          else if (timeSlots.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: AppColors.textTertiaryLight.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.taskExpertNoAvailableSlots,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
            )
          else
            ...timeSlots.map((slot) => _TimeSlotCard(slot: slot)),
        ],
      ),
    );
  }
}

class _TimeSlotCard extends StatelessWidget {
  const _TimeSlotCard({required this.slot});

  final ServiceTimeSlot slot;

  @override
  Widget build(BuildContext context) {
    // 判断状态：用户已申请 > 已满 > 已过期 > 可选
    final isDisabled = !slot.canSelect;

    return AnimatedOpacity(
      opacity: isDisabled ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: slot.userHasApplied
              ? AppColors.textTertiaryLight.withValues(alpha: 0.08)
              : AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDateTime(slot.slotStartDatetime),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDisabled
                          ? AppColors.textTertiaryLight
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_outline,
                          size: 12,
                          color: isDisabled
                              ? AppColors.textTertiaryLight
                              : AppColors.textSecondaryLight),
                      const SizedBox(width: 4),
                      Text(
                        '${slot.currentParticipants}/${slot.maxParticipants} ${context.l10n.activityPersonsBooked}',
                        style: AppTypography.caption.copyWith(
                          color: isDisabled
                              ? AppColors.textTertiaryLight
                              : AppColors.textSecondaryLight,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getBadgeColor(),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getBadgeText(context),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _getBadgeTextColor(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBadgeColor() {
    if (slot.userHasApplied) {
      return AppColors.textTertiaryLight.withValues(alpha: 0.2);
    }
    if (!slot.isAvailable ||
        slot.currentParticipants >= slot.maxParticipants) {
      return AppColors.textTertiaryLight.withValues(alpha: 0.2);
    }
    return AppColors.success;
  }

  String _getBadgeText(BuildContext context) {
    if (slot.userHasApplied) {
      return context.l10n.serviceApplied;
    }
    if (!slot.isAvailable ||
        slot.currentParticipants >= slot.maxParticipants) {
      return context.l10n.taskExpertFull;
    }
    return context.l10n.taskExpertOptional;
  }

  Color _getBadgeTextColor() {
    if (slot.userHasApplied || !slot.isAvailable ||
        slot.currentParticipants >= slot.maxParticipants) {
      return AppColors.textTertiaryLight;
    }
    return Colors.white;
  }

  String _formatDateTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}

// =============================================================
// 方案C：达人的相关活动区块（服务详情页）
// =============================================================

class _RelatedActivitiesSection extends StatelessWidget {
  const _RelatedActivitiesSection({
    required this.activities,
    required this.isLoading,
  });

  final List<Activity> activities;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading && activities.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    if (activities.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.taskExpertRelatedActivitiesSection,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...activities.map(
            (activity) => _RelatedActivityMiniCard(activity: activity),
          ),
        ],
      ),
    );
  }
}

class _RelatedActivityMiniCard extends StatelessWidget {
  const _RelatedActivityMiniCard({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ScrollSafeTap(
        onTap: () {
          AppHaptics.selection();
          context.push('/activities/${activity.id}');
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (activity.firstImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AsyncImageView(
                    imageUrl: activity.firstImage!,
                    width: 72,
                    height: 72,
                  ),
                )
              else
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.event,
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.displayTitle(Localizations.localeOf(context)),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activity.hasTimeSlots
                          ? context.l10n.activityMultipleTimeSlots
                          : (activity.deadline != null
                              ? DateFormat('MM/dd HH:mm')
                                  .format(activity.deadline!.toLocal())
                              : ''),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryLight,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${activity.currentParticipants ?? 0}/${activity.maxParticipants}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiaryLight,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          ' · ',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiaryLight,
                            fontSize: 11,
                          ),
                        ),
                        ActivityPriceWidget(activity: activity, fontSize: 11),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                context.l10n.homeView,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// 底部申请栏（对标iOS bottomApplyBar 5分支逻辑）
// =============================================================

class _BottomApplyBar extends StatelessWidget {
  const _BottomApplyBar({
    required this.service,
    required this.serviceId,
  });

  final TaskExpertService service;
  final int serviceId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: _buildButton(context),
      ),
    );
  }

  Widget _buildButton(BuildContext context) {
    if (service.userApplicationId != null) {
      // === 已申请 ===

      // 时间段服务特殊处理：已申请过某个时间段，但仍可申请其他时间段
      if (service.hasTimeSlots) {
        // 有议价 + 最新申请还在pending → 等待达人回应
        if (service.userApplicationHasNegotiation == true &&
            service.userApplicationStatus == 'pending') {
          return _buildDisabledButton(
            context,
            context.l10n.serviceWaitingExpertResponse,
          );
        }

        // 待支付 + 未支付 + 有taskId → 继续支付
        if (service.userTaskStatus == AppConstants.taskStatusPendingPayment &&
            service.userTaskIsPaid == false &&
            service.userTaskId != null) {
          return _buildPrimaryButton(
            context,
            context.l10n.serviceContinuePayment,
            () => context.goToTaskDetail(service.userTaskId!),
          );
        }

        // 其他情况：允许申请其他时间段
        return _buildPrimaryButton(
          context,
          context.l10n.serviceApplyOtherSlot,
          () => _ApplyServiceSheet.show(context, service, serviceId),
        );
      }

      // === 非时间段服务的已申请处理（原始逻辑） ===

      // 分支1: 有议价 + 任务状态为待支付 → 等待达人回应
      if (service.userApplicationHasNegotiation == true &&
          service.userTaskStatus == AppConstants.taskStatusPendingPayment) {
        return _buildDisabledButton(
          context,
          context.l10n.serviceWaitingExpertResponse,
        );
      }

      // 分支2: 待支付 + 未支付 + 有taskId → 继续支付
      if (service.userTaskStatus == AppConstants.taskStatusPendingPayment &&
          service.userTaskIsPaid == false &&
          service.userTaskId != null) {
        return _buildPrimaryButton(
          context,
          context.l10n.serviceContinuePayment,
          () => context.goToTaskDetail(service.userTaskId!),
        );
      }

      // 分支3: 有议价 + 申请状态pending → 等待达人回应
      if (service.userApplicationHasNegotiation == true &&
          service.userApplicationStatus == 'pending') {
        return _buildDisabledButton(
          context,
          context.l10n.serviceWaitingExpertResponse,
        );
      }

      // 分支4: 其他已申请状态 → 已申请
      return _buildDisabledButton(
        context,
        context.l10n.serviceApplied,
      );
    }

    // === 未申请 → 申请服务 ===
    return _buildPrimaryButton(
      context,
      context.l10n.taskExpertApplyService,
      () => _ApplyServiceSheet.show(context, service, serviceId),
    );
  }

  Widget _buildDisabledButton(BuildContext context, String text) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.textTertiaryLight.withValues(alpha: 0.3),
          disabledBackgroundColor:
              AppColors.textTertiaryLight.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(
      BuildContext context, String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(27),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(27),
            ),
            elevation: 0,
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================
// 申请服务弹窗（对标iOS ApplyServiceSheet）
// =============================================================

class _ApplyServiceSheet extends StatefulWidget {
  const _ApplyServiceSheet({
    required this.service,
    required this.serviceId,
  });

  final TaskExpertService service;
  final int serviceId;

  static void show(
      BuildContext context, TaskExpertService service, int serviceId) {
    SheetAdaptation.showAdaptiveModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<TaskExpertBloc>(),
        child: _ApplyServiceSheet(service: service, serviceId: serviceId),
      ),
    );
  }

  @override
  State<_ApplyServiceSheet> createState() => _ApplyServiceSheetState();
}

class _ApplyServiceSheetState extends State<_ApplyServiceSheet> {
  final _messageController = TextEditingController();
  final _counterPriceController = TextEditingController();
  bool _showCounterPrice = false;
  bool _isFlexibleTime = false;
  DateTime? _selectedDeadline;
  int? _selectedTimeSlotId;

  @override
  void dispose() {
    _messageController.dispose();
    _counterPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // 拖拽手柄
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      context.l10n.serviceApplyTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 内容
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // 留言
                    _buildSectionHeader(
                        context.l10n.serviceApplyMessage),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: context.l10n.serviceApplyMessage,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.medium),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 议价开关
                    _buildSectionHeader(context.l10n.serviceNegotiatePrice),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.serviceNegotiatePriceHint,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: _showCounterPrice,
                          activeTrackColor: AppColors.primary,
                          onChanged: (v) =>
                              setState(() => _showCounterPrice = v),
                        ),
                      ],
                    ),
                    if (_showCounterPrice) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _counterPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          prefixText: '£ ',
                          hintText: widget.service.basePrice
                              .toStringAsFixed(2),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.medium),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],

                    // 时间段选择（有时间段时显示）
                    if (widget.service.hasTimeSlots) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                          context.l10n.taskExpertOptionalTimeSlots),
                      const SizedBox(height: 8),
                      BlocBuilder<TaskExpertBloc, TaskExpertState>(
                        builder: (context, state) {
                          if (state.isLoadingTimeSlots) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          final slots = state.timeSlots;
                          if (slots.isEmpty) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                context.l10n.taskExpertNoAvailableSlots,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textTertiaryLight,
                                ),
                              ),
                            );
                          }
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: slots.map((slot) {
                              final isSelected =
                                  _selectedTimeSlotId == slot.id;
                              final canSelect = slot.canSelect;
                              return GestureDetector(
                                onTap: canSelect
                                    ? () => setState(
                                        () => _selectedTimeSlotId = slot.id)
                                    : null,
                                child: AnimatedOpacity(
                                  opacity: canSelect ? 1.0 : 0.4,
                                  duration:
                                      const Duration(milliseconds: 200),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                              .withValues(alpha: 0.1)
                                          : slot.userHasApplied
                                              ? AppColors.textTertiaryLight
                                                  .withValues(alpha: 0.08)
                                              : null,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.textTertiaryLight
                                                .withValues(alpha: 0.3),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (slot.userHasApplied)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 4),
                                            child: Text(
                                              context.l10n.serviceApplied,
                                              style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors
                                                    .textTertiaryLight,
                                              ),
                                            ),
                                          ),
                                        Text(
                                          _formatSlotTime(
                                              slot.slotStartDatetime),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? AppColors.primary
                                                : slot.userHasApplied
                                                    ? AppColors
                                                        .textTertiaryLight
                                                    : null,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${slot.currentParticipants}/${slot.maxParticipants}',
                                          style: AppTypography.caption
                                              .copyWith(
                                            fontSize: 11,
                                            color: AppColors
                                                .textSecondaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],

                    // 时间选择（仅无时间段时显示）
                    if (!widget.service.hasTimeSlots) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                          context.l10n.serviceSelectDeadline),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.serviceFlexibleTime,
                              style: AppTypography.body,
                            ),
                          ),
                          Switch.adaptive(
                            value: _isFlexibleTime,
                            activeTrackColor: AppColors.primary,
                            onChanged: (v) =>
                                setState(() => _isFlexibleTime = v),
                          ),
                        ],
                      ),
                      if (!_isFlexibleTime) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _selectDeadline,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: AppColors.textTertiaryLight
                                      .withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(
                                  AppRadius.medium),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  _selectedDeadline != null
                                      ? DateFormat('yyyy-MM-dd')
                                          .format(_selectedDeadline!)
                                      : context
                                          .l10n.serviceSelectDeadline,
                                  style: TextStyle(
                                    color: _selectedDeadline != null
                                        ? null
                                        : AppColors.textTertiaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              // 提交按钮
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: SafeArea(
                  top: false,
                  child: BlocBuilder<TaskExpertBloc, TaskExpertState>(
                    builder: (context, state) {
                      final canSubmit = !state.isSubmitting &&
                          (!widget.service.hasTimeSlots ||
                              _selectedTimeSlotId != null);
                      return SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: canSubmit ? _onSubmit : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(27),
                            ),
                          ),
                          child: state.isSubmitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  context
                                      .l10n.taskExpertApplyService,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatSlotTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('MM-dd HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  void _selectDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDeadline = picked);
    }
  }

  void _onSubmit() {
    double? counterPrice;
    if (_showCounterPrice && _counterPriceController.text.isNotEmpty) {
      counterPrice = double.tryParse(_counterPriceController.text);
    }

    String? deadline;
    if (!_isFlexibleTime && _selectedDeadline != null) {
      deadline = DateFormat('yyyy-MM-dd').format(_selectedDeadline!);
    }

    context.read<TaskExpertBloc>().add(
          TaskExpertApplyServiceEnhanced(
            widget.serviceId,
            message: _messageController.text.isNotEmpty
                ? _messageController.text
                : null,
            counterPrice: counterPrice,
            timeSlotId: _selectedTimeSlotId,
            isFlexibleTime:
                widget.service.hasTimeSlots ? false : _isFlexibleTime,
            preferredDeadline:
                widget.service.hasTimeSlots ? null : deadline,
          ),
        );

    Navigator.of(context).pop();
  }
}
