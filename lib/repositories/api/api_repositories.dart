import '../../models/anuncio_partida.dart';
import '../../models/notificacao.dart';
import '../../models/partida.dart';
import '../../models/referencia.dart';
import '../../models/solicitacao_confronto.dart';
import '../../models/time.dart';
import '../../models/usuario.dart';
import '../../services/api_client.dart';
import '../contratos.dart';

/// Implementações que consomem a API REST. Os caminhos abaixo são o contrato
/// planejado para a etapa do novo banco (ver docs/AUDITORIA_DADOS_DINAMICOS.md,
/// seção "Contrato da API"). A API Express atual ainda usa caminhos em inglês e
/// o schema antigo, então estes repositórios só funcionarão após essa etapa.

typedef _Json = Map<String, dynamic>;

List<T> _lista<T>(Object? data, T Function(_Json) parse) =>
    ((data as List?) ?? const []).map((e) => parse(e as _Json)).toList();

Repositorios criarRepositoriosApi(ApiClient api) => Repositorios(
  auth: ApiAuthRepository(api),
  referencias: ApiReferenciaRepository(api),
  times: ApiTimeRepository(api),
  anuncios: ApiAnuncioRepository(api),
  solicitacoes: ApiSolicitacaoRepository(api),
  partidas: ApiPartidaRepository(api),
  notificacoes: ApiNotificacaoRepository(api),
);

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api);
  final ApiClient _api;

  Sessao _sessao(Object? data) {
    final json = data as _Json;
    final token = json['token'] as String?;
    if (token != null) _api.setToken(token);
    return Sessao(
      usuario: Usuario.fromJson(json['usuario'] as _Json),
      time: Time.fromJson(json['time'] as _Json),
      token: token,
    );
  }

  @override
  Future<Sessao?> sessaoAtual() async {
    // Sem armazenamento seguro de token ainda (decisão pendente:
    // flutter_secure_storage). Sem token, o usuário precisa entrar.
    if (!_api.hasToken) return null;
    try {
      return _sessao(await _api.get('/auth/eu'));
    } on ApiException catch (e) {
      if (e.isUnauthorized) return null;
      rethrow;
    }
  }

  @override
  Future<Sessao> entrar({required String email, required String senha}) async =>
      _sessao(await _api.post('/auth/login', {'email': email, 'senha': senha}));

  @override
  Future<Sessao> cadastrar(CadastroCapitao dados) async =>
      _sessao(await _api.post('/auth/cadastro', dados.toJson()));

  @override
  Future<void> solicitarRecuperacaoSenha(String email) =>
      _api.post('/auth/recuperar-senha', {'email': email});

  @override
  Future<void> sair() async => _api.setToken(null);
}

class ApiReferenciaRepository implements ReferenciaRepository {
  ApiReferenciaRepository(this._api);
  final ApiClient _api;
  @override
  Future<Referencias> carregar() async =>
      Referencias.fromJson(await _api.get('/referencias') as _Json);
}

class ApiTimeRepository implements TimeRepository {
  ApiTimeRepository(this._api);
  final ApiClient _api;
  @override
  Future<Time> buscar(String idTime) async =>
      Time.fromJson(await _api.get('/times/$idTime') as _Json);
  @override
  Future<Time> atualizar(String idTime, AtualizacaoTime dados) async =>
      Time.fromJson(
        await _api.patch('/times/$idTime', dados.toJson()) as _Json,
      );
}

