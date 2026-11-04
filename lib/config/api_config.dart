import 'package:flutter/foundation.dart';

/// Configurações técnicas do app. Nada aqui é dado de negócio e nenhum
/// segredo pode ser colocado neste arquivo (o app é distribuído ao usuário).
class ApiConfig {
  const ApiConfig._();

  /// Sobrescreva ao executar:
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.0.10:3000/api`.
  /// O padrão funciona no emulador Android; em desktop use http://localhost:3000/api.
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api',
  );

  /// Usa repositórios em memória com dados fictícios de demonstração.
  /// Padrão: ligado em debug/teste, desligado em release. Builds de produção
  /// nunca carregam dados fictícios, a menos que alguém force
  /// `--dart-define=USE_DEMO_DATA=true`.
  static const useDemoData = bool.fromEnvironment(
    'USE_DEMO_DATA',
    defaultValue: !kReleaseMode,
  );

  static const requestTimeout = Duration(seconds: 15);
}
