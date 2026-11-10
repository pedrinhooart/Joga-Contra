-- =============================================================================
-- Joga Contra — banco joga_contra_v2 — MySQL 8.4 LTS
-- 01_esquema.sql: banco, tabelas, chaves, índices e restrições de verificação.
--
-- Execute em uma instância MySQL 8.4 sem o banco joga_contra_v2 (ou com ele vazio).
-- O script NÃO apaga nem sobrescreve nada: não há DROP. Se alguma tabela já
-- existir, o CREATE TABLE falha e a execução para (comportamento intencional).
--
-- Convenções de nomes (todos em português, minúsculas, snake_case, sem acentos):
--   ce_<tabela>_<referencia>   chave estrangeira
--   un_<tabela>_<colunas>      restrição de unicidade
--   vr_<tabela>_<regra>        restrição de verificação (CHECK)
--   ind_<tabela>_<finalidade>  índice
--   A chave primária de toda tabela se chama PRIMARY (imposição do MySQL).
--
-- Datas e horas: DATETIME(3) sempre em UTC. A conexão da API deve executar
-- SET time_zone = '+00:00' (os valores padrão usam o fuso da sessão).
-- Identificadores de negócio: UUID em texto (CHAR(36), minúsculo), gerado pela API.
-- =============================================================================

SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE DATABASE IF NOT EXISTS joga_contra_v2
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE joga_contra_v2;

-- -----------------------------------------------------------------------------
-- 1. Cadastros de referência (administráveis; carregados por GET /referencias)
-- -----------------------------------------------------------------------------

CREATE TABLE estados (
  sigla CHAR(2) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  nome  VARCHAR(40) NOT NULL,
  ativo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (sigla),
  CONSTRAINT un_estados_nome UNIQUE (nome),
  CONSTRAINT vr_estados_sigla CHECK (REGEXP_LIKE(sigla, '^[A-Z]{2}$', 'c'))
) ENGINE = InnoDB
  COMMENT = 'Unidades federativas do Brasil.';

CREATE TABLE modalidades (
  id_modalidade    TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  codigo           VARCHAR(30) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  nome             VARCHAR(60) NOT NULL,
  ordem            SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  ativo            BOOLEAN NOT NULL DEFAULT TRUE,
  data_criacao     DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  data_atualizacao DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id_modalidade),
  CONSTRAINT un_modalidades_codigo UNIQUE (codigo),
  CONSTRAINT vr_modalidades_codigo CHECK (REGEXP_LIKE(codigo, '^[a-z0-9_]+$', 'c')),
  CONSTRAINT vr_modalidades_nome CHECK (CHAR_LENGTH(TRIM(nome)) > 0)
) ENGINE = InnoDB
  COMMENT = 'Modalidades: futebol society/sintético e futebol de quadra.';

CREATE TABLE categorias_etarias (
  id_categoria_etaria TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  codigo              VARCHAR(30) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  nome                VARCHAR(60) NOT NULL,
  idade_maxima        TINYINT UNSIGNED NULL COMMENT 'Idade máxima (Sub-N). NULL = Livre.',
  ordem               SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  ativo               BOOLEAN NOT NULL DEFAULT TRUE,
  data_criacao        DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  data_atualizacao    DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id_categoria_etaria),
  CONSTRAINT un_categorias_etarias_codigo UNIQUE (codigo),
  CONSTRAINT vr_categorias_etarias_codigo CHECK (REGEXP_LIKE(codigo, '^[a-z0-9_]+$', 'c')),
  CONSTRAINT vr_categorias_etarias_nome CHECK (CHAR_LENGTH(TRIM(nome)) > 0),
  CONSTRAINT vr_categorias_etarias_idade CHECK (idade_maxima IS NULL OR idade_maxima BETWEEN 5 AND 99)
) ENGINE = InnoDB
  COMMENT = 'Categorias etárias: Sub-15, Sub-17, Sub-19, Livre.';

