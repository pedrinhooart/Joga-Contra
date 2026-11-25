import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joga_contra/main.dart';
import 'package:joga_contra/models/usuario.dart';
import 'package:joga_contra/repositories/contratos.dart';
import 'package:joga_contra/repositories/demo/demo_repositories.dart';
import 'package:joga_contra/services/armazenamento_sessao.dart';
import 'package:joga_contra/services/push.dart';
import 'package:joga_contra/state/app_state.dart';

/// Firebase simulado: permissão, token e mensagens sob controle do teste.
class _PushDeTeste implements ServicoPush {
  bool autorizar = true;
  int pedidosDePermissao = 0;
  String? tokenAtual = 'fid-aparelho-1-abcdefghijklmnop';
  MensagemPush? inicial;
  final renovado = StreamController<String>.broadcast();
  final primeiroPlano = StreamController<MensagemPush>.broadcast();
  final tocada = StreamController<MensagemPush>.broadcast();

  @override
  String get plataforma => 'android';
  @override
  Future<bool> pedirPermissao() async {
    pedidosDePermissao++;
    return autorizar;
  }

  @override
  Future<bool> permitido() async => autorizar;
  @override
  Future<String?> token() async => tokenAtual;
  @override
  Stream<String> get tokenRenovado => renovado.stream;
  @override
  Stream<MensagemPush> get emPrimeiroPlano => primeiroPlano.stream;
  @override
  Stream<MensagemPush> get tocadas => tocada.stream;
  @override
  Future<MensagemPush?> mensagemInicial() async => inicial;
}

class _Registro {
  _Registro(this.token, this.permitido, this.tokenAnterior);
  final String token;
  final bool permitido;
  final String? tokenAnterior;
}

/// API de dispositivos simulada; guarda se havia sessão ao desativar.
class _DispositivosDeTeste implements DispositivoRepository {
  _DispositivosDeTeste(this.sessaoAtiva);
  final bool Function() sessaoAtiva;
  final registros = <_Registro>[];
  final desativados = <(String, bool)>[];
  @override
  Future<void> registrar({
    required String token,
    required String plataforma,
    required bool permitido,
    String? tokenAnterior,
  }) async => registros.add(_Registro(token, permitido, tokenAnterior));
  @override
  Future<void> desativar(String token) async =>
      desativados.add((token, sessaoAtiva()));
}

/// Autenticação da demonstração, podendo começar sem sessão.
class _Auth implements AuthRepository {
  _Auth(this._base, {required this.logado});
  final AuthRepository _base;
  bool logado;
  @override
  Future<Sessao?> sessaoAtual() async =>
      logado ? await _base.sessaoAtual() : null;
  @override
  Future<Sessao> entrar({required String email, required String senha}) {
    logado = true;
    return _base.entrar(email: email, senha: senha);
  }

  @override
  Future<Sessao> cadastrar(CadastroCapitao dados) => _base.cadastrar(dados);
  @override
  Future<void> solicitarRecuperacaoSenha(String email) async {}
  @override
  Future<void> redefinirSenha({
    required String token,
    required String novaSenha,
    required String confirmacaoSenha,
  }) async {}
  @override
  Future<void> sair() async {
    logado = false;
    await _base.sair();
  }
}

class _Cenario {
  _Cenario(this.state, this.push, this.dispositivos, this.armazenamento);
  final AppState state;
  final _PushDeTeste push;
  final _DispositivosDeTeste dispositivos;
  final ArmazenamentoEmMemoria armazenamento;
}

