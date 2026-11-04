# PROJETO JOGA CONTRA — ETAPA 2: CRIAÇÃO DO NOVO BANCO MYSQL 8.4 LTS

> Antes de enviar este prompt, responda às decisões da seção 11 (ou aceite os padrões indicados).

Atue como arquiteto de dados e desenvolvedor sênior em MySQL 8.4 LTS, Node.js/TypeScript (Express 5) e Flutter.

O aplicativo **Joga Contra** conecta times que procuram adversários para partidas de futebol society/sintético e futebol de quadra. A etapa 1 auditou o repositório e refatorou o app Flutter para dados dinâmicos. O resultado está em:

- `docs/AUDITORIA_DADOS_DINAMICOS.md` — inventário, entidades, relacionamentos, contrato da API e decisões.
- `lib/models/*.dart` — modelos e o formato JSON que o app já espera.
- `lib/repositories/api/api_repositories.dart` — rotas que o app já chama.
- `lib/repositories/demo/demo_repositories.dart` — simulação em memória das regras de negócio (referência de comportamento).
- `backend/` — API Express 5 existente (reaproveitar infraestrutura; consultas serão reescritas).
- `database/` — banco **antigo** (inglês). **Não alterar, não apagar, não executar.**

Leia esses arquivos antes de começar. Não invente estruturas incompatíveis com eles.

## 1. Objetivo desta etapa

Criar o script SQL completo do novo banco, em português brasileiro, compatível com o app e com a API que será adaptada depois. **Não executar o script** em nenhuma instância e não rodar migrações. Entregar os arquivos para eu revisar e executar manualmente no MySQL Workbench.

Arquivos a criar (sem modificar `database/`):

```
database_v2/
├─ 01_schema.sql            -- banco, tabelas, chaves, índices, CHECKs
├─ 02_triggers.sql          -- triggers e procedimentos
├─ 03_dados_referencia.sql  -- somente cadastros de referência
├─ 04_views.sql             -- agregados usados pela API
├─ 05_verificacao.sql       -- consultas de verificação (somente SELECT)
└─ README.md                -- ordem de execução, decisões e mapeamento coluna → campo JSON
```

## 2. Convenções obrigatórias

- MySQL **8.4 LTS**, InnoDB, `CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci`.
- Nome do banco: **`joga_contra_v2`** (não sobrescrever `joga_contra`). Usar `CREATE DATABASE IF NOT EXISTS`; **não** usar `DROP DATABASE` nem `DROP TABLE`.
- Tabelas e colunas em português, **sem acentos, sem espaços, `snake_case`**.
- Chaves de negócio: `CHAR(36) CHARACTER SET ascii COLLATE ascii_bin` (UUID gerado pela API). O app trata IDs como `String`.
- Cadastros de referência: `TINYINT UNSIGNED AUTO_INCREMENT`, com `codigo` estável (ascii) usado pelo app em regras e estilos.
- Datas/horas em **UTC**: `DATETIME(3)`; a API executa `SET time_zone = '+00:00'`.
- Padrão de auditoria: `data_criacao DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)` e `data_atualizacao ... ON UPDATE CURRENT_TIMESTAMP(3)`.
- Exclusão lógica (`data_exclusao` / `data_arquivamento`) em vez de `DELETE` para usuários, times e anúncios.
- Status como `VARCHAR(20)` com `CHECK` (não são administráveis); classificações como tabelas de referência (são administráveis).
- Nomear restrições: `pk_`, `fk_<tabela>_<referencia>`, `uq_`, `ck_`, `ix_`, `tg_`, `sp_`, `vw_`.
- Comentar cada tabela (`COMMENT`) em português.

## 3. Tabelas de referência e dados iniciais

| Tabela | PK | Colunas | Dados iniciais (`codigo` → `nome`, `ordem`) |
|---|---|---|---|
| `estados` | `sigla CHAR(2)` | `nome VARCHAR(40)`, `ativo` | As 27 UFs |
| `modalidades` | `id_modalidade` | `codigo`, `nome VARCHAR(60)`, `ordem`, `ativo`, datas | `society` → Futebol society/sintético (10); `quadra` → Futebol de quadra (20) |
| `categorias_etarias` | `id_categoria_etaria` | idem + `idade_maxima TINYINT UNSIGNED NULL` | `sub_15` → Sub-15 (10, 15); `sub_17` → Sub-17 (20, 17); `sub_19` → Sub-19 (30, 19); `livre` → Livre (40, NULL) |
| `niveis_tecnicos` | `id_nivel_tecnico` | idem | `iniciante` → Iniciante (10); `intermediario` → Intermediário (20); `avancado` → Avançado (30) |
| `mandos_campo` | `id_mando_campo` | idem | `casa` → Jogo em casa (10); `fora` → Jogo fora (20); `indiferente` → Indiferente (30) |
| `criterios_avaliacao` | `id_criterio` | idem | `pontualidade` → Pontualidade (10); `organizacao` → Organização (20); `respeito` → Respeito (30); `estrutura_local` → Estrutura do local (40) |

