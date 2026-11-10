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
    this.categoriaEtaria,
    this.nivelTecnico,
    this.mandoCampo,
    this.quantidadeJogadores,
    required this.dataHoraInicio,
    this.duracaoMinutos,
    required this.cidade,
    required this.siglaEstado,
    this.bairro,
    required this.nomeLocal,
    this.endereco,
    this.latitude,
    this.longitude,
    this.valorAluguelPorTime,
    this.descricao,
    this.status = StatusAnuncio.ativo,
    this.totalSolicitacoes = 0,
    this.distanciaKm,
  });

  final String id;
  final ResumoTime time;
  final ItemReferencia modalidade;

  /// Só em anúncios antigos: o formulário atual não pede categoria, mando,
  /// quantidade nem bairro.
  final ItemReferencia? categoriaEtaria, nivelTecnico, mandoCampo;
  final int? quantidadeJogadores;
  final DateTime dataHoraInicio;

  /// Duração prevista, em minutos (anúncios antigos não têm).
  final int? duracaoMinutos;
  final String cidade, siglaEstado;
  final String? bairro;
  final String nomeLocal;
  final String? endereco;

  /// Coordenadas do local escolhido entre as sugestões.
  final double? latitude, longitude;
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
        duracaoMinutos: duracaoMinutos,
        cidade: cidade,
        siglaEstado: siglaEstado,
        bairro: bairro,
        nomeLocal: nomeLocal,
        endereco: endereco,
        latitude: latitude,
        longitude: longitude,
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
    categoriaEtaria: itemOuNulo(json['categoriaEtaria']),
    nivelTecnico: itemOuNulo(json['nivelTecnico']),
    mandoCampo: itemOuNulo(json['mandoCampo']),
    quantidadeJogadores: (json['quantidadeJogadores'] as num?)?.toInt(),
    dataHoraInicio: DateTime.parse(json['dataHoraInicio'] as String).toLocal(),
    duracaoMinutos: (json['duracaoMinutos'] as num?)?.toInt(),
    cidade: json['cidade'] as String,
    siglaEstado: json['siglaEstado'] as String,
    bairro: json['bairro'] as String?,
    nomeLocal: json['nomeLocal'] as String,
    endereco: json['endereco'] as String?,
    latitude: numeroOuNulo(json['latitude']),
    longitude: numeroOuNulo(json['longitude']),
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
    required this.idNivelTecnico,
    required this.dataHoraInicio,
    required this.duracaoMinutos,
    required this.cidade,
    required this.siglaEstado,
    required this.nomeLocal,
    this.endereco,
    this.latitude,
    this.longitude,
    this.valorAluguelPorTime,
    this.descricao,
    this.idCategoriaEtaria,
    this.idMandoCampo,
    this.quantidadeJogadores,
    this.bairro,
  });

  final int idModalidade, idNivelTecnico;
  final DateTime dataHoraInicio;
  final int duracaoMinutos;
  final String cidade, siglaEstado;
  final String nomeLocal;

  /// Preenchidos quando o local vem das sugestões; nulos se digitado à mão.
  final String? endereco;
  final double? latitude, longitude;
  final double? valorAluguelPorTime;
  final String? descricao;

  /// Fora do formulário atual. Só repassados ao editar um anúncio antigo,
  /// para não apagar o que ele já tinha.
  final int? idCategoriaEtaria, idMandoCampo, quantidadeJogadores;
  final String? bairro;

  Map<String, dynamic> toJson() => {
    'idModalidade': idModalidade,
    'idNivelTecnico': idNivelTecnico,
    'dataHoraInicio': dataHoraInicio.toUtc().toIso8601String(),
    'duracaoMinutos': duracaoMinutos,
    'cidade': cidade,
    'siglaEstado': siglaEstado,
    'nomeLocal': nomeLocal,
    'endereco': endereco,
    'latitude': latitude,
    'longitude': longitude,
    'valorAluguelPorTime': valorAluguelPorTime,
    'descricao': descricao,
    'idCategoriaEtaria': idCategoriaEtaria,
    'idMandoCampo': idMandoCampo,
    'quantidadeJogadores': quantidadeJogadores,
    'bairro': bairro,
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
