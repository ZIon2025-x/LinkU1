import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/user.dart';
import '../../../data/models/task.dart';
import '../../../data/models/forum.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../core/utils/logger.dart';

// ==================== Events ====================

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class ProfileLoadRequested extends ProfileEvent {
  const ProfileLoadRequested();
}

class ProfileUpdateRequested extends ProfileEvent {
  const ProfileUpdateRequested(this.data);

  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [data];
}

class ProfileUpdateAvatar extends ProfileEvent {
  const ProfileUpdateAvatar(this.avatarPath);

  final String avatarPath;

  @override
  List<Object?> get props => [avatarPath];
}

class ProfileUploadAvatar extends ProfileEvent {
  const ProfileUploadAvatar(this.bytes, this.filename);

  final Uint8List bytes;
  final String filename;

  @override
  List<Object?> get props => [bytes, filename];
}

class ProfileSendEmailCode extends ProfileEvent {
  const ProfileSendEmailCode(this.email);
  final String email;
  @override
  List<Object?> get props => [email];
}

class ProfileSendPhoneCode extends ProfileEvent {
  const ProfileSendPhoneCode(this.phone);
  final String phone;
  @override
  List<Object?> get props => [phone];
}

class ProfileEmailCountdownTick extends ProfileEvent {
  const ProfileEmailCountdownTick();
}

class ProfilePhoneCountdownTick extends ProfileEvent {
  const ProfilePhoneCountdownTick();
}

class ProfileLoadMyTasks extends ProfileEvent {
  const ProfileLoadMyTasks({
    this.isPosted = false,
    this.page = 1,
    this.pageSize = 20,
    this.status,
  });

  final bool isPosted;
  final int page;
  final int pageSize;
  final String? status;

  @override
  List<Object?> get props => [isPosted, page, pageSize, status];
}

class ProfileLoadPublicProfile extends ProfileEvent {
  const ProfileLoadPublicProfile(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}

class ProfileLoadMyForumPosts extends ProfileEvent {
  const ProfileLoadMyForumPosts({
    this.page = 1,
    this.pageSize = 20,
  });

  final int page;
  final int pageSize;

  @override
  List<Object?> get props => [page, pageSize];
}

class ProfileLoadMyForumActivity extends ProfileEvent {
  const ProfileLoadMyForumActivity({
    required this.type,
    this.page = 1,
    this.pageSize = 20,
  });

  final String type; // 'posts', 'favorited', 'liked'
  final int page;
  final int pageSize;

  @override
  List<Object?> get props => [type, page, pageSize];
}

class ProfileLoadPreferences extends ProfileEvent {
  const ProfileLoadPreferences();
}

class ProfileUpdatePreferences extends ProfileEvent {
  const ProfileUpdatePreferences(this.preferences);

  final Map<String, dynamic> preferences;

  @override
  List<Object?> get props => [preferences];
}

// ==================== State ====================

enum ProfileStatus { initial, loading, loaded, error }

class ProfileState extends Equatable {
  const ProfileState({
    this.status = ProfileStatus.initial,
    this.user,
    this.publicUser,
    this.publicProfileDetail,
    this.myTasks = const [],
    this.postedTasks = const [],
    this.myForumPosts = const [],
    this.favoritedPosts = const [],
    this.likedPosts = const [],
    this.preferences,
    this.errorMessage,
    this.isUpdating = false,
    this.actionMessage,
    this.myTasksPage = 1,
    this.myTasksHasMore = false,
    this.postedTasksPage = 1,
    this.postedTasksHasMore = false,
    this.forumPostsPage = 1,
    this.forumPostsHasMore = false,
    this.favoritedPostsPage = 1,
    this.favoritedPostsHasMore = false,
    this.likedPostsPage = 1,
    this.likedPostsHasMore = false,
    this.emailCountdown = 0,
    this.phoneCountdown = 0,
    this.isSendingEmailCode = false,
    this.isSendingPhoneCode = false,
    this.showEmailCodeField = false,
    this.showPhoneCodeField = false,
  });

  final ProfileStatus status;
  final User? user;
  final User? publicUser;
  final UserProfileDetail? publicProfileDetail;
  final List<Task> myTasks;
  final List<Task> postedTasks;
  final List<ForumPost> myForumPosts;
  final List<ForumPost> favoritedPosts;
  final List<ForumPost> likedPosts;
  final Map<String, dynamic>? preferences;
  final String? errorMessage;
  final bool isUpdating;
  final String? actionMessage;
  final int myTasksPage;
  final bool myTasksHasMore;
  final int postedTasksPage;
  final bool postedTasksHasMore;
  final int forumPostsPage;
  final bool forumPostsHasMore;
  final int favoritedPostsPage;
  final bool favoritedPostsHasMore;
  final int likedPostsPage;
  final bool likedPostsHasMore;
  final int emailCountdown;
  final int phoneCountdown;
  final bool isSendingEmailCode;
  final bool isSendingPhoneCode;
  final bool showEmailCodeField;
  final bool showPhoneCodeField;

