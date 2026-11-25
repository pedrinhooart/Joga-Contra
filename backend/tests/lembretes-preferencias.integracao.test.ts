import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

/**
 * Lembretes de jogo e preferências (fase 5): API + MySQL, com relógio injetado
 * (nada de esperar 24 h) e só partidas criadas pelo teste. Contas fictícias
 * (teste.homologacao.*@example.com), que permanecem no banco.
 */
const ativo = process.env.TESTE_INTEGRACAO === '1';
if (ativo && (process.env.DB_PORT ?? '3306') === '3306' && process.env.TESTE_BANCO_REAL_AUTORIZADO !== '1') {
  throw new Error('Testes de integração bloqueados no servidor padrão: defina TESTE_BANCO_REAL_AUTORIZADO=1 para rodar nele.');
}

type Conta = { token: string; idUsuario: string; nomeTime: string };
const H = 3_600_000;
/** Data local (AAAA-MM-DD) em São Paulo daqui a `dias` dias. */
const dia = (dias: number) => new Date(Date.now() - 3 * H + dias * 24 * H).toISOString().slice(0, 10);

class ProvedorQueFalha {
  readonly nome = 'teste';
  async enviar(): Promise<never> {
    throw Object.assign(new Error('Firebase fora'), { code: 'messaging/unavailable' });
  }
}

