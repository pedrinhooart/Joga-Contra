import { z } from 'zod';

export const id = z.string().uuid();
export const idReferencia = z.number().int().positive().max(255);
export const paginacao = z.object({
  pagina: z.coerce.number().int().min(1).default(1),
  limite: z.coerce.number().int().min(1).max(100).default(50),
});
export const textoOpcional = (maximo: number) =>
  z.string().trim().max(maximo).nullish().transform((v) => v || null);
export const siglaEstado = z.string().trim().length(2).transform((v) => v.toUpperCase());
