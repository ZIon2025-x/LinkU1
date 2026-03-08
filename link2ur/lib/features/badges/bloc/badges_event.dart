part of 'badges_bloc.dart';

// ==================== Events ====================

abstract class BadgesEvent extends Equatable {
  const BadgesEvent();

  @override
  List<Object?> get props => [];
}

/// Load my badges
class BadgesLoadRequested extends BadgesEvent {
  const BadgesLoadRequested();
}

/// Toggle badge display on/off
class BadgeDisplayToggled extends BadgesEvent {
  final int badgeId;
  const BadgeDisplayToggled(this.badgeId);

  @override
  List<Object?> get props => [badgeId];
}
