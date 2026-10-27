# API Joga Contra

API REST em Node.js/TypeScript para o aplicativo Flutter. Ela utiliza exatamente as tabelas do diretório `../database`: `users`, `teams`, `team_members`, `sports`, `game_listings` e `game_interests`.

## Pré-requisitos e banco

Instale Node.js 20+ e MySQL 8.4. No MySQL Workbench, abra e execute primeiro `database/schema.sql` em uma instância vazia. Depois execute `database/seeds.sql` uma única vez para cadastrar os catálogos (esportes, estados e status). Os scripts não são executados pela API e não devem ser usados contra uma base com dados sem revisão prévia.

Copie `.env.example` para `.env`, preencha credenciais válidas e gere um `JWT_SECRET` longo (mínimo 32 caracteres). O `.env` é ignorado pelo Git. Valide o banco com `npm run verify:db`. Se os catálogos estiverem vazios, execute `npm run seed:reference`; ele usa os valores reais de `database/seeds.sql` com `INSERT IGNORE`, sem atualizar ou duplicar registros existentes.

## Executar

```powershell
cd backend
npm install
Copy-Item .env.example .env
# edite .env
npm run dev
```

Para produção: `npm run build` e `npm start`. O servidor escuta em `0.0.0.0`; use `http://localhost:3000` no computador e `http://10.0.2.2:3000` no emulador Android. Em aparelho físico, configure `API_BASE_URL` com o IP LAN do computador e libere a porta 3000 no firewall.

## Endpoints

| Método | Caminho | Autenticação |
|---|---|---|
| GET | `/api/health`, `/api/health/db` | não |
| POST | `/api/auth/register`, `/api/auth/login` | não |
| GET/PATCH | `/api/auth/me` | Bearer JWT |
| GET | `/api/sports` | não |
| GET | `/api/catalogs` | não |
| POST/GET | `/api/teams` | POST: JWT |
| GET | `/api/teams/mine`, `/api/teams/:teamId`, `/api/teams/:teamId/members` | `mine`: JWT |
| PATCH/DELETE | `/api/teams/:teamId` | JWT/admin do time |
| POST/DELETE | `/api/teams/:teamId/members` | JWT/admin do time |
| POST/GET | `/api/listings` | POST: JWT |
| GET | `/api/listings/mine`, `/api/listings/:listingId` | `mine`: JWT |
| PATCH | `/api/listings/:listingId`, `/api/listings/:listingId/status` | JWT/admin do time |
| POST | `/api/interests/listings/:listingId` | JWT/membro do time interessado |
| GET | `/api/interests/listings/:listingId`, `/api/interests/mine/sent`, `/api/interests/mine/received` | JWT |
| PATCH | `/api/interests/:interestId/status` | JWT |

Listas de anúncios aceitam `page`, `limit` (máximo 100), `sportId`, `city`, `stateCode`, `date` (`YYYY-MM-DD`) e `status`. Para rotas protegidas envie `Authorization: Bearer <token>`.

Exemplo de cadastro:

```json
POST /api/auth/register
{"email":"ana@example.com","displayName":"Ana","password":"senha-segura-123","phoneE164":"+5511999999999"}
```

A resposta contém `{ "data": { "user": { ... }, "token": "..." } }`. Erros sempre usam `{ "error": { "code": "...", "message": "..." } }`.

## Testes

`npm test` executa verificações isoladas de saúde e proteção de rota sem tocar no MySQL. Para validar uma instalação real, execute `npm run verify:db`, depois `GET /api/health/db`. Os fluxos de cadastro, times, anúncios e interesses requerem uma base MySQL de teste quando automatizados; não são executados automaticamente para evitar qualquer risco a dados locais. Teste-os pelo Postman/Insomnia usando a coleção de endpoints acima.

Erros comuns: porta 3306 ocupada ou credenciais inválidas aparecem em `/api/health/db`; CORS é controlado por `CORS_ORIGIN` (use uma lista separada por vírgulas em produção); no Android, `localhost` aponta para o aparelho, então use `10.0.2.2` no emulador.
