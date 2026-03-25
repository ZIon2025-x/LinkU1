import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_routes.dart';
import '../page_transitions.dart';
import '../../../data/models/flea_market.dart';
import '../../../features/flea_market/views/flea_market_view.dart';
import '../../../features/flea_market/views/flea_market_detail_view.dart';
import '../../../features/flea_market/views/create_flea_market_item_view.dart';
import '../../../features/flea_market/views/edit_flea_market_item_view.dart';
import '../../../features/flea_market/views/rental_detail_view.dart';
import '../../../features/flea_market/views/my_rentals_view.dart';

/// 跳蚤市场相关路由
List<RouteBase> get fleaMarketRoutes => [
      GoRoute(
        path: AppRoutes.fleaMarket,
        name: 'fleaMarket',
        builder: (context, state) => const FleaMarketView(),
      ),
      GoRoute(
        path: AppRoutes.createFleaMarketItem,
        name: 'createFleaMarketItem',
        pageBuilder: (context, state) => SlideUpTransitionPage(
          key: state.pageKey,
          child: const CreateFleaMarketItemView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.editFleaMarketItem,
        name: 'editFleaMarketItem',
        redirect: (context, state) {
          final id = (state.pathParameters['id'] ?? '').trim();
          if (id.isEmpty) return AppRoutes.fleaMarket;
          final item = state.extra;
          if (item == null) return '/flea-market/$id';
          return null;
        },
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final item = state.extra;
          if (item is! FleaMarketItem) {
            return SlideUpTransitionPage(
              key: state.pageKey,
              child: const SizedBox.shrink(),
            );
          }
          return SlideUpTransitionPage(
            key: state.pageKey,
            child: EditFleaMarketItemView(itemId: id, item: item),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.fleaMarketMyRentals,
        name: 'fleaMarketMyRentals',
        builder: (context, state) => const MyRentalsView(),
      ),
      GoRoute(
        path: AppRoutes.fleaMarketRentalDetail,
        name: 'fleaMarketRentalDetail',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return platformDetailPage(
            context,
            key: state.pageKey,
            child: RentalDetailView(rentalId: id),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.fleaMarketDetail,
        name: 'fleaMarketDetail',
        redirect: (context, state) {
          final idParam = (state.pathParameters['id'] ?? '').trim();
          if (idParam.isEmpty) return AppRoutes.fleaMarket;
          return null;
        },
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return platformDetailPage(
            context,
            key: state.pageKey,
            child: FleaMarketDetailView(itemId: id),
          );
        },
      ),
    ];
