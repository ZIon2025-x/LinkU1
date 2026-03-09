import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../bloc/expert_dashboard_bloc.dart';
import 'expert_dashboard_applications_tab.dart';
import 'expert_dashboard_services_tab.dart';
import 'expert_dashboard_stats_tab.dart';
import 'expert_dashboard_schedule_tab.dart';
import 'expert_dashboard_time_slots_tab.dart';

/// 达人工作台 — 5-tab shell
class ExpertDashboardView extends StatelessWidget {
  const ExpertDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ExpertDashboardBloc(
        repository: context.read<TaskExpertRepository>(),
      )
        ..add(const ExpertDashboardLoadStats())
        ..add(const ExpertDashboardLoadMyServices())
        ..add(const ExpertDashboardLoadClosedDates()),
      child: const _ExpertDashboardContent(),
    );
  }
}

class _ExpertDashboardContent extends StatelessWidget {
  const _ExpertDashboardContent();

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
          body: const TabBarView(
            children: [
              ExpertDashboardStatsTab(),
              ExpertDashboardServicesTab(),
              ExpertDashboardApplicationsTab(),
              ExpertDashboardTimeSlotsTab(),
              ExpertDashboardScheduleTab(),
            ],
          ),
        ),
      ),
    );
  }
}
