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
    required this.title,
    required this.description,
    this.rules,
    this.coverImagePath,
  });

  final String title;
  final String description;
  final String? rules;
  final String? coverImagePath; // 本地图片路径，会先上传再提交

  @override
  List<Object?> get props => [title, description, rules, coverImagePath];
}

class LeaderboardSubmitItem extends LeaderboardEvent {
  const LeaderboardSubmitItem({
    required this.leaderboardId,
    required this.name,
    this.description,
    this.score,
  });

  final int leaderboardId;
  final String name;
  final String? description;
  final double? score;

  @override
  List<Object?> get props => [leaderboardId, name, description, score];
}

class LeaderboardLoadItemDetail extends LeaderboardEvent {
  const LeaderboardLoadItemDetail(this.itemId);

  final int itemId;

  @override
  List<Object?> get props => [itemId];
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
    this.sortBy,
    this.errorMessage,
    this.itemDetail,
    this.itemVotes = const [],
    this.isSubmitting = false,
    this.actionMessage,
  });

  final LeaderboardStatus status;
  final List<Leaderboard> leaderboards;
  final Leaderboard? selectedLeaderboard;
  final List<LeaderboardItem> items;
  final int total;
  final int page;
  final bool hasMore;
  final String? selectedCategory;
  final String? sortBy;
  final String? errorMessage;
  final LeaderboardItem? itemDetail;
  final List<Map<String, dynamic>> itemVotes;
  final bool isSubmitting;
  final String? actionMessage;

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
    String? sortBy,
    String? errorMessage,
    LeaderboardItem? itemDetail,
    List<Map<String, dynamic>>? itemVotes,
    bool? isSubmitting,
    String? actionMessage,
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
      sortBy: sortBy ?? this.sortBy,
      errorMessage: errorMessage,
      itemDetail: clearItemDetail ? null : (itemDetail ?? this.itemDetail),
      itemVotes: itemVotes ?? this.itemVotes,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionMessage: actionMessage,
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
        sortBy,
        errorMessage,
        itemDetail,
        itemVotes,
        isSubmitting,
        actionMessage,
      ];
}

// ==================== Bloc ====================

class LeaderboardBloc extends Bloc<LeaderboardEvent, LeaderboardState> {
  LeaderboardBloc({required LeaderboardRepository leaderboardRepository})
      : _leaderboardRepository = leaderboardRepository,
        super(const LeaderboardState()) {
    on<LeaderboardLoadRequested>(_onLoadRequested);
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

    try {
      final response = await _leaderboardRepository.getLeaderboards(
        page: 1,
        keyword: event.category,
      );

      emit(state.copyWith(
        status: LeaderboardStatus.loaded,
        leaderboards: response.leaderboards,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to load leaderboards', e);
      emit(state.copyWith(
        status: LeaderboardStatus.error,
        errorMessage: e.toString(),
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
      final response = await _leaderboardRepository.getLeaderboards(
        page: nextPage,
        keyword: state.selectedCategory,
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
      final response = await _leaderboardRepository.getLeaderboards(
        page: 1,
        keyword: state.selectedCategory,
      );

      emit(state.copyWith(
        status: LeaderboardStatus.loaded,
        leaderboards: response.leaderboards,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));
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

      emit(state.copyWith(
        status: LeaderboardStatus.loaded,
        selectedLeaderboard: leaderboard,
        items: items,
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

  /// 投票 — 支持 upvote / downvote + comment
  Future<void> _onVoteItem(
    LeaderboardVoteItem event,
    Emitter<LeaderboardState> emit,
  ) async {
    try {
      await _leaderboardRepository.voteItem(
        event.itemId,
        voteType: event.voteType,
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
      emit(state.copyWith(actionMessage: '投票失败'));
    }
  }

  /// 根据投票类型计算新的投票状态
  LeaderboardItem _applyVoteUpdate(LeaderboardItem item, String voteType) {
    final previousVote = item.userVote;

    if (previousVote == voteType) {
      // 取消投票（再次点同类型 = toggle off）
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
        status: item.status,
        upvotes: voteType == 'upvote' ? item.upvotes - 1 : item.upvotes,
        downvotes:
            voteType == 'downvote' ? item.downvotes - 1 : item.downvotes,
        netVotes: voteType == 'upvote'
            ? item.netVotes - 1
            : item.netVotes + 1,
        voteScore: item.voteScore,
        userVote: null,
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
        status: item.status,
        upvotes: voteType == 'upvote' ? item.upvotes + 1 : item.upvotes - 1,
        downvotes:
            voteType == 'downvote' ? item.downvotes + 1 : item.downvotes - 1,
        netVotes: voteType == 'upvote'
            ? item.netVotes + 2
            : item.netVotes - 2,
        voteScore: item.voteScore,
        userVote: voteType,
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
    emit(state.copyWith(isSubmitting: true, actionMessage: null));

    try {
      // 如果有封面图片，先上传获取 URL
      String? coverImageUrl;
      if (event.coverImagePath != null) {
        coverImageUrl =
            await _leaderboardRepository.uploadImage(event.coverImagePath!);
      }

      await _leaderboardRepository.applyLeaderboard(
        title: event.title,
        description: event.description,
        rules: event.rules,
        coverImage: coverImageUrl,
      );

      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '申请已提交',
      ));
    } catch (e) {
      AppLogger.error('Failed to apply leaderboard', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '申请失败: ${e.toString()}',
      ));
    }
  }

  Future<void> _onSubmitItem(
    LeaderboardSubmitItem event,
    Emitter<LeaderboardState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, actionMessage: null));

    try {
      await _leaderboardRepository.submitItem(
        leaderboardId: event.leaderboardId,
        name: event.name,
        description: event.description,
        score: event.score,
      );

      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '提交成功',
      ));
    } catch (e) {
      AppLogger.error('Failed to submit item', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '提交失败: ${e.toString()}',
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
}
