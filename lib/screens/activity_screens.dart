import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/formatters.dart';
import '../models/anuncio_partida.dart';
import '../models/partida.dart';
import '../models/referencia.dart';
import '../models/solicitacao_confronto.dart';
import '../models/time.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/carregador.dart';
import '../widgets/common.dart';

class CreateGameScreen extends StatefulWidget {
  const CreateGameScreen({super.key, required this.onSalvar, this.editando});
  final Future<void> Function(RascunhoAnuncio dados) onSalvar;
  final AnuncioPartida? editando;
  @override
  State<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends State<CreateGameScreen> {
  final form = GlobalKey<FormState>();
  late final AnuncioPartida? e = widget.editando;
  late final data = TextEditingController(
    text: e == null ? '' : Formatos.dataNumerica(e!.dataHoraInicio),
  );
  late final hora = TextEditingController(
    text: e == null ? '' : Formatos.hora(e!.dataHoraInicio),
  );
  late final jogadores = TextEditingController(
    text: e?.quantidadeJogadores.toString() ?? '',
  );
  late final cidade = TextEditingController(text: e?.cidade ?? '');
  late final bairro = TextEditingController(text: e?.bairro ?? '');
  late final local = TextEditingController(text: e?.nomeLocal ?? '');
  late final taxa = TextEditingController(
    text: e?.valorAluguelPorTime == null
        ? ''
        : Formatos.decimal(e!.valorAluguelPorTime!, casas: 2),
  );
  late final observacoes = TextEditingController(text: e?.descricao ?? '');
  int? modalidade, categoria, nivel, mando;
  String? siglaEstado;
  bool salvando = false;
  bool _iniciado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    final app = AppScope.of(context);
    final refs = app.referencias, time = app.time!;
    modalidade =
        e?.modalidade.id ??
        time.modalidades.firstOrNull?.id ??
        refs.modalidades.firstOrNull?.id;
    categoria =
        e?.categoriaEtaria.id ??
        time.categoriaEtaria?.id ??
        refs.categoriasEtarias.firstOrNull?.id;
    nivel = e?.nivelTecnico?.id ?? time.nivelTecnico?.id;
    mando = e?.mandoCampo?.id ?? refs.mandosCampo.firstOrNull?.id;
    siglaEstado = e?.siglaEstado ?? time.siglaEstado;
    if (cidade.text.isEmpty) cidade.text = time.cidade;
  }

