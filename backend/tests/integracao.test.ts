import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';

// Não há provedor de e-mail: o teste captura o código no ponto de envio.
const codigosEnviados = vi.hoisted(() => [] as string[]);
vi.mock('../src/services/email.js', () => ({
  enviarCodigoRecuperacao: async (_email: string, codigo: string) => {
    codigosEnviados.push(codigo);
  },
}));

/**
 * Integração API + MySQL. Grava dados fictícios (teste.homologacao.*@example.com) de verdade, por
 * isso só roda com TESTE_INTEGRACAO=1 e, no servidor padrão (3306), também com
 * TESTE_BANCO_REAL_AUTORIZADO=1 e ROTINAS_PRESERVAR_ATE. Os registros criados permanecem no banco.
 */
const ativo = process.env.TESTE_INTEGRACAO === '1';
if (ativo && (process.env.DB_PORT ?? '3306') === '3306' && process.env.TESTE_BANCO_REAL_AUTORIZADO !== '1') {
  throw new Error('Testes de integração bloqueados no servidor padrão: defina TESTE_BANCO_REAL_AUTORIZADO=1 para rodar nele.');
}

const SENHA = 'senha-de-teste-123';
const SOCIETY = 1;
const QUADRA = 2;
const SUB_17 = 2;
const LIVRE = 4;
const INICIANTE = 1;
const INTERMEDIARIO = 2;

