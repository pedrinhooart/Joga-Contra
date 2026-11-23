import 'anuncio_partida.dart';
import 'referencia.dart';
import 'time.dart';

enum StatusSolicitacao {
  /// Enviada; aguardando o aceite do time anunciante (sem chat ainda).
  pendente('pendente', 'Aguardando aceite'),

  /// O time anunciante aceitou: a partida foi criada e o chat liberado.
  confirmada('confirmada', 'Confirmada'),
  recusada('recusada', 'Recusada'),
  cancelada('cancelada', 'Cancelada'),

  /// Encerrada automaticamente porque o anúncio confirmou outra partida.
  encerrada('encerrada', 'Encerrada');

  const StatusSolicitacao(this.codigo, this.rotulo);
  final String codigo, rotulo;

  bool get emAberto => this == pendente;

  static StatusSolicitacao deCodigo(String? c) =>
      values.firstWhere((s) => s.codigo == c, orElse: () => pendente);
}

/// Pedido de confronto de um time a um anúncio. Um anúncio recebe várias.
class SolicitacaoConfronto {
  const SolicitacaoConfronto({
    required this.id,
    required this.anuncio,
    required this.timeSolicitante,
    required this.timeAnunciante,
    required this.status,
    required this.dataSolicitacao,
    this.mensagemInicial,
    this.dataResposta,
    this.confirmadoAnunciante = false,
    this.confirmadoSolicitante = false,
    this.idPartida,
    this.ultimaMensagem,
    this.dataUltimaMensagem,
    this.mensagensNaoLidas = 0,
    this.chatLiberado = false,
  });

  final String id;
  final AnuncioPartida anuncio;
  final ResumoTime timeSolicitante, timeAnunciante;
  final StatusSolicitacao status;
  final DateTime dataSolicitacao;
  final String? mensagemInicial;
  final DateTime? dataResposta;

  /// O pedido é a concordância do desafiante; o aceite do anunciante confirma.
  final bool confirmadoAnunciante, confirmadoSolicitante;
  final String? idPartida;

  final String? ultimaMensagem;
  final DateTime? dataUltimaMensagem;
  final int mensagensNaoLidas;

  /// O chat só existe depois que o time anunciante aceita (a API valida).
  final bool chatLiberado;

  /// Pendente: aguardando o aceite do time anunciante.
  bool get aguardandoAceite => status == StatusSolicitacao.pendente;

  bool souAnunciante(String idMeuTime) => timeAnunciante.id == idMeuTime;
  ResumoTime adversario(String idMeuTime) =>
      souAnunciante(idMeuTime) ? timeSolicitante : timeAnunciante;
  bool euConfirmei(String idMeuTime) =>
      souAnunciante(idMeuTime) ? confirmadoAnunciante : confirmadoSolicitante;

  factory SolicitacaoConfronto.fromJson(Map<String, dynamic> json) =>
      SolicitacaoConfronto(
        id: json['idSolicitacao'] as String,
        anuncio: AnuncioPartida.fromJson(
          json['anuncio'] as Map<String, dynamic>,
        ),
        timeSolicitante: ResumoTime.fromJson(
          json['timeSolicitante'] as Map<String, dynamic>,
        ),
        timeAnunciante: ResumoTime.fromJson(
          json['timeAnunciante'] as Map<String, dynamic>,
        ),
        status: StatusSolicitacao.deCodigo(json['status'] as String?),
        dataSolicitacao: DateTime.parse(
          json['dataSolicitacao'] as String,
        ).toLocal(),
        mensagemInicial: json['mensagemInicial'] as String?,
        dataResposta: json['dataResposta'] == null
            ? null
            : DateTime.parse(json['dataResposta'] as String).toLocal(),
        confirmadoAnunciante: json['confirmadoAnunciante'] as bool? ?? false,
        confirmadoSolicitante: json['confirmadoSolicitante'] as bool? ?? false,
        idPartida: json['idPartida'] as String?,
        ultimaMensagem: json['ultimaMensagem'] as String?,
        dataUltimaMensagem: json['dataUltimaMensagem'] == null
            ? null
            : DateTime.parse(json['dataUltimaMensagem'] as String).toLocal(),
        mensagensNaoLidas: (json['mensagensNaoLidas'] as num?)?.toInt() ?? 0,
        chatLiberado:
            json['chatLiberado'] as bool? ?? json['status'] == 'confirmada',
      );
}

/// Estado de uma mensagem para quem a enviou (como no WhatsApp).
enum StatusMensagem {
  /// Registrada no servidor.
  enviada('enviada', 'Enviada'),

  /// Chegou ao app do outro capitão (ele ainda não abriu a conversa).
  entregue('entregue', 'Entregue'),

  /// O outro capitão abriu a conversa.
  visualizada('visualizada', 'Visualizada');

  const StatusMensagem(this.codigo, this.rotulo);
  final String codigo, rotulo;

  static StatusMensagem deCodigo(String? c) =>
      values.firstWhere((s) => s.codigo == c, orElse: () => enviada);
}

/// Mensagem trocada entre os capitães dentro de uma solicitação.
class Mensagem {
  const Mensagem({
    required this.id,
    required this.idSolicitacao,
    required this.idTimeRemetente,
    required this.texto,
    required this.dataEnvio,
    this.dataEntrega,
    this.dataLeitura,
    this.status = StatusMensagem.enviada,
  });
  final String id, idSolicitacao, idTimeRemetente, texto;
  final DateTime dataEnvio;
  final DateTime? dataEntrega, dataLeitura;

  /// Calculado e persistido pela API (datas de entrega e de leitura).
  final StatusMensagem status;

  factory Mensagem.fromJson(Map<String, dynamic> json) => Mensagem(
    id: json['idMensagem'] as String,
    idSolicitacao: json['idSolicitacao'] as String,
    idTimeRemetente: json['idTimeRemetente'] as String,
    texto: json['texto'] as String,
    dataEnvio: DateTime.parse(json['dataEnvio'] as String).toLocal(),
    dataEntrega: dataOuNula(json['dataEntrega']),
    dataLeitura: dataOuNula(json['dataLeitura']),
    status: StatusMensagem.deCodigo(json['status'] as String?),
  );
}

/// Papel do meu time numa solicitação: dono do anúncio ou desafiante.
enum PapelSolicitacao { anunciante, solicitante }
