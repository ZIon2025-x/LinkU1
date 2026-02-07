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

class ProfileUploadAvatar extends ProfileEvent {
  const ProfileUploadAvatar(this.filePath);

  final String filePath;

  @override
  List<Object?> get props => [filePath];
}

class ProfileLoadMyTasks extends ProfileEvent {
  const ProfileLoadMyTasks({
    this.isPosted = false,
    this.page = 1,
    this.pageSize = 20,
  });

  final bool isPosted;
  final int page;
  final int pageSize;

  @override
  List<Object?> get props => [isPosted, page, pageSize];
}

class ProfileLoadPublicProfile extends ProfileEvent {
  const ProfileLoadPublicProfile(this.userId);

  final int userId;

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
    this.myTasks = const [],
    this.postedTasks = const [],
    this.myForumPosts = const [],
    this.favoritedPosts = const [],
    this.likedPosts = const [],
    this.preferences,
    this.errorMessage,
    this.isUpdating = false,
    this.actionMessage,
    // Pagination for tasks
    this.myTasksPage = 1,
    this.myTasksHasMore = false,
    this.postedTasksPage = 1,
    this.postedTasksHasMore = false,
    // Pagination for forum posts
    this.forumPostsPage = 1,
    this.forumPostsHasMore = false,
  });

  final ProfileStatus status;
  final User? user;
  final User? publicUser;
  final List<Task> myTasks;
  final List<Task> postedTasks;
  final List<ForumPost> myForumPosts;
  final List<ForumPost> favoritedPosts;
  final List<ForumPost> likedPosts;
  final Map<String, dynamic>? preferences;
  final String? errorMessage;
  final bool isUpdating;
  final String? actionMessage;
  // Pagination for tasks
  final int myTasksPage;
  final bool myTasksHasMore;
  final int postedTasksPage;
  final bool postedTasksHasMore;
  // Pagination for forum posts
  final int forumPostsPage;
  final bool forumPostsHasMore;

  bool get isLoading => status == ProfileStatus.loading;

  ProfileState copyWith({
    ProfileStatus? status,
    User? user,
    User? publicUser,
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
  }) {
    return ProfileState(
      status: status ?? this.status,
      user: user ?? this.user,
      publicUser: publicUser ?? this.publicUser,
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
    );
  }

  @override
  List<Object?> get props => [
        status,
        user,
        publicUser,
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
    on<ProfileUploadAvatar>(_onUploadAvatar);
    on<ProfileLoadMyTasks>(_onLoadMyTasks);
    on<ProfileLoadPublicProfile>(_onLoadPublicProfile);
    on<ProfileLoadMyForumPosts>(_onLoadMyForumPosts);
    on<ProfileLoadMyForumActivity>(_onLoadMyForumActivity);
    on<ProfileLoadPreferences>(_onLoadPreferences);
    on<ProfileUpdatePreferences>(_onUpdatePreferences);
  }

  final UserRepository _userRepository;
  final TaskRepository _taskRepository;
  final ForumRepository _forumRepository;

  Future<void> _onLoadRequested(
    ProfileLoadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(status: ProfileStatus.loading));

    try {
      final user = await _userRepository.getProfile();
      emit(state.copyWith(
        status: ProfileStatus.loaded,
        user: user,
      ));
    } catch (e) {
      AppLogger.error('Failed to load profile', e);
      emit(state.copyWith(
        status: ProfileStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onUpdateRequested(
    ProfileUpdateRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(isUpdating: true));

    try {
      final data = event.data;
      final user = await _userRepository.updateProfile(
        name: data['name'] as String?,
        bio: data['bio'] as String?,
        residenceCity: data['residence_city'] as String?,
        languagePreference: data['language_preference'] as String?,
        avatar: data['avatar'] as String?,
      );
      emit(state.copyWith(
        user: user,
        isUpdating: false,
        actionMessage: '资料已更新',
      ));
    } catch (e) {
      AppLogger.error('Failed to update profile', e);
      emit(state.copyWith(
        isUpdating: false,
        actionMessage: '更新失败',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onUploadAvatar(
    ProfileUploadAvatar event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(isUpdating: true));

    try {
      final updatedUser = await _userRepository.uploadAvatar(event.filePath);
      emit(state.copyWith(
        user: updatedUser,
        isUpdating: false,
        actionMessage: '头像已更新',
      ));
    } catch (e) {
      AppLogger.error('Failed to upload avatar', e);
      emit(state.copyWith(
        isUpdating: false,
        actionMessage: '上传失败',
      ));
    }
  }

  Future<void> _onLoadMyTasks(
    ProfileLoadMyTasks event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      if (event.isPosted) {
        final response = await _taskRepository.getMyPostedTasks(
          page: event.page,
          pageSize: event.pageSize,
        );
        final updatedTasks = event.page == 1
            ? response.tasks
            : [...state.postedTasks, ...response.tasks];
        emit(state.copyWith(
          postedTasks: updatedTasks,
          postedTasksPage: response.page,
          postedTasksHasMore: response.hasMore,
        ));
      } else {
        final response = await _taskRepository.getMyTasks(
          page: event.page,
          pageSize: event.pageSize,
        );
        final updatedTasks = event.page == 1
            ? response.tasks
            : [...state.myTasks, ...response.tasks];
        emit(state.copyWith(
          myTasks: updatedTasks,
          myTasksPage: response.page,
          myTasksHasMore: response.hasMore,
        ));
      }
    } catch (e) {
      AppLogger.error('Failed to load my tasks', e);
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadPublicProfile(
    ProfileLoadPublicProfile event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(status: ProfileStatus.loading));

    try {
      final user =
          await _userRepository.getUserPublicProfile(event.userId);
      emit(state.copyWith(
        status: ProfileStatus.loaded,
        publicUser: user,
      ));
    } catch (e) {
      AppLogger.error('Failed to load public profile', e);
      emit(state.copyWith(
        status: ProfileStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadMyForumPosts(
    ProfileLoadMyForumPosts event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      final response = await _forumRepository.getMyPosts(
        page: event.page,
        pageSize: event.pageSize,
      );
      final updatedPosts = event.page == 1
          ? response.posts
          : [...state.myForumPosts, ...response.posts];
      emit(state.copyWith(
        myForumPosts: updatedPosts,
        forumPostsPage: response.page,
        forumPostsHasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to load my forum posts', e);
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadMyForumActivity(
    ProfileLoadMyForumActivity event,
    Emitter<ProfileState> emit,
  ) async {
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
          favoritedPosts: updatedPosts,
          forumPostsPage: response.page,
          forumPostsHasMore: response.hasMore,
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
          likedPosts: updatedPosts,
          forumPostsPage: response.page,
          forumPostsHasMore: response.hasMore,
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
          myForumPosts: updatedPosts,
          forumPostsPage: response.page,
          forumPostsHasMore: response.hasMore,
        ));
      }
    } catch (e) {
      AppLogger.error('Failed to load forum activity', e);
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadPreferences(
    ProfileLoadPreferences event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      final preferences = await _userRepository.getUserPreferences();
      emit(state.copyWith(preferences: preferences));
    } catch (e) {
      AppLogger.error('Failed to load preferences', e);
      emit(state.copyWith(errorMessage: e.toString()));
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
        actionMessage: '偏好设置已更新',
      ));
    } catch (e) {
      AppLogger.error('Failed to update preferences', e);
      emit(state.copyWith(
        isUpdating: false,
        actionMessage: '更新失败',
      ));
    }
  }
}
