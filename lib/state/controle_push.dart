import 'dart:async';

import 'package:flutter/widgets.dart';

import '../repositories/contratos.dart';
import '../services/armazenamento_sessao.dart';
import '../services/push.dart';
import 'app_state.dart';

/// Liga o push à sessão do capitão:
/// - ao entrar (ou abrir o app já logado), pede a permissão e registra o
///   aparelho na API; com a permissão negada, registra como "sem permissão"
///   (a API não envia nada) e o app segue normal, com a central de sempre;
/// - quando o Firebase renova o token, troca o antigo pelo novo;
/// - ao voltar para o app, confere se a permissão mudou nas configurações;
/// - ao sair da conta, desliga o aparelho antes de apagar a sessão;
/// - mensagens com o app aberto viram um aviso discreto na tela, e as tocadas
///   na barra de notificações (app em segundo plano ou fechado) abrem o
///   conteúdo depois que a sessão estiver pronta.
class ControlePush with WidgetsBindingObserver {
  ControlePush({
    required this.estado,
    required this.servico,
    required this.dispositivos,
    required this.armazenamento,
  });

  final AppState estado;
  final ServicoPush servico;
  final DispositivoRepository dispositivos;
  final ArmazenamentoSessao armazenamento;

  final _assinaturas = <StreamSubscription<Object?>>[];
  bool _autenticado = false;
  bool? _permitido;
  Future<void>? _registrando;

  Future<void> iniciar() async {
    _assinaturas
      ..add(servico.emPrimeiroPlano.listen(estado.receberPushEmPrimeiroPlano))
      ..add(servico.tocadas.listen(estado.abrirPush))
      ..add(servico.tokenRenovado.listen((token) => _registrar(token: token)));
    estado.antesDeSair = _desligarAparelho;
    estado.addListener(_aoMudarEstado);
    WidgetsBinding.instance.addObserver(this);
    // Tocada com o app fechado: guardada até a sessão estar pronta.
    final inicial = await servico.mensagemInicial();
    if (inicial != null) estado.abrirPush(inicial);
    _aoMudarEstado();
  }

  void encerrar() {
    for (final a in _assinaturas) {
      a.cancel();
    }
    estado.removeListener(_aoMudarEstado);
    if (identical(estado.antesDeSair, _desligarAparelho)) {
      estado.antesDeSair = null;
    }
    WidgetsBinding.instance.removeObserver(this);
  }

  void _aoMudarEstado() {
    final agora = estado.autenticado && !estado.inicializando;
    if (agora && !_autenticado) _registrar();
    _autenticado = agora;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_autenticado) return;
    // A pessoa pode ter mudado a permissão nas configurações do Android.
    servico.permitido().then((p) {
      if (p != _permitido) _registrar(perguntar: false);
    }, onError: (_) {});
  }

  /// Um registro por vez (login e renovação podem chegar juntos).
  Future<void> _registrar({String? token, bool perguntar = true}) {
    final anterior = _registrando ?? Future<void>.value();
    return _registrando = anterior.then(
      (_) => _registrarAgora(token: token, perguntar: perguntar),
    );
  }

  Future<void> _registrarAgora({String? token, required bool perguntar}) async {
    if (!estado.autenticado) return;
    try {
      final permitido = perguntar
          ? await servico.pedirPermissao()
          : await servico.permitido();
      _permitido = permitido;
      final atual = token ?? await servico.token();
      if (atual == null || !estado.autenticado) return;
      final anterior = await armazenamento.lerTokenPush();
      await dispositivos.registrar(
        token: atual,
        plataforma: servico.plataforma,
        permitido: permitido,
        tokenAnterior: anterior,
      );
      await armazenamento.salvarTokenPush(atual);
    } catch (e) {
      // Sem conexão: tenta de novo na próxima abertura ou login. A central
      // interna funciona independentemente do push.
      debugPrint('Push: aparelho não registrado agora.');
    }
  }

  Future<void> _desligarAparelho() async {
    try {
      final token = await armazenamento.lerTokenPush();
      if (token != null) await dispositivos.desativar(token);
    } catch (_) {
      // Sair continua mesmo sem conexão; a API desativa tokens inválidos depois.
    }
  }
}
