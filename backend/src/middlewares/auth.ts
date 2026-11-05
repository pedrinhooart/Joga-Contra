import type { Request, RequestHandler } from 'express';
import jwt from 'jsonwebtoken';
import { pool } from '../config/db.js';
import { env } from '../config/env.js';
import { consultar } from '../services/helpers.js';
import { ApiError } from './error-handler.js';

/**
 * Valida o JWT e carrega o capitão da sessão. A conta é conferida a cada
 * requisição para que suspensão ou exclusão tenham efeito imediato.
 */
export const requireAuth: RequestHandler = async (req, _res, next) => {
  const token = req.header('authorization')?.replace(/^Bearer\s+/i, '');
  if (!token) return next(new ApiError(401, 'Token de autenticação obrigatório.', 'UNAUTHORIZED'));

  let idUsuario: string;
  try {
    const payload = jwt.verify(token, env.JWT_SECRET, { algorithms: ['HS256'] });
    if (typeof payload === 'string' || !payload.sub) throw new Error();
    idUsuario = payload.sub;
  } catch {
    return next(new ApiError(401, 'Sessão inválida ou expirada.', 'UNAUTHORIZED'));
  }

  const [linha] = await consultar(
    pool,
    `SELECT u.status_conta, t.id_time
       FROM usuarios u
       LEFT JOIN times t ON t.id_capitao = u.id_usuario AND t.data_arquivamento IS NULL
      WHERE u.id_usuario = ?`,
    [idUsuario],
  );
  if (!linha || linha.status_conta !== 'ativa') {
    return next(new ApiError(401, 'Sessão inválida ou expirada.', 'UNAUTHORIZED'));
  }
  req.auth = { idUsuario, idTime: linha.id_time ?? null };
  next();
};

/** Time do capitão logado. Toda rota que age em nome de um time usa este valor. */
export function meuTime(req: Request): string {
  const idTime = req.auth?.idTime;
  if (!idTime) throw new ApiError(403, 'Sua conta não possui um time ativo.', 'FORBIDDEN');
  return idTime;
}
