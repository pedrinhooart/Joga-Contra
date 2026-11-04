import '../models/anuncio_partida.dart';
import '../models/notificacao.dart';
import '../models/partida.dart';
import '../models/referencia.dart';
import '../models/solicitacao_confronto.dart';
import '../models/time.dart';
import '../models/usuario.dart';

/// Contratos de acesso a dados. As telas dependem apenas destas interfaces;
/// a implementação real (`repositories/api`) fala com a API REST e a de
/// demonstração (`repositories/demo`) guarda dados fictícios em memória.

class Sessao {
  const Sessao({required this.usuario, required this.time, this.token});
  final Usuario usuario;
  final Time time;
  final String? token;
}

abstract interface class AuthRepository {
  /// Sessão já ativa (token válido), ou null se o usuário precisa entrar.
  Future<Sessao?> sessaoAtual();
  Future<Sessao> entrar({required String email, required String senha});
  Future<Sessao> cadastrar(CadastroCapitao dados);
  Future<void> solicitarRecuperacaoSenha(String email);
  Future<void> sair();
}

abstract interface class ReferenciaRepository {
  Future<Referencias> carregar();
}

abstract interface class TimeRepository {
  Future<Time> buscar(String idTime);
  Future<Time> atualizar(String idTime, AtualizacaoTime dados);
}

abstract interface class AnuncioRepository {
  /// Anúncios ativos de outros times, para a busca.
  Future<List<AnuncioPartida>> buscar(FiltroAnuncios filtro);
  Future<AnuncioPartida> obter(String idAnuncio);
  Future<List<AnuncioPartida>> listarDoMeuTime();
  Future<AnuncioPartida> criar(RascunhoAnuncio dados);
  Future<AnuncioPartida> atualizar(String idAnuncio, RascunhoAnuncio dados);
  Future<AnuncioPartida> alterarStatus(String idAnuncio, StatusAnuncio status);
  Future<void> excluir(String idAnuncio);
}

abstract interface class SolicitacaoRepository {
  /// Enviadas e recebidas pelo meu time.
  Future<List<SolicitacaoConfronto>> listarDoMeuTime();
  Future<SolicitacaoConfronto> obter(String idSolicitacao);
  Future<SolicitacaoConfronto> solicitar(String idAnuncio, {String? mensagem});

  /// Registra a concordância do meu time. Quando os dois lados confirmam, a
  /// API cria a partida, encerra o anúncio e as demais solicitações dele e
  /// notifica os capitães afetados. O retorno traz `idPartida` nesse caso.
  Future<SolicitacaoConfronto> confirmar(String idSolicitacao);
  Future<SolicitacaoConfronto> recusar(String idSolicitacao);
  Future<SolicitacaoConfronto> cancelar(String idSolicitacao);

  Future<List<Mensagem>> mensagens(String idSolicitacao);
  Future<Mensagem> enviarMensagem(String idSolicitacao, String texto);
}

abstract interface class PartidaRepository {
  Future<List<Partida>> listarDoMeuTime();
  Future<Partida?> proximaDoMeuTime();
  Future<Partida> obter(String idPartida);
  Future<Partida> cancelar(String idPartida, {String? motivo});
  Future<void> avaliar(NovaAvaliacao avaliacao);
  Future<List<AvaliacaoRecebida>> avaliacoesDoTime(String idTime);
}

abstract interface class NotificacaoRepository {
  Future<List<Notificacao>> listar();
  Future<void> marcarComoLida(String idNotificacao);
}

/// Agrupa os repositórios para injeção nas telas.
class Repositorios {
  const Repositorios({
    required this.auth,
    required this.referencias,
    required this.times,
    required this.anuncios,
    required this.solicitacoes,
    required this.partidas,
    required this.notificacoes,
  });
  final AuthRepository auth;
  final ReferenciaRepository referencias;
  final TimeRepository times;
  final AnuncioRepository anuncios;
  final SolicitacaoRepository solicitacoes;
  final PartidaRepository partidas;
  final NotificacaoRepository notificacoes;
}
