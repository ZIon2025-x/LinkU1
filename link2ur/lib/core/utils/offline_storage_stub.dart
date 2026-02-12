/// Stub implementation — Web does not support offline file operations.

Future<void> saveOperationsToFile(String fileName, String jsonContent) async {}

Future<String?> loadOperationsFromFile(String fileName) async => null;

/// Perform an HTTP request using dart:io HttpClient.
/// Returns a map with 'statusCode' and optionally 'body'.
Future<Map<String, dynamic>> performHttpRequest({
  required String method,
  required String endpoint,
  Map<String, String>? headers,
  Map<String, dynamic>? body,
}) async {
  throw UnsupportedError('Offline sync HTTP not available on Web');
}

/// Save data to a JSON file in the app's documents directory.
Future<void> saveDataToFile(String basePath, String key, String jsonContent) async {}

/// Load data from a JSON file.
Future<String?> loadDataFromFile(String basePath, String key) async => null;

/// Delete a JSON file.
Future<void> deleteDataFile(String basePath, String key) async {}

/// Check if a JSON file exists.
Future<bool> dataFileExists(String basePath, String key) async => false;

/// Get or create the base path for offline data.
Future<String> getOfflineDataPath() async => '';

/// Clear all offline data.
Future<void> clearOfflineData(String basePath) async {}
