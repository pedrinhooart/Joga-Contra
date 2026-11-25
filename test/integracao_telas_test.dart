import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joga_contra/main.dart';
import 'package:joga_contra/models/anuncio_partida.dart';
import 'package:joga_contra/models/usuario.dart';
import 'package:joga_contra/repositories/contratos.dart';
import 'package:joga_contra/repositories/api/api_repositories.dart';
import 'package:joga_contra/services/api_client.dart';
import 'package:joga_contra/services/armazenamento_sessao.dart';
import 'package:joga_contra/state/app_state.dart';
import 'package:joga_contra/widgets/common.dart';

/// Telas reais do app com a API rodando (sem dados de demonstração).
/// Grava dados fictícios: só roda com `--dart-define=API_TESTE_URL=...`.
const _url = String.fromEnvironment('API_TESTE_URL');
const _senha = 'senha-de-teste-123';
const _novaSenha = 'senha-nova-456';

/// Pasta onde o servidor SMTP de teste grava os e-mails recebidos (JSON).
/// Sem ela, o teste de recuperação de senha é pulado.
const _emails = String.fromEnvironment('EMAILS_TESTE_DIR');

/// Espera o e-mail enviado pela API para [email] chegar à pasta de captura.
Future<Map<String, dynamic>> _emailPara(String email) async {
  for (var i = 0; i < 100; i++) {
    for (final arquivo in Directory(_emails).listSync().whereType<File>()) {
      final dados =
          jsonDecode(arquivo.readAsStringSync()) as Map<String, dynamic>;
      if ('${dados['para']}'.contains(email)) return dados;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('Nenhum e-mail chegou para $email.');
}

/// Deixa as requisições reais terminarem: `pump` sozinho não espera a rede.
Future<void> _aguardar(WidgetTester tester, [int ciclos = 8]) async {
  for (var i = 0; i < ciclos; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Snackbars ficam em fila e cobrem os botões da parte de baixo da tela.
Future<void> _semSnackbar(WidgetTester tester) async {
  for (var i = 0; i < 20 && find.byType(SnackBar).evaluate().isNotEmpty; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await tester.pump(const Duration(seconds: 1));
}

/// Espera o texto aparecer, enquanto a tela carrega da API.
Future<void> _esperarTexto(WidgetTester tester, Finder alvo) async {
  for (var i = 0; i < 60 && alvo.evaluate().isEmpty; i++) {
    await _aguardar(tester, 1);
  }
  expect(alvo, findsWidgets);
}

/// Como [_esperarTexto], rolando a lista (preguiçosa) até o alvo ser montado.
Future<void> _esperarRolando(WidgetTester tester, Finder alvo) async {
  for (var i = 0; i < 60 && alvo.evaluate().isEmpty; i++) {
    final listas = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    if (listas.evaluate().isNotEmpty) {
      await tester.drag(listas.first, const Offset(0, -150));
    }
    await _aguardar(tester, 1);
  }
  expect(alvo, findsWidgets);
}

Future<(String, String)> _capitaoComAnuncio(String marca) async {
  final repos = criarRepositoriosApi(
    ApiClient(baseUrl: _url),
    armazenamento: ArmazenamentoEmMemoria(),
  );
  final refs = await repos.referencias.carregar();
  final email = 'teste.homologacao.dono.$marca@example.com';
  await repos.auth.cadastrar(
    CadastroCapitao(
      nome: 'Dono Tela',
      email: email,
      senha: _senha,
      nomeTime: 'Dono $marca',
      cidade: 'São Paulo',
      siglaEstado: 'SP',
    ),
  );
  await repos.anuncios.criar(
    RascunhoAnuncio(
      idModalidade: refs.modalidades.first.id,
      idCategoriaEtaria: refs.categoriasEtarias.last.id,
      idNivelTecnico: refs.niveisTecnicos.first.id,
      quantidadeJogadores: 7,
      dataHoraInicio: DateTime.now().add(const Duration(days: 3)),
      duracaoMinutos: 90,
      cidade: 'São Paulo',
      siglaEstado: 'SP',
      nomeLocal: 'Arena $marca',
      valorAluguelPorTime: 50,
    ),
  );
  return (email, 'Dono $marca');
}

Future<String> _capitaoSemAnuncio(String marca) async {
  final repos = criarRepositoriosApi(
    ApiClient(baseUrl: _url),
    armazenamento: ArmazenamentoEmMemoria(),
  );
  final email = 'teste.homologacao.visitante.$marca@example.com';
  await repos.auth.cadastrar(
    CadastroCapitao(
      nome: 'Visitante Tela',
      email: email,
      senha: _senha,
      nomeTime: 'Visitante $marca',
      cidade: 'Campinas',
      siglaEstado: 'SP',
    ),
  );
  return email;
}

/// Capitão novo (repositórios com a sessão dele) e o e-mail para entrar no app.
Future<(Repositorios, String)> _capitao(String nomeTime) async {
  final repos = criarRepositoriosApi(
    ApiClient(baseUrl: _url),
    armazenamento: ArmazenamentoEmMemoria(),
  );
  final email =
      'teste.homologacao.horario.${DateTime.now().microsecondsSinceEpoch}@example.com';
  await repos.auth.cadastrar(
    CadastroCapitao(
      nome: 'Capitão $nomeTime',
      email: email,
      senha: _senha,
      nomeTime: nomeTime,
      cidade: 'São Paulo',
      siglaEstado: 'SP',
    ),
  );
  return (repos, email);
}

/// Dono com um jogo em São Paulo no horário [quando] (horário local).
Future<(Repositorios, String)> _donoComJogo(
  String nomeTime,
  DateTime quando,
) async {
  final (repos, _) = await _capitao(nomeTime);
  final refs = await repos.referencias.carregar();
  final anuncio = await repos.anuncios.criar(
    RascunhoAnuncio(
      idModalidade: refs.modalidades.first.id,
      idNivelTecnico: refs.niveisTecnicos.first.id,
      dataHoraInicio: quando,
      duracaoMinutos: 90,
      cidade: 'São Paulo',
      siglaEstado: 'SP',
      nomeLocal: 'Arena $nomeTime',
    ),
  );
  return (repos, anuncio.id);
}

void main() {
  setUpAll(
    () => HttpOverrides.global = null,
  ); // o binding de teste bloqueia a rede

  testWidgets(
    'login, início, busca, interesse, conversa, notificações e perfil',
    skip: _url.isEmpty,
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final marca = DateTime.now().microsecondsSinceEpoch.toString();
      final (emailDono, nomeDono) = (await tester.runAsync(
        () => _capitaoComAnuncio(marca),
      ))!;
      final emailVisitante = (await tester.runAsync(
        () => _capitaoSemAnuncio(marca),
      ))!;

      final api = ApiClient(baseUrl: _url);
      final state = AppState(
        criarRepositoriosApi(api, armazenamento: ArmazenamentoEmMemoria()),
      );
      await tester.pumpWidget(JogaContraApp(state: state));
      await _esperarTexto(tester, find.text('Seu time em campo.'));
      expect(find.byType(NavigationBar), findsNothing);

      // Senha errada: mensagem da API, continua no login.
      await tester.enterText(find.byType(TextFormField).at(0), emailVisitante);
      await tester.enterText(find.byType(TextFormField).at(1), 'senha-errada');
      await tester.tap(find.text('Entrar'));
      await _esperarTexto(tester, find.text('E-mail ou senha inválidos.'));

      await tester.enterText(find.byType(TextFormField).at(1), _senha);
      await tester.tap(find.text('Entrar'));
      await _esperarTexto(tester, find.text('BOM TE VER, VISITANTE'));
      expect(
        find.text('Encontre o próximo adversário para o Visitante $marca.'),
        findsOneWidget,
      );

      await _semSnackbar(tester);

      // Busca com filtro por texto, contra o banco real.
      await tester.tap(find.text('Buscar').last);
      await _aguardar(tester);
      await tester.enterText(find.byType(TextField).first, 'Arena $marca');
      await tester.pump(const Duration(milliseconds: 450));
      await _esperarRolando(tester, find.text(nomeDono));
      expect(find.text('1 jogos disponíveis · Qualquer data'), findsOneWidget);

      await tester.ensureVisible(find.text('Ver detalhes').first);
      await tester.pump();
      await tester.tap(find.text('Ver detalhes').first);
      await _esperarTexto(tester, find.text('Tenho interesse'));
      expect(find.text('7 por equipe'), findsOneWidget);
      expect(find.text('R\$ 50 por time'), findsOneWidget);

      await tester.ensureVisible(find.text('Tenho interesse'));
      await tester.pump();
      await tester.tap(find.text('Tenho interesse'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Sim, tenho interesse'));
      await _esperarTexto(tester, find.text('Quase tudo pronto!'));

      // Antes do aceite: sem chat (nem caixa de mensagem) e sem botão de aceitar.
      expect(
        find.textContaining('O chat é liberado quando Dono $marca aceitar'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.send), findsNothing);
      expect(find.text('Aguardando o aceite'), findsOneWidget);

      await _semSnackbar(tester);
      await tester.tap(find.text('Conversas').last);
      await _esperarTexto(tester, find.text('Aguardando aceite'));
      expect(find.text(nomeDono), findsOneWidget);

      // Quem enviou o desafio tem o registro do envio, já lido (sem número no sino).
      await tester.tap(find.byTooltip('Notificações'));
      await _esperarTexto(tester, find.text('Desafio enviado'));
      expect(find.text('Nenhuma não lida'), findsOneWidget);

      await tester.tap(find.text('Perfil').last);
      await _esperarTexto(tester, find.text('Visitante $marca'));
      expect(find.text('Nenhuma partida realizada ainda.'), findsOneWidget);

      // O dono entra e recebe a notificação real da solicitação.
      await _semSnackbar(tester);
      await tester.ensureVisible(find.text('Sair da conta'));
      await tester.pump();
      await tester.tap(find.text('Sair da conta'));
      await _esperarTexto(tester, find.text('Seu time em campo.'));
      await tester.enterText(find.byType(TextFormField).at(0), emailDono);
      await tester.enterText(find.byType(TextFormField).at(1), _senha);
      await tester.tap(find.text('Entrar'));
      await _esperarTexto(tester, find.text('BOM TE VER, DONO'));
      await tester.tap(find.byTooltip('Notificações'));
      await _esperarTexto(tester, find.text('Novo desafio recebido'));
      await tester.tap(find.text('Novo desafio recebido'));
      await _esperarTexto(tester, find.text('Aceitar desafio'));
      expect(find.byIcon(Icons.send), findsNothing); // chat ainda fechado

      // O dono aceita: partida confirmada vinda do banco e chat liberado.
      await _semSnackbar(tester);
      await tester.ensureVisible(find.text('Aceitar desafio'));
      await tester.pump();
      await tester.tap(find.text('Aceitar desafio'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(FilledButton, 'Aceitar desafio'));
      await _esperarTexto(tester, find.text('Partida confirmada!'));
      expect(find.text('Visitante $marca'), findsOneWidget);

      await _semSnackbar(tester);
      await tester.ensureVisible(find.text('Conversar'));
      await tester.pump();
      await tester.tap(find.text('Conversar'));
      await _esperarTexto(tester, find.byIcon(Icons.send));
      await tester.enterText(find.byType(TextField).first, 'Bora jogar?');
      await tester.tap(find.byIcon(Icons.send));
      await _esperarTexto(tester, find.text('Bora jogar?'));

      await tester.tap(find.text('Início').last);
      await _esperarRolando(tester, find.text('Próxima partida'));
      // Fontes maiores: o cartão da partida fica mais abaixo na lista.
      await tester.scrollUntilVisible(
        find.text('Ver partida'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ver partida'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(
        const Duration(seconds: 20),
      ); // timers de timeout do ApiClient
    },
  );

  testWidgets(
    'aceite no mesmo horário: Meus Desafios se atualiza sozinho',
    skip: _url.isEmpty,
    (tester) async {
      // Alta para a lista inteira ser montada; larga pela fonte dos testes.
      tester.view.physicalSize = const Size(600, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final marca = DateTime.now().microsecondsSinceEpoch.toString();
      final dia = DateTime.now().add(const Duration(days: 9));
      final as21 = DateTime(dia.year, dia.month, dia.day, 21);
      final as19 = DateTime(dia.year, dia.month, dia.day, 19);
      final (donoA, anuncioA) = (await tester.runAsync(
        () => _donoComJogo('Dono A $marca', as21),
      ))!;
      final (_, anuncioB) = (await tester.runAsync(
        () => _donoComJogo('Dono B $marca', as21),
      ))!;
      final (_, anuncioC) = (await tester.runAsync(
        () => _donoComJogo('Dono C $marca', as21),
      ))!;
      final (_, anuncioD) = (await tester.runAsync(
        () => _donoComJogo('Dono D $marca', as19),
      ))!;
      final (joga, emailJoga) = (await tester.runAsync(
        () => _capitao('JOGA $marca'),
      ))!;
      final pedidos = (await tester.runAsync(
        () async => [
          for (final a in [anuncioA, anuncioB, anuncioC, anuncioD])
            await joga.solicitacoes.solicitar(a),
        ],
      ))!;

      final state = AppState(
        criarRepositoriosApi(
          ApiClient(baseUrl: _url),
          armazenamento: ArmazenamentoEmMemoria(),
        ),
      );
      await tester.pumpWidget(JogaContraApp(state: state));
      await _esperarTexto(tester, find.text('Seu time em campo.'));
      await tester.enterText(find.byType(TextFormField).at(0), emailJoga);
      await tester.enterText(find.byType(TextFormField).at(1), _senha);
      await tester.tap(find.text('Entrar'));
      await _esperarTexto(tester, find.text('Seu time entra em campo.'));
      await _semSnackbar(tester);

      await tester.tap(find.text('Meus Jogos').last);
      await _aguardar(tester);
      await tester.tap(find.text('Meus Desafios'));
      await _esperarTexto(tester, find.text('Ver solicitação'));
      expect(find.text('Aguardando aceite'), findsNWidgets(4));

      // O dono do jogo A aceita no aparelho dele.
      await tester.runAsync(() => donoA.solicitacoes.confirmar(pedidos[0].id));

      // Próxima sincronização (a cada 30 s): a lista se atualiza sozinha.
      await tester.pump(const Duration(seconds: 31));
      await _esperarTexto(tester, find.text('Encerrada'));
      expect(find.text('Encerrada'), findsNWidgets(2)); // B e C
      expect(find.text('Confirmado'), findsOneWidget); // A, já como partida
      expect(find.text('Aguardando aceite'), findsOneWidget); // D, 19:00
      expect(find.text('Ver partida'), findsOneWidget);

      // Um desafio encerrado: motivo à vista, sem aceite e sem chat.
      final cartao = find.ancestor(
        of: find.text('Encerrada').first,
        matching: find.byType(Panel),
      );
      await tester.tap(
        find.descendant(of: cartao, matching: find.text('Ver solicitação')),
      );
      await _esperarTexto(tester, find.text('Solicitação encerrada.'));
      expect(
        find.textContaining('já tem partida confirmada neste dia e horário'),
        findsWidgets,
      );
      expect(find.text('Aceitar desafio'), findsNothing);
      expect(find.byIcon(Icons.send), findsNothing);

      // Conversas: B e C saíram dos pendentes; D continua.
      await tester.tap(find.text('Conversas').last);
      await _esperarTexto(tester, find.text('Dono D $marca'));
      expect(find.text('Dono B $marca'), findsNothing);
      expect(find.text('Dono C $marca'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(
        const Duration(seconds: 20),
      ); // timers de timeout do ApiClient
    },
  );

  testWidgets(
    'recuperação de senha: e-mail real, link, nova senha e login',
    skip: _url.isEmpty || _emails.isEmpty,
    (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final (_, email) = (await tester.runAsync(() => _capitao('Senha')))!;
      final links = StreamController<Uri>();
      addTearDown(links.close);
      final state = AppState(
        criarRepositoriosApi(
          ApiClient(baseUrl: _url),
          armazenamento: ArmazenamentoEmMemoria(),
        ),
      );
      await tester.pumpWidget(JogaContraApp(state: state, links: links.stream));
      await _esperarTexto(tester, find.text('Seu time em campo.'));

      // 1. Pede o link pela tela "Esqueci minha senha".
      await tester.tap(find.text('Esqueci minha senha'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), email);
      await tester.tap(find.text('Enviar link'));
      await _esperarTexto(tester, find.text('Confira seu e-mail'));

      // 2. O e-mail chega de verdade (servidor SMTP local) com o link.
      final recebido = (await tester.runAsync(() => _emailPara(email)))!;
      expect(recebido['assunto'], 'Recuperação de senha — Joga Contra');
      final texto = recebido['texto'] as String;
      expect(texto, contains('30 minutos'));
      final token = RegExp(
        r'/redefinir-senha#token=([A-Za-z0-9_-]{43})',
      ).firstMatch(texto)!.group(1)!;

      // 3. A página do link abre o app com jogacontra://redefinir-senha.
      await tester.tap(find.text('Voltar para o login'));
      await tester.pumpAndSettle();
      links.add(Uri.parse('jogacontra://redefinir-senha?token=$token'));
      await tester.pumpAndSettle();
      expect(find.text('Crie uma nova senha'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nova senha'),
        _novaSenha,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar nova senha'),
        _novaSenha,
      );
      await tester.tap(find.text('Salvar nova senha'));
      await _esperarTexto(tester, find.text('Senha alterada!'));
      await tester.tap(find.text('Voltar para o login'));
      await tester.pumpAndSettle();

      // 4. A senha antiga não entra mais; a nova, sim.
      await tester.enterText(find.byType(TextFormField).at(0), email);
      await tester.enterText(find.byType(TextFormField).at(1), _senha);
      await tester.tap(find.text('Entrar'));
      await _esperarTexto(tester, find.text('E-mail ou senha inválidos.'));
      await tester.enterText(find.byType(TextFormField).at(1), _novaSenha);
      await tester.tap(find.text('Entrar'));
      await _esperarTexto(tester, find.text('BOM TE VER, CAPITÃO'));

      // 5. O mesmo link de novo: já utilizado.
      await _semSnackbar(tester);
      links.add(Uri.parse('jogacontra://redefinir-senha?token=$token'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nova senha'),
        'outra-senha-789',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar nova senha'),
        'outra-senha-789',
      );
      await tester.tap(find.text('Salvar nova senha'));
      await _esperarTexto(tester, find.text('Link já utilizado'));
      expect(state.autenticado, isTrue); // a tentativa falha e nada muda

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
    },
  );

  testWidgets(
    'central de notificações: aviso real no sino, na lista e lido',
    skip: _url.isEmpty,
    (tester) async {
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // O backend cria a notificação de verdade: outro time pede desafio.
      final marca = DateTime.now().microsecondsSinceEpoch.toString();
      final (dono, emailDono) = (await tester.runAsync(
        () => _capitao('Avisos $marca'),
      ))!;
      final idAnuncio = (await tester.runAsync(() async {
        final refs = await dono.referencias.carregar();
        final anuncio = await dono.anuncios.criar(
          RascunhoAnuncio(
            idModalidade: refs.modalidades.first.id,
            idNivelTecnico: refs.niveisTecnicos.first.id,
            dataHoraInicio: DateTime.now().add(const Duration(days: 6)),
            duracaoMinutos: 90,
            cidade: 'São Paulo',
            siglaEstado: 'SP',
            nomeLocal: 'Arena Avisos',
          ),
        );
        return anuncio.id;
      }))!;
      final (visita, _) = (await tester.runAsync(
        () => _capitao('Visita $marca'),
      ))!;
      await tester.runAsync(() => visita.solicitacoes.solicitar(idAnuncio));

      final state = AppState(
        criarRepositoriosApi(
          ApiClient(baseUrl: _url),
          armazenamento: ArmazenamentoEmMemoria(),
        ),
      );
      await tester.pumpWidget(JogaContraApp(state: state));
      await _esperarTexto(tester, find.text('Seu time em campo.'));
      await tester.enterText(find.byType(TextFormField).at(0), emailDono);
      await tester.enterText(find.byType(TextFormField).at(1), _senha);
      await tester.tap(find.text('Entrar'));
      await _esperarTexto(tester, find.text('BOM TE VER, CAPITÃO'));

      // Contador no sino.
      final contador = find.descendant(
        of: find.byTooltip('Notificações'),
        matching: find.text('1'),
      );
      await _esperarTexto(tester, contador);
      await _semSnackbar(tester);

      await tester.tap(find.byTooltip('Notificações'));
      await _esperarTexto(tester, find.text('Novo desafio recebido'));
      expect(find.text('1 não lida'), findsOneWidget);
      expect(find.byKey(const ValueKey('marcador-nao-lida')), findsOneWidget);
      expect(find.textContaining('Visita $marca'), findsOneWidget);

      // Tocar abre a conversa do pedido e marca como lida na API.
      await tester.tap(find.text('Novo desafio recebido'));
      await _esperarTexto(tester, find.text('Conversa'));
      await _aguardar(tester);
      final resumo = (await tester.runAsync(() => dono.notificacoes.resumo()))!;
      expect(resumo, (naoLidas: 0, total: 1));
      expect(contador, findsNothing);
      expect(state.notificacoesNaoLidas, 0);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
    },
  );

  testWidgets(
    'eventos reais: "Desafio aceito!" chega ao desafiante e abre o jogo',
    skip: _url.isEmpty,
    (tester) async {
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final marca = DateTime.now().microsecondsSinceEpoch.toString();
      final (dono, _) = (await tester.runAsync(
        () => _capitao('Uniao $marca'),
      ))!;
      final (joga, emailJoga) = (await tester.runAsync(
        () => _capitao('Joga $marca'),
      ))!;
      // O dono anuncia, o JOGA desafia e o dono aceita: tudo pela API real.
      await tester.runAsync(() async {
        final refs = await dono.referencias.carregar();
        final anuncio = await dono.anuncios.criar(
          RascunhoAnuncio(
            idModalidade: refs.modalidades.first.id,
            idNivelTecnico: refs.niveisTecnicos.first.id,
            dataHoraInicio: DateTime.now().add(const Duration(days: 8)),
            duracaoMinutos: 90,
            cidade: 'São Paulo',
            siglaEstado: 'SP',
            nomeLocal: 'Arena Biase',
          ),
        );
        final pedido = await joga.solicitacoes.solicitar(anuncio.id);
        await dono.solicitacoes.confirmar(pedido.id);
      });

      final state = AppState(
        criarRepositoriosApi(
          ApiClient(baseUrl: _url),
          armazenamento: ArmazenamentoEmMemoria(),
        ),
      );
      await tester.pumpWidget(JogaContraApp(state: state));
      await _esperarTexto(tester, find.text('Seu time em campo.'));
      await tester.enterText(find.byType(TextFormField).at(0), emailJoga);
      await tester.enterText(find.byType(TextFormField).at(1), _senha);
      await tester.tap(find.text('Entrar'));
      await _esperarTexto(tester, find.text('BOM TE VER, CAPITÃO'));

      // Só o aceite conta como novidade (o envio chegou já lido).
      await _esperarTexto(
        tester,
        find.descendant(
          of: find.byTooltip('Notificações'),
          matching: find.text('1'),
        ),
      );
      await _semSnackbar(tester);
      await tester.tap(find.byTooltip('Notificações'));
      await _esperarTexto(tester, find.text('Desafio aceito!'));
      expect(find.text('Desafio enviado'), findsOneWidget);
      expect(
        find.textContaining('Arena Biase. O chat com o outro capitão'),
        findsOneWidget,
      );
      expect(find.textContaining('contra o time Uniao $marca'), findsOneWidget);

      await tester.tap(find.text('Desafio aceito!'));
      await _esperarTexto(tester, find.text('Partida confirmada'));
      await _aguardar(tester);
      expect(state.notificacoesNaoLidas, 0);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
    },
  );
}
