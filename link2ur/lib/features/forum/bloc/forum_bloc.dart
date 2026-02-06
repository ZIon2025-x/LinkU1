import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/forum.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../core/utils/logger.dart';

// ==================== Events ====================

abstract class ForumEvent extends Equatable {
  const ForumEvent();

  @override
  List<Object?> get props => [];
}

class ForumLoadCategories extends ForumEvent {
  const ForumLoadCategories();
}

class ForumLoadPosts extends ForumEvent {
  const ForumLoadPosts({this.categoryId});

  final int? categoryId;

  @override
  List<Object?> get props => [categoryId];
}

class ForumLoadMorePosts extends ForumEvent {
  const ForumLoadMorePosts();
}

class ForumRefreshRequested extends ForumEvent {
  const ForumRefreshRequested();
}

class ForumSearchChanged extends ForumEvent {
  const ForumSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class ForumCategoryChanged extends ForumEvent {
  const ForumCategoryChanged(this.categoryId);

  final int? categoryId;

  @override
  List<Object?> get props => [categoryId];
}

class ForumLikePost extends ForumEvent {
  const ForumLikePost(this.postId);

  final int postId;

  @override
  List<Object?> get props => [postId];
}

class ForumFavoritePost extends ForumEvent {
  const ForumFavoritePost(this.postId);

  final int postId;

  @override
  List<Object?> get props => [postId];
}

// ==================== State ====================

enum ForumStatus { initial, loading, loaded, error }

class ForumState extends Equatable {
  const ForumState({
    this.status = ForumStatus.initial,
    this.categories = const [],
    this.posts = const [],
    this.total = 0,
    this.page = 1,
    this.hasMore = true,
    this.selectedCategoryId,
    this.searchQuery = '',
    this.errorMessage,
    this.isRefreshing = false,
  });

  final ForumStatus status;
  final List<ForumCategory> categories;
  final List<ForumPost> posts;
  final int total;
  final int page;
  final bool hasMore;
  final int? selectedCategoryId;
  final String searchQuery;
  final String? errorMessage;
  final bool isRefreshing;

  bool get isLoading => status == ForumStatus.loading;

  ForumState copyWith({
    ForumStatus? status,
    List<ForumCategory>? categories,
    List<ForumPost>? posts,
    int? total,
    int? page,
    bool? hasMore,
    int? selectedCategoryId,
    bool clearCategory = false,
    String? searchQuery,
    String? errorMessage,
    bool? isRefreshing,
  }) {
    return ForumState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      posts: posts ?? this.posts,
      total: total ?? this.total,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      selectedCategoryId:
          clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [
        status,
        categories,
        posts,
        total,
        page,
        hasMore,
        selectedCategoryId,
        searchQuery,
        errorMessage,
        isRefreshing,
      ];
}

// ==================== Bloc ====================

class ForumBloc extends Bloc<ForumEvent, ForumState> {
  ForumBloc({required ForumRepository forumRepository})
      : _forumRepository = forumRepository,
        super(const ForumState()) {
    on<ForumLoadCategories>(_onLoadCategories);
    on<ForumLoadPosts>(_onLoadPosts);
    on<ForumLoadMorePosts>(_onLoadMorePosts);
    on<ForumRefreshRequested>(_onRefresh);
    on<ForumSearchChanged>(_onSearchChanged);
    on<ForumCategoryChanged>(_onCategoryChanged);
    on<ForumLikePost>(_onLikePost);
    on<ForumFavoritePost>(_onFavoritePost);
  }

  final ForumRepository _forumRepository;

  Future<void> _onLoadCategories(
    ForumLoadCategories event,
    Emitter<ForumState> emit,
  ) async {
    try {
      final categories = await _forumRepository.getCategories();
      emit(state.copyWith(categories: categories));
    } catch (e) {
      AppLogger.error('Failed to load forum categories', e);
    }
  }

  Future<void> _onLoadPosts(
    ForumLoadPosts event,
    Emitter<ForumState> emit,
  ) async {
    emit(state.copyWith(status: ForumStatus.loading));

    try {
      final response = await _forumRepository.getPosts(
        page: 1,
        categoryId: event.categoryId ?? state.selectedCategoryId,
        search: state.searchQuery.isEmpty ? null : state.searchQuery,
      );

      emit(state.copyWith(
        status: ForumStatus.loaded,
        posts: response.posts,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to load forum posts', e);
      emit(state.copyWith(
        status: ForumStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadMorePosts(
    ForumLoadMorePosts event,
    Emitter<ForumState> emit,
  ) async {
    if (!state.hasMore) return;

    try {
      final nextPage = state.page + 1;
      final response = await _forumRepository.getPosts(
        page: nextPage,
        categoryId: state.selectedCategoryId,
        search: state.searchQuery.isEmpty ? null : state.searchQuery,
      );

      emit(state.copyWith(
        posts: [...state.posts, ...response.posts],
        total: response.total,
        page: nextPage,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to load more posts', e);
    }
  }

  Future<void> _onRefresh(
    ForumRefreshRequested event,
    Emitter<ForumState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true));

    try {
      final response = await _forumRepository.getPosts(
        page: 1,
        categoryId: state.selectedCategoryId,
      );

      emit(state.copyWith(
        status: ForumStatus.loaded,
        posts: response.posts,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
        isRefreshing: false,
      ));
    } catch (e) {
      emit(state.copyWith(isRefreshing: false));
    }
  }

  Future<void> _onSearchChanged(
    ForumSearchChanged event,
    Emitter<ForumState> emit,
  ) async {
    emit(state.copyWith(
      searchQuery: event.query,
      status: ForumStatus.loading,
    ));

    try {
      final response = await _forumRepository.getPosts(
        page: 1,
        search: event.query.isEmpty ? null : event.query,
        categoryId: state.selectedCategoryId,
      );

      emit(state.copyWith(
        status: ForumStatus.loaded,
        posts: response.posts,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ForumStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onCategoryChanged(
    ForumCategoryChanged event,
    Emitter<ForumState> emit,
  ) async {
    emit(state.copyWith(
      selectedCategoryId: event.categoryId,
      clearCategory: event.categoryId == null,
      status: ForumStatus.loading,
    ));

    try {
      final response = await _forumRepository.getPosts(
        page: 1,
        categoryId: event.categoryId,
      );

      emit(state.copyWith(
        status: ForumStatus.loaded,
        posts: response.posts,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ForumStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLikePost(
    ForumLikePost event,
    Emitter<ForumState> emit,
  ) async {
    try {
      await _forumRepository.likePost(event.postId);

      // 更新本地状态
      final updatedPosts = state.posts.map((post) {
        if (post.id == event.postId) {
          return post.copyWith(
            isLiked: !post.isLiked,
            likeCount: post.isLiked
                ? post.likeCount - 1
                : post.likeCount + 1,
          );
        }
        return post;
      }).toList();

      emit(state.copyWith(posts: updatedPosts));
    } catch (e) {
      AppLogger.error('Failed to like post', e);
    }
  }

  Future<void> _onFavoritePost(
    ForumFavoritePost event,
    Emitter<ForumState> emit,
  ) async {
    try {
      await _forumRepository.favoritePost(event.postId);

      final updatedPosts = state.posts.map((post) {
        if (post.id == event.postId) {
          return post.copyWith(isFavorited: !post.isFavorited);
        }
        return post;
      }).toList();

      emit(state.copyWith(posts: updatedPosts));
    } catch (e) {
      AppLogger.error('Failed to favorite post', e);
    }
  }
}
