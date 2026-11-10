import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { env } from '../config/env.js';
import { ApiError } from '../middlewares/error-handler.js';

/** Local esportivo real, vindo da fonte de pesquisa (nunca inventado). */
export interface LocalEsportivo {
  nome: string;
  endereco: string | null;
  latitude: number | null;
  longitude: number | null;
}

/** Fonte de locais. Hoje: OpenStreetMap. Uma versão Google Places (chave só no servidor) pode substituí-la. */
export interface FonteLocais {
  readonly nome: string;
  readonly atribuicao: string;
  buscar(cidade: string, uf: string): Promise<LocalEsportivo[]>;
}

/** Esportes que interessam: futebol de campo/society, futsal e quadras poliesportivas. */
const ESPORTES_ACEITOS = new Set(['soccer', 'futsal', 'multi', 'society', 'football_7', 'five-a-side']);

type ElementoOsm = {
  lat?: number;
  lon?: number;
  center?: { lat: number; lon: number };
  tags?: Record<string, string>;
};

/** Converte a resposta do Overpass em locais úteis, sem duplicados e em ordem alfabética. */
export function locaisDoOverpass(elementos: ElementoOsm[]): LocalEsportivo[] {
  const vistos = new Set<string>();
  const locais: LocalEsportivo[] = [];
  for (const e of elementos) {
    const tags = e.tags ?? {};
    const nome = tags.name?.trim();
    if (!nome) continue;
    // Com esporte informado, só os de futebol/futsal/poliesportivo.
    const esportes = (tags.sport ?? '').split(';').map((s) => s.trim()).filter(Boolean);
    if (esportes.length && !esportes.some((s) => ESPORTES_ACEITOS.has(s))) continue;
    const latitude = e.lat ?? e.center?.lat ?? null;
    const longitude = e.lon ?? e.center?.lon ?? null;
    const rua = [tags['addr:street'], tags['addr:housenumber']].filter(Boolean).join(', ');
    const endereco = [rua, tags['addr:suburb']].filter(Boolean).join(' - ') || null;
    const chave = `${nome.toLowerCase()}|${latitude?.toFixed(3)}|${longitude?.toFixed(3)}`;
    if (vistos.has(chave)) continue;
    vistos.add(chave);
    locais.push({
      nome: nome.slice(0, 160),
      endereco: endereco?.slice(0, 255) ?? null,
      latitude: latitude === null ? null : Number(latitude.toFixed(6)),
      longitude: longitude === null ? null : Number(longitude.toFixed(6)),
    });
  }
  const ordem = new Intl.Collator('pt-BR', { sensitivity: 'base' });
  return locais.sort((a, b) => ordem.compare(a.nome, b.nome)).slice(0, 300);
}

/** Nome de cidade seguro para entrar na consulta (letras, espaços, apóstrofo, hífen e ponto). */
export function cidadeValida(cidade: string) {
  return /^[\p{L}\p{M}][\p{L}\p{M} '’.\-]{0,99}$/u.test(cidade);
}

/** OpenStreetMap via Overpass: gratuito e sem chave. Exige identificar o app (User-Agent). */
export class FonteOpenStreetMap implements FonteLocais {
  readonly nome = 'OpenStreetMap';
  readonly atribuicao = '© colaboradores do OpenStreetMap';

  constructor(
    private readonly url = env.OVERPASS_URL ?? 'https://overpass-api.de/api/interpreter',
    private readonly baixar: typeof fetch = fetch,
  ) {}

  async buscar(cidade: string, uf: string) {
    const consulta = `[out:json][timeout:60];
area["ISO3166-2"="BR-${uf}"]["admin_level"="4"]->.uf;
rel(area.uf)["boundary"="administrative"]["admin_level"="8"]["name"="${cidade}"];
map_to_area->.cidade;
nwr(area.cidade)["name"]["leisure"~"^(pitch|sports_centre|stadium)$"];
out center tags 500;`;
    let resposta: Response;
    try {
      resposta = await this.baixar(this.url, {
        method: 'POST',
        headers: {
          'User-Agent': 'JogaContra/1.0 (busca de locais esportivos)',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: `data=${encodeURIComponent(consulta)}`,
        signal: AbortSignal.timeout(90_000),
      });
    } catch {
      throw new ApiError(503, 'A busca de locais não respondeu. Digite o local.', 'LOCAIS_INDISPONIVEIS');
    }
    if (!resposta.ok) {
      throw new ApiError(503, 'A busca de locais está indisponível agora. Digite o local.', 'LOCAIS_INDISPONIVEIS');
    }
    const dados = (await resposta.json()) as { elements?: ElementoOsm[] };
    return locaisDoOverpass(dados.elements ?? []);
  }
}

const SETE_DIAS_MS = 7 * 24 * 60 * 60_000;

/**
 * Cache por cidade, em memória e em disco (sobrevive a reinícios). Pedidos
 * simultâneos da mesma cidade compartilham uma única consulta externa.
 */
export class LocaisEmCache {
  private readonly memoria = new Map<string, { expira: number; locais: LocalEsportivo[] }>();
  private readonly emAndamento = new Map<string, Promise<LocalEsportivo[]>>();

  constructor(
    readonly fonte: FonteLocais,
    private readonly pasta: string | null = path.resolve(env.ARQUIVOS_DIR ?? 'arquivos', 'cache', 'locais'),
    private readonly validade = SETE_DIAS_MS,
    private readonly agora = () => Date.now(),
  ) {}

  async buscar(cidade: string, uf: string): Promise<LocalEsportivo[]> {
    const chave = `${uf}-${cidade.toLowerCase().normalize('NFD').replace(/[^\w]+/g, '_')}`;
    const guardado = this.memoria.get(chave) ?? (await this.lerDisco(chave));
    if (guardado && guardado.expira > this.agora()) {
      this.memoria.set(chave, guardado);
      return guardado.locais;
    }
    const pendente = this.emAndamento.get(chave);
    if (pendente) return pendente;
    const consulta = this.fonte
      .buscar(cidade, uf)
      .then(async (locais) => {
        const item = { expira: this.agora() + this.validade, locais };
        this.memoria.set(chave, item);
        await this.gravarDisco(chave, item);
        return locais;
      })
      .finally(() => this.emAndamento.delete(chave));
    this.emAndamento.set(chave, consulta);
    return consulta;
  }

  private async lerDisco(chave: string) {
    if (!this.pasta) return undefined;
    try {
      return JSON.parse(await readFile(path.join(this.pasta, `${chave}.json`), 'utf8')) as {
        expira: number;
        locais: LocalEsportivo[];
      };
    } catch {
      return undefined;
    }
  }

  private async gravarDisco(chave: string, item: { expira: number; locais: LocalEsportivo[] }) {
    if (!this.pasta) return;
    try {
      await mkdir(this.pasta, { recursive: true });
      await writeFile(path.join(this.pasta, `${chave}.json`), JSON.stringify(item));
    } catch (e) {
      console.warn('Cache de locais não gravado:', (e as NodeJS.ErrnoException)?.code);
    }
  }
}

export const locais = new LocaisEmCache(new FonteOpenStreetMap());
