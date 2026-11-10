import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joga_contra/main.dart';
import 'package:joga_contra/models/usuario.dart';
import 'package:joga_contra/repositories/demo/demo_repositories.dart';
import 'package:joga_contra/services/municipios.dart';
import 'package:joga_contra/state/app_state.dart';

/// Percorre todas as telas com as fontes reais (Roboto e ícones do SDK) em
/// celulares de tamanhos diferentes, com textos longos. Falha em qualquer
/// texto cortado por falta de espaço (overflow).
///
/// Capturas de tela: `--dart-define=CAPTURAS=C:/pasta`.
const _capturas = String.fromEnvironment('CAPTURAS');

const _tamanhos = {
  'pequeno_360x640': Size(360, 640),
  'medio_390x844': Size(390, 844),
  'grande_412x915': Size(412, 915),
};

/// Pasta de fontes do SDK do Flutter em uso, ou nulo se não encontrada.
Directory? _fontesDoSdk() {
  var pasta = File(Platform.resolvedExecutable).parent;
  while (pasta.parent.path != pasta.path) {
    final fontes = Directory(
      '${pasta.path}/bin/cache/artifacts/material_fonts',
    );
    if (fontes.existsSync()) return fontes;
    pasta = pasta.parent;
  }
  return null;
}

Future<void> _carregarFontes(Directory pasta) async {
  Future<void> familia(String nome, List<String> arquivos) async {
    final loader = FontLoader(nome);
    for (final a in arquivos) {
      final bytes = File('${pasta.path}/$a').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await familia('Roboto', [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
    'roboto-light.ttf',
  ]);
  await familia('MaterialIcons', ['materialicons-regular.otf']);
}

void main() {
  final fontes = _fontesDoSdk();

  setUpAll(() async {
    if (fontes != null) await _carregarFontes(fontes);
  });

  for (final MapEntry(key: nome, value: tamanho) in _tamanhos.entries) {
    testWidgets(
      'todas as telas cabem em $nome com as fontes maiores',
      skip: fontes == null,
      (tester) async {
        tester.view.physicalSize = tamanho;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(Municipios.carregar);

        // Nomes longos de verdade: time e município do IBGE.
        final state = AppState(criarRepositoriosDemo());
        await state.cadastrar(
          const CadastroCapitao(
            nome: 'Maria Aparecida dos Santos Albuquerque',
            email: 'maria@example.com',
            senha: 'senha-longa-123',
            nomeTime: 'Associação Atlética Unidos da Vila Esperança FC',
            cidade: "Santa Bárbara d'Oeste",
            siglaEstado: 'SP',
          ),
        );
        final raiz = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: raiz,
            child: JogaContraApp(state: state),
          ),
        );
        await tester.pumpAndSettle();
        // A logo é um asset: decodifica fora do relógio simulado do teste.
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/imagens/logo_joga_contra.png'),
            tester.element(find.byType(Scaffold).first),
          ),
        );

        final erros = <String>[];
        Future<void> conferir(String tela) async {
          await tester.pumpAndSettle();
          final erro = tester.takeException();
          if (erro != null) erros.add('$tela: $erro');
          if (_capturas.isEmpty) return;
          await tester.runAsync(() async {
            final boundary =
                raiz.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final imagem = await boundary.toImage(pixelRatio: 2);
            final png = await imagem.toByteData(format: ui.ImageByteFormat.png);
            final arquivo = File('$_capturas/${nome}_$tela.png');
            await arquivo.create(recursive: true);
            await arquivo.writeAsBytes(png!.buffer.asUint8List());
          });
        }

        Future<void> aba(String rotulo) async {
          await tester.tap(find.text(rotulo).last);
          await tester.pumpAndSettle();
        }

        Future<void> rolarAteFim() async {
          await tester.fling(
            find.byType(Scrollable).first,
            const Offset(0, -3000),
            3000,
          );
          await tester.pumpAndSettle();
        }

        await conferir('01_inicio');
        await rolarAteFim();
        await conferir('02_inicio_fim');

        await aba('Buscar');
        await conferir('03_busca');
        await tester.tap(find.text('Filtros'));
        await conferir('04_filtros');
        await tester.tapAt(const Offset(20, 20)); // fecha a folha
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Ver detalhes').first);
        await tester.pumpAndSettle();
        final y = tester.getCenter(find.text('Ver detalhes').first).dy;
        await tester.drag(
          find.byType(Scrollable).first,
          Offset(0, tamanho.height / 2 - y),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ver detalhes').first);
        await conferir('05_detalhes');
        await rolarAteFim();
        await conferir('06_detalhes_fim');
        await tester.ensureVisible(find.text('Tenho interesse'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tenho interesse'));
        await conferir('07_confirmar_interesse');
        await tester.tap(find.text('Sim, tenho interesse'));
        await conferir('08_conversa');

        await aba('Conversas');
        await conferir('09_conversas');

        await aba('Anunciar');
        await conferir('10_anunciar');
        await rolarAteFim();
        await conferir('11_anunciar_fim');

        await aba('Perfil');
        await conferir('12_perfil');
        await rolarAteFim();
        await conferir('13_perfil_fim');
        await tester.scrollUntilVisible(
          find.text('Ver todos os jogos'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ver todos os jogos'));
        await conferir('14_meus_jogos');

        await tester.tap(find.byTooltip('Notificações'));
        await conferir('15_notificacoes');

        await aba('Buscar');
        await tester.tap(find.text('Mapa'));
        await conferir('16_mapa');

        await aba('Perfil');
        await tester.scrollUntilVisible(
          find.text('Sair da conta'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sair da conta'));
        await conferir('17_login');
        await tester.scrollUntilVisible(
          find.text('Ainda não tem conta? Criar conta'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ainda não tem conta? Criar conta'));
        await conferir('18_cadastro');
        await rolarAteFim();
        await conferir('19_cadastro_fim');
        await tester.scrollUntilVisible(
          find.text('Já tem conta? Entrar'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Já tem conta? Entrar'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Esqueci minha senha'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Esqueci minha senha'));
        await conferir('20_recuperar_senha');

        expect(erros, isEmpty, reason: erros.join('\n'));
        await tester.pump(const Duration(seconds: 5)); // snackbars
      },
    );
  }
}
