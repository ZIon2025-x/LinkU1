import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../../../data/services/storage_service.dart';

part 'user_profile_event.dart';
part 'user_profile_state.dart';

class UserProfileBloc extends Bloc<UserProfileEvent, UserProfileState> {
  final UserProfileRepository repository;

  UserProfileBloc({required this.repository}) : super(const UserProfileState()) {
    on<UserProfileLoadSummary>(_onLoadSummary);
    on<UserProfileUpdateCapabilities>(_onUpdateCapabilities);
    on<UserProfileDeleteCapability>(_onDeleteCapability);
    on<UserProfileUpdatePreferences>(_onUpdatePreferences);
  }

  Future<void> _onLoadSummary(
    UserProfileLoadSummary event,
    Emitter<UserProfileState> emit,
  ) async {
    emit(state.copyWith(status: UserProfileStatus.loading));
    try {
      final summary = await repository.getSummary();
      emit(state.copyWith(status: UserProfileStatus.loaded, summary: summary));
      // Cache nearby push setting for app startup check (best-effort)
      try {
        await StorageService.instance.setNearbyPushEnabled(summary.preference.nearbyPushEnabled);
      } catch (_) {
        // Ignore storage errors; the loaded state has already been emitted
      }
    } on UserProfileException catch (_) {
      emit(state.copyWith(status: UserProfileStatus.error, errorMessage: 'user_profile_load_failed'));
    } catch (e) {
      emit(state.copyWith(status: UserProfileStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onUpdateCapabilities(
    UserProfileUpdateCapabilities event,
    Emitter<UserProfileState> emit,
  ) async {
    emit(state.copyWith(status: UserProfileStatus.loading));
    try {
      await repository.updateCapabilities(event.capabilities);
      final summary = await repository.getSummary();
      emit(state.copyWith(status: UserProfileStatus.loaded, summary: summary));
    } on UserProfileException catch (_) {
      emit(state.copyWith(status: UserProfileStatus.error, errorMessage: 'user_profile_update_failed'));
    } catch (e) {
      emit(state.copyWith(status: UserProfileStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onDeleteCapability(
    UserProfileDeleteCapability event,
    Emitter<UserProfileState> emit,
  ) async {
    emit(state.copyWith(status: UserProfileStatus.loading));
    try {
      await repository.deleteCapability(event.capabilityId);
      final summary = await repository.getSummary();
      emit(state.copyWith(status: UserProfileStatus.loaded, summary: summary));
    } on UserProfileException catch (_) {
      emit(state.copyWith(status: UserProfileStatus.error, errorMessage: 'user_profile_delete_failed'));
    } catch (e) {
      emit(state.copyWith(status: UserProfileStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onUpdatePreferences(
    UserProfileUpdatePreferences event,
    Emitter<UserProfileState> emit,
  ) async {
    emit(state.copyWith(status: UserProfileStatus.loading));
    try {
      await repository.updatePreferences(event.preferences);
      final summary = await repository.getSummary();
      emit(state.copyWith(status: UserProfileStatus.loaded, summary: summary));
      // Cache nearby push setting for app startup check (best-effort)
      try {
        await StorageService.instance.setNearbyPushEnabled(summary.preference.nearbyPushEnabled);
      } catch (_) {
        // Ignore storage errors; the loaded state has already been emitted
      }
    } on UserProfileException catch (_) {
      emit(state.copyWith(status: UserProfileStatus.error, errorMessage: 'user_profile_update_failed'));
    } catch (e) {
      emit(state.copyWith(status: UserProfileStatus.error, errorMessage: e.toString()));
    }
  }
}
