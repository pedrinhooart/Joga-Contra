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

  /// O app sempre usa a API. Os dados fictícios em memória só entram quando
  /// pedidos de forma explícita: `--dart-define=USE_DEMO_DATA=true`.
  static const useDemoData = bool.fromEnvironment('USE_DEMO_DATA');

  static const requestTimeout = Duration(seconds: 15);

  /// Envio de imagens: mais tempo que as demais requisições.
  static const uploadTimeout = Duration(seconds: 60);

  /// Endereço completo de um arquivo devolvido pela API (ex.: escudo do time).
  /// A API guarda caminhos como `/api/arquivos/...`; endereços completos
  /// (como os de um armazenamento na nuvem) são usados como vieram.
  static String? urlArquivo(String? endereco) {
    if (endereco == null || endereco.isEmpty) return null;
    if (Uri.parse(endereco).hasScheme) return endereco;
    return Uri.parse(baseUrl).resolve(endereco).toString();
  }
}
