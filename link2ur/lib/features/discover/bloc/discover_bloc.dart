import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:link2ur/core/utils/logger.dart';
import 'package:link2ur/data/models/activity.dart';
import 'package:link2ur/data/models/forum.dart';
import 'package:link2ur/data/models/leaderboard.dart';
import 'package:link2ur/data/models/task_expert.dart';
import 'package:link2ur/data/models/trending_search.dart';
import 'package:link2ur/data/repositories/activity_repository.dart';
import 'package:link2ur/data/repositories/follow_repository.dart';
import 'package:link2ur/data/repositories/forum_repository.dart';
import 'package:link2ur/data/repositories/leaderboard_repository.dart';
import 'package:link2ur/data/repositories/task_expert_repository.dart';
import 'package:link2ur/data/repositories/trending_search_repository.dart';
import 'package:link2ur/data/services/storage_service.dart';

part 'discover_event.dart';
part 'discover_state.dart';

class DiscoverBloc extends Bloc<DiscoverEvent, DiscoverState> {
  DiscoverBloc({
    required TrendingSearchRepository trendingSearchRepository,
    required ForumRepository forumRepository,
    required LeaderboardRepository leaderboardRepository,
    required TaskExpertRepository taskExpertRepository,
    required ActivityRepository activityRepository,
    required FollowRepository followRepository,
  })  : _trendingRepo = trendingSearchRepository,
        _forumRepo = forumRepository,
        _leaderboardRepo = leaderboardRepository,
        _expertRepo = taskExpertRepository,
        _activityRepo = activityRepository,
        _followRepo = followRepository,
        super(const DiscoverState()) {
    on<DiscoverLoadRequested>(_onLoad);
    on<DiscoverRefreshRequested>(_onRefresh);
    on<DiscoverToggleFollowExpert>(_onToggleFollow);
  }

  final TrendingSearchRepository _trendingRepo;
  final ForumRepository _forumRepo;
  final LeaderboardRepository _leaderboardRepo;
  final TaskExpertRepository _expertRepo;
  final ActivityRepository _activityRepo;
  final FollowRepository _followRepo;

  Future<void> _onLoad(DiscoverLoadRequested event, Emitter<DiscoverState> emit) async {
    if (state.status == DiscoverStatus.loading) return;
    emit(state.copyWith(status: DiscoverStatus.loading));

    final userInfo = StorageService.instance.getUserInfo();
    final city = userInfo?['residence_city'] as String?;

    await _loadAll(emit, city);
  }

  Future<void> _onRefresh(DiscoverRefreshRequested event, Emitter<DiscoverState> emit) async {
    if (state.status == DiscoverStatus.loading) return;
    final userInfo = StorageService.instance.getUserInfo();
    final city = userInfo?['residence_city'] as String?;
    await _loadAll(emit, city);
  }

  Future<void> _loadAll(Emitter<DiscoverState> emit, String? city) async {
    try {
      final results = await Future.wait([
        _loadTrending(),         // 0
        _loadCategories(),       // 1
        _loadLeaderboards(city), // 2
        _loadExperts(city),      // 3
        _loadActivities(city),   // 4
      ]);

      final allCategories = results[1] as List<ForumCategory>;
      final leaderboards = results[2] as List<Leaderboard>;

      // 批量查询收藏状态
      final catIds = allCategories.map((c) => c.id).toList();
      final lbIds = leaderboards.map((lb) => lb.id).toList();
      final favResults = await Future.wait<Map<int, bool>>([
        catIds.isNotEmpty ? _forumRepo.getCategoryFavoritesBatch(catIds) : Future.value({}),
        lbIds.isNotEmpty ? _leaderboardRepo.getFavoritesBatch(lbIds) : Future.value({}),
      ]);
      final catFavMap = favResults[0];
      final lbFavMap = favResults[1];

      // 合并收藏状态到分类
      final categoriesWithFav = allCategories.map((c) {
        final fav = catFavMap[c.id] ?? false;
        return fav ? c.copyWith(isFavorited: true) : c;
      }).toList();

      // 板块：收藏优先
      final boards = categoriesWithFav
          .where((c) => c.skillType == null || c.skillType!.isEmpty)
          .toList()
        ..sort((a, b) {
          final aFav = a.isFavorited ? 0 : 1;
          final bFav = b.isFavorited ? 0 : 1;
          return aFav.compareTo(bFav);
        });
      final skillCats = categoriesWithFav
          .where((c) => c.skillType != null && c.skillType!.isNotEmpty)
          .toList()
        ..sort((a, b) => b.viewCount.compareTo(a.viewCount));

      // 合并收藏状态到榜单
      final leaderboardsWithFav = leaderboards.map((lb) {
        final fav = lbFavMap[lb.id] ?? false;
        return fav ? lb.copyWith(isFavorited: true) : lb;
      }).toList();

      // 榜单：收藏优先 > 同城优先
      final cityVariants = _getCityVariants(city);
      leaderboardsWithFav.sort((a, b) {
        final aFav = a.isFavorited ? 0 : 1;
        final bFav = b.isFavorited ? 0 : 1;
        if (aFav != bFav) return aFav.compareTo(bFav);
        if (cityVariants.isNotEmpty) {
          final locA = a.location.toLowerCase();
          final locB = b.location.toLowerCase();
          final aLocal = cityVariants.any((v) => locA.contains(v)) ? 0 : 1;
          final bLocal = cityVariants.any((v) => locB.contains(v)) ? 0 : 1;
          if (aLocal != bLocal) return aLocal.compareTo(bLocal);
        }
        return 0;
      });

      final experts = results[3] as List<TaskExpert>;
      // 从后端返回的 is_following 初始化关注状态
      final followedIds = experts
          .where((e) => e.isFollowing)
          .map((e) => e.id)
          .toSet();

      emit(state.copyWith(
        status: DiscoverStatus.loaded,
        trendingSearches: results[0] as List<TrendingSearchItem>,
        boards: boards.take(5).toList(),
        leaderboards: leaderboardsWithFav.take(4).toList(),
        skillCategories: skillCats.take(6).toList(),
        experts: experts,
        activities: results[4] as List<Activity>,
        followedExpertIds: followedIds,
        userCity: city,
      ));
    } catch (e) {
      AppLogger.error('Discover load failed', e);
      emit(state.copyWith(
        status: DiscoverStatus.error,
        errorMessage: 'discover_load_failed',
      ));
    }
  }

