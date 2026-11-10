import { ApiError } from '../middlewares/error-handler.js';
import { consultar, dataIso, marcadores, type Executor, type Linha } from './helpers.js';
import { colunasResumoTime, mapearAnuncio, mapearResumoTime, mapearTime } from './mapeadores.js';

/** Mesmas colunas de vis_anuncios_disponiveis, sem o filtro de disponibilidade. */
export const SELECT_ANUNCIO = `
  SELECT a.id_anuncio, a.id_time, t.nome AS nome_time, t.sigla AS sigla_time, t.url_escudo,
         t.cidade AS cidade_time, t.sigla_estado AS sigla_estado_time, u.nome AS nome_capitao,
         a.id_modalidade, m.codigo AS codigo_modalidade, m.nome AS nome_modalidade, m.ordem AS ordem_modalidade,
         a.id_categoria_etaria, c.codigo AS codigo_categoria_etaria, c.nome AS nome_categoria_etaria,
         c.ordem AS ordem_categoria_etaria,
         a.id_nivel_tecnico, n.codigo AS codigo_nivel_tecnico, n.nome AS nome_nivel_tecnico,
         n.ordem AS ordem_nivel_tecnico,
         a.id_mando_campo, mc.codigo AS codigo_mando_campo, mc.nome AS nome_mando_campo,
         mc.ordem AS ordem_mando_campo,
         a.quantidade_jogadores, a.data_hora_inicio, a.duracao_minutos, a.cidade, a.sigla_estado, a.bairro,
         a.nome_local,
         a.endereco, a.latitude, a.longitude, a.valor_aluguel_por_time, a.descricao, a.status,
         (SELECT COUNT(*) FROM solicitacoes_confronto s
           WHERE s.id_anuncio = a.id_anuncio AND s.status = 'pendente') AS total_solicitacoes
    FROM anuncios_partidas a
    JOIN times t ON t.id_time = a.id_time
    JOIN usuarios u ON u.id_usuario = t.id_capitao
    JOIN modalidades m ON m.id_modalidade = a.id_modalidade
    LEFT JOIN categorias_etarias c ON c.id_categoria_etaria = a.id_categoria_etaria
    JOIN niveis_tecnicos n ON n.id_nivel_tecnico = a.id_nivel_tecnico
    LEFT JOIN mandos_campo mc ON mc.id_mando_campo = a.id_mando_campo`;

export async function obterAnuncio(db: Executor, idAnuncio: string) {
  const [linha] = await consultar(db, `${SELECT_ANUNCIO} WHERE a.id_anuncio = ? AND a.data_exclusao IS NULL`, [idAnuncio]);
  if (!linha) throw new ApiError(404, 'Anúncio não encontrado.', 'NOT_FOUND');
  return linha;
}

/** Anúncio que o time logado pode alterar. */
export async function obterAnuncioProprio(db: Executor, idAnuncio: string, idTime: string) {
  const linha = await obterAnuncio(db, idAnuncio);
  if (linha.id_time !== idTime) {
    throw new ApiError(403, 'Somente o capitão do time dono pode alterar este anúncio.', 'FORBIDDEN');
  }
  return linha;
}

/** Perfil do time. `incluirContato` somente para o próprio capitão. */
export async function obterTime(db: Executor, idTime: string, incluirContato: boolean) {
  const [linha] = await consultar(db, 'SELECT * FROM vis_perfis_times WHERE id_time = ?', [idTime]);
  if (!linha) throw new ApiError(404, 'Time não encontrado.', 'NOT_FOUND');
  const modalidades = await consultar(
    db,
    `SELECT m.id_modalidade AS id, m.codigo, m.nome, m.ordem
       FROM times_modalidades tm
       JOIN modalidades m ON m.id_modalidade = tm.id_modalidade
      WHERE tm.id_time = ?
      ORDER BY m.ordem`,
    [idTime],
  );
  return mapearTime(linha, modalidades, incluirContato);
}

