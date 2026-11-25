import '../models/anuncio_partida.dart';
import '../models/local_esportivo.dart';
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

  /// Pede o e-mail com o link de redefinição. A resposta é a mesma para
  /// qualquer e-mail (não revela se a conta existe).
  Future<void> solicitarRecuperacaoSenha(String email);

  /// Troca a senha com o token do link. Falhas do link chegam como
  /// `ApiException` com código TOKEN_INVALIDO, TOKEN_EXPIRADO,
  /// TOKEN_UTILIZADO ou TOKEN_SUBSTITUIDO.
  Future<void> redefinirSenha({
    required String token,
    required String novaSenha,
    required String confirmacaoSenha,
  });
  Future<void> sair();
}

abstract interface class ReferenciaRepository {
  Future<Referencias> carregar();
}

abstract interface class TimeRepository {
  Future<Time> buscar(String idTime);
  Future<Time> atualizar(String idTime, AtualizacaoTime dados);

  /// Troca a foto (escudo) do time; a anterior só sai se o envio der certo.
  Future<Time> enviarEscudo(String idTime, ImagemSelecionada imagem);
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
  /// Enviadas e recebidas pelo meu time; [papel] filtra na API ("Meus
  /// desafios" = solicitante).
  Future<List<SolicitacaoConfronto>> listarDoMeuTime({PapelSolicitacao? papel});

  /// Sincronização leve: registra a entrega das mensagens recebidas e devolve
  /// quantas ainda não foram lidas, com a versão das solicitações e partidas.
  Future<Sincronizacao> sincronizar();
  Future<SolicitacaoConfronto> obter(String idSolicitacao);
  Future<SolicitacaoConfronto> solicitar(String idAnuncio, {String? mensagem});

  /// Registra a concordância do meu time. Quando os dois lados confirmam, a
  /// API cria a partida, encerra o anúncio e as demais solicitações dele e
  /// notifica os capitães afetados. O retorno traz `idPartida` nesse caso.
  Future<SolicitacaoConfronto> confirmar(String idSolicitacao);
  Future<SolicitacaoConfronto> recusar(String idSolicitacao);
  Future<SolicitacaoConfronto> cancelar(String idSolicitacao);

  /// Consultar as mensagens também marca a conversa como aberta na API (as
  /// mensagens novas não geram push enquanto ela está na tela).
  Future<List<Mensagem>> mensagens(String idSolicitacao);

  /// `idMensagem` (gerado no aparelho) torna o envio repetível: tentar de
  /// novo após uma falha de conexão não duplica a mensagem.
  Future<Mensagem> enviarMensagem(
    String idSolicitacao,
    String texto, {
    String? idMensagem,
  });

  /// A conversa saiu da tela (outra tela ou app em segundo plano): as
  /// mensagens novas voltam a gerar push.
  Future<void> marcarPresenca(String idSolicitacao, {required bool aberta});
}

abstract interface class PartidaRepository {
  Future<List<Partida>> listarDoMeuTime();
  Future<Partida?> proximaDoMeuTime();
  Future<Partida> obter(String idPartida);
  Future<Partida> cancelar(String idPartida, {String? motivo});
  Future<void> avaliar(NovaAvaliacao avaliacao);
  Future<List<AvaliacaoRecebida>> avaliacoesDoTime(String idTime);
}

/// Central de notificações do capitão logado (a API identifica a conta
/// pelo token; o app nunca informa de quem são as notificações).
abstract interface class NotificacaoRepository {
  /// Mais recentes primeiro.
  Future<PaginaNotificacoes> listar({int pagina = 1, int limite = 20});

  /// Contador do sino. `total` só aumenta quando chega notificação nova.
  Future<({int naoLidas, int total})> resumo();

  /// Marcar de novo uma já lida não é erro.
  Future<void> marcarComoLida(String idNotificacao);

  /// Devolve quantas estavam não lidas.
  Future<int> marcarTodasComoLidas();

  Future<PreferenciasNotificacoes> preferencias();
  Future<PreferenciasNotificacoes> salvarPreferencias(
    PreferenciasNotificacoes preferencias,
  );
}

/// Agrupa os repositórios para injeção nas telas.
/// Locais esportivos reais de uma cidade, para sugerir no anúncio.
abstract interface class LocalRepository {
  Future<LocaisDaCidade> daCidade(String siglaEstado, String cidade);
}

/// Aparelho que recebe notificações push. A API associa o token à conta da
/// sessão; o app nunca informa de quem é o aparelho.
abstract interface class DispositivoRepository {
  /// Registra ou renova (idempotente). `tokenAnterior`: token que este
  /// aparelho usava antes da renovação pelo Firebase.
  Future<void> registrar({
    required String token,
    required String plataforma,
    required bool permitido,
    String? tokenAnterior,
  });

  /// Sair da conta neste aparelho: para de receber push desta conta.
  Future<void> desativar(String token);
}

/// Sem push (demonstração e testes): não faz nada.
class DispositivosDesligados implements DispositivoRepository {
  const DispositivosDesligados();
  @override
  Future<void> registrar({
    required String token,
    required String plataforma,
    required bool permitido,
    String? tokenAnterior,
  }) async {}
  @override
  Future<void> desativar(String token) async {}
}

class Repositorios {
  const Repositorios({
    required this.auth,
    required this.referencias,
    required this.times,
    required this.anuncios,
    required this.solicitacoes,
    required this.partidas,
    required this.notificacoes,
    required this.locais,
    this.dispositivos = const DispositivosDesligados(),
  });
  final AuthRepository auth;
  final ReferenciaRepository referencias;
  final TimeRepository times;
  final AnuncioRepository anuncios;
  final SolicitacaoRepository solicitacoes;
  final PartidaRepository partidas;
  final NotificacaoRepository notificacoes;
  final LocalRepository locais;
  final DispositivoRepository dispositivos;
}
