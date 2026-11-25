import vm from 'node:vm';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const envFalso = vi.hoisted(() => ({
  NODE_ENV: 'development',
  CORS_ORIGIN: '*',
  JWT_SECRET: 'x'.repeat(32),
  JWT_EXPIRES_IN: '1d',
  TRUST_PROXY: 0,
  EMAIL_PROVEDOR: 'gmail' as 'gmail' | 'smtp',
  EMAIL_USER: undefined as string | undefined,
  EMAIL_PASS: undefined as string | undefined,
  EMAIL_FROM: undefined as string | undefined,
  EMAIL_SMTP_HOST: undefined as string | undefined,
  EMAIL_SMTP_PORT: undefined as number | undefined,
  EMAIL_SMTP_SEGURO: undefined as 'true' | 'false' | undefined,
  URL_PUBLICA: 'https://api.exemplo.test' as string | undefined,
  ANDROID_PACOTE: 'com.jogacontra.joga_contra',
  ANDROID_CERT_SHA256: undefined as string | undefined,
}));
vi.mock('../src/config/env.js', () => ({ env: envFalso }));
vi.mock('../src/config/db.js', () => ({
  // Nenhuma conta encontrada: o pedido termina sem tocar em mais nada.
  pool: { execute: vi.fn().mockResolvedValue([[], []]) },
  checkDatabase: vi.fn(),
}));

import request from 'supertest';
import { createApp } from '../src/app.js';
import { lerConfiguracaoEmail, motivoEmailIndisponivel } from '../src/config/email.js';
import {
  assetLinks,
  emailRecuperacao,
  gerarTokenRecuperacao,
  FORMATO_TOKEN,
  scriptPaginaRedefinicao,
} from '../src/services/recuperacao-senha.js';

beforeEach(() => {
  Object.assign(envFalso, {
    EMAIL_PROVEDOR: 'gmail',
    EMAIL_USER: undefined,
    EMAIL_PASS: undefined,
    EMAIL_FROM: undefined,
    EMAIL_SMTP_HOST: undefined,
    URL_PUBLICA: 'https://api.exemplo.test',
    ANDROID_CERT_SHA256: undefined,
  });
});

describe('configuração do e-mail', () => {
  it('sem credenciais fica desligado e diz só o nome do que falta', () => {
    envFalso.URL_PUBLICA = undefined;
    expect(lerConfiguracaoEmail()).toBeNull();
    expect(motivoEmailIndisponivel()).toBe('variáveis não configuradas: EMAIL_USER, EMAIL_PASS, URL_PUBLICA');
  });

  it('Gmail: smtp.gmail.com com TLS na 465 e senha de app sem espaços', () => {
    Object.assign(envFalso, { EMAIL_USER: 'app@gmail.com', EMAIL_PASS: 'abcd efgh ijkl mnop' });
    const config = lerConfiguracaoEmail()!;
    expect(config.provedor).toBe('gmail');
    expect(config.remetente).toBe('Joga Contra <app@gmail.com>');
    expect(config.smtp).toMatchObject({
      host: 'smtp.gmail.com',
      port: 465,
      secure: true,
      auth: { user: 'app@gmail.com', pass: 'abcdefghijklmnop' },
    });
    expect(motivoEmailIndisponivel()).toBeNull();
  });

  it('outro provedor por SMTP (ex.: Amazon SES) só com variáveis de ambiente', () => {
    Object.assign(envFalso, {
      EMAIL_PROVEDOR: 'smtp',
      EMAIL_USER: 'AKIA...',
      EMAIL_PASS: 'segredo',
      EMAIL_FROM: 'Joga Contra <nao-responda@exemplo.test>',
    });
    expect(motivoEmailIndisponivel()).toContain('EMAIL_SMTP_HOST');
    envFalso.EMAIL_SMTP_HOST = 'email-smtp.sa-east-1.amazonaws.com';
    expect(lerConfiguracaoEmail()).toMatchObject({
      provedor: 'smtp',
      remetente: 'Joga Contra <nao-responda@exemplo.test>',
      smtp: { host: 'email-smtp.sa-east-1.amazonaws.com', port: 587, secure: false, requireTLS: true },
    });
  });
});

