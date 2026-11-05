import type { RowDataPacket } from 'mysql2';
import { pool } from '../config/db.js';
import { env } from '../config/env.js';

const UMA_HORA_MS = 60 * 60_000;

/**
 * Quantos registros anteriores a ROTINAS_PRESERVAR_ATE cada rotina alteraria agora.
 * Os procedimentos do banco são globais e não aceitam filtro, por isso a proteção é aqui.
 */
export async function registrosPreservadosAfetados() {
  const corte = env.ROTINAS_PRESERVAR_ATE;
  if (!corte) return { anuncios: 0, partidas: 0 };
  const [linhas] = await pool.query<RowDataPacket[]>(
    `SELECT
       (SELECT COUNT(*) FROM anuncios_partidas
         WHERE status IN ('ativo', 'pausado') AND data_exclusao IS NULL
           AND data_hora_inicio <= UTC_TIMESTAMP(3) AND data_criacao <= ?) AS anuncios,
       (SELECT COUNT(*) FROM partidas
         WHERE status = 'confirmada' AND data_criacao <= ?
           AND data_hora_inicio <= UTC_TIMESTAMP(3) - INTERVAL ? HOUR) AS partidas`,
    [corte, corte, env.HORAS_PARTIDA_REALIZADA],
  );
  return { anuncios: Number(linhas[0].anuncios), partidas: Number(linhas[0].partidas) };
}

/** Expira anúncios vencidos e marca partidas como realizadas, sem tocar nos registros preservados. */
export async function executarRotinas() {
  const { anuncios, partidas } = await registrosPreservadosAfetados();
  if (anuncios > 0) {
    console.warn(`Expiração de anúncios suspensa: alteraria ${anuncios} registro(s) preservado(s).`);
  } else {
    await pool.query('CALL proc_expirar_anuncios()');
  }
  if (partidas > 0) {
    console.warn(`Marcação de partidas suspensa: alteraria ${partidas} registro(s) preservado(s).`);
  } else {
    await pool.query('CALL proc_marcar_partidas_realizadas(?)', [env.HORAS_PARTIDA_REALIZADA]);
  }
}

/** Agenda as rotinas: ao iniciar e a cada hora. Falhas só são registradas. */
export function agendarRotinas() {
  const rodar = () =>
    executarRotinas().catch((erro) => console.error('Falha nas rotinas agendadas:', erro?.code ?? erro?.message));
  rodar();
  return setInterval(rodar, UMA_HORA_MS);
}
