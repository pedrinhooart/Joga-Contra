import mysql from 'mysql2/promise';
import { env } from './env.js';

export const pool = mysql.createPool({
  host: env.DB_HOST,
  port: env.DB_PORT,
  user: env.DB_USER,
  password: env.DB_PASSWORD,
  database: env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  timezone: 'Z',
  charset: 'utf8mb4',
  decimalNumbers: true,
});

// O banco grava datas em UTC: os DEFAULT CURRENT_TIMESTAMP usam o fuso da sessão.
pool.pool.on('connection', (conexao) => {
  conexao.query("SET time_zone = '+00:00'");
});

/** Confirma a conexão e devolve o nome do banco em uso. */
export async function checkDatabase() {
  const [linhas] = await pool.query<mysql.RowDataPacket[]>('SELECT DATABASE() AS banco');
  return linhas[0].banco as string;
}
