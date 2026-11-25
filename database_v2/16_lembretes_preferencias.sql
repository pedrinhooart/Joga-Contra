-- =============================================================================
-- Joga Contra — banco joga_contra_v2 — MySQL 8.4 LTS
-- 16_lembretes_preferencias.sql (25/11/2026): notificações, fase 5.
--
--   tipo 'lembrete_partida'  lembretes de jogo (24 h, 2 h e 30 min antes).
--   lembretes_partidas       controle dos lembretes já tratados. A chave é
--                            (partida, tipo, horário de início): repetir o
--                            processamento não envia de novo; se o horário
--                            mudasse, a chave nova geraria lembretes novos (hoje
--                            o horário da partida confirmada não muda).
--                            'pulado' = janela perdida (jogo confirmado depois
--                            dela, ou servidor fora do ar): não se envia atrasado.
--   preferencias_notificacoes  categorias que o capitão desativou. Sem linha =
--                            tudo ativo.
--   gat_notificacoes_antes_inserir  categoria desativada: a notificação é
--                            registrada já lida (fica no histórico, não conta no
--                            sino e não vira push). Avisos gerais ('aviso') não
--                            são afetados.
--
-- Não altera nem apaga dados (a nova lista de tipos contém todos os anteriores).
-- Para bancos criados antes desta versão; 01 e 02 já trazem o resultado.
-- =============================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET time_zone = '+00:00';

ALTER TABLE notificacoes
  DROP CHECK vr_notificacoes_tipo,
  ADD CONSTRAINT vr_notificacoes_tipo CHECK (tipo IN (
    'solicitacao_recebida', 'mensagem_recebida', 'partida_confirmada', 'partida_cancelada',
    'solicitacao_encerrada', 'solicitacao_recusada', 'anuncio_expirando', 'avaliacao_pendente',
    'aviso', 'solicitacao_enviada', 'lembrete_partida'));

CREATE TABLE lembretes_partidas (
  id_partida        CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  tipo              VARCHAR(5) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  data_hora_inicio  DATETIME(3) NOT NULL COMMENT 'Início (UTC) considerado no lembrete.',
  status            VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  data_processamento DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id_partida, tipo, data_hora_inicio),
  CONSTRAINT ce_lembretes_partidas_partidas FOREIGN KEY (id_partida) REFERENCES partidas (id_partida),
  CONSTRAINT vr_lembretes_partidas_tipo CHECK (tipo IN ('24h', '2h', '30min')),
  CONSTRAINT vr_lembretes_partidas_status CHECK (status IN ('enviado', 'pulado'))
) ENGINE = InnoDB
  COMMENT = 'Lembretes de jogo já tratados (garante um por partida, tipo e horário).';

CREATE TABLE preferencias_notificacoes (
  id_usuario        CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  desafios          TINYINT(1) NOT NULL DEFAULT 1,
  jogos             TINYINT(1) NOT NULL DEFAULT 1,
  chat              TINYINT(1) NOT NULL DEFAULT 1,
  lembretes         TINYINT(1) NOT NULL DEFAULT 1,
  data_atualizacao  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id_usuario),
  CONSTRAINT ce_preferencias_notificacoes_usuarios FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario)
) ENGINE = InnoDB
  COMMENT = 'Categorias de notificação de cada capitão (sem linha = todas ativas).';

DELIMITER $$
-- Categoria desativada pelo destinatário: registra já lida (histórico, sem
-- contar no sino e sem push). Vale para as notificações da API e dos procedimentos.
CREATE TRIGGER gat_notificacoes_antes_inserir
BEFORE INSERT ON notificacoes FOR EACH ROW
BEGIN
  DECLARE v_categoria VARCHAR(10) DEFAULT CASE
    WHEN NEW.tipo IN ('solicitacao_recebida', 'solicitacao_enviada', 'solicitacao_recusada', 'solicitacao_encerrada')
      THEN 'desafios'
    WHEN NEW.tipo IN ('partida_confirmada', 'partida_cancelada', 'avaliacao_pendente', 'anuncio_expirando')
      THEN 'jogos'
    WHEN NEW.tipo = 'mensagem_recebida' THEN 'chat'
    WHEN NEW.tipo = 'lembrete_partida' THEN 'lembretes'
    ELSE NULL
  END;
  IF v_categoria IS NOT NULL AND NEW.data_leitura IS NULL AND EXISTS (
      SELECT 1 FROM preferencias_notificacoes p
       WHERE p.id_usuario = NEW.id_usuario_destinatario
         AND ((v_categoria = 'desafios' AND p.desafios = 0) OR (v_categoria = 'jogos' AND p.jogos = 0)
           OR (v_categoria = 'chat' AND p.chat = 0) OR (v_categoria = 'lembretes' AND p.lembretes = 0))) THEN
    SET NEW.data_leitura = NEW.data_criacao;
  END IF;
END$$
DELIMITER ;