  bool get isLoading => status == ProfileStatus.loading;

  ProfileState copyWith({
    ProfileStatus? status,
    User? user,
    User? publicUser,
    UserProfileDetail? publicProfileDetail,
    List<Task>? myTasks,
    List<Task>? postedTasks,
    List<ForumPost>? myForumPosts,
    List<ForumPost>? favoritedPosts,
    List<ForumPost>? likedPosts,
    Map<String, dynamic>? preferences,
    String? errorMessage,
    bool? isUpdating,
    String? actionMessage,
    int? myTasksPage,
    bool? myTasksHasMore,
    int? postedTasksPage,
    bool? postedTasksHasMore,
    int? forumPostsPage,
    bool? forumPostsHasMore,
    int? favoritedPostsPage,
    bool? favoritedPostsHasMore,
    int? likedPostsPage,
    bool? likedPostsHasMore,
    int? emailCountdown,
    int? phoneCountdown,
    bool? isSendingEmailCode,
    bool? isSendingPhoneCode,
    bool? showEmailCodeField,
    bool? showPhoneCodeField,
  }) {
    return ProfileState(
      status: status ?? this.status,
      user: user ?? this.user,
      publicUser: publicUser ?? this.publicUser,
      publicProfileDetail: publicProfileDetail ?? this.publicProfileDetail,
      myTasks: myTasks ?? this.myTasks,
      postedTasks: postedTasks ?? this.postedTasks,
      myForumPosts: myForumPosts ?? this.myForumPosts,
      favoritedPosts: favoritedPosts ?? this.favoritedPosts,
      likedPosts: likedPosts ?? this.likedPosts,
      preferences: preferences ?? this.preferences,
      errorMessage: errorMessage,
      isUpdating: isUpdating ?? this.isUpdating,
      actionMessage: actionMessage,
      myTasksPage: myTasksPage ?? this.myTasksPage,
      myTasksHasMore: myTasksHasMore ?? this.myTasksHasMore,
      postedTasksPage: postedTasksPage ?? this.postedTasksPage,
      postedTasksHasMore: postedTasksHasMore ?? this.postedTasksHasMore,
      forumPostsPage: forumPostsPage ?? this.forumPostsPage,
      forumPostsHasMore: forumPostsHasMore ?? this.forumPostsHasMore,
      favoritedPostsPage: favoritedPostsPage ?? this.favoritedPostsPage,
      favoritedPostsHasMore: favoritedPostsHasMore ?? this.favoritedPostsHasMore,
      likedPostsPage: likedPostsPage ?? this.likedPostsPage,
      likedPostsHasMore: likedPostsHasMore ?? this.likedPostsHasMore,
      emailCountdown: emailCountdown ?? this.emailCountdown,
      phoneCountdown: phoneCountdown ?? this.phoneCountdown,
      isSendingEmailCode: isSendingEmailCode ?? this.isSendingEmailCode,
      isSendingPhoneCode: isSendingPhoneCode ?? this.isSendingPhoneCode,
      showEmailCodeField: showEmailCodeField ?? this.showEmailCodeField,
      showPhoneCodeField: showPhoneCodeField ?? this.showPhoneCodeField,
    );
  }

