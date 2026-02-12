import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// IO implementation — uses File system for offline operations.

Future<void> saveOperationsToFile(String fileName, String jsonContent) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(jsonContent);
}

Future<String?> loadOperationsFromFile(String fileName) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileName');
  if (await file.exists()) {
    return await file.readAsString();
  }
  return null;
}

/// Perform an HTTP request using dart:io HttpClient.
Future<Map<String, dynamic>> performHttpRequest({
  required String method,
  required String endpoint,
  Map<String, String>? headers,
  Map<String, dynamic>? body,
}) async {
  final uri = Uri.parse(endpoint);
  final request = await HttpClient().openUrl(method, uri);

  headers?.forEach((key, value) {
    request.headers.set(key, value);
  });

  if (body != null) {
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
  }

  final response = await request.close();
  final result = <String, dynamic>{
    'statusCode': response.statusCode,
  };

  if (response.statusCode == 409) {
    final responseBody = await response.transform(utf8.decoder).join();
    result['body'] = responseBody;
  }

  return result;
}

/// Save data to a JSON file in the app's documents directory.
Future<void> saveDataToFile(String basePath, String key, String jsonContent) async {
  final file = File('$basePath/$key.json');
  await file.writeAsString(jsonContent);
}

/// Load data from a JSON file.
Future<String?> loadDataFromFile(String basePath, String key) async {
  final file = File('$basePath/$key.json');
  if (await file.exists()) {
    return await file.readAsString();
  }
  return null;
}

/// Delete a JSON file.
Future<void> deleteDataFile(String basePath, String key) async {
  final file = File('$basePath/$key.json');
  if (await file.exists()) {
    await file.delete();
  }
}

/// Check if a JSON file exists.
Future<bool> dataFileExists(String basePath, String key) async {
  return File('$basePath/$key.json').exists();
}

/// Get or create the base path for offline data.
Future<String> getOfflineDataPath() async {
  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/OfflineData';
  await Directory(path).create(recursive: true);
  return path;
}

/// Clear all offline data.
Future<void> clearOfflineData(String basePath) async {
  final dir = Directory(basePath);
  if (await dir.exists()) {
    await dir.delete(recursive: true);
    await dir.create(recursive: true);
  }
}
