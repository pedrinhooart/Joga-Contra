# Joga Contra — Relatório da integração com `joga_contra_v2`

Data: 05/11/2026 · Branch `refactor/dados-dinamicos` · Ponto de restauração: commit `81faa40`. As alterações deste relatório ainda não têm commit.

**Situação:** app Flutter, API e banco estão integrados e testados em conjunto, exceto a execução em aparelho ou emulador (seção 9). A estrutura do banco não foi alterada.

## 1. Arquivos analisados

- **Banco:** estrutura real lida do servidor local em sessão `READ ONLY` (17 tabelas, 4 visões, 15 gatilhos, 7 procedimentos, 35 FKs, 65 CHECKs), igual a `database_v2/`.
- **Backend:** todo `backend/src`, `tests`, `.env` (segredos não exibidos), `.env.example`, `.gitignore`, `package.json`, `README.md`.
- **Flutter:** todo `lib/`, `test/`, `pubspec.yaml`, manifestos Android.

## 2. Problemas encontrados

| Área | Arquivo | Problema |
|---|---|---|
| Conexão | `backend/.env`, `.env.example` | `DB_NAME=joga_contra` (banco antigo) |
| Conexão | `config/db.ts` | `time_zone` UTC só era aplicado em uma verificação, não em cada conexão: `data_criacao` seria gravada no fuso do servidor |
| SQL | `routes/auth, teams, listings, interests, catalogs, sports`, `services/helpers`, `scripts/*` | 100% das consultas usavam tabelas antigas em inglês |
| SQL | `routes/listings, teams, interests` | `LIMIT ?` em prepared statement falha no MySQL 8 |
| Regras | `routes/interests.ts` | Aceitar não exigia as duas equipes, não criava partida, não encerrava as demais nem notificava |
| Regras | `routes/teams.ts`, `helpers.ts` | Membros e papéis (`owner/manager/member`) contradizem "um capitão" |
| Regras | `routes/auth.ts` | Cadastro criava só o usuário, sem o time |
| Regras | `routes/listings.ts` | Busca listava qualquer status, o próprio time e anúncios passados |
| Rotas | — | Não existiam partidas, mensagens, notificações, avaliações, `/referencias`, recuperação de senha |
| Erros | `error-handler.ts` | CHECK, deadlock e banco fora do ar viravam HTTP 500 |
| Flutter | `config/api_config.dart` | Dados fictícios ligados por padrão em debug |
| Flutter | `api_repositories.dart` | Token só em memória: login a cada abertura |
| Flutter | `discover_screen.dart`, `carregador.dart` | **`setState` devolvendo `Future`: exceção em debug ao filtrar, buscar ou recarregar.** Só apareceu com a API real |
| Flutter | `discover_screen.dart` | Sem filtros de cidade e horário |
| Flutter | `activity_screens.dart`, `account_screens.dart` | Validação de jogadores diferente do banco (2–30, 1–60) |
| Flutter | `anuncio_partida.dart` | Nível técnico opcional no envio; o banco exige |
| API | `app.ts` | Resposta 429 fora do envelope JSON (achado nos testes) |

## 3. Arquivos modificados

**Backend, removidos:** `routes/listings.ts`, `interests.ts`, `sports.ts`, `catalogs.ts`, `teams.ts`.
**Backend, criados:** `routes/referencias.ts`, `times.ts`, `anuncios.ts`, `solicitacoes.ts`, `partidas.ts`, `notificacoes.ts`, `services/consultas.ts`, `mapeadores.ts`, `rotinas.ts`, `email.ts`, `tests/integracao.test.ts`.
**Backend, reescritos:** `app.ts`, `server.ts`, `config/env.ts`, `config/db.ts`, `middlewares/auth.ts`, `error-handler.ts`, `routes/auth.ts`, `health.ts`, `schemas/*`, `services/helpers.ts`, `scripts/*`, `types/express.d.ts`, `tests/health.test.ts`, `README.md`, `package.json`, `.env.example`, `.env` (somente `DB_NAME`).
**Flutter, criados:** `lib/services/armazenamento_sessao.dart`, `test/integracao_api_test.dart`, `test/integracao_telas_test.dart`.
**Flutter, alterados:** `config/api_config.dart`, `models/anuncio_partida.dart`, `repositories/api/api_repositories.dart`, `repositories/demo/demo_repositories.dart`, `state/app_state.dart`, `screens/discover_screen.dart`, `activity_screens.dart`, `account_screens.dart`, `home_screen.dart`, `widgets/carregador.dart`, `pubspec.yaml`, `pubspec.lock`, `README.md`.

