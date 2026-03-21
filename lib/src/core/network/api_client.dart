import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  String? _token;

  void setToken(String token) {
    _token = token;
  }

  Future<dynamic> getJson(
    String path, {
    bool authenticated = false,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final headers = <String, String>{};
    if (authenticated && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }

    final response = await http.get(uri, headers: headers);
    final decoded = jsonDecode(response.body.isEmpty ? '{}' : response.body);

    if (response.statusCode >= 400) {
      final message = decoded is Map<String, dynamic> && decoded['error'] is String
          ? decoded['error'] as String
          : 'Request failed with status ${response.statusCode}';
      throw ApiException(message, statusCode: response.statusCode);
    }

    return decoded;
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (authenticated && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }

    final response = await http.post(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );

    final decoded = jsonDecode(response.body.isEmpty ? '{}' : response.body);

    if (response.statusCode >= 400) {
      final message = decoded is Map<String, dynamic> && decoded['error'] is String
          ? decoded['error'] as String
          : 'Request failed with status ${response.statusCode}';
      throw ApiException(message, statusCode: response.statusCode);
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
    if (authenticated && _token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final decoded = jsonDecode(response.body.isEmpty ? '{}' : response.body);

    if (response.statusCode >= 400) {
      final message = decoded is Map<String, dynamic> && decoded['error'] is String
          ? decoded['error'] as String
          : 'Request failed with status ${response.statusCode}';
      throw ApiException(message, statusCode: response.statusCode);
    }

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const ApiException('Unexpected response format.');
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

