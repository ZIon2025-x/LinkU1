import 'dart:collection';

import 'cache_manager.dart';
import 'logger.dart';

/// 翻译缓存管理器
/// 参考iOS TranslationCacheManager.swift
/// 使用 CacheManager 的磁盘层持久化，加上内存LRU快速访问
class TranslationCacheManager {
  TranslationCacheManager._();
  static final TranslationCacheManager shared = TranslationCacheManager._();

  /// 内存 LRU 缓存
  final LinkedHashMap<String, String> _cache = LinkedHashMap();

  /// 最大条目数
  static const int _maxEntries = 1000;

  /// TTL
  static const Duration _ttl = CacheManager.translationTTL;

  /// 缓存键前缀
  static const String _prefix = CacheManager.prefixTranslation;

  /// 构建缓存键
  String _buildKey(String text, String sourceLang, String targetLang) {
    // 使用简单 hash 避免超长键
    final input = '${text}_${sourceLang}_$targetLang';
    final hash = input.hashCode.toRadixString(16);
    return '$_prefix$hash';
  }

  /// 获取缓存的翻译
  String? getCachedTranslation({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
  }) {
    final key = _buildKey(text, sourceLang, targetLang);

    // 1. 查内存 LRU
    if (_cache.containsKey(key)) {
      final value = _cache.remove(key)!;
      _cache[key] = value; // 移到末尾（最近访问）
      return value;
    }

    // 2. 查 CacheManager 磁盘缓存
    final diskValue = CacheManager.shared.get<String>(key);
    if (diskValue != null) {
      // 回写内存 LRU
      _cache[key] = diskValue;
      _evictIfNeeded();
      return diskValue;
    }

    return null;
  }

  /// 保存翻译到缓存
  Future<void> saveTranslation({
    required String text,
    required String translatedText,
    required String targetLang,
    String sourceLang = 'auto',
  }) async {
    final key = _buildKey(text, sourceLang, targetLang);

    // 写入内存 LRU
    _cache[key] = translatedText;
    _evictIfNeeded();

    // 写入 CacheManager 磁盘
    await CacheManager.shared.set(key, translatedText, ttl: _ttl);
  }

  /// 批量保存翻译
  Future<void> saveTranslationBatch({
    required List<String> texts,
    required List<String> translatedTexts,
    required String targetLang,
    String sourceLang = 'auto',
  }) async {
    if (texts.length != translatedTexts.length) return;

    for (int i = 0; i < texts.length; i++) {
      await saveTranslation(
        text: texts[i],
        translatedText: translatedTexts[i],
        targetLang: targetLang,
        sourceLang: sourceLang,
      );
    }
  }

  /// 清除所有翻译缓存
  Future<void> clearAllCache() async {
    _cache.clear();
    await CacheManager.shared.invalidateTranslationCache();
    AppLogger.debug('Translation cache cleared');
  }

  /// 获取缓存条目数
  int get cacheCount => _cache.length;

  /// 内存淘汰
  void _evictIfNeeded() {
    while (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }
}
