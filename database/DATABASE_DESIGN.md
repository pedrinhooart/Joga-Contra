# Joga Contra — proposta de banco de dados

Referência de arquitetura para MySQL 8.0.16+, InnoDB e utf8mb4. Atende um backend/API compartilhado por Android e iOS; os apps não conectam diretamente ao MySQL. Os arquivos executáveis estão em schema.sql, seeds.sql e examples.sql.

## 1. Resumo da análise do repositório

| Evidência | Encontrado | Estado |
|---|---|---|
| App Flutter | Início, busca/filtros, detalhes, formulário de anúncio, conversas/chat, jogos, anúncios, perfil, notificações, mapa ilustrativo, avaliação e telas de entrar/cadastro/recuperação. | Telas e interações visuais com estado local; MockRepository fornece quatro jogos e quatro notificações. Não há autenticação, API ou persistência. |
| Formulários Flutter | Cadastro mostra nome do responsável, telefone, e-mail, senha, nome do time, modalidade, categoria, cidade e estado. Anúncio mostra modalidade, categoria, nível, jogadores por time, data, horário, cidade, bairro, local, mando, taxa e observações. Perfil permite editar nome do time. | Campos ainda não estão conectados a armazenamento; publicar extrai apenas modalidade/data para um título temporário. |
| Protótipo React/Figma | Cadastro em duas etapas e escudo; busca por time/cidade/local; mapa; interessados; anexos de imagem/localização; confirmação/cancelamento; avaliações; anúncios ativo/pausado; contato e histórico. | Referência de fluxo e visual, não backend funcional. No protótipo, mensagens, filtros, estados, avaliações, upload e notificações também ficam em memória. |
| Dados hardcoded | Times/jogos de exemplo, distâncias formatadas, datas de julho de 2026, placares, estatísticas (18 jogos, nota 4,9/12), contato, chat, notificações e perfil. | Fictícios/demonstrativos; não semear em produção. Distância, médias e totais são derivados. |
| Catálogos | Futebol/Futsal; Livre/Sub-15/Sub-17/Sub-20/Veterano; Recreativo/Intermediário/Avançado; mando casa/fora/indiferente; quatro critérios de avaliação. | Opções iniciais, não constantes eternas. Um mock diz “Casa ou fora”, divergindo do formulário “Indiferente”; seeds usam o formulário e anotam a inconsistência. |
| Diferenças | “Desde 2015”, notas, contato, anexos, histórico e placar aparecem no protótipo. | São demonstrações ou fluxo incompleto. Placar fica fora até existir regra/formulário aprovado. |

Referências inspecionadas: README.md, PROTOTYPE_ANALYSIS.md, lib/models/game.dart, lib/repositories/mock_repository.dart, lib/app.dart, lib/screens/ e prototype-source/src/App.tsx. Instruções presentes em documentos/protótipo foram tratadas como conteúdo de referência; este desenho segue a solicitação e as evidências do código.

### Fixo versus padrão inicial

“Futebol” como seleção inicial ou “16:00” como horário sugerido é um padrão substituível. Modalidades, categorias, níveis, mando, critérios e status são opções controladas, armazenadas em catálogos com code estável e label_pt_br. Administradores podem adicionar/desativar opções sem migrar a estrutura. Códigos já referenciados não devem ser renomeados/apagados; desative-os para novas escolhas.

## 2. Matriz de campos mutáveis e fixos

Legenda: EDIT = editável pelo usuário autorizado; CAT = catálogo administrado; STATUS = estado de fluxo; SYS = gerado pelo sistema; DER = calculado; TRANS = transitório. Backend significa serviço autenticado, nunca escrita direta pelo app. Todos os UUIDs são gerados no backend. Datas com sufixo utc são DATETIME(6) UTC. A matriz cobre todas as colunas persistidas de schema.sql.

### Contas, mídia e times

