import { Router } from 'express';
import path from 'node:path';
import {
  CAMINHO_PAGINA,
  PASTA_PUBLICA,
  assetLinks,
  paginaRedefinicao,
  scriptPaginaRedefinicao,
} from '../services/recuperacao-senha.js';

/**
 * Páginas abertas no navegador (fora de /api): a ponte entre o link do e-mail
 * e o app, e a associação de domínio dos Android App Links.
 */
export const publicoRouter = Router();

/** Só o próprio script e estilos da página; nada de terceiros, nada embutido em frames. */
const POLITICA_PAGINA = [
  "default-src 'none'",
  "script-src 'self'",
  "style-src 'unsafe-inline'",
  "img-src 'self'",
  "base-uri 'none'",
  "form-action 'none'",
  "frame-ancestors 'none'",
].join('; ');

publicoRouter.get(CAMINHO_PAGINA, (_req, res) => {
  res
    .set('Content-Security-Policy', POLITICA_PAGINA)
    .set('Cache-Control', 'no-store')
    .type('html')
    .send(paginaRedefinicao());
});

publicoRouter.get(`${CAMINHO_PAGINA}/abrir.js`, (_req, res) => {
  res.set('Cache-Control', 'no-cache').type('application/javascript').send(scriptPaginaRedefinicao());
});

publicoRouter.get(`${CAMINHO_PAGINA}/logo.png`, (_req, res) => {
  res.sendFile(path.join(PASTA_PUBLICA, 'logo.png'), { maxAge: '1d' });
});

publicoRouter.get('/.well-known/assetlinks.json', (_req, res) => {
  const associacao = assetLinks();
  if (!associacao) {
    res.status(404).json({ error: { code: 'NOT_FOUND', message: 'App Links não configurados.' } });
    return;
  }
  res.json(associacao);
});
