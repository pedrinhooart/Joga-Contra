import { Router } from 'express';
import { pool } from '../config/db.js';
import { meuTime, requireAuth } from '../middlewares/auth.js';
import { ApiError } from '../middlewares/error-handler.js';
import { mensagemSchema, solicitacaoSchema } from '../schemas/api.js';
import { id, paginacao } from '../schemas/common.js';
import {
  exigirChatLiberado,
  listarSolicitacoes,
  obterSolicitacao,
  participacaoNaSolicitacao,
} from '../services/consultas.js';
import { consultar, criarNotificacao, emTransacao, limiteSql, uuid } from '../services/helpers.js';
import { mapearMensagem } from '../services/mapeadores.js';

export const solicitacoesRouter = Router();
solicitacoesRouter.use(requireAuth);

solicitacoesRouter.get('/minhas', async (req, res) => {
  const { pagina, limite } = paginacao.parse(req.query);
  res.json({
    data: await listarSolicitacoes(pool, meuTime(req), limiteSql(pagina, limite)),
    meta: { pagina, limite },
  });
});

solicitacoesRouter.get('/:idSolicitacao', async (req, res) => {
  const idSolicitacao = id.parse(req.params.idSolicitacao);
  const idTime = meuTime(req);
  await participacaoNaSolicitacao(pool, idSolicitacao, idTime);
  res.json({ data: await obterSolicitacao(pool, idSolicitacao, idTime) });
});

// "Tenho interesse". Disponibilidade do anúncio e autossolicitação são validadas
// pelo gatilho do banco, que também preenche o time anunciante.
solicitacoesRouter.post('/', async (req, res) => {
  const { idAnuncio, mensagemInicial } = solicitacaoSchema.parse(req.body);
  const idTime = meuTime(req);

  // Repetir o interesse reabre a conversa já existente.
  const [existente] = await consultar(
    pool,
    `SELECT id_solicitacao FROM solicitacoes_confronto
      WHERE id_anuncio = ? AND id_time_solicitante = ? AND status = 'pendente'`,
    [idAnuncio, idTime],
  );
  if (existente) {
    res.json({ data: await obterSolicitacao(pool, existente.id_solicitacao, idTime) });
    return;
  }

  const [anuncio] = await consultar(
    pool,
    `SELECT t.id_capitao, solicitante.nome AS nome_solicitante
       FROM anuncios_partidas a
       JOIN times t ON t.id_time = a.id_time
       JOIN times solicitante ON solicitante.id_time = ?
      WHERE a.id_anuncio = ? AND a.data_exclusao IS NULL`,
    [idTime, idAnuncio],
  );
  if (!anuncio) throw new ApiError(404, 'Anúncio não encontrado.', 'NOT_FOUND');

  const idSolicitacao = uuid();
  await emTransacao(async (db) => {
    await db.execute(
      `INSERT INTO solicitacoes_confronto (id_solicitacao, id_anuncio, id_time_solicitante, mensagem_inicial)
       VALUES (?, ?, ?, ?)`,
      [idSolicitacao, idAnuncio, idTime, mensagemInicial],
    );
    await criarNotificacao(db, {
      idDestinatario: anuncio.id_capitao,
      tipo: 'solicitacao_recebida',
      titulo: 'Tem rival querendo jogo!',
      mensagem: `O time ${anuncio.nome_solicitante} demonstrou interesse no seu anúncio.`,
      idSolicitacao,
    });
  });
  res.status(201).json({ data: await obterSolicitacao(pool, idSolicitacao, idTime) });
});

/**
 * Aceite do desafio: só o capitão do time anunciante. O pedido do desafiante já
 * é a concordância dele; o aceite registra os dois lados e o procedimento cria a
 * partida, encerra o anúncio e as demais solicitações, notifica os capitães e
 * libera o chat — tudo numa transação com bloqueio do anúncio.
 * Procedimentos abrem a própria transação: são chamados fora de `emTransacao`.
 */
