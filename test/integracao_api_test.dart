import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:joga_contra/core/uuid.dart';
import 'package:joga_contra/core/formatters.dart';
import 'package:joga_contra/models/anuncio_partida.dart';
import 'package:joga_contra/models/notificacao.dart';
import 'package:joga_contra/models/partida.dart';
import 'package:joga_contra/models/solicitacao_confronto.dart';
import 'package:joga_contra/models/time.dart';
import 'package:joga_contra/models/usuario.dart';
import 'package:joga_contra/repositories/api/api_repositories.dart';
import 'package:joga_contra/repositories/contratos.dart';
import 'package:joga_contra/services/api_client.dart';
import 'package:joga_contra/services/armazenamento_sessao.dart';
import 'package:joga_contra/services/selecao_imagem.dart';

/// Repositórios reais do app contra a API rodando: prova que os modelos Dart
/// leem o JSON de verdade. Grava dados fictícios, por isso só roda com
/// `--dart-define=API_TESTE_URL=http://127.0.0.1:PORTA/api`, apontando para uma
/// API ligada a um banco descartável.
const _url = String.fromEnvironment('API_TESTE_URL');

class _Capitao {
  _Capitao(this.repos, this.sessao, this.armazenamento);
  final Repositorios repos;
  final Sessao sessao;
  final ArmazenamentoEmMemoria armazenamento;
  String get idTime => sessao.time.id;
}

Future<_Capitao> _cadastrar(String nomeTime) async {
  final armazenamento = ArmazenamentoEmMemoria();
  final repos = criarRepositoriosApi(
    ApiClient(baseUrl: _url),
    armazenamento: armazenamento,
  );
  final sessao = await repos.auth.cadastrar(
    CadastroCapitao(
      nome: 'Capitão $nomeTime',
      email:
          'teste.homologacao.flutter.${DateTime.now().microsecondsSinceEpoch}.${nomeTime.hashCode.abs()}@example.com',
      senha: 'senha-de-teste-123',
      nomeTime: nomeTime,
      cidade: 'São Paulo',
      siglaEstado: 'SP',
    ),
  );
  return _Capitao(repos, sessao, armazenamento);
}

Future<AnuncioPartida> _publicar(_Capitao c, {DateTime? quando}) async {
  final refs = await c.repos.referencias.carregar();
  return c.repos.anuncios.criar(
    RascunhoAnuncio(
      idModalidade: refs.modalidades.first.id,
      idCategoriaEtaria: refs.categoriasEtarias.last.id,
      idNivelTecnico: refs.niveisTecnicos.first.id,
      idMandoCampo: refs.mandosCampo.first.id,
      quantidadeJogadores: 7,
      dataHoraInicio: quando ?? DateTime.now().add(const Duration(days: 5)),
      duracaoMinutos: 90,
      cidade: 'São Paulo',
      siglaEstado: 'SP',
      bairro: 'Vila Mariana',
      nomeLocal: 'Campo Flutter',
      valorAluguelPorTime: 80.5,
      descricao: 'Teste de integração',
    ),
  );
}

