import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/helpers.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: ResponsiveUtils.detailMaxWidth(context)),
          child: BlocConsumer<TaskExpertBloc, TaskExpertState>(
            listenWhen: (prev, curr) =>
                prev.actionMessage != curr.actionMessage,
            listener: (context, state) {
              if (state.actionMessage != null) {
                final isError = state.actionMessage!.contains('failed');
                final message = switch (state.actionMessage) {
                  'application_submitted' =>
                    context.l10n.actionApplicationSubmitted,
                  'application_failed' => state.errorMessage != null
                      ? '${context.l10n.actionApplicationFailed}: ${state.errorMessage}'
                      : context.l10n.actionApplicationFailed,
                  _ => state.actionMessage!,
                };
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor:
                        isError ? AppColors.error : AppColors.success,
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
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        _ImageGallery(images: service.images),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              Transform.translate(
                                offset: const Offset(0, -40),
                                child: _PriceAndTitleCard(
                                    service: service, isDark: isDark),
                              ),

                              _DescriptionCard(
                                  service: service, isDark: isDark),
                              const SizedBox(height: 20),

                              _ReviewsCard(
                                reviews: state.reviews,
                                isLoading: state.isLoadingReviews,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 20),

                              if (service.hasTimeSlots)
                                _TimeSlotsCard(
                                  timeSlots: state.timeSlots,
                                  isLoading: state.isLoadingTimeSlots,
                                  isDark: isDark,
                                ),

                              if (!(state.expertActivities.isEmpty &&
                                  !state.isLoadingExpertActivities)) ...[
                                _RelatedActivitiesSection(
                                  activities: state.expertActivities,
                                  isLoading: state.isLoadingExpertActivities,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 20),
                              ],

                              const SizedBox(height: 120),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _BottomApplyBar(
                      service: service,
                      serviceId: serviceId,
                      isDark: isDark,
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(images.length, (i) {
                          final isActive = i == _currentIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isActive ? 18 : 6,
                            height: 6,
                            margin:
                                const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      height: 260,
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
            size: 44,
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.serviceNoImages,
            style: TextStyle(
              fontSize: 13,
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
  const _PriceAndTitleCard({required this.service, required this.isDark});

  final TaskExpertService service;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                '£',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE84D3D),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                Helpers.formatAmountNumber(service.basePrice),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE84D3D),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            service.serviceName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.3,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
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
  const _DescriptionCard({required this.service, required this.isDark});

  final TaskExpertService service;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: context.l10n.serviceDetail),
          const SizedBox(height: 16),
          Text(
            service.description.isNotEmpty
                ? service.description
                : context.l10n.serviceNoDescription,
            style: TextStyle(
              fontSize: 15,
              color: service.description.isNotEmpty
                  ? (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight)
                  : (isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight),
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
    required this.isDark,
  });

  final List<Map<String, dynamic>> reviews;
  final bool isLoading;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.taskExpertReviews,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const Spacer(),
              if (reviews.isNotEmpty)
                Text(
                  context.l10n.taskExpertReviewsCount(reviews.length),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
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
                child: Column(
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      size: 32,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.taskExpertNoReviews,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...reviews
                .map((review) => _ReviewRow(review: review, isDark: isDark)),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.review, required this.isDark});

  final Map<String, dynamic> review;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final rating = (review['rating'] as num?)?.toDouble() ?? 0;
    final comment = review['comment'] as String?;
    final createdAt = review['created_at'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
                  color = isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight;
                }
                return Icon(icon, size: 14, color: color);
              }),
              const Spacer(),
              if (createdAt != null)
                Text(
                  _formatTime(createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
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
    required this.isDark,
  });

  final List<ServiceTimeSlot> timeSlots;
  final bool isLoading;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: context.l10n.taskExpertOptionalTimeSlots),
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
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.taskExpertNoAvailableSlots,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
            )
          else
            ...timeSlots
                .map((slot) => _TimeSlotCard(slot: slot, isDark: isDark)),
        ],
      ),
    );
  }
}

class _TimeSlotCard extends StatelessWidget {
  const _TimeSlotCard({required this.slot, required this.isDark});

  final ServiceTimeSlot slot;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isDisabled = !slot.canSelect;

    return AnimatedOpacity(
      opacity: isDisabled ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: slot.userHasApplied
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : AppColors.textTertiaryLight.withValues(alpha: 0.08))
              : AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.05),
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
                          ? (isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight)
                          : (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_outline,
                          size: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight),
                      const SizedBox(width: 4),
                      Text(
                        '${slot.currentParticipants}/${slot.maxParticipants} ${context.l10n.activityPersonsBooked}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
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
    if (slot.userHasApplied || !slot.isAvailable ||
        slot.currentParticipants >= slot.maxParticipants) {
      return isDark
          ? Colors.white.withValues(alpha: 0.1)
          : AppColors.textTertiaryLight.withValues(alpha: 0.2);
    }
    return AppColors.success;
  }

  String _getBadgeText(BuildContext context) {
    if (slot.userHasApplied) return context.l10n.serviceApplied;
    if (!slot.isAvailable ||
        slot.currentParticipants >= slot.maxParticipants) {
      return context.l10n.taskExpertFull;
    }
    return context.l10n.taskExpertOptional;
  }

  Color _getBadgeTextColor() {
    if (slot.userHasApplied || !slot.isAvailable ||
        slot.currentParticipants >= slot.maxParticipants) {
      return isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
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
    required this.isDark,
  });

  final List<Activity> activities;
  final bool isLoading;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (isLoading && activities.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
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
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
              title: context.l10n.taskExpertRelatedActivitiesSection),
          const SizedBox(height: 16),
          ...activities.map(
            (activity) =>
                _RelatedActivityMiniCard(activity: activity, isDark: isDark),
          ),
        ],
      ),
    );
  }
}

