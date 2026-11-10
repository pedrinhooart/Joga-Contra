import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import { env } from '../config/env.js';
import { requireAuth } from '../middlewares/auth.js';
import { ApiError } from '../middlewares/error-handler.js';
import { siglaEstado } from '../schemas/common.js';
import { cidadeValida, locais } from '../services/locais.js';

export const locaisRouter = Router();
locaisRouter.use(requireAuth);

if (env.NODE_ENV !== 'test') {
  locaisRouter.use(
    rateLimit({
      windowMs: 15 * 60_000,
      limit: 60,
      standardHeaders: true,
      legacyHeaders: false,
      message: { error: { code: 'RATE_LIMIT', message: 'Muitas buscas de locais. Aguarde alguns minutos.' } },
    }),
  );
}

const consultaSchema = z.object({
  uf: siglaEstado,
  cidade: z.string().trim().min(1).max(100),
});

/**
 * Locais esportivos de uma cidade, para sugerir no anúncio. O app pede uma vez
 * por cidade e filtra no aparelho enquanto o capitão digita.
 */
locaisRouter.get('/', async (req, res) => {
  const { uf, cidade } = consultaSchema.parse(req.query);
  if (!cidadeValida(cidade)) throw new ApiError(400, 'Cidade inválida.', 'VALIDATION_ERROR');
  res.json({
    data: {
      fonte: locais.fonte.nome,
      atribuicao: locais.fonte.atribuicao,
      locais: await locais.buscar(cidade, uf),
    },
  });
});