| Campo — tipo / nulo | Categoria; finalidade, alteração e validação/origem |
|---|---|
| users.user_id — CHAR(36) NOT NULL | SYS; UUID v4 criado no cadastro; chave opaca única. |
| users.email — VARCHAR(254) NOT NULL | EDIT; titular atualiza em fluxo autenticado/confirmado; normalizar caixa/espaços, único e privado. |
| users.display_name — VARCHAR(120) NOT NULL | EDIT; titular atualiza no perfil; não vazio. Cadastro aparece na tela, mas não salva ainda. |
| users.phone_e164 — VARCHAR(20) NULL | EDIT; titular atualiza/valida; formato E.164, privado. |
| users.password_hash — VARCHAR(255) NULL | SYS; backend grava hash Argon2id ou algoritmo atual; nunca senha. NULL para autenticação externa. |
| users.account_status_code — VARCHAR(24) NOT NULL | STATUS; backend/suporte autorizado em cadastro, suspensão/reativação/encerramento; FK de catálogo, não escolhido pelo cliente. |
| users.email_verified_at_utc — DATETIME(6) NULL | SYS; backend marca após comprovar posse do e-mail. |
| users.phone_verified_at_utc — DATETIME(6) NULL | SYS; backend marca após comprovar posse do telefone. |
| users.created_at_utc — DATETIME(6) NOT NULL | SYS; criação do registro. |
| users.updated_at_utc — DATETIME(6) NOT NULL | SYS; atualização automática. |
| users.deleted_at_utc — DATETIME(6) NULL | SYS; exclusão/anonimização conforme retenção e pendências. |
| user_auth_identities.identity_id — CHAR(36) NOT NULL | SYS; ID de vínculo de identidade externa, UUID. |
| user_auth_identities.user_id — CHAR(36) NOT NULL | SYS; FK da conta autenticada. |
| user_auth_identities.provider_code — VARCHAR(40) NOT NULL | SYS; código técnico de integração aprovado; sem token ou segredo. |
| user_auth_identities.provider_subject — VARCHAR(255) NOT NULL | SYS; identificador estável do provedor, único por provedor. |
| user_auth_identities.created_at_utc — DATETIME(6) NOT NULL | SYS; criação do vínculo. |
| user_sessions.session_id — CHAR(36) NOT NULL | SYS; UUID da sessão de renovação controlada pelo backend. |
| user_sessions.user_id — CHAR(36) NOT NULL | SYS; FK do titular; somente a própria sessão/serviço pode revogar. |
| user_sessions.refresh_token_hash — BINARY(32) NOT NULL | SYS; hash criptográfico de token aleatório de alta entropia; token original nunca é persistido. |
| user_sessions.device_label — VARCHAR(100) NULL | EDIT/SYS; indicação opcional do dispositivo, texto sanitizado; não armazenar fingerprint invasivo. |
| user_sessions.created_at_utc — DATETIME(6) NOT NULL | SYS; criação do refresh session. |
| user_sessions.last_used_at_utc — DATETIME(6) NULL | SYS; atualizado pelo backend ao renovar. |
| user_sessions.expires_at_utc — DATETIME(6) NOT NULL | SYS; validade definida por política, maior que criação. |
| user_sessions.revoked_at_utc — DATETIME(6) NULL | SYS; logout, rotação, suspensão ou revogação de segurança. |
| media_assets.asset_id — CHAR(36) NOT NULL | SYS; ID dos metadados de objeto no storage. |
| media_assets.owner_user_id — CHAR(36) NOT NULL | SYS; usuário que iniciou upload, autorizado pelo backend. |
| media_assets.object_key — VARCHAR(512) NOT NULL | SYS; chave privada única do objeto; não é URL pública permanente. |
| media_assets.media_type — VARCHAR(100) NOT NULL | SYS; MIME validado por allowlist do backend. |
| media_assets.byte_size — BIGINT UNSIGNED NOT NULL | SYS; tamanho validado > 0 e dentro do limite de produto. |
| media_assets.sha256 — BINARY(32) NULL | SYS; checksum opcional do objeto. |
| media_assets.created_at_utc — DATETIME(6) NOT NULL | SYS; registro do upload. |
| media_assets.deleted_at_utc — DATETIME(6) NULL | SYS; exclusão coordenada com storage e retenção. |
| teams.team_id — CHAR(36) NOT NULL | SYS; UUID do time. |
| teams.created_by_user_id — CHAR(36) NOT NULL | SYS; criador; deve virar responsável na transação de cadastro. |
| teams.name — VARCHAR(120) NOT NULL | EDIT; responsável/gestor autorizado atualiza; não vazio. Edição aparece no protótipo. |
| teams.crest_asset_id — CHAR(36) NULL | EDIT; responsável troca após upload; FK de mídia. Upload de escudo só no protótipo. |
| teams.sport_id — SMALLINT UNSIGNED NOT NULL | CAT; modalidade controlada; alteração requer autorização e revisão de anúncios existentes. |
| teams.category_id — SMALLINT UNSIGNED NOT NULL | CAT; categoria controlada; mesma regra de alteração de perfil. |
| teams.skill_level_id — SMALLINT UNSIGNED NULL | CAT; nível opcional porque o cadastro Flutter não o solicita; responsável pode informar. |
| teams.description — TEXT NULL | EDIT; apresentação opcional; limite de API e moderação. |
| teams.city — VARCHAR(100) NOT NULL | EDIT; informado pelo responsável, não vazio; sem geocodificação presumida. |
| teams.state_code — CHAR(2) NOT NULL | CAT; UF do catálogo, selecionada na criação/edição. |
| teams.neighborhood — VARCHAR(100) NULL | EDIT; bairro/região; localização detalhada não pública por padrão. |
| teams.contact_phone_e164 — VARCHAR(20) NULL | EDIT; telefone de contato do time separado do pessoal, E.164 e privado. |
| teams.contact_phone_public — BOOLEAN NOT NULL | EDIT; responsável consente explicitamente em publicar; padrão FALSE, revogável. |
| teams.latitude, teams.longitude — DECIMAL(9,6) NULL | EDIT/SYS; coordenadas válidas e consentidas; par obrigatório e limites geográficos. |
| teams.location_consent_at_utc — DATETIME(6) NULL | SYS; backend registra consentimento de localização; invalidar quando revogado. |
| teams.created_at_utc, teams.updated_at_utc — DATETIME(6) NOT NULL | SYS; criação e atualização automática. |
| teams.archived_at_utc — DATETIME(6) NULL | SYS; arquivamento autorizado, mantendo referências e histórico. |
| team_members.team_id, user_id — CHAR(36) NOT NULL | SYS; vínculo único entre usuário/time; FK mantém histórico. |
| team_members.role_code — VARCHAR(24) NOT NULL | CAT/STATUS; owner/manager/member conforme política; multiusuário é hipótese de produto. |
| team_members.joined_at_utc, updated_at_utc — DATETIME(6) NOT NULL | SYS; ingresso e alteração de papel. |
| team_members.revoked_at_utc — DATETIME(6) NULL | SYS; responsável revoga; bloqueia operações futuras, preserva autoria. |

