import 'dart:convert';
import '../../core/formatters.dart';
import '../../models/anuncio_partida.dart';
import '../../models/local_esportivo.dart';
import '../../models/notificacao.dart';
import '../../models/partida.dart';
import '../../models/referencia.dart';
import '../../models/solicitacao_confronto.dart';
import '../../models/time.dart';
import '../../models/usuario.dart';
import '../contratos.dart';

/// DADOS FICTÍCIOS DE DEMONSTRAÇÃO — usados somente quando
/// `ApiConfig.useDemoData` está ligado (debug/testes). Nenhum nome, telefone ou
/// e-mail aqui pertence a pessoas reais. Em release o app usa a API.
///
/// Os repositórios abaixo simulam em memória as regras de negócio que a API
/// deverá implementar (encerramento automático, confirmação dupla etc.).
Repositorios criarRepositoriosDemo({DateTime? agora}) {
  final db = DemoBanco(agora ?? DateTime.now());
  return Repositorios(
    auth: _DemoAuth(db),
    referencias: _DemoReferencias(db),
    times: _DemoTimes(db),
    anuncios: _DemoAnuncios(db),
    solicitacoes: _DemoSolicitacoes(db),
    partidas: _DemoPartidas(db),
    notificacoes: _DemoNotificacoes(db),
    locais: const _DemoLocais(),
  );
}

const _society = ItemReferencia(
  id: 1,
  codigo: 'society',
  nome: 'Futebol society/sintético',
  ordem: 10,
);
const _quadra = ItemReferencia(
  id: 2,
  codigo: 'quadra',
  nome: 'Futebol de quadra',
  ordem: 20,
);
const _sub15 = ItemReferencia(
  id: 1,
  codigo: 'sub_15',
  nome: 'Sub-15',
  ordem: 10,
);
const _sub17 = ItemReferencia(
  id: 2,
  codigo: 'sub_17',
  nome: 'Sub-17',
  ordem: 20,
);
const _sub19 = ItemReferencia(
  id: 3,
  codigo: 'sub_19',
  nome: 'Sub-19',
  ordem: 30,
);
const _livre = ItemReferencia(id: 4, codigo: 'livre', nome: 'Livre', ordem: 40);
const _iniciante = ItemReferencia(
  id: 1,
  codigo: 'iniciante',
  nome: 'Iniciante',
  ordem: 10,
);
const _intermediario = ItemReferencia(
  id: 2,
  codigo: 'intermediario',
  nome: 'Intermediário',
  ordem: 20,
);
const _avancado = ItemReferencia(
  id: 3,
  codigo: 'avancado',
  nome: 'Avançado',
  ordem: 30,
);
const _casa = ItemReferencia(
  id: 1,
  codigo: 'casa',
  nome: 'Jogo em casa',
  ordem: 10,
);
const _fora = ItemReferencia(
  id: 2,
  codigo: 'fora',
  nome: 'Jogo fora',
  ordem: 20,
);
const _indiferente = ItemReferencia(
  id: 3,
  codigo: 'indiferente',
  nome: 'Indiferente',
  ordem: 30,
);

const _estados = [
  ('AC', 'Acre'),
  ('AL', 'Alagoas'),
  ('AP', 'Amapá'),
  ('AM', 'Amazonas'),
  ('BA', 'Bahia'),
  ('CE', 'Ceará'),
  ('DF', 'Distrito Federal'),
  ('ES', 'Espírito Santo'),
  ('GO', 'Goiás'),
  ('MA', 'Maranhão'),
  ('MT', 'Mato Grosso'),
  ('MS', 'Mato Grosso do Sul'),
  ('MG', 'Minas Gerais'),
  ('PA', 'Pará'),
  ('PB', 'Paraíba'),
  ('PR', 'Paraná'),
  ('PE', 'Pernambuco'),
  ('PI', 'Piauí'),
  ('RJ', 'Rio de Janeiro'),
  ('RN', 'Rio Grande do Norte'),
  ('RS', 'Rio Grande do Sul'),
  ('RO', 'Rondônia'),
  ('RR', 'Roraima'),
  ('SC', 'Santa Catarina'),
  ('SP', 'São Paulo'),
  ('SE', 'Sergipe'),
  ('TO', 'Tocantins'),
];

class DemoBanco {
  DemoBanco(this.agora) {
    _popular();
  }
  final DateTime agora;
  int _seq = 100;
  String novoId(String prefixo) => '$prefixo-${_seq++}';

