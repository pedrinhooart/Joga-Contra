import 'package:flutter/material.dart';
import '../models/game.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class GameDetailScreen extends StatelessWidget {
  const GameDetailScreen({
    super.key,
    required this.game,
    required this.onInterest,
  });
  final Game game;
  final VoidCallback onInterest;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
    children: [
      const PageTitle(
        'Tem jogo esperando pelo seu time.',
        subtitle: 'Confira os detalhes e dê o primeiro passe.',
      ),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Crest(label: game.crest),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TagPill('Procurando adversário', green: true),
                      const SizedBox(height: 7),
                      Text(
                        game.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        '${game.city} · ${game.distance} de você',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 6,
              children: [
                TagPill(game.sport, green: true),
                TagPill(game.category),
                TagPill(game.level),
              ],
            ),
            const Divider(height: 24),
            for (final row in [
              (Icons.calendar_today_outlined, 'Data', '${game.date} de 2026'),
              (Icons.access_time, 'Horário', game.time),
              (Icons.place_outlined, 'Local', game.place),
              (Icons.home_outlined, 'Mando de campo', game.home),
              (
                Icons.people_outline,
                'Jogadores',
                game.sport == 'Futsal' ? '5 por equipe' : '11 por equipe',
              ),
              (Icons.sports_soccer, 'Aluguel do espaço', 'R\$ 120 por time'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Row(
                  children: [
                    Icon(row.$1, size: 18, color: AppColors.green),
                    const SizedBox(width: 11),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.$2,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                        Text(
                          row.$3,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const Text(
              'Sobre o jogo',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Estamos procurando um time parceiro para um amistoso! A ideia é jogar uma boa partida, com respeito e muita bola no pé. O espaço já está reservado. Podemos dividir a taxa do campo. Bora jogar?',
              style: TextStyle(
                height: 1.55,
                color: AppColors.muted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4E8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.green, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Compromisso e respeito dentro e fora de campo.',
                      style: TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ActionButton(
              'Tenho interesse',
              icon: Icons.sports_soccer,
              expand: true,
              onPressed: onInterest,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Panel(
        child: Column(
          children: [
            Crest(label: game.crest),
            const SizedBox(height: 8),
            Text(
              game.name,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Text(
              game.city,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            const SizedBox(height: 9),
            const Text(
              '★ 4,9 · 12 avaliações',
              style: TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '24 jogos realizados · Fundação 2010',
              style: TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 12),
            const Text(
              'Um time de amigos, um só futebol. A gente joga pela resenha, pela amizade e por aquele gol no último minuto.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            const TagPill('✓  Time verificado', green: true),
          ],
        ),
      ),
    ],
  );
}
