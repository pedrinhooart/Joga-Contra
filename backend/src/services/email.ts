import nodemailer from 'nodemailer';
import { lerConfiguracaoEmail, motivoEmailIndisponivel } from '../config/email.js';

export type AnexoEmbutido = { nomeArquivo: string; caminho: string; cid: string };

export type MensagemEmail = {
  para: string;
  assunto: string;
  html: string;
  /** Versão em texto puro (leitores sem HTML e filtros de spam). */
  texto: string;
  /** Imagens referenciadas no HTML como `cid:...` (ex.: o logo). */
  imagens?: AnexoEmbutido[];
};

/**
 * Contrato de qualquer provedor (Gmail, SMTP genérico, e no futuro uma API como
 * Amazon SES ou Resend). Quem envia e-mails só conhece esta interface.
 */
export interface ProvedorEmail {
  readonly nome: string;
  enviar(mensagem: MensagemEmail): Promise<void>;
}

/** Gmail e qualquer servidor SMTP, via Nodemailer. */
export class ProvedorSmtp implements ProvedorEmail {
  private readonly transporte;

  constructor(
    readonly nome: string,
    opcoes: Parameters<typeof nodemailer.createTransport>[0],
    private readonly remetente: string,
  ) {
    this.transporte = nodemailer.createTransport(opcoes);
  }

  async enviar(m: MensagemEmail) {
    await this.transporte.sendMail({
      from: this.remetente,
      to: m.para,
      subject: m.assunto,
      html: m.html,
      text: m.texto,
      attachments: m.imagens?.map((i) => ({ filename: i.nomeArquivo, path: i.caminho, cid: i.cid })),
    });
  }
}

/** Sem configuração: o pedido segue normalmente, mas nada é enviado (e o log avisa). */
class ProvedorIndisponivel implements ProvedorEmail {
  readonly nome = 'indisponível';
  constructor(private readonly motivo: string) {}
  async enviar(): Promise<void> {
    throw Object.assign(new Error(`E-mail não configurado (${this.motivo}).`), { code: 'EMAIL_NAO_CONFIGURADO' });
  }
}

let provedorAtual: ProvedorEmail | null = null;

export function provedorEmail(): ProvedorEmail {
  if (!provedorAtual) {
    const config = lerConfiguracaoEmail();
    provedorAtual = config
      ? new ProvedorSmtp(config.provedor, config.smtp, config.remetente)
      : new ProvedorIndisponivel(motivoEmailIndisponivel()!);
  }
  return provedorAtual;
}

/** Troca o provedor (testes, ou um provedor por API no futuro). Null volta ao do ambiente. */
export function definirProvedorEmail(provedor: ProvedorEmail | null) {
  provedorAtual = provedor;
}

/**
 * Descrição segura de uma falha de envio para o log: código e resposta do
 * servidor, sem destinatário, conteúdo do e-mail ou credenciais.
 */
export function descreverFalhaEmail(erro: any): string {
  const partes = [erro?.code, erro?.responseCode, erro?.command].filter(Boolean);
  return partes.length ? partes.join(' ') : 'erro desconhecido';
}
