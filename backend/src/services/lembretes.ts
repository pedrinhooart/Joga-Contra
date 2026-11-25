import { env } from '../config/env.js';
import { pool } from '../config/db.js';
import { horarioLocal } from './fuso.js';
import { consultar, dataSql, emTransacao, type Linha } from './helpers.js';
import { criarNotificacao } from './notificacoes.js';

/**
 * Lembretes de jogo: 24 h, 2 h e 30 min antes, aos dois capitães, só de
 * partidas confirmadas.
 *
 * Sem timers guardando lembretes futuros: a cada minuto a API procura no banco
 * as partidas confirmadas que entraram numa janela e grava em
 * `lembretes_partidas` (chave: partida + tipo + horário de início) o que tratou.
 * Por isso reiniciar a API não perde nem repete lembretes, vários servidores
 * podem rodar juntos, e um jogo cancelado simplesmente deixa de ser encontrado.
 *
 * Janela perdida não é enviada atrasada: se o jogo foi confirmado depois do
 * início da janela (ex.: confirmado 10 h antes, sem o de 24 h) ou a API ficou
 * fora do ar, vale só o lembrete mais próximo do jogo; os anteriores ficam como
 * 'pulado'. Nada é enviado depois do início do jogo.
 */
export type TipoLembrete = '24h' | '2h' | '30min';

/** Do mais próximo do jogo para o mais distante. */
export const JANELAS: { tipo: TipoLembrete; antesMs: number }[] = [
  { tipo: '30min', antesMs: 30 * 60_000 },
  { tipo: '2h', antesMs: 2 * 3_600_000 },
  { tipo: '24h', antesMs: 24 * 3_600_000 },
];

export type Plano = { enviar: TipoLembrete | null; pular: TipoLembrete[] };

/**
 * O que fazer agora com uma partida (função pura: relógio injetado).
 * `confirmadaEm`: janelas que começaram antes da confirmação não são enviadas.
 */
export function planejarLembretes(inicio: Date, confirmadaEm: Date, agora: Date): Plano {
  const falta = inicio.getTime() - agora.getTime();
  if (falta <= 0) return { enviar: null, pular: [] };
  const abertas = JANELAS.filter((j) => falta <= j.antesMs); // janelas já iniciadas
  if (abertas.length === 0) return { enviar: null, pular: [] };
  const [atual, ...anteriores] = abertas;
  const atualValida = confirmadaEm.getTime() <= inicio.getTime() - atual.antesMs;
  return {
    enviar: atualValida ? atual.tipo : null,
    pular: [...(atualValida ? [] : [atual.tipo]), ...anteriores.map((j) => j.tipo)],
  };
}

/** "21h" ou "21h30" no horário local do jogo. */
function horaTexto(inicio: Date, uf: string) {
  const l = horarioLocal(inicio, uf)!; // "2026-11-26T21:30:00"
  return `${l.slice(11, 13)}h${l.slice(14, 16) === '00' ? '' : l.slice(14, 16)}`;
}

/** "hoje", "amanhã" ou "em 26/11", pelo calendário local do jogo. */
function diaTexto(inicio: Date, agora: Date, uf: string) {
  const dia = (d: Date) => horarioLocal(d, uf)!.slice(0, 10);
  const amanha = dia(new Date(agora.getTime() + 24 * 3_600_000));
  const doJogo = dia(inicio);
  if (doJogo === dia(agora)) return 'hoje';
  if (doJogo === amanha) return 'amanhã';
  return `em ${doJogo.slice(8, 10)}/${doJogo.slice(5, 7)}`;
}

/**
 * Título e texto do lembrete para um dos capitães (com o adversário dele).
 * "em <local>" (não "na"): os locais têm nomes de gênero variado ("Campo...", "Arena...").
 */
export function textoLembrete(tipo: TipoLembrete, p: { inicio: Date; uf: string; local: string; adversario: string }, agora: Date) {
  const hora = horaTexto(p.inicio, p.uf);
  switch (tipo) {
    case '24h': {
      const dia = diaTexto(p.inicio, agora, p.uf);
      return {
        titulo: `Lembrete: jogo ${dia === 'hoje' ? 'hoje' : dia === 'amanhã' ? 'amanhã' : dia}`,
        mensagem: `Seu jogo contra o time ${p.adversario} acontece ${dia} às ${hora}, em ${p.local}.`,
      };
    }
    case '2h':
      return {
        titulo: 'Lembrete: jogo em 2 horas',
        mensagem: `Seu jogo contra o time ${p.adversario} começa em 2 horas, às ${hora}, em ${p.local}.`,
      };
    case '30min':
      return {
        titulo: 'Lembrete: jogo em 30 minutos',
        mensagem: `Seu jogo contra o time ${p.adversario} começa em 30 minutos, em ${p.local}.`,
      };
  }
}

