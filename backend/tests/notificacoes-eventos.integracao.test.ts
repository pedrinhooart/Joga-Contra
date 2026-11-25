import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

/**
 * Notificações dos eventos reais (fase 2): API + procedimentos + MySQL. Grava
 * contas e jogos fictícios (teste.homologacao.*@example.com), que permanecem no
 * banco. Mesmas travas de tests/integracao.test.ts.
 */
const ativo = process.env.TESTE_INTEGRACAO === '1';
if (ativo && (process.env.DB_PORT ?? '3306') === '3306' && process.env.TESTE_BANCO_REAL_AUTORIZADO !== '1') {
  throw new Error('Testes de integração bloqueados no servidor padrão: defina TESTE_BANCO_REAL_AUTORIZADO=1 para rodar nele.');
}

type Conta = { token: string; idUsuario: string; idTime: string; nomeTime: string };
type Aviso = {
  tipo: string;
  titulo: string;
  mensagem: string;
  chave_evento: string | null;
  id_solicitacao: string | null;
  id_partida: string | null;
  lida: number;
};

/** Data local (AAAA-MM-DD) daqui a `dias` dias, no fuso de São Paulo. */
const dia = (dias: number) => new Date(Date.now() - 3 * 3_600_000 + dias * 86_400_000).toISOString().slice(0, 10);
/** '2026-11-26' + '21:00' -> '26/11 às 21h' (formato das notificações). */
const quando = (data: string, hora = '21:00') =>
  `${data.slice(8, 10)}/${data.slice(5, 7)} às ${hora.slice(0, 2)}h${hora.endsWith(':00') ? '' : hora.slice(3)}`;

