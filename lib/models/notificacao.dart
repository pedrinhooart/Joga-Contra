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
  avaliacaoPendente('avaliacao_pendente'),

  /// Aviso geral do Joga Contra (também usado na notificação de teste).
  aviso('aviso'),

  /// Registro para o time que enviou um desafio (chega já lido).
  solicitacaoEnviada('solicitacao_enviada'),

  /// Lembrete de jogo (24 h, 2 h e 30 min antes).
  lembretePartida('lembrete_partida');

  const TipoNotificacao(this.codigo);
  final String codigo;

  static TipoNotificacao deCodigo(String? c) =>
      values.firstWhere((s) => s.codigo == c, orElse: () => aviso);
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

  /// A mesma notificação, marcada como lida.
  Notificacao comoLida() => Notificacao(
    id: id,
    tipo: tipo,
    titulo: titulo,
    mensagem: mensagem,
    dataCriacao: dataCriacao,
    lida: true,
    idAnuncio: idAnuncio,
    idSolicitacao: idSolicitacao,
    idPartida: idPartida,
  );

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

/// Uma página da central de notificações.
class PaginaNotificacoes {
  const PaginaNotificacoes({
    required this.itens,
    required this.temMais,
    required this.total,
    required this.naoLidas,
  });

  final List<Notificacao> itens;

  /// Há notificações mais antigas na próxima página.
  final bool temMais;
  final int total, naoLidas;
}

/// Categorias que o capitão quer receber. Desativada: a notificação continua no
/// histórico, mas chega já lida (sem contar no sino e sem push).
class PreferenciasNotificacoes {
  const PreferenciasNotificacoes({
    this.desafios = true,
    this.jogos = true,
    this.chat = true,
    this.lembretes = true,
  });

  final bool desafios, jogos, chat, lembretes;

  factory PreferenciasNotificacoes.fromJson(Map<String, dynamic> json) =>
      PreferenciasNotificacoes(
        desafios: json['desafios'] as bool? ?? true,
        jogos: json['jogos'] as bool? ?? true,
        chat: json['chat'] as bool? ?? true,
        lembretes: json['lembretes'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
    'desafios': desafios,
    'jogos': jogos,
    'chat': chat,
    'lembretes': lembretes,
  };

  PreferenciasNotificacoes copiar({
    bool? desafios,
    bool? jogos,
    bool? chat,
    bool? lembretes,
  }) => PreferenciasNotificacoes(
    desafios: desafios ?? this.desafios,
    jogos: jogos ?? this.jogos,
    chat: chat ?? this.chat,
    lembretes: lembretes ?? this.lembretes,
  );
}
