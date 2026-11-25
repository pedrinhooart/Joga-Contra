import { z } from 'zod';
import { utcDeHorarioLocal } from '../services/fuso.js';
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
// As regras da nova senha e da confirmação são conferidas na rota, com mensagens próprias.
export const redefinirSenhaSchema = z.object({
  token: z.string().max(200),
  novaSenha: z.string().max(200),
  confirmacaoSenha: z.string().max(200),
});

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

// Categoria, quantidade, mando e bairro são opcionais: o formulário atual não
// os pede (anúncios antigos mantêm os seus). A duração é obrigatória.
export const anuncioSchema = z
  .object({
    idModalidade: idReferencia,
    idCategoriaEtaria: idReferencia.nullish().transform((v) => v ?? null),
    idNivelTecnico: idReferencia,
    idMandoCampo: idReferencia.nullish().transform((v) => v ?? null),
    quantidadeJogadores: z.number().int().min(5).max(30).nullish().transform((v) => v ?? null),
    // Horário local da partida, na UF do anúncio ("2026-11-26T21:00"): é o que o
    // app envia. Instante com fuso explícito continua aceito (clientes antigos).
    dataHoraLocal: z
      .string()
      .regex(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$/)
      .optional(),
    dataHoraInicio: z
      .string()
      .datetime({ offset: true })
      .transform((v) => new Date(v))
      .optional(),
    duracaoMinutos: z.number().int().min(15).max(600),
    cidade: z.string().trim().min(1).max(100),
    siglaEstado,
    bairro: textoOpcional(100),
    nomeLocal: z.string().trim().min(1).max(160),
    endereco: textoOpcional(255),
    latitude: z.number().min(-90).max(90).nullish().transform((v) => v ?? null),
    longitude: z.number().min(-180).max(180).nullish().transform((v) => v ?? null),
    valorAluguelPorTime: z.number().min(0).max(99999999).nullish().transform((v) => v ?? null),
    descricao: textoOpcional(1000),
  })
  .refine((a) => a.dataHoraLocal !== undefined || a.dataHoraInicio !== undefined, {
    message: 'Informe a data e o horário da partida.',
    path: ['dataHoraLocal'],
  })
  .refine((a) => (a.latitude === null) === (a.longitude === null), {
    message: 'Informe latitude e longitude juntas.',
    path: ['latitude'],
  });

/** Anúncio validado, com o instante UTC calculado pelo fuso da UF do anúncio. */
export const anuncioComInicioSchema = anuncioSchema.transform((a, ctx) => {
  const inicio = a.dataHoraLocal ? utcDeHorarioLocal(a.dataHoraLocal, a.siglaEstado) : a.dataHoraInicio!;
  if (!inicio) {
    ctx.addIssue({ code: z.ZodIssueCode.custom, message: 'Data ou horário inválido.', path: ['dataHoraLocal'] });
    return z.NEVER;
  }
  return { ...a, dataHoraInicio: inicio };
});

export const statusAnuncioSchema = z.object({ status: z.enum(['ativo', 'pausado']) });

export const filtroAnunciosSchema = paginacao.extend({
  texto: z.string().trim().max(100).optional(),
  cidade: z.string().trim().max(100).optional(),
  siglaEstado: siglaEstado.optional(),
  idModalidade: z.coerce.number().int().positive().optional(),
  idCategoriaEtaria: z.coerce.number().int().positive().optional(),
  idNivelTecnico: z.coerce.number().int().positive().optional(),
  /** Dia no horário local da partida (UF do anúncio), YYYY-MM-DD. */
  data: z.string().date().optional(),
  /** Partidas a partir deste horário local da partida (HH:mm). */
  horario: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/).optional(),
  /** Ignorado: o horário segue a UF do anúncio. Mantido para clientes antigos. */
  fusoMinutos: z.coerce.number().int().min(-720).max(840).default(-180),
});

export const solicitacaoSchema = z.object({ idAnuncio: id, mensagemInicial: textoOpcional(1000) });
export const mensagemSchema = z.object({
  texto: z.string().trim().min(1).max(1000),
  /** Gerado pelo app (UUID em minúsculas): repetir o envio não duplica a mensagem. */
  idMensagem: z.string().regex(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/).optional(),
});
export const cancelamentoPartidaSchema = z.object({ motivo: textoOpcional(500) });
export const avaliacaoSchema = z.object({
  notas: z
    .array(z.object({ idCriterio: idReferencia, nota: z.number().int().min(1).max(5) }))
    .min(1)
    .max(20),
  comentario: textoOpcional(1000),
});