  final referencias = Referencias(
    modalidades: const [_society, _quadra],
    categoriasEtarias: const [_sub15, _sub17, _sub19, _livre],
    niveisTecnicos: const [_iniciante, _intermediario, _avancado],
    mandosCampo: const [_casa, _fora, _indiferente],
    criteriosAvaliacao: const [
      ItemReferencia(
        id: 1,
        codigo: 'pontualidade',
        nome: 'Pontualidade',
        ordem: 10,
      ),
      ItemReferencia(
        id: 2,
        codigo: 'organizacao',
        nome: 'Organização',
        ordem: 20,
      ),
      ItemReferencia(id: 3, codigo: 'respeito', nome: 'Respeito', ordem: 30),
      ItemReferencia(
        id: 4,
        codigo: 'estrutura_local',
        nome: 'Estrutura do local',
        ordem: 40,
      ),
    ],
    estados: [for (final (s, n) in _estados) Estado(sigla: s, nome: n)],
  );

  late Usuario usuario;
  late Time meuTime;
  final times = <String, ResumoTime>{};
  final anuncios = <AnuncioPartida>[];
  final solicitacoes = <SolicitacaoConfronto>[];
  final mensagens = <String, List<Mensagem>>{};
  final partidas = <Partida>[];
  final notificacoes = <Notificacao>[];
  final avaliacoes = <AvaliacaoRecebida>[];

  DateTime _proximo(
    int weekday,
    int hora, [
    int minuto = 0,
    int semanasExtras = 0,
  ]) {
    var d = DateTime(agora.year, agora.month, agora.day, hora, minuto);
    while (d.weekday != weekday || !d.isAfter(agora)) {
      d = d.add(const Duration(days: 1));
    }
    return d.add(Duration(days: 7 * semanasExtras));
  }

