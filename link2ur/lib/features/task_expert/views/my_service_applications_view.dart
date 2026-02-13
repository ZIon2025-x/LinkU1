import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../data/models/activity.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../activity/views/activity_list_view.dart';

/// 我的活动页（对齐iOS MyServiceApplicationsView.swift）
/// 3个分类Tab：全部 / 申请过的 / 收藏的
class MyServiceApplicationsView extends StatefulWidget {
  const MyServiceApplicationsView({super.key});

  @override
  State<MyServiceApplicationsView> createState() =>
      _MyServiceApplicationsViewState();
}

enum _ActivityTab { all, applied, favorited }

class _MyServiceApplicationsViewState extends State<MyServiceApplicationsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 各分类数据（对齐iOS cachedActivities）
  List<Activity> _allActivities = [];
  List<Activity> _appliedActivities = [];
  List<Activity> _favoritedActivities = [];

  // 加载状态
  bool _isLoadingAll = true;
  bool _isLoadingApplied = false;
  bool _isLoadingFavorited = false;

  // 错误状态
  final Map<_ActivityTab, String?> _tabErrors = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        AppHaptics.tabSwitch();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllActivities();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 对齐iOS loadAllActivities() — 加载全部数据并从中过滤
  Future<void> _loadAllActivities({bool forceRefresh = false}) async {
    if (!mounted) return;
    final repo = context.read<ActivityRepository>();

    setState(() {
      _isLoadingAll = true;
      _isLoadingApplied = true;
      _isLoadingFavorited = true;
      _tabErrors.clear();
    });

    try {
      final response = await repo.getMyActivities(type: 'all');
      if (!mounted) return;

      final all = response.activities;

      // 对齐iOS: 从全部数据中过滤
      final applied = all
          .where((a) => a.type == 'applied' || a.type == 'both')
          .toList();
      final favorited = all
          .where((a) => a.type == 'favorited' || a.type == 'both')
          .toList();

      setState(() {
        _allActivities = all;
        _appliedActivities = applied;
        _favoritedActivities = favorited;
        _isLoadingAll = false;
        _isLoadingApplied = false;
        _isLoadingFavorited = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingAll = false;
        _isLoadingApplied = false;
        _isLoadingFavorited = false;
        _tabErrors[_ActivityTab.all] = e.toString();
        _tabErrors[_ActivityTab.applied] = e.toString();
        _tabErrors[_ActivityTab.favorited] = e.toString();
      });
    }
  }

  List<Activity> _getActivities(_ActivityTab tab) {
    switch (tab) {
      case _ActivityTab.all:
        return _allActivities;
      case _ActivityTab.applied:
        return _appliedActivities;
      case _ActivityTab.favorited:
        return _favoritedActivities;
    }
  }

  bool _isLoading(_ActivityTab tab) {
    switch (tab) {
      case _ActivityTab.all:
        return _isLoadingAll;
      case _ActivityTab.applied:
        return _isLoadingApplied;
      case _ActivityTab.favorited:
        return _isLoadingFavorited;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.taskExpertMyApplications),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(text: l10n.activityTabAll),
            Tab(text: l10n.activityTabApplied),
            Tab(text: l10n.activityTabFavorited),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent(_ActivityTab.all),
          _buildTabContent(_ActivityTab.applied),
          _buildTabContent(_ActivityTab.favorited),
        ],
      ),
    );
  }

  Widget _buildTabContent(_ActivityTab tab) {
    final activities = _getActivities(tab);
    final loading = _isLoading(tab);
    final error = _tabErrors[tab];
    final l10n = context.l10n;

    if (loading && activities.isEmpty) {
      return const SkeletonList();
    }

    if (error != null && activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48,
                color: AppColors.error.withValues(alpha: 0.5)),
            AppSpacing.vMd,
            Text(l10n.taskExpertNoActivities),
            AppSpacing.vMd,
            TextButton(
              onPressed: () => _loadAllActivities(forceRefresh: true),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      );
    }

    if (activities.isEmpty) {
      String title;
      String message;
      switch (tab) {
        case _ActivityTab.all:
          title = l10n.taskExpertNoActivities;
          message = l10n.taskExpertNoActivitiesMessage;
        case _ActivityTab.applied:
          title = l10n.taskExpertNoActivities;
          message = l10n.taskExpertNoAppliedMessage;
        case _ActivityTab.favorited:
          title = l10n.taskExpertNoFavorites;
          message = l10n.taskExpertNoFavoritesMessage;
      }
      return EmptyStateView(
        icon: tab == _ActivityTab.favorited ? Icons.favorite_border : Icons.event_busy,
        title: title,
        message: message,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadAllActivities(forceRefresh: true),
      child: ListView.separated(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: activities.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final activity = activities[index];
          return AnimatedListItem(
            key: ValueKey(activity.id),
            index: index,
            child: ActivityCardView(
              activity: activity,
              activityType: activity.type,
              onTap: () => context.push('/activities/${activity.id}'),
            ),
          );
        },
      ),
    );
  }
}