Os valores antigos (`Futebol`, `Futsal`, `Sub-20`, `Veterano`, `Recreativo`) **não** devem existir. Os dados iniciais usam `INSERT ... ON DUPLICATE KEY UPDATE` pelo `codigo` (idempotente). **Nenhum** usuário, time, anúncio, partida ou mensagem fictícia no script.

## 4. Tabelas de negócio

Use exatamente estes nomes e colunas (tipos sugeridos; ajuste apenas com justificativa no README).

### 4.1 `usuarios` (capitães; únicos usuários com conta)
`id_usuario` PK · `nome VARCHAR(120)` NN · `email VARCHAR(254)` NN UNIQUE · `senha_hash VARCHAR(255)` NN · `telefone VARCHAR(20)` · `url_foto VARCHAR(500)` · `cidade VARCHAR(100)` · `sigla_estado` FK `estados` · `status_conta VARCHAR(20)` NN DEFAULT `'ativa'` CHECK (`ativa`,`suspensa`,`excluida`) · `email_verificado_em` · `data_criacao` · `data_atualizacao` · `data_exclusao`.
CHECKs: nome e e-mail não vazios; `senha_hash` com pelo menos 50 caracteres.

### 4.2 `tokens_recuperacao_senha`
`id_token` PK · `id_usuario` FK · `token_hash BINARY(32)` UNIQUE · `expira_em` NN · `usado_em` · `data_criacao`. CHECK `expira_em > data_criacao`. Índice (`id_usuario`, `expira_em`).

### 4.3 `times`
`id_time` PK · `id_capitao` FK `usuarios` NN **UNIQUE** · `nome VARCHAR(120)` NN · `sigla VARCHAR(4)` · `url_escudo VARCHAR(500)` · `cidade VARCHAR(100)` NN · `sigla_estado` FK NN · `bairro VARCHAR(100)` · `quantidade_jogadores TINYINT UNSIGNED` NN CHECK 5..60 · `id_categoria_etaria` FK NN · `id_nivel_tecnico` FK · `descricao VARCHAR(2000)` · `ano_fundacao SMALLINT UNSIGNED` CHECK ≥ 1900 · `telefone_contato VARCHAR(20)` · `verificado BOOLEAN` NN DEFAULT FALSE · `data_criacao` · `data_atualizacao` · `data_arquivamento`.
Índice de busca: (`sigla_estado`, `cidade`, `id_categoria_etaria`, `id_nivel_tecnico`).
Regras: cada time tem **um único capitão**; integrantes **não** têm cadastro; **não existe** tabela de membros nem papéis/permissões.

### 4.4 `times_modalidades`
`id_time` FK + `id_modalidade` FK, PK composta. Um time pratica uma ou mais modalidades.

### 4.5 `anuncios_partidas`
`id_anuncio` PK · `id_time` FK NN · `id_modalidade` FK NN · `id_categoria_etaria` FK NN · `id_nivel_tecnico` FK · `id_mando_campo` FK · `quantidade_jogadores TINYINT UNSIGNED` NN CHECK 5..30 (por equipe) · `data_hora_inicio` NN · `cidade` NN · `sigla_estado` FK NN · `bairro VARCHAR(100)` · `nome_local VARCHAR(160)` NN · `endereco VARCHAR(255)` · `latitude DECIMAL(9,6)` · `longitude DECIMAL(9,6)` · `valor_aluguel_por_time DECIMAL(10,2)` CHECK ≥ 0 · `descricao VARCHAR(1000)` · `status VARCHAR(20)` NN DEFAULT `'ativo'` CHECK (`ativo`,`pausado`,`encerrado`,`expirado`) · `data_criacao` · `data_atualizacao` · `data_exclusao`.
CHECK latitude/longitude em par e dentro dos limites. `UNIQUE (id_anuncio, id_time)` para a FK composta das solicitações.
Índices: descoberta (`status`, `data_hora_inicio`, `sigla_estado`, `cidade`, `id_modalidade`, `id_categoria_etaria`, `id_nivel_tecnico`); por time (`id_time`, `status`, `data_hora_inicio`).

