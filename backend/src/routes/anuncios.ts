import { Router } from 'express';
import { pool } from '../config/db.js';
import { meuTime, requireAuth } from '../middlewares/auth.js';
import { anuncioSchema, filtroAnunciosSchema, statusAnuncioSchema } from '../schemas/api.js';
import { id } from '../schemas/common.js';
import {
  listarSolicitacoesDoAnuncio,
  obterAnuncio,
  obterAnuncioProprio,
  SELECT_ANUNCIO,
} from '../services/consultas.js';
import { consultar, dataSql, escaparLike, limiteSql, uuid } from '../services/helpers.js';
import { mapearAnuncio } from '../services/mapeadores.js';

export const anunciosRouter = Router();
anunciosRouter.use(requireAuth);

const MINUTO_MS = 60_000;
const DIA_MS = 24 * 60 * MINUTO_MS;

/**
 * Busca de adversários: somente anúncios disponíveis de outros times.
 * Faixa etária e nível técnico são filtros independentes.
 */
anunciosRouter.get('/', async (req, res) => {
  const f = filtroAnunciosSchema.parse(req.query);
  const condicoes = ['a.id_time <> ?'];
  const params: unknown[] = [meuTime(req)];
  const filtrar = (condicao: string, ...valores: unknown[]) => {
    condicoes.push(condicao);
    params.push(...valores);
  };

  if (f.texto) {
    filtrar(
      "CONCAT_WS(' ', a.nome_time, a.cidade, a.bairro, a.nome_local) LIKE ?",
      `%${escaparLike(f.texto)}%`,
    );
  }
  if (f.cidade) filtrar('a.cidade LIKE ?', `${escaparLike(f.cidade)}%`);
  if (f.siglaEstado) filtrar('a.sigla_estado = ?', f.siglaEstado);
  if (f.idModalidade) filtrar('a.id_modalidade = ?', f.idModalidade);
  if (f.idCategoriaEtaria) filtrar('a.id_categoria_etaria = ?', f.idCategoriaEtaria);
  if (f.idNivelTecnico) filtrar('a.id_nivel_tecnico = ?', f.idNivelTecnico);
  if (f.data) {
    // O dia é o do aparelho; o banco guarda UTC.
    const inicio = new Date(`${f.data}T00:00:00.000Z`).getTime() - f.fusoMinutos * MINUTO_MS;
    filtrar(
      'a.data_hora_inicio >= ? AND a.data_hora_inicio < ?',
      dataSql(new Date(inicio)),
      dataSql(new Date(inicio + DIA_MS)),
    );
  }
  if (f.horario) {
    // fusoMinutos é um inteiro validado pelo zod.
    filtrar(`TIME(a.data_hora_inicio + INTERVAL ${Math.trunc(f.fusoMinutos)} MINUTE) >= ?`, `${f.horario}:00`);
  }

  const linhas = await consultar(
    pool,
    `SELECT a.* FROM vis_anuncios_disponiveis a
      WHERE ${condicoes.join(' AND ')}
      ORDER BY a.data_hora_inicio
      ${limiteSql(f.pagina, f.limite)}`,
    params,
  );
  res.json({ data: linhas.map(mapearAnuncio), meta: { pagina: f.pagina, limite: f.limite } });
});

anunciosRouter.get('/meus', async (req, res) => {
  const linhas = await consultar(
    pool,
    `${SELECT_ANUNCIO}
      WHERE a.id_time = ? AND a.data_exclusao IS NULL AND a.status <> 'encerrado'
      ORDER BY a.data_hora_inicio`,
    [meuTime(req)],
  );
  res.json({ data: linhas.map(mapearAnuncio) });
});

anunciosRouter.get('/:idAnuncio', async (req, res) => {
  res.json({ data: mapearAnuncio(await obterAnuncio(pool, id.parse(req.params.idAnuncio))) });
});

// O capitão dono analisa quem solicitou o confronto.
anunciosRouter.get('/:idAnuncio/solicitacoes', async (req, res) => {
  const idAnuncio = id.parse(req.params.idAnuncio);
  const idTime = meuTime(req);
  await obterAnuncioProprio(pool, idAnuncio, idTime);
  res.json({ data: await listarSolicitacoesDoAnuncio(pool, idAnuncio, idTime) });
});

const valoresAnuncio = (a: ReturnType<typeof anuncioSchema.parse>) => [
  a.idModalidade, a.idCategoriaEtaria, a.idNivelTecnico, a.idMandoCampo, a.quantidadeJogadores,
  dataSql(a.dataHoraInicio), a.duracaoMinutos, a.cidade, a.siglaEstado, a.bairro, a.nomeLocal, a.endereco,
  a.latitude, a.longitude,
  a.valorAluguelPorTime, a.descricao,
];

// O anúncio sempre pertence ao time do capitão logado.
anunciosRouter.post('/', async (req, res) => {
  const dados = anuncioSchema.parse(req.body);
  const idAnuncio = uuid();
  await pool.execute(
    `INSERT INTO anuncios_partidas (
       id_anuncio, id_time, id_modalidade, id_categoria_etaria, id_nivel_tecnico, id_mando_campo,
       quantidade_jogadores, data_hora_inicio, duracao_minutos, cidade, sigla_estado, bairro, nome_local,
       endereco, latitude, longitude,
       valor_aluguel_por_time, descricao)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [idAnuncio, meuTime(req), ...valoresAnuncio(dados)],
  );
  res.status(201).json({ data: mapearAnuncio(await obterAnuncio(pool, idAnuncio)) });
});

anunciosRouter.put('/:idAnuncio', async (req, res) => {
  const idAnuncio = id.parse(req.params.idAnuncio);
  const dados = anuncioSchema.parse(req.body);
  await obterAnuncioProprio(pool, idAnuncio, meuTime(req));
  await pool.execute(
    `UPDATE anuncios_partidas
        SET id_modalidade = ?, id_categoria_etaria = ?, id_nivel_tecnico = ?, id_mando_campo = ?,
            quantidade_jogadores = ?, data_hora_inicio = ?, duracao_minutos = ?, cidade = ?, sigla_estado = ?,
            bairro = ?,
            nome_local = ?, endereco = ?, latitude = ?, longitude = ?, valor_aluguel_por_time = ?, descricao = ?
      WHERE id_anuncio = ?`,
    [...valoresAnuncio(dados), idAnuncio],
  );
  res.json({ data: mapearAnuncio(await obterAnuncio(pool, idAnuncio)) });
});

anunciosRouter.patch('/:idAnuncio/status', async (req, res) => {
  const idAnuncio = id.parse(req.params.idAnuncio);
  const { status } = statusAnuncioSchema.parse(req.body);
  await obterAnuncioProprio(pool, idAnuncio, meuTime(req));
  await pool.execute('UPDATE anuncios_partidas SET status = ? WHERE id_anuncio = ?', [status, idAnuncio]);
  res.json({ data: mapearAnuncio(await obterAnuncio(pool, idAnuncio)) });
});

// Exclusão lógica: encerra as solicitações pendentes e notifica (procedimento do banco).
anunciosRouter.delete('/:idAnuncio', async (req, res) => {
  const idAnuncio = id.parse(req.params.idAnuncio);
  await obterAnuncioProprio(pool, idAnuncio, meuTime(req));
  await pool.execute('CALL proc_excluir_anuncio(?, ?)', [idAnuncio, req.auth!.idUsuario]);
  res.status(204).end();
});
