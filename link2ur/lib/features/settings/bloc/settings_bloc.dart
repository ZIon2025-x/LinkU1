import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/services/storage_service.dart';
import '../../../core/utils/logger.dart';

// ==================== Events ====================

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class SettingsLoadRequested extends SettingsEvent {
  const SettingsLoadRequested();
}

class SettingsThemeChanged extends SettingsEvent {
  const SettingsThemeChanged(this.themeMode);

  final ThemeMode themeMode;

  @override
  List<Object?> get props => [themeMode];
}

class SettingsLanguageChanged extends SettingsEvent {
  const SettingsLanguageChanged(this.locale);

  final String locale;

  @override
  List<Object?> get props => [locale];
}

class SettingsNotificationToggled extends SettingsEvent {
  const SettingsNotificationToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

class SettingsClearCache extends SettingsEvent {
  const SettingsClearCache();
}

// ==================== State ====================

class SettingsState extends Equatable {
  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.locale = 'zh',
    this.notificationsEnabled = true,
    this.cacheSize = '0 MB',
    this.appVersion = '',
  });

  final ThemeMode themeMode;
  final String locale;
  final bool notificationsEnabled;
  final String cacheSize;
  final String appVersion;

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? locale,
    bool? notificationsEnabled,
    String? cacheSize,
    String? appVersion,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      notificationsEnabled:
          notificationsEnabled ?? this.notificationsEnabled,
      cacheSize: cacheSize ?? this.cacheSize,
      appVersion: appVersion ?? this.appVersion,
    );
  }

  @override
  List<Object?> get props =>
      [themeMode, locale, notificationsEnabled, cacheSize, appVersion];
}

// ==================== Bloc ====================

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc() : super(const SettingsState()) {
    on<SettingsLoadRequested>(_onLoadRequested);
    on<SettingsThemeChanged>(_onThemeChanged);
    on<SettingsLanguageChanged>(_onLanguageChanged);
    on<SettingsNotificationToggled>(_onNotificationToggled);
    on<SettingsClearCache>(_onClearCache);
  }

  Future<void> _onLoadRequested(
    SettingsLoadRequested event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      final themeModeStr = StorageService.instance.getThemeMode();
      final themeMode = _parseThemeMode(themeModeStr);
      final locale = StorageService.instance.getLanguage() ?? 'zh';
      final notificationsEnabled =
          StorageService.instance.isNotificationEnabled();

      emit(state.copyWith(
        themeMode: themeMode,
        locale: locale,
        notificationsEnabled: notificationsEnabled,
      ));
    } catch (e) {
      AppLogger.error('Failed to load settings', e);
    }
  }

  ThemeMode _parseThemeMode(String? mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> _onThemeChanged(
    SettingsThemeChanged event,
    Emitter<SettingsState> emit,
  ) async {
    await StorageService.instance
        .saveThemeMode(_themeModeToString(event.themeMode));
    emit(state.copyWith(themeMode: event.themeMode));
  }

  Future<void> _onLanguageChanged(
    SettingsLanguageChanged event,
    Emitter<SettingsState> emit,
  ) async {
    await StorageService.instance.saveLanguage(event.locale);
    emit(state.copyWith(locale: event.locale));
  }

  Future<void> _onNotificationToggled(
    SettingsNotificationToggled event,
    Emitter<SettingsState> emit,
  ) async {
    await StorageService.instance
        .saveNotificationEnabled(event.enabled);
    emit(state.copyWith(notificationsEnabled: event.enabled));
  }

  Future<void> _onClearCache(
    SettingsClearCache event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      // TODO: 实现缓存清理逻辑
      emit(state.copyWith(cacheSize: '0 MB'));
    } catch (e) {
      AppLogger.error('Failed to clear cache', e);
    }
  }
}
