import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joga_contra/main.dart';
import 'package:joga_contra/models/solicitacao_confronto.dart';
import 'package:joga_contra/repositories/contratos.dart';
import 'package:joga_contra/repositories/demo/demo_repositories.dart';
import 'package:joga_contra/services/api_client.dart';
import 'package:joga_contra/services/armazenamento_sessao.dart';
import 'package:joga_contra/services/push.dart';
import 'package:joga_contra/state/app_state.dart';

/// Repositório da demonstração que registra presença, consultas e envios.
class _Espiao implements SolicitacaoRepository {
  _Espiao(this._base);
  final SolicitacaoRepository _base;
  final presencas = <(String, bool)>[];
  final consultas = <String>[];
  final ids = <String?>[];
  int falhasNoEnvio = 0;

  @override
  Future<List<SolicitacaoConfronto>> listarDoMeuTime({
    PapelSolicitacao? papel,
  }) => _base.listarDoMeuTime(papel: papel);
  @override
  Future<Sincronizacao> sincronizar() => _base.sincronizar();
  @override
  Future<SolicitacaoConfronto> obter(String id) => _base.obter(id);
  @override
  Future<SolicitacaoConfronto> solicitar(
    String idAnuncio, {
    String? mensagem,
  }) => _base.solicitar(idAnuncio, mensagem: mensagem);
  @override
  Future<SolicitacaoConfronto> confirmar(String id) => _base.confirmar(id);
  @override
  Future<SolicitacaoConfronto> recusar(String id) => _base.recusar(id);
  @override
  Future<SolicitacaoConfronto> cancelar(String id) => _base.cancelar(id);
  @override
  Future<List<Mensagem>> mensagens(String id) {
    consultas.add(id);
    return _base.mensagens(id);
  }

  @override
  Future<Mensagem> enviarMensagem(
    String id,
    String texto, {
    String? idMensagem,
  }) async {
    ids.add(idMensagem);
    if (falhasNoEnvio > 0) {
      falhasNoEnvio--;
      // A requisição chegou, mas a resposta se perdeu.
      await _base.enviarMensagem(id, texto, idMensagem: idMensagem);
      throw ApiException(
        'Não foi possível conectar ao servidor.',
        statusCode: 0,
      );
    }
    return _base.enviarMensagem(id, texto, idMensagem: idMensagem);
  }

  @override
  Future<void> marcarPresenca(String id, {required bool aberta}) async =>
      presencas.add((id, aberta));
}

class _PushDeTeste implements ServicoPush {
  final primeiroPlano = StreamController<MensagemPush>.broadcast();
  @override
  String get plataforma => 'android';
  @override
  Future<bool> pedirPermissao() async => true;
  @override
  Future<bool> permitido() async => true;
  @override
  Future<String?> token() async => null;
  @override
  Stream<String> get tokenRenovado => const Stream.empty();
  @override
  Stream<MensagemPush> get emPrimeiroPlano => primeiroPlano.stream;
  @override
  Stream<MensagemPush> get tocadas => const Stream.empty();
  @override
  Future<MensagemPush?> mensagemInicial() async => null;
}

Future<(_Espiao, _PushDeTeste)> _abrirConversa(WidgetTester tester) async {
  tester.view.physicalSize = const Size(600, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final demo = criarRepositoriosDemo();
  final espiao = _Espiao(demo.solicitacoes);
  final push = _PushDeTeste();
  await tester.pumpWidget(
    JogaContraApp(
      state: AppState(
        Repositorios(
          auth: demo.auth,
          referencias: demo.referencias,
          times: demo.times,
          anuncios: demo.anuncios,
          solicitacoes: espiao,
          partidas: demo.partidas,
          notificacoes: demo.notificacoes,
          locais: demo.locais,
        ),
      ),
      push: push,
      armazenamentoPush: ArmazenamentoEmMemoria(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Conversas').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Chegamos 15 minutos antes.'));
  await tester.pumpAndSettle();
  expect(find.text('Conversa'), findsOneWidget);
  return (espiao, push);
}

void main() {
  testWidgets(
    'sair da conversa avisa a API (as mensagens voltam a gerar push)',
    (tester) async {
      final (espiao, _) = await _abrirConversa(tester);
      expect(espiao.consultas, ['s-real-antiga']); // abrir = presença
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(espiao.presencas, [('s-real-antiga', false)]);
    },
  );

  testWidgets('em segundo plano para de consultar; ao voltar, retoma na hora', (
    tester,
  ) async {
    final (espiao, _) = await _abrirConversa(tester);
    await tester.pump(const Duration(seconds: 9));
    final abertas = espiao.consultas.length; // 1 + 2 ciclos de 4 s
    expect(abertas, 3);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 20));
    // Nada visualizado sem ninguém olhando; a API sabe que saiu.
    expect(espiao.consultas.length, abertas);
    expect(espiao.presencas, [('s-real-antiga', false)]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(espiao.consultas.length, abertas + 1);
    await tester.pump(const Duration(seconds: 4));
    expect(espiao.consultas.length, abertas + 2);
  });

  testWidgets(
    'tentar de novo após falha usa o mesmo id: sem mensagem duplicada',
    (tester) async {
      final (espiao, _) = await _abrirConversa(tester);
      espiao.falhasNoEnvio = 1;
      await tester.enterText(find.byType(TextField).first, 'Levamos a bola');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(
        find.text('Não foi possível conectar ao servidor.'),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.send)); // mesmo texto ainda no campo
      await tester.pumpAndSettle();
      expect(espiao.ids, hasLength(2));
      expect(espiao.ids[0], isNotNull);
      expect(espiao.ids[1], espiao.ids[0]);
      expect(find.text('Levamos a bola'), findsOneWidget);
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(espiao.ids[0]!),
        isTrue,
      );

      // Outro texto: outra mensagem, outro id.
      await tester.enterText(find.byType(TextField).first, 'Até sábado');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(espiao.ids.last, isNot(espiao.ids[0]));
    },
  );

  testWidgets('push da conversa aberta não gera aviso; de outra, gera', (
    tester,
  ) async {
    final (_, push) = await _abrirConversa(tester);
    push.primeiroPlano.add(
      const MensagemPush(
        idNotificacao: 'x1',
        tipo: 'mensagem_recebida',
        referenciaTipo: 'solicitacao',
        referenciaId: 's-real-antiga',
        titulo: 'Nova mensagem',
        corpo: 'Você recebeu uma nova mensagem do time Real Amigos FC.',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);

    push.primeiroPlano.add(
      const MensagemPush(
        idNotificacao: 'x2',
        tipo: 'mensagem_recebida',
        referenciaTipo: 'solicitacao',
        referenciaId: 's-vila',
        titulo: 'Nova mensagem',
        corpo: 'Você recebeu uma nova mensagem do time Vila Nova Futsal.',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Vila Nova Futsal'), findsWidgets);
  });
}
