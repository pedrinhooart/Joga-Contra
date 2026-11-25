import { Router } from 'express';
import type { ResultSetHeader } from 'mysql2/promise';
import { z } from 'zod';
import { pool } from '../config/db.js';
import { requireAuth } from '../middlewares/auth.js';
import { ApiError } from '../middlewares/error-handler.js';
import { id } from '../schemas/common.js';
import { consultar, dataIso, emTransacao, repetirEmImpasse, uuid } from '../services/helpers.js';

/**
 * Aparelhos que recebem push. Sempre do capitão logado (token da sessão); o
 * token FCM nunca é devolvido pela API nem gravado em log.
 */
export const dispositivosRouter = Router();
dispositivosRouter.use(requireAuth);

const tokenFcm = z.string().trim().min(20).max(512).regex(/^[A-Za-z0-9:_\-.]+$/, 'Token inválido.');

const registroSchema = z.object({
  token: tokenFcm,
  plataforma: z.enum(['android', 'ios', 'web']),
  /** O capitão autorizou notificações no aparelho. Sem autorização, nada é enviado. */
  permitido: z.boolean(),
  /** Token anterior deste aparelho (renovação pelo FCM): é substituído. */
  tokenAnterior: tokenFcm.optional(),
});

const mapear = (d: Record<string, any>) => ({
  idDispositivo: d.id_dispositivo,
  plataforma: d.plataforma,
  permitido: !!d.permissao_notificacoes,
  ativo: !!d.ativo,
  motivoDesativacao: d.motivo_desativacao,
  dataCriacao: dataIso(d.data_criacao),
  dataUltimoUso: dataIso(d.data_ultimo_uso),
  dataUltimoEnvio: dataIso(d.data_ultimo_envio),
});

/**
 * Registra ou renova o token deste aparelho (idempotente). Se o token estava
 * com outra conta (outra pessoa entrou neste aparelho), ele passa para quem está
 * logado agora: um token nunca fica com duas contas.
 */
dispositivosRouter.put('/', async (req, res) => {
  const { token, plataforma, permitido, tokenAnterior } = registroSchema.parse(req.body);
  const idUsuario = req.auth!.idUsuario;
  const idDispositivo = await repetirEmImpasse(() =>
    emTransacao(async (db) => {
      const [atual] = await consultar(db, 'SELECT id_dispositivo FROM dispositivos_push WHERE token_fcm = ? FOR UPDATE', [token]);
      const [anterior] =
        tokenAnterior && tokenAnterior !== token
          ? await consultar(
              db,
              'SELECT id_dispositivo FROM dispositivos_push WHERE token_fcm = ? AND id_usuario = ? FOR UPDATE',
              [tokenAnterior, idUsuario],
            )
          : [];
      if (atual) {
        await db.execute(
          `UPDATE dispositivos_push
              SET id_usuario = ?, plataforma = ?, permissao_notificacoes = ?, ativo = 1, motivo_desativacao = NULL,
                  data_ultimo_uso = UTC_TIMESTAMP(3)
            WHERE id_dispositivo = ?`,
          [idUsuario, plataforma, permitido ? 1 : 0, atual.id_dispositivo],
        );
        if (anterior) {
          await db.execute(
            `UPDATE dispositivos_push SET ativo = 0, motivo_desativacao = 'token_substituido'
              WHERE id_dispositivo = ? AND ativo = 1`,
            [anterior.id_dispositivo],
          );
        }
        return atual.id_dispositivo as string;
      }
      if (anterior) {
        // Renovação: o mesmo aparelho, com token novo.
        await db.execute(
          `UPDATE dispositivos_push
              SET token_fcm = ?, plataforma = ?, permissao_notificacoes = ?, ativo = 1, motivo_desativacao = NULL,
                  data_ultimo_uso = UTC_TIMESTAMP(3)
            WHERE id_dispositivo = ?`,
          [token, plataforma, permitido ? 1 : 0, anterior.id_dispositivo],
        );
        return anterior.id_dispositivo as string;
      }
      const novo = uuid();
      await db.execute(
        `INSERT INTO dispositivos_push (id_dispositivo, id_usuario, token_fcm, plataforma, permissao_notificacoes)
         VALUES (?, ?, ?, ?, ?)`,
        [novo, idUsuario, token, plataforma, permitido ? 1 : 0],
      );
      return novo;
    }),
  );
  const [dispositivo] = await consultar(pool, 'SELECT * FROM dispositivos_push WHERE id_dispositivo = ?', [idDispositivo]);
  res.json({ data: mapear(dispositivo) });
});

dispositivosRouter.get('/', async (req, res) => {
  const linhas = await consultar(
    pool,
    'SELECT * FROM dispositivos_push WHERE id_usuario = ? ORDER BY data_ultimo_uso DESC',
    [req.auth!.idUsuario],
  );
  res.json({ data: linhas.map(mapear) });
});

// Sair da conta neste aparelho: para de receber push desta conta. Responde 204
// mesmo se o token não for desta conta (não revela de quem é).
dispositivosRouter.patch('/desativar', async (req, res) => {
  const { token } = z.object({ token: tokenFcm }).parse(req.body);
  await pool.execute<ResultSetHeader>(
    `UPDATE dispositivos_push SET ativo = 0, motivo_desativacao = 'saiu_da_conta'
      WHERE token_fcm = ? AND id_usuario = ? AND ativo = 1`,
    [token, req.auth!.idUsuario],
  );
  res.status(204).end();
});

// Remover um aparelho da conta: desativa e apaga o token (o registro fica no histórico).
dispositivosRouter.delete('/:idDispositivo', async (req, res) => {
  const idDispositivo = id.parse(req.params.idDispositivo);
  const [resultado] = await pool.execute<ResultSetHeader>(
    `UPDATE dispositivos_push SET token_fcm = NULL, ativo = 0, motivo_desativacao = 'removido'
      WHERE id_dispositivo = ? AND id_usuario = ?`,
    [idDispositivo, req.auth!.idUsuario],
  );
  if (resultado.affectedRows === 0) throw new ApiError(404, 'Dispositivo não encontrado.', 'NOT_FOUND');
  res.status(204).end();
});
