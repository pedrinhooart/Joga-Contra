import 'package:flutter/widgets.dart';
import '../config/api_config.dart';
import '../models/referencia.dart';
import '../models/time.dart';
import '../models/usuario.dart';
import '../repositories/api/api_repositories.dart';
import '../repositories/contratos.dart';
import '../repositories/demo/demo_repositories.dart';
import '../services/api_client.dart';

/// Estado global mínimo: sessão (capitão + time) e cadastros de referência.
/// Dados de tela (anúncios, partidas...) são buscados sob demanda nos repositórios.
class AppState extends ChangeNotifier {
  AppState(this.repositorios);

  /// Escolhe API real ou demonstração conforme `ApiConfig.useDemoData`.
  factory AppState.padrao() {
    if (ApiConfig.useDemoData) return AppState(criarRepositoriosDemo());
    final api = ApiClient();
    final state = AppState(criarRepositoriosApi(api));
    api.onUnauthorized = state._sessaoExpirada;
    return state;
  }

  final Repositorios repositorios;

  Sessao? _sessao;
  Referencias referencias = const Referencias();
  bool inicializando = true;
  String? erroInicial;

  bool get autenticado => _sessao != null;
  Usuario? get usuario => _sessao?.usuario;
  Time? get time => _sessao?.time;

  Future<void> inicializar() async {
    inicializando = true;
    erroInicial = null;
    notifyListeners();
    try {
      final resultados = await Future.wait([
        repositorios.referencias.carregar(),
        repositorios.auth.sessaoAtual(),
      ]);
      referencias = resultados[0] as Referencias;
      _sessao = resultados[1] as Sessao?;
    } catch (e) {
      erroInicial = e.toString();
    } finally {
      inicializando = false;
      notifyListeners();
    }
  }

  Future<void> entrar(String email, String senha) async {
    _sessao = await repositorios.auth.entrar(email: email, senha: senha);
    notifyListeners();
  }

  Future<void> cadastrar(CadastroCapitao dados) async {
    _sessao = await repositorios.auth.cadastrar(dados);
    notifyListeners();
  }

  Future<void> sair() async {
    await repositorios.auth.sair();
    _sessao = null;
    notifyListeners();
  }

  Future<void> atualizarTime(AtualizacaoTime dados) async {
    final atual = _sessao;
    if (atual == null) return;
    final time = await repositorios.times.atualizar(atual.time.id, dados);
    _sessao = Sessao(usuario: atual.usuario, time: time, token: atual.token);
    notifyListeners();
  }

  /// Envia a nova foto do time. Se falhar, a sessão segue com a foto atual.
  Future<void> enviarEscudo(ImagemSelecionada imagem) async {
    final atual = _sessao;
    if (atual == null) return;
    final time = await repositorios.times.enviarEscudo(atual.time.id, imagem);
    _sessao = Sessao(usuario: atual.usuario, time: time, token: atual.token);
    notifyListeners();
  }

  /// Recarrega o perfil do time (estatísticas mudam após partidas/avaliações).
  Future<void> recarregarTime() async {
    final atual = _sessao;
    if (atual == null) return;
    final time = await repositorios.times.buscar(atual.time.id);
    _sessao = Sessao(usuario: atual.usuario, time: time, token: atual.token);
    notifyListeners();
  }

  void _sessaoExpirada() {
    if (_sessao == null) return;
    _sessao = null;
    repositorios.auth.sair();
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static Repositorios repos(BuildContext context) => of(context).repositorios;
}
