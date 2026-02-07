import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'logger.dart';
import 'network_monitor.dart';

/// 缓存条目
class _CacheEntry {
  _CacheEntry({
    required this.data,
    required this.expiresAt,
    required this.estimatedSize,
  });

  final dynamic data;
  final DateTime expiresAt;
  final int estimatedSize;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// 缓存管理器
/// 参考iOS CacheManager.swift — 内存+磁盘双层缓存，分级TTL，大小限制，缓存统计
class CacheManager {
  CacheManager._();
  static final CacheManager shared = CacheManager._();

  // ==================== 内存缓存 ====================
  final Map<String, _CacheEntry> _memoryCache = {};
  int _memoryCacheSize = 0;

  /// 内存缓存上限：50MB
  static const int _maxMemoryCacheBytes = 50 * 1024 * 1024;

  /// 内存缓存条目上限：100
  static const int _maxMemoryCacheCount = 100;

  // ==================== 磁盘缓存 ====================
  static const String _diskBoxName = 'api_cache_box';
  Box? _diskBox;

  // ==================== 统计 ====================
  int _hits = 0;
  int _misses = 0;
  int _diskHits = 0;

  // ==================== TTL 分级（对标iOS） ====================

  /// 短期：3分钟 — 任务列表、活动列表（频繁变动）
  static const Duration shortTTL = Duration(minutes: 3);

  /// 默认：5分钟 — 通用数据
  static const Duration defaultTTL = Duration(minutes: 5);

  /// 长期：10分钟 — 排行榜、达人列表（变动较少）
  static const Duration longTTL = Duration(minutes: 10);

  /// 个人数据：30分钟 — 我的任务、支付记录、收藏夹
  static const Duration personalTTL = Duration(minutes: 30);

  /// 静态数据：1小时 — 分类列表、FAQ、法律文档
  static const Duration staticTTL = Duration(hours: 1);

  /// 翻译：30天
  static const Duration translationTTL = Duration(days: 30);

  // ==================== 缓存键前缀 ====================

  /// 任务
  static const String prefixTasks = 'tasks_';
  static const String prefixRecommendedTasks = 'rec_tasks_';
  static const String prefixMyTasks = 'my_tasks_';
  static const String prefixTaskDetail = 'task_detail_';

  /// 论坛
  static const String prefixForum = 'forum_';
  static const String prefixForumCategories = 'forum_cat_';
  static const String prefixForumPosts = 'forum_posts_';
  static const String prefixForumPostDetail = 'forum_post_';
  static const String prefixMyForumPosts = 'my_forum_';

  /// 跳蚤市场
  static const String prefixFleaMarket = 'flea_';
  static const String prefixFleaMarketCategories = 'flea_cat_';
  static const String prefixFleaMarketDetail = 'flea_detail_';
  static const String prefixMyFleaMarket = 'my_flea_';

  /// 排行榜
  static const String prefixLeaderboard = 'lb_';
  static const String prefixLeaderboardDetail = 'lb_detail_';
  static const String prefixMyLeaderboard = 'my_lb_';

  /// 活动
  static const String prefixActivities = 'activities_';
  static const String prefixActivityDetail = 'activity_detail_';

  /// 任务达人
  static const String prefixTaskExperts = 'experts_';
  static const String prefixExpertDetail = 'expert_detail_';

  /// 通知
  static const String prefixNotifications = 'notif_';

  /// 通用
  static const String prefixBanners = 'banners_';
  static const String prefixCommon = 'common_';
  static const String prefixTranslation = 'trans_';

  /// 支付
  static const String prefixPayment = 'payment_';

  // ==================== 初始化 ====================

  /// 初始化磁盘缓存
  Future<void> init() async {
    try {
      _diskBox = await Hive.openBox(_diskBoxName);
      // 启动时清理过期缓存
      await clearExpired();
      AppLogger.info('CacheManager initialized');
    } catch (e) {
      AppLogger.error('CacheManager init failed', e);
    }
  }

  // ==================== 核心 API ====================

  /// 构建缓存键
  static String buildKey(String prefix, [Map<String, dynamic>? params]) {
    if (params == null || params.isEmpty) return prefix;
    // 按键排序确保一致性
    final sortedKeys = params.keys.toList()..sort();
    final parts =
        sortedKeys.map((k) => '${k}=${params[k]}').join('&');
    return '${prefix}$parts';
  }

