import 'dart:convert';
import 'package:flutter/services.dart';

/// Municípios brasileiros por UF, da API de Localidades do IBGE, embutidos no
/// app (`assets/dados/municipios_ibge.json`). Carregados uma vez e filtrados
/// localmente: nenhuma chamada externa durante a digitação.
class Municipios {
  Municipios._(this._porUf);

  static const asset = 'assets/dados/municipios_ibge.json';
  static Future<Municipios>? _carregando;

  /// Disponível sem espera depois do primeiro carregamento.
  static Municipios? carregado;

  /// Lê o arquivo uma única vez por execução do app.
  static Future<Municipios> carregar([AssetBundle? bundle]) =>
      _carregando ??= _ler(bundle ?? rootBundle);

  static Future<Municipios> _ler(AssetBundle bundle) async {
    final json =
        jsonDecode(await bundle.loadString(asset)) as Map<String, dynamic>;
    final porUf = (json['municipios'] as Map<String, dynamic>).map(
      (uf, nomes) => MapEntry(uf, List<String>.unmodifiable(nomes as List)),
    );
    return carregado = Municipios._(porUf);
  }

  final Map<String, List<String>> _porUf;

  /// Já em ordem alfabética (pt-BR, ignorando acentos).
  List<String> daUf(String uf) => _porUf[uf] ?? const [];

  /// Nomes que começam com o texto vêm antes dos que apenas o contêm.
  List<String> sugerir(String uf, String texto) {
    final busca = normalizar(texto);
    final cidades = daUf(uf);
    if (busca.isEmpty) return cidades;
    final inicio = <String>[], meio = <String>[];
    for (final nome in cidades) {
      final n = normalizar(nome);
      if (n.startsWith(busca)) {
        inicio.add(nome);
      } else if (n.contains(busca)) {
        meio.add(nome);
      }
    }
    return [...inicio, ...meio];
  }

  /// Nome oficial da cidade digitada, ou nulo se ela não pertence à UF.
  String? oficial(String uf, String texto) {
    final busca = normalizar(texto);
    if (busca.isEmpty) return null;
    for (final nome in daUf(uf)) {
      if (normalizar(nome) == busca) return nome;
    }
    return null;
  }

  static const _semAcento = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', //
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
    'ç': 'c', 'ñ': 'n',
  };

  /// Minúsculas, sem acentos e com espaços simples: "são  PAULO" → "sao paulo".
  static String normalizar(String texto) {
    final b = StringBuffer();
    for (final c in texto.trim().toLowerCase().split('')) {
      b.write(_semAcento[c] ?? c);
    }
    return b.toString().replaceAll(RegExp(r'\s+'), ' ');
  }
}
