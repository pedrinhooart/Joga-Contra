import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { describe, expect, it, vi } from 'vitest';
import {
  cidadeValida,
  FonteOpenStreetMap,
  LocaisEmCache,
  locaisDoOverpass,
  type FonteLocais,
  type LocalEsportivo,
} from '../src/services/locais.js';

const elementos = [
  { lat: -23.96, lon: -46.33, tags: { name: 'Estádio Ulrico Mursa', leisure: 'stadium', sport: 'soccer', 'addr:street': 'Avenida Senador Pinheiro Machado', 'addr:housenumber': '240', 'addr:suburb': 'Marapé' } },
  { center: { lat: -23.97, lon: -46.31 }, tags: { name: 'Arena Society Praia', leisure: 'pitch', sport: 'soccer;futsal' } },
  { lat: -23.95, lon: -46.32, tags: { name: 'Clube XV', leisure: 'sports_centre' } }, // sem esporte: mantém
  { lat: -23.95, lon: -46.32, tags: { name: 'Quadra de Vôlei', leisure: 'pitch', sport: 'volleyball' } }, // outro esporte
  { lat: -23.95, lon: -46.32, tags: { leisure: 'pitch', sport: 'soccer' } }, // sem nome
  { lat: -23.96, lon: -46.33, tags: { name: 'Estádio Ulrico Mursa', leisure: 'stadium', sport: 'soccer' } }, // repetido
];

describe('locais do OpenStreetMap', () => {
  it('mantém só locais de futebol com nome, sem repetidos e em ordem alfabética', () => {
    const locais = locaisDoOverpass(elementos);
    expect(locais.map((l) => l.nome)).toEqual(['Arena Society Praia', 'Clube XV', 'Estádio Ulrico Mursa']);
    expect(locais[2]).toEqual({
      nome: 'Estádio Ulrico Mursa',
      endereco: 'Avenida Senador Pinheiro Machado, 240 - Marapé',
      latitude: -23.96,
      longitude: -46.33,
    });
    expect(locais[0]).toMatchObject({ endereco: null, latitude: -23.97, longitude: -46.31 });
  });

  it('só aceita nomes de cidade seguros para a consulta', () => {
    expect(cidadeValida("Santa Bárbara d'Oeste")).toBe(true);
    expect(cidadeValida('São João del-Rei')).toBe(true);
    expect(cidadeValida('Santos"];out;')).toBe(false);
    expect(cidadeValida('')).toBe(false);
  });

  it('consulta o Overpass identificando o app e trata falhas como indisponibilidade', async () => {
    const baixar = vi.fn(async () => new Response(JSON.stringify({ elements: elementos }), { status: 200 }));
    const fonte = new FonteOpenStreetMap('https://overpass.teste/api', baixar as unknown as typeof fetch);
    expect(await fonte.buscar('Santos', 'SP')).toHaveLength(3);
    const [, opcoes] = baixar.mock.calls[0] as unknown as [string, RequestInit];
    expect((opcoes.headers as Record<string, string>)['User-Agent']).toContain('JogaContra');
    expect(decodeURIComponent(String(opcoes.body))).toContain('"BR-SP"');

    const fora = new FonteOpenStreetMap('https://overpass.teste/api', (async () =>
      new Response('ocupado', { status: 429 })) as unknown as typeof fetch);
    await expect(fora.buscar('Santos', 'SP')).rejects.toMatchObject({ status: 503, code: 'LOCAIS_INDISPONIVEIS' });
  });
});

describe('cache de locais por cidade', () => {
  const um: LocalEsportivo[] = [{ nome: 'Campo', endereco: null, latitude: null, longitude: null }];
  const fonte = (atraso = 0) => {
    const buscar = vi.fn(async () => {
      await new Promise((fim) => setTimeout(fim, atraso));
      return um;
    });
    return { fonte: { nome: 'teste', atribuicao: '', buscar } satisfies FonteLocais, buscar };
  };

  it('pedidos simultâneos da mesma cidade fazem uma só consulta externa', async () => {
    const { fonte: f, buscar } = fonte(20);
    const cache = new LocaisEmCache(f, null);
    const resultados = await Promise.all([cache.buscar('Santos', 'SP'), cache.buscar('santos', 'SP')]);
    expect(resultados).toEqual([um, um]);
    expect(buscar).toHaveBeenCalledTimes(1);
    await cache.buscar('Santos', 'SP');
    expect(buscar).toHaveBeenCalledTimes(1); // da memória
  });

  it('expira e consulta de novo; o disco sobrevive a reinícios', async () => {
    let agora = 1000;
    const pasta = mkdtempSync(path.join(tmpdir(), 'joga-locais-'));
    const { fonte: f, buscar } = fonte();
    await new LocaisEmCache(f, pasta, 100, () => agora).buscar('Santos', 'SP');
    // "Reinício": cache novo lê do disco, sem consultar.
    await new LocaisEmCache(f, pasta, 100, () => agora).buscar('Santos', 'SP');
    expect(buscar).toHaveBeenCalledTimes(1);
    agora += 101;
    await new LocaisEmCache(f, pasta, 100, () => agora).buscar('Santos', 'SP');
    expect(buscar).toHaveBeenCalledTimes(2);
  });
});
