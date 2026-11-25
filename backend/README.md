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
| GET `/notificacoes?pagina=&limite=` | destinatário | Central: mais recentes primeiro (limite 1–100, padrão 50). `meta`: `pagina`, `limite`, `temMais`, `total`, `naoLidas`. Sempre do capitão do token |
| GET `/notificacoes/nao-lidas` | destinatário | `{ naoLidas, total }` (contador do sino; `total` só cresce com notificação nova) |
| PATCH `/notificacoes/:id/lida` | destinatário | 204; repetir não é erro. De outra conta ou inexistente: 404 |
| PATCH `/notificacoes/lidas` | destinatário | Marca todas: `{ marcadas, naoLidas: 0 }`. Não há exclusão: o histórico é preservado |

Confirmar, recusar, cancelar e excluir chamam os procedimentos `proc_*` do banco, que têm transação própria e bloqueiam o anúncio. Não os chame dentro de `emTransacao`.

O servidor executa `proc_expirar_anuncios` e `proc_marcar_partidas_realizadas` ao iniciar e a cada hora (`services/rotinas.ts`). Com `ROTINAS_PRESERVAR_ATE` definida, a rotina que tocaria um registro criado até essa data não é executada e o log registra um aviso; como os procedimentos são globais, ela fica suspensa também para os registros novos.

## Notificações dos eventos

Toda notificação é criada pelo backend, na mesma transação do evento (rota da API ou procedimento do banco): se o evento for desfeito, a notificação também é. Cada uma tem `chave_evento` (no máximo uma por evento e destinatário). Datas e horas no horário local do jogo (`fn_quando_texto` / `textoQuando`).

| Evento | Quem recebe | Título | Ao tocar |
|---|---|---|---|
| Desafio enviado (`POST /solicitacoes`) | Dono do anúncio | Novo desafio recebido | Solicitação (aceitar/recusar) |
| | Quem enviou (já lida) | Desafio enviado | Solicitação |
| Aceite (`proc_confirmar_solicitacao`) | Desafiante | Desafio aceito! (adversário, data, hora, local, chat liberado) | Jogo |
| | Dono que aceitou (já lida) | Partida confirmada | Jogo |
| | Outros desafiantes do anúncio | Solicitação encerrada | Meus Desafios |
| | Desafiante, por solicitação no mesmo horário encerrada | Solicitação encerrada por conflito de horário | Meus Desafios |
| Recusa | Desafiante | Solicitação encerrada | Meus Desafios |
| Anúncio removido ou expirado | Desafiantes pendentes | Solicitação encerrada | Meus Desafios |
| Jogo cancelado (`proc_cancelar_partida`) | Outro capitão | Jogo cancelado (data, hora, motivo) | Jogo |
| | Quem cancelou (já lida) | Jogo cancelado | Jogo |
| Mensagem no chat | Outro capitão | Nova mensagem ("Você recebeu uma nova mensagem do time X.", sem o texto) | Conversa |

"Já lida": registro no histórico de uma ação da própria pessoa, sem número no sino. Não há aviso à parte de "chat liberado": o "Desafio aceito!" já informa. Desistência (o desafiante cancela) e pausa de anúncio não geram aviso: a pausa é reversível e as solicitações continuam pendentes.

## Lembretes de jogo e preferências

**Lembretes** (`services/lembretes.ts`): 24 h, 2 h e 30 min antes, aos dois capitães, só de partidas `confirmada`, com adversário, hora local (UF do jogo) e local ("acontece amanhã às 21h, em Arena Biase"; "em", não "na", porque os nomes de local têm gênero variado). A API verifica a cada minuto as partidas confirmadas das próximas 24 h (índice `ind_partidas_rotina_status`) e grava em `lembretes_partidas` (chave: partida + tipo + horário de início) o que tratou: reiniciar a API não perde nem repete, vários servidores podem rodar juntos, cancelada não recebe. Janela perdida (jogo confirmado depois dela, ou API fora do ar) não é enviada atrasada: vale só o lembrete mais próximo do jogo e os anteriores ficam `pulado`. Nada é enviado depois do início. O horário de uma partida confirmada não muda hoje (o banco bloqueia); se um dia mudar, a chave inclui o horário e os lembretes seguem o novo. Respeita `ROTINAS_PRESERVAR_ATE`. Testes usam relógio injetado (`processarLembretes({ agora, apenasPartidas })`).

**Preferências** (`GET`/`PUT /notificacoes/preferencias`, parcial: `{ desafios, jogos, chat, lembretes }`, padrão tudo ativo). Política: categoria desativada continua registrando no histórico, mas a notificação chega **já lida** (não conta no sino e não vira push). Aplicada pelo gatilho `gat_notificacoes_antes_inserir` (vale para a API e para os procedimentos). Avisos gerais (`aviso`) e os e-mails de segurança da conta (recuperação de senha) não dependem dessas opções. Não há preferência separada só de push: a permissão de notificações do Android já cumpre esse papel.

| Categoria | Tipos |
|---|---|
| desafios | `solicitacao_recebida`, `solicitacao_enviada`, `solicitacao_recusada`, `solicitacao_encerrada` |
| jogos | `partida_confirmada`, `partida_cancelada`, `avaliacao_pendente`, `anuncio_expirando` |
| chat | `mensagem_recebida` |
| lembretes | `lembrete_partida` |

**Fila de push**: envios pendentes há mais de 24 h expiram (`ignorado`, sem apagar) a cada 10 min, mesmo com o push desligado, para a fila não crescer sem limite.

## Notificações do chat