  void _popular() {
    usuario = const Usuario(
      id: 'u-demo-1',
      nome: 'João Silva',
      email: 'capitao.demo@example.com',
      telefone: '(11) 90000-0000',
      cidade: 'São Paulo',
      siglaEstado: 'SP',
    );
    meuTime = const Time(
      id: 't-uniao',
      idCapitao: 'u-demo-1',
      nome: 'União FC',
      sigla: 'UFC',
      cidade: 'São Paulo',
      siglaEstado: 'SP',
      quantidadeJogadores: 14,
      modalidades: [_society],
      categoriaEtaria: _livre,
      nivelTecnico: _intermediario,
      descricao:
          'Desde 2015, reunimos amigos que compartilham a paixão pelo futebol. Jogamos com raça, respeito e aquela resenha que não pode faltar. Estamos sempre prontos para um bom amistoso!',
      anoFundacao: 2015,
      nomeCapitao: 'João Silva',
      telefoneContato: '(11) 90000-0000',
      totalPartidasRealizadas: 18,
      mediaAvaliacao: 4.9,
      totalAvaliacoes: 12,
    );
    const real = ResumoTime(
      id: 't-real',
      nome: 'Real Amigos FC',
      sigla: 'RA',
      cidade: 'São Paulo',
      siglaEstado: 'SP',
      nomeCapitao: 'Carlos',
    );
    const vila = ResumoTime(
      id: 't-vila',
      nome: 'Vila Nova Futsal',
      sigla: 'VILA',
      cidade: 'São Paulo',
      siglaEstado: 'SP',
      nomeCapitao: 'Marcos',
    );
    const atletico = ResumoTime(
      id: 't-atletico',
      nome: 'Atlético da Zona Sul',
      sigla: 'AC',
      cidade: 'São Paulo',
      siglaEstado: 'SP',
      nomeCapitao: 'Paulo',
    );
    const resenha = ResumoTime(
      id: 't-resenha',
      nome: 'Resenha Esporte Clube',
      sigla: 'EC',
      cidade: 'São Paulo',
      siglaEstado: 'SP',
      nomeCapitao: 'André',
    );
    for (final t in [meuTime.resumo, real, vila, atletico, resenha]) {
      times[t.id] = t;
    }

    const descricaoPadrao =
        'Estamos procurando um time parceiro para um amistoso! A ideia é jogar uma boa partida, com respeito e muita bola no pé. O espaço já está reservado. Podemos dividir a taxa do campo. Bora jogar?';
    AnuncioPartida anuncio(
      String id,
      ResumoTime t,
      ItemReferencia mod,
      ItemReferencia cat,
      ItemReferencia nivel,
      ItemReferencia mando,
      DateTime quando,
      String local,
      double km, {
      StatusAnuncio status = StatusAnuncio.ativo,
      int jogadores = 7,
    }) => AnuncioPartida(
      id: id,
      time: t,
      modalidade: mod,
      categoriaEtaria: cat,
      nivelTecnico: nivel,
      mandoCampo: mando,
      quantidadeJogadores: jogadores,
      dataHoraInicio: quando,
      cidade: 'São Paulo',
      siglaEstado: 'SP',
      nomeLocal: local,
      valorAluguelPorTime: 120,
      descricao: descricaoPadrao,
      status: status,
      distanciaKm: km,
    );

    anuncios.addAll([
      anuncio(
        'a-real',
        real,
        _society,
        _livre,
        _intermediario,
        _casa,
        _proximo(DateTime.saturday, 16),
        'Campo do Ibirapuera',
        3.2,
      ),
      anuncio(
        'a-vila',
        vila,
        _quadra,
        _livre,
        _intermediario,
        _indiferente,
        _proximo(DateTime.sunday, 10),
        'Quadra Vila Mariana',
        4.8,
        jogadores: 5,
      ),
      anuncio(
        'a-atletico',
        atletico,
        _society,
        _sub19,
        _avancado,
        _fora,
        _proximo(DateTime.saturday, 9),
        'Campo Santo Amaro',
        6.1,
      ),
      anuncio(
        'a-resenha',
        resenha,
        _society,
        _livre,
        _iniciante,
        _indiferente,
        _proximo(DateTime.sunday, 8, 30),
        'Arena da Saúde',
        7.5,
      ),
      anuncio(
        'a-uniao',
        meuTime.resumo,
        _society,
        _livre,
        _intermediario,
        _casa,
        _proximo(DateTime.sunday, 15, 0, 1),
        'Society Vila Mariana',
        0,
      ),
      anuncio(
        'a-uniao-antigo',
        meuTime.resumo,
        _society,
        _livre,
        _intermediario,
        _casa,
        _proximo(DateTime.saturday, 16, 0, 1),
        'Campo do Ibirapuera',
        0,
        status: StatusAnuncio.encerrado,
      ),
    ]);

    final recebida = SolicitacaoConfronto(
      id: 's-vila',
      anuncio: anuncios[4],
      timeSolicitante: vila,
      timeAnunciante: meuTime.resumo,
      status: StatusSolicitacao.pendente,
      dataSolicitacao: agora.subtract(const Duration(days: 1, hours: 2)),
    );
    final enviada = SolicitacaoConfronto(
      id: 's-real',
      anuncio: anuncios[0],
      timeSolicitante: meuTime.resumo,
      timeAnunciante: real,
      status: StatusSolicitacao.pendente,
      dataSolicitacao: agora.subtract(const Duration(hours: 3)),
    );
    final confirmadaAntiga = SolicitacaoConfronto(
      id: 's-real-antiga',
      anuncio: anuncios[5],
      timeSolicitante: real,
      timeAnunciante: meuTime.resumo,
      status: StatusSolicitacao.confirmada,
      chatLiberado: true,
      dataSolicitacao: agora.subtract(const Duration(days: 4)),
      confirmadoAnunciante: true,
      confirmadoSolicitante: true,
      idPartida: 'p-confirmada',
    );
    solicitacoes.addAll([enviada, recebida, confirmadaAntiga]);
    Mensagem msg(String s, String t, String texto, Duration atras) => Mensagem(
      id: novoId('m'),
      idSolicitacao: s,
      idTimeRemetente: t,
      texto: texto,
      dataEnvio: agora.subtract(atras),
    );
    mensagens['s-real'] = [
      msg(
        's-real',
        meuTime.id,
        'Olá! Temos interesse em jogar.',
        const Duration(hours: 3),
      ),
      msg(
        's-real',
        real.id,
        'Opa, João! Vocês conseguem jogar sábado às 16h?',
        const Duration(hours: 2),
      ),
      msg(
        's-real',
        meuTime.id,
        'Sim, podemos. Vamos combinar!',
        const Duration(hours: 1),
      ),
    ];
    mensagens['s-vila'] = [
      msg(
        's-vila',
        vila.id,
        'Olá! Nossa quadra está disponível domingo.',
        const Duration(days: 1),
      ),
    ];

    partidas.addAll([
      Partida(
        id: 'p-confirmada',
        idAnuncio: 'a-uniao-antigo',
        idSolicitacao: 's-real-antiga',
        timeAnunciante: meuTime.resumo,
        timeAdversario: real,
        modalidade: _society,
        dataHoraInicio: anuncios[5].dataHoraInicio,
        nomeLocal: 'Campo do Ibirapuera',
        endereco: 'Av. Exemplo, 1000',
        cidade: 'São Paulo',
        siglaEstado: 'SP',
        status: StatusPartida.confirmada,
      ),
      Partida(
        id: 'p-realizada-1',
        idSolicitacao: 's-hist-1',
        timeAnunciante: meuTime.resumo,
        timeAdversario: real,
        modalidade: _society,
        dataHoraInicio: agora.subtract(const Duration(days: 7)),
        nomeLocal: 'Campo do Ibirapuera',
        cidade: 'São Paulo',
        siglaEstado: 'SP',
        status: StatusPartida.realizada,
        golsAnunciante: 2,
        golsAdversario: 1,
      ),
      Partida(
        id: 'p-realizada-2',
        idSolicitacao: 's-hist-2',
        timeAnunciante: atletico,
        timeAdversario: meuTime.resumo,
        modalidade: _society,
        dataHoraInicio: agora.subtract(const Duration(days: 14)),
        nomeLocal: 'Campo Santo Amaro',
        cidade: 'São Paulo',
        siglaEstado: 'SP',
        status: StatusPartida.realizada,
        golsAnunciante: 1,
        golsAdversario: 1,
        avaliadaPeloMeuTime: true,
      ),
    ]);

    avaliacoes.add(
      AvaliacaoRecebida(
        notaMedia: 5,
        timeAvaliador: real,
        dataAvaliacao: agora.subtract(const Duration(days: 6)),
        comentario:
            'Time pontual, organizado e com muito respeito em campo. Bora marcar a próxima!',
      ),
    );

    notificacoes.addAll([
      Notificacao(
        id: 'n1',
        tipo: TipoNotificacao.solicitacaoRecebida,
        titulo: 'Tem rival querendo jogo!',
        mensagem:
            'O time Vila Nova Futsal demonstrou interesse no seu anúncio.',
        dataCriacao: agora.subtract(const Duration(minutes: 5)),
        idSolicitacao: 's-vila',
      ),
      Notificacao(
        id: 'n2',
        tipo: TipoNotificacao.partidaConfirmada,
        titulo: 'Pode chamar a equipe.',
        mensagem: 'Sua partida contra o Real Amigos FC foi confirmada.',
        dataCriacao: agora.subtract(const Duration(minutes: 30)),
        idPartida: 'p-confirmada',
      ),
      Notificacao(
        id: 'n3',
        tipo: TipoNotificacao.mensagemRecebida,
        titulo: 'A conversa tá rolando.',
        mensagem: 'Você recebeu uma nova mensagem de Real Amigos FC.',
        dataCriacao: agora.subtract(const Duration(hours: 1)),
        idSolicitacao: 's-real',
      ),
      Notificacao(
        id: 'n4',
        tipo: TipoNotificacao.anuncioExpirando,
        titulo: 'Seu anúncio está próximo de expirar.',
        mensagem:
            'Atualize a disponibilidade para continuar encontrando adversários.',
        dataCriacao: agora.subtract(const Duration(days: 1)),
        idAnuncio: 'a-uniao',
      ),
    ]);
  }

