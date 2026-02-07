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
  const LeaderboardLoadDetail(this.leaderboardId);

  final int leaderboardId;

  @override
  List<Object?> get props => [leaderboardId];
}

class LeaderboardVoteItem extends LeaderboardEvent {
  const LeaderboardVoteItem(this.itemId);

  final int itemId;

  @override
  List<Object?> get props => [itemId];
}

class LeaderboardApplyRequested extends LeaderboardEvent {
  const LeaderboardApplyRequested({
    required this.title,
    required this.description,
    this.rules,
  });

  final String title;
  final String description;
  final String? rules;

  @override
  List<Object?> get props => [title, description, rules];
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
    this.errorMessage,
    this.itemDetail,
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
  final String? errorMessage;
  final Map<String, dynamic>? itemDetail;
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
    String? errorMessage,
    Map<String, dynamic>? itemDetail,
    bool? isSubmitting,
    String? actionMessage,
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
      errorMessage: errorMessage,
      itemDetail: itemDetail,
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
        errorMessage,
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
      final items = await _leaderboardRepository
          .getLeaderboardItems(event.leaderboardId);

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

  Future<void> _onVoteItem(
    LeaderboardVoteItem event,
    Emitter<LeaderboardState> emit,
  ) async {
    try {
      await _leaderboardRepository.voteItem(event.itemId, voteType: 'upvote');

      // 更新本地状态
      final updatedItems = state.items.map((item) {
        if (item.id == event.itemId) {
          final wasVoted = item.hasVoted;
          return item.copyWith(
            userVote: wasVoted ? null : 'upvote',
            upvotes: wasVoted ? item.upvotes - 1 : item.upvotes + 1,
            netVotes: wasVoted ? item.netVotes - 1 : item.netVotes + 1,
          );
        }
        return item;
      }).toList();

      emit(state.copyWith(items: updatedItems));
    } catch (e) {
      AppLogger.error('Failed to vote', e);
    }
  }

  Future<void> _onApplyRequested(
    LeaderboardApplyRequested event,
    Emitter<LeaderboardState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, actionMessage: null));

    try {
      await _leaderboardRepository.applyLeaderboard(
        title: event.title,
        description: event.description,
        rules: event.rules,
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

  Future<void> _onLoadItemDetail(
    LeaderboardLoadItemDetail event,
    Emitter<LeaderboardState> emit,
  ) async {
    emit(state.copyWith(status: LeaderboardStatus.loading));

    try {
      final itemDetail =
          await _leaderboardRepository.getItemDetail(event.itemId);

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
