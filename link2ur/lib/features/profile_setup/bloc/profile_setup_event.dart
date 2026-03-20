part of 'profile_setup_bloc.dart';

abstract class ProfileSetupEvent extends Equatable {
  const ProfileSetupEvent();
  @override
  List<Object?> get props => [];
}

class ProfileSetupSelectCategory extends ProfileSetupEvent {
  final int categoryId;
  const ProfileSetupSelectCategory({required this.categoryId});
  @override
  List<Object?> get props => [categoryId];
}

class ProfileSetupSetMode extends ProfileSetupEvent {
  final String mode;
  const ProfileSetupSetMode({required this.mode});
  @override
  List<Object?> get props => [mode];
}

class ProfileSetupAddSkill extends ProfileSetupEvent {
  final int categoryId;
  final String skillName;
  const ProfileSetupAddSkill({required this.categoryId, required this.skillName});
  @override
  List<Object?> get props => [categoryId, skillName];
}

class ProfileSetupRemoveSkill extends ProfileSetupEvent {
  final String skillName;
  const ProfileSetupRemoveSkill({required this.skillName});
  @override
  List<Object?> get props => [skillName];
}

class ProfileSetupSubmit extends ProfileSetupEvent {
  const ProfileSetupSubmit();
}
