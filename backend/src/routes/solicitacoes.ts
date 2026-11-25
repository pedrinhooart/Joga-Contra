import { z } from 'zod';
import { Router } from 'express';
import { pool } from '../config/db.js';
import { meuTime, requireAuth } from '../middlewares/auth.js';
import { ApiError } from '../middlewares/error-handler.js';
import { mensagemSchema, solicitacaoSchema } from '../schemas/api.js';
import { id, paginacao } from '../schemas/common.js';
import {
  exigirChatLiberado,
  marcarEntregues,
  listarSolicitacoes,
  obterSolicitacao,
  participacaoNaSolicitacao,
} from '../services/consultas.js';
import { consultar, emTransacao, limiteSql, repetirEmImpasse, uuid } from '../services/helpers.js';
import { textoQuando } from '../services/fuso.js';
import { criarNotificacao } from '../services/notificacoes.js';
import { mapearMensagem } from '../services/mapeadores.js';

export const solicitacoesRouter = Router();
solicitacoesRouter.use(requireAuth);

const papelSchema = z.enum(['anunciante', 'solicitante']).optional();

solicitacoesRouter.get('/minhas', async (req, res) => {
  const { pagina, limite } = paginacao.parse(req.query);
  const papel = papelSchema.parse(req.query.papel);
  const idTime = meuTime(req);
  // Listar as conversas no app = mensagens recebidas chegaram ao aparelho.
  await marcarEntregues(pool, idTime);
  res.json({
    data: await listarSolicitacoes(pool, idTime, limiteSql(pagina, limite), papel),
    meta: { pagina, limite },
  });
});

/**
 * Sincronização leve do app (a cada poucos segundos enquanto está aberto):
 * registra a entrega das mensagens recebidas e devolve quantas faltam ler.
 */
solicitacoesRouter.get('/sincronizar', async (req, res) => {
  const idTime = meuTime(req);
  await marcarEntregues(pool, idTime);
  const [linha] = await consultar(
    pool,
    `SELECT COUNT(*) AS total
       FROM mensagens m
       JOIN solicitacoes_confronto s ON s.id_solicitacao = m.id_solicitacao
      WHERE m.data_leitura IS NULL AND m.id_time_remetente <> ? AND s.status = 'confirmada'
        AND (s.id_time_anunciante = ? OR s.id_time_solicitante = ?)`,
    [idTime, idTime, idTime],
  );
  // Muda sempre que uma solicitação ou partida do meu time muda (pedido novo,
  // aceite, encerramento automático, cancelamento): o app recarrega as listas.
  const [versao] = await consultar(
    pool,
    `SELECT CONCAT_WS('|',
              (SELECT CONCAT(COUNT(*), '@', COALESCE(MAX(data_atualizacao), '')) FROM solicitacoes_confronto
                WHERE id_time_solicitante = ?),
              (SELECT CONCAT(COUNT(*), '@', COALESCE(MAX(data_atualizacao), '')) FROM solicitacoes_confronto
                WHERE id_time_anunciante = ?),
              (SELECT CONCAT(COUNT(*), '@', COALESCE(MAX(data_atualizacao), '')) FROM partidas
                WHERE id_time_anunciante = ? OR id_time_adversario = ?)) AS versao`,
    [idTime, idTime, idTime, idTime],
  );
  res.json({ data: { mensagensNaoLidas: Number(linha.total), versao: String(versao.versao) } });
});

