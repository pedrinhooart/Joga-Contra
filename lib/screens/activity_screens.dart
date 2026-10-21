import 'package:flutter/material.dart';
import '../models/game.dart';
import '../repositories/mock_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class CreateGameScreen extends StatefulWidget {
  const CreateGameScreen({
    super.key,
    required this.onPublish,
    this.editing = false,
  });
  final ValueChanged<String> onPublish;
  final bool editing;
  @override
  State<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends State<CreateGameScreen> {
  final form = GlobalKey<FormState>();
  final date = TextEditingController();
  String sport = 'Futebol';
  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
      children: [
        PageTitle(
          widget.editing ? 'Edite seu anúncio' : 'O seu time procura um rival?',
          subtitle:
              'Publique um jogo em poucos passos. Deixe o resto com a gente.',
        ),
        _SectionTitle(
          number: '01',
          title: 'Como vai ser o jogo?',
          subtitle: 'Conte um pouco sobre a sua equipe.',
        ),
        DropdownButtonFormField(
          initialValue: sport,
          decoration: const InputDecoration(labelText: 'Modalidade'),
          items: [
            'Futebol',
            'Futsal',
          ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => sport = v ?? 'Futebol'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField(
          initialValue: 'Livre',
          decoration: const InputDecoration(labelText: 'Categoria'),
          items: [
            'Livre',
            'Sub-15',
            'Sub-17',
            'Sub-20',
            'Veterano',
          ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (_) {},
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField(
          initialValue: 'Intermediário',
          decoration: const InputDecoration(labelText: 'Nível do time'),
          items: [
            'Intermediário',
            'Recreativo',
            'Avançado',
          ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (_) {},
        ),
        const SizedBox(height: 10),
        _field('Quantidade de jogadores', '11', number: true),
        const SizedBox(height: 20),
        _SectionTitle(
          number: '02',
          title: 'Quando e onde?',
          subtitle: 'O primeiro passo para uma partida marcada.',
        ),
        TextFormField(
          controller: date,
          decoration: const InputDecoration(
            labelText: 'Data',
            hintText: 'Ex.: 18/07/2026',
            suffixIcon: Icon(Icons.calendar_today_outlined),
          ),
          validator: (v) => (v == null || v.isEmpty) ? 'Informe a data' : null,
        ),
        const SizedBox(height: 10),
        _field('Horário', '16:00'),
        const SizedBox(height: 10),
        _field('Cidade', 'São Paulo'),
        const SizedBox(height: 10),
        _field('Bairro / região', 'Ex.: Vila Mariana'),
        const SizedBox(height: 10),
        _field('Local da partida', 'Nome do campo ou quadra'),
        const SizedBox(height: 10),
        DropdownButtonFormField(
          initialValue: 'Jogo em casa',
          decoration: const InputDecoration(labelText: 'Mando de campo'),
          items: [
            'Jogo em casa',
            'Jogo fora',
            'Indiferente',
          ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (_) {},
        ),
        const SizedBox(height: 10),
        _field('Taxa de aluguel por time (R\$)', '0', number: true),
        const SizedBox(height: 10),
        TextFormField(
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Observações',
            hintText: 'Conte mais sobre o jogo, as regras e a estrutura.',
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Icon(Icons.shield_outlined, size: 17, color: AppColors.green),
            SizedBox(width: 7),
            Expanded(
              child: Text(
                'Um bom jogo começa com compromisso.',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ActionButton(
          widget.editing ? 'Salvar alterações' : 'Publicar anúncio',
          icon: widget.editing ? Icons.save_outlined : Icons.add,
          expand: true,
          onPressed: () {
            if (form.currentState!.validate()) {
              widget.onPublish('$sport · ${date.text}');
            }
          },
        ),
      ],
    ),
  );
  Widget _field(String label, String hint, {bool number = false}) =>
      TextFormField(
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: (v) =>
            label == 'Bairro / região' || label == 'Local da partida'
            ? ((v == null || v.isEmpty) ? 'Campo obrigatório' : null)
            : null,
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.number,
    required this.title,
    required this.subtitle,
  });
  final String number, title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Container(
          width: 29,
          height: 29,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.forest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: AppColors.lime,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key, required this.onOpen});
  final ValueChanged<Game> onOpen;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
    children: [
      const PageTitle(
        'A conversa que vira jogo.',
        subtitle: 'Combine os detalhes com os responsáveis de cada time.',
      ),
      for (var i = 0; i < 2; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => onOpen(MockRepository.games[i]),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Crest(label: MockRepository.games[i].crest),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            MockRepository.games[i].name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            i == 0
                                ? 'Vocês conseguem jogar sábado às 16h?'
                                : 'Olá! Nossa quadra está disponível domingo.',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const TagPill('Negociando partida', green: true),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          i == 0 ? '14:32' : 'Ontem',
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.forest,
                          child: Text(
                            '2',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.lime,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.game,
    required this.teamName,
    required this.confirmed,
    required this.onConfirm,
  });
  final Game game;
  final String teamName;
  final bool confirmed;
  final VoidCallback onConfirm;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  final messages = <(String, bool)>[
    ('Olá! Temos interesse em jogar.', true),
    ('Opa, João! Vocês conseguem jogar sábado às 16h?', false),
    ('Sim, podemos. Vamos combinar!', true),
  ];
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
    children: [
      Panel(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            ListTile(
              leading: Crest(label: widget.game.crest, small: true),
              title: Text(
                widget.game.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              subtitle: const Text(
                '●  Carlos · Responsável pelo time',
                style: TextStyle(fontSize: 10, color: AppColors.green),
              ),
              trailing: const Icon(
                Icons.verified_user_outlined,
                color: AppColors.green,
              ),
            ),
            const Divider(height: 1),
            Container(
              constraints: const BoxConstraints(minHeight: 240),
              padding: const EdgeInsets.all(13),
              child: Column(
                children: [
                  const TagPill('Hoje'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.teamName} demonstrou interesse no jogo de ${widget.game.name}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final (text, mine) in messages)
                    Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(11),
                        constraints: const BoxConstraints(maxWidth: 250),
                        decoration: BoxDecoration(
                          color: mine
                              ? AppColors.forest
                              : const Color(0xFFF0F3F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          text,
                          style: TextStyle(
                            color: mine ? Colors.white : AppColors.ink,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(9),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      decoration: const InputDecoration(
                        hintText: 'Escreva sua mensagem…',
                        border: InputBorder.none,
                        filled: false,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send, color: AppColors.forest),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TagPill('Em negociação', green: true),
            const SizedBox(height: 8),
            const Text(
              'Quase tudo pronto!',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.teamName}  VS  ${widget.game.name}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Text(
              '▦  ${widget.game.date} · ${widget.game.time}\n⌖  ${widget.game.place}',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 10),
            ActionButton(
              widget.confirmed ? 'Ver partida' : 'Confirmar partida',
              icon: Icons.check,
              expand: true,
              onPressed: widget.onConfirm,
            ),
          ],
        ),
      ),
    ],
  );
  void _send() {
    if (input.text.trim().isEmpty) return;
    setState(() {
      messages.add((input.text.trim(), true));
      input.clear();
    });
  }
}

class GamesScreen extends StatelessWidget {
  const GamesScreen({
    super.key,
    required this.tab,
    required this.onTab,
    required this.teamName,
    required this.onOpen,
  });
  final String tab, teamName;
  final ValueChanged<String> onTab;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) {
    const tabs = [
      'Todos',
      'Aguardando',
      'Negociando',
      'Confirmado',
      'Realizado',
      'Cancelado',
    ];
    final items = [
      'Aguardando',
      'Negociando',
      'Confirmado',
      'Realizado',
    ].where((x) => tab == 'Todos' || tab == x).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
      children: [
        const PageTitle(
          'Toda partida tem uma história.',
          subtitle:
              'Acompanhe seus jogos, da primeira conversa ao apito final.',
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: tabs
                .map(
                  (x) => Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: ChoiceChip(
                      label: Text(x, style: const TextStyle(fontSize: 10)),
                      selected: tab == x,
                      onSelected: (_) => onTab(x),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        if (tab == 'Cancelado')
          const EmptyState(
            title: 'Nenhuma partida cancelada',
            message: 'Bom sinal! Compromisso também faz parte do jogo.',
          ),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Crest(label: 'UFC', small: true),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '$teamName  vs  ${items[i] == 'Aguardando' ? 'Adversário a definir' : MockRepository.games[i].name}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const Crest(label: 'RA', small: true),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${MockRepository.games[i].date} · ${MockRepository.games[i].time}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      TagPill(
                        items[i],
                        green: items[i] == 'Confirmado',
                        orange: items[i] == 'Negociando',
                      ),
                      const Spacer(),
                      ActionButton(
                        items[i] == 'Realizado' ? 'Avaliar' : 'Ver detalhes',
                        outline: true,
                        onPressed: () => onOpen(items[i]),
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
}