class _RelatedActivityMiniCard extends StatelessWidget {
  const _RelatedActivityMiniCard(
      {required this.activity, required this.isDark});

  final Activity activity;
  final bool isDark;

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
            color: AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.05),
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
                      activity
                          .displayTitle(Localizations.localeOf(context)),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
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
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${activity.currentParticipants ?? 0}/${activity.maxParticipants}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                        ),
                        Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                        ),
                        ActivityPriceWidget(
                            activity: activity, fontSize: 11),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// 底部申请栏（对标iOS bottomApplyBar — 毛玻璃效果）
// =============================================================

class _BottomApplyBar extends StatelessWidget {
  const _BottomApplyBar({
    required this.service,
    required this.serviceId,
    required this.isDark,
  });

  final TaskExpertService service;
  final int serviceId;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : Colors.white)
                .withValues(alpha: 0.85),
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
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildButton(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context) {
    if (service.userApplicationId != null) {
      if (service.hasTimeSlots) {
        if (service.userApplicationHasNegotiation == true &&
            service.userApplicationStatus == 'pending') {
          return _buildDisabledButton(
            context,
            context.l10n.serviceWaitingExpertResponse,
          );
        }

        if (service.userTaskStatus == AppConstants.taskStatusPendingPayment &&
            service.userTaskIsPaid == false &&
            service.userTaskId != null) {
          return _buildPrimaryButton(
            context,
            context.l10n.serviceContinuePayment,
            () => context.goToTaskDetail(service.userTaskId!),
          );
        }

        return _buildPrimaryButton(
          context,
          context.l10n.serviceApplyOtherSlot,
          () => _ApplyServiceSheet.show(context, service, serviceId),
        );
      }

      if (service.userApplicationHasNegotiation == true &&
          service.userTaskStatus == AppConstants.taskStatusPendingPayment) {
        return _buildDisabledButton(
          context,
          context.l10n.serviceWaitingExpertResponse,
        );
      }

      if (service.userTaskStatus == AppConstants.taskStatusPendingPayment &&
          service.userTaskIsPaid == false &&
          service.userTaskId != null) {
        return _buildPrimaryButton(
          context,
          context.l10n.serviceContinuePayment,
          () => context.goToTaskDetail(service.userTaskId!),
        );
      }

      if (service.userApplicationHasNegotiation == true &&
          service.userApplicationStatus == 'pending') {
        return _buildDisabledButton(
          context,
          context.l10n.serviceWaitingExpertResponse,
        );
      }

      // 服务支持多次申请，不再显示灰色「已申请」不可点击，始终可再次申请
      return _buildPrimaryButton(
        context,
        context.l10n.taskExpertApplyService,
        () => _ApplyServiceSheet.show(context, service, serviceId),
      );
    }

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
          backgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : AppColors.textTertiaryLight.withValues(alpha: 0.3),
          disabledBackgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : AppColors.textTertiaryLight.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white60 : Colors.white,
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
              blurRadius: 12,
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
// 共用组件：区块标题（竖线 + 文字）
// =============================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    if (title.isEmpty) return const SizedBox.shrink();
    return Row(
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
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
      ],
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
      showDragHandle: false,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardBackgroundDark : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // 不在此处再画拖拽条：主题已设置 showDragHandle: true，ModalBottomSheet 会自带一条
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      context.l10n.serviceApplyTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
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
              Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : null),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildSectionHeader(context.l10n.serviceApplyMessage),
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

                    _buildSectionHeader(context.l10n.serviceNegotiatePrice),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.serviceNegotiatePriceHint,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
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
                          hintText: Helpers.formatAmountNumber(
                              widget.service.basePrice),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.medium),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],

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
                                padding:
                                    EdgeInsets.symmetric(vertical: 20),
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
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.textTertiaryDark
                                      : AppColors.textTertiaryLight,
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
                                    ? () => setState(() =>
                                        _selectedTimeSlotId = slot.id)
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
                                              ? (isDark
                                                  ? Colors.white
                                                      .withValues(
                                                          alpha: 0.04)
                                                  : AppColors
                                                      .textTertiaryLight
                                                      .withValues(
                                                          alpha: 0.08))
                                              : null,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : (isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.15)
                                                : AppColors
                                                    .textTertiaryLight
                                                    .withValues(
                                                        alpha: 0.3)),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (slot.userHasApplied)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(
                                                    bottom: 4),
                                            child: Text(
                                              context.l10n.serviceApplied,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? AppColors
                                                        .textTertiaryDark
                                                    : AppColors
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
                                                    ? (isDark
                                                        ? AppColors
                                                            .textTertiaryDark
                                                        : AppColors
                                                            .textTertiaryLight)
                                                    : null,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${slot.currentParticipants}/${slot.maxParticipants}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? AppColors
                                                    .textSecondaryDark
                                                : AppColors
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
                                  color: isDark
                                      ? Colors.white
                                          .withValues(alpha: 0.15)
                                      : AppColors.textTertiaryLight
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
                                        : (isDark
                                            ? AppColors.textTertiaryDark
                                            : AppColors
                                                .textTertiaryLight),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                            disabledBackgroundColor:
                                AppColors.primary.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(27),
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
                                  context.l10n.taskExpertApplyService,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
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
