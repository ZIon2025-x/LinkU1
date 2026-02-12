import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'secure_storage_stub.dart';
export 'secure_storage_stub.dart' show SecureTokenStorage;

/// IO (mobile/desktop) implementation — uses FlutterSecureStorage (Keychain/Keystore).
class _IoSecureStorage implements SecureTokenStorage {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read({required String key}) =>
      _storage.read(key: key);

  @override
  Future<void> delete({required String key}) =>
      _storage.delete(key: key);
}

SecureTokenStorage createSecureStorage() => _IoSecureStorage();
