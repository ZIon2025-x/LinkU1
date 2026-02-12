/// Abstract interface for secure token storage.
/// Stub — should never be called at runtime.
abstract class SecureTokenStorage {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
}

SecureTokenStorage createSecureStorage() {
  throw UnsupportedError('Secure storage not available on this platform');
}