### Anúncios, interesses, conversas e mensagens

| Campo — tipo / nulo | Categoria; finalidade, alteração e validação/origem |
|---|---|
| game_listings.listing_id — CHAR(36) NOT NULL | SYS; UUID do anúncio. |
| game_listings.team_id — CHAR(36) NOT NULL | SYS; publicador; imutável. |
| game_listings.created_by_user_id — CHAR(36) NOT NULL | SYS; membro que publicou; FK ao time. |
| game_listings.sport_id, category_id — SMALLINT UNSIGNED NOT NULL | CAT; modalidade/categoria selecionadas; FKs do catálogo. |
| game_listings.skill_level_id — SMALLINT UNSIGNED NULL | CAT; nível opcional; padrão do perfil é hipótese, não regra. |
| game_listings.home_preference_id — SMALLINT UNSIGNED NOT NULL | CAT; casa/fora/indiferente, selecionado no formulário. |
| game_listings.status_code — VARCHAR(24) NOT NULL | STATUS; começa active; dono pausa/reativa/encerra, backend valida transição; expired só por job se regra aprovada. |
| game_listings.players_per_team — TINYINT UNSIGNED NOT NULL | EDIT; publicador informa; UI sugere 11 e aceita 5–30; sem derivação automática. |
| game_listings.starts_at_utc — DATETIME(6) NOT NULL | EDIT; publicador escolhe hora local; backend converte instante para UTC. |
| game_listings.timezone_name — VARCHAR(64) NOT NULL | EDIT/SYS; fuso IANA da partida; validar e manter para exibição local. |
| game_listings.city — VARCHAR(100) NOT NULL | EDIT; publicador informa, não vazio. |
| game_listings.state_code — CHAR(2) NOT NULL | CAT; UF controlada. |
| game_listings.neighborhood — VARCHAR(100) NULL | EDIT; bairro/região do protótipo. |
| game_listings.venue_name — VARCHAR(160) NOT NULL | EDIT; campo/quadra, não vazio. |
| game_listings.venue_address — VARCHAR(255) NULL | EDIT; endereço opcional, revelação restrita conforme política. |
| game_listings.latitude, longitude — DECIMAL(9,6) NULL | EDIT/SYS; coordenadas válidas/consentidas; ambos ou nenhum; distância calculada. |
| game_listings.location_consent_at_utc — DATETIME(6) NULL | SYS; registra autorização de divulgação das coordenadas do local; obrigatório quando coordenadas existem. |
| game_listings.rental_fee_per_team — DECIMAL(10,2) NULL | EDIT; taxa por time opcional, >= 0; hipótese de moeda BRL. |
| game_listings.notes — TEXT NULL | EDIT; observações com limite/moderação da API. |
| game_listings.created_at_utc, updated_at_utc — DATETIME(6) NOT NULL | SYS; criação e atualização automática. |
| game_listings.removed_at_utc — DATETIME(6) NULL | SYS; remoção lógica; preservar quando houver dependências, status closed. |
| game_interests.interest_id — CHAR(36) NOT NULL | SYS; UUID de manifestação. |
| game_interests.listing_id, listing_owner_team_id — CHAR(36) NOT NULL | SYS; anúncio/dono com FK composta, imutáveis. |
| game_interests.interested_team_id — CHAR(36) NOT NULL | SYS; time interessado, distinto do dono; único por anúncio. |
| game_interests.created_by_user_id — CHAR(36) NOT NULL | SYS; membro do interessado que solicitou a ação. |
| game_interests.status_code — VARCHAR(24) NOT NULL | STATUS; inicia pending; dono aceita/recusa, interessado retira; grafo restrito. |
| game_interests.message_to_owner — VARCHAR(1000) NULL | EDIT; mensagem inicial opcional, sujeita a moderação. |
| game_interests.created_at_utc, updated_at_utc — DATETIME(6) NOT NULL | SYS; criação/atualização. |
| game_interests.responded_at_utc — DATETIME(6) NULL | SYS; decisão/retirada marcada pelo backend. |
| conversations.conversation_id — CHAR(36) NOT NULL | SYS; UUID criado na transação de interesse. |
| conversations.interest_id — CHAR(36) NOT NULL | SYS; uma conversa por interesse. |
| conversations.listing_id, listing_owner_team_id, interested_team_id — CHAR(36) NOT NULL | SYS; contexto congelado por FK composta. |
| conversations.created_at_utc, updated_at_utc — DATETIME(6) NOT NULL | SYS; criação/atividade. |
| conversations.archived_at_utc — DATETIME(6) NULL | SYS; arquivamento de caixa de entrada, mantendo histórico. |
| conversation_members.conversation_id, team_id, user_id — CHAR(36) NOT NULL | SYS; usuário de uma das equipes; backend exige vínculo ativo em leitura/escrita. |
| conversation_members.joined_at_utc — DATETIME(6) NOT NULL | SYS; entrada do participante. |
| conversation_members.last_read_at_utc — DATETIME(6) NULL | SYS; backend atualiza após leitura. |
| conversation_members.removed_at_utc — DATETIME(6) NULL | SYS; revogação de acesso, histórico preservado. |
| chat_messages.message_id, conversation_id — CHAR(36) NOT NULL | SYS; ID e conversa; cursor por horário + ID. |
| chat_messages.sender_team_id, sender_user_id — CHAR(36) NOT NULL | SYS; autor/time e FK de vínculo; API valida participação. |
| chat_messages.message_type_code — VARCHAR(24) NOT NULL | CAT; text/image/location/system; tipo valida payload. Evento system só do backend. |
| chat_messages.body_text — TEXT NULL | EDIT/SYS; texto de usuário/evento; obrigatório para tipo text. |
| chat_messages.asset_id — CHAR(36) NULL | EDIT/SYS; mídia autorizada no storage. |
| chat_messages.latitude, longitude — DECIMAL(9,6) NULL | EDIT/SYS; localização compartilhada explicitamente; par e limites válidos. |
| chat_messages.location_consent_at_utc — DATETIME(6) NULL | SYS; comprova ação de compartilhar localização. |
| chat_messages.created_at_utc — DATETIME(6) NOT NULL | SYS; recebimento/ordenação. |
| chat_messages.edited_at_utc, deleted_at_utc — DATETIME(6) NULL | SYS; edição/ocultação lógica conforme política de retenção. |

