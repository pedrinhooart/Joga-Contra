-- =============================================================================
-- Joga Contra — banco joga_contra_v2 — MySQL 8.4 LTS
-- 14_push.sql (25/11/2026): notificações push (Firebase Cloud Messaging), fase 3.
--
--   dispositivos_push  aparelhos de cada capitão (token FCM). Um token pertence
--                      a uma conta por vez (UNIQUE); uma conta pode ter vários
--                      aparelhos. Nada é apagado: desativar guarda o motivo;
--                      "remover" apaga só o token (dado técnico do aparelho).
--   envios_push        fila de envio (padrão outbox). Cada notificação nova e
--                      não lida entra na fila pelo gatilho abaixo, NA MESMA
--                      TRANSAÇÃO do evento: se o evento for desfeito, o envio
--                      também é. A API envia depois, fora da transação, então
--                      uma falha do Firebase nunca desfaz o evento nem a
--                      notificação interna. Uma linha por notificação (UNIQUE):
--                      sem envio duplicado.
--
-- Notificações já existentes não entram na fila (só as criadas daqui em
-- diante). Não altera nem apaga dados. Para bancos criados antes desta versão;
-- 01 e 02 já trazem o resultado. Execute uma vez (CREATE TABLE).
-- =============================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET time_zone = '+00:00';

CREATE TABLE dispositivos_push (
  id_dispositivo         CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_usuario             CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  token_fcm              VARCHAR(512) CHARACTER SET ascii COLLATE ascii_bin NULL
    COMMENT 'Token do Firebase Cloud Messaging. NULL depois de removido.',
  plataforma             VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  permissao_notificacoes TINYINT(1) NOT NULL DEFAULT 1
    COMMENT 'O capitão autorizou notificações no aparelho (Android 13+ e iOS pedem).',
  ativo                  TINYINT(1) NOT NULL DEFAULT 1,
  motivo_desativacao     VARCHAR(40) NULL,
  data_criacao           DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  data_atualizacao       DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  data_ultimo_uso        DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
    COMMENT 'Último registro do token pelo app (abertura com sessão).',
  data_ultimo_envio      DATETIME(3) NULL,
  PRIMARY KEY (id_dispositivo),
  CONSTRAINT un_dispositivos_push_token UNIQUE (token_fcm),
  CONSTRAINT ce_dispositivos_push_usuarios FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario),
  CONSTRAINT vr_dispositivos_push_id CHECK (REGEXP_LIKE(id_dispositivo, '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', 'c')),
  CONSTRAINT vr_dispositivos_push_plataforma CHECK (plataforma IN ('android', 'ios', 'web')),
  CONSTRAINT vr_dispositivos_push_ativo_token CHECK (ativo = 0 OR token_fcm IS NOT NULL),
  CONSTRAINT vr_dispositivos_push_motivo CHECK ((ativo = 1) = (motivo_desativacao IS NULL)),
  INDEX ind_dispositivos_push_usuario (id_usuario, ativo)
) ENGINE = InnoDB
  COMMENT = 'Aparelhos que recebem notificações push.';

CREATE TABLE envios_push (
  id_envio              CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_notificacao        CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  status                VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'pendente',
  tentativas            TINYINT UNSIGNED NOT NULL DEFAULT 0,
  proxima_tentativa     DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
    COMMENT 'Pendente: quando tentar. Enviando: fim da reserva (se o servidor cair, volta para a fila).',
  dispositivos_enviados SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  ultimo_erro           VARCHAR(200) NULL COMMENT 'Código do erro, sem token nem conteúdo.',
  data_criacao          DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  data_atualizacao      DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  data_conclusao        DATETIME(3) NULL,
  PRIMARY KEY (id_envio),
  CONSTRAINT un_envios_push_notificacao UNIQUE (id_notificacao),
  CONSTRAINT ce_envios_push_notificacoes FOREIGN KEY (id_notificacao) REFERENCES notificacoes (id_notificacao),
  CONSTRAINT vr_envios_push_id CHECK (REGEXP_LIKE(id_envio, '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', 'c')),
  CONSTRAINT vr_envios_push_status CHECK (status IN ('pendente', 'enviando', 'enviado', 'falhou', 'ignorado')),
  INDEX ind_envios_push_fila (status, proxima_tentativa)
) ENGINE = InnoDB
  COMMENT = 'Fila de envio das notificações push (outbox).';

DELIMITER $$
-- Toda notificação nova ainda não lida entra na fila de push, na mesma
-- transação que a criou. As já lidas (registro de uma ação da própria pessoa)
-- não geram push.
CREATE TRIGGER gat_notificacoes_depois_inserir
AFTER INSERT ON notificacoes FOR EACH ROW
BEGIN
  IF NEW.data_leitura IS NULL THEN
    INSERT INTO envios_push (id_envio, id_notificacao, proxima_tentativa, data_criacao)
    VALUES (UUID(), NEW.id_notificacao, NEW.data_criacao, NEW.data_criacao);
  END IF;
END$$
DELIMITER ;
