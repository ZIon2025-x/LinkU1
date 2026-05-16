import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';

import '../../../core/utils/cache_manager.dart';
import '../../../data/models/feed_item.dart';
import '../../../data/models/forum.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/app_exception.dart';

EventTransformer<E> _debounce<E>(Duration duration) {
  return (events, mapper) => events.debounce(duration).switchMap(mapper);
}

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

/// 收藏/取消收藏板块（分类）
class ForumToggleCategoryFavorite extends ForumEvent {
  const ForumToggleCategoryFavorite(this.categoryId);

  final int categoryId;

  @override
  List<Object?> get props => [categoryId];
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

/// 切换根评论排序方式（'hot' | 'time'）
/// 处理器会清空已加载的子回复缓存并重新拉根评论
class ForumReplySortChanged extends ForumEvent {
  const ForumReplySortChanged(this.postId, this.sort);

  final int postId;
  final String sort;

  @override
  List<Object?> get props => [postId, sort];
}

/// 展开/继续加载某根评论的子回复（下一批）
class ForumLoadMoreChildren extends ForumEvent {
  const ForumLoadMoreChildren(this.rootReplyId);

  final int rootReplyId;

  @override
  List<Object?> get props => [rootReplyId];
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

class ForumReportPost extends ForumEvent {
  const ForumReportPost(this.postId, {required this.reason});

  final int postId;
  final String reason;

  @override
  List<Object?> get props => [postId, reason];
}

class ForumDeletePost extends ForumEvent {
  const ForumDeletePost(this.postId);

  final int postId;

  @override
  List<Object?> get props => [postId];
}

class ForumEditPost extends ForumEvent {
  /// 仅传有改动的字段，减少后端翻译等重复调用
  const ForumEditPost(this.postId, {this.title, this.content, this.images, this.attachments});

  final int postId;
  final String? title;
  final String? content;
  final List<String>? images;
  final List<ForumPostAttachment>? attachments;

  @override
  List<Object?> get props => [postId, title, content, images, attachments];
}

class ForumDeleteReply extends ForumEvent {
  const ForumDeleteReply(this.replyId, {required this.postId});

  final int replyId;
  final int postId;

  @override
  List<Object?> get props => [replyId, postId];
}

class ForumLikeReply extends ForumEvent {
  const ForumLikeReply(this.replyId);

  final int replyId;

  @override
  List<Object?> get props => [replyId];
}

class ForumLoadFeed extends ForumEvent {
  const ForumLoadFeed({required this.categoryId, this.sortBy = 'weight'});
  final int categoryId;
  final String sortBy;

  @override
  List<Object?> get props => [categoryId, sortBy];
}

class ForumLoadMoreFeed extends ForumEvent {
  const ForumLoadMoreFeed({required this.categoryId});
  final int categoryId;

  @override
  List<Object?> get props => [categoryId];
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
    this.loadMoreError = false,
    this.isLoadingMore = false,
    this.selectedPost,
    this.replies = const [],
    this.isCreatingPost = false,
    this.createPostSuccess = false,
    this.isReplying = false,
    this.myPosts = const [],
    this.favoritedPosts = const [],
    this.isLoadingMyPosts = false,
    this.isLoadingFavoritedPosts = false,
    this.reportSuccess = false,
    this.repliesPage = 1,
    this.repliesHasMore = true,
    this.isLoadingMoreReplies = false,
    this.lastOfficialTaskReward,
    this.feedItems = const [],
    this.feedStatus = ForumStatus.initial,
    this.feedHasMore = false,
    this.feedPage = 1,
    this.isLoadingMoreFeed = false,
    this.replySort = 'hot',
    this.loadedChildren = const {},
    this.hasMoreChildren = const {},
    this.nextChildOffset = const {},
    this.loadingChildrenRoots = const {},
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
  /// 分页加载更多失败标志，用于 UI 显示重试按钮
  final bool loadMoreError;
  /// 是否正在加载更多，防止快速滚动触发重复请求
  final bool isLoadingMore;
  final ForumPost? selectedPost;
  final List<ForumReply> replies;
  final bool isCreatingPost;
  final bool createPostSuccess;
  final bool isReplying;
  final List<ForumPost> myPosts;
  final List<ForumPost> favoritedPosts;
  final bool isLoadingMyPosts;
  final bool isLoadingFavoritedPosts;
  final bool reportSuccess;
  /// 回复分页：当前页码
  final int repliesPage;
  /// 回复分页：是否还有更多
  final bool repliesHasMore;
  /// 回复分页：是否正在加载更多回复
  final bool isLoadingMoreReplies;
  final Map<String, dynamic>? lastOfficialTaskReward;
  final List<FeedItem> feedItems;
  final ForumStatus feedStatus;
  final bool feedHasMore;
  final int feedPage;
  final bool isLoadingMoreFeed;

