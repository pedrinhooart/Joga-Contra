import 'package:flutter_test/flutter_test.dart';
import 'package:joga_contra/models/anuncio_partida.dart';
import 'package:joga_contra/models/notificacao.dart';
import 'package:joga_contra/models/partida.dart';
import 'package:joga_contra/models/solicitacao_confronto.dart';
import 'package:joga_contra/models/usuario.dart';
import 'package:joga_contra/repositories/api/api_repositories.dart';
import 'package:joga_contra/repositories/contratos.dart';
import 'package:joga_contra/services/api_client.dart';
import 'package:joga_contra/services/armazenamento_sessao.dart';

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
  final refs = await repos.referencias.carregar();
  final sessao = await repos.auth.cadastrar(
    CadastroCapitao(
      nome: 'Capitão $nomeTime',
      email:
          'teste.homologacao.flutter.${DateTime.now().microsecondsSinceEpoch}.${nomeTime.hashCode.abs()}@example.com',
      senha: 'senha-de-teste-123',
      telefone: '(11) 90000-0000',
      nomeTime: nomeTime,
      idModalidade: refs.modalidades.first.id,
      idCategoriaEtaria: refs.categoriasEtarias.last.id,
      idNivelTecnico: refs.niveisTecnicos[1].id,
      quantidadeJogadores: 14,
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
      expect(refs.modalidades.map((m) => m.codigo), ['society', 'quadra']);
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
      expect(c.sessao.time.quantidadeJogadores, 14);
      expect(c.sessao.time.modalidades.single.codigo, 'society');

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

      final meus = await dono.repos.anuncios.listarDoMeuTime();
      expect(meus.single.totalSolicitacoes, 2);

      final lado1 = await dono.repos.solicitacoes.confirmar(s1.id);
      expect(lado1.euConfirmei(dono.idTime), isTrue);
      expect(lado1.idPartida, isNull);
      final lado2 = await escolhido.repos.solicitacoes.confirmar(s1.id);
      expect(lado2.status, StatusSolicitacao.confirmada);
      expect(lado2.idPartida, isNotNull);

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
      final aviso = avisos.firstWhere(
        (n) => n.tipo == TipoNotificacao.solicitacaoEncerrada,
      );
      expect(aviso.idSolicitacao, s2.id);
      await outro.repos.notificacoes.marcarComoLida(aviso.id);
      expect(
        (await outro.repos.notificacoes.listar())
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
  });
}
