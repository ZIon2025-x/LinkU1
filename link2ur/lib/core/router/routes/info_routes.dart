import 'package:go_router/go_router.dart';

import '../app_routes.dart';
import '../../../features/coupon_points/views/coupon_points_view.dart';
import '../../../features/info/views/info_views.dart';
import '../../../features/info/views/vip_purchase_view.dart';
import '../../../features/info/views/vip_view.dart';
import '../../../features/search/views/search_view.dart';

/// 信息与设置类页面路由（优惠券、FAQ、条款、VIP、搜索等）
List<RouteBase> get infoRoutes => [
      GoRoute(
        path: AppRoutes.couponPoints,
        name: 'couponPoints',
        builder: (context, state) => const CouponPointsView(),
      ),
      GoRoute(
        path: AppRoutes.faq,
        name: 'faq',
        builder: (context, state) => const FAQView(),
      ),
      GoRoute(
        path: AppRoutes.terms,
        name: 'terms',
        builder: (context, state) => const TermsView(),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        name: 'privacy',
        builder: (context, state) => const PrivacyView(),
      ),
      GoRoute(
        path: AppRoutes.about,
        name: 'about',
        builder: (context, state) => const AboutView(),
      ),
      GoRoute(
        path: AppRoutes.vip,
        name: 'vip',
        builder: (context, state) => const VipView(),
      ),
      GoRoute(
        path: AppRoutes.vipPurchase,
        name: 'vipPurchase',
        builder: (context, state) => const VIPPurchaseView(),
      ),
      GoRoute(
        path: AppRoutes.search,
        name: 'search',
        builder: (context, state) => const SearchView(),
      ),
    ];
