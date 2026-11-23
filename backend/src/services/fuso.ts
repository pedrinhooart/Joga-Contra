/**
 * Horário das partidas. O banco guarda o instante em UTC; o horário que as
 * pessoas veem e escolhem é o horário local de onde a partida acontece (a UF do
 * anúncio), nunca o fuso do aparelho de quem cria ou de quem vê.
 */

/** Fuso oficial de cada UF (IANA). Exceções municipais, como o oeste do AM e
 * Fernando de Noronha, usam o fuso principal do estado. */
export const FUSO_POR_UF: Record<string, string> = {
  AC: 'America/Rio_Branco',
  AL: 'America/Maceio',
  AM: 'America/Manaus',
  AP: 'America/Belem',
  BA: 'America/Bahia',
  CE: 'America/Fortaleza',
  DF: 'America/Sao_Paulo',
  ES: 'America/Sao_Paulo',
  GO: 'America/Sao_Paulo',
  MA: 'America/Fortaleza',
  MG: 'America/Sao_Paulo',
  MS: 'America/Campo_Grande',
  MT: 'America/Cuiaba',
  PA: 'America/Belem',
  PB: 'America/Fortaleza',
  PE: 'America/Recife',
  PI: 'America/Fortaleza',
  PR: 'America/Sao_Paulo',
  RJ: 'America/Sao_Paulo',
  RN: 'America/Fortaleza',
  RO: 'America/Porto_Velho',
  RR: 'America/Boa_Vista',
  RS: 'America/Sao_Paulo',
  SC: 'America/Sao_Paulo',
  SE: 'America/Maceio',
  SP: 'America/Sao_Paulo',
  TO: 'America/Araguaina',
};

export const fusoDaUf = (uf: string | null | undefined) => FUSO_POR_UF[uf ?? ''] ?? 'America/Sao_Paulo';

const formatadores = new Map<string, Intl.DateTimeFormat>();
function partes(zona: string, instante: number) {
  let f = formatadores.get(zona);
  if (!f) {
    f = new Intl.DateTimeFormat('en-US', {
      timeZone: zona,
      hourCycle: 'h23',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
    formatadores.set(zona, f);
  }
  const p = Object.fromEntries(f.formatToParts(new Date(instante)).map((x) => [x.type, x.value]));
  return { ano: +p.year, mes: +p.month, dia: +p.day, hora: +p.hour, minuto: +p.minute, segundo: +p.second };
}

/** Diferença, em minutos, entre o horário local da zona e o UTC naquele instante. */
export function deslocamentoMinutos(zona: string, instante: number) {
  const l = partes(zona, instante);
  const comoUtc = Date.UTC(l.ano, l.mes - 1, l.dia, l.hora, l.minuto, l.segundo);
  return Math.round((comoUtc - Math.floor(instante / 1000) * 1000) / 60_000);
}

const HORARIO_LOCAL = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?$/;

/** "2026-11-26T21:00" em PR → instante UTC 2026-11-27T00:00:00Z. Nulo se inválido. */
export function utcDeHorarioLocal(local: string, uf: string): Date | null {
  const m = HORARIO_LOCAL.exec(local);
  if (!m) return null;
  const [ano, mes, dia, hora, minuto, segundo = '0'] = m.slice(1).map((v) => v ?? '0');
  const comoUtc = Date.UTC(+ano, +mes - 1, +dia, +hora, +minuto, +segundo);
  const zona = fusoDaUf(uf);
  // Duas passagens acertam o deslocamento mesmo perto de mudança de horário.
  let instante = comoUtc - deslocamentoMinutos(zona, comoUtc) * 60_000;
  instante = comoUtc - deslocamentoMinutos(zona, instante) * 60_000;
  const conferido = partes(zona, instante);
  // Recusa datas impossíveis (31/02, 25:00...).
  if (conferido.ano !== +ano || conferido.mes !== +mes || conferido.dia !== +dia || conferido.hora !== +hora) {
    return null;
  }
  return new Date(instante);
}

/** Instante UTC → horário local da UF, sem fuso: "2026-11-26T21:00:00". */
export function horarioLocal(instante: Date | null | undefined, uf: string | null | undefined) {
  if (!(instante instanceof Date)) return null;
  const l = partes(fusoDaUf(uf), instante.getTime());
  const d2 = (n: number) => String(n).padStart(2, '0');
  return `${l.ano}-${d2(l.mes)}-${d2(l.dia)}T${d2(l.hora)}:${d2(l.minuto)}:${d2(l.segundo)}`;
}

/**
 * Expressão SQL do horário local de uma partida, para filtros por data e hora.
 * O Brasil não tem horário de verão desde 2019: cada UF tem deslocamento fixo,
 * calculado aqui a partir dos fusos acima (sem depender das tabelas de fuso do MySQL).
 */
export function sqlHorarioLocal(colunaInicio: string, colunaUf: string) {
  const agora = Date.now();
  const porDeslocamento = new Map<number, string[]>();
  for (const [uf, zona] of Object.entries(FUSO_POR_UF)) {
    const minutos = deslocamentoMinutos(zona, agora);
    porDeslocamento.set(minutos, [...(porDeslocamento.get(minutos) ?? []), uf]);
  }
  const casos = [...porDeslocamento]
    .map(([minutos, ufs]) => `WHEN ${colunaUf} IN (${ufs.map((u) => `'${u}'`).join(', ')}) THEN ${minutos}`)
    .join(' ');
  return `(${colunaInicio} + INTERVAL (CASE ${casos} ELSE -180 END) MINUTE)`;
}
