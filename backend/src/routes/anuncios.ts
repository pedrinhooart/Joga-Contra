import { Router } from 'express';
import { pool } from '../config/db.js';
import { meuTime, requireAuth } from '../middlewares/auth.js';
import { anuncioComInicioSchema, filtroAnunciosSchema, statusAnuncioSchema } from '../schemas/api.js';
import { sqlHorarioLocal } from '../services/fuso.js';
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
  // Data e horário são os locais da partida (UF do anúncio), como o capitão vê,
  // e não os do aparelho de quem busca.
  const inicioLocal = sqlHorarioLocal('a.data_hora_inicio', 'a.sigla_estado');
  if (f.data) filtrar(`DATE(${inicioLocal}) = ?`, f.data);
  if (f.horario) filtrar(`TIME(${inicioLocal}) >= ?`, `${f.horario}:00`);

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

const valoresAnuncio = (a: ReturnType<typeof anuncioComInicioSchema.parse>) => [
  a.idModalidade, a.idCategoriaEtaria, a.idNivelTecnico, a.idMandoCampo, a.quantidadeJogadores,
  dataSql(a.dataHoraInicio), a.duracaoMinutos, a.cidade, a.siglaEstado, a.bairro, a.nomeLocal, a.endereco,
  a.latitude, a.longitude,
  a.valorAluguelPorTime, a.descricao,
];

// O anúncio sempre pertence ao time do capitão logado.
anunciosRouter.post('/', async (req, res) => {
  const dados = anuncioComInicioSchema.parse(req.body);
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
  const dados = anuncioComInicioSchema.parse(req.body);
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
