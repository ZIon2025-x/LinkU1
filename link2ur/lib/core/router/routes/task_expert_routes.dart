import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_routes.dart';
import '../page_transitions.dart';
import '../../../features/task_expert/views/task_expert_list_view.dart';
import '../../../features/task_expert/views/task_expert_search_view.dart';
import '../../../features/task_expert/views/task_experts_intro_view.dart';
import '../../../features/task_expert/views/task_expert_detail_view.dart';
import '../../../features/task_expert/views/service_detail_view.dart';
import '../../../features/task_expert/views/my_service_applications_view.dart';
import '../../../features/task_expert/views/expert_applications_management_view.dart';

/// 任务达人相关路由
List<RouteBase> get taskExpertRoutes => [
      GoRoute(
        path: AppRoutes.taskExperts,
        name: 'taskExperts',
        builder: (context, state) => const TaskExpertListView(),
      ),
      GoRoute(
        path: AppRoutes.taskExpertSearch,
        name: 'taskExpertSearch',
        builder: (context, state) => const TaskExpertSearchView(),
      ),
      GoRoute(
        path: AppRoutes.taskExpertsIntro,
        name: 'taskExpertsIntro',
        builder: (context, state) => const TaskExpertsIntroView(),
      ),
      GoRoute(
        path: AppRoutes.taskExpertDetail,
        name: 'taskExpertDetail',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return platformDetailPage(
            context,
            key: state.pageKey,
            child: TaskExpertDetailView(expertId: id),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.serviceDetail,
        name: 'serviceDetail',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null || id <= 0) {
            return const Scaffold(
                body: Center(child: Text('Invalid service ID')));
          }
          return ServiceDetailView(serviceId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.myServiceApplications,
        name: 'myServiceApplications',
        builder: (context, state) => const MyServiceApplicationsView(),
      ),
      GoRoute(
        path: AppRoutes.expertApplicationsManagement,
        name: 'expertApplicationsManagement',
        builder: (context, state) => const ExpertApplicationsManagementView(),
      ),
    ];
