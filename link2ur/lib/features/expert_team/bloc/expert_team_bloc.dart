import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:link2ur/data/models/expert_team.dart';
import 'package:link2ur/data/repositories/expert_team_repository.dart';

// ==================== Events ====================

abstract class ExpertTeamEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class ExpertTeamLoadMyTeams extends ExpertTeamEvent {}

class ExpertTeamLoadDetail extends ExpertTeamEvent {
  final String expertId;
  ExpertTeamLoadDetail(this.expertId);
  @override
  List<Object?> get props => [expertId];
}

class ExpertTeamLoadMembers extends ExpertTeamEvent {
  final String expertId;
  ExpertTeamLoadMembers(this.expertId);
  @override
  List<Object?> get props => [expertId];
}

class ExpertTeamApplyCreate extends ExpertTeamEvent {
  final String expertName;
  final String? bio;
  final String? avatar;
  final String? message;
  ExpertTeamApplyCreate({required this.expertName, this.bio, this.avatar, this.message});
  @override
  List<Object?> get props => [expertName];
}

class ExpertTeamLoadMyApplications extends ExpertTeamEvent {}

class ExpertTeamInviteMember extends ExpertTeamEvent {
  final String expertId;
  final String inviteeId;
  ExpertTeamInviteMember({required this.expertId, required this.inviteeId});
  @override
  List<Object?> get props => [expertId, inviteeId];
}

class ExpertTeamRespondInvitation extends ExpertTeamEvent {
  final int invitationId;
  final String action;
  ExpertTeamRespondInvitation({required this.invitationId, required this.action});
  @override
  List<Object?> get props => [invitationId, action];
}

class ExpertTeamRequestJoin extends ExpertTeamEvent {
  final String expertId;
  final String? message;
  ExpertTeamRequestJoin({required this.expertId, this.message});
  @override
  List<Object?> get props => [expertId];
}

class ExpertTeamLoadJoinRequests extends ExpertTeamEvent {
  final String expertId;
  ExpertTeamLoadJoinRequests(this.expertId);
  @override
  List<Object?> get props => [expertId];
}

class ExpertTeamReviewJoinRequest extends ExpertTeamEvent {
  final String expertId;
  final int requestId;
  final String action;
  ExpertTeamReviewJoinRequest({required this.expertId, required this.requestId, required this.action});
  @override
  List<Object?> get props => [expertId, requestId, action];
}

class ExpertTeamChangeMemberRole extends ExpertTeamEvent {
  final String expertId;
  final String userId;
  final String role;
  ExpertTeamChangeMemberRole({required this.expertId, required this.userId, required this.role});
  @override
  List<Object?> get props => [expertId, userId, role];
}

class ExpertTeamRemoveMember extends ExpertTeamEvent {
  final String expertId;
  final String userId;
  ExpertTeamRemoveMember({required this.expertId, required this.userId});
  @override
  List<Object?> get props => [expertId, userId];
}

class ExpertTeamTransferOwnership extends ExpertTeamEvent {
  final String expertId;
  final String newOwnerId;
  ExpertTeamTransferOwnership({required this.expertId, required this.newOwnerId});
  @override
  List<Object?> get props => [expertId, newOwnerId];
}

class ExpertTeamLeave extends ExpertTeamEvent {
  final String expertId;
  ExpertTeamLeave(this.expertId);
  @override
  List<Object?> get props => [expertId];
}

class ExpertTeamToggleFollow extends ExpertTeamEvent {
  final String expertId;
  ExpertTeamToggleFollow(this.expertId);
  @override
  List<Object?> get props => [expertId];
}

// ==================== State ====================

enum ExpertTeamStatus { initial, loading, loaded, error }

class ExpertTeamState extends Equatable {
  final ExpertTeamStatus status;
  final List<ExpertTeam> myTeams;
  final ExpertTeam? currentTeam;
  final List<ExpertMember> members;
  final List<ExpertTeamApplication> myApplications;
  final List<ExpertJoinRequest> joinRequests;
  final String? errorMessage;
  final String? actionMessage;

  const ExpertTeamState({
    this.status = ExpertTeamStatus.initial,
    this.myTeams = const [],
    this.currentTeam,
    this.members = const [],
    this.myApplications = const [],
    this.joinRequests = const [],
    this.errorMessage,
    this.actionMessage,
  });

