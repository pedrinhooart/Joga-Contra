import { createHash, randomBytes, randomUUID } from 'node:crypto';
import request from 'supertest';
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from 'vitest';

/**
 * Push (FCM): dispositivos, fila de envio (outbox) e tratamento de falhas, com
 * MySQL real e um provedor de teste no lugar do Firebase. Grava contas
 * fictícias (teste.homologacao.*@example.com), que permanecem no banco.
 */
const ativo = process.env.TESTE_INTEGRACAO === '1';
if (ativo && (process.env.DB_PORT ?? '3306') === '3306' && process.env.TESTE_BANCO_REAL_AUTORIZADO !== '1') {
  throw new Error('Testes de integração bloqueados no servidor padrão: defina TESTE_BANCO_REAL_AUTORIZADO=1 para rodar nele.');
}

type Conta = { token: string; idUsuario: string; nomeTime: string; email: string };
type Envio = { tokens: string[]; mensagem: any };

/** Provedor de teste: guarda o que seria enviado; tokens e falhas sob controle. */
class ProvedorDeTeste {
  readonly nome = 'teste';
  envios: Envio[] = [];
  tokensInvalidos = new Set<string>();
  falhaGeral: Error | null = null;
  async enviar(tokens: string[], mensagem: any) {
    if (this.falhaGeral) throw this.falhaGeral;
    this.envios.push({ tokens, mensagem });
    return tokens.map((token) =>
      this.tokensInvalidos.has(token)
        ? { token, ok: false, tokenInvalido: true, erro: 'messaging/registration-token-not-registered' }
        : { token, ok: true },
    );
  }
}

const tokenFcm = () => `teste-${randomBytes(24).toString('base64url')}:APA91b${randomBytes(30).toString('base64url')}`;

