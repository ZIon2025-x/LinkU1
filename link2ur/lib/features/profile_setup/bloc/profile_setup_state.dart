part of 'profile_setup_bloc.dart';

enum ProfileSetupStatus { initial, submitting, success, error }

class ProfileSetupState extends Equatable {
  final ProfileSetupStatus status;
  final List<int> selectedCategories;
  final List<Map<String, dynamic>> selectedSkills;
  final String mode;
  final String? errorMessage;

  const ProfileSetupState({
    this.status = ProfileSetupStatus.initial,
    this.selectedCategories = const [],
    this.selectedSkills = const [],
    this.mode = 'both',
    this.errorMessage,
  });

  ProfileSetupState copyWith({
    ProfileSetupStatus? status,
    List<int>? selectedCategories,
    List<Map<String, dynamic>>? selectedSkills,
    String? mode,
    String? errorMessage,
  }) {
    return ProfileSetupState(
      status: status ?? this.status,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      selectedSkills: selectedSkills ?? this.selectedSkills,
      mode: mode ?? this.mode,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, selectedCategories, selectedSkills, mode, errorMessage];
}
