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
  static const _memberSinceKey = 'member_since';
  static const _deviceIdKey = 'device_id';

  final FlutterSecureStorage _storage;

  Future<void> save({
    required String token,
    required String userId,
    required String deviceId,
    String? memberSinceIso,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
    await _storage.write(key: _deviceIdKey, value: deviceId);
    if (memberSinceIso != null && memberSinceIso.isNotEmpty) {
      await _storage.write(key: _memberSinceKey, value: memberSinceIso);
    } else {
      await _storage.delete(key: _memberSinceKey);
    }
  }

  Future<({String token, String userId, String deviceId, String? memberSinceIso})?>
      read() async {
    final token = await _storage.read(key: _tokenKey);
    final userId = await _storage.read(key: _userIdKey);
    final deviceId = await _storage.read(key: _deviceIdKey);
    if (token == null ||
        token.isEmpty ||
        userId == null ||
        userId.isEmpty ||
        deviceId == null ||
        deviceId.isEmpty) {
      return null;
    }
    final memberSinceIso = await _storage.read(key: _memberSinceKey);
    return (
      token: token,
      userId: userId,
      deviceId: deviceId,
      memberSinceIso: memberSinceIso
    );
  }

  Future<String?> readMemberSinceIso() async {
    return _storage.read(key: _memberSinceKey);
  }

  Future<void> saveMemberSinceIso(String? memberSinceIso) async {
    if (memberSinceIso != null && memberSinceIso.isNotEmpty) {
      await _storage.write(key: _memberSinceKey, value: memberSinceIso);
    } else {
      await _storage.delete(key: _memberSinceKey);
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _memberSinceKey);
    await _storage.delete(key: _deviceIdKey);
  }
}
