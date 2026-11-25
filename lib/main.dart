import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app.dart';
import 'services/links_recebidos.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'theme/rolagem.dart';
import 'theme/tipografia.dart';

void main() => runApp(JogaContraApp(links: LinksRecebidos.fluxo()));

class JogaContraApp extends StatefulWidget {
  const JogaContraApp({super.key, this.state, this.links});

  /// Permite injetar o estado (ex.: testes com repositórios de demonstração).
  final AppState? state;

  /// Links que abrem o app (ex.: redefinição de senha do e-mail).
  final Stream<Uri>? links;

  @override
  State<JogaContraApp> createState() => _JogaContraAppState();
}

class _JogaContraAppState extends State<JogaContraApp> {
  late final AppState state = widget.state ?? AppState.padrao();

  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    state.inicializar();
    // Inclui o link que abriu o app (com ele fechado).
    _links = widget.links?.listen(state.abrirLink, onError: (_) {});
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    state: state,
    child: MaterialApp(
      title: 'Joga Contra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: const RolagemSemEfeito(),
      // Calendário, relógio e textos do Material em português do Brasil.
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Fontes maiores em todas as telas, mantendo a escala do sistema.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: EscalaDeLeitura(MediaQuery.textScalerOf(context)),
        ),
        child: child!,
      ),
      home: const AppShell(),
    ),
  );
}
