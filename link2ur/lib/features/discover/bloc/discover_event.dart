part of 'discover_bloc.dart';

abstract class DiscoverEvent extends Equatable {
  const DiscoverEvent();
  @override
  List<Object?> get props => [];
}

class DiscoverLoadRequested extends DiscoverEvent {
  const DiscoverLoadRequested();
}

class DiscoverRefreshRequested extends DiscoverEvent {
  const DiscoverRefreshRequested();
}

class DiscoverToggleFollowExpert extends DiscoverEvent {
  const DiscoverToggleFollowExpert(this.expertId);
  final String expertId;

  @override
  List<Object?> get props => [expertId];
}
