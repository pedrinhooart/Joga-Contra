import 'package:flutter/material.dart';
import '../models/game.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.games,
    required this.teamName,
    required this.onNavigate,
    required this.onSelectGame,
  });
  final List<Game> games;
  final String teamName;
  final ValueChanged<String> onNavigate;
  final ValueChanged<Game> onSelectGame;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 21, 18, 28),
    children: [
      const Text(
        'BOM TE VER, JOÃO',
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 1.4,
          color: AppColors.muted,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'Seu time entra em campo. ⚽',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Encontre o próximo adversário para o União FC.',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      ),
      const SizedBox(height: 20),
      _Hero(
        onSearch: () => onNavigate('search'),
        onCreate: () => onNavigate('create'),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.sports_soccer,
              value: '18',
              label: 'Jogos realizados',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.star_outline,
              value: '4,9',
              label: 'Avaliação geral',
            ),
          ),
        ],
      ),
      const SizedBox(height: 21),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Próxima partida',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(
            onPressed: () => onNavigate('games'),
            child: const Text('Ver jogos'),
          ),
        ],
      ),
      Panel(
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Confirmada',
                    style: TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                Text(
                  'Sábado, 18 de julho',
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                const Crest(),
                Expanded(
                  child: Text(
                    teamName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Text(
                  'VS',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Real Amigos',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Crest(label: 'RA'),
              ],
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.place_outlined, size: 15, color: AppColors.green),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Campo do Ibirapuera · 16:00',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ActionButton(
              'Ver partida',
              expand: true,
              outline: true,
              icon: Icons.arrow_forward,
              onPressed: () => onNavigate('confirmed'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Jogos perto de você',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(
            onPressed: () => onNavigate('search'),
            child: const Text('Ver todos'),
          ),
        ],
      ),
      for (final game in games.take(2))
        Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: GameCard(game: game, onTap: () => onSelectGame(game)),
        ),
    ],
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onSearch, required this.onCreate});
  final VoidCallback onSearch, onCreate;
  @override
  Widget build(BuildContext context) => Container(
    height: 340,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AppColors.forest,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: PitchLinesPainter()),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [AppColors.forest, Color(0xE6123D2B), Color(0x55123D2B)],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A BOLA VAI ROLAR',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 13),
              const Text(
                'O PRÓXIMO JOGO\nCOMEÇA AQUI.',
                style: TextStyle(
                  fontSize: 26,
                  height: 1.03,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: .4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Encontre times da sua região e marque\num amistoso de verdade.',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFD4E1D7),
                  height: 1.45,
                ),
              ),
              const Spacer(),
              Wrap(
                spacing: 8,
                children: [
                  ActionButton(
                    'Buscar adversário',
                    icon: Icons.search,
                    onPressed: onSearch,
                  ),
                  ActionButton(
                    'Anunciar jogo',
                    outline: true,
                    icon: Icons.add,
                    onPressed: onCreate,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value, label;
  @override
  Widget build(BuildContext context) => Panel(
    child: Row(
      children: [
        Icon(icon, color: AppColors.green, size: 22),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
