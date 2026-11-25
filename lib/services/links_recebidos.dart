import 'package:app_links/app_links.dart';

/// Links que abrem o app (hoje, só o de redefinição de senha).
///
/// Formatos aceitos:
/// - `jogacontra://redefinir-senha?token=...` (aberto pela página do link do e-mail);
/// - `https://<URL_PUBLICA>/redefinir-senha#token=...` (Android App Links, com domínio próprio).
abstract final class LinksRecebidos {
  /// Todos os links: o que abriu o app e os que chegarem com ele aberto.
  static Stream<Uri> fluxo() => AppLinks().uriLinkStream;

  static final _formatoToken = RegExp(r'^[A-Za-z0-9_-]{43}$');

  /// Link de redefinição de senha (com token válido ou não).
  static bool eRedefinicao(Uri uri) =>
      (uri.scheme == 'jogacontra' && uri.host == 'redefinir-senha') ||
      ((uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.path == '/redefinir-senha');

  /// Token de redefinição de senha contido no link, ou null se não houver um
  /// token bem formado.
  static String? tokenDeRedefinicao(Uri uri) {
    if (!eRedefinicao(uri)) return null;
    final token =
        uri.queryParameters['token'] ??
        (uri.fragment.isEmpty
            ? null
            : Uri.splitQueryString(uri.fragment)['token']);
    return token != null && _formatoToken.hasMatch(token) ? token : null;
  }
}
