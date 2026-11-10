import 'dotenv/config';
import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.string().default('development'),
  DB_HOST: z.string().default('127.0.0.1'),
  DB_PORT: z.coerce.number().int().positive().default(3306),
  DB_USER: z.string().min(1),
  DB_PASSWORD: z.string(),
  DB_NAME: z.string().min(1).default('joga_contra_v2'),
  JWT_SECRET: z.string().min(32),
  JWT_EXPIRES_IN: z.string().default('1d'),
  PORT: z.coerce.number().int().positive().default(3000),
  HOST: z.string().default('0.0.0.0'),
  CORS_ORIGIN: z.string().default('*'),
  /** Horas após o início para a partida ser marcada como realizada. */
  HORAS_PARTIDA_REALIZADA: z.coerce.number().int().min(0).default(3),
  /** Registros criados até esta data nunca são alterados pelas rotinas. Vazio: sem proteção. */
  ROTINAS_PRESERVAR_ATE: z.coerce.date().optional(),
  /** Pasta das imagens enviadas (escudos). Relativa à pasta da API. */
  ARQUIVOS_DIR: z.string().min(1).default('arquivos'),
  /** Servidor Overpass (OpenStreetMap) para a busca de locais esportivos. */
  OVERPASS_URL: z.string().url().optional(),
});

export const env = schema.parse(process.env);
