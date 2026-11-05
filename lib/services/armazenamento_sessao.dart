import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda o JWT entre aberturas do app. Somente o token é persistido: nenhuma
/// credencial do banco ou segredo da API existe no aplicativo.
abstract interface class ArmazenamentoSessao {
  Future<String?> lerToken();
  Future<void> salvarToken(String token);
  Future<void> apagarToken();
}

/// Keychain/Keystore do sistema operacional.
class ArmazenamentoSeguro implements ArmazenamentoSessao {
  const ArmazenamentoSeguro();
  static const _chave = 'joga_contra_token';
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> lerToken() => _storage.read(key: _chave);
  @override
  Future<void> salvarToken(String token) =>
      _storage.write(key: _chave, value: token);
  @override
  Future<void> apagarToken() => _storage.delete(key: _chave);
}

/// Sem persistência (testes).
class ArmazenamentoEmMemoria implements ArmazenamentoSessao {
  String? token;
  @override
  Future<String?> lerToken() async => token;
  @override
  Future<void> salvarToken(String valor) async => token = valor;
  @override
  Future<void> apagarToken() async => token = null;
}
