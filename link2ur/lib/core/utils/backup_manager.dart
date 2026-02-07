import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'logger.dart';

/// 备份管理器
/// 对齐 iOS BackupManager.swift
/// 提供数据备份的创建、恢复、列表、清理功能
class BackupManager {
  BackupManager._();
  static final BackupManager instance = BackupManager._();

  String? _backupDirPath;

  /// 获取备份目录
  Future<Directory> get _backupDir async {
    if (_backupDirPath == null) {
      final docDir = await getApplicationDocumentsDirectory();
      _backupDirPath = '${docDir.path}/Backups';
    }
    final dir = Directory(_backupDirPath!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 创建备份
  /// [data] 要备份的数据
  /// [name] 备份名称
  /// [metadata] 可选的元数据
  /// 返回备份文件路径
  Future<String> createBackup({
    required Uint8List data,
    required String name,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final dir = await _backupDir;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${name}_$timestamp.backup';
      final file = File('${dir.path}/$fileName');

      await file.writeAsBytes(data);

      // 保存元数据
      if (metadata != null) {
        final metaFile = File('${dir.path}/$fileName.meta');
        await metaFile.writeAsString(jsonEncode({
          ...metadata,
          'name': name,
          'createdAt': DateTime.now().toIso8601String(),
          'sizeBytes': data.length,
        }));
      }

      AppLogger.info('BackupManager: Created backup - $fileName');
      return file.path;
    } catch (e) {
      AppLogger.error('BackupManager: Create backup failed', e);
      rethrow;
    }
  }

  /// 创建 JSON 数据备份
  Future<String> createJsonBackup({
    required Map<String, dynamic> data,
    required String name,
    Map<String, dynamic>? metadata,
  }) async {
    final jsonStr = jsonEncode(data);
    final bytes = Uint8List.fromList(utf8.encode(jsonStr));
    return createBackup(
      data: bytes,
      name: name,
      metadata: {
        ...?metadata,
        'format': 'json',
      },
    );
  }

  /// 恢复备份
  /// [filePath] 备份文件路径
  /// 返回备份数据
  Future<Uint8List> restoreBackup({required String filePath}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw BackupException('备份文件不存在: $filePath');
      }

      final data = await file.readAsBytes();
      AppLogger.info('BackupManager: Restored backup - $filePath');
      return data;
    } catch (e) {
      AppLogger.error('BackupManager: Restore backup failed', e);
      rethrow;
    }
  }

  /// 恢复 JSON 备份
  Future<Map<String, dynamic>> restoreJsonBackup(
      {required String filePath}) async {
    final data = await restoreBackup(filePath: filePath);
    final jsonStr = utf8.decode(data);
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  /// 列出所有备份
  /// 返回按创建时间倒序排列的备份信息列表
  Future<List<BackupInfo>> listBackups() async {
    try {
      final dir = await _backupDir;
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.backup'))
          .toList();

      // 按修改时间倒序排列
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      final backups = <BackupInfo>[];
      for (final file in files) {
        final stat = file.statSync();
        final metaFile = File('${file.path}.meta');
        Map<String, dynamic>? metadata;

        if (await metaFile.exists()) {
          try {
            metadata = jsonDecode(await metaFile.readAsString())
                as Map<String, dynamic>;
          } catch (_) {}
        }

        backups.add(BackupInfo(
          filePath: file.path,
          fileName: file.uri.pathSegments.last,
          sizeBytes: stat.size,
          createdAt: stat.modified,
          metadata: metadata,
        ));
      }

      return backups;
    } catch (e) {
      AppLogger.error('BackupManager: List backups failed', e);
      return [];
    }
  }

  /// 删除备份
  Future<void> deleteBackup({required String filePath}) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      // 同时删除元数据
      final metaFile = File('$filePath.meta');
      if (await metaFile.exists()) {
        await metaFile.delete();
      }
      AppLogger.info('BackupManager: Deleted backup - $filePath');
    } catch (e) {
      AppLogger.error('BackupManager: Delete backup failed', e);
    }
  }

  /// 清理旧备份，保留最新的 N 个
  Future<void> cleanOldBackups({int keepCount = 10}) async {
    try {
      final backups = await listBackups();
      if (backups.length <= keepCount) return;

      // 删除多余的备份（列表已按时间倒序）
      final toDelete = backups.sublist(keepCount);
      for (final backup in toDelete) {
        await deleteBackup(filePath: backup.filePath);
      }

      AppLogger.info(
          'BackupManager: Cleaned ${toDelete.length} old backups');
    } catch (e) {
      AppLogger.error('BackupManager: Clean old backups failed', e);
    }
  }

  /// 获取备份总大小（字节）
  Future<int> getTotalBackupSize() async {
    final backups = await listBackups();
    return backups.fold<int>(0, (sum, b) => sum + b.sizeBytes);
  }
}

/// 备份信息
class BackupInfo {
  BackupInfo({
    required this.filePath,
    required this.fileName,
    required this.sizeBytes,
    required this.createdAt,
    this.metadata,
  });

  final String filePath;
  final String fileName;
  final int sizeBytes;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  String get name => metadata?['name'] as String? ?? fileName;
  String get format => metadata?['format'] as String? ?? 'binary';
}

/// 备份异常
class BackupException implements Exception {
  BackupException(this.message);
  final String message;

  @override
  String toString() => 'BackupException: $message';
}
