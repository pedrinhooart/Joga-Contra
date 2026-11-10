import 'package:flutter/material.dart';
import '../core/formatters.dart';
import '../models/anuncio_partida.dart';
import '../models/local_esportivo.dart';
import '../models/partida.dart';
import '../models/referencia.dart';
import '../models/solicitacao_confronto.dart';
import '../models/time.dart';
import '../services/municipios.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/campo_cidade.dart';
import '../widgets/campo_local.dart';
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

  // Data e horário são escolhidos no calendário e no relógio; os campos só
  // mostram o resultado (DD/MM/AAAA e HH:mm).
  late DateTime? dia = e == null
      ? null
      : DateUtils.dateOnly(e!.dataHoraInicio.toLocal());
  late TimeOfDay? horario = e == null
      ? null
      : TimeOfDay.fromDateTime(e!.dataHoraInicio.toLocal());
  late final data = TextEditingController(
    text: dia == null ? '' : Formatos.dataNumerica(dia!),
  );
  late final hora = TextEditingController(
    text: e == null ? '' : Formatos.hora(e!.dataHoraInicio),
  );
  late final cidade = TextEditingController(text: e?.cidade ?? '');
  late final local = TextEditingController(text: e?.nomeLocal ?? '');
  late final taxa = TextEditingController(
    text: e?.valorAluguelPorTime == null
        ? ''
        : Formatos.decimal(e!.valorAluguelPorTime!, casas: 2),
  );
  late final observacoes = TextEditingController(text: e?.descricao ?? '');
  int? modalidade, nivel, duracao;
  String? siglaEstado;

  /// Endereço e coordenadas do local escolhido nas sugestões.
  late String? endereco = e?.endereco;
  late double? latitude = e?.latitude, longitude = e?.longitude;
  bool salvando = false;
  bool _iniciado = false;

  static const _duracoes = [30, 60, 90, 120, 150, 180];
  static const _outraDuracao = -1;
  int _versaoDuracao = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    final time = AppScope.of(context).time!;
    // O cadastro não pede esses dados: sem eles no time, o capitão escolhe
    // os do jogo (nada pré-marcado por engano). Times antigos mantêm o padrão.
    modalidade = e?.modalidade.id ?? time.modalidades.firstOrNull?.id;
    nivel = e?.nivelTecnico?.id ?? time.nivelTecnico?.id;
    duracao = e?.duracaoMinutos;
    siglaEstado = e?.siglaEstado ?? time.siglaEstado;
    if (cidade.text.isEmpty) cidade.text = time.cidade;
    cidade.addListener(_cidadeMudou);
  }

  @override
  void dispose() {
    for (final c in [data, hora, cidade, local, taxa, observacoes]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Nome oficial da cidade digitada/escolhida, ou nulo se ainda não é válida.
  String? get _cidadeOficial => siglaEstado == null
      ? null
      : Municipios.carregado?.oficial(siglaEstado!, cidade.text);

  String? _ultimaCidade;
  void _cidadeMudou() {
    final atual = _cidadeOficial;
    if (atual == _ultimaCidade) return;
    _ultimaCidade = atual;
    setState(() {}); // atualiza as sugestões de locais
  }

  void _localEscolhido(LocalEsportivo? l) {
    endereco = l?.endereco;
    latitude = l?.latitude;
    longitude = l?.longitude;
  }

  DateTime? get _inicio => dia == null || horario == null
      ? null
      : DateTime(
          dia!.year,
          dia!.month,
          dia!.day,
          horario!.hour,
          horario!.minute,
        );

  Future<void> _escolherData() async {
    final hoje = DateUtils.dateOnly(DateTime.now());
    final escolhido = await showDatePicker(
      context: context,
      initialDate: dia != null && !dia!.isBefore(hoje) ? dia! : hoje,
      firstDate: hoje, // nada antes de hoje
      lastDate: DateTime(hoje.year + 1, hoje.month, hoje.day),
      helpText: 'Data da partida',
      cancelText: 'Cancelar',
      confirmText: 'OK',
      fieldLabelText: 'Data',
      fieldHintText: 'DD/MM/AAAA',
      errorFormatText: 'Use o formato DD/MM/AAAA',
      errorInvalidText: 'Escolha uma data de hoje em diante',
    );
    if (escolhido == null) return;
    setState(() {
      dia = escolhido;
      data.text = Formatos.dataNumerica(escolhido);
    });
  }

  Future<void> _escolherHorario() async {
    final escolhido = await showTimePicker(
      context: context,
      initialTime: horario ?? const TimeOfDay(hour: 16, minute: 0),
      helpText: 'Horário da partida',
      cancelText: 'Cancelar',
      confirmText: 'OK',
      hourLabelText: 'Hora',
      minuteLabelText: 'Minuto',
      errorInvalidText: 'Horário inválido',
      builder: (context, filho) => MediaQuery(
        // Sempre 24 horas, independente da configuração do aparelho.
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: filho!,
      ),
    );
    if (escolhido == null) return;
    setState(() {
      horario = escolhido;
      hora.text =
          '${escolhido.hour.toString().padLeft(2, '0')}:${escolhido.minute.toString().padLeft(2, '0')}';
    });
  }

  /// Duração fora da lista: horas e minutos, de 15 min a 10 h.
  Future<void> _outraDuracaoPersonalizada() async {
    var horas = (duracao ?? 60) ~/ 60,
        minutos = ((duracao ?? 60) % 60) ~/ 15 * 15;
    final escolhida = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, atualizar) {
          final total = horas * 60 + minutos;
          final valida = total >= 15 && total <= 600;
          return AlertDialog(
            title: const Text('Duração da partida'),
            // Um embaixo do outro: cabe em telas estreitas com fonte maior.
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: horas,
                  decoration: const InputDecoration(labelText: 'Horas'),
                  items: [
                    for (var h = 0; h <= 10; h++)
                      DropdownMenuItem(value: h, child: Text('$h h')),
                  ],
                  onChanged: (v) => atualizar(() => horas = v ?? 0),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: minutos,
                  decoration: const InputDecoration(labelText: 'Minutos'),
                  items: [
                    for (final m in [0, 15, 30, 45])
                      DropdownMenuItem(value: m, child: Text('$m min')),
                  ],
                  onChanged: (v) => atualizar(() => minutos = v ?? 0),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: valida ? () => Navigator.pop(ctx, total) : null,
                child: Text(
                  valida
                      ? 'Usar ${Formatos.duracao(total)}'
                      : 'De 15 min a 10 h',
                ),
              ),
            ],
          );
        },
      ),
    );
    // Cancelou ou escolheu: o seletor volta a mostrar a duração real
    // (e não "Outra duração…").
    setState(() {
      if (escolhida != null) duracao = escolhida;
      _versaoDuracao++;
    });
  }

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
    final opcoesDuracao = [
      ..._duracoes,
      if (duracao != null && !_duracoes.contains(duracao)) duracao!,
    ]..sort();
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
            'Nível do time',
            refs.niveisTecnicos,
            nivel,
            (v) => nivel = v,
          ),
          const SizedBox(height: 20),
          const _SectionTitle(
            number: '02',
            title: 'Quando e onde?',
            subtitle: 'O primeiro passo para uma partida marcada.',
          ),
          TextFormField(
            controller: data,
            readOnly: true,
            onTap: _escolherData,
            decoration: const InputDecoration(
              labelText: 'Data',
              hintText: 'DD/MM/AAAA',
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
            validator: (_) => dia == null ? 'Escolha a data' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: hora,
            readOnly: true,
            onTap: _escolherHorario,
            decoration: const InputDecoration(
              labelText: 'Horário',
              hintText: 'HH:mm',
              suffixIcon: Icon(Icons.schedule),
            ),
            validator: (_) {
              if (horario == null) return 'Escolha o horário';
              final inicio = _inicio;
              if (inicio != null && !inicio.isAfter(DateTime.now())) {
                return 'Escolha um horário futuro';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            key: ValueKey('duracao-$duracao-$_versaoDuracao'),
            initialValue: duracao,
            decoration: const InputDecoration(labelText: 'Duração da partida'),
            items: [
              for (final d in opcoesDuracao)
                DropdownMenuItem(value: d, child: Text(Formatos.duracao(d))),
              const DropdownMenuItem(
                value: _outraDuracao,
                child: Text('Outra duração…'),
              ),
            ],
            onChanged: (v) {
              if (v == _outraDuracao) {
                _outraDuracaoPersonalizada();
              } else {
                setState(() => duracao = v);
              }
            },
            validator: (v) =>
                (duracao ?? 0) <= 0 ? 'Escolha a duração da partida' : null,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: siglaEstado,
            decoration: const InputDecoration(labelText: 'Estado'),
            items: refs.estados
                .map(
                  (s) => DropdownMenuItem(value: s.sigla, child: Text(s.sigla)),
                )
                .toList(),
            onChanged: (v) => setState(() {
              // Cidade e local de outro estado nunca ficam por engano.
              if (v != siglaEstado) {
                cidade.clear();
                local.clear();
                _localEscolhido(null);
              }
              siglaEstado = v;
            }),
            validator: (v) => v == null ? 'Selecione o estado' : null,
          ),
          const SizedBox(height: 10),
          CampoCidade(controller: cidade, siglaEstado: siglaEstado),
          const SizedBox(height: 10),
          CampoLocal(
            controller: local,
            siglaEstado: siglaEstado,
            cidade: _cidadeOficial,
            onLocal: _localEscolhido,
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
          idNivelTecnico: nivel!,
          dataHoraInicio: _inicio!,
          duracaoMinutos: duracao!,
          // Nome oficial do IBGE (o validador da cidade já garantiu).
          cidade: _cidadeOficial!,
          siglaEstado: siglaEstado!,
          nomeLocal: local.text.trim(),
          endereco: endereco,
          latitude: latitude,
          longitude: longitude,
          valorAluguelPorTime: taxaTexto.isEmpty
              ? null
              : double.parse(taxaTexto),
          descricao: opcional(observacoes),
          // Fora do formulário: um anúncio antigo editado mantém o que tinha.
          idCategoriaEtaria: e?.categoriaEtaria?.id,
          idMandoCampo: e?.mandoCampo?.id,
          quantidadeJogadores: e?.quantidadeJogadores,
          bairro: e?.bairro,
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
      carregar: () => app.repositorios.solicitacoes.listarDoMeuTime(),
      builder: (context, todas, _) {
        // Pendentes ainda não têm chat: ficam numa seção à parte, para o dono
        // analisar e o desafiante acompanhar. Conversas = chat liberado.
        final pendentes = todas.where((s) => s.status.emAberto).toList();
        final conversas = todas
            .where((s) => s.chatLiberado && s.idPartida != null)
            .toList();
        Widget secao(String titulo) => Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 4),
          child: Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
          children: [
            const PageTitle(
              'A conversa que vira jogo.',
              subtitle: 'Combine os detalhes com os responsáveis de cada time.',
            ),
            if (pendentes.isEmpty && conversas.isEmpty)
              const EmptyState(
                title: 'Nenhuma conversa por enquanto.',
                message:
                    'Demonstre interesse em um jogo ou aguarde solicitações para o seu anúncio. O chat abre quando o desafio é aceito.',
              ),
            if (pendentes.isNotEmpty) secao('Aguardando aceite'),
            for (final s in pendentes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ConversaTile(
                  solicitacao: s,
                  adversario: s.adversario(idMeuTime),
                  onTap: () => onOpen(s),
                ),
              ),
            if (conversas.isNotEmpty) secao('Conversas'),
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
        );
      },
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
              Crest(
                imagem: adversario.urlEscudo,
                label: adversario.siglaExibicao,
              ),
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
                          (s.aguardandoAceite
                              ? (s.timeAnunciante.id == adversario.id
                                    ? 'Aguardando o aceite para o jogo de ${Formatos.dataCurta(s.anuncio.dataHoraInicio)}.'
                                    : 'Quer jogar contra vocês em ${Formatos.dataCurta(s.anuncio.dataHoraInicio)}. Toque para analisar.')
                              : 'Jogo de ${Formatos.dataCurta(s.anuncio.dataHoraInicio)}.'),
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
    // Antes do aceite não há chat: nem pede as mensagens (a API recusaria).
    final lista = s.chatLiberado
        ? await repo.mensagens(widget.idSolicitacao)
        : const <Mensagem>[];
    mensagens
      ..clear()
      ..addAll(lista);
    return s;
  }

  /// Texto no lugar das mensagens enquanto o chat não está liberado.
  String _avisoSemChat(
    SolicitacaoConfronto s,
    bool souAnunciante,
  ) => switch (s.status) {
    StatusSolicitacao.pendente when souAnunciante =>
      '${s.timeSolicitante.nome} quer jogar contra vocês. Aceite o desafio para liberar o chat entre os capitães.',
    StatusSolicitacao.pendente =>
      'Solicitação enviada. O chat é liberado quando ${s.timeAnunciante.nome} aceitar o desafio.',
    _ =>
      'Solicitação ${s.status.rotulo.toLowerCase()}. O chat entre os capitães não está disponível.',
  };

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
        final souAnunciante = s.souAnunciante(idMeuTime);
        // Só o dono do anúncio aceita; o aceite confirma a partida e libera o chat.
        final (rotulo, acao) = switch (s) {
          _ when s.idPartida != null => (
            'Ver partida',
            () => widget.onVerPartida(s.idPartida!),
          ),
          _ when !s.status.emAberto => (s.status.rotulo, null),
          _ when souAnunciante => (
            'Aceitar desafio',
            () => widget.onConfirmar(s),
          ),
          _ => ('Aguardando o aceite', null),
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
                      imagem: adversario.urlEscudo,
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
                        if (!s.chatLiberado)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.lock_outline,
                                  color: AppColors.muted,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _avisoSemChat(s, souAnunciante),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        for (final m in mensagens)
                          _Balao(
                            texto: m.texto,
                            mine: m.idTimeRemetente == idMeuTime,
                          ),
                      ],
                    ),
                  ),
                  if (s.chatLiberado) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(9),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: input,
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
                            icon: const Icon(
                              Icons.send,
                              color: AppColors.forest,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TagPill(
                    s.status.emAberto ? 'Aguardando aceite' : s.status.rotulo,
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
    'Em análise',
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
                status: 'Em análise', // aguardando o aceite do anunciante
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
                          Crest(
                            imagem: time.urlEscudo,
                            label: time.siglaExibicao,
                            small: true,
                          ),
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
                              imagem: item.adversario!.urlEscudo,
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
                            orange: item.status == 'Em análise',
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
