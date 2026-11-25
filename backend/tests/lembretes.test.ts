import { describe, expect, it, vi } from 'vitest';

vi.mock('../src/config/env.js', () => ({ env: { NODE_ENV: 'test' } }));
vi.mock('../src/config/db.js', () => ({ pool: { execute: vi.fn() } }));

import { planejarLembretes, textoLembrete } from '../src/services/lembretes.js';

const H = 3_600_000;
const inicio = new Date('2026-11-27T00:00:00.000Z'); // 26/11 às 21h em São Paulo
const antes = (ms: number) => new Date(inicio.getTime() - ms);
const confirmadaCedo = new Date('2026-11-01T12:00:00.000Z');

describe('planejamento dos lembretes (relógio injetado)', () => {
  it.each([
    ['30 h antes', antes(30 * H), null, []],
    ['24 h antes', antes(24 * H), '24h', []],
    ['23 h antes', antes(23 * H), '24h', []],
    ['2 h antes', antes(2 * H), '2h', ['24h']],
    ['31 min antes', antes(31 * 60_000), '2h', ['24h']],
    ['30 min antes', antes(30 * 60_000), '30min', ['2h', '24h']],
    ['1 min antes', antes(60_000), '30min', ['2h', '24h']],
    ['na hora do jogo', inicio, null, []],
    ['depois do início', new Date(inicio.getTime() + 60_000), null, []],
  ])('%s', (_, agora, enviar, pular) => {
    expect(planejarLembretes(inicio, confirmadaCedo, agora as Date)).toEqual({ enviar, pular });
  });

  it('jogo confirmado dentro da janela: sem lembrete atrasado', () => {
    // Confirmado 10 h antes: o de 24 h é pulado; o de 2 h sai na hora certa.
    const confirmada = antes(10 * H);
    expect(planejarLembretes(inicio, confirmada, antes(9 * H))).toEqual({ enviar: null, pular: ['24h'] });
    expect(planejarLembretes(inicio, confirmada, antes(2 * H))).toEqual({ enviar: '2h', pular: ['24h'] });
    // Confirmado 20 min antes: até a janela de 30 min já tinha começado; nenhum lembrete.
    expect(planejarLembretes(inicio, antes(20 * 60_000), antes(19 * 60_000))).toEqual({
      enviar: null,
      pular: ['30min', '2h', '24h'],
    });
  });

  it('servidor fora do ar nas janelas: vale só o lembrete mais próximo do jogo', () => {
    expect(planejarLembretes(inicio, confirmadaCedo, antes(10 * 60_000))).toEqual({ enviar: '30min', pular: ['2h', '24h'] });
  });

  it('horário alterado: o plano segue o novo início', () => {
    const novoInicio = new Date(inicio.getTime() + 2 * 24 * H);
    expect(planejarLembretes(novoInicio, confirmadaCedo, antes(2 * H))).toEqual({ enviar: null, pular: [] });
  });
});

describe('textos com o horário local do jogo', () => {
  const p = { inicio, uf: 'SP', local: 'Arena Biase', adversario: 'JOGA' };

  it('24 h: "amanhã às 21h, em Arena Biase"', () => {
    expect(textoLembrete('24h', p, antes(24 * H))).toEqual({
      titulo: 'Lembrete: jogo amanhã',
      mensagem: 'Seu jogo contra o time JOGA acontece amanhã às 21h, em Arena Biase.',
    });
  });

  it('24 h processado no mesmo dia: "hoje"', () => {
    expect(textoLembrete('24h', p, antes(5 * H)).mensagem).toBe('Seu jogo contra o time JOGA acontece hoje às 21h, em Arena Biase.');
  });

  it('2 h e 30 min', () => {
    expect(textoLembrete('2h', p, antes(2 * H)).mensagem).toBe('Seu jogo contra o time JOGA começa em 2 horas, às 21h, em Arena Biase.');
    expect(textoLembrete('30min', p, antes(30 * 60_000)).mensagem).toBe('Seu jogo contra o time JOGA começa em 30 minutos, em Arena Biase.');
  });

  it('fuso da UF do jogo: o mesmo instante é 19h no Acre e 20h30 em minutos quebrados', () => {
    expect(textoLembrete('24h', { ...p, uf: 'AC' }, antes(24 * H)).mensagem).toContain('amanhã às 19h');
    const quebrado = new Date('2026-11-26T23:30:00.000Z');
    expect(textoLembrete('2h', { ...p, inicio: quebrado }, new Date(quebrado.getTime() - 2 * H)).mensagem).toContain('às 20h30');
  });

  it('dia por calendário local: perto da meia-noite em SP ainda é "hoje"', () => {
    // Jogo às 23h de 26/11 (SP) = 02:00 UTC de 27/11; lembrete às 22h (SP) do mesmo dia.
    const tarde = new Date('2026-11-27T02:00:00.000Z');
    expect(textoLembrete('24h', { ...p, inicio: tarde }, new Date(tarde.getTime() - H)).mensagem).toContain('hoje às 23h');
  });
});