  @override
  List<Object?> get props => [
        status,
        user,
        publicUser,
        publicProfileDetail,
        myTasks,
        postedTasks,
        myForumPosts,
        favoritedPosts,
        likedPosts,
        preferences,
        errorMessage,
        isUpdating,
        actionMessage,
        myTasksPage,
        myTasksHasMore,
        postedTasksPage,
        postedTasksHasMore,
        forumPostsPage,
        forumPostsHasMore,
        favoritedPostsPage,
        favoritedPostsHasMore,
        likedPostsPage,
        likedPostsHasMore,
        emailCountdown,
        phoneCountdown,
        isSendingEmailCode,
        isSendingPhoneCode,
        showEmailCodeField,
        showPhoneCodeField,
      ];
}

// ==================== Bloc ====================

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({
    required UserRepository userRepository,
    required TaskRepository taskRepository,
    required ForumRepository forumRepository,
  })  : _userRepository = userRepository,
        _taskRepository = taskRepository,
        _forumRepository = forumRepository,
        super(const ProfileState()) {
    on<ProfileLoadRequested>(_onLoadRequested);
    on<ProfileUpdateRequested>(_onUpdateRequested);
    on<ProfileUpdateAvatar>(_onUpdateAvatar);
    on<ProfileUploadAvatar>(_onUploadAvatar);
    on<ProfileLoadMyTasks>(_onLoadMyTasks);
    on<ProfileLoadPublicProfile>(_onLoadPublicProfile);
    on<ProfileLoadMyForumPosts>(_onLoadMyForumPosts);
    on<ProfileLoadMyForumActivity>(_onLoadMyForumActivity);
    on<ProfileLoadPreferences>(_onLoadPreferences);
    on<ProfileUpdatePreferences>(_onUpdatePreferences);
    on<ProfileSendEmailCode>(_onSendEmailCode);
    on<ProfileSendPhoneCode>(_onSendPhoneCode);
    on<ProfileEmailCountdownTick>(_onEmailCountdownTick);
    on<ProfilePhoneCountdownTick>(_onPhoneCountdownTick);
  }

  final UserRepository _userRepository;
  final TaskRepository _taskRepository;
  final ForumRepository _forumRepository;
  Timer? _emailTimer;
  Timer? _phoneTimer;

  @override
  Future<void> close() {
    _emailTimer?.cancel();
    _phoneTimer?.cancel();
    return super.close();
  }

  Future<void> _onLoadRequested(
    ProfileLoadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(status: ProfileStatus.loading));