solicitacoesRouter.patch('/:idSolicitacao/confirmar', async (req, res) => {
  const idSolicitacao = id.parse(req.params.idSolicitacao);
  const idTime = meuTime(req);
  const participacao = await participacaoNaSolicitacao(pool, idSolicitacao, idTime);
  if (participacao.id_time_anunciante !== idTime) {
    throw new ApiError(403, 'Somente o capitão do time anunciante aceita o desafio.', 'FORBIDDEN');
  }
  const [solicitante] = await consultar(
    pool,
    `SELECT s.data_confirmacao_solicitante, t.id_capitao
       FROM solicitacoes_confronto s JOIN times t ON t.id_time = s.id_time_solicitante
      WHERE s.id_solicitacao = ?`,
    [idSolicitacao],
  );
  if (!solicitante.data_confirmacao_solicitante) {
    await pool.execute('CALL proc_confirmar_solicitacao(?, ?)', [idSolicitacao, solicitante.id_capitao]);
  }
  await pool.execute('CALL proc_confirmar_solicitacao(?, ?)', [idSolicitacao, req.auth!.idUsuario]);
  res.json({ data: await obterSolicitacao(pool, idSolicitacao, idTime) });
});

solicitacoesRouter.patch('/:idSolicitacao/recusar', async (req, res) => {
  const idSolicitacao = id.parse(req.params.idSolicitacao);
  const idTime = meuTime(req);
  const participacao = await participacaoNaSolicitacao(pool, idSolicitacao, idTime);
  if (participacao.id_time_anunciante !== idTime) {
    throw new ApiError(403, 'Somente o capitão do time anunciante pode recusar.', 'FORBIDDEN');
  }
  await pool.execute('CALL proc_recusar_solicitacao(?, ?)', [idSolicitacao, req.auth!.idUsuario]);
  res.json({ data: await obterSolicitacao(pool, idSolicitacao, idTime) });
});

solicitacoesRouter.patch('/:idSolicitacao/cancelar', async (req, res) => {
  const idSolicitacao = id.parse(req.params.idSolicitacao);
  const idTime = meuTime(req);
  const participacao = await participacaoNaSolicitacao(pool, idSolicitacao, idTime);
  if (participacao.id_time_solicitante !== idTime) {
    throw new ApiError(403, 'Somente o capitão do time solicitante pode cancelar.', 'FORBIDDEN');
  }
  await pool.execute('CALL proc_cancelar_solicitacao(?, ?)', [idSolicitacao, req.auth!.idUsuario]);
  res.json({ data: await obterSolicitacao(pool, idSolicitacao, idTime) });
});

// Abrir a conversa marca como lidas as mensagens do outro time.
solicitacoesRouter.get('/:idSolicitacao/mensagens', async (req, res) => {
  const idSolicitacao = id.parse(req.params.idSolicitacao);
  const idTime = meuTime(req);
  await exigirChatLiberado(pool, idSolicitacao, idTime);
  await pool.execute(
    `UPDATE mensagens SET data_leitura = UTC_TIMESTAMP(3)
      WHERE id_solicitacao = ? AND id_time_remetente <> ? AND data_leitura IS NULL`,
    [idSolicitacao, idTime],
  );
  const linhas = await consultar(
    pool,
    'SELECT * FROM mensagens WHERE id_solicitacao = ? ORDER BY data_envio, id_mensagem',
    [idSolicitacao],
  );
  res.json({ data: linhas.map(mapearMensagem) });
});

solicitacoesRouter.post('/:idSolicitacao/mensagens', async (req, res) => {
  const idSolicitacao = id.parse(req.params.idSolicitacao);
  const { texto } = mensagemSchema.parse(req.body);
  const idTime = meuTime(req);
  const participacao = await exigirChatLiberado(pool, idSolicitacao, idTime);
  const idOutroTime =
    participacao.id_time_anunciante === idTime ? participacao.id_time_solicitante : participacao.id_time_anunciante;
  const [dados] = await consultar(
    pool,
    `SELECT outro.id_capitao, meu.nome AS nome_remetente
       FROM times outro JOIN times meu ON meu.id_time = ?
      WHERE outro.id_time = ?`,
    [idTime, idOutroTime],
  );

  const idMensagem = uuid();
  await emTransacao(async (db) => {
    await db.execute(
      `INSERT INTO mensagens (id_mensagem, id_solicitacao, id_time_remetente, id_usuario_remetente, texto)
       VALUES (?, ?, ?, ?, ?)`,
      [idMensagem, idSolicitacao, idTime, req.auth!.idUsuario, texto],
    );
    await criarNotificacao(db, {
      idDestinatario: dados.id_capitao,
      tipo: 'mensagem_recebida',
      titulo: 'A conversa tá rolando.',
      mensagem: `Você recebeu uma nova mensagem de ${dados.nome_remetente}.`,
      idSolicitacao,
    });
  });
  const [mensagem] = await consultar(pool, 'SELECT * FROM mensagens WHERE id_mensagem = ?', [idMensagem]);
  res.status(201).json({ data: mapearMensagem(mensagem) });
});