const SELECT_SOLICITACAO = `
  SELECT s.id_solicitacao, s.id_anuncio, s.id_time_anunciante, s.id_time_solicitante, s.status,
         s.mensagem_inicial, s.data_criacao, s.data_resposta,
         s.data_confirmacao_anunciante, s.data_confirmacao_solicitante,
         ${colunasResumoTime('anunciante', 'ta', 'ua')},
         ${colunasResumoTime('solicitante', 'ts', 'us')},
         p.id_partida, r.ultima_mensagem, r.data_ultima_mensagem,
         r.nao_lidas_anunciante, r.nao_lidas_solicitante
    FROM solicitacoes_confronto s
    JOIN times ta ON ta.id_time = s.id_time_anunciante
    JOIN usuarios ua ON ua.id_usuario = ta.id_capitao
    JOIN times ts ON ts.id_time = s.id_time_solicitante
    JOIN usuarios us ON us.id_usuario = ts.id_capitao
    JOIN vis_resumo_solicitacoes r ON r.id_solicitacao = s.id_solicitacao
    LEFT JOIN partidas p ON p.id_solicitacao = s.id_solicitacao`;

async function montarSolicitacoes(db: Executor, linhas: Linha[], idMeuTime: string) {
  if (!linhas.length) return [];
  const ids = [...new Set(linhas.map((l) => l.id_anuncio as string))];
  // Inclui anúncios excluídos: o histórico da conversa continua acessível.
  const anuncios = await consultar(db, `${SELECT_ANUNCIO} WHERE a.id_anuncio IN (${marcadores(ids.length)})`, ids);
  const porId = new Map(anuncios.map((a) => [a.id_anuncio, mapearAnuncio(a)]));
  return linhas.map((r) => {
    // Chat só depois do aceite: antes disso, nada da conversa é exposto.
    const chatLiberado = r.status === 'confirmada';
    return {
    idSolicitacao: r.id_solicitacao,
    anuncio: porId.get(r.id_anuncio),
    timeSolicitante: mapearResumoTime(r, 'solicitante'),
    timeAnunciante: mapearResumoTime(r, 'anunciante'),
    status: r.status,
    dataSolicitacao: dataIso(r.data_criacao),
    mensagemInicial: r.mensagem_inicial,
    dataResposta: dataIso(r.data_resposta),
    confirmadoAnunciante: r.data_confirmacao_anunciante != null,
    confirmadoSolicitante: r.data_confirmacao_solicitante != null,
    idPartida: r.id_partida,
    chatLiberado,
    ultimaMensagem: chatLiberado ? r.ultima_mensagem : null,
    dataUltimaMensagem: chatLiberado ? dataIso(r.data_ultima_mensagem) : null,
    mensagensNaoLidas: !chatLiberado
      ? 0
      : r.id_time_anunciante === idMeuTime
        ? r.nao_lidas_anunciante
        : r.nao_lidas_solicitante,
    };
  });
}

/** Solicitações em que `idTime` é anunciante ou solicitante. */
export async function listarSolicitacoes(db: Executor, idTime: string, limite: string) {
  const linhas = await consultar(
    db,
    `${SELECT_SOLICITACAO}
      WHERE s.id_time_anunciante = ? OR s.id_time_solicitante = ?
      ORDER BY COALESCE(r.data_ultima_mensagem, s.data_criacao) DESC
      ${limite}`,
    [idTime, idTime],
  );
  return montarSolicitacoes(db, linhas, idTime);
}

/** Solicitações de um anúncio, para o capitão dono analisar. */
export async function listarSolicitacoesDoAnuncio(db: Executor, idAnuncio: string, idTime: string) {
  const linhas = await consultar(db, `${SELECT_SOLICITACAO} WHERE s.id_anuncio = ? ORDER BY s.data_criacao`, [idAnuncio]);
  return montarSolicitacoes(db, linhas, idTime);
}

/** Autoriza o acesso. Quem não participa recebe 404, sem revelar a existência. */
export async function participacaoNaSolicitacao(db: Executor, idSolicitacao: string, idTime: string) {
  const [linha] = await consultar(
    db,
    `SELECT s.id_solicitacao, s.id_time_anunciante, s.id_time_solicitante, s.status
       FROM solicitacoes_confronto s
      WHERE s.id_solicitacao = ? AND (s.id_time_anunciante = ? OR s.id_time_solicitante = ?)`,
    [idSolicitacao, idTime, idTime],
  );
  if (!linha) throw new ApiError(404, 'Solicitação não encontrada.', 'NOT_FOUND');
  return linha;
}

