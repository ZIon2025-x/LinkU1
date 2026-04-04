# 达人团队体系 Phase 1b — Flutter 前端适配

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Flutter 前端新增达人团队管理功能——申请创建团队、查看我的团队、团队详情/成员管理、邀请/加入/关注。现有达人发现/服务/面板功能不改动。

**Architecture:** 新增 `ExpertTeam` 模型（独立于现有 `TaskExpert`）、`ExpertTeamRepository`、`ExpertTeamBloc`，以及 6 个新页面。通过 `app_providers.dart` 注册，`app_router.dart` 添加路由。现有 `TaskExpert` 模型和功能保持不变，待 Phase 2 服务层改造后再统一。

**Tech Stack:** Flutter 3.33+, BLoC, Equatable, GoRouter

**Spec:** `docs/superpowers/specs/2026-04-04-expert-team-redesign.md`
**Backend:** Phase 1a 已完成，后端 API 在 `/api/experts/*`

---

## File Structure

### New Files
- `link2ur/lib/data/models/expert_team.dart` — ExpertTeam, ExpertMember, ExpertApplication 等模型
- `link2ur/lib/data/repositories/expert_team_repository.dart` — 团队管理 API 调用
- `link2ur/lib/features/expert_team/bloc/expert_team_bloc.dart` — 团队管理 BLoC（events + states 内联）
- `link2ur/lib/features/expert_team/views/my_teams_view.dart` — 我的团队列表
- `link2ur/lib/features/expert_team/views/expert_team_detail_view.dart` — 团队详情（含成员列表）
- `link2ur/lib/features/expert_team/views/expert_team_members_view.dart` — 成员管理（邀请/角色/移除）
- `link2ur/lib/features/expert_team/views/create_team_view.dart` — 申请创建团队
- `link2ur/lib/features/expert_team/views/join_requests_view.dart` — 加入申请管理
- `link2ur/lib/features/expert_team/views/my_invitations_view.dart` — 我收到的邀请

### Modified Files
- `link2ur/lib/core/constants/api_endpoints.dart` — 新增团队管理端点
- `link2ur/lib/app_providers.dart` — 注册 ExpertTeamRepository
- `link2ur/lib/core/router/app_router.dart` — 新增团队管理路由
- `link2ur/lib/core/router/app_routes.dart` — 新增路由常量

---

## Task 1: API 端点常量

**Files:**
- Modify: `link2ur/lib/core/constants/api_endpoints.dart`

- [ ] **Step 1: 添加团队管理端点常量**

在 `api_endpoints.dart` 的 `ApiEndpoints` 类中添加：

```dart
// ==================== Expert Team ====================
static const String expertTeams = '/api/experts';
static const String expertTeamApply = '/api/experts/apply';
static const String expertTeamMyApplications = '/api/experts/my-applications';
static const String expertTeamMyTeams = '/api/experts/my-teams';
static String expertTeamById(String id) => '/api/experts/$id';
static String expertTeamMembers(String id) => '/api/experts/$id/members';
static String expertTeamFollow(String id) => '/api/experts/$id/follow';
static String expertTeamInvite(String id) => '/api/experts/$id/invite';
static String expertTeamJoin(String id) => '/api/experts/$id/join';
static String expertTeamJoinRequests(String id) => '/api/experts/$id/join-requests';
static String expertTeamReviewJoinRequest(String expertId, int requestId) =>
    '/api/experts/$expertId/join-requests/$requestId';
static String expertTeamMemberRole(String expertId, String userId) =>
    '/api/experts/$expertId/members/$userId/role';
static String expertTeamTransfer(String id) => '/api/experts/$id/transfer';
static String expertTeamRemoveMember(String expertId, String userId) =>
    '/api/experts/$expertId/members/$userId';
static String expertTeamLeave(String id) => '/api/experts/$id/leave';
static String expertTeamProfileUpdateRequest(String id) =>
    '/api/experts/$id/profile-update-request';
static String expertTeamRespondInvitation(int invitationId) =>
    '/api/experts/invitations/$invitationId/respond';
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/core/constants/api_endpoints.dart
git commit -m "feat: add expert team API endpoint constants"
```

