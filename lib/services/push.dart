import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/notificacao.dart';

/// Notificação push recebida. Traz só identificadores: o app busca os
/// detalhes na API, com a sessão do capitão.
class MensagemPush {
  const MensagemPush({
    required this.idNotificacao,
    required this.tipo,
    this.referenciaTipo = '',
    this.referenciaId = '',
    this.titulo = '',
    this.corpo = '',
  });

  final String idNotificacao, tipo, referenciaTipo, referenciaId;
  final String titulo, corpo;

  factory MensagemPush.dosDados(
    Map<String, dynamic> dados, {
    String? titulo,
    String? corpo,
  }) => MensagemPush(
    idNotificacao: '${dados['idNotificacao'] ?? ''}',
    tipo: '${dados['tipo'] ?? ''}',
    referenciaTipo: '${dados['referenciaTipo'] ?? ''}',
    referenciaId: '${dados['referenciaId'] ?? ''}',
    titulo: titulo ?? '',
    corpo: corpo ?? '',
  );

  bool get valida => idNotificacao.isNotEmpty;

  /// Mesma navegação da central de notificações.
  Notificacao comoNotificacao() => Notificacao(
    id: idNotificacao,
    tipo: TipoNotificacao.deCodigo(tipo),
    titulo: titulo,
    mensagem: corpo,
    dataCriacao: DateTime.now(),
    idSolicitacao: referenciaTipo == 'solicitacao' ? referenciaId : null,
    idPartida: referenciaTipo == 'partida' ? referenciaId : null,
    idAnuncio: referenciaTipo == 'anuncio' ? referenciaId : null,
  );
}

/// O que o app usa do push. A implementação real é [PushFirebase]; os testes
/// usam uma simulada.
abstract interface class ServicoPush {
  /// 'android' ou 'ios'.
  String get plataforma;

  /// Pede a permissão (Android 13+ e iOS mostram o aviso do sistema uma vez).
  /// Devolve se as notificações estão autorizadas.
  Future<bool> pedirPermissao();

  /// Situação atual, sem perguntar de novo.
  Future<bool> permitido();
  Future<String?> token();
  Stream<String> get tokenRenovado;

  /// Chegou com o app aberto (o sistema não mostra nada nesse caso).
  Stream<MensagemPush> get emPrimeiroPlano;

  /// Tocada na barra de notificações com o app em segundo plano.
  Stream<MensagemPush> get tocadas;

  /// Tocada com o app fechado: a que abriu o app (uma vez).
  Future<MensagemPush?> mensagemInicial();
}

/// Firebase Cloud Messaging. Em segundo plano e com o app fechado, o próprio
/// Android mostra a notificação (canal "Avisos do Joga Contra").
class PushFirebase implements ServicoPush {
  PushFirebase._(this._fcm);
  final FirebaseMessaging _fcm;

  /// Usa a configuração nativa do app Android (values/firebase.xml, gerado por
  /// tool/firebase_config.dart). Null quando este build não tem essa
  /// configuração (ou o Firebase falhou): o app segue normalmente, sem push.
  static Future<PushFirebase?> iniciar() async {
    if (kIsWeb) return null;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      return PushFirebase._(FirebaseMessaging.instance);
    } catch (e) {
      debugPrint('Push desligado: Firebase não configurado neste build.');
      return null;
    }
  }

  MensagemPush _converter(RemoteMessage m) => MensagemPush.dosDados(
    m.data,
    titulo: m.notification?.title,
    corpo: m.notification?.body,
  );

  bool _autorizado(NotificationSettings s) =>
      s.authorizationStatus == AuthorizationStatus.authorized ||
      s.authorizationStatus == AuthorizationStatus.provisional;

  @override
  String get plataforma => Platform.isIOS ? 'ios' : 'android';

  @override
  Future<bool> pedirPermissao() async =>
      _autorizado(await _fcm.requestPermission());

  @override
  Future<bool> permitido() async =>
      _autorizado(await _fcm.getNotificationSettings());

  /// Registra este aparelho no FCM e espera o token (`onRegistered`).
  @override
  Future<String?> token() async {
    try {
      final registrado = _fcm.onRegistered.first.timeout(
        const Duration(seconds: 30),
      );
      await _fcm.register();
      return await registrado;
    } catch (e) {
      // Sem Google Play Services ou sem rede: tenta de novo na próxima abertura.
      debugPrint('Push: token indisponível.');
      return null;
    }
  }

  /// Também dispara quando o FCM troca o token deste aparelho.
  @override
  Stream<String> get tokenRenovado => _fcm.onRegistered;

  @override
  Stream<MensagemPush> get emPrimeiroPlano =>
      FirebaseMessaging.onMessage.map(_converter);

  @override
  Stream<MensagemPush> get tocadas =>
      FirebaseMessaging.onMessageOpenedApp.map(_converter);

  @override
  Future<MensagemPush?> mensagemInicial() async {
    final m = await _fcm.getInitialMessage();
    return m == null ? null : _converter(m);
  }
}
