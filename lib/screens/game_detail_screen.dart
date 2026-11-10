import 'package:flutter/material.dart';
import '../core/formatters.dart';
import '../models/anuncio_partida.dart';
import '../models/time.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/carregador.dart';
import '../widgets/common.dart';

class GameDetailScreen extends StatelessWidget {
  const GameDetailScreen({
    super.key,
    required this.anuncio,
    required this.onInterest,
  });
  final AnuncioPartida anuncio;
  final VoidCallback onInterest;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final proprio = anuncio.time.id == app.time?.id;
    return Carregador<Time>(
      carregar: () => app.repositorios.times.buscar(anuncio.time.id),
      builder: (context, time, _) => ListView(
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
                    Crest(
                      imagem: anuncio.time.urlEscudo,
                      label: anuncio.time.siglaExibicao,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TagPill(
                            anuncio.aceitaSolicitacoes
                                ? 'Procurando adversário'
                                : anuncio.status.rotulo,
                            green: anuncio.aceitaSolicitacoes,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            anuncio.time.nome,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            anuncio.distanciaKm == null
                                ? anuncio.localExibicao
                                : '${anuncio.localExibicao} · ${Formatos.distancia(anuncio.distanciaKm!)} de você',
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
                  runSpacing: 6,
                  children: [
                    TagPill(anuncio.modalidade.nome, green: true),
                    TagPill(anuncio.categoriaEtaria.nome),
                    if (anuncio.nivelTecnico != null)
                      TagPill(anuncio.nivelTecnico!.nome),
                  ],
                ),
                const Divider(height: 24),
                for (final row in [
                  (
                    Icons.calendar_today_outlined,
                    'Data',
                    Formatos.dataComAno(anuncio.dataHoraInicio),
                  ),
                  (
                    Icons.access_time,
                    'Horário',
                    Formatos.hora(anuncio.dataHoraInicio),
                  ),
                  (
                    Icons.place_outlined,
                    'Local',
                    [
                      anuncio.nomeLocal,
                      if (anuncio.bairro != null) anuncio.bairro!,
                    ].join(' · '),
                  ),
                  if (anuncio.mandoCampo != null)
                    (
                      Icons.home_outlined,
                      'Mando de campo',
                      anuncio.mandoCampo!.nome,
                    ),
                  (
                    Icons.people_outline,
                    'Jogadores',
                    '${anuncio.quantidadeJogadores} por equipe',
                  ),
                  if (anuncio.valorAluguelPorTime != null)
                    (
                      Icons.sports_soccer,
                      'Aluguel do espaço',
                      anuncio.valorAluguelPorTime == 0
                          ? 'Sem custo'
                          : '${Formatos.moeda(anuncio.valorAluguelPorTime!)} por time',
                    ),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 13),
                    child: Row(
                      children: [
                        Icon(row.$1, size: 18, color: AppColors.green),
                        const SizedBox(width: 11),
                        // Local ou endereço longo quebra a linha, sem estourar.
                        Expanded(
                          child: Column(
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
                        ),
                      ],
                    ),
                  ),
                if (anuncio.descricao?.trim().isNotEmpty ?? false) ...[
                  const Text(
                    'Sobre o jogo',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    anuncio.descricao!,
                    style: const TextStyle(
                      height: 1.55,
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 13),
                ],
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF4E8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: AppColors.green,
                        size: 18,
                      ),
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
                  proprio ? 'Este anúncio é do seu time' : 'Tenho interesse',
                  icon: Icons.sports_soccer,
                  expand: true,
                  onPressed: anuncio.aceitaSolicitacoes && !proprio
                      ? onInterest
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(
              children: [
                Crest(
                  imagem: time.urlEscudo,
                  label: time.siglaExibicao,
                  ano: time.anoFundacao,
                ),
                const SizedBox(height: 8),
                Text(
                  time.nome,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  time.localExibicao,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                const SizedBox(height: 9),
                Text(
                  time.mediaAvaliacao == null
                      ? 'Ainda sem avaliações'
                      : '★ ${Formatos.decimal(time.mediaAvaliacao!)} · ${time.totalAvaliacoes} avaliações',
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  [
                    '${time.totalPartidasRealizadas} jogos realizados',
                    if (time.anoFundacao != null)
                      'Fundação ${time.anoFundacao}',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 11),
                ),
                if (time.descricao?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 12),
                  Text(
                    time.descricao!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (time.verificado) ...[
                  const SizedBox(height: 10),
                  const TagPill('✓  Time verificado', green: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