---

## Task 2: Flutter 模型

**Files:**
- Create: `link2ur/lib/data/models/expert_team.dart`

- [ ] **Step 1: 创建团队模型文件**

```dart
import 'package:equatable/equatable.dart';

/// 达人团队
class ExpertTeam extends Equatable {
  final String id;
  final String name;
  final String? nameEn;
  final String? nameZh;
  final String? bio;
  final String? bioEn;
  final String? bioZh;
  final String? avatar;
  final String status;
  final bool allowApplications;
  final int memberCount;
  final double rating;
  final int totalServices;
  final int completedTasks;
  final double completionRate;
  final bool isOfficial;
  final String? officialBadge;
  final bool stripeOnboardingComplete;
  final DateTime? createdAt;
  final bool isFollowing;
  // Detail fields
  final List<ExpertMember>? members;
  final bool? isFeatured;

  const ExpertTeam({
    required this.id,
    required this.name,
    this.nameEn,
    this.nameZh,
    this.bio,
    this.bioEn,
    this.bioZh,
    this.avatar,
    this.status = 'active',
    this.allowApplications = true,
    this.memberCount = 1,
    this.rating = 0.0,
    this.totalServices = 0,
    this.completedTasks = 0,
    this.completionRate = 0.0,
    this.isOfficial = false,
    this.officialBadge,
    this.stripeOnboardingComplete = false,
    this.createdAt,
    this.isFollowing = false,
    this.members,
    this.isFeatured,
  });

  factory ExpertTeam.fromJson(Map<String, dynamic> json) {
    return ExpertTeam(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      nameEn: json['name_en'] as String?,
      nameZh: json['name_zh'] as String?,
      bio: json['bio'] as String?,
      bioEn: json['bio_en'] as String?,
      bioZh: json['bio_zh'] as String?,
      avatar: json['avatar'] as String?,
      status: json['status'] as String? ?? 'active',
      allowApplications: json['allow_applications'] as bool? ?? true,
      memberCount: json['member_count'] as int? ?? 1,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalServices: json['total_services'] as int? ?? 0,
      completedTasks: json['completed_tasks'] as int? ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0.0,
      isOfficial: json['is_official'] as bool? ?? false,
      officialBadge: json['official_badge'] as String?,
      stripeOnboardingComplete: json['stripe_onboarding_complete'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      isFollowing: json['is_following'] as bool? ?? false,
      members: json['members'] != null
          ? (json['members'] as List).map((e) => ExpertMember.fromJson(e as Map<String, dynamic>)).toList()
          : null,
      isFeatured: json['is_featured'] as bool?,
    );
  }

  String displayName(String locale) {
    if (locale.startsWith('zh')) return nameZh ?? name;
    return nameEn ?? name;
  }

  String? displayBio(String locale) {
    if (locale.startsWith('zh')) return bioZh ?? bio;
    return bioEn ?? bio;
  }

  @override
  List<Object?> get props => [id, name, status, memberCount, rating, isFollowing];
}

/// 达人团队成员
class ExpertMember extends Equatable {
  final int id;
  final String userId;
  final String? userName;
  final String? userAvatar;
  final String role;
  final String status;
  final DateTime? joinedAt;

  const ExpertMember({
    required this.id,
    required this.userId,
    this.userName,
    this.userAvatar,
    required this.role,
    this.status = 'active',
    this.joinedAt,
  });

  factory ExpertMember.fromJson(Map<String, dynamic> json) {
    return ExpertMember(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String?,
      userAvatar: json['user_avatar'] as String?,
      role: json['role'] as String,
      status: json['status'] as String? ?? 'active',
      joinedAt: json['joined_at'] != null ? DateTime.tryParse(json['joined_at'].toString()) : null,
    );
  }

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin';
  bool get isMember => role == 'member';
  bool get canManage => role == 'owner' || role == 'admin';

  @override
  List<Object?> get props => [id, userId, role, status];
}

/// 达人创建申请
class ExpertTeamApplication extends Equatable {
  final int id;
  final String userId;
  final String expertName;
  final String? bio;
  final String? avatar;
  final String? applicationMessage;
  final String status;
  final String? reviewComment;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const ExpertTeamApplication({
    required this.id,
    required this.userId,
    required this.expertName,
    this.bio,
    this.avatar,
    this.applicationMessage,
    this.status = 'pending',
    this.reviewComment,
    this.createdAt,
    this.reviewedAt,
  });

  factory ExpertTeamApplication.fromJson(Map<String, dynamic> json) {
    return ExpertTeamApplication(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      expertName: json['expert_name'] as String,
      bio: json['bio'] as String?,
      avatar: json['avatar'] as String?,
      applicationMessage: json['application_message'] as String?,
      status: json['status'] as String? ?? 'pending',
      reviewComment: json['review_comment'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      reviewedAt: json['reviewed_at'] != null ? DateTime.tryParse(json['reviewed_at'].toString()) : null,
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  @override
  List<Object?> get props => [id, userId, status];
}

/// 加入团队请求
class ExpertJoinRequest extends Equatable {
  final int id;
  final String expertId;
  final String userId;
  final String? userName;
  final String? userAvatar;
  final String? message;
  final String status;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const ExpertJoinRequest({
    required this.id,
    required this.expertId,
    required this.userId,
    this.userName,
    this.userAvatar,
    this.message,
    this.status = 'pending',
    this.createdAt,
    this.reviewedAt,
  });

  factory ExpertJoinRequest.fromJson(Map<String, dynamic> json) {
    return ExpertJoinRequest(
      id: json['id'] as int,
      expertId: json['expert_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String?,
      userAvatar: json['user_avatar'] as String?,
      message: json['message'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      reviewedAt: json['reviewed_at'] != null ? DateTime.tryParse(json['reviewed_at'].toString()) : null,
    );
  }

  @override
  List<Object?> get props => [id, expertId, userId, status];
}

/// 团队邀请
class ExpertInvitation extends Equatable {
  final int id;
  final String expertId;
  final String inviterId;
  final String inviteeId;
  final String? inviteeName;
  final String? inviteeAvatar;
  final String status;
  final DateTime? createdAt;
  final DateTime? respondedAt;
  // 邀请列表需要显示团队信息
  final String? expertName;
  final String? expertAvatar;

  const ExpertInvitation({
    required this.id,
    required this.expertId,
    required this.inviterId,
    required this.inviteeId,
    this.inviteeName,
    this.inviteeAvatar,
    this.status = 'pending',
    this.createdAt,
    this.respondedAt,
    this.expertName,
    this.expertAvatar,
  });

  factory ExpertInvitation.fromJson(Map<String, dynamic> json) {
    return ExpertInvitation(
      id: json['id'] as int,
      expertId: json['expert_id'] as String,
      inviterId: json['inviter_id'] as String,
      inviteeId: json['invitee_id'] as String,
      inviteeName: json['invitee_name'] as String?,
      inviteeAvatar: json['invitee_avatar'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      respondedAt: json['responded_at'] != null ? DateTime.tryParse(json['responded_at'].toString()) : null,
      expertName: json['expert_name'] as String?,
      expertAvatar: json['expert_avatar'] as String?,
    );
  }

  bool get isPending => status == 'pending';

  @override
  List<Object?> get props => [id, expertId, inviteeId, status];
}
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/data/models/expert_team.dart
git commit -m "feat: add ExpertTeam, ExpertMember, ExpertInvitation Flutter models"
```

