import { createHash, randomBytes } from 'node:crypto';
import path from 'node:path';
import { env } from '../config/env.js';
import type { MensagemEmail } from './email.js';

/**
 * Recuperação de senha: token, link e conteúdo do e-mail.
 *
 * O token (32 bytes aleatórios do gerador criptográfico do sistema, em base64url)
 * só existe no e-mail. O banco guarda o SHA-256 dele, que basta para
 * localizar o pedido e não permite reconstruir o link.
 */
export const VALIDADE_TOKEN_MINUTOS = 30;
/** Pedidos por conta dentro da janela; além disso a resposta é a mesma, mas nada é enviado. */
export const LIMITE_PEDIDOS_POR_CONTA = 3;
export const JANELA_LIMITE_MINUTOS = 60;

export const gerarTokenRecuperacao = () => randomBytes(32).toString('base64url');
export const hashTokenRecuperacao = (token: string) => createHash('sha256').update(token, 'utf8').digest();
/** Formato de um token gerado por `gerarTokenRecuperacao` (43 caracteres base64url). */
export const FORMATO_TOKEN = /^[A-Za-z0-9_-]{43}$/;

export const CAMINHO_PAGINA = '/redefinir-senha';
/** Arquivos públicos (logo), dentro da pasta da API. Vale para src/ e dist/. */
export const PASTA_PUBLICA = path.resolve(__dirname, '../../publico');
const CAMINHO_LOGO = path.join(PASTA_PUBLICA, 'logo.png');

/**
 * Link do e-mail. O token vai no fragmento (#): navegadores não o enviam ao
 * servidor, então ele não aparece em logs da API nem de proxies. A página lê o
 * fragmento e abre o app (ou, com App Links configurados, o Android abre o app direto).
 */
export function urlRedefinicao(token: string): string {
  const base = env.URL_PUBLICA!.replace(/\/+$/, '');
  return `${base}${CAMINHO_PAGINA}#token=${token}`;
}

const escapar = (texto: string) =>
  texto.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

const CORES = { floresta: '#123D2B', limao: '#C3F35A', tinta: '#222B26', apagado: '#5F6861', borda: '#E8ECE8', fundo: '#F6F8F6' };

export function emailRecuperacao(para: string, nome: string, token: string): MensagemEmail {
  const link = urlRedefinicao(token);
  const primeiroNome = nome.trim().split(/\s+/)[0] || 'capitão';
  const c = CORES;
  const html = `<!DOCTYPE html>
<html lang="pt-BR">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Recuperação de senha — Joga Contra</title></head>
<body style="margin:0;padding:0;background:${c.fundo};font-family:Arial,Helvetica,sans-serif;color:${c.tinta};">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${c.fundo};padding:24px 12px;">
<tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;background:#ffffff;border:1px solid ${c.borda};border-radius:14px;overflow:hidden;">
  <tr><td style="background:${c.floresta};padding:22px 24px;">
    <table role="presentation" cellpadding="0" cellspacing="0"><tr>
      <td style="padding-right:12px;"><img src="cid:logo-joga-contra" width="44" height="43" alt="" style="display:block;border:0;border-radius:10px;"></td>
      <td style="color:#ffffff;font-size:20px;font-weight:800;letter-spacing:0.3px;">Joga Contra</td>
    </tr></table>
  </td></tr>
  <tr><td style="padding:28px 24px 8px;">
    <h1 style="margin:0 0 14px;font-size:22px;line-height:1.3;color:${c.tinta};">Recuperação de senha</h1>
    <p style="margin:0 0 12px;font-size:16px;line-height:1.5;">Olá, ${escapar(primeiroNome)}!</p>
    <p style="margin:0 0 22px;font-size:16px;line-height:1.5;">Recebemos um pedido para redefinir a senha da sua conta no Joga Contra. Toque no botão abaixo, no celular em que o aplicativo está instalado, para cadastrar uma nova senha.</p>
    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 0 22px;"><tr>
      <td style="background:${c.limao};border-radius:10px;">
        <a href="${escapar(link)}" style="display:inline-block;padding:14px 26px;font-size:16px;font-weight:700;color:${c.floresta};text-decoration:none;">Redefinir minha senha</a>
      </td>
    </tr></table>
    <p style="margin:0 0 12px;font-size:15px;line-height:1.5;"><strong>Este link vale por ${VALIDADE_TOKEN_MINUTOS} minutos</strong> e só pode ser usado uma vez.</p>
    <p style="margin:0 0 22px;font-size:15px;line-height:1.5;">Se você não pediu a recuperação, ignore este e-mail: sua senha continua a mesma.</p>
    <p style="margin:0 0 6px;font-size:13px;line-height:1.5;color:${c.apagado};">Se o botão não funcionar, copie este endereço e abra no navegador do celular:</p>
    <p style="margin:0 0 24px;font-size:13px;line-height:1.5;word-break:break-all;"><a href="${escapar(link)}" style="color:${c.floresta};">${escapar(link)}</a></p>
  </td></tr>
  <tr><td style="padding:16px 24px;border-top:1px solid ${c.borda};font-size:12px;line-height:1.5;color:${c.apagado};">
    Joga Contra — O próximo rival. A próxima história.<br>Nunca pedimos sua senha por e-mail.
  </td></tr>
</table>
</td></tr>
</table>
</body>
</html>`;
  const texto = [
    'Joga Contra — Recuperação de senha',
    '',
    `Olá, ${primeiroNome}!`,
    '',
    'Recebemos um pedido para redefinir a senha da sua conta no Joga Contra.',
    'Abra o link abaixo no celular em que o aplicativo está instalado para cadastrar uma nova senha:',
    '',
    link,
    '',
    `O link vale por ${VALIDADE_TOKEN_MINUTOS} minutos e só pode ser usado uma vez.`,
    'Se você não pediu a recuperação, ignore este e-mail: sua senha continua a mesma.',
    '',
    'Nunca pedimos sua senha por e-mail.',
  ].join('\n');
  return {
    para,
    assunto: 'Recuperação de senha — Joga Contra',
    html,
    texto,
    imagens: [{ nomeArquivo: 'joga-contra.png', caminho: CAMINHO_LOGO, cid: 'logo-joga-contra' }],
  };
}