  // ===== 帖子详情页：根评论排序 + 子评论分批 (Task 14) =====
  /// 根评论排序：'hot'（默认）/'time'
  final String replySort;
  /// 某根评论已加载的子回复（追加在 preview_children 之后）。key = root reply id
  final Map<int, List<ForumReply>> loadedChildren;
  /// 某根评论是否还有更多子回复可加载。key = root reply id
  final Map<int, bool> hasMoreChildren;
  /// 某根评论下一次加载的 offset。key = root reply id
  final Map<int, int> nextChildOffset;
  /// 当前正在加载子回复的 root id 集合（用于按钮 spinner + 防重复请求）
  final Set<int> loadingChildrenRoots;

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
    bool? loadMoreError,
    bool? isLoadingMore,
    ForumPost? selectedPost,
    List<ForumReply>? replies,
    bool? isCreatingPost,
    bool? createPostSuccess,
    bool? isReplying,
    List<ForumPost>? myPosts,
    List<ForumPost>? favoritedPosts,
    bool? isLoadingMyPosts,
    bool? isLoadingFavoritedPosts,
    bool? reportSuccess,
    int? repliesPage,
    bool? repliesHasMore,
    bool? isLoadingMoreReplies,
    Map<String, dynamic>? lastOfficialTaskReward,
    bool clearOfficialTaskReward = false,
    List<FeedItem>? feedItems,
    ForumStatus? feedStatus,
    bool? feedHasMore,
    int? feedPage,
    bool? isLoadingMoreFeed,
    String? replySort,
    Map<int, List<ForumReply>>? loadedChildren,
    Map<int, bool>? hasMoreChildren,
    Map<int, int>? nextChildOffset,
    Set<int>? loadingChildrenRoots,
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
      loadMoreError: loadMoreError ?? false,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      selectedPost: selectedPost ?? this.selectedPost,
      replies: replies ?? this.replies,
      isCreatingPost: isCreatingPost ?? this.isCreatingPost,
      createPostSuccess: createPostSuccess ?? false,
      isReplying: isReplying ?? this.isReplying,
      myPosts: myPosts ?? this.myPosts,
      favoritedPosts: favoritedPosts ?? this.favoritedPosts,
      isLoadingMyPosts: isLoadingMyPosts ?? this.isLoadingMyPosts,
      isLoadingFavoritedPosts:
          isLoadingFavoritedPosts ?? this.isLoadingFavoritedPosts,
      reportSuccess: reportSuccess ?? this.reportSuccess,
      repliesPage: repliesPage ?? this.repliesPage,
      repliesHasMore: repliesHasMore ?? this.repliesHasMore,
      isLoadingMoreReplies: isLoadingMoreReplies ?? this.isLoadingMoreReplies,
      lastOfficialTaskReward: clearOfficialTaskReward ? null : (lastOfficialTaskReward ?? this.lastOfficialTaskReward),
      feedItems: feedItems ?? this.feedItems,
      feedStatus: feedStatus ?? this.feedStatus,
      feedHasMore: feedHasMore ?? this.feedHasMore,
      feedPage: feedPage ?? this.feedPage,
      isLoadingMoreFeed: isLoadingMoreFeed ?? this.isLoadingMoreFeed,
      replySort: replySort ?? this.replySort,
      loadedChildren: loadedChildren ?? this.loadedChildren,
      hasMoreChildren: hasMoreChildren ?? this.hasMoreChildren,
      nextChildOffset: nextChildOffset ?? this.nextChildOffset,
      loadingChildrenRoots: loadingChildrenRoots ?? this.loadingChildrenRoots,
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
        loadMoreError,
        isLoadingMore,
        selectedPost,
        replies,
        isCreatingPost,
        createPostSuccess,
        isReplying,
        myPosts,
        favoritedPosts,
        isLoadingMyPosts,
        isLoadingFavoritedPosts,
        reportSuccess,
        repliesPage,
        repliesHasMore,
        isLoadingMoreReplies,
        lastOfficialTaskReward,
        feedItems,
        feedStatus,
        feedHasMore,
        feedPage,
        isLoadingMoreFeed,
        replySort,
        loadedChildren,
        hasMoreChildren,
        nextChildOffset,
        loadingChildrenRoots,
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
    on<ForumSearchChanged>(
      _onSearchChanged,
      transformer: _debounce(const Duration(milliseconds: 500)),
    );
    on<ForumCategoryChanged>(_onCategoryChanged);
    on<ForumLikePost>(_onLikePost);
    on<ForumFavoritePost>(_onFavoritePost);
    on<ForumToggleCategoryFavorite>(_onToggleCategoryFavorite);
    on<ForumLoadPostDetail>(_onLoadPostDetail);
    on<ForumLoadReplies>(_onLoadReplies);
    on<ForumReplySortChanged>(_onReplySortChanged);
    on<ForumLoadMoreChildren>(_onLoadMoreChildren);
    on<ForumCreatePost>(_onCreatePost);
    on<ForumReplyPost>(_onReplyPost);
    on<ForumReportPost>(_onReportPost);
    on<ForumDeletePost>(_onDeletePost);
    on<ForumEditPost>(_onEditPost);
    on<ForumDeleteReply>(_onDeleteReply);
    on<ForumLikeReply>(_onLikeReply);
    on<ForumLoadMyPosts>(_onLoadMyPosts);
    on<ForumLoadFavoritedPosts>(_onLoadFavoritedPosts);
    on<ForumLoadFeed>(_onLoadFeed);
    on<ForumLoadMoreFeed>(_onLoadMoreFeed);
  }

