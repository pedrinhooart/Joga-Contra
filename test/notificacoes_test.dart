import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joga_contra/main.dart';
import 'package:joga_contra/models/notificacao.dart';
import 'package:joga_contra/repositories/contratos.dart';
import 'package:joga_contra/repositories/demo/demo_repositories.dart';
import 'package:joga_contra/services/api_client.dart';
import 'package:joga_contra/state/app_state.dart';
import 'package:joga_contra/widgets/common.dart';

/// Notificações em memória, com falha sob demanda (sem conexão).
class _NotificacoesDeTeste implements NotificacaoRepository {
  final itens = <Notificacao>[];
  ApiException? erro;
  final marcadas = <String>[];

  void _falharSePreciso() {
    if (erro != null) throw erro!;
  }

  void adicionar(String titulo, {bool lida = false, DateTime? quando}) =>
      itens.add(
        Notificacao(
          id: 'n${itens.length + 1}',
          tipo: TipoNotificacao.aviso,
          titulo: titulo,
          mensagem: 'Detalhes de $titulo',
          dataCriacao:
              quando ??
              DateTime.now().subtract(Duration(minutes: 100 - itens.length)),
          lida: lida,
        ),
      );

  List<Notificacao> get _ordenadas =>
      [...itens]..sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));

  @override
  Future<PaginaNotificacoes> listar({int pagina = 1, int limite = 20}) async {
    _falharSePreciso();
    final inicio = (pagina - 1) * limite;
    final pg = _ordenadas.skip(inicio).take(limite).toList();
    return PaginaNotificacoes(
      itens: pg,
      temMais: inicio + pg.length < itens.length,
      total: itens.length,
      naoLidas: itens.where((n) => !n.lida).length,
    );
  }

  @override
  Future<({int naoLidas, int total})> resumo() async {
    _falharSePreciso();
    return (naoLidas: itens.where((n) => !n.lida).length, total: itens.length);
  }

  @override
  Future<void> marcarComoLida(String id) async {
    _falharSePreciso();
    marcadas.add(id);
    final i = itens.indexWhere((n) => n.id == id);
    if (i >= 0) itens[i] = itens[i].comoLida();
  }

  PreferenciasNotificacoes salvas = const PreferenciasNotificacoes();
  ApiException? erroAoSalvar;

  @override
  Future<PreferenciasNotificacoes> preferencias() async {
    _falharSePreciso();
    return salvas;
  }

  @override
  Future<PreferenciasNotificacoes> salvarPreferencias(
    PreferenciasNotificacoes p,
  ) async {
    if (erroAoSalvar != null) throw erroAoSalvar!;
    return salvas = p;
  }

  @override
  Future<int> marcarTodasComoLidas() async {
    _falharSePreciso();
    var n = 0;
    for (var i = 0; i < itens.length; i++) {
      if (!itens[i].lida) {
        itens[i] = itens[i].comoLida();
        n++;
      }
    }
    return n;
  }
}