## 4. Correções realizadas

- API usa só `joga_contra_v2`, com pool, `time_zone` UTC em toda conexão e consultas parametrizadas. `LIMIT` e fuso são inteiros validados; colunas dinâmicas vêm de lista fixa.
- JWT com algoritmo fixo (HS256); a conta é conferida a cada requisição, então suspensão vale na hora.
- Autorização sempre pelo time do capitão logado. Contato do time visível só ao próprio capitão.
- Confirmação, recusa, desistência, cancelamento e exclusão pelos procedimentos do banco.
- Rotinas horárias de expiração de anúncios e de partidas realizadas.
- Flutter: API como padrão, sessão persistente com `flutter_secure_storage`, filtros de cidade e horário, validações iguais às do banco, estatísticas atualizadas ao abrir o Início.

**Mudanças visuais, todas com os componentes existentes:** dois campos a mais na folha de filtros ("Horário a partir de" e "Cidade", pedidos na seção 5) e duas etiquetas de filtro ativo.

## 5. Endpoints

Tabela completa em [backend/README.md](../backend/README.md). Removidos: `/listings`, `/interests`, `/teams`, `/sports`, `/catalogs`, `/auth/register`, `/auth/me`. Todas as rotas atuais foram criadas ou reescritas.

## 6. Consultas SQL

Todas reescritas. Usam `usuarios`, `codigos_recuperacao_senha`, `times`, `times_modalidades`, `anuncios_partidas`, `solicitacoes_confronto`, `mensagens`, `partidas`, `avaliacoes`, `notas_avaliacao`, `notificacoes`, as tabelas de referência, as visões `vis_perfis_times`, `vis_anuncios_disponiveis`, `vis_resumo_solicitacoes` e cinco procedimentos pela API, mais dois pelas rotinas. Busca em `backend/src` e `tests` não encontrou nenhum nome de tabela antiga.

## 7. Relacionamentos corrigidos

- Capitão: `times.id_capitao` no lugar de `team_members`.
- Time ↔ modalidades: N:N por `times_modalidades`.
- Anúncio → time do capitão logado; o cliente não escolhe o time.
- Solicitação → anúncio e os dois times, com `id_time_anunciante` vindo do gatilho.
- Partida → solicitação e anúncio, com os dados copiados pelo procedimento.
- Faixa etária e nível técnico: colunas, tabelas e filtros separados.

## 8. Testes executados

**Backend, integração no `joga_contra_v2` real (14/14).** Rodou antes do último ajuste em `app.ts` (formato do 429), que fica desligado nesse modo de teste.

| # | Cenário | Resultado |
|---|---|---|
| 1 | Conexão com `joga_contra_v2` e sessão em UTC | Passou |
| 2 | Cadastro e autenticação (hash bcrypt, e-mail duplicado, senha errada) | Passou |
| 3 | Cadastro, consulta e edição de equipe | Passou |
| 4 | Publicação de anúncio (e rejeição sem nível, data passada, poucos jogadores) | Passou |
| 5 | Listagem (sem o próprio time; pausado some) | Passou |
| 6 | Filtros: cidade, data, horário, modalidade, faixa etária, nível; SQL injection | Passou |
| 7 | Solicitação de confronto, várias por anúncio | Passou |
| 8 | Consulta de solicitações pelo capitão dono e pelo solicitante | Passou |
| 9 | Aceitação de um lado só (não cria partida) | Passou |
| 10 | Confirmação pelos dois lados cria a partida | Passou |
| 11 | Encerramento automático das demais | Passou |
| 12 | Notificação aos capitães não selecionados | Passou |
| 13 | Bloqueio de solicitação em anúncio encerrado | Passou |
| 14 | Confirmações duplicadas e simultâneas (10 rodadas paralelas: sempre 200 + 409, uma partida) | Passou |
| 15 | Permissões entre equipes (editar, excluir, ler, confirmar, notificação alheia) | Passou |
| — | Recusa, desistência, exclusão, rotinas, avaliação, cancelamento, transação do cadastro | Passou |

