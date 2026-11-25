import { readFileSync } from 'node:fs';
import { env } from '../config/env.js';
import { pool } from '../config/db.js';
import { consultar, emTransacao, type Linha } from './helpers.js';

/**
 * Notificações push (Firebase Cloud Messaging).
 *
 * Padrão outbox: o gatilho gat_notificacoes_depois_inserir põe cada notificação
 * nova e não lida em `envios_push`, na mesma transação do evento. Esta fila é
 * processada aqui, fora da transação: uma falha do Firebase nunca desfaz o
 * evento nem a notificação interna, e o envio é repetido com espera crescente.
 *
 * Conteúdo enviado: título, texto e só identificadores (notificação, tipo e o
 * conteúdo ligado). O app consulta a API com a sessão para abrir os detalhes.
 */
export type MensagemPush = {
  titulo: string;
  corpo: string;
  dados: {
    idNotificacao: string;
    tipo: string;
    referenciaTipo: 'solicitacao' | 'partida' | 'anuncio' | '';
    referenciaId: string;
  };
};

/** Resultado por token. `tokenInvalido`: o aparelho não existe mais para o FCM. */
export type ResultadoToken = { token: string; ok: boolean; tokenInvalido?: boolean; erro?: string };

/** Contrato do provedor (Firebase hoje; outro amanhã, sem mudar a fila). */
export interface EnviadorPush {
  readonly nome: string;
  enviar(tokens: string[], mensagem: MensagemPush): Promise<ResultadoToken[]>;
}

/** Códigos do FCM que significam token morto ou de outro projeto: desativa o aparelho. */
const ERROS_TOKEN_INVALIDO = new Set([
  'messaging/installation-id-not-registered',
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/mismatched-credential',
  'messaging/invalid-recipient',
]);

/** Canal Android criado pelo app (MainActivity.kt) e ícone pequeno monocromático. */
export const CANAL_ANDROID = 'joga_contra_avisos';

/** Máximo de alvos por chamada do sendEachForMulticast. */
const LOTE_FCM = 500;

/** Firebase Admin SDK, com a conta de serviço lida só do servidor. */
export class EnviadorFirebase implements EnviadorPush {
  readonly nome = 'firebase';
  private mensageiro?: import('firebase-admin/messaging').Messaging;

  constructor(private readonly arquivoCredenciais: string) {}

  private async obterMensageiro() {
    if (!this.mensageiro) {
      const { initializeApp, cert, getApps } = await import('firebase-admin/app');
      const { getMessaging } = await import('firebase-admin/messaging');
      const conta = JSON.parse(readFileSync(this.arquivoCredenciais, 'utf8'));
      const app = getApps().find((a) => a.name === 'joga-contra') ?? initializeApp({ credential: cert(conta) }, 'joga-contra');
      this.mensageiro = getMessaging(app);
    }
    return this.mensageiro;
  }

  /** O Admin SDK aceita até 500 alvos por chamada: listas maiores vão em lotes. */
  async enviar(tokens: string[], m: MensagemPush): Promise<ResultadoToken[]> {
    const resultados: ResultadoToken[] = [];
    for (let i = 0; i < tokens.length; i += LOTE_FCM) {
      resultados.push(...(await this.enviarLote(tokens.slice(i, i + LOTE_FCM), m)));
    }
    return resultados;
  }

  private async enviarLote(tokens: string[], m: MensagemPush): Promise<ResultadoToken[]> {
    const mensageiro = await this.obterMensageiro();
    // O app registra o aparelho com register()/onRegistered, que entrega o
    // FID (Firebase Installation ID): o alvo atual do FCM (campo fids).
    const resposta = await mensageiro.sendEachForMulticast({
      fids: tokens,
      notification: { title: m.titulo, body: m.corpo },
      data: m.dados,
      android: {
        priority: 'high',
        // Reenvio substitui a anterior no aparelho; mensagens da mesma conversa
        // também (uma por conversa na barra, não uma por mensagem).
        notification: { channelId: CANAL_ANDROID, icon: 'ic_notificacao', color: '#123D2B', tag: etiquetaAndroid(m) },
      },
      apns: { payload: { aps: { sound: 'default', threadId: m.dados.tipo } } },
    });
    return resposta.responses.map((r, i) => ({
      token: tokens[i],
      ok: r.success,
      tokenInvalido: !r.success && ERROS_TOKEN_INVALIDO.has(r.error?.code ?? ''),
      erro: r.success ? undefined : (r.error?.code ?? 'erro desconhecido'),
    }));
  }
}

/** Etiqueta da notificação no Android: a mesma etiqueta substitui a anterior. */
export const etiquetaAndroid = (m: MensagemPush) =>
  m.dados.tipo === 'mensagem_recebida' && m.dados.referenciaId ? `chat-${m.dados.referenciaId}` : m.dados.idNotificacao;

let enviadorAtual: EnviadorPush | null | undefined;