---

## Task 3: Repository

**Files:**
- Create: `link2ur/lib/data/repositories/expert_team_repository.dart`

- [ ] **Step 1: 创建团队管理 Repository**

```dart
import 'package:link2ur/core/constants/api_endpoints.dart';
import 'package:link2ur/data/models/expert_team.dart';
import 'package:link2ur/data/services/api_service.dart';

class ExpertTeamRepository {
  final ApiService _apiService;

  ExpertTeamRepository({required ApiService apiService}) : _apiService = apiService;

  // ==================== 团队发现 ====================

  Future<List<ExpertTeam>> getExperts({
    String? keyword,
    String sort = 'created_at',
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'sort': sort,
      'limit': limit,
      'offset': offset,
    };
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;

    final response = await _apiService.get(ApiEndpoints.expertTeams, queryParameters: params);
    final list = response.data as List;
    return list.map((e) => ExpertTeam.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ExpertTeam> getExpertById(String id) async {
    final response = await _apiService.get(ApiEndpoints.expertTeamById(id));
    return ExpertTeam.fromJson(response.data as Map<String, dynamic>);
  }

  // ==================== 我的团队 ====================

  Future<List<ExpertTeam>> getMyTeams() async {
    final response = await _apiService.get(ApiEndpoints.expertTeamMyTeams);
    final list = response.data as List;
    return list.map((e) => ExpertTeam.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ==================== 申请创建团队 ====================

  Future<ExpertTeamApplication> applyToCreateTeam({
    required String expertName,
    String? bio,
    String? avatar,
    String? applicationMessage,
  }) async {
    final response = await _apiService.post(ApiEndpoints.expertTeamApply, data: {
      'expert_name': expertName,
      if (bio != null) 'bio': bio,
      if (avatar != null) 'avatar': avatar,
      if (applicationMessage != null) 'application_message': applicationMessage,
    });
    return ExpertTeamApplication.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ExpertTeamApplication>> getMyApplications() async {
    final response = await _apiService.get(ApiEndpoints.expertTeamMyApplications);
    final list = response.data as List;
    return list.map((e) => ExpertTeamApplication.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ==================== 成员管理 ====================

  Future<List<ExpertMember>> getMembers(String expertId) async {
    final response = await _apiService.get(ApiEndpoints.expertTeamMembers(expertId));
    final list = response.data as List;
    return list.map((e) => ExpertMember.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> inviteMember(String expertId, String inviteeId) async {
    await _apiService.post(ApiEndpoints.expertTeamInvite(expertId), data: {
      'invitee_id': inviteeId,
    });
  }

  Future<void> respondToInvitation(int invitationId, String action) async {
    await _apiService.post(ApiEndpoints.expertTeamRespondInvitation(invitationId), data: {
      'action': action,
    });
  }

  Future<void> changeMemberRole(String expertId, String userId, String role) async {
    await _apiService.put(ApiEndpoints.expertTeamMemberRole(expertId, userId), data: {
      'role': role,
    });
  }

  Future<void> removeMember(String expertId, String userId) async {
    await _apiService.delete(ApiEndpoints.expertTeamRemoveMember(expertId, userId));
  }

  Future<void> transferOwnership(String expertId, String newOwnerId) async {
    await _apiService.post(ApiEndpoints.expertTeamTransfer(expertId), data: {
      'new_owner_id': newOwnerId,
    });
  }

  Future<void> leaveTeam(String expertId) async {
    await _apiService.post(ApiEndpoints.expertTeamLeave(expertId));
  }

  // ==================== 加入申请 ====================

  Future<void> requestToJoin(String expertId, {String? message}) async {
    await _apiService.post(ApiEndpoints.expertTeamJoin(expertId), data: {
      if (message != null) 'message': message,
    });
  }

  Future<List<ExpertJoinRequest>> getJoinRequests(String expertId, {String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;

    final response = await _apiService.get(
      ApiEndpoints.expertTeamJoinRequests(expertId),
      queryParameters: params,
    );
    final list = response.data as List;
    return list.map((e) => ExpertJoinRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> reviewJoinRequest(String expertId, int requestId, String action) async {
    await _apiService.put(
      ApiEndpoints.expertTeamReviewJoinRequest(expertId, requestId),
      data: {'action': action},
    );
  }

  // ==================== 关注 ====================

  Future<bool> toggleFollow(String expertId) async {
    final response = await _apiService.post(ApiEndpoints.expertTeamFollow(expertId));
    return response.data['following'] as bool;
  }

  // ==================== 资料修改 ====================

  Future<void> requestProfileUpdate(String expertId, {
    String? newName,
    String? newBio,
    String? newAvatar,
  }) async {
    await _apiService.post(ApiEndpoints.expertTeamProfileUpdateRequest(expertId), data: {
      if (newName != null) 'new_name': newName,
      if (newBio != null) 'new_bio': newBio,
      if (newAvatar != null) 'new_avatar': newAvatar,
    });
  }
}
```

