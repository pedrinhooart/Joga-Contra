import 'package:flutter/widgets.dart';

/// Fontes maiores em todo o app, num só lugar: vale para os tamanhos fixos das
/// telas e para os do tema (botões, campos, menus). Ícones não mudam.
///
/// Textos pequenos (até 10) crescem 32% e títulos (a partir de 24) 12%, com
/// transição gradual entre eles: a leitura melhora sem que os títulos dominem
/// a tela, e a ordem dos tamanhos (hierarquia) é mantida.
/// A escala de acessibilidade do sistema continua valendo por cima desta.
class EscalaDeLeitura extends TextScaler {
  const EscalaDeLeitura(this.sistema);

  /// Escala escolhida pelo usuário nas configurações do aparelho.
  final TextScaler sistema;

  static const _pequeno = 10.0, _grande = 24.0;
  static const _fatorPequeno = 1.32, _fatorGrande = 1.12;

  /// Fator de aumento para um tamanho de fonte do layout.
  static double fator(double tamanho) {
    if (tamanho <= _pequeno) return _fatorPequeno;
    if (tamanho >= _grande) return _fatorGrande;
    final t = (tamanho - _pequeno) / (_grande - _pequeno);
    return _fatorPequeno + (_fatorGrande - _fatorPequeno) * t;
  }

  @override
  double scale(double fontSize) => sistema.scale(fontSize * fator(fontSize));

  @override
  @Deprecated('Use scale().')
  // ignore: deprecated_member_use
  double get textScaleFactor => sistema.textScaleFactor * fator(14);

  @override
  TextScaler clamp({
    double minScaleFactor = 0,
    double maxScaleFactor = double.infinity,
  }) => EscalaDeLeitura(
    sistema.clamp(
      minScaleFactor: minScaleFactor,
      maxScaleFactor: maxScaleFactor,
    ),
  );

  @override
  bool operator ==(Object other) =>
      other is EscalaDeLeitura && other.sistema == sistema;

  @override
  int get hashCode => Object.hash(EscalaDeLeitura, sistema);

  @override
  String toString() => 'EscalaDeLeitura($sistema)';
}
