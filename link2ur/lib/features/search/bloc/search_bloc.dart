import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/repositories/flea_market_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../../../data/services/storage_service.dart';
import '../../../core/utils/logger.dart';

// ==================== Events ====================

abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

/// 执行搜索
class SearchSubmitted extends SearchEvent {
  const SearchSubmitted(this.query, [this.locale]);

  final String query;
  /// 用于任务/活动标题展示语言
  final Locale? locale;

  @override
  List<Object?> get props => [query, locale];
}

/// 清除搜索
class SearchCleared extends SearchEvent {
  const SearchCleared();
}

/// 加载最近搜索记录
class LoadRecentSearches extends SearchEvent {
  const LoadRecentSearches();
}

/// 清除搜索记录（历史）
class SearchHistoryCleared extends SearchEvent {
  const SearchHistoryCleared();
}

// ==================== State ====================

enum SearchStatus { initial, loading, loaded, error }

class SearchState extends Equatable {
  const SearchState({
    this.status = SearchStatus.initial,
    this.query = '',
    this.taskResults = const [],
    this.forumResults = const [],
    this.fleaMarketResults = const [],
    this.expertResults = const [],
    this.activityResults = const [],
    this.leaderboardResults = const [],
    this.leaderboardItemResults = const [],
    this.forumCategoryResults = const [],
    this.recentSearches = const [],
    this.errorMessage,
  });

  final SearchStatus status;
  final String query;
  final List<Map<String, dynamic>> taskResults;
  final List<Map<String, dynamic>> forumResults;
  final List<Map<String, dynamic>> fleaMarketResults;
  final List<Map<String, dynamic>> expertResults;
  final List<Map<String, dynamic>> activityResults;
  final List<Map<String, dynamic>> leaderboardResults;
  final List<Map<String, dynamic>> leaderboardItemResults;
  final List<Map<String, dynamic>> forumCategoryResults;
  /// 最近搜索关键词列表（从 StorageService 加载）
  final List<String> recentSearches;
  final String? errorMessage;

  bool get isLoading => status == SearchStatus.loading;
  bool get hasResults =>
      taskResults.isNotEmpty ||
      forumResults.isNotEmpty ||
      fleaMarketResults.isNotEmpty ||
      expertResults.isNotEmpty ||
      activityResults.isNotEmpty ||
      leaderboardResults.isNotEmpty ||
      leaderboardItemResults.isNotEmpty ||
      forumCategoryResults.isNotEmpty;
  int get totalResults =>
      taskResults.length +
      forumResults.length +
      fleaMarketResults.length +
      expertResults.length +
      activityResults.length +
      leaderboardResults.length +
      leaderboardItemResults.length +
      forumCategoryResults.length;

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    List<Map<String, dynamic>>? taskResults,
    List<Map<String, dynamic>>? forumResults,
    List<Map<String, dynamic>>? fleaMarketResults,
    List<Map<String, dynamic>>? expertResults,
    List<Map<String, dynamic>>? activityResults,
    List<Map<String, dynamic>>? leaderboardResults,
    List<Map<String, dynamic>>? leaderboardItemResults,
    List<Map<String, dynamic>>? forumCategoryResults,
    List<String>? recentSearches,
    String? errorMessage,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      taskResults: taskResults ?? this.taskResults,
      forumResults: forumResults ?? this.forumResults,
      fleaMarketResults: fleaMarketResults ?? this.fleaMarketResults,
      expertResults: expertResults ?? this.expertResults,
      activityResults: activityResults ?? this.activityResults,
      leaderboardResults: leaderboardResults ?? this.leaderboardResults,
      leaderboardItemResults: leaderboardItemResults ?? this.leaderboardItemResults,
      forumCategoryResults: forumCategoryResults ?? this.forumCategoryResults,
      recentSearches: recentSearches ?? this.recentSearches,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        query,
        taskResults,
        forumResults,
        fleaMarketResults,
        expertResults,
        activityResults,
        leaderboardResults,
        leaderboardItemResults,
        forumCategoryResults,
        recentSearches,
        errorMessage,
      ];
}

