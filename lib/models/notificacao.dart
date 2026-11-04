enum TipoNotificacao {
  solicitacaoRecebida('solicitacao_recebida'),
  mensagemRecebida('mensagem_recebida'),
  partidaConfirmada('partida_confirmada'),
  partidaCancelada('partida_cancelada'),

  /// Enviada aos capitães cujas solicitações foram encerradas porque o
  /// anúncio confirmou partida com outro time.
  solicitacaoEncerrada('solicitacao_encerrada'),
  solicitacaoRecusada('solicitacao_recusada'),
  anuncioExpirando('anuncio_expirando'),
  avaliacaoPendente('avaliacao_pendente');

  const TipoNotificacao(this.codigo);
  final String codigo;

  static TipoNotificacao deCodigo(String? c) =>
      values.firstWhere((s) => s.codigo == c, orElse: () => mensagemRecebida);
}

class Notificacao {
  const Notificacao({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensagem,
    required this.dataCriacao,
    this.lida = false,
    this.idAnuncio,
    this.idSolicitacao,
    this.idPartida,
  });

  final String id;
  final TipoNotificacao tipo;
  final String titulo, mensagem;
  final DateTime dataCriacao;
  final bool lida;
  final String? idAnuncio, idSolicitacao, idPartida;

  factory Notificacao.fromJson(Map<String, dynamic> json) => Notificacao(
    id: json['idNotificacao'] as String,
    tipo: TipoNotificacao.deCodigo(json['tipo'] as String?),
    titulo: json['titulo'] as String,
    mensagem: json['mensagem'] as String,
    dataCriacao: DateTime.parse(json['dataCriacao'] as String).toLocal(),
    lida: json['lida'] as bool? ?? false,
    idAnuncio: json['idAnuncio'] as String?,
    idSolicitacao: json['idSolicitacao'] as String?,
    idPartida: json['idPartida'] as String?,
  );
}
