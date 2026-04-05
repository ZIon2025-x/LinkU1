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

class ExpertTeamLoadServices extends ExpertTeamEvent {
  final String expertId;
  ExpertTeamLoadServices(this.expertId);
  @override
  List<Object?> get props => [expertId];
}

class ExpertTeamCreateService extends ExpertTeamEvent {
  final String expertId;
  final Map<String, dynamic> data;
  ExpertTeamCreateService({required this.expertId, required this.data});
  @override
  List<Object?> get props => [expertId];
}

class ExpertTeamDeleteService extends ExpertTeamEvent {
  final String expertId;
  final int serviceId;
  ExpertTeamDeleteService({required this.expertId, required this.serviceId});
  @override
  List<Object?> get props => [expertId, serviceId];
}

class ExpertTeamLoadFeatured extends ExpertTeamEvent {}

class ExpertTeamLoadMyFollowing extends ExpertTeamEvent {}

class ExpertTeamDissolve extends ExpertTeamEvent {
  final String expertId;
  ExpertTeamDissolve(this.expertId);
  @override
  List<Object?> get props => [expertId];
}

class ExpertTeamToggleAllowApplications extends ExpertTeamEvent {
  final String expertId;
  final bool allow;
  ExpertTeamToggleAllowApplications({required this.expertId, required this.allow});
  @override
  List<Object?> get props => [expertId, allow];
}

class ExpertTeamLoadMyInvitations extends ExpertTeamEvent {}

class ExpertTeamJoinGroupBuy extends ExpertTeamEvent {
  final int activityId;
  ExpertTeamJoinGroupBuy(this.activityId);
  @override
  List<Object?> get props => [activityId];
}

class ExpertTeamCancelGroupBuy extends ExpertTeamEvent {
  final int activityId;
  ExpertTeamCancelGroupBuy(this.activityId);
  @override
  List<Object?> get props => [activityId];
}

class ExpertTeamLoadMyPackages extends ExpertTeamEvent {}

class ExpertTeamUsePackage extends ExpertTeamEvent {
  final String expertId;
  final int packageId;
  final String? note;
  ExpertTeamUsePackage({required this.expertId, required this.packageId, this.note});
  @override
  List<Object?> get props => [expertId, packageId];
}

class ExpertTeamLoadCoupons extends ExpertTeamEvent {
  final String expertId;
  ExpertTeamLoadCoupons(this.expertId);
  @override
  List<Object?> get props => [expertId];
}

class ExpertTeamCreateCoupon extends ExpertTeamEvent {
  final String expertId;
  final Map<String, dynamic> data;
  ExpertTeamCreateCoupon({required this.expertId, required this.data});
  @override
  List<Object?> get props => [expertId];
}

class ExpertTeamDeactivateCoupon extends ExpertTeamEvent {
  final String expertId;
  final int couponId;
  ExpertTeamDeactivateCoupon({required this.expertId, required this.couponId});
  @override
  List<Object?> get props => [expertId, couponId];
}

class ExpertTeamReplyReview extends ExpertTeamEvent {
  final int reviewId;
  final String content;
  ExpertTeamReplyReview({required this.reviewId, required this.content});
  @override
  List<Object?> get props => [reviewId, content];
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
  final List<Map<String, dynamic>> services;
  final List<ExpertTeam> featuredExperts;
  final List<ExpertTeam> followingExperts;
  final List<ExpertInvitation> myInvitations;
  final List<Map<String, dynamic>> packages;
  final List<Map<String, dynamic>> coupons;
  final Map<String, dynamic>? groupBuyStatus;
  final String? errorMessage;
  final String? actionMessage;

  const ExpertTeamState({
    this.status = ExpertTeamStatus.initial,
    this.myTeams = const [],
    this.currentTeam,
    this.members = const [],
    this.myApplications = const [],
    this.joinRequests = const [],
    this.services = const [],
    this.featuredExperts = const [],
    this.followingExperts = const [],
    this.myInvitations = const [],
    this.packages = const [],
    this.coupons = const [],
    this.groupBuyStatus,
    this.errorMessage,
    this.actionMessage,
  });