describe('token e e-mail', () => {
  it('tokens aleatórios de 256 bits, nunca repetidos', () => {
    const tokens = new Set(Array.from({ length: 1000 }, gerarTokenRecuperacao));
    expect(tokens.size).toBe(1000);
    for (const t of tokens) expect(t).toMatch(FORMATO_TOKEN);
  });

  it('e-mail com link no fragmento, validade, aviso e nome escapado', () => {
    const token = gerarTokenRecuperacao();
    const m = emailRecuperacao('ana@exemplo.test', '<script>x</script> Silva', token);
    const link = `https://api.exemplo.test/redefinir-senha#token=${token}`;
    expect(m.assunto).toBe('Recuperação de senha — Joga Contra');
    expect(m.html).toContain(`href="${link}"`);
    expect(m.html).toContain('Redefinir minha senha');
    expect(m.html).toContain('30 minutos');
    expect(m.html).toContain('ignore este e-mail');
    expect(m.html).not.toContain('<script>');
    expect(m.html).toContain('&lt;script&gt;x&lt;/script&gt;');
    expect(m.texto).toContain(link);
    expect(m.imagens?.[0].cid).toBe('logo-joga-contra');
  });
});

describe('página do link', () => {
  /** Executa o script da página num DOM mínimo e devolve o que ela mostrou. */
  function abrir(hash: string, userAgent: string) {
    const elementos: Record<string, { hidden: boolean; href: string }> = {};
    for (const id of ['com-token', 'sem-app', 'sem-token', 'abrir']) elementos[id] = { hidden: false, href: '#' };
    vm.runInNewContext(scriptPaginaRedefinicao(), {
      document: { getElementById: (id: string) => elementos[id] },
      location: { hash, origin: 'https://api.exemplo.test', pathname: '/redefinir-senha' },
      navigator: { userAgent },
      encodeURIComponent,
    });
    const visivel = ['com-token', 'sem-app', 'sem-token'].find((id) => !elementos[id].hidden);
    return { visivel, href: elementos.abrir.href };
  }
  const ANDROID = 'Mozilla/5.0 (Linux; Android 14; Pixel 9 Pro) Chrome/131.0 Mobile';
  const token = 'A'.repeat(20) + '_-' + 'b'.repeat(21);

  it('no Android abre o app pelo pacote, com volta para a página se ele faltar', () => {
    const { visivel, href } = abrir(`#token=${token}`, ANDROID);
    expect(visivel).toBe('com-token');
    expect(href).toBe(
      `intent://redefinir-senha?token=${token}#Intent;scheme=jogacontra;package=com.jogacontra.joga_contra;` +
        `S.browser_fallback_url=${encodeURIComponent('https://api.exemplo.test/redefinir-senha#sem-app')};end`,
    );
  });

  it('em outros navegadores usa o esquema do app', () => {
    expect(abrir(`#token=${token}`, 'Mozilla/5.0 (Windows NT 10.0)').href).toBe(`jogacontra://redefinir-senha?token=${token}`);
  });

  it('link incompleto, adulterado ou sem o app instalado', () => {
    expect(abrir('', ANDROID).visivel).toBe('sem-token');
    expect(abrir('#token=curto', ANDROID).visivel).toBe('sem-token');
    expect(abrir(`#token=${token}"><script>`, ANDROID).visivel).toBe('sem-token');
    expect(abrir('#sem-app', ANDROID).visivel).toBe('sem-app');
  });

  it('assetlinks.json só com o certificado configurado', async () => {
    const app = createApp();
    expect((await request(app).get('/.well-known/assetlinks.json')).status).toBe(404);
    const sha = Array.from({ length: 32 }, () => 'ab').join(':');
    envFalso.ANDROID_CERT_SHA256 = sha;
    expect(assetLinks()?.[0].target).toEqual({
      namespace: 'android_app',
      package_name: 'com.jogacontra.joga_contra',
      sha256_cert_fingerprints: [sha.toUpperCase()],
    });
    const r = await request(app).get('/.well-known/assetlinks.json');
    expect(r.status).toBe(200);
    expect(r.body[0].relation).toEqual(['delegate_permission/common.handle_all_urls']);
  });
});

describe('limite por IP', () => {
  it('a partir do 6º pedido em 15 minutos responde 429', async () => {
    const app = createApp(); // NODE_ENV=development: limites ligados
    const status: number[] = [];
    for (let i = 0; i < 7; i++) {
      // Rota nova e antiga contam juntas.
      const caminho = i % 2 ? '/api/auth/recuperar-senha' : '/api/auth/forgot-password';
      status.push((await request(app).post(caminho).send({ email: `pessoa${i}@exemplo.test` })).status);
    }
    expect(status).toEqual([202, 202, 202, 202, 202, 429, 429]);
  });

  it('a redefinição também é limitada (10 por IP)', async () => {
    const app = createApp();
    const status: number[] = [];
    for (let i = 0; i < 11; i++) {
      status.push(
        (await request(app).post('/api/auth/reset-password').send({ token: 'x', novaSenha: 'a', confirmacaoSenha: 'a' }))
          .status,
      );
    }
    expect(status.slice(0, 10).every((s) => s === 400)).toBe(true);
    expect(status[10]).toBe(429);
  });
});
