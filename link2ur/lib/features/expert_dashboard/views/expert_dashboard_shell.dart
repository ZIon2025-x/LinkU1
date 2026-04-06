import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/models/expert_team.dart';
import '../../../data/repositories/expert_team_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../../../data/services/storage_service.dart';
import '../bloc/expert_dashboard_bloc.dart';
import '../bloc/selected_expert_cubit.dart';
import 'tabs/applications_tab.dart';
import 'tabs/schedule_tab.dart';
import 'tabs/services_tab.dart';
import 'tabs/stats_tab.dart';
import 'tabs/time_slots_tab.dart';

/// 统一达人管理页面 shell
/// 两阶段：1. fetch my-teams 解析 expertId；2. 显示 5 tab dashboard
class ExpertDashboardShell extends StatefulWidget {
  const ExpertDashboardShell({super.key});

  @override
  State<ExpertDashboardShell> createState() => _ExpertDashboardShellState();
}

class _ExpertDashboardShellState extends State<ExpertDashboardShell> {
  List<ExpertTeam>? _myTeams;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMyTeams();
  }

  Future<void> _fetchMyTeams() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final teams = await context.read<ExpertTeamRepository>().getMyTeams();
      if (!mounted) return;
      if (teams.isEmpty) {
        // 无团队 → 重定向到 intro 页
        context.go(AppRoutes.taskExpertsIntro);
        return;
      }
      setState(() {
        _myTeams = teams;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.expertDashboardTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _myTeams == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.expertDashboardTitle)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(context.localizeError(_error ?? 'expert_dashboard_no_team')),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _fetchMyTeams,
                child: Text(context.l10n.commonRetry),
              ),
            ],
          ),
        ),
      );
    }

    // 初始 expertId：存储的优先，否则第一个
    final storedId = StorageService.instance.getSelectedExpertId();
    final initialId =
        (storedId != null && _myTeams!.any((t) => t.id == storedId))
            ? storedId
            : _myTeams!.first.id;

    return BlocProvider(
      create: (_) => SelectedExpertCubit(
        myTeams: _myTeams!,
        initialExpertId: initialId,
      ),
      child: BlocBuilder<SelectedExpertCubit, SelectedExpertState>(
        buildWhen: (prev, curr) => prev.currentExpertId != curr.currentExpertId,
        builder: (context, state) {
          return _DashboardTabs(key: ValueKey(state.currentExpertId));
        },
      ),
    );
  }
}

class _DashboardTabs extends StatelessWidget {
  const _DashboardTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final cubitState = context.watch<SelectedExpertCubit>().state;
    final canManage = cubitState.canManage;
    final expertId = cubitState.currentExpertId;

    // Member 角色不显示 applications tab
    final tabs = <Widget>[
      Tab(icon: const Icon(Icons.dashboard), text: context.l10n.expertDashboardTabStats),
      Tab(icon: const Icon(Icons.design_services), text: context.l10n.expertDashboardTabServices),
      if (canManage)
        Tab(icon: const Icon(Icons.assignment), text: context.l10n.expertDashboardTabApplications),
      Tab(icon: const Icon(Icons.schedule), text: context.l10n.expertDashboardTabTimeSlots),
      Tab(icon: const Icon(Icons.calendar_month), text: context.l10n.expertDashboardTabSchedule),
    ];

    final views = <Widget>[
      const StatsTab(),
      const ServicesTab(),
      if (canManage) const ApplicationsTab(),
      const TimeSlotsTab(),
      const ScheduleTab(),
    ];

    return BlocProvider(
      create: (context) => ExpertDashboardBloc(
        repository: context.read<TaskExpertRepository>(),
        expertId: expertId,
      )
        ..add(const ExpertDashboardLoadStats())
        ..add(const ExpertDashboardLoadMyServices())
        ..add(const ExpertDashboardLoadClosedDates()),
      child: BlocListener<ExpertDashboardBloc, ExpertDashboardState>(
        listenWhen: (prev, curr) =>
            (curr.errorMessage != null && prev.errorMessage != curr.errorMessage) ||
            (curr.actionMessage != null && prev.actionMessage != curr.actionMessage),
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.localizeError(state.errorMessage!))),
            );
          }
          if (state.actionMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.localizeError(state.actionMessage!))),
            );
          }
        },
        child: DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: _TeamTitle(state: cubitState),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: context.l10n.expertDashboardManagement,
                  onPressed: () {
                    context.push('/expert-dashboard/$expertId/management');
                  },
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabs: tabs,
              ),
            ),
            body: TabBarView(children: views),
          ),
        ),
      ),
    );
  }
}

class _TeamTitle extends StatelessWidget {
  const _TeamTitle({required this.state});
  final SelectedExpertState state;

  @override
  Widget build(BuildContext context) {
    // Phase B 会替换为可点击切换团队的版本
    return Text(state.currentTeam.name);
  }
}