Future<AppState> _abrir(
  WidgetTester tester, {
  NotificacaoRepository? notificacoes,
}) async {
  tester.view.physicalSize = const Size(600, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final demo = criarRepositoriosDemo();
  final state = AppState(
    Repositorios(
      auth: demo.auth,
      referencias: demo.referencias,
      times: demo.times,
      anuncios: demo.anuncios,
      solicitacoes: demo.solicitacoes,
      partidas: demo.partidas,
      notificacoes: notificacoes ?? demo.notificacoes,
      locais: demo.locais,
    ),
  );
  await tester.pumpWidget(JogaContraApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

Finder _contador(String texto) => find.descendant(
  of: find.byTooltip('Notificações'),
  matching: find.text(texto),
);

Future<void> _abrirCentral(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Notificações'));
  await tester.pumpAndSettle();
}

final _marcadores = find.byKey(const ValueKey('marcador-nao-lida'));

void main() {
  testWidgets('sino mostra as não lidas; a central diferencia lidas', (
    tester,
  ) async {
    final state = await _abrir(tester);
    // Demonstração: 3 não lidas e 1 lida.
    expect(state.notificacoesNaoLidas, 3);
    expect(_contador('3'), findsOneWidget);

    await _abrirCentral(tester);
    expect(find.text('O jogo não para.'), findsOneWidget);
    expect(find.text('3 não lidas'), findsOneWidget);
    expect(find.text('Novo desafio recebido'), findsOneWidget);
    expect(find.text('Seu anúncio está próximo de expirar.'), findsOneWidget);
    expect(_marcadores, findsNWidgets(3));
    // Data relativa e data/hora completas.
    expect(find.textContaining('Há 5 minutos · '), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'\d\d/\d\d/\d{4} às \d\d:\d\d')),
      findsNWidgets(4),
    );
  });

  testWidgets('tocar marca como lida, abre o conteúdo e atualiza o contador', (
    tester,
  ) async {
    final state = await _abrir(tester);
    await _abrirCentral(tester);
    await tester.tap(find.text('A conversa tá rolando.'));
    await tester.pumpAndSettle();
    expect(find.text('Conversa'), findsOneWidget); // abriu o chat
    expect(state.notificacoesNaoLidas, 2);
    expect(_contador('2'), findsOneWidget);

    await _abrirCentral(tester);
    expect(find.text('2 não lidas'), findsOneWidget);
    expect(_marcadores, findsNWidgets(2));
  });

  testWidgets('aviso sem conteúdo ligado: marca como lido e fica na central', (
    tester,
  ) async {
    final repo = _NotificacoesDeTeste()..adicionar('Aviso geral');
    final state = await _abrir(tester, notificacoes: repo);
    await _abrirCentral(tester);
    await tester.tap(find.text('Aviso geral'));
    await tester.pumpAndSettle();
    expect(find.text('O jogo não para.'), findsOneWidget); // não saiu
    expect(_marcadores, findsNothing);
    expect(repo.marcadas, ['n1']);
    expect(state.notificacoesNaoLidas, 0);
  });

  testWidgets('marcar todas como lidas', (tester) async {
    final state = await _abrir(tester);
    await _abrirCentral(tester);
    await tester.tap(find.text('Marcar todas como lidas'));
    await tester.pumpAndSettle();
    expect(state.notificacoesNaoLidas, 0);
    expect(_marcadores, findsNothing);
    expect(find.text('Nenhuma não lida'), findsOneWidget);
    expect(find.text('Marcar todas como lidas'), findsNothing);
    expect(
      find.text('Todas as notificações foram marcadas como lidas.'),
      findsOneWidget,
    );
    // Sem não lidas, o sino fica sem número.
    expect(
      find.descendant(
        of: find.byTooltip('Notificações'),
        matching: find.byWidgetPredicate((w) => w is Badge && w.isLabelVisible),
      ),
      findsNothing,
    );
  });

  testWidgets('estado vazio', (tester) async {
    await _abrir(tester, notificacoes: _NotificacoesDeTeste());
    await _abrirCentral(tester);
    expect(find.text('Tudo tranquilo por aqui.'), findsOneWidget);
    expect(find.text('Marcar todas como lidas'), findsNothing);
  });

  testWidgets('sem conexão: erro com "Tentar novamente"', (tester) async {
    final repo = _NotificacoesDeTeste()..adicionar('Aviso guardado');
    await _abrir(tester, notificacoes: repo);
    repo.erro = ApiException(
      'Não foi possível conectar ao servidor.',
      statusCode: 0,
    );
    await _abrirCentral(tester);
    expect(find.text('A bola não chegou.'), findsOneWidget);
    expect(find.text('Não foi possível conectar ao servidor.'), findsOneWidget);

    repo.erro = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Aviso guardado'), findsOneWidget);
  });

  testWidgets('falha ao marcar: a notificação volta a aparecer não lida', (
    tester,
  ) async {
    final repo = _NotificacoesDeTeste()..adicionar('Aviso sem rede');
    final state = await _abrir(tester, notificacoes: repo);
    await _abrirCentral(tester);
    repo.erro = ApiException('Sem conexão.', statusCode: 0);
    await tester.tap(find.text('Aviso sem rede'));
    await tester.pumpAndSettle();
    expect(repo.itens.single.lida, isFalse);
    repo.erro = null;
    await state.atualizarNotificacoes();
    await tester.pumpAndSettle();
    expect(state.notificacoesNaoLidas, 1);
  });

  testWidgets('paginação: 20 por vez, depois as anteriores', (tester) async {
    final repo = _NotificacoesDeTeste();
    for (var i = 1; i <= 25; i++) {
      repo.adicionar('Aviso $i');
    }
    await _abrir(tester, notificacoes: repo);
    await _abrirCentral(tester);
    // Primeira página: as 20 mais recentes (25 a 6).
    expect(find.text('Aviso 25'), findsOneWidget);
    expect(find.text('Aviso 6'), findsOneWidget);
    expect(find.text('Aviso 5'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Ver notificações anteriores'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Ver notificações anteriores'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Aviso 1'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Aviso 5'), findsOneWidget);
    expect(find.text('Ver notificações anteriores'), findsNothing);
    expect(find.text('25 não lidas'), findsOneWidget);
  });

  testWidgets('notificação nova aparece sozinha (sincronização de 30 s)', (
    tester,
  ) async {
    final repo = _NotificacoesDeTeste()..adicionar('Primeira', lida: true);
    final state = await _abrir(tester, notificacoes: repo);
    expect(state.notificacoesNaoLidas, 0);
    await _abrirCentral(tester);
    expect(find.text('Primeira'), findsOneWidget);

    // O backend registra uma nova (aqui, direto no repositório).
    repo.adicionar('Chegou agora', quando: DateTime.now());
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.text('Chegou agora'), findsOneWidget);
    expect(_contador('1'), findsOneWidget);
    expect(_marcadores, findsOneWidget);
  });

  testWidgets('ao voltar para o app, o contador é atualizado', (tester) async {
    final repo = _NotificacoesDeTeste();
    final state = await _abrir(tester, notificacoes: repo);
    expect(state.notificacoesNaoLidas, 0);
    repo.adicionar('Enquanto o app estava fechado');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(state.notificacoesNaoLidas, 1);
    expect(_contador('1'), findsOneWidget);
  });

  test('tipo desconhecido vira aviso (API mais nova que o app)', () {
    final n = Notificacao.fromJson({
      'idNotificacao': 'x',
      'tipo': 'tipo_do_futuro',
      'titulo': 'T',
      'mensagem': 'M',
      'dataCriacao': '2026-11-25T12:00:00.000Z',
      'lida': false,
    });
    expect(n.tipo, TipoNotificacao.aviso);
    expect(n.comoLida().lida, isTrue);
    expect(n.comoLida().titulo, 'T');
  });

  group('tocar leva ao conteúdo do evento', () {
    /// Uma notificação do tipo/ids dados; os ids existem na demonstração.
    Future<void> tocar(
      WidgetTester tester,
      TipoNotificacao tipo, {
      String? idSolicitacao,
      String? idPartida,
    }) async {
      final repo = _NotificacoesDeTeste();
      repo.itens.add(
        Notificacao(
          id: 'n-nav',
          tipo: tipo,
          titulo: 'Toque aqui',
          mensagem: 'Mensagem',
          dataCriacao: DateTime.now(),
          idSolicitacao: idSolicitacao,
          idPartida: idPartida,
        ),
      );
      await _abrir(tester, notificacoes: repo);
      await _abrirCentral(tester);
      await tester.tap(find.text('Toque aqui'));
      await tester.pumpAndSettle();
      expect(repo.marcadas, ['n-nav']);
    }

    bool meusDesafiosSelecionado(WidgetTester tester) => tester
        .widget<ChipFiltro>(find.widgetWithText(ChipFiltro, 'Meus Desafios'))
        .selecionado;

    testWidgets('desafio enviado: abre a solicitação', (tester) async {
      await tocar(
        tester,
        TipoNotificacao.solicitacaoEnviada,
        idSolicitacao: 's-real',
      );
      expect(find.text('Conversa'), findsOneWidget);
      expect(find.text('Aguardando o aceite'), findsOneWidget);
    });

    testWidgets('novo desafio recebido: abre a solicitação recebida', (
      tester,
    ) async {
      await tocar(
        tester,
        TipoNotificacao.solicitacaoRecebida,
        idSolicitacao: 's-vila',
      );
      expect(find.text('Conversa'), findsOneWidget);
      expect(find.text('Aceitar desafio'), findsOneWidget);
    });

    testWidgets('desafio aceito: abre o jogo confirmado', (tester) async {
      await tocar(
        tester,
        TipoNotificacao.partidaConfirmada,
        idPartida: 'p-confirmada',
      );
      expect(find.text('Partida confirmada'), findsWidgets);
    });

    testWidgets('jogo cancelado: abre os detalhes do jogo', (tester) async {
      await tocar(
        tester,
        TipoNotificacao.partidaCancelada,
        idPartida: 'p-confirmada',
      );
      expect(find.text('Partida confirmada'), findsWidgets);
    });

    for (final tipo in [
      TipoNotificacao.solicitacaoEncerrada,
      TipoNotificacao.solicitacaoRecusada,
    ]) {
      testWidgets('${tipo.codigo}: abre Meus Desafios', (tester) async {
        await tocar(tester, tipo, idSolicitacao: 's-real');
        expect(find.text('Meus jogos'), findsOneWidget);
        expect(meusDesafiosSelecionado(tester), isTrue);
      });
    }
  });

  group('preferências e lembretes', () {
    SwitchListTile chave(WidgetTester tester, String titulo) => tester
        .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, titulo));

    testWidgets('abre pela central e salva cada categoria', (tester) async {
      final repo = _NotificacoesDeTeste()..adicionar('Aviso');
      await _abrir(tester, notificacoes: repo);
      await _abrirCentral(tester);
      await tester.tap(find.text('Preferências'));
      await tester.pumpAndSettle();
      expect(find.text('Do seu jeito.'), findsOneWidget);
      expect(find.text('Preferências de notificação'), findsOneWidget);
      for (final t in ['Desafios', 'Jogos', 'Chat', 'Lembretes de jogo']) {
        expect(chave(tester, t).value, isTrue, reason: t);
      }
      await tester.tap(find.widgetWithText(SwitchListTile, 'Chat'));
      await tester.pumpAndSettle();
      expect(repo.salvas.chat, isFalse);
      expect(repo.salvas.desafios, isTrue);
      expect(chave(tester, 'Chat').value, isFalse);

      // Voltar leva à central.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('O jogo não para.'), findsOneWidget);
    });

    testWidgets('falha ao salvar: a opção volta ao que era', (tester) async {
      final repo = _NotificacoesDeTeste()
        ..erroAoSalvar = ApiException('Sem conexão.', statusCode: 0);
      await _abrir(tester, notificacoes: repo);
      await _abrirCentral(tester);
      await tester.tap(find.text('Preferências'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Lembretes de jogo'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sem conexão.'), findsOneWidget);
      expect(chave(tester, 'Lembretes de jogo').value, isTrue);
    });

    testWidgets('lembrete de jogo abre a partida', (tester) async {
      final repo = _NotificacoesDeTeste();
      repo.itens.add(
        Notificacao(
          id: 'l1',
          tipo: TipoNotificacao.lembretePartida,
          titulo: 'Lembrete: jogo em 2 horas',
          mensagem: 'Seu jogo contra o time Real Amigos FC começa em 2 horas.',
          dataCriacao: DateTime.now(),
          idPartida: 'p-confirmada',
        ),
      );
      await _abrir(tester, notificacoes: repo);
      await _abrirCentral(tester);
      expect(find.byIcon(Icons.alarm), findsOneWidget);
      await tester.tap(find.text('Lembrete: jogo em 2 horas'));
      await tester.pumpAndSettle();
      expect(find.text('Partida confirmada'), findsWidgets);
    });
  });
}
