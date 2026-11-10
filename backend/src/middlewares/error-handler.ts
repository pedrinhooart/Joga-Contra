import type { ErrorRequestHandler, RequestHandler, Response } from 'express';
import { ZodError } from 'zod';

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
    public code = 'REQUEST_ERROR',
  ) {
    super(message);
  }
}

export const notFound: RequestHandler = (_req, _res, next) =>
  next(new ApiError(404, 'Rota não encontrada.', 'NOT_FOUND'));

/** Restrições de unicidade com mensagem própria para o usuário. */
const MENSAGENS_UNICIDADE: Record<string, string> = {
  un_usuarios_email: 'Este e-mail já está cadastrado.',
  un_times_capitao: 'Este capitão já possui um time.',
  un_solicitacoes_confronto_pendente: 'Seu time já tem uma solicitação pendente para este anúncio.',
  un_solicitacoes_confronto_confirmada: 'Este anúncio já tem uma partida confirmada.',
  un_partidas_anuncio: 'Este anúncio já tem uma partida confirmada.',
  un_avaliacoes_partida_avaliador: 'Seu time já avaliou esta partida.',
};

const responder = (res: Response, status: number, code: string, message: string, details?: unknown) =>
  res.status(status).json({ error: { code, message, details } });

export const errorHandler: ErrorRequestHandler = (error, _req, res, _next) => {
  if (error instanceof ZodError) {
    return responder(res, 400, 'VALIDATION_ERROR', 'Dados inválidos.', error.flatten());
  }
  if (error instanceof ApiError) {
    return responder(res, error.status, error.code, error.message);
  }
  if (error?.type === 'entity.too.large') {
    return responder(res, 413, 'PAYLOAD_TOO_LARGE', 'O envio passa do tamanho máximo permitido.');
  }
  // Corpo JSON malformado (express.json).
  if (error?.type === 'entity.parse.failed') {
    return responder(res, 400, 'VALIDATION_ERROR', 'Corpo da requisição inválido.');
  }

  switch (error?.code) {
    case 'ER_SIGNAL_EXCEPTION': // regras de negócio dos gatilhos e procedimentos
      return responder(res, 409, 'BUSINESS_RULE', error.sqlMessage ?? 'Regra de negócio não permitiu a operação.');
    case 'ER_DUP_ENTRY': {
      const chave = Object.keys(MENSAGENS_UNICIDADE).find((nome) => error.sqlMessage?.includes(nome));
      return responder(res, 409, 'CONFLICT', chave ? MENSAGENS_UNICIDADE[chave] : 'Registro duplicado.');
    }
    case 'ER_CHECK_CONSTRAINT_VIOLATED':
      return responder(res, 400, 'VALIDATION_ERROR', 'Os dados informados não atendem às regras do cadastro.');
    case 'ER_NO_REFERENCED_ROW_2':
      return responder(res, 400, 'VALIDATION_ERROR', 'Um dos itens informados não existe.');
    case 'ER_ROW_IS_REFERENCED_2':
      return responder(res, 409, 'RELATIONSHIP_CONFLICT', 'O registro está em uso e não pode ser removido.');
    case 'ER_LOCK_DEADLOCK':
    case 'ER_LOCK_WAIT_TIMEOUT':
      return responder(res, 409, 'CONFLICT', 'Outra operação estava em andamento. Tente novamente.');
    case 'ECONNREFUSED':
    case 'PROTOCOL_CONNECTION_LOST':
    case 'ER_ACCESS_DENIED_ERROR':
    case 'ER_BAD_DB_ERROR':
      console.error('Banco indisponível:', error.code);
      return responder(res, 503, 'DATABASE_UNAVAILABLE', 'Serviço temporariamente indisponível.');
  }

  console.error('Erro não tratado:', error instanceof Error ? error.message : error);
  return responder(res, 500, 'INTERNAL_ERROR', 'Erro interno do servidor.');
};