  final ForumRepository _forumRepository;

  Future<void> _onLoadCategories(
    ForumLoadCategories event,
    Emitter<ForumState> emit,
  ) async {
    // 防止重复加载
    if (state.status == ForumStatus.loading) return;
    final hasData = state.categories.isNotEmpty;
    if (!hasData) {
      emit(state.copyWith(status: ForumStatus.loading));
    }

    try {
      final categories = await _forumRepository.getVisibleCategories();
      emit(state.copyWith(
        status: ForumStatus.loaded,
        categories: categories,
      ));

      // 对齐 iOS：加载分类后批量获取收藏状态
      if (categories.isNotEmpty) {
        await _loadCategoryFavoritesBatch(categories, emit);
      }
    } catch (e) {
      AppLogger.error('Failed to load forum categories', e);
      if (state.categories.isEmpty) {
        emit(state.copyWith(
          status: ForumStatus.error,
          errorMessage: e is AppException ? e.message : e.toString(),
        ));
      }
    }
  }

  /// 批量获取分类收藏状态并更新 — 对标 iOS ForumViewModel.loadCategoryFavoritesBatch
  Future<void> _loadCategoryFavoritesBatch(
    List<ForumCategory> categories,
    Emitter<ForumState> emit,
  ) async {
    try {
      final ids = categories.map((c) => c.id).toList();
      final favMap = await _forumRepository.getCategoryFavoritesBatch(ids);
      if (emit.isDone || favMap.isEmpty) return;

      final updated = state.categories.map((c) {
        final fav = favMap[c.id];
        return fav != null ? c.copyWith(isFavorited: fav) : c;
      }).toList();

      emit(state.copyWith(categories: updated));
    } catch (e) {
      AppLogger.error('Failed to load category favorites batch', e);
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
        categoryId: event.categoryId ?? state.selectedCategoryId,
        keyword: state.searchQuery.isEmpty ? null : state.searchQuery,
      );

      emit(state.copyWith(
        status: ForumStatus.loaded,
        posts: response.posts,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
        isLoadingMore: false,
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
    if (!state.hasMore || state.isLoadingMore) return;

    emit(state.copyWith(isLoadingMore: true));
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
        loadMoreError: false,
        isLoadingMore: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to load more posts', e);
      // 标记加载更多失败，UI 可显示重试按钮（不设 hasMore: false，允许用户重试）
      emit(state.copyWith(loadMoreError: true, isLoadingMore: false));
    }
  }

  Future<void> _onRefresh(
    ForumRefreshRequested event,
    Emitter<ForumState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true));

