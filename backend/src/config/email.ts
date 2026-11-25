import type SMTPTransport from 'nodemailer/lib/smtp-transport/index.js';
import { env } from './env.js';

/**
 * Configuração central do envio de e-mails. Para trocar de provedor basta
 * mudar as variáveis de ambiente (EMAIL_PROVEDOR=smtp + EMAIL_SMTP_*) ou criar
 * outro `ProvedorEmail` em services/email.ts; o fluxo de recuperação de senha
 * não depende do provedor.
 *
 * Credenciais só vêm do ambiente (.env, fora do Git) e nunca vão para o log.
 */
export type ConfiguracaoEmail = {
  provedor: 'gmail' | 'smtp';
  remetente: string;
  smtp: SMTPTransport.Options;
};

/** Servidor do Gmail: TLS direto na 465, autenticação com senha de app. */
const GMAIL = { host: 'smtp.gmail.com', port: 465, secure: true };

/** Sem resposta do provedor nesse tempo, o envio falha (e é registrado). */
const TEMPOS = { connectionTimeout: 10_000, greetingTimeout: 10_000, socketTimeout: 20_000 };

/** Null quando o e-mail não está configurado (o motivo vai para `motivoEmailIndisponivel`). */
export function lerConfiguracaoEmail(): ConfiguracaoEmail | null {
  if (motivoEmailIndisponivel()) return null;
  const usuario = env.EMAIL_USER!;
  // A senha de app do Google é exibida em 4 grupos ("abcd efgh ijkl mnop").
  const senha = env.EMAIL_PROVEDOR === 'gmail' ? env.EMAIL_PASS!.replace(/\s+/g, '') : env.EMAIL_PASS!;
  const servidor =
    env.EMAIL_PROVEDOR === 'gmail'
      ? GMAIL
      : {
          host: env.EMAIL_SMTP_HOST!,
          port: env.EMAIL_SMTP_PORT ?? 587,
          secure: (env.EMAIL_SMTP_SEGURO ?? (env.EMAIL_SMTP_PORT === 465 ? 'true' : 'false')) === 'true',
          requireTLS: true,
        };
  return {
    provedor: env.EMAIL_PROVEDOR,
    remetente: env.EMAIL_FROM ?? `Joga Contra <${usuario}>`,
    smtp: { ...servidor, ...TEMPOS, auth: { user: usuario, pass: senha } },
  };
}

/** Por que o envio está desligado (null = configurado). Nunca inclui valores. */
export function motivoEmailIndisponivel(): string | null {
  const faltando = ['EMAIL_USER', 'EMAIL_PASS'].filter((nome) => !env[nome as 'EMAIL_USER']);
  if (env.EMAIL_PROVEDOR === 'smtp' && !env.EMAIL_SMTP_HOST) faltando.push('EMAIL_SMTP_HOST');
  if (!env.URL_PUBLICA) faltando.push('URL_PUBLICA');
  return faltando.length ? `variáveis não configuradas: ${faltando.join(', ')}` : null;
}
