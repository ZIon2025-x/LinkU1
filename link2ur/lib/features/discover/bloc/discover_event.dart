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