    // 下拉刷新前失效缓存，确保获取最新数据
    await CacheManager.shared.invalidateForumCache();

    try {
      // 刷新板块列表（使用权限过滤 API）
      final categories = await _forumRepository.getVisibleCategories();

      // 如果当前有选中分类，也刷新帖子
      if (state.selectedCategoryId != null) {
        final response = await _forumRepository.getPosts(
          categoryId: state.selectedCategoryId,
        );
        emit(state.copyWith(
          status: ForumStatus.loaded,
          categories: categories,
          posts: response.posts,
          total: response.total,
          page: 1,
          hasMore: response.hasMore,
          isRefreshing: false,
        ));
      } else {
        emit(state.copyWith(
          status: ForumStatus.loaded,
          categories: categories,
          isRefreshing: false,
        ));
      }

      // 刷新后同样拉取板块收藏状态，否则会显示为未收藏
      if (categories.isNotEmpty) {
        await _loadCategoryFavoritesBatch(categories, emit);
      }
    } catch (e) {
      AppLogger.error('Failed to refresh forum', e);
      emit(state.copyWith(
        isRefreshing: false,
        errorMessage: e.toString(),
      ));
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
        keyword: event.query.isEmpty ? null : event.query,
        categoryId: state.selectedCategoryId,
      );