CREATE TABLE niveis_tecnicos (
  id_nivel_tecnico TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  codigo           VARCHAR(30) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  nome             VARCHAR(60) NOT NULL,
  ordem            SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  ativo            BOOLEAN NOT NULL DEFAULT TRUE,
  data_criacao     DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  data_atualizacao DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id_nivel_tecnico),
  CONSTRAINT un_niveis_tecnicos_codigo UNIQUE (codigo),
  CONSTRAINT vr_niveis_tecnicos_codigo CHECK (REGEXP_LIKE(codigo, '^[a-z0-9_]+$', 'c')),
  CONSTRAINT vr_niveis_tecnicos_nome CHECK (CHAR_LENGTH(TRIM(nome)) > 0)
) ENGINE = InnoDB
  COMMENT = 'Níveis técnicos: Iniciante, Intermediário, Avançado.';

CREATE TABLE mandos_campo (
  id_mando_campo   TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  codigo           VARCHAR(30) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  nome             VARCHAR(60) NOT NULL,
  ordem            SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  ativo            BOOLEAN NOT NULL DEFAULT TRUE,
  data_criacao     DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  data_atualizacao DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id_mando_campo),
  CONSTRAINT un_mandos_campo_codigo UNIQUE (codigo),
  CONSTRAINT vr_mandos_campo_codigo CHECK (REGEXP_LIKE(codigo, '^[a-z0-9_]+$', 'c')),
  CONSTRAINT vr_mandos_campo_nome CHECK (CHAR_LENGTH(TRIM(nome)) > 0)
) ENGINE = InnoDB
  COMMENT = 'Mando de campo do anúncio: em casa, fora, indiferente.';

CREATE TABLE criterios_avaliacao (
  id_criterio      TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  codigo           VARCHAR(30) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  nome             VARCHAR(60) NOT NULL,
  ordem            SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  ativo            BOOLEAN NOT NULL DEFAULT TRUE,
  data_criacao     DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  data_atualizacao DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id_criterio),
  CONSTRAINT un_criterios_avaliacao_codigo UNIQUE (codigo),
  CONSTRAINT vr_criterios_avaliacao_codigo CHECK (REGEXP_LIKE(codigo, '^[a-z0-9_]+$', 'c')),
  CONSTRAINT vr_criterios_avaliacao_nome CHECK (CHAR_LENGTH(TRIM(nome)) > 0)
) ENGINE = InnoDB
  COMMENT = 'Critérios da avaliação pós-partida (nota de 1 a 5 em cada).';

-- -----------------------------------------------------------------------------
-- 2. Usuários (somente capitães possuem conta)
-- -----------------------------------------------------------------------------

CREATE TABLE usuarios (
  id_usuario             CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  nome                   VARCHAR(120) NOT NULL,
  email                  VARCHAR(254) NOT NULL COMMENT 'Dado pessoal: nunca expor publicamente.',
  hash_senha             VARCHAR(255) CHARACTER SET ascii COLLATE ascii_bin NOT NULL
                           COMMENT 'Hash bcrypt/argon2 gerado pela API. Nunca a senha.',
  telefone               VARCHAR(20) NULL COMMENT 'Dado pessoal: nunca expor publicamente.',
  url_foto               VARCHAR(500) NULL,
  cidade                 VARCHAR(100) NULL,
  sigla_estado           CHAR(2) CHARACTER SET ascii COLLATE ascii_bin NULL,
  status_conta           VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'ativa',
  data_verificacao_email DATETIME(3) NULL,
  data_criacao           DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  data_atualizacao       DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  data_exclusao          DATETIME(3) NULL COMMENT 'Exclusão lógica; dados pessoais devem ser anonimizados.',
  PRIMARY KEY (id_usuario),
  CONSTRAINT un_usuarios_email UNIQUE (email),
  CONSTRAINT ce_usuarios_estados FOREIGN KEY (sigla_estado) REFERENCES estados (sigla),
  CONSTRAINT vr_usuarios_id CHECK (REGEXP_LIKE(id_usuario, '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', 'c')),
  CONSTRAINT vr_usuarios_nome CHECK (CHAR_LENGTH(TRIM(nome)) > 0),
  CONSTRAINT vr_usuarios_email CHECK (email LIKE '_%@_%._%' AND email = TRIM(email)),
  CONSTRAINT vr_usuarios_hash_senha CHECK (CHAR_LENGTH(hash_senha) >= 50),
  CONSTRAINT vr_usuarios_status_conta CHECK (status_conta IN ('ativa', 'suspensa', 'excluida')),
  CONSTRAINT vr_usuarios_exclusao CHECK ((status_conta = 'excluida') = (data_exclusao IS NOT NULL))
) ENGINE = InnoDB
  COMMENT = 'Capitães. Os integrantes dos times não possuem cadastro.';

