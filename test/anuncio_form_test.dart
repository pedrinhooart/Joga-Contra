import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joga_contra/core/formatters.dart';
import 'package:joga_contra/models/anuncio_partida.dart';
import 'package:joga_contra/models/local_esportivo.dart';
import 'package:joga_contra/repositories/contratos.dart';
import 'package:joga_contra/repositories/demo/demo_repositories.dart';
import 'package:joga_contra/screens/activity_screens.dart';
import 'package:joga_contra/services/municipios.dart';
import 'package:joga_contra/state/app_state.dart';
import 'package:joga_contra/widgets/campo_local.dart';

/// Fonte de locais do teste (dados de exemplo só para o teste).
class _LocaisTeste implements LocalRepository {
  int consultas = 0;
  @override
  Future<LocaisDaCidade> daCidade(String siglaEstado, String cidade) async {
    consultas++;
    return const LocaisDaCidade([
      LocalEsportivo(
        nome: 'Arena Teste Society',
        endereco: 'Rua A, 10 - Centro',
        latitude: -23.5,
        longitude: -46.6,
      ),
      LocalEsportivo(nome: 'Quadra Teste Bairro'),
    ], atribuicao: '© fonte de teste');
  }
}

late _LocaisTeste _locais;
RascunhoAnuncio? _enviado;

Future<void> _abrirFormulario(WidgetTester tester) async {
  tester.view.physicalSize = const Size(700, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.runAsync(Municipios.carregar);
  final demo = criarRepositoriosDemo();
  _locais = _LocaisTeste();
  final state = AppState(
    Repositorios(
      auth: demo.auth,
      referencias: demo.referencias,
      times: demo.times,
      anuncios: demo.anuncios,
      solicitacoes: demo.solicitacoes,
      partidas: demo.partidas,
      notificacoes: demo.notificacoes,
      locais: _locais,
    ),
  );
  await state.inicializar();
  _enviado = null;
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: CreateGameScreen(onSalvar: (r) async => _enviado = r),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _escolherNoMenu(
  WidgetTester tester,
  String campo,
  String opcao,
) async {
  final menu = find.widgetWithText(DropdownButtonFormField<int>, campo);
  await tester.ensureVisible(menu);
  await tester.pumpAndSettle();
  await tester.tap(menu);
  await tester.pumpAndSettle();
  await tester.tap(find.text(opcao).last);
  await tester.pumpAndSettle();
}

Future<void> _publicar(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Publicar anúncio'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Publicar anúncio'));
  await tester.pumpAndSettle();
}

Finder get _campoLocal =>
    find.widgetWithText(TextFormField, 'Local da partida');

