import 'dart:async';
import 'package:flutter/material.dart';
import '../models/local_esportivo.dart';
import '../services/municipios.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Local da partida com sugestões de locais esportivos reais da cidade.
/// A lista vem da API uma vez por cidade e é filtrada no aparelho enquanto o
/// capitão digita. Também aceita um local digitado à mão.
class CampoLocal extends StatefulWidget {
  const CampoLocal({
    super.key,
    required this.controller,
    required this.siglaEstado,
    required this.cidade,
    required this.onLocal,
  });

  final TextEditingController controller;
  final String? siglaEstado;

  /// Nome oficial da cidade, ou nulo enquanto não houver cidade válida.
  final String? cidade;

  /// Local escolhido nas sugestões; nulo quando o texto é digitado à mão.
  final ValueChanged<LocalEsportivo?> onLocal;

  /// Uma consulta por cidade durante a execução do app: em andamento e prontas.
  static final _cache = <String, Future<LocaisDaCidade>>{};
  static final _prontos = <String, LocaisDaCidade>{};

  /// Só para testes: esquece as cidades já consultadas.
  @visibleForTesting
  static void limparCache() {
    _cache.clear();
    _prontos.clear();
  }

  @override
  State<CampoLocal> createState() => _CampoLocalState();
}

class _CampoLocalState extends State<CampoLocal> {
  final _foco = FocusNode();
  Timer? _espera;
  LocaisDaCidade? _dados;
  bool _carregando = false, _falhou = false;
  LocalEsportivo? _escolhido;

  String? get _chave => widget.siglaEstado == null || widget.cidade == null
      ? null
      : '${widget.siglaEstado}|${widget.cidade}';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_textoMudou);
    _agendar();
  }

  @override
  void didUpdateWidget(CampoLocal antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.siglaEstado != widget.siglaEstado ||
        antigo.cidade != widget.cidade) {
      _agendar();
    }
  }

  @override
  void dispose() {
    _espera?.cancel();
    widget.controller.removeListener(_textoMudou);
    _foco.dispose();
    super.dispose();
  }

  /// Editar o texto de um local escolhido vira preenchimento manual.
  void _textoMudou() {
    if (_escolhido != null && widget.controller.text != _escolhido!.nome) {
      _escolhido = null;
      widget.onLocal(null);
    }
  }

  /// Espera a cidade "assentar" antes de consultar (evita pedidos à toa).
  void _agendar() {
    _espera?.cancel();
    setState(() {
      _dados = null;
      _falhou = false;
      _carregando = _chave != null;
    });
    final chave = _chave;
    if (chave == null) return;
    final pronto = CampoLocal._prontos[chave];
    if (pronto != null) {
      // Cidade já consultada: sugestões na hora, sem espera nem rede.
      setState(() {
        _dados = pronto;
        _carregando = false;
      });
      return;
    }
    _espera = Timer(const Duration(milliseconds: 500), () async {
      final repos = AppScope.repos(context);
      final consulta = CampoLocal._cache.putIfAbsent(
        chave,
        () => repos.locais.daCidade(widget.siglaEstado!, widget.cidade!),
      );
      try {
        final dados = await consulta;
        CampoLocal._prontos[chave] = dados;
        if (mounted && chave == _chave) {
          setState(() {
            _dados = dados;
            _carregando = false;
          });
        }
      } catch (_) {
        CampoLocal._cache.remove(chave); // tenta de novo na próxima vez
        if (mounted && chave == _chave) {
          setState(() {
            _falhou = true;
            _carregando = false;
          });
        }
      }
    });
  }

  List<LocalEsportivo> _sugestoes(String texto) {
    final locais = _dados?.locais ?? const <LocalEsportivo>[];
    final busca = Municipios.normalizar(texto);
    if (busca.isEmpty) return locais.take(50).toList();
    final inicio = <LocalEsportivo>[], meio = <LocalEsportivo>[];
    for (final l in locais) {
      final n = Municipios.normalizar(l.nome);
      if (n.startsWith(busca)) {
        inicio.add(l);
      } else if (n.contains(busca) ||
          Municipios.normalizar(l.endereco ?? '').contains(busca)) {
        meio.add(l);
      }
    }
    return [...inicio, ...meio].take(50).toList();
  }

  String? get _ajuda {
    final cidade = widget.cidade;
    if (cidade == null) return 'Escolha a cidade para ver sugestões.';
    if (_carregando) return 'Buscando locais esportivos em $cidade…';
    if (_falhou) return 'Sugestões indisponíveis agora. Digite o local.';
    if (_dados != null && _dados!.locais.isEmpty) {
      return 'Nenhum local esportivo cadastrado em $cidade. Digite o local.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => RawAutocomplete<LocalEsportivo>(
    textEditingController: widget.controller,
    focusNode: _foco,
    optionsViewOpenDirection: OptionsViewOpenDirection.mostSpace,
    displayStringForOption: (l) => l.nome,
    optionsBuilder: (valor) => _sugestoes(valor.text),
    onSelected: (local) {
      _escolhido = local;
      widget.onLocal(local);
    },
    fieldViewBuilder: (context, controller, foco, enviar) => TextFormField(
      controller: controller,
      focusNode: foco,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: 'Local da partida',
        hintText: 'Nome do campo ou quadra',
        helperText: _ajuda,
        helperMaxLines: 2,
        suffixIcon: _carregando
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
      onFieldSubmitted: (_) => enviar(),
    ),
    optionsViewBuilder: (context, selecionar, opcoes) => Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: ListView(
          key: const ValueKey('sugestoes-local'),
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: [
            for (var i = 0; i < opcoes.length; i++)
              Builder(
                builder: (context) {
                  final local = opcoes.elementAt(i);
                  final destacado =
                      AutocompleteHighlightedOption.of(context) == i;
                  return InkWell(
                    onTap: () => selecionar(local),
                    child: Container(
                      color: destacado ? AppColors.canvas : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            local.nome,
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (local.endereco != null)
                            Text(
                              local.endereco!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            if (_dados?.atribuicao != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                child: Text(
                  'Dados ${_dados!.atribuicao}',
                  style: const TextStyle(fontSize: 9, color: AppColors.muted),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