    try {
      // 始终强制刷新，确保切换账号后不会显示旧数据
      final user = await _userRepository.getProfile(forceRefresh: true);
      emit(state.copyWith(
        status: ProfileStatus.loaded,
        user: user,
      ));
    } catch (e) {
      AppLogger.error('Failed to load profile', e);
      emit(state.copyWith(
        status: ProfileStatus.error,
        errorMessage: 'profile_load_failed',
      ));
    }
  }

  Future<void> _onUpdateRequested(
    ProfileUpdateRequested event,
    Emitter<ProfileState> emit,
  ) async {
    if (state.isUpdating) return;
    emit(state.copyWith(isUpdating: true));

    try {
      final data = event.data;
      final user = await _userRepository.updateProfile(
        name: data['name'] as String?,
        residenceCity: data['residence_city'] as String?,
        languagePreference: data['language_preference'] as String?,
        email: data['email'] as String?,
        emailVerificationCode: data['email_verification_code'] as String?,
        phone: data['phone'] as String?,
        phoneVerificationCode: data['phone_verification_code'] as String?,
      );
      emit(state.copyWith(
        user: user,
        isUpdating: false,
        actionMessage: 'profile_updated',
      ));
    } catch (e) {
      AppLogger.error('Failed to update profile', e);
      emit(state.copyWith(
        isUpdating: false,
        actionMessage: 'update_failed',
        errorMessage: 'profile_update_failed',
      ));
    }
  }

  Future<void> _onUpdateAvatar(
    ProfileUpdateAvatar event,
    Emitter<ProfileState> emit,
  ) async {
    if (state.isUpdating) return;
    emit(state.copyWith(isUpdating: true));

    try {
      final updatedUser = await _userRepository.updateAvatar(event.avatarPath);
      emit(state.copyWith(
        user: updatedUser,
        isUpdating: false,
        actionMessage: 'avatar_updated',
      ));
    } catch (e) {
      AppLogger.error('Failed to update avatar', e);
      emit(state.copyWith(
        isUpdating: false,
        actionMessage: 'update_failed',
        errorMessage: 'profile_update_avatar_failed',
      ));
    }
  }

  Future<void> _onUploadAvatar(
    ProfileUploadAvatar event,
    Emitter<ProfileState> emit,
  ) async {
    if (state.isUpdating) return;
    emit(state.copyWith(isUpdating: true));

    try {
      final updatedUser = await _userRepository.uploadAvatar(event.bytes, event.filename);
      emit(state.copyWith(
        user: updatedUser,
        isUpdating: false,
        actionMessage: 'avatar_updated',
      ));
    } catch (e) {
      AppLogger.error('Failed to upload avatar', e);
      emit(state.copyWith(
        isUpdating: false,
        actionMessage: 'upload_failed',
        errorMessage: 'profile_upload_avatar_failed',
      ));
    }
  }

  Future<void> _onLoadMyTasks(
    ProfileLoadMyTasks event,
    Emitter<ProfileState> emit,
  ) async {
    if (event.page == 1) {
      emit(state.copyWith(status: ProfileStatus.loading));
    }
    try {
      if (event.isPosted) {
        final response = await _taskRepository.getMyPostedTasks(
          page: event.page,
          pageSize: event.pageSize,
          status: event.status,
        );
        final updatedTasks = event.page == 1
            ? response.tasks
            : [...state.postedTasks, ...response.tasks];
        emit(state.copyWith(
          status: ProfileStatus.loaded,
          postedTasks: updatedTasks,
          postedTasksPage: response.page,
          postedTasksHasMore: response.hasMore,
        ));
      } else {
        final response = await _taskRepository.getMyTasks(
          page: event.page,
          pageSize: event.pageSize,
          status: event.status,
        );
        final updatedTasks = event.page == 1
            ? response.tasks
            : [...state.myTasks, ...response.tasks];
        emit(state.copyWith(
          status: ProfileStatus.loaded,
          myTasks: updatedTasks,
          myTasksPage: response.page,
          myTasksHasMore: response.hasMore,
        ));
      }
    } catch (e) {
      AppLogger.error('Failed to load my tasks', e);
      emit(state.copyWith(status: ProfileStatus.error, errorMessage: 'profile_load_tasks_failed'));
    }
  }

  Future<void> _onLoadPublicProfile(
    ProfileLoadPublicProfile event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(status: ProfileStatus.loading));

    try {
      final detail =
          await _userRepository.getPublicProfileDetail(event.userId);
      emit(state.copyWith(
        status: ProfileStatus.loaded,
        publicUser: detail.user,
        publicProfileDetail: detail,
      ));
    } catch (e) {
      AppLogger.error('Failed to load public profile', e);
      emit(state.copyWith(
        status: ProfileStatus.error,
        errorMessage: 'profile_load_public_failed',
      ));
    }
  }

  Future<void> _onLoadMyForumPosts(
    ProfileLoadMyForumPosts event,
    Emitter<ProfileState> emit,
  ) async {
    if (event.page == 1) {
      emit(state.copyWith(status: ProfileStatus.loading));
    }
    try {
      final response = await _forumRepository.getMyPosts(
        page: event.page,
        pageSize: event.pageSize,
      );
      final updatedPosts = event.page == 1
          ? response.posts
          : [...state.myForumPosts, ...response.posts];
      emit(state.copyWith(
        status: ProfileStatus.loaded,
        myForumPosts: updatedPosts,
        forumPostsPage: response.page,
        forumPostsHasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to load my forum posts', e);
      emit(state.copyWith(status: ProfileStatus.error, errorMessage: 'profile_load_forum_posts_failed'));
    }
  }

  Future<void> _onLoadMyForumActivity(
    ProfileLoadMyForumActivity event,
    Emitter<ProfileState> emit,
  ) async {
    if (event.page == 1) {
      emit(state.copyWith(status: ProfileStatus.loading));
    }
    try {
      ForumPostListResponse response;
      if (event.type == 'favorited') {
        response = await _forumRepository.getFavoritePosts(
          page: event.page,
          pageSize: event.pageSize,
        );
        final updatedPosts = event.page == 1
            ? response.posts
            : [...state.favoritedPosts, ...response.posts];
        emit(state.copyWith(
          status: ProfileStatus.loaded,
          favoritedPosts: updatedPosts,
          favoritedPostsPage: response.page,
          favoritedPostsHasMore: response.hasMore,
        ));
      } else if (event.type == 'liked') {
        response = await _forumRepository.getLikedPosts(
          page: event.page,
          pageSize: event.pageSize,
        );
        final updatedPosts = event.page == 1
            ? response.posts
            : [...state.likedPosts, ...response.posts];
        emit(state.copyWith(
          status: ProfileStatus.loaded,
          likedPosts: updatedPosts,
          likedPostsPage: response.page,
          likedPostsHasMore: response.hasMore,
        ));
      } else {
        // 'posts' - same as ProfileLoadMyForumPosts
        response = await _forumRepository.getMyPosts(
          page: event.page,
          pageSize: event.pageSize,
        );
        final updatedPosts = event.page == 1
            ? response.posts
            : [...state.myForumPosts, ...response.posts];
        emit(state.copyWith(
          status: ProfileStatus.loaded,
          myForumPosts: updatedPosts,
          forumPostsPage: response.page,
          forumPostsHasMore: response.hasMore,
        ));
      }
    } catch (e) {
      AppLogger.error('Failed to load forum activity', e);
      emit(state.copyWith(status: ProfileStatus.error, errorMessage: 'profile_load_forum_posts_failed'));
    }
  }

  Future<void> _onLoadPreferences(
    ProfileLoadPreferences event,
    Emitter<ProfileState> emit,
  ) async {
    AppLogger.info('[Preferences] _onLoadPreferences started');
    emit(state.copyWith(status: ProfileStatus.loading));
    try {
      final preferences = await _userRepository.getUserPreferences()
          .timeout(const Duration(seconds: 10));
      AppLogger.info('[Preferences] loaded successfully: $preferences');
      emit(state.copyWith(status: ProfileStatus.loaded, preferences: preferences));
    } catch (e) {
      AppLogger.error('[Preferences] failed: $e');
      // 超时或失败时使用默认空偏好，让用户可以正常使用页面
      emit(state.copyWith(
        status: ProfileStatus.loaded,
        preferences: const {
          'task_types': [],
          'locations': [],
          'task_levels': [],
          'min_deadline_days': 1,
        },
      ));
    }
  }

  Future<void> _onUpdatePreferences(
    ProfileUpdatePreferences event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(isUpdating: true));

    try {
      await _userRepository.updateUserPreferences(event.preferences);
      final updatedPreferences = await _userRepository.getUserPreferences();
      emit(state.copyWith(
        preferences: updatedPreferences,
        isUpdating: false,
        actionMessage: 'preferences_updated',
      ));
    } catch (e) {
      AppLogger.error('Failed to update preferences', e);
      emit(state.copyWith(
        isUpdating: false,
        actionMessage: 'update_failed',
        errorMessage: 'profile_update_preferences_failed',
      ));
    }
  }

  Future<void> _onSendEmailCode(
    ProfileSendEmailCode event,
    Emitter<ProfileState> emit,
  ) async {
    if (state.isSendingEmailCode) return;
    emit(state.copyWith(
      isSendingEmailCode: true,
      showEmailCodeField: true,
    ));

    try {
      await _userRepository.sendEmailUpdateCode(event.email);
      emit(state.copyWith(
        isSendingEmailCode: false,
        emailCountdown: 60,
        actionMessage: 'email_code_sent',
      ));
      _startEmailCountdown();
    } catch (e) {
      AppLogger.error('Failed to send email code', e);
      emit(state.copyWith(
        isSendingEmailCode: false,
        actionMessage: 'send_code_failed',
        errorMessage: 'profile_send_email_code_failed',
      ));
    }
  }

  Future<void> _onSendPhoneCode(
    ProfileSendPhoneCode event,
    Emitter<ProfileState> emit,
  ) async {
    if (state.isSendingPhoneCode) return;
    emit(state.copyWith(
      isSendingPhoneCode: true,
      showPhoneCodeField: true,
    ));

    try {
      await _userRepository.sendPhoneUpdateCode(event.phone);
      emit(state.copyWith(
        isSendingPhoneCode: false,
        phoneCountdown: 60,
        actionMessage: 'phone_code_sent',
      ));
      _startPhoneCountdown();
    } catch (e) {
      AppLogger.error('Failed to send phone code', e);
      emit(state.copyWith(
        isSendingPhoneCode: false,
        actionMessage: 'send_code_failed',
        errorMessage: 'profile_send_phone_code_failed',
      ));
    }
  }

  void _startEmailCountdown() {
    _emailTimer?.cancel();
    _emailTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      add(const ProfileEmailCountdownTick());
    });
  }

  void _startPhoneCountdown() {
    _phoneTimer?.cancel();
    _phoneTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      add(const ProfilePhoneCountdownTick());
    });
  }

  void _onEmailCountdownTick(
    ProfileEmailCountdownTick event,
    Emitter<ProfileState> emit,
  ) {
    final newCount = state.emailCountdown - 1;
    if (newCount <= 0) {
      _emailTimer?.cancel();
      emit(state.copyWith(emailCountdown: 0));
    } else {
      emit(state.copyWith(emailCountdown: newCount));
    }
  }

  void _onPhoneCountdownTick(
    ProfilePhoneCountdownTick event,
    Emitter<ProfileState> emit,
  ) {
    final newCount = state.phoneCountdown - 1;
    if (newCount <= 0) {
      _phoneTimer?.cancel();
      emit(state.copyWith(phoneCountdown: 0));
    } else {
      emit(state.copyWith(phoneCountdown: newCount));
    }
  }
}
