import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/utils/logger.dart';

/// 存储服务
/// 参考iOS KeychainHelper.swift 和 UserDefaults
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  late SharedPreferences _prefs;
  late FlutterSecureStorage _secureStorage;
  Box? _cacheBox;

  /// 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );

    // 初始化Hive缓存
    _cacheBox = await Hive.openBox(StorageKeys.cacheBox);

    AppLogger.info('StorageService initialized');
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
  Future<void> saveUserId(int userId) async {
    await _prefs.setInt(StorageKeys.userId, userId);
  }

  /// 获取用户ID
  int? getUserId() {
    return _prefs.getInt(StorageKeys.userId);
  }

  /// 保存用户信息JSON
  Future<void> saveUserInfo(Map<String, dynamic> userInfo) async {
    await _prefs.setString(StorageKeys.userInfo, jsonEncode(userInfo));
  }

  /// 获取用户信息
  Map<String, dynamic>? getUserInfo() {
    final json = _prefs.getString(StorageKeys.userInfo);
    if (json == null) return null;
    return jsonDecode(json) as Map<String, dynamic>;
  }

  /// 清除用户信息
  Future<void> clearUserInfo() async {
    await _prefs.remove(StorageKeys.userId);
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
    await _prefs.setString(StorageKeys.languageCode, languageCode);
  }

  /// 获取语言设置
  String? getLanguage() {
    return _prefs.getString(StorageKeys.languageCode);
  }

  /// 保存主题模式
  Future<void> saveThemeMode(String themeMode) async {
    await _prefs.setString(StorageKeys.themeMode, themeMode);
  }

  /// 获取主题模式
  String? getThemeMode() {
    return _prefs.getString(StorageKeys.themeMode);
  }

  /// 保存通知设置
  Future<void> saveNotificationEnabled(bool enabled) async {
    await _prefs.setBool(StorageKeys.notificationEnabled, enabled);
  }

  /// 获取通知设置
  bool isNotificationEnabled() {
    return _prefs.getBool(StorageKeys.notificationEnabled) ?? true;
  }

  /// 保存推送Token
  Future<void> savePushToken(String token) async {
    await _prefs.setString(StorageKeys.pushToken, token);
  }

  /// 获取推送Token
  String? getPushToken() {
    return _prefs.getString(StorageKeys.pushToken);
  }

  // ==================== 搜索历史 ====================

  /// 获取搜索历史
  List<String> getSearchHistory() {
    final json = _prefs.getString(StorageKeys.searchHistory);
    if (json == null) return [];
    return List<String>.from(jsonDecode(json));
  }

  /// 添加搜索历史
  Future<void> addSearchHistory(String keyword) async {
    final history = getSearchHistory();
    // 移除重复项
    history.remove(keyword);
    // 添加到开头
    history.insert(0, keyword);
    // 最多保存20条
    if (history.length > 20) {
      history.removeLast();
    }
    await _prefs.setString(StorageKeys.searchHistory, jsonEncode(history));
  }

  /// 清除搜索历史
  Future<void> clearSearchHistory() async {
    await _prefs.remove(StorageKeys.searchHistory);
  }

  // ==================== 缓存（Hive） ====================

  /// 设置缓存
  Future<void> setCache(String key, dynamic value, {Duration? expiry}) async {
    final box = _cacheBox;
    if (box == null) return;

    final cacheData = {
      'value': value,
      'expiry': expiry != null
          ? DateTime.now().add(expiry).millisecondsSinceEpoch
          : null,
    };
    await box.put(key, jsonEncode(cacheData));
  }

  /// 获取缓存
  T? getCache<T>(String key) {
    final box = _cacheBox;
    if (box == null) return null;

    final json = box.get(key);
    if (json == null) return null;

    final cacheData = jsonDecode(json) as Map<String, dynamic>;
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
    // 保留语言和主题设置
    AppLogger.info('User data cleared on logout');
  }
}
