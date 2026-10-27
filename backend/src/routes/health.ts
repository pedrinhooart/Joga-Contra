import { Router } from 'express';
import { checkDatabase } from '../config/db.js';
import { asyncHandler } from '../middlewares/error-handler.js';
export const healthRouter = Router();
healthRouter.get('/', (_req, res) => res.json({ data: { status: 'ok' } }));
healthRouter.get('/db', asyncHandler(async (_req, res) => { try { await checkDatabase(); res.json({ data: { status: 'ok', database: 'reachable' } }); } catch { res.status(503).json({ error: { code: 'DATABASE_UNAVAILABLE', message: 'Banco de dados indisponível.' } }); } }));
