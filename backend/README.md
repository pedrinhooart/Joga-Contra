# API Joga Contra

API REST (Node.js, TypeScript, Express 5) do aplicativo Flutter. Usa exclusivamente o banco MySQL 8.4 `joga_contra_v2` (estrutura em [../database_v2](../database_v2/README.md)). O app nunca acessa o MySQL diretamente.

## Executar

```powershell
cd backend
npm install
Copy-Item .env.example .env   # preencha credenciais e um JWT_SECRET com 32+ caracteres
npm run verify:db             # só leitura: confere estrutura e referências
npm run dev
```

Produção: `npm run build` e `npm start`. No emulador Android use `http://10.0.2.2:3000/api`; em aparelho físico, o IP da máquina em `API_BASE_URL`.

O `.env` é ignorado pelo Git. Variáveis: `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `JWT_SECRET`, `JWT_EXPIRES_IN`, `PORT`, `HOST`, `CORS_ORIGIN`, `HORAS_PARTIDA_REALIZADA`, `ROTINAS_PRESERVAR_ATE`, `ARQUIVOS_DIR` (pasta das imagens enviadas; padrão `arquivos`, fora do Git), `TRUST_PROXY` e as de e-mail da seção "Recuperação de senha". As imagens ficam no disco do servidor por trás da interface `Armazenamento` (`services/armazenamento.ts`); na AWS, troque pela implementação com S3 sem mudar as rotas. O banco guarda só o endereço. Em produção use o usuário de privilégio mínimo da seção 10 de `database_v2/README.md`, não `root`.

## Convenções

- Sucesso: `{ "data": ..., "meta": { "pagina", "limite" } }`. Erro: `{ "error": { "code", "message" } }`.
- JSON em camelCase português (`idAnuncio`, `dataHoraInicio`). Datas em ISO 8601 UTC.
- **Horário das partidas:** é o horário local de onde a partida acontece (fuso da UF do anúncio, `services/fuso.ts`), nunca o do aparelho. O app envia `dataHoraLocal` (`2026-11-26T21:00`) e a API grava o instante UTC; as respostas de anúncio e partida trazem `dataHoraInicio` (UTC), `dataHoraLocal` (para exibir) e `fusoHorario`. Os filtros `data` e `horario` da busca usam o horário local de cada anúncio.
- Textos recebidos são normalizados para NFC (acentos compostos).
- Rotas protegidas: `Authorization: Bearer <token>`. O time usado é sempre o do capitão logado, nunca um valor enviado pelo cliente.
- Regras do banco (gatilhos e procedimentos) voltam como HTTP 409 com a mensagem em português.
- Quem não participa de uma solicitação ou partida recebe 404.

## Endpoints (base `/api`)

| Método e caminho | Acesso | Uso |
|---|---|---|
| GET `/health`, `/health/db` | público | Saúde; `/db` confirma a conexão e se o banco é `joga_contra_v2` (503 se não for) |
| GET `/referencias` | público | Modalidades, categorias etárias, níveis, mandos, critérios, estados |
| POST `/auth/cadastro` | público | Capitão + time em uma transação. Obrigatórios: nome, e-mail, senha, nome do time, cidade e UF. Telefone, modalidades, categoria, nível e quantidade são opcionais: o anúncio informa os de cada jogo |
| POST `/auth/login` | público | Devolve `{ token, usuario, time }` |
| GET `/auth/eu` | JWT | Sessão atual |
| POST `/auth/forgot-password` (alias `/auth/recuperar-senha`) | público | `{ email }`. Sempre 202 com a mesma mensagem; o e-mail sai depois da resposta. Ver "Recuperação de senha" |
| POST `/auth/reset-password` (alias `/auth/redefinir-senha`) | público | `{ token, novaSenha, confirmacaoSenha }`. 200 troca a senha e derruba as sessões abertas; 400 `TOKEN_INVALIDO`/`VALIDATION_ERROR`; 410 `TOKEN_EXPIRADO`, `TOKEN_UTILIZADO` ou `TOKEN_SUBSTITUIDO` |
| GET `/redefinir-senha` (fora de `/api`) | público | Página aberta pelo link do e-mail: abre o app com o token |
| GET `/.well-known/assetlinks.json` (fora de `/api`) | público | Android App Links, só com `ANDROID_CERT_SHA256` configurada |
| GET `/times/:id`, `/times/:id/avaliacoes` | JWT | Perfil público e avaliações. Contato só para o próprio capitão |
| PATCH `/times/:id` | capitão | Edita o time (nome, descrição etc.). Descrição em branco remove a descrição |
| PUT `/times/:id/escudo` | capitão | Foto do time: corpo binário `image/jpeg`, `image/png` ou `image/webp`, até 2 MB (formato conferido pelos bytes). Devolve o time com `urlEscudo` |
| GET `/arquivos/...` | público | Imagens enviadas (endereço vem em `urlEscudo`) |
| GET `/anuncios` | JWT | Busca: `texto`, `cidade`, `siglaEstado`, `idModalidade`, `idNivelTecnico`, `data`, `horario`, `fusoMinutos`, `pagina`, `limite` (`idCategoriaEtaria` só encontra anúncios antigos, que têm categoria) |
| GET `/anuncios/meus`, `/anuncios/:id` | JWT | |
| POST `/anuncios` | capitão | Publica pelo próprio time. Obrigatórios: modalidade, nível, data e hora, `duracaoMinutos` (15 a 600), cidade, UF e local. Opcionais: `endereco`, `latitude`/`longitude` (juntas), taxa, descrição; categoria, quantidade, mando e bairro só por compatibilidade |
| GET `/locais?uf=&cidade=` | JWT | Locais esportivos reais da cidade (OpenStreetMap, com cache de 7 dias em memória e disco). Devolve `{ fonte, atribuicao, locais }`; o app filtra localmente |
| PUT `/anuncios/:id`, PATCH `/anuncios/:id/status`, DELETE `/anuncios/:id` | capitão dono | Editar, pausar/reativar, excluir (lógica) |
| GET `/anuncios/:id/solicitacoes` | capitão dono | Analisa quem solicitou |
| POST `/solicitacoes` | capitão | "Tenho interesse"; repetir devolve a pendente existente |
| GET `/solicitacoes/minhas?papel=` | participante | Conversas do meu time. `papel=solicitante`: só os desafios que o meu time enviou (Meus Desafios); `papel=anunciante`: só os recebidos. Marca como entregues as mensagens recebidas |
| GET `/solicitacoes/sincronizar` | JWT | Chamado pelo app a cada 30 s e ao voltar ao app: marca como entregues as mensagens recebidas nas conversas liberadas e devolve `{ mensagensNaoLidas, versao }`. `versao` muda quando uma solicitação ou partida do time muda; o app então recarrega Meus Jogos e Conversas |
| GET `/solicitacoes/:id` | participante | |
| PATCH `/solicitacoes/:id/confirmar` | anunciante | **Aceite do desafio.** O pedido já é a concordância do desafiante; o aceite confirma a partida, encerra o anúncio e as demais solicitações, notifica e libera o chat. Na mesma transação, encerra as outras solicitações **pendentes** do time desafiante para jogos na mesma data e hora local (`motivoEncerramento` explica; nada é apagado). Aceitar uma solicitação já encerrada: 409 `BUSINESS_RULE`. Impasse entre aceites simultâneos: a API repete a transação. O desafiante recebe 403 |
| PATCH `/solicitacoes/:id/recusar` | anunciante | |
| PATCH `/solicitacoes/:id/cancelar` | solicitante | |
| GET, POST `/solicitacoes/:id/mensagens` | participante, após o aceite | Chat entre os capitães. Antes do aceite: 403 `CHAT_BLOQUEADO` (o gatilho do banco também recusa). Quem não participa: 404. GET marca as recebidas como visualizadas. Cada mensagem traz `status` (`enviada`, `entregue`, `visualizada`), `dataEntrega` e `dataLeitura`; o remetente nunca marca as próprias |
| GET `/partidas/minhas`, `/partidas/proxima`, `/partidas/:id` | participante | |
| PATCH `/partidas/:id/cancelar` | participante | |
| POST `/partidas/:id/avaliacoes` | participante | Só em partida realizada; todos os critérios ativos |
| GET `/notificacoes`, PATCH `/notificacoes/:id/lida` | destinatário | |

Confirmar, recusar, cancelar e excluir chamam os procedimentos `proc_*` do banco, que têm transação própria e bloqueiam o anúncio. Não os chame dentro de `emTransacao`.

O servidor executa `proc_expirar_anuncios` e `proc_marcar_partidas_realizadas` ao iniciar e a cada hora (`services/rotinas.ts`). Com `ROTINAS_PRESERVAR_ATE` definida, a rotina que tocaria um registro criado até essa data não é executada e o log registra um aviso; como os procedimentos são globais, ela fica suspensa também para os registros novos.

## Recuperação de senha

**Fluxo.** O app chama `forgot-password`. A API responde 202 na hora e, depois, procura a conta ativa, gera um token de 32 bytes (`crypto.randomBytes`), grava só o SHA-256 dele em `codigos_recuperacao_senha` (validade de 30 minutos) e envia o e-mail. O link é `URL_PUBLICA/redefinir-senha#token=...`: o token fica no fragmento, que o navegador não envia ao servidor (não aparece em logs da API nem de proxies). A página lê o fragmento e o botão "Abrir no aplicativo" abre `jogacontra://redefinir-senha?token=...` (no Android, por um link `intent:` com o pacote do app). O app mostra a tela de nova senha e chama `reset-password`.

