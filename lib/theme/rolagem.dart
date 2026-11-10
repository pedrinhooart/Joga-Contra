import 'package:flutter/material.dart';

/// Rolagem do app inteiro sem efeito visual no limite do conteúdo: sem brilho
/// (Android antigo), sem esticar (Android 12+) e sem elástico (iOS).
/// A rolagem em si continua igual; só some o efeito de overscroll.
class RolagemSemEfeito extends MaterialScrollBehavior {
  const RolagemSemEfeito();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}
