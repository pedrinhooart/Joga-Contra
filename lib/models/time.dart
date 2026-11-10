import 'dart:typed_data';
import '../core/formatters.dart';
import 'referencia.dart';

/// Dados mínimos de um time exibidos em cards, escudos e confrontos.
class ResumoTime {
  const ResumoTime({
    required this.id,
    required this.nome,
    this.sigla,
    this.urlEscudo,
    this.cidade,
    this.siglaEstado,
    this.nomeCapitao,
  });

  final String id, nome;
  final String? sigla, urlEscudo, cidade, siglaEstado, nomeCapitao;

  String get siglaExibicao => sigla ?? Formatos.sigla(nome);
  String get localExibicao => [
    if (cidade != null) cidade,
    if (siglaEstado != null) siglaEstado,
  ].join(', ');

  factory ResumoTime.fromJson(Map<String, dynamic> json) => ResumoTime(
    id: json['idTime'] as String,
    nome: json['nome'] as String,
    sigla: json['sigla'] as String?,
    urlEscudo: json['urlEscudo'] as String?,
    cidade: json['cidade'] as String?,
    siglaEstado: json['siglaEstado'] as String?,
    nomeCapitao: json['nomeCapitao'] as String?,
  );
}

/// Perfil completo do time. Cada time tem exatamente um capitão (usuário);
/// os integrantes não têm cadastro: o capitão informa só a quantidade.
class Time {
  const Time({
    required this.id,
    required this.idCapitao,
    required this.nome,
    this.sigla,
    this.urlEscudo,
    required this.cidade,
    required this.siglaEstado,
    this.bairro,
    this.quantidadeJogadores,
    this.modalidades = const [],
    this.categoriaEtaria,
    this.nivelTecnico,
    this.descricao,
    this.anoFundacao,
    this.nomeCapitao,
    this.telefoneContato,
    this.totalPartidasRealizadas = 0,
    this.mediaAvaliacao,
    this.totalAvaliacoes = 0,
    this.verificado = false,
  });

  final String id, idCapitao, nome;
  final String? sigla, urlEscudo;
  final String cidade, siglaEstado;
  final String? bairro;

  /// Opcional: o cadastro não pede; cada anúncio informa a do jogo.
  final int? quantidadeJogadores;
  final List<ItemReferencia> modalidades;
  final ItemReferencia? categoriaEtaria, nivelTecnico;
  final String? descricao;
  final int? anoFundacao;
  final String? nomeCapitao, telefoneContato;

  /// Campos calculados pela API a partir de partidas e avaliações.
  final int totalPartidasRealizadas;
  final double? mediaAvaliacao;
  final int totalAvaliacoes;
  final bool verificado;

  String get siglaExibicao => sigla ?? Formatos.sigla(nome);
  String get localExibicao => '$cidade, $siglaEstado';

  ResumoTime get resumo => ResumoTime(
    id: id,
    nome: nome,
    sigla: sigla,
    urlEscudo: urlEscudo,
    cidade: cidade,
    siglaEstado: siglaEstado,
    nomeCapitao: nomeCapitao,
  );

  /// [descricao] vazia remove a descrição.
  Time copyWith({String? nome, String? descricao, String? urlEscudo}) => Time(
    id: id,
    idCapitao: idCapitao,
    nome: nome ?? this.nome,
    sigla: nome == null ? sigla : null,
    urlEscudo: urlEscudo ?? this.urlEscudo,
    cidade: cidade,
    siglaEstado: siglaEstado,
    bairro: bairro,
    quantidadeJogadores: quantidadeJogadores,
    modalidades: modalidades,
    categoriaEtaria: categoriaEtaria,
    nivelTecnico: nivelTecnico,
    descricao: descricao == null
        ? this.descricao
        : (descricao.trim().isEmpty ? null : descricao.trim()),
    anoFundacao: anoFundacao,
    nomeCapitao: nomeCapitao,
    telefoneContato: telefoneContato,
    totalPartidasRealizadas: totalPartidasRealizadas,
    mediaAvaliacao: mediaAvaliacao,
    totalAvaliacoes: totalAvaliacoes,
    verificado: verificado,
  );