  @override
  void dispose() {
    for (final c in [
      data,
      hora,
      jogadores,
      cidade,
      bairro,
      local,
      taxa,
      observacoes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _obrigatorio(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null;

  DropdownButtonFormField<int> _dropdown(
    String label,
    List<ItemReferencia> itens,
    int? valor,
    ValueChanged<int?> onChanged,
  ) => DropdownButtonFormField<int>(
    initialValue: itens.any((i) => i.id == valor) ? valor : null,
    decoration: InputDecoration(labelText: label),
    items: itens
        .map((s) => DropdownMenuItem(value: s.id, child: Text(s.nome)))
        .toList(),
    onChanged: (v) => setState(() => onChanged(v)),
    validator: (v) => v == null ? 'Selecione uma opção' : null,
  );

  @override
  Widget build(BuildContext context) {
    final refs = AppScope.of(context).referencias;
    final editing = e != null;
    return Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
        children: [
          PageTitle(
            editing ? 'Edite seu anúncio' : 'O seu time procura um rival?',
            subtitle:
                'Publique um jogo em poucos passos. Deixe o resto com a gente.',
          ),
          const _SectionTitle(
            number: '01',
            title: 'Como vai ser o jogo?',
            subtitle: 'Conte um pouco sobre a sua equipe.',
          ),
          _dropdown(
            'Modalidade',
            refs.modalidades,
            modalidade,
            (v) => modalidade = v,
          ),
          const SizedBox(height: 10),
          _dropdown(
            'Categoria',
            refs.categoriasEtarias,
            categoria,
            (v) => categoria = v,
          ),
          const SizedBox(height: 10),
          _dropdown(
            'Nível do time',
            refs.niveisTecnicos,
            nivel,
            (v) => nivel = v,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: jogadores,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Quantidade de jogadores',
              hintText: 'Ex.: 7',
            ),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              return n == null || n < 5 || n > 30
                  ? 'Informe de 5 a 30 jogadores por equipe'
                  : null;
            },
          ),
          const SizedBox(height: 20),
          const _SectionTitle(
            number: '02',
            title: 'Quando e onde?',
            subtitle: 'O primeiro passo para uma partida marcada.',
          ),
          TextFormField(
            controller: data,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: 'Data',
              hintText: 'Ex.: 18/07/2026',
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Informe a data';
              return Formatos.lerDataHora(v, '00:00') == null
                  ? 'Use o formato dd/mm/aaaa'
                  : null;
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: hora,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: 'Horário',
              hintText: '16:00',
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Informe o horário';
              final quando = Formatos.lerDataHora(data.text, v);
              if (Formatos.lerDataHora('01/01/2000', v) == null) {
                return 'Use o formato hh:mm';
              }
              if (quando != null && quando.isBefore(DateTime.now())) {
                return 'Escolha uma data e horário futuros';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: cidade,
            decoration: const InputDecoration(
              labelText: 'Cidade',
              hintText: 'São Paulo',
            ),
            validator: _obrigatorio,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: bairro,
            decoration: const InputDecoration(
              labelText: 'Bairro / região',
              hintText: 'Ex.: Vila Mariana',
            ),
            validator: _obrigatorio,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: local,
            decoration: const InputDecoration(
              labelText: 'Local da partida',
              hintText: 'Nome do campo ou quadra',
            ),
            validator: _obrigatorio,
          ),
          const SizedBox(height: 10),
          _dropdown(
            'Mando de campo',
            refs.mandosCampo,
            mando,
            (v) => mando = v,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: taxa,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Taxa de aluguel por time (R\$)',
              hintText: '0',
            ),
            validator: (v) =>
                (v == null ||
                    v.trim().isEmpty ||
                    (double.tryParse(v.replaceAll(',', '.')) ?? -1) >= 0)
                ? null
                : 'Informe um valor válido',
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: observacoes,
            maxLines: 3,
            maxLength: 1000,
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
            salvando
                ? 'Salvando…'
                : editing
                ? 'Salvar alterações'
                : 'Publicar anúncio',
            icon: editing ? Icons.save_outlined : Icons.add,
            expand: true,
            onPressed: salvando ? null : _salvar,
          ),
        ],
      ),
    );
  }