**Outros:**

| Suíte | Resultado |
|---|---|
| Backend unitários (JWT, rotas protegidas, rotas antigas 404, validação) | 21/21 |
| Flutter repositórios reais contra a API real (sessão salva e restaurada, fluxo até a partida) | 6/6 |
| Flutter telas reais contra a API real (login, senha errada, Início, Busca, Detalhes, interesse, chat, confirmação dos dois capitães, notificações, Perfil, sair) | 1/1 |
| Flutter padrão (demonstração, regras, HTTP simulado, formatação) | 12/12 |
| `flutter analyze`, `tsc --noEmit`, `npm run verify:db` | Sem problemas |
| Limite de tentativas: 6ª chamada devolve 429 em JSON | Verificado manualmente |
| `flutter build apk --debug` | Compilou com o código final |

**Falhas durante o trabalho, todas resolvidas:** teste antigo de `/api/auth/me`; os dois defeitos de `setState`; o 429 sem JSON; ajustes de roteiro do teste de telas por causa de snackbars.

## 9. Ainda não testado

- **App em aparelho ou emulador.** Os testes de tela rodam no ambiente de testes do Flutter. O armazenamento seguro real do Android não foi exercido (os testes usam a versão em memória). A aparência não foi conferida visualmente.
- Formulários **Criar conta** e **Anunciar jogo** preenchidos pela tela: os dados que eles geram foram testados pelos repositórios, mas não o preenchimento em si.
- `redefinir-senha` com código válido: só o caso inválido foi testado, porque o código não é exposto sem e-mail.
- Usuário de privilégio mínimo com a API completa (a API rodou como `root`).

## 10. Dependem de alteração no banco

**Nenhum.** A API e o app funcionaram com a estrutura atual.

## 11. Pendências

**Precisam da sua decisão**
1. **Dados de teste no banco real:** ficaram 71 usuários, 71 times, 31 anúncios, 36 solicitações, 17 partidas, 7 mensagens, 1 avaliação, 99 notificações e 1 código de recuperação. Todos os usuários são `@example.com`. Remover exige `DELETE`, que depende da sua autorização.
2. **Usuário MySQL:** a API usa `root`. Recomendo o usuário de privilégio mínimo da seção 10 de `database_v2/README.md`.
3. **Recusar solicitação:** existe na API, mas não há botão no app, para não alterar o protótipo.

**Não implementado**
4. **Envio de e-mail** da recuperação de senha: falta um provedor (`services/email.ts`).
5. **Distância:** o filtro "raio" aparece na tela, mas a API o ignora, porque não há geolocalização. Mapa continua ilustrativo.
6. **Edição do perfil no app:** só o nome. A API aceita descrição, quantidade de jogadores e demais campos, mas falta o formulário.
7. **Placar:** colunas existem, mas não há rota nem tela; o histórico mostra `– × –`.
8. **Notificação `anuncio_expirando`:** tipo existe, nada a gera.
9. **Upload de escudo e foto, login com Google, abrir localização, push e chat em tempo real** (a conversa atualiza ao reabrir).

**Para produção**
10. HTTPS: o Android bloqueia HTTP fora do modo debug. Definir `API_BASE_URL` com HTTPS.
11. Restringir `CORS_ORIGIN`, hoje `*`.
12. Expiração do JWT é de 1 dia, sem renovação: o capitão precisa entrar de novo depois disso.
13. `database_v2/README.md` (seção 9.2) ainda descreve como pendentes itens já feitos aqui.
