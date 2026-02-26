import 'package:go_router/go_router.dart';

import '../app_routes.dart';
import '../../../features/payment/views/stripe_connect_onboarding_view.dart';
import '../../../features/payment/views/stripe_connect_payments_view.dart';
import '../../../features/payment/views/stripe_connect_payouts_view.dart';

/// Stripe Connect 与支付相关路由
List<RouteBase> get paymentRoutes => [
      GoRoute(
        path: AppRoutes.stripeConnectOnboarding,
        name: 'stripeConnectOnboarding',
        builder: (context, state) => const StripeConnectOnboardingView(),
      ),
      GoRoute(
        path: AppRoutes.stripeConnectPayments,
        name: 'stripeConnectPayments',
        builder: (context, state) => const StripeConnectPaymentsView(),
      ),
      GoRoute(
        path: AppRoutes.stripeConnectPayouts,
        name: 'stripeConnectPayouts',
        builder: (context, state) => const StripeConnectPayoutsView(),
      ),
    ];
