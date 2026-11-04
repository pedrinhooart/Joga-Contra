# Joga Contra — Auditoria de dados variáveis e preparação para dados dinâmicos

Data: 04/11/2026 · Branch: `refactor/dados-dinamicos` (ponto de restauração: commit `a8b6d97` em `main`).

Escopo examinado: `lib/` (Flutter), `test/`, `backend/` (Express/TypeScript), `database/` (schema, seeds e exemplos atuais), `prototype-source/` (export do Figma Make, apenas referência), `pubspec.yaml`, `.env.example`, `README.md`, `PROTOTYPE_ANALYSIS.md`. Não há arquivos JSON de dados nem assets de imagem com dados no projeto Flutter.

Nada foi executado contra MySQL. O banco atual (`database/schema.sql`) não foi alterado.

---

## 1. Resumo executivo

| Item | Situação encontrada | Situação após esta etapa |
|---|---|---|
| Dados das telas | 100% fixos: `MockRepository` (4 jogos, 4 notificações), anúncios como `String` `'texto\|Ativo'`, nomes, estatísticas, histórico, avaliações, mensagens, endereço e contato escritos direto nos widgets. | Todas as telas leem de repositórios (`lib/repositories/contratos.dart`). Dados fictícios só existem no repositório de demonstração, desligado por padrão em release. |
| Classificações | Listas duplicadas em 3 telas e **divergentes das regras**: `Futebol/Futsal`, `Sub-20`, `Veterano`, `Recreativo`. | Vêm de `GET /referencias`. A demonstração usa as classificações oficiais (Sub-15, Sub-17, Sub-19, Livre · Iniciante, Intermediário, Avançado · Futebol society/sintético, Futebol de quadra). |
| Formulários | Cadastro, login, anúncio, avaliação: valores digitados eram descartados. | Ligados a controllers, validados e enviados como objetos tipados (`CadastroCapitao`, `RascunhoAnuncio`, `NovaAvaliacao`). |
| Cliente HTTP | `lib/services/api_client.dart` **não compilava** (`StreamedResponse.body`). Não era usado. | Corrigido, centralizado, com timeout, token, query, PUT/DELETE, envelope `{data}`/`{error}` e callback de sessão expirada. Coberto por testes. |
| API Express | Funcional para usuários, times, anúncios e interesses no schema antigo (inglês). Modelo de membros/permissões contradiz as regras. Não tem partidas, mensagens, notificações nem avaliações. | **Não alterada** (depende do novo banco). Avaliação e plano na seção 9. |
| Testes | 2 testes de widget. | 12 testes: 3 de widget (fluxo completo interesse → confirmação, logout) + 9 de dados (regras, ApiClient, parse JSON, formatação). |

---

## 2. Inventário de dados variáveis encontrados (com caminhos)

Linhas referem-se ao código **antes** da refatoração (commit `a8b6d97`).

### 2.1 Usuário e perfil

| Dado | Onde estava fixo | Classificação |
|---|---|---|
| Nome do usuário "João" na saudação `BOM TE VER, JOÃO` | `lib/screens/home_screen.dart:24` | Banco (`usuarios.nome`) |
| Inicial "J" no avatar da AppBar | `lib/app.dart:98` | Derivado de `usuarios.nome` |
| Responsável "João Silva" e contato "(11) 99999-1234" | `lib/screens/account_screens.dart:214` | Banco (`times.id_capitao` → `usuarios.nome`; `times.telefone_contato`) |
| Campos de cadastro (nome, telefone, e-mail, senha) descartados | `lib/screens/account_screens.dart:862-901` | Banco (`usuarios`); senha só como hash |
| Login/recuperação simulados ("protótipo demonstrativo") | `lib/app.dart:255-266` | API (`/auth/*`) |
| Dica "Pelo menos 6 caracteres" (backend exige 8) | `lib/screens/account_screens.dart:899` | Regra de validação — corrigida para 8 |
| Foto de perfil, cidade/estado do usuário, preferências | **Não existem** no app | — (cidade/UF do usuário previstas no modelo, opcionais) |

### 2.2 Time

| Dado | Onde estava fixo | Classificação |
|---|---|---|
| Nome "União FC" (estado local `teamName`) | `lib/app.dart:19`, `home_screen.dart:43` | Banco (`times.nome`) |
| Sigla do escudo "UFC" (padrão do widget) e ano "2015" | `lib/widgets/common.dart:108-140` | Banco (`times.sigla`, `times.ano_fundacao`); sigla derivável do nome |
| Ícone especial quando sigla == 'RA' | `lib/widgets/common.dart:133` | Visual acoplado a dado fictício — removido |
| "São Paulo, SP · Desde 2015" | `account_screens.dart:171` | Banco (`times.cidade`, `sigla_estado`, `ano_fundacao`) |
| Tags "Futebol / Livre / Intermediário" do perfil | `account_screens.dart:190-197` | Banco (`times_modalidades`, `id_categoria_etaria`, `id_nivel_tecnico`) |
| Título "Mais que um time, uma família." + texto de apresentação | `account_screens.dart:199-211` | Banco (`times.descricao`). O título passou a ser o rótulo fixo "Sobre o time" |
| Estatísticas "18 jogos realizados", "4,9 avaliação" | `home_screen.dart:57, 65`, `account_screens.dart:236, 240` | **Calculado** (contagem de `partidas` realizadas e média de `notas_avaliacao`) |
| Perfil do adversário: "★ 4,9 · 12 avaliações", "24 jogos · Fundação 2010", bio, "Time verificado" | `game_detail_screen.dart:160-186` | Banco/calculado (`times.*`, agregados, `times.verificado`) |
| Quantidade de jogadores do time | **Não existia** (regra de negócio exige) | Banco (`times.quantidade_jogadores`) — campo adicionado ao cadastro |
| Capitão / integrantes | Não existia no app; backend tem `team_members` com papéis owner/manager/member | Banco: **um** capitão (`times.id_capitao`); integrantes sem cadastro |

