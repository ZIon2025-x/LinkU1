part of 'user_profile_bloc.dart';

enum UserProfileStatus { initial, loading, loaded, error }

class UserProfileState extends Equatable {
  final UserProfileStatus status;
  final UserProfileSummary? summary;
  final String? errorMessage;

  const UserProfileState({
    this.status = UserProfileStatus.initial,
    this.summary,
    this.errorMessage,
  });

  UserProfileState copyWith({
    UserProfileStatus? status,
    UserProfileSummary? summary,
    String? errorMessage,
  }) {
    return UserProfileState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, summary, errorMessage];
}
