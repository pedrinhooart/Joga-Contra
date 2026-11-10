import 'package:flutter/material.dart';
import '../core/formatters.dart';
import '../models/anuncio_partida.dart';
import '../models/notificacao.dart';
import '../models/partida.dart';
import '../models/referencia.dart';
import '../models/usuario.dart';
import '../services/municipios.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/campo_cidade.dart';
import '../widgets/carregador.dart';
import '../widgets/common.dart';

void _avisar(BuildContext context, String mensagem) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );

class AdsScreen extends StatelessWidget {
  const AdsScreen({
    super.key,
    required this.onCreate,
    required this.onEdit,
    required this.onConversations,
  });
  final VoidCallback onCreate, onConversations;
  final ValueChanged<AnuncioPartida> onEdit;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.repos(context).anuncios;
    return Carregador<List<AnuncioPartida>>(
      carregar: repo.listarDoMeuTime,
      builder: (context, ads, recarregar) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
        children: [
          const PageTitle(
            'Seus anúncios, suas próximas partidas.',
            subtitle:
                'Gerencie seus jogos e encontre quem está pronto para jogar.',
          ),
          ActionButton('Novo anúncio', icon: Icons.add, onPressed: onCreate),
          const SizedBox(height: 12),
          if (ads.isEmpty)
            EmptyState(
              title: 'Seu próximo jogo começa aqui.',
              message: 'Você ainda não publicou um anúncio.',
              action: ActionButton('Anunciar jogo', onPressed: onCreate),
            ),
          for (final ad in ads)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AnuncioPainel(
                ad: ad,
                onEdit: () => onEdit(ad),
                onToggle: () async {
                  try {
                    await repo.alterarStatus(
                      ad.id,
                      ad.status == StatusAnuncio.pausado
                          ? StatusAnuncio.ativo
                          : StatusAnuncio.pausado,
                    );
                    recarregar();
                  } catch (e) {
                    if (context.mounted) _avisar(context, '$e');
                  }
                },
                onDelete: () => _excluir(context, ad, recarregar),
                onConversations: onConversations,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _excluir(
    BuildContext context,
    AnuncioPartida ad,
    VoidCallback recarregar,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir este anúncio?'),
        content: const Text(
          'Esta ação não pode ser desfeita. Os interessados não poderão mais encontrar este jogo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim, excluir'),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    try {
      await AppScope.repos(context).anuncios.excluir(ad.id);
      recarregar();
      if (context.mounted) _avisar(context, 'Anúncio excluído.');
    } catch (e) {
      if (context.mounted) _avisar(context, '$e');
    }
  }
}

class _AnuncioPainel extends StatelessWidget {
  const _AnuncioPainel({
    required this.ad,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onConversations,
  });
  final AnuncioPartida ad;
  final VoidCallback onEdit, onToggle, onDelete, onConversations;

  @override
  Widget build(BuildContext context) {
    final pausado = ad.status == StatusAnuncio.pausado;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Crest(
                imagem: ad.time.urlEscudo,
                label: ad.time.siglaExibicao,
                small: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${ad.time.nome} · ${Formatos.dataCurta(ad.dataHoraInicio)} · ${Formatos.hora(ad.dataHoraInicio)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${ad.modalidade.nome} · ${ad.categoriaEtaria.nome} · ${ad.localExibicao}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              TagPill(
                ad.status.rotulo,
                green: ad.status == StatusAnuncio.ativo,
              ),
            ],
          ),
          const Divider(height: 20),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Editar'),
              ),
              if (ad.status == StatusAnuncio.ativo || pausado)
                TextButton(
                  onPressed: onToggle,
                  child: Text(pausado ? 'Reativar anúncio' : 'Pausar anúncio'),
                ),
              TextButton.icon(
                onPressed: onConversations,
                icon: const Icon(Icons.person_outline, size: 15),
                label: Text('Interessados · ${ad.totalSolicitacoes}'),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 15,
                  color: Colors.red,
                ),
                label: const Text(
                  'Excluir',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.onEdit,
    required this.onEditFoto,
    required this.onEditDescricao,
    required this.onGames,
    required this.onLogout,
  });
  final VoidCallback onEdit, onEditFoto, onEditDescricao, onGames, onLogout;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final time = app.time!;
    final repos = app.repositorios;
    return Carregador<(List<Partida>, List<AvaliacaoRecebida>)>(
      carregar: () async => (
        (await repos.partidas.listarDoMeuTime())
            .where((p) => p.status == StatusPartida.realizada)
            .toList(),
        await repos.partidas.avaliacoesDoTime(time.id),
      ),
      builder: (context, dados, _) {
        final (historico, avaliacoes) = dados;
        final avaliacao = avaliacoes.firstOrNull;
        final local = [
          time.localExibicao,
          if (time.anoFundacao != null) 'Desde ${time.anoFundacao}',
        ].join(' · ');
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
          children: [
            const PageTitle(
              'Seu time. Sua identidade.',
              subtitle:
                  'Dentro e fora de campo, esse é o seu cartão de visita.',
            ),
            Container(
              height: 84,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.forest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const CustomPaint(
                painter: PitchLinesPainter(),
                size: Size.infinite,
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -20),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Tocar no escudo troca a foto do time.
                        Semantics(
                          button: true,
                          label: 'Alterar foto do time',
                          child: GestureDetector(
                            onTap: onEditFoto,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Crest(
                                  imagem: time.urlEscudo,
                                  label: time.siglaExibicao,
                                  ano: time.anoFundacao,
                                ),
                                Positioned(
                                  right: -6,
                                  bottom: -6,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: AppColors.forest,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.photo_camera_outlined,
                                      size: 13,
                                      color: AppColors.lime,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                time.nome,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 19,
                                ),
                              ),
                              Text(
                                '⌖  $local',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: onEdit,
                          tooltip: 'Editar nome do time',
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: AppColors.green,
                          ),
                        ),
                      ],
                    ),
                    // Modalidade, categoria, nível e quantidade são de cada
                    // anúncio, não do time: não aparecem no perfil.
                    const Divider(height: 28),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Sobre o time',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onEditDescricao,
                          tooltip: 'Editar descrição',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: AppColors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (time.descricao?.trim().isNotEmpty ?? false)
                          ? time.descricao!
                          : 'Conte a história do seu time para os adversários.',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      [
                        'Responsável   ${time.nomeCapitao ?? app.usuario!.nome}',
                        if (time.telefoneContato != null)
                          'Contato           ${time.telefoneContato}',
                      ].join('\n'),
                      style: const TextStyle(fontSize: 11, height: 1.8),
                    ),
                    const Divider(height: 22),
                    const Text(
                      'Histórico de jogos',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    if (historico.isEmpty)
                      const Text(
                        'Nenhuma partida realizada ainda.',
                        style: TextStyle(fontSize: 10, color: AppColors.muted),
                      ),
                    for (final p in historico.take(2)) ...[
                      Text(
                        '${time.nome}   ${p.placarPara(time.id)}   ${p.adversarioDe(time.id).nome}     ${Formatos.dataHistorico(p.dataHoraInicio)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        Expanded(
                          child: _ProfileStat(
                            value: '${time.totalPartidasRealizadas}',
                            label: 'Jogos realizados',
                          ),
                        ),
                        Expanded(
                          child: _ProfileStat(
                            value: time.mediaAvaliacao == null
                                ? '–'
                                : '${Formatos.decimal(time.mediaAvaliacao!)} ★',
                            label: 'Avaliação geral',
                          ),
                        ),
                      ],
                    ),
                    if (avaliacao != null) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Quem já jogou com a gente',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${'★' * avaliacao.notaMedia.round()}${avaliacao.comentario == null ? '' : '\n“${avaliacao.comentario}”'}',
                        style: const TextStyle(
                          color: AppColors.green,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    ActionButton(
                      'Ver todos os jogos',
                      icon: Icons.arrow_forward,
                      outline: true,
                      expand: true,
                      onPressed: onGames,
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout, size: 16),
                      label: const Text('Sair da conta'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 19,
          color: AppColors.forest,
        ),
      ),
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 9)),
    ],
  );
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.onOpen});
  final ValueChanged<Notificacao> onOpen;

  IconData _icone(TipoNotificacao t) => switch (t) {
    TipoNotificacao.partidaConfirmada => Icons.check,
    TipoNotificacao.mensagemRecebida ||
    TipoNotificacao.solicitacaoRecebida => Icons.chat_bubble_outline,
    _ => Icons.notifications_none,
  };

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.repos(context).notificacoes;
    return Carregador<List<Notificacao>>(
      carregar: repo.listar,
      builder: (context, lista, _) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
        children: [
          const PageTitle(
            'O jogo não para.',
            subtitle: 'Fique por dentro de tudo que acontece com o seu time.',
          ),
          if (lista.isEmpty)
            const EmptyState(
              title: 'Tudo tranquilo por aqui.',
              message: 'Avisaremos quando houver novidades do seu time.',
            )
          else
            Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < lista.length; i++) ...[
                    InkWell(
                      onTap: () {
                        if (!lista[i].lida) {
                          // Falha ao marcar não deve impedir abrir o destino.
                          repo.marcarComoLida(lista[i].id).catchError((_) {});
                        }
                        onOpen(lista[i]);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFFEAF4E8),
                              child: Icon(
                                _icone(lista[i].tipo),
                                size: 18,
                                color: AppColors.green,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lista[i].titulo,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    lista[i].mensagem,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 10,
                                      height: 1.45,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    Formatos.relativo(lista[i].dataCriacao),
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppColors.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (i < lista.length - 1)
                      const Divider(height: 1, indent: 14, endIndent: 14),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Mapa ilustrativo: os marcadores não usam coordenadas reais. Integração com
/// mapa e geolocalização é decisão pendente.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.onSelect});
  final ValueChanged<AnuncioPartida> onSelect;
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  AnuncioPartida? selected;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Carregador<List<AnuncioPartida>>(
      carregar: () => app.repositorios.anuncios.buscar(const FiltroAnuncios()),
      builder: (context, anuncios, _) {
        final atual = anuncios.contains(selected)
            ? selected
            : anuncios.firstOrNull;
        final marcadores = anuncios.take(5).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 25),
          children: [
            const PageTitle(
              'O futebol acontece perto de você.',
              subtitle: 'Explore os campos, quadras e times da sua região.',
            ),
            Container(
              height: 300,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFE8EFE4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 40,
                    right: 25,
                    top: 80,
                    child: Transform.rotate(
                      angle: -.2,
                      child: Container(height: 20, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    left: -30,
                    right: -20,
                    top: 180,
                    child: Transform.rotate(
                      angle: .12,
                      child: Container(height: 24, color: Colors.white),
                    ),
                  ),
                  const Positioned(
                    left: 22,
                    top: 145,
                    child: Chip(
                      avatar: Icon(Icons.my_location, size: 14),
                      label: Text(
                        'Você está aqui',
                        style: TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
                  for (var i = 0; i < marcadores.length; i++)
                    Positioned(
                      left: 35.0 + i * 65,
                      top: 80.0 + (i % 2) * 95,
                      child: GestureDetector(
                        onTap: () => setState(() => selected = marcadores[i]),
                        child: const CircleAvatar(
                          backgroundColor: AppColors.forest,
                          child: Text('⚽', style: TextStyle(fontSize: 17)),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Text(
                      'Mapa ilustrativo · ${app.time!.localExibicao}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            if (atual == null)
              const EmptyState(
                title: 'Nenhum rival por aqui. Ainda.',
                message:
                    'Assim que novos jogos forem anunciados, eles aparecem aqui.',
              )
            else ...[
              Text(
                'Perto de você · ${atual.time.nome}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              AnuncioCard(anuncio: atual, onTap: () => widget.onSelect(atual)),
              for (final g in anuncios.where((g) => g.id != atual.id).take(2))
                ListTile(
                  leading: Crest(
                    imagem: g.time.urlEscudo,
                    label: g.time.siglaExibicao,
                    small: true,
                  ),
                  title: Text(
                    g.time.nome,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    [
                      if (g.distanciaKm != null)
                        Formatos.distancia(g.distanciaKm!),
                      g.modalidade.nome,
                    ].join(' · '),
                    style: const TextStyle(fontSize: 10),
                  ),
                  onTap: () => setState(() => selected = g),
                ),
            ],
          ],
        );
      },
    );
  }
}

class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({
    super.key,
    required this.idPartida,
    required this.onChat,
    required this.onCancel,
  });
  final String idPartida;
  final ValueChanged<String> onChat;
  final ValueChanged<Partida> onCancel;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final meuTime = app.time!;
    return Carregador<Partida>(
      carregar: () => app.repositorios.partidas.obter(idPartida),
      builder: (context, partida, _) {
        final adversario = partida.adversarioDe(meuTime.id);
        final cancelada = partida.status == StatusPartida.cancelada;
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
          children: [
            Icon(
              cancelada ? Icons.cancel : Icons.check_circle,
              color: cancelada ? AppColors.muted : AppColors.green,
              size: 52,
            ),
            const SizedBox(height: 9),
            Text(
              switch (partida.status) {
                StatusPartida.confirmada => 'AGORA É SÓ ENTRAR EM CAMPO',
                StatusPartida.realizada => 'APITO FINAL',
                StatusPartida.cancelada => 'PARTIDA CANCELADA',
              },
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 9,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              switch (partida.status) {
                StatusPartida.confirmada => 'Partida confirmada!',
                StatusPartida.realizada => 'Partida realizada',
                StatusPartida.cancelada => 'Partida cancelada',
              },
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            if (partida.status == StatusPartida.confirmada)
              const Text(
                'Chame a equipe. Seu próximo jogo já tem dia e hora.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            const SizedBox(height: 18),
            Panel(
              child: Column(
                children: [
                  TagPill('Amistoso · ${partida.modalidade.nome}', green: true),
                  const SizedBox(height: 17),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Crest(
                              imagem: meuTime.urlEscudo,
                              label: meuTime.siglaExibicao,
                            ),
                            Text(
                              meuTime.nome,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              meuTime.localExibicao,
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        'VS',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.muted,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Crest(
                              imagem: adversario.urlEscudo,
                              label: adversario.siglaExibicao,
                            ),
                            Text(
                              adversario.nome,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              adversario.localExibicao,
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _Info(
                    icon: Icons.calendar_today_outlined,
                    label: 'Data',
                    value: Formatos.dataComAno(partida.dataHoraInicio),
                  ),
                  _Info(
                    icon: Icons.access_time,
                    label: 'Horário',
                    value: Formatos.hora(partida.dataHoraInicio),
                  ),
                  _Info(
                    icon: Icons.place_outlined,
                    label: 'Local',
                    value: [
                      partida.nomeLocal,
                      [
                        if (partida.endereco != null) partida.endereco!,
                        '${partida.cidade}, ${partida.siglaEstado}',
                      ].join(' · '),
                    ].join('\n'),
                  ),
                  const SizedBox(height: 8),
                  ActionButton(
                    'Abrir localização',
                    outline: true,
                    icon: Icons.place_outlined,
                    expand: true,
                    // Pendente: abrir app de mapas (requer url_launcher).
                    onPressed: () => _avisar(
                      context,
                      'Abrir no mapa estará disponível em breve.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  ActionButton(
                    'Conversar',
                    icon: Icons.chat_bubble_outline,
                    expand: true,
                    onPressed: () => onChat(partida.idSolicitacao),
                  ),
                  if (partida.status == StatusPartida.confirmada)
                    TextButton(
                      onPressed: () => onCancel(partida),
                      child: const Text(
                        'Cancelar partida',
                        style: TextStyle(color: Colors.red, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.green),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: AppColors.muted),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    ),
  );
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.partida,
    required this.onSubmit,
  });
  final Partida partida;
  final Future<void> Function(NovaAvaliacao) onSubmit;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final ratings = <int, int>{};
  final comentario = TextEditingController();
  bool enviando = false;

  @override
  void dispose() {
    comentario.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final criterios = app.referencias.criteriosAvaliacao;
    final adversario = widget.partida.adversarioDe(app.time!.id);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
      children: [
        const PageTitle(
          'Como foi o jogo?',
          subtitle:
              'Sua avaliação ajuda a construir uma comunidade que joga junto.',
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Crest(
                    imagem: adversario.urlEscudo,
                    label: adversario.siglaExibicao,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          adversario.nome,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${Formatos.dataCurta(widget.partida.dataHoraInicio)} · ${widget.partida.nomeLocal}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final criterio in criterios)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        criterio.nome,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (var star = 1; star <= 5; star++)
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 27),
                        onPressed: () =>
                            setState(() => ratings[criterio.id] = star),
                        icon: Icon(
                          Icons.star,
                          size: 21,
                          color: (ratings[criterio.id] ?? 0) >= star
                              ? const Color(0xFFF2B844)
                              : const Color(0xFFDCE1DC),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 10),
              TextField(
                controller: comentario,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Deixe um comentário',
                  hintText:
                      'Conte como foi a experiência de jogar com esse time.',
                ),
              ),
              const SizedBox(height: 12),
              ActionButton(
                enviando ? 'Enviando…' : 'Enviar avaliação',
                icon: Icons.star,
                expand: true,
                onPressed: enviando ? null : () => _enviar(criterios),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _enviar(List<ItemReferencia> criterios) async {
    if (ratings.length < criterios.length) {
      _avisar(context, 'Avalie todos os critérios antes de enviar.');
      return;
    }
    setState(() => enviando = true);
    try {
      await widget.onSubmit(
        NovaAvaliacao(
          idPartida: widget.partida.id,
          notas: Map.of(ratings),
          comentario: comentario.text.trim().isEmpty
              ? null
              : comentario.text.trim(),
        ),
      );
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.page,
    required this.onPage,
    required this.onDone,
  });
  final String page;
  final ValueChanged<String> onPage;

  /// Chamado após sucesso com a mensagem a exibir.
  final ValueChanged<String> onDone;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final nome = TextEditingController(),
      email = TextEditingController(),
      senha = TextEditingController(),
      nomeTime = TextEditingController(),
      cidade = TextEditingController();
  String? estado;
  bool enviando = false;

  static const _senhaMinima = 8;

  @override
  void dispose() {
    for (final c in [nome, email, senha, nomeTime, cidade]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _obrigatorio(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null;

  String? _email(String? v) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v?.trim() ?? '')
      ? null
      : 'Informe um e-mail válido';

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    final refs = AppScope.of(context).referencias;
    final title = page == 'login'
        ? 'Seu time em campo.'
        : page == 'forgot'
        ? 'Recupere seu acesso'
        : 'Vamos começar?';
    return Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 40, 22, 30),
        children: [
          const Center(child: BrandMark()),
          const SizedBox(height: 38),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.forest,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'O próximo rival.\nA próxima história.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 23,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'O futebol conecta. A gente dá o primeiro passe.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 23),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
          ),
          const SizedBox(height: 5),
          Text(
            page == 'forgot'
                ? 'Informe seu e-mail para receber um link de recuperação.'
                : page == 'register'
                ? 'Cadastre os dados do responsável e do seu time.'
                : 'Entre e encontre o próximo adversário.',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 17),
          if (page == 'register') ...[
            TextFormField(
              controller: nome,
              decoration: const InputDecoration(
                labelText: 'Nome do responsável',
                hintText: 'Seu nome',
              ),
              validator: _obrigatorio,
            ),
            const SizedBox(height: 10),
          ],
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'E-mail',
              hintText: 'voce@email.com',
            ),
            validator: _email,
          ),
          if (page != 'forgot') ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: senha,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(
                labelText: 'Senha',
                hintText: 'Pelo menos $_senhaMinima caracteres',
              ),
              validator: (v) =>
                  page == 'register' && (v ?? '').length < _senhaMinima
                  ? 'A senha precisa de pelo menos $_senhaMinima caracteres'
                  : (v ?? '').isEmpty
                  ? 'Informe a senha'
                  : null,
            ),
          ],
          if (page == 'register') ..._camposTime(refs),
          if (page == 'login')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => widget.onPage('forgot'),
                child: const Text('Esqueci minha senha'),
              ),
            )
          else
            const SizedBox(height: 14),
          ActionButton(
            enviando
                ? 'Aguarde…'
                : page == 'forgot'
                ? 'Enviar link'
                : page == 'register'
                ? 'Criar perfil do time'
                : 'Entrar',
            icon: Icons.arrow_forward,
            expand: true,
            onPressed: enviando ? null : _enviar,
          ),
          const SizedBox(height: 8),
          if (page == 'login')
            OutlinedButton(
              onPressed: () => _avisar(
                context,
                'O login com Google estará disponível na versão conectada.',
              ),
              child: const Text('G   Entrar com Google'),
            ),
          Center(
            child: TextButton(
              onPressed: () =>
                  widget.onPage(page == 'register' ? 'login' : 'register'),
              child: Text(
                page == 'register'
                    ? 'Já tem conta? Entrar'
                    : 'Ainda não tem conta? Criar conta',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Só o necessário para a conta. Modalidade, categoria, nível e quantidade
  /// de jogadores são informados em cada anúncio de partida.
  List<Widget> _camposTime(Referencias refs) {
    return [
      const SizedBox(height: 10),
      TextFormField(
        controller: nomeTime,
        decoration: const InputDecoration(
          labelText: 'Nome do time',
          hintText: 'Ex.: União FC',
        ),
        validator: _obrigatorio,
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: estado,
        decoration: const InputDecoration(labelText: 'Estado'),
        items: refs.estados
            .map((e) => DropdownMenuItem(value: e.sigla, child: Text(e.sigla)))
            .toList(),
        onChanged: (v) => setState(() {
          // Cidade de outro estado nunca fica selecionada por engano.
          if (v != estado) cidade.clear();
          estado = v;
        }),
        validator: (v) => v == null ? 'Selecione o estado' : null,
      ),
      const SizedBox(height: 10),
      CampoCidade(controller: cidade, siglaEstado: estado),
    ];
  }

  Future<void> _enviar() async {
    if (!form.currentState!.validate()) return;
    final app = AppScope.of(context);
    setState(() => enviando = true);
    try {
      switch (widget.page) {
        case 'forgot':
          await app.repositorios.auth.solicitarRecuperacaoSenha(
            email.text.trim(),
          );
          widget.onDone(
            'Se o e-mail estiver cadastrado, você receberá um link de recuperação.',
          );
        case 'register':
          // O validador da cidade já exigiu a lista carregada.
          final municipios = Municipios.carregado!;
          await app.cadastrar(
            CadastroCapitao(
              nome: nome.text.trim(),
              email: email.text.trim().toLowerCase(),
              senha: senha.text,
              nomeTime: nomeTime.text.trim(),
              // Nome oficial do IBGE, mesmo se digitado sem acento.
              cidade: municipios.oficial(estado!, cidade.text)!,
              siglaEstado: estado!,
            ),
          );
          widget.onDone('Bem-vindo ao Joga Contra!');
        default:
          await app.entrar(email.text.trim().toLowerCase(), senha.text);
          widget.onDone('Bem-vindo ao Joga Contra!');
      }
    } catch (e) {
      if (mounted) _avisar(context, '$e');
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }
}
