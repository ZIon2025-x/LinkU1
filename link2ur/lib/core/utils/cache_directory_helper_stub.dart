/// Stub implementation — returns 0 on platforms without file system access (Web).
Future<int> calculateCacheDirectorySize() async => 0;

/// Stub implementation — no-op on Web.
Future<void> clearCacheDirectory() async {}