describe.runIf(ativo)('lembretes de jogo e preferências', () => {
  let app: any;
  let pool: any;
  let processar: (o: { agora?: Date; apenasPartidas?: string[] }) => Promise<Record<string, number>>;
  let processarPush: (o?: any) => Promise<Record<string, number>>;
  let definirEnviador: (e: any) => void;
  let criarNotificacao: (db: any, n: any) => Promise<any>;
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

  /** Anúncio do dono; `quando`: horário local ('AAAA-MM-DDTHH:MM') ou instante. */
  async function anunciar(dono: Conta, quando: { local?: string; instante?: Date }, uf = 'SP', cidade = 'São Paulo') {
    const r = await api(dono).post('/anuncios').send({
      idModalidade: 1, idCategoriaEtaria: 4, idNivelTecnico: 2, idMandoCampo: 1, quantidadeJogadores: 7,
      dataHoraInicio: (quando.instante ?? new Date(Date.now() + 7 * 24 * H)).toISOString(),
      ...(quando.local ? { dataHoraLocal: quando.local } : {}),
      duracaoMinutos: 90, cidade, siglaEstado: uf, bairro: 'Centro', nomeLocal: 'Arena Biase',
    });
    expect(r.status).toBe(201);
    return r.body.data.idAnuncio as string;
  }

  /** Jogo confirmado entre dois times novos. */
  async function jogo(quando: { local?: string; instante?: Date }, uf = 'SP', cidade = 'São Paulo') {
    const m = randomUUID().slice(0, 5);
    const dono = await novaConta(`União ${m}`);
    const joga = await novaConta(`JOGA ${m}`);
    const idAnuncio = await anunciar(dono, quando, uf, cidade);
    const s = await api(joga).post('/solicitacoes').send({ idAnuncio });
    await api(dono).patch(`/solicitacoes/${s.body.data.idSolicitacao}/confirmar`).expect(200);
    const [[p]] = await pool.query('SELECT id_partida, data_hora_inicio FROM partidas WHERE id_solicitacao = ?', [s.body.data.idSolicitacao]);
    return { dono, joga, idPartida: p.id_partida as string, inicio: new Date(p.data_hora_inicio) };
  }

  const lembretes = async (c: Conta) =>
    (
      await pool.query(
        `SELECT n.titulo, n.mensagem, n.id_partida, n.data_leitura IS NOT NULL AS lida, e.status AS push
           FROM notificacoes n LEFT JOIN envios_push e USING (id_notificacao)
          WHERE n.id_usuario_destinatario = ? AND n.tipo = 'lembrete_partida'
          ORDER BY n.data_criacao, n.titulo`,
        [c.idUsuario],
      )
    )[0];

  const controle = async (idPartida: string) =>
    (await pool.query('SELECT tipo, status FROM lembretes_partidas WHERE id_partida = ? ORDER BY tipo', [idPartida]))[0];

  beforeAll(async () => {
    app = (await import('../src/app.js')).createApp();
    ({ pool } = await import('../src/config/db.js'));
    ({ processarLembretes: processar } = await import('../src/services/lembretes.js'));
    ({ processarFilaPush: processarPush, definirEnviadorPush: definirEnviador } = await import('../src/services/push.js'));
    ({ criarNotificacao } = await import('../src/services/notificacoes.js'));
  });

  afterAll(async () => {
    definirEnviador?.(undefined);
    await pool?.end();
  });

  it('24 h, 2 h e 30 min: aos dois capitães, com os dados reais, uma vez cada', async () => {
    const { dono, joga, idPartida, inicio } = await jogo({ local: `${dia(6)}T21:00` });
    const em = (ms: number) => new Date(inicio.getTime() - ms);
    const rodar = (agora: Date) => processar({ agora, apenasPartidas: [idPartida] });

    expect(await rodar(em(25 * H))).toEqual({}); // antes da janela
    expect(await rodar(em(23 * H))).toEqual({ '24h': 1 });
    expect(await rodar(em(22 * H))).toEqual({}); // reprocessar não repete
    expect(await lembretes(dono)).toEqual([
      {
        titulo: 'Lembrete: jogo amanhã',
        mensagem: `Seu jogo contra o time ${joga.nomeTime} acontece amanhã às 21h, em Arena Biase.`,
        id_partida: idPartida,
        lida: 0,
        push: 'pendente',
      },
    ]);
    expect((await lembretes(joga))[0].mensagem).toBe(
      `Seu jogo contra o time ${dono.nomeTime} acontece amanhã às 21h, em Arena Biase.`,
    );

    expect(await rodar(em(2 * H - 60_000))).toEqual({ '2h': 1 });
    expect(await rodar(em(29 * 60_000))).toEqual({ '30min': 1 });
    expect(await rodar(new Date(inicio.getTime() + 60_000))).toEqual({}); // depois do início: nada
    expect((await lembretes(dono)).map((l: any) => l.titulo)).toEqual([
      'Lembrete: jogo amanhã',
      'Lembrete: jogo em 2 horas',
      'Lembrete: jogo em 30 minutos',
    ]);
    expect((await lembretes(joga)).at(-1).mensagem).toBe(`Seu jogo contra o time ${dono.nomeTime} começa em 30 minutos, em Arena Biase.`);
    expect(await controle(idPartida)).toEqual([
      { tipo: '24h', status: 'enviado' },
      { tipo: '2h', status: 'enviado' },
      { tipo: '30min', status: 'enviado' },
    ]);
  });

  it('backend fora do ar nas janelas: ao voltar, só o lembrete mais próximo', async () => {
    const { dono, idPartida, inicio } = await jogo({ local: `${dia(6)}T20:00` });
    expect(await processar({ agora: new Date(inicio.getTime() - 20 * 60_000), apenasPartidas: [idPartida] })).toEqual({ '30min': 1 });
    expect((await lembretes(dono)).map((l: any) => l.titulo)).toEqual(['Lembrete: jogo em 30 minutos']);
    expect(await controle(idPartida)).toEqual([
      { tipo: '24h', status: 'pulado' },
      { tipo: '2h', status: 'pulado' },
      { tipo: '30min', status: 'enviado' },
    ]);
  });

  it('processamentos simultâneos (dois servidores): um lembrete por capitão', async () => {
    const { dono, joga, idPartida, inicio } = await jogo({ local: `${dia(6)}T19:00` });
    const agora = new Date(inicio.getTime() - 23 * H);
    await Promise.all([1, 2, 3].map(() => processar({ agora, apenasPartidas: [idPartida] })));
    expect(await lembretes(dono)).toHaveLength(1);
    expect(await lembretes(joga)).toHaveLength(1);
  });

  it('jogo cancelado e pedido pendente não recebem lembrete', async () => {
    const { dono, joga, idPartida, inicio } = await jogo({ local: `${dia(6)}T18:00` });
    await api(joga).patch(`/partidas/${idPartida}/cancelar`).send({}).expect(200);
    expect(await processar({ agora: new Date(inicio.getTime() - 23 * H), apenasPartidas: [idPartida] })).toEqual({});
    expect(await lembretes(dono)).toEqual([]);
    expect(await controle(idPartida)).toEqual([]);

    // Pedido ainda pendente no mesmo horário: não há partida, não há lembrete.
    const m = randomUUID().slice(0, 5);
    const outroDono = await novaConta(`Pendente ${m}`);
    const visitante = await novaConta(`Visita ${m}`);
    const idAnuncio = await anunciar(outroDono, { local: `${dia(6)}T18:00` });
    await api(visitante).post('/solicitacoes').send({ idAnuncio }).expect(201);
    expect(await lembretes(outroDono)).toEqual([]);
    expect(await lembretes(visitante)).toEqual([]);
  });

  it('jogo confirmado dentro da janela de 24 h: sem lembrete atrasado; o de 2 h sai na hora', async () => {
    const instante = new Date(Math.ceil((Date.now() + 10 * H) / 60_000) * 60_000);
    const { dono, idPartida, inicio } = await jogo({ instante });
    expect(await processar({ agora: new Date(), apenasPartidas: [idPartida] })).toEqual({});
    expect(await controle(idPartida)).toEqual([{ tipo: '24h', status: 'pulado' }]);
    expect(await processar({ agora: new Date(inicio.getTime() - 2 * H), apenasPartidas: [idPartida] })).toEqual({ '2h': 1 });
    expect((await lembretes(dono)).map((l: any) => l.titulo)).toEqual(['Lembrete: jogo em 2 horas']);
  });

  it('fuso do jogo: 21h no Acre aparece como 21h (não 23h de Brasília)', async () => {
    const { dono, idPartida, inicio } = await jogo({ local: `${dia(6)}T21:00` }, 'AC', 'Rio Branco');
    expect(inicio.toISOString().slice(11, 16)).toBe('02:00'); // 21h no Acre = 02:00 UTC
    await processar({ agora: new Date(inicio.getTime() - 2 * H), apenasPartidas: [idPartida] });
    expect((await lembretes(dono))[0].mensagem).toContain('começa em 2 horas, às 21h');
  });

  it('lembretes desativados: no histórico, mas já lido e sem push; o outro capitão normal', async () => {
    const { dono, joga, idPartida, inicio } = await jogo({ local: `${dia(6)}T17:00` });
    await api(joga).put('/notificacoes/preferencias').send({ lembretes: false }).expect(200);
    await processar({ agora: new Date(inicio.getTime() - 23 * H), apenasPartidas: [idPartida] });
    expect(await lembretes(joga)).toEqual([expect.objectContaining({ lida: 1, push: null })]);
    expect(await lembretes(dono)).toEqual([expect.objectContaining({ lida: 0, push: 'pendente' })]);
  });

  it('push fora do ar: o lembrete interno fica, o envio é reagendado', async () => {
    const { dono, idPartida, inicio } = await jogo({ local: `${dia(6)}T16:00` });
    await api(dono).put('/dispositivos').send({ token: `teste-${randomUUID()}`, plataforma: 'android', permitido: true }).expect(200);
    await processar({ agora: new Date(inicio.getTime() - 23 * H), apenasPartidas: [idPartida] });
    definirEnviador(new ProvedorQueFalha());
    await processarPush({ apenasUsuarios: contas });
    definirEnviador(undefined);
    const [l] = await lembretes(dono);
    expect(l).toMatchObject({ titulo: 'Lembrete: jogo amanhã', lida: 0, push: 'pendente' });
    const [[e]] = await pool.query(
      `SELECT e.tentativas, e.ultimo_erro FROM envios_push e JOIN notificacoes n USING (id_notificacao)
        WHERE n.id_usuario_destinatario = ? AND n.tipo = 'lembrete_partida'`,
      [dono.idUsuario],
    );
    expect(e).toEqual({ tentativas: 1, ultimo_erro: 'messaging/unavailable' });
  });

  describe('preferências', () => {
    it('padrão ativo; salva por conta, parcial, validado e autenticado', async () => {
      const a = await novaConta('Prefs A');
      const b = await novaConta('Prefs B');
      expect((await api(a).get('/notificacoes/preferencias')).body.data).toEqual({ desafios: true, jogos: true, chat: true, lembretes: true });
      expect((await api(a).put('/notificacoes/preferencias').send({ chat: false })).body.data).toEqual({ desafios: true, jogos: true, chat: false, lembretes: true });
      expect((await api(a).put('/notificacoes/preferencias').send({ jogos: false })).body.data).toMatchObject({ chat: false, jogos: false });
      const [[linha]] = await pool.query('SELECT desafios, jogos, chat, lembretes FROM preferencias_notificacoes WHERE id_usuario = ?', [a.idUsuario]);
      expect(linha).toEqual({ desafios: 1, jogos: 0, chat: 0, lembretes: 1 });
      expect((await api(b).get('/notificacoes/preferencias')).body.data.chat).toBe(true); // outra conta intacta
      for (const corpo of [{}, { chat: 'nao' }, { chat: null }]) {
        expect((await api(a).put('/notificacoes/preferencias').send(corpo)).status).toBe(400);
      }
      expect((await request(app).get('/api/notificacoes/preferencias')).status).toBe(401);
    });

    it('categoria desativada: histórico mantido, sem sino e sem push; aviso geral não muda', async () => {
      const m = randomUUID().slice(0, 5);
      const dono = await novaConta(`Dono ${m}`);
      const joga = await novaConta(`JOGA ${m}`);
      await api(dono).put('/notificacoes/preferencias').send({ desafios: false, chat: false }).expect(200);
      await api(joga).put('/notificacoes/preferencias').send({ jogos: false }).expect(200);

      const idAnuncio = await anunciar(dono, { local: `${dia(7)}T21:00` });
      const s = (await api(joga).post('/solicitacoes').send({ idAnuncio })).body.data.idSolicitacao;
      await api(dono).patch(`/solicitacoes/${s}/confirmar`).expect(200);
      await api(joga).post(`/solicitacoes/${s}/mensagens`).send({ texto: 'Oi' }).expect(201);
      const { pool: db } = await import('../src/config/db.js');
      await criarNotificacao(db, { idDestinatario: dono.idUsuario, tipo: 'aviso', titulo: 'Aviso do Joga Contra', mensagem: 'Manutenção' });

      const situacao = async (c: Conta) =>
        Object.fromEntries(
          (
            await pool.query(
              `SELECT n.tipo, n.data_leitura IS NOT NULL AS lida, e.status AS push FROM notificacoes n
                 LEFT JOIN envios_push e USING (id_notificacao) WHERE n.id_usuario_destinatario = ?`,
              [c.idUsuario],
            )
          )[0].map((l: any) => [l.tipo, [l.lida, l.push]]),
        );
      expect(await situacao(dono)).toEqual({
        solicitacao_recebida: [1, null], // desafios desativados
        partida_confirmada: [1, null], // já lida: foi ele quem aceitou
        mensagem_recebida: [1, null], // chat desativado
        aviso: [0, 'pendente'], // aviso geral não depende das preferências
      });
      expect(await situacao(joga)).toEqual({
        solicitacao_enviada: [1, null],
        partida_confirmada: [1, null], // jogos desativados
      });
      // O histórico continua consultável.
      expect((await api(dono).get('/notificacoes')).body.meta.total).toBe(4);

      // Reativou: os próximos voltam a contar.
      await api(dono).put('/notificacoes/preferencias').send({ chat: true }).expect(200);
      await api(joga).post(`/solicitacoes/${s}/mensagens`).send({ texto: 'De novo' }).expect(201);
      const [[ultima]] = await pool.query(
        "SELECT data_leitura FROM notificacoes WHERE id_usuario_destinatario = ? AND tipo = 'mensagem_recebida' ORDER BY data_criacao DESC LIMIT 1",
        [dono.idUsuario],
      );
      expect(ultima.data_leitura).toBeNull();
    });
  });
});
