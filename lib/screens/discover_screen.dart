import 'dart:async';
import 'package:flutter/material.dart';
import '../core/formatters.dart';
import '../models/anuncio_partida.dart';
import '../models/referencia.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/carregador.dart';
import '../widgets/common.dart';

/// Filtros escolhidos na busca. Guardado pelo AppShell para sobreviver à
/// navegação entre abas.
class FiltrosBusca {
  const FiltrosBusca({
    this.texto = '',
    this.idModalidade,
    this.idCategoriaEtaria,
    this.idNivelTecnico,
    this.raioKm = 25,
    this.data,
    this.cidade = '',
    this.horario = '',
  });
  final String texto, cidade, horario;
  final int? idModalidade, idCategoriaEtaria, idNivelTecnico;
  final int raioKm;
  final DateTime? data;

  FiltroAnuncios get consulta => FiltroAnuncios(
    texto: texto.trim().isEmpty ? null : texto.trim(),
    idModalidade: idModalidade,
    idCategoriaEtaria: idCategoriaEtaria,
    idNivelTecnico: idNivelTecnico,
    raioKm: raioKm,
    data: data,
    cidade: cidade.isEmpty ? null : cidade,
    horario: horario.isEmpty ? null : horario,
  );
}

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    required this.filtros,
    required this.onFiltros,
    required this.onSelectAnuncio,
    required this.onMap,
  });
  final FiltrosBusca filtros;
  final ValueChanged<FiltrosBusca> onFiltros;
  final ValueChanged<AnuncioPartida> onSelectAnuncio;
  final VoidCallback onMap;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  static const _raios = [5, 10, 25, 50, 100];
  late FiltrosBusca f = widget.filtros;
  late final texto = TextEditingController(text: f.texto);
  // Vivem com a tela: a folha de filtros ainda os usa durante a animação de fechar.
  final dataController = TextEditingController();
  final cidadeController = TextEditingController();
  final horarioController = TextEditingController();
  Future<List<AnuncioPartida>>? _resultados;
  Timer? _debounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resultados ??= _buscar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    texto.dispose();
    dataController.dispose();
    cidadeController.dispose();
    horarioController.dispose();
    super.dispose();
  }

  Future<List<AnuncioPartida>> _buscar() =>
      AppScope.repos(context).anuncios.buscar(f.consulta);

  void _rebuscar() {
    setState(() {
      _resultados = _buscar();
    });
  }

  void _aplicar(FiltrosBusca novo, {bool imediato = true}) {
    setState(() => f = novo);
    widget.onFiltros(novo);
    _debounce?.cancel();
    if (imediato) {
      _rebuscar();
    } else {
      _debounce = Timer(
        const Duration(milliseconds: 400),
        () => mounted ? _rebuscar() : null,
      );
    }
  }

  FiltrosBusca _com({
    String? texto,
    int? Function()? modalidade,
    int? Function()? categoria,
    int? Function()? nivel,
    int? raio,
    DateTime? Function()? data,
    String? cidade,
    String? horario,
  }) => FiltrosBusca(
    cidade: cidade ?? f.cidade,
    horario: horario ?? f.horario,
    texto: texto ?? f.texto,
    idModalidade: modalidade != null ? modalidade() : f.idModalidade,
    idCategoriaEtaria: categoria != null ? categoria() : f.idCategoriaEtaria,
    idNivelTecnico: nivel != null ? nivel() : f.idNivelTecnico,
    raioKm: raio ?? f.raioKm,
    data: data != null ? data() : f.data,
  );

  String _nome(List<ItemReferencia> lista, int? id, String todos) =>
      lista.where((i) => i.id == id).map((i) => i.nome).firstOrNull ?? todos;

  @override
  Widget build(BuildContext context) {
    final refs = AppScope.of(context).referencias;
    final dataTexto = f.data == null ? null : Formatos.dataNumerica(f.data!);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
      children: [
        const PageTitle(
          'Tem jogo esperando pelo seu time.',
          subtitle: 'Encontre um adversário e dê o primeiro passe.',
        ),
        TextField(
          controller: texto,
          onChanged: (v) => _aplicar(_com(texto: v), imediato: false),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Busque um time, cidade ou região',
          ),
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (id, nome) in [
                      (null, 'Todos'),
                      for (final m in refs.modalidades) (m.id, m.nome),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: ChoiceChip(
                          label: Text(nome),
                          selected: f.idModalidade == id,
                          onSelected: (_) =>
                              _aplicar(_com(modalidade: () => id)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: widget.onMap,
              icon: const Icon(Icons.map_outlined, size: 16),
              label: const Text('Mapa'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text(
                'FILTROS',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppColors.muted,
                  letterSpacing: 1,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _showFilters(refs),
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('Filtros'),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Wrap(
          spacing: 7,
          children: [
            TagPill('${f.raioKm} km'),
            TagPill(
              _nome(
                refs.categoriasEtarias,
                f.idCategoriaEtaria,
                'Todas as categorias',
              ),
            ),
            TagPill(
              _nome(refs.niveisTecnicos, f.idNivelTecnico, 'Todos os níveis'),
            ),
            if (dataTexto != null) TagPill(dataTexto),
            if (f.cidade.isNotEmpty) TagPill(f.cidade),
            if (f.horario.isNotEmpty) TagPill('A partir de ${f.horario}'),
          ],
        ),
        const SizedBox(height: 13),
        FutureBuilder<List<AnuncioPartida>>(
          future: _resultados,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(30),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.green),
                ),
              );
            }
            if (snap.hasError) {
              return ErroCarregamento(
                mensagem: '${snap.error}',
                onTentar: () => _rebuscar(),
              );
            }
            final results = snap.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${results.length} jogos disponíveis · ${dataTexto ?? 'Qualquer data'}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                const SizedBox(height: 10),
                if (results.isEmpty)
                  EmptyState(
                    title: 'Nenhum rival por aqui. Ainda.',
                    message: 'Amplie a distância ou tente outros filtros.',
                    action: TextButton(
                      onPressed: _clear,
                      child: const Text('Limpar filtros'),
                    ),
                  ),
                for (final anuncio in results)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: AnuncioCard(
                      anuncio: anuncio,
                      onTap: () => widget.onSelectAnuncio(anuncio),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _showFilters(Referencias refs) {
    int? draftCategoria = f.idCategoriaEtaria, draftNivel = f.idNivelTecnico;
    var draftRaio = f.raioKm;
    dataController.text = f.data == null ? '' : Formatos.dataNumerica(f.data!);
    cidadeController.text = f.cidade;
    horarioController.text = f.horario;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtrar jogos',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
              ),
              const SizedBox(height: 14),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Data disponível',
                  hintText: 'Ex.: 18/07/2026',
                ),
                keyboardType: TextInputType.datetime,
                controller: dataController,
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Horário a partir de',
                  hintText: 'Ex.: 16:00',
                ),
                keyboardType: TextInputType.datetime,
                controller: horarioController,
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Cidade',
                  hintText: 'Ex.: São Paulo',
                ),
                controller: cidadeController,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: draftRaio,
                decoration: const InputDecoration(
                  labelText: 'Raio de distância',
                ),
                items: _raios
                    .map(
                      (v) => DropdownMenuItem(value: v, child: Text('$v km')),
                    )
                    .toList(),
                onChanged: (v) => update(() => draftRaio = v ?? 25),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int?>(
                initialValue: draftCategoria,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  for (final c in refs.categoriasEtarias)
                    DropdownMenuItem(value: c.id, child: Text(c.nome)),
                ],
                onChanged: (v) => update(() => draftCategoria = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int?>(
                initialValue: draftNivel,
                decoration: const InputDecoration(labelText: 'Nível do time'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  for (final n in refs.niveisTecnicos)
                    DropdownMenuItem(value: n.id, child: Text(n.nome)),
                ],
                onChanged: (v) => update(() => draftNivel = v),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _aplicar(
                        _com(
                          categoria: () => null,
                          nivel: () => null,
                          raio: 25,
                          data: () => null,
                          cidade: '',
                          horario: '',
                        ),
                      );
                    },
                    child: const Text('Limpar filtros'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      final data = Formatos.lerDataHora(
                        dataController.text,
                        '00:00',
                      );
                      final horario = horarioController.text.trim();
                      // Horário inválido é ignorado, como a data.
                      final horarioValido =
                          Formatos.lerDataHora('01/01/2000', horario) != null;
                      final cidade = cidadeController.text.trim();
                      Navigator.pop(context);
                      _aplicar(
                        _com(
                          categoria: () => draftCategoria,
                          nivel: () => draftNivel,
                          raio: draftRaio,
                          data: () => data,
                          cidade: cidade,
                          horario: horarioValido ? horario.padLeft(5, '0') : '',
                        ),
                      );
                    },
                    child: const Text('Aplicar filtros'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clear() {
    texto.clear();
    _aplicar(const FiltrosBusca());
  }
}