CREATE TABLE codigos_recuperacao_senha (
  id_codigo       CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_usuario      CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  hash_codigo     BINARY(32) NOT NULL COMMENT 'SHA-256 do código enviado por e-mail. Nunca o código.',
  data_expiracao  DATETIME(3) NOT NULL,
  data_uso        DATETIME(3) NULL,
  data_criacao    DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id_codigo),
  CONSTRAINT un_codigos_recuperacao_senha_hash UNIQUE (hash_codigo),
  CONSTRAINT ce_codigos_recuperacao_senha_usuarios FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario),
  CONSTRAINT vr_codigos_recuperacao_senha_id CHECK (REGEXP_LIKE(id_codigo, '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', 'c')),
  CONSTRAINT vr_codigos_recuperacao_senha_validade CHECK (data_expiracao > data_criacao),
  CONSTRAINT vr_codigos_recuperacao_senha_uso CHECK (data_uso IS NULL OR data_uso >= data_criacao),
  INDEX ind_codigos_recuperacao_senha_usuario (id_usuario, data_expiracao)
) ENGINE = InnoDB
  COMMENT = 'Códigos de uso único do fluxo "Recuperar acesso".';

-- -----------------------------------------------------------------------------
-- 3. Times
-- -----------------------------------------------------------------------------

CREATE TABLE times (
  id_time              CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_capitao           CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  nome                 VARCHAR(120) NOT NULL,
  sigla                VARCHAR(4) NULL COMMENT 'Texto do escudo. NULL = derivada do nome pela API/app.',
  url_escudo           VARCHAR(500) NULL,
  cidade               VARCHAR(100) NOT NULL,
  sigla_estado         CHAR(2) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  bairro               VARCHAR(100) NULL,
  quantidade_jogadores TINYINT UNSIGNED NULL COMMENT 'Informada pelo capitão (opcional).',
  id_categoria_etaria  TINYINT UNSIGNED NULL,
  id_nivel_tecnico     TINYINT UNSIGNED NULL,
  descricao            VARCHAR(2000) NULL,
  ano_fundacao         SMALLINT UNSIGNED NULL,
  telefone_contato     VARCHAR(20) NULL,
  verificado           BOOLEAN NOT NULL DEFAULT FALSE,
  data_criacao         DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  data_atualizacao     DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  data_arquivamento    DATETIME(3) NULL,
  PRIMARY KEY (id_time),
  CONSTRAINT un_times_capitao UNIQUE (id_capitao),
  CONSTRAINT ce_times_usuarios FOREIGN KEY (id_capitao) REFERENCES usuarios (id_usuario),
  CONSTRAINT ce_times_estados FOREIGN KEY (sigla_estado) REFERENCES estados (sigla),
  CONSTRAINT ce_times_categorias_etarias FOREIGN KEY (id_categoria_etaria) REFERENCES categorias_etarias (id_categoria_etaria),
  CONSTRAINT ce_times_niveis_tecnicos FOREIGN KEY (id_nivel_tecnico) REFERENCES niveis_tecnicos (id_nivel_tecnico),
  CONSTRAINT vr_times_id CHECK (REGEXP_LIKE(id_time, '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', 'c')),
  CONSTRAINT vr_times_nome CHECK (CHAR_LENGTH(TRIM(nome)) > 0),
  CONSTRAINT vr_times_sigla CHECK (sigla IS NULL OR CHAR_LENGTH(TRIM(sigla)) BETWEEN 1 AND 4),
  CONSTRAINT vr_times_cidade CHECK (CHAR_LENGTH(TRIM(cidade)) > 0),
  CONSTRAINT vr_times_quantidade_jogadores CHECK (quantidade_jogadores BETWEEN 5 AND 60),
  CONSTRAINT vr_times_ano_fundacao CHECK (ano_fundacao IS NULL OR ano_fundacao BETWEEN 1900 AND 2100),
  INDEX ind_times_busca (sigla_estado, cidade, id_categoria_etaria, id_nivel_tecnico)
) ENGINE = InnoDB
  COMMENT = 'Times. Exatamente um capitão por time e um time por capitão.';