Future<_Cenario> _abrir(
  WidgetTester tester, {
  bool logado = true,
  void Function(_PushDeTeste)? preparar,
}) async {
  tester.view.physicalSize = const Size(600, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final demo = criarRepositoriosDemo();
  late final AppState state;
  final dispositivos = _DispositivosDeTeste(() => state.autenticado);
  state = AppState(
    Repositorios(
      auth: _Auth(demo.auth, logado: logado),
      referencias: demo.referencias,
      times: demo.times,
      anuncios: demo.anuncios,
      solicitacoes: demo.solicitacoes,
      partidas: demo.partidas,
      notificacoes: demo.notificacoes,
      locais: demo.locais,
      dispositivos: dispositivos,
    ),
  );
  final push = _PushDeTeste();
  preparar?.call(push);
  final armazenamento = ArmazenamentoEmMemoria();
  await tester.pumpWidget(
    JogaContraApp(state: state, push: push, armazenamentoPush: armazenamento),
  );
  await tester.pumpAndSettle();
  return _Cenario(state, push, dispositivos, armazenamento);
}

const _desafio = MensagemPush(
  idNotificacao: 'n1',
  tipo: 'solicitacao_recebida',
  referenciaTipo: 'solicitacao',
  referenciaId: 's-vila',
  titulo: 'Novo desafio recebido',
  corpo: 'O time Vila Nova Futsal demonstrou interesse no seu jogo.',
);

const _aceito = MensagemPush(
  idNotificacao: 'n2',
  tipo: 'partida_confirmada',
  referenciaTipo: 'partida',
  referenciaId: 'p-confirmada',
  titulo: 'Desafio aceito!',
  corpo: 'Seu desafio foi aceito!',
);

void main() {
  group('registro do aparelho', () {
    testWidgets('com sessão: pede permissão e registra o token', (
      tester,
    ) async {
      final c = await _abrir(tester);
      expect(c.push.pedidosDePermissao, 1);
      final r = c.dispositivos.registros.single;
      expect(r.token, 'fid-aparelho-1-abcdefghijklmnop');
      expect(r.permitido, isTrue);
      expect(r.tokenAnterior, isNull);
      expect(c.armazenamento.tokenPush, r.token);
    });

    testWidgets('sem permissão: registra "sem permissão" e o app segue', (
      tester,
    ) async {
      final c = await _abrir(tester, preparar: (p) => p.autorizar = false);
      expect(c.dispositivos.registros.single.permitido, isFalse);
      // A central interna continua com as notificações de sempre.
      expect(c.state.notificacoesNaoLidas, 3);
      expect(find.text('Seu time entra em campo.'), findsOneWidget);
    });

    testWidgets('sem sessão: só registra depois do login', (tester) async {
      final c = await _abrir(tester, logado: false);
      expect(c.dispositivos.registros, isEmpty);
      expect(c.push.pedidosDePermissao, 0);
      await c.state.entrar('capitao@exemplo.test', 'senha-123');
      await tester.pumpAndSettle();
      expect(c.dispositivos.registros, hasLength(1));
    });

    testWidgets('token renovado pelo Firebase substitui o anterior', (
      tester,
    ) async {
      final c = await _abrir(tester);
      c.push.renovado.add('fid-aparelho-2-abcdefghijklmnop');
      await tester.pumpAndSettle();
      final r = c.dispositivos.registros.last;
      expect(r.token, 'fid-aparelho-2-abcdefghijklmnop');
      expect(r.tokenAnterior, 'fid-aparelho-1-abcdefghijklmnop');
    });

    testWidgets('permissão mudada nas configurações: registra de novo', (
      tester,
    ) async {
      final c = await _abrir(tester);
      c.push.autorizar = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(c.dispositivos.registros.last.permitido, isFalse);
      expect(c.push.pedidosDePermissao, 1); // não pergunta de novo
    });

    testWidgets('sair desliga o aparelho com a sessão ainda válida', (
      tester,
    ) async {
      final c = await _abrir(tester);
      await c.state.sair();
      await tester.pumpAndSettle();
      expect(c.dispositivos.desativados, [
        ('fid-aparelho-1-abcdefghijklmnop', true),
      ]);
      expect(c.state.autenticado, isFalse);
    });

    testWidgets('sem token (sem Google Play Services): app segue normal', (
      tester,
    ) async {
      final c = await _abrir(tester, preparar: (p) => p.tokenAtual = null);
      expect(c.dispositivos.registros, isEmpty);
      expect(find.text('Seu time entra em campo.'), findsOneWidget);
    });
  });

  group('mensagens', () {
    testWidgets('app aberto: aviso discreto com "Ver", sem duplicar', (
      tester,
    ) async {
      final c = await _abrir(tester);
      c.push.primeiroPlano.add(_desafio);
      await tester.pumpAndSettle();
      expect(find.textContaining('Novo desafio recebido'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);

      await tester.tap(find.text('Ver'));
      await tester.pumpAndSettle();
      expect(find.text('Conversa'), findsOneWidget);
      expect(find.text('Aceitar desafio'), findsOneWidget);
      // Abrir pelo aviso marca a notificação como lida.
      expect(c.state.notificacoesNaoLidas, 2);
    });

    testWidgets('tocada em segundo plano: abre o jogo e marca como lida', (
      tester,
    ) async {
      final c = await _abrir(tester);
      c.push.tocada.add(_aceito);
      await tester.pumpAndSettle();
      expect(find.text('Partida confirmada'), findsWidgets);
      expect(c.state.notificacoesNaoLidas, 2);
      expect(c.state.pushParaAbrir, isNull);
    });

    testWidgets('app fechado: a notificação que abriu o app vai ao conteúdo', (
      tester,
    ) async {
      await _abrir(tester, preparar: (p) => p.inicial = _aceito);
      expect(find.text('Partida confirmada'), findsWidgets);
    });

    testWidgets('sem sessão: o conteúdo abre depois do login', (tester) async {
      final c = await _abrir(
        tester,
        logado: false,
        preparar: (p) => p.inicial = _desafio,
      );
      expect(find.text('Seu time em campo.'), findsOneWidget);
      expect(c.state.pushParaAbrir, isNotNull);
      await c.state.entrar('capitao@exemplo.test', 'senha-123');
      await tester.pumpAndSettle();
      expect(find.text('Conversa'), findsOneWidget);
    });

    testWidgets('mensagem sem identificador é ignorada', (tester) async {
      final c = await _abrir(tester);
      c.push.primeiroPlano.add(const MensagemPush(idNotificacao: '', tipo: ''));
      c.push.tocada.add(const MensagemPush(idNotificacao: '', tipo: ''));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Seu time entra em campo.'), findsOneWidget);
    });
  });

  test('dados do push viram a mesma navegação da central', () {
    final n = MensagemPush.dosDados({
      'idNotificacao': 'x',
      'tipo': 'partida_cancelada',
      'referenciaTipo': 'partida',
      'referenciaId': 'p1',
    }, titulo: 'Jogo cancelado').comoNotificacao();
    expect(n.idPartida, 'p1');
    expect(n.idSolicitacao, isNull);
    expect(n.titulo, 'Jogo cancelado');
  });
}