### 2.3 Anúncios de partidas

| Dado | Onde estava fixo | Classificação |
|---|---|---|
| 4 jogos fictícios (time, sigla, modalidade, categoria, cidade, data, hora, local, nível, distância, mando) | `lib/repositories/mock_repository.dart:4-61` | Banco (`anuncios_partidas`) |
| Modelo `Game` com tudo em `String` (data "Sáb, 18 jul", distância "3,2 km") | `lib/models/game.dart` | Substituído por `AnuncioPartida` tipado (`DateTime`, `double?`, `ItemReferencia`) |
| Lista "Meus anúncios" como `List<String>` `'União FC procura adversário\|Ativo'` | `lib/app.dart:23, 186, 231, 429` | Banco (`anuncios_partidas.status`) |
| Subtítulo "Futebol · Livre · São Paulo, SP" igual para todo anúncio | `account_screens.dart:58-63` | Banco (campos do anúncio) |
| "Interessados · 2" | `account_screens.dart:95` | Calculado (contagem de `solicitacoes_confronto` em aberto) |
| "Aluguel do espaço: R$ 120 por time" | `game_detail_screen.dart:75` | Banco (`valor_aluguel_por_time`) |
| Jogadores "5 por equipe" / "11 por equipe" deduzido da modalidade | `game_detail_screen.dart:73` | Banco (`anuncios_partidas.quantidade_jogadores`) |
| Texto "Sobre o jogo" | `game_detail_screen.dart:106-111` | Banco (`anuncios_partidas.descricao`) |
| "de 2026" concatenado à data | `game_detail_screen.dart:66`, `account_screens.dart:616` | Derivado de `data_hora_inicio` |
| Formulário: modalidade, categoria, nível, jogadores, data, horário, cidade, bairro, local, mando, taxa, observações — só modalidade+data eram usados | `activity_screens.dart:7-150` (descarte em `:138`) | Banco; todos os campos agora vão para `RascunhoAnuncio` |
| Status do anúncio | Só "Ativo/Pausado" em string | Banco: `ativo`, `pausado`, `encerrado`, `expirado` |
| **Vagas disponíveis** | **Não existe** no app, no protótipo nem no backend | Decisão pendente (seção 10) |

### 2.4 Categorias e classificações

| Lista | Onde estava fixa | Valores no código | Valores oficiais |
|---|---|---|---|
| Modalidade | `discover_screen.dart:71`, `activity_screens.dart:43`, `account_screens.dart:914-917`, `database/seeds.sql:338-339` | Futebol, Futsal | Futebol society/sintético, Futebol de quadra |
| Categoria etária | `discover_screen.dart:200`, `activity_screens.dart:56`, `account_screens.dart:924-930`, `seeds.sql:341-343` | Livre, Sub-15, Sub-17, **Sub-20**, **Veterano** | Sub-15, Sub-17, Sub-19, Livre |
| Nível técnico | `discover_screen.dart:209`, `activity_screens.dart:67`, `seeds.sql:345-346` | **Recreativo**, Intermediário, Avançado | Iniciante, Intermediário, Avançado |
| Mando de campo | `activity_screens.dart:99-102`, `seeds.sql:348-349` | Jogo em casa, Jogo fora, Indiferente | Não definido nas regras (mantido) |
| Critérios de avaliação | `account_screens.dart:732-737`, `seeds.sql:375-377` | Pontualidade, Organização, Respeito, Estrutura do local | Não definido nas regras (mantido) |
| Estados (UF) | `account_screens.dart:944-955` (só 10 UFs) | SP, RJ, MG, PR, RS, SC, BA, PE, CE, DF | 27 UFs (já em `seeds.sql`) |
| Raio de distância | `discover_screen.dart:188` | 5, 10, 25, 50, 100 km | **Parâmetro de UI legítimo** — continua no código |
| Abas de "Meus jogos" | `activity_screens.dart:479` | Todos, Aguardando, Negociando, Confirmado, Realizado, Cancelado | **Navegação** — continua no código, agora alimentada por status reais |

Já existia estrutura dinâmica no backend (`GET /api/catalogs`, `GET /api/sports`), mas o app não a usava e os valores semeados também divergem das regras.

### 2.5 Solicitações de confronto