  int contarSolicitacoesAbertas(String idAnuncio) => solicitacoes
      .where((s) => s.anuncio.id == idAnuncio && s.status.emAberto)
      .length;

  AnuncioPartida comContagem(AnuncioPartida a) =>
      a.copyWith(totalSolicitacoes: contarSolicitacoesAbertas(a.id));

  ItemReferencia _ref(List<ItemReferencia> lista, int? id) =>
      lista.firstWhere((i) => i.id == id, orElse: () => lista.first);

  AnuncioPartida deRascunho(
    String id,
    RascunhoAnuncio r, {
    StatusAnuncio status = StatusAnuncio.ativo,
  }) => AnuncioPartida(
    id: id,
    time: meuTime.resumo,
    modalidade: _ref(referencias.modalidades, r.idModalidade),
    categoriaEtaria: _ref(referencias.categoriasEtarias, r.idCategoriaEtaria),
    nivelTecnico: _ref(referencias.niveisTecnicos, r.idNivelTecnico),
    mandoCampo: r.idMandoCampo == null
        ? null
        : _ref(referencias.mandosCampo, r.idMandoCampo),
    quantidadeJogadores: r.quantidadeJogadores,
    dataHoraInicio: r.dataHoraInicio,
    cidade: r.cidade,
    siglaEstado: r.siglaEstado,
    bairro: r.bairro,
    nomeLocal: r.nomeLocal,
    endereco: r.endereco,
    valorAluguelPorTime: r.valorAluguelPorTime,
    descricao: r.descricao,
    status: status,
  );
}

