import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'logger.dart';

/// IO implementation — uses file system for backup operations.

Future<String> getBackupDirPath() async {
  final docDir = await getApplicationDocumentsDirectory();
  final path = '${docDir.path}/Backups';
  final dir = Directory(path);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return path;
}

Future<String> writeBackup(String dirPath, String fileName, Uint8List data) async {
  final file = File('$dirPath/$fileName');
  await file.writeAsBytes(data);
  return file.path;
}

Future<void> writeMetadata(String filePath, String jsonContent) async {
  final metaFile = File('$filePath.meta');
  await metaFile.writeAsString(jsonContent);
}

Future<Uint8List> readBackup(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw Exception('Backup file not found: $filePath');
  }
  return await file.readAsBytes();
}

Future<List<Map<String, dynamic>>> listBackupFiles(String dirPath) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) return [];

  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.backup'))
      .toList();

  files.sort((a, b) {
    final aStat = a.statSync();
    final bStat = b.statSync();
    return bStat.modified.compareTo(aStat.modified);
  });

  final results = <Map<String, dynamic>>[];
  for (final file in files) {
    final stat = file.statSync();
    final metaFile = File('${file.path}.meta');
    Map<String, dynamic>? metadata;

    if (await metaFile.exists()) {
      try {
        metadata = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
      } catch (e) {
        AppLogger.warning('Failed to parse backup metadata ${metaFile.path}: $e');
      }
    }

    results.add({
      'filePath': file.path,
      'fileName': file.uri.pathSegments.last,
      'sizeBytes': stat.size,
      'createdAt': stat.modified.toIso8601String(),
      'metadata': metadata,
    });
  }

  return results;
}

Future<void> deleteBackupFile(String filePath) async {
  final file = File(filePath);
  if (await file.exists()) {
    await file.delete();
  }
  final metaFile = File('$filePath.meta');
  if (await metaFile.exists()) {
    await metaFile.delete();
  }
}
