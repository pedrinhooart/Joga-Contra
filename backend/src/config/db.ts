import mysql from 'mysql2/promise';
import { env } from './env.js';
export const pool = mysql.createPool({ host: env.DB_HOST, port: env.DB_PORT, user: env.DB_USER, password: env.DB_PASSWORD, database: env.DB_NAME, waitForConnections: true, connectionLimit: 10, timezone: 'Z' });
export async function checkDatabase() { const connection = await pool.getConnection(); try { await connection.query("SET time_zone = '+00:00'"); await connection.query('SELECT 1'); } finally { connection.release(); } }
