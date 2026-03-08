part of 'badges_bloc.dart';

// ==================== State ====================

enum BadgesStatus { initial, loading, loaded, error }

class BadgesState extends Equatable {
  const BadgesState({
    this.status = BadgesStatus.initial,
    this.badges = const [],
    this.errorMessage,
  });

  final BadgesStatus status;
  final List<UserBadge> badges;
  final String? errorMessage;

  bool get isLoading => status == BadgesStatus.loading;

  /// Badges that are currently displayed on user profile
  List<UserBadge> get displayedBadges =>
      badges.where((b) => b.isDisplayed).toList();

  BadgesState copyWith({
    BadgesStatus? status,
    List<UserBadge>? badges,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BadgesState(
      status: status ?? this.status,
      badges: badges ?? this.badges,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        badges,
        errorMessage,
      ];
}
