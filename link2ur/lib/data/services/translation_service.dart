import 'dart:ui' as ui;

import '../../core/constants/api_endpoints.dart';
import '../../core/utils/logger.dart';
import 'api_service.dart';

/// 翻译服务
/// 对齐 iOS TranslationService.swift
/// 提供语言检测、文本翻译（单条/批量）、缓存功能
class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  ApiService? _apiService;

  /// 翻译缓存（key: "sourceText_targetLang"）
  final Map<String, String> _cache = {};

  /// 语言检测缓存
  final Map<String, String> _languageCache = {};

  /// 最大缓存条数
  static const int _maxCacheSize = 500;

  /// 初始化
  void initialize({required ApiService apiService}) {
    _apiService = apiService;
    AppLogger.info('TranslationService initialized');
  }

  /// 获取用户系统语言
  String getUserSystemLanguage() {
    final locale = ui.PlatformDispatcher.instance.locale;
    return locale.languageCode;
  }

  /// 简单语言检测（基于 Unicode 范围）
  /// 返回语言代码：zh, en, ja, ko 等
  String? detectLanguage(String text) {
    if (text.trim().isEmpty) return null;

    // 检查缓存
    final cacheKey = text.length > 100 ? text.substring(0, 100) : text;
    if (_languageCache.containsKey(cacheKey)) {
      return _languageCache[cacheKey];
    }

    String? detected;
    int zhCount = 0;
    int enCount = 0;
    int jaCount = 0;
    int koCount = 0;

    for (final rune in text.runes) {
      if (rune >= 0x4E00 && rune <= 0x9FFF) {
        zhCount++;
      } else if ((rune >= 0x0041 && rune <= 0x005A) ||
          (rune >= 0x0061 && rune <= 0x007A)) {
        enCount++;
      } else if ((rune >= 0x3040 && rune <= 0x309F) ||
          (rune >= 0x30A0 && rune <= 0x30FF)) {
        jaCount++;
      } else if (rune >= 0xAC00 && rune <= 0xD7AF) {
        koCount++;
      }
    }

    final total = zhCount + enCount + jaCount + koCount;
    if (total == 0) return null;

    if (zhCount > enCount && zhCount > jaCount && zhCount > koCount) {
      detected = 'zh';
    } else if (enCount > zhCount && enCount > jaCount && enCount > koCount) {
      detected = 'en';
    } else if (jaCount > zhCount && jaCount > enCount) {
      detected = 'ja';
    } else if (koCount > zhCount && koCount > enCount) {
      detected = 'ko';
    } else {
      detected = 'en';
    }

    // 缓存结果
    _languageCache[cacheKey] = detected;

    return detected;
  }

  /// 判断文本是否需要翻译
  /// 如果文本语言和用户系统语言不同，则需要翻译
  bool needsTranslation(String text) {
    final textLang = detectLanguage(text);
    if (textLang == null) return false;

    final userLang = getUserSystemLanguage();

    // 简体/繁体中文不需要互译
    if (textLang == 'zh' && (userLang == 'zh')) return false;

    return textLang != userLang;
  }

  /// 翻译文本
  /// [text] 原文
  /// [targetLanguage] 目标语言（默认使用用户系统语言）
  /// [sourceLanguage] 源语言（可选，自动检测）
  Future<String> translate(
    String text, {
    String? targetLanguage,
    String? sourceLanguage,
  }) async {
    if (_apiService == null) {
      throw TranslationException('TranslationService not initialized');
    }

    if (text.trim().isEmpty) return text;

    final target = targetLanguage ?? getUserSystemLanguage();
    final source = sourceLanguage ?? detectLanguage(text);

    // 如果源语言和目标语言相同，无需翻译
    if (source == target) return text;

    // 检查缓存
    final cacheKey = '${text}_$target';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final response = await _apiService!.post<Map<String, dynamic>>(
        ApiEndpoints.translate,
        data: {
          'text': text,
          'target_language': target,
          if (source != null) 'source_language': source,
        },
      );

      if (response.isSuccess && response.data != null) {
        final translated =
            response.data!['translated_text'] as String? ?? text;

        // 缓存翻译结果
        _addToCache(cacheKey, translated);

        return translated;
      }

      return text;
    } catch (e) {
      AppLogger.error('Translation failed', e);
      return text;
    }
  }

  /// 批量翻译
  /// [texts] 原文列表
  /// [targetLanguage] 目标语言（默认使用用户系统语言）
  Future<Map<String, String>> translateBatch(
    List<String> texts, {
    String? targetLanguage,
  }) async {
    if (_apiService == null) {
      throw TranslationException('TranslationService not initialized');
    }

    if (texts.isEmpty) return {};

    final target = targetLanguage ?? getUserSystemLanguage();
    final result = <String, String>{};
    final textsToTranslate = <String>[];

    // 检查缓存，收集需要翻译的文本
    for (final text in texts) {
      final cacheKey = '${text}_$target';
      if (_cache.containsKey(cacheKey)) {
        result[text] = _cache[cacheKey]!;
      } else {
        textsToTranslate.add(text);
      }
    }

    if (textsToTranslate.isEmpty) return result;

    try {
      final response = await _apiService!.post<Map<String, dynamic>>(
        ApiEndpoints.translateBatch,
        data: {
          'texts': textsToTranslate,
          'target_language': target,
        },
      );

      if (response.isSuccess && response.data != null) {
        final translations =
            response.data!['translations'] as Map<String, dynamic>? ?? {};

        for (final entry in translations.entries) {
          final translated = entry.value as String;
          result[entry.key] = translated;
          _addToCache('${entry.key}_$target', translated);
        }
      }

      // 确保所有文本都有对应的翻译（未翻译的保持原文）
      for (final text in textsToTranslate) {
        result.putIfAbsent(text, () => text);
      }

      return result;
    } catch (e) {
      AppLogger.error('Batch translation failed', e);
      // 出错时返回原文
      for (final text in textsToTranslate) {
        result.putIfAbsent(text, () => text);
      }
      return result;
    }
  }

  /// 清除缓存
  void clearCache() {
    _cache.clear();
    _languageCache.clear();
    AppLogger.info('Translation cache cleared');
  }

  // ==================== 内部方法 ====================

  void _addToCache(String key, String value) {
    // 如果缓存已满，清除最早的条目
    if (_cache.length >= _maxCacheSize) {
      final keysToRemove =
          _cache.keys.take(_maxCacheSize ~/ 4).toList();
      for (final k in keysToRemove) {
        _cache.remove(k);
      }
    }
    _cache[key] = value;
  }
}

/// 翻译异常
class TranslationException implements Exception {
  TranslationException(this.message);
  final String message;

  @override
  String toString() => 'TranslationException: $message';
}
