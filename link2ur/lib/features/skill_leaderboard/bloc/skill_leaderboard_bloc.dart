import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/logger.dart';
import '../../../data/models/skill_category.dart';
import '../../../data/models/skill_leaderboard_entry.dart';
import '../../../data/repositories/skill_leaderboard_repository.dart';

part 'skill_leaderboard_event.dart';
part 'skill_leaderboard_state.dart';

// ==================== Bloc ====================

class SkillLeaderboardBloc
    extends Bloc<SkillLeaderboardEvent, SkillLeaderboardState> {
  SkillLeaderboardBloc({
    required SkillLeaderboardRepository skillLeaderboardRepository,
  })  : _repository = skillLeaderboardRepository,
        super(const SkillLeaderboardState()) {
    on<LeaderboardLoadRequested>(_onLoadRequested);
    on<LeaderboardCategorySelected>(_onCategorySelected);
    on<LeaderboardMyRankRequested>(_onMyRankRequested);
  }

  final SkillLeaderboardRepository _repository;

  /// Load categories; if any exist, select the first one and load its entries
  Future<void> _onLoadRequested(
    LeaderboardLoadRequested event,
    Emitter<SkillLeaderboardState> emit,
  ) async {
    emit(state.copyWith(status: LeaderboardStatus.loading, clearError: true));

    try {
      final categoriesData = await _repository.getCategories();
      final categories =
          categoriesData.map((e) => SkillCategory.fromJson(e)).toList();

      if (categories.isEmpty) {
        emit(state.copyWith(
          status: LeaderboardStatus.loaded,
          categories: categories,
          entries: [],
          clearMyRank: true,
        ));
        return;
      }

      // Select the first category and load its entries
      final firstCategory = categories.first.nameEn;
      final entriesData = await _repository.getLeaderboard(firstCategory);
      final entries =
          entriesData.map((e) => SkillLeaderboardEntry.fromJson(e)).toList();

      // Try to fetch my rank (non-fatal if it fails)
      SkillLeaderboardEntry? myRank;
      try {
        final myRankData = await _repository.getMyRank(firstCategory);
        myRank = SkillLeaderboardEntry.fromJson(myRankData);
      } catch (_) {
        // User may not have a rank in this category
      }

      emit(state.copyWith(
        status: LeaderboardStatus.loaded,
        categories: categories,
        entries: entries,
        selectedCategory: firstCategory,
        myRank: myRank,
        clearMyRank: myRank == null,
      ));
    } catch (e) {
      AppLogger.error('Failed to load leaderboard categories', e);
      emit(state.copyWith(
        status: LeaderboardStatus.error,
        errorMessage: 'leaderboard_load_failed',
      ));
    }
  }

  /// Fetch Top 10 for the selected category and try to fetch my rank
  Future<void> _onCategorySelected(
    LeaderboardCategorySelected event,
    Emitter<SkillLeaderboardState> emit,
  ) async {
    emit(state.copyWith(
      status: LeaderboardStatus.loading,
      selectedCategory: event.category,
      clearError: true,
    ));

    try {
      final entriesData = await _repository.getLeaderboard(event.category);
      final entries =
          entriesData.map((e) => SkillLeaderboardEntry.fromJson(e)).toList();

      // Try to fetch my rank (non-fatal if it fails)
      SkillLeaderboardEntry? myRank;
      try {
        final myRankData = await _repository.getMyRank(event.category);
        myRank = SkillLeaderboardEntry.fromJson(myRankData);
      } catch (_) {
        // User may not have a rank in this category
      }

      emit(state.copyWith(
        status: LeaderboardStatus.loaded,
        entries: entries,
        myRank: myRank,
        clearMyRank: myRank == null,
      ));
    } catch (e) {
      AppLogger.error('Failed to load leaderboard for ${event.category}', e);
      emit(state.copyWith(
        status: LeaderboardStatus.error,
        errorMessage: 'leaderboard_category_load_failed',
      ));
    }
  }

  /// Fetch my rank for the given category
  Future<void> _onMyRankRequested(
    LeaderboardMyRankRequested event,
    Emitter<SkillLeaderboardState> emit,
  ) async {
    try {
      final myRankData = await _repository.getMyRank(event.category);
      final myRank = SkillLeaderboardEntry.fromJson(myRankData);

      emit(state.copyWith(myRank: myRank));
    } catch (e) {
      AppLogger.error('Failed to load my rank for ${event.category}', e);
      emit(state.copyWith(
        errorMessage: 'leaderboard_my_rank_failed',
        clearMyRank: true,
      ));
    }
  }
}
