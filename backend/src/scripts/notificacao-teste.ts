import { pool } from '../config/db.js';
import { consultar } from '../services/helpers.js';
import { criarNotificacao } from '../services/notificacoes.js';

/**
 * Cria uma notificação de teste (tipo `aviso`) para uma conta de teste.
 * Uso: npm run notificacao:teste -- teste.homologacao.xxx@example.com [chave]
 * Com a mesma chave, rodar de novo não cria outra (idempotência).
 * Só aceita contas teste.homologacao.*@example.com: nunca toca contas reais.
 */
async function principal() {
  const [email, chave] = process.argv.slice(2);
  if (!email || !/^teste\.homologacao\.[^@\s]+@example\.com$/.test(email)) {
    console.error('Informe o e-mail de uma conta de teste (teste.homologacao.*@example.com).');
    process.exitCode = 1;
    return;
  }
  const [usuario] = await consultar(pool, 'SELECT id_usuario FROM usuarios WHERE email = ?', [email]);
  if (!usuario) {
    console.error('Conta de teste não encontrada.');
    process.exitCode = 1;
    return;
  }
  const agora = new Date();
  const resultado = await criarNotificacao(pool, {
    idDestinatario: usuario.id_usuario,
    tipo: 'aviso',
    titulo: 'Notificação de teste',
    mensagem: `Criada em ${agora.toLocaleString('pt-BR', { timeZone: 'America/Sao_Paulo' })}. Se você está vendo isto, a central de notificações funciona.`,
    chaveEvento: chave ?? `teste:${agora.getTime()}`,
  });
  console.log(
    resultado.criada
      ? `Notificação criada: ${resultado.idNotificacao}`
      : `Já existia uma notificação com essa chave: ${resultado.idNotificacao} (nada foi criado).`,
  );
}

principal().finally(() => pool.end());