/** Provedor configurado no ambiente, ou null (push desligado). */
export function enviadorPush(): EnviadorPush | null {
  if (enviadorAtual === undefined) {
    enviadorAtual = env.FIREBASE_CREDENCIAIS ? new EnviadorFirebase(env.FIREBASE_CREDENCIAIS) : null;
  }
  return enviadorAtual;
}

/** Troca o provedor (testes). `undefined` volta ao do ambiente. */
export function definirEnviadorPush(enviador: EnviadorPush | null | undefined) {
  enviadorAtual = enviador;
}

/** Tentativas e espera entre elas (segundos). Depois disso, o envio fica como falhou. */
const ESPERAS_S = [10, 30, 120, 600, 1800];
export const MAXIMO_TENTATIVAS = ESPERAS_S.length;
/** Reserva de um lote: se o servidor cair no meio, o envio volta para a fila depois disso. */
const RESERVA_S = 120;
/** Notificação mais antiga que isso não vira push (chegaria fora de hora). */
const VALIDADE_HORAS = 24;

const referencia = (n: Linha): Pick<MensagemPush['dados'], 'referenciaTipo' | 'referenciaId'> =>
  n.id_solicitacao
    ? { referenciaTipo: 'solicitacao', referenciaId: n.id_solicitacao }
    : n.id_partida
      ? { referenciaTipo: 'partida', referenciaId: n.id_partida }
      : n.id_anuncio
        ? { referenciaTipo: 'anuncio', referenciaId: n.id_anuncio }
        : { referenciaTipo: '', referenciaId: '' };

export const mensagemDaNotificacao = (n: Linha): MensagemPush => ({
  titulo: n.titulo,
  corpo: n.mensagem,
  dados: { idNotificacao: n.id_notificacao, tipo: n.tipo, ...referencia(n) },
});

type Conclusao = { status: 'enviado' | 'ignorado' | 'falhou' | 'pendente'; erro?: string; enviados?: number; tentativas: number };

async function concluir(idEnvio: string, c: Conclusao) {
  const espera = ESPERAS_S[Math.min(c.tentativas, ESPERAS_S.length) - 1] ?? ESPERAS_S.at(-1)!;
  await pool.execute(
    `UPDATE envios_push
        SET status = ?, ultimo_erro = ?, dispositivos_enviados = ?,
            proxima_tentativa = IF(? = 'pendente', UTC_TIMESTAMP(3) + INTERVAL ? SECOND, proxima_tentativa),
            data_conclusao = IF(? IN ('enviado', 'ignorado', 'falhou'), UTC_TIMESTAMP(3), NULL)
      WHERE id_envio = ?`,
    [c.status, c.erro?.slice(0, 200) ?? null, c.enviados ?? 0, c.status, espera, c.status, idEnvio],
  );
}

async function processarEnvio(envio: Linha, enviador: EnviadorPush | null): Promise<Conclusao['status']> {
  const tentativas = Number(envio.tentativas);
  const [n] = await consultar(pool, 'SELECT * FROM notificacoes WHERE id_notificacao = ?', [envio.id_notificacao]);
  const ignorar = async (erro: string) => {
    await concluir(envio.id_envio, { status: 'ignorado', erro, tentativas });
    return 'ignorado' as const;
  };
  if (!n) return ignorar('notificacao_inexistente');
  if (n.data_leitura) return ignorar('ja_lida');
  if (Date.now() - new Date(n.data_criacao).getTime() > VALIDADE_HORAS * 3_600_000) return ignorar('expirada');
  if (!enviador) return ignorar('push_desligado');

  // Só aparelhos ativos e com permissão do capitão destinatário.
  const aparelhos = await consultar(
    pool,
    `SELECT id_dispositivo, token_fcm FROM dispositivos_push
      WHERE id_usuario = ? AND ativo = 1 AND permissao_notificacoes = 1 AND token_fcm IS NOT NULL`,
    [n.id_usuario_destinatario],
  );
  if (aparelhos.length === 0) return ignorar('sem_dispositivo');

  let resultados: ResultadoToken[];
  try {
    resultados = await enviador.enviar(aparelhos.map((a) => a.token_fcm), mensagemDaNotificacao(n));
  } catch (erro: any) {
    // Falha geral (rede, credencial, Firebase fora do ar): tenta de novo depois.
    return reagendar(envio.id_envio, tentativas, `${erro?.code ?? erro?.name ?? 'erro'}`);
  }

  const porToken = new Map(aparelhos.map((a) => [a.token_fcm as string, a.id_dispositivo as string]));
  const invalidos = resultados.filter((r) => r.tokenInvalido).map((r) => porToken.get(r.token)!);
  if (invalidos.length) {
    await pool.execute(
      `UPDATE dispositivos_push SET ativo = 0, motivo_desativacao = 'token_invalido'
        WHERE id_dispositivo IN (${invalidos.map(() => '?').join(', ')}) AND ativo = 1`,
      invalidos,
    );
  }
  const enviados = resultados.filter((r) => r.ok);
  if (enviados.length) {
    await pool.execute(
      `UPDATE dispositivos_push SET data_ultimo_envio = UTC_TIMESTAMP(3)
        WHERE id_dispositivo IN (${enviados.map(() => '?').join(', ')})`,
      enviados.map((r) => porToken.get(r.token)!),
    );
    await concluir(envio.id_envio, { status: 'enviado', enviados: enviados.length, tentativas });
    return 'enviado';
  }
  const transitorios = resultados.filter((r) => !r.ok && !r.tokenInvalido);
  if (transitorios.length === 0) return ignorar('tokens_invalidos');
  return reagendar(envio.id_envio, tentativas, transitorios[0].erro ?? 'erro');
}

