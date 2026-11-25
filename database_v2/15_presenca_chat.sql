-- =============================================================================
-- Joga Contra — banco joga_contra_v2 — MySQL 8.4 LTS
-- 15_presenca_chat.sql (25/11/2026): notificações do chat, fase 4.
--
-- conversas_abertas: quando cada capitão está com uma conversa aberta. O app
-- consulta as mensagens a cada 4 s enquanto a conversa está na tela; cada
-- consulta renova data_ultimo_acesso. Ao sair da conversa ou deixar o app em
-- segundo plano, o app avisa (aberta = 0). A API considera a conversa aberta se
-- aberta = 1 e o último acesso tem menos de 12 s (três consultas): nesse caso a
-- mensagem nova gera a notificação interna já lida (histórico, sem push), porque
-- a pessoa está vendo a conversa. Uma linha por capitão e conversa (presença,
-- não histórico: é atualizada no lugar).
--
-- Não altera nem apaga dados. Para bancos criados antes desta versão; 01 já
-- traz o resultado. Execute uma vez (CREATE TABLE).
-- =============================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET time_zone = '+00:00';

CREATE TABLE conversas_abertas (
  id_usuario          CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  id_solicitacao      CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  aberta              TINYINT(1) NOT NULL DEFAULT 1,
  data_ultimo_acesso  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id_usuario, id_solicitacao),
  CONSTRAINT ce_conversas_abertas_usuarios FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario),
  CONSTRAINT ce_conversas_abertas_solicitacoes FOREIGN KEY (id_solicitacao) REFERENCES solicitacoes_confronto (id_solicitacao)
) ENGINE = InnoDB
  COMMENT = 'Presença no chat: conversa aberta na tela de cada capitão (evita push para quem está lendo).';