### Partidas, avaliações e notificações

| Campo — tipo / nulo | Categoria; finalidade, alteração e validação/origem |
|---|---|
| matches.match_id — CHAR(36) NOT NULL | SYS; UUID da negociação. |
| matches.listing_id — CHAR(36) NULL | SYS; anúncio de origem; nullable deixa extensão futura, fluxo atual requer anúncio. |
| matches.interest_id — CHAR(36) NOT NULL | SYS; interesse aceito; único por partida. |
| matches.host_team_id, opponent_team_id — CHAR(36) NOT NULL | SYS; equipes capturadas do interesse, distintas. |
| matches.status_code — VARCHAR(24) NOT NULL | STATUS; proposed; confirmed após aceite de ambos (hipótese); depois completed/cancelled. |
| matches.host_team_name_snapshot, opponent_team_name_snapshot — VARCHAR(120) NOT NULL | SYS; preserva nomes mesmo que equipe renomeie. |
| matches.sport_code_snapshot — VARCHAR(32) NOT NULL | SYS; código de modalidade acordado, copiado. |
| matches.category_label_snapshot, home_preference_label_snapshot — VARCHAR(60) NOT NULL | SYS; rótulos do acordo preservados. |
| matches.skill_level_label_snapshot — VARCHAR(60) NULL | SYS; cópia opcional do nível. |
| matches.players_per_team_snapshot — TINYINT UNSIGNED NOT NULL | SYS; quantidade acordada, 5–30. |
| matches.starts_at_utc — DATETIME(6) NOT NULL | EDIT/SYS; hora acordada em UTC; mudança só por fluxo de acordo explícito. |
| matches.timezone_name — VARCHAR(64) NOT NULL | SYS; fuso local do acordo. |
| matches.city — VARCHAR(100) NOT NULL; state_code — CHAR(2) NOT NULL; neighborhood — VARCHAR(100) NULL; venue_name — VARCHAR(160) NOT NULL; venue_address — VARCHAR(255) NULL | EDIT/SYS; local acordado copiado; endereço só para participantes; UF controlada. |
| matches.latitude, longitude — DECIMAL(9,6) NULL | SYS; coordenadas acordadas/consentidas, sem seguir mudanças posteriores do anúncio; ambas ou nenhuma. |
| matches.location_consent_at_utc — DATETIME(6) NULL | SYS; consentimento copiado do anúncio; obrigatório quando coordenadas existem. |
| matches.rental_fee_per_team — DECIMAL(10,2) NULL | EDIT/SYS; valor acordado, não negativo. |
| matches.notes_snapshot — TEXT NULL | SYS; observações copiadas para preservar contexto. |
| matches.host_confirmed_at_utc, opponent_confirmed_at_utc — DATETIME(6) NULL | SYS; backend marca aprovação individual autorizada; ambos necessários. |
| matches.confirmed_at_utc — DATETIME(6) NULL | SYS; instante da segunda aprovação. |
| matches.cancelled_by_team_id — CHAR(36) NULL | SYS; equipe participante que cancelou. |
| matches.cancellation_reason — VARCHAR(1000) NULL | EDIT; motivo opcional do responsável. |
| matches.cancelled_at_utc, completed_at_utc — DATETIME(6) NULL | SYS; momento de cancelamento/conclusão validada. |
| matches.created_at_utc, updated_at_utc — DATETIME(6) NOT NULL | SYS; criação/atualização. |
| review_records.review_id, match_id — CHAR(36) NOT NULL | SYS; ID e partida avaliada, apenas completed. |
| review_records.reviewer_team_id, reviewed_team_id — CHAR(36) NOT NULL | SYS; avaliador/adversário, ambos participantes da partida. |
| review_records.created_by_user_id — CHAR(36) NOT NULL | SYS; membro autorizado do time avaliador. |
| review_records.comment_text — TEXT NULL | EDIT; comentário opcional, sujeito a moderação/retenção a definir. |
| review_records.created_at_utc, updated_at_utc — DATETIME(6) NOT NULL | SYS; criação/edição se permitida. |
| review_records.deleted_at_utc — DATETIME(6) NULL | SYS; ocultação lógica por denúncia/exclusão conforme política. |
| review_scores.review_id, criterion_id — CHAR(36), SMALLINT UNSIGNED NOT NULL | SYS/CAT; chave de nota por critério; backend grava conjunto completo atomicamente. |
| review_scores.score — TINYINT UNSIGNED NOT NULL | EDIT; nota 1–5. |
| notifications.notification_id — CHAR(36) NOT NULL | SYS; UUID. |
| notifications.recipient_user_id — CHAR(36) NOT NULL | SYS; backend determina pelo evento/vínculo. |
| notifications.team_id — CHAR(36) NULL | SYS; time relacionado, se houver, deve ser do destinatário. |
| notifications.type_code — VARCHAR(40) NOT NULL | CAT/SYS; tipo de evento criado pelo backend. |
| notifications.title, body_text — VARCHAR(160/1000) NOT NULL | SYS; texto localizado; não inclui dado privado sem autorização. |
| notifications.listing_id, interest_id, conversation_id, match_id — CHAR(36) NULL | SYS; no máximo um alvo tipado. |
| notifications.created_at_utc — DATETIME(6) NOT NULL | SYS; criação do evento. |
| notifications.read_at_utc — DATETIME(6) NULL | SYS; backend marca leitura do titular. |

