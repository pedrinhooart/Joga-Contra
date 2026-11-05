import { beforeEach, describe, expect, it, vi } from 'vitest';

const { env, query } = vi.hoisted(() => ({
  env: { HORAS_PARTIDA_REALIZADA: 3, ROTINAS_PRESERVAR_ATE: undefined as Date | undefined },
  query: vi.fn(),
}));
vi.mock('../src/config/env.js', () => ({ env }));
vi.mock('../src/config/db.js', () => ({ pool: { query } }));

import { executarRotinas } from '../src/services/rotinas.js';

const CORTE = new Date('2026-11-05T14:00:00.000Z');
const chamadas = () => query.mock.calls.map(([sql]) => sql as string).filter((sql) => sql.startsWith('CALL'));

function preservados(anuncios: number, partidas: number) {
  query.mockImplementation(async (sql: string) => (sql.startsWith('CALL') ? [[]] : [[{ anuncios, partidas }]]));
}

describe('proteção das rotinas', () => {
  beforeEach(() => {
    query.mockReset();
    vi.spyOn(console, 'warn').mockImplementation(() => {});
    env.ROTINAS_PRESERVAR_ATE = CORTE;
  });

  it('roda as duas rotinas quando nenhum registro preservado seria alterado', async () => {
    preservados(0, 0);
    await executarRotinas();
    expect(chamadas()).toEqual(['CALL proc_expirar_anuncios()', 'CALL proc_marcar_partidas_realizadas(?)']);
  });

  it('suspende só a expiração quando atingiria um anúncio preservado', async () => {
    preservados(1, 0);
    await executarRotinas();
    expect(chamadas()).toEqual(['CALL proc_marcar_partidas_realizadas(?)']);
  });

  it('suspende só a marcação quando atingiria uma partida preservada', async () => {
    preservados(0, 2);
    await executarRotinas();
    expect(chamadas()).toEqual(['CALL proc_expirar_anuncios()']);
  });

  it('sem data de corte funciona sem consulta prévia', async () => {
    env.ROTINAS_PRESERVAR_ATE = undefined;
    preservados(9, 9);
    await executarRotinas();
    expect(query).toHaveBeenCalledTimes(2);
    expect(chamadas()).toHaveLength(2);
  });
});
