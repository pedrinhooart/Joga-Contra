import { describe, expect, it, vi } from 'vitest';

vi.mock('../src/config/env.js', () => ({
  env: { NODE_ENV: 'test', CORS_ORIGIN: '*', JWT_SECRET: 'x'.repeat(32), JWT_EXPIRES_IN: '1d' },
}));
vi.mock('../src/config/db.js', () => ({
  pool: { execute: vi.fn() },
  checkDatabase: vi.fn().mockResolvedValue('joga_contra_v2'),
}));

import jwt from 'jsonwebtoken';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { checkDatabase, pool } from '../src/config/db.js';

const app = createApp();

describe('saúde', () => {
  it('responde sem banco', async () => {
    const r = await request(app).get('/api/health');
    expect(r.status).toBe(200);
    expect(r.body.data.status).toBe('ok');
  });

  it('recusa banco diferente do esperado', async () => {
    vi.mocked(checkDatabase).mockResolvedValueOnce('joga_contra');
    const r = await request(app).get('/api/health/db');
    expect(r.status).toBe(503);
    expect(r.body.data).toMatchObject({ status: 'banco_incorreto', bancoCorreto: false });
  });

  it('informa o banco em uso', async () => {
    const r = await request(app).get('/api/health/db');
    expect(r.body.data).toEqual({ status: 'ok', conexaoAtiva: true, banco: 'joga_contra_v2', bancoCorreto: true });
  });
});

describe('rotas protegidas', () => {
  const protegidas: [string, string][] = [
    ['get', '/api/auth/eu'],
    ['get', '/api/anuncios'],
    ['post', '/api/anuncios'],
    ['get', '/api/anuncios/meus'],
    ['get', '/api/times/7d0f6f5e-0000-4000-8000-000000000001'],
    ['get', '/api/solicitacoes/minhas'],
    ['post', '/api/solicitacoes'],
    ['get', '/api/partidas/minhas'],
    ['get', '/api/notificacoes'],
  ];

  it.each(protegidas)('%s %s exige token', async (metodo, caminho) => {
    const r = await (request(app) as any)[metodo](caminho);
    expect(r.status).toBe(401);
  });

  it('rejeita token assinado com outra chave', async () => {
    const token = jwt.sign({}, 'y'.repeat(32), { subject: 'abc' });
    const r = await request(app).get('/api/auth/eu').set('Authorization', `Bearer ${token}`);
    expect(r.status).toBe(401);
  });

  it('rejeita token com algoritmo none', async () => {
    const token = jwt.sign({}, '', { subject: 'abc', algorithm: 'none' });
    const r = await request(app).get('/api/auth/eu').set('Authorization', `Bearer ${token}`);
    expect(r.status).toBe(401);
  });

  it('rejeita conta suspensa mesmo com token válido', async () => {
    vi.mocked(pool.execute).mockResolvedValueOnce([[{ status_conta: 'suspensa', id_time: null }], []] as never);
    const token = jwt.sign({}, 'x'.repeat(32), { subject: 'abc' });
    const r = await request(app).get('/api/anuncios').set('Authorization', `Bearer ${token}`);
    expect(r.status).toBe(401);
  });
});

describe('rotas da estrutura antiga', () => {
  it.each(['/api/listings', '/api/teams', '/api/interests/mine/sent', '/api/sports', '/api/catalogs'])(
    '%s não existe mais',
    async (caminho) => {
      expect((await request(app).get(caminho)).status).toBe(404);
    },
  );
});

describe('validação', () => {
  it('rejeita cadastro incompleto sem tocar no banco', async () => {
    vi.mocked(pool.execute).mockClear();
    const r = await request(app).post('/api/auth/cadastro').send({ usuario: { email: 'x' } });
    expect(r.status).toBe(400);
    expect(r.body.error.code).toBe('VALIDATION_ERROR');
    expect(pool.execute).not.toHaveBeenCalled();
  });

  it('corpo JSON inválido vira 400', async () => {
    const r = await request(app).post('/api/auth/login').set('Content-Type', 'application/json').send('{');
    expect(r.status).toBe(400);
  });
});