**Regras.**
- Resposta e tempo iguais para e-mail cadastrado ou não; falha do provedor de e-mail também não muda a resposta (vai para o log, sem destinatário, token ou senha).
- Só o pedido mais recente da conta vale; os anteriores ficam no histórico com `TOKEN_SUBSTITUIDO`.
- Uso único: a troca roda numa transação com `SELECT ... FOR UPDATE` no pedido e na conta; dois envios simultâneos do mesmo link trocam a senha uma vez só.
- Limites: 5 pedidos e 10 redefinições por IP a cada 15 minutos (`express-rate-limit`), e 3 pedidos por conta por hora (contados no banco, com a conta travada).
- Nova senha: mínimo de 8 caracteres, máximo de 72 bytes (bcrypt, custo 12), confirmação igual.
- Sessões: o JWT leva a claim `sv`, um HMAC do hash da senha. Ao trocar a senha, todas as sessões abertas caem. Tokens emitidos antes desta regra (sem `sv`) valem até expirar, salvo se a senha foi redefinida depois de emitidos.
- Produção (`NODE_ENV=production`): `URL_PUBLICA` precisa ser `https://` (a API não sobe sem isso) e requisições sem HTTPS recebem 403 (exceto `/api/health`). Atrás de proxy, defina `TRUST_PROXY`.