describe.runIf(ativo)('integração com joga_contra_v2', () => {
  let app: any;
  let pool: any;
  let executarRotinas: () => Promise<void>;
  let registrosPreservadosAfetados: () => Promise<{ anuncios: number; partidas: number }>;

  type Capitao = { token: string; idUsuario: string; idTime: string; nomeTime: string };

  const api = (c?: Capitao) => {
    const agente = (metodo: 'get' | 'post' | 'put' | 'patch' | 'delete', caminho: string) => {
      const r = request(app)[metodo](`/api${caminho}`);
      return c ? r.set('Authorization', `Bearer ${c.token}`) : r;
    };
    return {
      get: (p: string) => agente('get', p),
      post: (p: string) => agente('post', p),
      put: (p: string) => agente('put', p),
      patch: (p: string) => agente('patch', p),
      delete: (p: string) => agente('delete', p),
    };
  };

  async function novoCapitao(nomeTime: string, categoria = LIVRE): Promise<Capitao> {
    const r = await api().post('/auth/cadastro').send({
      usuario: {
        nome: `Capitão ${nomeTime}`,
        email: `teste.homologacao.${randomUUID()}@example.com`,
        senha: SENHA,
        telefone: '(11) 90000-0000',
        cidade: 'São Paulo',
        siglaEstado: 'SP',
      },
      time: {
        nome: nomeTime,
        idsModalidades: [SOCIETY],
        idCategoriaEtaria: categoria,
        idNivelTecnico: INTERMEDIARIO,
        quantidadeJogadores: 14,
        cidade: 'São Paulo',
        siglaEstado: 'SP',
      },
    });
    expect(r.status).toBe(201);
    return { token: r.body.data.token, idUsuario: r.body.data.usuario.idUsuario, idTime: r.body.data.time.idTime, nomeTime };
  }

  const dadosAnuncio = (extra: Record<string, unknown> = {}) => ({
    idModalidade: SOCIETY,
    idCategoriaEtaria: LIVRE,
    idNivelTecnico: INTERMEDIARIO,
    idMandoCampo: 1,
    quantidadeJogadores: 7,
    dataHoraInicio: new Date(Date.now() + 7 * 86_400_000).toISOString(),
    cidade: 'São Paulo',
    siglaEstado: 'SP',
    bairro: 'Vila Mariana',
    nomeLocal: 'Campo de Teste',
    valorAluguelPorTime: 120.5,
    descricao: 'Amistoso de teste',
    ...extra,
  });

  async function publicar(c: Capitao, extra?: Record<string, unknown>) {
    const r = await api(c).post('/anuncios').send(dadosAnuncio(extra));
    expect(r.status).toBe(201);
    return r.body.data;
  }

  async function solicitar(c: Capitao, idAnuncio: string) {
    const r = await api(c).post('/solicitacoes').send({ idAnuncio });
    expect(r.status).toBe(201);
    return r.body.data;
  }

  beforeAll(async () => {
    ({ createApp: app } = await import('../src/app.js'));
    app = (app as any)();
    ({ pool } = await import('../src/config/db.js'));
    ({ executarRotinas, registrosPreservadosAfetados } = await import('../src/services/rotinas.js'));
    const { env } = await import('../src/config/env.js');
    if (env.DB_PORT === 3306 && !env.ROTINAS_PRESERVAR_ATE) {
      throw new Error('Defina ROTINAS_PRESERVAR_ATE: sem ela, as rotinas podem alterar registros antigos.');
    }
  });

  afterAll(async () => {
    await pool?.end();
  });

  it('1. conecta ao banco joga_contra_v2', async () => {
    const r = await api().get('/health/db');
    expect(r.status).toBe(200);
    expect(r.body.data.banco).toBe('joga_contra_v2');
    const [[{ fuso }]] = await pool.query('SELECT @@session.time_zone AS fuso');
    expect(fuso).toBe('+00:00');
  });

  it('referências usam as classificações oficiais, separadas', async () => {
    const { data } = (await api().get('/referencias')).body;
    expect(data.modalidades.map((m: any) => m.nome)).toEqual(['Futebol society/sintético', 'Futebol de quadra']);
    expect(data.categoriasEtarias.map((c: any) => c.nome)).toEqual(['Sub-15', 'Sub-17', 'Sub-19', 'Livre']);
    expect(data.niveisTecnicos.map((n: any) => n.nome)).toEqual(['Iniciante', 'Intermediário', 'Avançado']);
    expect(data.estados).toHaveLength(27);
  });

  it('2 e 3. cadastra capitão com time, autentica e consulta', async () => {
    const email = `teste.homologacao.${randomUUID()}@example.com`;
    const corpo = {
      usuario: { nome: 'Capitão', email, senha: SENHA },
      time: {
        nome: 'Time Login', idsModalidades: [SOCIETY, QUADRA], idCategoriaEtaria: LIVRE,
        quantidadeJogadores: 12, cidade: 'Campinas', siglaEstado: 'sp',
      },
    };
    const cadastro = await api().post('/auth/cadastro').send(corpo);
    expect(cadastro.status).toBe(201);
    expect(cadastro.body.data.time.modalidades).toHaveLength(2);
    expect(cadastro.body.data.time.quantidadeJogadores).toBe(12);
    expect(JSON.stringify(cadastro.body)).not.toContain('hash');

    const [[{ hash_senha }]] = await pool.query('SELECT hash_senha FROM usuarios WHERE email = ?', [email]);
    expect(hash_senha).toMatch(/^\$2[aby]\$12\$/);

    expect((await api().post('/auth/cadastro').send(corpo)).status).toBe(409);
    expect((await api().post('/auth/login').send({ email, senha: 'errada-123' })).status).toBe(401);

    const login = await api().post('/auth/login').send({ email: email.toUpperCase(), senha: SENHA });
    expect(login.status).toBe(200);
    const c = { token: login.body.data.token } as Capitao;
    const eu = await api(c).get('/auth/eu');
    expect(eu.body.data.usuario.email).toBe(email);
    expect(eu.body.data.time.nome).toBe('Time Login');
    expect(eu.body.data.time.nomeCapitao).toBe('Capitão');
  });

  it('cadastro com time inválido não deixa usuário órfão (transação)', async () => {
    const email = `teste.homologacao.${randomUUID()}@example.com`;
    const r = await api().post('/auth/cadastro').send({
      usuario: { nome: 'X', email, senha: SENHA },
      time: {
        nome: 'Y', idsModalidades: [99], idCategoriaEtaria: LIVRE, quantidadeJogadores: 10,
        cidade: 'Z', siglaEstado: 'SP',
      },
    });
    expect(r.status).toBe(400);
    const [linhas] = await pool.query('SELECT 1 FROM usuarios WHERE email = ?', [email]);
    expect(linhas).toHaveLength(0);
  });

  it('atualiza o time e protege o contato', async () => {
    const a = await novoCapitao('Time Editável');
    const b = await novoCapitao('Time Visitante');
    const r = await api(a).patch(`/times/${a.idTime}`).send({
      nome: 'Time Editado', descricao: 'Sobre nós', quantidadeJogadores: 20, idsModalidades: [QUADRA],
    });
    expect(r.status).toBe(200);
    expect(r.body.data).toMatchObject({ nome: 'Time Editado', descricao: 'Sobre nós', quantidadeJogadores: 20 });
    expect(r.body.data.modalidades.map((m: any) => m.codigo)).toEqual(['quadra']);
    expect(r.body.data.telefoneContato).toBe('(11) 90000-0000');

    expect((await api(b).patch(`/times/${a.idTime}`).send({ nome: 'Invasão' })).status).toBe(403);
    const visto = await api(b).get(`/times/${a.idTime}`);
    expect(visto.body.data.nome).toBe('Time Editado');
    expect(visto.body.data.telefoneContato).toBeNull();
    expect(JSON.stringify(visto.body)).not.toContain('@example.com');
  });

  it('4 e 5. publica, edita, pausa e lista anúncios', async () => {
    const dono = await novoCapitao('Dono');
    const outro = await novoCapitao('Outro');
    const anuncio = await publicar(dono);
    expect(anuncio).toMatchObject({
      status: 'ativo', quantidadeJogadores: 7, valorAluguelPorTime: 120.5,
      modalidade: { codigo: 'society' }, categoriaEtaria: { codigo: 'livre' }, nivelTecnico: { codigo: 'intermediario' },
      mandoCampo: { codigo: 'casa' },
    });
    expect(anuncio.time.idTime).toBe(dono.idTime);

    const editado = await api(dono).put(`/anuncios/${anuncio.idAnuncio}`).send(dadosAnuncio({ nomeLocal: 'Novo Campo', idMandoCampo: null }));
    expect(editado.status).toBe(200);
    expect(editado.body.data.nomeLocal).toBe('Novo Campo');
    expect(editado.body.data.mandoCampo).toBeNull();

    const meus = await api(dono).get('/anuncios/meus');
    expect(meus.body.data.map((a: any) => a.idAnuncio)).toContain(anuncio.idAnuncio);

    const proprio = await api(dono).get('/anuncios?limite=100');
    expect(proprio.body.data.some((a: any) => a.time.idTime === dono.idTime)).toBe(false);
    const visivel = async () =>
      (await api(outro).get('/anuncios?limite=100&texto=Novo%20Campo')).body.data.some((a: any) => a.idAnuncio === anuncio.idAnuncio);
    expect(await visivel()).toBe(true);

    await api(dono).patch(`/anuncios/${anuncio.idAnuncio}/status`).send({ status: 'pausado' }).expect(200);
    expect(await visivel()).toBe(false);
    await api(dono).patch(`/anuncios/${anuncio.idAnuncio}/status`).send({ status: 'ativo' }).expect(200);
    expect(await visivel()).toBe(true);
  });

  it('rejeita anúncio sem nível técnico, com data passada ou com poucos jogadores', async () => {
    const c = await novoCapitao('Validações');
    expect((await api(c).post('/anuncios').send(dadosAnuncio({ idNivelTecnico: null }))).status).toBe(400);
    expect((await api(c).post('/anuncios').send(dadosAnuncio({ quantidadeJogadores: 4 }))).status).toBe(400);
    const passada = await api(c).post('/anuncios').send(dadosAnuncio({ dataHoraInicio: '2020-01-01T10:00:00.000Z' }));
    expect(passada.status).toBe(409);
    expect(passada.body.error.message).toContain('futuros');
  });

  it('6. filtros: cidade, data, horário, modalidade, faixa etária e nível são independentes', async () => {
    const dono = await novoCapitao('Filtros');
    const leitor = await novoCapitao('Leitor');
    const marca = `Local${randomUUID().slice(0, 8)}`;
    // 15h de Brasília = 18h UTC, em dia fixo no futuro.
    const dia = new Date(Date.now() + 10 * 86_400_000).toISOString().slice(0, 10);
    const quando = (hora: string) => `${dia}T${hora}:00:00.000Z`;
    const a = await publicar(dono, {
      nomeLocal: `${marca} A`, dataHoraInicio: quando('18'), cidade: 'Santos', idModalidade: SOCIETY,
      idCategoriaEtaria: SUB_17, idNivelTecnico: INICIANTE,
    });
    const b = await publicar(dono, {
      nomeLocal: `${marca} B`, dataHoraInicio: quando('23'), cidade: 'Campinas', idModalidade: QUADRA,
      idCategoriaEtaria: LIVRE, idNivelTecnico: INICIANTE,
    });
    const buscar = async (filtro: string) => {
      const r = await api(leitor).get(`/anuncios?limite=100&texto=${marca}&${filtro}`);
      expect(r.status).toBe(200);
      return r.body.data.map((x: any) => x.idAnuncio).sort();
    };
    const ambos = [a.idAnuncio, b.idAnuncio].sort();

    expect(await buscar('')).toEqual(ambos);
    expect(await buscar('cidade=santos')).toEqual([a.idAnuncio]);
    expect(await buscar(`idModalidade=${QUADRA}`)).toEqual([b.idAnuncio]);
    expect(await buscar(`idCategoriaEtaria=${SUB_17}`)).toEqual([a.idAnuncio]);
    // Mesmo nível, faixas etárias diferentes: as classificações não se misturam.
    expect(await buscar(`idNivelTecnico=${INICIANTE}`)).toEqual(ambos);
    expect(await buscar(`idNivelTecnico=${INTERMEDIARIO}`)).toEqual([]);
    expect(await buscar(`idCategoriaEtaria=${SUB_17}&idNivelTecnico=${INICIANTE}`)).toEqual([a.idAnuncio]);
    expect(await buscar(`data=${dia}&fusoMinutos=-180`)).toEqual(ambos);
    expect(await buscar('data=2099-01-01')).toEqual([]);
    expect(await buscar('horario=16:00&fusoMinutos=-180')).toEqual([b.idAnuncio]); // 15h fica de fora; 20h entra
    expect(await buscar('horario=15:00&fusoMinutos=-180')).toEqual(ambos);
    expect((await api(leitor).get('/anuncios?horario=25:00')).status).toBe(400);

    const curinga = await api(leitor).get('/anuncios?texto=%25');
    expect(curinga.body.data.every((x: any) => JSON.stringify(x).includes('%'))).toBe(true);
    const injecao = await api(leitor).get(`/anuncios?cidade=${encodeURIComponent("' OR 1=1 -- ")}`);
    expect(injecao.status).toBe(200);
    expect(injecao.body.data).toEqual([]);
  });

  it('cada faixa etária, nível e modalidade filtra sozinho, em qualquer combinação', async () => {
    const dono = await novoCapitao('Matriz');
    const leitor = await novoCapitao('Leitor Matriz');
    const refs = (await api().get('/referencias')).body.data;
    expect(refs.categoriasEtarias.map((c: any) => c.nome)).toEqual(['Sub-15', 'Sub-17', 'Sub-19', 'Livre']);
    expect(refs.niveisTecnicos.map((n: any) => n.nome)).toEqual(['Iniciante', 'Intermediário', 'Avançado']);
    expect(refs.modalidades).toHaveLength(2);

    const marca = `Matriz${randomUUID().slice(0, 8)}`;
    const criados: { id: string; categoria: number; nivel: number; modalidade: number }[] = [];
    for (const categoria of refs.categoriasEtarias) {
      for (const nivel of refs.niveisTecnicos) {
        const modalidade = refs.modalidades[criados.length % 2];
        const anuncio = await publicar(dono, {
          nomeLocal: marca,
          idCategoriaEtaria: categoria.id,
          idNivelTecnico: nivel.id,
          idModalidade: modalidade.id,
        });
        criados.push({ id: anuncio.idAnuncio, categoria: categoria.id, nivel: nivel.id, modalidade: modalidade.id });
      }
    }

    const buscar = async (filtro: string) =>
      (await api(leitor).get(`/anuncios?limite=100&texto=${marca}&${filtro}`).expect(200)).body.data
        .map((a: any) => a.idAnuncio)
        .sort();
    const ids = (lista: typeof criados) => lista.map((a) => a.id).sort();

    for (const { id } of refs.categoriasEtarias) {
      expect(await buscar(`idCategoriaEtaria=${id}`)).toEqual(ids(criados.filter((a) => a.categoria === id)));
    }
    for (const { id } of refs.niveisTecnicos) {
      expect(await buscar(`idNivelTecnico=${id}`)).toEqual(ids(criados.filter((a) => a.nivel === id)));
    }
    for (const { id } of refs.modalidades) {
      expect(await buscar(`idModalidade=${id}`)).toEqual(ids(criados.filter((a) => a.modalidade === id)));
    }
    for (const a of criados) {
      expect(await buscar(`idCategoriaEtaria=${a.categoria}&idNivelTecnico=${a.nivel}`)).toEqual([a.id]);
    }
  });

  it('7 a 14. fluxo completo de confirmação', async () => {
    const dono = await novoCapitao('Anunciante');
    const escolhido = await novoCapitao('Escolhido');
    const perdedor1 = await novoCapitao('Perdedor Um');
    const perdedor2 = await novoCapitao('Perdedor Dois');
    const estranho = await novoCapitao('Estranho');
    const anuncio = await publicar(dono);

    // 7. Várias solicitações para o mesmo anúncio.
    const s1 = await solicitar(escolhido, anuncio.idAnuncio);
    const s2 = await solicitar(perdedor1, anuncio.idAnuncio);
    const s3 = await solicitar(perdedor2, anuncio.idAnuncio);
    expect(s1).toMatchObject({ status: 'pendente', confirmadoAnunciante: false, idPartida: null });
    expect(s1.timeAnunciante.idTime).toBe(dono.idTime);
    expect(s1.timeSolicitante.idTime).toBe(escolhido.idTime);

    // Repetir o interesse não duplica.
    const repetida = await api(escolhido).post('/solicitacoes').send({ idAnuncio: anuncio.idAnuncio });
    expect(repetida.status).toBe(200);
    expect(repetida.body.data.idSolicitacao).toBe(s1.idSolicitacao);

    // Próprio anúncio é bloqueado.
    expect((await api(dono).post('/solicitacoes').send({ idAnuncio: anuncio.idAnuncio })).status).toBe(409);

    // 8. Consultas.
    const analise = await api(dono).get(`/anuncios/${anuncio.idAnuncio}/solicitacoes`);
    expect(analise.body.data).toHaveLength(3);
    expect((await api(dono).get('/anuncios/meus')).body.data[0].totalSolicitacoes).toBe(3);
    expect((await api(escolhido).get('/solicitacoes/minhas')).body.data.map((s: any) => s.idSolicitacao)).toContain(s1.idSolicitacao);
    const recebida = (await api(dono).get('/notificacoes')).body.data;
    expect(recebida.filter((n: any) => n.tipo === 'solicitacao_recebida')).toHaveLength(3);

    // Mensagens e não lidas.
    const m = await api(escolhido).post(`/solicitacoes/${s1.idSolicitacao}/mensagens`).send({ texto: 'Sábado às 16h?' });
    expect(m.status).toBe(201);
    expect((await api(dono).get(`/solicitacoes/${s1.idSolicitacao}`)).body.data).toMatchObject({
      ultimaMensagem: 'Sábado às 16h?', mensagensNaoLidas: 1,
    });
    expect((await api(dono).get(`/solicitacoes/${s1.idSolicitacao}/mensagens`)).body.data).toHaveLength(1);
    expect((await api(dono).get(`/solicitacoes/${s1.idSolicitacao}`)).body.data.mensagensNaoLidas).toBe(0);

    // 15. Permissões entre times.
    expect((await api(estranho).get(`/solicitacoes/${s1.idSolicitacao}`)).status).toBe(404);
    expect((await api(estranho).get(`/solicitacoes/${s1.idSolicitacao}/mensagens`)).status).toBe(404);
    expect((await api(estranho).post(`/solicitacoes/${s1.idSolicitacao}/mensagens`).send({ texto: 'Oi' })).status).toBe(404);
    expect((await api(estranho).patch(`/solicitacoes/${s1.idSolicitacao}/confirmar`)).status).toBe(404);
    expect((await api(estranho).get(`/anuncios/${anuncio.idAnuncio}/solicitacoes`)).status).toBe(403);
    expect((await api(estranho).put(`/anuncios/${anuncio.idAnuncio}`).send(dadosAnuncio())).status).toBe(403);
    expect((await api(estranho).patch(`/anuncios/${anuncio.idAnuncio}/status`).send({ status: 'pausado' })).status).toBe(403);
    expect((await api(estranho).delete(`/anuncios/${anuncio.idAnuncio}`)).status).toBe(403);
    expect((await api(escolhido).patch(`/solicitacoes/${s1.idSolicitacao}/recusar`)).status).toBe(403);
    expect((await api(dono).patch(`/solicitacoes/${s1.idSolicitacao}/cancelar`)).status).toBe(403);

    // 9. Um lado só não cria partida.
    const lado1 = await api(dono).patch(`/solicitacoes/${s1.idSolicitacao}/confirmar`);
    expect(lado1.status).toBe(200);
    expect(lado1.body.data).toMatchObject({ status: 'pendente', confirmadoAnunciante: true, confirmadoSolicitante: false, idPartida: null });

    // 10. Os dois lados concordam.
    const lado2 = await api(escolhido).patch(`/solicitacoes/${s1.idSolicitacao}/confirmar`);
    expect(lado2.status).toBe(200);
    expect(lado2.body.data.status).toBe('confirmada');
    const idPartida = lado2.body.data.idPartida;
    expect(idPartida).toBeTruthy();

    const partida = (await api(dono).get(`/partidas/${idPartida}`)).body.data;
    expect(partida).toMatchObject({ status: 'confirmada', nomeLocal: 'Campo de Teste', modalidade: { codigo: 'society' } });
    expect(partida.timeAnunciante.idTime).toBe(dono.idTime);
    expect(partida.timeAdversario.idTime).toBe(escolhido.idTime);
    expect((await api(escolhido).get('/partidas/proxima')).body.data.idPartida).toBe(idPartida);
    expect((await api(estranho).get(`/partidas/${idPartida}`)).status).toBe(404);

    // 11. Demais solicitações encerradas; anúncio indisponível.
    for (const [capitao, s] of [[perdedor1, s2], [perdedor2, s3]] as const) {
      expect((await api(capitao).get(`/solicitacoes/${s.idSolicitacao}`)).body.data.status).toBe('encerrada');
    }
    expect((await api(dono).get(`/anuncios/${anuncio.idAnuncio}`)).body.data.status).toBe('encerrado');
    expect((await api(estranho).get('/anuncios?limite=100')).body.data.some((a: any) => a.idAnuncio === anuncio.idAnuncio)).toBe(false);

    // 12. Capitães não selecionados notificados; o escolhido não.
    for (const capitao of [perdedor1, perdedor2]) {
      const n = (await api(capitao).get('/notificacoes')).body.data.filter((x: any) => x.tipo === 'solicitacao_encerrada');
      expect(n).toHaveLength(1);
      expect(n[0].mensagem).toContain('confirmou partida com outro time');
      expect(n[0].lida).toBe(false);
    }
    const doEscolhido = (await api(escolhido).get('/notificacoes')).body.data.map((n: any) => n.tipo);
    expect(doEscolhido).toContain('partida_confirmada');
    expect(doEscolhido).not.toContain('solicitacao_encerrada');

    // Notificação: só o destinatário marca.
    const alvo = (await api(perdedor1).get('/notificacoes')).body.data[0];
    expect((await api(estranho).patch(`/notificacoes/${alvo.idNotificacao}/lida`)).status).toBe(404);
    expect((await api(perdedor1).patch(`/notificacoes/${alvo.idNotificacao}/lida`)).status).toBe(204);
    expect((await api(perdedor1).get('/notificacoes')).body.data.find((n: any) => n.idNotificacao === alvo.idNotificacao).lida).toBe(true);

    // 13. Anúncio encerrado não aceita solicitações.
    const tardia = await api(estranho).post('/solicitacoes').send({ idAnuncio: anuncio.idAnuncio });
    expect(tardia.status).toBe(409);
    expect(tardia.body.error.message).toContain('não está disponível');

    // 14. Sem confirmação duplicada.
    expect((await api(perdedor1).patch(`/solicitacoes/${s2.idSolicitacao}/confirmar`)).status).toBe(409);
    expect((await api(dono).patch(`/solicitacoes/${s2.idSolicitacao}/confirmar`)).status).toBe(409);
    expect((await api(dono).patch(`/solicitacoes/${s1.idSolicitacao}/confirmar`)).status).toBe(409);
    const [partidas] = await pool.query('SELECT id_partida FROM partidas WHERE id_anuncio = ?', [anuncio.idAnuncio]);
    expect(partidas).toHaveLength(1);

    // Anúncio com partida não pode ser excluído nem reaberto.
    expect((await api(dono).delete(`/anuncios/${anuncio.idAnuncio}`)).status).toBe(409);
    expect((await api(dono).patch(`/anuncios/${anuncio.idAnuncio}/status`).send({ status: 'ativo' })).status).toBe(409);

    // Cancelamento avisa o outro capitão; anúncio continua encerrado.
    expect((await api(estranho).patch(`/partidas/${idPartida}/cancelar`).send({})).status).toBe(404);
    const cancelada = await api(escolhido).patch(`/partidas/${idPartida}/cancelar`).send({ motivo: 'Chuva' });
    expect(cancelada.status).toBe(200);
    expect(cancelada.body.data.status).toBe('cancelada');
    expect((await api(dono).get('/notificacoes')).body.data.map((n: any) => n.tipo)).toContain('partida_cancelada');
    expect((await api(dono).get(`/anuncios/${anuncio.idAnuncio}`)).body.data.status).toBe('encerrado');
  });

  it('14. confirmações simultâneas de solicitações diferentes geram uma só partida', async () => {
    const dono = await novoCapitao('Concorrência');
    for (let rodada = 0; rodada < 10; rodada++) {
      const a = await novoCapitao(`Rival A${rodada}`);
      const b = await novoCapitao(`Rival B${rodada}`);
      const anuncio = await publicar(dono);
      const sa = await solicitar(a, anuncio.idAnuncio);
      const sb = await solicitar(b, anuncio.idAnuncio);
      await api(a).patch(`/solicitacoes/${sa.idSolicitacao}/confirmar`).expect(200);
      await api(b).patch(`/solicitacoes/${sb.idSolicitacao}/confirmar`).expect(200);

      const respostas = await Promise.all([
        api(dono).patch(`/solicitacoes/${sa.idSolicitacao}/confirmar`),
        api(dono).patch(`/solicitacoes/${sb.idSolicitacao}/confirmar`),
      ]);
      expect(respostas.map((r) => r.status).sort()).toEqual([200, 409]);
      const [partidas] = await pool.query('SELECT id_partida FROM partidas WHERE id_anuncio = ?', [anuncio.idAnuncio]);
      expect(partidas).toHaveLength(1);
      const [confirmadas] = await pool.query(
        "SELECT id_solicitacao FROM solicitacoes_confronto WHERE id_anuncio = ? AND status = 'confirmada'",
        [anuncio.idAnuncio],
      );
      expect(confirmadas).toHaveLength(1);
    }
  }, 60_000);

  it('recusa, desistência e exclusão de anúncio notificam corretamente', async () => {
    const dono = await novoCapitao('Recusa');
    const a = await novoCapitao('Recusado');
    const b = await novoCapitao('Desistente');
    const c = await novoCapitao('Pendente');
    const anuncio = await publicar(dono);
    const sa = await solicitar(a, anuncio.idAnuncio);
    const sb = await solicitar(b, anuncio.idAnuncio);
    const sc = await solicitar(c, anuncio.idAnuncio);

    expect((await api(dono).patch(`/solicitacoes/${sa.idSolicitacao}/recusar`)).body.data.status).toBe('recusada');
    expect((await api(a).get('/notificacoes')).body.data.map((n: any) => n.tipo)).toContain('solicitacao_recusada');
    expect((await api(b).patch(`/solicitacoes/${sb.idSolicitacao}/cancelar`)).body.data.status).toBe('cancelada');

    await api(dono).delete(`/anuncios/${anuncio.idAnuncio}`).expect(204);
    expect((await api(dono).get(`/anuncios/${anuncio.idAnuncio}`)).status).toBe(404);
    const encerrada = (await api(c).get(`/solicitacoes/${sc.idSolicitacao}`)).body.data;
    expect(encerrada.status).toBe('encerrada');
    expect(encerrada.anuncio.idAnuncio).toBe(anuncio.idAnuncio); // histórico preservado
    expect((await api(c).get('/notificacoes')).body.data.map((n: any) => n.tipo)).toContain('solicitacao_encerrada');
  });

  it('rotinas marcam partida realizada, expiram anúncio e liberam a avaliação', async (contexto) => {
    // Os procedimentos são globais: com registro antigo vencido, o cenário não roda.
    const preservados = await registrosPreservadosAfetados();
    if (preservados.anuncios + preservados.partidas > 0) {
      contexto.skip('Rotinas suspensas para não alterar registros preservados.');
    }

    const dono = await novoCapitao('Rotina');
    const rival = await novoCapitao('Rival Rotina');
    const emBreve = () => new Date(Date.now() + 1500).toISOString();
    const jogo = await publicar(dono, { dataHoraInicio: emBreve() });
    const vencido = await publicar(dono, { dataHoraInicio: emBreve() });
    const s = await solicitar(rival, jogo.idAnuncio);
    const pendente = await solicitar(rival, vencido.idAnuncio);
    await api(dono).patch(`/solicitacoes/${s.idSolicitacao}/confirmar`).expect(200);
    const { idPartida } = (await api(rival).patch(`/solicitacoes/${s.idSolicitacao}/confirmar`).expect(200)).body.data;

    const notas = [1, 2, 3, 4].map((idCriterio) => ({ idCriterio, nota: 5 }));
    expect((await api(dono).post(`/partidas/${idPartida}/avaliacoes`).send({ notas })).status).toBe(409);

    await new Promise((fim) => setTimeout(fim, 1800));
    await executarRotinas();

    expect((await api(dono).get(`/partidas/${idPartida}`)).body.data.status).toBe('realizada');
    expect((await api(dono).get(`/anuncios/${vencido.idAnuncio}`)).body.data.status).toBe('expirado');
    expect((await api(rival).get(`/solicitacoes/${pendente.idSolicitacao}`)).body.data.status).toBe('encerrada');
    expect((await api(dono).get('/notificacoes')).body.data.map((n: any) => n.tipo)).toContain('avaliacao_pendente');

    expect((await api(dono).post(`/partidas/${idPartida}/avaliacoes`).send({ notas: notas.slice(1) })).status).toBe(400);
    const avaliacao = await api(dono).post(`/partidas/${idPartida}/avaliacoes`).send({ notas, comentario: 'Pontuais.' });
    expect(avaliacao.status).toBe(201);
    expect((await api(dono).post(`/partidas/${idPartida}/avaliacoes`).send({ notas })).status).toBe(409);

    expect((await api(dono).get(`/partidas/${idPartida}`)).body.data.avaliadaPeloMeuTime).toBe(true);
    expect((await api(rival).get(`/partidas/${idPartida}`)).body.data.avaliadaPeloMeuTime).toBe(false);
    const recebidas = (await api(dono).get(`/times/${rival.idTime}/avaliacoes`)).body.data;
    expect(recebidas[0]).toMatchObject({ notaMedia: 5, comentario: 'Pontuais.' });
    const perfil = (await api(dono).get(`/times/${rival.idTime}`)).body.data;
    expect(perfil).toMatchObject({ totalPartidasRealizadas: 1, totalAvaliacoes: 1, mediaAvaliacao: 5 });
  });

  it('recuperação de senha: não revela e-mail e o código é de uso único', async () => {
    const email = `teste.homologacao.${randomUUID()}@example.com`;
    await api().post('/auth/cadastro').send({
      usuario: { nome: 'X', email, senha: SENHA },
      time: { nome: 'Y', idsModalidades: [1], idCategoriaEtaria: LIVRE, quantidadeJogadores: 10, cidade: 'Z', siglaEstado: 'SP' },
    }).expect(201);
    expect((await api().post('/auth/recuperar-senha').send({ email })).status).toBe(202);
    expect((await api().post('/auth/recuperar-senha').send({ email: 'ninguem@example.com' })).status).toBe(202);
    const [[{ total }]] = await pool.query(
      'SELECT COUNT(*) AS total FROM codigos_recuperacao_senha c JOIN usuarios u USING (id_usuario) WHERE u.email = ?',
      [email],
    );
    expect(total).toBe(1);
    expect((await api().post('/auth/redefinir-senha').send({ codigo: 'x'.repeat(64), novaSenha: 'nova-senha-123' })).status).toBe(400);

    const codigo = codigosEnviados.at(-1);
    const novaSenha = 'nova-senha-123';
    expect((await api().post('/auth/redefinir-senha').send({ codigo, novaSenha })).status).toBe(204);
    expect((await api().post('/auth/login').send({ email, senha: SENHA })).status).toBe(401);
    expect((await api().post('/auth/login').send({ email, senha: novaSenha })).status).toBe(200);
    expect((await api().post('/auth/redefinir-senha').send({ codigo, novaSenha: 'outra-senha-123' })).status).toBe(400);
  });

  it('não grava datas fora de UTC', async () => {
    const c = await novoCapitao('Fuso');
    const [[{ diferenca }]] = await pool.query(
      'SELECT ABS(TIMESTAMPDIFF(MINUTE, data_criacao, UTC_TIMESTAMP())) AS diferenca FROM times WHERE id_time = ?',
      [c.idTime],
    );
    expect(diferenca).toBeLessThan(2);
  });
});
