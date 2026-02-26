import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/leaderboard.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../../../core/utils/logger.dart';

// ==================== Events ====================

abstract class LeaderboardEvent extends Equatable {
  const LeaderboardEvent();

  @override
  List<Object?> get props => [];
}

class LeaderboardLoadRequested extends LeaderboardEvent {
  const LeaderboardLoadRequested({this.category});

  final String? category;

  @override
  List<Object?> get props => [category];
}

class LeaderboardLoadMore extends LeaderboardEvent {
  const LeaderboardLoadMore();
}

class LeaderboardRefreshRequested extends LeaderboardEvent {
  const LeaderboardRefreshRequested();
}

/// 排行榜列表关键词搜索（仅搜排行榜名称/描述）
class LeaderboardSearchChanged extends LeaderboardEvent {
  const LeaderboardSearchChanged(this.keyword);

  final String keyword;

  @override
  List<Object?> get props => [keyword];
}

class LeaderboardLoadDetail extends LeaderboardEvent {
  const LeaderboardLoadDetail(this.leaderboardId, {this.sortBy});

  final int leaderboardId;
  final String? sortBy;

  @override
  List<Object?> get props => [leaderboardId, sortBy];
}

/// 投票事件 — 支持 voteType / comment / isAnonymous
class LeaderboardVoteItem extends LeaderboardEvent {
  const LeaderboardVoteItem(
    this.itemId, {
    required this.voteType,
    this.comment,
    this.isAnonymous = false,
  });

  final int itemId;
  final String voteType; // 'upvote' or 'downvote'
  final String? comment;
  final bool isAnonymous;

  @override
  List<Object?> get props => [itemId, voteType, comment, isAnonymous];
}

/// 排序变更
class LeaderboardSortChanged extends LeaderboardEvent {
  const LeaderboardSortChanged(this.sortBy, {required this.leaderboardId});

  final String sortBy;
  final int leaderboardId;

  @override
  List<Object?> get props => [sortBy, leaderboardId];
}

/// 加载条目投票/评论列表
class LeaderboardLoadItemVotes extends LeaderboardEvent {
  const LeaderboardLoadItemVotes(this.itemId);

  final int itemId;

  @override
  List<Object?> get props => [itemId];
}

/// 点赞投票/评论
class LeaderboardLikeVote extends LeaderboardEvent {
  const LeaderboardLikeVote(this.voteId);

  final int voteId;

  @override
  List<Object?> get props => [voteId];
}

class LeaderboardApplyRequested extends LeaderboardEvent {
  const LeaderboardApplyRequested({
    required this.name,
    required this.location,
    this.description,
    this.applicationReason,
    this.coverImagePath,
  });

  final String name;
  final String location;
  final String? description;
  final String? applicationReason;
  final String? coverImagePath;

  @override
  List<Object?> get props => [name, location, description, applicationReason, coverImagePath];
}

class LeaderboardSubmitItem extends LeaderboardEvent {
  const LeaderboardSubmitItem({
    required this.leaderboardId,
    required this.name,
    this.description,
    this.address,
    this.phone,
    this.website,
    this.imagePaths,
  });

  final int leaderboardId;
  final String name;
  final String? description;
  final String? address;
  final String? phone;
  final String? website;
  final List<String>? imagePaths;

  @override
  List<Object?> get props => [leaderboardId, name, description, address, phone, website, imagePaths];
}

class LeaderboardLoadItemDetail extends LeaderboardEvent {
  const LeaderboardLoadItemDetail(this.itemId);

  final int itemId;

  @override
  List<Object?> get props => [itemId];
}

/// 收藏/取消收藏排行榜
class LeaderboardToggleFavorite extends LeaderboardEvent {
  const LeaderboardToggleFavorite(this.leaderboardId);

  final int leaderboardId;

  @override
  List<Object?> get props => [leaderboardId];
}

/// 举报排行榜
class LeaderboardReport extends LeaderboardEvent {
  const LeaderboardReport(this.leaderboardId, {required this.reason, this.description});

  final int leaderboardId;
  final String reason;
  final String? description;

  @override
  List<Object?> get props => [leaderboardId, reason, description];
}