  /// 设置缓存（同时写入内存和磁盘）
  Future<void> set(String key, dynamic value, {Duration? ttl}) async {
    final duration = ttl ?? defaultTTL;
    final expiresAt = DateTime.now().add(duration);

    // 估算大小
    final jsonStr = jsonEncode(value);
    final estimatedSize = jsonStr.length * 2; // UTF-16 estimate

    // 写入内存
    _memoryCache[key] = _CacheEntry(
      data: value,
      expiresAt: expiresAt,
      estimatedSize: estimatedSize,
    );
    _memoryCacheSize += estimatedSize;

    // 内存溢出检查
    _evictMemoryIfNeeded();

    // 写入磁盘
    try {
      final diskData = {
        'value': jsonStr,
        'expiresAt': expiresAt.millisecondsSinceEpoch,
      };
      await _diskBox?.put(key, jsonEncode(diskData));
    } catch (e) {
      AppLogger.warning('CacheManager disk write failed for key: $key');
    }
  }

  /// 获取缓存（先内存后磁盘）
  T? get<T>(String key) {
    // 1. 查内存
    final memEntry = _memoryCache[key];
    if (memEntry != null) {
      if (!memEntry.isExpired) {
        _hits++;
        return memEntry.data as T?;
      } else {
        // 过期，移除
        _removeMem(key);
      }
    }

    // 2. 查磁盘
    try {
      final diskJson = _diskBox?.get(key) as String?;
      if (diskJson != null) {
        final diskData = jsonDecode(diskJson) as Map<String, dynamic>;
        final expiresAt = DateTime.fromMillisecondsSinceEpoch(
            diskData['expiresAt'] as int);

        if (DateTime.now().isBefore(expiresAt)) {
          // 磁盘命中，回写内存
          final value = jsonDecode(diskData['value'] as String);
          final jsonStr = diskData['value'] as String;
          final estimatedSize = jsonStr.length * 2;

          _memoryCache[key] = _CacheEntry(
            data: value,
            expiresAt: expiresAt,
            estimatedSize: estimatedSize,
          );
          _memoryCacheSize += estimatedSize;
          _evictMemoryIfNeeded();

          _diskHits++;
          _hits++;
          return value as T?;
        } else {
          // 磁盘过期，移除
          _diskBox?.delete(key);
        }
      }
    } catch (e) {
      AppLogger.warning('CacheManager disk read failed for key: $key');
    }

    _misses++;
    return null;
  }

  /// 获取过期缓存（离线回退用）
  /// 即使数据已过期也返回，仅在缓存完全不存在时返回 null
  /// 参考iOS APICache 的 networkFirst 策略：网络失败时回退到过期缓存
  T? getStale<T>(String key) {
    // 1. 查内存（包括过期的）
    final memEntry = _memoryCache[key];
    if (memEntry != null) {
      return memEntry.data as T?;
    }

    // 2. 查磁盘（忽略过期）
    try {
      final diskJson = _diskBox?.get(key) as String?;
      if (diskJson != null) {
        final diskData = jsonDecode(diskJson) as Map<String, dynamic>;
        final value = jsonDecode(diskData['value'] as String);
        return value as T?;
      }
    } catch (e) {
      AppLogger.warning('CacheManager getStale failed for key: $key');
    }

    return null;
  }

  /// 获取缓存，支持离线回退
  /// 在线时只返回未过期的缓存；离线时也返回过期的缓存
  T? getWithOfflineFallback<T>(String key) {
    // 先尝试获取未过期的
    final fresh = get<T>(key);
    if (fresh != null) return fresh;

    // 如果离线，回退到过期缓存
    if (!NetworkMonitor.instance.isConnected) {
      final stale = getStale<T>(key);
      if (stale != null) {
        AppLogger.debug('CacheManager offline fallback for key: $key');
      }
      return stale;
    }

    return null;
  }

  /// 当前是否离线
  bool get isOffline => !NetworkMonitor.instance.isConnected;

  /// 检查缓存是否存在且未过期
  bool has(String key) {
    // 内存检查
    final memEntry = _memoryCache[key];
    if (memEntry != null && !memEntry.isExpired) return true;

    // 磁盘检查
    try {
      final diskJson = _diskBox?.get(key) as String?;
      if (diskJson != null) {
        final diskData = jsonDecode(diskJson) as Map<String, dynamic>;
        final expiresAt = DateTime.fromMillisecondsSinceEpoch(
            diskData['expiresAt'] as int);
        return DateTime.now().isBefore(expiresAt);
      }
    } catch (_) {}
    return false;
  }