  Future<List<TrendingSearchItem>> _loadTrending() async {
    try {
      final response = await _trendingRepo.getTrendingSearches();
      return response.items;
    } catch (e) {
      AppLogger.error('Trending load failed', e);
      return [];
    }
  }

  Future<List<ForumCategory>> _loadCategories() async {
    try {
      return await _forumRepo.getVisibleCategories();
    } catch (e) {
      AppLogger.error('Categories load failed', e);
      return [];
    }
  }

  Future<List<Leaderboard>> _loadLeaderboards(String? city) async {
    try {
      // 不传 location，获取所有榜单；同城排序由前端 _getCityVariants 处理
      final response = await _leaderboardRepo.getLeaderboards(
        pageSize: 10,
      );
      return response.leaderboards;
    } catch (e) {
      AppLogger.error('Leaderboards load failed', e);
      return [];
    }
  }

  Future<List<TaskExpert>> _loadExperts(String? city) async {
    try {
      final response = await _expertRepo.getExperts(
        pageSize: 3, location: city, sort: 'random',
      );
      return response.experts;
    } catch (e) {
      AppLogger.error('Experts load failed', e);
      return [];
    }
  }

  Future<List<Activity>> _loadActivities(String? city) async {
    try {
      final response = await _activityRepo.getActivities(
        pageSize: 3, location: city, sortBy: 'view_count', status: 'open',
      );
      return response.activities;
    } catch (e) {
      AppLogger.error('Activities load failed', e);
      return [];
    }
  }

  Future<void> _onToggleFollow(DiscoverToggleFollowExpert event, Emitter<DiscoverState> emit) async {
    final id = event.expertId;
    final wasFollowing = state.followedExpertIds.contains(id);

    // Optimistic update
    final newIds = Set<String>.from(state.followedExpertIds);
    if (wasFollowing) {
      newIds.remove(id);
    } else {
      newIds.add(id);
    }
    emit(state.copyWith(followedExpertIds: newIds));

    try {
      if (wasFollowing) {
        await _followRepo.unfollowUser(id);
      } else {
        await _followRepo.followUser(id);
      }
    } catch (e) {
      // Revert on failure
      final revertIds = Set<String>.from(state.followedExpertIds);
      if (wasFollowing) {
        revertIds.add(id);
      } else {
        revertIds.remove(id);
      }
      emit(state.copyWith(followedExpertIds: revertIds));
      AppLogger.error('Follow toggle failed', e);
    }
  }

  /// 获取城市名的中英文变体（小写），用于本地排序匹配
  static List<String> _getCityVariants(String? city) {
    if (city == null || city.isEmpty) return [];
    const mapping = {
      'london': '伦敦', 'edinburgh': '爱丁堡', 'manchester': '曼彻斯特',
      'birmingham': '伯明翰', 'glasgow': '格拉斯哥', 'bristol': '布里斯托',
      'sheffield': '谢菲尔德', 'leeds': '利兹', 'nottingham': '诺丁汉',
      'newcastle': '纽卡斯尔', 'southampton': '南安普顿', 'liverpool': '利物浦',
      'cardiff': '卡迪夫', 'coventry': '考文垂', 'leicester': '莱斯特',
      'york': '约克', 'aberdeen': '阿伯丁', 'bath': '巴斯',
      'cambridge': '剑桥', 'oxford': '牛津', 'brighton': '布莱顿',
      'reading': '雷丁', 'belfast': '贝尔法斯特',
    };
    const reverseMapping = {
      '伦敦': 'london', '爱丁堡': 'edinburgh', '曼彻斯特': 'manchester',
      '伯明翰': 'birmingham', '格拉斯哥': 'glasgow', '布里斯托': 'bristol',
      '谢菲尔德': 'sheffield', '利兹': 'leeds', '诺丁汉': 'nottingham',
      '纽卡斯尔': 'newcastle', '南安普顿': 'southampton', '利物浦': 'liverpool',
      '卡迪夫': 'cardiff', '考文垂': 'coventry', '莱斯特': 'leicester',
      '约克': 'york', '阿伯丁': 'aberdeen', '巴斯': 'bath',
      '剑桥': 'cambridge', '牛津': 'oxford', '布莱顿': 'brighton',
      '雷丁': 'reading', '贝尔法斯特': 'belfast',
    };
    final lower = city.toLowerCase().trim();
    final variants = <String>{lower};
    if (mapping.containsKey(lower)) variants.add(mapping[lower]!);
    if (reverseMapping.containsKey(city.trim())) variants.add(reverseMapping[city.trim()]!);
    return variants.toList();
  }
}