| Dado | Onde estava fixo | Classificação |
|---|---|---|
| "Interesse" apenas navegava para o chat | `lib/app.dart:335` | Banco (`solicitacoes_confronto`) via `POST /solicitacoes` |
| Confirmação = booleano local `confirmed` | `lib/app.dart:340` | Banco: confirmação de cada lado (`confirmado_anunciante_em`, `confirmado_solicitante_em`) |
| Recusa, encerramento automático, alerta aos capitães | **Não existiam** | Regras na API/banco; simuladas no repositório de demonstração (encerramento) |
| Backend: `game_interests` com `accepted/declined/withdrawn`, sem criar partida nem encerrar as demais | `backend/src/routes/interests.ts:161` | Precisa ser reescrito (seção 9) |

### 2.6 Partidas

| Dado | Onde estava fixo | Classificação |
|---|---|---|
| Próxima partida "Confirmada · Sábado, 18 de julho · União FC VS Real Amigos · Campo do Ibirapuera · 16:00" | `home_screen.dart:102, 131` | Banco (`partidas`) via `GET /partidas/proxima` |
| Endereço "Av. República do Líbano, 1111 · São Paulo, SP" | `account_screens.dart:622-623` | Banco (`partidas.endereco`, cópia do anúncio) |
| "Amistoso · Futebol" | `account_screens.dart:558` | Banco (`partidas.id_modalidade`) |
| Histórico "2 × 1 Real Amigos FC 11 jul 2026", "1 × 1 Atlético 4 jul 2026" | `account_screens.dart:223-231` | Banco (`partidas` realizadas, `gols_*` opcionais) |
| Lista "Meus jogos" montada com índices fixos de `MockRepository.games[i]` | `activity_screens.dart:466+`, `app.dart:275-290` | Composição de anúncios + solicitações + partidas |

### 2.7 Outras funcionalidades

| Funcionalidade | Estado antes | Estado agora | Dependência |
|---|---|---|---|
| Notificações | Apenas visual: 4 tuplas fixas (`mock_repository.dart:63-88`) | Lista dinâmica, tipos tipados, navegação por referência (anúncio/solicitação/partida) | API + tabela `notificacoes`; push (FCM) não existe |
| Conversas / mensagens | Apenas visual: 2 conversas fixas por índice (`activity_screens.dart:209+`), 3 mensagens fixas (`:312`), "Carlos · Responsável", horários "14:32"/"Ontem", contador "2" | Ligadas a `SolicitacaoConfronto` e `Mensagem`; enviar mensagem chama o repositório | API + tabela `mensagens`; tempo real não existe (só recarga) |
| Avaliações | Parcial: estrelas por critério com validação; envio descartado; comentário descartado | Critérios do cadastro de referência; envio de `NovaAvaliacao` | API + `avaliacoes`/`notas_avaliacao` |
| Histórico de partidas | Apenas visual (2 linhas fixas) | Partidas realizadas reais | API |
| Busca e filtros | Parcial: filtro em memória; data só reconhecia "18"/"19" (`discover_screen.dart:37`); distância parseada de texto (`:45`) | Filtro enviado à API (`FiltroAnuncios`); data dd/mm/aaaa; debounce no texto | API; distância depende de geolocalização |
| Mapa | Apenas visual (ilustrativo, bairros de SP fixos) | Continua ilustrativo, marcadores = anúncios reais, legenda com a cidade do time; rótulos "VILA MARIANA/IBIRAPUERA" removidos | Integração de mapas e geolocalização (pendente) |
| Login com Google | Apenas visual (snackbar) | Inalterado | Fora do escopo |
| Recuperação de senha | Apenas visual | Chama `POST /auth/recuperar-senha` | API + envio de e-mail |
| Abrir localização | Botão sem ação | Aviso "em breve" | `url_launcher` (pendente) |
| Escudo/foto (upload) | Não existe no Flutter (só no protótipo) | Campo `urlEscudo` previsto, não exibido | Armazenamento de arquivos (pendente) |
| Favoritos, créditos, pagamentos | **Não existem** | — | — |

---

## 3. Classificação

### 3.1 Dados que devem ser persistidos no banco
Usuários (capitães) · times · modalidades praticadas pelo time · quantidade de jogadores · anúncios de partidas · solicitações de confronto · mensagens · partidas · avaliações e notas · notificações · tokens de recuperação de senha · cadastros de referência (modalidades, categorias etárias, níveis técnicos, mandos de campo, critérios de avaliação, estados).

### 3.2 Calculados pela API (não armazenar como coluna editável)
Total de partidas realizadas do time · média e total de avaliações · total de solicitações em aberto de um anúncio · mensagens não lidas e última mensagem de uma conversa · distância até o anúncio · próxima partida.

### 3.3 Configurações técnicas (ambiente)
| Configuração | Onde fica |
|---|---|
| URL da API | `--dart-define=API_BASE_URL` → `lib/config/api_config.dart` |
| Usar dados de demonstração | `--dart-define=USE_DEMO_DATA` (padrão: ligado em debug/teste, **desligado em release**) |
| Timeout HTTP (15 s) | `lib/config/api_config.dart` |
| Host, porta, credenciais MySQL, `JWT_SECRET`, `JWT_EXPIRES_IN`, `CORS_ORIGIN` | `backend/.env` (modelo em `backend/.env.example`, sem segredos reais) |

Nenhum segredo existe no código Flutter.

