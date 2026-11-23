import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joga_contra/main.dart';
import 'package:joga_contra/models/anuncio_partida.dart';
import 'package:joga_contra/repositories/demo/demo_repositories.dart';
import 'package:joga_contra/state/app_state.dart';
import 'package:joga_contra/theme/tipografia.dart';
import 'package:joga_contra/widgets/common.dart';

/// Etapa 3: busca sem raio de distância, tipos de jogo legíveis, perfil sem
/// telefone, fontes maiores e frase do início sem emoji. A tela padrão é alta
/// para a lista de resultados (preguiçosa) ser montada inteira, e larga porque
/// a fonte dos testes (Ahem) é bem mais larga que a do app.
Future<AppState> _abrirApp(
  WidgetTester tester, {
  Size tela = const Size(600, 1600),
}) async {
  tester.view.physicalSize = tela;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final state = AppState(criarRepositoriosDemo());
  await tester.pumpWidget(JogaContraApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

Future<void> _abrirBusca(WidgetTester tester) async {
  await tester.tap(find.text('Buscar').last);
  await tester.pumpAndSettle();
}

/// Contagem que a tela mostra ("N jogos disponíveis · ...").
int _contagem(WidgetTester tester) {
  final texto = find.textContaining('jogos disponíveis');
  final s = tester.widget<Text>(texto).data!;
  return int.parse(s.split(' ').first);
}

const _opcoes = [
  'Todos',
  'Society/Futebol Sintético',
  'Futsal',
  'Futebol de Campo',
  'Futebol de Campo Reduzido',
];

void main() {
  group('busca', () {
    testWidgets('sem filtro de raio de distância', (tester) async {
      await _abrirApp(tester);
      await _abrirBusca(tester);
      // A distância de cada anúncio continua no card; só o filtro saiu.
      expect(
        find.descendant(
          of: find.byType(TagPill),
          matching: find.textContaining('km'),
        ),
        findsNothing,
      );
      expect(find.text('25 km'), findsNothing);
      await tester.tap(find.text('Filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Raio de distância'), findsNothing);
      // Os outros filtros continuam.
      for (final campo in [
        'Data disponível',
        'Horário a partir de',
        'Cidade',
        'Nível do time',
      ]) {
        expect(find.text(campo), findsOneWidget, reason: campo);
      }
      // E o parâmetro não vai mais para a API.
      expect(const FiltroAnuncios().toQuery().containsKey('raioKm'), isFalse);
    });

    testWidgets('nível e cidade continuam filtrando', (tester) async {
      await _abrirApp(tester);
      await _abrirBusca(tester);
      expect(_contagem(tester), 4);

      await tester.tap(find.text('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todos').last); // nível
      await tester.pumpAndSettle();
      await tester.tap(find.text('Avançado').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();
      expect(_contagem(tester), 1);
      expect(find.text('Atlético da Zona Sul'), findsWidgets);

      await tester.tap(find.text('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpar filtros').last);
      await tester.pumpAndSettle();
      expect(_contagem(tester), 4);

      await tester.tap(find.text('Filtros'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Cidade'),
        'Campinas',
      );
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();
      expect(_contagem(tester), 0);
      expect(find.text('Nenhum rival por aqui. Ainda.'), findsOneWidget);
    });

    for (final tela in const [Size(360, 640), Size(390, 844), Size(412, 915)]) {
      testWidgets(
        'cinco tipos de jogo inteiros e legíveis em ${tela.width.toInt()}x${tela.height.toInt()}',
        (tester) async {
          await _abrirApp(tester, tela: tela);
          await _abrirBusca(tester);
          expect(find.byType(ChipFiltro), findsNWidgets(5));
          for (final nome in _opcoes) {
            final texto = find.descendant(
              of: find.widgetWithText(ChipFiltro, nome),
              matching: find.text(nome),
            );
            expect(texto, findsOneWidget, reason: nome);
            final paragrafo = tester.renderObject<RenderParagraph>(texto);
            expect(paragrafo.didExceedMaxLines, isFalse, reason: nome);
            // Cabe na largura da tela.
            expect(tester.getRect(texto).right, lessThanOrEqualTo(tela.width));
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('cada tipo de jogo traz só a sua modalidade', (tester) async {
      final state = await _abrirApp(tester);
      final repos = state.repositorios.anuncios;
      final modalidades = state.referencias.modalidades;
      // Os mesmos ids e nomes da Etapa 1.
      expect(modalidades.map((m) => m.nome), _opcoes.skip(1));
      await _abrirBusca(tester);

      for (final (id, nome) in [
        (null, 'Todos'),
        for (final m in modalidades) (m.id, m.nome),
      ]) {
        await tester.tap(find.widgetWithText(ChipFiltro, nome));
        await tester.pumpAndSettle();
        final selecionados = tester
            .widgetList<ChipFiltro>(find.byType(ChipFiltro))
            .where((c) => c.selecionado)
            .map((c) => c.texto);
        expect(selecionados, [nome]);
        final esperado = await repos.buscar(FiltroAnuncios(idModalidade: id));
        if (id != null) {
          expect(esperado.every((a) => a.modalidade.id == id), isTrue);
        }
        expect(_contagem(tester), esperado.length, reason: nome);
      }
      // Todos = soma de todas as modalidades.
      await tester.tap(find.widgetWithText(ChipFiltro, 'Todos'));
      await tester.pumpAndSettle();
      expect(_contagem(tester), 4);
    });
  });

  testWidgets('perfil do time sem contato/telefone', (tester) async {
    await _abrirApp(tester);
    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();
    expect(find.text('Responsável'), findsOneWidget);
    expect(find.textContaining('Contato'), findsNothing);
    expect(find.textContaining('90000-0000'), findsNothing);
    expect(find.textContaining('Telefone'), findsNothing);
  });

  testWidgets('frase do início sem emoji', (tester) async {
    await _abrirApp(tester);
    final frase = find.text('Seu time entra em campo.');
    expect(frase, findsOneWidget);
    expect(tester.widget<Text>(frase).style?.fontSize, 22);
    expect(find.textContaining('⚽'), findsNothing);
  });

  group('fontes', () {
    test('escala central aumenta todos os textos e mantém a hierarquia', () {
      const escala = EscalaDeLeitura(TextScaler.noScaling);
      // Antes: +15% nos textos pequenos e +8% nos títulos.
      expect(EscalaDeLeitura.fator(10), closeTo(1.32, 1e-9));
      expect(EscalaDeLeitura.fator(24), closeTo(1.12, 1e-9));
      for (final t in <double>[8, 9, 10, 11, 12, 14, 16, 19, 22, 26, 32]) {
        expect(escala.scale(t), greaterThan(t * 1.11), reason: '$t');
      }
      // Um tamanho maior no layout continua maior na tela.
      var anterior = 0.0;
      for (var t = 6.0; t <= 40; t += 0.5) {
        expect(escala.scale(t), greaterThan(anterior), reason: '$t');
        anterior = escala.scale(t);
      }
      // A escala do sistema (acessibilidade) continua valendo por cima.
      expect(
        const EscalaDeLeitura(TextScaler.linear(1.3)).scale(12),
        closeTo(escala.scale(12) * 1.3, 1e-9),
      );
    });

    testWidgets('o app inteiro usa a escala de leitura', (tester) async {
      await _abrirApp(tester);
      expect(
        MediaQuery.textScalerOf(tester.element(find.text('Início').last)),
        isA<EscalaDeLeitura>(),
      );
      // Ícones não crescem: a barra continua com ícones de 24.
      final icone = tester.getSize(find.byIcon(Icons.search).last);
      expect(icone.height, 24);
    });
  });
}
