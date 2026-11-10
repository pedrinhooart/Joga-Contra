import { z } from 'zod';
import { id, idReferencia, paginacao, siglaEstado, textoOpcional } from './common.js';

const email = z.string().trim().toLowerCase().email().max(254);
const senha = z.string().min(8).max(72); // bcrypt considera até 72 bytes
const quantidadeTime = z.number().int().min(5).max(60);
const idsModalidades = z.array(idReferencia).min(1).max(10).transform((v) => [...new Set(v)]);
// No cadastro são opcionais: modalidade, categoria, nível e quantidade de cada
// jogo são informados no anúncio.
const idsModalidadesCadastro = z.array(idReferencia).max(10).default([]).transform((v) => [...new Set(v)]);

export const cadastroSchema = z.object({
  usuario: z.object({
    nome: z.string().trim().min(1).max(120),
    email,
    senha,
    telefone: textoOpcional(20),
    cidade: textoOpcional(100),
    siglaEstado: siglaEstado.nullish().transform((v) => v ?? null),
  }),
  time: z.object({
    nome: z.string().trim().min(1).max(120),
    idsModalidades: idsModalidadesCadastro,
    idCategoriaEtaria: idReferencia.nullish().transform((v) => v ?? null),
    idNivelTecnico: idReferencia.nullish().transform((v) => v ?? null),
    quantidadeJogadores: quantidadeTime.nullish().transform((v) => v ?? null),
    cidade: z.string().trim().min(1).max(100),
    siglaEstado,
  }),
});

export const loginSchema = z.object({ email, senha: z.string().min(1).max(72) });
export const recuperarSenhaSchema = z.object({ email });
export const redefinirSenhaSchema = z.object({ codigo: z.string().min(16).max(128), novaSenha: senha });

export const atualizacaoTimeSchema = z
  .object({
    nome: z.string().trim().min(1).max(120),
    // Vazia remove a descrição (o perfil volta a mostrar o convite para escrever).
    descricao: z.string().trim().max(2000).transform((v) => v || null),
    quantidadeJogadores: quantidadeTime,
    idCategoriaEtaria: idReferencia,
    idNivelTecnico: idReferencia,
    idsModalidades,
    cidade: z.string().trim().min(1).max(100),
    siglaEstado,
    telefoneContato: z.string().trim().max(20),
  })
  .partial();

export const anuncioSchema = z.object({
  idModalidade: idReferencia,
  idCategoriaEtaria: idReferencia,
  idNivelTecnico: idReferencia,
  idMandoCampo: idReferencia.nullish().transform((v) => v ?? null),
  quantidadeJogadores: z.number().int().min(5).max(30),
  dataHoraInicio: z.string().datetime({ offset: true }).transform((v) => new Date(v)),
  cidade: z.string().trim().min(1).max(100),
  siglaEstado,
  bairro: textoOpcional(100),
  nomeLocal: z.string().trim().min(1).max(160),
  endereco: textoOpcional(255),
  valorAluguelPorTime: z.number().min(0).max(99999999).nullish().transform((v) => v ?? null),
  descricao: textoOpcional(1000),
});

export const statusAnuncioSchema = z.object({ status: z.enum(['ativo', 'pausado']) });

export const filtroAnunciosSchema = paginacao.extend({
  texto: z.string().trim().max(100).optional(),
  cidade: z.string().trim().max(100).optional(),
  siglaEstado: siglaEstado.optional(),
  idModalidade: z.coerce.number().int().positive().optional(),
  idCategoriaEtaria: z.coerce.number().int().positive().optional(),
  idNivelTecnico: z.coerce.number().int().positive().optional(),
  /** Dia no fuso do aparelho (YYYY-MM-DD). */
  data: z.string().date().optional(),
  /** Partidas a partir deste horário, no fuso do aparelho (HH:mm). */
  horario: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/).optional(),
  /** Deslocamento do fuso do aparelho em minutos. Padrão: Brasília (-180). */
  fusoMinutos: z.coerce.number().int().min(-720).max(840).default(-180),
});

export const solicitacaoSchema = z.object({ idAnuncio: id, mensagemInicial: textoOpcional(1000) });
export const mensagemSchema = z.object({ texto: z.string().trim().min(1).max(1000) });
export const cancelamentoPartidaSchema = z.object({ motivo: textoOpcional(500) });
export const avaliacaoSchema = z.object({
  notas: z
    .array(z.object({ idCriterio: idReferencia, nota: z.number().int().min(1).max(5) }))
    .min(1)
    .max(20),
  comentario: textoOpcional(1000),
});