Never _naoEncontrado(String o) => throw StateError('$o não encontrado.');

class _DemoAuth implements AuthRepository {
  _DemoAuth(this.db);
  final DemoBanco db;
  bool _logado = true; // simula sessão já salva no aparelho
  Sessao get _sessao => Sessao(usuario: db.usuario, time: db.meuTime);

  @override
  Future<Sessao?> sessaoAtual() async => _logado ? _sessao : null;
  @override
  Future<Sessao> entrar({required String email, required String senha}) async {
    _logado = true;
    return _sessao;
  }

  @override
  Future<Sessao> cadastrar(CadastroCapitao d) async {
    db.usuario = Usuario(
      id: db.usuario.id,
      nome: d.nome,
      email: d.email,
      cidade: d.cidade,
      siglaEstado: d.siglaEstado,
    );
    db.meuTime = Time(
      id: db.meuTime.id,
      idCapitao: db.usuario.id,
      nome: d.nomeTime,
      cidade: d.cidade,
      siglaEstado: d.siglaEstado,
      nomeCapitao: d.nome,
    );
    _logado = true;
    return _sessao;
  }

  @override
  Future<void> solicitarRecuperacaoSenha(String email) async {}
  @override
  Future<void> sair() async => _logado = false;
}

class _DemoReferencias implements ReferenciaRepository {
  _DemoReferencias(this.db);
  final DemoBanco db;
  @override
  Future<Referencias> carregar() async => db.referencias;
}

class _DemoTimes implements TimeRepository {
  _DemoTimes(this.db);
  final DemoBanco db;
  @override
  Future<Time> buscar(String idTime) async {
    if (idTime == db.meuTime.id) return db.meuTime;
    final r = db.times[idTime] ?? _naoEncontrado('Time');
    return Time(
      id: r.id,
      idCapitao: 'u-${r.id}',
      nome: r.nome,
      sigla: r.sigla,
      cidade: r.cidade ?? 'São Paulo',
      siglaEstado: r.siglaEstado ?? 'SP',
      quantidadeJogadores: 12,
      nomeCapitao: r.nomeCapitao,
      anoFundacao: 2010,
      descricao:
          'Um time de amigos, um só futebol. A gente joga pela resenha, pela amizade e por aquele gol no último minuto.',
      totalPartidasRealizadas: 24,
      mediaAvaliacao: 4.9,
      totalAvaliacoes: 12,
      verificado: true,
    );
  }

  @override
  Future<Time> atualizar(String idTime, AtualizacaoTime dados) async {
    db.meuTime = db.meuTime.copyWith(
      nome: dados.nome,
      descricao: dados.descricao,
    );
    final resumo = db.meuTime.resumo;
    db.times[resumo.id] = resumo;
    return db.meuTime;
  }

  /// Demonstração: a foto fica em memória, como endereço `data:`.
  @override
  Future<Time> enviarEscudo(String idTime, ImagemSelecionada imagem) async {
    db.meuTime = db.meuTime.copyWith(
      urlEscudo: 'data:${imagem.tipo};base64,${base64Encode(imagem.bytes)}',
    );
    db.times[idTime] = db.meuTime.resumo;
    return db.meuTime;
  }
}

class _DemoAnuncios implements AnuncioRepository {
  _DemoAnuncios(this.db);
  final DemoBanco db;

