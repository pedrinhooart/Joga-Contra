import 'dotenv/config';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import mysql from 'mysql2/promise';
const dbEnv = { host: process.env.DB_HOST ?? '127.0.0.1', port: Number(process.env.DB_PORT ?? 3306), user: process.env.DB_USER ?? '', password: process.env.DB_PASSWORD ?? '', database: process.env.DB_NAME ?? '' };

async function main() {
  const seedPath = path.resolve(process.cwd(), '../database/seeds.sql');
  const source = await readFile(seedPath, 'utf8');
  // The source catalog is authoritative. INSERT IGNORE preserves all existing rows and makes this safe to repeat.
  const safeSql = source.replace(/INSERT\s+INTO/gi, 'INSERT IGNORE INTO');
  const db = await mysql.createConnection({ ...dbEnv, multipleStatements: true });
  try {
    await db.query("SET time_zone = '+00:00'");
    await db.query(safeSql);
    console.log('Catálogos de referência aplicados sem sobrescrever registros existentes.');
  } finally { await db.end(); }
}
main().catch(error => { console.error('Falha no seed:', error.code ?? error.message); process.exitCode = 1; });
