import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/user_profile_repository.dart';

part 'profile_setup_event.dart';
part 'profile_setup_state.dart';

class ProfileSetupBloc extends Bloc<ProfileSetupEvent, ProfileSetupState> {
  final UserProfileRepository repository;

  ProfileSetupBloc({required this.repository}) : super(const ProfileSetupState()) {
    on<ProfileSetupSelectCategory>(_onSelectCategory);
    on<ProfileSetupSetMode>(_onSetMode);
    on<ProfileSetupAddSkill>(_onAddSkill);
    on<ProfileSetupRemoveSkill>(_onRemoveSkill);
    on<ProfileSetupSubmit>(_onSubmit);
  }

  void _onSelectCategory(ProfileSetupSelectCategory event, Emitter<ProfileSetupState> emit) {
    final categories = List<int>.from(state.selectedCategories);
    if (categories.contains(event.categoryId)) {
      categories.remove(event.categoryId);
    } else {
      categories.add(event.categoryId);
    }
    emit(state.copyWith(selectedCategories: categories));
  }

  void _onSetMode(ProfileSetupSetMode event, Emitter<ProfileSetupState> emit) {
    emit(state.copyWith(mode: event.mode));
  }

  void _onAddSkill(ProfileSetupAddSkill event, Emitter<ProfileSetupState> emit) {
    final skills = List<Map<String, dynamic>>.from(state.selectedSkills);
    skills.add({'category_id': event.categoryId, 'skill_name': event.skillName});
    emit(state.copyWith(selectedSkills: skills));
  }

  void _onRemoveSkill(ProfileSetupRemoveSkill event, Emitter<ProfileSetupState> emit) {
    final skills = List<Map<String, dynamic>>.from(state.selectedSkills);
    skills.removeWhere((s) => s['skill_name'] == event.skillName);
    emit(state.copyWith(selectedSkills: skills));
  }

  Future<void> _onSubmit(ProfileSetupSubmit event, Emitter<ProfileSetupState> emit) async {
    emit(state.copyWith(status: ProfileSetupStatus.submitting));
    try {
      await repository.submitOnboarding(
        capabilities: state.selectedSkills,
        mode: state.mode,
        preferredCategories: state.selectedCategories,
      );
      emit(state.copyWith(status: ProfileSetupStatus.success));
    } on UserProfileException catch (e) {
      emit(state.copyWith(status: ProfileSetupStatus.error, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(status: ProfileSetupStatus.error, errorMessage: e.toString()));
    }
  }
}
