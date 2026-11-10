import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:joga_contra/main.dart';
import 'package:joga_contra/models/time.dart';
import 'package:joga_contra/repositories/contratos.dart';
import 'package:joga_contra/repositories/demo/demo_repositories.dart';
import 'package:joga_contra/services/api_client.dart';
import 'package:joga_contra/services/selecao_imagem.dart';
import 'package:joga_contra/state/app_state.dart';
import 'package:joga_contra/widgets/common.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

/// Times da demonstração, mas o envio da foto falha como sem conexão.
class _EnvioFalha implements TimeRepository {
  _EnvioFalha(this.real);
  final TimeRepository real;
  @override
  Future<Time> buscar(String idTime) => real.buscar(idTime);
  @override
  Future<Time> atualizar(String idTime, AtualizacaoTime dados) =>
      real.atualizar(idTime, dados);
  @override
  Future<Time> enviarEscudo(String idTime, ImagemSelecionada imagem) =>
      throw ApiException(
        'Não foi possível conectar ao servidor.',
        statusCode: 0,
      );
}

Future<AppState> _abrirPerfil(
  WidgetTester tester, {
  bool envioFalha = false,
}) async {
  tester.view.physicalSize = const Size(700, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final demo = criarRepositoriosDemo();
  final state = AppState(
    envioFalha
        ? Repositorios(
            auth: demo.auth,
            referencias: demo.referencias,
            times: _EnvioFalha(demo.times),
            anuncios: demo.anuncios,
            solicitacoes: demo.solicitacoes,
            partidas: demo.partidas,
            notificacoes: demo.notificacoes,
          )
        : demo,
  );
  await tester.pumpWidget(JogaContraApp(state: state));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Perfil').last);
  await tester.pumpAndSettle();
  return state;
}

Future<void> _tocarFoto(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.photo_camera_outlined));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => SelecaoDeImagem.selecionar = () async => null);

  testWidgets('perfil não mostra modalidade, categoria, nível e quantidade', (
    tester,
  ) async {
    final state = await _abrirPerfil(tester);
    final time = state.time!;
    // O time da demonstração tem os quatro dados: nenhum aparece no perfil.
    expect(time.modalidades, isNotEmpty);
    expect(time.categoriaEtaria, isNotNull);
    expect(time.nivelTecnico, isNotNull);
    expect(time.quantidadeJogadores, isNotNull);
    for (final texto in [
      time.modalidades.first.nome,
      time.categoriaEtaria!.nome,
      time.nivelTecnico!.nome,
      '${time.quantidadeJogadores} jogadores',
    ]) {
      expect(find.text(texto), findsNothing, reason: texto);
    }
    expect(find.text('Sobre o time'), findsOneWidget);
    expect(find.text(time.nome), findsOneWidget);
  });

  testWidgets('foto: prévia, cancelar mantém a atual, salvar troca', (
    tester,
  ) async {
    final state = await _abrirPerfil(tester);
    SelecaoDeImagem.selecionar = () async =>
        SelecaoDeImagem.validar(Uint8List.fromList(_png));

    // Cancelar na prévia: nada muda.
    await _tocarFoto(tester);
    expect(find.text('Nova foto do time'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Prévia da nova foto do time'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Nova foto do time'), findsNothing);
    expect(state.time!.urlEscudo, isNull);

    // Salvar: o perfil passa a mostrar a foto.
    await _tocarFoto(tester);
    await tester.tap(find.text('Salvar foto'));
    await tester.pumpAndSettle();
    expect(find.text('Nova foto do time'), findsNothing);
    expect(state.time!.urlEscudo, startsWith('data:image/png;base64,'));
    expect(find.text('Foto do time atualizada!'), findsOneWidget);
    final escudos = tester.widgetList<Crest>(find.byType(Crest));
    expect(escudos.where((c) => c.imagem == state.time!.urlEscudo), isNotEmpty);
    expect(
      find.descendant(of: find.byType(Crest), matching: find.byType(Image)),
      findsWidgets,
    );
    await tester.pump(const Duration(seconds: 4)); // snackbar
  });

  testWidgets('fechar a galeria sem escolher não abre a prévia', (
    tester,
  ) async {
    await _abrirPerfil(tester);
    SelecaoDeImagem.selecionar = () async => null;
    await _tocarFoto(tester);
    expect(find.text('Nova foto do time'), findsNothing);
  });

  testWidgets('arquivo que não é imagem mostra o motivo', (tester) async {
    await _abrirPerfil(tester);
    SelecaoDeImagem.selecionar = () async =>
        SelecaoDeImagem.validar(Uint8List.fromList(utf8.encode('não é foto')));
    await _tocarFoto(tester);
    expect(find.text('Escolha uma imagem JPG, PNG ou WebP.'), findsOneWidget);
    expect(find.text('Nova foto do time'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('falha no envio mantém a foto atual e permite tentar de novo', (
    tester,
  ) async {
    final state = await _abrirPerfil(tester, envioFalha: true);
    SelecaoDeImagem.selecionar = () async =>
        SelecaoDeImagem.validar(Uint8List.fromList(_png));
    await _tocarFoto(tester);
    await tester.tap(find.text('Salvar foto'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível conectar ao servidor.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(state.time!.urlEscudo, isNull);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Nova foto do time'), findsNothing);
  });

  testWidgets('descrição: salvar, cancelar e remover', (tester) async {
    final state = await _abrirPerfil(tester);
    const nova = 'Time de amigos desde 2010. Jogo limpo e pontualidade.';

    await tester.tap(find.byTooltip('Editar descrição'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, nova);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text(nova), findsOneWidget);
    expect(state.time!.descricao, nova);
    await tester.pump(const Duration(seconds: 4));

    // Cancelar descarta o texto digitado.
    await tester.tap(find.byTooltip('Editar descrição'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Rascunho');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text(nova), findsOneWidget);
    expect(find.text('Rascunho'), findsNothing);

    // Em branco remove: volta o convite para escrever.
    await tester.tap(find.byTooltip('Editar descrição'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '   ');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(state.time!.descricao, isNull);
    expect(
      find.text('Conte a história do seu time para os adversários.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
  });

  group('envio pela API', () {
    test('foto vai como corpo binário com o tipo da imagem', () async {
      late http.Request enviada;
      final api = ApiClient(
        baseUrl: 'http://api.teste/api',
        client: MockClient((req) async {
          enviada = req;
          return http.Response(
            '{"data":{"idTime":"t1","idCapitao":"u1","nome":"X","cidade":"Y",'
            '"siglaEstado":"SP","urlEscudo":"/api/arquivos/escudos/t1-a.png"}}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final dados = await api.putBytes(
        '/times/t1/escudo',
        Uint8List.fromList(_png),
        'image/png',
      );
      expect(enviada.method, 'PUT');
      expect(enviada.headers['Content-Type'], 'image/png');
      expect(enviada.bodyBytes, _png);
      expect(Time.fromJson(dados).urlEscudo, '/api/arquivos/escudos/t1-a.png');
    });

    test('sem conexão e arquivo grande viram mensagens claras', () async {
      final semRede = ApiClient(
        baseUrl: 'http://api.teste/api',
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      await expectLater(
        semRede.putBytes('/times/t1/escudo', Uint8List(4), 'image/png'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'mensagem',
            'Não foi possível conectar ao servidor.',
          ),
        ),
      );
      final grande = ApiClient(
        baseUrl: 'http://api.teste/api',
        client: MockClient(
          (_) async => http.Response(
            '{"error":{"code":"PAYLOAD_TOO_LARGE","message":"O envio passa do tamanho máximo permitido."}}',
            413,
          ),
        ),
      );
      await expectLater(
        grande.putBytes('/times/t1/escudo', Uint8List(4), 'image/png'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 413)),
      );
      expect(
        () => SelecaoDeImagem.validar(
          Uint8List.fromList([
            ..._png,
            ...Uint8List(ImagemSelecionada.limiteBytes),
          ]),
        ),
        throwsA(isA<ErroImagem>()),
      );
    });
  });
}