      emit(state.copyWith(
        status: ForumStatus.loaded,
        posts: response.posts,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
        isLoadingMore: false,
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
        categoryId: event.categoryId,
      );

      emit(state.copyWith(
        status: ForumStatus.loaded,
        posts: response.posts,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
        isLoadingMore: false,
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
    // 乐观更新：先更新 UI，失败时回滚（同时更新 posts 与 selectedPost，详情页读 selectedPost）
    final originalPosts = List<ForumPost>.from(state.posts);
    final originalSelectedPost = state.selectedPost;

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

    final updatedSelectedPost = state.selectedPost?.id == event.postId
        ? state.selectedPost!.copyWith(
            isLiked: !state.selectedPost!.isLiked,
            likeCount: state.selectedPost!.isLiked
                ? state.selectedPost!.likeCount - 1
                : state.selectedPost!.likeCount + 1,
          )
        : state.selectedPost;

    emit(state.copyWith(
      posts: updatedPosts,
      selectedPost: updatedSelectedPost,
    ));

    try {
      final result = await _forumRepository.likePost(event.postId);
      // 用服务器返回的真实数据校正乐观更新
      final correctedPosts = state.posts.map((post) {
        if (post.id == event.postId) {
          return post.copyWith(
            isLiked: result.liked,
            likeCount: result.likeCount,
          );
        }
        return post;
      }).toList();
      final correctedSelectedPost = state.selectedPost?.id == event.postId
          ? state.selectedPost!.copyWith(
              isLiked: result.liked,
              likeCount: result.likeCount,
            )
          : state.selectedPost;
      emit(state.copyWith(
        posts: correctedPosts,
        selectedPost: correctedSelectedPost,
      ));
    } catch (e) {
      AppLogger.error('Failed to like post', e);
      emit(state.copyWith(
        posts: originalPosts,
        selectedPost: originalSelectedPost,
        errorMessage: e is AppException ? e.message : e.toString(),
      ));
    }
  }

  Future<void> _onFavoritePost(
    ForumFavoritePost event,
    Emitter<ForumState> emit,
  ) async {
    // 乐观更新：先更新 UI，失败时回滚
    final originalPosts = List<ForumPost>.from(state.posts);
    final originalSelectedPost = state.selectedPost;

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

    try {
      final result = await _forumRepository.favoritePost(event.postId);
      // 用服务器返回的真实数据校正乐观更新
      final correctedPosts = state.posts.map((post) {
        if (post.id == event.postId) {
          return post.copyWith(
            isFavorited: result.favorited,
            favoriteCount: result.favoriteCount,
          );
        }
        return post;
      }).toList();
      final correctedSelectedPost = state.selectedPost?.id == event.postId
          ? state.selectedPost!.copyWith(
              isFavorited: result.favorited,
              favoriteCount: result.favoriteCount,
            )
          : state.selectedPost;
      emit(state.copyWith(
        posts: correctedPosts,
        selectedPost: correctedSelectedPost,
      ));
    } catch (e) {
      AppLogger.error('Failed to favorite post', e);
      // 回滚到原始状态并发出错误信息
      emit(state.copyWith(
        posts: originalPosts,
        selectedPost: originalSelectedPost,
        errorMessage: e is AppException ? e.message : e.toString(),
      ));
    }
  }

  /// 收藏/取消收藏板块 — 乐观更新
  Future<void> _onToggleCategoryFavorite(
    ForumToggleCategoryFavorite event,
    Emitter<ForumState> emit,
  ) async {
    final original = state.categories;
    final updated = state.categories.map((c) {
      if (c.id == event.categoryId) {
        return c.copyWith(isFavorited: !c.isFavorited);
      }
      return c;
    }).toList();
    emit(state.copyWith(categories: updated));
    try {
      await _forumRepository.toggleCategoryFavorite(event.categoryId);
    } catch (e) {
      AppLogger.error('Failed to toggle category favorite', e);
      emit(state.copyWith(
        categories: original,
        errorMessage: e is AppException ? e.message : e.toString(),
      ));
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
    // Task 10 重构后只拉根评论 + preview_children；子回复分批走 getReplyChildren。
    try {
      final replies = await _forumRepository.getPostReplies(
        event.postId,
        sort: state.replySort,
      );
      emit(state.copyWith(
        replies: replies,
        // 根级分页已废弃：服务器一次返回所有根（pageSize 默认 100）
        repliesHasMore: false,
        isLoadingMoreReplies: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to load replies', e);
      emit(state.copyWith(
        errorMessage: 'forum_load_replies_failed',
        isLoadingMoreReplies: false,
      ));
    }
  }

  Future<void> _onReplySortChanged(
    ForumReplySortChanged event,
    Emitter<ForumState> emit,
  ) async {
    // 切换 sort 后清空旧的 children 缓存,重新拉根
    if (event.sort == state.replySort) return;
    emit(state.copyWith(
      replySort: event.sort,
      loadedChildren: const {},
      hasMoreChildren: const {},
      nextChildOffset: const {},
      loadingChildrenRoots: const {},
    ));
    add(ForumLoadReplies(event.postId));
  }

  Future<void> _onLoadMoreChildren(
    ForumLoadMoreChildren event,
    Emitter<ForumState> emit,
  ) async {
    final rootId = event.rootReplyId;
    if (state.loadingChildrenRoots.contains(rootId)) return; // 防重复
    // 首次展开 offset 从 3 起 (跳过 preview_children 已加载的 3 条)
    final offset = state.nextChildOffset[rootId] ?? 3;

    emit(state.copyWith(
      loadingChildrenRoots: {...state.loadingChildrenRoots, rootId},
    ));

    try {
      // limit 用 repo 默认值 (5); 后端 Task 11 端点也允许调用方覆盖
      final page = await _forumRepository.getReplyChildren(
        rootId,
        offset: offset,
      );
      final existing =
          state.loadedChildren[rootId] ?? const <ForumReply>[];
      // 去重：按 id 过滤新批次中已存在的
      final existingIds = existing.map((r) => r.id).toSet();
      final fresh =
          page.replies.where((r) => !existingIds.contains(r.id)).toList();

      emit(state.copyWith(
        loadedChildren: {
          ...state.loadedChildren,
          rootId: [...existing, ...fresh],
        },
        hasMoreChildren: {...state.hasMoreChildren, rootId: page.hasMore},
        nextChildOffset: {...state.nextChildOffset, rootId: page.nextOffset},
        loadingChildrenRoots:
            state.loadingChildrenRoots.where((id) => id != rootId).toSet(),
      ));
    } catch (e) {
      AppLogger.error('Failed to load more children for root $rootId', e);
      emit(state.copyWith(
        loadingChildrenRoots:
            state.loadingChildrenRoots.where((id) => id != rootId).toSet(),
        errorMessage: 'forum_load_children_failed',
      ));
    }
  }

  Future<void> _onCreatePost(
    ForumCreatePost event,
    Emitter<ForumState> emit,
  ) async {
    if (state.isCreatingPost) return;
    emit(state.copyWith(isCreatingPost: true, createPostSuccess: false));

    try {
      final post = await _forumRepository.createPost(event.request);
      emit(state.copyWith(
        isCreatingPost: false,
        createPostSuccess: true,
        lastOfficialTaskReward: post.officialTaskReward,
        posts: [post, ...state.posts],
      ));
    } catch (e) {
      AppLogger.error('Failed to create post', e);
      emit(state.copyWith(
        isCreatingPost: false,
        createPostSuccess: false,
        errorMessage: 'forum_create_post_failed',
      ));
    }
  }

  Future<void> _onReplyPost(
    ForumReplyPost event,
    Emitter<ForumState> emit,
  ) async {
    if (state.isReplying) return;
    emit(state.copyWith(isReplying: true));

    try {
      final reply = await _forumRepository.replyPost(
        event.postId,
        content: event.content,
        parentReplyId: event.parentReplyId,
      );

      // Task 10 重构后 state.replies 只装根；子回复要 append 到 ancestor root 的 loadedChildren
      if (reply.parentReplyId == null) {
        // 根回复 → append 到 state.replies
        emit(state.copyWith(
          isReplying: false,
          replies: [...state.replies, reply],
          selectedPost: state.selectedPost?.copyWith(
            replyCount: (state.selectedPost?.replyCount ?? 0) + 1,
          ),
        ));
      } else {
        // 子回复 → append 到 ancestor root 的 loadedChildren + totalChildren++
        final ancestorRootId = _findAncestorRootId(reply.parentReplyId!);
        if (ancestorRootId == null) {
          // 应当不会发生：parent 不在视野里。降级：只增 replyCount，等下次 ForumLoadReplies
          AppLogger.warning(
            'Reply parent id=${reply.parentReplyId} not in current view; skipping local children update',
          );
          emit(state.copyWith(
            isReplying: false,
            selectedPost: state.selectedPost?.copyWith(
              replyCount: (state.selectedPost?.replyCount ?? 0) + 1,
            ),
          ));
          return;
        }
        final existingLoaded =
            state.loadedChildren[ancestorRootId] ?? const <ForumReply>[];
        final newLoadedChildren = {
          ...state.loadedChildren,
          ancestorRootId: [...existingLoaded, reply],
        };
        // 给该 root 增 totalChildren
        final newReplies = state.replies.map((r) {
          if (r.id == ancestorRootId) {
            return r.copyWith(totalChildren: r.totalChildren + 1);
          }
          return r;
        }).toList();
        emit(state.copyWith(
          isReplying: false,
          replies: newReplies,
          loadedChildren: newLoadedChildren,
          selectedPost: state.selectedPost?.copyWith(
            replyCount: (state.selectedPost?.replyCount ?? 0) + 1,
          ),
        ));
      }
    } catch (e) {
      AppLogger.error('Failed to reply post', e);
      emit(state.copyWith(
        isReplying: false,
        errorMessage: e.toString(),
      ));
    }
  }

  /// 找回复所属的根评论 id. 用于 C2/C3/I1 中 BLoC 本地状态更新.
  /// 返回 null 表示该 reply 不在当前 visible 范围里 (理论上不该发生).
  int? _findAncestorRootId(int replyId) {
    for (final root in state.replies) {
      if (root.id == replyId) return root.id;
      for (final preview in root.previewChildren) {
        if (preview.id == replyId) return root.id;
      }
      final loaded = state.loadedChildren[root.id] ?? const <ForumReply>[];
      for (final c in loaded) {
        if (c.id == replyId) return root.id;
      }
    }
    return null;
  }

  Future<void> _onReportPost(
    ForumReportPost event,
    Emitter<ForumState> emit,
  ) async {
    try {
      await _forumRepository.reportPost(event.postId, reason: event.reason);
      // Single emit — UI is responsible for clearing reportSuccess after handling
      emit(state.copyWith(reportSuccess: true));
    } catch (e) {
      AppLogger.error('Failed to report post', e);
      emit(state.copyWith(
        errorMessage: e is AppException ? e.message : e.toString(),
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
        myPosts: event.page == 1
            ? response.posts
            : [...state.myPosts, ...response.posts],
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
        favoritedPosts: event.page == 1
            ? response.posts
            : [...state.favoritedPosts, ...response.posts],
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

  Future<void> _onDeletePost(
    ForumDeletePost event,
    Emitter<ForumState> emit,
  ) async {
    try {
      await _forumRepository.deletePost(event.postId);
      final updatedPosts =
          state.posts.where((p) => p.id != event.postId).toList();
      final updatedMyPosts =
          state.myPosts.where((p) => p.id != event.postId).toList();
      emit(state.copyWith(
        posts: updatedPosts,
        myPosts: updatedMyPosts,
        selectedPost: state.selectedPost?.id == event.postId
            ? null
            : state.selectedPost,
      ));
    } catch (e) {
      AppLogger.error('Failed to delete post', e);
      emit(state.copyWith(
        errorMessage: e is AppException ? e.message : e.toString(),
      ));
    }
  }

  Future<void> _onEditPost(
    ForumEditPost event,
    Emitter<ForumState> emit,
  ) async {
    try {
      final data = <String, dynamic>{};
      if (event.title != null) data['title'] = event.title;
      if (event.content != null) data['content'] = event.content;
      if (event.images != null) data['images'] = event.images;
      if (event.attachments != null) {
        data['attachments'] = event.attachments!.map((a) => a.toJson()).toList();
      }
      if (data.isEmpty) return;
      final updated = await _forumRepository.updatePost(event.postId, data);
      final updatedPosts = state.posts
          .map((p) => p.id == event.postId ? updated : p)
          .toList();
      emit(state.copyWith(
        posts: updatedPosts,
        selectedPost:
            state.selectedPost?.id == event.postId ? updated : state.selectedPost,
      ));
    } catch (e) {
      AppLogger.error('Failed to edit post', e);
      emit(state.copyWith(
        errorMessage: e is AppException ? e.message : e.toString(),
      ));
    }
  }

  Future<void> _onDeleteReply(
    ForumDeleteReply event,
    Emitter<ForumState> emit,
  ) async {
    try {
      await _forumRepository.deleteReply(event.replyId);
      // 展平列表中需移除该回复及其所有子回复（递归 parentReplyId 链）
      final idsToRemove = <int>{event.replyId};
      bool changed = true;
      while (changed) {
        changed = false;
        for (final r in state.replies) {
          if (r.parentReplyId != null &&
              idsToRemove.contains(r.parentReplyId) &&
              !idsToRemove.contains(r.id)) {
            idsToRemove.add(r.id);
            changed = true;
          }
        }
      }
      final updatedReplies =
          state.replies.where((r) => !idsToRemove.contains(r.id)).toList();
      final newCount = (state.selectedPost?.replyCount ?? 0) - idsToRemove.length;
      emit(state.copyWith(
        replies: updatedReplies,
        selectedPost: state.selectedPost?.copyWith(
          replyCount: newCount > 0 ? newCount : 0,
        ),
      ));
    } catch (e) {
      AppLogger.error('Failed to delete reply', e);
      emit(state.copyWith(
        errorMessage: e is AppException ? e.message : e.toString(),
      ));
    }
  }

  /// 评论点赞 — 乐观更新：先更新 UI，后端异步；失败则回滚
  Future<void> _onLikeReply(
    ForumLikeReply event,
    Emitter<ForumState> emit,
  ) async {
    final previousReplies = state.replies;
    final updatedReplies = state.replies.map((r) {
      if (r.id == event.replyId) {
        final nowLiked = !r.isLiked;
        return r.copyWith(
          likeCount: r.likeCount + (nowLiked ? 1 : -1),
          isLiked: nowLiked,
        );
      }
      return r;
    }).toList();
    emit(state.copyWith(replies: updatedReplies));

    try {
      final result = await _forumRepository.likeReply(event.replyId);
      // 用服务器返回的真实数据校正乐观更新
      final correctedReplies = state.replies.map((r) {
        if (r.id == event.replyId) {
          return r.copyWith(
            isLiked: result.liked,
            likeCount: result.likeCount,
          );
        }
        return r;
      }).toList();
      emit(state.copyWith(replies: correctedReplies));
    } catch (e) {
      AppLogger.error('Failed to like reply', e);
      emit(state.copyWith(
        replies: previousReplies,
        errorMessage: e is AppException ? e.message : e.toString(),
      ));
    }
  }

  Future<void> _onLoadFeed(ForumLoadFeed event, Emitter<ForumState> emit) async {
    emit(state.copyWith(feedStatus: ForumStatus.loading, feedItems: const []));
    try {
      final response = await _forumRepository.getSkillFeed(
        categoryId: event.categoryId,
        sortBy: event.sortBy,
      );
      emit(state.copyWith(
        feedStatus: ForumStatus.loaded,
        feedItems: response.items,
        feedHasMore: response.hasMore,
        feedPage: 1,
      ));
    } catch (e) {
      emit(state.copyWith(
        feedStatus: ForumStatus.error,
        errorMessage: e is AppException ? e.message : 'skill_feed_load_failed',
      ));
    }
  }

  Future<void> _onLoadMoreFeed(ForumLoadMoreFeed event, Emitter<ForumState> emit) async {
    if (state.isLoadingMoreFeed || !state.feedHasMore) return;
    emit(state.copyWith(isLoadingMoreFeed: true));
    try {
      final nextPage = state.feedPage + 1;
      final response = await _forumRepository.getSkillFeed(
        categoryId: event.categoryId,
        page: nextPage,
      );
      emit(state.copyWith(
        feedItems: [...state.feedItems, ...response.items],
        feedHasMore: response.hasMore,
        feedPage: nextPage,
        isLoadingMoreFeed: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingMoreFeed: false,
        errorMessage: e is AppException ? e.message : 'skill_feed_load_more_failed',
      ));
    }
  }
}