### Catálogos e campos auxiliares

Em cada linha, CAT controla opções selecionáveis; code é estável, label editável, is_active desativa sem apagar histórico. IDs AUTO_INCREMENT são SYS e datas são SYS.

| Tabela e campos | Tipo / regra |
|---|---|
| account_statuses.status_code, label_pt_br, is_active | VARCHAR(24) PK; VARCHAR(40) NOT NULL; BOOLEAN NOT NULL. STATUS/CAT. |
| team_roles.role_code, label_pt_br, is_active | VARCHAR(24) PK; VARCHAR(40) NOT NULL; BOOLEAN NOT NULL. CAT. |
| brazilian_states.state_code, state_name, is_active | CHAR(2) PK; VARCHAR(40) NOT NULL; BOOLEAN NOT NULL. CAT, sigla oficial. |
| sports.sport_id, code, label_pt_br, sort_order, is_active, created_at_utc, updated_at_utc | SMALLINT UNSIGNED AUTO_INCREMENT PK; VARCHAR(32) ASCII unique; VARCHAR(60); SMALLINT UNSIGNED; BOOLEAN; DATETIME(6) NOT NULL para datas. CAT/SYS. |
| team_categories.category_id, code, label_pt_br, sort_order, is_active, created_at_utc, updated_at_utc | Mesmo padrão de sports, ID category_id. CAT/SYS. |
| skill_levels.skill_level_id, code, label_pt_br, sort_order, is_active, created_at_utc, updated_at_utc | Mesmo padrão de sports, ID skill_level_id. CAT/SYS. |
| home_preferences.home_preference_id, code, label_pt_br, sort_order, is_active, created_at_utc, updated_at_utc | Mesmo padrão de sports, ID home_preference_id. CAT/SYS. |
| review_criteria.criterion_id, code, label_pt_br, sort_order, is_active, created_at_utc, updated_at_utc | Mesmo padrão de sports; código não muda para preservar avaliações. CAT/SYS. |
| listing_statuses, interest_statuses, match_statuses: status_code, label_pt_br, is_active | VARCHAR(24) ASCII PK; VARCHAR(40); BOOLEAN. STATUS/CAT, sem datas. |
| *_status_transitions.from_status_code, to_status_code | VARCHAR(24) ASCII, PK composta e FKs; arestas alteradas em migração controlada, trigger impede aresta ausente. STATUS. |
| message_types.type_code, label_pt_br, is_active | VARCHAR(24) ASCII PK; VARCHAR(40); BOOLEAN. CAT/SYS. |
| notification_types.type_code, label_pt_br, is_active | VARCHAR(40) ASCII PK; VARCHAR(80); BOOLEAN. CAT/SYS. |

