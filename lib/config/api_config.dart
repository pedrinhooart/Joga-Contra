class ApiConfig {
  const ApiConfig._();

  // Sobrescreva ao executar: flutter run --dart-define=API_BASE_URL=http://192.168.0.10:3000/api
  // O padrão funciona no emulador Android; em desktop use http://localhost:3000/api.
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api',
  );
}
