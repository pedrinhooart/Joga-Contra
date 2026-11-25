import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

/**
 * Central de notificações: API + MySQL. Grava contas e notificações fictícias
 * (teste.homologacao.*@example.com), que permanecem no banco. Mesmas travas de
 * tests/integracao.test.ts.
 */
const ativo = process.env.TESTE_INTEGRACAO === '1';
if (ativo && (process.env.DB_PORT ?? '3306') === '3306' && process.env.TESTE_BANCO_REAL_AUTORIZADO !== '1') {
  throw new Error('Testes de integração bloqueados no servidor padrão: defina TESTE_BANCO_REAL_AUTORIZADO=1 para rodar nele.');
}

describe.runIf(ativo)('central de notificações (API + MySQL)', () => {
  let app: any;
  let pool: any;
  let criar: (db: any, n: any) => Promise<{ idNotificacao: string; criada: boolean }>;
  type Conta = { token: string; idUsuario: string; idTime: string };

  async function novaConta(): Promise<Conta> {
    const r = await request(app).post('/api/auth/cadastro').send({
      usuario: { nome: 'Capitão Notificações', email: `teste.homologacao.${randomUUID()}@example.com`, senha: 'senha-de-teste-123', cidade: 'São Paulo', siglaEstado: 'SP' },
      time: { nome: `Avisos ${randomUUID().slice(0, 6)}`, idsModalidades: [1], idCategoriaEtaria: 4, cidade: 'São Paulo', siglaEstado: 'SP' },
    });
    expect(r.status).toBe(201);
    return { token: r.body.data.token, idUsuario: r.body.data.usuario.idUsuario, idTime: r.body.data.time.idTime };
  }

  const api = (c: Conta) => ({
    get: (p: string) => request(app).get(`/api/notificacoes${p}`).set('Authorization', `Bearer ${c.token}`),
    patch: (p: string) => request(app).patch(`/api/notificacoes${p}`).set('Authorization', `Bearer ${c.token}`),
  });

  const aviso = (c: Conta, titulo: string, chaveEvento?: string) =>
    criar(pool, { idDestinatario: c.idUsuario, tipo: 'aviso', titulo, mensagem: `Mensagem de ${titulo}`, chaveEvento });

  const naoLidas = async (c: Conta) => (await api(c).get('/nao-lidas')).body.data.naoLidas as number;

  beforeAll(async () => {
    app = (await import('../src/app.js')).createApp();
    ({ pool } = await import('../src/config/db.js'));
    ({ criarNotificacao: criar } = await import('../src/services/notificacoes.js'));
  });

  afterAll(async () => {
    await pool?.end();
  });

  it('cria, grava no MySQL e lista a notificação como não lida', async () => {
    const a = await novaConta();
    const { idNotificacao, criada } = await aviso(a, 'Bem-vindo à central');
    expect(criada).toBe(true);

    const [[linha]] = await pool.query('SELECT * FROM notificacoes WHERE id_notificacao = ?', [idNotificacao]);
    expect(linha).toMatchObject({
      id_usuario_destinatario: a.idUsuario,
      tipo: 'aviso',
      titulo: 'Bem-vindo à central',
      data_leitura: null,
    });
    expect(linha.data_criacao).toBeInstanceOf(Date);

    const r = await api(a).get('');
    expect(r.status).toBe(200);
    expect(r.body.data).toHaveLength(1);
    expect(r.body.data[0]).toMatchObject({ idNotificacao, tipo: 'aviso', lida: false, dataLeitura: null });
    expect(r.body.meta).toMatchObject({ pagina: 1, total: 1, naoLidas: 1, temMais: false });
  });

  it('mesmo evento não gera duas notificações, mesmo com tentativas simultâneas', async () => {
    const a = await novaConta();
    const b = await novaConta();
    const chave = `teste:evento:${randomUUID()}`;
    const resultados = await Promise.all(Array.from({ length: 6 }, () => aviso(a, 'Evento único', chave)));
    expect(new Set(resultados.map((r) => r.idNotificacao)).size).toBe(1);
    expect(resultados.filter((r) => r.criada)).toHaveLength(1);
    // A mesma chave para outro destinatário é outro aviso; e repetir depois da leitura também não duplica.
    expect((await aviso(b, 'Evento único', chave)).criada).toBe(true);
    await api(a).patch('/lidas');
    expect((await aviso(a, 'Evento único', chave)).criada).toBe(false);
    const [[{ total }]] = await pool.query('SELECT COUNT(*) AS total FROM notificacoes WHERE chave_evento = ?', [chave]);
    expect(total).toBe(2);
    // Sem chave, cada chamada é uma notificação.
    await aviso(a, 'Sem chave');
    await aviso(a, 'Sem chave');
    expect((await api(a).get('')).body.meta.total).toBe(3);
  });

  it('paginação: mais recentes primeiro, sem repetir nem pular', async () => {
    const a = await novaConta();
    for (let i = 1; i <= 7; i++) await aviso(a, `Aviso ${i}`);
    const paginas = [];
    for (let p = 1; p <= 3; p++) paginas.push((await api(a).get(`?pagina=${p}&limite=3`)).body);
    expect(paginas.map((p) => p.data.length)).toEqual([3, 3, 1]);
    expect(paginas.map((p) => p.meta.temMais)).toEqual([true, true, false]);
    expect(paginas[0].meta).toMatchObject({ total: 7, naoLidas: 7, limite: 3 });
    const titulos = paginas.flatMap((p) => p.data.map((n: any) => n.titulo));
    expect(titulos).toEqual(['Aviso 7', 'Aviso 6', 'Aviso 5', 'Aviso 4', 'Aviso 3', 'Aviso 2', 'Aviso 1']);
    expect((await api(a).get('?pagina=4&limite=3')).body.data).toEqual([]);
  });

  it('marca uma e todas como lidas; repetir não dá erro', async () => {
    const a = await novaConta();
    const ids = [];
    for (let i = 1; i <= 4; i++) ids.push((await aviso(a, `Leitura ${i}`)).idNotificacao);
    expect(await naoLidas(a)).toBe(4);

    expect((await api(a).patch(`/${ids[0]}/lida`)).status).toBe(204);
    expect((await api(a).patch(`/${ids[0]}/lida`)).status).toBe(204); // de novo: sem erro
    expect(await naoLidas(a)).toBe(3);
    const [[{ data_leitura: primeira }]] = await pool.query('SELECT data_leitura FROM notificacoes WHERE id_notificacao = ?', [ids[0]]);
    expect(primeira).toBeInstanceOf(Date);

    const todas = await api(a).patch('/lidas');
    expect(todas.status).toBe(200);
    expect(todas.body.data).toEqual({ marcadas: 3, naoLidas: 0 });
    expect((await api(a).patch('/lidas')).body.data).toEqual({ marcadas: 0, naoLidas: 0 });
    expect(await naoLidas(a)).toBe(0);
    const lista = (await api(a).get('')).body.data;
    expect(lista.every((n: any) => n.lida && n.dataLeitura)).toBe(true);
    // A leitura da primeira não foi reescrita pelo "marcar todas".
    const [[{ data_leitura: depois }]] = await pool.query('SELECT data_leitura FROM notificacoes WHERE id_notificacao = ?', [ids[0]]);
    expect(depois.getTime()).toBe(primeira.getTime());
  });

  it('isolamento: ninguém vê nem marca notificações de outra conta', async () => {
    const a = await novaConta();
    const b = await novaConta();
    const { idNotificacao } = await aviso(a, 'Só do A');
    await aviso(b, 'Só do B');

    const listaB = (await api(b).get('')).body;
    expect(listaB.data.map((n: any) => n.titulo)).toEqual(['Só do B']);
    expect(listaB.meta.total).toBe(1);
    // B tenta marcar a do A: 404 (como inexistente), e a do A continua não lida.
    expect((await api(b).patch(`/${idNotificacao}/lida`)).status).toBe(404);
    expect((await api(b).patch('/lidas')).body.data.marcadas).toBe(1);
    expect(await naoLidas(a)).toBe(1);
    // Parâmetros extras não mudam o dono.
    expect((await api(b).get(`?idUsuario=${a.idUsuario}`)).body.data.map((n: any) => n.titulo)).toEqual(['Só do B']);
  });

  it('valida parâmetros e exige autenticação', async () => {
    const a = await novaConta();
    for (const q of ['?pagina=0', '?limite=0', '?limite=101', '?pagina=abc', '?limite=-1']) {
      expect((await api(a).get(q)).status, q).toBe(400);
    }
    expect((await api(a).patch('/nao-e-uuid/lida')).status).toBe(400);
    expect((await api(a).patch(`/${randomUUID()}/lida`)).status).toBe(404);
    for (const [metodo, caminho] of [
      ['get', '/api/notificacoes'],
      ['get', '/api/notificacoes/nao-lidas'],
      ['patch', '/api/notificacoes/lidas'],
      ['patch', `/api/notificacoes/${randomUUID()}/lida`],
    ] as const) {
      expect((await (request(app) as any)[metodo](caminho)).status, caminho).toBe(401);
    }
  });

  it('histórico preservado: o banco só deixa registrar a leitura, uma vez', async () => {
    const a = await novaConta();
    const { idNotificacao } = await aviso(a, 'Imutável', `teste:imutavel:${randomUUID()}`);
    for (const sql of [
      "UPDATE notificacoes SET titulo = 'outro' WHERE id_notificacao = ?",
      "UPDATE notificacoes SET chave_evento = 'outra' WHERE id_notificacao = ?",
    ]) {
      await expect(pool.query(sql, [idNotificacao])).rejects.toMatchObject({ code: 'ER_SIGNAL_EXCEPTION' });
    }
    await api(a).patch(`/${idNotificacao}/lida`);
    await expect(
      pool.query('UPDATE notificacoes SET data_leitura = NULL WHERE id_notificacao = ?', [idNotificacao]),
    ).rejects.toMatchObject({ code: 'ER_SIGNAL_EXCEPTION' });
  });

  it('eventos reais da API gravam a chave do evento', async () => {
    const dono = await novaConta();
    const visitante = await novaConta();
    const anuncio = await request(app)
      .post('/api/anuncios')
      .set('Authorization', `Bearer ${dono.token}`)
      .send({
        idModalidade: 1, idCategoriaEtaria: 4, idNivelTecnico: 2, idMandoCampo: 1, quantidadeJogadores: 7,
        dataHoraInicio: new Date(Date.now() + 9 * 86_400_000).toISOString(), duracaoMinutos: 90,
        cidade: 'São Paulo', siglaEstado: 'SP', bairro: 'Centro', nomeLocal: 'Campo de Teste',
      });
    expect(anuncio.status).toBe(201);
    const pedido = await request(app)
      .post('/api/solicitacoes')
      .set('Authorization', `Bearer ${visitante.token}`)
      .send({ idAnuncio: anuncio.body.data.idAnuncio });
    expect(pedido.status).toBe(201);
    const idSolicitacao = pedido.body.data.idSolicitacao;
    const [linhas] = await pool.query(
      'SELECT tipo, chave_evento, id_solicitacao FROM notificacoes WHERE id_usuario_destinatario = ?',
      [dono.idUsuario],
    );
    expect(linhas).toEqual([
      { tipo: 'solicitacao_recebida', chave_evento: `solicitacao_recebida:${idSolicitacao}`, id_solicitacao: idSolicitacao },
    ]);
    const lista = (await api(dono).get('')).body;
    expect(lista.data[0]).toMatchObject({ tipo: 'solicitacao_recebida', idSolicitacao, lida: false });
    expect(lista.meta.naoLidas).toBe(1);
  });
});