CREATE TABLE times_modalidades (
  id_time       CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_modalidade TINYINT UNSIGNED NOT NULL,
  data_criacao  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id_time, id_modalidade),
  CONSTRAINT ce_times_modalidades_times FOREIGN KEY (id_time) REFERENCES times (id_time),
  CONSTRAINT ce_times_modalidades_modalidades FOREIGN KEY (id_modalidade) REFERENCES modalidades (id_modalidade),
  INDEX ind_times_modalidades_modalidade (id_modalidade)
) ENGINE = InnoDB
  COMMENT = 'Modalidades praticadas por cada time (N:N).';

-- -----------------------------------------------------------------------------
-- 4. Anúncios de partidas
-- -----------------------------------------------------------------------------

CREATE TABLE anuncios_partidas (
  id_anuncio             CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_time                CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_modalidade          TINYINT UNSIGNED NOT NULL,
  id_categoria_etaria    TINYINT UNSIGNED NULL,
  id_nivel_tecnico       TINYINT UNSIGNED NOT NULL,
  id_mando_campo         TINYINT UNSIGNED NULL,
  quantidade_jogadores   TINYINT UNSIGNED NULL COMMENT 'Jogadores por equipe na partida (opcional).',
  data_hora_inicio       DATETIME(3) NOT NULL COMMENT 'UTC.',
  duracao_minutos        SMALLINT UNSIGNED NULL COMMENT 'Duração prevista da partida, em minutos.',
  cidade                 VARCHAR(100) NOT NULL,
  sigla_estado           CHAR(2) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  bairro                 VARCHAR(100) NULL,
  nome_local             VARCHAR(160) NOT NULL,
  endereco               VARCHAR(255) NULL,
  latitude               DECIMAL(9,6) NULL,
  longitude              DECIMAL(9,6) NULL,
  valor_aluguel_por_time DECIMAL(10,2) NULL,
  descricao              VARCHAR(1000) NULL,
  status                 VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'ativo'
                           COMMENT 'ativo | pausado | encerrado (partida confirmada; indisponível) | expirado',
  data_criacao           DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  data_atualizacao       DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  data_exclusao          DATETIME(3) NULL COMMENT 'Exclusão lógica pelo capitão (preserva o histórico).',
  PRIMARY KEY (id_anuncio),
  CONSTRAINT un_anuncios_partidas_anuncio_time UNIQUE (id_anuncio, id_time),
  CONSTRAINT ce_anuncios_partidas_times FOREIGN KEY (id_time) REFERENCES times (id_time),
  CONSTRAINT ce_anuncios_partidas_modalidades FOREIGN KEY (id_modalidade) REFERENCES modalidades (id_modalidade),
  CONSTRAINT ce_anuncios_partidas_categorias_etarias FOREIGN KEY (id_categoria_etaria) REFERENCES categorias_etarias (id_categoria_etaria),
  CONSTRAINT ce_anuncios_partidas_niveis_tecnicos FOREIGN KEY (id_nivel_tecnico) REFERENCES niveis_tecnicos (id_nivel_tecnico),
  CONSTRAINT ce_anuncios_partidas_mandos_campo FOREIGN KEY (id_mando_campo) REFERENCES mandos_campo (id_mando_campo),
  CONSTRAINT ce_anuncios_partidas_estados FOREIGN KEY (sigla_estado) REFERENCES estados (sigla),
  CONSTRAINT vr_anuncios_partidas_id CHECK (REGEXP_LIKE(id_anuncio, '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', 'c')),
  CONSTRAINT vr_anuncios_partidas_quantidade_jogadores CHECK (quantidade_jogadores BETWEEN 5 AND 30),
  CONSTRAINT vr_anuncios_partidas_duracao CHECK (duracao_minutos IS NULL OR duracao_minutos BETWEEN 15 AND 600),
  CONSTRAINT vr_anuncios_partidas_cidade CHECK (CHAR_LENGTH(TRIM(cidade)) > 0),
  CONSTRAINT vr_anuncios_partidas_nome_local CHECK (CHAR_LENGTH(TRIM(nome_local)) > 0),
  CONSTRAINT vr_anuncios_partidas_valor_aluguel CHECK (valor_aluguel_por_time IS NULL OR valor_aluguel_por_time >= 0),
  CONSTRAINT vr_anuncios_partidas_latitude CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  CONSTRAINT vr_anuncios_partidas_longitude CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
  CONSTRAINT vr_anuncios_partidas_coordenadas CHECK ((latitude IS NULL) = (longitude IS NULL)),
  CONSTRAINT vr_anuncios_partidas_status CHECK (status IN ('ativo', 'pausado', 'encerrado', 'expirado')),
  -- Busca de adversários: status + período, com ou sem filtro de UF/cidade.
  -- busca_local começa por sigla_estado para também servir à chave estrangeira
  -- de estados (evita um índice extra criado automaticamente pela FK).
  INDEX ind_anuncios_partidas_busca_data (status, data_hora_inicio),
  INDEX ind_anuncios_partidas_busca_local (sigla_estado, cidade, status, data_hora_inicio),
  -- "Meus anúncios" e "Meus jogos" (também atende a chave estrangeira de id_time).
  INDEX ind_anuncios_partidas_time (id_time, status, data_hora_inicio)
) ENGINE = InnoDB
  COMMENT = 'Anúncios de times procurando adversário.';

