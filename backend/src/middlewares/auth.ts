import type { Request, RequestHandler } from 'express';
import jwt from 'jsonwebtoken';
import { createHmac } from 'node:crypto';
import { pool } from '../config/db.js';
import { env } from '../config/env.js';
import { consultar } from '../services/helpers.js';
import { ApiError } from './error-handler.js';

/**
 * Impressão da senha atual, gravada no token (claim `sv`). Quando a senha muda,
 * a impressão muda e todas as sessões abertas antes disso deixam de valer.
 * É um HMAC do hash: o token (legível por quem o tem) não revela nada da senha.
 */
export const impressaoSenha = (hashSenha: string) =>
  createHmac('sha256', env.JWT_SECRET).update(hashSenha).digest('base64url').slice(0, 16);

export const gerarTokenSessao = (idUsuario: string, hashSenha: string) =>
  jwt.sign({ sv: impressaoSenha(hashSenha) }, env.JWT_SECRET, {
    subject: idUsuario,
    algorithm: 'HS256',
    expiresIn: env.JWT_EXPIRES_IN as jwt.SignOptions['expiresIn'],
  });

/**
 * Valida o JWT e carrega o capitão da sessão. A conta é conferida a cada
 * requisição para que suspensão, exclusão ou troca de senha tenham efeito imediato.
 */
export const requireAuth: RequestHandler = async (req, _res, next) => {
  const token = req.header('authorization')?.replace(/^Bearer\s+/i, '');
  if (!token) return next(new ApiError(401, 'Token de autenticação obrigatório.', 'UNAUTHORIZED'));

  let idUsuario: string;
  let payload: jwt.JwtPayload;
  try {
    const lido = jwt.verify(token, env.JWT_SECRET, { algorithms: ['HS256'] });
    if (typeof lido === 'string' || !lido.sub) throw new Error();
    payload = lido;
    idUsuario = lido.sub;
  } catch {
    return next(new ApiError(401, 'Sessão inválida ou expirada.', 'UNAUTHORIZED'));
  }

  const [linha] = await consultar(
    pool,
    `SELECT u.status_conta, u.hash_senha, t.id_time,
            (SELECT MAX(c.data_uso) FROM codigos_recuperacao_senha c WHERE c.id_usuario = u.id_usuario) AS ultima_redefinicao
       FROM usuarios u
       LEFT JOIN times t ON t.id_capitao = u.id_usuario AND t.data_arquivamento IS NULL
      WHERE u.id_usuario = ?`,
    [idUsuario],
  );
  if (!linha || linha.status_conta !== 'ativa' || !sessaoAindaValida(payload, linha)) {
    return next(new ApiError(401, 'Sessão inválida ou expirada.', 'UNAUTHORIZED'));
  }
  req.auth = { idUsuario, idTime: linha.id_time ?? null };
  next();
};

/**
 * Tokens novos trazem a impressão da senha. Os emitidos antes desta regra (sem
 * `sv`) valem até expirar, salvo se a senha foi redefinida depois da emissão.
 */
function sessaoAindaValida(payload: jwt.JwtPayload, linha: Record<string, any>): boolean {
  if (typeof payload.sv === 'string') return payload.sv === impressaoSenha(linha.hash_senha);
  const redefinida = linha.ultima_redefinicao instanceof Date ? linha.ultima_redefinicao.getTime() : null;
  return redefinida === null || (payload.iat ?? 0) * 1000 > redefinida;
}

/** Time do capitão logado. Toda rota que age em nome de um time usa este valor. */
export function meuTime(req: Request): string {
  const idTime = req.auth?.idTime;
  if (!idTime) throw new ApiError(403, 'Sua conta não possui um time ativo.', 'FORBIDDEN');
  return idTime;
}