### 3.4 Elementos que continuam fixos no código (legítimos)
Cores e tema (`lib/theme/app_theme.dart`), tipografia, espaçamentos, ícones, `PitchLinesPainter`, marca `BrandMark`, títulos e textos institucionais ("Tem jogo esperando pelo seu time.", "Compromisso e respeito dentro e fora de campo." etc.), mensagens de diálogo, rotas/títulos da AppBar, abas de "Meus jogos", opções do raio de distância, faixas de validação de formulário, formatação de datas pt-BR (`lib/core/formatters.dart`).

---

## 4. Informações removidas da estrutura fixa do código

1. `lib/repositories/mock_repository.dart` — **removido** (substituído por `lib/repositories/demo/demo_repositories.dart`, só para demonstração).
2. `lib/models/game.dart` — **removido** (substituído por `AnuncioPartida`, que tipa datas, valores e classificações).
3. Todas as listas de modalidade/categoria/nível/mando/critério/UF nas telas.
4. Nome do usuário, nome/sigla/ano/descrição/contato do time, estatísticas e avaliação.
5. Próxima partida, histórico, endereço, placar e "Amistoso · Futebol".
6. Mensagens do chat, nome do responsável adversário, conversas, horários e contadores.
7. Notificações.
8. Anúncios em `List<String>` e o subtítulo/contador fixos de "Meus anúncios".
9. Taxa "R$ 120", "11/5 por equipe", texto "Sobre o jogo", perfil do adversário.
10. Rótulos de bairros de São Paulo no mapa e legenda "São Paulo, SP".

Os dados fictícios que permanecem (em `demo_repositories.dart`) usam nomes inventados, telefone `(11) 90000-0000` e e-mail `capitao.demo@example.com`, e as datas são relativas ao dia atual (as fixas de julho/2026 já haviam passado).

## 5. Informações que ainda precisam ser cadastradas dinamicamente

| Origem | O que cadastrar |
|---|---|
| Script do novo banco (dados iniciais de referência) | Modalidades, categorias etárias, níveis técnicos, mandos de campo, critérios de avaliação, 27 UFs |
| Usuário no app (cadastro) | Capitão: nome, e-mail, senha, telefone, cidade, UF · Time: nome, modalidade(s), categoria, nível, quantidade de jogadores, cidade, UF |
| Usuário no app (perfil) | Descrição, ano de fundação, telefone de contato, sigla, escudo (quando houver upload). Hoje a tela de edição só altera o nome: os demais campos já existem em `AtualizacaoTime`, mas falta o formulário |
| Usuário no app (uso) | Anúncios, solicitações, confirmações, recusas, mensagens, cancelamentos, avaliações, placar (se aprovado) |
| API (automático) | Notificações, encerramento de solicitações, status `encerrado`/`expirado` de anúncios, status `realizada` de partidas, agregados |
| Administração | `times.verificado` (não há painel administrativo; decidir quem marca) |

---

## 6. Estrutura criada/modificada no Flutter

```
lib/
├─ config/api_config.dart         (mod) URL da API, USE_DEMO_DATA, timeout
├─ core/formatters.dart           (novo) datas/horas/moeda/distância pt-BR, leitura de dd/mm/aaaa, sigla
├─ models/
│  ├─ referencia.dart             (novo) ItemReferencia, Estado, Referencias
│  ├─ usuario.dart                (novo) Usuario, CadastroCapitao
│  ├─ time.dart                   (novo) ResumoTime, Time, AtualizacaoTime
│  ├─ anuncio_partida.dart        (novo) AnuncioPartida, StatusAnuncio, RascunhoAnuncio, FiltroAnuncios
│  ├─ solicitacao_confronto.dart  (novo) SolicitacaoConfronto, StatusSolicitacao, Mensagem
│  ├─ partida.dart                (novo) Partida, StatusPartida, NovaAvaliacao, AvaliacaoRecebida
│  └─ notificacao.dart            (novo) Notificacao, TipoNotificacao
├─ repositories/
│  ├─ contratos.dart              (novo) interfaces Auth/Referencia/Time/Anuncio/Solicitacao/Partida/Notificacao + Repositorios + Sessao
│  ├─ api/api_repositories.dart   (novo) implementação HTTP (contrato da seção 8)
│  └─ demo/demo_repositories.dart (novo) implementação em memória, com as regras de negócio simuladas
├─ services/api_client.dart       (mod) corrigido e completado
├─ state/app_state.dart           (novo) AppState (sessão + referências) e AppScope (InheritedNotifier)
├─ widgets/carregador.dart        (novo) estados de carregamento/erro (+ "Tentar novamente")
├─ widgets/common.dart            (mod) Crest sem dados fixos; GameCard → AnuncioCard
├─ screens/*.dart                 (mod) todas as telas leem repositórios; layout, cores e textos preservados
├─ app.dart                       (mod) navegação igual; orquestra ações e bloqueia telas sem sessão
└─ main.dart                      (mod) cria AppState (injetável em testes)
test/widget_test.dart             (mod) 3 testes de fluxo
test/dados_test.dart              (novo) 9 testes de regras, HTTP e formatação
```