- [ ] **Step 2: 在 app_providers.dart 注册 Repository**

在 `MultiRepositoryProvider` 的 children 列表中添加：

```dart
RepositoryProvider<ExpertTeamRepository>(
  create: (_) => ExpertTeamRepository(apiService: apiService),
),
```

需要 import：
```dart
import 'package:link2ur/data/repositories/expert_team_repository.dart';
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/data/repositories/expert_team_repository.dart link2ur/lib/app_providers.dart
git commit -m "feat: add ExpertTeamRepository with team management API methods"
```

---

## Task 4: BLoC

**Files:**
- Create: `link2ur/lib/features/expert_team/bloc/expert_team_bloc.dart`

- [ ] **Step 1: 创建团队管理 BLoC**

```dart
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
  final String action; // 'accept' or 'reject'
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
      // Reload join requests
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
      // Reload my teams
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
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/features/expert_team/bloc/expert_team_bloc.dart
git commit -m "feat: add ExpertTeamBloc with team management events and handlers"
```

---

## Task 5: 路由配置

**Files:**
- Modify: `link2ur/lib/core/router/app_routes.dart`
- Modify: `link2ur/lib/core/router/app_router.dart`

- [ ] **Step 1: 在 app_routes.dart 添加路由常量**

```dart
// Expert Team Management
static const String expertTeamMyTeams = '/expert-teams';
static const String expertTeamDetail = '/expert-teams/:id';
static const String expertTeamMembers = '/expert-teams/:id/members';
static const String expertTeamCreate = '/expert-teams/create';
static const String expertTeamJoinRequests = '/expert-teams/:id/join-requests';
static const String expertTeamInvitations = '/expert-teams/invitations';
```

