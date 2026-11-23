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
    this.data,
    this.cidade = '',
    this.horario = '',
  });
  final String texto, cidade, horario;
  final int? idModalidade, idCategoriaEtaria, idNivelTecnico;
  final DateTime? data;

  FiltroAnuncios get consulta => FiltroAnuncios(
    texto: texto.trim().isEmpty ? null : texto.trim(),
    idModalidade: idModalidade,
    idCategoriaEtaria: idCategoriaEtaria,
    idNivelTecnico: idNivelTecnico,
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
            // Em telas estreitas, quebra a linha em vez de cortar o texto.
            hintMaxLines: 2,
          ),
        ),
        const SizedBox(height: 14),
        const _Rotulo('TIPO DE JOGO'),
        const SizedBox(height: 6),
        // Todas as opções à vista, quebrando a linha quando preciso: nenhum
        // nome fica cortado nem escondido atrás da rolagem.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (id, nome) in [
              (null, 'Todos'),
              for (final m in refs.modalidades) (m.id, m.nome),
            ])
              ChipFiltro(
                nome,
                selecionado: f.idModalidade == id,
                onTap: () => _aplicar(_com(modalidade: () => id)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Com fonte grande (acessibilidade), os botões descem para a linha de
        // baixo em vez de transbordar.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          children: [
            const _Rotulo('FILTROS'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showFilters(refs),
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Filtros'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onMap,
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('Mapa'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 3),
        Wrap(
          spacing: 7,
          children: [
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
                    message: 'Tente outro tipo de jogo, data ou cidade.',
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
    int? draftNivel = f.idNivelTecnico;
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
              // Sem filtro de categoria: os anúncios novos não têm categoria.
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
              // Fonte grande: "Aplicar" desce para a linha de baixo, sem transbordar.
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _aplicar(
                          _com(
                            categoria: () => null,
                            nivel: () => null,
                            data: () => null,
                            cidade: '',
                            horario: '',
                          ),
                        );
                      },
                      child: const Text('Limpar filtros'),
                    ),
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
                            categoria: () => null,
                            nivel: () => draftNivel,
                            data: () => data,
                            cidade: cidade,
                            horario: horarioValido
                                ? horario.padLeft(5, '0')
                                : '',
                          ),
                        );
                      },
                      child: const Text('Aplicar filtros'),
                    ),
                  ],
                ),
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

/// Título de seção da busca ("TIPO DE JOGO", "FILTROS").
class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: const TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w800,
      color: AppColors.muted,
      letterSpacing: 1,
    ),
  );
}
