import '../../../core/network/api_client.dart';
import 'auth_session_store.dart';

class AuthRepository {
  AuthRepository(
    this._apiClient, {
    AuthSessionStore? sessionStore,
  }) : _sessionStore = sessionStore ?? AuthSessionStore();

  final ApiClient _apiClient;
  final AuthSessionStore _sessionStore;

  /// Signs in and persists the session. Returns the user's Telegram ID as string.
  Future<String> login({
    required String id,
    required String password,
  }) async {
    final idNum = int.tryParse(id.trim());
    if (idNum == null) {
      throw const AuthException('Please enter a valid ID (numbers only).');
    }

    final json = await _apiClient.postJson(
      '/auth/login',
      body: {
        'id': idNum,
        'password': password,
      },
    );

    final token = json['token'] as String?;
    if (token == null) {
      throw const AuthException('Missing token in response.');
    }

    final user = json['user'];
    final telegramId = user is Map<String, dynamic>
        ? user['telegram_id']
        : null;
    final userId = telegramId?.toString() ?? id.trim();

    _apiClient.setToken(token);
    await _sessionStore.save(token: token, userId: userId);
    return userId;
  }

  /// Restores a saved session. Returns user id if valid, otherwise null.
  Future<String?> restoreSession() async {
    final session = await _sessionStore.read();
    if (session == null) return null;
    _apiClient.setToken(session.token);
    return session.userId;
  }

  /// Clears saved credentials and in-memory token (explicit sign out).
  Future<void> logout() async {
    _apiClient.clearToken();
    await _sessionStore.clear();
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}