void main() {
  setUp(CampoLocal.limparCache);

  testWidgets('formulário só com os campos do jogo', (tester) async {
    await _abrirFormulario(tester);
    for (final campo in [
      'Modalidade',
      'Nível do time',
      'Data',
      'Horário',
      'Duração da partida',
      'Estado',
      'Cidade',
      'Local da partida',
    ]) {
      expect(find.text(campo), findsWidgets, reason: campo);
    }
    for (final removido in [
      'Categoria',
      'Quantidade de jogadores',
      'Mando de campo',
      'Bairro / região',
    ]) {
      expect(find.text(removido), findsNothing, reason: removido);
    }
    // Estado vem antes da cidade, que vem antes do local.
    double y(String t) => tester.getTopLeft(find.text(t).first).dy;
    expect(y('Estado'), lessThan(y('Cidade')));
    expect(y('Cidade'), lessThan(y('Local da partida')));
  });

  testWidgets('sem preencher, avisa data, horário e duração', (tester) async {
    await _abrirFormulario(tester);
    await _publicar(tester);
    expect(find.text('Escolha a data'), findsOneWidget);
    expect(find.text('Escolha o horário'), findsOneWidget);
    expect(find.text('Escolha a duração da partida'), findsOneWidget);
    expect(_enviado, isNull);
  });

  testWidgets('data no calendário, a partir de hoje, em DD/MM/AAAA', (
    tester,
  ) async {
    await _abrirFormulario(tester);
    await tester.tap(find.widgetWithText(TextFormField, 'Data'));
    await tester.pumpAndSettle();
    final calendario = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    final hoje = DateUtils.dateOnly(DateTime.now());
    expect(calendario.firstDate, hoje); // nada antes de hoje
    expect(find.text('Data da partida'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text(Formatos.dataNumerica(hoje)), findsOneWidget);
    expect(
      RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(Formatos.dataNumerica(hoje)),
      isTrue,
    );
  });

  testWidgets('horário no relógio de 24 horas, em HH:mm', (tester) async {
    await _abrirFormulario(tester);
    await tester.tap(find.widgetWithText(TextFormField, 'Horário'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(find.text('AM'), findsNothing); // sem AM/PM
    expect(find.text('PM'), findsNothing);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('16:00'), findsOneWidget);
  });

  testWidgets('duração: opções de 30 min a 3 h e personalizada', (
    tester,
  ) async {
    await _abrirFormulario(tester);
    final menu = find.widgetWithText(
      DropdownButtonFormField<int>,
      'Duração da partida',
    );
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    for (final opcao in [
      '30 min',
      '1 h',
      '1 h 30 min',
      '2 h',
      '2 h 30 min',
      '3 h',
      'Outra duração…',
    ]) {
      expect(find.text(opcao), findsWidgets, reason: opcao);
    }
    await tester.tap(find.text('Outra duração…').last);
    await tester.pumpAndSettle();
    await _escolherNoMenu(tester, 'Horas', '2 h');
    await _escolherNoMenu(tester, 'Minutos', '15 min');
    await tester.tap(find.text('Usar 2 h 15 min'));
    await tester.pumpAndSettle();
    expect(find.text('2 h 15 min'), findsOneWidget);
  });

  testWidgets('local: sugestões da cidade, filtro, escolha e modo manual', (
    tester,
  ) async {
    await _abrirFormulario(tester);
    // A cidade do time (São Paulo) já é válida: uma consulta, após a espera.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(_locais.consultas, 1);

    await tester.ensureVisible(_campoLocal);
    await tester.pumpAndSettle();
    await tester.enterText(_campoLocal, 'arena');
    await tester.pumpAndSettle();
    expect(find.text('Arena Teste Society'), findsOneWidget);
    expect(find.text('Quadra Teste Bairro'), findsNothing); // filtrado
    expect(find.text('Dados © fonte de teste'), findsOneWidget);
    expect(_locais.consultas, 1); // digitar não consulta de novo
    await tester.tap(find.text('Arena Teste Society'));
    await tester.pumpAndSettle();

    // Preenche o resto e publica: vai com endereço e coordenadas.
    await _escolherNoMenu(tester, 'Modalidade', 'Futebol de quadra');
    await _escolherNoMenu(tester, 'Nível do time', 'Avançado');
    await tester.tap(find.widgetWithText(TextFormField, 'Data'));
    await tester.pumpAndSettle();
    final amanha = DateUtils.dateOnly(
      DateTime.now(),
    ).add(const Duration(days: 1));
    await tester.tap(find.byIcon(Icons.edit_outlined).last); // digitar a data
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      Formatos.dataNumerica(amanha),
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextFormField, 'Horário'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await _escolherNoMenu(tester, 'Duração da partida', '1 h 30 min');
    await _publicar(tester);

    final r = _enviado!;
    expect(r.nomeLocal, 'Arena Teste Society');
    expect(r.endereco, 'Rua A, 10 - Centro');
    expect((r.latitude, r.longitude), (-23.5, -46.6));
    expect(r.duracaoMinutos, 90);
    expect(r.cidade, 'São Paulo');
    expect(r.siglaEstado, 'SP');
    expect(
      r.dataHoraInicio,
      DateTime(amanha.year, amanha.month, amanha.day, 16),
    );
    expect(r.toJson()['idCategoriaEtaria'], isNull);
    expect(r.toJson()['quantidadeJogadores'], isNull);
    expect(r.toJson()['idMandoCampo'], isNull);
    expect(r.toJson()['bairro'], isNull);

    // Mudar o texto do local escolhido vira local digitado: sem coordenadas.
    await tester.enterText(_campoLocal, 'Campo do Zé');
    await tester.pumpAndSettle();
    await _publicar(tester);
    expect(_enviado!.nomeLocal, 'Campo do Zé');
    expect(_enviado!.endereco, isNull);
    expect(_enviado!.latitude, isNull);
  });

  testWidgets('cancelar a duração personalizada mantém a escolha anterior', (
    tester,
  ) async {
    await _abrirFormulario(tester);
    await _escolherNoMenu(tester, 'Duração da partida', '1 h 30 min');
    await _escolherNoMenu(tester, 'Duração da partida', 'Outra duração…');
    expect(find.text('Duração da partida'), findsWidgets);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('1 h 30 min'), findsOneWidget);
    expect(find.text('Outra duração…'), findsNothing);
  });
}