/** Página aberta pelo link do e-mail: entrega o token ao app. */
export function paginaRedefinicao(): string {
  const c = CORES;
  return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>Redefinir senha — Joga Contra</title>
<style>
  body { margin: 0; background: ${c.fundo}; color: ${c.tinta}; font-family: Roboto, Arial, Helvetica, sans-serif; }
  main { max-width: 440px; margin: 0 auto; padding: 32px 20px; }
  .marca { display: flex; align-items: center; gap: 12px; background: ${c.floresta}; color: #fff; padding: 18px 20px; border-radius: 14px; font-size: 21px; font-weight: 800; }
  .marca img { width: 44px; height: 43px; border-radius: 10px; }
  h1 { font-size: 24px; margin: 28px 0 10px; }
  p { font-size: 17px; line-height: 1.5; margin: 0 0 14px; }
  .nota { font-size: 15px; color: ${c.apagado}; }
  .botao { display: block; text-align: center; background: ${c.limao}; color: ${c.floresta}; font-size: 18px; font-weight: 700; text-decoration: none; padding: 16px; border-radius: 12px; margin: 22px 0; }
  [hidden] { display: none !important; }
</style>
</head>
<body>
<main>
  <div class="marca"><img src="${CAMINHO_PAGINA}/logo.png" alt="">Joga Contra</div>
  <h1>Redefinir sua senha</h1>
  <div id="com-token">
    <p>Toque no botão para abrir o aplicativo Joga Contra e cadastrar a nova senha.</p>
    <a id="abrir" class="botao" href="#">Abrir no aplicativo</a>
    <p class="nota">Abra este link no celular Android em que o Joga Contra está instalado. Ele vale por ${VALIDADE_TOKEN_MINUTOS} minutos e só pode ser usado uma vez.</p>
  </div>
  <div id="sem-app" hidden>
    <p>Não encontramos o aplicativo Joga Contra neste aparelho.</p>
    <p class="nota">Abra o e-mail no celular em que o aplicativo está instalado e toque de novo em “Redefinir minha senha”.</p>
  </div>
  <div id="sem-token" hidden>
    <p>Este link está incompleto.</p>
    <p class="nota">Copie o endereço inteiro do e-mail ou peça um novo link no aplicativo, em “Esqueci minha senha”.</p>
  </div>
</main>
<script src="${CAMINHO_PAGINA}/abrir.js"></script>
</body>
</html>`;
}

/**
 * Script da página (arquivo à parte: a política de segurança não permite
 * scripts embutidos). No Android usa um link `intent:`, que abre o app pelo
 * pacote e volta para a página se ele não estiver instalado.
 */
export function scriptPaginaRedefinicao(): string {
  return `(function () {
  var pacote = ${JSON.stringify(env.ANDROID_PACOTE)};
  var mostrar = function (id) {
    ['com-token', 'sem-app', 'sem-token'].forEach(function (i) {
      document.getElementById(i).hidden = i !== id;
    });
  };
  if (location.hash === '#sem-app') return mostrar('sem-app');
  var achado = /(?:^#|&)token=([A-Za-z0-9_-]{43})(?:&|$)/.exec(location.hash);
  if (!achado) return mostrar('sem-token');
  var token = achado[1];
  var botao = document.getElementById('abrir');
  if (/Android/i.test(navigator.userAgent)) {
    var volta = location.origin + location.pathname + '#sem-app';
    botao.href = 'intent://redefinir-senha?token=' + token +
      '#Intent;scheme=jogacontra;package=' + pacote +
      ';S.browser_fallback_url=' + encodeURIComponent(volta) + ';end';
  } else {
    botao.href = 'jogacontra://redefinir-senha?token=' + token;
  }
  mostrar('com-token');
})();
`;
}

/** Associação do domínio com o app (Android App Links). Null se não configurada. */
export function assetLinks() {
  if (!env.ANDROID_CERT_SHA256) return null;
  return [
    {
      relation: ['delegate_permission/common.handle_all_urls'],
      target: {
        namespace: 'android_app',
        package_name: env.ANDROID_PACOTE,
        sha256_cert_fingerprints: env.ANDROID_CERT_SHA256.split(',').map((v) => v.toUpperCase()),
      },
    },
  ];
}
