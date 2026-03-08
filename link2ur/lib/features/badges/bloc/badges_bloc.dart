import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/logger.dart';
import '../../../data/models/badge.dart';
import '../../../data/repositories/badges_repository.dart';

part 'badges_event.dart';
part 'badges_state.dart';

// ==================== Bloc ====================

class BadgesBloc extends Bloc<BadgesEvent, BadgesState> {
  BadgesBloc({
    required BadgesRepository badgesRepository,
  })  : _repository = badgesRepository,
        super(const BadgesState()) {
    on<BadgesLoadRequested>(_onLoadRequested);
    on<BadgeDisplayToggled>(_onDisplayToggled);
  }

  final BadgesRepository _repository;

  /// Fetch all user badges
  Future<void> _onLoadRequested(
    BadgesLoadRequested event,
    Emitter<BadgesState> emit,
  ) async {
    emit(state.copyWith(status: BadgesStatus.loading, clearError: true));

    try {
      final badgesData = await _repository.getMyBadges();
      final badges =
          badgesData.map((e) => UserBadge.fromJson(e)).toList();

      emit(state.copyWith(
        status: BadgesStatus.loaded,
        badges: badges,
      ));
    } catch (e) {
      AppLogger.error('Failed to load badges', e);
      emit(state.copyWith(
        status: BadgesStatus.error,
        errorMessage: 'badges_load_failed',
      ));
    }
  }

  /// Toggle badge display, then reload badges
  Future<void> _onDisplayToggled(
    BadgeDisplayToggled event,
    Emitter<BadgesState> emit,
  ) async {
    try {
      await _repository.toggleBadgeDisplay(event.badgeId);

      // Reload badges to get updated display state
      add(const BadgesLoadRequested());
    } catch (e) {
      AppLogger.error('Failed to toggle badge display: ${event.badgeId}', e);
      emit(state.copyWith(
        errorMessage: 'badge_toggle_failed',
      ));
    }
  }
}
