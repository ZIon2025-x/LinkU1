import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:share_plus/share_plus.dart';

import 'logger.dart';
import 'l10n_extension.dart';

/// 原生分享（对标 iOS UIActivityViewController）
///
/// 支持：标题、描述、链接、可选图片（files）。
/// 注意：share_plus 不允许 uri 与 text 同时传，链接写在正文中。
class NativeShare {
  NativeShare._();

  /// 将首图 URL 转为可分享的 [XFile]（优先走缓存）。
  /// 返回单元素列表或 null（无图或下载失败）。
  static Future<List<XFile>?> fileFromFirstImageUrl(String? imageUrl) async {
    if (imageUrl == null || imageUrl.trim().isEmpty) return null;
    try {
      final file = await DefaultCacheManager().getSingleFile(imageUrl.trim());
      return [XFile(file.path)];
    } catch (e) {
      AppLogger.warning('NativeShare: 获取分享图失败', e);
      return null;
    }
  }

  /// 构建与 iOS 一致的分享正文（标题 + 描述 + 链接）
  static String buildShareText({
    required String title,
    String description = '',
    String? url,
  }) {
    final parts = <String>[title];
    if (description.trim().isNotEmpty) {
      parts.add(description.trim());
    }
    if (url != null && url.trim().isNotEmpty) {
      parts.add('👉 ${url.trim()}');
    }
    return parts.join('\n\n');
  }

  /// 调起系统分享
  ///
  /// [title] 分享标题
  /// [description] 描述文案
  /// [url] 链接：会拼进正文（share_plus 不允许与 text 同时传 uri）
  /// [files] 可选图片/文件列表
  /// [context] 可选；分享失败时用于显示 SnackBar 提示
  static Future<void> share({
    required String title,
    String description = '',
    String? url,
    List<XFile>? files,
    BuildContext? context,
  }) async {
    final text = buildShareText(title: title, description: description, url: url);
    final hasText = text.trim().isNotEmpty;
    final hasFiles = files != null && files.isNotEmpty;
    if (!hasText && !hasFiles) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.actionOperationFailed)),
        );
      }
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: hasText ? text : null,
          subject: hasText ? title : null,
          files: hasFiles ? files : null,
        ),
      );
    } catch (e, st) {
      AppLogger.warning('NativeShare: 分享失败', e);
      AppLogger.debug('NativeShare share stack', e, st);
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.actionOperationFailed),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
