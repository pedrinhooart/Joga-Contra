import type { Executor } from './helpers.js';
import { consultar, uuid } from './helpers.js';

/**
 * Criação de notificações pela API (as dos procedimentos do banco são criadas
 * dentro das próprias transações deles).
 *
 * Idempotência: com `chaveEvento`, o mesmo evento gera no máximo uma
 * notificação por destinatário. A garantia é do banco (UNIQUE em
 * destinatário + chave), então vale também para tentativas repetidas e
 * simultâneas da API, não só para verificações feitas no app.
 */
export type TipoNotificacao =
  | 'solicitacao_recebida'
  | 'mensagem_recebida'
  | 'partida_confirmada'
  | 'partida_cancelada'
  | 'solicitacao_encerrada'
  | 'solicitacao_recusada'
  | 'anuncio_expirando'
  | 'avaliacao_pendente'
  | 'aviso'
  | 'solicitacao_enviada'
  | 'lembrete_partida';

export type NovaNotificacao = {
  idDestinatario: string;
  tipo: TipoNotificacao;
  titulo: string;
  mensagem: string;
  /** Conteúdo para onde a notificação leva (no máximo um). */
  idAnuncio?: string | null;
  idSolicitacao?: string | null;
  idPartida?: string | null;
  /** Identifica o evento de origem, ex.: `mensagem_recebida:<idMensagem>`. */
  chaveEvento?: string | null;
  /** Já lida: registro no histórico de uma ação da própria pessoa, sem contar como novidade. */
  lida?: boolean;
};

export type ResultadoNotificacao = { idNotificacao: string; criada: boolean };

const LIMITE_TITULO = 160;
const LIMITE_MENSAGEM = 500;
const FORMATO_CHAVE = /^[\x21-\x7e]{1,150}$/; // ASCII visível, como a coluna

/**
 * Grava a notificação. Se já existir uma do mesmo evento para o mesmo
 * destinatário, não grava de novo e devolve a existente (`criada: false`).
 * Pode ser chamada dentro de uma transação: o conflito de chave desfaz só
 * este comando, não a transação.
 */
export async function criarNotificacao(db: Executor, n: NovaNotificacao): Promise<ResultadoNotificacao> {
  const chave = n.chaveEvento ?? null;
  if (chave !== null && !FORMATO_CHAVE.test(chave)) throw new Error('Chave de evento inválida.');
  const idNotificacao = uuid();
  try {
    await db.execute(
      `INSERT INTO notificacoes (id_notificacao, id_usuario_destinatario, tipo, titulo, mensagem,
                                 id_anuncio, id_solicitacao, id_partida, chave_evento, data_criacao, data_leitura)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, UTC_TIMESTAMP(3), IF(?, UTC_TIMESTAMP(3), NULL))`,
      [
        idNotificacao,
        n.idDestinatario,
        n.tipo,
        n.titulo.slice(0, LIMITE_TITULO),
        n.mensagem.slice(0, LIMITE_MENSAGEM),
        n.idAnuncio ?? null,
        n.idSolicitacao ?? null,
        n.idPartida ?? null,
        chave,
        n.lida ? 1 : 0,
      ],
    );
    return { idNotificacao, criada: true };
  } catch (erro: any) {
    if (chave === null || erro?.code !== 'ER_DUP_ENTRY' || !erro.sqlMessage?.includes('un_notificacoes_evento')) {
      throw erro;
    }
    const [existente] = await consultar(
      db,
      'SELECT id_notificacao FROM notificacoes WHERE id_usuario_destinatario = ? AND chave_evento = ?',
      [n.idDestinatario, chave],
    );
    return { idNotificacao: existente.id_notificacao, criada: false };
  }
}