  ExpertTeamState copyWith({
    ExpertTeamStatus? status,
    List<ExpertTeam>? myTeams,
    ExpertTeam? Function()? currentTeam,
    List<ExpertMember>? members,
    List<ExpertTeamApplication>? myApplications,
    List<ExpertJoinRequest>? joinRequests,
    List<Map<String, dynamic>>? services,
    List<ExpertTeam>? featuredExperts,
    List<ExpertTeam>? followingExperts,
    List<ExpertInvitation>? myInvitations,
    List<Map<String, dynamic>>? packages,
    List<Map<String, dynamic>>? coupons,
    Map<String, dynamic>? groupBuyStatus,
    String? errorMessage,
    String? actionMessage,
  }) {
    return ExpertTeamState(
      status: status ?? this.status,
      myTeams: myTeams ?? this.myTeams,
      currentTeam: currentTeam != null ? currentTeam() : this.currentTeam,
      members: members ?? this.members,
      myApplications: myApplications ?? this.myApplications,
      joinRequests: joinRequests ?? this.joinRequests,
      services: services ?? this.services,
      featuredExperts: featuredExperts ?? this.featuredExperts,
      followingExperts: followingExperts ?? this.followingExperts,
      myInvitations: myInvitations ?? this.myInvitations,
      packages: packages ?? this.packages,
      coupons: coupons ?? this.coupons,
      groupBuyStatus: groupBuyStatus,
      errorMessage: errorMessage,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [status, myTeams, currentTeam, members, myApplications, joinRequests, services, featuredExperts, followingExperts, myInvitations, packages, coupons, groupBuyStatus, errorMessage, actionMessage];
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
    on<ExpertTeamLoadServices>(_onLoadServices);
    on<ExpertTeamCreateService>(_onCreateService);
    on<ExpertTeamDeleteService>(_onDeleteService);
    on<ExpertTeamLoadFeatured>(_onLoadFeatured);
    on<ExpertTeamLoadMyFollowing>(_onLoadMyFollowing);
    on<ExpertTeamDissolve>(_onDissolve);
    on<ExpertTeamToggleAllowApplications>(_onToggleAllowApplications);
    on<ExpertTeamLoadMyInvitations>(_onLoadMyInvitations);
    on<ExpertTeamJoinGroupBuy>(_onJoinGroupBuy);
    on<ExpertTeamCancelGroupBuy>(_onCancelGroupBuy);
    on<ExpertTeamLoadMyPackages>(_onLoadMyPackages);
    on<ExpertTeamUsePackage>(_onUsePackage);
    on<ExpertTeamLoadCoupons>(_onLoadCoupons);
    on<ExpertTeamCreateCoupon>(_onCreateCoupon);
    on<ExpertTeamDeactivateCoupon>(_onDeactivateCoupon);
    on<ExpertTeamReplyReview>(_onReplyReview);
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
      emit(state.copyWith(status: ExpertTeamStatus.loaded, currentTeam: () => team));
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

  Future<void> _onLoadServices(ExpertTeamLoadServices event, Emitter<ExpertTeamState> emit) async {
    try {
      final services = await _repository.getExpertServices(event.expertId);
      emit(state.copyWith(services: services));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onCreateService(ExpertTeamCreateService event, Emitter<ExpertTeamState> emit) async {
    try {
      await _repository.createService(event.expertId, event.data);
      final services = await _repository.getExpertServices(event.expertId);
      emit(state.copyWith(services: services, actionMessage: '服务已创建'));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onDeleteService(ExpertTeamDeleteService event, Emitter<ExpertTeamState> emit) async {
    try {
      await _repository.deleteService(event.expertId, event.serviceId);
      final services = await _repository.getExpertServices(event.expertId);
      emit(state.copyWith(services: services, actionMessage: '服务已删除'));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadFeatured(ExpertTeamLoadFeatured event, Emitter<ExpertTeamState> emit) async {
    try {
      final experts = await _repository.getFeaturedExperts();
      emit(state.copyWith(featuredExperts: experts));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadMyFollowing(ExpertTeamLoadMyFollowing event, Emitter<ExpertTeamState> emit) async {
    try {
      final experts = await _repository.getMyFollowingExperts();
      emit(state.copyWith(followingExperts: experts));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onDissolve(ExpertTeamDissolve event, Emitter<ExpertTeamState> emit) async {
    try {
      await _repository.dissolveTeam(event.expertId);
      final teams = await _repository.getMyTeams();
      emit(state.copyWith(myTeams: teams, actionMessage: '达人团队已注销'));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onToggleAllowApplications(ExpertTeamToggleAllowApplications event, Emitter<ExpertTeamState> emit) async {
    try {
      final allow = await _repository.toggleAllowApplications(event.expertId, event.allow);
      emit(state.copyWith(actionMessage: allow ? '已开启申请入口' : '已关闭申请入口'));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadMyInvitations(ExpertTeamLoadMyInvitations event, Emitter<ExpertTeamState> emit) async {
    try {
      final invitations = await _repository.getMyInvitations();
      emit(state.copyWith(myInvitations: invitations));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onJoinGroupBuy(ExpertTeamJoinGroupBuy event, Emitter<ExpertTeamState> emit) async {
    try {
      final result = await _repository.joinGroupBuy(event.activityId);
      emit(state.copyWith(groupBuyStatus: result, actionMessage: '已报名拼单'));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onCancelGroupBuy(ExpertTeamCancelGroupBuy event, Emitter<ExpertTeamState> emit) async {
    try {
      final result = await _repository.cancelGroupBuy(event.activityId);
      emit(state.copyWith(groupBuyStatus: result, actionMessage: '已取消拼单'));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadMyPackages(ExpertTeamLoadMyPackages event, Emitter<ExpertTeamState> emit) async {
    try {
      final packages = await _repository.getMyPackages();
      emit(state.copyWith(packages: packages));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onUsePackage(ExpertTeamUsePackage event, Emitter<ExpertTeamState> emit) async {
    try {
      await _repository.usePackageSession(event.expertId, event.packageId, note: event.note);
      final packages = await _repository.getMyPackages();
      emit(state.copyWith(packages: packages, actionMessage: '已核销一次'));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadCoupons(ExpertTeamLoadCoupons event, Emitter<ExpertTeamState> emit) async {
    try {
      final coupons = await _repository.getExpertCoupons(event.expertId);
      emit(state.copyWith(coupons: coupons));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onCreateCoupon(ExpertTeamCreateCoupon event, Emitter<ExpertTeamState> emit) async {
    try {
      await _repository.createExpertCoupon(event.expertId, event.data);
      final coupons = await _repository.getExpertCoupons(event.expertId);
      emit(state.copyWith(coupons: coupons, actionMessage: '优惠券已创建'));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onDeactivateCoupon(ExpertTeamDeactivateCoupon event, Emitter<ExpertTeamState> emit) async {
    try {
      await _repository.deactivateExpertCoupon(event.expertId, event.couponId);
      final coupons = await _repository.getExpertCoupons(event.expertId);
      emit(state.copyWith(coupons: coupons, actionMessage: '优惠券已停用'));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onReplyReview(ExpertTeamReplyReview event, Emitter<ExpertTeamState> emit) async {
    try {
      await _repository.replyToReview(event.reviewId, event.content);
      emit(state.copyWith(actionMessage: '回复成功'));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }
}
