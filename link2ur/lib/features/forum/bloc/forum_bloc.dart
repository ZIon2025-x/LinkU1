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

class ForumLoadPostDetail extends ForumEvent {
  const ForumLoadPostDetail(this.postId);

  final int postId;

  @override
  List<Object?> get props => [postId];
}

class ForumLoadReplies extends ForumEvent {
  const ForumLoadReplies(this.postId);

  final int postId;

  @override
  List<Object?> get props => [postId];
}

class ForumCreatePost extends ForumEvent {
  const ForumCreatePost(this.request);

  final CreatePostRequest request;

  @override
  List<Object?> get props => [request];
}

class ForumLoadMyPosts extends ForumEvent {
  const ForumLoadMyPosts({this.page = 1});

  final int page;

  @override
  List<Object?> get props => [page];
}

class ForumLoadFavoritedPosts extends ForumEvent {
  const ForumLoadFavoritedPosts({this.page = 1});

  final int page;

  @override
  List<Object?> get props => [page];
}

class ForumReplyPost extends ForumEvent {
  const ForumReplyPost({
    required this.postId,
    required this.content,
    this.parentReplyId,
  });

  final int postId;
  final String content;
  final int? parentReplyId;

  @override
  List<Object?> get props => [postId, content, parentReplyId];
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
    this.selectedPost,
    this.replies = const [],
    this.isCreatingPost = false,
    this.isReplying = false,
    this.myPosts = const [],
    this.favoritedPosts = const [],
    this.isLoadingMyPosts = false,
    this.isLoadingFavoritedPosts = false,
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
  final ForumPost? selectedPost;
  final List<ForumReply> replies;
  final bool isCreatingPost;
  final bool isReplying;
  final List<ForumPost> myPosts;
  final List<ForumPost> favoritedPosts;
  final bool isLoadingMyPosts;
  final bool isLoadingFavoritedPosts;

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
    ForumPost? selectedPost,
    List<ForumReply>? replies,
    bool? isCreatingPost,
    bool? isReplying,
    List<ForumPost>? myPosts,
    List<ForumPost>? favoritedPosts,
    bool? isLoadingMyPosts,
    bool? isLoadingFavoritedPosts,
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
      selectedPost: selectedPost ?? this.selectedPost,
      replies: replies ?? this.replies,
      isCreatingPost: isCreatingPost ?? this.isCreatingPost,
      isReplying: isReplying ?? this.isReplying,
      myPosts: myPosts ?? this.myPosts,
      favoritedPosts: favoritedPosts ?? this.favoritedPosts,
      isLoadingMyPosts: isLoadingMyPosts ?? this.isLoadingMyPosts,
      isLoadingFavoritedPosts:
          isLoadingFavoritedPosts ?? this.isLoadingFavoritedPosts,
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
        selectedPost,
        replies,
        isCreatingPost,
        isReplying,
        myPosts,
        favoritedPosts,
        isLoadingMyPosts,
        isLoadingFavoritedPosts,
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
    on<ForumLoadPostDetail>(_onLoadPostDetail);
    on<ForumLoadReplies>(_onLoadReplies);
    on<ForumCreatePost>(_onCreatePost);
    on<ForumReplyPost>(_onReplyPost);
    on<ForumLoadMyPosts>(_onLoadMyPosts);
    on<ForumLoadFavoritedPosts>(_onLoadFavoritedPosts);
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
    // 防止重复加载：已有数据且非强制刷新时跳过全屏 loading
    if (state.status == ForumStatus.loading) return;
    final hasExistingData = state.posts.isNotEmpty;
    if (!hasExistingData) {
      emit(state.copyWith(status: ForumStatus.loading));
    }

    try {
      final response = await _forumRepository.getPosts(
        page: 1,
        categoryId: event.categoryId ?? state.selectedCategoryId,
        keyword: state.searchQuery.isEmpty ? null : state.searchQuery,
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
        keyword: state.searchQuery.isEmpty ? null : state.searchQuery,
      );

      emit(state.copyWith(
        posts: [...state.posts, ...response.posts],
        total: response.total,
        page: nextPage,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to load more posts', e);
      emit(state.copyWith(hasMore: false));
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
        keyword: event.query.isEmpty ? null : event.query,
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

      // Also update selectedPost if it's the same post
      final updatedSelectedPost = state.selectedPost?.id == event.postId
          ? state.selectedPost!.copyWith(
              isFavorited: !state.selectedPost!.isFavorited)
          : state.selectedPost;

      emit(state.copyWith(
        posts: updatedPosts,
        selectedPost: updatedSelectedPost,
      ));
    } catch (e) {
      AppLogger.error('Failed to favorite post', e);
    }
  }

  Future<void> _onLoadPostDetail(
    ForumLoadPostDetail event,
    Emitter<ForumState> emit,
  ) async {
    emit(state.copyWith(status: ForumStatus.loading));

    try {
      final post = await _forumRepository.getPostById(event.postId);
      emit(state.copyWith(
        status: ForumStatus.loaded,
        selectedPost: post,
      ));
    } catch (e) {
      AppLogger.error('Failed to load post detail', e);
      emit(state.copyWith(
        status: ForumStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadReplies(
    ForumLoadReplies event,
    Emitter<ForumState> emit,
  ) async {
    try {
      final replies = await _forumRepository.getPostReplies(event.postId);
      emit(state.copyWith(replies: replies));
    } catch (e) {
      AppLogger.error('Failed to load replies', e);
    }
  }

  Future<void> _onCreatePost(
    ForumCreatePost event,
    Emitter<ForumState> emit,
  ) async {
    emit(state.copyWith(isCreatingPost: true));

    try {
      final post = await _forumRepository.createPost(event.request);
      emit(state.copyWith(
        isCreatingPost: false,
        posts: [post, ...state.posts],
      ));
    } catch (e) {
      AppLogger.error('Failed to create post', e);
      emit(state.copyWith(
        isCreatingPost: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onReplyPost(
    ForumReplyPost event,
    Emitter<ForumState> emit,
  ) async {
    emit(state.copyWith(isReplying: true));

    try {
      final reply = await _forumRepository.replyPost(
        event.postId,
        content: event.content,
        parentReplyId: event.parentReplyId,
      );
      emit(state.copyWith(
        isReplying: false,
        replies: [...state.replies, reply],
        selectedPost: state.selectedPost?.copyWith(
          replyCount: (state.selectedPost?.replyCount ?? 0) + 1,
        ),
      ));
    } catch (e) {
      AppLogger.error('Failed to reply post', e);
      emit(state.copyWith(
        isReplying: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadMyPosts(
    ForumLoadMyPosts event,
    Emitter<ForumState> emit,
  ) async {
    emit(state.copyWith(isLoadingMyPosts: true));

    try {
      final response = await _forumRepository.getMyPosts(page: event.page);
      emit(state.copyWith(
        myPosts: response.posts,
        isLoadingMyPosts: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to load my posts', e);
      emit(state.copyWith(
        isLoadingMyPosts: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadFavoritedPosts(
    ForumLoadFavoritedPosts event,
    Emitter<ForumState> emit,
  ) async {
    emit(state.copyWith(isLoadingFavoritedPosts: true));

    try {
      final response =
          await _forumRepository.getFavoritePosts(page: event.page);
      emit(state.copyWith(
        favoritedPosts: response.posts,
        isLoadingFavoritedPosts: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to load favorited posts', e);
      emit(state.copyWith(
        isLoadingFavoritedPosts: false,
        errorMessage: e.toString(),
      ));
    }
  }
}