describe.runIf(ativo)('notificações dos eventos do Joga Contra', () => {
  let app: any;
  let pool: any;

  const marca = () => randomUUID().slice(0, 6);

  async function novaConta(nomeTime: string): Promise<Conta> {
    const r = await request(app).post('/api/auth/cadastro').send({
      usuario: { nome: `Capitão ${nomeTime}`, email: `teste.homologacao.${randomUUID()}@example.com`, senha: 'senha-de-teste-123', cidade: 'São Paulo', siglaEstado: 'SP' },
      time: { nome: nomeTime, idsModalidades: [1], idCategoriaEtaria: 4, cidade: 'São Paulo', siglaEstado: 'SP' },
    });
    expect(r.status).toBe(201);
    return { token: r.body.data.token, idUsuario: r.body.data.usuario.idUsuario, idTime: r.body.data.time.idTime, nomeTime };
  }

  const api = (c: Conta) => ({
    get: (p: string) => request(app).get(`/api${p}`).set('Authorization', `Bearer ${c.token}`),
    post: (p: string) => request(app).post(`/api${p}`).set('Authorization', `Bearer ${c.token}`),
    patch: (p: string) => request(app).patch(`/api${p}`).set('Authorization', `Bearer ${c.token}`),
    delete: (p: string) => request(app).delete(`/api${p}`).set('Authorization', `Bearer ${c.token}`),
  });

  async function publicar(dono: Conta, data: string, hora = '21:00', nomeLocal = 'Arena Biase') {
    const r = await api(dono).post('/anuncios').send({
      idModalidade: 1, idCategoriaEtaria: 4, idNivelTecnico: 2, idMandoCampo: 1, quantidadeJogadores: 7,
      dataHoraInicio: new Date(Date.now() + 7 * 86_400_000).toISOString(),
      dataHoraLocal: `${data}T${hora}`, duracaoMinutos: 90,
      cidade: 'São Paulo', siglaEstado: 'SP', bairro: 'Centro', nomeLocal,
    });
    expect(r.status).toBe(201);
    return r.body.data.idAnuncio as string;
  }

  async function solicitar(c: Conta, idAnuncio: string) {
    const r = await api(c).post('/solicitacoes').send({ idAnuncio });
    expect(r.status).toBe(201);
    return r.body.data.idSolicitacao as string;
  }

  /** Notificações da conta direto do MySQL (persistência), mais antigas primeiro. */
  async function avisos(c: Conta): Promise<Aviso[]> {
    const [linhas] = await pool.query(
      `SELECT tipo, titulo, mensagem, chave_evento, id_solicitacao, id_partida, data_leitura IS NOT NULL AS lida
         FROM notificacoes WHERE id_usuario_destinatario = ? ORDER BY data_criacao, id_notificacao`,
      [c.idUsuario],
    );
    return linhas;
  }

  beforeAll(async () => {
    app = (await import('../src/app.js')).createApp();
    ({ pool } = await import('../src/config/db.js'));
  });

  afterAll(async () => {
    await pool?.end();
  });

  it('envio do desafio: "Novo desafio recebido" ao dono e "Desafio enviado" (já lido) a quem enviou', async () => {
    const m = marca();
    const dono = await novaConta(`União Esportiva ${m}`);
    const joga = await novaConta(`JOGA ${m}`);
    const data = dia(5);
    const idAnuncio = await publicar(dono, data);
    const idSolicitacao = await solicitar(joga, idAnuncio);

    expect(await avisos(dono)).toEqual([
      {
        tipo: 'solicitacao_recebida',
        titulo: 'Novo desafio recebido',
        mensagem: `O time JOGA ${m} demonstrou interesse no seu jogo de ${quando(data)}, em Arena Biase.`,
        chave_evento: `solicitacao_recebida:${idSolicitacao}`,
        id_solicitacao: idSolicitacao,
        id_partida: null,
        lida: 0,
      },
    ]);
    expect(await avisos(joga)).toEqual([
      {
        tipo: 'solicitacao_enviada',
        titulo: 'Desafio enviado',
        mensagem: `Sua solicitação foi enviada para o time União Esportiva ${m} (jogo de ${quando(data)}, em Arena Biase). Avisaremos quando houver resposta.`,
        chave_evento: `solicitacao_enviada:${idSolicitacao}`,
        id_solicitacao: idSolicitacao,
        id_partida: null,
        lida: 1,
      },
    ]);
    // Só o dono tem novidade no sino.
    expect((await api(dono).get('/notificacoes/nao-lidas')).body.data.naoLidas).toBe(1);
    expect((await api(joga).get('/notificacoes/nao-lidas')).body.data.naoLidas).toBe(0);

    // Pedir de novo reabre o mesmo pedido: nenhum aviso repetido.
    const repetido = await api(joga).post('/solicitacoes').send({ idAnuncio });
    expect(repetido.status).toBe(200);
    expect(repetido.body.data.idSolicitacao).toBe(idSolicitacao);
    expect(await avisos(dono)).toHaveLength(1);
    expect(await avisos(joga)).toHaveLength(1);
  });

  it('aceite: "Desafio aceito!" com jogo real e chat liberado; encerra e avisa os outros desafiantes', async () => {
    const m = marca();
    const dono = await novaConta(`União Esportiva ${m}`);
    const joga = await novaConta(`JOGA ${m}`);
    const outro = await novaConta(`Outro ${m}`);
    const data = dia(6);
    const idAnuncio = await publicar(dono, data, '21:30', 'Arena Biase');
    const sJoga = await solicitar(joga, idAnuncio);
    const sOutro = await solicitar(outro, idAnuncio);

    // Antes do aceite o chat continua fechado.
    expect((await api(joga).get(`/solicitacoes/${sJoga}/mensagens`)).status).toBe(403);

    const aceite = await api(dono).patch(`/solicitacoes/${sJoga}/confirmar`);
    expect(aceite.status).toBe(200);
    const [[{ id_partida: idPartida }]] = await pool.query('SELECT id_partida FROM partidas WHERE id_solicitacao = ?', [sJoga]);

    const doJoga = (await avisos(joga)).filter((n) => n.tipo !== 'solicitacao_enviada');
    expect(doJoga).toEqual([
      {
        tipo: 'partida_confirmada',
        titulo: 'Desafio aceito!',
        mensagem: `Seu desafio foi aceito! O jogo contra o time União Esportiva ${m} será em ${quando(data, '21:30')}, em Arena Biase. O chat com o outro capitão já está liberado.`,
        chave_evento: `desafio_aceito:${sJoga}`,
        id_solicitacao: null,
        id_partida: idPartida,
        lida: 0,
      },
    ]);
    // Quem aceitou: registro no histórico, já lido.
    const doDono = (await avisos(dono)).filter((n) => n.tipo === 'partida_confirmada');
    expect(doDono).toHaveLength(1);
    expect(doDono[0]).toMatchObject({ titulo: 'Partida confirmada', lida: 1, id_partida: idPartida });
    expect(doDono[0].mensagem).toContain(`Você aceitou o desafio do time JOGA ${m}`);
    // O outro desafiante: solicitação encerrada (só a dele, só uma vez).
    const doOutro = (await avisos(outro)).filter((n) => n.tipo === 'solicitacao_encerrada');
    expect(doOutro).toEqual([
      {
        tipo: 'solicitacao_encerrada',
        titulo: 'Solicitação encerrada',
        mensagem: `Sua solicitação para jogar contra o time União Esportiva ${m} foi encerrada: o jogo de ${quando(data, '21:30')} foi confirmado com outro time.`,
        chave_evento: `solicitacao_encerrada:${sOutro}`,
        id_solicitacao: sOutro,
        id_partida: null,
        lida: 0,
      },
    ]);
    // O chat abre agora; não há aviso separado de "chat liberado".
    expect((await api(joga).get(`/solicitacoes/${sJoga}/mensagens`)).status).toBe(200);
    expect((await avisos(joga)).map((n) => n.tipo)).toEqual(['solicitacao_enviada', 'partida_confirmada']);

    // Repetir o aceite não gera nada.
    const antes = [(await avisos(joga)).length, (await avisos(dono)).length, (await avisos(outro)).length];
    expect((await api(dono).patch(`/solicitacoes/${sJoga}/confirmar`)).status).toBe(409);
    expect((await api(dono).patch(`/solicitacoes/${sOutro}/confirmar`)).status).toBe(409);
    expect([(await avisos(joga)).length, (await avisos(dono)).length, (await avisos(outro)).length]).toEqual(antes);
  });

  it('recusa avisa só o desafiante; desistência não gera aviso', async () => {
    const m = marca();
    const dono = await novaConta(`União Esportiva ${m}`);
    const joga = await novaConta(`JOGA ${m}`);
    const data = dia(7);
    const idAnuncio = await publicar(dono, data, '19:00');
    const s1 = await solicitar(joga, idAnuncio);

    expect((await api(dono).patch(`/solicitacoes/${s1}/recusar`)).status).toBe(200);
    const recusa = (await avisos(joga)).filter((n) => n.tipo === 'solicitacao_recusada');
    expect(recusa).toEqual([
      {
        tipo: 'solicitacao_recusada',
        titulo: 'Solicitação encerrada',
        mensagem: `Sua solicitação para jogar contra o time União Esportiva ${m} em ${quando(data, '19:00')} foi recusada.`,
        chave_evento: `solicitacao_encerrada:${s1}`,
        id_solicitacao: s1,
        id_partida: null,
        lida: 0,
      },
    ]);
    expect((await api(dono).patch(`/solicitacoes/${s1}/recusar`)).status).toBe(409);
    expect((await avisos(joga)).filter((n) => n.tipo === 'solicitacao_recusada')).toHaveLength(1);
    expect((await avisos(dono)).map((n) => n.tipo)).toEqual(['solicitacao_recebida']);

    // Desistência: o próprio desafiante cancela; ninguém recebe encerramento.
    const s2 = await solicitar(joga, idAnuncio);
    expect((await api(joga).patch(`/solicitacoes/${s2}/cancelar`)).status).toBe(200);
    const deS2 = [...(await avisos(joga)), ...(await avisos(dono))].filter((n) => n.id_solicitacao === s2);
    expect(deS2.map((n) => n.tipo).sort()).toEqual(['solicitacao_enviada', 'solicitacao_recebida']);
  });

  it('conflito de horário: aviso só ao time desafiante, uma por solicitação encerrada', async () => {
    const m = marca();
    const joga = await novaConta(`JOGA ${m}`);
    const outroTime = await novaConta(`Outro ${m}`);
    const donos = await Promise.all(['A', 'B', 'C', 'D'].map((x) => novaConta(`Dono ${x} ${m}`)));
    const data = dia(8);
    const [aA, aB, aC] = await Promise.all(donos.slice(0, 3).map((d, i) => publicar(d, data, '21:00', `Campo ${'ABC'[i]}`)));
    const aD = await publicar(donos[3], data, '19:00', 'Campo D');
    const [sA, sB, sC, sD] = [await solicitar(joga, aA), await solicitar(joga, aB), await solicitar(joga, aC), await solicitar(joga, aD)];
    const sOutroB = await solicitar(outroTime, aB);
    const donosAntes = await Promise.all(donos.map(async (d) => (await avisos(d)).length));

    expect((await api(donos[0]).patch(`/solicitacoes/${sA}/confirmar`)).status).toBe(200);

    const conflito = (await avisos(joga)).filter((n) => n.titulo === 'Solicitação encerrada por conflito de horário');
    expect(conflito.map((n) => n.id_solicitacao).sort()).toEqual([sB, sC].sort());
    for (const n of conflito) {
      const campo = n.id_solicitacao === sB ? 'B' : 'C';
      expect(n).toMatchObject({ tipo: 'solicitacao_encerrada', lida: 0, chave_evento: `solicitacao_encerrada:${n.id_solicitacao}` });
      expect(n.mensagem).toBe(
        `Como seu desafio contra o time Dono A ${m} foi confirmado para ${quando(data)}, sua solicitação para o jogo do time Dono ${campo} ${m} nesse mesmo horário foi encerrada.`,
      );
    }
    // D (19h) não foi encerrada nem avisada; o pedido do outro time em B segue pendente e sem aviso.
    expect((await avisos(joga)).some((n) => n.id_solicitacao === sD && n.tipo === 'solicitacao_encerrada')).toBe(false);
    expect((await avisos(outroTime)).filter((n) => n.tipo === 'solicitacao_encerrada')).toEqual([]);
    const [[{ status }]] = await pool.query('SELECT status FROM solicitacoes_confronto WHERE id_solicitacao = ?', [sOutroB]);
    expect(status).toBe('pendente');
    // Os donos de B, C e D não recebem nada novo; o dono A só o registro do próprio aceite.
    const donosDepois = await Promise.all(donos.map(async (d) => (await avisos(d)).length));
    expect(donosDepois).toEqual([donosAntes[0] + 1, donosAntes[1], donosAntes[2], donosAntes[3]]);
  });

  it('anúncio removido avisa os desafiantes pendentes', async () => {
    const m = marca();
    const dono = await novaConta(`União Esportiva ${m}`);
    const joga = await novaConta(`JOGA ${m}`);
    const data = dia(9);
    const idAnuncio = await publicar(dono, data, '20:00');
    const s = await solicitar(joga, idAnuncio);
    expect((await api(dono).delete(`/anuncios/${idAnuncio}`)).status).toBe(204);
    expect((await avisos(joga)).filter((n) => n.tipo === 'solicitacao_encerrada')).toEqual([
      {
        tipo: 'solicitacao_encerrada',
        titulo: 'Solicitação encerrada',
        mensagem: `Sua solicitação para jogar contra o time União Esportiva ${m} foi encerrada: o anúncio do jogo de ${quando(data, '20:00')} foi removido.`,
        chave_evento: `solicitacao_encerrada:${s}`,
        id_solicitacao: s,
        id_partida: null,
        lida: 0,
      },
    ]);
  });

  it('jogo cancelado avisa os dois lados (quem cancelou, já lido)', async () => {
    const m = marca();
    const dono = await novaConta(`União Esportiva ${m}`);
    const joga = await novaConta(`JOGA ${m}`);
    const data = dia(10);
    const idAnuncio = await publicar(dono, data);
    const s = await solicitar(joga, idAnuncio);
    await api(dono).patch(`/solicitacoes/${s}/confirmar`).expect(200);
    const [[{ id_partida: idPartida }]] = await pool.query('SELECT id_partida FROM partidas WHERE id_solicitacao = ?', [s]);

    expect((await api(joga).patch(`/partidas/${idPartida}/cancelar`).send({ motivo: 'Chuva forte' })).status).toBe(200);
    const doDono = (await avisos(dono)).filter((n) => n.tipo === 'partida_cancelada');
    const doJoga = (await avisos(joga)).filter((n) => n.tipo === 'partida_cancelada');
    expect(doDono).toEqual([
      {
        tipo: 'partida_cancelada',
        titulo: 'Jogo cancelado',
        mensagem: `O jogo contra o time JOGA ${m}, previsto para ${quando(data)}, foi cancelado. Motivo: Chuva forte`,
        chave_evento: `partida_cancelada:${idPartida}`,
        id_solicitacao: null,
        id_partida: idPartida,
        lida: 0,
      },
    ]);
    expect(doJoga).toHaveLength(1);
    expect(doJoga[0]).toMatchObject({ titulo: 'Jogo cancelado', lida: 1, id_partida: idPartida });
    expect(doJoga[0].mensagem).toBe(
      `Você cancelou o jogo contra o time União Esportiva ${m}, previsto para ${quando(data)}. O outro capitão foi avisado.`,
    );
    // Cancelar de novo: recusado, sem aviso repetido.
    expect((await api(dono).patch(`/partidas/${idPartida}/cancelar`).send({})).status).toBe(409);
    expect((await avisos(dono)).filter((n) => n.tipo === 'partida_cancelada')).toHaveLength(1);
  });

  it('aceites simultâneos no mesmo horário: um só "Desafio aceito!" e um só encerramento', async () => {
    const m = marca();
    const joga = await novaConta(`JOGA ${m}`);
    const [donoA, donoB] = await Promise.all([novaConta(`Dono A ${m}`), novaConta(`Dono B ${m}`)]);
    const data = dia(11);
    const [aA, aB] = await Promise.all([publicar(donoA, data), publicar(donoB, data)]);
    const sA = await solicitar(joga, aA);
    const sB = await solicitar(joga, aB);

    const respostas = await Promise.all([
      api(donoA).patch(`/solicitacoes/${sA}/confirmar`),
      api(donoB).patch(`/solicitacoes/${sB}/confirmar`),
    ]);
    expect(respostas.map((r) => r.status).sort()).toEqual([200, 409]);
    const venceu = respostas[0].status === 200 ? { dono: donoA, s: sA, perdeu: sB, donoPerdeu: donoB } : { dono: donoB, s: sB, perdeu: sA, donoPerdeu: donoA };

    const doJoga = await avisos(joga);
    expect(doJoga.filter((n) => n.titulo === 'Desafio aceito!')).toHaveLength(1);
    const encerradas = doJoga.filter((n) => n.tipo === 'solicitacao_encerrada');
    expect(encerradas.map((n) => n.id_solicitacao)).toEqual([venceu.perdeu]);
    // O aceite que falhou foi desfeito por inteiro: nenhum aviso de partida para aquele dono.
    expect((await avisos(venceu.donoPerdeu)).filter((n) => n.tipo === 'partida_confirmada')).toEqual([]);
    expect((await avisos(venceu.dono)).filter((n) => n.tipo === 'partida_confirmada')).toHaveLength(1);
  });

  it('evento desfeito não deixa notificação', async () => {
    const m = marca();
    const dono = await novaConta(`União Esportiva ${m}`);
    const joga = await novaConta(`JOGA ${m}`);
    const estranho = await novaConta(`Estranho ${m}`);
    const idAnuncio = await publicar(dono, dia(12));
    const s = await solicitar(joga, idAnuncio);
    const contar = async () => {
      const [[{ n }]] = await pool.query(
        'SELECT COUNT(*) AS n FROM notificacoes WHERE id_usuario_destinatario IN (?, ?, ?)',
        [dono.idUsuario, joga.idUsuario, estranho.idUsuario],
      );
      return n;
    };
    const antes = await contar();

    // Procedimento chamado por quem não pode aceitar: erro e ROLLBACK de tudo.
    await expect(pool.query('CALL proc_confirmar_solicitacao(?, ?)', [s, estranho.idUsuario])).rejects.toMatchObject({
      code: 'ER_SIGNAL_EXCEPTION',
    });
    await expect(pool.query('CALL proc_cancelar_partida(?, ?, NULL)', [randomUUID(), dono.idUsuario])).rejects.toMatchObject({
      code: 'ER_SIGNAL_EXCEPTION',
    });
    // Pedido para anúncio pausado: o banco recusa o pedido e os avisos não ficam.
    await api(dono).patch(`/anuncios/${idAnuncio}/status`).send({ status: 'pausado' }).expect(200);
    expect((await api(estranho).post('/solicitacoes').send({ idAnuncio })).status).toBe(409);
    expect(await contar()).toBe(antes);
  });

  it('data e hora dos textos: SQL e API iguais em todas as UFs', async () => {
    const { textoQuando } = await import('../src/services/fuso.js');
    const ufs = ['AC', 'AL', 'AM', 'AP', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MG', 'MS', 'MT', 'PA', 'PB', 'PE', 'PI', 'PR', 'RJ', 'RN', 'RO', 'RR', 'RS', 'SC', 'SE', 'SP', 'TO'];
    for (const uf of ufs) {
      for (const instante of ['2026-11-27T00:00:00.000Z', '2026-11-27T00:30:00.000Z', '2026-12-31T23:05:00.000Z']) {
        const [[{ t }]] = await pool.query('SELECT fn_quando_texto(?, ?) AS t', [instante.replace('T', ' ').slice(0, 23), uf]);
        expect(t, `${uf} ${instante}`).toBe(textoQuando(new Date(instante), uf));
      }
    }
  });
});
