import { createApp } from './app.js';
import { checkDatabase, pool } from './config/db.js';
import { env } from './config/env.js';
import { agendarRotinas } from './services/rotinas.js';

const app = createApp();

const server = app.listen(env.PORT, env.HOST, async () => {
  console.log(`API ouvindo em http://${env.HOST}:${env.PORT}`);
  try {
    console.log(`MySQL conectado ao banco ${await checkDatabase()}.`);
  } catch {
    console.error('MySQL indisponível; /api/health/db indicará o problema.');
  }
});

const rotinas = agendarRotinas();

for (const sinal of ['SIGINT', 'SIGTERM']) {
  process.on(sinal, () => {
    clearInterval(rotinas);
    server.close(() => pool.end().finally(() => process.exit(0)));
  });
}
