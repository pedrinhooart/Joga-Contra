/// Local esportivo real sugerido pela API (fonte: OpenStreetMap).
class LocalEsportivo {
  const LocalEsportivo({
    required this.nome,
    this.endereco,
    this.latitude,
    this.longitude,
  });

  final String nome;
  final String? endereco;
  final double? latitude, longitude;

  factory LocalEsportivo.fromJson(Map<String, dynamic> json) => LocalEsportivo(
    nome: json['nome'] as String,
    endereco: json['endereco'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );
}

/// Locais de uma cidade e o crédito exigido pela fonte dos dados.
class LocaisDaCidade {
  const LocaisDaCidade(this.locais, {this.atribuicao});
  final List<LocalEsportivo> locais;
  final String? atribuicao;
}
