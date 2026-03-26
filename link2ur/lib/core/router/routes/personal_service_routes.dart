import 'package:go_router/go_router.dart';

import '../../../features/personal_service/views/browse_services_view.dart';
import '../../../features/personal_service/views/my_service_applications_list_view.dart';
import '../../../features/personal_service/views/my_services_view.dart';
import '../../../features/personal_service/views/personal_service_form_view.dart';
import '../../../features/personal_service/views/received_applications_view.dart';
import '../../../features/personal_service/views/service_reviews_view.dart';

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
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>?;
          return PersonalServiceFormView(serviceData: data);
        },
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
      GoRoute(
        path: '/services/my/sent-applications',
        name: 'mySentServiceApplications',
        builder: (context, state) => const MyServiceApplicationsListView(),
      ),
      GoRoute(
        path: '/services/browse',
        name: 'browseServices',
        builder: (context, state) => const BrowseServicesView(),
      ),
      GoRoute(
        path: '/services/:serviceId/reviews',
        name: 'serviceReviews',
        builder: (context, state) {
          final serviceId = int.tryParse(state.pathParameters['serviceId'] ?? '') ?? 0;
          final extra = state.extra as Map<String, dynamic>?;
          final serviceName = extra?['serviceName'] as String?;
          return ServiceReviewsView(serviceId: serviceId, serviceName: serviceName);
        },
      ),
    ];