- [ ] **Step 2: 在 app_router.dart 添加路由定义**

在 GoRouter 配置中添加新的路由（参照现有 task_expert_routes.dart 的模式）：

```dart
// Expert Team routes
GoRoute(
  path: AppRoutes.expertTeamMyTeams,
  builder: (context, state) => const MyTeamsView(),
),
GoRoute(
  path: AppRoutes.expertTeamCreate,
  builder: (context, state) => const CreateTeamView(),
),
GoRoute(
  path: AppRoutes.expertTeamDetail,
  builder: (context, state) {
    final id = state.pathParameters['id']!;
    return ExpertTeamDetailView(expertId: id);
  },
),
GoRoute(
  path: AppRoutes.expertTeamMembers,
  builder: (context, state) {
    final id = state.pathParameters['id']!;
    return ExpertTeamMembersView(expertId: id);
  },
),
GoRoute(
  path: AppRoutes.expertTeamJoinRequests,
  builder: (context, state) {
    final id = state.pathParameters['id']!;
    return JoinRequestsView(expertId: id);
  },
),
GoRoute(
  path: AppRoutes.expertTeamInvitations,
  builder: (context, state) => const MyInvitationsView(),
),
```

需要 import 所有新 view 文件。

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/core/router/app_routes.dart link2ur/lib/core/router/app_router.dart
git commit -m "feat: add expert team management routes"
```

---

## Task 6: View 页面 — 我的团队 + 创建团队

**Files:**
- Create: `link2ur/lib/features/expert_team/views/my_teams_view.dart`
- Create: `link2ur/lib/features/expert_team/views/create_team_view.dart`

- [ ] **Step 1: 创建"我的团队"页面**

展示用户加入的所有达人团队列表，每个卡片显示团队名称、头像、成员数、评分、用户角色（Owner/Admin/Member）。顶部有"创建团队"按钮。

关键要素：
- 使用 `BlocProvider` 在页面级创建 `ExpertTeamBloc`
- 页面加载时 dispatch `ExpertTeamLoadMyTeams`
- 列表项点击跳转 `ExpertTeamDetailView`
- 空状态引导用户创建或加入团队
- 使用 `context.l10n` 做本地化（或暂用中文硬编码，后续 l10n）

- [ ] **Step 2: 创建"申请创建团队"页面**

表单页面：团队名称（必填）、简介（选填）、头像上传（选填）、申请理由（选填）。提交后 dispatch `ExpertTeamApplyCreate`，成功后返回上一页。

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/expert_team/views/my_teams_view.dart link2ur/lib/features/expert_team/views/create_team_view.dart
git commit -m "feat: add MyTeamsView and CreateTeamView"
```

