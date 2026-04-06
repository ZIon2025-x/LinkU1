import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/repositories/expert_team_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../bloc/expert_dashboard_bloc.dart';
import 'expert_dashboard_applications_tab.dart';
import 'expert_dashboard_services_tab.dart';
import 'expert_dashboard_stats_tab.dart';
import 'expert_dashboard_schedule_tab.dart';
import 'expert_dashboard_time_slots_tab.dart';

/// 达人工作台 — 5-tab shell
///
/// Two-phase widget:
/// 1. Fetch my-teams to resolve the user's expertId
/// 2. Once resolved, create ExpertDashboardBloc with expertId
class ExpertDashboardView extends StatefulWidget {
  const ExpertDashboardView({super.key});

  @override
  State<ExpertDashboardView> createState() => _ExpertDashboardViewState();
}

class _ExpertDashboardViewState extends State<ExpertDashboardView> {
  String? _expertId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchExpertId();
  }

  Future<void> _fetchExpertId() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final teams = await context.read<ExpertTeamRepository>().getMyTeams();
      if (teams.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'expert_dashboard_no_team';
        });
        return;
      }
      setState(() {
        _expertId = teams.first.id;
        _loading = false;
      });
    } catch (e) {
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
        appBar: AppBar(
          title: Text(context.l10n.expertDashboardTitle),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _expertId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.expertDashboardTitle),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.localizeError(_error ?? 'expert_dashboard_no_team')),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchExpertId,
                child: Text(context.l10n.commonRetry),
              ),
            ],
          ),
        ),
      );
    }

    return BlocProvider(
      create: (context) => ExpertDashboardBloc(
        repository: context.read<TaskExpertRepository>(),
        expertId: _expertId!,
      )
        ..add(const ExpertDashboardLoadStats())
        ..add(const ExpertDashboardLoadMyServices())
        ..add(const ExpertDashboardLoadClosedDates()),
      child: _ExpertDashboardContent(expertId: _expertId!),
    );
  }
}

class _ExpertDashboardContent extends StatelessWidget {
  const _ExpertDashboardContent({required this.expertId});

  final String expertId;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExpertDashboardBloc, ExpertDashboardState>(
      listenWhen: (prev, curr) =>
          (curr.errorMessage != null &&
              prev.errorMessage != curr.errorMessage) ||
          (curr.actionMessage != null &&
              prev.actionMessage != curr.actionMessage),
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(context.localizeError(state.errorMessage!))),
          );
        }
        if (state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(context.localizeError(state.actionMessage!))),
          );
        }
      },
      child: DefaultTabController(
        length: 5,
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.expertDashboardTitle),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: context.l10n.expertProfileEditTitle,
                onPressed: () => context.push(AppRoutes.expertProfileEdit),
              ),
            ],
            bottom: TabBar(
              isScrollable: true,
              tabs: [
                Tab(
                  icon: const Icon(Icons.dashboard),
                  text: context.l10n.expertDashboardTabStats,
                ),
                Tab(
                  icon: const Icon(Icons.design_services),
                  text: context.l10n.expertDashboardTabServices,
                ),
                Tab(
                  icon: const Icon(Icons.assignment),
                  text: context.l10n.expertDashboardTabApplications,
                ),
                Tab(
                  icon: const Icon(Icons.schedule),
                  text: context.l10n.expertDashboardTabTimeSlots,
                ),
                Tab(
                  icon: const Icon(Icons.calendar_month),
                  text: context.l10n.expertDashboardTabSchedule,
                ),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              const ExpertDashboardStatsTab(),
              const ExpertDashboardServicesTab(),
              ExpertDashboardApplicationsTab(expertId: expertId),
              const ExpertDashboardTimeSlotsTab(),
              const ExpertDashboardScheduleTab(),
            ],
          ),
        ),
      ),
    );
  }
}
