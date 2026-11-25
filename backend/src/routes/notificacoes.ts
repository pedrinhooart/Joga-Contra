import { Router } from 'express';
import { z } from 'zod';
import type { ResultSetHeader } from 'mysql2/promise';
import { pool } from '../config/db.js';
import { requireAuth } from '../middlewares/auth.js';
import { ApiError } from '../middlewares/error-handler.js';
import { id, paginacao } from '../schemas/common.js';
import { consultar, type Executor } from '../services/helpers.js';
import { mapearNotificacao } from '../services/mapeadores.js';

/**
 * Central de notificações. Sempre do capitão logado: o destinatário vem do
 * token, nunca do app. Não há exclusão: o histórico é preservado (o banco só
 * permite registrar a leitura).
 */
export const notificacoesRouter = Router();
notificacoesRouter.use(requireAuth);

const contagem = async (db: Executor, idUsuario: string) => {
  const [linha] = await consultar(
    db,
    `SELECT COUNT(*) AS total, COALESCE(SUM(data_leitura IS NULL), 0) AS nao_lidas
       FROM notificacoes WHERE id_usuario_destinatario = ?`,
    [idUsuario],
  );
  return { total: Number(linha.total), naoLidas: Number(linha.nao_lidas) };
};

// Mais recentes primeiro. `meta.temMais` indica se há outra página.
notificacoesRouter.get('/', async (req, res) => {
  const { pagina, limite } = paginacao.parse(req.query);
  const idUsuario = req.auth!.idUsuario;
  const linhas = await consultar(
    pool,
    `SELECT * FROM notificacoes
      WHERE id_usuario_destinatario = ?
      ORDER BY data_criacao DESC, id_notificacao DESC
      LIMIT ${limite + 1} OFFSET ${(pagina - 1) * limite}`, // inteiros validados pelo zod; um a mais indica outra página
    [idUsuario],
  );
  const temMais = linhas.length > limite;
  res.json({
    data: linhas.slice(0, limite).map(mapearNotificacao),
    meta: { pagina, limite, temMais, ...(await contagem(pool, idUsuario)) },
  });
});

// Contador do sino. `total` só cresce quando chega notificação nova: o app usa
// para saber se precisa recarregar a lista aberta.
notificacoesRouter.get('/nao-lidas', async (req, res) => {
  res.json({ data: await contagem(pool, req.auth!.idUsuario) });
});

/**
 * Preferências por categoria. Desativada: a notificação continua no histórico,
 * mas chega já lida (sem contar no sino e sem push) — quem aplica é o gatilho
 * gat_notificacoes_antes_inserir. Avisos gerais e e-mails de segurança da conta
 * (recuperação de senha) não dependem dessas opções.
 */
const preferenciasSchema = z
  .object({ desafios: z.boolean(), jogos: z.boolean(), chat: z.boolean(), lembretes: z.boolean() })
  .partial()
  .refine((p) => Object.keys(p).length > 0, 'Informe ao menos uma preferência.');

const lerPreferencias = async (idUsuario: string) => {
  const [p] = await consultar(pool, 'SELECT * FROM preferencias_notificacoes WHERE id_usuario = ?', [idUsuario]);
  return {
    desafios: p ? !!p.desafios : true,
    jogos: p ? !!p.jogos : true,
    chat: p ? !!p.chat : true,
    lembretes: p ? !!p.lembretes : true,
  };
};

notificacoesRouter.get('/preferencias', async (req, res) => {
  res.json({ data: await lerPreferencias(req.auth!.idUsuario) });
});

notificacoesRouter.put('/preferencias', async (req, res) => {
  const mudancas = preferenciasSchema.parse(req.body);
  const idUsuario = req.auth!.idUsuario;
  const novas = { ...(await lerPreferencias(idUsuario)), ...mudancas };
  await pool.execute(
    `INSERT INTO preferencias_notificacoes (id_usuario, desafios, jogos, chat, lembretes)
     VALUES (?, ?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE desafios = VALUES(desafios), jogos = VALUES(jogos),
                             chat = VALUES(chat), lembretes = VALUES(lembretes)`,
    [idUsuario, novas.desafios ? 1 : 0, novas.jogos ? 1 : 0, novas.chat ? 1 : 0, novas.lembretes ? 1 : 0],
  );
  res.json({ data: novas });
});

// Todas as do capitão. Repetir não muda nada (0 marcadas).
notificacoesRouter.patch('/lidas', async (req, res) => {
  const [resultado] = await pool.execute<ResultSetHeader>(
    `UPDATE notificacoes SET data_leitura = UTC_TIMESTAMP(3)
      WHERE id_usuario_destinatario = ? AND data_leitura IS NULL`,
    [req.auth!.idUsuario],
  );
  res.json({ data: { marcadas: resultado.affectedRows, naoLidas: 0 } });
});

// Só o destinatário marca a própria notificação; marcar de novo não é erro.
// Notificação de outra conta responde 404, como uma inexistente.
notificacoesRouter.patch('/:idNotificacao/lida', async (req, res) => {
  const idNotificacao = id.parse(req.params.idNotificacao);
  const idUsuario = req.auth!.idUsuario;
  const [resultado] = await pool.execute<ResultSetHeader>(
    `UPDATE notificacoes SET data_leitura = UTC_TIMESTAMP(3)
      WHERE id_notificacao = ? AND id_usuario_destinatario = ? AND data_leitura IS NULL`,
    [idNotificacao, idUsuario],
  );
  if (resultado.affectedRows === 0) {
    const [existe] = await consultar(
      pool,
      'SELECT 1 AS ok FROM notificacoes WHERE id_notificacao = ? AND id_usuario_destinatario = ?',
      [idNotificacao, idUsuario],
    );
    if (!existe) throw new ApiError(404, 'Notificação não encontrada.', 'NOT_FOUND');
  }
  res.status(204).end();
});
