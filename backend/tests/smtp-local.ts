import { simpleParser, type ParsedMail } from 'mailparser';
import type { AddressInfo } from 'node:net';
import { SMTPServer } from 'smtp-server';

/**
 * Servidor SMTP local para os testes: recebe as mensagens que o Nodemailer
 * envia de verdade (mesmo caminho do Gmail, sem sair da máquina).
 */
export async function iniciarSmtpLocal(opcoes: { recusarLogin?: boolean } = {}) {
  const recebidos: ParsedMail[] = [];
  const logins: { usuario: string; senha: string }[] = [];
  const servidor = new SMTPServer({
    secure: false,
    disabledCommands: ['STARTTLS'],
    authOptional: true,
    allowInsecureAuth: true, // só na máquina local; o Gmail exige TLS

    logger: false,
    onAuth(auth, _sessao, responder) {
      logins.push({ usuario: auth.username ?? '', senha: auth.password ?? '' });
      if (opcoes.recusarLogin) {
        const erro = Object.assign(new Error('Username and Password not accepted'), { responseCode: 535 });
        return responder(erro);
      }
      responder(null, { user: auth.username });
    },
    onData(fluxo, _sessao, responder) {
      simpleParser(fluxo)
        .then((mensagem) => {
          recebidos.push(mensagem);
          responder();
        })
        .catch(responder);
    },
  });
  await new Promise<void>((ok) => servidor.listen(0, '127.0.0.1', ok));
  const porta = (servidor.server.address() as AddressInfo).port;
  return {
    porta,
    recebidos,
    logins,
    /** Mensagens enviadas para `email`. */
    para: (email: string) => recebidos.filter((m) => [m.to].flat().some((d) => d?.text.includes(email))),
    fechar: () => new Promise<void>((ok) => servidor.close(() => ok())),
  };
}

/** Token do link recebido (fica no fragmento `#token=`). */
export function tokenDoEmail(mensagem: ParsedMail): string {
  const html = typeof mensagem.html === 'string' ? mensagem.html : '';
  const achado = /redefinir-senha#token=([A-Za-z0-9_-]{43})"/.exec(html);
  if (!achado) throw new Error('E-mail sem link de redefinição.');
  return achado[1];
}
