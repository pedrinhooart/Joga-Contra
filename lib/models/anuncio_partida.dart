import 'referencia.dart';
import 'time.dart';

enum StatusAnuncio {
  ativo('ativo', 'Ativo'),
  pausado('pausado', 'Pausado'),

  /// Partida confirmada: o anúncio não aceita novas solicitações.
  encerrado('encerrado', 'Encerrado'),
  expirado('expirado', 'Expirado');

  const StatusAnuncio(this.codigo, this.rotulo);
  final String codigo, rotulo;

  static StatusAnuncio deCodigo(String? c) =>
      values.firstWhere((s) => s.codigo == c, orElse: () => ativo);
}

/// Anúncio publicado por um time procurando adversário.
class AnuncioPartida {
  const AnuncioPartida({
    required this.id,
    required this.time,
    required this.modalidade,
    required this.categoriaEtaria,
    this.nivelTecnico,
    this.mandoCampo,
    required this.quantidadeJogadores,
    required this.dataHoraInicio,
    required this.cidade,
    required this.siglaEstado,
    this.bairro,
    required this.nomeLocal,
    this.endereco,
    this.valorAluguelPorTime,
    this.descricao,
    this.status = StatusAnuncio.ativo,
    this.totalSolicitacoes = 0,
    this.distanciaKm,
  });

  final String id;
  final ResumoTime time;
  final ItemReferencia modalidade, categoriaEtaria;
  final ItemReferencia? nivelTecnico, mandoCampo;
  final int quantidadeJogadores;
  final DateTime dataHoraInicio;
  final String cidade, siglaEstado;
  final String? bairro;
  final String nomeLocal;
  final String? endereco;
  final double? valorAluguelPorTime;
  final String? descricao;
  final StatusAnuncio status;

  /// Calculado pela API (solicitações pendentes/aceitas).
  final int totalSolicitacoes;

  /// Calculado pela API a partir da localização do usuário, quando houver.
  final double? distanciaKm;

  bool get aceitaSolicitacoes => status == StatusAnuncio.ativo;
  String get localExibicao => '$cidade, $siglaEstado';

  AnuncioPartida copyWith({StatusAnuncio? status, int? totalSolicitacoes}) =>
      AnuncioPartida(
        id: id,
        time: time,
        modalidade: modalidade,
        categoriaEtaria: categoriaEtaria,
        nivelTecnico: nivelTecnico,
        mandoCampo: mandoCampo,
        quantidadeJogadores: quantidadeJogadores,
        dataHoraInicio: dataHoraInicio,
        cidade: cidade,
        siglaEstado: siglaEstado,
        bairro: bairro,
        nomeLocal: nomeLocal,
        endereco: endereco,
        valorAluguelPorTime: valorAluguelPorTime,
        descricao: descricao,
        status: status ?? this.status,
        totalSolicitacoes: totalSolicitacoes ?? this.totalSolicitacoes,
        distanciaKm: distanciaKm,
      );

  factory AnuncioPartida.fromJson(Map<String, dynamic> json) => AnuncioPartida(
    id: json['idAnuncio'] as String,
    time: ResumoTime.fromJson(json['time'] as Map<String, dynamic>),
    modalidade: ItemReferencia.fromJson(
      json['modalidade'] as Map<String, dynamic>,
    ),
    categoriaEtaria: ItemReferencia.fromJson(
      json['categoriaEtaria'] as Map<String, dynamic>,
    ),
    nivelTecnico: itemOuNulo(json['nivelTecnico']),
    mandoCampo: itemOuNulo(json['mandoCampo']),
    quantidadeJogadores: (json['quantidadeJogadores'] as num).toInt(),
    dataHoraInicio: DateTime.parse(json['dataHoraInicio'] as String).toLocal(),
    cidade: json['cidade'] as String,
    siglaEstado: json['siglaEstado'] as String,
    bairro: json['bairro'] as String?,
    nomeLocal: json['nomeLocal'] as String,
    endereco: json['endereco'] as String?,
    valorAluguelPorTime: numeroOuNulo(json['valorAluguelPorTime']),
    descricao: json['descricao'] as String?,
    status: StatusAnuncio.deCodigo(json['status'] as String?),
    totalSolicitacoes: (json['totalSolicitacoes'] as num?)?.toInt() ?? 0,
    distanciaKm: numeroOuNulo(json['distanciaKm']),
  );
}

/// Dados do formulário "Anunciar jogo" (`POST /anuncios`, `PUT /anuncios/:id`).
class RascunhoAnuncio {
  const RascunhoAnuncio({
    required this.idModalidade,
    required this.idCategoriaEtaria,
    required this.idNivelTecnico,
    this.idMandoCampo,
    required this.quantidadeJogadores,
    required this.dataHoraInicio,
    required this.cidade,
    required this.siglaEstado,
    this.bairro,
    required this.nomeLocal,
    this.endereco,
    this.valorAluguelPorTime,
    this.descricao,
  });

  final int idModalidade, idCategoriaEtaria, idNivelTecnico;
  final int? idMandoCampo;
  final int quantidadeJogadores;
  final DateTime dataHoraInicio;
  final String cidade, siglaEstado;
  final String? bairro;
  final String nomeLocal;
  final String? endereco;
  final double? valorAluguelPorTime;
  final String? descricao;

  Map<String, dynamic> toJson() => {
    'idModalidade': idModalidade,
    'idCategoriaEtaria': idCategoriaEtaria,
    'idNivelTecnico': idNivelTecnico,
    'idMandoCampo': idMandoCampo,
    'quantidadeJogadores': quantidadeJogadores,
    'dataHoraInicio': dataHoraInicio.toUtc().toIso8601String(),
    'cidade': cidade,
    'siglaEstado': siglaEstado,
    'bairro': bairro,
    'nomeLocal': nomeLocal,
    'endereco': endereco,
    'valorAluguelPorTime': valorAluguelPorTime,
    'descricao': descricao,
  };
}

/// Filtros da busca (`GET /anuncios`).
class FiltroAnuncios {
  const FiltroAnuncios({
    this.texto,
    this.idModalidade,
    this.idCategoriaEtaria,
    this.idNivelTecnico,
    this.data,
    this.raioKm,
    this.siglaEstado,
    this.cidade,
    this.horario,
  });
  final String? texto;
  final int? idModalidade, idCategoriaEtaria, idNivelTecnico;
  final DateTime? data;
  final int? raioKm;
  final String? siglaEstado, cidade;

  /// Partidas a partir deste horário (HH:mm), no fuso do aparelho.
  final String? horario;

  Map<String, Object?> toQuery() => {
    'texto': texto,
    'idModalidade': idModalidade,
    'idCategoriaEtaria': idCategoriaEtaria,
    'idNivelTecnico': idNivelTecnico,
    'data': data == null
        ? null
        : '${data!.year}-${data!.month.toString().padLeft(2, '0')}-${data!.day.toString().padLeft(2, '0')}',
    'raioKm': raioKm,
    'siglaEstado': siglaEstado,
    'cidade': cidade,
    'horario': horario,
    // Data e horário são os do aparelho; o banco guarda UTC.
    if (data != null || horario != null)
      'fusoMinutos': (data ?? DateTime.now()).timeZoneOffset.inMinutes,
  };
}