describe.runIf(ativo)('push: dispositivos e fila de envio', () => {
  let app: any;
  let pool: any;
  let processar: (o?: { limite?: number; apenasUsuarios?: string[] }) => Promise<Record<string, number>>;
  let definirEnviador: (e: any) => void;
  let provedor: ProvedorDeTeste;
  const contas: string[] = [];

  async function novaConta(nomeTime: string): Promise<Conta> {
    const email = `teste.homologacao.${randomUUID()}@example.com`;
    const r = await request(app).post('/api/auth/cadastro').send({
      usuario: { nome: `Capitão ${nomeTime}`, email, senha: 'senha-de-teste-123', cidade: 'São Paulo', siglaEstado: 'SP' },
      time: { nome: nomeTime, idsModalidades: [1], idCategoriaEtaria: 4, cidade: 'São Paulo', siglaEstado: 'SP' },
    });
    expect(r.status).toBe(201);
    contas.push(r.body.data.usuario.idUsuario);
    return { token: r.body.data.token, idUsuario: r.body.data.usuario.idUsuario, nomeTime, email };
  }

  const api = (c: Conta) => ({
    get: (p: string) => request(app).get(`/api${p}`).set('Authorization', `Bearer ${c.token}`),
    put: (p: string) => request(app).put(`/api${p}`).set('Authorization', `Bearer ${c.token}`),
    post: (p: string) => request(app).post(`/api${p}`).set('Authorization', `Bearer ${c.token}`),
    patch: (p: string) => request(app).patch(`/api${p}`).set('Authorization', `Bearer ${c.token}`),
    delete: (p: string) => request(app).delete(`/api${p}`).set('Authorization', `Bearer ${c.token}`),
  });

  const registrar = (c: Conta, token: string, extra: Record<string, unknown> = {}) =>
    api(c).put('/dispositivos').send({ token, plataforma: 'android', permitido: true, ...extra });

  /** Desafio real: gera "Novo desafio recebido" (não lida) ao dono. */
  async function desafio(dono: Conta, visitante: Conta) {
    const anuncio = await api(dono).post('/anuncios').send({
      idModalidade: 1, idCategoriaEtaria: 4, idNivelTecnico: 2, idMandoCampo: 1, quantidadeJogadores: 7,
      dataHoraInicio: new Date(Date.now() + 9 * 86_400_000).toISOString(), duracaoMinutos: 90,
      cidade: 'São Paulo', siglaEstado: 'SP', bairro: 'Centro', nomeLocal: 'Arena Push',
    });
    expect(anuncio.status).toBe(201);
    const pedido = await api(visitante).post('/solicitacoes').send({ idAnuncio: anuncio.body.data.idAnuncio });
    expect(pedido.status).toBe(201);
    const [[n]] = await pool.query(
      "SELECT id_notificacao FROM notificacoes WHERE id_usuario_destinatario = ? AND tipo = 'solicitacao_recebida' ORDER BY data_criacao DESC LIMIT 1",
      [dono.idUsuario],
    );
    return { idSolicitacao: pedido.body.data.idSolicitacao as string, idNotificacao: n.id_notificacao as string, idAnuncio: anuncio.body.data.idAnuncio as string };
  }

  const envio = async (idNotificacao: string) =>
    (await pool.query('SELECT * FROM envios_push WHERE id_notificacao = ?', [idNotificacao]))[0][0];
  const dispositivo = async (token: string) =>
    (await pool.query('SELECT * FROM dispositivos_push WHERE token_fcm = ?', [token]))[0][0];
  const rodarFila = () => processar({ apenasUsuarios: contas });

  beforeAll(async () => {
    app = (await import('../src/app.js')).createApp();
    ({ pool } = await import('../src/config/db.js'));
    ({ processarFilaPush: processar, definirEnviadorPush: definirEnviador } = await import('../src/services/push.js'));
  });

  afterEach(() => {
    provedor = new ProvedorDeTeste();
    definirEnviador(provedor);
  });

  afterAll(async () => {
    definirEnviador?.(undefined);
    await pool?.end();
  });

  it('registra, renova e lista o aparelho; o token nunca volta pela API', async () => {
    provedor = new ProvedorDeTeste();
    definirEnviador(provedor);
    const a = await novaConta('Push Registro');
    const t1 = tokenFcm();
    const r1 = await registrar(a, t1);
    expect(r1.status).toBe(200);
    expect(r1.body.data).toMatchObject({ plataforma: 'android', permitido: true, ativo: true });
    expect(JSON.stringify(r1.body)).not.toContain(t1);
    // Repetir é idempotente.
    expect((await registrar(a, t1)).body.data.idDispositivo).toBe(r1.body.data.idDispositivo);

    // Renovação pelo FCM: mesmo aparelho, token novo.
    const t2 = tokenFcm();
    const r2 = await registrar(a, t2, { tokenAnterior: t1 });
    expect(r2.body.data.idDispositivo).toBe(r1.body.data.idDispositivo);
    expect(await dispositivo(t1)).toBeUndefined();
    expect(await dispositivo(t2)).toMatchObject({ id_usuario: a.idUsuario, ativo: 1 });

    const lista = await api(a).get('/dispositivos');
    expect(lista.body.data).toHaveLength(1);
    expect(JSON.stringify(lista.body)).not.toMatch(/teste-|APA91b/);

    // Validação e autenticação.
    for (const corpo of [{ token: 'curto', plataforma: 'android', permitido: true }, { token: tokenFcm(), plataforma: 'symbian', permitido: true }, { token: tokenFcm(), plataforma: 'android' }]) {
      expect((await api(a).put('/dispositivos').send(corpo)).status).toBe(400);
    }
    expect((await request(app).put('/api/dispositivos').send({ token: tokenFcm(), plataforma: 'android', permitido: true })).status).toBe(401);
  });

  it('token muda de conta quando outra pessoa entra no mesmo aparelho', async () => {
    const a = await novaConta('Push A');
    const b = await novaConta('Push B');
    const t = tokenFcm();
    await registrar(a, t);
    await registrar(b, t);
    const [linhas] = await pool.query('SELECT id_usuario FROM dispositivos_push WHERE token_fcm = ?', [t]);
    expect(linhas).toEqual([{ id_usuario: b.idUsuario }]);
    expect((await api(a).get('/dispositivos')).body.data).toEqual([]);
  });

  it('evento real: push aos dois aparelhos do dono, uma vez, com só identificadores', async () => {
    const dono = await novaConta('Push Dono');
    const visitante = await novaConta('Push Visitante');
    const [celular, tablet] = [tokenFcm(), tokenFcm()];
    await registrar(dono, celular);
    await registrar(dono, tablet);
    await registrar(visitante, tokenFcm());
    const { idSolicitacao, idNotificacao } = await desafio(dono, visitante);

    // Fila preenchida na transação do evento; o "Desafio enviado" (já lido) não entra.
    expect(await envio(idNotificacao)).toMatchObject({ status: 'pendente', tentativas: 0 });
    const [enviadasVisitante] = await pool.query(
      `SELECT COUNT(*) AS n FROM envios_push e JOIN notificacoes n USING (id_notificacao)
        WHERE n.id_usuario_destinatario = ?`,
      [visitante.idUsuario],
    );
    expect(enviadasVisitante[0].n).toBe(0);

    await rodarFila();
    expect(provedor.envios).toHaveLength(1);
    const [{ tokens, mensagem }] = provedor.envios;
    expect(tokens.sort()).toEqual([celular, tablet].sort());
    expect(mensagem).toEqual({
      titulo: 'Novo desafio recebido',
      corpo: expect.stringContaining('demonstrou interesse no seu jogo'),
      dados: { idNotificacao, tipo: 'solicitacao_recebida', referenciaTipo: 'solicitacao', referenciaId: idSolicitacao },
    });
    expect(JSON.stringify(mensagem)).not.toMatch(/@|senha|token/i);
    expect(await envio(idNotificacao)).toMatchObject({ status: 'enviado', tentativas: 1, dispositivos_enviados: 2 });

    // Rodar de novo (ou em paralelo) não reenvia.
    await Promise.all([rodarFila(), rodarFila()]);
    expect(provedor.envios).toHaveLength(1);
    // A notificação interna existe e segue não lida na central.
    const central = await api(dono).get('/notificacoes');
    expect(central.body.data.find((n: any) => n.idNotificacao === idNotificacao)).toMatchObject({ lida: false });
  });

  it('sem permissão no aparelho: nada é enviado, a central continua igual', async () => {
    const dono = await novaConta('Push Sem Permissao');
    const visitante = await novaConta('Push Visita 2');
    await registrar(dono, tokenFcm(), { permitido: false });
    const { idNotificacao } = await desafio(dono, visitante);
    await rodarFila();
    expect(provedor.envios).toHaveLength(0);
    expect(await envio(idNotificacao)).toMatchObject({ status: 'ignorado', ultimo_erro: 'sem_dispositivo' });
    expect((await api(dono).get('/notificacoes/nao-lidas')).body.data.naoLidas).toBe(1);
  });

  it('token inválido: aparelho desativado, os outros continuam recebendo', async () => {
    const dono = await novaConta('Push Token Invalido');
    const visitante = await novaConta('Push Visita 3');
    const [velho, novo] = [tokenFcm(), tokenFcm()];
    await registrar(dono, velho);
    await registrar(dono, novo);
    provedor.tokensInvalidos.add(velho);
    const { idNotificacao } = await desafio(dono, visitante);
    await rodarFila();
    expect(await dispositivo(velho)).toMatchObject({ ativo: 0, motivo_desativacao: 'token_invalido' });
    expect(await dispositivo(novo)).toMatchObject({ ativo: 1 });
    expect(await envio(idNotificacao)).toMatchObject({ status: 'enviado', dispositivos_enviados: 1 });
    // O próximo evento já não tenta o token inválido.
    const segundo = await desafio(dono, await novaConta('Push Visita 4'));
    await rodarFila();
    expect(provedor.envios.at(-1)!.tokens).toEqual([novo]);
    expect(await envio(segundo.idNotificacao)).toMatchObject({ status: 'enviado' });
  });

  it('Firebase fora do ar: evento e notificação intactos; o envio é repetido depois', async () => {
    const dono = await novaConta('Push Falha');
    const visitante = await novaConta('Push Visita 5');
    await registrar(dono, tokenFcm());
    provedor.falhaGeral = Object.assign(new Error('Firebase indisponível'), { code: 'messaging/unavailable' });
    const { idNotificacao, idSolicitacao } = await desafio(dono, visitante);
    await rodarFila();
    const depois = await envio(idNotificacao);
    expect(depois).toMatchObject({ status: 'pendente', tentativas: 1, ultimo_erro: 'messaging/unavailable' });
    expect(new Date(depois.proxima_tentativa).getTime()).toBeGreaterThan(Date.now());
    // O evento de negócio continua confirmado.
    const [[s]] = await pool.query('SELECT status FROM solicitacoes_confronto WHERE id_solicitacao = ?', [idSolicitacao]);
    expect(s.status).toBe('pendente');

    // Firebase volta; a espera venceu (adiantada só nesta linha de teste): enviado.
    provedor.falhaGeral = null;
    await pool.query('UPDATE envios_push SET proxima_tentativa = UTC_TIMESTAMP(3) WHERE id_notificacao = ?', [idNotificacao]);
    await rodarFila();
    expect(await envio(idNotificacao)).toMatchObject({ status: 'enviado', tentativas: 2 });
  });

  it('desiste depois de 5 tentativas', async () => {
    const dono = await novaConta('Push Desiste');
    await registrar(dono, tokenFcm());
    provedor.falhaGeral = Object.assign(new Error('fora'), { code: 'messaging/internal-error' });
    const { idNotificacao } = await desafio(dono, await novaConta('Push Visita 6'));
    for (let i = 0; i < 5; i++) {
      await pool.query('UPDATE envios_push SET proxima_tentativa = UTC_TIMESTAMP(3) WHERE id_notificacao = ?', [idNotificacao]);
      await rodarFila();
    }
    expect(await envio(idNotificacao)).toMatchObject({ status: 'falhou', tentativas: 5 });
  });

  it('lida antes do envio, push desligado e evento desfeito não geram push', async () => {
    const dono = await novaConta('Push Lida');
    await registrar(dono, tokenFcm());
    const lida = await desafio(dono, await novaConta('Push Visita 7'));
    await api(dono).patch(`/notificacoes/${lida.idNotificacao}/lida`).expect(204);
    await rodarFila();
    expect(await envio(lida.idNotificacao)).toMatchObject({ status: 'ignorado', ultimo_erro: 'ja_lida' });

    definirEnviador(null);
    const desligado = await desafio(dono, await novaConta('Push Visita 8'));
    await rodarFila();
    expect(await envio(desligado.idNotificacao)).toMatchObject({ status: 'ignorado', ultimo_erro: 'push_desligado' });

    // Pedido recusado pelo banco (anúncio pausado): sem notificação e sem envio.
    definirEnviador(provedor);
    await api(dono).patch(`/anuncios/${lida.idAnuncio}/status`).send({ status: 'pausado' }).expect(200);
    const antes = (await pool.query('SELECT COUNT(*) AS n FROM envios_push'))[0][0].n;
    expect((await api(await novaConta('Push Visita 9')).post('/solicitacoes').send({ idAnuncio: lida.idAnuncio })).status).toBe(409);
    expect((await pool.query('SELECT COUNT(*) AS n FROM envios_push'))[0][0].n).toBe(antes);
    expect(provedor.envios).toHaveLength(0);
  });

  it('sair, remover e redefinir a senha desligam o aparelho', async () => {
    const a = await novaConta('Push Sair');
    const b = await novaConta('Push Outro');
    const [t1, t2, t3] = [tokenFcm(), tokenFcm(), tokenFcm()];
    await registrar(a, t1);
    const r2 = await registrar(a, t2);
    await registrar(a, t3);

    // Sair neste aparelho; o token de outra conta não é afetado (e nada é revelado).
    expect((await api(a).patch('/dispositivos/desativar').send({ token: t1 })).status).toBe(204);
    expect(await dispositivo(t1)).toMatchObject({ ativo: 0, motivo_desativacao: 'saiu_da_conta' });
    expect((await api(b).patch('/dispositivos/desativar').send({ token: t3 })).status).toBe(204);
    expect(await dispositivo(t3)).toMatchObject({ ativo: 1 });

    // Remover: o token é apagado; de outra conta, 404.
    expect((await api(b).delete(`/dispositivos/${r2.body.data.idDispositivo}`)).status).toBe(404);
    expect((await api(a).delete(`/dispositivos/${r2.body.data.idDispositivo}`)).status).toBe(204);
    expect(await dispositivo(t2)).toBeUndefined();
    const [[removido]] = await pool.query('SELECT token_fcm, ativo, motivo_desativacao FROM dispositivos_push WHERE id_dispositivo = ?', [r2.body.data.idDispositivo]);
    expect(removido).toEqual({ token_fcm: null, ativo: 0, motivo_desativacao: 'removido' });

    // Redefinir a senha: todos os aparelhos ativos da conta param de receber.
    const token = randomBytes(32).toString('base64url');
    await pool.query(
      `INSERT INTO codigos_recuperacao_senha (id_codigo, id_usuario, hash_codigo, data_criacao, data_expiracao)
       VALUES (?, ?, ?, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3) + INTERVAL 30 MINUTE)`,
      [randomUUID(), a.idUsuario, createHash('sha256').update(token).digest()],
    );
    expect((await request(app).post('/api/auth/reset-password').send({ token, novaSenha: 'nova-senha-789', confirmacaoSenha: 'nova-senha-789' })).status).toBe(200);
    expect(await dispositivo(t3)).toMatchObject({ ativo: 0, motivo_desativacao: 'senha_redefinida' });
  });

  it('envios pendentes há mais de 24 h expiram (sem apagar), mesmo com o push desligado', async () => {
    const dono = await novaConta('Push Expira');
    const { idNotificacao } = await desafio(dono, await novaConta('Push Visita 11'));
    await pool.query(
      'UPDATE envios_push SET data_criacao = UTC_TIMESTAMP(3) - INTERVAL 25 HOUR WHERE id_notificacao = ?',
      [idNotificacao],
    );
    const { expirarEnviosAntigos } = await import('../src/services/push.js');
    expect(await expirarEnviosAntigos()).toBeGreaterThanOrEqual(1);
    expect(await envio(idNotificacao)).toMatchObject({ status: 'ignorado', ultimo_erro: 'expirada' });
    const [[n]] = await pool.query('SELECT data_leitura FROM notificacoes WHERE id_notificacao = ?', [idNotificacao]);
    expect(n.data_leitura).toBeNull(); // a notificação interna segue intacta
  });

  it('o log da fila não mostra tokens', async () => {
    const logs: string[] = [];
    const espiao = vi.spyOn(console, 'log').mockImplementation((...a) => void logs.push(a.join(' ')));
    try {
      const dono = await novaConta('Push Log');
      const t = tokenFcm();
      await registrar(dono, t);
      await desafio(dono, await novaConta('Push Visita 10'));
      await rodarFila();
      expect(logs.join('\n')).not.toContain(t);
    } finally {
      espiao.mockRestore();
    }
  });
});
