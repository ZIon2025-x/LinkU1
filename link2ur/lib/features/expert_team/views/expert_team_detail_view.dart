import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/utils/share_util.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/activity.dart';
import '../../../data/models/expert_team.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../data/repositories/expert_team_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../../../data/services/storage_service.dart';
import '../../task_expert/views/activity_price_widget.dart';
import '../bloc/expert_team_bloc.dart';

// ---------------------------------------------------------------------------
// 1. Top-level entry
// ---------------------------------------------------------------------------

class ExpertTeamDetailView extends StatelessWidget {
  final String expertId;

  const ExpertTeamDetailView({super.key, required this.expertId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ExpertTeamBloc(
        repository: context.read<ExpertTeamRepository>(),
        activityRepository: context.read<ActivityRepository>(),
        taskExpertRepository: context.read<TaskExpertRepository>(),
      )
        ..add(ExpertTeamLoadDetail(expertId))
        ..add(ExpertTeamLoadServices(expertId))
        ..add(ExpertTeamLoadActivities(expertId))
        ..add(ExpertTeamLoadReviews(expertId)),
      child: _ExpertTeamDetailBody(expertId: expertId),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Body — handles loading / error / scaffold / bottom bar
// ---------------------------------------------------------------------------

class _ExpertTeamDetailBody extends StatelessWidget {
  final String expertId;
  const _ExpertTeamDetailBody({required this.expertId});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExpertTeamBloc, ExpertTeamState>(
      listenWhen: (prev, curr) =>
          curr.actionMessage != prev.actionMessage ||
          curr.errorMessage != prev.errorMessage,
      listener: (context, state) {
        // Handle consultation navigation
        if (state.actionMessage == 'consultation_started' &&
            state.consultationData != null) {
          final taskId = state.consultationData!['task_id'];
          final appId = state.consultationData!['application_id'];
          if (taskId != null && appId != null) {
            context.push('/tasks/$taskId/applications/$appId/chat?consultation=true');
          }
          return; // Don't show snackbar for this
        }
        final msg = state.actionMessage ?? state.errorMessage;
        if (msg != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.localizeError(msg))),
          );
        }
      },
      child: BlocBuilder<ExpertTeamBloc, ExpertTeamState>(
        buildWhen: (prev, curr) =>
            prev.status != curr.status ||
            prev.currentTeam != curr.currentTeam ||
            prev.services != curr.services ||
            prev.activities != curr.activities ||
            prev.isLoadingActivities != curr.isLoadingActivities ||
            prev.reviews != curr.reviews ||
            prev.isLoadingReviews != curr.isLoadingReviews ||
            prev.hasMoreReviews != curr.hasMoreReviews ||
            prev.totalReviews != curr.totalReviews,
        builder: (context, state) {
          if (state.status == ExpertTeamStatus.loading &&
              state.currentTeam == null) {
            return const Scaffold(body: LoadingView());
          }
          if (state.status == ExpertTeamStatus.error &&
              state.currentTeam == null) {
            return Scaffold(
              appBar: AppBar(title: Text(context.l10n.expertTeamDetail)),
              body: ErrorStateView(
                message: state.errorMessage != null
                    ? context.localizeError(state.errorMessage!)
                    : context.l10n.taskExpertLoadFailed,
                onRetry: () => context
                    .read<ExpertTeamBloc>()
                    .add(ExpertTeamLoadDetail(expertId)),
              ),
            );
          }
          final team = state.currentTeam;
          if (team == null) {
            return Scaffold(
              appBar: AppBar(title: Text(context.l10n.expertTeamDetail)),
              body: ErrorStateView(message: context.l10n.taskExpertLoadFailed),
            );
          }

          final currentUserId = StorageService.instance.getUserId();
          final members = team.members ?? [];
          final currentMember = members.firstWhere(
            (m) => m.userId == currentUserId,
            orElse: () => const ExpertMember(id: -1, userId: '', role: ''),
          );
          final isInTeam = currentMember.id != -1;
          final canManage = isInTeam && currentMember.canManage;

          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () {
                    ShareUtil.share(
                      title: team.displayName(Localizations.localeOf(context).languageCode),
                      description: team.displayBio(Localizations.localeOf(context).languageCode) ?? '',
                      url: ShareUtil.expertTeamUrl(team.id),
                      imageUrl: team.avatar,
                    );
                  },
                ),
              ],
            ),
            body: _DetailContent(
              team: team,
              expertId: expertId,
              state: state,
              isInTeam: isInTeam,
              canManage: canManage,
            ),
            bottomNavigationBar: _BottomActionBar(
              team: team,
              expertId: expertId,
              isInTeam: isInTeam,
              canManage: canManage,
              currentMember: currentMember,
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Detail content — assembles all sections
// ---------------------------------------------------------------------------

class _DetailContent extends StatelessWidget {
  final ExpertTeam team;
  final String expertId;
  final ExpertTeamState state;
  final bool isInTeam;
  final bool canManage;

  const _DetailContent({
    required this.team,
    required this.expertId,
    required this.state,
    required this.isInTeam,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 80,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroBanner(team: team),
          _StatsCard(team: team),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _BioSection(team: team),
                const SizedBox(height: 12),
                _TagsSection(team: team),
                if (state.services.isNotEmpty) ...[
                  _ServicesSection(
                    services: state.services,
                    expertId: expertId,
                  ),
                  const SizedBox(height: 12),
                ],
                if (state.activities.isNotEmpty ||
                    state.isLoadingActivities) ...[
                  _ActivitiesSection(
                    activities: state.activities,
                    isLoading: state.isLoadingActivities,
                  ),
                  const SizedBox(height: 12),
                ],
                _ReviewsSection(
                  reviews: state.reviews,
                  totalReviews: state.totalReviews,
                  rating: team.rating,
                  isLoading: state.isLoadingReviews,
                  hasMore: state.hasMoreReviews,
                  expertId: expertId,
                ),
                if (team.forumCategoryId != null) ...[
                  const SizedBox(height: 12),
                  _ForumEntry(forumCategoryId: team.forumCategoryId!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Hero banner
// ---------------------------------------------------------------------------

class _HeroBanner extends StatelessWidget {
  final ExpertTeam team;
  const _HeroBanner({required this.team});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final langCode = locale.languageCode;
    final teamName = team.displayName(langCode);

    final topPadding = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: 170 + topPadding,
      child: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF007AFF),
                    Color(0xFF5856D6),
                    Color(0xFFAF52DE),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Bottom gradient overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha(115),
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Decorative circles
                  Positioned(
                    top: -50,
                    right: -30,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withAlpha(15),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: -20,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withAlpha(15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Hero content
          Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Avatar ring
                Container(
                  width: 82,
                  height: 82,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Colors.white.withAlpha(153),
                      ],
                    ),
                  ),
                  child: AvatarView(
                    imageUrl: team.avatar,
                    name: team.name,
                    size: 76,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Name + badges
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Text(
                              teamName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            if (team.isOfficial)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFD700),
                                      Color(0xFFFF8C00),
                                    ],
                                  ),
                                ),
                                child: Text(
                                  context.l10n.expertTeamOfficialBadge,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            if (team.status == 'active') ...[
                              // isOpen: true=营业中, false=休息中, null=未设置营业时间(仅显示"运营中")
                              Builder(builder: (context) {
                                final isOpen = team.isOpen;
                                final String label;
                                final Color bgColor;
                                final IconData icon;
                                if (isOpen == null) {
                                  label = context.l10n.expertTeamStatusActive;
                                  bgColor = Colors.white.withAlpha(64);
                                  icon = Icons.check;
                                } else if (isOpen) {
                                  label = context.l10n.expertTeamStatusActive;
                                  bgColor = const Color(0xFF34C759).withAlpha(179);
                                  icon = Icons.circle;
                                } else {
                                  label = context.l10n.expertTeamStatusResting;
                                  bgColor = Colors.white.withAlpha(51);
                                  icon = Icons.nightlight_round;
                                }
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: bgColor,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(icon, size: 10, color: Colors.white),
                                      const SizedBox(width: 3),
                                      Text(
                                        label,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            if (team.isVerified)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.white.withAlpha(64),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.verified, size: 11, color: Colors.white),
                                    const SizedBox(width: 2),
                                    Text(context.l10n.verificationStatusVerified,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        )),
                                  ],
                                ),
                              ),
                            if (team.userLevel != 'normal')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFAF52DE), Color(0xFFFF2D55)],
                                  ),
                                ),
                                child: Text(
                                  team.userLevel.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Sub-row: category + follower count
                        Row(
                          children: [
                            if (team.category != null && team.category!.isNotEmpty) ...[
                              Text(
                                team.category!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withAlpha(217),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                ' · ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withAlpha(153),
                                ),
                              ),
                            ],
                            Text(
                              '${team.followerCount} ${context.l10n.expertTeamStatFollowers}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withAlpha(217),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        // Location
                        if (team.location != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 14,
                                  color: Colors.white.withAlpha(179)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  team.serviceRadiusKm != null
                                      ? '${team.location} · ${team.serviceRadiusKm}km'
                                      : team.location!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withAlpha(179),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Stats card — floating card overlapping hero bottom
// ---------------------------------------------------------------------------

class _StatsCard extends StatelessWidget {
  final ExpertTeam team;
  const _StatsCard({required this.team});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    return Transform.translate(
      offset: const Offset(0, -28),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 77 : 15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              _StatCell(
                  value: team.memberCount.toString(),
                  label: l10n.expertTeamStatMembers),
              _divider(isDark),
              _StatCell(
                  value: team.totalServices.toString(),
                  label: l10n.expertTeamStatServices),
              _divider(isDark),
              _StatCell(
                  value: team.completedTasks.toString(),
                  label: l10n.expertTeamStatCompleted),
              _divider(isDark),
              _StatCell(
                  value: team.rating.toStringAsFixed(1),
                  label: l10n.expertTeamStatRating,
                  valueColor: const Color(0xFFFF9500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: isDark ? AppColors.separatorDark : const Color(0xFFF0F0F0),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Stat cell
// ---------------------------------------------------------------------------

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  const _StatCell({required this.value, required this.label, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: valueColor ??
                  (isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. Bio section — expandable
// ---------------------------------------------------------------------------

class _BioSection extends StatefulWidget {
  final ExpertTeam team;
  const _BioSection({required this.team});

  @override
  State<_BioSection> createState() => _BioSectionState();
}

class _BioSectionState extends State<_BioSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final bio = widget.team.displayBio(locale.languageCode);
    if (bio == null || bio.isEmpty) return const SizedBox.shrink();
    final isLongBio = bio.length > 50;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.info_outline,
            iconGradient: const [Color(0xFF007AFF), Color(0xFF5856D6)],
            title: context.l10n.expertTeamBio,
          ),
          const SizedBox(height: 12),
          if (isLongBio)
            AnimatedCrossFade(
              firstChild: Text(
                bio,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.65,
                  color: isDark ? Colors.white70 : const Color(0xFF3C3C43),
                ),
              ),
              secondChild: Text(
                bio,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.65,
                  color: isDark ? Colors.white70 : const Color(0xFF3C3C43),
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            )
          else
            Text(
              bio,
              style: TextStyle(
                fontSize: 14,
                height: 1.65,
                color: isDark ? Colors.white70 : const Color(0xFF3C3C43),
              ),
            ),
          if (isLongBio) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? context.l10n.taskDetailCollapse : context.l10n.taskDetailExpandAll,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
          if (!isLongBio || _expanded) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.team.displayResponseTime(Localizations.localeOf(context).languageCode) != null)
                  _InfoPill(
                    icon: Icons.bolt_outlined,
                    label: context.l10n.taskExpertResponseTime,
                    value: widget.team.displayResponseTime(Localizations.localeOf(context).languageCode)!,
                  ),
                if (widget.team.serviceRadiusKm != null)
                  _InfoPill(
                    icon: Icons.location_on_outlined,
                    label: context.l10n.serviceRadius,
                    value: '${widget.team.serviceRadiusKm}km',
                  ),
                _InfoPill(
                  icon: Icons.check_circle_outline,
                  label: context.l10n.taskExpertCompletionRate,
                  value:
                      '${(widget.team.completionRate * 100).toStringAsFixed(0)}%',
                ),
              ],
            ),
            if (widget.team.businessHours != null && widget.team.businessHours!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _BusinessHoursView(businessHours: widget.team.businessHours!),
            ],
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7b. Business hours display
// ---------------------------------------------------------------------------

class _BusinessHoursView extends StatelessWidget {
  final Map<String, dynamic> businessHours;
  const _BusinessHoursView({required this.businessHours});

  static const _dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const _dayLabelsZh = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  static const _dayLabelsEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isZh = Localizations.localeOf(context).languageCode.startsWith('zh');
    final labels = isZh ? _dayLabelsZh : _dayLabelsEn;
    final closedText = isZh ? '休息' : 'Closed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.schedule, size: 14, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            const SizedBox(width: 4),
            Text(
              isZh ? '营业时间' : 'Business Hours',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...List.generate(_dayKeys.length, (i) {
          final day = _dayKeys[i];
          final hours = businessHours[day];
          final isOpen = hours is Map && hours['open'] != null && hours['close'] != null;
          final now = DateTime.now();
          final isToday = now.weekday == i + 1; // DateTime.monday = 1

          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                      color: isToday
                          ? AppColors.primary
                          : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isOpen ? '${hours['open']} - ${hours['close']}' : closedText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                    color: isOpen
                        ? (isToday
                            ? AppColors.primary
                            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight))
                        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 8. Section card — reusable white card wrapper
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// 9. Section header — icon + title + count + trailing
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final List<Color> iconGradient;
  final String title;
  final int? count;
  final VoidCallback? onSeeAll;

  const _SectionHeader({
    required this.icon,
    required this.iconGradient,
    required this.title,
    this.count,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            gradient: LinearGradient(colors: iconGradient),
          ),
          child: Icon(icon, size: 12, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Text(
          count != null ? '$title ($count)' : title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const Spacer(),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.expertTeamSeeAll,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 16, color: AppColors.primary),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 10. Info pill
// ---------------------------------------------------------------------------

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.secondaryBackgroundDark : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
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

// ---------------------------------------------------------------------------
// 10b. Tags section — expertise + skills + achievements
// ---------------------------------------------------------------------------

class _TagsSection extends StatelessWidget {
  final ExpertTeam team;
  const _TagsSection({required this.team});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langCode = Localizations.localeOf(context).languageCode;
    final expertise = team.displayExpertiseAreas(langCode);
    final skills = team.displayFeaturedSkills(langCode);
    final achievementList = team.displayAchievements(langCode);

    if (expertise.isEmpty && skills.isEmpty && achievementList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (expertise.isNotEmpty) ...[
              Text(
                context.l10n.taskExpertExpertiseAreas,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: expertise.map((t) => _Tag(
                  text: t,
                  bgColor: isDark ? const Color(0x260055CC) : const Color(0xFFE8F0FE),
                  textColor: isDark ? const Color(0xFF409CFF) : const Color(0xFF0055CC),
                )).toList(),
              ),
              const SizedBox(height: 10),
            ],
            if (skills.isNotEmpty) ...[
              Text(
                context.l10n.taskExpertFeaturedSkills,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: skills.map((t) => _Tag(
                  text: t,
                  bgColor: isDark ? const Color(0x266D28D9) : const Color(0xFFF0E6FF),
                  textColor: isDark ? const Color(0xFFBF9FFF) : const Color(0xFF6D28D9),
                )).toList(),
              ),
              const SizedBox(height: 10),
            ],
            if (achievementList.isNotEmpty) ...[
              Text(
                context.l10n.taskExpertAchievements,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: achievementList.map((t) => _Tag(
                  text: '\u{1F3C6} $t',
                  bgColor: isDark ? const Color(0x1FB45309) : const Color(0xFFFFF4E5),
                  textColor: isDark ? const Color(0xFFFFB84D) : const Color(0xFFB45309),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color textColor;

  const _Tag({required this.text, required this.bgColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 11. Services section — horizontal scroll
// ---------------------------------------------------------------------------

class _ServicesSection extends StatelessWidget {
  final List<Map<String, dynamic>> services;
  final String expertId;

  const _ServicesSection({
    required this.services,
    required this.expertId,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.design_services_outlined,
            iconGradient: const [Color(0xFF34C759), Color(0xFF30B350)],
            title: context.l10n.expertTeamStatServices,
            count: services.length,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 195,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: services.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _ServiceCard(
                key: ValueKey(services[i]['id']),
                service: services[i],
                expertId: expertId,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 14. Service card
// ---------------------------------------------------------------------------

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final String expertId;

  const _ServiceCard({super.key, required this.service, required this.expertId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final langCode = locale.languageCode;

    final name = (langCode.startsWith('zh')
            ? (service['name_zh'] as String?)
            : (service['name_en'] as String?)) ??
        (service['name'] as String? ?? '');
    final images = service['images'] as List?;
    final firstImage =
        images != null && images.isNotEmpty ? images.first as String? : null;
    // price 优先取后端计算好的 price (= package_price ?? base_price)，兼容 fallback
    final price = (service['price'] ?? service['package_price'] ?? service['base_price']) as num?;
    final packageType = service['package_type'] as String?;
    final isPackage = packageType == 'multi' || packageType == 'bundle';
    final totalSessions = service['total_sessions'] as int?;
    final serviceId = service['id'];

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        context.push('/service/$serviceId');
      },
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.secondaryBackgroundDark
              : const Color(0xFFF9F9FB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                width: 220,
                height: 120,
                child: firstImage != null
                    ? AsyncImageView(
                        imageUrl: Helpers.getThumbnailUrl(firstImage),
                        fallbackUrl: Helpers.getImageUrl(firstImage),
                        width: 220,
                        height: 120,
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFE8F0FE), Color(0xFFF0E6FF)],
                          ),
                        ),
                        child: Icon(Icons.design_services,
                            size: 28, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      ),
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (price != null)
                        Text(
                          '\u00a3${Helpers.formatAmountNumber(price)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.priceRed,
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      if (isPackage)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.primary.withAlpha(51)
                                : const Color(0xFFE8F0FE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            totalSessions != null ? '${totalSessions}x' : packageType!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
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

// ---------------------------------------------------------------------------
// 15. Activities section — horizontal scroll
// ---------------------------------------------------------------------------

class _ActivitiesSection extends StatelessWidget {
  final List<Activity> activities;
  final bool isLoading;

  const _ActivitiesSection({
    required this.activities,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && activities.isEmpty) {
      return _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.event_outlined,
              iconGradient: const [Color(0xFF34C759), Color(0xFF30D158)],
              title: context.l10n.activityActivities,
            ),
            const SizedBox(height: 12),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
        ),
      );
    }
    if (activities.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.event_outlined,
            iconGradient: const [Color(0xFF34C759), Color(0xFF30D158)],
            title: context.l10n.activityActivities,
            count: activities.length,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: activities.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _ActivityCard(key: ValueKey(activities[i].id), activity: activities[i]),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 16. Activity card
// ---------------------------------------------------------------------------

class _ActivityCard extends StatelessWidget {
  final Activity activity;
  const _ActivityCard({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final title = activity.displayTitle(locale);
    final desc = activity.displayDescription(locale);
    final image = activity.firstImage;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        context.push('/activities/${activity.id}');
      },
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.secondaryBackgroundDark
              : const Color(0xFFF9F9FB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area with overlays
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                width: 260,
                height: 130,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image != null)
                      AsyncImageView(
                        imageUrl: Helpers.getThumbnailUrl(image),
                        fallbackUrl: Helpers.getImageUrl(image),
                        width: 260,
                        height: 130,
                      )
                    else
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFE3F6E8), Color(0xFFD0F0DF)],
                          ),
                        ),
                        child: Icon(Icons.event,
                            size: 28, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      ),
                    // Status badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF34C759), Color(0xFF30B350)],
                          ),
                        ),
                        child: Text(
                          context.l10n.taskStatusOpen,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Date badge
                    if (activity.deadline != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(140),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            DateFormat('MM/dd').format(activity.deadline!),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Participants
                      Row(
                        children: [
                          Icon(Icons.people_outline,
                              size: 14, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                          const SizedBox(width: 4),
                          Text(
                            '${activity.currentParticipants ?? 0}/${activity.maxParticipants}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      // Price
                      ActivityPriceWidget(
                        activity: activity,
                        fontSize: 13,
                      ),
                    ],
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

// ---------------------------------------------------------------------------
// 17. Reviews section
// ---------------------------------------------------------------------------

class _ReviewsSection extends StatelessWidget {
  final List<Map<String, dynamic>> reviews;
  final int totalReviews;
  final double rating;
  final bool isLoading;
  final bool hasMore;
  final String expertId;

  const _ReviewsSection({
    required this.reviews,
    required this.totalReviews,
    required this.rating,
    required this.isLoading,
    required this.hasMore,
    required this.expertId,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.star_outline,
            iconGradient: const [Color(0xFFFF9500), Color(0xFFFFCC00)],
            title: l10n.taskExpertReviews,
            count: totalReviews > 0 ? totalReviews : (reviews.isNotEmpty ? reviews.length : null),
          ),
          const SizedBox(height: 14),
          // Summary row
          Row(
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF9500),
                  height: 1,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(5, (i) {
                      if (i < rating.floor()) {
                        return const Icon(Icons.star,
                            size: 16, color: Color(0xFFFF9500));
                      } else if (i < rating.ceil() && rating % 1 >= 0.5) {
                        return const Icon(Icons.star_half,
                            size: 16, color: Color(0xFFFF9500));
                      }
                      return Icon(Icons.star_border,
                          size: 16,
                          color: Colors.grey.withAlpha(100));
                    }),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.taskExpertReviewsCount(totalReviews > 0 ? totalReviews : reviews.length),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (reviews.isEmpty && !isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  l10n.taskExpertNoReviews,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ),
          if (reviews.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...reviews.take(5).map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ReviewCard(review: r),
                )),
          ],
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (hasMore && !isLoading)
            Center(
              child: TextButton(
                onPressed: () => context
                    .read<ExpertTeamBloc>()
                    .add(ExpertTeamLoadReviews(expertId, loadMore: true)),
                child: Text(l10n.commonLoadMore),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 18. Review card
// ---------------------------------------------------------------------------

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = review['user_name'] as String? ?? '';
    final userAvatar = review['user_avatar'] as String?;
    final reviewRating = (review['rating'] as num?)?.toDouble() ?? 5.0;
    final content = review['content'] as String? ?? '';
    final createdAt = review['created_at'] as String?;

    String dateStr = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt);
        dateStr = DateFormat('yyyy-MM-dd').format(dt);
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.secondaryBackgroundDark
            : const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarView(
                imageUrl: userAvatar,
                name: userName,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          if (i < reviewRating.floor()) {
                            return const Icon(Icons.star, size: 11, color: Color(0xFFFF9500));
                          } else if (i < reviewRating.ceil() && reviewRating % 1 >= 0.5) {
                            return const Icon(Icons.star_half, size: 11, color: Color(0xFFFF9500));
                          }
                          return Icon(Icons.star_border, size: 11, color: Colors.grey.withAlpha(100));
                        }),
                        if (dateStr.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              content,
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: isDark ? Colors.white70 : const Color(0xFF3C3C43),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 19. Forum entry
// ---------------------------------------------------------------------------

class _ForumEntry extends StatelessWidget {
  final int forumCategoryId;
  const _ForumEntry({required this.forumCategoryId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _SectionCard(
      child: GestureDetector(
        onTap: () {
          AppHaptics.selection();
          context.push('/forum/category/$forumCategoryId');
        },
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [Color(0xFF007AFF), Color(0xFF5AC8FA)],
                ),
              ),
              child: const Icon(Icons.forum, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.expertTeamForumSection,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 20. Bottom action bar
// ---------------------------------------------------------------------------

class _BottomActionBar extends StatelessWidget {
  final ExpertTeam team;
  final String expertId;
  final bool isInTeam;
  final bool canManage;
  final ExpertMember currentMember;

  const _BottomActionBar({
    required this.team,
    required this.expertId,
    required this.isInTeam,
    required this.canManage,
    required this.currentMember,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bloc = context.read<ExpertTeamBloc>();
    final members = team.members ?? [];
    final owner =
        members.where((m) => m.role == 'owner').toList();

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1C1C1E) : Colors.white)
            .withAlpha(235),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withAlpha(15)
                : Colors.black.withAlpha(15),
            width: 0.5,
          ),
        ),
      ),
      child: _buildContent(context, bloc, owner, isDark),
    );
  }

  Widget _buildContent(BuildContext context, ExpertTeamBloc bloc,
      List<ExpertMember> owners, bool isDark) {
    // Admin/owner: management button
    if (canManage) {
      return SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton.icon(
          onPressed: () =>
              context.push('/expert-dashboard/$expertId/management'),
          icon: const Icon(Icons.settings_outlined, size: 18),
          label: Text(context.l10n.expertDashboardManagement),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    // In team but not admin: leave button
    if (isInTeam) {
      return SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => _confirmLeave(context, bloc),
          child: Text(context.l10n.expertTeamLeave),
        ),
      );
    }

    // Visitor: follow + chat + apply
    final l10n = context.l10n;
    return Row(
      children: [
        // Follow button
        SizedBox(
          width: 52,
          height: 44,
          child: OutlinedButton(
            onPressed: () {
              AppHaptics.selection();
              bloc.add(ExpertTeamToggleFollow(expertId));
            },
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: team.isFollowing ? AppColors.primary : null,
              foregroundColor: team.isFollowing
                  ? Colors.white
                  : (isDark ? AppColors.primaryLight : AppColors.primary),
              side: BorderSide(
                color: isDark ? AppColors.primaryLight : AppColors.primary,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Icon(
              team.isFollowing ? Icons.favorite : Icons.favorite_border,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Chat button
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () {
                AppHaptics.selection();
                context.read<ExpertTeamBloc>().add(
                  ExpertTeamStartConsultation(expertId),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline, size: 16),
              label: Text(l10n.consultExpert),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    isDark ? AppColors.primaryLight : AppColors.primary,
                side: BorderSide(
                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        if (team.allowApplications) ...[
          const SizedBox(width: 10),
          // Apply button
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 44,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(77),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    AppHaptics.selection();
                    bloc.add(ExpertTeamRequestJoin(expertId: expertId));
                  },
                  icon: const Icon(Icons.group_add_outlined, size: 16),
                  label: Text(l10n.expertTeamRequestJoin),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmLeave(BuildContext context, ExpertTeamBloc bloc) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.expertTeamLeave),
        content: Text(l10n.expertTeamConfirmLeave),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.expertTeamLeave,
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      bloc.add(ExpertTeamLeave(expertId));
    }
  }
}
