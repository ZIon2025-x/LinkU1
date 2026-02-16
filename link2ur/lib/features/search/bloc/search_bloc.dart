import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/repositories/flea_market_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../../../core/utils/logger.dart';

// ==================== Events ====================

abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

/// 执行搜索
class SearchSubmitted extends SearchEvent {
  const SearchSubmitted(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// 清除搜索
class SearchCleared extends SearchEvent {
  const SearchCleared();
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
  final String? errorMessage;

  bool get isLoading => status == SearchStatus.loading;
  bool get hasResults =>
      taskResults.isNotEmpty ||
      forumResults.isNotEmpty ||
      fleaMarketResults.isNotEmpty ||
      expertResults.isNotEmpty ||
      activityResults.isNotEmpty ||
      leaderboardResults.isNotEmpty;
  int get totalResults =>
      taskResults.length +
      forumResults.length +
      fleaMarketResults.length +
      expertResults.length +
      activityResults.length +
      leaderboardResults.length;

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    List<Map<String, dynamic>>? taskResults,
    List<Map<String, dynamic>>? forumResults,
    List<Map<String, dynamic>>? fleaMarketResults,
    List<Map<String, dynamic>>? expertResults,
    List<Map<String, dynamic>>? activityResults,
    List<Map<String, dynamic>>? leaderboardResults,
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
      // 并行搜索六个模块
      final results = await Future.wait([
        _searchTasks(query),
        _searchForum(query),
        _searchFleaMarket(query),
        _searchExperts(query),
        _searchActivities(query),
        _searchLeaderboards(query),
      ]);

      emit(state.copyWith(
        status: SearchStatus.loaded,
        taskResults: results[0],
        forumResults: results[1],
        fleaMarketResults: results[2],
        expertResults: results[3],
        activityResults: results[4],
        leaderboardResults: results[5],
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
    emit(const SearchState());
  }

  Future<List<Map<String, dynamic>>> _searchTasks(String query) async {
    try {
      final response = await _taskRepository.getTasks(
        keyword: query,
        page: 1,
        pageSize: 10,
      );
      return response.tasks
          .map((t) => {
                'id': t.id,
                'title': t.titleZh ?? t.titleEn ?? t.title,
                'type': 'task',
                'description': t.descriptionZh ?? t.descriptionEn ?? '',
                'status': t.status,
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchForum(String query) async {
    try {
      final response = await _forumRepository.searchPosts(
        keyword: query,
        page: 1,
        pageSize: 10,
      );
      return response.posts
          .map((p) => {
                'id': p.id,
                'title': p.title,
                'type': 'forum',
                'description': p.content ?? '',
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
        page: 1,
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
        page: 1,
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

  Future<List<Map<String, dynamic>>> _searchActivities(String query) async {
    try {
      final response = await _activityRepository.getActivities(
        keyword: query,
        page: 1,
        pageSize: 10,
      );
      return response.activities
          .map((a) => {
                'id': a.id,
                'title': a.title,
                'type': 'activity',
                'description': a.description,
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchLeaderboards(String query) async {
    try {
      final response = await _leaderboardRepository.getLeaderboards(
        keyword: query,
        page: 1,
        pageSize: 10,
      );
      return response.leaderboards
          .map((lb) => {
                'id': lb.id,
                'title': lb.name,
                'type': 'leaderboard',
                'description': lb.description ?? lb.location,
              })
          .toList();
    } catch (_) {
      return [];
    }
  }
}
