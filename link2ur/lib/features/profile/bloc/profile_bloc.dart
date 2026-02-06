import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/user.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/task_repository.dart';
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
  const ProfileLoadMyTasks({this.isPosted = false});

  final bool isPosted;

  @override
  List<Object?> get props => [isPosted];
}

class ProfileLoadPublicProfile extends ProfileEvent {
  const ProfileLoadPublicProfile(this.userId);

  final int userId;

  @override
  List<Object?> get props => [userId];
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
    this.errorMessage,
    this.isUpdating = false,
    this.actionMessage,
  });

  final ProfileStatus status;
  final User? user;
  final User? publicUser;
  final List<Task> myTasks;
  final List<Task> postedTasks;
  final String? errorMessage;
  final bool isUpdating;
  final String? actionMessage;

  bool get isLoading => status == ProfileStatus.loading;

  ProfileState copyWith({
    ProfileStatus? status,
    User? user,
    User? publicUser,
    List<Task>? myTasks,
    List<Task>? postedTasks,
    String? errorMessage,
    bool? isUpdating,
    String? actionMessage,
  }) {
    return ProfileState(
      status: status ?? this.status,
      user: user ?? this.user,
      publicUser: publicUser ?? this.publicUser,
      myTasks: myTasks ?? this.myTasks,
      postedTasks: postedTasks ?? this.postedTasks,
      errorMessage: errorMessage,
      isUpdating: isUpdating ?? this.isUpdating,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        user,
        publicUser,
        myTasks,
        postedTasks,
        errorMessage,
        isUpdating,
        actionMessage,
      ];
}

// ==================== Bloc ====================

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({
    required UserRepository userRepository,
    required TaskRepository taskRepository,
  })  : _userRepository = userRepository,
        _taskRepository = taskRepository,
        super(const ProfileState()) {
    on<ProfileLoadRequested>(_onLoadRequested);
    on<ProfileUpdateRequested>(_onUpdateRequested);
    on<ProfileUploadAvatar>(_onUploadAvatar);
    on<ProfileLoadMyTasks>(_onLoadMyTasks);
    on<ProfileLoadPublicProfile>(_onLoadPublicProfile);
  }

  final UserRepository _userRepository;
  final TaskRepository _taskRepository;

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
      final user = await _userRepository.updateProfile(event.data);
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
      ));
    }
  }

  Future<void> _onUploadAvatar(
    ProfileUploadAvatar event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(isUpdating: true));

    try {
      final avatarUrl = await _userRepository.uploadAvatar(event.filePath);
      final updatedUser = state.user?.copyWith(avatar: avatarUrl);
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
        final response = await _taskRepository.getMyPostedTasks();
        emit(state.copyWith(postedTasks: response.tasks));
      } else {
        final response = await _taskRepository.getMyTasks();
        emit(state.copyWith(myTasks: response.tasks));
      }
    } catch (e) {
      AppLogger.error('Failed to load my tasks', e);
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
}