  @override
  Future<List<AnuncioPartida>> buscar(FiltroAnuncios f) async {
    final texto = (f.texto ?? '').toLowerCase();
    return db.anuncios
        .where((a) => a.time.id != db.meuTime.id && a.aceitaSolicitacoes)
        .where(
          (a) =>
              texto.isEmpty ||
              '${a.time.nome} ${a.cidade} ${a.nomeLocal} ${a.bairro ?? ''}'
                  .toLowerCase()
                  .contains(texto),
        )
        .where(
          (a) => f.idModalidade == null || a.modalidade.id == f.idModalidade,
        )
        .where(
          (a) =>
              f.idCategoriaEtaria == null ||
              a.categoriaEtaria?.id == f.idCategoriaEtaria,
        )
        .where(
          (a) =>
              f.idNivelTecnico == null ||
              a.nivelTecnico?.id == f.idNivelTecnico,
        )
        .where(
          (a) =>
              f.raioKm == null ||
              a.distanciaKm == null ||
              a.distanciaKm! <= f.raioKm!,
        )
        .where(
          (a) =>
              f.cidade == null ||
              a.cidade.toLowerCase().startsWith(f.cidade!.toLowerCase()),
        )
        .where(
          (a) =>
              f.horario == null ||
              Formatos.hora(a.dataHoraInicio).compareTo(f.horario!) >= 0,
        )
        .where(
          (a) =>
              f.data == null ||
              (a.dataHoraInicio.year == f.data!.year &&
                  a.dataHoraInicio.month == f.data!.month &&
                  a.dataHoraInicio.day == f.data!.day),
        )
        .map(db.comContagem)
        .toList()
      ..sort((a, b) => a.dataHoraInicio.compareTo(b.dataHoraInicio));
  }

  @override
  Future<AnuncioPartida> obter(String id) async => db.comContagem(
    db.anuncios.firstWhere(
      (a) => a.id == id,
      orElse: () => _naoEncontrado('Anúncio'),
    ),
  );

  @override
  Future<List<AnuncioPartida>> listarDoMeuTime() async => db.anuncios
      .where(
        (a) =>
            a.time.id == db.meuTime.id && a.status != StatusAnuncio.encerrado,
      )
      .map(db.comContagem)
      .toList();

  @override
  Future<AnuncioPartida> criar(RascunhoAnuncio dados) async {
    final novo = db.deRascunho(db.novoId('a'), dados);
    db.anuncios.add(novo);
    return novo;
  }

  int _indice(String id) {
    final i = db.anuncios.indexWhere(
      (a) => a.id == id && a.time.id == db.meuTime.id,
    );
    return i < 0 ? _naoEncontrado('Anúncio') : i;
  }

  @override
  Future<AnuncioPartida> atualizar(String id, RascunhoAnuncio dados) async {
    final i = _indice(id);
    db.anuncios[i] = db.deRascunho(id, dados, status: db.anuncios[i].status);
    return db.comContagem(db.anuncios[i]);
  }

  @override
  Future<AnuncioPartida> alterarStatus(String id, StatusAnuncio status) async {
    final i = _indice(id);
    if (db.anuncios[i].status == StatusAnuncio.encerrado) {
      throw StateError('Anúncio com partida confirmada não pode ser reaberto.');
    }
    db.anuncios[i] = db.anuncios[i].copyWith(status: status);
    return db.comContagem(db.anuncios[i]);
  }

  @override
  Future<void> excluir(String id) async => db.anuncios.removeAt(_indice(id));
}

class _DemoSolicitacoes implements SolicitacaoRepository {
  _DemoSolicitacoes(this.db);
  final DemoBanco db;

  int _indice(String id) {
    final i = db.solicitacoes.indexWhere((s) => s.id == id);
    return i < 0 ? _naoEncontrado('Solicitação') : i;
  }

  SolicitacaoConfronto _com(
    SolicitacaoConfronto s, {
    StatusSolicitacao? status,
    bool? confAnunciante,
    bool? confSolicitante,
    String? idPartida,
    String? ultimaMensagem,
    DateTime? dataUltima,
    int? naoLidas,
  }) => SolicitacaoConfronto(
    id: s.id,
    anuncio: s.anuncio,
    timeSolicitante: s.timeSolicitante,
    timeAnunciante: s.timeAnunciante,
    status: status ?? s.status,
    dataSolicitacao: s.dataSolicitacao,
    mensagemInicial: s.mensagemInicial,
    dataResposta: status != null ? DateTime.now() : s.dataResposta,
    confirmadoAnunciante: confAnunciante ?? s.confirmadoAnunciante,
    confirmadoSolicitante: confSolicitante ?? s.confirmadoSolicitante,
    idPartida: idPartida ?? s.idPartida,
    ultimaMensagem: ultimaMensagem ?? s.ultimaMensagem,
    dataUltimaMensagem: dataUltima ?? s.dataUltimaMensagem,
    mensagensNaoLidas: naoLidas ?? s.mensagensNaoLidas,
    chatLiberado: (status ?? s.status) == StatusSolicitacao.confirmada,
  );