export async function obterSolicitacao(db: Executor, idSolicitacao: string, idTime: string) {
  const linhas = await consultar(db, `${SELECT_SOLICITACAO} WHERE s.id_solicitacao = ?`, [idSolicitacao]);
  const [solicitacao] = await montarSolicitacoes(db, linhas, idTime);
  if (!solicitacao) throw new ApiError(404, 'Solicitação não encontrada.', 'NOT_FOUND');
  return solicitacao;
}

const SELECT_PARTIDA = `
  SELECT p.*, m.codigo AS codigo_modalidade, m.nome AS nome_modalidade, m.ordem AS ordem_modalidade,
         ${colunasResumoTime('anunciante', 'ta', 'ua')},
         ${colunasResumoTime('adversario', 'tv', 'uv')},
         EXISTS (SELECT 1 FROM avaliacoes av
                  WHERE av.id_partida = p.id_partida AND av.id_time_avaliador = ?) AS avaliada_pelo_meu_time
    FROM partidas p
    JOIN modalidades m ON m.id_modalidade = p.id_modalidade
    JOIN times ta ON ta.id_time = p.id_time_anunciante
    JOIN usuarios ua ON ua.id_usuario = ta.id_capitao
    JOIN times tv ON tv.id_time = p.id_time_adversario
    JOIN usuarios uv ON uv.id_usuario = tv.id_capitao`;

const mapearPartida = (r: Linha) => ({
  idPartida: r.id_partida,
  idAnuncio: r.id_anuncio,
  idSolicitacao: r.id_solicitacao,
  timeAnunciante: mapearResumoTime(r, 'anunciante'),
  timeAdversario: mapearResumoTime(r, 'adversario'),
  modalidade: { id: r.id_modalidade, codigo: r.codigo_modalidade, nome: r.nome_modalidade, ordem: r.ordem_modalidade },
  dataHoraInicio: dataIso(r.data_hora_inicio),
  nomeLocal: r.nome_local,
  endereco: r.endereco,
  cidade: r.cidade,
  siglaEstado: r.sigla_estado,
  status: r.status,
  golsAnunciante: r.gols_anunciante,
  golsAdversario: r.gols_adversario,
  avaliadaPeloMeuTime: Boolean(r.avaliada_pelo_meu_time),
});

const DO_TIME = '(p.id_time_anunciante = ? OR p.id_time_adversario = ?)';

export async function listarPartidas(db: Executor, idTime: string, limite: string) {
  const linhas = await consultar(
    db,
    `${SELECT_PARTIDA} WHERE ${DO_TIME} ORDER BY p.data_hora_inicio DESC ${limite}`,
    [idTime, idTime, idTime],
  );
  return linhas.map(mapearPartida);
}

export async function proximaPartida(db: Executor, idTime: string) {
  const [linha] = await consultar(
    db,
    `${SELECT_PARTIDA}
      WHERE ${DO_TIME} AND p.status = 'confirmada' AND p.data_hora_inicio > UTC_TIMESTAMP(3)
      ORDER BY p.data_hora_inicio
      LIMIT 1`,
    [idTime, idTime, idTime],
  );
  return linha ? mapearPartida(linha) : null;
}

/** Somente os dois times da partida têm acesso. */
export async function obterPartida(db: Executor, idPartida: string, idTime: string) {
  const [linha] = await consultar(
    db,
    `${SELECT_PARTIDA} WHERE p.id_partida = ? AND ${DO_TIME}`,
    [idTime, idPartida, idTime, idTime],
  );
  if (!linha) throw new ApiError(404, 'Partida não encontrada.', 'NOT_FOUND');
  return mapearPartida(linha);
}

/**
 * Chat entre capitães: só os dois times da solicitação e só depois que o time
 * anunciante aceitou (solicitação confirmada). Antes disso, nem leitura.
 */
export async function exigirChatLiberado(db: Executor, idSolicitacao: string, idTime: string) {
  const participacao = await participacaoNaSolicitacao(db, idSolicitacao, idTime);
  if (participacao.status !== 'confirmada') {
    throw new ApiError(403, 'O chat é liberado quando o time anunciante aceita o desafio.', 'CHAT_BLOQUEADO');
  }
  return participacao;
}
