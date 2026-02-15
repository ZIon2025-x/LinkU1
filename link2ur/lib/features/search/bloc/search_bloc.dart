import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/repositories/flea_market_repository.dart';
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
    this.errorMessage,
  });

  final SearchStatus status;
  final String query;
  final List<Map<String, dynamic>> taskResults;
  final List<Map<String, dynamic>> forumResults;
  final List<Map<String, dynamic>> fleaMarketResults;
  final String? errorMessage;

  bool get isLoading => status == SearchStatus.loading;
  bool get hasResults =>
      taskResults.isNotEmpty ||
      forumResults.isNotEmpty ||
      fleaMarketResults.isNotEmpty;
  int get totalResults =>
      taskResults.length + forumResults.length + fleaMarketResults.length;

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    List<Map<String, dynamic>>? taskResults,
    List<Map<String, dynamic>>? forumResults,
    List<Map<String, dynamic>>? fleaMarketResults,
    String? errorMessage,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      taskResults: taskResults ?? this.taskResults,
      forumResults: forumResults ?? this.forumResults,
      fleaMarketResults: fleaMarketResults ?? this.fleaMarketResults,
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
        errorMessage,
      ];
}

// ==================== Bloc ====================

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc({
    required TaskRepository taskRepository,
    required ForumRepository forumRepository,
    required FleaMarketRepository fleaMarketRepository,
  })  : _taskRepository = taskRepository,
        _forumRepository = forumRepository,
        _fleaMarketRepository = fleaMarketRepository,
        super(const SearchState()) {
    on<SearchSubmitted>(_onSubmitted);
    on<SearchCleared>(_onCleared);
  }

  final TaskRepository _taskRepository;
  final ForumRepository _forumRepository;
  final FleaMarketRepository _fleaMarketRepository;

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
      // 并行搜索三个模块
      final results = await Future.wait([
        _searchTasks(query),
        _searchForum(query),
        _searchFleaMarket(query),
      ]);

      emit(state.copyWith(
        status: SearchStatus.loaded,
        taskResults: results[0],
        forumResults: results[1],
        fleaMarketResults: results[2],
      ));
    } catch (e) {
      AppLogger.error('Search failed', e);
      emit(state.copyWith(
        status: SearchStatus.error,
        errorMessage: '搜索失败，请重试',
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
}
