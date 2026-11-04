import 'referencia.dart';
import 'time.dart';

enum StatusPartida {
  confirmada('confirmada', 'Confirmado'),
  realizada('realizada', 'Realizado'),
  cancelada('cancelada', 'Cancelado');

  const StatusPartida(this.codigo, this.rotulo);
  final String codigo, rotulo;

  static StatusPartida deCodigo(String? c) =>
      values.firstWhere((s) => s.codigo == c, orElse: () => confirmada);
}

/// Partida confirmada pelos dois times. Guarda cópia dos dados combinados
/// para que edições posteriores no anúncio não alterem o histórico.
class Partida {
  const Partida({
    required this.id,
    this.idAnuncio,
    required this.idSolicitacao,
    required this.timeAnunciante,
    required this.timeAdversario,
    required this.modalidade,
    required this.dataHoraInicio,
    required this.nomeLocal,
    this.endereco,
    required this.cidade,
    required this.siglaEstado,
    required this.status,
    this.golsAnunciante,
    this.golsAdversario,
    this.avaliadaPeloMeuTime = false,
  });

  final String id;
  final String? idAnuncio;
  final String idSolicitacao;
  final ResumoTime timeAnunciante, timeAdversario;
  final ItemReferencia modalidade;
  final DateTime dataHoraInicio;
  final String nomeLocal;
  final String? endereco;
  final String cidade, siglaEstado;
  final StatusPartida status;

  /// Placar opcional (exibido no histórico do perfil). Decisão pendente.
  final int? golsAnunciante, golsAdversario;
  final bool avaliadaPeloMeuTime;

  ResumoTime adversarioDe(String idMeuTime) =>
      timeAnunciante.id == idMeuTime ? timeAdversario : timeAnunciante;

  /// "2 × 1" do ponto de vista do meu time, ou "– × –" sem placar.
  String placarPara(String idMeuTime) {
    if (golsAnunciante == null || golsAdversario == null) return '– × –';
    final meu = timeAnunciante.id == idMeuTime;
    return meu
        ? '$golsAnunciante × $golsAdversario'
        : '$golsAdversario × $golsAnunciante';
  }

  factory Partida.fromJson(Map<String, dynamic> json) => Partida(
    id: json['idPartida'] as String,
    idAnuncio: json['idAnuncio'] as String?,
    idSolicitacao: json['idSolicitacao'] as String,
    timeAnunciante: ResumoTime.fromJson(
      json['timeAnunciante'] as Map<String, dynamic>,
    ),
    timeAdversario: ResumoTime.fromJson(
      json['timeAdversario'] as Map<String, dynamic>,
    ),
    modalidade: ItemReferencia.fromJson(
      json['modalidade'] as Map<String, dynamic>,
    ),
    dataHoraInicio: DateTime.parse(json['dataHoraInicio'] as String).toLocal(),
    nomeLocal: json['nomeLocal'] as String,
    endereco: json['endereco'] as String?,
    cidade: json['cidade'] as String,
    siglaEstado: json['siglaEstado'] as String,
    status: StatusPartida.deCodigo(json['status'] as String?),
    golsAnunciante: (json['golsAnunciante'] as num?)?.toInt(),
    golsAdversario: (json['golsAdversario'] as num?)?.toInt(),
    avaliadaPeloMeuTime: json['avaliadaPeloMeuTime'] as bool? ?? false,
  );
}

/// Avaliação enviada após uma partida realizada.
class NovaAvaliacao {
  const NovaAvaliacao({
    required this.idPartida,
    required this.notas,
    this.comentario,
  });
  final String idPartida;

  /// id do critério -> nota de 1 a 5.
  final Map<int, int> notas;
  final String? comentario;

  Map<String, dynamic> toJson() => {
    'notas': [
      for (final e in notas.entries) {'idCriterio': e.key, 'nota': e.value},
    ],
    'comentario': comentario,
  };
}

/// Avaliação recebida por um time (exibida no perfil).
class AvaliacaoRecebida {
  const AvaliacaoRecebida({
    required this.notaMedia,
    this.comentario,
    required this.timeAvaliador,
    required this.dataAvaliacao,
  });
  final double notaMedia;
  final String? comentario;
  final ResumoTime timeAvaliador;
  final DateTime dataAvaliacao;

  factory AvaliacaoRecebida.fromJson(Map<String, dynamic> json) =>
      AvaliacaoRecebida(
        notaMedia: numeroOuNulo(json['notaMedia']) ?? 0,
        comentario: json['comentario'] as String?,
        timeAvaliador: ResumoTime.fromJson(
          json['timeAvaliador'] as Map<String, dynamic>,
        ),
        dataAvaliacao: DateTime.parse(
          json['dataAvaliacao'] as String,
        ).toLocal(),
      );
}