  @override
  Future<List<SolicitacaoConfronto>> listarDoMeuTime() async =>
      db.solicitacoes
          .where(
            (s) =>
                s.timeAnunciante.id == db.meuTime.id ||
                s.timeSolicitante.id == db.meuTime.id,
          )
          .toList()
        ..sort(
          (a, b) => (b.dataUltimaMensagem ?? b.dataSolicitacao).compareTo(
            a.dataUltimaMensagem ?? a.dataSolicitacao,
          ),
        );

  @override
  Future<SolicitacaoConfronto> obter(String id) async =>
      db.solicitacoes[_indice(id)];

  @override
  Future<SolicitacaoConfronto> solicitar(
    String idAnuncio, {
    String? mensagem,
  }) async {
    final anuncio = db.anuncios.firstWhere(
      (a) => a.id == idAnuncio,
      orElse: () => _naoEncontrado('Anúncio'),
    );
    if (!anuncio.aceitaSolicitacoes) {
      throw StateError('Este anúncio não aceita novas solicitações.');
    }
    if (anuncio.time.id == db.meuTime.id) {
      throw StateError('Você não pode solicitar o próprio anúncio.');
    }
    final existente = db.solicitacoes.where(
      (s) =>
          s.anuncio.id == idAnuncio &&
          s.timeSolicitante.id == db.meuTime.id &&
          s.status.emAberto,
    );
    if (existente.isNotEmpty) return existente.first;
    final nova = SolicitacaoConfronto(
      id: db.novoId('s'),
      anuncio: anuncio,
      timeSolicitante: db.meuTime.resumo,
      timeAnunciante: anuncio.time,
      status: StatusSolicitacao.pendente,
      dataSolicitacao: DateTime.now(),
      mensagemInicial: mensagem,
    );
    db.solicitacoes.insert(0, nova);
    return nova;
  }

  @override
  Future<SolicitacaoConfronto> confirmar(String id) async {
    final i = _indice(id);
    var s = db.solicitacoes[i];
    if (!s.status.emAberto) {
      throw StateError('Esta solicitação não está mais em aberto.');
    }
    // Mesma regra da API: só o time anunciante aceita; o pedido já é a
    // concordância do desafiante.
    if (s.timeAnunciante.id != db.meuTime.id) {
      throw StateError(
        'Somente o capitão do time anunciante aceita o desafio.',
      );
    }
    s = _com(s, confAnunciante: true, confSolicitante: true);
    final partida = Partida(
      id: db.novoId('p'),
      idAnuncio: s.anuncio.id,
      idSolicitacao: s.id,
      timeAnunciante: s.timeAnunciante,
      timeAdversario: s.timeSolicitante,
      modalidade: s.anuncio.modalidade,
      dataHoraInicio: s.anuncio.dataHoraInicio,
      nomeLocal: s.anuncio.nomeLocal,
      endereco: s.anuncio.endereco,
      cidade: s.anuncio.cidade,
      siglaEstado: s.anuncio.siglaEstado,
      status: StatusPartida.confirmada,
    );
    db.partidas.add(partida);
    s = _com(s, status: StatusSolicitacao.confirmada, idPartida: partida.id);
    db.solicitacoes[i] = s;
    // Regra: o anúncio deixa de aceitar solicitações e as demais são encerradas
    // (a API notifica os capitães afetados).
    final ia = db.anuncios.indexWhere((a) => a.id == s.anuncio.id);
    if (ia >= 0) {
      db.anuncios[ia] = db.anuncios[ia].copyWith(
        status: StatusAnuncio.encerrado,
      );
    }
    for (var j = 0; j < db.solicitacoes.length; j++) {
      final o = db.solicitacoes[j];
      if (j != i && o.anuncio.id == s.anuncio.id && o.status.emAberto) {
        db.solicitacoes[j] = _com(o, status: StatusSolicitacao.encerrada);
      }
    }
    return s;
  }

  @override
  Future<SolicitacaoConfronto> recusar(String id) async {
    final i = _indice(id);
    return db.solicitacoes[i] = _com(
      db.solicitacoes[i],
      status: StatusSolicitacao.recusada,
    );
  }

  @override
  Future<SolicitacaoConfronto> cancelar(String id) async {
    final i = _indice(id);
    return db.solicitacoes[i] = _com(
      db.solicitacoes[i],
      status: StatusSolicitacao.cancelada,
    );
  }