### 4.6 `solicitacoes_confronto`
`id_solicitacao` PK · `id_anuncio` NN · `id_time_anunciante` NN · `id_time_solicitante` FK `times` NN · `status VARCHAR(20)` NN DEFAULT `'pendente'` CHECK (`pendente`,`confirmada`,`recusada`,`cancelada`,`encerrada`) · `mensagem_inicial VARCHAR(1000)` · `confirmado_anunciante_em` · `confirmado_solicitante_em` · `data_resposta` · `motivo_encerramento VARCHAR(255)` · `data_criacao` (= data da solicitação) · `data_atualizacao`.
- FK composta (`id_anuncio`, `id_time_anunciante`) → `anuncios_partidas(id_anuncio, id_time)`.
- CHECK `id_time_solicitante <> id_time_anunciante`.
- CHECK: `status = 'confirmada'` exige as duas datas de confirmação.
- No máximo **uma pendente** por (`id_anuncio`, `id_time_solicitante`): coluna gerada `chave_pendente = IF(status = 'pendente', id_time_solicitante, NULL)` + `UNIQUE (id_anuncio, chave_pendente)`.
- Índices: (`id_anuncio`, `status`), (`id_time_solicitante`, `status`), (`id_time_anunciante`, `status`).

### 4.7 `mensagens`
`id_mensagem` PK · `id_solicitacao` FK NN · `id_time_remetente` FK NN · `id_usuario_remetente` FK NN · `texto VARCHAR(1000)` NN (não vazio) · `data_envio` NN DEFAULT agora · `data_leitura` (lida pelo outro time). Índice (`id_solicitacao`, `data_envio`).

### 4.8 `partidas`
`id_partida` PK · `id_solicitacao` FK NN UNIQUE · `id_anuncio` FK NN UNIQUE · `id_time_anunciante` FK NN · `id_time_adversario` FK NN · `id_modalidade` FK NN · `quantidade_jogadores` NN · `data_hora_inicio` NN · `nome_local` NN · `endereco` · `cidade` NN · `sigla_estado` FK NN · `latitude` · `longitude` · `valor_aluguel_por_time` · `status VARCHAR(20)` NN DEFAULT `'confirmada'` CHECK (`confirmada`,`realizada`,`cancelada`) · `gols_anunciante TINYINT UNSIGNED` · `gols_adversario TINYINT UNSIGNED` · `id_time_cancelou` FK · `motivo_cancelamento VARCHAR(500)` · `data_cancelamento` · `data_realizacao` · `data_criacao` · `data_atualizacao`.
- Os dados do local/data são **cópia** do anúncio no momento da confirmação; edições no anúncio não alteram a partida.
- CHECKs: times diferentes; `cancelada` exige `id_time_cancelou` e `data_cancelamento`; `realizada` exige `data_realizacao`; gols só ambos nulos ou ambos preenchidos.
- Índices: (`id_time_anunciante`, `status`, `data_hora_inicio`), (`id_time_adversario`, `status`, `data_hora_inicio`).

### 4.9 `avaliacoes` e `notas_avaliacao`
`avaliacoes`: `id_avaliacao` PK · `id_partida` FK NN · `id_time_avaliador` FK NN · `id_time_avaliado` FK NN · `comentario VARCHAR(1000)` · `data_criacao`. `UNIQUE (id_partida, id_time_avaliador)`; CHECK avaliador ≠ avaliado; índice (`id_time_avaliado`, `data_criacao`).
`notas_avaliacao`: `id_avaliacao` FK + `id_criterio` FK (PK composta) · `nota TINYINT UNSIGNED` CHECK 1..5.

### 4.10 `notificacoes`
`id_notificacao` PK · `id_usuario_destinatario` FK NN · `tipo VARCHAR(40)` NN CHECK (`solicitacao_recebida`, `mensagem_recebida`, `partida_confirmada`, `partida_cancelada`, `solicitacao_encerrada`, `solicitacao_recusada`, `anuncio_expirando`, `avaliacao_pendente`) · `titulo VARCHAR(160)` NN · `mensagem VARCHAR(500)` NN · `id_anuncio` FK · `id_solicitacao` FK · `id_partida` FK · `data_leitura` · `data_criacao`. CHECK no máximo uma referência preenchida. Índice (`id_usuario_destinatario`, `data_leitura`, `data_criacao`).