-- -----------------------------------------------------------------------------
-- 5. Solicitações de confronto
-- -----------------------------------------------------------------------------

CREATE TABLE solicitacoes_confronto (
  id_solicitacao            CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_anuncio                CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_time_anunciante        CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL
                              COMMENT 'Copiado do anúncio pelo gatilho; garante a FK composta.',
  id_time_solicitante       CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  status                    VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'pendente'
                              COMMENT 'pendente | confirmada | recusada | cancelada | encerrada',
  mensagem_inicial          VARCHAR(1000) NULL,
  data_confirmacao_anunciante  DATETIME(3) NULL,
  data_confirmacao_solicitante DATETIME(3) NULL,
  data_resposta             DATETIME(3) NULL COMMENT 'Quando deixou de estar pendente.',
  motivo_encerramento       VARCHAR(255) NULL,
  data_criacao              DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT 'Data da solicitação.',
  data_atualizacao          DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  -- Colunas geradas que tornam regras parciais em índices únicos:
  chave_pendente            CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
                              GENERATED ALWAYS AS (IF(status = 'pendente', id_time_solicitante, NULL)) VIRTUAL,
  chave_confirmada          TINYINT UNSIGNED
                              GENERATED ALWAYS AS (IF(status = 'confirmada', 1, NULL)) VIRTUAL,
  PRIMARY KEY (id_solicitacao),
  -- Um time só pode ter uma solicitação pendente por anúncio.
  CONSTRAINT un_solicitacoes_confronto_pendente UNIQUE (id_anuncio, chave_pendente),
  -- No máximo UMA solicitação confirmada por anúncio (barreira final contra concorrência).
  CONSTRAINT un_solicitacoes_confronto_confirmada UNIQUE (id_anuncio, chave_confirmada),
  -- Alvo da FK composta de partidas (garante times e anúncio coerentes).
  CONSTRAINT un_solicitacoes_confronto_contexto UNIQUE (id_solicitacao, id_anuncio, id_time_anunciante, id_time_solicitante),
  CONSTRAINT ce_solicitacoes_confronto_anuncios_partidas FOREIGN KEY (id_anuncio, id_time_anunciante)
    REFERENCES anuncios_partidas (id_anuncio, id_time),
  CONSTRAINT ce_solicitacoes_confronto_times FOREIGN KEY (id_time_solicitante) REFERENCES times (id_time),
  CONSTRAINT vr_solicitacoes_confronto_id CHECK (REGEXP_LIKE(id_solicitacao, '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', 'c')),
  CONSTRAINT vr_solicitacoes_confronto_times_distintos CHECK (id_time_solicitante <> id_time_anunciante),
  CONSTRAINT vr_solicitacoes_confronto_status CHECK (status IN ('pendente', 'confirmada', 'recusada', 'cancelada', 'encerrada')),
  CONSTRAINT vr_solicitacoes_confronto_confirmada CHECK (
    status <> 'confirmada' OR (data_confirmacao_anunciante IS NOT NULL AND data_confirmacao_solicitante IS NOT NULL)),
  CONSTRAINT vr_solicitacoes_confronto_resposta CHECK ((status = 'pendente') = (data_resposta IS NULL)),
  CONSTRAINT vr_solicitacoes_confronto_motivo CHECK (status <> 'encerrada' OR motivo_encerramento IS NOT NULL),
  INDEX ind_solicitacoes_confronto_anuncio (id_anuncio, status),
  INDEX ind_solicitacoes_confronto_solicitante (id_time_solicitante, status, data_atualizacao),
  INDEX ind_solicitacoes_confronto_anunciante (id_time_anunciante, status, data_atualizacao)
) ENGINE = InnoDB
  COMMENT = 'Pedidos de confronto de um time a um anúncio. Um anúncio recebe vários.';