  /// 移除指定缓存
  Future<void> remove(String key) async {
    _removeMem(key);
    await _diskBox?.delete(key);
  }

  /// 移除匹配前缀的所有缓存
  Future<void> removeByPrefix(String prefix) async {
    // 内存
    final memKeys =
        _memoryCache.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in memKeys) {
      _removeMem(key);
    }

    // 磁盘
    try {
      final diskKeys =
          _diskBox?.keys.where((k) => k.toString().startsWith(prefix)).toList();
      if (diskKeys != null) {
        await _diskBox?.deleteAll(diskKeys);
      }
    } catch (e) {
      AppLogger.warning('CacheManager removeByPrefix failed for: $prefix');
    }
  }

  // ==================== 精细化缓存失效（对标iOS） ====================

  /// 清除任务缓存
  Future<void> invalidateTasksCache() async {
    await removeByPrefix(prefixTasks);
    await removeByPrefix(prefixRecommendedTasks);
    AppLogger.debug('Tasks cache invalidated');
  }

  /// 清除我的任务缓存
  Future<void> invalidateMyTasksCache() async {
    await removeByPrefix(prefixMyTasks);
    AppLogger.debug('My tasks cache invalidated');
  }

  /// 清除任务详情缓存
  Future<void> invalidateTaskDetailCache(int taskId) async {
    await remove('${prefixTaskDetail}$taskId');
    AppLogger.debug('Task detail cache invalidated: $taskId');
  }

  /// 清除所有任务相关缓存
  Future<void> invalidateAllTasksCache() async {
    await invalidateTasksCache();
    await invalidateMyTasksCache();
    await removeByPrefix(prefixTaskDetail);
    AppLogger.debug('All tasks cache invalidated');
  }

  /// 清除论坛缓存
  Future<void> invalidateForumCache() async {
    await removeByPrefix(prefixForum);
    await removeByPrefix(prefixForumCategories);
    await removeByPrefix(prefixForumPosts);
    await removeByPrefix(prefixForumPostDetail);
    AppLogger.debug('Forum cache invalidated');
  }

  /// 清除我的论坛缓存
  Future<void> invalidateMyForumCache() async {
    await removeByPrefix(prefixMyForumPosts);
    AppLogger.debug('My forum cache invalidated');
  }

  /// 清除跳蚤市场缓存
  Future<void> invalidateFleaMarketCache() async {
    await removeByPrefix(prefixFleaMarket);
    await removeByPrefix(prefixFleaMarketCategories);
    await removeByPrefix(prefixFleaMarketDetail);
    AppLogger.debug('Flea market cache invalidated');
  }

  /// 清除我的跳蚤市场缓存
  Future<void> invalidateMyFleaMarketCache() async {
    await removeByPrefix(prefixMyFleaMarket);
    AppLogger.debug('My flea market cache invalidated');
  }

  /// 清除排行榜缓存
  Future<void> invalidateLeaderboardsCache() async {
    await removeByPrefix(prefixLeaderboard);
    await removeByPrefix(prefixLeaderboardDetail);
    AppLogger.debug('Leaderboards cache invalidated');
  }

  /// 清除我的排行榜缓存
  Future<void> invalidateMyLeaderboardsCache() async {
    await removeByPrefix(prefixMyLeaderboard);
    AppLogger.debug('My leaderboards cache invalidated');
  }

  /// 清除活动缓存
  Future<void> invalidateActivitiesCache() async {
    await removeByPrefix(prefixActivities);
    await removeByPrefix(prefixActivityDetail);
    AppLogger.debug('Activities cache invalidated');
  }

  /// 清除任务达人缓存
  Future<void> invalidateTaskExpertsCache() async {
    await removeByPrefix(prefixTaskExperts);
    await removeByPrefix(prefixExpertDetail);
    AppLogger.debug('Task experts cache invalidated');
  }

  /// 清除通知缓存
  Future<void> invalidateNotificationsCache() async {
    await removeByPrefix(prefixNotifications);
    AppLogger.debug('Notifications cache invalidated');
  }

  /// 清除支付缓存
  Future<void> invalidatePaymentCache() async {
    await removeByPrefix(prefixPayment);
    AppLogger.debug('Payment cache invalidated');
  }

