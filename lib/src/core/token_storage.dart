import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the JWT access token in the platform secure store
/// (iOS Keychain / Android EncryptedSharedPreferences). Never in plain prefs.
class TokenStorage {
  TokenStorage(this._storage);

  static const String _key = 'access_token';
  static const String _userKey = 'auth_user';
  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _key);

  Future<void> write(String token) => _storage.write(key: _key, value: token);

  /// The last successful `GET /auth/me` payload (JSON), used to resume the
  /// session when the server is briefly unreachable instead of signing out.
  Future<String?> readUser() => _storage.read(key: _userKey);

  Future<void> writeUser(String json) =>
      _storage.write(key: _userKey, value: json);

  /// Clears the token **and** the cached user — call on a real sign-out / 401.
  Future<void> clear() async {
    await _storage.delete(key: _key);
    await _storage.delete(key: _userKey);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(
    const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  );
});
