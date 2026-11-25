import { createApp } from './app.js';
import { checkDatabase, pool } from './config/db.js';
import { motivoEmailIndisponivel } from './config/email.js';
import { env } from './config/env.js';
import { agendarLembretes } from './services/lembretes.js';
import { agendarFilaPush, enviadorPush } from './services/push.js';
import { agendarRotinas } from './services/rotinas.js';

const app = createApp();

const server = app.listen(env.PORT, env.HOST, async () => {
  console.log(`API ouvindo em http://${env.HOST}:${env.PORT}`);
  try {
    console.log(`MySQL conectado ao banco ${await checkDatabase()}.`);
  } catch {
    console.error('MySQL indisponível; /api/health/db indicará o problema.');
  }
  const semEmail = motivoEmailIndisponivel();
  console.log(
    semEmail
      ? `E-mail de recuperação de senha desligado (${semEmail}).`
      : `E-mail de recuperação de senha: ${env.EMAIL_PROVEDOR}.`,
  );
  console.log(
    enviadorPush()
      ? 'Push (Firebase Cloud Messaging): ligado.'
      : 'Push desligado (FIREBASE_CREDENCIAIS não configurada); as notificações internas continuam.',
  );
});

const rotinas = agendarRotinas();
const filaPush = agendarFilaPush();
const lembretes = agendarLembretes();

for (const sinal of ['SIGINT', 'SIGTERM']) {
  process.on(sinal, () => {
    clearInterval(rotinas);
    clearInterval(filaPush);
    clearInterval(lembretes);
    server.close(() => pool.end().finally(() => process.exit(0)));
  });
}