Decisões técnicas:
- **Sem novas dependências.** Estado com `ChangeNotifier` + `InheritedNotifier`; o projeto não usava gerenciador de estado e o tamanho atual não justifica um.
- **Contrato JSON em camelCase português**, espelhando as futuras colunas (`id_anuncio` → `idAnuncio`). O envelope `{data, meta}` / `{error: {code, message}}` da API atual foi mantido.
- **IDs como `String`** (UUID), compatível com a API atual.
- **Datas** trafegam em ISO 8601 UTC e são exibidas no fuso do aparelho.
- **Estados vazios** usam o componente `EmptyState` já existente, com as mensagens no tom da marca.
- Alterações visuais mínimas e justificadas: campo "Quantidade de jogadores" e dropdown "Nível do time" no cadastro (regra de negócio); título do perfil "Sobre o time" (o anterior era texto do time fictício); "Interessados · N", tags e ano do escudo agora condicionais aos dados; botão "Confirmar partida" mostra "Aguardando o adversário" depois da confirmação de um lado.

---

## 7. Entidades necessárias para o novo banco

Convenções: português sem acentos, `snake_case`, InnoDB, `utf8mb4_0900_ai_ci`, datas `DATETIME(3)` em UTC, IDs de negócio `CHAR(36)` (UUID gerado pela API), referências com `TINYINT/SMALLINT UNSIGNED AUTO_INCREMENT`.

### 7.1 Cadastros de referência

| Tabela | Finalidade | Campos (tipo) | PK | Restrições | Usado em |
|---|---|---|---|---|---|
| `estados` | UFs | `sigla CHAR(2)`, `nome VARCHAR(40)`, `ativo BOOLEAN` | `sigla` | 27 linhas | Cadastro, anúncio, perfil |
| `modalidades` | Modalidades | `id_modalidade TINYINT UNSIGNED`, `codigo VARCHAR(30) UNIQUE`, `nome VARCHAR(60)`, `ordem SMALLINT`, `ativo BOOLEAN`, `data_criacao`, `data_atualizacao` | `id_modalidade` | `codigo` em ascii; nome não vazio | Busca (chips), anúncio, cadastro, perfil |
| `categorias_etarias` | Faixa etária | mesmos campos + `idade_maxima TINYINT UNSIGNED NULL` | `id_categoria_etaria` | Sub-15=15, Sub-17=17, Sub-19=19, Livre=NULL | Busca, anúncio, cadastro, perfil |
| `niveis_tecnicos` | Nível | mesmos campos | `id_nivel_tecnico` | | Busca, anúncio, cadastro, perfil |
| `mandos_campo` | Mando | mesmos campos | `id_mando_campo` | | Anúncio, detalhe |
| `criterios_avaliacao` | Critérios de nota | mesmos campos | `id_criterio` | | Avaliar partida |

Origem: hoje fixos em telas e em `database/seeds.sql`; passarão a ser carregados por `GET /referencias`.

### 7.2 Entidades de negócio

**`usuarios`** — capitães (únicos usuários com conta). Origem: tela Criar conta/Entrar. Usado em: autenticação, saudação, avatar, perfil, chat.

| Campo | Tipo | Obrig. | Observação |
|---|---|---|---|
| `id_usuario` | CHAR(36) | sim | PK, UUID |
| `nome` | VARCHAR(120) | sim | não vazio |
| `email` | VARCHAR(254) | sim | UNIQUE, minúsculo |
| `senha_hash` | VARCHAR(255) | sim | bcrypt/argon2; nunca a senha |
| `telefone` | VARCHAR(20) | não | |
| `url_foto` | VARCHAR(500) | não | sem upload ainda |
| `cidade` | VARCHAR(100) | não | |
| `sigla_estado` | CHAR(2) | não | FK `estados` |
| `status_conta` | VARCHAR(20) | sim | `ativa`, `suspensa`, `excluida` (CHECK) |
| `email_verificado_em` | DATETIME(3) | não | |
| `data_criacao`, `data_atualizacao` | DATETIME(3) | sim | |
| `data_exclusao` | DATETIME(3) | não | exclusão lógica (LGPD) |

**`tokens_recuperacao_senha`** — fluxo "Recuperar acesso". `id_token CHAR(36)` PK · `id_usuario` FK · `token_hash BINARY(32)` UNIQUE · `expira_em` · `usado_em NULL` · `data_criacao`.

**`times`** — um por capitão. Origem: cadastro e perfil. Usado em: todas as telas.

| Campo | Tipo | Obrig. | Observação |
|---|---|---|---|
| `id_time` | CHAR(36) | sim | PK |
| `id_capitao` | CHAR(36) | sim | FK `usuarios`, **UNIQUE** (1 time por capitão — confirmar, seção 10) |
| `nome` | VARCHAR(120) | sim | |
| `sigla` | VARCHAR(4) | não | se nulo, a API/app deriva do nome |
| `url_escudo` | VARCHAR(500) | não | |
| `cidade` | VARCHAR(100) | sim | |
| `sigla_estado` | CHAR(2) | sim | FK `estados` |
| `bairro` | VARCHAR(100) | não | |
| `quantidade_jogadores` | TINYINT UNSIGNED | sim | informada pelo capitão; CHECK de faixa |
| `id_categoria_etaria` | TINYINT UNSIGNED | sim | FK |
| `id_nivel_tecnico` | TINYINT UNSIGNED | não | FK |
| `descricao` | VARCHAR(2000) | não | |
| `ano_fundacao` | SMALLINT UNSIGNED | não | CHECK 1900..ano atual (validar na API) |
| `telefone_contato` | VARCHAR(20) | não | |
| `verificado` | BOOLEAN | sim | padrão FALSE |
| `data_criacao`, `data_atualizacao` | DATETIME(3) | sim | |
| `data_arquivamento` | DATETIME(3) | não | |

