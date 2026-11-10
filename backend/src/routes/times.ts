import { randomUUID } from 'node:crypto';
import express, { Router, type NextFunction, type Request, type Response } from 'express';
import rateLimit from 'express-rate-limit';
import { pool } from '../config/db.js';
import { env } from '../config/env.js';
import { meuTime, requireAuth } from '../middlewares/auth.js';
import { ApiError } from '../middlewares/error-handler.js';
import { atualizacaoTimeSchema } from '../schemas/api.js';
import { id } from '../schemas/common.js';
import { armazenamento, LIMITE_IMAGEM_BYTES, TIPOS_IMAGEM, tipoDaImagem } from '../services/armazenamento.js';
import { obterTime } from '../services/consultas.js';
import { consultar, dataIso, emTransacao } from '../services/helpers.js';

export const timesRouter = Router();
timesRouter.use(requireAuth);

const COLUNAS: Record<string, string> = {
  nome: 'nome',
  descricao: 'descricao',
  quantidadeJogadores: 'quantidade_jogadores',
  idCategoriaEtaria: 'id_categoria_etaria',
  idNivelTecnico: 'id_nivel_tecnico',
  cidade: 'cidade',
  siglaEstado: 'sigla_estado',
  telefoneContato: 'telefone_contato',
};

timesRouter.get('/:idTime', async (req, res) => {
  const idTime = id.parse(req.params.idTime);
  res.json({ data: await obterTime(pool, idTime, idTime === req.auth!.idTime) });
});

// Somente o capitão altera o próprio time.
timesRouter.patch('/:idTime', async (req, res) => {
  const idTime = id.parse(req.params.idTime);
  if (idTime !== meuTime(req)) throw new ApiError(403, 'Somente o capitão pode alterar este time.', 'FORBIDDEN');
  const { idsModalidades, ...campos } = atualizacaoTimeSchema.parse(req.body);

  const alterados = Object.entries(campos).filter(([, valor]) => valor !== undefined);
  if (!alterados.length && !idsModalidades) throw new ApiError(400, 'Informe ao menos um campo.', 'VALIDATION_ERROR');

  await emTransacao(async (db) => {
    if (alterados.length) {
      // As colunas vêm da lista fixa acima, nunca do corpo da requisição.
      await db.execute(
        `UPDATE times SET ${alterados.map(([campo]) => `${COLUNAS[campo]} = ?`).join(', ')} WHERE id_time = ?`,
        [...alterados.map(([, valor]) => valor as string | number), idTime],
      );
    }
    if (idsModalidades) {
      await db.execute('DELETE FROM times_modalidades WHERE id_time = ?', [idTime]);
      await db.execute(
        `INSERT INTO times_modalidades (id_time, id_modalidade) VALUES ${idsModalidades.map(() => '(?, ?)').join(', ')}`,
        idsModalidades.flatMap((modalidade) => [idTime, modalidade]),
      );
    }
  });

  res.json({ data: await obterTime(pool, idTime, true) });
});

// Foto (escudo) do time: corpo binário JPEG, PNG ou WebP de até 2 MB.
// Ordem segura: grava o arquivo novo, troca a referência no banco e só então
// apaga o antigo. Qualquer falha antes disso mantém a foto atual.
const imagemNoCorpo = express.raw({ type: Object.keys(TIPOS_IMAGEM), limit: LIMITE_IMAGEM_BYTES });
const limitarEnvios =
  env.NODE_ENV === 'test'
    ? (_req: Request, _res: Response, next: NextFunction) => next()
    : rateLimit({
        windowMs: 15 * 60_000,
        limit: 20,
        standardHeaders: true,
        legacyHeaders: false,
        message: { error: { code: 'RATE_LIMIT', message: 'Muitos envios. Aguarde alguns minutos.' } },
      });

timesRouter.put('/:idTime/escudo', limitarEnvios, imagemNoCorpo, async (req, res) => {
  const idTime = id.parse(req.params.idTime);
  if (idTime !== meuTime(req)) throw new ApiError(403, 'Somente o capitão pode alterar este time.', 'FORBIDDEN');
  if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
    throw new ApiError(415, 'Envie uma imagem JPEG, PNG ou WebP.', 'UNSUPPORTED_MEDIA_TYPE');
  }
  const tipo = tipoDaImagem(req.body);
  if (!tipo) throw new ApiError(400, 'O arquivo enviado não é uma imagem JPEG, PNG ou WebP válida.', 'VALIDATION_ERROR');

  const [atual] = await consultar(pool, 'SELECT url_escudo FROM times WHERE id_time = ?', [idTime]);
  const endereco = await armazenamento.salvar('escudos', `${idTime}-${randomUUID()}.${TIPOS_IMAGEM[tipo]}`, req.body);
  try {
    await pool.execute('UPDATE times SET url_escudo = ? WHERE id_time = ?', [endereco, idTime]);
  } catch (erro) {
    await armazenamento.remover(endereco).catch(() => {});
    throw erro;
  }
  if (atual?.url_escudo) {
    await armazenamento.remover(atual.url_escudo).catch((e) => console.warn('Escudo antigo não removido:', e?.code));
  }
  res.json({ data: await obterTime(pool, idTime, true) });
});


timesRouter.get('/:idTime/avaliacoes', async (req, res) => {
  const idTime = id.parse(req.params.idTime);
  const linhas = await consultar(
    pool,
    `SELECT a.comentario, a.data_criacao, ROUND(AVG(n.nota), 1) AS nota_media,
            t.id_time, t.nome, t.sigla, t.url_escudo, t.cidade, t.sigla_estado
       FROM avaliacoes a
       JOIN notas_avaliacao n ON n.id_avaliacao = a.id_avaliacao
       JOIN times t ON t.id_time = a.id_time_avaliador
      WHERE a.id_time_avaliado = ?
      GROUP BY a.id_avaliacao, a.comentario, a.data_criacao, t.id_time, t.nome, t.sigla, t.url_escudo, t.cidade, t.sigla_estado
      ORDER BY a.data_criacao DESC
      LIMIT 50`,
    [idTime],
  );
  res.json({
    data: linhas.map((r) => ({
      notaMedia: r.nota_media,
      comentario: r.comentario,
      dataAvaliacao: dataIso(r.data_criacao),
      timeAvaliador: {
        idTime: r.id_time,
        nome: r.nome,
        sigla: r.sigla,
        urlEscudo: r.url_escudo,
        cidade: r.cidade,
        siglaEstado: r.sigla_estado,
      },
    })),
  });
});
