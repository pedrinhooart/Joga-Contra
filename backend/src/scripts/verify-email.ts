import nodemailer from 'nodemailer';
import { lerConfiguracaoEmail, motivoEmailIndisponivel } from '../config/email.js';
import { descreverFalhaEmail } from '../services/email.js';

/**
 * Confere a configuração de e-mail do .env: conecta ao servidor e faz o login,
 * sem enviar nada. Uso: npm run verify:email
 */
async function verificar() {
  const config = lerConfiguracaoEmail();
  if (!config) {
    console.error(`E-mail não configurado (${motivoEmailIndisponivel()}).`);
    process.exit(1);
  }
  try {
    await nodemailer.createTransport(config.smtp).verify();
    console.log(`E-mail OK: login aceito por ${config.provedor} (${config.smtp.host}). Remetente: ${config.remetente}.`);
  } catch (erro) {
    const motivo = descreverFalhaEmail(erro);
    console.error(`Falha no e-mail (${motivo}).`);
    if (motivo.includes('EAUTH')) {
      console.error('Login recusado: confira EMAIL_USER e use uma senha de app do Google, não a senha da conta.');
    }
    process.exit(1);
  }
}

void verificar();
