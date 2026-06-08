import '../../../core/device/device_id_store.dart';
import '../../../core/local_date.dart';
import '../../../core/network/api_client.dart';
import '../../billing/models/subscription_info.dart';
import 'auth_session_store.dart';

class AuthRepository {
  AuthRepository(
    this._apiClient, {
    AuthSessionStore? sessionStore,
    DeviceIdStore? deviceIdStore,
  })  : _sessionStore = sessionStore ?? AuthSessionStore(),
        _deviceIdStore = deviceIdStore ?? DeviceIdStore.instance;

  final ApiClient _apiClient;
  final AuthSessionStore _sessionStore;
  final DeviceIdStore _deviceIdStore;

  /// Signs in and persists the session. Returns the user's Telegram ID as string.
  Future<AuthLoginResult> login({
    required String id,
    required String password,
  }) async {
    final idNum = int.tryParse(id.trim());
    if (idNum == null) {
      throw const AuthException('Please enter a valid ID (numbers only).');
    }

    final deviceId = await _deviceIdStore.getOrCreate();
    final json = await _apiClient.postJson(
      '/auth/login',
      body: {
        'id': idNum,
        'password': password,
        'device_id': deviceId,
        'device_label': _deviceIdStore.deviceLabel(),
      },
    );

    final token = json['token'] as String?;
    if (token == null) {
      throw const AuthException('Missing token in response.');
    }

    final user = json['user'];
    if (user is! Map<String, dynamic>) {
      throw const AuthException('Unexpected login response from server.');
    }

    final rawTelegramId = user['telegram_id'];
    final userId = rawTelegramId == null
        ? id.trim()
        : rawTelegramId.toString();
    final createdAt = user['created_at'];
    final memberSinceIso =
        createdAt is String ? createdAt : createdAt?.toString();

    SubscriptionInfo subscription = SubscriptionInfo.freeDefaults();
    final subJson = json['subscription'];
    if (subJson is Map<String, dynamic>) {
      subscription = SubscriptionInfo.fromJson(subJson);
    }

    _apiClient.setToken(token);
    _apiClient.setDeviceId(deviceId);
    try {
      await _sessionStore.save(
        token: token,
        userId: userId,
        deviceId: deviceId,
        memberSinceIso: memberSinceIso,
      );
    } catch (e) {
      throw AuthException(
        'Signed in, but could not save session on this device. '
        'Try again or reinstall the app. ($e)',
      );
    }
    return AuthLoginResult(userId: userId, subscription: subscription);
  }

  /// Restores a saved session. Returns user id if valid, otherwise null.
  Future<String?> restoreSession() async {
    final session = await _sessionStore.read();
    if (session == null) return null;

    final deviceId = await _deviceIdStore.getOrCreate();
    if (deviceId != session.deviceId) {
      await _sessionStore.save(
        token: session.token,
        userId: session.userId,
        deviceId: deviceId,
        memberSinceIso: session.memberSinceIso,
      );
    }

    _apiClient.setToken(session.token);
    _apiClient.setDeviceId(deviceId);

    try {
      await _apiClient.getJson('/billing/subscription', authenticated: true);
      return session.userId;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await logout(localOnly: true);
        return null;
      }
      rethrow;
    }
  }

  /// Account signup instant (UTC ISO), for calendar bounds.
  Future<DateTime?> memberSinceLocal() async {
    final iso = await _sessionStore.readMemberSinceIso();
    return memberSinceFromIso(iso);
  }

  Future<void> persistMemberSinceIso(String? iso) async {
    await _sessionStore.saveMemberSinceIso(iso);
  }

  /// Clears saved credentials and in-memory token (explicit sign out).
  Future<void> logout({bool localOnly = false}) async {
    if (!localOnly) {
      try {
        await _apiClient.postJson('/auth/logout', authenticated: true);
      } catch (_) {
        // Still clear local session if server call fails.
      }
    }
    _apiClient.clearToken();
    await _sessionStore.clear();
  }
}

class AuthLoginResult {
  const AuthLoginResult({
    required this.userId,
    required this.subscription,
  });

  final String userId;
  final SubscriptionInfo subscription;
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}