**`times_modalidades`** — modalidades praticadas (N:N). `id_time` FK + `id_modalidade` FK, PK composta.

**`anuncios_partidas`** — Origem: "Anunciar jogo". Usado em: Início, Buscar, Detalhes, Mapa, Meus anúncios, Meus jogos.

| Campo | Tipo | Obrig. | Observação |
|---|---|---|---|
| `id_anuncio` | CHAR(36) | sim | PK |
| `id_time` | CHAR(36) | sim | FK `times` |
| `id_modalidade`, `id_categoria_etaria` | TINYINT UNSIGNED | sim | FK |
| `id_nivel_tecnico`, `id_mando_campo` | TINYINT UNSIGNED | não | FK |
| `quantidade_jogadores` | TINYINT UNSIGNED | sim | por equipe; CHECK 2..30 (faixa a confirmar) |
| `data_hora_inicio` | DATETIME(3) | sim | UTC |
| `cidade` | VARCHAR(100) | sim | |
| `sigla_estado` | CHAR(2) | sim | FK |
| `bairro` | VARCHAR(100) | não | obrigatório no formulário |
| `nome_local` | VARCHAR(160) | sim | |
| `endereco` | VARCHAR(255) | não | |
| `latitude`, `longitude` | DECIMAL(9,6) | não | em par (CHECK) |
| `valor_aluguel_por_time` | DECIMAL(10,2) | não | ≥ 0 |
| `descricao` | VARCHAR(1000) | não | "Observações" |
| `status` | VARCHAR(20) | sim | `ativo`, `pausado`, `encerrado`, `expirado` |
| `data_criacao`, `data_atualizacao` | DATETIME(3) | sim | |
| `data_exclusao` | DATETIME(3) | não | "Excluir" = exclusão lógica |

**`solicitacoes_confronto`** — Origem: "Tenho interesse". Usado em: Conversas, Chat, Meus jogos, contador "Interessados".

| Campo | Tipo | Obrig. | Observação |
|---|---|---|---|
| `id_solicitacao` | CHAR(36) | sim | PK |
| `id_anuncio` | CHAR(36) | sim | FK |
| `id_time_anunciante` | CHAR(36) | sim | cópia do dono do anúncio; FK composta (`id_anuncio`, `id_time_anunciante`) → `anuncios_partidas(id_anuncio, id_time)` |
| `id_time_solicitante` | CHAR(36) | sim | FK `times`; CHECK ≠ anunciante |
| `status` | VARCHAR(20) | sim | `pendente`, `confirmada`, `recusada`, `cancelada`, `encerrada` |
| `mensagem_inicial` | VARCHAR(1000) | não | |
| `confirmado_anunciante_em` | DATETIME(3) | não | |
| `confirmado_solicitante_em` | DATETIME(3) | não | |
| `data_resposta` | DATETIME(3) | não | confirmação final/recusa/encerramento |
| `motivo_encerramento` | VARCHAR(255) | não | |
| `data_criacao` (= data da solicitação), `data_atualizacao` | DATETIME(3) | sim | |

Unicidade: no máximo uma solicitação **pendente** por (`id_anuncio`, `id_time_solicitante`) — coluna gerada + UNIQUE.

**`mensagens`** — Chat dentro da solicitação. `id_mensagem CHAR(36)` PK · `id_solicitacao` FK · `id_time_remetente` FK (deve ser anunciante ou solicitante) · `id_usuario_remetente` FK · `texto VARCHAR(1000)` · `data_envio` · `data_leitura NULL` (lida pelo outro time; como cada time tem um capitão, basta esta coluna).

**`partidas`** — criada quando os dois lados confirmam. Guarda cópia dos dados combinados. Usado em: Início (próxima), Partida confirmada, Meus jogos, Histórico, Avaliar.

| Campo | Tipo | Obrig. | Observação |
|---|---|---|---|
| `id_partida` | CHAR(36) | sim | PK |
| `id_solicitacao` | CHAR(36) | sim | FK, UNIQUE |
| `id_anuncio` | CHAR(36) | sim | FK, UNIQUE (um anúncio gera no máximo uma partida) |
| `id_time_anunciante`, `id_time_adversario` | CHAR(36) | sim | FK; CHECK diferentes |
| `id_modalidade` | TINYINT UNSIGNED | sim | cópia |
| `quantidade_jogadores` | TINYINT UNSIGNED | sim | cópia |
| `data_hora_inicio` | DATETIME(3) | sim | cópia |
| `nome_local`, `endereco`, `cidade`, `sigla_estado`, `latitude`, `longitude`, `valor_aluguel_por_time` | — | conforme anúncio | cópias |
| `status` | VARCHAR(20) | sim | `confirmada`, `realizada`, `cancelada` |
| `gols_anunciante`, `gols_adversario` | TINYINT UNSIGNED | não | placar (pendente) |
| `id_time_cancelou`, `motivo_cancelamento`, `data_cancelamento` | — | não | obrigatórios se cancelada |
| `data_realizacao` | DATETIME(3) | não | |
| `data_criacao`, `data_atualizacao` | DATETIME(3) | sim | |

