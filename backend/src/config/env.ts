import 'dotenv/config';
import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.string().default('development'),
  DB_HOST: z.string().default('127.0.0.1'),
  DB_PORT: z.coerce.number().int().positive().default(3306),
  DB_USER: z.string().min(1),
  DB_PASSWORD: z.string(),
  DB_NAME: z.string().min(1).default('joga_contra_v2'),
  JWT_SECRET: z.string().min(32),
  JWT_EXPIRES_IN: z.string().default('1d'),
  PORT: z.coerce.number().int().positive().default(3000),
  HOST: z.string().default('0.0.0.0'),
  CORS_ORIGIN: z.string().default('*'),
  /** Horas após o início para a partida ser marcada como realizada. */
  HORAS_PARTIDA_REALIZADA: z.coerce.number().int().min(0).default(3),
  /** Registros criados até esta data nunca são alterados pelas rotinas. Vazio: sem proteção. */
  ROTINAS_PRESERVAR_ATE: z.coerce.date().optional(),
  /** Pasta das imagens enviadas (escudos). Relativa à pasta da API. */
  ARQUIVOS_DIR: z.string().min(1).default('arquivos'),
  /** Servidor Overpass (OpenStreetMap) para a busca de locais esportivos. */
  OVERPASS_URL: z.string().url().optional(),
  /** Proxies confiáveis à frente da API (ex.: 1 atrás de um nginx). Define o IP real para os limites. */
  TRUST_PROXY: z.coerce.number().int().min(0).default(0),

  // --- E-mail (recuperação de senha). Ver config/email.ts. ---
  /** gmail (padrão) ou smtp (qualquer servidor SMTP: Amazon SES SMTP, Resend SMTP etc.). */
  EMAIL_PROVEDOR: z.enum(['gmail', 'smtp']).default('gmail'),
  EMAIL_USER: vazioComoAusente(z.string().min(1).optional()),
  /** No Gmail: senha de app de 16 letras (nunca a senha normal da conta). */
  EMAIL_PASS: vazioComoAusente(z.string().min(1).optional()),
  /** Remetente exibido. Ex.: "Joga Contra <seu.email@gmail.com>". Padrão: EMAIL_USER. */
  EMAIL_FROM: vazioComoAusente(z.string().min(3).optional()),
  EMAIL_SMTP_HOST: vazioComoAusente(z.string().min(1).optional()),
  EMAIL_SMTP_PORT: vazioComoAusente(z.coerce.number().int().positive().optional()),
  /** true = TLS direto (porta 465); false = STARTTLS (porta 587). */
  EMAIL_SMTP_SEGURO: vazioComoAusente(z.enum(['true', 'false']).optional()),
  /**
   * Endereço público desta API, sem /api (ex.: https://api.seudominio.com.br).
   * Usado no link do e-mail de recuperação. Em homologação, o IP da máquina na
   * rede local (ex.: http://192.168.0.10:3000).
   */
  URL_PUBLICA: vazioComoAusente(z.string().url().optional()),
  /** Pacote Android do app (abre o app a partir do link). */
  ANDROID_PACOTE: z.string().regex(/^[a-zA-Z][\w]*(\.[a-zA-Z][\w]*)+$/).default('com.jogacontra.joga_contra'),
  // --- Push (Firebase Cloud Messaging). Ver services/push.ts. ---
  /**
   * Caminho do JSON da conta de serviço do Firebase (Firebase Console >
   * Configurações do projeto > Contas de serviço). Fica só no servidor, fora do
   * Git. Vazio: push desligado (as notificações internas continuam).
   */
  FIREBASE_CREDENCIAIS: vazioComoAusente(z.string().min(1).optional()),
  /** Intervalo da fila de envio de push, em milissegundos. */
  PUSH_INTERVALO_MS: z.coerce.number().int().min(500).default(3000),
  /** SHA-256 do certificado de assinatura do app, para os Android App Links (assetlinks.json). */
  ANDROID_CERT_SHA256: vazioComoAusente(z.string().regex(/^([0-9A-F]{2}:){31}[0-9A-F]{2}(,([0-9A-F]{2}:){31}[0-9A-F]{2})*$/i).optional()),
});

/** Variável declarada mas vazia (`EMAIL_USER=`) vale como não configurada. */
function vazioComoAusente<T extends z.ZodTypeAny>(tipo: T) {
  return z.preprocess((v) => (typeof v === 'string' && v.trim() === '' ? undefined : v), tipo);
}

/** Em produção, links e API só por HTTPS. */
const schemaComRegras = schema.superRefine((v, ctx) => {
  if (v.NODE_ENV === 'production' && v.URL_PUBLICA && !v.URL_PUBLICA.startsWith('https://')) {
    ctx.addIssue({ code: 'custom', path: ['URL_PUBLICA'], message: 'Em produção a URL_PUBLICA precisa usar https://.' });
  }
});

export const env = schemaComRegras.parse(process.env);