  void _exigirChat(int i) {
    if (db.solicitacoes[i].status != StatusSolicitacao.confirmada) {
      throw StateError(
        'O chat é liberado quando o time anunciante aceita o desafio.',
      );
    }
  }

  @override
  Future<List<Mensagem>> mensagens(String id) async {
    final i = _indice(id);
    _exigirChat(i);
    db.solicitacoes[i] = _com(db.solicitacoes[i], naoLidas: 0);
    return List.of(db.mensagens[id] ?? const []);
  }

  @override
  Future<Mensagem> enviarMensagem(String id, String texto) async {
    final i = _indice(id);
    _exigirChat(i);
    final m = Mensagem(
      id: db.novoId('m'),
      idSolicitacao: id,
      idTimeRemetente: db.meuTime.id,
      texto: texto,
      dataEnvio: DateTime.now(),
    );
    (db.mensagens[id] ??= []).add(m);
    db.solicitacoes[i] = _com(
      db.solicitacoes[i],
      ultimaMensagem: texto,
      dataUltima: m.dataEnvio,
    );
    return m;
  }
}

class _DemoPartidas implements PartidaRepository {
  _DemoPartidas(this.db);
  final DemoBanco db;

  bool _minha(Partida p) =>
      p.timeAnunciante.id == db.meuTime.id ||
      p.timeAdversario.id == db.meuTime.id;

  @override
  Future<List<Partida>> listarDoMeuTime() async =>
      db.partidas.where(_minha).toList()
        ..sort((a, b) => b.dataHoraInicio.compareTo(a.dataHoraInicio));

  @override
  Future<Partida?> proximaDoMeuTime() async {
    final futuras =
        db.partidas
            .where((p) => _minha(p) && p.status == StatusPartida.confirmada)
            .toList()
          ..sort((a, b) => a.dataHoraInicio.compareTo(b.dataHoraInicio));
    return futuras.isEmpty ? null : futuras.first;
  }

  int _indice(String id) {
    final i = db.partidas.indexWhere((p) => p.id == id);
    return i < 0 ? _naoEncontrado('Partida') : i;
  }

  @override
  Future<Partida> obter(String id) async => db.partidas[_indice(id)];

  @override
  Future<Partida> cancelar(String id, {String? motivo}) async {
    final i = _indice(id);
    final p = db.partidas[i];
    return db.partidas[i] = Partida(
      id: p.id,
      idAnuncio: p.idAnuncio,
      idSolicitacao: p.idSolicitacao,
      timeAnunciante: p.timeAnunciante,
      timeAdversario: p.timeAdversario,
      modalidade: p.modalidade,
      dataHoraInicio: p.dataHoraInicio,
      nomeLocal: p.nomeLocal,
      endereco: p.endereco,
      cidade: p.cidade,
      siglaEstado: p.siglaEstado,
      status: StatusPartida.cancelada,
    );
  }

  @override
  Future<void> avaliar(NovaAvaliacao a) async {
    final i = _indice(a.idPartida);
    final p = db.partidas[i];
    db.partidas[i] = Partida(
      id: p.id,
      idAnuncio: p.idAnuncio,
      idSolicitacao: p.idSolicitacao,
      timeAnunciante: p.timeAnunciante,
      timeAdversario: p.timeAdversario,
      modalidade: p.modalidade,
      dataHoraInicio: p.dataHoraInicio,
      nomeLocal: p.nomeLocal,
      endereco: p.endereco,
      cidade: p.cidade,
      siglaEstado: p.siglaEstado,
      status: p.status,
      golsAnunciante: p.golsAnunciante,
      golsAdversario: p.golsAdversario,
      avaliadaPeloMeuTime: true,
    );
  }

  @override
  Future<List<AvaliacaoRecebida>> avaliacoesDoTime(String idTime) async =>
      idTime == db.meuTime.id ? List.of(db.avaliacoes) : const [];
}

class _DemoNotificacoes implements NotificacaoRepository {
  _DemoNotificacoes(this.db);
  final DemoBanco db;
  @override
  Future<List<Notificacao>> listar() async => List.of(db.notificacoes);
  @override
  Future<void> marcarComoLida(String id) async {}
}

/// Demonstração: sem fonte real de locais, não sugere nada (nunca inventa).
class _DemoLocais implements LocalRepository {
  const _DemoLocais();
  @override
  Future<LocaisDaCidade> daCidade(String siglaEstado, String cidade) async =>
      const LocaisDaCidade([]);
}
