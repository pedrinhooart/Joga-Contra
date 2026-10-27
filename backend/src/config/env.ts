import 'dotenv/config';
import { z } from 'zod';

const schema = z.object({
  DB_HOST: z.string().default('127.0.0.1'), DB_PORT: z.coerce.number().int().positive().default(3306),
  DB_USER: z.string().min(1), DB_PASSWORD: z.string(), DB_NAME: z.string().min(1),
  JWT_SECRET: z.string().min(32), JWT_EXPIRES_IN: z.string().default('1d'),
  PORT: z.coerce.number().int().positive().default(3000), HOST: z.string().default('0.0.0.0'), CORS_ORIGIN: z.string().default('*'),
});
export const env = schema.parse(process.env);
