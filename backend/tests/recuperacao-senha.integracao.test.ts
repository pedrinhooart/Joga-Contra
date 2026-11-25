import { createHash, randomBytes, randomUUID } from 'node:crypto';
import jwt from 'jsonwebtoken';
import request from 'supertest';
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { iniciarSmtpLocal, tokenDoEmail } from './smtp-local.js';

/**
 * Recuperação de senha de ponta a ponta: API + MySQL + envio real por SMTP
 * (Nodemailer, o mesmo caminho do Gmail) para um servidor local. Grava contas
 * fictícias (teste.homologacao.*@example.com), que permanecem no banco; nenhum
 * e-mail sai da máquina. Mesmas travas de tests/integracao.test.ts.
 */
const ativo = process.env.TESTE_INTEGRACAO === '1';
if (ativo && (process.env.DB_PORT ?? '3306') === '3306' && process.env.TESTE_BANCO_REAL_AUTORIZADO !== '1') {
  throw new Error('Testes de integração bloqueados no servidor padrão: defina TESTE_BANCO_REAL_AUTORIZADO=1 para rodar nele.');
}
// Endereço que vai no link do e-mail (o mesmo papel do IP da máquina em homologação).
process.env.URL_PUBLICA = 'http://127.0.0.1:3999';

const SENHA = 'senha-de-teste-123';
const NOVA = 'nova-senha-456';
const SENHA_SMTP = 'senha-smtp-secreta-de-teste';
const LIVRE = 4;

