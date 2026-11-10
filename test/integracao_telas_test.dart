import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joga_contra/main.dart';
import 'package:joga_contra/models/anuncio_partida.dart';
import 'package:joga_contra/models/usuario.dart';
import 'package:joga_contra/repositories/api/api_repositories.dart';
import 'package:joga_contra/services/api_client.dart';
import 'package:joga_contra/services/armazenamento_sessao.dart';
import 'package:joga_contra/state/app_state.dart';

/// Telas reais do app com a API rodando (sem dados de demonstração).
/// Grava dados fictícios: só roda com `--dart-define=API_TESTE_URL=...`.
const _url = String.fromEnvironment('API_TESTE_URL');
const _senha = 'senha-de-teste-123';

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
      await _esperarTexto(tester, find.text(nomeDono));
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

      // Mensagem real.
      await tester.enterText(find.byType(TextField).first, 'Bora jogar?');
      await tester.tap(find.byIcon(Icons.send));
      await _esperarTexto(tester, find.text('Bora jogar?'));

      // Um lado confirma: a partida ainda depende do outro time.
      await _semSnackbar(tester);
      await tester.ensureVisible(find.text('Confirmar partida'));
      await tester.pump();
      await tester.tap(find.text('Confirmar partida'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar partida'));
      await _esperarTexto(tester, find.text('Aguardando o adversário'));

      await tester.tap(find.text('Conversas').last);
      await _esperarTexto(tester, find.text(nomeDono));
      expect(find.text('Bora jogar?'), findsOneWidget);

      await tester.tap(find.byTooltip('Notificações'));
      await _esperarTexto(tester, find.text('Tudo tranquilo por aqui.'));

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
      await _esperarTexto(tester, find.text('Tem rival querendo jogo!'));
      await tester.tap(find.text('Tem rival querendo jogo!'));
      await _esperarTexto(tester, find.text('Bora jogar?'));

      // O dono confirma: as telas mostram a partida vinda do banco.
      await _semSnackbar(tester);
      await tester.ensureVisible(find.text('Confirmar partida'));
      await tester.pump();
      await tester.tap(find.text('Confirmar partida'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar partida'));
      await _esperarTexto(tester, find.text('Partida confirmada!'));
      expect(find.text('Visitante $marca'), findsOneWidget);

      await tester.tap(find.text('Início').last);
      await _esperarTexto(tester, find.text('Próxima partida'));
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
}
