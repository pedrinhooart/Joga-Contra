import 'package:flutter/material.dart';
import 'core/formatters.dart';
import 'models/anuncio_partida.dart';
import 'models/notificacao.dart';
import 'models/partida.dart';
import 'models/solicitacao_confronto.dart';
import 'models/time.dart';
import 'screens/account_screens.dart';
import 'screens/activity_screens.dart';
import 'screens/discover_screen.dart';
import 'screens/game_detail_screen.dart';
import 'screens/home_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/carregador.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Vive com a tela: o diálogo ainda o usa durante a animação de fechar.
  final _nomeTime = TextEditingController();

  static const _paginasAuth = {'login', 'register', 'forgot'};

  String page = 'home', gameTab = 'Todos';
  FiltrosBusca filtrosBusca = const FiltrosBusca();
  AnuncioPartida? anuncioSelecionado, anuncioEditando;
  String? idSolicitacao, idPartida;
  Partida? partidaAvaliada;

  /// Incrementado após alterações para recarregar a tela atual.
  int versao = 0;

  @override
  void dispose() {
    _nomeTime.dispose();
    super.dispose();
  }

  static const titles = <String, String>{
    'home': 'Início',
    'search': 'Buscar adversário',
    'create': 'Anunciar jogo',
    'conversations': 'Conversas',
    'chat': 'Conversa',
    'games': 'Meus jogos',
    'ads': 'Meus anúncios',
    'map': 'Mapa de jogos',
    'profile': 'Perfil do time',
    'notifications': 'Notificações',
    'details': 'Detalhes do jogo',
    'confirmed': 'Partida confirmada',
    'review': 'Avaliar partida',
    'login': 'Entrar',
    'register': 'Criar conta',
    'forgot': 'Recuperar acesso',
  };

  AppState get app => AppScope.of(context);

  void go(String next) => setState(() {
    if (next == 'create') anuncioEditando = null;
    page = next;
  });

  void _recarregar() => setState(() => versao++);

  void openAnuncio(AnuncioPartida anuncio) => setState(() {
    anuncioSelecionado = anuncio;
    page = 'details';
  });

  void openChat(String id) => setState(() {
    idSolicitacao = id;
    page = 'chat';
  });

  void openPartida(String id) => setState(() {
    idPartida = id;
    page = 'confirmed';
  });

  void notify(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (app.inicializando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.green)),
      );
    }
    if (app.erroInicial != null) {
      return Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const SizedBox(height: 60),
              ErroCarregamento(
                mensagem: app.erroInicial!,
                onTentar: app.inicializar,
              ),
            ],
          ),
        ),
      );
    }
    // Sem sessão, somente as telas de autenticação ficam acessíveis.
    final atual = app.autenticado || _paginasAuth.contains(page)
        ? page
        : 'login';
    final tabs = const ['home', 'search', 'create', 'conversations', 'profile'];
    final tabIndex = tabs.indexOf(atual);
    final telaAuth = _paginasAuth.contains(atual);
    return PopScope(
      canPop: atual == 'home' || atual == 'login',
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) go(telaAuth ? 'login' : _backFor(atual));
      },
      child: Scaffold(
        appBar: telaAuth
            ? null
            : AppBar(
                leading: atual == 'home'
                    ? null
                    : IconButton(
                        onPressed: () => go(_backFor(atual)),
                        icon: const Icon(Icons.arrow_back),
                      ),
                title: Text(
                  titles[atual] ?? 'Joga Contra',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Notificações',
                    onPressed: () => go('notifications'),
                    icon: const Icon(Icons.notifications_none),
                  ),
                  IconButton(
                    tooltip: 'Perfil',
                    onPressed: () => go('profile'),
                    icon: CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFFEAF2E8),
                      child: Text(
                        app.usuario?.inicial ?? '',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: AppColors.border),
                ),
              ),
        body: SafeArea(
          top: false,
          child: KeyedSubtree(
            key: ValueKey('$atual#$versao'),
            child: _screen(atual),
          ),
        ),
        bottomNavigationBar: telaAuth
            ? null
            : NavigationBar(
                selectedIndex: tabIndex < 0 ? 0 : tabIndex,
                onDestinationSelected: (i) => go(tabs[i]),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Início',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.search),
                    label: 'Buscar',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.add_circle_outline),
                    selectedIcon: Icon(Icons.add_circle),
                    label: 'Anunciar',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.chat_bubble_outline),
                    selectedIcon: Icon(Icons.chat_bubble),
                    label: 'Conversas',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Perfil',
                  ),
                ],
              ),
      ),
    );
  }

  String _backFor(String route) => switch (route) {
    'details' => 'search',
    'chat' => 'conversations',
    'confirmed' => 'games',
    'review' => 'games',
    'notifications' => 'home',
    'map' => 'search',
    _ => 'home',
  };

  Widget _home() => HomeScreen(
    onNavigate: go,
    onSelectAnuncio: openAnuncio,
    onOpenPartida: (p) => openPartida(p.id),
  );

  Widget _screen(String atual) => switch (atual) {
    'home' => _home(),
    'search' => DiscoverScreen(
      filtros: filtrosBusca,
      onFiltros: (f) => filtrosBusca = f,
      onSelectAnuncio: openAnuncio,
      onMap: () => go('map'),
    ),
    'details' when anuncioSelecionado != null => GameDetailScreen(
      anuncio: anuncioSelecionado!,
      onInterest: () => _demonstrarInteresse(anuncioSelecionado!),
    ),
    'create' => CreateGameScreen(
      editando: anuncioEditando,
      onSalvar: _salvarAnuncio,
    ),
    'conversations' => ConversationsScreen(onOpen: (s) => openChat(s.id)),
    'chat' when idSolicitacao != null => ChatScreen(
      idSolicitacao: idSolicitacao!,
      onConfirmar: _confirmarPartida,
      onVerPartida: openPartida,
    ),
    'confirmed' when idPartida != null => ConfirmationScreen(
      idPartida: idPartida!,
      onChat: openChat,
      onCancel: _cancelarPartida,
    ),
    'games' => GamesScreen(
      tab: gameTab,
      onTab: (v) => setState(() => gameTab = v),
      onAnuncios: () => go('ads'),
      onChat: (s) => openChat(s.id),
      onPartida: (p) => openPartida(p.id),
      onAvaliar: (p) => setState(() {
        partidaAvaliada = p;
        page = 'review';
      }),
    ),
    'ads' => AdsScreen(
      onCreate: () => go('create'),
      onEdit: (ad) => setState(() {
        anuncioEditando = ad;
        page = 'create';
      }),
      onConversations: () => go('conversations'),
    ),
    'profile' => ProfileScreen(
      onEdit: _editProfile,
      onGames: () => go('games'),
      onLogout: _sair,
    ),
    'notifications' => NotificationsScreen(onOpen: _abrirNotificacao),
    'map' => MapScreen(onSelect: openAnuncio),
    'review' when partidaAvaliada != null => ReviewScreen(
      partida: partidaAvaliada!,
      onSubmit: _avaliar,
    ),
    'login' || 'register' || 'forgot' => AuthScreen(
      page: atual,
      onPage: go,
      onDone: (mensagem) {
        notify(mensagem);
        go(atual == 'forgot' ? 'login' : 'home');
      },
    ),
    _ => _home(),
  };

  Future<bool> _perguntar(String title, String body, String positive) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Agora não'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(positive),
            ),
          ],
        ),
      ) ==
      true;

  /// Executa uma ação de dados mostrando o erro da API, se houver.
  Future<T?> _executar<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } catch (e) {
      if (mounted) notify('$e');
      return null;
    }
  }

  Future<void> _demonstrarInteresse(AnuncioPartida anuncio) async {
    final ok = await _perguntar(
      'Bora marcar esse jogo?',
      'Você quer demonstrar interesse neste jogo? Vamos abrir uma conversa com o responsável pelo time.',
      'Sim, tenho interesse',
    );
    if (!ok || !mounted) return;
    final s = await _executar(
      () => app.repositorios.solicitacoes.solicitar(anuncio.id),
    );
    if (s == null || !mounted) return;
    openChat(s.id);
    notify('Interesse enviado! Combine os detalhes na conversa.');
  }

  Future<void> _confirmarPartida(SolicitacaoConfronto s) async {
    final meuTime = app.time!;
    final adversario = s.adversario(meuTime.id);
    final ok = await _perguntar(
      'Tudo combinado?',
      'Confirme a partida de ${meuTime.nome} contra ${adversario.nome}, ${Formatos.dataCurta(s.anuncio.dataHoraInicio)} às ${Formatos.hora(s.anuncio.dataHoraInicio)}.',
      'Confirmar partida',
    );
    if (!ok || !mounted) return;
    final atualizada = await _executar(
      () => app.repositorios.solicitacoes.confirmar(s.id),
    );
    if (atualizada == null || !mounted) return;
    if (atualizada.idPartida != null) {
      openPartida(atualizada.idPartida!);
    } else {
      notify('Confirmação registrada. Aguardando o outro time confirmar.');
      _recarregar();
    }
  }

  Future<void> _cancelarPartida(Partida p) async {
    final ok = await _perguntar(
      'Cancelar a partida?',
      'O outro time será avisado. Tenha certeza antes de cancelar.',
      'Cancelar partida',
    );
    if (!ok || !mounted) return;
    final cancelada = await _executar(
      () => app.repositorios.partidas.cancelar(p.id),
    );
    if (cancelada == null || !mounted) return;
    go('games');
    notify('Partida cancelada. O time adversário será avisado.');
  }

  Future<void> _salvarAnuncio(RascunhoAnuncio dados) async {
    final editando = anuncioEditando;
    final salvo = await _executar(
      () => editando == null
          ? app.repositorios.anuncios.criar(dados)
          : app.repositorios.anuncios.atualizar(editando.id, dados),
    );
    if (salvo == null || !mounted) return;
    setState(() {
      anuncioEditando = null;
      page = 'ads';
    });
    notify('Anúncio salvo! Os times da sua região já podem encontrá-lo.');
  }

  Future<void> _avaliar(NovaAvaliacao avaliacao) async {
    final ok = await _executar(() async {
      await app.repositorios.partidas.avaliar(avaliacao);
      return true;
    });
    if (ok != true || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Valeu pelo feedback!'),
        content: const Text(
          'Sua avaliação ajuda todo mundo a encontrar bons adversários.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
    if (mounted) go('games');
  }

  void _abrirNotificacao(Notificacao n) => switch (n.tipo) {
    TipoNotificacao.solicitacaoRecebida || TipoNotificacao.mensagemRecebida
        when n.idSolicitacao != null =>
      openChat(n.idSolicitacao!),
    TipoNotificacao.partidaConfirmada || TipoNotificacao.partidaCancelada
        when n.idPartida != null =>
      openPartida(n.idPartida!),
    TipoNotificacao.anuncioExpirando => go('ads'),
    TipoNotificacao.solicitacaoRecebida ||
    TipoNotificacao.mensagemRecebida => go('conversations'),
    _ => go('games'),
  };

  Future<void> _editProfile() async {
    _nomeTime.text = app.time!.nome;
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seu time, do seu jeito.'),
        content: TextField(
          controller: _nomeTime,
          decoration: const InputDecoration(labelText: 'Nome do time'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _nomeTime.text),
            child: const Text('Salvar perfil'),
          ),
        ],
      ),
    );
    if (value == null || value.trim().isEmpty || !mounted) return;
    final ok = await _executar(() async {
      await app.atualizarTime(AtualizacaoTime(nome: value.trim()));
      return true;
    });
    if (ok == true && mounted) notify('Perfil atualizado com sucesso!');
  }

  Future<void> _sair() async {
    await _executar(app.sair);
    if (mounted) go('login');
  }
}