describe.runIf(ativo)('recuperação de senha (API + MySQL + SMTP)', () => {
  let app: any;
  let pool: any;
  let jwtSecret: string;
  let smtp: Awaited<ReturnType<typeof iniciarSmtpLocal>>;
  let aguardar: () => Promise<unknown>;
  let definirProvedor: (p: any) => void;
  let ProvedorSmtp: any;
  /** Tudo o que a API escreveu no console durante os testes. */
  const logs: string[] = [];
  /** Tokens e senhas que nunca podem aparecer nos logs. */
  const segredos = new Set<string>([SENHA, NOVA, SENHA_SMTP]);

  const provedorLocal = (porta: number, nome = 'teste-smtp') =>
    new ProvedorSmtp(
      nome,
      { host: '127.0.0.1', port: porta, secure: false, ignoreTLS: true, auth: { user: 'app@example.com', pass: SENHA_SMTP } },
      'Joga Contra <nao-responda@example.com>',
    );

  async function novaConta(nome = 'Capitão Recuperação') {
    const email = `teste.homologacao.${randomUUID()}@example.com`;
    const r = await request(app).post('/api/auth/cadastro').send({
      usuario: { nome, email, senha: SENHA, cidade: 'São Paulo', siglaEstado: 'SP' },
      time: { nome: `Recuperação ${randomUUID().slice(0, 6)}`, idsModalidades: [1], idCategoriaEtaria: LIVRE, cidade: 'São Paulo', siglaEstado: 'SP' },
    });
    expect(r.status).toBe(201);
    return { email, tokenSessao: r.body.data.token as string, idUsuario: r.body.data.usuario.idUsuario as string };
  }

  async function pedir(email: string, caminho = '/api/auth/forgot-password') {
    const r = await request(app).post(caminho).send({ email });
    await aguardar();
    return r;
  }

  async function pedirToken(email: string) {
    expect((await pedir(email)).status).toBe(202);
    const token = tokenDoEmail(smtp.para(email).at(-1)!);
    segredos.add(token);
    return token;
  }

  const redefinir = (token: string, novaSenha = NOVA, confirmacaoSenha = novaSenha, caminho = '/api/auth/reset-password') =>
    request(app).post(caminho).send({ token, novaSenha, confirmacaoSenha });

  const entrar = (email: string, senha: string) => request(app).post('/api/auth/login').send({ email, senha });

  const codigos = async (idUsuario: string) =>
    (await pool.query(
      `SELECT hash_codigo, data_uso, TIMESTAMPDIFF(SECOND, data_criacao, data_expiracao) AS validade_s
         FROM codigos_recuperacao_senha WHERE id_usuario = ? ORDER BY data_criacao`,
      [idUsuario],
    ))[0] as { hash_codigo: Buffer; data_uso: Date | null; validade_s: number }[];

  beforeAll(async () => {
    for (const nivel of ['log', 'warn', 'error'] as const) {
      vi.spyOn(console, nivel).mockImplementation((...args: unknown[]) => {
        logs.push(args.map(String).join(' '));
      });
    }
    smtp = await iniciarSmtpLocal();
    const { createApp } = await import('../src/app.js');
    app = createApp();
    ({ pool } = await import('../src/config/db.js'));
    ({ aguardarPedidosRecuperacao: aguardar } = await import('../src/routes/auth.js'));
    ({ definirProvedorEmail: definirProvedor, ProvedorSmtp } = await import('../src/services/email.js'));
    jwtSecret = (await import('../src/config/env.js')).env.JWT_SECRET;
    definirProvedor(provedorLocal(smtp.porta));
  });

  afterEach(() => definirProvedor(provedorLocal(smtp.porta)));

  afterAll(async () => {
    definirProvedor?.(null);
    await smtp?.fechar();
    await pool?.end();
    vi.restoreAllMocks();
  });

  it('e-mail cadastrado: resposta genérica, token só como hash, validade de 30 min e e-mail enviado', async () => {
    const { email, idUsuario } = await novaConta('Ana <b>Souza</b>');
    const r = await pedir(email);
    expect(r.status).toBe(202);
    expect(r.body.data.mensagem).toMatch(/Se o e-mail estiver cadastrado/);

    const [mensagem] = smtp.para(email);
    expect(mensagem).toBeDefined();
    expect(mensagem.subject).toBe('Recuperação de senha — Joga Contra');
    expect(mensagem.from?.text).toContain('nao-responda@example.com');
    const html = mensagem.html as string;
    expect(html).toContain('Redefinir minha senha');
    expect(html).toContain('30 minutos');
    expect(html).toContain('ignore este e-mail');
    expect(html).toContain('Olá, Ana!'); // primeiro nome, sem HTML do cadastro
    expect(html).not.toContain('<b>Souza');
    // O leitor de e-mail troca `cid:logo-joga-contra` pela imagem anexada.
    expect(html).toMatch(/src="(cid:logo-joga-contra|data:image\/png;base64,)/);
    expect(mensagem.attachments.some((a) => a.cid === 'logo-joga-contra' && a.contentType === 'image/png')).toBe(true);
    expect(mensagem.text).toContain('http://127.0.0.1:3999/redefinir-senha#token=');
    expect(html).not.toMatch(/senha-de-teste|sua senha é/i); // nunca envia senha
    // O SMTP recebeu as credenciais do ambiente (no Gmail, a senha de app).
    expect(smtp.logins.at(-1)).toEqual({ usuario: 'app@example.com', senha: SENHA_SMTP });

    const token = tokenDoEmail(mensagem);
    segredos.add(token);
    const [registro] = await codigos(idUsuario);
    expect(registro.hash_codigo.equals(createHash('sha256').update(token).digest())).toBe(true);
    expect(registro.hash_codigo.toString('utf8')).not.toContain(token);
    expect(registro.validade_s).toBe(30 * 60);
    expect(registro.data_uso).toBeNull();
    // O token não aparece em nenhuma coluna de texto do banco.
    const [[{ achados }]] = await pool.query(
      'SELECT COUNT(*) AS achados FROM codigos_recuperacao_senha WHERE HEX(hash_codigo) = HEX(?)',
      [token],
    );
    expect(achados).toBe(0);
  });

  it('e-mail não cadastrado: mesma resposta, sem e-mail e sem registro', async () => {
    const { email } = await novaConta();
    const cadastrado = await pedir(email);
    const inexistente = `teste.homologacao.inexistente.${randomUUID()}@example.com`;
    const antes = smtp.recebidos.length;
    const r = await pedir(inexistente);
    expect(r.status).toBe(cadastrado.status);
    expect(r.body).toEqual(cadastrado.body);
    expect(smtp.recebidos.length).toBe(antes);
    expect(smtp.para(inexistente)).toHaveLength(0);
    const [[{ total }]] = await pool.query(
      'SELECT COUNT(*) AS total FROM codigos_recuperacao_senha c JOIN usuarios u USING (id_usuario) WHERE u.email = ?',
      [inexistente],
    );
    expect(total).toBe(0);
  });

  it('valida o formato do e-mail (inválido, vazio ou ausente)', async () => {
    const antes = smtp.recebidos.length;
    for (const email of ['', '   ', 'sem-arroba', 'a@b', 'x'.repeat(260) + '@example.com']) {
      const r = await pedir(email);
      expect(r.status, email).toBe(400);
      expect(r.body.error.code).toBe('VALIDATION_ERROR');
    }
    for (const corpo of [{}, { email: null }, { email: 123 }, { email: ['a@example.com'] }]) {
      const r = await request(app).post('/api/auth/forgot-password').send(corpo);
      expect(r.status, JSON.stringify(corpo)).toBe(400);
    }
    await aguardar();
    expect(smtp.recebidos.length).toBe(antes);
  });

  it('e-mails diferentes: cada conta recebe o próprio link, que só troca a senha dela', async () => {
    const a = await novaConta();
    const b = await novaConta();
    const tokenA = await pedirToken(a.email);
    const tokenB = await pedirToken(b.email);
    expect(tokenA).not.toBe(tokenB);
    expect(smtp.para(a.email)).toHaveLength(1);
    expect(smtp.para(b.email)).toHaveLength(1);
    const hashes = async () =>
      (await pool.query('SELECT id_usuario, hash_senha FROM usuarios WHERE id_usuario IN (?, ?)', [a.idUsuario, b.idUsuario]))[0]
        .reduce((m: Record<string, string>, l: any) => ({ ...m, [l.id_usuario]: l.hash_senha }), {});
    const antes = await hashes();

    expect((await redefinir(tokenA)).status).toBe(200);
    const depois = await hashes();
    expect(depois[a.idUsuario]).not.toBe(antes[a.idUsuario]);
    expect(depois[b.idUsuario]).toBe(antes[b.idUsuario]); // a outra conta não muda
    expect((await entrar(b.email, SENHA)).status).toBe(200);
    expect((await entrar(b.email, NOVA)).status).toBe(401);
    // O link de B continua valendo (só para B) e o pedido de B segue sem uso.
    expect((await codigos(b.idUsuario))[0].data_uso).toBeNull();
    expect((await redefinir(tokenB, 'senha-de-b-000', 'senha-de-b-000')).status).toBe(200);
    segredos.add('senha-de-b-000');
    expect((await entrar(a.email, NOVA)).status).toBe(200);
    expect((await entrar(a.email, 'senha-de-b-000')).status).toBe(401);
  });

  it('não há como escolher a conta: campos extras no corpo são ignorados', async () => {
    const vitima = await novaConta();
    const atacante = await novaConta();
    const token = await pedirToken(atacante.email);
    const r = await request(app)
      .post('/api/auth/reset-password')
      .send({ token, novaSenha: NOVA, confirmacaoSenha: NOVA, idUsuario: vitima.idUsuario, email: vitima.email });
    expect(r.status).toBe(200);
    expect((await entrar(vitima.email, SENHA)).status).toBe(200); // vítima intacta
    expect((await entrar(atacante.email, NOVA)).status).toBe(200);
  });

  it('redefine a senha: login com a nova, a antiga e as sessões abertas deixam de valer', async () => {
    const { email, tokenSessao, idUsuario } = await novaConta();
    // Sessão emitida antes desta regra (sem a impressão da senha), ainda válida.
    const sessaoAntiga = jwt.sign({}, jwtSecret, { subject: idUsuario, algorithm: 'HS256', expiresIn: '1h' });
    for (const s of [tokenSessao, sessaoAntiga]) {
      expect((await request(app).get('/api/auth/eu').set('Authorization', `Bearer ${s}`)).status).toBe(200);
    }
    const [[{ hash_senha: hashAntes }]] = await pool.query('SELECT hash_senha FROM usuarios WHERE id_usuario = ?', [idUsuario]);

    const token = await pedirToken(email);
    // Confirmação diferente ou senha curta: recusadas, e o link continua valendo.
    const diferente = await redefinir(token, NOVA, 'outra-coisa-789');
    expect(diferente.status).toBe(400);
    expect(diferente.body.error.message).toBe('A confirmação não é igual à nova senha.');
    expect((await redefinir(token, '1234567')).body.error.message).toMatch(/pelo menos 8/);
    expect((await redefinir(token, '        ')).status).toBe(400);
    expect((await redefinir(token, 'ç'.repeat(40))).body.error.message).toMatch(/longa demais/);
    expect((await codigos(idUsuario))[0].data_uso).toBeNull();

    // Dois envios simultâneos do mesmo link: só um troca a senha.
    await new Promise((r) => setTimeout(r, 1100)); // sessões acima ficam com "iat" anterior
    const [a, b] = await Promise.all([redefinir(token), redefinir(token, 'senha-concorrente-1', 'senha-concorrente-1')]);
    expect([a.status, b.status].sort()).toEqual([200, 410]);
    const venceu = a.status === 200 ? NOVA : 'senha-concorrente-1';
    segredos.add('senha-concorrente-1');
    expect((a.status === 200 ? a : b).body.data.mensagem).toMatch(/Senha alterada/);
    expect((a.status === 200 ? b : a).body.error.code).toBe('TOKEN_UTILIZADO');

    expect((await entrar(email, venceu)).status).toBe(200);
    expect((await entrar(email, SENHA)).status).toBe(401);
    for (const s of [tokenSessao, sessaoAntiga]) {
      expect((await request(app).get('/api/auth/eu').set('Authorization', `Bearer ${s}`)).status).toBe(401);
    }
    const novaSessao = (await entrar(email, venceu)).body.data.token;
    expect((await request(app).get('/api/auth/eu').set('Authorization', `Bearer ${novaSessao}`)).status).toBe(200);

    // Reutilizar o link: recusado, e a senha não muda de novo.
    const reuso = await redefinir(token, 'terceira-senha-000');
    expect(reuso.status).toBe(410);
    expect(reuso.body.error.code).toBe('TOKEN_UTILIZADO');
    expect((await entrar(email, venceu)).status).toBe(200);

    // Persistência: hash bcrypt novo e pedido marcado como usado.
    const [[{ hash_senha: hashDepois }]] = await pool.query('SELECT hash_senha FROM usuarios WHERE id_usuario = ?', [idUsuario]);
    expect(hashDepois).not.toBe(hashAntes);
    expect(hashDepois).toMatch(/^\$2[aby]\$12\$/);
    expect((await codigos(idUsuario))[0].data_uso).toBeInstanceOf(Date);
  });

  it('token inválido ou malformado', async () => {
    for (const token of [randomBytes(32).toString('base64url'), 'abc', 'x'.repeat(43), '']) {
      const r = await redefinir(token);
      expect(r.status, token).toBe(400);
      expect(r.body.error.code).toBe('TOKEN_INVALIDO');
    }
  });

  it('token expirado', async () => {
    const { email, idUsuario } = await novaConta();
    const token = randomBytes(32).toString('base64url');
    segredos.add(token);
    await pool.query(
      `INSERT INTO codigos_recuperacao_senha (id_codigo, id_usuario, hash_codigo, data_criacao, data_expiracao)
       VALUES (?, ?, ?, UTC_TIMESTAMP(3) - INTERVAL 40 MINUTE, UTC_TIMESTAMP(3) - INTERVAL 10 MINUTE)`,
      [randomUUID(), idUsuario, createHash('sha256').update(token).digest()],
    );
    const r = await redefinir(token);
    expect(r.status).toBe(410);
    expect(r.body.error.code).toBe('TOKEN_EXPIRADO');
    expect(r.body.error.message).toMatch(/expirou/);
    expect((await entrar(email, SENHA)).status).toBe(200); // senha intacta
  });

  it('novo pedido invalida o link anterior', async () => {
    const { email } = await novaConta();
    const primeiro = await pedirToken(email);
    const segundo = await pedirToken(email);
    expect(segundo).not.toBe(primeiro);
    const r = await redefinir(primeiro);
    expect(r.status).toBe(410);
    expect(r.body.error.code).toBe('TOKEN_SUBSTITUIDO');
    expect((await redefinir(segundo)).status).toBe(200);
  });

  it('limite por conta: 3 pedidos por hora; os seguintes respondem igual, mas não geram e-mail', async () => {
    const { email, idUsuario } = await novaConta();
    const respostas = [];
    for (let i = 0; i < 5; i++) respostas.push(await pedir(email));
    expect(respostas.map((r) => r.status)).toEqual([202, 202, 202, 202, 202]);
    expect(new Set(respostas.map((r) => JSON.stringify(r.body))).size).toBe(1);
    expect(smtp.para(email)).toHaveLength(3);
    expect(await codigos(idUsuario)).toHaveLength(3);
    expect(logs.some((l) => l.includes('limite de pedidos da conta atingido'))).toBe(true);
    for (const m of smtp.para(email)) segredos.add(tokenDoEmail(m));
  });

  it('pedidos simultâneos da mesma conta respeitam o limite', async () => {
    const { email, idUsuario } = await novaConta();
    await Promise.all(Array.from({ length: 6 }, () => request(app).post('/api/auth/forgot-password').send({ email })));
    await aguardar();
    expect(await codigos(idUsuario)).toHaveLength(3);
    for (const m of smtp.para(email)) segredos.add(tokenDoEmail(m));
  });

  it('servidor de e-mail fora do ar: mesma resposta, falha registrada sem dados sensíveis', async () => {
    const { email, idUsuario } = await novaConta();
    const fora = await iniciarSmtpLocal();
    await fora.fechar(); // porta sem ninguém ouvindo
    definirProvedor(provedorLocal(fora.porta, 'gmail'));
    const r = await pedir(email);
    expect(r.status).toBe(202);
    expect(r.body.data.mensagem).toMatch(/Se o e-mail estiver cadastrado/);
    expect(await codigos(idUsuario)).toHaveLength(1);
    const falha = logs.filter((l) => l.includes('e-mail não enviado')).at(-1);
    expect(falha).toMatch(/e-mail não enviado por gmail \((ESOCKET|ECONNECTION)/);
    expect(falha).not.toContain(email);
  });

  it('senha de app recusada pelo servidor: falha registrada sem a senha', async () => {
    const { email } = await novaConta();
    const recusa = await iniciarSmtpLocal({ recusarLogin: true });
    try {
      definirProvedor(provedorLocal(recusa.porta, 'gmail'));
      expect((await pedir(email)).status).toBe(202);
      expect(recusa.recebidos).toHaveLength(0);
      expect(logs.filter((l) => l.includes('e-mail não enviado')).at(-1)).toMatch(/EAUTH 535/);
    } finally {
      await recusa.fechar();
    }
  });

  it('rotas antigas (recuperar-senha / redefinir-senha) seguem funcionando', async () => {
    const { email } = await novaConta();
    expect((await pedir(email, '/api/auth/recuperar-senha')).status).toBe(202);
    const token = tokenDoEmail(smtp.para(email).at(-1)!);
    // Acentos do nome chegam intactos (UTF-8 do cadastro ao e-mail).
    expect(smtp.para(email).at(-1)!.html).toContain('Olá, Capitão!');
    segredos.add(token);
    expect((await redefinir(token, NOVA, NOVA, '/api/auth/redefinir-senha')).status).toBe(200);
    expect((await entrar(email, NOVA)).status).toBe(200);
  });

  it('página do link: entrega o token ao app, sem cache e sem scripts de fora', async () => {
    const pagina = await request(app).get('/redefinir-senha');
    expect(pagina.status).toBe(200);
    expect(pagina.headers['content-type']).toMatch(/text\/html/);
    expect(pagina.headers['cache-control']).toBe('no-store');
    expect(pagina.headers['content-security-policy']).toContain("script-src 'self'");
    expect(pagina.headers['referrer-policy']).toBe('no-referrer');
    expect(pagina.text).toContain('Abrir no aplicativo');
    const script = await request(app).get('/redefinir-senha/abrir.js');
    expect(script.status).toBe(200);
    expect(script.text).toContain('#Intent;scheme=jogacontra;package=');
    expect(script.text).toContain('"com.jogacontra.joga_contra"');
    expect((await request(app).get('/redefinir-senha/logo.png')).headers['content-type']).toBe('image/png');
  });

  it('nenhum log contém token, senha ou credencial', () => {
    expect(logs.length).toBeGreaterThan(0);
    for (const linha of logs) {
      for (const segredo of segredos) expect(linha).not.toContain(segredo);
      expect(linha).not.toMatch(/teste\.homologacao\./);
    }
  });
});
