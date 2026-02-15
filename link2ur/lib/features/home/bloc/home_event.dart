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
    this.city,
  });

  final double latitude;
  final double longitude;
  final bool loadMore;

  /// 反向地理编码得到的城市名（如 "Birmingham"），用于后端同城过滤
  final String? city;

  @override
  List<Object?> get props => [latitude, longitude, loadMore, city];
}

/// 切换Tab
class HomeTabChanged extends HomeEvent {
  const HomeTabChanged(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

/// 加载发现 Feed
class HomeLoadDiscoveryFeed extends HomeEvent {
  const HomeLoadDiscoveryFeed();
}

/// 加载更多发现 Feed
class HomeLoadMoreDiscovery extends HomeEvent {
  const HomeLoadMoreDiscovery();
}

/// 更新推荐任务筛选/排序
class HomeRecommendedFilterChanged extends HomeEvent {
  const HomeRecommendedFilterChanged({
    this.category,
    this.sortBy,
    this.clearCategory = false,
  });

  /// 筛选类别（null + clearCategory=false 表示不变，clearCategory=true 表示清除）
  final String? category;
  /// 排序方式
  final String? sortBy;
  /// 是否清除类别筛选
  final bool clearCategory;

  @override
  List<Object?> get props => [category, sortBy, clearCategory];
}
