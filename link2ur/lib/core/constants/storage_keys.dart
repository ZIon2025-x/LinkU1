/// 存储键常量
class StorageKeys {
  StorageKeys._();

  // ==================== 安全存储（Keychain/Keystore） ====================
  /// Access Token
  static const String accessToken = 'access_token';

  /// Refresh Token
  static const String refreshToken = 'refresh_token';

  /// Token过期时间
  static const String tokenExpiry = 'token_expiry';

  // ==================== 普通存储（SharedPreferences） ====================
  /// 用户ID
  static const String userId = 'user_id';

  /// 用户信息JSON
  static const String userInfo = 'user_info';

  /// 是否首次启动
  static const String isFirstLaunch = 'is_first_launch';

  /// 是否已完成引导
  static const String hasCompletedOnboarding = 'has_completed_onboarding';

  /// 语言设置
  static const String languageCode = 'language_code';

  /// 主题模式
  static const String themeMode = 'theme_mode';

  /// 通知设置
  static const String notificationEnabled = 'notification_enabled';

  /// 推送Token
  static const String pushToken = 'push_token';

  /// 最后同步时间
  static const String lastSyncTime = 'last_sync_time';

  /// 搜索历史
  static const String searchHistory = 'search_history';

  /// 草稿箱
  static const String taskDraft = 'task_draft';
  static const String postDraft = 'post_draft';

  // ==================== Hive Box名称 ====================
  /// 缓存Box
  static const String cacheBox = 'cache_box';

  /// 消息Box
  static const String messagesBox = 'messages_box';

  /// 离线任务Box
  static const String offlineTasksBox = 'offline_tasks_box';
}
