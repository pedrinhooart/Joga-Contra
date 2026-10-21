import 'package:flutter/material.dart';
import '../models/game.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    required this.games,
    required this.query,
    required this.sport,
    required this.onQuery,
    required this.onSport,
    required this.onSelectGame,
    required this.onMap,
  });
  final List<Game> games;
  final String query, sport;
  final ValueChanged<String> onQuery, onSport;
  final ValueChanged<Game> onSelectGame;
  final VoidCallback onMap;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String category = 'Todas', level = 'Todos', distance = '25', date = '';
  @override
  Widget build(BuildContext context) {
    final results = widget.games.where((g) {
      final matchesQuery = '${g.name} ${g.city} ${g.place}'
          .toLowerCase()
          .contains(widget.query.toLowerCase());
      final matchesDate =
          date.isEmpty ||
          (date.endsWith('18')
              ? g.date.contains('18')
              : date.endsWith('19')
              ? g.date.contains('19')
              : false);
      return (widget.sport == 'Todos' || g.sport == widget.sport) &&
          (category == 'Todas' || g.category == category) &&
          (level == 'Todos' || g.level == level) &&
          double.parse(g.distance.replaceAll(',', '.').split(' ').first) <=
              double.parse(distance) &&
          matchesDate &&
          matchesQuery;
    }).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
      children: [
        const PageTitle(
          'Tem jogo esperando pelo seu time.',
          subtitle: 'Encontre um adversário e dê o primeiro passe.',
        ),
        TextField(
          onChanged: widget.onQuery,
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
                  children: ['Todos', 'Futebol', 'Futsal']
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: ChoiceChip(
                            label: Text(s),
                            selected: widget.sport == s,
                            onSelected: (_) => widget.onSport(s),
                          ),
                        ),
                      )
                      .toList(),
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
              onPressed: _showFilters,
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('Filtros'),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Wrap(
          spacing: 7,
          children: [
            TagPill('$distance km'),
            TagPill(category == 'Todas' ? 'Todas as categorias' : category),
            TagPill(level == 'Todos' ? 'Todos os níveis' : level),
            if (date.isNotEmpty) TagPill(date),
          ],
        ),
        const SizedBox(height: 13),
        Text(
          '${results.length} jogos disponíveis · ${date.isEmpty ? 'Qualquer data' : date}',
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
        for (final game in results)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: GameCard(game: game, onTap: () => widget.onSelectGame(game)),
          ),
      ],
    );
  }

  Future<void> _showFilters() async {
    var draftCategory = category,
        draftLevel = level,
        draftDistance = distance,
        draftDate = date;
    await showModalBottomSheet<void>(
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
                  hintText: 'Ex.: 18 ou 19',
                ),
                controller: TextEditingController(text: draftDate),
                onChanged: (v) => draftDate = v,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField(
                initialValue: draftDistance,
                decoration: const InputDecoration(
                  labelText: 'Raio de distância',
                ),
                items: ['5', '10', '25', '50', '100']
                    .map(
                      (v) => DropdownMenuItem(value: v, child: Text('$v km')),
                    )
                    .toList(),
                onChanged: (v) => update(() => draftDistance = v ?? '25'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField(
                initialValue: draftCategory,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items:
                    ['Todas', 'Livre', 'Sub-15', 'Sub-17', 'Sub-20', 'Veterano']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                onChanged: (v) => update(() => draftCategory = v ?? 'Todas'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField(
                initialValue: draftLevel,
                decoration: const InputDecoration(labelText: 'Nível do time'),
                items: ['Todos', 'Recreativo', 'Intermediário', 'Avançado']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => update(() => draftLevel = v ?? 'Todos'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        category = 'Todas';
                        level = 'Todos';
                        distance = '25';
                        date = '';
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Limpar filtros'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        category = draftCategory;
                        level = draftLevel;
                        distance = draftDistance;
                        date = draftDate;
                      });
                      Navigator.pop(context);
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
    setState(() {
      category = 'Todas';
      level = 'Todos';
      distance = '25';
      date = '';
    });
    widget.onQuery('');
    widget.onSport('Todos');
  }
}
