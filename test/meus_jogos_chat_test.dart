import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joga_contra/theme/app_theme.dart';
import 'package:joga_contra/main.dart';
import 'package:joga_contra/models/solicitacao_confronto.dart';
import 'package:joga_contra/repositories/demo/demo_repositories.dart';
import 'package:joga_contra/state/app_state.dart';
import 'package:joga_contra/widgets/common.dart';

/// Etapa 2: "Meus Jogos" na barra (no lugar de "Anunciar"), os filtros
/// Meus Anúncios / Meus Desafios e os indicadores do chat.
Future<AppState> _abrirApp(WidgetTester tester) async {
  // Alta para a lista inteira ser montada; larga porque a fonte de teste
  // (Ahem) é bem mais larga que a do app (telas_tamanhos_test usa a real).
  tester.view.physicalSize = const Size(600, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final state = AppState(criarRepositoriosDemo());
  await tester.pumpWidget(JogaContraApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

Future<void> _abrirMeusJogos(WidgetTester tester) async {
  await tester.tap(find.text('Meus Jogos').last);
  await tester.pumpAndSettle();
}

Future<void> _filtro(WidgetTester tester, String nome) async {
  await tester.tap(find.widgetWithText(ChipFiltro, nome));
  await tester.pumpAndSettle();
}

/// Ícone de estado do balão que contém [texto] (nulo se não houver).
Icon? _indicador(WidgetTester tester, String texto) {
  final balao = find
      .ancestor(of: find.text(texto), matching: find.byType(Container))
      .first;
  final icones = find.descendant(of: balao, matching: find.byType(Icon));
  return icones.evaluate().isEmpty ? null : tester.widget<Icon>(icones.first);
}

void main() {
  group('navegação', () {
    testWidgets('"Meus Jogos" substitui "Anunciar" na barra inferior', (
      tester,
    ) async {
      await _abrirApp(tester);
      final barra = find.byType(NavigationBar);
      for (final rotulo in [
        'Início',
        'Buscar',
        'Meus Jogos',
        'Conversas',
        'Perfil',
      ]) {
        expect(
          find.descendant(of: barra, matching: find.text(rotulo)),
          findsOneWidget,
          reason: rotulo,
        );
      }
      expect(
        find.descendant(of: barra, matching: find.text('Anunciar')),
        findsNothing,
      );

      await _abrirMeusJogos(tester);
      expect(find.text('Toda partida tem uma história.'), findsOneWidget);
      // Só os dois filtros; as abas antigas saíram.
      expect(find.byType(ChipFiltro), findsNWidgets(2));
      expect(find.widgetWithText(ChipFiltro, 'Meus Anúncios'), findsOneWidget);
      expect(find.widgetWithText(ChipFiltro, 'Meus Desafios'), findsOneWidget);
      for (final antigo in ['Todos', 'Em análise', 'Realizado', 'Cancelado']) {
        expect(
          find.widgetWithText(ChipFiltro, antigo),
          findsNothing,
          reason: antigo,
        );
      }

      // Anunciar continua disponível pelo Início.
      await tester.tap(find.text('Início').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Anunciar jogo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anunciar jogo'));
      await tester.pumpAndSettle();
      expect(find.text('Nível do time'), findsWidgets);
    });
  });

  group('Meus Jogos', () {
    testWidgets('Meus Anúncios: só os anúncios do meu time', (tester) async {
      await _abrirApp(tester);
      await _abrirMeusJogos(tester);
      expect(
        tester
            .widget<ChipFiltro>(
              find.widgetWithText(ChipFiltro, 'Meus Anúncios'),
            )
            .selecionado,
        isTrue,
      );
      // a-uniao (ativo, sem adversário), a-uniao-antigo (virou a partida
      // confirmada) e a partida já realizada de um anúncio do União.
      expect(find.text('Ver anúncio'), findsOneWidget);
      expect(find.text('Aguardando adversário'), findsOneWidget);
      expect(find.text('Ver partida'), findsOneWidget);
      expect(find.text('Confirmado'), findsOneWidget);
      expect(find.text('Avaliar'), findsOneWidget);
      expect(find.text('Realizado'), findsOneWidget);
      // Anúncios de outros times e desafios enviados não aparecem aqui.
      expect(find.text('Ver solicitação'), findsNothing);
      for (final outro in [
        'Vila Nova Futsal',
        'Atlético da Zona Sul',
        'Resenha Esporte Clube',
      ]) {
        expect(find.textContaining(outro), findsNothing, reason: outro);
      }

      await tester.tap(find.text('Ver partida'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Campo do Ibirapuera'), findsWidgets);
    });

    testWidgets('Meus Desafios: só anúncios de outros times que desafiei', (
      tester,
    ) async {
      await _abrirApp(tester);
      await _abrirMeusJogos(tester);
      await _filtro(tester, 'Meus Desafios');
      // s-real: pedido do União ao Real Amigos (aguardando) e a partida
      // realizada no anúncio do Atlético. s-vila foi recebida e s-real-antiga
      // partiu do Real: nenhuma das duas é desafio do União.
      expect(find.text('Ver solicitação'), findsOneWidget);
      expect(find.text('Aguardando aceite'), findsOneWidget);
      expect(find.textContaining('Real Amigos FC'), findsOneWidget);
      expect(find.textContaining('Atlético da Zona Sul'), findsOneWidget);
      expect(find.text('Ver partida'), findsOneWidget);
      expect(find.text('Ver anúncio'), findsNothing);
      expect(find.text('Confirmado'), findsNothing);
      expect(find.textContaining('Vila Nova Futsal'), findsNothing);
      expect(find.textContaining('Resenha Esporte Clube'), findsNothing);

      await tester.tap(find.text('Ver solicitação'));
      await tester.pumpAndSettle();
      // O chat só abre depois do aceite: a tela mostra a espera.
      expect(find.text('Aguardando o aceite'), findsOneWidget);
      expect(find.byIcon(Icons.send), findsNothing);
    });

    testWidgets('Meus Desafios sem duplicar e atualizado após as ações', (
      tester,
    ) async {
      final state = await _abrirApp(tester);
      final repos = state.repositorios.solicitacoes;
      // Cancela e pede de novo o mesmo anúncio: duas solicitações, um item.
      await repos.cancelar('s-real');
      final nova = await repos.solicitar('a-real');
      final enviadas = await repos.listarDoMeuTime(
        papel: PapelSolicitacao.solicitante,
      );
      expect(enviadas.where((s) => s.anuncio.id == 'a-real'), hasLength(2));

      await _abrirMeusJogos(tester);
      await _filtro(tester, 'Meus Desafios');
      expect(find.text('Ver solicitação'), findsOneWidget);
      expect(find.text('Aguardando aceite'), findsOneWidget);
      expect(find.text('Cancelada'), findsNothing);

      // O desafio mais recente foi cancelado: a lista mostra o novo estado.
      await repos.cancelar(nova.id);
      await _filtro(tester, 'Meus Anúncios');
      await _filtro(tester, 'Meus Desafios');
      expect(find.text('Cancelada'), findsOneWidget);
      expect(find.text('Ver solicitação'), findsOneWidget);
    });

    testWidgets('Meus Anúncios mostra a partida depois do aceite', (
      tester,
    ) async {
      final state = await _abrirApp(tester);
      await _abrirMeusJogos(tester);
      expect(find.text('Aguardando adversário'), findsOneWidget);

      // O União aceita o desafio do Vila Nova no anúncio a-uniao.
      await state.repositorios.solicitacoes.confirmar('s-vila');
      await _filtro(tester, 'Meus Desafios');
      await _filtro(tester, 'Meus Anúncios');
      expect(find.text('Ver anúncio'), findsNothing);
      expect(find.text('Aguardando adversário'), findsNothing);
      expect(find.text('Confirmado'), findsNWidgets(2));
      expect(find.textContaining('Vila Nova Futsal'), findsOneWidget);
      // E o aceite recebido não vira "desafio" do União.
      await _filtro(tester, 'Meus Desafios');
      expect(find.textContaining('Vila Nova Futsal'), findsNothing);
    });
  });

  group('chat', () {
    test('estado da mensagem vem da API', () {
      Mensagem ler(String? status, {String? entrega, String? leitura}) =>
          Mensagem.fromJson({
            'idMensagem': 'm1',
            'idSolicitacao': 's1',
            'idTimeRemetente': 't1',
            'texto': 'Oi',
            'dataEnvio': '2026-11-23T20:00:00.000Z',
            'dataEntrega': entrega,
            'dataLeitura': leitura,
            'status': status,
          });
      expect(ler('enviada').status, StatusMensagem.enviada);
      final entregue = ler('entregue', entrega: '2026-11-23T20:00:05.000Z');
      expect(entregue.status, StatusMensagem.entregue);
      expect(entregue.dataEntrega, isNotNull);
      expect(entregue.dataLeitura, isNull);
      final lida = ler(
        'visualizada',
        entrega: '2026-11-23T20:00:05.000Z',
        leitura: '2026-11-23T20:01:00.000Z',
      );
      expect(lida.status, StatusMensagem.visualizada);
      expect(lida.dataLeitura!.isAfter(lida.dataEntrega!), isTrue);
      // API antiga (sem o campo): nunca inventa leitura.
      expect(ler(null).status, StatusMensagem.enviada);
    });

    testWidgets('balões mostram enviada, entregue e visualizada', (
      tester,
    ) async {
      await _abrirApp(tester);
      await tester.tap(find.text('Conversas').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chegamos 15 minutos antes.'));
      await tester.pumpAndSettle();

      final visualizada = _indicador(tester, 'Campo reservado para sábado.')!;
      expect(visualizada.icon, Icons.done_all);
      expect(visualizada.color, AppColors.lime);
      final entregue = _indicador(tester, 'Levamos as bolas.')!;
      expect(entregue.icon, Icons.done_all);
      expect(entregue.color, Colors.white60);
      final enviada = _indicador(tester, 'Chegamos 15 minutos antes.')!;
      expect(enviada.icon, Icons.done);
      // Mensagem do outro capitão: sem indicador (só quem envia vê).
      expect(_indicador(tester, 'Perfeito, estaremos lá.'), isNull);
      final semantica = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('Visualizada')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Entregue')), findsOneWidget);
      semantica.dispose();

      await tester.enterText(find.byType(TextField).first, 'Até sábado!');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(_indicador(tester, 'Até sábado!')!.icon, Icons.done);
    });
  });
}
