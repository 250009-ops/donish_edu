import '../../../core/network/api_client.dart';

class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final json = await _apiClient.postJson(
      '/auth/login',
      body: {
        'username': username,
        'password': password,
      },
    );

    final token = json['token'] as String?;
    if (token == null) {
      throw const AuthException('Missing token in response.');
    }

    _apiClient.setToken(token);
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}