CREATE TABLE mensagens (
  id_mensagem          CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_solicitacao       CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_time_remetente    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_usuario_remetente CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  texto                VARCHAR(1000) NOT NULL,
  data_envio           DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  data_leitura         DATETIME(3) NULL COMMENT 'Lida pelo capitão do outro time.',
  PRIMARY KEY (id_mensagem),
  CONSTRAINT ce_mensagens_solicitacoes_confronto FOREIGN KEY (id_solicitacao) REFERENCES solicitacoes_confronto (id_solicitacao),
  CONSTRAINT ce_mensagens_times FOREIGN KEY (id_time_remetente) REFERENCES times (id_time),
  CONSTRAINT ce_mensagens_usuarios FOREIGN KEY (id_usuario_remetente) REFERENCES usuarios (id_usuario),
  CONSTRAINT vr_mensagens_id CHECK (REGEXP_LIKE(id_mensagem, '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', 'c')),
  CONSTRAINT vr_mensagens_texto CHECK (CHAR_LENGTH(TRIM(texto)) > 0),
  CONSTRAINT vr_mensagens_leitura CHECK (data_leitura IS NULL OR data_leitura >= data_envio),
  INDEX ind_mensagens_conversa (id_solicitacao, data_envio),
  INDEX ind_mensagens_nao_lidas (id_solicitacao, id_time_remetente, data_leitura)
) ENGINE = InnoDB
  COMMENT = 'Conversa entre os capitães dentro de uma solicitação.';

-- -----------------------------------------------------------------------------
-- 6. Partidas
-- -----------------------------------------------------------------------------