  /// 清除Banner缓存
  Future<void> invalidateBannersCache() async {
    await removeByPrefix(prefixBanners);
    AppLogger.debug('Banners cache invalidated');
  }

  /// 清除翻译缓存
  Future<void> invalidateTranslationCache() async {
    await removeByPrefix(prefixTranslation);
    AppLogger.debug('Translation cache invalidated');
  }

  /// 清除所有个人数据缓存（登出时使用）
  Future<void> invalidatePersonalDataCache() async {
    await invalidateMyTasksCache();
    await invalidateMyForumCache();
    await invalidateMyFleaMarketCache();
    await invalidateMyLeaderboardsCache();
    await invalidatePaymentCache();
    await invalidateNotificationsCache();
    AppLogger.debug('Personal data cache invalidated');
  }

  // ==================== 全局清理 ====================

  /// 清除所有过期缓存
  Future<void> clearExpired() async {
    int removedCount = 0;

    // 内存
    final expiredMemKeys = _memoryCache.entries
        .where((e) => e.value.isExpired)
        .map((e) => e.key)
        .toList();
    for (final key in expiredMemKeys) {
      _removeMem(key);
      removedCount++;
    }

    // 磁盘
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final keysToRemove = <dynamic>[];

      for (final key in _diskBox?.keys ?? []) {
        try {
          final json = _diskBox?.get(key) as String?;
          if (json != null) {
            final data = jsonDecode(json) as Map<String, dynamic>;
            if (data['expiresAt'] is int && (data['expiresAt'] as int) < now) {
              keysToRemove.add(key);
              removedCount++;
            }
          }
        } catch (_) {
          keysToRemove.add(key);
        }
      }

      if (keysToRemove.isNotEmpty) {
        await _diskBox?.deleteAll(keysToRemove);
      }
    } catch (e) {
      AppLogger.warning('CacheManager clearExpired disk error: $e');
    }

    if (removedCount > 0) {
      AppLogger.debug('CacheManager cleared $removedCount expired entries');
    }
  }

  /// 清除所有缓存
  Future<void> clearAll() async {
    _memoryCache.clear();
    _memoryCacheSize = 0;
    await _diskBox?.clear();
    _hits = 0;
    _misses = 0;
    _diskHits = 0;
    AppLogger.info('CacheManager all cache cleared');
  }

  // ==================== 统计 ====================

  /// 获取缓存统计信息
  Map<String, dynamic> getStatistics() {
    final totalRequests = _hits + _misses;
    final hitRate =
        totalRequests > 0 ? (_hits / totalRequests * 100).toStringAsFixed(1) : '0.0';

    return {
      'memoryEntries': _memoryCache.length,
      'memorySizeBytes': _memoryCacheSize,
      'memorySizeFormatted': _formatSize(_memoryCacheSize),
      'diskEntries': _diskBox?.length ?? 0,
      'totalHits': _hits,
      'diskHits': _diskHits,
      'totalMisses': _misses,
      'hitRate': '$hitRate%',
    };
  }

  /// 获取磁盘缓存大小（bytes）
  int get diskCacheSizeBytes {
    int size = 0;
    try {
      for (final key in _diskBox?.keys ?? []) {
        final value = _diskBox?.get(key);
        if (value is String) {
          size += value.length * 2;
        }
      }
    } catch (_) {}
    return size;
  }

  /// 获取格式化的缓存大小
  String get formattedCacheSize {
    return _formatSize(_memoryCacheSize + diskCacheSizeBytes);
  }

  // ==================== 私有方法 ====================

  void _removeMem(String key) {
    final entry = _memoryCache.remove(key);
    if (entry != null) {
      _memoryCacheSize -= entry.estimatedSize;
      if (_memoryCacheSize < 0) _memoryCacheSize = 0;
    }
  }

  /// 内存淘汰（类LRU，优先移除最早的条目）
  void _evictMemoryIfNeeded() {
    // 超出条目数限制
    while (_memoryCache.length > _maxMemoryCacheCount) {
      final oldestKey = _memoryCache.keys.first;
      _removeMem(oldestKey);
    }

    // 超出大小限制
    while (_memoryCacheSize > _maxMemoryCacheBytes && _memoryCache.isNotEmpty) {
      final oldestKey = _memoryCache.keys.first;
      _removeMem(oldestKey);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
