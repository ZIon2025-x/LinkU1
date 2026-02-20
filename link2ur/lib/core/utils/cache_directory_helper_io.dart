import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'logger.dart';

/// IO implementation — calculates the size of the temporary cache directory.
Future<int> calculateCacheDirectorySize() async {
  try {
    final cacheDir = await getTemporaryDirectory();
    return await _calculateDirectorySize(cacheDir);
  } catch (e) {
    AppLogger.warning('Failed to calculate cache directory size: $e');
    return 0;
  }
}

/// IO implementation — clears all files in the temporary cache directory.
Future<void> clearCacheDirectory() async {
  try {
    final cacheDir = await getTemporaryDirectory();
    if (cacheDir.existsSync()) {
      await for (final entity in cacheDir.list()) {
        try {
          if (entity is File) {
            await entity.delete();
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        } catch (_) {
          // Skip files that can't be deleted
        }
      }
    }
  } catch (e) {
    AppLogger.warning('Failed to clear cache directory: $e');
  }
}

Future<int> _calculateDirectorySize(Directory dir) async {
  int totalSize = 0;
  try {
    if (dir.existsSync()) {
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }
  } catch (e) {
    AppLogger.warning('Failed to calculate directory size: $e');
  }
  return totalSize;
}
