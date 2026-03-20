part of 'user_profile_bloc.dart';

abstract class UserProfileEvent extends Equatable {
  const UserProfileEvent();
  @override
  List<Object?> get props => [];
}

class UserProfileLoadSummary extends UserProfileEvent {
  const UserProfileLoadSummary();
}

class UserProfileUpdateCapabilities extends UserProfileEvent {
  final List<Map<String, dynamic>> capabilities;
  const UserProfileUpdateCapabilities({required this.capabilities});
  @override
  List<Object?> get props => [capabilities];
}

class UserProfileDeleteCapability extends UserProfileEvent {
  final int capabilityId;
  const UserProfileDeleteCapability({required this.capabilityId});
  @override
  List<Object?> get props => [capabilityId];
}

class UserProfileUpdatePreferences extends UserProfileEvent {
  final Map<String, dynamic> preferences;
  const UserProfileUpdatePreferences({required this.preferences});
  @override
  List<Object?> get props => [preferences];
}