**`avaliacoes`** — `id_avaliacao CHAR(36)` PK · `id_partida` FK · `id_time_avaliador` FK · `id_time_avaliado` FK · `comentario VARCHAR(1000) NULL` · `data_criacao`. UNIQUE (`id_partida`, `id_time_avaliador`). Só para partida `realizada` entre os dois times.

**`notas_avaliacao`** — `id_avaliacao` FK + `id_criterio` FK (PK composta) · `nota TINYINT UNSIGNED` CHECK 1..5.

**`notificacoes`** — `id_notificacao CHAR(36)` PK · `id_usuario_destinatario` FK · `tipo VARCHAR(40)` (CHECK: `solicitacao_recebida`, `mensagem_recebida`, `partida_confirmada`, `partida_cancelada`, `solicitacao_encerrada`, `solicitacao_recusada`, `anuncio_expirando`, `avaliacao_pendente`) · `titulo VARCHAR(160)` · `mensagem VARCHAR(500)` · `id_anuncio NULL` · `id_solicitacao NULL` · `id_partida NULL` · `data_leitura NULL` · `data_criacao`.

## 8. Relacionamentos e contrato da API

```
estados 1─N usuarios, times, anuncios_partidas, partidas
usuarios 1─1 times (id_capitao UNIQUE)
usuarios 1─N tokens_recuperacao_senha, notificacoes, mensagens (remetente)
times N─N modalidades (times_modalidades)
times N─1 categorias_etarias, niveis_tecnicos
times 1─N anuncios_partidas
anuncios_partidas N─1 modalidades, categorias_etarias, niveis_tecnicos, mandos_campo
anuncios_partidas 1─N solicitacoes_confronto          (várias por anúncio)
times 1─N solicitacoes_confronto (solicitante e anunciante)
solicitacoes_confronto 1─N mensagens
solicitacoes_confronto 1─0..1 partidas
anuncios_partidas 1─0..1 partidas
partidas 1─N avaliacoes (máx. 1 por time) 1─N notas_avaliacao N─1 criterios_avaliacao
notificacoes N─0..1 anuncios_partidas / solicitacoes_confronto / partidas
```

Contrato que os repositórios Flutter já consomem (`lib/repositories/api/api_repositories.dart`), base `/api`:

| Método e caminho | Uso | Corpo/retorno (`data`) |
|---|---|---|
| `POST /auth/cadastro` | Criar conta + time (transação) | `{usuario:{nome,email,senha,telefone,cidade,siglaEstado}, time:{nome,idsModalidades,idCategoriaEtaria,idNivelTecnico,quantidadeJogadores,cidade,siglaEstado}}` → `{token, usuario, time}` |
| `POST /auth/login` | Entrar | `{email, senha}` → `{token, usuario, time}` |
| `GET /auth/eu` | Sessão atual | `{usuario, time}` |
| `POST /auth/recuperar-senha` | Recuperação | `{email}` → 202 sem revelar se existe |
| `GET /referencias` | Listas | `{modalidades, categoriasEtarias, niveisTecnicos, mandosCampo, criteriosAvaliacao, estados}`; itens `{id,codigo,nome,ordem}`, estados `{sigla,nome}` |
| `GET /times/:id` · `PATCH /times/:id` | Perfil | `Time` (com agregados `totalPartidasRealizadas`, `mediaAvaliacao`, `totalAvaliacoes`, `nomeCapitao`) |
| `GET /times/:id/avaliacoes` | Avaliações recebidas | `[{notaMedia, comentario, timeAvaliador, dataAvaliacao}]` |
| `GET /anuncios?texto&idModalidade&idCategoriaEtaria&idNivelTecnico&data&raioKm&siglaEstado&cidade` | Busca: só `ativo`, futuros e de outros times | `[AnuncioPartida]` com `time` resumido, itens de referência aninhados, `totalSolicitacoes`, `distanciaKm` |
| `GET /anuncios/meus` · `GET /anuncios/:id` | | |
| `POST /anuncios` · `PUT /anuncios/:id` · `DELETE /anuncios/:id` | Criar/editar/excluir (só capitão dono) | `RascunhoAnuncio` |
| `PATCH /anuncios/:id/status` | Pausar/reativar | `{status}` |
| `POST /solicitacoes` | Tenho interesse | `{idAnuncio, mensagemInicial}` |
| `GET /solicitacoes/minhas` · `GET /solicitacoes/:id` | Conversas | inclui `anuncio`, `timeSolicitante`, `timeAnunciante`, `confirmadoAnunciante`, `confirmadoSolicitante`, `idPartida`, `ultimaMensagem`, `dataUltimaMensagem`, `mensagensNaoLidas` |
| `PATCH /solicitacoes/:id/confirmar` · `/recusar` · `/cancelar` | Confirmação dupla, recusa, desistência | solicitação atualizada |
| `GET/POST /solicitacoes/:id/mensagens` | Chat | `{texto}` → `Mensagem` |
| `GET /partidas/minhas` · `GET /partidas/proxima` · `GET /partidas/:id` | Partidas | `Partida` (`data` = `null` quando não há próxima) |
| `PATCH /partidas/:id/cancelar` | Cancelar | `{motivo}` |
| `POST /partidas/:id/avaliacoes` | Avaliar | `{notas:[{idCriterio,nota}], comentario}` |
| `GET /notificacoes` · `PATCH /notificacoes/:id/lida` | Notificações | |