solicitacoesRouter.get('/:idSolicitacao', async (req, res) => {
  const idSolicitacao = id.parse(req.params.idSolicitacao);
  const idTime = meuTime(req);
  const participacao = await participacaoNaSolicitacao(pool, idSolicitacao, idTime);
  if (participacao.status === 'confirmada') await marcarEntregues(pool, idTime, idSolicitacao);
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
    `SELECT t.id_capitao, t.nome AS nome_anunciante, solicitante.nome AS nome_solicitante,
            a.data_hora_inicio, a.sigla_estado, COALESCE(NULLIF(TRIM(a.nome_local), ''), a.cidade) AS local_jogo
       FROM anuncios_partidas a
       JOIN times t ON t.id_time = a.id_time
       JOIN times solicitante ON solicitante.id_time = ?
      WHERE a.id_anuncio = ? AND a.data_exclusao IS NULL`,
    [idTime, idAnuncio],
  );
  if (!anuncio) throw new ApiError(404, 'Anúncio não encontrado.', 'NOT_FOUND');

  const idSolicitacao = uuid();
  const jogo = `${textoQuando(anuncio.data_hora_inicio, anuncio.sigla_estado)}, em ${anuncio.local_jogo}`;
  // Pedido e avisos na mesma transação: se o pedido for recusado pelo banco
  // (anúncio indisponível, time incompleto...), nenhum aviso fica gravado.
  await emTransacao(async (db) => {
    await db.execute(
      `INSERT INTO solicitacoes_confronto (id_solicitacao, id_anuncio, id_time_solicitante, mensagem_inicial)
       VALUES (?, ?, ?, ?)`,
      [idSolicitacao, idAnuncio, idTime, mensagemInicial],
    );
    await criarNotificacao(db, {
      idDestinatario: anuncio.id_capitao,
      tipo: 'solicitacao_recebida',
      titulo: 'Novo desafio recebido',
      mensagem: `O time ${anuncio.nome_solicitante} demonstrou interesse no seu jogo de ${jogo}.`,
      idSolicitacao,
      chaveEvento: `solicitacao_recebida:${idSolicitacao}`,
    });
    // Para quem enviou: registro no histórico, já lido — o app já confirma o
    // envio na hora, então não conta como novidade no sino.
    await criarNotificacao(db, {
      idDestinatario: req.auth!.idUsuario,
      tipo: 'solicitacao_enviada',
      titulo: 'Desafio enviado',
      mensagem: `Sua solicitação foi enviada para o time ${anuncio.nome_anunciante} (jogo de ${jogo}). Avisaremos quando houver resposta.`,
      idSolicitacao,
      chaveEvento: `solicitacao_enviada:${idSolicitacao}`,
      lida: true,
    });
  });
  res.status(201).json({ data: await obterSolicitacao(pool, idSolicitacao, idTime) });
});

/**
 * Aceite do desafio: só o capitão do time anunciante. O pedido do desafiante já
 * é a concordância dele; o aceite registra os dois lados e o procedimento cria a
 * partida, encerra o anúncio e as demais solicitações, notifica os capitães e
 * libera o chat — tudo numa transação com bloqueio do time desafiante e do
 * anúncio. Na mesma transação, as outras solicitações pendentes do desafiante
 * para jogos na mesma data e hora local são encerradas (02_rotinas.sql).
 * Procedimentos abrem a própria transação: são chamados fora de `emTransacao`.
 */