CREATE TABLE partidas (
  id_partida             CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_solicitacao         CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_anuncio             CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_time_anunciante     CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_time_adversario     CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  -- Cópia dos dados combinados (edições no anúncio não alteram a partida):
  id_modalidade          TINYINT UNSIGNED NOT NULL,
  quantidade_jogadores   TINYINT UNSIGNED NULL,
  data_hora_inicio       DATETIME(3) NOT NULL COMMENT 'UTC.',
  nome_local             VARCHAR(160) NOT NULL,
  endereco               VARCHAR(255) NULL,
  cidade                 VARCHAR(100) NOT NULL,
  sigla_estado           CHAR(2) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  latitude               DECIMAL(9,6) NULL,
  longitude              DECIMAL(9,6) NULL,
  valor_aluguel_por_time DECIMAL(10,2) NULL,
  status                 VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'confirmada'
                           COMMENT 'confirmada | realizada | cancelada',
  gols_anunciante        TINYINT UNSIGNED NULL,
  gols_adversario        TINYINT UNSIGNED NULL,
  id_time_cancelou       CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  motivo_cancelamento    VARCHAR(500) NULL,
  data_cancelamento      DATETIME(3) NULL,
  data_realizacao        DATETIME(3) NULL,
  data_criacao           DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT 'Momento da confirmação.',
  data_atualizacao       DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id_partida),
  -- Uma partida por solicitação e uma por anúncio (o anúncio fica indisponível).
  CONSTRAINT un_partidas_solicitacao UNIQUE (id_solicitacao),
  CONSTRAINT un_partidas_anuncio UNIQUE (id_anuncio),
  CONSTRAINT ce_partidas_solicitacoes_confronto
    FOREIGN KEY (id_solicitacao, id_anuncio, id_time_anunciante, id_time_adversario)
    REFERENCES solicitacoes_confronto (id_solicitacao, id_anuncio, id_time_anunciante, id_time_solicitante),
  CONSTRAINT ce_partidas_anuncios_partidas FOREIGN KEY (id_anuncio) REFERENCES anuncios_partidas (id_anuncio),
  CONSTRAINT ce_partidas_time_anunciante FOREIGN KEY (id_time_anunciante) REFERENCES times (id_time),
  CONSTRAINT ce_partidas_time_adversario FOREIGN KEY (id_time_adversario) REFERENCES times (id_time),
  CONSTRAINT ce_partidas_time_cancelou FOREIGN KEY (id_time_cancelou) REFERENCES times (id_time),
  CONSTRAINT ce_partidas_modalidades FOREIGN KEY (id_modalidade) REFERENCES modalidades (id_modalidade),
  CONSTRAINT ce_partidas_estados FOREIGN KEY (sigla_estado) REFERENCES estados (sigla),
  CONSTRAINT vr_partidas_id CHECK (REGEXP_LIKE(id_partida, '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', 'c')),
  CONSTRAINT vr_partidas_times_distintos CHECK (id_time_anunciante <> id_time_adversario),
  CONSTRAINT vr_partidas_quantidade_jogadores CHECK (quantidade_jogadores BETWEEN 5 AND 30),
  CONSTRAINT vr_partidas_valor_aluguel CHECK (valor_aluguel_por_time IS NULL OR valor_aluguel_por_time >= 0),
  CONSTRAINT vr_partidas_latitude CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  CONSTRAINT vr_partidas_longitude CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
  CONSTRAINT vr_partidas_coordenadas CHECK ((latitude IS NULL) = (longitude IS NULL)),
  CONSTRAINT vr_partidas_status CHECK (status IN ('confirmada', 'realizada', 'cancelada')),
  CONSTRAINT vr_partidas_cancelamento CHECK (
    (status = 'cancelada') = (id_time_cancelou IS NOT NULL AND data_cancelamento IS NOT NULL)),
  CONSTRAINT vr_partidas_time_cancelou CHECK (
    id_time_cancelou IS NULL OR id_time_cancelou IN (id_time_anunciante, id_time_adversario)),
  CONSTRAINT vr_partidas_realizacao CHECK ((status = 'realizada') = (data_realizacao IS NOT NULL)),
  CONSTRAINT vr_partidas_placar CHECK (
    (gols_anunciante IS NULL AND gols_adversario IS NULL)
    OR (status = 'realizada' AND gols_anunciante IS NOT NULL AND gols_adversario IS NOT NULL)),
  INDEX ind_partidas_time_anunciante (id_time_anunciante, status, data_hora_inicio),
  INDEX ind_partidas_time_adversario (id_time_adversario, status, data_hora_inicio),
  INDEX ind_partidas_rotina_status (status, data_hora_inicio)
) ENGINE = InnoDB
  COMMENT = 'Partidas confirmadas pelas duas equipes.';

-- -----------------------------------------------------------------------------
-- 7. Avaliações
-- -----------------------------------------------------------------------------