  factory Time.fromJson(Map<String, dynamic> json) => Time(
    id: json['idTime'] as String,
    idCapitao: json['idCapitao'] as String,
    nome: json['nome'] as String,
    sigla: json['sigla'] as String?,
    urlEscudo: json['urlEscudo'] as String?,
    cidade: json['cidade'] as String,
    siglaEstado: json['siglaEstado'] as String,
    bairro: json['bairro'] as String?,
    quantidadeJogadores: (json['quantidadeJogadores'] as num?)?.toInt(),
    modalidades: ((json['modalidades'] as List?) ?? const [])
        .map((e) => ItemReferencia.fromJson(e as Map<String, dynamic>))
        .toList(),
    categoriaEtaria: itemOuNulo(json['categoriaEtaria']),
    nivelTecnico: itemOuNulo(json['nivelTecnico']),
    descricao: json['descricao'] as String?,
    anoFundacao: (json['anoFundacao'] as num?)?.toInt(),
    nomeCapitao: json['nomeCapitao'] as String?,
    telefoneContato: json['telefoneContato'] as String?,
    totalPartidasRealizadas:
        (json['totalPartidasRealizadas'] as num?)?.toInt() ?? 0,
    mediaAvaliacao: numeroOuNulo(json['mediaAvaliacao']),
    totalAvaliacoes: (json['totalAvaliacoes'] as num?)?.toInt() ?? 0,
    verificado: json['verificado'] as bool? ?? false,
  );
}

/// Campos editáveis do time (`PATCH /times/:idTime`). Só os não nulos são enviados.
class AtualizacaoTime {
  const AtualizacaoTime({
    this.nome,
    this.descricao,
    this.quantidadeJogadores,
    this.idCategoriaEtaria,
    this.idNivelTecnico,
    this.idsModalidades,
    this.cidade,
    this.siglaEstado,
    this.telefoneContato,
  });
  final String? nome, descricao, cidade, siglaEstado, telefoneContato;
  final int? quantidadeJogadores, idCategoriaEtaria, idNivelTecnico;
  final List<int>? idsModalidades;

  Map<String, dynamic> toJson() => {
    'nome': ?nome,
    'descricao': ?descricao,
    'quantidadeJogadores': ?quantidadeJogadores,
    'idCategoriaEtaria': ?idCategoriaEtaria,
    'idNivelTecnico': ?idNivelTecnico,
    'idsModalidades': ?idsModalidades,
    'cidade': ?cidade,
    'siglaEstado': ?siglaEstado,
    'telefoneContato': ?telefoneContato,
  };
}

/// Imagem escolhida para o escudo, já validada no aparelho.
class ImagemSelecionada {
  const ImagemSelecionada(this.bytes, this.tipo);

  final Uint8List bytes;

  /// `image/jpeg`, `image/png` ou `image/webp`.
  final String tipo;

  /// Mesmo limite da API.
  static const limiteBytes = 2 * 1024 * 1024;

  /// Formato real pelos primeiros bytes; nulo se não for JPEG, PNG ou WebP.
  static String? tipoDe(Uint8List b) {
    bool comeca(List<int> assinatura, [int inicio = 0]) =>
        b.length >= inicio + assinatura.length &&
        [
          for (var i = 0; i < assinatura.length; i++)
            b[inicio + i] == assinatura[i],
        ].every((igual) => igual);
    if (comeca([0xFF, 0xD8, 0xFF])) return 'image/jpeg';
    if (comeca([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return 'image/png';
    }
    if (comeca('RIFF'.codeUnits) && comeca('WEBP'.codeUnits, 8)) {
      return 'image/webp';
    }
    return null;
  }
}
