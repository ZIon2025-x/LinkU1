import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/repositories/package_purchase_repository.dart';
import '../../../data/services/payment_service.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/sheet_adaptation.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/qa_section.dart';
import '../../../core/widgets/scroll_safe_tap.dart';
import '../../../data/models/activity.dart';
import '../../../data/models/task_expert.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../data/repositories/question_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import 'activity_price_widget.dart';
import '../bloc/task_expert_bloc.dart';

/// 服务详情页
/// 对标iOS ServiceDetailView.swift
class ServiceDetailView extends StatelessWidget {
  const ServiceDetailView(
      {super.key, required this.serviceId, this.withinServiceArea});

  final int serviceId;

  /// null = unknown (not from browse); false = outside service area; true = inside
  final bool? withinServiceArea;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TaskExpertBloc(
        taskExpertRepository: context.read<TaskExpertRepository>(),
        activityRepository: context.read<ActivityRepository>(),
        questionRepository: context.read<QuestionRepository>(),
      )
        ..add(TaskExpertLoadServiceDetail(serviceId))
        ..add(TaskExpertLoadServiceReviews(serviceId))
        ..add(TaskExpertLoadServiceTimeSlots(serviceId))
        ..add(TaskExpertLoadServiceApplications(serviceId))
        ..add(TaskExpertLoadServiceQuestions(serviceId)),
      child: _ServiceDetailContent(
          serviceId: serviceId, withinServiceArea: withinServiceArea),
    );
  }
}

class _ServiceDetailContent extends StatelessWidget {
  const _ServiceDetailContent(
      {required this.serviceId, this.withinServiceArea});

  final int serviceId;
  final bool? withinServiceArea;

