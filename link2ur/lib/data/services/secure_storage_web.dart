import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
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
    html.window.sessionStorage['$_prefix$key'] = encoded;
  }

  @override
  Future<String?> read({required String key}) async {
    final encoded = html.window.sessionStorage['$_prefix$key'];
    if (encoded == null) return null;
    try {
      return utf8.decode(base64Decode(encoded));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> delete({required String key}) async {
    html.window.sessionStorage.remove('$_prefix$key');
  }
}

SecureTokenStorage createSecureStorage() => _WebSecureStorage();