async function reagendar(idEnvio: string, tentativas: number, erro: string): Promise<Conclusao['status']> {
  const status = tentativas >= MAXIMO_TENTATIVAS ? 'falhou' : 'pendente';
  await concluir(idEnvio, { status, erro, tentativas });
  return status;
}

/**
 * Processa um lote da fila. Vários servidores podem rodar ao mesmo tempo: cada
 * envio é reservado com FOR UPDATE SKIP LOCKED, então nenhum é enviado duas vezes.
 */
export async function processarFilaPush(opcoes: { limite?: number; apenasUsuarios?: string[] } = {}) {
  const limite = Math.trunc(opcoes.limite ?? 50);
  // Testes: só os envios das contas criadas pelo teste.
  const filtro = opcoes.apenasUsuarios?.length
    ? `AND id_notificacao IN (SELECT id_notificacao FROM notificacoes
                               WHERE id_usuario_destinatario IN (${opcoes.apenasUsuarios.map(() => '?').join(', ')}))`
    : '';
  const reservados = await emTransacao(async (db) => {
    const linhas = await consultar(
      db,
      `SELECT id_envio, id_notificacao, tentativas FROM envios_push
        WHERE status IN ('pendente', 'enviando') AND proxima_tentativa <= UTC_TIMESTAMP(3) ${filtro}
        ORDER BY proxima_tentativa
        LIMIT ${limite}
        FOR UPDATE SKIP LOCKED`,
      opcoes.apenasUsuarios ?? [],
    );
    if (linhas.length) {
      await db.execute(
        `UPDATE envios_push
            SET status = 'enviando', tentativas = tentativas + 1,
                proxima_tentativa = UTC_TIMESTAMP(3) + INTERVAL ${RESERVA_S} SECOND
          WHERE id_envio IN (${linhas.map(() => '?').join(', ')})`,
        linhas.map((l) => l.id_envio),
      );
    }
    return linhas.map((l): Linha => ({ ...l, tentativas: Number(l.tentativas) + 1 }));
  });
  const enviador = enviadorPush();
  const contagem: Record<string, number> = {};
  for (const envio of reservados) {
    let status: string;
    try {
      status = await processarEnvio(envio, enviador);
    } catch (erro: any) {
      status = await reagendar(envio.id_envio, envio.tentativas, `${erro?.code ?? 'erro_interno'}`);
    }
    contagem[status] = (contagem[status] ?? 0) + 1;
  }
  return contagem;
}

/**
 * Envios pendentes há mais que a validade viram 'ignorado' (expirada), sem
 * apagar nada. Mantém a fila curta mesmo com o push desligado por muito tempo.
 */
export async function expirarEnviosAntigos() {
  const [r] = await pool.execute<import('mysql2/promise').ResultSetHeader>(
    `UPDATE envios_push
        SET status = 'ignorado', ultimo_erro = 'expirada', data_conclusao = UTC_TIMESTAMP(3)
      WHERE status = 'pendente' AND data_criacao < UTC_TIMESTAMP(3) - INTERVAL ${VALIDADE_HORAS} HOUR`,
  );
  return r.affectedRows;
}

/**
 * Processa a fila em intervalos (um lote por vez). Com o push desligado a fila
 * não é enviada: os envios esperam até a validade (24 h) e depois expiram.
 */
export function agendarFilaPush() {
  let ocupado = false;
  let ultimaExpiracao = 0;
  return setInterval(async () => {
    if (ocupado) return;
    ocupado = true;
    try {
      if (Date.now() - ultimaExpiracao > 10 * 60_000) {
        ultimaExpiracao = Date.now();
        await expirarEnviosAntigos();
      }
      if (!enviadorPush()) return;
      const r = await processarFilaPush();
      const falhas = (r.pendente ?? 0) + (r.falhou ?? 0);
      if (r.enviado || falhas) {
        console.log(`Push: ${r.enviado ?? 0} enviado(s), ${r.pendente ?? 0} reagendado(s), ${r.falhou ?? 0} com falha.`);
      }
    } catch (erro: any) {
      console.error(`Push: fila não processada (${erro?.code ?? 'erro'}).`);
    } finally {
      ocupado = false;
    }
  }, env.PUSH_INTERVALO_MS);
}
