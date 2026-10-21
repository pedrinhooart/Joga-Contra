import 'package:flutter/material.dart';
import '../models/game.dart';
import '../repositories/mock_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class AdsScreen extends StatelessWidget {
  const AdsScreen({
    super.key,
    required this.ads,
    required this.onCreate,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onConversations,
  });
  final List<String> ads;
  final VoidCallback onCreate, onConversations;
  final ValueChanged<int> onEdit, onToggle, onDelete;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
    children: [
      const PageTitle(
        'Seus anúncios, suas próximas partidas.',
        subtitle: 'Gerencie seus jogos e encontre quem está pronto para jogar.',
      ),
      ActionButton('Novo anúncio', icon: Icons.add, onPressed: onCreate),
      const SizedBox(height: 12),
      if (ads.isEmpty)
        EmptyState(
          title: 'Seu próximo jogo começa aqui.',
          message: 'Você ainda não publicou um anúncio.',
          action: ActionButton('Anunciar jogo', onPressed: onCreate),
        ),
      for (var i = 0; i < ads.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Crest(small: true),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ads[i].split('|').first,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const Text(
                            'Futebol · Livre · São Paulo, SP',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TagPill(
                      ads[i].contains('|Pausado') ? 'Pausado' : 'Ativo',
                      green: !ads[i].contains('|Pausado'),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    TextButton.icon(
                      onPressed: () => onEdit(i),
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('Editar'),
                    ),
                    TextButton(
                      onPressed: () => onToggle(i),
                      child: Text(
                        ads[i].contains('|Pausado')
                            ? 'Reativar anúncio'
                            : 'Pausar anúncio',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onConversations,
                      icon: const Icon(Icons.person_outline, size: 15),
                      label: const Text('Interessados · 2'),
                    ),
                    TextButton.icon(
                      onPressed: () => onDelete(i),
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
          ),
        ),
    ],
  );
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.teamName,
    required this.onEdit,
    required this.onGames,
    required this.onLogout,
  });
  final String teamName;
  final VoidCallback onEdit, onGames, onLogout;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
    children: [
      const PageTitle(
        'Seu time. Sua identidade.',
        subtitle: 'Dentro e fora de campo, esse é o seu cartão de visita.',
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
                  const Crest(),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          teamName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 19,
                          ),
                        ),
                        const Text(
                          '⌖  São Paulo, SP · Desde 2015',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Wrap(
                spacing: 6,
                children: [
                  TagPill('Futebol', green: true),
                  TagPill('Livre'),
                  TagPill('Intermediário'),
                ],
              ),
              const Divider(height: 24),
              const Text(
                'Mais que um time, uma família.',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 6),
              const Text(
                'Desde 2015, reunimos amigos que compartilham a paixão pelo futebol. Jogamos com raça, respeito e aquela resenha que não pode faltar. Estamos sempre prontos para um bom amistoso!',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Responsável   João Silva\nContato           (11) 99999-1234',
                style: TextStyle(fontSize: 11, height: 1.8),
              ),
              const Divider(height: 22),
              const Text(
                'Histórico de jogos',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                '$teamName   2 × 1   Real Amigos FC     11 jul 2026',
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              Text(
                '$teamName   1 × 1   Atlético da Zona Sul    4 jul 2026',
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
              const SizedBox(height: 15),
              const Row(
                children: [
                  Expanded(
                    child: _ProfileStat(value: '18', label: 'Jogos realizados'),
                  ),
                  Expanded(
                    child: _ProfileStat(
                      value: '4,9 ★',
                      label: 'Avaliação geral',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Quem já jogou com a gente',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 7),
              const Text(
                '★★★★★\n“Time pontual, organizado e com muito respeito em campo. Bora marcar a próxima!”',
                style: TextStyle(
                  color: AppColors.green,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
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
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    ],
  );
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
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
    children: [
      const PageTitle(
        'O jogo não para.',
        subtitle: 'Fique por dentro de tudo que acontece com o seu time.',
      ),
      Panel(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < MockRepository.notifications.length; i++) ...[
              Builder(
                builder: (context) {
                  final n = MockRepository.notifications[i];
                  return InkWell(
                    onTap: () => onOpen(n.$4),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFFEAF4E8),
                            child: Icon(
                              n.$4 == 'confirmed'
                                  ? Icons.check
                                  : n.$4 == 'chat'
                                  ? Icons.chat_bubble_outline
                                  : Icons.notifications_none,
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
                                  n.$1,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  n.$2,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 10,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  n.$3,
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
                  );
                },
              ),
              if (i < MockRepository.notifications.length - 1)
                const Divider(height: 1, indent: 14, endIndent: 14),
            ],
          ],
        ),
      ),
    ],
  );
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.games, required this.onSelect});
  final List<Game> games;
  final ValueChanged<Game> onSelect;
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late Game selected = widget.games.first;
  @override
  Widget build(BuildContext context) => ListView(
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
            Positioned(
              left: 65,
              top: 35,
              child: const Text(
                'VILA MARIANA',
                style: TextStyle(
                  fontSize: 9,
                  color: AppColors.muted,
                  letterSpacing: 1,
                ),
              ),
            ),
            Positioned(
              right: 23,
              top: 128,
              child: const Text(
                'IBIRAPUERA',
                style: TextStyle(
                  fontSize: 9,
                  color: AppColors.muted,
                  letterSpacing: 1,
                ),
              ),
            ),
            Positioned(
              left: 22,
              top: 145,
              child: const Chip(
                avatar: Icon(Icons.my_location, size: 14),
                label: Text('Você está aqui', style: TextStyle(fontSize: 9)),
              ),
            ),
            for (var i = 0; i < widget.games.length; i++)
              Positioned(
                left: 35.0 + i * 65,
                top: 80.0 + (i % 2) * 95,
                child: GestureDetector(
                  onTap: () => setState(() => selected = widget.games[i]),
                  child: CircleAvatar(
                    backgroundColor: AppColors.forest,
                    child: Text('⚽', style: const TextStyle(fontSize: 17)),
                  ),
                ),
              ),
            const Positioned(
              left: 10,
              bottom: 10,
              child: Text(
                'Mapa ilustrativo · São Paulo, SP',
                style: TextStyle(fontSize: 9, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 13),
      Text(
        'Perto de você · ${selected.name}',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
      const SizedBox(height: 8),
      GameCard(game: selected, onTap: () => widget.onSelect(selected)),
      for (final g in widget.games.where((g) => g.id != selected.id).take(2))
        ListTile(
          leading: Crest(label: g.crest, small: true),
          title: Text(
            g.name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${g.distance} · ${g.sport}',
            style: const TextStyle(fontSize: 10),
          ),
          onTap: () => setState(() => selected = g),
        ),
    ],
  );
}

class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({
    super.key,
    required this.game,
    required this.teamName,
    required this.onChat,
    required this.onCancel,
  });
  final Game game;
  final String teamName;
  final VoidCallback onChat, onCancel;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
    children: [
      const Icon(Icons.check_circle, color: AppColors.green, size: 52),
      const SizedBox(height: 9),
      const Text(
        'AGORA É SÓ ENTRAR EM CAMPO',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 9,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'Partida confirmada!',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      const Text(
        'Chame a equipe. Seu próximo jogo já tem dia e hora.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted, fontSize: 11),
      ),
      const SizedBox(height: 18),
      Panel(
        child: Column(
          children: [
            const TagPill('Amistoso · Futebol', green: true),
            const SizedBox(height: 17),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Crest(),
                      Text(
                        teamName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      const Text(
                        'São Paulo, SP',
                        style: TextStyle(fontSize: 9, color: AppColors.muted),
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
                      Crest(label: game.crest),
                      Text(
                        game.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        game.city,
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
              value: '${game.date} de 2026',
            ),
            _Info(icon: Icons.access_time, label: 'Horário', value: game.time),
            _Info(
              icon: Icons.place_outlined,
              label: 'Local',
              value:
                  '${game.place}\nAv. República do Líbano, 1111 · São Paulo, SP',
            ),
            const SizedBox(height: 8),
            ActionButton(
              'Abrir localização',
              outline: true,
              icon: Icons.place_outlined,
              expand: true,
              onPressed: () {},
            ),
            const SizedBox(height: 8),
            ActionButton(
              'Conversar',
              icon: Icons.chat_bubble_outline,
              expand: true,
              onPressed: onChat,
            ),
            TextButton(
              onPressed: onCancel,
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
  const ReviewScreen({super.key, required this.game, required this.onSubmit});
  final Game game;
  final VoidCallback onSubmit;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final ratings = <String, int>{};
  @override
  Widget build(BuildContext context) => ListView(
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
                Crest(label: widget.game.crest),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.game.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${widget.game.date} · ${widget.game.place}',
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
            for (final label in [
              'Pontualidade',
              'Organização',
              'Respeito',
              'Estrutura do local',
            ])
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
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
                      onPressed: () => setState(() => ratings[label] = star),
                      icon: Icon(
                        Icons.star,
                        size: 21,
                        color: (ratings[label] ?? 0) >= star
                            ? const Color(0xFFF2B844)
                            : const Color(0xFFDCE1DC),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 10),
            TextField(
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Deixe um comentário',
                hintText:
                    'Conte como foi a experiência de jogar com esse time.',
              ),
            ),
            const SizedBox(height: 12),
            ActionButton(
              'Enviar avaliação',
              icon: Icons.star,
              expand: true,
              onPressed: () {
                if (ratings.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Avalie todos os critérios antes de enviar.',
                      ),
                    ),
                  );
                } else {
                  widget.onSubmit();
                }
              },
            ),
          ],
        ),
      ),
    ],
  );
}

class AuthScreen extends StatelessWidget {
  const AuthScreen({
    super.key,
    required this.page,
    required this.onPage,
    required this.onDone,
  });
  final String page;
  final ValueChanged<String> onPage;
  final VoidCallback onDone;
  @override
  Widget build(BuildContext context) {
    final title = page == 'login'
        ? 'Seu time em campo.'
        : page == 'forgot'
        ? 'Recupere seu acesso'
        : 'Vamos começar?';
    return ListView(
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
        if (page == 'register')
          const TextField(
            decoration: InputDecoration(
              labelText: 'Nome do responsável',
              hintText: 'Seu nome',
            ),
          ),
        if (page == 'register') const SizedBox(height: 10),
        if (page == 'register')
          const TextField(
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Telefone',
              hintText: '(11) 99999-9999',
            ),
          ),
        if (page == 'register') const SizedBox(height: 10),
        if (page != 'forgot')
          const TextField(
            decoration: InputDecoration(
              labelText: 'E-mail',
              hintText: 'voce@email.com',
            ),
          ),
        if (page != 'forgot') const SizedBox(height: 10),
        if (page == 'forgot')
          const TextField(
            decoration: InputDecoration(
              labelText: 'E-mail',
              hintText: 'voce@email.com',
            ),
          ),
        if (page != 'forgot')
          const TextField(
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Senha',
              hintText: 'Pelo menos 6 caracteres',
            ),
          ),
        if (page == 'register') ...[
          const SizedBox(height: 10),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Nome do time',
              hintText: 'Ex.: União FC',
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: 'Futebol',
            decoration: const InputDecoration(labelText: 'Modalidade'),
            items: [
              'Futebol',
              'Futsal',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (_) {},
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: 'Livre',
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: [
              'Livre',
              'Sub-15',
              'Sub-17',
              'Sub-20',
              'Veterano',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (_) {},
          ),
          const SizedBox(height: 10),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Cidade',
              hintText: 'São Paulo',
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: 'SP',
            decoration: const InputDecoration(labelText: 'Estado'),
            items: [
              'SP',
              'RJ',
              'MG',
              'PR',
              'RS',
              'SC',
              'BA',
              'PE',
              'CE',
              'DF',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (_) {},
          ),
        ],
        if (page == 'login')
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => onPage('forgot'),
              child: const Text('Esqueci minha senha'),
            ),
          ),
        ActionButton(
          page == 'forgot'
              ? 'Enviar link'
              : page == 'register'
              ? 'Criar perfil do time'
              : 'Entrar',
          icon: Icons.arrow_forward,
          expand: true,
          onPressed: onDone,
        ),
        const SizedBox(height: 8),
        if (page == 'login')
          OutlinedButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'O login com Google estará disponível na versão conectada.',
                ),
              ),
            ),
            child: const Text('G   Entrar com Google'),
          ),
        Center(
          child: TextButton(
            onPressed: () => onPage(page == 'register' ? 'login' : 'register'),
            child: Text(
              page == 'register'
                  ? 'Já tem conta? Entrar'
                  : 'Ainda não tem conta? Criar conta',
            ),
          ),
        ),
      ],
    );
  }
}
