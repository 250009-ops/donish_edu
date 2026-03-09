import '../../../core/network/api_client.dart';

class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<void> login({
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

    _apiClient.setToken(token);
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}

