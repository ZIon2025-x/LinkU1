import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/expert_team.dart';
import '../../../data/services/storage_service.dart';

class SelectedExpertState extends Equatable {
  const SelectedExpertState({
    required this.myTeams,
    required this.currentExpertId,
  });

  final List<ExpertTeam> myTeams;
  final String currentExpertId;

  ExpertTeam get currentTeam => myTeams.firstWhere(
        (t) => t.id == currentExpertId,
        orElse: () => myTeams.first,
      );

  String get currentRole => currentTeam.myRole ?? 'member';
  bool get isOwner => currentRole == 'owner';
  bool get isAdmin => currentRole == 'admin';
  bool get isMember => currentRole == 'member';
  bool get canManage => isOwner || isAdmin;

  @override
  List<Object?> get props => [myTeams, currentExpertId];
}

class SelectedExpertCubit extends Cubit<SelectedExpertState> {
  SelectedExpertCubit({
    required List<ExpertTeam> myTeams,
    required String initialExpertId,
  }) : super(SelectedExpertState(
          myTeams: myTeams,
          currentExpertId: initialExpertId,
        ));

  Future<void> switchTo(String expertId) async {
    if (state.currentExpertId == expertId) return;
    emit(SelectedExpertState(
      myTeams: state.myTeams,
      currentExpertId: expertId,
    ));
    await StorageService.instance.setSelectedExpertId(expertId);
  }

  void refreshTeams(List<ExpertTeam> teams) {
    final keep = teams.any((t) => t.id == state.currentExpertId)
        ? state.currentExpertId
        : (teams.isNotEmpty ? teams.first.id : '');
    emit(SelectedExpertState(myTeams: teams, currentExpertId: keep));
  }
}
