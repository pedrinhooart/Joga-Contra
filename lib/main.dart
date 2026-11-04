import 'package:flutter/material.dart';
import 'app.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

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
      home: const AppShell(),
    ),
  );
}
