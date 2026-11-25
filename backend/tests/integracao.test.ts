import { randomUUID } from 'node:crypto';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { PNG_1X1 } from './dados-teste.js';

/**
 * Integração API + MySQL. Grava dados fictícios (teste.homologacao.*@example.com) de verdade, por
 * isso só roda com TESTE_INTEGRACAO=1 e, no servidor padrão (3306), também com
 * TESTE_BANCO_REAL_AUTORIZADO=1 e ROTINAS_PRESERVAR_ATE. Os registros criados permanecem no banco.
 */
// Imagens enviadas nos testes não vão para a pasta real de arquivos.
process.env.ARQUIVOS_DIR = mkdtempSync(path.join(tmpdir(), 'joga-arquivos-teste-'));

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

  type Capitao = { token: string; idUsuario: string; idTime: string; nomeTime: string; email: string };

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
    const email = `teste.homologacao.${randomUUID()}@example.com`;
    const r = await api().post('/auth/cadastro').send({
      usuario: {
        nome: `Capitão ${nomeTime}`,
        email,
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
    return { token: r.body.data.token, idUsuario: r.body.data.usuario.idUsuario, idTime: r.body.data.time.idTime, nomeTime, email };
  }

  const dadosAnuncio = (extra: Record<string, unknown> = {}) => ({
    idModalidade: SOCIETY,
    idCategoriaEtaria: LIVRE,
    idNivelTecnico: INTERMEDIARIO,
    idMandoCampo: 1,
    quantidadeJogadores: 7,
    dataHoraInicio: new Date(Date.now() + 7 * 86_400_000).toISOString(),
    duracaoMinutos: 90,
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
    expect(data.modalidades.map((m: any) => m.nome)).toEqual([
      'Society/Futebol Sintético', 'Futsal', 'Futebol de Campo', 'Futebol de Campo Reduzido',
    ]);
    expect(data.modalidades.map((m: any) => m.codigo)).toEqual(['society', 'futsal', 'campo', 'campo_reduzido']);
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

  it('cadastro sem telefone, modalidade, categoria, nível e quantidade: o jogo define esses dados', async () => {
    const r = await api().post('/auth/cadastro').send({
      usuario: { nome: 'Capitão Mínimo', email: `teste.homologacao.${randomUUID()}@example.com`, senha: SENHA },
      time: { nome: 'Mínimo FC', cidade: 'Campinas', siglaEstado: 'SP' },
    });
    expect(r.status).toBe(201);
    expect(r.body.data.usuario.telefone).toBeNull();
    expect(r.body.data.time).toMatchObject({
      modalidades: [], categoriaEtaria: null, nivelTecnico: null, quantidadeJogadores: null, telefoneContato: null,
    });
    const perfil = await api(r.body.data as Capitao).get(`/times/${r.body.data.time.idTime}`);
    expect(perfil.status).toBe(200); // continua visível no perfil público
    const c = { token: r.body.data.token } as Capitao;
    const anuncio = await publicar(c, { idModalidade: QUADRA, idCategoriaEtaria: SUB_17, idNivelTecnico: INTERMEDIARIO });
    expect(anuncio).toMatchObject({
      modalidade: { id: QUADRA }, categoriaEtaria: { id: SUB_17 }, nivelTecnico: { id: INTERMEDIARIO }, quantidadeJogadores: 7,
    });
  });

  it('foto do time: envio, validação, troca e visibilidade para outros times', async () => {
    const dono = await novoCapitao('Foto');
    const outro = await novoCapitao('Visitante Foto');
    const enviar = (c: Capitao | undefined, tipo: string, corpo: Buffer, alvo = dono.idTime) =>
      api(c).put(`/times/${alvo}/escudo`).set('Content-Type', tipo).send(corpo);

    expect((await enviar(undefined, 'image/png', PNG_1X1)).status).toBe(401);
    expect((await enviar(outro, 'image/png', PNG_1X1)).status).toBe(403);
    expect((await enviar(dono, 'text/plain', Buffer.from('oi'))).status).toBe(415);
    expect((await enviar(dono, 'image/png', Buffer.from('não é imagem'))).status).toBe(400);
    const grande = Buffer.concat([PNG_1X1, Buffer.alloc(2 * 1024 * 1024)]);
    const recusada = await enviar(dono, 'image/png', grande);
    expect(recusada.status).toBe(413);
    expect(recusada.body.error.code).toBe('PAYLOAD_TOO_LARGE');
    // Nenhuma falha trocou a foto (ainda sem foto).
    expect((await api(dono).get(`/times/${dono.idTime}`)).body.data.urlEscudo).toBeNull();

    const primeira = await enviar(dono, 'image/png', PNG_1X1);
    expect(primeira.status).toBe(200);
    const url1: string = primeira.body.data.urlEscudo;
    expect(url1).toMatch(new RegExp(`^/api/arquivos/escudos/${dono.idTime}-[0-9a-f-]{36}\.png$`));
    const arquivo = await request(app).get(url1);
    expect(arquivo.status).toBe(200);
    expect(arquivo.headers['content-type']).toBe('image/png');
    expect(Buffer.from(arquivo.body)).toEqual(PNG_1X1);

    // Outro capitão, em outra sessão, vê a mesma foto.
    expect((await api(outro).get(`/times/${dono.idTime}`)).body.data.urlEscudo).toBe(url1);

    // Trocar a foto apaga o arquivo antigo.
    const jpeg = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(64)]);
    const url2: string = (await enviar(dono, 'image/jpeg', jpeg)).body.data.urlEscudo;
    expect(url2).toMatch(/\.jpg$/);
    expect((await request(app).get(url1)).status).toBe(404);
    expect((await request(app).get(url2)).status).toBe(200);
    expect((await api(dono).get('/auth/eu')).body.data.time.urlEscudo).toBe(url2); // reabrir o app
  });

  it('descrição do time: salvar, ver em outra sessão e remover', async () => {
    const dono = await novoCapitao('Descrição');
    const outro = await novoCapitao('Leitor Descrição');
    const texto = 'Time de amigos desde 2010. Jogamos limpo e chegamos no horário.';
    const salvo = await api(dono).patch(`/times/${dono.idTime}`).send({ descricao: `  ${texto}  ` });
    expect(salvo.body.data.descricao).toBe(texto);
    expect((await api(outro).get(`/times/${dono.idTime}`)).body.data.descricao).toBe(texto);
    expect((await api(dono).get('/auth/eu')).body.data.time.descricao).toBe(texto);
    expect((await api(dono).patch(`/times/${dono.idTime}`).send({ descricao: 'x'.repeat(2001) })).status).toBe(400);
    expect((await api(outro).patch(`/times/${dono.idTime}`).send({ descricao: 'invasão' })).status).toBe(403);
    const vazia = await api(dono).patch(`/times/${dono.idTime}`).send({ descricao: '   ' });
    expect(vazia.body.data.descricao).toBeNull();
  });

  it('acentos: nome do time e "Sobre o time" ficam intactos', async () => {
    const nomes = ['Time Taboão da Serra', 'Vilson Prato Feito', 'São Paulo', 'União Esportiva'];
    for (const nome of nomes) {
      const r = await api().post('/auth/cadastro').send({
        usuario: { nome: 'Capitão João', email: `teste.homologacao.${randomUUID()}@example.com`, senha: SENHA },
        time: { nome, cidade: 'Taboão da Serra', siglaEstado: 'SP' },
      });
      expect(r.status).toBe(201);
      expect(r.body.data.time.nome).toBe(nome);
      expect(r.body.data.usuario.nome).toBe('Capitão João');
    }
    const c = await novoCapitao('Acentuação');
    const frase = 'Somos uma equipe de amigos apaixonados por futebol, união e competição saudável.';
    expect((await api(c).patch(`/times/${c.idTime}`).send({ descricao: frase })).body.data.descricao).toBe(frase);
    // Reabrir o app (sessão) e outro capitão leem o mesmo texto.
    expect((await api(c).get('/auth/eu')).body.data.time.descricao).toBe(frase);
    // No banco, em UTF-8 de verdade ("ã" = C3 A3, "ç" = C3 A7).
    const [[linha]] = await pool.query('SELECT HEX(descricao) h FROM times WHERE id_time = ?', [c.idTime]);
    expect(linha.h).toContain('C3A3'); // ã
    expect(linha.h).toContain('C3A7'); // ç
    // "ã" enviado decomposto (a + til, NFD) é gravado composto (NFC).
    const nfd = 'Taboão FC';
    const editado = await api(c).patch(`/times/${c.idTime}`).send({ nome: nfd });
    expect(editado.body.data.nome).toBe('Taboão FC');
    expect(editado.body.data.nome).toHaveLength(9);
  });

  it('as quatro modalidades no anúncio e na busca', async () => {
    const dono = await novoCapitao('Modalidades');
    const leitor = await novoCapitao('Leitor Modalidades');
    const refs = (await api().get('/referencias')).body.data.modalidades;
    const marca = `Mod${randomUUID().slice(0, 8)}`;
    for (const m of refs) {
      const a = await publicar(dono, { idModalidade: m.id, nomeLocal: `${marca} ${m.codigo}` });
      expect(a.modalidade.nome).toBe(m.nome);
      const achados = (await api(leitor).get(`/anuncios?limite=100&texto=${marca}&idModalidade=${m.id}`)).body.data;
      expect(achados.map((x: any) => x.modalidade.codigo)).toEqual([m.codigo]);
    }
  });

  it('horário: 21:00 do anúncio aparece 21:00 para todos (cenário Arena Biase)', async () => {
    const dono = await novoCapitao('Vilson Homologação');
    const desafiante = await novoCapitao('Joga Homologação');
    const marca = `Biase${randomUUID().slice(0, 8)}`;
    const criado = await api(dono).post('/anuncios').send({
      ...dadosAnuncio({ cidade: 'Cascavel', siglaEstado: 'PR', nomeLocal: `Arena ${marca}` }),
      dataHoraInicio: undefined,
      dataHoraLocal: '2026-11-26T21:00',
    });
    expect(criado.status).toBe(201);
    const local = { dataHoraLocal: '2026-11-26T21:00:00', fusoHorario: 'America/Sao_Paulo' };
    expect(criado.body.data).toMatchObject(local);
    // No banco: o instante certo (21:00 em Brasília = 00:00 UTC do dia 27).
    const [[gravado]] = await pool.query(
      "SELECT DATE_FORMAT(data_hora_inicio, '%Y-%m-%d %H:%i') d FROM anuncios_partidas WHERE id_anuncio = ?",
      [criado.body.data.idAnuncio],
    );
    expect(gravado.d).toBe('2026-11-27 00:00');

    // O desafiante vê 21:00 na busca e nos detalhes, e os filtros usam o horário local.
    const busca = (f: string) => api(desafiante).get(`/anuncios?limite=100&texto=${marca}${f}`);
    expect((await busca('')).body.data[0]).toMatchObject(local);
    expect((await busca('&data=2026-11-26&horario=21:00')).body.data).toHaveLength(1);
    expect((await busca('&data=2026-11-27')).body.data).toHaveLength(0);
    expect((await busca('&horario=21:01')).body.data).toHaveLength(0);
    expect((await api(desafiante).get(`/anuncios/${criado.body.data.idAnuncio}`)).body.data).toMatchObject(local);

    // Solicitação e partida também em 21:00, para os dois.
    const s = await solicitar(desafiante, criado.body.data.idAnuncio);
    expect(s.anuncio).toMatchObject(local);
    const { idPartida } = (await api(dono).patch(`/solicitacoes/${s.idSolicitacao}/confirmar`).expect(200)).body.data;
    for (const c of [dono, desafiante]) {
      expect((await api(c).get(`/partidas/${idPartida}`)).body.data).toMatchObject(local);
      expect((await api(c).get(`/solicitacoes/${s.idSolicitacao}`)).body.data.anuncio).toMatchObject(local);
    }
  });

  it('chat: enviada → entregue → visualizada, persistido e só para os dois capitães', async () => {
    const dono = await novoCapitao('Dono Indicadores');
    const desafiante = await novoCapitao('Desafiante Indicadores');
    const terceiro = await novoCapitao('Terceiro Indicadores');
    const anuncio = await publicar(dono);
    const s = await solicitar(desafiante, anuncio.idAnuncio);
    await api(dono).patch(`/solicitacoes/${s.idSolicitacao}/confirmar`).expect(200);
    const conversa = `/solicitacoes/${s.idSolicitacao}/mensagens`;

    // 1 e 2. Enviada.
    const enviada = await api(desafiante).post(conversa).send({ texto: 'Bora às 21h?' });
    expect(enviada.status).toBe(201);
    expect(enviada.body.data).toMatchObject({ status: 'enviada', dataEntrega: null, dataLeitura: null });

    // O remetente sincronizar ou reabrir a conversa não muda o estado da própria mensagem.
    await api(desafiante).get('/solicitacoes/sincronizar').expect(200);
    expect((await api(desafiante).get(conversa)).body.data[0].status).toBe('enviada');

    // 3. Entregue: o app do dono sincroniza (sem abrir a conversa). Entrega não é leitura.
    const sync = await api(dono).get('/solicitacoes/sincronizar');
    expect(sync.body.data.mensagensNaoLidas).toBeGreaterThanOrEqual(1);
    expect((await api(desafiante).get(conversa)).body.data[0]).toMatchObject({ status: 'entregue', dataLeitura: null });
    const [[gravado]] = await pool.query('SELECT data_entrega, data_leitura FROM mensagens WHERE id_mensagem = ?', [enviada.body.data.idMensagem]);
    expect(gravado.data_entrega).not.toBeNull();
    expect(gravado.data_leitura).toBeNull();

    // 4 e 5. O dono abre a conversa: visualizada para o remetente.
    await api(dono).get(conversa).expect(200);
    const visto = (await api(desafiante).get(conversa)).body.data[0];
    expect(visto.status).toBe('visualizada');
    expect(new Date(visto.dataLeitura).getTime()).toBeGreaterThanOrEqual(new Date(visto.dataEntrega).getTime());

    // Abrir a conversa marca também a entrega, se ainda não constava.
    const resposta = await api(dono).post(conversa).send({ texto: 'Fechado!' });
    await api(desafiante).get(conversa).expect(200);
    const doDono = (await api(dono).get(conversa)).body.data.find((m: any) => m.idMensagem === resposta.body.data.idMensagem);
    expect(doDono).toMatchObject({ status: 'visualizada' });
    expect(doDono.dataEntrega).not.toBeNull();

    // 6. Terceiros não acessam nem sincronizam mensagens alheias.
    expect((await api(terceiro).get(conversa)).status).toBe(404);
    expect((await api(terceiro).post(conversa).send({ texto: 'Oi' })).status).toBe(404);
    expect((await api(terceiro).get('/solicitacoes/sincronizar')).body.data.mensagensNaoLidas).toBe(0);

    // 7. Persistência: outra sessão (novo login) vê os mesmos estados.
    const login = await api().post('/auth/login').send({ email: desafiante.email, senha: SENHA });
    const outraSessao = { ...desafiante, token: login.body.data.token };
    expect((await api(outraSessao).get(conversa)).body.data.map((m: any) => m.status)).toEqual(['visualizada', 'visualizada']);

    // Leitura é registrada uma única vez (gatilho do banco).
    await expect(
      pool.execute('UPDATE mensagens SET data_leitura = UTC_TIMESTAMP(3) WHERE id_mensagem = ?', [enviada.body.data.idMensagem]),
    ).rejects.toMatchObject({ code: 'ER_SIGNAL_EXCEPTION' });
  });

  it('meus desafios: só anúncios de outros times em que o meu time pediu desafio', async () => {
    const eu = await novoCapitao('Eu Desafios');
    const outro = await novoCapitao('Outro Desafios');
    const terceiro = await novoCapitao('Terceiro Desafios');
    const meu = await publicar(eu);
    const alvo = await publicar(outro);
    const semPedido = await publicar(terceiro);
    const s = await solicitar(eu, alvo.idAnuncio);
    await solicitar(outro, meu.idAnuncio); // alguém desafiou o meu anúncio

    const desafios = (await api(eu).get('/solicitacoes/minhas?papel=solicitante')).body.data;
    expect(desafios.map((x: any) => x.idSolicitacao)).toEqual([s.idSolicitacao]);
    expect(desafios[0].anuncio.idAnuncio).toBe(alvo.idAnuncio);
    expect(desafios.some((x: any) => x.anuncio.idAnuncio === semPedido.idAnuncio)).toBe(false);
    const recebidas = (await api(eu).get('/solicitacoes/minhas?papel=anunciante')).body.data;
    expect(recebidas.map((x: any) => x.anuncio.idAnuncio)).toEqual([meu.idAnuncio]);
    expect((await api(eu).get('/solicitacoes/minhas?papel=outro')).status).toBe(400);

    // Estado acompanha aceite e cancelamento da partida.
    const { idPartida } = (await api(outro).patch(`/solicitacoes/${s.idSolicitacao}/confirmar`).expect(200)).body.data;
    expect((await api(eu).get('/solicitacoes/minhas?papel=solicitante')).body.data[0]).toMatchObject({ status: 'confirmada', idPartida });
    await api(eu).patch(`/partidas/${idPartida}/cancelar`).send({ motivo: 'Teste' }).expect(200);
    expect((await api(eu).get(`/partidas/${idPartida}`)).body.data.status).toBe('cancelada');
    expect((await api(eu).get('/anuncios/meus')).body.data.map((a: any) => a.idAnuncio)).toEqual([meu.idAnuncio]);
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
    expect(r.body.data.modalidades.map((m: any) => m.codigo)).toEqual(['futsal']);
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

  it('anúncio do formulário novo: sem categoria, quantidade, mando e bairro; com duração e local', async () => {
    const dono = await novoCapitao('Anúncio Novo');
    const leitor = await novoCapitao('Leitor Anúncio Novo');
    const rival = await novoCapitao('Rival Anúncio Novo');
    const marca = `Arena${randomUUID().slice(0, 8)}`;
    const novo = {
      idModalidade: QUADRA,
      idNivelTecnico: INICIANTE,
      dataHoraInicio: new Date(Date.now() + 9 * 86_400_000).toISOString(),
      duracaoMinutos: 75,
      cidade: 'Santos',
      siglaEstado: 'SP',
      nomeLocal: marca,
      endereco: 'Avenida Senador Pinheiro Machado, 240 - Marapé',
      latitude: -23.9596,
      longitude: -46.3392,
    };
    const criado = await api(dono).post('/anuncios').send(novo);
    expect(criado.status).toBe(201);
    expect(criado.body.data).toMatchObject({
      categoriaEtaria: null, quantidadeJogadores: null, mandoCampo: null, bairro: null,
      duracaoMinutos: 75, endereco: novo.endereco, latitude: -23.9596, longitude: -46.3392,
    });

    // Continua na busca (LEFT JOIN) e sai com o filtro de categoria (só anúncios antigos têm).
    const busca = (f = '') => api(leitor).get(`/anuncios?limite=100&texto=${marca}${f}`);
    expect((await busca()).body.data.map((a: any) => a.duracaoMinutos)).toEqual([75]);
    expect((await busca(`&idCategoriaEtaria=${LIVRE}`)).body.data).toEqual([]);

    // Duração obrigatória e dentro dos limites; coordenadas sempre em par.
    const { duracaoMinutos: _sem, ...semDuracao } = novo;
    expect((await api(dono).post('/anuncios').send(semDuracao)).status).toBe(400);
    expect((await api(dono).post('/anuncios').send({ ...novo, duracaoMinutos: 0 })).status).toBe(400);
    expect((await api(dono).post('/anuncios').send({ ...novo, duracaoMinutos: 601 })).status).toBe(400);
    expect((await api(dono).post('/anuncios').send({ ...novo, longitude: null })).status).toBe(400);

    // A partida sai de um anúncio sem quantidade (coluna da partida aceita nulo).
    const s = await solicitar(rival, criado.body.data.idAnuncio);
    const { idPartida } = (await api(dono).patch(`/solicitacoes/${s.idSolicitacao}/confirmar`).expect(200)).body.data;
    const [[copia]] = await pool.query('SELECT quantidade_jogadores FROM partidas WHERE id_partida = ?', [idPartida]);
    expect(copia.quantidade_jogadores).toBeNull();
    expect((await api(rival).get(`/partidas/${idPartida}`)).body.data).toMatchObject({
      status: 'confirmada', nomeLocal: marca,
    });
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
    expect(refs.modalidades).toHaveLength(4);

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

    // Chat 1 a 5: com a solicitação pendente, nem B (escolhido) nem A (dono)
    // abrem, leem ou enviam mensagens.
    const mensagens = `/solicitacoes/${s1.idSolicitacao}/mensagens`;
    for (const capitao of [escolhido, dono]) {
      const ler = await api(capitao).get(mensagens);
      expect(ler.status).toBe(403);
      expect(ler.body.error.code).toBe('CHAT_BLOQUEADO');
      expect((await api(capitao).post(mensagens).send({ texto: 'Sábado às 16h?' })).status).toBe(403);
      expect((await api(capitao).get(`/solicitacoes/${s1.idSolicitacao}`)).body.data).toMatchObject({
        chatLiberado: false, ultimaMensagem: null, mensagensNaoLidas: 0,
      });
    }
    // O banco também recusa, mesmo gravando direto (gatilho).
    await expect(
      pool.execute(
        `INSERT INTO mensagens (id_mensagem, id_solicitacao, id_time_remetente, id_usuario_remetente, texto)
         VALUES (?, ?, ?, ?, 'Direto no banco')`,
        [randomUUID(), s1.idSolicitacao, escolhido.idTime, escolhido.idUsuario],
      ),
    ).rejects.toMatchObject({ code: 'ER_SIGNAL_EXCEPTION' });

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

    // 9. O desafiante não aceita a própria solicitação: só o dono do anúncio.
    const indevido = await api(escolhido).patch(`/solicitacoes/${s1.idSolicitacao}/confirmar`);
    expect(indevido.status).toBe(403);
    expect((await api(escolhido).get(`/solicitacoes/${s1.idSolicitacao}`)).body.data.status).toBe('pendente');

    // 10. Chat 6: o dono aceita; a partida é confirmada (o pedido já era a
    // concordância do desafiante) e o chat é liberado.
    const aceite = await api(dono).patch(`/solicitacoes/${s1.idSolicitacao}/confirmar`);
    expect(aceite.status).toBe(200);
    expect(aceite.body.data).toMatchObject({
      status: 'confirmada', confirmadoAnunciante: true, confirmadoSolicitante: true, chatLiberado: true,
    });
    const idPartida = aceite.body.data.idPartida;
    expect(idPartida).toBeTruthy();

    // Chat 7 e 8: os dois capitães trocam mensagens.
    const m = await api(escolhido).post(mensagens).send({ texto: 'Sábado às 16h?' });
    expect(m.status).toBe(201);
    expect((await api(dono).get(`/solicitacoes/${s1.idSolicitacao}`)).body.data).toMatchObject({
      chatLiberado: true, ultimaMensagem: 'Sábado às 16h?', mensagensNaoLidas: 1,
    });
    expect((await api(dono).get(mensagens)).body.data).toHaveLength(1);
    expect((await api(dono).get(`/solicitacoes/${s1.idSolicitacao}`)).body.data.mensagensNaoLidas).toBe(0);
    expect((await api(dono).post(mensagens).send({ texto: 'Fechado!' })).status).toBe(201);
    expect((await api(escolhido).get(mensagens)).body.data.map((x: any) => x.texto)).toEqual(['Sábado às 16h?', 'Fechado!']);

    // Chat 9 e 10: terceiro time e times com solicitação (agora encerrada) não acessam.
    for (const capitao of [estranho, perdedor1]) {
      expect((await api(capitao).get(mensagens)).status).toBe(404);
      expect((await api(capitao).post(mensagens).send({ texto: 'Oi' })).status).toBe(404);
    }
    expect((await api(perdedor1).get(`/solicitacoes/${s2.idSolicitacao}/mensagens`)).status).toBe(403);

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
      expect(n[0].titulo).toBe('Solicitação encerrada');
      expect(n[0].mensagem).toContain('foi confirmado com outro time');
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
    expect((await api(perdedor1).patch(`/solicitacoes/${s2.idSolicitacao}/confirmar`)).status).toBe(403);
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

    // Chat 11: regra existente no cancelamento — a solicitação continua
    // confirmada, então a conversa segue só entre os dois capitães.
    expect((await api(dono).get(mensagens)).status).toBe(200);
    expect((await api(escolhido).post(mensagens).send({ texto: 'Remarcamos?' })).status).toBe(201);
    expect((await api(estranho).get(mensagens)).status).toBe(404);
  }, 30_000); // muitas chamadas (bcrypt no cadastro de 5 capitães)

  it('14. confirmações simultâneas de solicitações diferentes geram uma só partida', async () => {
    const dono = await novoCapitao('Concorrência');
    for (let rodada = 0; rodada < 10; rodada++) {
      const a = await novoCapitao(`Rival A${rodada}`);
      const b = await novoCapitao(`Rival B${rodada}`);
      const anuncio = await publicar(dono);
      const sa = await solicitar(a, anuncio.idAnuncio);
      const sb = await solicitar(b, anuncio.idAnuncio);

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
    // O aceite do dono confirma a partida.
    const { idPartida } = (await api(dono).patch(`/solicitacoes/${s.idSolicitacao}/confirmar`).expect(200)).body.data;

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

  // Recuperação de senha: tests/recuperacao-senha.integracao.test.ts (com servidor SMTP local).

  it('não grava datas fora de UTC', async () => {
    const c = await novoCapitao('Fuso');
    const [[{ diferenca }]] = await pool.query(
      'SELECT ABS(TIMESTAMPDIFF(MINUTE, data_criacao, UTC_TIMESTAMP())) AS diferenca FROM times WHERE id_time = ?',
      [c.idTime],
    );
    expect(diferenca).toBeLessThan(2);
  });

  // Cada cenário cria ~10 contas (bcrypt custo 12 cada): folga acima dos 5 s padrão.
  describe('aceite: outras solicitações do desafiante no mesmo dia e horário', { timeout: 15_000 }, () => {
    /** Data local (AAAA-MM-DD) daqui a `dias` dias. */
    const dia = (dias: number) => new Date(Date.now() + dias * 86_400_000).toISOString().slice(0, 10);
    const jogo = (dono: Capitao, local: string, uf = 'SP', cidade = 'São Paulo') =>
      publicar(dono, { dataHoraLocal: local, siglaEstado: uf, cidade });
    const estado = async (idSolicitacao: string) => {
      const [[l]] = await pool.query(
        'SELECT status, motivo_encerramento, data_resposta FROM solicitacoes_confronto WHERE id_solicitacao = ?',
        [idSolicitacao],
      );
      return l;
    };
    const aceitar = (dono: Capitao, s: { idSolicitacao: string }) =>
      api(dono).patch(`/solicitacoes/${s.idSolicitacao}/confirmar`);

    it('encerra só as pendentes do mesmo time na mesma data e hora local', async () => {
      const joga = await novoCapitao('JOGA Horário');
      const outro = await novoCapitao('Outro Time Horário');
      const donos = await Promise.all(['A', 'B', 'C', 'D', 'E', 'F', 'G'].map((x) => novoCapitao(`Dono ${x} Horário`)));
      const [donoA, donoB, donoC, donoD, donoE, donoF, donoG] = donos;
      const d = dia(12);
      const amanha = dia(13);
      const anuncios = {
        A: await jogo(donoA, `${d}T21:00`),
        B: await jogo(donoB, `${d}T21:00`),
        C: await jogo(donoC, `${d}T21:00`),
        D: await jogo(donoD, `${d}T19:00`), // mesmo dia, outro horário
        E: await jogo(donoE, `${amanha}T21:00`), // mesmo horário, outro dia
        // MS (UTC-4): 21:00 local é outro instante, mas a mesma data e hora local.
        F: await jogo(donoF, `${d}T21:00`, 'MS', 'Campo Grande'),
        // MS 20:00 é o mesmo instante de 21:00 em SP, mas outro horário local.
        G: await jogo(donoG, `${d}T20:00`, 'MS', 'Campo Grande'),
      };
      const s: Record<string, any> = {};
      for (const [k, a] of Object.entries(anuncios)) s[k] = await solicitar(joga, a.idAnuncio);
      const deOutroTime = await solicitar(outro, anuncios.B.idAnuncio);

      const aceito = (await aceitar(donoA, s.A).expect(200)).body.data;
      expect(aceito.status).toBe('confirmada');
      expect(aceito.idPartida).toBeTruthy();

      // B, C e F: encerradas automaticamente, com motivo, sem apagar.
      for (const k of ['B', 'C', 'F']) {
        const l = await estado(s[k].idSolicitacao);
        expect(l.status, k).toBe('encerrada');
        expect(l.motivo_encerramento, k).toBe('O time desafiante já tem partida confirmada neste dia e horário.');
        expect(l.data_resposta, k).not.toBeNull();
      }
      // Outro horário, outro dia, outro horário local e outro time: intactas.
      for (const k of ['D', 'E', 'G']) expect((await estado(s[k].idSolicitacao)).status, k).toBe('pendente');
      expect((await estado(deOutroTime.idSolicitacao)).status).toBe('pendente');
      expect((await estado(s.A.idSolicitacao)).status).toBe('confirmada');

      // Histórico em Meus Desafios: todas continuam lá, com o estado e o motivo.
      const meus = (await api(joga).get('/solicitacoes/minhas?papel=solicitante').expect(200)).body.data;
      expect(meus).toHaveLength(7);
      const porId = new Map(meus.map((x: any) => [x.idSolicitacao, x]));
      expect((porId.get(s.A.idSolicitacao) as any).status).toBe('confirmada');
      expect((porId.get(s.B.idSolicitacao) as any).status).toBe('encerrada');
      expect((porId.get(s.B.idSolicitacao) as any).motivoEncerramento).toMatch(/mesmo|neste dia e horário/);
      expect((porId.get(s.D.idSolicitacao) as any).motivoEncerramento).toBeNull();

      // Aviso só ao time que teve as solicitações encerradas (fase 2 das
      // notificações): o dono do anúncio B não é notificado.
      const avisoB = (await api(donoB).get('/notificacoes')).body.data.filter(
        (n: any) => n.tipo === 'solicitacao_encerrada' && n.idSolicitacao === s.B.idSolicitacao,
      );
      expect(avisoB).toEqual([]);
      const avisosJoga = (await api(joga).get('/notificacoes')).body.data.filter(
        (n: any) => n.tipo === 'solicitacao_encerrada',
      );
      expect(avisosJoga.map((n: any) => n.idSolicitacao).sort()).toEqual(
        [s.B, s.C, s.F].map((x) => x.idSolicitacao).sort(),
      );
      expect((await api(donoD).get('/notificacoes')).body.data.filter((n: any) => n.tipo === 'solicitacao_encerrada')).toEqual([]);

      // Aprovar uma encerrada: recusado, nada muda.
      const tentativa = await aceitar(donoB, s.B);
      expect(tentativa.status).toBe(409);
      expect(tentativa.body.error.code).toBe('BUSINESS_RULE');
      expect((await estado(s.B.idSolicitacao)).status).toBe('encerrada');
      // O dono de B ainda aceita o outro time.
      expect((await aceitar(donoB, deOutroTime).expect(200)).body.data.status).toBe('confirmada');

      // Outro horário do mesmo dia continua aceitável e não mexe em E nem G.
      expect((await aceitar(donoD, s.D).expect(200)).body.data.status).toBe('confirmada');
      for (const k of ['E', 'G']) expect((await estado(s[k].idSolicitacao)).status, k).toBe('pendente');
    });

    it('dois aceites simultâneos no mesmo horário: só um vale', async () => {
      for (let rodada = 0; rodada < 3; rodada++) {
        const joga = await novoCapitao(`JOGA Simultâneo ${rodada}`);
        const [donoH, donoI] = await Promise.all([novoCapitao(`Dono H ${rodada}`), novoCapitao(`Dono I ${rodada}`)]);
        const local = `${dia(14 + rodada)}T21:00`;
        const sH = await solicitar(joga, (await jogo(donoH, local)).idAnuncio);
        const sI = await solicitar(joga, (await jogo(donoI, local)).idAnuncio);

        const respostas = await Promise.all([aceitar(donoH, sH), aceitar(donoI, sI)]);
        expect(respostas.map((r) => r.status).sort(), `rodada ${rodada}`).toEqual([200, 409]);
        const estados = [await estado(sH.idSolicitacao), await estado(sI.idSolicitacao)].map((l) => l.status).sort();
        expect(estados).toEqual(['confirmada', 'encerrada']);
        const [[{ partidas }]] = await pool.query(
          "SELECT COUNT(*) AS partidas FROM partidas WHERE id_time_adversario = ? AND status = 'confirmada'",
          [joga.idTime],
        );
        expect(partidas).toBe(1);
      }
    });

    it('fn_inicio_local usa os mesmos fusos da API em todas as UFs', async () => {
      const { FUSO_POR_UF, deslocamentoMinutos } = await import('../src/services/fuso.js');
      const instante = Date.UTC(2026, 10, 27, 0, 0); // 26/11/2026 21:00 em SP
      for (const [uf, zona] of Object.entries(FUSO_POR_UF)) {
        const local = new Date(instante + deslocamentoMinutos(zona, instante) * 60_000);
        const esperado = local.toISOString().slice(0, 16).replace('T', ' ');
        const [[{ calculado }]] = await pool.query('SELECT fn_inicio_local(?, ?) AS calculado', [
          '2026-11-27 00:00:00.000',
          uf,
        ]);
        expect(calculado, uf).toBe(esperado);
      }
    });
  });
});