---

## Task 7: View 页面 — 团队详情 + 成员管理

**Files:**
- Create: `link2ur/lib/features/expert_team/views/expert_team_detail_view.dart`
- Create: `link2ur/lib/features/expert_team/views/expert_team_members_view.dart`

- [ ] **Step 1: 创建"团队详情"页面**

展示团队完整信息：头像、名称、简介、状态、成员列表（前几位）、统计数据（服务数、完成任务数、评分）。

操作按钮根据用户角色显示：
- 访客：关注按钮、申请加入（如果 allowApplications）
- Member：退出团队
- Admin：无额外操作（成员管理在单独页面）
- Owner：编辑信息、管理成员入口

加载时 dispatch `ExpertTeamLoadDetail`。

- [ ] **Step 2: 创建"成员管理"页面**

成员列表，每个成员显示头像、名称、角色徽章。

Owner 可见操作：
- 提升/降级角色（Admin ↔ Member）
- 移除成员
- 转让 Owner
- 邀请新成员（搜索用户 → 发送邀请）

管理加入申请入口（跳转 JoinRequestsView）。

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/expert_team/views/expert_team_detail_view.dart link2ur/lib/features/expert_team/views/expert_team_members_view.dart
git commit -m "feat: add ExpertTeamDetailView and MembersView"
```

---

## Task 8: View 页面 — 加入申请 + 我的邀请

**Files:**
- Create: `link2ur/lib/features/expert_team/views/join_requests_view.dart`
- Create: `link2ur/lib/features/expert_team/views/my_invitations_view.dart`

- [ ] **Step 1: 创建"加入申请管理"页面**

Owner/Admin 查看和处理加入申请列表。每条显示申请人头像、名称、申请理由、申请时间。操作：批准/拒绝。

加载时 dispatch `ExpertTeamLoadJoinRequests(expertId)`。

- [ ] **Step 2: 创建"我的邀请"页面**

用户查看收到的团队邀请列表。每条显示团队名称、头像、邀请人。操作：接受/拒绝。

注意：这需要一个新的后端端点 `GET /api/experts/my-invitations` 来获取当前用户收到的所有邀请。**如果后端还没有这个端点，先用空列表占位，在 repository 中标注 TODO。**

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/expert_team/views/join_requests_view.dart link2ur/lib/features/expert_team/views/my_invitations_view.dart
git commit -m "feat: add JoinRequestsView and MyInvitationsView"
```

---

## Self-Review Checklist

- [x] **Spec coverage:** 模型（ExpertTeam/ExpertMember/ExpertApplication/ExpertJoinRequest/ExpertInvitation）✅, Repository（团队CRUD/成员管理/关注/加入）✅, BLoC（15个事件处理器）✅, 路由（6条新路由）✅, 页面（6个新页面）✅
- [x] **Not in scope:** 现有达人发现/服务/面板功能不改动，Admin React 面板不改动（留到单独 task）
- [x] **Known gap:** 后端缺少 `GET /my-invitations` 端点，需要补充
- [x] **Type consistency:** ExpertTeam/ExpertMember/ExpertTeamBloc 命名全文一致