// ==================== Bloc ====================

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc({
    required TaskRepository taskRepository,
    required ForumRepository forumRepository,
    required FleaMarketRepository fleaMarketRepository,
    required TaskExpertRepository taskExpertRepository,
    required ActivityRepository activityRepository,
    required LeaderboardRepository leaderboardRepository,
  })  : _taskRepository = taskRepository,
        _forumRepository = forumRepository,
        _fleaMarketRepository = fleaMarketRepository,
        _taskExpertRepository = taskExpertRepository,
        _activityRepository = activityRepository,
        _leaderboardRepository = leaderboardRepository,
        super(const SearchState()) {
    on<SearchSubmitted>(_onSubmitted);
    on<SearchCleared>(_onCleared);
    on<LoadRecentSearches>(_onLoadRecentSearches);
    on<SearchHistoryCleared>(_onSearchHistoryCleared);
  }

  final TaskRepository _taskRepository;
  final ForumRepository _forumRepository;
  final FleaMarketRepository _fleaMarketRepository;
  final TaskExpertRepository _taskExpertRepository;
  final ActivityRepository _activityRepository;
  final LeaderboardRepository _leaderboardRepository;

  Future<void> _onSubmitted(
    SearchSubmitted event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty) return;

    emit(state.copyWith(
      status: SearchStatus.loading,
      query: query,
    ));

    try {
      // 并行搜索八个模块（含排行榜竞品、论坛板块）
      final locale = event.locale;
      final results = await Future.wait([
        _searchTasks(query, locale),
        _searchForum(query, locale),
        _searchFleaMarket(query),
        _searchExperts(query),
        _searchActivities(query, locale),
        _searchLeaderboards(query, locale),
        _searchLeaderboardItems(query, locale),
        _searchForumCategories(query, locale),
      ]);

      emit(state.copyWith(
        status: SearchStatus.loaded,
        taskResults: results[0],
        forumResults: results[1],
        fleaMarketResults: results[2],
        expertResults: results[3],
        activityResults: results[4],
        leaderboardResults: results[5],
        leaderboardItemResults: results[6],
        forumCategoryResults: results[7],
      ));
      // 写入最近搜索记录
      await StorageService.instance.addSearchHistory(query);
      emit(state.copyWith(
        recentSearches: StorageService.instance.getSearchHistory(),
      ));
    } catch (e) {
      AppLogger.error('Search failed', e);
      emit(state.copyWith(
        status: SearchStatus.error,
        errorMessage: 'search_error_failed',
      ));
    }
  }

  Future<void> _onCleared(
    SearchCleared event,
    Emitter<SearchState> emit,
  ) async {
    emit(state.copyWith(
      status: SearchStatus.initial,
      query: '',
      taskResults: [],
      forumResults: [],
      fleaMarketResults: [],
      expertResults: [],
      activityResults: [],
      leaderboardResults: [],
      leaderboardItemResults: [],
      forumCategoryResults: [],
    ));
  }

  Future<void> _onLoadRecentSearches(
    LoadRecentSearches event,
    Emitter<SearchState> emit,
  ) async {
    final recent = StorageService.instance.getSearchHistory();
    emit(state.copyWith(recentSearches: recent));
  }

  Future<void> _onSearchHistoryCleared(
    SearchHistoryCleared event,
    Emitter<SearchState> emit,
  ) async {
    await StorageService.instance.clearSearchHistory();
    emit(state.copyWith(recentSearches: const []));
  }

  Future<List<Map<String, dynamic>>> _searchTasks(String query, Locale? locale) async {
    try {
      final response = await _taskRepository.getTasks(
        keyword: query,
        pageSize: 10,
      );
      return response.tasks
          .map((t) => {
                'id': t.id,
                'title': locale != null
                    ? t.displayTitle(locale)
                    : (t.titleZh ?? t.titleEn ?? t.title),
                'type': 'task',
                'description': locale != null
                    ? (t.displayDescription(locale) ?? '')
                    : (t.descriptionZh ?? t.descriptionEn ?? ''),
                'status': t.status,
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchForum(
      String query, Locale? locale) async {
    try {
      final response = await _forumRepository.searchPosts(
        keyword: query,
        pageSize: 10,
      );
      return response.posts
          .map((p) => {
                'id': p.id,
                'title': locale != null
                    ? p.displayTitle(locale)
                    : p.title,
                'type': 'forum',
                'description': locale != null
                    ? (p.displayContent(locale) ?? '')
                    : (p.content ?? ''),
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchFleaMarket(String query) async {
    try {
      final response = await _fleaMarketRepository.getItems(
        keyword: query,
        pageSize: 10,
      );
      return response.items
          .map((item) => {
                'id': item.id,
                'title': item.title,
                'type': 'flea_market',
                'description': item.description ?? '',
                'price': item.priceDisplay,
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchExperts(String query) async {
    try {
      final experts = await _taskExpertRepository.searchExperts(
        keyword: query,
        pageSize: 10,
      );
      return experts
          .map((e) => {
                'id': e.id,
                'title': e.expertName ?? e.displayName,
                'type': 'expert',
                'description': e.bio ?? e.bioZh ?? e.bioEn ?? '',
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchActivities(String query, Locale? locale) async {
    try {
      final response = await _activityRepository.getActivities(
        keyword: query,
        pageSize: 10,
      );
      return response.activities
          .map((a) => {
                'id': a.id,
                'title': locale != null
                    ? a.displayTitle(locale)
                    : a.title,
                'type': 'activity',
                'description': locale != null
                    ? a.displayDescription(locale)
                    : a.description,
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchLeaderboards(
      String query, Locale? locale) async {
    try {
      final response = await _leaderboardRepository.getLeaderboards(
        keyword: query,
        pageSize: 10,
      );
      return response.leaderboards
          .map((lb) => {
                'id': lb.id,
                'title': locale != null
                    ? lb.displayName(locale)
                    : lb.name,
                'type': 'leaderboard',
                'description': locale != null
                    ? (lb.displayDescription(locale) ?? lb.location)
                    : (lb.description ?? lb.location),
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 搜索排行榜竞品（在各榜单内按名称/描述搜，聚合后最多 10 条）
  Future<List<Map<String, dynamic>>> _searchLeaderboardItems(
      String query, Locale? locale) async {
    try {
      final response = await _leaderboardRepository.getLeaderboards(
        pageSize: 10,
      );
      final List<Map<String, dynamic>> out = [];
      for (final lb in response.leaderboards) {
        if (out.length >= 10) break;
        final items = await _leaderboardRepository.getLeaderboardItems(
          lb.id,
          keyword: query,
          pageSize: 3,
        );
        for (final item in items) {
          if (out.length >= 10) break;
          out.add({
            'id': item.id,
            'title': item.name,
            'type': 'leaderboard_item',
            'description': item.description ?? '',
            'leaderboard_id': lb.id,
            'leaderboard_name': locale != null
                ? lb.displayName(locale)
                : lb.name,
          });
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /// 搜索论坛板块（拉取可见板块后按名称/描述客户端过滤）
  Future<List<Map<String, dynamic>>> _searchForumCategories(
      String query, Locale? locale) async {
    try {
      final categories = await _forumRepository.getVisibleCategories();
      final lower = query.toLowerCase();
      return categories
          .where((c) {
            final name = (c.nameZh ?? c.name).toLowerCase();
            final nameEn = (c.nameEn ?? '').toLowerCase();
            final descRaw = c.descriptionZh ?? c.description ?? c.descriptionEn;
            final desc = (descRaw ?? '').toLowerCase();
            return name.contains(lower) ||
                nameEn.contains(lower) ||
                desc.contains(lower);
          })
          .take(10)
          .map((c) {
            final descRaw = c.description ?? c.descriptionZh ?? c.descriptionEn;
            return {
              'id': c.id,
              'title': locale != null
                  ? c.displayName(locale)
                  : (c.nameZh ?? c.nameEn ?? c.name),
              'type': 'forum_category',
              'description': locale != null
                  ? (c.displayDescription(locale) ?? '')
                  : (descRaw ?? ''),
            };
          })
          .toList();
    } catch (_) {
      return [];
    }
  }
}
