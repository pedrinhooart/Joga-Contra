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

  testWidgets('aplicar filtros com o teclado aberto não quebra a tela', (
    tester,
  ) async {
    await _abrirApp(tester);
    // A fonte de teste é mais larga que a real: sem isto, os botões da folha transbordam.
    tester.view.physicalSize = const Size(700, 900);
    await tester.tap(find.text('Buscar').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Cidade'),
      'São Paulo',
    );
    await tester.tap(find.text('Aplicar filtros'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Filtrar jogos'), findsNothing);
    expect(find.text('Tem jogo esperando pelo seu time.'), findsOneWidget);

    // Reabrir mostra o filtro aplicado.
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'São Paulo'), findsOneWidget);
  });

  testWidgets('editar o nome do time no diálogo não quebra a tela', (
    tester,
  ) async {
    await _abrirApp(tester);
    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nome do time'),
      'Novo Nome FC',
    );
    await tester.tap(find.text('Salvar perfil'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Novo Nome FC'), findsWidgets);
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