**Variáveis.** `EMAIL_PROVEDOR` (`gmail` padrão, ou `smtp`), `EMAIL_USER`, `EMAIL_PASS`, `EMAIL_FROM`, `URL_PUBLICA` e, para `smtp`, `EMAIL_SMTP_HOST`, `EMAIL_SMTP_PORT`, `EMAIL_SMTP_SEGURO`. Sem elas o envio fica desligado e o log da inicialização diz quais faltam (só os nomes). Trocar de provedor: Amazon SES, Resend e outros oferecem SMTP (`EMAIL_PROVEDOR=smtp`); um provedor por API é uma nova classe `ProvedorEmail` em `services/email.ts`, sem mexer nas rotas.

**Senha de app do Gmail.**
1. Na conta Google que vai enviar, ative a verificação em duas etapas (Conta Google > Segurança).
2. Acesse https://myaccount.google.com/apppasswords, crie uma senha com o nome "Joga Contra API" e copie as 16 letras.
3. No `.env`: `EMAIL_USER=conta@gmail.com`, `EMAIL_PASS=<16 letras>` (com ou sem espaços), `EMAIL_FROM=Joga Contra <conta@gmail.com>`.
4. Nunca use a senha normal da conta. Para revogar, apague a senha de app na mesma página.
5. Limite do Gmail: cerca de 500 destinatários por dia em contas comuns; para produção prefira SES ou Resend com domínio próprio (SPF/DKIM).

**`URL_PUBLICA`.** Endereço desta API visto pelo celular, sem `/api`. Homologação: o IP da máquina na rede Wi-Fi (`http://192.168.x.x:3000`; o celular precisa estar na mesma rede). Emulador: `http://10.0.2.2:3000`. Produção: o domínio com HTTPS.

**Android App Links (produção, com domínio).** Com eles, o link do e-mail abre o app direto, sem a página intermediária:
1. `ANDROID_CERT_SHA256` = SHA-256 do certificado de assinatura do app (Play Console > Integridade do app, ou `keytool -list -v -keystore <arquivo>`). Confira em `https://<domínio>/.well-known/assetlinks.json`.
2. No `android/app/src/main/AndroidManifest.xml`, descomente o `intent-filter` com `android:autoVerify="true"` e troque `DOMINIO_DA_API` pelo host da `URL_PUBLICA`.
3. O app já aceita os dois formatos de link (`lib/services/links_recebidos.dart`).

## Testes

- `npm test`: unitários, sem banco.
- `npm run test:integracao` com `TESTE_INTEGRACAO=1`: fluxo completo com MySQL real. **Grava dados fictícios (`teste.homologacao.*@example.com`) que permanecem no banco.** Na porta 3306 exige também `TESTE_BANCO_REAL_AUTORIZADO=1`. Rode com `HORAS_PARTIDA_REALIZADA=0`. No banco real, exige `ROTINAS_PRESERVAR_ATE`: se algum registro preservado seria afetado, o cenário de rotinas é ignorado. Inclui `tests/recuperacao-senha.integracao.test.ts`, que envia os e-mails de verdade pelo Nodemailer para um servidor SMTP local (`tests/smtp-local.ts`); nenhum e-mail sai da máquina.
- `npm run verify:email`: confere o login no Gmail (ou outro SMTP) com as variáveis do `.env`, sem enviar nada.
