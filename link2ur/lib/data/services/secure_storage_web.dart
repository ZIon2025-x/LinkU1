import 'dart:convert';
import 'package:web/web.dart' as web;
import 'secure_storage_stub.dart';
export 'secure_storage_stub.dart' show SecureTokenStorage;

/// Web implementation — uses sessionStorage for token storage.
/// sessionStorage is cleared when the tab closes, providing basic security.
/// For higher security, consider encrypting values before storing.
class _WebSecureStorage implements SecureTokenStorage {
  // Use a prefix to avoid collisions with other storage
  static const _prefix = 'link2ur_secure_';

  @override
  Future<void> write({required String key, required String value}) async {
    // Base64 encode to provide basic obfuscation (not true encryption)
    final encoded = base64Encode(utf8.encode(value));
    web.window.sessionStorage.setItem('$_prefix$key', encoded);
  }

  @override
  Future<String?> read({required String key}) async {
    final encoded = web.window.sessionStorage.getItem('$_prefix$key');
    if (encoded == null) return null;
    try {
      return utf8.decode(base64Decode(encoded));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> delete({required String key}) async {
    web.window.sessionStorage.removeItem('$_prefix$key');
  }
}

SecureTokenStorage createSecureStorage() => _WebSecureStorage();
