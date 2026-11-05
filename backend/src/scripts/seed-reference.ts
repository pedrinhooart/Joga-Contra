import 'dotenv/config';
import mysql from 'mysql2/promise';
import { readFile } from 'node:fs/promises';
import path from 'node:path';

// Aplica database_v2/03_dados_referencia.sql, que é idempotente (só cadastros de referência).
const conexao = {
  host: process.env.DB_HOST ?? '127.0.0.1',
  port: Number(process.env.DB_PORT ?? 3306),
  user: process.env.DB_USER ?? '',
  password: process.env.DB_PASSWORD ?? '',
  database: process.env.DB_NAME ?? '',
};

async function main() {
  const script = await readFile(path.resolve(process.cwd(), '../database_v2/03_dados_referencia.sql'), 'utf8');
  const db = await mysql.createConnection({ ...conexao, multipleStatements: true });
  try {
    await db.query(script);
    console.log('Cadastros de referência aplicados.');
  } finally {
    await db.end();
  }
}

main().catch((erro) => {
  console.error('Falha ao aplicar os cadastros de referência:', erro.code ?? erro.message);
  process.exitCode = 1;
});
