import { describe, expect, it } from 'vitest';
import { FUSO_POR_UF, horarioLocal, sqlHorarioLocal, utcDeHorarioLocal } from '../src/services/fuso.js';

describe('horário local da partida pela UF', () => {
  it('21:00 em Cascavel (PR) é 00:00 UTC do dia seguinte, e volta a 21:00', () => {
    const utc = utcDeHorarioLocal('2026-11-26T21:00', 'PR')!;
    expect(utc.toISOString()).toBe('2026-11-27T00:00:00.000Z');
    expect(horarioLocal(utc, 'PR')).toBe('2026-11-26T21:00:00');
  });

  it('respeita os fusos do Brasil', () => {
    expect(utcDeHorarioLocal('2026-11-26T21:00', 'AM')!.toISOString()).toBe('2026-11-27T01:00:00.000Z'); // -4
    expect(utcDeHorarioLocal('2026-11-26T21:00', 'AC')!.toISOString()).toBe('2026-11-27T02:00:00.000Z'); // -5
    expect(utcDeHorarioLocal('2026-11-26T21:00', 'SP')!.toISOString()).toBe('2026-11-27T00:00:00.000Z'); // -3
  });

  it('o mesmo instante aparece igual, sem depender de quem vê', () => {
    const instante = new Date('2026-11-27T00:00:00Z');
    expect(horarioLocal(instante, 'PR')).toBe('2026-11-26T21:00:00');
    expect(horarioLocal(instante, 'MT')).toBe('2026-11-26T20:00:00');
  });

  it('recusa datas e horários impossíveis', () => {
    expect(utcDeHorarioLocal('2026-02-31T21:00', 'PR')).toBeNull();
    expect(utcDeHorarioLocal('2026-11-26T25:00', 'PR')).toBeNull();
    expect(utcDeHorarioLocal('26/11/2026 21:00', 'PR')).toBeNull();
  });

  it('cobre as 27 UFs e gera o SQL com deslocamentos fixos', () => {
    expect(Object.keys(FUSO_POR_UF)).toHaveLength(27);
    const sql = sqlHorarioLocal('a.data_hora_inicio', 'a.sigla_estado');
    expect(sql).toContain('THEN -180');
    expect(sql).toContain('THEN -240');
    expect(sql).toContain('THEN -300');
    expect(sql).toMatch(/'PR'/);
  });
});