/// 举报排行榜条目
class LeaderboardReportItem extends LeaderboardEvent {
  const LeaderboardReportItem(this.itemId, {required this.reason, this.description});

  final int itemId;
  final String reason;
  final String? description;

  @override
  List<Object?> get props => [itemId, reason, description];
}

// ==================== State ====================

enum LeaderboardStatus { initial, loading, loaded, error }

class LeaderboardState extends Equatable {
  const LeaderboardState({
    this.status = LeaderboardStatus.initial,
    this.leaderboards = const [],
    this.selectedLeaderboard,
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.hasMore = true,
    this.selectedCategory,
    this.searchKeyword = '',
    this.sortBy,
    this.errorMessage,
    this.itemDetail,
    this.itemVotes = const [],
    this.isSubmitting = false,
    this.actionMessage,
    this.isFavorited = false,
    this.reportSuccess = false,
  });

  final LeaderboardStatus status;
  final List<Leaderboard> leaderboards;
  final Leaderboard? selectedLeaderboard;
  final List<LeaderboardItem> items;
  final int total;
  final int page;
  final bool hasMore;
  final String? selectedCategory;
  final String searchKeyword;
  final String? sortBy;
  final String? errorMessage;
  final LeaderboardItem? itemDetail;
  final List<Map<String, dynamic>> itemVotes;
  final bool isSubmitting;
  final String? actionMessage;
  final bool isFavorited;
  final bool reportSuccess;

  bool get isLoading => status == LeaderboardStatus.loading;

  LeaderboardState copyWith({
    LeaderboardStatus? status,
    List<Leaderboard>? leaderboards,
    Leaderboard? selectedLeaderboard,
    List<LeaderboardItem>? items,
    int? total,
    int? page,
    bool? hasMore,
    String? selectedCategory,
    String? searchKeyword,
    String? sortBy,
    String? errorMessage,
    LeaderboardItem? itemDetail,
    List<Map<String, dynamic>>? itemVotes,
    bool? isSubmitting,
    String? actionMessage,
    bool? isFavorited,
    bool? reportSuccess,
    bool clearItemDetail = false,
  }) {
    return LeaderboardState(
      status: status ?? this.status,
      leaderboards: leaderboards ?? this.leaderboards,
      selectedLeaderboard:
          selectedLeaderboard ?? this.selectedLeaderboard,
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchKeyword: searchKeyword ?? this.searchKeyword,
      sortBy: sortBy ?? this.sortBy,
      errorMessage: errorMessage,
      itemDetail: clearItemDetail ? null : (itemDetail ?? this.itemDetail),
      itemVotes: itemVotes ?? this.itemVotes,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionMessage: actionMessage,
      isFavorited: isFavorited ?? this.isFavorited,
      reportSuccess: reportSuccess ?? this.reportSuccess,
    );
  }

  @override
  List<Object?> get props => [
        status,
        leaderboards,
        selectedLeaderboard,
        items,
        total,
        page,
        hasMore,
        selectedCategory,
        searchKeyword,
        sortBy,
        errorMessage,
        itemDetail,
        itemVotes,
        isSubmitting,
        actionMessage,
        isFavorited,
        reportSuccess,
      ];
}

// ==================== Bloc ====================

class LeaderboardBloc extends Bloc<LeaderboardEvent, LeaderboardState> {
  LeaderboardBloc({required LeaderboardRepository leaderboardRepository})
      : _leaderboardRepository = leaderboardRepository,
        super(const LeaderboardState()) {
    on<LeaderboardLoadRequested>(_onLoadRequested);
    on<LeaderboardSearchChanged>(_onSearchChanged);
    on<LeaderboardLoadMore>(_onLoadMore);
    on<LeaderboardRefreshRequested>(_onRefresh);
    on<LeaderboardLoadDetail>(_onLoadDetail);
    on<LeaderboardVoteItem>(_onVoteItem);
    on<LeaderboardSortChanged>(_onSortChanged);
    on<LeaderboardLoadItemVotes>(_onLoadItemVotes);
    on<LeaderboardLikeVote>(_onLikeVote);
    on<LeaderboardApplyRequested>(_onApplyRequested);
    on<LeaderboardSubmitItem>(_onSubmitItem);
    on<LeaderboardLoadItemDetail>(_onLoadItemDetail);
    on<LeaderboardToggleFavorite>(_onToggleFavorite);
    on<LeaderboardReport>(_onReport);
    on<LeaderboardReportItem>(_onReportItem);
  }

