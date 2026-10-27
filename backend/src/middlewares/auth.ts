import type { RequestHandler } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { ApiError } from './error-handler.js';
export const requireAuth: RequestHandler = (req, _res, next) => { const token = req.header('authorization')?.replace(/^Bearer\s+/i, ''); if (!token) return next(new ApiError(401, 'Token de autenticação obrigatório.')); try { const payload = jwt.verify(token, env.JWT_SECRET); if (typeof payload === 'string' || !payload.sub) throw new Error(); req.auth = { userId: payload.sub }; next(); } catch { next(new ApiError(401, 'Token inválido ou expirado.')); } };
