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
    this.radius,
  });

  final double latitude;
  final double longitude;
  final bool loadMore;

  /// 反向地理编码得到的城市名（如 "Birmingham"），用于后端同城过滤
  final String? city;

  /// 搜索半径（km）
  final int? radius;

  @override
  List<Object?> get props => [latitude, longitude, loadMore, city, radius];
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

/// 加载关注 Feed
class HomeLoadFollowFeed extends HomeEvent {
  const HomeLoadFollowFeed({this.loadMore = false});
  final bool loadMore;
  @override
  List<Object?> get props => [loadMore];
}

/// 加载动态 Ticker
class HomeLoadTicker extends HomeEvent {
  const HomeLoadTicker();
}

/// 加载活动列表（活动 Tab）
class HomeLoadActivitiesList extends HomeEvent {
  const HomeLoadActivitiesList({this.loadMore = false});
  final bool loadMore;
  @override
  List<Object?> get props => [loadMore];
}

/// GPS 反向地理编码得到的城市名
class HomeLocationCityUpdated extends HomeEvent {
  const HomeLocationCityUpdated(this.city);
  final String city;
  @override
  List<Object?> get props => [city];
}

/// 加载附近个人服务
class HomeLoadNearbyServices extends HomeEvent {
  const HomeLoadNearbyServices({
    required this.latitude,
    required this.longitude,
    this.radius = 5,
  });
  final double latitude;
  final double longitude;
  final int radius;
  @override
  List<Object?> get props => [latitude, longitude, radius];
}

/// 切换附近服务搜索半径
class HomeChangeNearbyRadius extends HomeEvent {
  const HomeChangeNearbyRadius(this.radius);
  final int radius;
  @override
  List<Object?> get props => [radius];
}
