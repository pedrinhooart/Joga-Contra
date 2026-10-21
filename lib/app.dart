import 'package:flutter/material.dart';
import 'models/game.dart';
import 'repositories/mock_repository.dart';
import 'screens/account_screens.dart';
import 'screens/activity_screens.dart';
import 'screens/discover_screen.dart';
import 'screens/game_detail_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String page = 'home', query = '', sport = 'Todos', gameTab = 'Todos';
  String teamName = 'União FC';
  Game selected = MockRepository.games.first;
  bool confirmed = false;
  int? editingAd;
  final ads = <String>['União FC procura adversário|Ativo'];

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

  void go(String next) => setState(() => page = next);
  void openGame(Game game) => setState(() {
    selected = game;
    page = 'details';
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
    final tabs = const ['home', 'search', 'create', 'conversations', 'profile'];
    final tabIndex = tabs.indexOf(page);
    final showNavigation = !['login', 'register', 'forgot'].contains(page);
    return PopScope(
      canPop: page == 'home',
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) go('home');
      },
      child: Scaffold(
        appBar:
            page.startsWith('login') || page == 'register' || page == 'forgot'
            ? null
            : AppBar(
                leading: page == 'home'
                    ? null
                    : IconButton(
                        onPressed: () => go(_backFor(page)),
                        icon: const Icon(Icons.arrow_back),
                      ),
                title: Text(
                  titles[page] ?? 'Joga Contra',
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
                    icon: const CircleAvatar(
                      radius: 14,
                      backgroundColor: Color(0xFFEAF2E8),
                      child: Text(
                        'J',
                        style: TextStyle(
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
        body: SafeArea(top: false, child: _screen()),
        bottomNavigationBar: showNavigation
            ? NavigationBar(
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
              )
            : null,
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
    'login' || 'register' || 'forgot' => 'home',
    _ => 'home',
  };

  Widget _screen() => switch (page) {
    'home' => HomeScreen(
      games: MockRepository.games,
      teamName: teamName,
      onNavigate: go,
      onSelectGame: openGame,
    ),
    'search' => DiscoverScreen(
      games: MockRepository.games,
      query: query,
      sport: sport,
      onQuery: (v) => setState(() => query = v),
      onSport: (v) => setState(() => sport = v),
      onSelectGame: openGame,
      onMap: () => go('map'),
    ),
    'details' => GameDetailScreen(
      game: selected,
      onInterest: () => _confirm('interest'),
    ),
    'create' => CreateGameScreen(
      editing: editingAd != null,
      onPublish: (title) {
        setState(() {
          if (editingAd case final index?) {
            ads[index] = '$teamName · $title|Ativo';
          } else {
            ads.add('$teamName · $title|Ativo');
          }
          editingAd = null;
          page = 'ads';
        });
        notify('Anúncio salvo! Os times da sua região já podem encontrá-lo.');
      },
    ),
    'conversations' => ConversationsScreen(
      onOpen: (g) => setState(() {
        selected = g;
        page = 'chat';
      }),
    ),
    'chat' => ChatScreen(
      game: selected,
      teamName: teamName,
      confirmed: confirmed,
      onConfirm: () => confirmed ? go('confirmed') : _confirm('confirm'),
    ),
    'confirmed' => ConfirmationScreen(
      game: selected,
      teamName: teamName,
      onChat: () => go('chat'),
      onCancel: () => _confirm('cancel'),
    ),
    'games' => GamesScreen(
      tab: gameTab,
      onTab: (v) => setState(() => gameTab = v),
      teamName: teamName,
      onOpen: _openGameStatus,
    ),
    'ads' => AdsScreen(
      ads: ads,
      onCreate: () => setState(() {
        editingAd = null;
        page = 'create';
      }),
      onEdit: (i) => setState(() {
        editingAd = i;
        page = 'create';
      }),
      onToggle: (i) => setState(() {
        ads[i] = ads[i].contains('|Pausado')
            ? ads[i].replaceAll('|Pausado', '|Ativo')
            : ads[i].replaceAll('|Ativo', '|Pausado');
      }),
      onDelete: (i) => _deleteAd(i),
      onConversations: () => go('conversations'),
    ),
    'profile' => ProfileScreen(
      teamName: teamName,
      onEdit: _editProfile,
      onGames: () => go('games'),
      onLogout: () => go('login'),
    ),
    'notifications' => NotificationsScreen(onOpen: go),
    'map' => MapScreen(games: MockRepository.games, onSelect: openGame),
    'review' => ReviewScreen(
      game: selected,
      onSubmit: () {
        _success('reviewed');
      },
    ),
    'login' || 'register' || 'forgot' => AuthScreen(
      page: page,
      onPage: go,
      onDone: () {
        if (page == 'forgot') {
          notify(
            'Link de recuperação solicitado. Este é um protótipo demonstrativo.',
          );
          go('login');
        } else {
          go('home');
          notify('Bem-vindo ao Joga Contra!');
        }
      },
    ),
    _ => HomeScreen(
      games: MockRepository.games,
      teamName: teamName,
      onNavigate: go,
      onSelectGame: openGame,
    ),
  };

  void _openGameStatus(String status) {
    final index = switch (status) {
      'Aguardando' => 3,
      'Negociando' => 1,
      'Confirmado' => 0,
      _ => 0,
    };
    selected = MockRepository.games[index];
    setState(
      () => page = switch (status) {
        'Aguardando' => 'ads',
        'Negociando' => 'chat',
        'Confirmado' => 'confirmed',
        _ => 'review',
      },
    );
  }

  Future<void> _confirm(String kind) async {
    final (title, body, positive) = switch (kind) {
      'interest' => (
        'Bora marcar esse jogo?',
        'Você quer demonstrar interesse neste jogo? Vamos abrir uma conversa com o responsável pelo time.',
        'Sim, tenho interesse',
      ),
      'confirm' => (
        'Tudo combinado?',
        'Confirme a partida de $teamName contra ${selected.name}, ${selected.date} às ${selected.time}.',
        'Confirmar partida',
      ),
      'cancel' => (
        'Cancelar a partida?',
        'O outro time será avisado. Tenha certeza antes de cancelar.',
        'Cancelar partida',
      ),
      _ => (
        'Excluir este anúncio?',
        'Esta ação não pode ser desfeita. Os interessados não poderão mais encontrar este jogo.',
        'Sim, excluir',
      ),
    };
    final ok = await showDialog<bool>(
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
    );
    if (ok != true || !mounted) return;
    switch (kind) {
      case 'interest':
        go('chat');
        notify('Interesse enviado! Combine os detalhes na conversa.');
      case 'confirm':
        setState(() {
          confirmed = true;
          page = 'confirmed';
        });
      case 'cancel':
        setState(() {
          confirmed = false;
          page = 'games';
        });
        notify(
          'Partida cancelada. O time adversário será informado na versão conectada.',
        );
    }
  }

  Future<void> _success(String type) async {
    final (title, body, next) = type == 'reviewed'
        ? (
            'Valeu pelo feedback!',
            'Sua avaliação ajuda todo mundo a encontrar bons adversários.',
            'games',
          )
        : (
            'Seu anúncio está no jogo!',
            'Agora os times da sua região podem encontrar seu anúncio e demonstrar interesse.',
            'ads',
          );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
    if (mounted) go(next);
  }

  Future<void> _editProfile() async {
    final controller = TextEditingController(text: teamName);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seu time, do seu jeito.'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nome do time'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Salvar perfil'),
          ),
        ],
      ),
    );
    if (value != null && value.trim().isNotEmpty) {
      setState(() => teamName = value.trim());
      notify('Perfil atualizado com sucesso!');
    }
  }

  Future<void> _deleteAd(int index) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir este anúncio?'),
        content: const Text('Esta ação não pode ser desfeita.'),
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
    if (yes == true) {
      setState(() => ads.removeAt(index));
      notify('Anúncio excluído.');
    }
  }
}