  ExpertTeamState copyWith({
    ExpertTeamStatus? status,
    List<ExpertTeam>? myTeams,
    ExpertTeam? currentTeam,
    List<ExpertMember>? members,
    List<ExpertTeamApplication>? myApplications,
    List<ExpertJoinRequest>? joinRequests,
    String? errorMessage,
    String? actionMessage,
  }) {
    return ExpertTeamState(
      status: status ?? this.status,
      myTeams: myTeams ?? this.myTeams,
      currentTeam: currentTeam ?? this.currentTeam,
      members: members ?? this.members,
      myApplications: myApplications ?? this.myApplications,
      joinRequests: joinRequests ?? this.joinRequests,
      errorMessage: errorMessage,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [status, myTeams, currentTeam, members, myApplications, joinRequests, errorMessage, actionMessage];
}

// ==================== BLoC ====================

class ExpertTeamBloc extends Bloc<ExpertTeamEvent, ExpertTeamState> {
  final ExpertTeamRepository _repository;

  ExpertTeamBloc({required ExpertTeamRepository repository})
      : _repository = repository,
        super(const ExpertTeamState()) {
    on<ExpertTeamLoadMyTeams>(_onLoadMyTeams);
    on<ExpertTeamLoadDetail>(_onLoadDetail);
    on<ExpertTeamLoadMembers>(_onLoadMembers);
    on<ExpertTeamApplyCreate>(_onApplyCreate);
    on<ExpertTeamLoadMyApplications>(_onLoadMyApplications);
    on<ExpertTeamInviteMember>(_onInviteMember);
    on<ExpertTeamRespondInvitation>(_onRespondInvitation);
    on<ExpertTeamRequestJoin>(_onRequestJoin);
    on<ExpertTeamLoadJoinRequests>(_onLoadJoinRequests);
    on<ExpertTeamReviewJoinRequest>(_onReviewJoinRequest);
    on<ExpertTeamChangeMemberRole>(_onChangeMemberRole);
    on<ExpertTeamRemoveMember>(_onRemoveMember);
    on<ExpertTeamTransferOwnership>(_onTransferOwnership);
    on<ExpertTeamLeave>(_onLeave);
    on<ExpertTeamToggleFollow>(_onToggleFollow);
  }

  Future<void> _onLoadMyTeams(ExpertTeamLoadMyTeams event, Emitter<ExpertTeamState> emit) async {
    emit(state.copyWith(status: ExpertTeamStatus.loading));
    try {
      final teams = await _repository.getMyTeams();
      emit(state.copyWith(status: ExpertTeamStatus.loaded, myTeams: teams));
    } catch (e) {
      emit(state.copyWith(status: ExpertTeamStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadDetail(ExpertTeamLoadDetail event, Emitter<ExpertTeamState> emit) async {
    emit(state.copyWith(status: ExpertTeamStatus.loading));
    try {
      final team = await _repository.getExpertById(event.expertId);
      emit(state.copyWith(status: ExpertTeamStatus.loaded, currentTeam: team));
    } catch (e) {
      emit(state.copyWith(status: ExpertTeamStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadMembers(ExpertTeamLoadMembers event, Emitter<ExpertTeamState> emit) async {
    try {
      final members = await _repository.getMembers(event.expertId);
      emit(state.copyWith(members: members));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onApplyCreate(ExpertTeamApplyCreate event, Emitter<ExpertTeamState> emit) async {
    emit(state.copyWith(status: ExpertTeamStatus.loading));
    try {
      await _repository.applyToCreateTeam(
        expertName: event.expertName,
        bio: event.bio,
        avatar: event.avatar,
        applicationMessage: event.message,
      );
      emit(state.copyWith(status: ExpertTeamStatus.loaded, actionMessage: '申请已提交'));
    } catch (e) {
      emit(state.copyWith(status: ExpertTeamStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadMyApplications(ExpertTeamLoadMyApplications event, Emitter<ExpertTeamState> emit) async {
    try {
      final apps = await _repository.getMyApplications();
      emit(state.copyWith(myApplications: apps));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onInviteMember(ExpertTeamInviteMember event, Emitter<ExpertTeamState> emit) async {
    try {
      await _repository.inviteMember(event.expertId, event.inviteeId);
      emit(state.copyWith(actionMessage: '邀请已发送'));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onRespondInvitation(ExpertTeamRespondInvitation event, Emitter<ExpertTeamState> emit) async {
    try {
      await _repository.respondToInvitation(event.invitationId, event.action);
      final msg = event.action == 'accept' ? '已加入团队' : '已拒绝邀请';
      emit(state.copyWith(actionMessage: msg));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onRequestJoin(ExpertTeamRequestJoin event, Emitter<ExpertTeamState> emit) async {
    try {
      await _repository.requestToJoin(event.expertId, message: event.message);
      emit(state.copyWith(actionMessage: '申请已提交'));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadJoinRequests(ExpertTeamLoadJoinRequests event, Emitter<ExpertTeamState> emit) async {
    try {
      final requests = await _repository.getJoinRequests(event.expertId);
      emit(state.copyWith(joinRequests: requests));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onReviewJoinRequest(ExpertTeamReviewJoinRequest event, Emitter<ExpertTeamState> emit) async {
    try {
      await _repository.reviewJoinRequest(event.expertId, event.requestId, event.action);
      final requests = await _repository.getJoinRequests(event.expertId);
      emit(state.copyWith(joinRequests: requests, actionMessage: event.action == 'approve' ? '已批准' : '已拒绝'));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onChangeMemberRole(ExpertTeamChangeMemberRole event, Emitter<ExpertTeamState> emit) async {
    try {
      await _repository.changeMemberRole(event.expertId, event.userId, event.role);
      final members = await _repository.getMembers(event.expertId);
      emit(state.copyWith(members: members, actionMessage: '角色已更新'));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onRemoveMember(ExpertTeamRemoveMember event, Emitter<ExpertTeamState> emit) async {
    try {
      await _repository.removeMember(event.expertId, event.userId);
      final members = await _repository.getMembers(event.expertId);
      emit(state.copyWith(members: members, actionMessage: '成员已移除'));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onTransferOwnership(ExpertTeamTransferOwnership event, Emitter<ExpertTeamState> emit) async {
    try {
      await _repository.transferOwnership(event.expertId, event.newOwnerId);
      emit(state.copyWith(actionMessage: '所有权已转让'));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onLeave(ExpertTeamLeave event, Emitter<ExpertTeamState> emit) async {
    try {
      await _repository.leaveTeam(event.expertId);
      final teams = await _repository.getMyTeams();
      emit(state.copyWith(myTeams: teams, actionMessage: '已离开团队'));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onToggleFollow(ExpertTeamToggleFollow event, Emitter<ExpertTeamState> emit) async {
    try {
      final following = await _repository.toggleFollow(event.expertId);
      final msg = following ? '已关注' : '已取消关注';
      emit(state.copyWith(actionMessage: msg));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }
}