  bool _isServiceOwner(TaskExpertService? service) {
    if (service == null) return false;
    final userId = StorageService.instance.getUserId();
    if (userId == null) return false;
    if (service.isPersonalService) {
      return service.userId == userId;
    }
    return service.expertId == userId;
  }

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
        actions: [
          BlocSelector<TaskExpertBloc, TaskExpertState, TaskExpertService?>(
            selector: (state) => state.selectedService,
            builder: (context, service) {
              if (service == null || !service.isPersonalService) return const SizedBox.shrink();
              final avatar = service.ownerAvatar;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: service.userId != null
                      ? () => context.goToUserProfile(service.userId!)
                      : null,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    backgroundImage: avatar != null && avatar.isNotEmpty
                        ? NetworkImage(Helpers.getImageUrl(avatar))
                        : null,
                    child: avatar == null || avatar.isEmpty
                        ? const Icon(Icons.person, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
              );
            },
          ),
        ],
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
                // consultation_started/failed are handled by _BottomApplyBar's BlocConsumer
                if (state.actionMessage == 'consultation_started' ||
                    state.actionMessage == 'consultation_failed') {
                  return;
                }
                final isError = state.actionMessage!.contains('failed');
                final message = switch (state.actionMessage) {
                  'application_submitted' =>
                    context.l10n.actionApplicationSubmitted,
                  'application_failed' => state.errorMessage != null
                      ? context.localizeError(state.errorMessage)
                      : context.l10n.actionApplicationFailed,
                  'service_reply_submitted' => context.l10n.successOperationSuccess,
                  'qa_ask_success' => context.l10n.qaAskSuccess,
                  'qa_reply_success' => context.l10n.qaReplySuccess,
                  'qa_delete_success' => context.l10n.qaDeleteSuccess,
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

                              if (withinServiceArea == false)
                                Builder(builder: (context) {
                                  final isBannerDark = Theme.of(context).brightness == Brightness.dark;
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    margin:
                                        const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: isBannerDark
                                          ? Colors.orange.withAlpha(30)
                                          : Colors.orange.shade50,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                          color: isBannerDark
                                              ? Colors.orange.withAlpha(80)
                                              : Colors.orange.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline,
                                            color: isBannerDark
                                                ? Colors.orange.shade300
                                                : Colors.orange.shade700,
                                            size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            context.l10n.outsideServiceArea,
                                            style: TextStyle(
                                                color: isBannerDark
                                                    ? Colors.orange.shade200
                                                    : Colors.orange.shade800,
                                                fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),

                              _ReviewsCard(
                                reviews: state.reviews,
                                isLoading: state.isLoadingReviews,
                                hasMore: state.hasMoreReviews,
                                serviceId: serviceId,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 20),

                              // Q&A 区域
                              QASection(
                                targetType: 'service',
                                isOwner: _isServiceOwner(state.selectedService),
                                isDark: isDark,
                                questions: state.serviceQuestions,
                                isLoading: state.isLoadingServiceQuestions,
                                totalCount: state.serviceQuestionsTotalCount,
                                isLoggedIn: StorageService.instance.getUserId() != null,
                                onAsk: (content) => context.read<TaskExpertBloc>().add(
                                  TaskExpertAskServiceQuestion(serviceId: serviceId, content: content),
                                ),
                                onReply: (questionId, content) => context.read<TaskExpertBloc>().add(
                                  TaskExpertReplyServiceQuestion(questionId: questionId, content: content),
                                ),
                                onDelete: (questionId) => context.read<TaskExpertBloc>().add(
                                  TaskExpertDeleteServiceQuestion(questionId),
                                ),
                                onLoadMore: () => context.read<TaskExpertBloc>().add(
                                  TaskExpertLoadServiceQuestions(serviceId, page: state.serviceQuestionsCurrentPage + 1),
                                ),
                              ),

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
                  imageUrl: Helpers.getThumbnailUrl(images[index], size: 'large'),
                  fallbackUrl: Helpers.getImageUrl(images[index]),
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
          if (service.isPending || service.isRejected)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: service.isPending
                    ? Colors.orange.withValues(alpha: 0.12)
                    : AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    service.isPending ? Icons.hourglass_top : Icons.block,
                    size: 16,
                    color: service.isPending ? Colors.orange : AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    service.isPending
                        ? context.l10n.servicePendingReview
                        : context.l10n.serviceRejected,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          service.isPending ? Colors.orange : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                Helpers.currencySymbolFor(service.currency),
                style: const TextStyle(
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
            service.displayServiceName(Localizations.localeOf(context)),
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
// 个人服务所有者信息卡片
// =============================================================


// =============================================================
// 描述卡片
// =============================================================

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.service, required this.isDark});

  final TaskExpertService service;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final displayDesc = service.displayDescription(locale);
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
            displayDesc.isNotEmpty
                ? Helpers.normalizeContentNewlines(displayDesc)
                : context.l10n.serviceNoDescription,
            style: TextStyle(
              fontSize: 15,
              color: displayDesc.isNotEmpty
                  ? (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight)
                  : (isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight),
              height: 1.6,
              fontStyle: displayDesc.isNotEmpty
                  ? FontStyle.normal
                  : FontStyle.italic,
            ),
          ),
          // 技能标签
          if (service.skills != null && service.skills!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: isDark ? AppColors.dividerDark : AppColors.dividerLight),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.label_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  context.l10n.createTaskRequiredSkills,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: service.skills!.map((skill) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  skill,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
            ),
          ],
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
    required this.hasMore,
    required this.serviceId,
    required this.isDark,
  });

  final List<Map<String, dynamic>> reviews;
  final bool isLoading;
  final bool hasMore;
  final int serviceId;
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
          else ...[
            ...reviews
                .map((review) => _ReviewRow(review: review, isDark: isDark)),
            if (hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : TextButton(
                          onPressed: () {
                            context.read<TaskExpertBloc>().add(
                                  TaskExpertLoadServiceReviews(serviceId,
                                      loadMore: true),
                                );
                          },
                          child: Text(
                            context.l10n.commonLoadMore,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                ),
              ),
          ],
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
      final date = DateTime.parse(dateStr).toLocal();
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
                    imageUrl: Helpers.getThumbnailUrl(activity.firstImage!),
                    fallbackUrl: Helpers.getImageUrl(activity.firstImage!),
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

  bool get _isOwner {
    final currentUserId = StorageService.instance.getUserId();
    if (currentUserId == null) return false;
    return (service.isPersonalService && currentUserId == service.userId) ||
        (!service.isPersonalService && currentUserId == service.expertId);
  }

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
              child: Row(
                children: [
                  if (_showConsultButton)
                    Expanded(child: _buildConsultButton(context)),
                  if (_showConsultButton)
                    const SizedBox(width: 12),
                  Expanded(child: _buildButton(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _showConsultButton {
    if (_isOwner) return false;
    if (service.isPending || service.isRejected) return false;
    return true;
  }

  Widget _buildConsultButton(BuildContext context) {
    final hasConsulting = service.userApplicationStatus == 'consulting';
    final label = hasConsulting
        ? context.l10n.continueConsultation
        : context.l10n.consultExpert;

    return BlocConsumer<TaskExpertBloc, TaskExpertState>(
      listenWhen: (prev, curr) =>
          prev.actionMessage != curr.actionMessage &&
          (curr.actionMessage == 'consultation_started' ||
           curr.actionMessage == 'consultation_failed'),
      listener: (context, state) {
        if (state.actionMessage == 'consultation_started' &&
            state.consultationData != null) {
          final taskId = state.consultationData!['task_id'];
          final appId = state.consultationData!['application_id'];
          if (taskId != null && appId != null) {
            context.push('/tasks/$taskId/applications/$appId/chat?consultation=true');
          }
        } else if (state.actionMessage == 'consultation_failed') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.errorMessage != null
                    ? context.localizeError(state.errorMessage)
                    : context.l10n.consultExpert,
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      buildWhen: (prev, curr) => prev.isSubmitting != curr.isSubmitting,
      builder: (context, state) {
        return SizedBox(
          height: 54,
          child: OutlinedButton.icon(
            onPressed: state.isSubmitting
                ? null
                : () => requireAuth(context, () => context
                    .read<TaskExpertBloc>()
                    .add(TaskExpertStartConsultation(serviceId))),
            icon: state.isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    hasConsulting ? Icons.chat : Icons.chat_bubble_outline,
                    size: 18,
                  ),
            label: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(27),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 申请状态为「达人审核/议价中」：pending / negotiating / price_agreed
  static bool _isApplicationUnderReview(String? status) {
    return status == 'pending' ||
        status == 'negotiating' ||
        status == 'price_agreed';
  }

  Widget _buildButton(BuildContext context) {
    if (service.isPending) {
      return _buildDisabledButton(context, context.l10n.servicePendingReview);
    }
    if (service.isRejected) {
      return _buildDisabledButton(context, context.l10n.serviceRejected);
    }

    // 服务所有者不能申请自己的服务
    if (_isOwner) {
      return const SizedBox.shrink();
    }

    if (service.userApplicationId != null) {
      // 1. 待支付且未支付 -> 继续支付
      if (service.userTaskStatus == AppConstants.taskStatusPendingPayment &&
          service.userTaskIsPaid == false &&
          service.userTaskId != null) {
        return _buildPrimaryButton(
          context,
          context.l10n.serviceContinuePayment,
          () => context.goToTaskDetail(service.userTaskId!),
        );
      }

      // 2. 达人正在审核或议价中 -> 灰色「审核中」不可点击
      if (_isApplicationUnderReview(service.userApplicationStatus)) {
        return _buildDisabledButton(
          context,
          context.l10n.serviceUnderReview,
        );
      }

      // 3. 服务已完成 -> 允许再次申请同一服务
      if (service.userTaskStatus == AppConstants.taskStatusCompleted) {
        return _buildPrimaryButton(
          context,
          context.l10n.serviceApplyAgain,
          () => _ApplyServiceSheet.show(context, service, serviceId),
        );
      }

      // 4. 已通过且任务进行中（未完成、非待支付）-> 灰色「服务进行中」不可点击
      if (service.userApplicationStatus == 'approved' &&
          service.userTaskStatus != null &&
          service.userTaskStatus != AppConstants.taskStatusCompleted &&
          service.userTaskStatus != AppConstants.taskStatusPendingPayment) {
        return _buildDisabledButton(
          context,
          context.l10n.serviceInProgress,
        );
      }

      // 5. 有时间段且当前申请已结束（已通过/拒绝等）-> 申请其他时段
      if (service.hasTimeSlots) {
        return _buildPrimaryButton(
          context,
          context.l10n.serviceApplyOtherSlot,
          () => _ApplyServiceSheet.show(context, service, serviceId),
        );
      }

      // 6. 其他（如已拒绝、已取消等）-> 可再次申请
      return _buildPrimaryButton(
        context,
        context.l10n.serviceApplyAgain,
        () => _ApplyServiceSheet.show(context, service, serviceId),
      );
    }

    final primaryApply = _buildPrimaryButton(
      context,
      context.l10n.taskExpertApplyService,
      () => _ApplyServiceSheet.show(context, service, serviceId),
    );

    // A1: 套餐类型服务额外显示"购买套餐"按钮
    final isPackage = service.packageType == 'multi' || service.packageType == 'bundle';
    if (isPackage) {
      return Column(
        children: [
          _buildPrimaryButton(
            context,
            '购买套餐',
            () => _PurchasePackageDialog.show(context, service, serviceId),
          ),
          const SizedBox(height: 8),
          primaryApply,
        ],
      );
    }
    return primaryApply;
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
    required this.bloc,
  });

  final TaskExpertService service;
  final int serviceId;
  final TaskExpertBloc bloc;

  static void show(
      BuildContext context, TaskExpertService service, int serviceId) {
    final bloc = context.read<TaskExpertBloc>();
    SheetAdaptation.showAdaptiveModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (_) => _ApplyServiceSheet(service: service, serviceId: serviceId, bloc: bloc),
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

    return BlocListener<TaskExpertBloc, TaskExpertState>(
      bloc: widget.bloc,
      listenWhen: (prev, curr) =>
          curr.actionMessage != null &&
          prev.actionMessage != curr.actionMessage,
      listener: (context, state) {
        if (state.actionMessage == 'application_submitted') {
          Navigator.of(context).pop();
        }
        if (state.actionMessage == 'application_failed') {
          // Stay open so user can retry; snackbar handled by parent listener
        }
      },
      child: DraggableScrollableSheet(
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
                        tooltip: 'Close',
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
                          prefixText: '${Helpers.currencySymbolFor(widget.service.currency)} ',
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
                        bloc: widget.bloc,
                        buildWhen: (prev, curr) =>
                            prev.isLoadingTimeSlots != curr.isLoadingTimeSlots ||
                            prev.timeSlots != curr.timeSlots,
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
                    bloc: widget.bloc,
                    buildWhen: (prev, curr) =>
                        prev.isSubmitting != curr.isSubmitting,
                    builder: (context, state) {
                      final canSubmit = !state.isSubmitting &&
                          (widget.service.hasTimeSlots
                              ? _selectedTimeSlotId != null
                              : (_isFlexibleTime || _selectedDeadline != null));
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
      ),
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
      if (counterPrice == null || counterPrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.fleaMarketNegotiatePriceTooLow)),
        );
        return;
      }
      // Round to 2 decimal places to avoid floating point precision issues
      counterPrice = double.parse(counterPrice.toStringAsFixed(2));
    }

    String? deadline;
    if (!_isFlexibleTime && _selectedDeadline != null) {
      // Set to end-of-day (23:59:59) local time, then convert to UTC ISO 8601
      final endOfDay = DateTime(
        _selectedDeadline!.year,
        _selectedDeadline!.month,
        _selectedDeadline!.day,
        23, 59, 59,
      );
      deadline = endOfDay.toUtc().toIso8601String();
    }

    widget.bloc.add(
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
  }
}

// =============================================================
// A1: 套餐购买对话框
// =============================================================
//
// 显示套餐基本信息(总价/课时/有效期),用户确认后调用
// PackagePurchaseRepository.purchasePackage 拿 client_secret,
// 然后跳转 Stripe payment sheet (复用项目现有支付集成)。
class _PurchasePackageDialog extends StatelessWidget {
  final TaskExpertService service;
  final int serviceId;

  const _PurchasePackageDialog({
    required this.service,
    required this.serviceId,
  });

  static Future<void> show(
    BuildContext context,
    TaskExpertService service,
    int serviceId,
  ) {
    return showDialog<void>(
      context: context,
      builder: (_) => _PurchasePackageDialog(
        service: service,
        serviceId: serviceId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isMulti = service.packageType == 'multi';
    final isBundle = service.packageType == 'bundle';
    final theme = Theme.of(context);
    final routerSaved = GoRouter.of(context);
    final messengerSaved = ScaffoldMessenger.of(context);

    // 价格格式化: packagePrice 是单位一致的 double (GBP 为镑),
    // 未设置时 fallback 为 base_price * total_sessions 的估算, 与后端 metadata 不一定一致,
    // 所以只在 packagePrice 存在时才显示, 避免误导用户.
    final priceStr = service.packagePrice?.toStringAsFixed(2);
    final currency = service.currency;

    return AlertDialog(
      title: Text(l10n.packagePurchaseDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            service.serviceName,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (isMulti) ...[
            _row(
              l10n.packagePurchaseTypeLabel,
              l10n.packagePurchaseTypeMulti,
            ),
            _row(
              l10n.packagePurchaseTotalSessionsLabel,
              l10n.packagePurchaseTotalSessionsValue(service.totalSessions ?? 0),
            ),
          ],
          if (isBundle) ...[
            _row(
              l10n.packagePurchaseTypeLabel,
              l10n.packagePurchaseTypeBundle,
            ),
            _row(
              l10n.packagePurchaseBundleSizeLabel,
              l10n.packagePurchaseBundleSizeValue(service.bundleServiceIds?.length ?? 0),
            ),
          ],
          if (priceStr != null)
            _row(
              l10n.packagePurchasePriceLabel,
              '${Helpers.currencySymbolFor(currency)}$priceStr',
            ),
          _row(
            l10n.packagePurchaseValidityLabel,
            service.validityDays != null
                ? l10n.packagePurchaseValidityDays(service.validityDays!)
                : l10n.packagePurchaseValidityForever,
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 4),
          Text(
            l10n.packagePurchaseFootnote,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.packagePurchaseCancel),
        ),
        ElevatedButton(
          onPressed: () async {
            final repo = context.read<PackagePurchaseRepository>();
            final rootNavigator = Navigator.of(context, rootNavigator: true);
            // 先把对话框用到的 l10n / localizer 句柄保存下来, pop 后 context 就不能再用了
            final l10nSaved = context.l10n;
            // 扩展方法不能直接 tear-off, 用闭包包一层, 捕获 root navigator 的 context
            String localizeError(String msg) =>
                rootNavigator.context.localizeError(msg);
            // 用专属 GlobalKey 给 loading dialog 定身份, 关闭时只 pop 它本身,
            // 避免 rootNavigator.canPop() 误伤无关路由 (例如用户在等待期间进了别的页面)。
            final loadingDialogKey = GlobalKey();
            bool loadingDialogOpen = false;
            void closeLoadingDialog() {
              if (!loadingDialogOpen) return;
              loadingDialogOpen = false;
              final ctx = loadingDialogKey.currentContext;
              if (ctx != null) {
                Navigator.of(ctx, rootNavigator: true).pop();
              }
            }

            Navigator.of(context).pop();
            try {
              // 1. 创建套餐订单 PaymentIntent
              final result = await repo.purchasePackage(serviceId);
              final clientSecret = result['client_secret'] as String?;
              final paymentIntentId = result['payment_intent_id'] as String?;
              if (clientSecret == null || clientSecret.isEmpty) {
                messengerSaved.showSnackBar(
                  SnackBar(content: Text(l10nSaved.packagePurchaseOrderCreateFailed)),
                );
                return;
              }
              // 2. 唤起 Stripe PaymentSheet 完成支付
              final success = await PaymentService.instance.presentPaymentSheet(
                clientSecret: clientSecret,
              );
              if (!success) return;
              // 3. 显示 loading dialog,轮询直到 webhook 创建 UserServicePackage
              //    避免导航竞速导致"我的套餐"列表为空
              // 用 root navigator 的 context 打开 dialog — 原 dialog 的 context 已在 pop 后失效
              loadingDialogOpen = true;
              unawaited(showDialog<void>(
                // ignore: use_build_context_synchronously
                context: rootNavigator.context,
                barrierDismissible: false,
                builder: (_) => Dialog(
                  key: loadingDialogKey,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(width: 16),
                        Flexible(child: Text(l10nSaved.packagePurchaseProcessing)),
                      ],
                    ),
                  ),
                ),
              ).whenComplete(() => loadingDialogOpen = false));
              Map<String, dynamic>? created;
              if (paymentIntentId != null && paymentIntentId.isNotEmpty) {
                created = await repo.waitForPackageByPaymentIntent(
                  paymentIntentId,
                );
              }
              // 关闭 loading dialog (只 pop 它自身, 不动其他路由)
              closeLoadingDialog();
              if (created != null) {
                messengerSaved.showSnackBar(
                  SnackBar(content: Text(l10nSaved.packagePurchaseSuccess)),
                );
              } else {
                // 轮询超时:webhook 可能稍后完成,友好提示
                messengerSaved.showSnackBar(
                  SnackBar(content: Text(l10nSaved.packagePurchasePendingWebhook)),
                );
              }
              routerSaved.go('/my-packages');
            } catch (e) {
              // 任何错误都要确保 loading dialog 被关掉
              closeLoadingDialog();
              messengerSaved.showSnackBar(
                SnackBar(content: Text(localizeError(e.toString()))),
              );
            }
          },
          child: Text(l10n.packagePurchaseConfirm),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
