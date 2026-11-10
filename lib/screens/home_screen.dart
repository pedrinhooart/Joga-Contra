import 'package:flutter/material.dart';
import '../core/formatters.dart';
import '../models/anuncio_partida.dart';
import '../models/partida.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/carregador.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onNavigate,
    required this.onSelectAnuncio,
    required this.onOpenPartida,
  });
  final ValueChanged<String> onNavigate;
  final ValueChanged<AnuncioPartida> onSelectAnuncio;
  final ValueChanged<Partida> onOpenPartida;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final time = app.time!;
    final repos = app.repositorios;
    return Carregador<(Partida?, List<AnuncioPartida>)>(
      carregar: () async => (
        // Estatísticas do time mudam com partidas e avaliações.
        await app.recarregarTime().then(
          (_) => repos.partidas.proximaDoMeuTime(),
        ),
        await repos.anuncios.buscar(const FiltroAnuncios()),
      ),
      builder: (context, dados, _) {
        final (proxima, anuncios) = dados;
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 21, 18, 28),
          children: [
            Text(
              'BOM TE VER, ${app.usuario!.primeiroNome.toUpperCase()}',
              style: const TextStyle(
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
            Text(
              'Encontre o próximo adversário para o ${time.nome}.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
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
                    value: '${time.totalPartidasRealizadas}',
                    label: 'Jogos realizados',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    icon: Icons.star_outline,
                    value: time.mediaAvaliacao == null
                        ? '–'
                        : Formatos.decimal(time.mediaAvaliacao!),
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
            if (proxima == null)
              EmptyState(
                title: 'Nenhuma partida marcada.',
                message: 'Encontre um adversário ou publique um anúncio.',
                action: TextButton(
                  onPressed: () => onNavigate('search'),
                  child: const Text('Buscar adversário'),
                ),
              )
            else
              _ProximaPartida(
                partida: proxima,
                idMeuTime: time.id,
                siglaMeuTime: time.siglaExibicao,
                escudoMeuTime: time.urlEscudo,
                nomeMeuTime: time.nome,
                onOpen: () => onOpenPartida(proxima),
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
            if (anuncios.isEmpty)
              const EmptyState(
                title: 'Nenhum rival por aqui. Ainda.',
                message:
                    'Assim que novos jogos forem anunciados, eles aparecem aqui.',
              ),
            for (final anuncio in anuncios.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: AnuncioCard(
                  anuncio: anuncio,
                  onTap: () => onSelectAnuncio(anuncio),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ProximaPartida extends StatelessWidget {
  const _ProximaPartida({
    required this.partida,
    required this.idMeuTime,
    required this.siglaMeuTime,
    this.escudoMeuTime,
    required this.nomeMeuTime,
    required this.onOpen,
  });
  final Partida partida;
  final String idMeuTime, siglaMeuTime, nomeMeuTime;
  final String? escudoMeuTime;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final adversario = partida.adversarioDe(idMeuTime);
    return Panel(
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
                Formatos.dataLonga(partida.dataHoraInicio),
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Crest(imagem: escudoMeuTime, label: siglaMeuTime),
              Expanded(
                child: Text(
                  nomeMeuTime,
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
                  adversario.nome,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              Crest(
                imagem: adversario.urlEscudo,
                label: adversario.siglaExibicao,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 15,
                color: AppColors.green,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${partida.nomeLocal} · ${Formatos.hora(partida.dataHoraInicio)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
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
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onSearch, required this.onCreate});
  final VoidCallback onSearch, onCreate;
  @override
  // Altura mínima, não fixa: em telas estreitas ou com fonte maior, os botões
  // quebram de linha e o banner cresce em vez de cortar o conteúdo.
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AppColors.forest,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: PitchLinesPainter()),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.forest,
                  Color(0xE6123D2B),
                  Color(0x55123D2B),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 300),
            child: IntrinsicHeight(
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