CREATE TABLE avaliacoes (
  id_avaliacao      CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_partida        CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_time_avaliador CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_time_avaliado  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  comentario        VARCHAR(1000) NULL,
  data_criacao      DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id_avaliacao),
  CONSTRAINT un_avaliacoes_partida_avaliador UNIQUE (id_partida, id_time_avaliador),
  CONSTRAINT ce_avaliacoes_partidas FOREIGN KEY (id_partida) REFERENCES partidas (id_partida),
  CONSTRAINT ce_avaliacoes_time_avaliador FOREIGN KEY (id_time_avaliador) REFERENCES times (id_time),
  CONSTRAINT ce_avaliacoes_time_avaliado FOREIGN KEY (id_time_avaliado) REFERENCES times (id_time),
  CONSTRAINT vr_avaliacoes_id CHECK (REGEXP_LIKE(id_avaliacao, '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', 'c')),
  CONSTRAINT vr_avaliacoes_times_distintos CHECK (id_time_avaliador <> id_time_avaliado),
  INDEX ind_avaliacoes_time_avaliado (id_time_avaliado, data_criacao)
) ENGINE = InnoDB
  COMMENT = 'Avaliação de um time sobre o adversário após partida realizada (imutável).';

CREATE TABLE notas_avaliacao (
  id_avaliacao CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_criterio  TINYINT UNSIGNED NOT NULL,
  nota         TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (id_avaliacao, id_criterio),
  CONSTRAINT ce_notas_avaliacao_avaliacoes FOREIGN KEY (id_avaliacao) REFERENCES avaliacoes (id_avaliacao),
  CONSTRAINT ce_notas_avaliacao_criterios_avaliacao FOREIGN KEY (id_criterio) REFERENCES criterios_avaliacao (id_criterio),
  CONSTRAINT vr_notas_avaliacao_nota CHECK (nota BETWEEN 1 AND 5),
  INDEX ind_notas_avaliacao_criterio (id_criterio)
) ENGINE = InnoDB
  COMMENT = 'Nota de 1 a 5 por critério de cada avaliação.';

-- -----------------------------------------------------------------------------
-- 8. Notificações
-- -----------------------------------------------------------------------------

CREATE TABLE notificacoes (
  id_notificacao          CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_usuario_destinatario CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  tipo                    VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  titulo                  VARCHAR(160) NOT NULL,
  mensagem                VARCHAR(500) NOT NULL,
  id_anuncio              CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  id_solicitacao          CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  id_partida              CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  data_leitura            DATETIME(3) NULL,
  data_criacao            DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id_notificacao),
  CONSTRAINT ce_notificacoes_usuarios FOREIGN KEY (id_usuario_destinatario) REFERENCES usuarios (id_usuario),
  CONSTRAINT ce_notificacoes_anuncios_partidas FOREIGN KEY (id_anuncio) REFERENCES anuncios_partidas (id_anuncio),
  CONSTRAINT ce_notificacoes_solicitacoes_confronto FOREIGN KEY (id_solicitacao) REFERENCES solicitacoes_confronto (id_solicitacao),
  CONSTRAINT ce_notificacoes_partidas FOREIGN KEY (id_partida) REFERENCES partidas (id_partida),
  CONSTRAINT vr_notificacoes_id CHECK (REGEXP_LIKE(id_notificacao, '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', 'c')),
  CONSTRAINT vr_notificacoes_tipo CHECK (tipo IN (
    'solicitacao_recebida', 'mensagem_recebida', 'partida_confirmada', 'partida_cancelada',
    'solicitacao_encerrada', 'solicitacao_recusada', 'anuncio_expirando', 'avaliacao_pendente')),
  CONSTRAINT vr_notificacoes_titulo CHECK (CHAR_LENGTH(TRIM(titulo)) > 0),
  CONSTRAINT vr_notificacoes_referencia_unica CHECK (
    (id_anuncio IS NOT NULL) + (id_solicitacao IS NOT NULL) + (id_partida IS NOT NULL) <= 1),
  CONSTRAINT vr_notificacoes_leitura CHECK (data_leitura IS NULL OR data_leitura >= data_criacao),
  INDEX ind_notificacoes_destinatario (id_usuario_destinatario, data_leitura, data_criacao)
) ENGINE = InnoDB
  COMMENT = 'Alertas para os capitães.';
