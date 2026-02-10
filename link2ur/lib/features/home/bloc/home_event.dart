import 'package:equatable/equatable.dart';

/// 首页事件
abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

/// 加载首页数据
class HomeLoadRequested extends HomeEvent {
  const HomeLoadRequested();
}

/// 刷新首页数据
class HomeRefreshRequested extends HomeEvent {
  const HomeRefreshRequested();
}

/// 加载推荐任务
class HomeLoadRecommended extends HomeEvent {
  const HomeLoadRecommended({this.loadMore = false});

  final bool loadMore;

  @override
  List<Object?> get props => [loadMore];
}

/// 加载附近任务
class HomeLoadNearby extends HomeEvent {
  const HomeLoadNearby({
    required this.latitude,
    required this.longitude,
    this.loadMore = false,
  });

  final double latitude;
  final double longitude;
  final bool loadMore;

  @override
  List<Object?> get props => [latitude, longitude, loadMore];
}

/// 切换Tab
class HomeTabChanged extends HomeEvent {
  const HomeTabChanged(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

/// 加载最新动态（论坛帖子，按权限过滤）
class HomeLoadRecentActivities extends HomeEvent {
  const HomeLoadRecentActivities();
}
