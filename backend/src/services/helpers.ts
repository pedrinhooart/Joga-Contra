import type { Pool, PoolConnection, RowDataPacket } from 'mysql2/promise';
import { randomUUID } from 'node:crypto';
import { pool } from '../config/db.js';

export type Linha = Record<string, any>;
export type Executor = Pick<Pool | PoolConnection, 'execute'>;

export const uuid = () => randomUUID();

/** Consulta parametrizada (prepared statement). */
export async function consultar(db: Executor, sql: string, params: unknown[] = []): Promise<Linha[]> {
  const [linhas] = await db.execute<RowDataPacket[]>(sql, params as any[]);
  return linhas;
}

/** Executa `acao` numa transação, com rollback em caso de erro. */
export async function emTransacao<T>(acao: (db: PoolConnection) => Promise<T>): Promise<T> {
  const db = await pool.getConnection();
  try {
    await db.beginTransaction();
    const resultado = await acao(db);
    await db.commit();
    return resultado;
  } catch (erro) {
    await db.rollback();
    throw erro;
  } finally {
    db.release();
  }
}

/** `?, ?, ?` para cláusulas IN. */
export const marcadores = (quantidade: number) => Array(quantidade).fill('?').join(', ');

/**
 * LIMIT/OFFSET interpolados: o protocolo binário do MySQL rejeita números como
 * parâmetro de LIMIT. Os valores são inteiros validados pelo zod.
 */
export const limiteSql = (pagina: number, limite: number) =>
  `LIMIT ${Math.trunc(limite)} OFFSET ${Math.trunc((pagina - 1) * limite)}`;

/** Date -> texto UTC aceito por DATETIME(3). */
export const dataSql = (data: Date) => data.toISOString().slice(0, 23).replace('T', ' ');

export const dataIso = (valor: unknown): string | null =>
  valor instanceof Date ? valor.toISOString() : null;

/** Escapa curingas de LIKE vindos do usuário. */
export const escaparLike = (texto: string) => texto.replace(/[\\%_]/g, '\\$&');

type NovaNotificacao = {
  idDestinatario: string;
  tipo: 'solicitacao_recebida' | 'mensagem_recebida';
  titulo: string;
  mensagem: string;
  idSolicitacao: string;
};

/** Notificações geradas pela API (as demais são criadas pelos procedimentos do banco). */
export const criarNotificacao = (db: Executor, n: NovaNotificacao) =>
  db.execute(
    `INSERT INTO notificacoes (id_notificacao, id_usuario_destinatario, tipo, titulo, mensagem, id_solicitacao)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [uuid(), n.idDestinatario, n.tipo, n.titulo, n.mensagem.slice(0, 500), n.idSolicitacao],
  );