  Future<void> _salvar() async {
    if (!form.currentState!.validate()) return;
    final taxaTexto = taxa.text.trim().replaceAll(',', '.');
    String? opcional(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    setState(() => salvando = true);
    try {
      await widget.onSalvar(
        RascunhoAnuncio(
          idModalidade: modalidade!,
          idCategoriaEtaria: categoria!,
          idNivelTecnico: nivel!,
          idMandoCampo: mando,
          quantidadeJogadores: int.parse(jogadores.text),
          dataHoraInicio: Formatos.lerDataHora(data.text, hora.text)!,
          cidade: cidade.text.trim(),
          siglaEstado: siglaEstado!,
          bairro: opcional(bairro),
          nomeLocal: local.text.trim(),
          valorAluguelPorTime: taxaTexto.isEmpty
              ? null
              : double.parse(taxaTexto),
          descricao: opcional(observacoes),
        ),
      );
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }
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
  final ValueChanged<SolicitacaoConfronto> onOpen;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final idMeuTime = app.time!.id;
    return Carregador<List<SolicitacaoConfronto>>(
      carregar: () async =>
          (await app.repositorios.solicitacoes.listarDoMeuTime())
              .where((s) => s.status.emAberto)
              .toList(),
      builder: (context, conversas, _) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
        children: [
          const PageTitle(
            'A conversa que vira jogo.',
            subtitle: 'Combine os detalhes com os responsáveis de cada time.',
          ),
          if (conversas.isEmpty)
            const EmptyState(
              title: 'Nenhuma conversa por enquanto.',
              message:
                  'Demonstre interesse em um jogo ou aguarde solicitações para o seu anúncio.',
            ),
          for (final s in conversas)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ConversaTile(
                solicitacao: s,
                adversario: s.adversario(idMeuTime),
                onTap: () => onOpen(s),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConversaTile extends StatelessWidget {
  const _ConversaTile({
    required this.solicitacao,
    required this.adversario,
    required this.onTap,
  });
  final SolicitacaoConfronto solicitacao;
  final ResumoTime adversario;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = solicitacao;
    final quando = s.dataUltimaMensagem ?? s.dataSolicitacao;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Crest(label: adversario.siglaExibicao),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adversario.nome,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.ultimaMensagem ??
                          s.mensagemInicial ??
                          'Interesse no jogo de ${Formatos.dataCurta(s.anuncio.dataHoraInicio)}.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 7),
                    TagPill(s.status.rotulo, green: true),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    Formatos.horaOuDia(quando),
                    style: const TextStyle(fontSize: 9, color: AppColors.muted),
                  ),
                  const SizedBox(height: 5),
                  if (s.mensagensNaoLidas > 0)
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: AppColors.forest,
                      child: Text(
                        '${s.mensagensNaoLidas}',
                        style: const TextStyle(
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
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.idSolicitacao,
    required this.onConfirmar,
    required this.onVerPartida,
  });
  final String idSolicitacao;

  /// Pede confirmação ao usuário e registra a concordância do time.
  final Future<void> Function(SolicitacaoConfronto) onConfirmar;
  final ValueChanged<String> onVerPartida;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  final mensagens = <Mensagem>[];
  bool enviando = false;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<SolicitacaoConfronto> _carregar() async {
    final repo = AppScope.repos(context).solicitacoes;
    final s = await repo.obter(widget.idSolicitacao);
    final lista = await repo.mensagens(widget.idSolicitacao);
    mensagens
      ..clear()
      ..addAll(lista);
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final idMeuTime = AppScope.of(context).time!.id;
    return Carregador<SolicitacaoConfronto>(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
      carregar: _carregar,
      builder: (context, s, _) {
        final adversario = s.adversario(idMeuTime);
        final eu = s.souAnunciante(idMeuTime)
            ? s.timeAnunciante
            : s.timeSolicitante;
        final hoje = DateUtils.isSameDay(s.dataSolicitacao, DateTime.now());
        final (rotulo, acao) = switch (s) {
          _ when s.idPartida != null => (
            'Ver partida',
            () => widget.onVerPartida(s.idPartida!),
          ),
          _ when !s.status.emAberto => (s.status.rotulo, null),
          _ when s.euConfirmei(idMeuTime) => ('Aguardando o adversário', null),
          _ => ('Confirmar partida', () => widget.onConfirmar(s)),
        };
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
          children: [
            Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: Crest(
                      label: adversario.siglaExibicao,
                      small: true,
                    ),
                    title: Text(
                      adversario.nome,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      '●  ${adversario.nomeCapitao ?? 'Capitão'} · Responsável pelo time',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.green,
                      ),
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
                        TagPill(
                          hoje ? 'Hoje' : Formatos.dataCurta(s.dataSolicitacao),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.canvas,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${s.timeSolicitante.nome} demonstrou interesse no jogo de ${s.timeAnunciante.nome}.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final m in mensagens)
                          _Balao(
                            texto: m.texto,
                            mine: m.idTimeRemetente == idMeuTime,
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
                            enabled:
                                s.status.emAberto ||
                                s.status == StatusSolicitacao.confirmada,
                            maxLength: 1000,
                            decoration: const InputDecoration(
                              hintText: 'Escreva sua mensagem…',
                              border: InputBorder.none,
                              filled: false,
                              counterText: '',
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        IconButton(
                          onPressed: enviando ? null : _send,
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
                  TagPill(
                    s.status.emAberto ? 'Em negociação' : s.status.rotulo,
                    green: true,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Quase tudo pronto!',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${eu.nome}  VS  ${adversario.nome}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '▦  ${Formatos.dataCurta(s.anuncio.dataHoraInicio)} · ${Formatos.hora(s.anuncio.dataHoraInicio)}\n⌖  ${s.anuncio.nomeLocal}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ActionButton(
                    rotulo,
                    icon: Icons.check,
                    expand: true,
                    onPressed: acao,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _send() async {
    final texto = input.text.trim();
    if (texto.isEmpty) return;
    setState(() => enviando = true);
    try {
      final m = await AppScope.repos(
        context,
      ).solicitacoes.enviarMensagem(widget.idSolicitacao, texto);
      if (!mounted) return;
      setState(() {
        mensagens.add(m);
        input.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }
}

class _Balao extends StatelessWidget {
  const _Balao({required this.texto, required this.mine});
  final String texto;
  final bool mine;
  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      constraints: const BoxConstraints(maxWidth: 250),
      decoration: BoxDecoration(
        color: mine ? AppColors.forest : const Color(0xFFF0F3F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: mine ? Colors.white : AppColors.ink,
          fontSize: 12,
        ),
      ),
    ),
  );
}

/// Linha da tela "Meus jogos": anúncio aguardando, solicitação em negociação
/// ou partida (confirmada, realizada, cancelada).
class _ItemJogo {
  const _ItemJogo({
    required this.status,
    required this.adversario,
    required this.data,
    required this.acao,
    required this.abrir,
  });
  final String status;
  final ResumoTime? adversario;
  final DateTime data;
  final String acao;
  final VoidCallback abrir;
}

class GamesScreen extends StatelessWidget {
  const GamesScreen({
    super.key,
    required this.tab,
    required this.onTab,
    required this.onAnuncios,
    required this.onChat,
    required this.onPartida,
    required this.onAvaliar,
  });
  final String tab;
  final ValueChanged<String> onTab;
  final VoidCallback onAnuncios;
  final ValueChanged<SolicitacaoConfronto> onChat;
  final ValueChanged<Partida> onPartida, onAvaliar;

  static const tabs = [
    'Todos',
    'Aguardando',
    'Negociando',
    'Confirmado',
    'Realizado',
    'Cancelado',
  ];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final time = app.time!;
    final repos = app.repositorios;
    return Carregador<List<_ItemJogo>>(
      carregar: () async {
        final anuncios = await repos.anuncios.listarDoMeuTime();
        final solicitacoes = await repos.solicitacoes.listarDoMeuTime();
        final partidas = await repos.partidas.listarDoMeuTime();
        return [
          for (final a in anuncios)
            if (a.status == StatusAnuncio.ativo ||
                a.status == StatusAnuncio.pausado)
              _ItemJogo(
                status: 'Aguardando',
                adversario: null,
                data: a.dataHoraInicio,
                acao: 'Ver detalhes',
                abrir: onAnuncios,
              ),
          for (final s in solicitacoes)
            if (s.status.emAberto)
              _ItemJogo(
                status: 'Negociando',
                adversario: s.adversario(time.id),
                data: s.anuncio.dataHoraInicio,
                acao: 'Ver detalhes',
                abrir: () => onChat(s),
              ),
          for (final p in partidas)
            _ItemJogo(
              status: p.status.rotulo,
              adversario: p.adversarioDe(time.id),
              data: p.dataHoraInicio,
              acao:
                  p.status == StatusPartida.realizada && !p.avaliadaPeloMeuTime
                  ? 'Avaliar'
                  : 'Ver detalhes',
              abrir:
                  p.status == StatusPartida.realizada && !p.avaliadaPeloMeuTime
                  ? () => onAvaliar(p)
                  : () => onPartida(p),
            ),
        ];
      },
      builder: (context, todos, _) {
        final items = todos
            .where((x) => tab == 'Todos' || tab == x.status)
            .toList();
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
            if (items.isEmpty)
              tab == 'Cancelado'
                  ? const EmptyState(
                      title: 'Nenhuma partida cancelada',
                      message:
                          'Bom sinal! Compromisso também faz parte do jogo.',
                    )
                  : const EmptyState(
                      title: 'Nada por aqui ainda.',
                      message:
                          'Quando seu time tiver jogos, eles aparecem aqui.',
                    ),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Crest(label: time.siglaExibicao, small: true),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              '${time.nome}  vs  ${item.adversario?.nome ?? 'Adversário a definir'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (item.adversario != null)
                            Crest(
                              label: item.adversario!.siglaExibicao,
                              small: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${Formatos.dataCurta(item.data)} · ${Formatos.hora(item.data)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          TagPill(
                            item.status,
                            green: item.status == 'Confirmado',
                            orange: item.status == 'Negociando',
                          ),
                          const Spacer(),
                          ActionButton(
                            item.acao,
                            outline: true,
                            onPressed: item.abrir,
                          ),
                        ],
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
