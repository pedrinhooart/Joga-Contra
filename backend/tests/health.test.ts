import { describe, expect, it, vi } from 'vitest';
vi.mock('../src/config/env.js',()=>({env:{CORS_ORIGIN:'*',JWT_SECRET:'x'.repeat(32),JWT_EXPIRES_IN:'1d'}}));
vi.mock('../src/config/db.js',()=>({pool:{execute:vi.fn()},checkDatabase:vi.fn().mockResolvedValue(undefined)}));
import request from 'supertest'; import { createApp } from '../src/app.js';
describe('health',()=>{it('retorna saúde da API sem banco',async()=>{const r=await request(createApp()).get('/api/health');expect(r.status).toBe(200);expect(r.body.data.status).toBe('ok');});it('rejeita rota protegida sem token',async()=>{const r=await request(createApp()).get('/api/auth/me');expect(r.status).toBe(401);});});
