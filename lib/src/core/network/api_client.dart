import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  String? _token;
  String? _deviceId;

  void setToken(String token) {
    _token = token;
  }

  void setDeviceId(String deviceId) {
    _deviceId = deviceId;
  }

  void clearToken() {
    _token = null;
  }

  Map<String, String> _authHeaders({required bool authenticated}) {
    final headers = <String, String>{};
    if (authenticated && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    if (authenticated && _deviceId != null && _deviceId!.isNotEmpty) {
      headers['X-Device-Id'] = _deviceId!;
    }
    return headers;
  }

  Future<dynamic> getJson(
    String path, {
    Map<String, String>? queryParameters,
    bool authenticated = false,
  }) async {
    final base = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final uri = queryParameters == null || queryParameters.isEmpty
        ? base
        : base.replace(
            queryParameters: {
              ...base.queryParameters,
              ...queryParameters,
            },
          );
    final response = await http.get(uri, headers: _authHeaders(authenticated: authenticated));
    final decoded = jsonDecode(response.body.isEmpty ? '{}' : response.body);

    if (response.statusCode >= 400) {
      final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      final message = map['error'] is String
          ? map['error'] as String
          : 'Request failed with status ${response.statusCode}';
      final code = map['code'] is String ? map['code'] as String : null;
      throw ApiException(message, statusCode: response.statusCode, code: code);
    }

    return decoded;
  }

  /// DELETE with optional auth. Accepts 204 No Content or empty body.
  Future<void> deleteJson(
    String path, {
    bool authenticated = false,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final response = await http.delete(
      uri,
      headers: _authHeaders(authenticated: authenticated),
    );

    if (response.statusCode >= 400) {
      dynamic decoded;
      try {
        decoded = response.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(response.body);
      } catch (_) {
        decoded = <String, dynamic>{};
      }
      final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      final message = map['error'] is String
          ? map['error'] as String
          : 'Request failed with status ${response.statusCode}';
      final code = map['code'] is String ? map['code'] as String : null;
      throw ApiException(message, statusCode: response.statusCode, code: code);
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ..._authHeaders(authenticated: authenticated),
    };

    final response = await http.post(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );

    final decoded = jsonDecode(response.body.isEmpty ? '{}' : response.body);

    if (response.statusCode >= 400) {
      final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      final message = map['error'] is String
          ? map['error'] as String
          : 'Request failed with status ${response.statusCode}';
      final code = map['code'] is String ? map['code'] as String : null;
      throw ApiException(message, statusCode: response.statusCode, code: code);
    }

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const ApiException('Unexpected response format.');
  }

  /// Multipart upload (e.g. PDF). [fileField] must match server (we use `file`).
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required List<int> fileBytes,
    required String fileName,
    bool authenticated = false,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final request = http.MultipartRequest('POST', uri);
    request.fields.addAll(fields);
    request.files.add(
      http.MultipartFile.fromBytes(
        fileField,
        fileBytes,
        filename: fileName,
        contentType: MediaType('application', 'pdf'),
      ),
    );
    for (final entry in _authHeaders(authenticated: authenticated).entries) {
      request.headers[entry.key] = entry.value;
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final decoded = jsonDecode(response.body.isEmpty ? '{}' : response.body);

    if (response.statusCode >= 400) {
      final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      final message = map['error'] is String
          ? map['error'] as String
          : 'Request failed with status ${response.statusCode}';
      final code = map['code'] is String ? map['code'] as String : null;
      throw ApiException(message, statusCode: response.statusCode, code: code);
    }

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const ApiException('Unexpected response format.');
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  /// Optional machine-readable code from API (e.g. `pdf_no_extractable_text`).
  final String? code;

  @override
  String toString() => message;
}

