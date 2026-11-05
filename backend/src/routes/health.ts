import { Router } from 'express';
import { checkDatabase } from '../config/db.js';

const BANCO_ESPERADO = 'joga_contra_v2';

export const healthRouter = Router();

healthRouter.get('/', (_req, res) => {
  res.json({ data: { status: 'ok' } });
});

/** API no ar, conexão ativa e banco correto. Nunca devolver host, usuário ou senha. */
healthRouter.get('/db', async (_req, res) => {
  try {
    const banco = await checkDatabase();
    const bancoCorreto = banco === BANCO_ESPERADO;
    res.status(bancoCorreto ? 200 : 503).json({
      data: { status: bancoCorreto ? 'ok' : 'banco_incorreto', conexaoAtiva: true, banco, bancoCorreto },
    });
  } catch {
    res.status(503).json({ error: { code: 'DATABASE_UNAVAILABLE', message: 'Banco de dados indisponível.' } });
  }
});
