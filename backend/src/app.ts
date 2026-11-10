import cors from 'cors';
import express from 'express';
import rateLimit from 'express-rate-limit';
import helmet from 'helmet';
import { env } from './config/env.js';
import { errorHandler, notFound } from './middlewares/error-handler.js';
import { anunciosRouter } from './routes/anuncios.js';
import { armazenamento } from './services/armazenamento.js';
import { authRouter } from './routes/auth.js';
import { healthRouter } from './routes/health.js';
import { notificacoesRouter } from './routes/notificacoes.js';
import { partidasRouter } from './routes/partidas.js';
import { referenciasRouter } from './routes/referencias.js';
import { solicitacoesRouter } from './routes/solicitacoes.js';
import { timesRouter } from './routes/times.js';

export function createApp() {
  const app = express();
  const origens = env.CORS_ORIGIN === '*' ? true : env.CORS_ORIGIN.split(',').map((v) => v.trim());

  if (env.NODE_ENV !== 'test') {
    // Só método, caminho e status: nunca corpo, query string ou cabeçalhos.
    app.use((req, res, next) => {
      const inicio = Date.now();
      res.on('finish', () =>
        console.log(`${req.method} ${req.originalUrl.split('?')[0]} ${res.statusCode} ${Date.now() - inicio}ms`),
      );
      next();
    });
  }

  app.use(helmet());
  app.use(cors({ origin: origens }));
  app.use(express.json({ limit: '100kb' }));

  if (env.NODE_ENV !== 'test') {
    const limitar = (limit: number, skipSuccessfulRequests = false) =>
      rateLimit({
        windowMs: 15 * 60_000,
        limit,
        skipSuccessfulRequests,
        standardHeaders: true,
        legacyHeaders: false,
        message: { error: { code: 'RATE_LIMIT', message: 'Muitas tentativas. Aguarde alguns minutos.' } },
      });
    app.use('/api/auth/login', limitar(10, true)); // conta só as tentativas erradas
    app.use('/api/auth/cadastro', limitar(10));
    app.use('/api/auth/recuperar-senha', limitar(5));
    app.use('/api/auth/redefinir-senha', limitar(5));
  }

  // Imagens enviadas (escudos). Nomes únicos por envio: podem ficar em cache.
  app.use(
    '/api/arquivos',
    express.static(armazenamento.raiz, { index: false, dotfiles: 'deny', maxAge: '30d', immutable: true }),
  );

  app.use('/api/health', healthRouter);
  app.use('/api/auth', authRouter);
  app.use('/api/referencias', referenciasRouter);
  app.use('/api/times', timesRouter);
  app.use('/api/anuncios', anunciosRouter);
  app.use('/api/solicitacoes', solicitacoesRouter);
  app.use('/api/partidas', partidasRouter);
  app.use('/api/notificacoes', notificacoesRouter);

  app.use(notFound);
  app.use(errorHandler);
  return app;
}
