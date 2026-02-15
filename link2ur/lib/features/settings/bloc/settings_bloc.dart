import 'package:equatable/equatable.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/services/storage_service.dart';
import '../../../data/services/api_service.dart';
import '../../../core/utils/cache_manager.dart';
import '../../../core/utils/translation_cache_manager.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/cache_directory_helper_stub.dart'
    if (dart.library.io) '../../../core/utils/cache_directory_helper_io.dart'
    as cache_dir_helper;

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

class SettingsSoundToggled extends SettingsEvent {
  const SettingsSoundToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

class SettingsClearCache extends SettingsEvent {
  const SettingsClearCache();
}

class SettingsDeleteAccount extends SettingsEvent {
  const SettingsDeleteAccount();
}

class SettingsCalculateCacheSize extends SettingsEvent {
  const SettingsCalculateCacheSize();
}

// ==================== State ====================

class SettingsState extends Equatable {
  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.locale = 'zh',
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.cacheSize = 'common_loading',
    this.appVersion = '',
    this.isClearingCache = false,
    this.isDeletingAccount = false,
    this.deleteAccountError,
  });

  final ThemeMode themeMode;
  final String locale;
  final bool notificationsEnabled;
  final bool soundEnabled;
  final String cacheSize;
  final String appVersion;
  final bool isClearingCache;
  final bool isDeletingAccount;
  final String? deleteAccountError;

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? locale,
    bool? notificationsEnabled,
    bool? soundEnabled,
    String? cacheSize,
    String? appVersion,
    bool? isClearingCache,
    bool? isDeletingAccount,
    String? deleteAccountError,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      notificationsEnabled:
          notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      cacheSize: cacheSize ?? this.cacheSize,
      appVersion: appVersion ?? this.appVersion,
      isClearingCache: isClearingCache ?? this.isClearingCache,
      isDeletingAccount: isDeletingAccount ?? this.isDeletingAccount,
      deleteAccountError: deleteAccountError,
    );
  }

  @override
  List<Object?> get props => [
        themeMode,
        locale,
        notificationsEnabled,
        soundEnabled,
        cacheSize,
        appVersion,
        isClearingCache,
        isDeletingAccount,
        deleteAccountError,
      ];
}

// ==================== Bloc ====================

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({this.apiService}) : super(const SettingsState()) {
    on<SettingsLoadRequested>(_onLoadRequested);
    on<SettingsThemeChanged>(_onThemeChanged);
    on<SettingsLanguageChanged>(_onLanguageChanged);
    on<SettingsNotificationToggled>(_onNotificationToggled);
    on<SettingsSoundToggled>(_onSoundToggled);
    on<SettingsClearCache>(_onClearCache);
    on<SettingsDeleteAccount>(_onDeleteAccount);
    on<SettingsCalculateCacheSize>(_onCalculateCacheSize);
  }

  final ApiService? apiService;

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
      final soundEnabled =
          StorageService.instance.isSoundEnabled();

      emit(state.copyWith(
        themeMode: themeMode,
        locale: locale,
        notificationsEnabled: notificationsEnabled,
        soundEnabled: soundEnabled,
      ));

      // 寮傛璁＄畻缂撳瓨澶у皬
      add(const SettingsCalculateCacheSize());
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

  Future<void> _onSoundToggled(
    SettingsSoundToggled event,
    Emitter<SettingsState> emit,
  ) async {
    await StorageService.instance.saveSoundEnabled(event.enabled);
    emit(state.copyWith(soundEnabled: event.enabled));
  }

  Future<void> _onCalculateCacheSize(
    SettingsCalculateCacheSize event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      // 璁＄畻涓存椂鐩綍澶у皬锛堝浘鐗囩紦瀛樼瓑锛夆€?Web 涓婅繑鍥?0
      final tempSize = await cache_dir_helper.calculateCacheDirectorySize();

      // 鍔犱笂 CacheManager 鐨勭紦瀛樺ぇ灏?
      final apiCacheSize = CacheManager.shared.diskCacheSizeBytes;

      final totalSize = tempSize + apiCacheSize;
      emit(state.copyWith(cacheSize: _formatFileSize(totalSize)));
    } catch (e) {
      emit(state.copyWith(cacheSize: 'N/A'));
    }
  }

  Future<void> _onClearCache(
    SettingsClearCache event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      emit(state.copyWith(isClearingCache: true));

      // 1. 娓呯悊 CacheManager锛圓PI 鍝嶅簲缂撳瓨锛?
      await CacheManager.shared.clearAll();

      // 2. 娓呯悊缈昏瘧缂撳瓨
      await TranslationCacheManager.shared.clearAllCache();

      // 3. 娓呯悊 StorageService 鐨?Hive 缂撳瓨
      await StorageService.instance.clearCache();

      // 4. 娓呯悊涓存椂鐩綍锛堝浘鐗囩紦瀛樼瓑锛夆€?Web 涓婁负 no-op
      await cache_dir_helper.clearCacheDirectory();

      // 璁板綍缂撳瓨缁熻
      final stats = CacheManager.shared.getStatistics();
      AppLogger.info('Cache cleared. Stats before clear: $stats');

      emit(state.copyWith(
        cacheSize: '0 B',
        isClearingCache: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to clear cache', e);
      emit(state.copyWith(isClearingCache: false));
    }
  }

  Future<void> _onDeleteAccount(
    SettingsDeleteAccount event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      emit(state.copyWith(isDeletingAccount: true, deleteAccountError: null));

      if (apiService != null) {
        await apiService!.delete('/api/users/me');
      }

      // 娓呯悊鏈湴鏁版嵁
      await StorageService.instance.clearAll();

      emit(state.copyWith(isDeletingAccount: false));
    } catch (e) {
      AppLogger.error('Failed to delete account', e);
      emit(state.copyWith(
        isDeletingAccount: false,
        deleteAccountError: e.toString(),
      ));
    }
  }

  /// 鏍煎紡鍖栨枃浠跺ぇ灏?
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

