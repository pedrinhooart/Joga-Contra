import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joga_contra/main.dart';
import 'package:joga_contra/models/usuario.dart';
import 'package:joga_contra/repositories/contratos.dart';
import 'package:joga_contra/repositories/demo/demo_repositories.dart';
import 'package:joga_contra/services/api_client.dart';
import 'package:joga_contra/services/links_recebidos.dart';
import 'package:joga_contra/state/app_state.dart';

/// Autenticação de demonstração que registra os pedidos de recuperação e
/// responde à redefinição como a API configurada no teste.
class _AuthDeTeste implements AuthRepository {
  _AuthDeTeste(this._base, {this.logado = true});
  final AuthRepository _base;
  bool logado;
  final pedidos = <String>[];
  final redefinicoes = <Map<String, String>>[];

  /// Erro devolvido pela "API" na redefinição (null = sucesso).
  ApiException? erroRedefinicao;

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
  Future<void> solicitarRecuperacaoSenha(String email) async =>
      pedidos.add(email);
  @override
  Future<void> redefinirSenha({
    required String token,
    required String novaSenha,
    required String confirmacaoSenha,
  }) async {
    redefinicoes.add({
      'token': token,
      'novaSenha': novaSenha,
      'confirmacaoSenha': confirmacaoSenha,
    });
    if (erroRedefinicao != null) throw erroRedefinicao!;
  }

  @override
  Future<void> sair() async {
    logado = false;
    await _base.sair();
  }
}

const _token = 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789_-abcde';

Future<(AppState, _AuthDeTeste, StreamController<Uri>)> _abrirApp(
  WidgetTester tester, {
  bool logado = false,
}) async {
  tester.view.physicalSize = const Size(600, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final demo = criarRepositoriosDemo();
  final auth = _AuthDeTeste(demo.auth, logado: logado);
  final state = AppState(
    Repositorios(
      auth: auth,
      referencias: demo.referencias,
      times: demo.times,
      anuncios: demo.anuncios,
      solicitacoes: demo.solicitacoes,
      partidas: demo.partidas,
      notificacoes: demo.notificacoes,
      locais: demo.locais,
    ),
  );
  final links = StreamController<Uri>();
  addTearDown(links.close);
  await tester.pumpWidget(JogaContraApp(state: state, links: links.stream));
  await tester.pumpAndSettle();
  return (state, auth, links);
}

Future<void> _abrirLink(
  WidgetTester tester,
  StreamController<Uri> links,
  String link,
) async {
  links.add(Uri.parse(link));
  await tester.pumpAndSettle();
}

Future<void> _preencher(WidgetTester tester, String nova, String conf) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Nova senha'),
    nova,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Confirmar nova senha'),
    conf,
  );
  await tester.tap(find.text('Salvar nova senha'));
  await tester.pumpAndSettle();
}