class ApiAnuncioRepository implements AnuncioRepository {
  ApiAnuncioRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<AnuncioPartida>> buscar(FiltroAnuncios filtro) async => _lista(
    await _api.get('/anuncios', query: filtro.toQuery()),
    AnuncioPartida.fromJson,
  );
  @override
  Future<AnuncioPartida> obter(String idAnuncio) async =>
      AnuncioPartida.fromJson(await _api.get('/anuncios/$idAnuncio') as _Json);
  @override
  Future<List<AnuncioPartida>> listarDoMeuTime() async =>
      _lista(await _api.get('/anuncios/meus'), AnuncioPartida.fromJson);
  @override
  Future<AnuncioPartida> criar(RascunhoAnuncio dados) async =>
      AnuncioPartida.fromJson(
        await _api.post('/anuncios', dados.toJson()) as _Json,
      );
  @override
  Future<AnuncioPartida> atualizar(
    String idAnuncio,
    RascunhoAnuncio dados,
  ) async => AnuncioPartida.fromJson(
    await _api.put('/anuncios/$idAnuncio', dados.toJson()) as _Json,
  );
  @override
  Future<AnuncioPartida> alterarStatus(
    String idAnuncio,
    StatusAnuncio status,
  ) async => AnuncioPartida.fromJson(
    await _api.patch('/anuncios/$idAnuncio/status', {'status': status.codigo})
        as _Json,
  );
  @override
  Future<void> excluir(String idAnuncio) => _api.delete('/anuncios/$idAnuncio');
}

class ApiSolicitacaoRepository implements SolicitacaoRepository {
  ApiSolicitacaoRepository(this._api);
  final ApiClient _api;
  SolicitacaoConfronto _s(Object? d) =>
      SolicitacaoConfronto.fromJson(d as _Json);

  @override
  Future<List<SolicitacaoConfronto>> listarDoMeuTime() async => _lista(
    await _api.get('/solicitacoes/minhas'),
    SolicitacaoConfronto.fromJson,
  );
  @override
  Future<SolicitacaoConfronto> obter(String id) async =>
      _s(await _api.get('/solicitacoes/$id'));
  @override
  Future<SolicitacaoConfronto> solicitar(
    String idAnuncio, {
    String? mensagem,
  }) async => _s(
    await _api.post('/solicitacoes', {
      'idAnuncio': idAnuncio,
      'mensagemInicial': mensagem,
    }),
  );
  @override
  Future<SolicitacaoConfronto> confirmar(String id) async =>
      _s(await _api.patch('/solicitacoes/$id/confirmar'));
  @override
  Future<SolicitacaoConfronto> recusar(String id) async =>
      _s(await _api.patch('/solicitacoes/$id/recusar'));
  @override
  Future<SolicitacaoConfronto> cancelar(String id) async =>
      _s(await _api.patch('/solicitacoes/$id/cancelar'));
  @override
  Future<List<Mensagem>> mensagens(String id) async =>
      _lista(await _api.get('/solicitacoes/$id/mensagens'), Mensagem.fromJson);
  @override
  Future<Mensagem> enviarMensagem(String id, String texto) async =>
      Mensagem.fromJson(
        await _api.post('/solicitacoes/$id/mensagens', {'texto': texto})
            as _Json,
      );
}

class ApiPartidaRepository implements PartidaRepository {
  ApiPartidaRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<Partida>> listarDoMeuTime() async =>
      _lista(await _api.get('/partidas/minhas'), Partida.fromJson);
  @override
  Future<Partida?> proximaDoMeuTime() async {
    final data = await _api.get('/partidas/proxima');
    return data == null ? null : Partida.fromJson(data as _Json);
  }

  @override
  Future<Partida> obter(String id) async =>
      Partida.fromJson(await _api.get('/partidas/$id') as _Json);
  @override
  Future<Partida> cancelar(String id, {String? motivo}) async =>
      Partida.fromJson(
        await _api.patch('/partidas/$id/cancelar', {'motivo': motivo}) as _Json,
      );
  @override
  Future<void> avaliar(NovaAvaliacao a) =>
      _api.post('/partidas/${a.idPartida}/avaliacoes', a.toJson());
  @override
  Future<List<AvaliacaoRecebida>> avaliacoesDoTime(String idTime) async =>
      _lista(
        await _api.get('/times/$idTime/avaliacoes'),
        AvaliacaoRecebida.fromJson,
      );
}

class ApiNotificacaoRepository implements NotificacaoRepository {
  ApiNotificacaoRepository(this._api);
  final ApiClient _api;
  @override
  Future<List<Notificacao>> listar() async =>
      _lista(await _api.get('/notificacoes'), Notificacao.fromJson);
  @override
  Future<void> marcarComoLida(String id) =>
      _api.patch('/notificacoes/$id/lida');
}