- **Uma por mensagem e destinatário**, nunca ao remetente (`chave_evento = mensagem_recebida:<idMensagem>`). O texto da mensagem não vai na notificação nem no push.
- **Envio repetível**: o app manda `idMensagem` (UUID gerado no aparelho) em `POST /solicitacoes/:id/mensagens`. Repetir a requisição (falha de conexão) devolve a mensagem já gravada (200), sem mensagem nem notificação duplicadas; o mesmo id em outra conversa ou de outro time: 409.
- **Conversa aberta (presença)**: `GET /solicitacoes/:id/mensagens` (o app consulta a cada 4 s com a conversa na tela) grava em `conversas_abertas`; `PATCH /solicitacoes/:id/presenca { aberta }` avisa a saída (outra tela ou app em segundo plano). Se o destinatário está com a conversa aberta (último acesso < 12 s), a notificação é criada **já lida** (histórico, sem push); fora dela, não lida e com push. Limitação: se o app for encerrado à força com a conversa aberta, por até 12 s as mensagens novas dela não geram push (continuam como não lidas na lista de conversas).
- **Leitura**: abrir a conversa marca as mensagens recebidas como visualizadas (regra existente) e os avisos de mensagem dessa conversa como lidos. Ler a notificação **não** marca a mensagem; nada é apagado.
- **Em segundo plano** o app para de consultar a conversa: mensagens não são mais marcadas como visualizadas sem ninguém olhando.
- **Push no aparelho**: mensagens da mesma conversa se substituem (etiqueta `chat-<idSolicitacao>`); com a conversa aberta no app, o aviso na tela é suprimido.
- **Liberação**: "Desafio aceito!" já informa que o chat está liberado (sem aviso separado). Antes do aceite: 403; quem não participa: 404 (inclusive a presença).

## Notificações push (Firebase Cloud Messaging)

**Fluxo.** Toda notificação nova e **não lida** entra na fila `envios_push` pelo gatilho `gat_notificacoes_depois_inserir`, na mesma transação do evento (padrão outbox): evento desfeito, envio desfeito. A API processa a fila a cada `PUSH_INTERVALO_MS` (`services/push.ts`), fora da transação: uma falha do Firebase nunca desfaz o evento nem a notificação interna. Cada envio é reservado com `FOR UPDATE SKIP LOCKED` (vários servidores sem envio duplicado) e há uma linha por notificação (UNIQUE).

**Regras de envio.** Só para aparelhos ativos e com permissão do destinatário; notificação já lida ou com mais de 24 h não vira push. Falha geral (rede, credencial, Firebase fora): nova tentativa em 10 s, 30 s, 2 min, 10 min e 30 min; depois `falhou`. Token inválido (`installation-id-not-registered` e afins): o aparelho é desativado. Usuário com mais de 500 aparelhos ativos: envio em lotes de 500 (limite do `sendEachForMulticast`). Com o push desligado (sem `FIREBASE_CREDENCIAIS`) a fila não é processada.

**Conteúdo.** Título, texto e só identificadores em `data`: `idNotificacao`, `tipo`, `referenciaTipo` (`solicitacao`, `partida`, `anuncio`) e `referenciaId`. O app abre a tela, que busca os detalhes na API com a sessão (e a API confere a participação). Android: canal `joga_contra_avisos`, prioridade alta, `tag` = id da notificação (reenvio substitui, não duplica).

| Rota | Uso |
|---|---|
| PUT `/dispositivos` | `{ token, plataforma, permitido, tokenAnterior? }`. Registra ou renova (idempotente). Token de outra conta passa para a conta logada; `tokenAnterior` é substituído. O token nunca volta nas respostas |
| GET `/dispositivos` | Aparelhos da conta (sem token) |
| PATCH `/dispositivos/desativar` | `{ token }`: sair da conta neste aparelho. 204 sempre (não revela de quem é o token) |
| DELETE `/dispositivos/:id` | Remove o aparelho da conta: apaga o token, mantém o registro |

Redefinir a senha desativa todos os aparelhos da conta (as sessões caem; o app registra de novo no próximo login).

**Configuração (manual, uma vez).**
1. Firebase Console > criar projeto > adicionar app **Android** com o pacote `com.jogacontra.joga_contra`.
2. Baixar o `google-services.json` para `android/app/` e rodar `dart run tool/firebase_config.dart` (gera `android/app/src/main/res/values/firebase.xml`; os dois ficam fora do Git). Gerar o APK de novo.
3. Configurações do projeto > Contas de serviço > Gerar nova chave privada. Salvar em `backend/credenciais/` (fora do Git) e apontar `FIREBASE_CREDENCIAIS` no `.env`. Reiniciar a API: o log mostra "Push (Firebase Cloud Messaging): ligado.".
4. iOS (o projeto ainda não tem a pasta `ios`): criar o app iOS, chave APNs (.p8) no Firebase (Cloud Messaging > Configuração do app Apple), capacidades Push Notifications e Background Modes > Remote notifications no Xcode, e `GoogleService-Info.plist` em `ios/Runner/`.

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
- `npm run notificacao:teste -- teste.homologacao.xxx@example.com [chave]`: cria uma notificação de teste (tipo `aviso`) para uma **conta de teste** (recusa outras). Com a mesma chave, não cria de novo.
- `tests/lembretes-preferencias.integracao.test.ts`: lembretes com relógio injetado (janelas, repetição, cancelada, fuso, servidor fora do ar, falha no push) e preferências.
- `tests/chat-notificacoes.integracao.test.ts`: avisos de mensagem, envio repetido, presença na conversa, leitura e acesso.
- `tests/push.integracao.test.ts`: dispositivos, fila de envio, falhas e tokens inválidos com um provedor de teste no lugar do Firebase (nada sai da máquina).
- `npm run verify:email`: confere o login no Gmail (ou outro SMTP) com as variáveis do `.env`, sem enviar nada.