## 5. Regras de negócio que o banco deve garantir

1. Anúncio novo nasce `ativo`. Transições permitidas: `ativo↔pausado`; `ativo|pausado → encerrado|expirado`. `encerrado` e `expirado` são finais.
2. Solicitação só pode ser criada para anúncio `ativo`, sem `data_exclusao`, com `data_hora_inicio` futura, e de time diferente do anunciante. A trigger preenche/valida `id_time_anunciante` a partir do anúncio.
3. Vários times podem solicitar o mesmo anúncio.
4. Solicitação nasce `pendente`. Transições: `pendente → confirmada|recusada|cancelada|encerrada`. As demais são finais.
5. **A confirmação depende da concordância das duas equipes**: cada capitão registra sua confirmação (`confirmado_anunciante_em`, `confirmado_solicitante_em`). Quando as duas existem, na **mesma transação**:
   - a solicitação vira `confirmada` (`data_resposta = agora`);
   - cria-se a `partida` copiando os dados do anúncio;
   - o anúncio vira `encerrado` e deixa de aceitar solicitações;
   - **todas as outras solicitações pendentes** do anúncio viram `encerrada` com `motivo_encerramento`;
   - é criada uma notificação `solicitacao_encerrada` para o **capitão de cada time** cuja solicitação foi encerrada, e `partida_confirmada` para os dois capitães envolvidos.
   Implementar como procedimento **`sp_confirmar_solicitacao(p_id_solicitacao, p_id_usuario)`**, com `SELECT ... FOR UPDATE` no anúncio e nas solicitações para evitar duas confirmações simultâneas no mesmo anúncio, que valida que `p_id_usuario` é capitão de um dos dois times, registra o lado correto e retorna a solicitação (e o `id_partida`, se criado). Erros de regra via `SIGNAL SQLSTATE '45000'` com mensagens em português (a API já converte `ER_SIGNAL_EXCEPTION` em HTTP 409).
6. Mensagens só podem ser enviadas por um dos dois times da solicitação, por seu capitão (trigger).
7. Partida: transições `confirmada → realizada|cancelada`. Após `confirmada`, dados copiados (data, local, times, modalidade) são imutáveis (trigger).
8. Avaliação só para partida `realizada`, por um dos dois times, avaliando o outro (trigger).
9. Uma partida por anúncio e por solicitação (UNIQUE).
10. Usuário com `status_conta <> 'ativa'` não pode criar anúncio nem solicitação (trigger ou verificação no procedimento; explique a escolha).

Inclua também `sp_cancelar_partida(p_id_partida, p_id_usuario, p_motivo)` (notifica o outro capitão) e, se aprovado na seção 11, um `EVENT` que marca anúncios vencidos como `expirado` (deixe o `EVENT` comentado e documente que exige `event_scheduler=ON`).

## 6. Views para a API (`04_views.sql`)

- `vw_estatisticas_times`: `id_time`, `total_partidas_realizadas`, `media_avaliacao` (média das notas de todas as avaliações recebidas, 1 casa), `total_avaliacoes`.
- `vw_resumo_solicitacoes`: por solicitação, `ultima_mensagem`, `data_ultima_mensagem` e mensagens não lidas por time destinatário.
- `vw_anuncios_disponiveis`: anúncios `ativo`, não excluídos, futuros, com nomes das referências, dados resumidos do time e `total_solicitacoes` pendentes.

Esses agregados alimentam os campos calculados do app (`totalPartidasRealizadas`, `mediaAvaliacao`, `totalAvaliacoes`, `totalSolicitacoes`, `ultimaMensagem`, `mensagensNaoLidas`). Não criar colunas desnormalizadas para eles.

## 7. Compatibilidade com o app (obrigatório)

O README do banco deve trazer a tabela **coluna → campo JSON** que a API devolverá, em camelCase português, exatamente como os modelos Flutter leem. Exemplos já usados pelo app:

| Coluna | JSON |
|---|---|
| `anuncios_partidas.id_anuncio` | `idAnuncio` |
| `anuncios_partidas.data_hora_inicio` (UTC) | `dataHoraInicio` (ISO 8601 com `Z`) |
| `anuncios_partidas.nome_local` | `nomeLocal` |
| `anuncios_partidas.valor_aluguel_por_time` | `valorAluguelPorTime` (número) |
| referência (`id_*`, `codigo`, `nome`, `ordem`) | objeto `{id, codigo, nome, ordem}` em `modalidade`, `categoriaEtaria`, `nivelTecnico`, `mandoCampo` |
| `times.id_time`, `times.id_capitao` | `idTime`, `idCapitao` |
| `solicitacoes_confronto.confirmado_anunciante_em IS NOT NULL` | `confirmadoAnunciante` (bool) |
| `solicitacoes_confronto.data_criacao` | `dataSolicitacao` |
| `partidas.gols_anunciante` | `golsAnunciante` |
| `notificacoes.data_leitura IS NOT NULL` | `lida` (bool) |
| `estados.sigla` | `siglaEstado` |

Confira cada modelo em `lib/models/` e liste qualquer campo do app sem coluna correspondente (ou vice-versa).

## 8. Índices e desempenho

Justifique cada índice pela consulta que atende (busca de anúncios com filtros, "meus anúncios", "minhas solicitações", conversas, próxima partida, histórico, notificações não lidas, estatísticas do time). Não criar índices redundantes com o prefixo de outro índice ou de uma FK.

## 9. Segurança e LGPD

- Nunca armazenar senha ou token em texto: só `senha_hash` e `token_hash`.
- Não incluir credenciais no script. Sugerir no README um usuário de aplicação com privilégios mínimos (`SELECT, INSERT, UPDATE, EXECUTE` em `joga_contra_v2.*`, sem `DROP`/`ALTER`), com senha como placeholder.
- Telefone e e-mail são dados pessoais: indicar quais colunas a API nunca deve expor publicamente (ex.: `usuarios.email`, `usuarios.telefone`).
- Exclusão lógica + orientação de anonimização para pedidos de exclusão.

## 10. Verificação (`05_verificacao.sql`)

Apenas consultas `SELECT` que confirmem: tabelas e colunas esperadas (via `information_schema`), contagem dos dados de referência (2 modalidades, 4 categorias, 3 níveis, 3 mandos, 4 critérios, 27 UFs), FKs, triggers, procedimentos e views existentes. Inclua em comentário um roteiro de teste manual (com UUIDs fictícios e e-mails `@example.com`) para: auto-solicitação bloqueada, solicitação duplicada pendente bloqueada, confirmação de um lado só, confirmação dos dois lados encerrando as demais e gerando notificações, solicitação em anúncio encerrado bloqueada, avaliação antes de `realizada` bloqueada, nota 0/6 bloqueada. O roteiro deve ser executado por mim, numa base de teste, e terminar com `ROLLBACK`.

## 11. Decisões a confirmar antes de gerar (padrões indicados)

1. Um time por capitão (`UNIQUE id_capitao`)? **Padrão: sim.**
2. "Vagas disponíveis" no anúncio: **padrão: não incluir** (não existe no app nem no protótipo). Se quiser, defina o significado.
3. Manter mando de campo, taxa de aluguel, bairro e endereço? **Padrão: sim, opcionais.**
4. Faixas: time 5–60 jogadores; anúncio 5–30 por equipe. **Padrão: essas.** (O formulário Flutter hoje aceita 2–30 e será ajustado.)
5. Registrar placar? **Padrão: colunas opcionais, preenchidas pelo capitão anunciante após a partida.**
6. Partida cancelada reabre o anúncio? **Padrão: não.**
7. Partida vira `realizada`: **padrão: API marca automaticamente 3 h após `data_hora_inicio`** (sem `EVENT` no banco).
8. Expirar anúncios vencidos: **padrão: `EVENT` comentado + job na API.**
9. Login com Google: **padrão: fora do escopo** (não criar tabela de identidades externas).

## 12. Entrega esperada

1. Os arquivos da seção 1, completos e comentados.
2. README com: ordem de execução, pré-requisitos (MySQL 8.4, `log_bin_trust_function_creators` se necessário para triggers/procedimentos), diagrama textual de relacionamentos, mapeamento coluna → JSON, decisões tomadas e diferenças em relação a `database/schema.sql`.
3. Lista das alterações necessárias na API Express (rotas da seção 8 da auditoria, remoção de `team_members`/papéis, cadastro de usuário + time em transação, uso de `sp_confirmar_solicitacao`), **sem implementá-las ainda**.
4. Lista dos ajustes pequenos necessários no Flutter, se houver.

**IMPORTANTE:** não execute o script, não rode migrações, não altere nem apague `database/` e não toque no banco `joga_contra` atual. Gere os arquivos e aguarde minha revisão antes da etapa de adaptação da API.
