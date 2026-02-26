import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:share_plus/share_plus.dart';

/// 原生分享（对标 iOS UIActivityViewController）
///
/// 暂时禁用自定义分享栏，点击分享直接调起系统分享面板。
/// 支持：标题、描述、链接、可选图片（files）。
/// 参考 iOS ActivityShareItem：title + description + url + image
class NativeShare {
  NativeShare._();

  /// 将首图 URL 转为可分享的 [XFile]（优先走缓存）。
  /// 返回单元素列表或 null（无图或下载失败）。
  static Future<List<XFile>?> fileFromFirstImageUrl(String? imageUrl) async {
    if (imageUrl == null || imageUrl.trim().isEmpty) return null;
    try {
      final file = await DefaultCacheManager().getSingleFile(imageUrl.trim());
      return [XFile(file.path)];
    } catch (_) {
      return null;
    }
  }

  /// 调起系统分享
  ///
  /// [title] 分享标题（对应 iOS subject / LPLinkMetadata.title）
  /// [description] 描述文案
  /// [url] 链接：会拼进正文，且单独传 [ShareParams.uri] 以便微信等识别为链接并抓取网页 meta 展示卡片
  /// [files] 可选图片/文件列表（对应 iOS 的 image，系统分享会带图）
  static Future<void> share({
    required String title,
    String description = '',
    String? url,
    List<XFile>? files,
  }) async {
    final parts = <String>[title];
    if (description.trim().isNotEmpty) {
      parts.add(description.trim());
    }
    if (url != null && url.trim().isNotEmpty) {
      parts.add('👉 ${url.trim()}');
    }
    final text = parts.join('\n\n');
    final uri = (url != null && url.trim().isNotEmpty)
        ? Uri.tryParse(url.trim())
        : null;

    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: title,
        uri: uri,
        files: files,
      ),
    );
  }
}