void main() {
  group('App + API', skip: _url.isEmpty ? 'defina API_TESTE_URL' : null, () {
    test('referências chegam com as classificações oficiais', () async {
      final repos = criarRepositoriosApi(
        ApiClient(baseUrl: _url),
        armazenamento: ArmazenamentoEmMemoria(),
      );
      final refs = await repos.referencias.carregar();
      expect(refs.modalidades.map((m) => m.codigo), [
        'society',
        'futsal',
        'campo',
        'campo_reduzido',
      ]);
      expect(refs.categoriasEtarias.map((c) => c.nome), [
        'Sub-15',
        'Sub-17',
        'Sub-19',
        'Livre',
      ]);
      expect(refs.niveisTecnicos.map((n) => n.nome), [
        'Iniciante',
        'Intermediário',
        'Avançado',
      ]);
      expect(refs.estados, hasLength(27));
      expect(refs.mandosCampo, hasLength(3));
      expect(refs.criteriosAvaliacao, hasLength(4));
    });

    test('sessão é salva, restaurada e encerrada', () async {
      final c = await _cadastrar('Sessão');
      expect(c.armazenamento.token, isNotNull);
      expect(c.sessao.time.quantidadeJogadores, isNull);
      expect(c.sessao.time.categoriaEtaria, isNull);
      // Modalidade, nível e telefone não são pedidos no cadastro.
      expect(c.sessao.time.modalidades, isEmpty);
      expect(c.sessao.time.nivelTecnico, isNull);
      expect(c.sessao.usuario.telefone, isNull);

      // Simula reabrir o app com o token salvo.
      final reaberto = criarRepositoriosApi(
        ApiClient(baseUrl: _url),
        armazenamento: c.armazenamento,
      );
      final restaurada = await reaberto.auth.sessaoAtual();
      expect(restaurada?.usuario.id, c.sessao.usuario.id);
      expect(restaurada?.time.nome, 'Sessão');

      await reaberto.auth.sair();
      expect(c.armazenamento.token, isNull);
      expect(await reaberto.auth.sessaoAtual(), isNull);
    });

    test('foto e descrição persistem e aparecem para outro time', () async {
      final dono = await _cadastrar('Foto Flutter');
      final outro = await _cadastrar('Outro Flutter');
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      );

      final comFoto = await dono.repos.times.enviarEscudo(
        dono.idTime,
        SelecaoDeImagem.validar(png),
      );
      final endereco = comFoto.urlEscudo!;
      expect(endereco, startsWith('/api/arquivos/escudos/'));
      final arquivo = await http.get(Uri.parse(_url).resolve(endereco));
      expect(arquivo.statusCode, 200);
      expect(arquivo.bodyBytes, png);

      const texto = 'Time do bairro, jogo limpo.';
      await dono.repos.times.atualizar(
        dono.idTime,
        const AtualizacaoTime(descricao: texto),
      );

      // Reabrir o app com o token salvo traz foto e descrição do servidor.
      final reaberto = criarRepositoriosApi(
        ApiClient(baseUrl: _url),
        armazenamento: dono.armazenamento,
      );
      final sessao = (await reaberto.auth.sessaoAtual())!;
      expect(sessao.time.urlEscudo, endereco);
      expect(sessao.time.descricao, texto);

      // Outro capitão, em outra sessão, vê o mesmo.
      final visto = await outro.repos.times.buscar(dono.idTime);
      expect(visto.urlEscudo, endereco);
      expect(visto.descricao, texto);
    });

    test('acentos e horário 21:00 chegam iguais a outro capitão', () async {
      final dono = await _cadastrar('União Esportiva');
      final desafiante = await _cadastrar('Taboão da Serra FC');
      expect(dono.sessao.time.nome, 'União Esportiva');
      const frase =
          'Somos uma equipe de amigos apaixonados por futebol, união e competição saudável.';
      await dono.repos.times.atualizar(
        dono.idTime,
        const AtualizacaoTime(descricao: frase),
      );
      final refs = await dono.repos.referencias.carregar();
      final anuncio = await dono.repos.anuncios.criar(
        RascunhoAnuncio(
          idModalidade: refs.modalidades.last.id,
          idNivelTecnico: refs.niveisTecnicos.first.id,
          dataHoraInicio: DateTime(2026, 11, 26, 21),
          duracaoMinutos: 60,
          cidade: 'Cascavel',
          siglaEstado: 'PR',
          nomeLocal: 'Arena Biase Homologação',
        ),
      );
      expect(Formatos.hora(anuncio.dataHoraInicio), '21:00');
      final visto = await desafiante.repos.anuncios.obter(anuncio.id);
      expect(Formatos.hora(visto.dataHoraInicio), '21:00');
      expect(Formatos.dataNumerica(visto.dataHoraInicio), '26/11/2026');
      expect(visto.modalidade.nome, 'Futebol de Campo Reduzido');
      final time = await desafiante.repos.times.buscar(dono.idTime);
      expect(time.nome, 'União Esportiva');
      expect(time.descricao, frase);
    });

    test('token inválido salvo é descartado', () async {
      final armazenamento = ArmazenamentoEmMemoria()..token = 'token-invalido';
      final repos = criarRepositoriosApi(
        ApiClient(baseUrl: _url),
        armazenamento: armazenamento,
      );
      expect(await repos.auth.sessaoAtual(), isNull);
      expect(armazenamento.token, isNull);
    });

    test('erro da API chega traduzido', () async {
      final repos = criarRepositoriosApi(
        ApiClient(baseUrl: _url),
        armazenamento: ArmazenamentoEmMemoria(),
      );
      await expectLater(
        repos.auth.entrar(email: 'ninguem@example.com', senha: 'senha-errada'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isUnauthorized, 'não autorizado', isTrue)
              .having((e) => e.message, 'mensagem', contains('inválidos')),
        ),
      );
    });

    test('fluxo de anúncio até a partida confirmada', () async {
      final dono = await _cadastrar('Dono Flutter');
      final escolhido = await _cadastrar('Escolhido Flutter');
      final outro = await _cadastrar('Outro Flutter');

      final anuncio = await _publicar(dono);
      expect(anuncio.status, StatusAnuncio.ativo);
      expect(anuncio.valorAluguelPorTime, 80.5);
      expect(anuncio.mandoCampo?.codigo, 'casa');
      expect(anuncio.dataHoraInicio.isAfter(DateTime.now()), isTrue);
      expect(anuncio.time.siglaExibicao, isNotEmpty);

      final busca = await escolhido.repos.anuncios.buscar(
        const FiltroAnuncios(cidade: 'São', texto: 'Campo Flutter'),
      );
      expect(busca.map((a) => a.id), contains(anuncio.id));
      final porData = await escolhido.repos.anuncios.buscar(
        FiltroAnuncios(data: anuncio.dataHoraInicio, texto: 'Campo Flutter'),
      );
      expect(porData.map((a) => a.id), contains(anuncio.id));
      expect(
        (await dono.repos.anuncios.buscar(
          const FiltroAnuncios(),
        )).map((a) => a.time.id),
        isNot(contains(dono.idTime)),
      );

      final s1 = await escolhido.repos.solicitacoes.solicitar(anuncio.id);
      final s2 = await outro.repos.solicitacoes.solicitar(anuncio.id);
      expect(s1.status, StatusSolicitacao.pendente);
      expect(s1.adversario(escolhido.idTime).id, dono.idTime);

      // Antes do aceite não há chat: a API recusa ler e enviar.
      expect(s1.chatLiberado, isFalse);
      await expectLater(
        escolhido.repos.solicitacoes.enviarMensagem(s1.id, 'Bora jogar?'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );
      await expectLater(
        dono.repos.solicitacoes.mensagens(s1.id),
        throwsA(isA<ApiException>()),
      );

      final meus = await dono.repos.anuncios.listarDoMeuTime();
      expect(meus.single.totalSolicitacoes, 2);

      // Só o dono aceita; o aceite confirma a partida e libera o chat.
      await expectLater(
        escolhido.repos.solicitacoes.confirmar(s1.id),
        throwsA(isA<ApiException>()),
      );
      final aceita = await dono.repos.solicitacoes.confirmar(s1.id);
      expect(aceita.status, StatusSolicitacao.confirmada);
      expect(aceita.chatLiberado, isTrue);
      expect(aceita.idPartida, isNotNull);

      final mensagem = await escolhido.repos.solicitacoes.enviarMensagem(
        s1.id,
        'Bora jogar?',
      );
      expect(mensagem.idTimeRemetente, escolhido.idTime);
      final conversas = await dono.repos.solicitacoes.listarDoMeuTime();
      final conversa = conversas.firstWhere((s) => s.id == s1.id);
      expect(conversa.ultimaMensagem, 'Bora jogar?');
      expect(conversa.mensagensNaoLidas, 1);
      expect(await dono.repos.solicitacoes.mensagens(s1.id), hasLength(1));
      final lado2 = aceita;

      final partida = await dono.repos.partidas.obter(lado2.idPartida!);
      expect(partida.status, StatusPartida.confirmada);
      expect(partida.adversarioDe(dono.idTime).id, escolhido.idTime);
      expect(partida.placarPara(dono.idTime), '– × –');
      expect(
        (await escolhido.repos.partidas.proximaDoMeuTime())?.id,
        partida.id,
      );
      expect(await escolhido.repos.partidas.listarDoMeuTime(), hasLength(1));

      expect(
        (await outro.repos.solicitacoes.obter(s2.id)).status,
        StatusSolicitacao.encerrada,
      );
      final avisos = await outro.repos.notificacoes.listar();
      final aviso = avisos.itens.firstWhere(
        (n) => n.tipo == TipoNotificacao.solicitacaoEncerrada,
      );
      expect(aviso.idSolicitacao, s2.id);
      await outro.repos.notificacoes.marcarComoLida(aviso.id);
      expect(
        (await outro.repos.notificacoes.listar()).itens
            .firstWhere((n) => n.id == aviso.id)
            .lida,
        isTrue,
      );

      await expectLater(
        outro.repos.solicitacoes.solicitar(anuncio.id),
        throwsA(isA<ApiException>()),
      );

      final cancelada = await escolhido.repos.partidas.cancelar(partida.id);
      expect(cancelada.status, StatusPartida.cancelada);
    });

    test('chat: enviada, entregue e visualizada chegam ao app', () async {
      final dono = await _cadastrar('Dono Chat');
      final desafiante = await _cadastrar('Desafiante Chat');
      final anuncio = await _publicar(dono);
      final s = await desafiante.repos.solicitacoes.solicitar(anuncio.id);
      await dono.repos.solicitacoes.confirmar(s.id);

      final enviada = await desafiante.repos.solicitacoes.enviarMensagem(
        s.id,
        'Levamos as bolas.',
      );
      expect(enviada.status, StatusMensagem.enviada);
      // Quem enviou sincroniza: a própria mensagem não muda de estado.
      expect(
        (await desafiante.repos.solicitacoes.sincronizar()).mensagensNaoLidas,
        0,
      );
      var vistas = await desafiante.repos.solicitacoes.mensagens(s.id);
      expect(vistas.single.status, StatusMensagem.enviada);

      // O app do dono sincroniza (sem abrir a conversa): entregue.
      expect(
        (await dono.repos.solicitacoes.sincronizar()).mensagensNaoLidas,
        1,
      );
      vistas = await desafiante.repos.solicitacoes.mensagens(s.id);
      expect(vistas.single.status, StatusMensagem.entregue);
      expect(vistas.single.dataLeitura, isNull);

      // O dono abre a conversa: visualizada.
      await dono.repos.solicitacoes.mensagens(s.id);
      expect(
        (await dono.repos.solicitacoes.sincronizar()).mensagensNaoLidas,
        0,
      );
      vistas = await desafiante.repos.solicitacoes.mensagens(s.id);
      expect(vistas.single.status, StatusMensagem.visualizada);
      expect(vistas.single.dataLeitura, isNotNull);
    });

    test(
      'aceite encerra os outros pedidos do desafiante no mesmo horário',
      () async {
        final joga = await _cadastrar('JOGA Horário');
        final donoA = await _cadastrar('Dono A Horário');
        final donoB = await _cadastrar('Dono B Horário');
        final quando = DateTime.now().add(const Duration(days: 8));
        final as21 = DateTime(quando.year, quando.month, quando.day, 21);
        final pedidoA = await joga.repos.solicitacoes.solicitar(
          (await _publicar(donoA, quando: as21)).id,
        );
        final pedidoB = await joga.repos.solicitacoes.solicitar(
          (await _publicar(donoB, quando: as21)).id,
        );

        await donoA.repos.solicitacoes.confirmar(pedidoA.id);

        final meus = await joga.repos.solicitacoes.listarDoMeuTime(
          papel: PapelSolicitacao.solicitante,
        );
        final b = meus.singleWhere((s) => s.id == pedidoB.id);
        expect(b.status, StatusSolicitacao.encerrada);
        expect(b.motivoEncerramento, contains('neste dia e horário'));
        expect(b.chatLiberado, isFalse);
        expect(
          meus.singleWhere((s) => s.id == pedidoA.id).status,
          StatusSolicitacao.confirmada,
        );
        // Aceitar o encerrado: a API recusa e nada muda.
        await expectLater(
          donoB.repos.solicitacoes.confirmar(pedidoB.id),
          throwsA(isA<ApiException>()),
        );
        expect(
          (await donoB.repos.solicitacoes.obter(pedidoB.id)).status,
          StatusSolicitacao.encerrada,
        );
        // A sincronização devolve a versão que faz o app recarregar as listas.
        expect(
          (await joga.repos.solicitacoes.sincronizar()).versao,
          isNotEmpty,
        );
      },
    );

    test('Meus Desafios só traz os pedidos feitos pelo meu time', () async {
      final a = await _cadastrar('Anunciante Filtro');
      final b = await _cadastrar('Desafiante Filtro');
      final anuncioA = await _publicar(a);
      final anuncioB = await _publicar(b);
      final deB = await b.repos.solicitacoes.solicitar(anuncioA.id);
      final deA = await a.repos.solicitacoes.solicitar(anuncioB.id);

      final desafiosDeB = await b.repos.solicitacoes.listarDoMeuTime(
        papel: PapelSolicitacao.solicitante,
      );
      expect(desafiosDeB.map((s) => s.id), [deB.id]);
      expect(desafiosDeB.single.anuncio.id, anuncioA.id);
      final recebidasDeB = await b.repos.solicitacoes.listarDoMeuTime(
        papel: PapelSolicitacao.anunciante,
      );
      expect(recebidasDeB.map((s) => s.id), [deA.id]);
      // Sem papel: as duas (lista de conversas).
      expect(await b.repos.solicitacoes.listarDoMeuTime(), hasLength(2));
      // Meus Anúncios: só o anúncio do próprio time.
      final meus = await b.repos.anuncios.listarDoMeuTime();
      expect(meus.map((x) => x.id), [anuncioB.id]);
    });

    test('editar, pausar, excluir e atualizar perfil', () async {
      final c = await _cadastrar('Editor Flutter');
      final anuncio = await _publicar(c);
      final pausado = await c.repos.anuncios.alterarStatus(
        anuncio.id,
        StatusAnuncio.pausado,
      );
      expect(pausado.status, StatusAnuncio.pausado);
      await c.repos.anuncios.excluir(anuncio.id);
      expect(await c.repos.anuncios.listarDoMeuTime(), isEmpty);
      final perfil = await c.repos.times.buscar(c.idTime);
      expect(perfil.totalPartidasRealizadas, 0);
      expect(perfil.mediaAvaliacao, isNull);
      expect(await c.repos.partidas.avaliacoesDoTime(c.idTime), isEmpty);
    });

    test(
      'central de notificações: contador, páginas, leitura e isolamento',
      () async {
        final dono = await _cadastrar('Dono Avisos');
        final anuncio = await _publicar(dono);
        final visitantes = [
          for (final nome in ['Visita A', 'Visita B', 'Visita C'])
            await _cadastrar(nome),
        ];
        for (final v in visitantes) {
          await v.repos.solicitacoes.solicitar(anuncio.id);
        }
        final avisos = dono.repos.notificacoes;
        expect(await avisos.resumo(), (naoLidas: 3, total: 3));

        final p1 = await avisos.listar(limite: 2);
        final p2 = await avisos.listar(pagina: 2, limite: 2);
        expect([p1.itens.length, p2.itens.length], [2, 1]);
        expect([p1.temMais, p2.temMais], [true, false]);
        expect((p1.total, p1.naoLidas), (3, 3));
        final todos = [...p1.itens, ...p2.itens];
        expect(todos.map((n) => n.id).toSet(), hasLength(3));
        expect(
          todos.every((n) => n.tipo == TipoNotificacao.solicitacaoRecebida),
          isTrue,
        );
        expect(
          todos.first.dataCriacao.isAfter(todos.last.dataCriacao) ||
              todos.first.dataCriacao == todos.last.dataCriacao,
          isTrue,
        );

        // Marcar duas vezes não é erro.
        await avisos.marcarComoLida(todos.first.id);
        await avisos.marcarComoLida(todos.first.id);
        expect((await avisos.resumo()).naoLidas, 2);

        // Outro capitão não marca (nem enxerga) as do dono.
        await expectLater(
          visitantes.first.repos.notificacoes.marcarComoLida(todos[1].id),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 404),
          ),
        );
        // O visitante só tem o próprio registro de envio (já lido).
        final doVisitante =
            (await visitantes.first.repos.notificacoes.listar()).itens;
        expect(doVisitante.map((n) => n.tipo), [
          TipoNotificacao.solicitacaoEnviada,
        ]);
        expect(doVisitante.single.lida, isTrue);
        expect(
          (await visitantes.first.repos.notificacoes.resumo()).naoLidas,
          0,
        );
        expect((await avisos.resumo()).naoLidas, 2);

        expect(await avisos.marcarTodasComoLidas(), 2);
        expect(await avisos.marcarTodasComoLidas(), 0);
        expect(await avisos.resumo(), (naoLidas: 0, total: 3));
        expect((await avisos.listar()).itens.every((n) => n.lida), isTrue);
      },
    );

    test(
      'chat: envio repetido com o mesmo id e presença na conversa',
      () async {
        final dono = await _cadastrar('Dono Chat F4');
        final visitante = await _cadastrar('Visita Chat F4');
        final anuncio = await _publicar(dono);
        final pedido = await visitante.repos.solicitacoes.solicitar(anuncio.id);
        await dono.repos.solicitacoes.confirmar(pedido.id);

        final id =
            novoUuid(); // novo a cada execução (o banco guarda as anteriores)
        final a = await visitante.repos.solicitacoes.enviarMensagem(
          pedido.id,
          'Levamos a bola',
          idMensagem: id,
        );
        final b = await visitante.repos.solicitacoes.enviarMensagem(
          pedido.id,
          'Levamos a bola',
          idMensagem: id,
        );
        expect([a.id, b.id], [id, id]);
        expect(
          await dono.repos.solicitacoes.mensagens(pedido.id),
          hasLength(1),
        );
        await dono.repos.solicitacoes.marcarPresenca(pedido.id, aberta: false);

        final avisos = (await dono.repos.notificacoes.listar()).itens.where(
          (n) => n.tipo == TipoNotificacao.mensagemRecebida,
        );
        expect(avisos.map((n) => n.titulo), ['Nova mensagem']);
        expect(avisos.single.mensagem, contains('Visita Chat F4'));
        expect(avisos.single.mensagem, isNot(contains('bola')));
      },
    );

    test(
      'preferências de notificação: padrão, salvar e efeito no chat',
      () async {
        final dono = await _cadastrar('Dono Prefs F5');
        final visitante = await _cadastrar('Visita Prefs F5');
        final repo = dono.repos.notificacoes;
        final padrao = await repo.preferencias();
        expect(
          [padrao.desafios, padrao.jogos, padrao.chat, padrao.lembretes],
          [true, true, true, true],
        );
        final salvas = await repo.salvarPreferencias(
          padrao.copiar(chat: false),
        );
        expect(salvas.chat, isFalse);
        expect((await repo.preferencias()).chat, isFalse);

        final anuncio = await _publicar(dono);
        final pedido = await visitante.repos.solicitacoes.solicitar(anuncio.id);
        await dono.repos.solicitacoes.confirmar(pedido.id);
        await visitante.repos.solicitacoes.enviarMensagem(pedido.id, 'Oi');
        final mensagem = (await repo.listar()).itens.firstWhere(
          (n) => n.tipo == TipoNotificacao.mensagemRecebida,
        );
        expect(mensagem.lida, isTrue); // chat desativado: no histórico, já lida
      },
    );
  });
}
