import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app.dart';
import 'services/armazenamento_sessao.dart';
import 'services/links_recebidos.dart';
import 'services/push.dart';
import 'state/app_state.dart';
import 'state/controle_push.dart';
import 'theme/app_theme.dart';
import 'theme/rolagem.dart';
import 'theme/tipografia.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Null sem configuração do Firebase neste build: o app funciona sem push.
  final push = await PushFirebase.iniciar();
  runApp(JogaContraApp(links: LinksRecebidos.fluxo(), push: push));
}

class JogaContraApp extends StatefulWidget {
  const JogaContraApp({
    super.key,
    this.state,
    this.links,
    this.push,
    this.armazenamentoPush = const ArmazenamentoSeguro(),
  });

  /// Permite injetar o estado (ex.: testes com repositórios de demonstração).
  final AppState? state;

  /// Links que abrem o app (ex.: redefinição de senha do e-mail).
  final Stream<Uri>? links;

  /// Notificações push (Firebase). Null: sem push (demonstração, testes ou
  /// build sem configuração do Firebase).
  final ServicoPush? push;

  /// Onde fica o último token de push registrado por este aparelho.
  final ArmazenamentoSessao armazenamentoPush;

  @override
  State<JogaContraApp> createState() => _JogaContraAppState();
}

class _JogaContraAppState extends State<JogaContraApp> {
  late final AppState state = widget.state ?? AppState.padrao();

  StreamSubscription<Uri>? _links;
  ControlePush? _push;

  @override
  void initState() {
    super.initState();
    state.inicializar();
    // Inclui o link que abriu o app (com ele fechado).
    _links = widget.links?.listen(state.abrirLink, onError: (_) {});
    final servico = widget.push;
    if (servico != null) {
      _push = ControlePush(
        estado: state,
        servico: servico,
        dispositivos: state.repositorios.dispositivos,
        armazenamento: widget.armazenamentoPush,
      )..iniciar();
    }
  }

  @override
  void dispose() {
    _links?.cancel();
    _push?.encerrar();
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