| Estado transitório/derivado | Persistência |
|---|---|
| Aba/rota, busca, filtros Todos/Todas, distância escolhida, modal, seleção do mapa, etapa de cadastro, estrelas não enviadas | TRANS; não gravar. Só criar preferências se produto pedir explicitamente. |
| Distância, média/contagem de avaliações, total de jogos, interessados | DER; calcular da origem. Cache futuro precisa de estratégia de invalidação/rebuild. |

## 3. Modelo conceitual, relações e ER

- users N:M teams via team_members; papel/revogação no vínculo. Um usuário pode representar vários times; responsável inicial recebe owner.
- teams 1:N game_listings; anúncio usa catálogos de modalidade/categoria/nível/mando.
- Anúncio 1:N game_interests; vários times podem demonstrar interesse; unique limita um por time/anúncio; self-interest é negado.
- Interesse 0..1 conversation; conversa ligada ao mesmo anúncio e times, com membros e mensagens.
- Interesse aceito 0..1 match; match copia detalhes e nomes do acordo para preservar histórico.
- Partida realizada recebe até duas avaliações direcionais; cada avaliação tem nota por critério.
- Usuário recebe notificações com no máximo um alvo tipado. Mídia usa object storage e guarda somente metadados/chave.

Confirmado no UI/protótipo: anúncio com interessados, chat, ativo/pausado, confirmação/cancelamento, critérios 1–5 e mensagens texto/imagem/localização desenhadas. Nada persiste hoje.

Hipóteses do schema: uma conversa por interesse; interesse não equivale a aceite; dono aceita/recusa; partida nasce de interesse aceito; ambos times confirmam; cada time avalia o adversário uma vez após conclusão. Não há exclusividade automática nem placar. Revisar antes de produção.

