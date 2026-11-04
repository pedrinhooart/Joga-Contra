import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joga_contra/main.dart';
import 'package:joga_contra/repositories/demo/demo_repositories.dart';
import 'package:joga_contra/state/app_state.dart';

Future<void> _abrirApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    JogaContraApp(state: AppState(criarRepositoriosDemo())),
  );
  await tester.pumpAndSettle();
}

Finder get _listaVertical => find
    .byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    )
    .first;

void main() {
  testWidgets('abre o início com dados da sessão e navega para a busca', (
    tester,
  ) async {
    await _abrirApp(tester);
    expect(find.text('Seu time entra em campo. ⚽'), findsOneWidget);
    expect(find.text('BOM TE VER, JOÃO'), findsOneWidget);
    expect(
      find.text('Encontre o próximo adversário para o União FC.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Buscar').last);
    await tester.pumpAndSettle();
    expect(find.text('Tem jogo esperando pelo seu time.'), findsOneWidget);
    expect(find.text('Real Amigos FC'), findsWidgets);
    // Modalidades vêm dos cadastros de referência, não de listas fixas.
    expect(find.text('Futebol de quadra'), findsWidgets);
  });

  testWidgets('interesse vira conversa e a confirmação cria a partida', (
    tester,
  ) async {
    await _abrirApp(tester);
    await tester.tap(find.text('Buscar').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Ver detalhes').first,
      280,
      scrollable: _listaVertical,
    );
    await tester.tap(find.text('Ver detalhes').first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tenho interesse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sim, tenho interesse'));
    await tester.pumpAndSettle();
    expect(find.text('Quase tudo pronto!'), findsOneWidget);

    // Espera o snackbar "Interesse enviado!" sumir para não cobrir o botão.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirmar partida'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar partida'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar partida'));
    await tester.pumpAndSettle();
    expect(find.text('Partida confirmada!'), findsOneWidget);
  });

  testWidgets('sair da conta leva para a tela de entrar', (tester) async {
    await _abrirApp(tester);
    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sair da conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair da conta'));
    await tester.pumpAndSettle();
    expect(find.text('Seu time em campo.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
