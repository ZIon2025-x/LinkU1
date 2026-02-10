import 'package:equatable/equatable.dart';

import '../../../data/models/task.dart';
import '../../../data/models/forum.dart';
import '../../../data/models/flea_market.dart';
import '../../../data/models/leaderboard.dart';

/// 首页状态
enum HomeStatus { initial, loading, loaded, error }

/// 最新动态项（对标 iOS RecentActivity）
///
/// 聚合三种数据源：论坛帖子、跳蚤市场商品、排行榜
class RecentActivityItem extends Equatable {
  const RecentActivityItem({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    required this.userName,
    this.userAvatar,
    this.categoryName,
    this.categoryId,
    this.replyCount = 0,
    this.viewCount = 0,
    this.createdAt,
    this.itemId, // 原始数据ID（用于跳转导航）
  });

  /// 唯一标识（带类型前缀，如 "forum_123", "flea_456"）
  final String id;

  /// 动态类型：forum_post, flea_market_item, leaderboard_created
  final String type;
  final String title;
  final String? description;
  final String userName;
  final String? userAvatar;
  final String? categoryName;
  final int? categoryId;
  final int replyCount;
  final int viewCount;
  final DateTime? createdAt;

  /// 原始数据 ID（int 或 String，用于导航跳转）
  final String? itemId;

  // ==================== 类型常量（对标 iOS ActivityType） ====================

  static const String typeForumPost = 'forum_post';
  static const String typeFleaMarketItem = 'flea_market_item';
  static const String typeLeaderboardCreated = 'leaderboard_created';

  // ==================== 工厂构造 ====================

  /// 从论坛帖子创建（对标 iOS RecentActivity.init(forumPost:)）
  factory RecentActivityItem.fromForumPost(ForumPost post) {
    return RecentActivityItem(
      id: 'forum_${post.id}',
      type: typeForumPost,
      title: post.title,
      description: post.displayContent,
      userName: post.author?.name ?? '',
      userAvatar: post.author?.avatar,
      categoryName: post.category?.displayName,
      categoryId: post.categoryId,
      replyCount: post.replyCount,
      viewCount: post.viewCount,
      createdAt: post.createdAt,
      itemId: post.id.toString(),
    );
  }

  /// 从跳蚤市场商品创建（对标 iOS RecentActivity.init(fleaMarketItem:)）
  factory RecentActivityItem.fromFleaMarketItem(FleaMarketItem item) {
    return RecentActivityItem(
      id: 'flea_${item.id}',
      type: typeFleaMarketItem,
      title: item.title,
      description: item.description,
      userName: '', // FleaMarketItem 只有 sellerId，无 seller 名称
      categoryName: item.category,
      viewCount: item.viewCount,
      createdAt: item.createdAt,
      itemId: item.id,
    );
  }

  /// 从排行榜创建（对标 iOS RecentActivity.init(leaderboard:)）
  factory RecentActivityItem.fromLeaderboard(Leaderboard leaderboard) {
    return RecentActivityItem(
      id: 'leaderboard_${leaderboard.id}',
      type: typeLeaderboardCreated,
      title: leaderboard.displayName,
      description: leaderboard.displayDescription,
      userName: leaderboard.applicant?.name ?? '',
      userAvatar: leaderboard.applicant?.avatar,
      viewCount: leaderboard.viewCount,
      createdAt: leaderboard.createdAt,
      itemId: leaderboard.id.toString(),
    );
  }

  @override
  List<Object?> get props => [id, type, title, createdAt];
}

class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.initial,
    this.recommendedTasks = const [],
    this.nearbyTasks = const [],
    this.currentTab = 0,
    this.hasMoreRecommended = true,
    this.hasMoreNearby = true,
    this.recommendedPage = 1,
    this.nearbyPage = 1,
    this.errorMessage,
    this.isRefreshing = false,
    this.refreshError,
    this.recentActivities = const [],
    this.isLoadingActivities = false,
  });

  final HomeStatus status;
  final List<Task> recommendedTasks;
  final List<Task> nearbyTasks;
  final int currentTab;
  final bool hasMoreRecommended;
  final bool hasMoreNearby;
  final int recommendedPage;
  final int nearbyPage;
  final String? errorMessage;
  final bool isRefreshing;
  /// 刷新失败错误信息，用于 UI 层通过 BlocListener 显示 Toast
  final String? refreshError;
  final List<RecentActivityItem> recentActivities;
  final bool isLoadingActivities;

  bool get isLoading => status == HomeStatus.loading;
  bool get isLoaded => status == HomeStatus.loaded;
  bool get hasError => status == HomeStatus.error;

  HomeState copyWith({
    HomeStatus? status,
    List<Task>? recommendedTasks,
    List<Task>? nearbyTasks,
    int? currentTab,
    bool? hasMoreRecommended,
    bool? hasMoreNearby,
    int? recommendedPage,
    int? nearbyPage,
    String? errorMessage,
    bool? isRefreshing,
    String? refreshError,
    bool clearRefreshError = false,
    List<RecentActivityItem>? recentActivities,
    bool? isLoadingActivities,
  }) {
    return HomeState(
      status: status ?? this.status,
      recommendedTasks: recommendedTasks ?? this.recommendedTasks,
      nearbyTasks: nearbyTasks ?? this.nearbyTasks,
      currentTab: currentTab ?? this.currentTab,
      hasMoreRecommended: hasMoreRecommended ?? this.hasMoreRecommended,
      hasMoreNearby: hasMoreNearby ?? this.hasMoreNearby,
      recommendedPage: recommendedPage ?? this.recommendedPage,
      nearbyPage: nearbyPage ?? this.nearbyPage,
      errorMessage: errorMessage ?? this.errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      refreshError: clearRefreshError ? null : (refreshError ?? this.refreshError),
      recentActivities: recentActivities ?? this.recentActivities,
      isLoadingActivities: isLoadingActivities ?? this.isLoadingActivities,
    );
  }

  @override
  List<Object?> get props => [
        status,
        recommendedTasks,
        nearbyTasks,
        currentTab,
        hasMoreRecommended,
        hasMoreNearby,
        recommendedPage,
        nearbyPage,
        errorMessage,
        isRefreshing,
        refreshError,
        recentActivities,
        isLoadingActivities,
      ];
}
