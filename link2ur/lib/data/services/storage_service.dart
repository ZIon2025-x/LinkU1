import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/utils/cache_manager.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/translation_cache_manager.dart';
import 'secure_storage_stub.dart'
    if (dart.library.io) 'secure_storage_io.dart'
    if (dart.library.html) 'secure_storage_web.dart';

/// 存储服务
/// 参考iOS KeychainHelper.swift 和 UserDefaults
///
/// 高频读取的值在 init() 时预加载到内存缓存，
/// 避免每次 BLoC 状态重建时触发 SharedPreferences 磁盘 I/O。
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  late SharedPreferences _prefs;
  late SecureTokenStorage _secureStorage;
  Box? _cacheBox;

  // ==================== 内存缓存 ====================
  String? _cachedUserId;
  Map<String, dynamic>? _cachedUserInfo;
  String? _cachedLanguage;
  String? _cachedThemeMode;
  bool _cachedNotificationEnabled = true;
  bool _cachedSoundEnabled = true;
  List<String>? _cachedSearchHistory;
  Set<int>? _cachedPinnedTaskChatIds;
  Map<int, DateTime>? _cachedHiddenTaskChats;

  /// 初始化
  /// SharedPreferences、Hive.openBox、CacheManager 互不依赖，并行执行以减少启动时间
  Future<void> init() async {
    _secureStorage = createSecureStorage();

    // 并行初始化三个独立的异步操作
    late final SharedPreferences prefs;
    late final Box cacheBox;
    await Future.wait([
      SharedPreferences.getInstance().then((p) => prefs = p),
      _openEncryptedCacheBox().then((b) => cacheBox = b),
      CacheManager.shared.init(),
    ]);
    _prefs = prefs;
    _cacheBox = cacheBox;

    // 预加载热数据到内存，避免后续 UI 线程同步磁盘读取
    await _loadCachedValues();

    AppLogger.info('StorageService initialized');
  }

  /// 从 SharedPreferences / SecureStorage 加载热数据到内存缓存
  Future<void> _loadCachedValues() async {
    _cachedUserId = _prefs.getString(StorageKeys.userId);
    _cachedLanguage = _prefs.getString(StorageKeys.languageCode);
    _cachedThemeMode = _prefs.getString(StorageKeys.themeMode);
    _cachedNotificationEnabled = _prefs.getBool(StorageKeys.notificationEnabled) ?? true;
    _cachedSoundEnabled = _prefs.getBool(StorageKeys.soundEnabled) ?? true;

    // 用户信息从 SecureStorage 读取，兼容旧版 SharedPreferences 数据
    try {
      var userInfoJson = await _secureStorage.read(key: StorageKeys.userInfo);
      if (userInfoJson == null || userInfoJson.isEmpty) {
        userInfoJson = _prefs.getString(StorageKeys.userInfo);
        if (userInfoJson != null) {
          await _secureStorage.write(key: StorageKeys.userInfo, value: userInfoJson);
          await _prefs.remove(StorageKeys.userInfo);
        }
      }
      if (userInfoJson != null) {
        _cachedUserInfo = jsonDecode(userInfoJson) as Map<String, dynamic>;
      }
    } catch (_) {
      _secureStorage.delete(key: StorageKeys.userInfo);
      _prefs.remove(StorageKeys.userInfo);
    }

    try {
      final searchJson = _prefs.getString(StorageKeys.searchHistory);
      if (searchJson != null) {
        _cachedSearchHistory = List<String>.from(jsonDecode(searchJson));
      }
    } catch (_) {
      _prefs.remove(StorageKeys.searchHistory);
    }

    try {
      final pinnedJson = _prefs.getString(StorageKeys.pinnedTaskChatIds);
      if (pinnedJson != null) {
        _cachedPinnedTaskChatIds = Set<int>.from(jsonDecode(pinnedJson) as List);
      }
    } catch (_) {
      _prefs.remove(StorageKeys.pinnedTaskChatIds);
    }

    try {
      final hiddenJson = _prefs.getString(StorageKeys.hiddenTaskChats);
      if (hiddenJson != null) {
        final raw = jsonDecode(hiddenJson) as Map<String, dynamic>;
        _cachedHiddenTaskChats = raw.map((key, value) =>
            MapEntry(int.parse(key), DateTime.parse(value as String)));
      }
    } catch (_) {
      _prefs.remove(StorageKeys.hiddenTaskChats);
    }
  }

  /// 打开加密的 Hive 缓存盒，密钥存储在 SecureStorage 中
  Future<Box> _openEncryptedCacheBox() async {
    try {
      const cacheKeyName = 'hive_cache_encryption_key';
      final existing = await _secureStorage.read(key: cacheKeyName);
      final Uint8List encryptionKey;
      if (existing != null && existing.isNotEmpty) {
        encryptionKey = base64Decode(existing);
      } else {
        encryptionKey = Uint8List.fromList(Hive.generateSecureKey());
        await _secureStorage.write(key: cacheKeyName, value: base64Encode(encryptionKey));
      }
      return await Hive.openBox(
        StorageKeys.cacheBox,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
    } catch (e) {
      AppLogger.warning('Failed to open encrypted Hive box, falling back to unencrypted: $e');
      return await Hive.openBox(StorageKeys.cacheBox);
    }
  }

  // ==================== 安全存储（Token等敏感信息） ====================

  /// 保存Tokens
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _secureStorage.write(
      key: StorageKeys.accessToken,
      value: accessToken,
    );
    if (refreshToken != null) {
      await _secureStorage.write(
        key: StorageKeys.refreshToken,
        value: refreshToken,
      );
    }
    AppLogger.debug('Tokens saved');
  }

  /// 获取Access Token
  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: StorageKeys.accessToken);
  }

  /// 获取Refresh Token
  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: StorageKeys.refreshToken);
  }

  /// 清除Tokens
  Future<void> clearTokens() async {
    await _secureStorage.delete(key: StorageKeys.accessToken);
    await _secureStorage.delete(key: StorageKeys.refreshToken);
    AppLogger.debug('Tokens cleared');
  }

  /// 是否已登录
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ==================== 普通存储（设置等） ====================

  /// 保存用户ID
  Future<void> saveUserId(String userId) async {
    _cachedUserId = userId;
    await _prefs.setString(StorageKeys.userId, userId);
  }

  /// 获取用户ID
  String? getUserId() => _cachedUserId;

  /// 保存用户信息JSON（敏感字段存入 SecureStorage）
  Future<void> saveUserInfo(Map<String, dynamic> userInfo) async {
    _cachedUserInfo = userInfo;
    await _secureStorage.write(
      key: StorageKeys.userInfo,
      value: jsonEncode(userInfo),
    );
  }

  /// 获取用户信息
  Map<String, dynamic>? getUserInfo() => _cachedUserInfo;

  /// 清除用户信息
  Future<void> clearUserInfo() async {
    _cachedUserId = null;
    _cachedUserInfo = null;
    await _prefs.remove(StorageKeys.userId);
    await _secureStorage.delete(key: StorageKeys.userInfo);
    // 兼容：清除旧版 SharedPreferences 中的用户信息
    await _prefs.remove(StorageKeys.userInfo);
  }

  /// 是否首次启动
  bool isFirstLaunch() {
    return _prefs.getBool(StorageKeys.isFirstLaunch) ?? true;
  }

  /// 设置首次启动完成
  Future<void> setFirstLaunchComplete() async {
    await _prefs.setBool(StorageKeys.isFirstLaunch, false);
  }

  /// 是否完成引导
  bool hasCompletedOnboarding() {
    return _prefs.getBool(StorageKeys.hasCompletedOnboarding) ?? false;
  }

  /// 设置引导完成
  Future<void> setOnboardingComplete() async {
    await _prefs.setBool(StorageKeys.hasCompletedOnboarding, true);
  }

  /// 保存语言设置
  Future<void> saveLanguage(String languageCode) async {
    _cachedLanguage = languageCode;
    await _prefs.setString(StorageKeys.languageCode, languageCode);
  }

  /// 获取语言设置
  String? getLanguage() => _cachedLanguage;

  /// 保存主题模式
  Future<void> saveThemeMode(String themeMode) async {
    _cachedThemeMode = themeMode;
    await _prefs.setString(StorageKeys.themeMode, themeMode);
  }

  /// 获取主题模式
  String? getThemeMode() => _cachedThemeMode;

  /// 保存通知设置
  Future<void> saveNotificationEnabled(bool enabled) async {
    _cachedNotificationEnabled = enabled;
    await _prefs.setBool(StorageKeys.notificationEnabled, enabled);
  }

  /// 获取通知设置
  bool isNotificationEnabled() => _cachedNotificationEnabled;

  /// 保存音效设置
  Future<void> saveSoundEnabled(bool enabled) async {
    _cachedSoundEnabled = enabled;
    await _prefs.setBool(StorageKeys.soundEnabled, enabled);
  }

  /// 获取音效设置
  bool isSoundEnabled() => _cachedSoundEnabled;

  /// 保存推送Token
  Future<void> savePushToken(String token) async {
    await _prefs.setString(StorageKeys.pushToken, token);
  }

  /// 获取推送Token（低频访问，不缓存）
  String? getPushToken() {
    return _prefs.getString(StorageKeys.pushToken);
  }

  // ==================== 搜索历史 ====================

  /// 获取搜索历史
  List<String> getSearchHistory() => List.of(_cachedSearchHistory ?? const []);

  /// 添加搜索历史
  Future<void> addSearchHistory(String keyword) async {
    final history = getSearchHistory();
    history.remove(keyword);
    history.insert(0, keyword);
    if (history.length > 20) {
      history.removeLast();
    }
    _cachedSearchHistory = history;
    await _prefs.setString(StorageKeys.searchHistory, jsonEncode(history));
  }

  /// 清除搜索历史
  Future<void> clearSearchHistory() async {
    _cachedSearchHistory = null;
    await _prefs.remove(StorageKeys.searchHistory);
  }

  // ==================== 任务聊天偏好（置顶/隐藏） ====================

  /// 获取置顶的任务聊天ID列表
  Set<int> getPinnedTaskChatIds() => Set.of(_cachedPinnedTaskChatIds ?? const {});

  /// 置顶任务聊天
  Future<void> pinTaskChat(int taskId) async {
    final ids = getPinnedTaskChatIds()..add(taskId);
    _cachedPinnedTaskChatIds = ids;
    await _prefs.setString(StorageKeys.pinnedTaskChatIds, jsonEncode(ids.toList()));
  }

  /// 取消置顶任务聊天
  Future<void> unpinTaskChat(int taskId) async {
    final ids = getPinnedTaskChatIds()..remove(taskId);
    _cachedPinnedTaskChatIds = ids;
    await _prefs.setString(StorageKeys.pinnedTaskChatIds, jsonEncode(ids.toList()));
  }

  /// 获取隐藏的任务聊天 (taskId -> 隐藏时间)
  Map<int, DateTime> getHiddenTaskChats() => Map.of(_cachedHiddenTaskChats ?? const {});

  /// 隐藏（软删除）任务聊天
  Future<void> hideTaskChat(int taskId) async {
    final hidden = getHiddenTaskChats();
    hidden[taskId] = DateTime.now();
    _cachedHiddenTaskChats = hidden;
    final raw = hidden.map((key, value) =>
        MapEntry(key.toString(), value.toIso8601String()));
    await _prefs.setString(StorageKeys.hiddenTaskChats, jsonEncode(raw));
  }

  /// 移除隐藏记录（恢复显示）
  Future<void> unhideTaskChat(int taskId) async {
    final hidden = getHiddenTaskChats();
    hidden.remove(taskId);
    _cachedHiddenTaskChats = hidden;
    final raw = hidden.map((key, value) =>
        MapEntry(key.toString(), value.toIso8601String()));
    await _prefs.setString(StorageKeys.hiddenTaskChats, jsonEncode(raw));
  }

  // ==================== 缓存（Hive） ====================

  /// 设置缓存
  ///
  /// 使用 Hive 原生 Map 存储，避免 jsonEncode/jsonDecode 的序列化开销。
  /// Hive 原生支持 Map、List、基本类型的直接存储。
  Future<void> setCache(String key, dynamic value, {Duration? expiry}) async {
    final box = _cacheBox;
    if (box == null) return;

    final cacheData = {
      'value': value,
      'expiry': expiry != null
          ? DateTime.now().add(expiry).millisecondsSinceEpoch
          : null,
    };
    await box.put(key, cacheData);
  }

  /// 获取缓存
  T? getCache<T>(String key) {
    final box = _cacheBox;
    if (box == null) return null;

    final raw = box.get(key);
    if (raw == null) return null;

    // 兼容旧格式（JSON 字符串）和新格式（原生 Map）
    final Map<String, dynamic> cacheData;
    if (raw is String) {
      cacheData = jsonDecode(raw) as Map<String, dynamic>;
    } else if (raw is Map) {
      cacheData = Map<String, dynamic>.from(raw);
    } else {
      return null;
    }

    final expiry = cacheData['expiry'] as int?;

    // 检查是否过期
    if (expiry != null && DateTime.now().millisecondsSinceEpoch > expiry) {
      box.delete(key);
      return null;
    }

    return cacheData['value'] as T?;
  }

  /// 删除缓存
  Future<void> deleteCache(String key) async {
    await _cacheBox?.delete(key);
  }

  /// 清除所有缓存
  Future<void> clearCache() async {
    await _cacheBox?.clear();
  }

  // ==================== 登出清理 ====================

  /// 登出时清理所有数据
  Future<void> clearAllOnLogout() async {
    await clearTokens();
    await clearUserInfo();
    // 清除个人数据相关的内存缓存
    _cachedSearchHistory = null;
    _cachedPinnedTaskChatIds = null;
    _cachedHiddenTaskChats = null;
    _cachedNotificationEnabled = true;
    _cachedSoundEnabled = true;
    // 清除个人数据缓存（保留公共缓存如分类、FAQ等）
    await CacheManager.shared.invalidatePersonalDataCache();
    // 保留语言和主题设置
    AppLogger.info('User data cleared on logout');
  }

  /// 完全清理所有数据（注销账户使用）
  Future<void> clearAll() async {
    await clearTokens();
    await clearUserInfo();
    await clearCache();
    // 重置所有内存缓存
    _cachedLanguage = null;
    _cachedThemeMode = null;
    _cachedNotificationEnabled = true;
    _cachedSoundEnabled = true;
    _cachedSearchHistory = null;
    _cachedPinnedTaskChatIds = null;
    _cachedHiddenTaskChats = null;
    // 清除所有 API 缓存
    await CacheManager.shared.clearAll();
    // 清除翻译缓存
    await TranslationCacheManager.shared.clearAllCache();
    // 清除所有 SharedPreferences
    await _prefs.clear();
    AppLogger.info('All user data cleared');
  }
}