async function tratarPartida(p: Linha, agora: Date): Promise<TipoLembrete | null> {
  const inicio = new Date(p.data_hora_inicio);
  const plano = planejarLembretes(inicio, new Date(p.data_criacao), agora);
  if (!plano.enviar && plano.pular.length === 0) return null;
  const inicioSql = dataSql(inicio);

  return emTransacao(async (db) => {
    // Relê com bloqueio: cancelada no meio do caminho não recebe lembrete.
    const [atual] = await consultar(db, 'SELECT status FROM partidas WHERE id_partida = ? FOR UPDATE', [p.id_partida]);
    if (atual?.status !== 'confirmada') return null;

    const tratados = new Set(
      (
        await consultar(
          db,
          'SELECT tipo FROM lembretes_partidas WHERE id_partida = ? AND data_hora_inicio = ?',
          [p.id_partida, inicioSql],
        )
      ).map((l) => l.tipo),
    );
    for (const tipo of plano.pular.filter((t) => !tratados.has(t))) {
      await db.execute(
        `INSERT INTO lembretes_partidas (id_partida, tipo, data_hora_inicio, status, data_processamento)
         VALUES (?, ?, ?, 'pulado', ?)`,
        [p.id_partida, tipo, inicioSql, dataSql(agora)],
      );
    }
    if (!plano.enviar || tratados.has(plano.enviar)) return null;

    await db.execute(
      `INSERT INTO lembretes_partidas (id_partida, tipo, data_hora_inicio, status, data_processamento)
       VALUES (?, ?, ?, 'enviado', ?)`,
      [p.id_partida, plano.enviar, inicioSql, dataSql(agora)],
    );
    for (const [destinatario, adversario] of [
      [p.capitao_anunciante, p.nome_adversario],
      [p.capitao_adversario, p.nome_anunciante],
    ]) {
      const texto = textoLembrete(plano.enviar, { inicio, uf: p.sigla_estado, local: p.nome_local, adversario }, agora);
      await criarNotificacao(db, {
        idDestinatario: destinatario,
        tipo: 'lembrete_partida',
        ...texto,
        idPartida: p.id_partida,
        chaveEvento: `lembrete_${plano.enviar}:${p.id_partida}:${inicio.getTime()}`,
      });
    }
    return plano.enviar;
  });
}

/**
 * Procura e envia os lembretes devidos. `agora` é injetável (testes);
 * `apenasPartidas` restringe às partidas dadas (testes, sem tocar em outras).
 * Partidas anteriores a ROTINAS_PRESERVAR_ATE não são tocadas (homologação).
 */
export async function processarLembretes(opcoes: { agora?: Date; apenasPartidas?: string[] } = {}) {
  const agora = opcoes.agora ?? new Date();
  const filtros: string[] = [];
  const params: unknown[] = [dataSql(agora), dataSql(new Date(agora.getTime() + JANELAS.at(-1)!.antesMs))];
  if (env.ROTINAS_PRESERVAR_ATE) {
    filtros.push('AND p.data_criacao > ?');
    params.push(dataSql(env.ROTINAS_PRESERVAR_ATE));
  }
  if (opcoes.apenasPartidas) {
    if (opcoes.apenasPartidas.length === 0) return {};
    filtros.push(`AND p.id_partida IN (${opcoes.apenasPartidas.map(() => '?').join(', ')})`);
    params.push(...opcoes.apenasPartidas);
  }
  // Usa o índice (status, data_hora_inicio): só as confirmadas das próximas 24 h.
  const partidas = await consultar(
    pool,
    `SELECT p.id_partida, p.data_hora_inicio, p.data_criacao, p.sigla_estado, p.nome_local,
            ta.id_capitao AS capitao_anunciante, ta.nome AS nome_anunciante,
            tv.id_capitao AS capitao_adversario, tv.nome AS nome_adversario
       FROM partidas p
       JOIN times ta ON ta.id_time = p.id_time_anunciante
       JOIN times tv ON tv.id_time = p.id_time_adversario
      WHERE p.status = 'confirmada' AND p.data_hora_inicio > ? AND p.data_hora_inicio <= ? ${filtros.join(' ')}`,
    params,
  );
  const enviados: Record<string, number> = {};
  for (const p of partidas) {
    try {
      const tipo = await tratarPartida(p, agora);
      if (tipo) enviados[tipo] = (enviados[tipo] ?? 0) + 1;
    } catch (erro: any) {
      // Outro servidor tratou ao mesmo tempo (chave duplicada) ou falha pontual:
      // a próxima passada resolve, sem duplicar.
      if (erro?.code !== 'ER_DUP_ENTRY') console.error(`Lembretes: partida não tratada (${erro?.code ?? 'erro'}).`);
    }
  }
  return enviados;
}

/** Verifica os lembretes a cada minuto (o estado fica no banco, não aqui). */
export function agendarLembretes(intervaloMs = 60_000) {
  let ocupado = false;
  const rodar = async () => {
    if (ocupado) return;
    ocupado = true;
    try {
      const r = await processarLembretes();
      const total = Object.values(r).reduce((a, b) => a + b, 0);
      if (total) console.log(`Lembretes de jogo: ${total} partida(s) avisada(s).`);
    } catch (erro: any) {
      console.error(`Lembretes: verificação falhou (${erro?.code ?? 'erro'}).`);
    } finally {
      ocupado = false;
    }
  };
  void rodar();
  return setInterval(rodar, intervaloMs);
}
