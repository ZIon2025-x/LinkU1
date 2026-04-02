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
      // 板块：收藏优先
      final boards = allCategories
          .where((c) => c.skillType == null || c.skillType!.isEmpty)
          .toList()
        ..sort((a, b) {
          final aFav = a.isFavorited ? 0 : 1;
          final bFav = b.isFavorited ? 0 : 1;
          return aFav.compareTo(bFav);
        });
      final skillCats = allCategories
          .where((c) => c.skillType != null && c.skillType!.isNotEmpty)
          .toList()
        ..sort((a, b) => b.viewCount.compareTo(a.viewCount));

      // 榜单：收藏优先 > 同城优先
      final leaderboards = results[2] as List<Leaderboard>;
      final cityLower = (city != null && city.isNotEmpty) ? city.toLowerCase() : null;
      leaderboards.sort((a, b) {
        final aFav = a.isFavorited ? 0 : 1;
        final bFav = b.isFavorited ? 0 : 1;
        if (aFav != bFav) return aFav.compareTo(bFav);
        if (cityLower != null) {
          final aLocal = a.location.toLowerCase().contains(cityLower) ? 0 : 1;
          final bLocal = b.location.toLowerCase().contains(cityLower) ? 0 : 1;
          if (aLocal != bLocal) return aLocal.compareTo(bLocal);
        }
        return 0;
      });

      emit(state.copyWith(
        status: DiscoverStatus.loaded,
        trendingSearches: results[0] as List<TrendingSearchItem>,
        boards: boards.take(5).toList(),
        leaderboards: leaderboards.take(4).toList(),
        skillCategories: skillCats.take(6).toList(),
        experts: results[3] as List<TaskExpert>,
        activities: results[4] as List<Activity>,
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
      final response = await _leaderboardRepo.getLeaderboards(
        pageSize: 10, location: city,
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
}
