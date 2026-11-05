import { Router } from 'express';
import type { ResultSetHeader } from 'mysql2/promise';
import { pool } from '../config/db.js';
import { requireAuth } from '../middlewares/auth.js';
import { ApiError } from '../middlewares/error-handler.js';
import { id, paginacao } from '../schemas/common.js';
import { consultar, limiteSql } from '../services/helpers.js';
import { mapearNotificacao } from '../services/mapeadores.js';

export const notificacoesRouter = Router();
notificacoesRouter.use(requireAuth);

notificacoesRouter.get('/', async (req, res) => {
  const { pagina, limite } = paginacao.parse(req.query);
  const linhas = await consultar(
    pool,
    `SELECT * FROM notificacoes
      WHERE id_usuario_destinatario = ?
      ORDER BY data_criacao DESC
      ${limiteSql(pagina, limite)}`,
    [req.auth!.idUsuario],
  );
  res.json({ data: linhas.map(mapearNotificacao), meta: { pagina, limite } });
});

// Só o destinatário marca a própria notificação.
notificacoesRouter.patch('/:idNotificacao/lida', async (req, res) => {
  const idNotificacao = id.parse(req.params.idNotificacao);
  const [existe] = await consultar(
    pool,
    'SELECT 1 AS ok FROM notificacoes WHERE id_notificacao = ? AND id_usuario_destinatario = ?',
    [idNotificacao, req.auth!.idUsuario],
  );
  if (!existe) throw new ApiError(404, 'Notificação não encontrada.', 'NOT_FOUND');
  await pool.execute<ResultSetHeader>(
    `UPDATE notificacoes SET data_leitura = UTC_TIMESTAMP(3)
      WHERE id_notificacao = ? AND data_leitura IS NULL`,
    [idNotificacao],
  );
  res.status(204).end();
});
