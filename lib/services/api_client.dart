import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {required this.statusCode});
  final String message;
  final int statusCode;
  bool get isUnauthorized => statusCode == 401;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  String? _token;
  void setToken(String? token) => _token = token;

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);
  Future<Map<String, dynamic>> post(String path, [Object? body]) => _send('POST', path, body);
  Future<Map<String, dynamic>> patch(String path, [Object? body]) => _send('PATCH', path, body);

  Future<Map<String, dynamic>> _send(String method, String path, [Object? body]) async {
    final headers = <String, String>{'Accept': 'application/json', 'Content-Type': 'application/json'};
    if (_token != null) headers['Authorization'] = 'Bearer $_token';
    try {
      final request = http.Request(method, Uri.parse('${ApiConfig.baseUrl}$path'))
        ..headers.addAll(headers)
        ..body = body == null ? '' : jsonEncode(body);
      final response = await _client.send(request).timeout(const Duration(seconds: 15));
      final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401) _token = null;
        throw ApiException((decoded['error']?['message'] as String?) ?? 'Não foi possível concluir a solicitação.', statusCode: response.statusCode);
      }
      return decoded;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Não foi possível conectar ao servidor.', statusCode: 0);
    }
  }
}
