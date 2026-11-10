import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joga_contra/main.dart';
import 'package:joga_contra/repositories/demo/demo_repositories.dart';
import 'package:joga_contra/services/municipios.dart';
import 'package:joga_contra/state/app_state.dart';

Future<void> _abrirApp(WidgetTester tester) async {
  // Asset carregado fora do relógio simulado do teste.
  await tester.runAsync(Municipios.carregar);
  tester.view.physicalSize = const Size(700, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    JogaContraApp(state: AppState(criarRepositoriosDemo())),
  );
  await tester.pumpAndSettle();
}

Future<void> _abrirCadastro(WidgetTester tester) async {
  await _abrirApp(tester);
  await tester.tap(find.text('Perfil').last);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Sair da conta'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sair da conta'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ainda não tem conta? Criar conta'));
  await tester.pumpAndSettle();
  expect(find.text('Vamos começar?'), findsOneWidget);
}

Future<void> _escolherEstado(WidgetTester tester, String sigla) async {
  final campo = find.byType(DropdownButtonFormField<String>);
  await tester.ensureVisible(campo);
  await tester.pumpAndSettle();
  await tester.tap(campo);
  await tester.pumpAndSettle();
  // O menu só monta os itens visíveis: rola até a sigla.
  await tester.scrollUntilVisible(
    find.text(sigla),
    120,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text(sigla).last);
  await tester.pumpAndSettle();
}

Finder get _campoCidade => find.widgetWithText(TextFormField, 'Cidade');

/// Textos da lista de sugestões aberta, na ordem exibida.
List<String> _sugestoes(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('sugestoes-cidade')),
        matching: find.byType(Text),
      ),
    )
    .map((t) => t.data!)
    .toList();

