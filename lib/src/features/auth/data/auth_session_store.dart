import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists auth credentials so the user stays signed in until they log out.
class AuthSessionStore {
  AuthSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';

  final FlutterSecureStorage _storage;

  Future<void> save({
    required String token,
    required String userId,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
  }

  Future<({String token, String userId})?> read() async {
    final token = await _storage.read(key: _tokenKey);
    final userId = await _storage.read(key: _userIdKey);
    if (token == null ||
        token.isEmpty ||
        userId == null ||
        userId.isEmpty) {
      return null;
    }
    return (token: token, userId: userId);
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
  }
}
