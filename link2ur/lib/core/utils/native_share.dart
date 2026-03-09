import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:share_plus/share_plus.dart';

import 'logger.dart';
import 'l10n_extension.dart';

/// 原生分享（对标 iOS UIActivityViewController）
///
/// 支持：标题、描述、链接、可选图片（files）。
/// Web 端：优先 Web Share API，不支持时降级为复制链接。
///
/// **分享策略**（与 frontend navigator.share 对齐）：
/// - 有 URL 时：用 `uri` 模式分享，系统会抓取网页 OG 标签生成链接卡片
///   （微信/微博等均能正确显示标题+描述+缩略图）
/// - 无 URL 时：用 `text` 模式分享纯文本
/// - share_plus 不允许 uri 与 text 同时传
class NativeShare {
  NativeShare._();

  /// 将首图 URL 转为可分享的 [XFile]（优先走缓存）。
  /// Web 端不支持文件缓存，直接返回 null。
  /// 返回单元素列表或 null（无图或下载失败）。
  static Future<List<XFile>?> fileFromFirstImageUrl(String? imageUrl) async {
    if (kIsWeb) return null;
    if (imageUrl == null || imageUrl.trim().isEmpty) return null;
    try {
      final file = await DefaultCacheManager().getSingleFile(imageUrl.trim());
      return [XFile(file.path)];
    } catch (e) {
      AppLogger.warning('NativeShare: 获取分享图失败', e);
      return null;
    }
  }

  /// 构建纯文本分享正文（无 URL 时使用）
  static String buildShareText({
    required String title,
    String description = '',
  }) {
    final parts = <String>[title];
    if (description.trim().isNotEmpty) {
      parts.add(description.trim());
    }
    return parts.join('\n\n');
  }

  /// 调起系统分享
  ///
  /// [title] 分享标题（用于 subject / email）
  /// [description] 描述文案
  /// [url] 链接：有 URL 时走 `uri` 模式，让系统/微信抓取 OG 标签生成链接卡片
  /// [files] 可选图片/文件列表（Web 端忽略）
  /// [context] 可选；分享失败时用于显示 SnackBar 提示
  static Future<void> share({
    required String title,
    String description = '',
    String? url,
    List<XFile>? files,
    BuildContext? context,
  }) async {
    final hasUrl = url != null && url.trim().isNotEmpty;
    final hasText = title.trim().isNotEmpty || description.trim().isNotEmpty;
    // Web 端不传文件（Web Share API 对文件支持有限）
    final hasFiles = !kIsWeb && files != null && files.isNotEmpty;

    if (!hasUrl && !hasText && !hasFiles) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.actionOperationFailed)),
        );
      }
      return;
    }

    try {
      if (hasUrl) {
        // URI 模式：系统会抓取网页 OG 标签，微信可生成链接卡片
        // share_plus 不允许 uri 与 text 同时传，subject 可以一起用
        await SharePlus.instance.share(
          ShareParams(
            uri: Uri.parse(url.trim()),
            subject: title.trim().isNotEmpty ? title.trim() : null,
          ),
        );
      } else {
        // 纯文本模式：无 URL 时走 text
        final text = buildShareText(title: title, description: description);
        await SharePlus.instance.share(
          ShareParams(
            text: text,
            subject: title.trim().isNotEmpty ? title.trim() : null,
            files: hasFiles ? files : null,
          ),
        );
      }
    } catch (e, st) {
      AppLogger.warning('NativeShare: 分享失败', e);
      AppLogger.debug('NativeShare share stack', e, st);

      // Web 端 Web Share API 不可用时，降级为复制链接
      if (kIsWeb && hasUrl) {
        await Clipboard.setData(ClipboardData(text: url.trim()));
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.shareLinkCopied),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

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
