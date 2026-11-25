import { randomBytes, randomUUID } from 'node:crypto';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

/**
 * Notificações do chat (fase 4): API + MySQL + fila de push com um provedor de
 * teste. Contas e conversas fictícias (teste.homologacao.*@example.com), que
 * permanecem no banco. Mesmas travas de tests/integracao.test.ts.
 */
const ativo = process.env.TESTE_INTEGRACAO === '1';
if (ativo && (process.env.DB_PORT ?? '3306') === '3306' && process.env.TESTE_BANCO_REAL_AUTORIZADO !== '1') {
  throw new Error('Testes de integração bloqueados no servidor padrão: defina TESTE_BANCO_REAL_AUTORIZADO=1 para rodar nele.');
}

type Conta = { token: string; idUsuario: string; nomeTime: string };

class ProvedorDeTeste {
  readonly nome = 'teste';
  envios: { tokens: string[]; mensagem: any }[] = [];
  async enviar(tokens: string[], mensagem: any) {
    this.envios.push({ tokens, mensagem });
    return tokens.map((token) => ({ token, ok: true }));
  }
}

describe.runIf(ativo)('notificações do chat', () => {
  let app: any;
  let pool: any;
  let processar: (o?: any) => Promise<Record<string, number>>;
  let definirEnviador: (e: any) => void;
  const contas: string[] = [];

  async function novaConta(nomeTime: string): Promise<Conta> {
    const r = await request(app).post('/api/auth/cadastro').send({
      usuario: { nome: `Capitão ${nomeTime}`, email: `teste.homologacao.${randomUUID()}@example.com`, senha: 'senha-de-teste-123', cidade: 'São Paulo', siglaEstado: 'SP' },
      time: { nome: nomeTime, idsModalidades: [1], idCategoriaEtaria: 4, cidade: 'São Paulo', siglaEstado: 'SP' },
    });
    expect(r.status).toBe(201);
    contas.push(r.body.data.usuario.idUsuario);
    return { token: r.body.data.token, idUsuario: r.body.data.usuario.idUsuario, nomeTime };
  }

  const api = (c: Conta) => ({
    get: (p: string) => request(app).get(`/api${p}`).set('Authorization', `Bearer ${c.token}`),
    post: (p: string) => request(app).post(`/api${p}`).set('Authorization', `Bearer ${c.token}`),
    put: (p: string) => request(app).put(`/api${p}`).set('Authorization', `Bearer ${c.token}`),
    patch: (p: string) => request(app).patch(`/api${p}`).set('Authorization', `Bearer ${c.token}`),
  });

  /** Dono e JOGA com o desafio aceito (chat liberado), e a solicitação. */
  async function conversa(confirmar = true) {
    const m = randomUUID().slice(0, 5);
    const dono = await novaConta(`União ${m}`);
    const joga = await novaConta(`JOGA ${m}`);
    const anuncio = await api(dono).post('/anuncios').send({
      idModalidade: 1, idCategoriaEtaria: 4, idNivelTecnico: 2, idMandoCampo: 1, quantidadeJogadores: 7,
      dataHoraInicio: new Date(Date.now() + 9 * 86_400_000).toISOString(), duracaoMinutos: 90,
      cidade: 'São Paulo', siglaEstado: 'SP', bairro: 'Centro', nomeLocal: 'Arena Chat',
    });
    const pedido = await api(joga).post('/solicitacoes').send({ idAnuncio: anuncio.body.data.idAnuncio });
    const idSolicitacao = pedido.body.data.idSolicitacao as string;
    if (confirmar) await api(dono).patch(`/solicitacoes/${idSolicitacao}/confirmar`).expect(200);
    return { dono, joga, idSolicitacao };
  }

  const enviar = (c: Conta, idSolicitacao: string, texto: string, idMensagem?: string) =>
    api(c).post(`/solicitacoes/${idSolicitacao}/mensagens`).send({ texto, ...(idMensagem ? { idMensagem } : {}) });

  /** Avisos de mensagem da conta (MySQL), com o estado na fila de push. */
  async function avisosDeMensagem(c: Conta, idSolicitacao: string) {
    const [linhas] = await pool.query(
      `SELECT n.titulo, n.mensagem, n.chave_evento, n.data_leitura IS NOT NULL AS lida, e.status AS push
         FROM notificacoes n LEFT JOIN envios_push e USING (id_notificacao)
        WHERE n.id_usuario_destinatario = ? AND n.id_solicitacao = ? AND n.tipo = 'mensagem_recebida'
        ORDER BY n.data_criacao, n.id_notificacao`,
      [c.idUsuario, idSolicitacao],
    );
    return linhas;
  }

  const naoLidasNaConversa = async (c: Conta, idSolicitacao: string) =>
    (await api(c).get('/solicitacoes/minhas')).body.data.find((s: any) => s.idSolicitacao === idSolicitacao)
      .mensagensNaoLidas;

  beforeAll(async () => {
    app = (await import('../src/app.js')).createApp();
    ({ pool } = await import('../src/config/db.js'));
    ({ processarFilaPush: processar, definirEnviadorPush: definirEnviador } = await import('../src/services/push.js'));
  });

  afterAll(async () => {
    definirEnviador?.(undefined);
    await pool?.end();
  });

  it('mensagem recebida: "Nova mensagem" sem o texto, ao destinatário (não ao remetente)', async () => {
    const { dono, joga, idSolicitacao } = await conversa();
    const r = await enviar(joga, idSolicitacao, 'Segredo: levem a camisa azul');
    expect(r.status).toBe(201);
    const idMensagem = r.body.data.idMensagem;

    expect(await avisosDeMensagem(dono, idSolicitacao)).toEqual([
      {
        titulo: 'Nova mensagem',
        mensagem: `Você recebeu uma nova mensagem do time ${joga.nomeTime}.`,
        chave_evento: `mensagem_recebida:${idMensagem}`,
        lida: 0,
        push: 'pendente',
      },
    ]);
    expect(await avisosDeMensagem(joga, idSolicitacao)).toEqual([]);
    const [[n]] = await pool.query("SELECT mensagem FROM notificacoes WHERE chave_evento = ?", [`mensagem_recebida:${idMensagem}`]);
    expect(n.mensagem).not.toContain('camisa azul');
    // Mensagem persistida com o estado "enviada".
    const [[msg]] = await pool.query('SELECT texto, data_entrega, data_leitura FROM mensagens WHERE id_mensagem = ?', [idMensagem]);
    expect(msg).toEqual({ texto: 'Segredo: levem a camisa azul', data_entrega: null, data_leitura: null });
  });

  it('mensagens consecutivas: um aviso por mensagem; contador de não lidas', async () => {
    const { dono, joga, idSolicitacao } = await conversa();
    for (const texto of ['Oi', 'Tudo certo?', 'Confirma o horário']) await enviar(joga, idSolicitacao, texto).expect(201);
    expect(await avisosDeMensagem(dono, idSolicitacao)).toHaveLength(3);
    expect(await naoLidasNaConversa(dono, idSolicitacao)).toBe(3);
    expect((await api(dono).get('/notificacoes/nao-lidas')).body.data.naoLidas).toBeGreaterThanOrEqual(3);
  });

  it('repetir o envio (falha de conexão) não duplica mensagem nem aviso', async () => {
    const { dono, joga, idSolicitacao } = await conversa();
    const idMensagem = randomUUID();
    const primeira = await enviar(joga, idSolicitacao, 'Chegamos às 20h', idMensagem);
    expect(primeira.status).toBe(201);
    const [r2, r3] = await Promise.all([
      enviar(joga, idSolicitacao, 'Chegamos às 20h', idMensagem),
      enviar(joga, idSolicitacao, 'Chegamos às 20h', idMensagem),
    ]);
    expect([r2.status, r3.status]).toEqual([200, 200]);
    expect(r2.body.data.idMensagem).toBe(idMensagem);
    const [[{ n }]] = await pool.query('SELECT COUNT(*) AS n FROM mensagens WHERE id_mensagem = ?', [idMensagem]);
    expect(n).toBe(1);
    expect(await avisosDeMensagem(dono, idSolicitacao)).toHaveLength(1);
    // O mesmo id em outra conversa (ou de outro time) é recusado.
    const outra = await conversa();
    expect((await enviar(outra.joga, outra.idSolicitacao, 'x', idMensagem)).status).toBe(409);
    expect((await enviar(dono, idSolicitacao, 'x', idMensagem)).status).toBe(409);
  });

  it('conversa aberta: aviso já lido e sem push; fora dela, push normal', async () => {
    const { dono, joga, idSolicitacao } = await conversa();
    // O dono abre a conversa (o app consulta as mensagens a cada 4 s).
    await api(dono).get(`/solicitacoes/${idSolicitacao}/mensagens`).expect(200);
    await enviar(joga, idSolicitacao, 'Você está aí?').expect(201);
    // Saiu da conversa (outra tela ou segundo plano).
    await api(dono).patch(`/solicitacoes/${idSolicitacao}/presenca`).send({ aberta: false }).expect(204);
    await enviar(joga, idSolicitacao, 'Responde quando puder').expect(201);
    // Abriu de novo, mas o app parou de consultar (fechado à força): depois de 12 s volta o push.
    await api(dono).get(`/solicitacoes/${idSolicitacao}/mensagens`).expect(200);
    await pool.query(
      'UPDATE conversas_abertas SET data_ultimo_acesso = UTC_TIMESTAMP(3) - INTERVAL 13 SECOND WHERE id_usuario = ? AND id_solicitacao = ?',
      [dono.idUsuario, idSolicitacao],
    );
    await enviar(joga, idSolicitacao, 'Alô?').expect(201);

    const avisos = await avisosDeMensagem(dono, idSolicitacao);
    expect(avisos.map((a: any) => [a.lida, a.push])).toEqual([
      [1, null], // conversa aberta: histórico, sem push
      [1, 'pendente'], // fora da conversa: push (e lido depois, quando ele abriu de novo)
      [0, 'pendente'], // presença vencida: push
    ]);
  });

  it('abrir a conversa marca mensagens e avisos dela como lidos; o contrário não', async () => {
    const { dono, joga, idSolicitacao } = await conversa();
    const r1 = await enviar(joga, idSolicitacao, 'Primeira');
    await enviar(joga, idSolicitacao, 'Segunda');
    // Ler a notificação não lê a mensagem.
    const [[aviso]] = await pool.query(
      "SELECT id_notificacao FROM notificacoes WHERE chave_evento = ?",
      [`mensagem_recebida:${r1.body.data.idMensagem}`],
    );
    await api(dono).patch(`/notificacoes/${aviso.id_notificacao}/lida`).expect(204);
    expect(await naoLidasNaConversa(dono, idSolicitacao)).toBe(2);
    const [[m1]] = await pool.query('SELECT data_leitura FROM mensagens WHERE id_mensagem = ?', [r1.body.data.idMensagem]);
    expect(m1.data_leitura).toBeNull();

    // Abrir a conversa: mensagens visualizadas e avisos dela lidos — sem apagar nada.
    await api(dono).get(`/solicitacoes/${idSolicitacao}/mensagens`).expect(200);
    expect(await naoLidasNaConversa(dono, idSolicitacao)).toBe(0);
    const avisos = await avisosDeMensagem(dono, idSolicitacao);
    expect(avisos).toHaveLength(2);
    expect(avisos.every((a: any) => a.lida === 1)).toBe(true);
    const doJoga = (await api(joga).get(`/solicitacoes/${idSolicitacao}/mensagens`)).body.data;
    expect(doJoga.map((m: any) => m.status)).toEqual(['visualizada', 'visualizada']);
    // Avisos de outros tipos da mesma solicitação não mudam.
    const [[aceito]] = await pool.query(
      "SELECT data_leitura FROM notificacoes WHERE id_usuario_destinatario = ? AND id_solicitacao = ? AND tipo = 'solicitacao_recebida'",
      [dono.idUsuario, idSolicitacao],
    );
    expect(aceito.data_leitura).toBeNull();
  });

  it('push: dois aparelhos, texto genérico e referência à conversa', async () => {
    const provedor = new ProvedorDeTeste();
    definirEnviador(provedor);
    const { dono, joga, idSolicitacao } = await conversa();
    const token = () => `teste-${randomBytes(20).toString('base64url')}`;
    const [celular, tablet] = [token(), token()];
    for (const t of [celular, tablet]) {
      await api(dono).put('/dispositivos').send({ token: t, plataforma: 'android', permitido: true }).expect(200);
    }
    await enviar(joga, idSolicitacao, 'Conteúdo privado da conversa').expect(201);
    await processar({ apenasUsuarios: contas });
    const doChat = provedor.envios.filter((e) => e.mensagem.dados.tipo === 'mensagem_recebida');
    expect(doChat).toHaveLength(1);
    expect(doChat[0].tokens.sort()).toEqual([celular, tablet].sort());
    expect(doChat[0].mensagem).toEqual({
      titulo: 'Nova mensagem',
      corpo: `Você recebeu uma nova mensagem do time ${joga.nomeTime}.`,
      dados: expect.objectContaining({ tipo: 'mensagem_recebida', referenciaTipo: 'solicitacao', referenciaId: idSolicitacao }),
    });
    expect(JSON.stringify(doChat[0].mensagem)).not.toContain('privado');
  });

  it('sem acesso: estranho não lê, não envia, não marca presença; chat ainda fechado não gera aviso', async () => {
    const { dono, joga, idSolicitacao } = await conversa(false); // pedido ainda não aceito
    const estranho = await novaConta('Estranho');
    for (const c of [dono, joga]) {
      expect((await api(c).get(`/solicitacoes/${idSolicitacao}/mensagens`)).status).toBe(403);
      expect((await enviar(c, idSolicitacao, 'antes do aceite')).status).toBe(403);
    }
    expect((await api(estranho).get(`/solicitacoes/${idSolicitacao}/mensagens`)).status).toBe(404);
    expect((await enviar(estranho, idSolicitacao, 'intruso')).status).toBe(404);
    expect((await api(estranho).patch(`/solicitacoes/${idSolicitacao}/presenca`).send({ aberta: true })).status).toBe(404);
    const [[{ n }]] = await pool.query(
      "SELECT COUNT(*) AS n FROM notificacoes WHERE id_solicitacao = ? AND tipo = 'mensagem_recebida'",
      [idSolicitacao],
    );
    expect(n).toBe(0);
    const [[{ p }]] = await pool.query('SELECT COUNT(*) AS p FROM conversas_abertas WHERE id_solicitacao = ?', [idSolicitacao]);
    expect(p).toBe(0);
  });

  it('jogo cancelado: a conversa segue entre os dois capitães (regra existente) e avisa', async () => {
    const { dono, joga, idSolicitacao } = await conversa();
    const [[{ id_partida }]] = await pool.query('SELECT id_partida FROM partidas WHERE id_solicitacao = ?', [idSolicitacao]);
    await api(joga).patch(`/partidas/${id_partida}/cancelar`).send({}).expect(200);
    await enviar(joga, idSolicitacao, 'Remarcamos?').expect(201);
    expect(await avisosDeMensagem(dono, idSolicitacao)).toHaveLength(1);
  });
});
