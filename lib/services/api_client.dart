import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {required this.statusCode, this.code});
  final String message;
  final int statusCode;
  final String? code;
  bool get isUnauthorized => statusCode == 401;
  bool get isOffline => statusCode == 0;
  @override
  String toString() => message;
}

/// Único ponto de comunicação HTTP do app. Respostas seguem o envelope da API:
/// sucesso `{ "data": ..., "meta": ... }`, erro `{ "error": { "code", "message" } }`.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;
  final http.Client _client;
  final String _baseUrl;
  String? _token;

  /// Chamado quando a API responde 401 (sessão expirada).
  void Function()? onUnauthorized;

  void setToken(String? token) => _token = token;
  bool get hasToken => _token != null;

  Future<dynamic> get(String path, {Map<String, Object?>? query}) =>
      _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body: body);
  Future<dynamic> put(String path, [Object? body]) =>
      _send('PUT', path, body: body);
  Future<dynamic> patch(String path, [Object? body]) =>
      _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Envia um arquivo (ex.: imagem) como corpo binário, com mais tempo limite.
  Future<dynamic> putBytes(String path, Uint8List bytes, String contentType) =>
      _send(
        'PUT',
        path,
        bytes: bytes,
        contentType: contentType,
        timeout: ApiConfig.uploadTimeout,
      );

  Uri _uri(String path, Map<String, Object?>? query) {
    final params = <String, String>{
      for (final e in (query ?? const {}).entries)
        if (e.value != null && '${e.value}'.isNotEmpty) e.key: '${e.value}',
    };
    final uri = Uri.parse('$_baseUrl$path');
    return params.isEmpty ? uri : uri.replace(queryParameters: params);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, Object?>? query,
    Uint8List? bytes,
    String? contentType,
    Duration? timeout,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (bytes != null) headers['Content-Type'] = contentType!;
    if (_token != null) headers['Authorization'] = 'Bearer $_token';
    final http.Response response;
    try {
      final request = http.Request(method, _uri(path, query))
        ..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      if (bytes != null) request.bodyBytes = bytes;
      final streamed = await _client
          .send(request)
          .timeout(timeout ?? ApiConfig.requestTimeout);
      response = await http.Response.fromStream(streamed);
    } catch (_) {
      throw ApiException(
        'Não foi possível conectar ao servidor.',
        statusCode: 0,
      );
    }

    Map<String, dynamic> decoded = const {};
    if (response.body.isNotEmpty) {
      try {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        if (json is Map<String, dynamic>) decoded = json;
      } on FormatException {
        // Resposta não-JSON (proxy, HTML de erro): tratada abaixo pelo status.
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) {
        _token = null;
        onUnauthorized?.call();
      }
      final error = decoded['error'];
      throw ApiException(
        (error is Map ? error['message'] as String? : null) ??
            'Não foi possível concluir a solicitação.',
        statusCode: response.statusCode,
        code: error is Map ? error['code'] as String? : null,
      );
    }
    return decoded['data'];
  }
}