---

## 9. Backend existente: avaliação

**Manter Express 5.** A pilha atual (Express 5, zod, mysql2/promise com pool, bcryptjs, jsonwebtoken, helmet, express-rate-limit, vitest/supertest) é adequada. Trocar para Fastify não traz ganho que justifique reescrever middlewares e testes.

O que reaproveitar: `config/env.ts` (validação de ambiente com zod), `config/db.ts` (pool + `time_zone` UTC), `middlewares/error-handler.ts` (envelope de erro, mapeamento de `ER_DUP_ENTRY`/`ER_SIGNAL_EXCEPTION`), `middlewares/auth.ts`, rate limit de login, `helpers.ts` (`toJson`, paginação), testes de saúde.

O que precisa mudar na etapa do banco:
1. Todas as consultas usam tabelas/colunas em inglês (`users`, `teams`, `game_listings`, `game_interests`...).
2. `team_members` com papéis `owner/manager/member` e `requireActiveMembership(managerOnly)` contradizem as regras (um capitão, sem permissões). A autorização passa a ser: "o usuário é o capitão do time".
3. `POST /auth/register` cria só o usuário; o app precisa criar usuário + time na mesma transação.
4. `PATCH /interests/:id/status` aceita/recusa, mas não cria partida, não exige confirmação das duas equipes, não encerra as demais solicitações e não notifica.
5. `GET /listings` lista qualquer status por padrão e inclui anúncios do próprio time e passados.
6. `GET /listings/mine` filtra por quem criou, não pelo time.
7. Não há rotas de partidas, mensagens, notificações, avaliações, recuperação de senha nem `/referencias`.
8. Código em linhas únicas minificadas (`routes/*.ts`), difícil de revisar; reescrever com uma rota por arquivo e camada de serviço.
9. `CORS_ORIGIN=*` como padrão; restringir em produção.
10. `seed-reference.ts` lê `database/seeds.sql` (valores divergentes das regras); será substituído pelos dados iniciais do novo script.

---

## 10. Problemas encontrados e decisões pendentes

### Problemas corrigidos nesta etapa
1. `ApiClient` não compilava (`StreamedResponse.body`).
2. Classificações erradas e triplicadas no app (e erradas também em `database/seeds.sql`, **não alterado**).
3. Formulários de cadastro, login, anúncio e avaliação descartavam os dados.
4. Anúncios guardados como texto com status embutido (`'...|Ativo'`).
5. Filtro de data só funcionava para "18" e "19"; distância parseada de string.
6. Datas fixas de julho/2026 já vencidas.
7. Dica de senha (6) diferente da regra do backend (8).
8. `TextField` da busca perdia o texto ao voltar para a tela.
9. Sem sessão, todas as telas eram acessíveis; agora só as de autenticação.

### Decisões pendentes (preciso da sua confirmação)
1. **Um time por capitão?** O app assume uma sessão = um time. Recomendo `UNIQUE(id_capitao)`.
2. **"Vagas disponíveis"** não existe em nenhuma camada. Num confronto entre times, o que seria? (Ex.: vagas para completar o time adversário? ou o anúncio aceitar N solicitações?) Sem definição, não entra no banco.
3. **Mando de campo, taxa de aluguel, bairro e endereço** existem na UI, mas não estão na sua lista. Recomendo manter (opcionais, exceto bairro, obrigatório no formulário).
4. **Faixas de quantidade de jogadores:** time (sugestão 5–60) e anúncio por equipe (app: 2–30; backend atual: 5–30). Society costuma ter 7 e quadra 5: sugiro 5–30 no anúncio.
5. **Placar:** o perfil mostra placar no histórico. Registrar? Quem informa (os dois capitães ou só um)?
6. **Partida cancelada:** o anúncio volta a ficar ativo ou permanece encerrado? (Recomendo permanecer; o capitão publica outro.)
7. **Quando a partida vira "realizada"?** Automático após `data_hora_inicio` + N horas (evento agendado) ou por ação de um capitão?
8. **Expiração de anúncios:** marcar `expirado` automaticamente após a data (evento MySQL ou job na API)?
9. **Recusar solicitação:** existe na API/repositório, mas não há botão na UI (o Figma não prevê). Adicionar?
10. **Tempo real no chat:** recarga manual/polling agora; WebSocket/FCM depois?
11. **Persistência do token** no aparelho: adicionar `flutter_secure_storage` (hoje o token fica só em memória e o usuário entra de novo ao reabrir o app).
12. **Upload de escudo/foto** e **geolocalização/mapa real** (com consentimento LGPD): dependem de serviços externos.
13. **Login com Google:** manter apenas visual?
14. **Nome do novo banco:** sugiro `joga_contra_v2`, para não destruir o `joga_contra` atual.
15. **Quem marca `times.verificado`?** Não há painel administrativo.