  final LeaderboardRepository _leaderboardRepository;

  Future<void> _onLoadRequested(
    LeaderboardLoadRequested event,
    Emitter<LeaderboardState> emit,
  ) async {
    emit(state.copyWith(
      status: LeaderboardStatus.loading,
      selectedCategory: event.category,
    ));

    final kw = state.searchKeyword.trim().isEmpty ? null : state.searchKeyword.trim();
    try {
      final response = await _leaderboardRepository.getLeaderboards(
        keyword: kw,
      );

      emit(state.copyWith(
        status: LeaderboardStatus.loaded,
        leaderboards: response.leaderboards,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));

      if (response.leaderboards.isNotEmpty) {
        await _loadLeaderboardFavoritesBatch(response.leaderboards, emit);
      }
    } catch (e) {
      AppLogger.error('Failed to load leaderboards', e);
      emit(state.copyWith(
        status: LeaderboardStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// 批量获取排行榜收藏状态并合并到列表（与论坛板块收藏一致，刷新后仍显示正确收藏状态）
  Future<void> _loadLeaderboardFavoritesBatch(
    List<Leaderboard> leaderboards,
    Emitter<LeaderboardState> emit,
  ) async {
    try {
      final ids = leaderboards.map((e) => e.id).toList();
      final favMap = await _leaderboardRepository.getFavoritesBatch(ids);
      if (emit.isDone || favMap.isEmpty) return;

      final updated = state.leaderboards.map((lb) {
        final fav = favMap[lb.id];
        return fav != null ? lb.copyWith(isFavorited: fav) : lb;
      }).toList();

      emit(state.copyWith(leaderboards: updated));
    } catch (e) {
      AppLogger.error('Failed to load leaderboard favorites batch', e);
    }
  }

  Future<void> _onSearchChanged(
    LeaderboardSearchChanged event,
    Emitter<LeaderboardState> emit,
  ) async {
    final keyword = event.keyword.trim();
    emit(state.copyWith(
      searchKeyword: event.keyword,
      status: LeaderboardStatus.loading,
    ));

    try {
      final response = await _leaderboardRepository.getLeaderboards(
        keyword: keyword.isEmpty ? null : keyword,
      );

      emit(state.copyWith(
        status: LeaderboardStatus.loaded,
        leaderboards: response.leaderboards,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
        searchKeyword: event.keyword,
      ));

      if (response.leaderboards.isNotEmpty) {
        await _loadLeaderboardFavoritesBatch(response.leaderboards, emit);
      }
    } catch (e) {
      AppLogger.error('Failed to search leaderboards', e);
      emit(state.copyWith(
        status: LeaderboardStatus.error,
        errorMessage: e.toString(),
        searchKeyword: event.keyword,
      ));
    }
  }

  Future<void> _onLoadMore(
    LeaderboardLoadMore event,
    Emitter<LeaderboardState> emit,
  ) async {
    if (!state.hasMore) return;

    try {
      final nextPage = state.page + 1;
      final kw = state.searchKeyword.trim().isEmpty ? null : state.searchKeyword.trim();
      final response = await _leaderboardRepository.getLeaderboards(
        page: nextPage,
        keyword: kw,
      );

      emit(state.copyWith(
        leaderboards: [...state.leaderboards, ...response.leaderboards],
        page: nextPage,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to load more leaderboards', e);
      emit(state.copyWith(hasMore: false));
    }
  }

  Future<void> _onRefresh(
    LeaderboardRefreshRequested event,
    Emitter<LeaderboardState> emit,
  ) async {
    try {
      final kw = state.searchKeyword.trim().isEmpty ? null : state.searchKeyword.trim();
      final response = await _leaderboardRepository.getLeaderboards(
        keyword: kw,
      );

      emit(state.copyWith(
        status: LeaderboardStatus.loaded,
        leaderboards: response.leaderboards,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));

      if (response.leaderboards.isNotEmpty) {
        await _loadLeaderboardFavoritesBatch(response.leaderboards, emit);
      }
    } catch (e) {
      AppLogger.error('Failed to refresh leaderboards', e);
    }
  }

  Future<void> _onLoadDetail(
    LeaderboardLoadDetail event,
    Emitter<LeaderboardState> emit,
  ) async {
    emit(state.copyWith(status: LeaderboardStatus.loading));

    try {
      final leaderboard = await _leaderboardRepository
          .getLeaderboardById(event.leaderboardId);
      final items = await _leaderboardRepository.getLeaderboardItems(
        event.leaderboardId,
        sortBy: event.sortBy ?? state.sortBy,
      );

      // 详情接口不返回 is_favorited，需单独拉取收藏状态
      bool isFavorited = false;
      try {
        isFavorited = await _leaderboardRepository.getFavoriteStatus(event.leaderboardId);
      } catch (_) {}

      emit(state.copyWith(
        status: LeaderboardStatus.loaded,
        selectedLeaderboard: leaderboard.copyWith(isFavorited: isFavorited),
        items: items,
        isFavorited: isFavorited,
      ));
    } catch (e) {
      AppLogger.error('Failed to load leaderboard detail', e);
      emit(state.copyWith(
        status: LeaderboardStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// 排序变更 — 重新加载 items
  Future<void> _onSortChanged(
    LeaderboardSortChanged event,
    Emitter<LeaderboardState> emit,
  ) async {
    emit(state.copyWith(sortBy: event.sortBy));

    try {
      final items = await _leaderboardRepository.getLeaderboardItems(
        event.leaderboardId,
        sortBy: event.sortBy,
      );
      emit(state.copyWith(items: items));
    } catch (e) {
      AppLogger.error('Failed to sort items', e);
    }
  }

  /// 投票 — 支持 upvote / downvote / remove + comment
  Future<void> _onVoteItem(
    LeaderboardVoteItem event,
    Emitter<LeaderboardState> emit,
  ) async {
    try {
      // 判断是否需要取消投票：再次点击同类型 → 发送 remove
      final currentItem = state.items.cast<LeaderboardItem?>().firstWhere(
            (i) => i?.id == event.itemId,
            orElse: () => state.itemDetail?.id == event.itemId
                ? state.itemDetail
                : null,
          );
      final actualVoteType =
          (currentItem?.userVote == event.voteType) ? 'remove' : event.voteType;

      await _leaderboardRepository.voteItem(
        event.itemId,
        voteType: actualVoteType,
        comment: event.comment,
        isAnonymous: event.isAnonymous,
      );

      // 乐观更新 items 列表（排行榜详情页）
      final updatedItems = state.items.map((item) {
        if (item.id == event.itemId) {
          return _applyVoteUpdate(item, event.voteType);
        }
        return item;
      }).toList();

      // 乐观更新 itemDetail（竞品详情页）
      LeaderboardItem? updatedDetail;
      if (state.itemDetail != null && state.itemDetail!.id == event.itemId) {
        updatedDetail = _applyVoteUpdate(state.itemDetail!, event.voteType);
      }

      emit(state.copyWith(
        items: updatedItems,
        itemDetail: updatedDetail ?? state.itemDetail,
      ));
    } catch (e) {
      AppLogger.error('Failed to vote', e);
      emit(state.copyWith(actionMessage: 'vote_failed'));
    }
  }

  /// 根据投票类型计算新的投票状态
  LeaderboardItem _applyVoteUpdate(LeaderboardItem item, String voteType) {
    final previousVote = item.userVote;

    if (previousVote == voteType) {
      // 取消投票（再次点同类型 = toggle off）— userVote 置 null
      return LeaderboardItem(
        id: item.id,
        leaderboardId: item.leaderboardId,
        name: item.name,
        description: item.description,
        address: item.address,
        phone: item.phone,
        website: item.website,
        images: item.images,
        submittedBy: item.submittedBy,
        submitterName: item.submitterName,
        submitterAvatar: item.submitterAvatar,
        submitterId: item.submitterId,
        status: item.status,
        upvotes: voteType == 'upvote' ? item.upvotes - 1 : item.upvotes,
        downvotes:
            voteType == 'downvote' ? item.downvotes - 1 : item.downvotes,
        netVotes: voteType == 'upvote'
            ? item.netVotes - 1
            : item.netVotes + 1,
        voteScore: item.voteScore,
        displayComment: item.displayComment,
        displayCommentType: item.displayCommentType,
        displayCommentInfo: item.displayCommentInfo,
        rank: item.rank,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      );
    } else if (previousVote != null) {
      // 切换投票方向（例 upvote → downvote）
      return LeaderboardItem(
        id: item.id,
        leaderboardId: item.leaderboardId,
        name: item.name,
        description: item.description,
        address: item.address,
        phone: item.phone,
        website: item.website,
        images: item.images,
        submittedBy: item.submittedBy,
        submitterName: item.submitterName,
        submitterAvatar: item.submitterAvatar,
        submitterId: item.submitterId,
        status: item.status,
        upvotes: voteType == 'upvote' ? item.upvotes + 1 : item.upvotes - 1,
        downvotes:
            voteType == 'downvote' ? item.downvotes + 1 : item.downvotes - 1,
        netVotes: voteType == 'upvote'
            ? item.netVotes + 2
            : item.netVotes - 2,
        voteScore: item.voteScore,
        userVote: voteType,
        displayComment: item.displayComment,
        displayCommentType: item.displayCommentType,
        displayCommentInfo: item.displayCommentInfo,
        rank: item.rank,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      );
    } else {
      // 新增投票
      return item.copyWith(
        userVote: voteType,
        upvotes: voteType == 'upvote' ? item.upvotes + 1 : item.upvotes,
        downvotes:
            voteType == 'downvote' ? item.downvotes + 1 : item.downvotes,
        netVotes: voteType == 'upvote'
            ? item.netVotes + 1
            : item.netVotes - 1,
      );
    }
  }

  /// 加载条目投票/评论列表
  Future<void> _onLoadItemVotes(
    LeaderboardLoadItemVotes event,
    Emitter<LeaderboardState> emit,
  ) async {
    try {
      final votes = await _leaderboardRepository.getItemVotes(event.itemId);
      emit(state.copyWith(itemVotes: votes));
    } catch (e) {
      AppLogger.error('Failed to load item votes', e);
    }
  }

  /// 点赞评论
  Future<void> _onLikeVote(
    LeaderboardLikeVote event,
    Emitter<LeaderboardState> emit,
  ) async {
    try {
      await _leaderboardRepository.likeVote(event.voteId);

      // 乐观更新评论列表中的点赞数
      final updatedVotes = state.itemVotes.map((vote) {
        if (vote['id'] == event.voteId) {
          final wasLiked = vote['is_liked'] == true;
          final currentLikes = (vote['like_count'] as int?) ?? 0;
          return {
            ...vote,
            'is_liked': !wasLiked,
            'like_count': wasLiked ? currentLikes - 1 : currentLikes + 1,
          };
        }
        return vote;
      }).toList();

      emit(state.copyWith(itemVotes: updatedVotes));
    } catch (e) {
      AppLogger.error('Failed to like vote', e);
    }
  }

  Future<void> _onApplyRequested(
    LeaderboardApplyRequested event,
    Emitter<LeaderboardState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));

    try {
      // 如果有封面图片，先上传获取 URL
      String? coverImageUrl;
      if (event.coverImagePath != null) {
        coverImageUrl =
            await _leaderboardRepository.uploadImage(event.coverImagePath!);
      }

      await _leaderboardRepository.applyLeaderboard(
        name: event.name,
        location: event.location,
        description: event.description,
        coverImage: coverImageUrl,
        applicationReason: event.applicationReason,
      );

      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'leaderboard_applied',
      ));
    } catch (e) {
      AppLogger.error('Failed to apply leaderboard', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSubmitItem(
    LeaderboardSubmitItem event,
    Emitter<LeaderboardState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));

    try {
      List<String>? imageUrls;
      if (event.imagePaths != null && event.imagePaths!.isNotEmpty) {
        imageUrls = [];
        for (final path in event.imagePaths!) {
          final url = await _leaderboardRepository.uploadImage(
              path, category: 'leaderboard_item');
          imageUrls.add(url);
        }
      }

      await _leaderboardRepository.submitItem(
        leaderboardId: event.leaderboardId,
        name: event.name,
        description: event.description,
        address: event.address,
        phone: event.phone,
        website: event.website,
        images: imageUrls,
      );

      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'leaderboard_submitted',
      ));
    } catch (e) {
      AppLogger.error('Failed to submit item', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'submit_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  /// 加载条目详情 — 使用 LeaderboardItem 模型
  Future<void> _onLoadItemDetail(
    LeaderboardLoadItemDetail event,
    Emitter<LeaderboardState> emit,
  ) async {
    emit(state.copyWith(status: LeaderboardStatus.loading));

    try {
      final rawDetail =
          await _leaderboardRepository.getItemDetail(event.itemId);
      final itemDetail = LeaderboardItem.fromJson(rawDetail);

      emit(state.copyWith(
        status: LeaderboardStatus.loaded,
        itemDetail: itemDetail,
      ));
    } catch (e) {
      AppLogger.error('Failed to load item detail', e);
      emit(state.copyWith(
        status: LeaderboardStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// 收藏/取消收藏 — 乐观更新 isFavorited（详情页 + 列表页卡片）
  Future<void> _onToggleFavorite(
    LeaderboardToggleFavorite event,
    Emitter<LeaderboardState> emit,
  ) async {
    final listItem = state.leaderboards.isEmpty
        ? null
        : state.leaderboards.cast<Leaderboard?>().firstWhere(
              (e) => e?.id == event.leaderboardId,
              orElse: () => null,
            );
    final previous = listItem?.isFavorited ?? state.isFavorited;

    emit(state.copyWith(
      isFavorited: !previous,
      selectedLeaderboard:
          state.selectedLeaderboard?.copyWith(isFavorited: !previous),
      leaderboards: state.leaderboards.isEmpty
          ? state.leaderboards
          : state.leaderboards
              .map((lb) =>
                  lb.id == event.leaderboardId
                      ? lb.copyWith(isFavorited: !previous)
                      : lb)
              .toList(),
    ));

    try {
      await _leaderboardRepository.toggleFavorite(event.leaderboardId);
    } catch (e) {
      AppLogger.error('Failed to toggle favorite', e);
      emit(state.copyWith(
        isFavorited: previous,
        selectedLeaderboard:
            state.selectedLeaderboard?.copyWith(isFavorited: previous),
        leaderboards: state.leaderboards.isEmpty
            ? state.leaderboards
            : state.leaderboards
                .map((lb) =>
                    lb.id == event.leaderboardId
                        ? lb.copyWith(isFavorited: previous)
                        : lb)
                .toList(),
      ));
    }
  }

  /// 举报排行榜
  Future<void> _onReport(
    LeaderboardReport event,
    Emitter<LeaderboardState> emit,
  ) async {
    try {
      await _leaderboardRepository.reportLeaderboard(
        event.leaderboardId,
        reason: event.reason,
        description: event.description,
      );
      emit(state.copyWith(reportSuccess: true));
      emit(state.copyWith(reportSuccess: false));
    } catch (e) {
      AppLogger.error('Failed to report leaderboard', e);
      emit(state.copyWith(
        errorMessage: e.toString(),
      ));
    }
  }

  /// 举报排行榜条目
  Future<void> _onReportItem(
    LeaderboardReportItem event,
    Emitter<LeaderboardState> emit,
  ) async {
    try {
      await _leaderboardRepository.reportItem(
        event.itemId,
        reason: event.reason,
        description: event.description,
      );
      emit(state.copyWith(reportSuccess: true));
      emit(state.copyWith(reportSuccess: false));
    } catch (e) {
      AppLogger.error('Failed to report leaderboard item', e);
      emit(state.copyWith(
        errorMessage: e.toString(),
      ));
    }
  }
}
