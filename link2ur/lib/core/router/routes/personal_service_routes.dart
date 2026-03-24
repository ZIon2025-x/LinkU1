import 'package:go_router/go_router.dart';

import '../../../features/personal_service/views/my_services_view.dart';
import '../../../features/personal_service/views/personal_service_form_view.dart';
import '../../../features/personal_service/views/received_applications_view.dart';

/// 个人服务相关路由
List<RouteBase> get personalServiceRoutes => [
      GoRoute(
        path: '/services/my',
        name: 'myServices',
        builder: (context, state) => const MyServicesView(),
      ),
      GoRoute(
        path: '/services/create',
        name: 'createService',
        builder: (context, state) => const PersonalServiceFormView(),
      ),
      GoRoute(
        path: '/services/edit/:id',
        name: 'editService',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>?;
          return PersonalServiceFormView(serviceData: data);
        },
      ),
      GoRoute(
        path: '/services/my/applications',
        name: 'myReceivedServiceApplications',
        builder: (context, state) => const ReceivedApplicationsView(),
      ),
    ];
