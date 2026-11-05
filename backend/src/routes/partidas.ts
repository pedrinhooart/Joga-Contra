import { Router } from 'express';
import { pool } from '../config/db.js';
import { meuTime, requireAuth } from '../middlewares/auth.js';
import { ApiError } from '../middlewares/error-handler.js';
import { avaliacaoSchema, cancelamentoPartidaSchema } from '../schemas/api.js';
import { id, paginacao } from '../schemas/common.js';
import { listarPartidas, obterPartida, proximaPartida } from '../services/consultas.js';
import { consultar, emTransacao, limiteSql, uuid } from '../services/helpers.js';

export const partidasRouter = Router();
partidasRouter.use(requireAuth);

partidasRouter.get('/minhas', async (req, res) => {
  const { pagina, limite } = paginacao.parse(req.query);
  res.json({
    data: await listarPartidas(pool, meuTime(req), limiteSql(pagina, limite)),
    meta: { pagina, limite },
  });
});

partidasRouter.get('/proxima', async (req, res) => {
  res.json({ data: await proximaPartida(pool, meuTime(req)) });
});

partidasRouter.get('/:idPartida', async (req, res) => {
  res.json({ data: await obterPartida(pool, id.parse(req.params.idPartida), meuTime(req)) });
});

partidasRouter.patch('/:idPartida/cancelar', async (req, res) => {
  const idPartida = id.parse(req.params.idPartida);
  const { motivo } = cancelamentoPartidaSchema.parse(req.body ?? {});
  const idTime = meuTime(req);
  await obterPartida(pool, idPartida, idTime);
  await pool.execute('CALL proc_cancelar_partida(?, ?, ?)', [idPartida, req.auth!.idUsuario, motivo]);
  res.json({ data: await obterPartida(pool, idPartida, idTime) });
});

// Avaliação e notas na mesma transação; todos os critérios ativos são obrigatórios.
partidasRouter.post('/:idPartida/avaliacoes', async (req, res) => {
  const idPartida = id.parse(req.params.idPartida);
  const { notas, comentario } = avaliacaoSchema.parse(req.body);
  const idTime = meuTime(req);
  const partida = await obterPartida(pool, idPartida, idTime);

  const criterios = await consultar(pool, 'SELECT id_criterio FROM criterios_avaliacao WHERE ativo = TRUE');
  const informados = new Set(notas.map((n) => n.idCriterio));
  if (informados.size !== notas.length || criterios.some((c) => !informados.has(c.id_criterio))) {
    throw new ApiError(400, 'Avalie cada critério uma vez.', 'VALIDATION_ERROR');
  }

  const idTimeAvaliado =
    partida.timeAnunciante.idTime === idTime ? partida.timeAdversario.idTime : partida.timeAnunciante.idTime;
  const idAvaliacao = uuid();
  await emTransacao(async (db) => {
    await db.execute(
      `INSERT INTO avaliacoes (id_avaliacao, id_partida, id_time_avaliador, id_time_avaliado, comentario)
       VALUES (?, ?, ?, ?, ?)`,
      [idAvaliacao, idPartida, idTime, idTimeAvaliado, comentario],
    );
    await db.execute(
      `INSERT INTO notas_avaliacao (id_avaliacao, id_criterio, nota)
       VALUES ${notas.map(() => '(?, ?, ?)').join(', ')}`,
      notas.flatMap((n) => [idAvaliacao, n.idCriterio, n.nota]),
    );
  });
  res.status(201).end();
});