void main() {
  group('link recebido', () {
    test('lê o token do esquema do app e do link https', () {
      expect(
        LinksRecebidos.tokenDeRedefinicao(
          Uri.parse('jogacontra://redefinir-senha?token=$_token'),
        ),
        _token,
      );
      expect(
        LinksRecebidos.tokenDeRedefinicao(
          Uri.parse('https://api.exemplo.test/redefinir-senha#token=$_token'),
        ),
        _token,
      );
    });

    test('recusa token malformado e links de outras telas', () {
      for (final link in [
        'jogacontra://redefinir-senha?token=curto',
        'jogacontra://redefinir-senha',
        'jogacontra://outra-coisa?token=$_token',
        'https://api.exemplo.test/outra#token=$_token',
        'mailto:x@exemplo.test',
      ]) {
        expect(
          LinksRecebidos.tokenDeRedefinicao(Uri.parse(link)),
          isNull,
          reason: link,
        );
      }
      expect(
        LinksRecebidos.eRedefinicao(Uri.parse('jogacontra://redefinir-senha')),
        isTrue,
      );
      expect(
        LinksRecebidos.eRedefinicao(Uri.parse('jogacontra://outra-coisa')),
        isFalse,
      );
    });
  });

  testWidgets('esqueci minha senha: pede o link e mostra a orientação', (
    tester,
  ) async {
    final (_, auth, _) = await _abrirApp(tester);
    expect(find.text('Seu time em campo.'), findsOneWidget);
    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();
    expect(find.text('Recupere seu acesso'), findsOneWidget);

    // Validação local antes de chamar a API.
    await tester.tap(find.text('Enviar link'));
    await tester.pumpAndSettle();
    expect(find.text('Informe um e-mail válido'), findsOneWidget);
    expect(auth.pedidos, isEmpty);

    await tester.enterText(find.byType(TextFormField), ' Ana@Exemplo.test ');
    await tester.tap(find.text('Enviar link'));
    await tester.pumpAndSettle();
    expect(auth.pedidos, ['ana@exemplo.test']);
    expect(find.text('Confira seu e-mail'), findsOneWidget);
    expect(find.text('Se este e-mail estiver cadastrado:'), findsOneWidget);
    // O endereço normalizado, em linha própria.
    expect(find.text('ana@exemplo.test'), findsOneWidget);
    expect(find.textContaining('30 minutos'), findsOneWidget);

    await tester.tap(find.text('Voltar para o login'));
    await tester.pumpAndSettle();
    expect(find.text('Seu time em campo.'), findsOneWidget);
  });

  testWidgets('link do e-mail abre a nova senha; sucesso volta ao login', (
    tester,
  ) async {
    final (state, auth, links) = await _abrirApp(tester);
    await _abrirLink(
      tester,
      links,
      'jogacontra://redefinir-senha?token=$_token',
    );
    expect(find.text('Crie uma nova senha'), findsOneWidget);
    expect(state.tokenRedefinicao, _token);

    // Validações locais: tamanho, igualdade e limite do bcrypt.
    await _preencher(tester, '1234567', '1234567');
    expect(find.text('A senha precisa de pelo menos 8 caracteres'), findsOne);
    await _preencher(tester, 'nova-senha-1', 'nova-senha-2');
    expect(find.text('As senhas não são iguais'), findsOneWidget);
    await _preencher(tester, 'ç' * 40, 'ç' * 40);
    expect(find.text('Senha longa demais'), findsOneWidget);
    expect(auth.redefinicoes, isEmpty);

    // Mostrar a senha.
    await tester.tap(find.byTooltip('Mostrar senha'));
    await tester.pump();
    expect(find.byTooltip('Ocultar senha'), findsOneWidget);

    await _preencher(tester, 'nova-senha-1', 'nova-senha-1');
    expect(auth.redefinicoes.single, {
      'token': _token,
      'novaSenha': 'nova-senha-1',
      'confirmacaoSenha': 'nova-senha-1',
    });
    expect(find.text('Senha alterada!'), findsOneWidget);
    await tester.tap(find.text('Voltar para o login'));
    await tester.pumpAndSettle();
    expect(state.tokenRedefinicao, isNull);
    expect(find.text('Seu time em campo.'), findsOneWidget);
  });

  testWidgets('com sessão aberta: a troca encerra a sessão deste aparelho', (
    tester,
  ) async {
    final (state, _, links) = await _abrirApp(tester, logado: true);
    expect(state.autenticado, isTrue);
    await _abrirLink(
      tester,
      links,
      'jogacontra://redefinir-senha?token=$_token',
    );
    expect(find.text('Crie uma nova senha'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await _preencher(tester, 'nova-senha-1', 'nova-senha-1');
    expect(state.autenticado, isFalse);
    await tester.tap(find.text('Voltar para o login'));
    await tester.pumpAndSettle();
    expect(find.text('Seu time em campo.'), findsOneWidget);
  });

  for (final (codigo, titulo) in [
    ('TOKEN_EXPIRADO', 'Link expirado'),
    ('TOKEN_UTILIZADO', 'Link já utilizado'),
    ('TOKEN_SUBSTITUIDO', 'Link substituído'),
    ('TOKEN_INVALIDO', 'Link inválido'),
  ]) {
    testWidgets('$codigo: explica e oferece um novo link', (tester) async {
      final (state, auth, links) = await _abrirApp(tester);
      auth.erroRedefinicao = ApiException(
        'Mensagem da API para $codigo.',
        statusCode: codigo == 'TOKEN_INVALIDO' ? 400 : 410,
        code: codigo,
      );
      await _abrirLink(
        tester,
        links,
        'jogacontra://redefinir-senha?token=$_token',
      );
      await _preencher(tester, 'nova-senha-1', 'nova-senha-1');
      expect(find.text(titulo), findsOneWidget);
      expect(find.text('Mensagem da API para $codigo.'), findsOneWidget);
      expect(find.text('Salvar nova senha'), findsNothing);

      await tester.tap(find.text('Pedir novo link'));
      await tester.pumpAndSettle();
      expect(state.tokenRedefinicao, isNull);
      expect(find.text('Recupere seu acesso'), findsOneWidget);
    });
  }

  testWidgets('erro sem relação com o link fica no formulário', (tester) async {
    final (_, auth, links) = await _abrirApp(tester);
    auth.erroRedefinicao = ApiException(
      'Sem conexão com o servidor.',
      statusCode: 0,
    );
    await _abrirLink(
      tester,
      links,
      'jogacontra://redefinir-senha?token=$_token',
    );
    await _preencher(tester, 'nova-senha-1', 'nova-senha-1');
    expect(find.text('Sem conexão com o servidor.'), findsOneWidget);
    expect(find.text('Salvar nova senha'), findsOneWidget);
  });

  testWidgets('link sem token mostra "Link inválido" sem chamar a API', (
    tester,
  ) async {
    final (_, auth, links) = await _abrirApp(tester);
    await _abrirLink(tester, links, 'jogacontra://redefinir-senha?token=x');
    expect(find.text('Link inválido'), findsOneWidget);
    expect(auth.redefinicoes, isEmpty);
    await tester.tap(find.text('Voltar para o login'));
    await tester.pumpAndSettle();
    expect(find.text('Seu time em campo.'), findsOneWidget);
  });

  testWidgets('outros links não mudam a tela', (tester) async {
    final (state, _, links) = await _abrirApp(tester);
    await _abrirLink(tester, links, 'jogacontra://outra-coisa?token=$_token');
    expect(state.tokenRedefinicao, isNull);
    expect(find.text('Seu time em campo.'), findsOneWidget);
  });

  testWidgets('voltar (botão do sistema) cancela a redefinição', (
    tester,
  ) async {
    final (state, _, links) = await _abrirApp(tester);
    await _abrirLink(
      tester,
      links,
      'jogacontra://redefinir-senha?token=$_token',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(state.tokenRedefinicao, isNull);
    expect(find.text('Seu time em campo.'), findsOneWidget);
  });
}
