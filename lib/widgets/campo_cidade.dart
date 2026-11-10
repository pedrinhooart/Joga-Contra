import 'dart:async';
import 'package:flutter/material.dart';
import '../services/municipios.dart';
import '../theme/app_theme.dart';

/// Cidade com sugestões dos municípios da UF escolhida. Só aceita cidades
/// da UF; quem troca a UF deve limpar o [controller].
class CampoCidade extends StatefulWidget {
  const CampoCidade({
    super.key,
    required this.controller,
    required this.siglaEstado,
  });

  final TextEditingController controller;
  final String? siglaEstado;

  @override
  State<CampoCidade> createState() => _CampoCidadeState();
}

class _CampoCidadeState extends State<CampoCidade> {
  final _foco = FocusNode();
  Municipios? _municipios = Municipios.carregado;

  @override
  void initState() {
    super.initState();
    if (_municipios == null) {
      Municipios.carregar().then((m) {
        if (mounted) setState(() => _municipios = m);
      });
    }
    _foco.addListener(_mostrarSugestoes);
  }

  @override
  void dispose() {
    _subir?.cancel();
    _foco.dispose();
    super.dispose();
  }

  Timer? _subir;

  /// Ao focar, sobe o campo para as sugestões caberem acima do teclado
  /// (espera o teclado abrir para saber o espaço que sobra).
  void _mostrarSugestoes() {
    _subir?.cancel();
    if (!_foco.hasFocus) return;
    _subir = Timer(const Duration(milliseconds: 350), () {
      final contexto = _foco.context;
      if (mounted && _foco.hasFocus && contexto != null && contexto.mounted) {
        Scrollable.ensureVisible(
          contexto,
          alignment: 0.05,
          duration: const Duration(milliseconds: 200),
        );
      }
    });
  }

  String? _validar(String? valor) {
    final uf = widget.siglaEstado;
    if (uf == null) return 'Selecione o estado primeiro';
    if ((valor ?? '').trim().isEmpty) return 'Informe a cidade';
    final municipios = _municipios;
    if (municipios == null) return 'Carregando as cidades…';
    return municipios.oficial(uf, valor!) == null
        ? 'Escolha uma cidade de $uf na lista'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final uf = widget.siglaEstado;
    final municipios = _municipios;
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _foco,
      optionsViewOpenDirection: OptionsViewOpenDirection.mostSpace,
      optionsBuilder: (valor) => uf == null || municipios == null
          ? const <String>[]
          : municipios.sugerir(uf, valor.text),
      fieldViewBuilder: (context, controller, foco, enviar) =>
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, valor, _) {
              final semResultado =
                  uf != null &&
                  municipios != null &&
                  valor.text.trim().isNotEmpty &&
                  municipios.sugerir(uf, valor.text).isEmpty;
              return TextFormField(
                controller: controller,
                focusNode: foco,
                enabled: uf != null,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Cidade',
                  hintText: uf == null
                      ? 'Selecione o estado primeiro'
                      : 'Digite o nome da cidade',
                  helperText: semResultado
                      ? 'Nenhuma cidade de $uf com esse nome.'
                      : null,
                ),
                validator: _validar,
                onFieldSubmitted: (_) => enviar(),
              );
            },
          ),
      optionsViewBuilder: (context, selecionar, opcoes) => Material(
        color: Colors.white,
        elevation: 3,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: ListView.builder(
            key: const ValueKey('sugestoes-cidade'),
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: opcoes.length,
            itemBuilder: (context, i) {
              final nome = opcoes.elementAt(i);
              final destacado = AutocompleteHighlightedOption.of(context) == i;
              return InkWell(
                onTap: () => selecionar(nome),
                child: Container(
                  color: destacado ? AppColors.canvas : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Text(nome, style: const TextStyle(fontSize: 14)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
