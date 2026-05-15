import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:gal/gal.dart' as gal_pkg;
import 'package:path_provider/path_provider.dart';

import 'logger.dart';

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
  static Future<String> downloadToTemp(String url, String filename) async {
    final dir = await getTemporaryDirectory();
    final localPath = '${dir.path}/$filename';
    final dio = Dio();
    await dio.download(url, localPath);
    return localPath;
  }
}
