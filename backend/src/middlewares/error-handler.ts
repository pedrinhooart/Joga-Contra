import type { ErrorRequestHandler, RequestHandler } from 'express';
import { ZodError } from 'zod';
export class ApiError extends Error { constructor(public status: number, message: string) { super(message); } }
export const asyncHandler = (fn: RequestHandler): RequestHandler => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
export const notFound: RequestHandler = (_req, _res, next) => next(new ApiError(404, 'Rota não encontrada.'));
export const errorHandler: ErrorRequestHandler = (error, _req, res, _next) => {
  if (error instanceof ZodError) return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: 'Dados inválidos.', details: error.flatten() } });
  if (error?.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: { code: 'CONFLICT', message: 'Registro duplicado.' } });
  if (error?.code === 'ER_NO_REFERENCED_ROW_2' || error?.code === 'ER_ROW_IS_REFERENCED_2') return res.status(409).json({ error: { code: 'RELATIONSHIP_CONFLICT', message: 'A operação viola um relacionamento existente.' } });
  if (error?.code === 'ER_SIGNAL_EXCEPTION') return res.status(409).json({ error: { code: 'BUSINESS_RULE', message: error.sqlMessage || 'Regra de negócio não permitiu a operação.' } });
  const status = error instanceof ApiError ? error.status : 500;
  if (status === 500) console.error('Erro não tratado:', error instanceof Error ? error.message : error);
  return res.status(status).json({ error: { code: status === 500 ? 'INTERNAL_ERROR' : 'REQUEST_ERROR', message: status === 500 ? 'Erro interno do servidor.' : error.message } });
};