~~~mermaid
erDiagram
  USERS ||--o{ TEAM_MEMBERS : pertence
  TEAM_ROLES ||--o{ TEAM_MEMBERS : papel
  TEAMS ||--o{ TEAM_MEMBERS : possui
  USERS ||--o{ TEAMS : cria
  SPORTS ||--o{ TEAMS : modalidade
  TEAM_CATEGORIES ||--o{ TEAMS : categoria
  SKILL_LEVELS o|--o{ TEAMS : nivel
  TEAMS ||--o{ GAME_LISTINGS : publica
  GAME_LISTINGS ||--o{ GAME_INTERESTS : recebe
  TEAMS ||--o{ GAME_INTERESTS : demonstra
  GAME_INTERESTS ||--o| CONVERSATIONS : abre
  CONVERSATIONS ||--o{ CONVERSATION_MEMBERS : inclui
  USERS ||--o{ CONVERSATION_MEMBERS : participa
  CONVERSATIONS ||--o{ CHAT_MESSAGES : contem
  GAME_INTERESTS ||--o| MATCHES : origina
  TEAMS ||--o{ MATCHES : participa
  MATCHES ||--o{ REVIEW_RECORDS : recebe
  TEAMS ||--o{ REVIEW_RECORDS : avalia
  REVIEW_RECORDS ||--|{ REVIEW_SCORES : pontua
  REVIEW_CRITERIA ||--o{ REVIEW_SCORES : criterio
  USERS ||--o{ NOTIFICATIONS : recebe
~~~

## 4–6. SQL, seeds e consultas

schema.sql cria tabelas, tipos, chaves, checks, índices e triggers; suporta MySQL 8.0.16+ (checks ativos). UUID v4 usa CHAR(36) ASCII para contratos multiplataforma. Não há cascade delete de dados de negócio.

seeds.sql inclui apenas catálogos iniciais atualizáveis: 27 UFs, Futebol/Futsal, 5 categorias, 3 níveis, 3 mandos, quatro critérios e estados/tipos auxiliares. Flutter tem 10 UFs no seletor e o protótipo 27; seed inclui 27. Nenhuma conta/time/anúncio/partida fictícia.

examples.sql demonstra filtros/distância calculada, detalhe, interesse+conversa atômicos, conversas/mensagens cursorizadas, aceite/snapshot, confirmação/cancelamento, jogos por status, avaliação e notificações. Placeholders :nome devem ser parâmetros vinculados, não concatenados. Para listas grandes, usar cursor (timestamp, UUID), limite e next_cursor; LIMIT/OFFSET é ilustrativo.

## 7. Transições e operações compostas

| Ciclo | Transições iniciais | Proteção |
|---|---|---|
| Anúncio | active→paused/closed/expired; paused→active/closed/expired. | Grafo + trigger; dono/gestor autorizado. Expiração depende de regra/job. |
| Interesse | pending→accepted/declined/withdrawn. | Grafo + trigger; índice único; trigger nega self-interest. |
| Conversa | Criada para interesse pending/accepted; arquivar não muda interesse. | FK composta + trigger; API verifica membro em toda operação. |
| Partida | proposed→confirmed/cancelled; confirmed→completed/cancelled. | Trigger requer ambos aceites. API bloqueia linha FOR UPDATE, checa papel, atualiza e notifica numa transação. |
| Avaliação | Após completed, por um participante ao adversário. | Trigger + FKs; API valida quatro notas e insere transacionalmente. SQL não força contagem de linhas diferida. |

Operações usam lock, validação do estado, gravações e outbox/notificações antes do COMMIT; falha causa ROLLBACK. Trigger protege grafo, mas não substitui autorização. Credencial SQL do backend nunca vai ao app. Notificação externa futura recomenda outbox/fila transacional.

## 8. Índices

- ix_listing_discovery: anúncios ativos filtrados por modalidade/categoria/nível/data/UF/cidade.
- ix_listing_team_status: “Meus anúncios” por time/status/data.
- Índices de interesse por time/status/data: recebidos e enviados.
- Índices de partidas por participante/status/data: “Meus jogos”.
- ix_messages_conversation_time: timeline e cursor.
- Índices de conversation_members/equipe: inbox e autorização.
- ix_notifications_unread: não lidas por usuário/data.
- ix_review_team_date: perfil e agregações.
- ix_teams_search: filtro exato cidade/UF/modalidade/categoria; busca textual ampla pode exigir FULLTEXT após medir.
- Coordenadas opcionais; ST_Distance_Sphere calcula distância. Sem coordenadas, busca por cidade continua; raio não. Índice espacial depende de volume medido.

## 9. Segurança e LGPD

- API obtém identidade da sessão validada e verifica vínculo/role ativo por operação. user_id/team_id do app não são prova de autorização.
- Filtrar conversa/mensagem por membership. UUID não substitui autorização; FKs garantem integridade, não sigilo.
- Contato, endereço, coordenadas e anexos têm acesso mínimo; telefone público FALSE por padrão. Coordenadas exigem consentimento/finalidade; definir precisão e retenção.
- Senhas: hash Argon2id atualizado apenas no backend; recuperação com token de uso único. user_sessions guarda somente hash de refresh token. Com provedor, guardar provider_code/subject, validar token no servidor e não salvar senha/token do provedor na tabela.
- Storage privado, URL assinada curta, validação MIME/tamanho/autorização/antimalware; MySQL só metadata.
- Exclusão revoga sessões/acessos/consentimentos, anonimiza quando possível, preserva histórico sem identificação desnecessária e apaga objetos conforme política. Retenção de chat/avaliações/denúncias depende de produto/jurídico.
- Métricas são derivadas. Cache precisa de invalidação/rebuild a partir da origem.

## 10. API Android/iOS

Ambos consomem a mesma API HTTPS versionada (/v1), sem driver MySQL nos clientes. IDs UUID strings; datas ISO 8601 UTC com timezone_name; dinheiro decimal string ou centavos inteiros conforme contrato único. Catálogos entregam code/label/sort_order. Usar autorização de servidor, paginação cursor, limites, rate limit e idempotency keys em publicar/interessar/confirmar/cancelar.

Erro consistente (code, message, field_errors, request_id): 401 sessão, 403 papel, 404 recurso inacessível/não encontrado, 409 conflito, 422 validação, 429 limite. Não revelar dado privado de outro time.

## 11. Decisões pendentes e hipóteses

1. **Confirmação bilateral:** protótipo não mostra dois aceites. Hipótese: ambos confirmam; alternativa é só publicador.
2. **Concorrência/exclusividade:** vários interesses permitidos; desconhecido se aceitar um fecha anúncio. Hipótese: várias partidas podem decorrer; decidir limite/efeito nos demais.
3. **Papéis:** app mostra um responsável; multiusuário é extensão. Definir se membros conversam e quem publica/confirma.
4. **Status/expiração:** UI mostra ativo/pausado; expiração não funciona. Aguardando/Negociando são agregações, não status duplicado. Definir validade.
5. **Localização/contato:** definir visibilidade de endereço, precisão, consentimento e retenção. Contato fica privado inicialmente.
6. **Avaliações:** edição, prazo, moderação/resposta e bilateralidade indefinidos. Hipótese: uma por direção após realização, quatro notas, comentário opcional.
7. **Auth:** escolher backend/provedor e regras de verificação/recuperação/retenção.
8. **Moeda/fuso/território:** hipótese BRL, UFs e timezone IANA; decidir expansão internacional.
9. **Anexos/placar:** imagem/localização só no protótipo; placares estáticos. Adicionar placar apenas com fluxo aprovado.
10. **Form incompleto:** bairro/local/taxa/observações/nível aparecem mas não persistem no Flutter; responsável/contato são demonstrativos. Rever telas antes da API.

## 12. Checklist verificável

- [ ] Em MySQL 8.0.16+ vazio, executar schema.sql e confirmar tabelas/FKs/checks/índices/triggers.
- [ ] Executar seeds.sql e confirmar apenas catálogos, sem dados fictícios de negócio.
- [ ] Testar rejeição de FK inválida, jogadores 4/31, nota 0/6, taxa negativa e coordenada incompleta.
- [ ] Testar self-interest, duplicidade, conversa inconsistente e review antes de completed.
- [ ] Testar saltos de status e confirmação sem os dois timestamps.
- [ ] Testar rollback, idempotência e interesses concorrentes em duas sessões.
- [ ] Testar acesso cruzado a anúncios/chat/mensagens/reviews/notificações com contas distintas.
- [ ] Auditar respostas para dados privados; URL do storage expira.
- [ ] Revisar exclusão/anonimização/consentimento/retenção e medir EXPLAIN ANALYZE em volume representativo.
- [ ] Confirmar Android/iOS na mesma API HTTPS, UUID, datas UTC/fuso e paginação.

Checklist é plano de verificação; SQL ainda não foi executado contra uma instância MySQL neste repositório.
