/// Item de cadastro de referência (modalidade, categoria etária, nível técnico,
/// mando de campo, critério de avaliação). Vem da API (`GET /referencias`);
/// o app não fixa essas listas no código.
class ItemReferencia {
  const ItemReferencia({
    required this.id,
    required this.codigo,
    required this.nome,
    this.ordem = 0,
  });

  final int id;

  /// Código estável usado em regras/estilos (ex.: `society`, `quadra`).
  final String codigo;
  final String nome;
  final int ordem;

  factory ItemReferencia.fromJson(Map<String, dynamic> json) => ItemReferencia(
    id: (json['id'] as num).toInt(),
    codigo: json['codigo'] as String,
    nome: json['nome'] as String,
    ordem: (json['ordem'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'codigo': codigo,
    'nome': nome,
    'ordem': ordem,
  };

  @override
  bool operator ==(Object other) => other is ItemReferencia && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class Estado {
  const Estado({required this.sigla, required this.nome});
  final String sigla, nome;
  factory Estado.fromJson(Map<String, dynamic> json) =>
      Estado(sigla: json['sigla'] as String, nome: json['nome'] as String);
}

/// Todos os cadastros de referência carregados de uma vez ao abrir o app.
class Referencias {
  const Referencias({
    this.modalidades = const [],
    this.categoriasEtarias = const [],
    this.niveisTecnicos = const [],
    this.mandosCampo = const [],
    this.criteriosAvaliacao = const [],
    this.estados = const [],
  });

  final List<ItemReferencia> modalidades,
      categoriasEtarias,
      niveisTecnicos,
      mandosCampo,
      criteriosAvaliacao;
  final List<Estado> estados;

  bool get vazio => modalidades.isEmpty && categoriasEtarias.isEmpty;

  static List<ItemReferencia> _lista(Object? v) =>
      ((v as List?) ?? const [])
          .map((e) => ItemReferencia.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.ordem.compareTo(b.ordem));

  factory Referencias.fromJson(Map<String, dynamic> json) => Referencias(
    modalidades: _lista(json['modalidades']),
    categoriasEtarias: _lista(json['categoriasEtarias']),
    niveisTecnicos: _lista(json['niveisTecnicos']),
    mandosCampo: _lista(json['mandosCampo']),
    criteriosAvaliacao: _lista(json['criteriosAvaliacao']),
    estados: ((json['estados'] as List?) ?? const [])
        .map((e) => Estado.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

ItemReferencia? itemOuNulo(Object? json) =>
    json is Map<String, dynamic> ? ItemReferencia.fromJson(json) : null;

DateTime? dataOuNula(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

double? numeroOuNulo(Object? v) => switch (v) {
  num n => n.toDouble(),
  String s => double.tryParse(s),
  _ => null,
};
