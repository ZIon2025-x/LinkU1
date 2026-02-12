import 'dart:typed_data';

/// Stub implementation — backup is not supported on Web.

Future<String> getBackupDirPath() async => '';

Future<String> writeBackup(String dirPath, String fileName, Uint8List data) async {
  throw UnsupportedError('Backup not available on Web');
}

Future<void> writeMetadata(String filePath, String jsonContent) async {}

Future<Uint8List> readBackup(String filePath) async {
  throw UnsupportedError('Backup not available on Web');
}

Future<List<Map<String, dynamic>>> listBackupFiles(String dirPath) async => [];

Future<void> deleteBackupFile(String filePath) async {}