solicitacoesRouter.patch('/:idSolicitacao/confirmar', async (req, res) => {
  const idSolicitacao = id.parse(req.params.idSolicitacao);
  const idTime = meuTime(req);
  const participacao = await participacaoNaSolicitacao(pool, idSolicitacao, idTime);
  if (participacao.id_time_anunciante !== idTime) {
    throw new ApiError(403, 'Somente o capitão do time anunciante aceita o desafio.', 'FORBIDDEN');
  }
  // Impasse (deadlock) entre aceites simultâneos: o MySQL desfaz a transação
  // inteira, então repetir é seguro. Regras de negócio não são repetidas.
  await repetirEmImpasse(async () => {
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
  });
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

/**
 * Presença no chat: a conversa conta como aberta se o app consultou as
 * mensagens há menos de 12 s (consulta a cada 4 s) e não avisou que saiu.
 * Limitação: se o app for encerrado à força, por até 12 s as mensagens novas
 * dessa conversa ainda não geram push (a notificação interna fica registrada
 * e a mensagem continua não lida na lista de conversas).
 */
const PRESENCA_S = 12;

// Abrir a conversa marca como lidas as mensagens do outro time.
solicitacoesRouter.get('/:idSolicitacao/mensagens', async (req, res) => {
  const idSolicitacao = id.parse(req.params.idSolicitacao);
  const idTime = meuTime(req);
  await exigirChatLiberado(pool, idSolicitacao, idTime);
  await pool.execute(
    // Abrir a conversa = visualizar (e, se ainda não constava, receber) as mensagens do outro.
    `UPDATE mensagens
        SET data_leitura = UTC_TIMESTAMP(3), data_entrega = COALESCE(data_entrega, UTC_TIMESTAMP(3))
      WHERE id_solicitacao = ? AND id_time_remetente <> ? AND data_leitura IS NULL`,
    [idSolicitacao, idTime],
  );
  // A pessoa está com esta conversa na tela.
  await pool.execute(
    `INSERT INTO conversas_abertas (id_usuario, id_solicitacao, aberta, data_ultimo_acesso)
     VALUES (?, ?, 1, UTC_TIMESTAMP(3))
     ON DUPLICATE KEY UPDATE aberta = 1, data_ultimo_acesso = UTC_TIMESTAMP(3)`,
    [req.auth!.idUsuario, idSolicitacao],
  );
  // Os avisos de mensagem desta conversa ficam lidos: a pessoa já viu as
  // mensagens. (O contrário não vale: ler a notificação não marca mensagem.)
  await pool.execute(
    `UPDATE notificacoes SET data_leitura = UTC_TIMESTAMP(3)
      WHERE id_usuario_destinatario = ? AND id_solicitacao = ? AND tipo = 'mensagem_recebida'
        AND data_leitura IS NULL`,
    [req.auth!.idUsuario, idSolicitacao],
  );
  const linhas = await consultar(
    pool,
    'SELECT * FROM mensagens WHERE id_solicitacao = ? ORDER BY data_envio, id_mensagem',
    [idSolicitacao],
  );
  res.json({ data: linhas.map(mapearMensagem) });
});

// O app avisa quando a conversa sai da tela (outra tela ou segundo plano):
// a partir daí as mensagens novas voltam a gerar push.
solicitacoesRouter.patch('/:idSolicitacao/presenca', async (req, res) => {
  const idSolicitacao = id.parse(req.params.idSolicitacao);
  const { aberta } = z.object({ aberta: z.boolean() }).parse(req.body);
  await participacaoNaSolicitacao(pool, idSolicitacao, meuTime(req));
  await pool.execute(
    `INSERT INTO conversas_abertas (id_usuario, id_solicitacao, aberta, data_ultimo_acesso)
     VALUES (?, ?, ?, UTC_TIMESTAMP(3))
     ON DUPLICATE KEY UPDATE aberta = VALUES(aberta), data_ultimo_acesso = UTC_TIMESTAMP(3)`,
    [req.auth!.idUsuario, idSolicitacao, aberta ? 1 : 0],
  );
  res.status(204).end();
});

/**
 * Envio. `idMensagem` (opcional, gerado pelo app) torna o envio idempotente:
 * repetir a mesma requisição (falha de conexão) devolve a mensagem já gravada,
 * sem mensagem nem notificação duplicadas.
 */
solicitacoesRouter.post('/:idSolicitacao/mensagens', async (req, res) => {
  const idSolicitacao = id.parse(req.params.idSolicitacao);
  const { texto, idMensagem: idDoApp } = mensagemSchema.parse(req.body);
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

  const idMensagem = idDoApp ?? uuid();
  /** A mesma mensagem já gravada (repetição) devolve 200; id de outra mensagem, 409. */
  const jaGravada = async () => {
    const [existente] = await consultar(pool, 'SELECT * FROM mensagens WHERE id_mensagem = ?', [idMensagem]);
    if (!existente) return null;
    if (existente.id_solicitacao !== idSolicitacao || existente.id_time_remetente !== idTime) {
      throw new ApiError(409, 'Identificador de mensagem já usado.', 'CONFLICT');
    }
    return existente;
  };
  const repetida = idDoApp ? await jaGravada() : null;
  if (repetida) {
    res.json({ data: mapearMensagem(repetida) });
    return;
  }

  try {
    await emTransacao(async (db) => {
      await db.execute(
        `INSERT INTO mensagens (id_mensagem, id_solicitacao, id_time_remetente, id_usuario_remetente, texto)
         VALUES (?, ?, ?, ?, ?)`,
        [idMensagem, idSolicitacao, idTime, req.auth!.idUsuario, texto],
      );
      // Destinatário com esta conversa aberta: aviso já lido (histórico, sem
      // push). Fora dela (outra tela, segundo plano, app fechado): não lido e
      // com push. O texto nunca vai na notificação (privacidade).
      const [presenca] = await consultar(
        db,
        `SELECT 1 AS aberta FROM conversas_abertas
          WHERE id_usuario = ? AND id_solicitacao = ? AND aberta = 1
            AND data_ultimo_acesso > UTC_TIMESTAMP(3) - INTERVAL ${PRESENCA_S} SECOND`,
        [dados.id_capitao, idSolicitacao],
      );
      await criarNotificacao(db, {
        idDestinatario: dados.id_capitao,
        tipo: 'mensagem_recebida',
        titulo: 'Nova mensagem',
        mensagem: `Você recebeu uma nova mensagem do time ${dados.nome_remetente}.`,
        idSolicitacao,
        chaveEvento: `mensagem_recebida:${idMensagem}`,
        lida: !!presenca,
      });
    });
  } catch (erro: any) {
    // Duas repetições simultâneas: a segunda encontra a primeira já gravada.
    const mesma = erro?.code === 'ER_DUP_ENTRY' && idDoApp ? await jaGravada() : null;
    if (!mesma) throw erro;
    res.json({ data: mapearMensagem(mesma) });
    return;
  }
  const [mensagem] = await consultar(pool, 'SELECT * FROM mensagens WHERE id_mensagem = ?', [idMensagem]);
  res.status(201).json({ data: mapearMensagem(mensagem) });
});
