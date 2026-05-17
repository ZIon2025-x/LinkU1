import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:gal/gal.dart' as gal_pkg;
import 'package:path_provider/path_provider.dart';

import 'logger.dart';

/// 提取文件名的 basename,剥离任何路径分隔符。
/// 防 filename 含 `/` 或 `\` 或 `..` 逃出 tempDir 写到任意位置。
String _safeBasename(String filename) {
  // 取最后一个 / 或 \ 之后的部分
  var name = filename;
  final lastFwd = name.lastIndexOf('/');
  if (lastFwd >= 0) name = name.substring(lastFwd + 1);
  final lastBwd = name.lastIndexOf('\\');
  if (lastBwd >= 0) name = name.substring(lastBwd + 1);
  return name;
}

/// 抽象出 gal 调用方便单测注入。生产用 [DefaultGalClient] 桥接到 `gal` 包。
abstract class GalClient {
  Future<bool> hasAccess({bool toAlbum = false});
  Future<bool> requestAccess({bool toAlbum = false});
  Future<void> putVideo(String path);
  Future<void> putImageBytes(List<int> bytes);
}

class DefaultGalClient implements GalClient {
  const DefaultGalClient();
  @override
  Future<bool> hasAccess({bool toAlbum = false}) =>
      gal_pkg.Gal.hasAccess(toAlbum: toAlbum);
  @override
  Future<bool> requestAccess({bool toAlbum = false}) =>
      gal_pkg.Gal.requestAccess(toAlbum: toAlbum);
  @override
  Future<void> putVideo(String path) => gal_pkg.Gal.putVideo(path);
  @override
  Future<void> putImageBytes(List<int> bytes) =>
      gal_pkg.Gal.putImageBytes(Uint8List.fromList(bytes));
}

enum SaveResult { success, permissionDenied, failed }

class MediaSaver {
  /// 保存图片 URL 到系统相册。
  /// 内部:① 检查权限 → 必要时请求;② 下载 URL → bytes;③ putImageBytes。
  static Future<SaveResult> saveImage(
    String url, {
    GalClient galClient = const DefaultGalClient(),
    Dio? dio,
  }) async {
    try {
      if (!await galClient.hasAccess(toAlbum: true)) {
        final granted = await galClient.requestAccess(toAlbum: true);
        if (!granted) return SaveResult.permissionDenied;
      }
      final http = dio ?? Dio();
      final resp = await http.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = resp.data;
      if (bytes == null || bytes.isEmpty) return SaveResult.failed;
      await galClient.putImageBytes(bytes);
      return SaveResult.success;
    } catch (e) {
      AppLogger.error('MediaSaver.saveImage failed', e);
      return SaveResult.failed;
    }
  }

  /// 保存本地视频文件到系统相册。
  /// 调用前需要先把视频下载到 app 临时目录(参考 [downloadToTemp])。
  static Future<SaveResult> saveVideo(
    String localPath, {
    GalClient galClient = const DefaultGalClient(),
  }) async {
    try {
      if (!await galClient.hasAccess(toAlbum: true)) {
        final granted = await galClient.requestAccess(toAlbum: true);
        if (!granted) return SaveResult.permissionDenied;
      }
      await galClient.putVideo(localPath);
      return SaveResult.success;
    } catch (e) {
      AppLogger.error('MediaSaver.saveVideo failed', e);
      return SaveResult.failed;
    }
  }

  /// 将远程 URL 下载到 app 临时目录,返回本地路径。视频/PDF 保存前的预处理。
  ///
  /// 安全:filename 用 [_safeBasename] 剥离任何路径分隔符,防 `../../etc/passwd.pdf`
  /// 这类路径遍历(虽然 filename 当前只来自后端 meta,但加固防御)。
  static Future<String> downloadToTemp(String url, String filename) async {
    final dir = await getTemporaryDirectory();
    final safeName = _safeBasename(filename);
    if (safeName.isEmpty || safeName == '.' || safeName == '..') {
      throw ArgumentError('downloadToTemp: invalid filename "$filename"');
    }
    final localPath = '${dir.path}/$safeName';
    final dio = Dio();
    await dio.download(url, localPath);
    return localPath;
  }

  /// 清理 app 临时目录中 chat media 旧文件(超过 [maxAge] 默认 7 天)。
  /// 启动时调用一次即可。OS 会在低空间时也清,但主动清避免长期累积。
  ///
  /// 不抛异常(IO 失败不应影响 app 启动);失败只 log warning。
  static Future<void> pruneTempOldFiles({
    Duration maxAge = const Duration(days: 7),
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      if (!dir.existsSync()) return;
      final now = DateTime.now();
      int prunedCount = 0;
      int prunedBytes = 0;
      // 只扫顶层(downloadToTemp 落在 dir 顶层),不递归 — 避免误删
      // OS / 其他包(image_picker / video_compress)在 tempDir 创建的子目录。
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        try {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);
          if (age > maxAge) {
            prunedBytes += stat.size;
            await entity.delete();
            prunedCount++;
          }
        } catch (e) {
          // 单个文件失败不影响其他
          AppLogger.error('MediaSaver.pruneTempOldFiles: skip ${entity.path}', e);
        }
      }
      if (prunedCount > 0) {
        AppLogger.info(
          'MediaSaver pruned $prunedCount old temp file(s), '
          '${(prunedBytes / 1024).toStringAsFixed(1)} KB freed',
        );
      }
    } catch (e) {
      AppLogger.error('MediaSaver.pruneTempOldFiles failed', e);
    }
  }
}
