import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'theme/rolagem.dart';
import 'theme/tipografia.dart';

void main() => runApp(const JogaContraApp());

class JogaContraApp extends StatefulWidget {
  const JogaContraApp({super.key, this.state});

  /// Permite injetar o estado (ex.: testes com repositórios de demonstração).
  final AppState? state;

  @override
  State<JogaContraApp> createState() => _JogaContraAppState();
}

class _JogaContraAppState extends State<JogaContraApp> {
  late final AppState state = widget.state ?? AppState.padrao();

  @override
  void initState() {
    super.initState();
    state.inicializar();
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
