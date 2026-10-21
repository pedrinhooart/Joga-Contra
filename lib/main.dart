import 'package:flutter/material.dart';
import 'app.dart';
import 'theme/app_theme.dart';

void main() => runApp(const JogaContraApp());

class JogaContraApp extends StatelessWidget {
  const JogaContraApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Joga Contra',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const AppShell(),
  );
}
