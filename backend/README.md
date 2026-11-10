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

O `.env` é ignorado pelo Git. Variáveis: `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `JWT_SECRET`, `JWT_EXPIRES_IN`, `PORT`, `HOST`, `CORS_ORIGIN`, `HORAS_PARTIDA_REALIZADA`, `ROTINAS_PRESERVAR_ATE`, `ARQUIVOS_DIR` (pasta das imagens enviadas; padrão `arquivos`, fora do Git). As imagens ficam no disco do servidor por trás da interface `Armazenamento` (`services/armazenamento.ts`); na AWS, troque pela implementação com S3 sem mudar as rotas. O banco guarda só o endereço. Em produção use o usuário de privilégio mínimo da seção 10 de `database_v2/README.md`, não `root`.

## Convenções

- Sucesso: `{ "data": ..., "meta": { "pagina", "limite" } }`. Erro: `{ "error": { "code", "message" } }`.
- JSON em camelCase português (`idAnuncio`, `dataHoraInicio`). Datas em ISO 8601 UTC.
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
| POST `/auth/recuperar-senha`, `/auth/redefinir-senha` | público | Código de uso único. **Envio de e-mail não configurado** |
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
| GET `/solicitacoes/minhas`, `/solicitacoes/:id` | participante | |
| PATCH `/solicitacoes/:id/confirmar` | anunciante | **Aceite do desafio.** O pedido já é a concordância do desafiante; o aceite confirma a partida, encerra o anúncio e as demais solicitações, notifica e libera o chat. O desafiante recebe 403 |
| PATCH `/solicitacoes/:id/recusar` | anunciante | |
| PATCH `/solicitacoes/:id/cancelar` | solicitante | |
| GET, POST `/solicitacoes/:id/mensagens` | participante, após o aceite | Chat entre os capitães. Antes do aceite: 403 `CHAT_BLOQUEADO` (o gatilho do banco também recusa). Quem não participa: 404. GET marca como lidas |
| GET `/partidas/minhas`, `/partidas/proxima`, `/partidas/:id` | participante | |
| PATCH `/partidas/:id/cancelar` | participante | |
| POST `/partidas/:id/avaliacoes` | participante | Só em partida realizada; todos os critérios ativos |
| GET `/notificacoes`, PATCH `/notificacoes/:id/lida` | destinatário | |

Confirmar, recusar, cancelar e excluir chamam os procedimentos `proc_*` do banco, que têm transação própria e bloqueiam o anúncio. Não os chame dentro de `emTransacao`.

O servidor executa `proc_expirar_anuncios` e `proc_marcar_partidas_realizadas` ao iniciar e a cada hora (`services/rotinas.ts`). Com `ROTINAS_PRESERVAR_ATE` definida, a rotina que tocaria um registro criado até essa data não é executada e o log registra um aviso; como os procedimentos são globais, ela fica suspensa também para os registros novos.

## Testes

- `npm test`: unitários, sem banco.
- `npm run test:integracao` com `TESTE_INTEGRACAO=1`: fluxo completo com MySQL real. **Grava dados fictícios (`teste.homologacao.*@example.com`) que permanecem no banco.** Na porta 3306 exige também `TESTE_BANCO_REAL_AUTORIZADO=1`. Rode com `HORAS_PARTIDA_REALIZADA=0`. No banco real, exige `ROTINAS_PRESERVAR_ATE`: se algum registro preservado seria afetado, o cenário de rotinas é ignorado.