void main() {
  group('municípios do IBGE', () {
    late Municipios municipios;
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      municipios = await Municipios.carregar();
    });

    test('lista completa e em ordem alfabética', () {
      const ufs = [
        'AC', 'AL', 'AM', 'AP', 'BA', 'CE', 'DF', 'ES', 'GO', //
        'MA', 'MG', 'MS', 'MT', 'PA', 'PB', 'PE', 'PI', 'PR', 'RJ', 'RN', //
        'RO', 'RR', 'RS', 'SC', 'SE', 'SP', 'TO',
      ];
      final total = ufs.fold<int>(0, (s, uf) => s + municipios.daUf(uf).length);
      expect(total, 5571);
      expect(municipios.daUf('SP'), hasLength(645));
      expect(municipios.daUf('DF'), ['Brasília']);
      for (final uf in ufs) {
        final nomes = municipios.daUf(uf).map(Municipios.normalizar).toList();
        expect(nomes, [...nomes]..sort(), reason: uf);
      }
    });

    test('filtra pelo texto, ignora acentos e prioriza o início do nome', () {
      final sugestoes = municipios.sugerir('SP', 'sao pa');
      expect(sugestoes.first, 'São Paulo');
      expect(sugestoes, everyElement(startsWith('São Pa')));
      final contem = municipios.sugerir('SP', 'paulo');
      expect(contem.first, 'Paulo de Faria'); // começa com o texto
      expect(contem, contains('São Paulo')); // contém o texto
      expect(municipios.sugerir('RJ', 'santos'), isEmpty);
    });

    test('só aceita cidade da UF escolhida, com o nome oficial', () {
      expect(municipios.oficial('SP', '  sao   paulo '), 'São Paulo');
      expect(municipios.oficial('RJ', 'São Paulo'), isNull);
      expect(municipios.oficial('SP', 'Cidade Inventada'), isNull);
    });
  });

  testWidgets('cadastro só pede o essencial, com estado antes da cidade', (
    tester,
  ) async {
    await _abrirCadastro(tester);
    for (final removido in [
      'Telefone',
      'Modalidade',
      'Categoria',
      'Nível do time',
      'Quantidade de jogadores',
    ]) {
      expect(find.text(removido), findsNothing, reason: removido);
    }
    final estadoY = tester.getTopLeft(find.text('Estado')).dy;
    final cidadeY = tester.getTopLeft(find.text('Cidade')).dy;
    expect(estadoY, lessThan(cidadeY));

    // Sem estado, a cidade fica bloqueada.
    expect(tester.widget<TextFormField>(_campoCidade).enabled, isFalse);
  });

  testWidgets('cidade sugere, filtra, seleciona e é limpa ao trocar o estado', (
    tester,
  ) async {
    await _abrirCadastro(tester);
    await _escolherEstado(tester, 'SP');
    expect(tester.widget<TextFormField>(_campoCidade).enabled, isTrue);

    await tester.ensureVisible(_campoCidade);
    await tester.pumpAndSettle();
    await tester.enterText(_campoCidade, 'sao p');
    await tester.pumpAndSettle();
    final lista = _sugestoes(tester);
    // Primeiro os que começam com o texto, depois os que só o contêm;
    // cada grupo em ordem alfabética.
    expect(lista, [
      'São Paulo',
      'São Pedro',
      'São Pedro do Turvo',
      'Águas de São Pedro',
    ]);

    await tester.enterText(_campoCidade, 'sao paulo');
    await tester.pumpAndSettle();
    await tester.tap(find.text('São Paulo').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(_campoCidade).controller!.text,
      'São Paulo',
    );

    // Outro estado: a cidade de SP é descartada e não é mais sugerida.
    await _escolherEstado(tester, 'RJ');
    expect(tester.widget<TextFormField>(_campoCidade).controller!.text, '');
    await tester.enterText(_campoCidade, 'santos');
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma cidade de RJ com esse nome.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cria a conta só com o essencial; o anúncio pede os dados do jogo',
    (tester) async {
      await _abrirCadastro(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome do responsável'),
        'Ana',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        'ana@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        'senha-segura-1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome do time'),
        'Unidos FC',
      );
      await _escolherEstado(tester, 'SP');
      await tester.enterText(_campoCidade, 'campinas');
      await tester.pumpAndSettle();

      // Cidade digitada sem acento ou maiúscula vira o nome oficial.
      await tester.ensureVisible(find.text('Criar perfil do time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Criar perfil do time'));
      await tester.pumpAndSettle();
      expect(find.text('BOM TE VER, ANA'), findsOneWidget);
      expect(
        find.text('Encontre o próximo adversário para o Unidos FC.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5)); // snackbar

      // Perfil: cidade com o nome oficial e nenhum dado que não foi pedido.
      await tester.tap(find.text('Perfil').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Campinas, SP'), findsOneWidget);
      expect(find.textContaining('jogadores'), findsNothing);

      // Anúncio: modalidade e nível continuam, sem nada marcado; categoria,
      // quantidade, mando e bairro saíram do formulário.
      await tester.tap(find.text('Anunciar').last);
      await tester.pumpAndSettle();
      for (final campo in ['Modalidade', 'Nível do time']) {
        final dropdown = find.widgetWithText(
          DropdownButtonFormField<int>,
          campo,
        );
        expect(dropdown, findsOneWidget, reason: campo);
        expect(
          tester.widget<DropdownButtonFormField<int>>(dropdown).initialValue,
          isNull,
          reason: campo,
        );
      }
      for (final removido in [
        'Categoria',
        'Quantidade de jogadores',
        'Mando de campo',
        'Bairro / região',
      ]) {
        expect(find.text(removido), findsNothing, reason: removido);
      }
      await tester.tap(find.text('Nível do time'));
      await tester.pumpAndSettle();
      for (final nivel in ['Iniciante', 'Intermediário', 'Avançado']) {
        expect(find.text(nivel), findsWidgets, reason: nivel);
      }
    },
  );

  testWidgets('cidade fora da lista não passa na validação', (tester) async {
    await _abrirCadastro(tester);
    await _escolherEstado(tester, 'SP');
    await tester.enterText(_campoCidade, 'Cidade Inventada');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Criar perfil do time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar perfil do time'));
    await tester.pumpAndSettle();
    expect(find.text('Escolha uma cidade de SP na lista'), findsOneWidget);
    expect(find.text('Vamos começar?'), findsOneWidget);
  });

  group('rolagem sem efeito de overscroll', () {
    for (final plataforma in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets('em ${plataforma.name}: rola, mas não estica nem brilha', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = plataforma;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        await _abrirApp(tester);

        for (final aba in ['Início', 'Buscar', 'Perfil']) {
          await tester.tap(find.text(aba).last);
          await tester.pumpAndSettle();
          expect(find.byType(GlowingOverscrollIndicator), findsNothing);
          expect(find.byType(StretchingOverscrollIndicator), findsNothing);

          final lista = find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .first;
          final posicao = tester.state<ScrollableState>(lista).position;

          // Puxar além do topo não desloca o conteúdo (sem elástico).
          await tester.drag(lista, const Offset(0, 300));
          await tester.pump();
          expect(posicao.pixels, 0, reason: aba);
          await tester.pumpAndSettle();

          // A rolagem normal continua funcionando.
          await tester.drag(lista, const Offset(0, -200));
          await tester.pumpAndSettle();
          expect(posicao.pixels, greaterThan(0), reason: aba);
        }
        debugDefaultTargetPlatformOverride = null;
      });
    }
  });
}
