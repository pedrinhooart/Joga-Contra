import 'dart:async';

import 'package:flutter/widgets.dart';
import '../config/api_config.dart';
import '../models/referencia.dart';
import '../models/time.dart';
import '../models/usuario.dart';
import '../repositories/api/api_repositories.dart';
import '../repositories/contratos.dart';
import '../repositories/demo/demo_repositories.dart';
import '../services/api_client.dart';
import '../services/links_recebidos.dart';
import '../services/push.dart';

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
    atualizarNotificacoes();
  }

  Future<void> entrar(String email, String senha) async {
    _sessao = await repositorios.auth.entrar(email: email, senha: senha);
    _zerarNotificacoes();
    notifyListeners();
    atualizarNotificacoes();
  }

  Future<void> cadastrar(CadastroCapitao dados) async {
    _sessao = await repositorios.auth.cadastrar(dados);
    _zerarNotificacoes();
    notifyListeners();
    atualizarNotificacoes();
  }

  Future<void> sair() async {
    // Ex.: desligar o push deste aparelho, que precisa da sessão ainda ativa.
    try {
      await antesDeSair?.call();
    } catch (_) {}
    await repositorios.auth.sair();
    _sessao = null;
    _zerarNotificacoes();
    notifyListeners();
  }

  /// Executado no início de [sair], com a sessão ainda válida.
  Future<void> Function()? antesDeSair;

  // --- Push ----------------------------------------------------------------

  final _avisosPush = StreamController<MensagemPush>.broadcast();

  /// Push que chegou com o app aberto: a tela mostra um aviso discreto.
  Stream<MensagemPush> get avisosPush => _avisosPush.stream;

  void receberPushEmPrimeiroPlano(MensagemPush m) {
    if (!m.valida) return;
    _avisosPush.add(m);
    atualizarNotificacoes();
  }

  /// Push tocado na barra de notificações. Fica guardado até haver sessão (o
  /// app pode estar abrindo); quem mostra as telas consome com [consumirPush].
  MensagemPush? pushParaAbrir;

  void abrirPush(MensagemPush m) {
    if (!m.valida) return;
    pushParaAbrir = m;
    notifyListeners();
  }

  MensagemPush? consumirPush() {
    final m = pushParaAbrir;
    pushParaAbrir = null;
    return m;
  }

  /// Notificações não lidas do capitão logado (contador do sino).
  int notificacoesNaoLidas = 0;

  /// Total de notificações da conta: muda quando chega uma nova.
  int notificacoesTotal = 0;

  void _zerarNotificacoes() {
    notificacoesNaoLidas = 0;
    notificacoesTotal = 0;
  }

  /// Consulta o contador na API. Devolve true se chegou notificação nova.
  /// Sem conexão, mantém o último valor (tenta de novo na próxima vez).
  Future<bool> atualizarNotificacoes() async {
    if (!autenticado) return false;
    try {
      final r = await repositorios.notificacoes.resumo();
      final chegouNova = r.total > notificacoesTotal;
      if (r.naoLidas != notificacoesNaoLidas || r.total != notificacoesTotal) {
        notificacoesNaoLidas = r.naoLidas;
        notificacoesTotal = r.total;
        notifyListeners();
      }
      return chegouNova;
    } catch (_) {
      return false;
    }
  }

  /// A central já sabe o novo valor (ex.: depois de marcar como lida).
  void definirNotificacoesNaoLidas(int naoLidas, {int? total}) {
    if (naoLidas == notificacoesNaoLidas &&
        (total == null || total == notificacoesTotal)) {
      return;
    }
    notificacoesNaoLidas = naoLidas;
    if (total != null) notificacoesTotal = total;
    notifyListeners();
  }

  /// Token do link de redefinição de senha aberto no app. Vazio: o link veio
  /// sem um token válido. Null: nenhum link aberto. Enquanto não for null, o
  /// app mostra a tela de nova senha, com ou sem sessão.
  String? tokenRedefinicao;

  /// Link recebido pelo app (e-mail de recuperação). Outros links são ignorados.
  void abrirLink(Uri uri) {
    if (!LinksRecebidos.eRedefinicao(uri)) return;
    tokenRedefinicao = LinksRecebidos.tokenDeRedefinicao(uri) ?? '';
    notifyListeners();
  }

  void fecharRedefinicao() {
    tokenRedefinicao = null;
    notifyListeners();
  }

  /// Troca a senha pelo link aberto. A API derruba todas as sessões da conta,
  /// então este aparelho também sai e a pessoa entra com a senha nova.
  Future<void> redefinirSenha(String novaSenha, String confirmacaoSenha) async {
    await repositorios.auth.redefinirSenha(
      token: tokenRedefinicao ?? '',
      novaSenha: novaSenha,
      confirmacaoSenha: confirmacaoSenha,
    );
    if (_sessao != null) await sair();
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
    _zerarNotificacoes();
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
